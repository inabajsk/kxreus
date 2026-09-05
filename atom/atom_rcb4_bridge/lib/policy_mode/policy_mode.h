#ifndef POLICY_MODE_H
#define POLICY_MODE_H

#include <mode.h>
#include <policy.h>
#include <rcb4_link.h>

/// Runs the trained actor here, with the PC reduced to a joystick.
///
/// In BRIDGE mode the PC speaks RCB-4 and this only carries bytes. Here that
/// is inverted: this owns the board, and the PC sends nothing but the three
/// numbers of the velocity command. Everything else in the 68-wide
/// observation -- the gait phase, the joint positions and velocities, the
/// previous action -- is produced on this chip, because it either comes from
/// the board next door or from the policy's own last output.
///
/// The two modes must never both be live: each would be driving the same
/// UART. That is why this is a mode and not a feature of the bridge.
///
/// The host protocol, in both directions, is one fixed-size frame:
///
///     host -> device  [0xA5][request][vx][vy][wz][checksum]    9 bytes
///     device -> host  [0x5A][state][request][pad][step][loop_us]
///                     [overruns][errors][host_frames][peak][vx][wz]
///                                                             30 bytes
///
/// with the velocities as int16 in thousandths (so 0.35 m/s is 350). A frame
/// of literal bytes rather than text because it is read inside the control
/// loop, where parsing is time the servos pay for.
///
/// The device echoes back the request it last understood, the command it
/// decoded from it, and how many host frames it has accepted. That is not
/// decoration: without it an operator watching a screen that says IDLE has
/// no way to tell "the host is not asking me to run" from "nothing the host
/// sends is reaching me", and those need different fixes.
class PolicyMode : public Mode {
public:
    explicit PolicyMode(Rcb4Link& link) : link_(link) {}

    const char* name() const override { return "POLICY"; }
    void enter() override;
    void exit() override;
    void loop() override;

    /// Servos on and off: to the home stance and held, or released.
    ///
    /// "On" deliberately means HOLDING and not RUNNING. Someone standing at
    /// the robot pressing a button wants the hand in its stance, not walking
    /// -- and this is the one control that works with nothing attached but
    /// power, so it is the one that must not start it moving.
    void onClick() override;

    /// Start and stop the policy driving.
    void onDoubleClick() override;

    /// What the loop is doing, which is also what the LCD shows.
    enum class State : uint8_t {
        /// Servos free, policy not running. Entered on arrival, on a host
        /// that has gone quiet for too long, and on any board error.
        IDLE = 0,
        /// Policy running, servos driven.
        RUNNING = 1,
        /// Driving to the home stance, slowly, before the policy starts.
        ///
        /// Not optional. The action is an OFFSET from the home pose and the
        /// observation reports joint positions relative to it, so a policy
        /// started from a collapsed hand is being asked about a pose it was
        /// never trained on, and answers with a target the servos then chase
        /// in 60 ms. The host-side hand_deploy.py does the same thing before
        /// its loop ("moving to the home stance first").
        HOMING = 4,
        /// Policy still running -- so its `actions` observation stays its own
        /// output and resuming does not feed it a gap -- but the joint target
        /// is discarded and the hand is ramped back to the home pose.
        HOLDING = 2,
        /// The board stopped answering. Servos freed, and it does not restart
        /// on its own.
        FAULT = 3,
    };

    /// What the host asks for in the `mode` byte of its frame.
    enum class Request : uint8_t {
        FREE = 0,
        RUN = 1,
        HOLD = 2,
    };

private:
    /// The host is a joystick, and a joystick that has been unplugged should
    /// not leave the hand walking. Silence past the first threshold zeroes the
    /// command, which stops the gait clock exactly as a zero command from a
    /// present host would; silence past the second frees the servos.
    ///
    /// Only once a host has spoken at least once, though. A host that was
    /// never there cannot have gone away, and treating its absence as a
    /// failure would make the button useless -- every press undone on the
    /// next pass.
    static constexpr uint32_t HOST_STAND_MS = 500;
    static constexpr uint32_t HOST_FREE_MS = 3000;

    /// Rate the home ramp may move a joint at, in rad/s, when holding.
    static constexpr float HOLD_MAX_RATE = 1.0f;

    /// How long one attempt at reaching home is given.
    /// POLICY_HOME_FRAME_COUNT frames of 10 ms each, plus a margin.
    static constexpr uint32_t HOMING_MS = POLICY_HOME_FRAME_COUNT * 10 + 500;

    /// Close enough to the home stance to start the policy from, in radians.
    /// About 6 degrees; the servo reports to 0.3 and the host tool calls a
    /// home within 3.2 degrees good, so this is loose but not meaningless.
    static constexpr float HOME_TOLERANCE_RAD = 0.10f;

    /// How many times to re-send the home command before giving up on it.
    ///
    /// One interpolation is not always enough: the servo has its own speed
    /// limit and cannot honour a 500 ms request across a large angle, so a
    /// hand starting from collapsed arrives short. Measured: one attempt left
    /// 725 mrad of error where the policy's own hold ramp reached 31. Giving
    /// up is still the right end -- a thumb pressed against the floor never
    /// arrives, and calibration.yaml records that as contact, not a fault.
    static constexpr uint8_t HOMING_ATTEMPTS = 4;

    /// Send the home command once and (re)start the wait.
    bool sendHome();

    /// Send the servos to the home stance and start the HOMING wait.
    ///
    /// @param then  what to become when the hand has got there.
    bool beginHoming(State then);

    /// Decide whether homing is done: measure, retry if short and attempts
    /// remain, and latch the error either way.
    bool homingArrived();

    /// Leave HOMING for whatever it was on the way to, starting the gait
    /// clock from the stance rather than from wherever the hand had been.
    void beginAfterHoming();

    /// Read the servos and return the worst distance from the home pose, in
    /// radians, or a negative number if the board did not answer.
    float measureHomeError();

    void setState(State state);
    /// Paint the screen. Runs on core 0, from a task of its own.
    ///
    /// Repainting this panel was measured at 16.5 ms against a 33 ms control
    /// period, and it was happening four times a second on the control
    /// loop's own core, immediately after a step that already took up to 27.
    /// The loop's overrun counter did not catch it -- it only counts a step
    /// that is a whole period late -- so the cost showed up as movement
    /// rather than as a number. Everything it needs is in the telemetry
    /// snapshot the control loop already publishes, so nothing else had to
    /// change to move it.
    static void drawTask(void* arg);
    void draw();
    bool readHostFrame();
    /// Validate one 9 byte command frame and adopt it. Shared by both
    /// transports so they cannot drift apart.
    bool acceptHostFrame(const uint8_t* frame);
    void sendTelemetry();
    /// Assemble the observation the actor was trained on.
    void buildObs(float* obs) const;
    bool step();
    void freeServos();

    Rcb4Link& link_;

    State state_ = State::IDLE;
    Request request_ = Request::FREE;

    float command_[3] = {0.0f, 0.0f, 0.0f};
    uint32_t last_host_ms_ = 0;
    bool host_spoke_ = false;
    /// Which way the last command arrived, and so which way the answer goes.
    /// A browser is answered in the same pass it was read, so HTTP means
    /// "already answered" rather than "answer this way".
    enum class ReplyTo : uint8_t { USB, UDP, HTTP };
    ReplyTo reply_to_ = ReplyTo::USB;

    // The gait clock is driven by the STEP COUNT, not by wall time, exactly as
    // in training (episode_length_buf * step_dt). A late step then does not
    // shift the phase the policy sees.
    uint32_t step_ = 0;
    uint32_t next_step_us_ = 0;

    float joint_pos_[POLICY_ACT_DIM] = {0.0f};
    float joint_vel_[POLICY_ACT_DIM] = {0.0f};
    float last_action_[POLICY_ACT_DIM] = {0.0f};
    float last_target_[POLICY_ACT_DIM] = {0.0f};

    // joint_vel is a finite difference over a fixed WINDOW OF TIME, not over
    // one control step: the servo quantises its angle to about 0.3 deg, and a
    // one-step difference divides that quantum by dt. At 40 Hz that alone
    // would put a 0.27 rad/s noise floor on a still hand, against the
    // +-1.5 rad/s the actor was trained with.
    static constexpr size_t VEL_STEPS =
            static_cast<size_t>(POLICY_JOINT_VEL_WINDOW_S * POLICY_CONTROL_HZ +
                                0.5f) > 1
                    ? static_cast<size_t>(POLICY_JOINT_VEL_WINDOW_S *
                                          POLICY_CONTROL_HZ + 0.5f)
                    : 1;
    float pos_history_[VEL_STEPS + 1][POLICY_ACT_DIM] = {};
    size_t history_len_ = 0;
    size_t history_head_ = 0;

    uint32_t hold_step_ = 0;
    uint32_t hold_steps_ = 1;
    float hold_from_[POLICY_ACT_DIM] = {0.0f};

    uint32_t loop_us_ = 0;
    uint32_t overruns_ = 0;
    /// Failures in a row, which is what decides a fault -- the board declines
    /// a read while it is busy with its own servo cycle, so one failure is
    /// ordinary. Reset by any success.
    uint32_t consecutive_errors_ = 0;
    /// Failures since entering the mode, which is what the operator wants to
    /// see: a link failing one read in fifty never trips the fault above but
    /// is still worth knowing about.
    uint32_t total_errors_ = 0;
    uint32_t last_draw_ms_ = 0;
    TaskHandle_t draw_task_ = nullptr;
    /// How long the last LCD repaint took. It happens on the control loop's
    /// core, so it is time the servos pay for -- and the only way to know
    /// whether that matters is to measure it rather than assume.
    uint32_t draw_us_ = 0;
    /// Host frames accepted, checksum and all. The one number that separates
    /// a quiet operator from a broken link.
    uint32_t host_frames_ = 0;
    uint32_t homing_until_ms_ = 0;
    /// What to become once homing finishes. RUNNING when the policy was
    /// asked for, HOLDING when someone just wanted the hand in its stance.
    State after_homing_ = State::RUNNING;
    uint8_t homing_attempt_ = 0;
    /// Worst joint error against the home pose, in milliradians, latched at
    /// the moment homing finished. The one number that says whether the hand
    /// physically reached the stance the policy assumes it starts from -- and
    /// without it a hand that never moved looks exactly like one that did.
    int16_t home_error_milli_ = -1;
    /// The same error, live, every step.
    int16_t pose_error_milli_ = 0;
};

#endif  // POLICY_MODE_H
