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
    static constexpr uint32_t HOST_STAND_MS = 500;
    static constexpr uint32_t HOST_FREE_MS = 3000;

    /// Rate the home ramp may move a joint at, in rad/s, when holding.
    static constexpr float HOLD_MAX_RATE = 1.0f;

    /// How long to let the hand reach home before starting the policy.
    /// POLICY_HOME_FRAME_COUNT frames of 10 ms each, plus a margin for a
    /// joint that has to travel the furthest.
    static constexpr uint32_t HOMING_MS = POLICY_HOME_FRAME_COUNT * 10 + 500;

    /// Send the servos to the home stance and start the HOMING wait.
    bool beginHoming();

    /// Read the servos and return the worst distance from the home pose, in
    /// radians, or a negative number if the board did not answer.
    float measureHomeError();

    void setState(State state);
    void draw();
    bool readHostFrame();
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
    /// Host frames accepted, checksum and all. The one number that separates
    /// a quiet operator from a broken link.
    uint32_t host_frames_ = 0;
    uint32_t homing_until_ms_ = 0;
    /// Worst joint error against the home pose, in milliradians, latched at
    /// the moment homing finished. The one number that says whether the hand
    /// physically reached the stance the policy assumes it starts from -- and
    /// without it a hand that never moved looks exactly like one that did.
    int16_t home_error_milli_ = -1;
    /// The same error, live, every step.
    int16_t pose_error_milli_ = 0;
};

#endif  // POLICY_MODE_H
