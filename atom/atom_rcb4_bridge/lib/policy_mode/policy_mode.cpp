#include "policy_mode.h"

#include <M5Unified.h>
#include <math.h>
#include <net.h>
#include <string.h>

namespace {

/// How the AtomS3's IMU sits on this robot, measured with
/// tools/imu_calibrate.py on the host and copied here:
///
///   root_x =  imu_y      (fingers pointed down: AtomS3 -Y reads up)
///   root_y = -imu_x
///   root_z =  imu_z      (palm down flat: AtomS3 +Z reads up)
///
/// Not the KondoH7's rotation, which was sign flips only. Row major,
/// v_root = kImuToRoot @ v_imu.
const float kImuToRoot[9] = {0.0f, 1.0f, 0.0f,
                             -1.0f, 0.0f, 0.0f,
                             0.0f, 0.0f, 1.0f};

/// Gyro zero, in the IMU frame, rad/s. Measured still over 380 samples; one
/// axis drifts 0.32 rad/s, which is 18 deg/s and the size of the noise the
/// policies were trained against, so leaving it in would tell them the hand
/// is turning whenever it is not.
const float kGyroBias[3] = {-0.191637f, -0.323070f, 0.141785f};

/// How fast a joint may be asked to travel during a ramp, rad/s. Measured on
/// this hand: a 92 deg move commanded over 2 s landed 16 deg short and needed
/// a second command. A ramp that respects the servo's own speed arrives once.
constexpr float RAMP_MAX_RATE = 1.2f;

void matVec3(const float* m, const float* v, float* out) {
    for (int r = 0; r < 3; r++) {
        out[r] = m[r * 3] * v[0] + m[r * 3 + 1] * v[1] + m[r * 3 + 2] * v[2];
    }
}

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
        while (j > 0 && policy::servoIds()[g_sorted_to_joint[j - 1]] >
                                policy::servoIds()[key]) {
            g_sorted_to_joint[j] = g_sorted_to_joint[j - 1];
            j--;
        }
        g_sorted_to_joint[j] = key;
    }
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
        g_sorted_ids[i] = policy::servoIds()[g_sorted_to_joint[i]];
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
    memcpy(last_target_, policy::homeRad(), sizeof(last_target_));
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
    sequence_ = nullptr;
    pending_transition_ = Request::FREE;
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
        memcpy(hold_from_, policy::homeRad(), sizeof(hold_from_));
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
        worst = fmaxf(worst, fabsf(rad - policy::homeRad()[g_sorted_to_joint[i]]));
    }
    return worst;
}

bool PolicyMode::sendHome() {
    uint16_t out[POLICY_ACT_DIM];
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
        const size_t joint = g_sorted_to_joint[i];
        const float pulse = policy::homeRad()[joint] * kRadToDeg *
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
    memcpy(last_target_, policy::homeRad(), sizeof(last_target_));
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
    // Bit 7 selects the attitude source; the low bits are the request.
    use_imu_ = (buf[1] & 0x80) == 0;
    request_ = static_cast<Request>(buf[1] & 0x7F);
    for (size_t axis = 0; axis < 3; axis++) {
        const int16_t raw = static_cast<int16_t>(
                static_cast<uint16_t>(buf[2 + axis * 2]) |
                (static_cast<uint16_t>(buf[3 + axis * 2]) << 8));
        command_[axis] = raw * VELOCITY_SCALE;
    }
    // Clamp to what the actor was trained on, not to what the operator's
    // stick can reach. Outside that band the policy is extrapolating and
    // nothing in the observation tells it so -- it just produces a target for
    // a speed it never had to achieve. The two are not close: this hand's
    // stick spans +-0.5 m/s against a policy trained on +-0.156.
    command_[0] = clampf(command_[0], policy::commandVxMin(),
                         policy::commandVxMax());
    command_[1] = 0.0f;  // vy was never commanded during training
    command_[2] = clampf(command_[2], -policy::commandWzMax(),
                         policy::commandWzMax());
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
    frame[3] = actor_;
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
    debug.actor = actor_ | (use_imu_ ? 0x00 : 0x80);
    debug.sequence_step = sequence_ == nullptr
                                  ? 0xFF
                                  : static_cast<uint8_t>(sequence_at_);
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

    // Attitude, from the IMU bolted to the same board this runs on. The
    // mounting rotation was measured on this robot (see kImuToRoot); before
    // it was, this fed each policy its own stance value as a constant, which
    // is fine for walking at a fixed attitude and useless for a transition --
    // rise and sit rotate the hand 20 deg and moving projected_gravity by
    // 0.35, against the +-0.05 of noise they were trained with.
    float gravity_root[3];
    float ang_vel_gyro[3];
    readAttitude(gravity_root, ang_vel_gyro);
    for (size_t i = 0; i < 3; i++) {
        obs[POLICY_OBS_PROJECTED_GRAVITY_START + i] = gravity_root[i];
        obs[POLICY_OBS_BASE_ANG_VEL_START + i] = ang_vel_gyro[i];
    }

    for (size_t i = 0; i < 3; i++) {
        obs[POLICY_OBS_COMMAND_START + i] = command_[i];
    }

    // A standing command stops the gait clock rather than letting it run
    // under a policy that expects it stopped -- the same branch training
    // takes (see the task's observations.py).
    const float speed = sqrtf(command_[0] * command_[0] +
                              command_[1] * command_[1] +
                              command_[2] * command_[2]);
    if (speed >= policy::phaseStandThreshold()) {
        const float period = policy::phasePeriodS();
        const float t = step_ / POLICY_CONTROL_HZ;
        const float frac = fmodf(t, period) / period;
        obs[POLICY_OBS_PHASE_START] = sinf(frac * 2.0f * (float)M_PI);
        obs[POLICY_OBS_PHASE_START + 1] = cosf(frac * 2.0f * (float)M_PI);
    }

    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
        // Relative to the default pose; the default joint VELOCITY is zero,
        // so joint_vel goes through untouched.
        obs[POLICY_OBS_JOINT_POS_START + i] = joint_pos_[i] - policy::homeRad()[i];
        obs[POLICY_OBS_JOINT_VEL_START + i] = joint_vel_[i];
        obs[POLICY_OBS_ACTIONS_START + i] = last_action_[i];
    }
}

void PolicyMode::readAttitude(float* gravity_root, float* ang_vel_gyro) const {
    m5::imu_data_t data = {};
    const bool live = use_imu_ && M5.Imu.isEnabled();
    if (live) {
        M5.Imu.update();
        data = M5.Imu.getImuData();
    }
    const float mag = sqrtf(data.accel.x * data.accel.x +
                            data.accel.y * data.accel.y +
                            data.accel.z * data.accel.z);
    if (!live || mag < 0.1f) {
        // No IMU, or a reading that cannot be a gravity vector. Fall back to
        // the policy's own stance rather than to zeros: a zero gravity is not
        // a pose, and the actor would be asked about one that cannot exist.
        const float* stance = policy::stanceGravity();
        for (int i = 0; i < 3; i++) {
            gravity_root[i] = stance[i];
            ang_vel_gyro[i] = 0.0f;
        }
        return;
    }
    // At rest the accelerometer measures specific force, which points up; the
    // gravity DIRECTION is its negation.
    const float g_imu[3] = {-data.accel.x / mag, -data.accel.y / mag,
                            -data.accel.z / mag};
    matVec3(kImuToRoot, g_imu, gravity_root);

    constexpr float kDegToRad = 0.017453292519943295f;
    const float w_imu[3] = {data.gyro.x * kDegToRad - kGyroBias[0],
                            data.gyro.y * kDegToRad - kGyroBias[1],
                            data.gyro.z * kDegToRad - kGyroBias[2]};
    float w_root[3];
    matVec3(kImuToRoot, w_imu, w_root);
    matVec3(policy::rootToGyro(), w_root, ang_vel_gyro);
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
        target[i] = policy::homeRad()[i] + policy::actionScale() * action[i];
    }

    if (state_ == State::HOLDING) {
        // The network keeps running -- so its `actions` observation stays its
        // own output and resuming does not feed it a gap -- but its target is
        // discarded for a ramp back to the home pose.
        hold_step_++;
        const float k = fminf(1.0f, static_cast<float>(hold_step_) / hold_steps_);
        for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
            target[i] = hold_from_[i] + k * (policy::homeRad()[i] - hold_from_[i]);
        }
    }

    if (!writeJointTargets(target)) {
        consecutive_errors_++;
        total_errors_++;
        return false;
    }

    float worst = 0.0f;
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
        worst = fmaxf(worst, fabsf(joint_pos_[i] - policy::homeRad()[i]));
    }
    pose_error_milli_ = static_cast<int16_t>(clampf(worst * 1000.0f, 0.0f,
                                                    32767.0f));

    memcpy(last_target_, target, sizeof(target));
    memcpy(last_action_, action, sizeof(action));
    step_++;
    return true;
}

const PolicyMode::Step PolicyMode::kRiseSequence[3] = {
        {Step::Kind::RAMP, PolicyMode::OMNI, 0.5f},
        {Step::Kind::RUN, PolicyMode::RISE_A, 3.0f},
        // Then across to the walking policy's own stance. This step is not
        // decoration: beginActor() swaps weights without moving anything, and
        // crawl's home is 81 degrees away from the stance rise leaves the hand
        // in -- every other actor here shares one home, crawl does not. Landing
        // on it directly would start it from a pose it was never trained near.
        {Step::Kind::RAMP, PolicyMode::CRAWL, 2.0f},
        // No ramp between here and legs_walk. See the header.
};

const PolicyMode::Step PolicyMode::kSitSequence[3] = {
        {Step::Kind::RAMP, PolicyMode::LEGS, 1.0f},
        {Step::Kind::RUN, PolicyMode::SIT_A, 2.0f},
        {Step::Kind::RAMP, PolicyMode::OMNI, 0.5f},
};

bool PolicyMode::writeJointTargets(const float* target) {
    uint16_t out[POLICY_ACT_DIM];
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
        const size_t joint = g_sorted_to_joint[i];
        const float clipped = clampf(target[joint], policy::jointLowRad()[joint],
                                     policy::jointHighRad()[joint]);
        const float pulse = clipped * kRadToDeg * Rcb4Link::DEG_TO_PULSE +
                            Rcb4Link::PULSE_NEUTRAL;
        out[i] = static_cast<uint16_t>(clampf(pulse, 3500.0f, 11500.0f));
    }
    return link_.writeServoPulses(g_sorted_ids, out, POLICY_ACT_DIM,
                                  POLICY_SERVO_FRAME_COUNT);
}

void PolicyMode::beginActor(uint8_t actor) {
    actor_ = actor;
    policy::select(actor);
    // Every one of these was trained to start from a stopped gait clock and
    // no action history. Carrying either across a switch feeds the new actor
    // a state it never saw.
    step_ = 0;
    history_len_ = 0;
    history_head_ = 0;
    memset(last_action_, 0, sizeof(last_action_));
    next_step_us_ = micros();
}

void PolicyMode::beginRamp(const float* target, float seconds) {
    uint16_t pulses[POLICY_ACT_DIM];
    if (link_.readServoPulsesFor(g_sorted_ids, pulses, POLICY_ACT_DIM)) {
        for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
            const float deg = (pulses[i] - Rcb4Link::PULSE_NEUTRAL) /
                              Rcb4Link::DEG_TO_PULSE;
            ramp_from_[g_sorted_to_joint[i]] = deg * kDegToRad;
        }
    } else {
        memcpy(ramp_from_, last_target_, sizeof(ramp_from_));
    }
    float span = 0.0f;
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
        ramp_to_[i] = target[i];
        span = fmaxf(span, fabsf(target[i] - ramp_from_[i]));
    }
    const float needed = span / RAMP_MAX_RATE;
    if (needed > seconds) seconds = needed;
    ramp_start_ms_ = millis();
    ramp_ms_ = static_cast<uint32_t>(seconds * 1000.0f);
    if (ramp_ms_ < 1) ramp_ms_ = 1;
}

bool PolicyMode::stepRamp() {
    const uint32_t elapsed = millis() - ramp_start_ms_;
    const float k = elapsed >= ramp_ms_
                            ? 1.0f
                            : static_cast<float>(elapsed) / ramp_ms_;
    // Cosine, not linear: a linear ramp starts and stops with a step in
    // velocity, and snapping the hand about is what made the palm bounce.
    const float blend = 0.5f * (1.0f - cosf((float)M_PI * k));
    float target[POLICY_ACT_DIM];
    for (size_t i = 0; i < POLICY_ACT_DIM; i++) {
        target[i] = ramp_from_[i] + blend * (ramp_to_[i] - ramp_from_[i]);
    }
    writeJointTargets(target);
    memcpy(last_target_, target, sizeof(target));
    return elapsed >= ramp_ms_;
}

bool PolicyMode::beginSequence(const Step* steps, size_t count,
                               uint8_t ends_as) {
    if (sequence_ != nullptr) return false;
    sequence_ = steps;
    sequence_len_ = count;
    sequence_at_ = 0;
    sequence_ends_as_ = ends_as;
    const Step& first = steps[0];
    if (first.kind == Step::Kind::RAMP) {
        beginRamp(policy::homeRadOf(first.actor), first.seconds);
    } else {
        beginActor(first.actor);
        sequence_step_until_ms_ =
                millis() + static_cast<uint32_t>(first.seconds * 1000.0f);
    }
    setState(State::SEQUENCE);
    return true;
}

bool PolicyMode::stepSequence() {
    const Step& current = sequence_[sequence_at_];
    bool done = false;
    if (current.kind == Step::Kind::RAMP) {
        done = stepRamp();
    } else {
        step();  // one control step of the transition actor
        done = static_cast<int32_t>(millis() - sequence_step_until_ms_) >= 0;
    }
    if (!done) return true;

    sequence_at_++;
    if (sequence_at_ >= sequence_len_) {
        sequence_ = nullptr;
        beginActor(sequence_ends_as_);
        return false;
    }
    const Step& next = sequence_[sequence_at_];
    if (next.kind == Step::Kind::RAMP) {
        beginRamp(policy::homeRadOf(next.actor), next.seconds);
    } else {
        beginActor(next.actor);
        sequence_step_until_ms_ =
                millis() + static_cast<uint32_t>(next.seconds * 1000.0f);
    }
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

    // A running transition owns the hand. Only FREE gets through -- it is the
    // one request that must always work -- and everything else is ignored
    // until the script finishes.
    //
    // Without this, RUN's `else setState(RUNNING)` yanked the state out of
    // SEQUENCE part-way: the hand kept whichever transition actor was loaded
    // (sit, whose command range is [0, 0], so nothing moved), and `sequence_`
    // stayed non-null, which made every later rise or sit refuse to start.
    // A transition is started by ASKING, not by continuing to ask: the host
    // repeats its command ten times a second. What counts as an ask is a
    // change in the RAW request, tracked before anything below rewrites it.
    // Tracking the rewritten value instead made the mask below look like a
    // change every time a sequence ended, so a held `rise` restarted itself
    // forever and nothing else could get a word in.
    if (request != last_seen_request_) {
        last_seen_request_ = request;
        if (request == Request::RISE || request == Request::SIT) {
            pending_transition_ = request;
        } else if (request == Request::FREE) {
            // Only FREE cancels a transition that has not started yet. RUN and
            // HOLD deliberately do not: the web page sends `rise` for 400 ms
            // and then returns to RUN, the way releasing a button does, and a
            // transition asked for while the hand is still homing has seconds
            // to wait -- so treating that return as a cancellation threw away
            // exactly the ask this holding is here to keep. FREE is the one
            // request that always means stop.
            pending_transition_ = Request::FREE;
        }
    }

    // A running transition owns the hand. Only FREE gets through -- it is the
    // one request that must always work -- and everything else waits.
    //
    // Without this, RUN's `else setState(RUNNING)` yanked the state out of
    // SEQUENCE part-way: the hand kept whichever transition actor was loaded
    // (sit, whose command range is [0, 0], so nothing moved), and `sequence_`
    // stayed non-null, which made every later rise or sit refuse to start.
    if (state_ == State::SEQUENCE && request != Request::FREE) {
        request = static_cast<Request>(0xFF);  // matches no case
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
            case Request::RISE:
            case Request::SIT:
                // The transition itself is started below, once the hand is in
                // a state that can take one. All that is needed here is to get
                // it into one: from IDLE the servos are free and there is no
                // pose to transition from, so go to the stance first, exactly
                // as `hold` does. Without this the key was simply dead until
                // something else had been pressed.
                if (state_ == State::IDLE) {
                    if (!beginHoming(State::HOLDING)) {
                        total_errors_++;
                        consecutive_errors_++;
                    }
                } else if (state_ == State::HOMING) {
                    after_homing_ = State::HOLDING;
                    if (static_cast<int32_t>(now_ms - homing_until_ms_) >= 0 &&
                        homingArrived()) {
                        next_step_us_ = micros();
                        beginAfterHoming();
                    }
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
                        span = fmaxf(span, fabsf(policy::homeRad()[i] - hold_from_[i]));
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

    // A held transition starts as soon as the hand can take one: after the
    // homing that `run` and `hold` begin with, or after a sequence already
    // under way. Asking during either used to be silently forgotten.
    if (pending_transition_ != Request::FREE &&
        (state_ == State::RUNNING || state_ == State::HOLDING)) {
        const bool rise = pending_transition_ == Request::RISE;
        if (beginSequence(rise ? kRiseSequence : kSitSequence,
                          rise ? sizeof(kRiseSequence) / sizeof(Step)
                               : sizeof(kSitSequence) / sizeof(Step),
                          // Walking is crawl, the policy from the earlier
                          // walking hand -- the machine turned out to be the
                          // same one, and that is the policy that has actually
                          // walked on it. legs, from the wheeled set, cannot
                          // turn (wz_max 0) and cannot stop (vx_min 0.125).
                          rise ? CRAWL : OMNI)) {
            pending_transition_ = Request::FREE;
        }
    }

    if (state_ == State::SEQUENCE) {
        // The sequence owns the hand. It is paced on the same grid as the
        // control loop, because one of its steps IS the control loop.
        const uint32_t period_us =
                static_cast<uint32_t>(1000000.0f / POLICY_CONTROL_HZ);
        if (static_cast<int32_t>(next_step_us_ - micros()) > 0) return;
        next_step_us_ += period_us;
        if (!stepSequence()) {
            setState(State::RUNNING);
        }
        sendTelemetry();
        return;
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
