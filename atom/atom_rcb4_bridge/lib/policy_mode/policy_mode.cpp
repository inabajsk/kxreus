#include "policy_mode.h"

#include <M5Unified.h>
#include <math.h>
#include <net.h>
#include <string.h>

namespace {

/// Host frame: [0xA5][mode][vx lo,hi][vy lo,hi][wz lo,hi][checksum].
constexpr uint8_t HOST_MAGIC = 0xA5;
constexpr size_t HOST_FRAME_SIZE = 9;
/// Velocities travel as int16 thousandths, so 0.35 m/s is 350.
constexpr float VELOCITY_SCALE = 0.001f;

constexpr uint8_t DEVICE_MAGIC = 0x5A;
constexpr size_t DEVICE_FRAME_SIZE = 34;

/// How often the LCD is redrawn while the loop runs. Drawing costs
/// milliseconds the servos would feel, so it happens between control steps
/// and no more often than the eye can use.
constexpr uint32_t DRAW_INTERVAL_MS = 250;

/// Servo ids ascending, and where each one sits in the policy's joint order.
/// The board reads a servo command's positions in id order against a bitmap,
/// so an unsorted list would send every angle to the wrong servo.
uint8_t g_sorted_ids[POLICY_ACT_DIM];
uint8_t g_sorted_to_joint[POLICY_ACT_DIM];
bool g_order_ready = false;

void buildServoOrder() {
    if (g_order_ready) return;
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) g_sorted_to_joint[i] = i;
    // Insertion sort: 19 elements, once, at startup.
    for (size_t i = 1; i < POLICY_ACT_DIM; i++) {
        const uint8_t key = g_sorted_to_joint[i];
        size_t j = i;
        while (j > 0 && kPolicyServoIds[g_sorted_to_joint[j - 1]] >
                                kPolicyServoIds[key]) {
            g_sorted_to_joint[j] = g_sorted_to_joint[j - 1];
            j--;
        }
        g_sorted_to_joint[j] = key;
    }
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
        g_sorted_ids[i] = kPolicyServoIds[g_sorted_to_joint[i]];
    }
    g_order_ready = true;
}

float clampf(float v, float low, float high) {
    return v < low ? low : (v > high ? high : v);
}

// Not Arduino's DEG_TO_RAD / RAD_TO_DEG: those are macros, so the names
// cannot be reused, and they are double, which would quietly promote every
// conversion here out of single precision.
constexpr float kDegToRad = 0.017453292519943295f;
constexpr float kRadToDeg = 57.29577951308232f;

}  // namespace

void PolicyMode::enter() {
    buildServoOrder();
    M5.Display.clear();
    // Arriving here must not move anything: the operator switched modes, they
    // did not ask the hand to walk. The policy starts only when the host says
    // RUN.
    request_ = Request::FREE;
    command_[0] = command_[1] = command_[2] = 0.0f;
    host_spoke_ = false;
    step_ = 0;
    history_len_ = 0;
    history_head_ = 0;
    memset(last_action_, 0, sizeof(last_action_));
    host_frames_ = 0;
    // A HOLD asked for before the first step would otherwise ramp from a pose
    // of all zeros, which is not a pose the hand has ever been in.
    memcpy(last_target_, kPolicyHomeRad, sizeof(last_target_));
    overruns_ = 0;
    consecutive_errors_ = 0;
    total_errors_ = 0;
    last_draw_ms_ = 0;
    freeServos();
    setState(State::IDLE);
    next_step_us_ = micros();
    if (draw_task_ == nullptr) {
        // Core 0, beside the Wi-Fi stack and the web server; the control loop
        // has core 1 to itself.
        xTaskCreatePinnedToCore(drawTask, "kxr-lcd", 4096, this, 1,
                                &draw_task_, 0);
    }
}

void PolicyMode::exit() {
    // Stop painting before the next mode starts: two tasks drawing to one
    // panel would interleave.
    if (draw_task_ != nullptr) {
        vTaskDelete(draw_task_);
        draw_task_ = nullptr;
    }
    // Leaving with servos driven would hand a live hand to the bridge, which
    // does not know it is holding anything.
    freeServos();
    state_ = State::IDLE;
}

void PolicyMode::freeServos() {
    uint16_t free_all[POLICY_ACT_DIM];
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) free_all[i] = 0x8000;
    link_.writeServoPulses(g_sorted_ids, free_all, POLICY_ACT_DIM,
                           POLICY_SERVO_FRAME_COUNT);
}

bool PolicyMode::homingArrived() {
    // Measure rather than assume. One interpolation often falls short, so
    // this decides between sending the hand at home again and accepting where
    // it got to -- and either way it latches the number the operator needs to
    // tell "the hand reached its stance" from "the hand never moved".
    const float err = measureHomeError();
    if (err >= 0.0f && err > HOME_TOLERANCE_RAD &&
        homing_attempt_ < HOMING_ATTEMPTS) {
        if (sendHome()) return false;
    }
    home_error_milli_ = static_cast<int16_t>(
            err < 0.0f ? -1 : clampf(err * 1000.0f, 0.0f, 32767.0f));
    return true;
}

void PolicyMode::beginAfterHoming() {
    if (after_homing_ == State::HOLDING) {
        // Hold where homing has just put it, so the ramp has nothing left to
        // travel and the hand simply stays in its stance.
        memcpy(hold_from_, kPolicyHomeRad, sizeof(hold_from_));
        hold_steps_ = 1;
        hold_step_ = 0;
    }
    setState(after_homing_);
}

float PolicyMode::measureHomeError() {
    uint16_t pulses[POLICY_ACT_DIM];
    if (!link_.readServoPulsesFor(g_sorted_ids, pulses, POLICY_ACT_DIM)) {
        return -1.0f;
    }
    float worst = 0.0f;
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
        const float rad = (pulses[i] - Rcb4Link::PULSE_NEUTRAL) /
                          Rcb4Link::DEG_TO_PULSE * kDegToRad;
        worst = fmaxf(worst, fabsf(rad - kPolicyHomeRad[g_sorted_to_joint[i]]));
    }
    return worst;
}

bool PolicyMode::sendHome() {
    uint16_t out[POLICY_ACT_DIM];
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
        const size_t joint = g_sorted_to_joint[i];
        const float pulse = kPolicyHomeRad[joint] * kRadToDeg *
                                    Rcb4Link::DEG_TO_PULSE +
                            Rcb4Link::PULSE_NEUTRAL;
        out[i] = static_cast<uint16_t>(clampf(pulse, 3500.0f, 11500.0f));
    }
    // Slowly: the hand may be starting from anywhere, and nothing here is
    // time-critical.
    if (!link_.writeServoPulses(g_sorted_ids, out, POLICY_ACT_DIM,
                                POLICY_HOME_FRAME_COUNT)) {
        return false;
    }
    homing_attempt_++;
    homing_until_ms_ = millis() + HOMING_MS;
    return true;
}

bool PolicyMode::beginHoming(State then) {
    // Stiffness first, because it changes how the servos behave on the very
    // move this is about to command. The board comes set to 127, which buzzed
    // on this hand; calibration.yaml settled on 90.
    if (!link_.writeServoStretch(g_sorted_ids, POLICY_ACT_DIM,
                                 POLICY_SERVO_STRETCH)) {
        return false;
    }
    // Turn the servos on where they already are, before asking them to go
    // anywhere. 0x7FFF holds the current position; the host library calls
    // this out as its own step (`interface.hold(...)`) ahead of writing any
    // angle, and a servo that was freed on the way into this mode has to be
    // taken out of that state before a position means anything to it.
    uint16_t hold_all[POLICY_ACT_DIM];
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) hold_all[i] = 0x7FFF;
    if (!link_.writeServoPulses(g_sorted_ids, hold_all, POLICY_ACT_DIM, 1)) {
        return false;
    }

    homing_attempt_ = 0;
    home_error_milli_ = -1;
    after_homing_ = then;
    if (!sendHome()) return false;
    // The gait clock and the velocity history both start from the stance,
    // not from whatever the hand was doing while it was free.
    step_ = 0;
    history_len_ = 0;
    history_head_ = 0;
    memset(last_action_, 0, sizeof(last_action_));
    memcpy(last_target_, kPolicyHomeRad, sizeof(last_target_));
    setState(State::HOMING);
    return true;
}

void PolicyMode::setState(State state) {
    // No repaint here: the display task notices within its own interval. A
    // state change is exactly the moment the control loop can least afford
    // 16 ms of SPI.
    state_ = state;
}

void PolicyMode::drawTask(void* arg) {
    PolicyMode* self = static_cast<PolicyMode*>(arg);
    for (;;) {
        self->draw();
        vTaskDelay(pdMS_TO_TICKS(DRAW_INTERVAL_MS));
    }
}

void PolicyMode::draw() {
    const net::Telemetry t = net::telemetry();
    const char* label = "IDLE";
    uint16_t colour = TFT_DARKGREY;
    switch (static_cast<State>(t.state)) {
        case State::RUNNING: label = "RUN"; colour = TFT_GREEN; break;
        case State::HOMING: label = "HOME"; colour = TFT_CYAN; break;
        case State::HOLDING: label = "HOLD"; colour = TFT_YELLOW; break;
        case State::FAULT: label = "FAULT"; colour = TFT_RED; break;
        case State::IDLE: break;
    }
    M5.Display.fillRect(0, 0, M5.Display.width(), M5.Display.height(),
                        TFT_BLACK);
    M5.Display.setTextSize(2);
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("POLICY");
    M5.Display.fillRoundRect(4, 26, 16, 16, 4, colour);
    M5.Display.setCursor(26, 27);
    M5.Display.println(label);
    M5.Display.setTextSize(1);
    M5.Display.setCursor(0, 52);
    M5.Display.printf("vx %+.2f\nwz %+.2f\n", t.vx, t.wz);
    // What the button does from here, because there is no other label on it.
    M5.Display.printf("%s / run\n",
                      t.state == static_cast<uint8_t>(State::IDLE) ||
                                      t.state == static_cast<uint8_t>(State::FAULT)
                              ? "1=on"
                              : "1=off");
    M5.Display.printf("loop %lu us\n", static_cast<unsigned long>(t.loop_us));
    M5.Display.printf("over %lu  err %lu",
                      static_cast<unsigned long>(t.overruns),
                      static_cast<unsigned long>(t.errors));
}

bool PolicyMode::acceptHostFrame(const uint8_t* buf) {
    uint16_t sum = 0;
    for (size_t i = 0; i + 1 < HOST_FRAME_SIZE; i++) sum += buf[i];
    if (static_cast<uint8_t>(sum & 0xFF) != buf[HOST_FRAME_SIZE - 1]) {
        return false;
    }
    request_ = static_cast<Request>(buf[1]);
    for (size_t axis = 0; axis < 3; axis++) {
        const int16_t raw = static_cast<int16_t>(
                static_cast<uint16_t>(buf[2 + axis * 2]) |
                (static_cast<uint16_t>(buf[3 + axis * 2]) << 8));
        command_[axis] = raw * VELOCITY_SCALE;
    }
    last_host_ms_ = millis();
    host_spoke_ = true;
    host_frames_++;
    return true;
}

bool PolicyMode::readHostFrame() {
    // Two transports carrying the same frame: the USB cable and UDP over the
    // lab network. Whichever spoke last is the operator, and telemetry
    // follows it back -- so unplugging the cable and picking up a phone needs
    // no mode, no setting and no restart.
    //
    // Only whole frames are acted on, and the newest one wins: if a host sent
    // faster than the loop ran, the older commands are stale by definition
    // and replaying them would lag the operator's stick.
    static uint8_t buf[HOST_FRAME_SIZE];
    static size_t len = 0;
    bool got = false;


    while (Serial.available()) {
        const uint8_t byte = Serial.read();
        if (len == 0 && byte != HOST_MAGIC) continue;
        buf[len++] = byte;
        if (len < HOST_FRAME_SIZE) continue;
        len = 0;
        if (acceptHostFrame(buf)) {
            reply_to_ = ReplyTo::USB;
            got = true;
        }
    }

    // One path for both radios' worth of client: a UDP datagram and a
    // request from the page arrive the same way, because net:: has already
    // reduced them to the same nine bytes. The page's request was answered on
    // the other core before this ever saw it.
    uint8_t frame[HOST_FRAME_SIZE];
    while (net::receiveCommand(frame, sizeof(frame))) {
        if (frame[0] != HOST_MAGIC) continue;
        if (acceptHostFrame(frame)) {
            reply_to_ = net::lastCommandWasUdp() ? ReplyTo::UDP : ReplyTo::HTTP;
            got = true;
        }
    }
    return got;
}

void PolicyMode::sendTelemetry() {
    uint8_t frame[DEVICE_FRAME_SIZE];
    memset(frame, 0, sizeof(frame));
    frame[0] = DEVICE_MAGIC;
    frame[1] = static_cast<uint8_t>(state_);
    frame[2] = static_cast<uint8_t>(request_);
    frame[3] = 0;
    memcpy(frame + 4, &step_, 4);
    memcpy(frame + 8, &loop_us_, 4);
    memcpy(frame + 12, &overruns_, 4);
    memcpy(frame + 16, &total_errors_, 4);
    memcpy(frame + 20, &host_frames_, 4);
    // Enough of the pose to see it move without sending all 19 joints every
    // step: the largest action the policy asked for, in thousandths.
    float peak = 0.0f;
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
        peak = fmaxf(peak, fabsf(last_action_[i]));
    }
    const int16_t peak_milli = static_cast<int16_t>(
            clampf(peak * 1000.0f, -32768.0f, 32767.0f));
    memcpy(frame + 24, &peak_milli, 2);
    // The command as THIS end understood it, which is the half of the link
    // the host cannot check on its own.
    const int16_t vx_milli = static_cast<int16_t>(
            clampf(command_[0] * 1000.0f, -32768.0f, 32767.0f));
    const int16_t wz_milli = static_cast<int16_t>(
            clampf(command_[2] * 1000.0f, -32768.0f, 32767.0f));
    memcpy(frame + 26, &vx_milli, 2);
    memcpy(frame + 28, &wz_milli, 2);
    memcpy(frame + 30, &home_error_milli_, 2);
    memcpy(frame + 32, &pose_error_milli_, 2);
    // Back the way the last command came. A USB host that is not there gets
    // nothing written at it, and a UDP peer that has gone quiet is forgotten
    // by net:: rather than being sent telemetry forever.
    // The page reads this out of a snapshot rather than being sent to, and
    // it is what tells the page that a control loop is running at all.
    net::Debug debug;
    debug.request = static_cast<uint8_t>(request_);
    debug.quiet_ms = host_spoke_ ? millis() - last_host_ms_ : 0;
    debug.host_frames = host_frames_;
    debug.step = step_;
    debug.homing_attempt = homing_attempt_;
    debug.home_err = home_error_milli_;
    net::setTelemetry(static_cast<uint8_t>(state_), command_[0], command_[2],
                      loop_us_, total_errors_, overruns_, draw_us_, debug);

    switch (reply_to_) {
        case ReplyTo::USB: Serial.write(frame, sizeof(frame)); break;
        case ReplyTo::UDP: net::send(frame, sizeof(frame)); break;
        // A browser was already answered inline, in readHostFrame().
        case ReplyTo::HTTP: break;
    }
}

void PolicyMode::buildObs(float* obs) const {
    memset(obs, 0, sizeof(float) * POLICY_OBS_DIM);

    // base_ang_vel and projected_gravity are the `--imu fixed` case: still,
    // and gravity straight down the root frame's -Z. The policy then has no
    // way to notice the hand tipping, so this rehearses a gait, it does not
    // balance. Reading the AtomS3's own IMU here would need the mounting
    // rotation measured for THIS board, which it has not been.
    obs[POLICY_OBS_PROJECTED_GRAVITY_START + 2] = -1.0f;

    for (size_t i = 0; i < 3; i++) {
        obs[POLICY_OBS_COMMAND_START + i] = command_[i];
    }

    // A standing command stops the gait clock rather than letting it run
    // under a policy that expects it stopped -- the same branch training
    // takes (see the task's observations.py).
    const float speed = sqrtf(command_[0] * command_[0] +
                              command_[1] * command_[1] +
                              command_[2] * command_[2]);
    if (speed >= POLICY_PHASE_STAND_THRESHOLD) {
        const float period = POLICY_PHASE_PERIOD_S;
        const float t = step_ / POLICY_CONTROL_HZ;
        const float frac = fmodf(t, period) / period;
        obs[POLICY_OBS_PHASE_START] = sinf(frac * 2.0f * (float)M_PI);
        obs[POLICY_OBS_PHASE_START + 1] = cosf(frac * 2.0f * (float)M_PI);
    }

    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
        // Relative to the default pose; the default joint VELOCITY is zero,
        // so joint_vel goes through untouched.
        obs[POLICY_OBS_JOINT_POS_START + i] = joint_pos_[i] - kPolicyHomeRad[i];
        obs[POLICY_OBS_JOINT_VEL_START + i] = joint_vel_[i];
        obs[POLICY_OBS_ACTIONS_START + i] = last_action_[i];
    }
}

bool PolicyMode::step() {
    // Only the 19 servos the policy drives, one 2 byte read each. Pulling
    // the whole 630 byte table instead costs 37 ms against 20 -- the board
    // answers at about 54 us per byte, so bytes are what the budget is spent
    // on, not round trips. Measured; see src/bench.cpp.
    uint16_t pulses[POLICY_ACT_DIM];
    if (!link_.readServoPulsesFor(g_sorted_ids, pulses, POLICY_ACT_DIM)) {
        consecutive_errors_++;
        total_errors_++;
        return false;
    }
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
        const float deg = (pulses[i] - Rcb4Link::PULSE_NEUTRAL) /
                          Rcb4Link::DEG_TO_PULSE;
        joint_pos_[g_sorted_to_joint[i]] = deg * kDegToRad;
    }

    // joint_vel over the fixed window, differenced against the oldest sample
    // held. Early steps difference over whatever history exists rather than
    // against a zero, so the first estimates are noisier but never wrong by a
    // factor.
    const size_t capacity = VEL_STEPS + 1;
    memcpy(pos_history_[history_head_], joint_pos_, sizeof(joint_pos_));
    history_head_ = (history_head_ + 1) % capacity;
    if (history_len_ < capacity) history_len_++;
    const size_t oldest =
            (history_head_ + capacity - history_len_) % capacity;
    const size_t span = history_len_ - 1;
    if (span > 0) {
        const float window = span / POLICY_CONTROL_HZ;
        for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
            joint_vel_[i] = (joint_pos_[i] - pos_history_[oldest][i]) / window;
        }
    } else {
        memset(joint_vel_, 0, sizeof(joint_vel_));
    }

    float obs[POLICY_OBS_DIM];
    float action[POLICY_ACT_DIM];
    buildObs(obs);
    policy::run(obs, action);

    float target[POLICY_ACT_DIM];
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
        target[i] = kPolicyHomeRad[i] + POLICY_ACTION_SCALE * action[i];
    }

    if (state_ == State::HOLDING) {
        // The network keeps running -- so its `actions` observation stays its
        // own output and resuming does not feed it a gap -- but its target is
        // discarded for a ramp back to the home pose.
        hold_step_++;
        const float k = fminf(1.0f, static_cast<float>(hold_step_) / hold_steps_);
        for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
            target[i] = hold_from_[i] + k * (kPolicyHomeRad[i] - hold_from_[i]);
        }
    }

    uint16_t out[POLICY_ACT_DIM];
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
        const size_t joint = g_sorted_to_joint[i];
        const float clipped = clampf(target[joint], kPolicyJointLowRad[joint],
                                     kPolicyJointHighRad[joint]);
        const float pulse = clipped * kRadToDeg * Rcb4Link::DEG_TO_PULSE +
                            Rcb4Link::PULSE_NEUTRAL;
        out[i] = static_cast<uint16_t>(clampf(pulse, 3500.0f, 11500.0f));
    }
    if (!link_.writeServoPulses(g_sorted_ids, out, POLICY_ACT_DIM,
                                POLICY_SERVO_FRAME_COUNT)) {
        consecutive_errors_++;
        total_errors_++;
        return false;
    }

    float worst = 0.0f;
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
        worst = fmaxf(worst, fabsf(joint_pos_[i] - kPolicyHomeRad[i]));
    }
    pose_error_milli_ = static_cast<int16_t>(clampf(worst * 1000.0f, 0.0f,
                                                    32767.0f));

    memcpy(last_target_, target, sizeof(target));
    memcpy(last_action_, action, sizeof(action));
    step_++;
    return true;
}

void PolicyMode::onClick() {
    // Pressing the button means a person is standing at the robot, so local
    // control takes over: the host-silence failsafe stops applying until a
    // host speaks again. Otherwise one earlier host session would leave the
    // button dead for good, three seconds at a time.
    host_spoke_ = false;
    // Servos on and off. On means the stance, held -- not walking; see the
    // header for why this gesture in particular must not start motion.
    request_ = (state_ == State::IDLE || state_ == State::FAULT)
                       ? Request::HOLD
                       : Request::FREE;
    if (state_ == State::FAULT) {
        // A fault does not clear itself, but a person pressing the button IS
        // the operator looking at it, which is the condition the latch was
        // waiting for.
        consecutive_errors_ = 0;
        setState(State::IDLE);
    }
}

void PolicyMode::onDoubleClick() {
    host_spoke_ = false;
    request_ = (state_ == State::RUNNING) ? Request::HOLD : Request::RUN;
}

void PolicyMode::loop() {
    readHostFrame();

    const uint32_t now_ms = millis();
    // A host that never spoke cannot have gone quiet. Without this the
    // failsafe would undo every button press on the very next pass, and the
    // button is the whole point of being able to run with nothing attached.
    const uint32_t quiet = host_spoke_ ? now_ms - last_host_ms_ : 0;
    Request request = request_;
    if (quiet > HOST_FREE_MS) {
        request = Request::FREE;
    } else if (quiet > HOST_STAND_MS) {
        // Not a stop: the gait clock stops because the command is zero, which
        // is the same thing a present host asking to stand would produce.
        command_[0] = command_[1] = command_[2] = 0.0f;
    }

    if (state_ != State::FAULT) {
        switch (request) {
            case Request::FREE:
                if (state_ != State::IDLE) {
                    freeServos();
                    setState(State::IDLE);
                }
                break;
            case Request::RUN:
                if (state_ == State::IDLE) {
                    if (!beginHoming(State::RUNNING)) {
                        total_errors_++;
                        consecutive_errors_++;
                    }
                } else if (state_ == State::HOMING) {
                    after_homing_ = State::RUNNING;
                    if (static_cast<int32_t>(now_ms - homing_until_ms_) >= 0 &&
                        homingArrived()) {
                        next_step_us_ = micros();
                        beginAfterHoming();
                    }
                } else {
                    setState(State::RUNNING);
                }
                break;
            case Request::HOLD:
                if (state_ == State::IDLE) {
                    // Nothing has been driven yet, so there is no pose to
                    // hold; get to the stance first.
                    if (!beginHoming(State::HOLDING)) {
                        total_errors_++;
                        consecutive_errors_++;
                    }
                } else if (state_ == State::HOMING) {
                    // Already on the way to home, which is where HOLD goes.
                    after_homing_ = State::HOLDING;
                    if (static_cast<int32_t>(now_ms - homing_until_ms_) >= 0 &&
                        homingArrived()) {
                        next_step_us_ = micros();
                        beginAfterHoming();
                    }
                    break;
                } else if (state_ != State::HOLDING) {
                    memcpy(hold_from_, last_target_, sizeof(hold_from_));
                    float span = 0.0f;
                    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
                        span = fmaxf(span, fabsf(kPolicyHomeRad[i] - hold_from_[i]));
                    }
                    hold_steps_ = static_cast<uint32_t>(
                            ceilf(span / (HOLD_MAX_RATE / POLICY_CONTROL_HZ)));
                    if (hold_steps_ < 1) hold_steps_ = 1;
                    hold_step_ = 0;
                    setState(State::HOLDING);
                }
                break;
        }
    }

    if (state_ == State::HOMING || state_ == State::IDLE ||
        state_ == State::FAULT) {
        // Nothing is being driven, or the board is moving under its own
        // interpolation. Either way there is only the telemetry to keep up.
        if (now_ms - last_draw_ms_ > DRAW_INTERVAL_MS) {
            last_draw_ms_ = now_ms;
            sendTelemetry();
        }
        return;
    }

    // The loop is paced on a fixed grid rather than by sleeping a fixed
    // amount, so a step that runs long does not push every step after it.
    const uint32_t period_us =
            static_cast<uint32_t>(1000000.0f / POLICY_CONTROL_HZ);
    const int32_t wait = static_cast<int32_t>(next_step_us_ - micros());
    if (wait > 0) return;
    if (wait < -static_cast<int32_t>(period_us)) {
        overruns_++;
        next_step_us_ = micros();  // fell behind; restart the grid
    }
    next_step_us_ += period_us;

    const uint32_t t0 = micros();
    const bool ok = step();
    loop_us_ = micros() - t0;
    if (!ok) {
        // Two failures in a row is a board that has stopped answering rather
        // than one that was busy -- and each of those two already spent four
        // retries per servo inside readServoPulsesFor. Freeing is the only
        // safe thing left, and it does not clear itself: something is wrong
        // with the hardware and an operator should look at it.
        if (consecutive_errors_ >= 2) {
            freeServos();
            setState(State::FAULT);
        }
    } else {
        consecutive_errors_ = 0;
    }

    sendTelemetry();
}
