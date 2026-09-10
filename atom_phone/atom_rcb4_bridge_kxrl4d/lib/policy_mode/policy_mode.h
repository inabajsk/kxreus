#ifndef POLICY_MODE_H
#define POLICY_MODE_H

#include <mode.h>
#include <net.h>
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
        /// Servos free, policy not running. Entered on arrival, on an
        /// explicit FREE request, and on any board error. NOT entered just
        /// because the host went quiet -- see HOST_HOLD_MS -- so losing the
        /// phone link mid-stride ramps to the home stance and holds it
        /// rather than dropping the robot.
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
        /// Part-way through a rise or a sit. The sequence owns the hand until
        /// it finishes or the host asks to stop.
        SEQUENCE = 5,
        /// The RCB-4's own program counter is off running one of its 120
        /// onboard motion-table slots (see Rcb4Link::callMotion) -- NOT
        /// this policy. Nothing here writes a servo target in this state:
        /// the two sources would be fighting over the same servos. Left
        /// only by RUN or HOLD, both of which re-home first (see the
        /// switch on Request::RUN/HOLD in loop()) because the motion could
        /// have put the robot anywhere, not just wherever writeJointTargets()
        /// last thought it was.
        MOTION = 6,
    };

    /// What the host asks for in the `mode` byte of its frame.
    enum class Request : uint8_t {
        FREE = 0,
        RUN = 1,
        HOLD = 2,
        /// Wheels to fingertips, and back. Each runs a fixed sequence of
        /// ramps and actors; see kRiseSequence.
        RISE = 3,
        SIT = 4,
        /// Jump to one of the RCB-4's own onboard motion-table slots. Which
        /// one travels in the frame's vx field (see acceptHostFrame) rather
        /// than adding a tenth byte to a protocol everything else already
        /// parses as fixed-size.
        MOTION = 5,
    };

    /// The actors compiled in, in the order lib/policy lists them.
    ///
    /// This build is for kxrl4d (Kondo KXR-L4D, a 19-DOF legged biped) --
    /// not the walking hand the rest of this mode's comments describe. It
    /// has its own two actors, sharing one home pose (see docs/policies.md
    /// item 2: a shared home is what lets a transition RUN straight into the
    /// other actor with no RAMP in between).
    enum Actor : uint8_t {
        WALK = 0,
        GETUP = 1,
    };

private:
    /// The host is a joystick, and a joystick that has been unplugged should
    /// not leave the hand walking. Silence past the first threshold zeroes the
    /// command, which stops the gait clock exactly as a zero command from a
    /// present host would; silence past the second asks for HOLD -- ramps to
    /// the home stance and keeps the servos there -- rather than freeing
    /// them. A dropped phone link (a locked screen stops its own JS timers;
    /// a Wi-Fi hop drops the UDP path) is not a request to collapse, and a
    /// robot left FREE mid-stride falls over. Reaching FREE from here still
    /// takes an explicit request -- the physical button, or the page's own
    /// "free" mode -- same as it always did.
    ///
    /// Only once a host has spoken at least once, though. A host that was
    /// never there cannot have gone away, and treating its absence as a
    /// failure would make the button useless -- every press undone on the
    /// next pass.
    static constexpr uint32_t HOST_STAND_MS = 500;
    static constexpr uint32_t HOST_HOLD_MS = 3000;

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

    // ---------------------------------------------------------------
    // Rise and sit
    //
    // A transition is a short fixed script, not a mode the operator drives:
    // ramp into the stance the transition actor was trained to start from,
    // run that actor for a couple of seconds, then hand over. The steps and
    // their durations are the ones sim completed laps of (DEPLOY.md section
    // 5), including two asymmetries that were not free:
    //
    //   rise -> legs_walk goes straight across with NO ramp. Rise ends about
    //   0.7 rad rms from the fingertip stance and legs_walk pulls it in
    //   within half a second, while ramping to home first collapsed part-way.
    //
    //   everything else ramps. Snapping from finger walking to a home pose
    //   made the palm bounce and the hand fall.
    // ---------------------------------------------------------------

    /// One step of a transition: either ease the joints somewhere, or run an
    /// actor for a while.
    struct Step {
        enum class Kind : uint8_t { RAMP, RUN } kind;
        uint8_t actor;      ///< RUN: which actor. RAMP: whose home pose.
        float seconds;      ///< RUN: how long. RAMP: the minimum time.
    };

    /// The two scripts. kxrl4d's getup and walk actors share one home pose
    /// (measured once, in robot/mjcf/kxrl4d/home.json on the training side),
    /// so neither needs a RAMP step to reach the other's starting stance --
    /// unlike the walking hand's crawl, which sits 81 deg from the wheeled
    /// set's shared home.
    static const Step kRiseSequence[1];
    static const Step kSitSequence[1];

    /// Start a scripted transition. Returns false if one is already running.
    bool beginSequence(const Step* steps, size_t count, uint8_t ends_as);

    /// Advance the current sequence. Returns false when it has finished.
    bool stepSequence();

    /// Ease every joint from where it is to `target` over at least `seconds`.
    ///
    /// The time is a floor: a servo has its own speed limit and simply
    /// arrives short of anything quicker, so the ramp takes whichever is
    /// longer, what was asked or what the furthest joint needs.
    /// Clip to the joint limits and send one position command.
    bool writeJointTargets(const float* target);

    void beginRamp(const float* target, float seconds);
    bool stepRamp();

    /// Load an actor and start it from a clean slate: gait clock at zero and
    /// no action history, which is the state each was trained to begin from.
    void beginActor(uint8_t actor);

    /// Set joint_pos_ to home for every joint with no real servo id, so
    /// buildObs() reports them sitting still at home rather than at whatever
    /// they last happened to hold (0 at startup). See kNoServo in the .cpp.
    void pinUnwiredJoints();

    /// Send the RCB-4 off to run one of its own onboard motions and stop
    /// driving servos for as long as it might still be running -- see
    /// State::MOTION.
    void beginMotion(uint8_t number);

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

    /// Read the IMU into the two frames the observation wants: gravity in
    /// root, angular velocity in the URDF base link frame.
    ///
    /// Honours `use_imu_`. Holding the attitude at the policy's own stance
    /// instead is not a fallback but a comparison: the wheeled policy was
    /// first driven from a host that had no IMU at all, so it saw a perfect
    /// constant gravity and a zero angular velocity, and it worked. Feeding
    /// the real thing adds a bias of about 10 deg AND closes a loop that did
    /// not exist before -- the hand shakes, the gyro sees it, the policy
    /// answers. Being able to switch at runtime is what separates those two
    /// changes, which were made at the same time.
    void readAttitude(float* gravity_root, float* ang_vel_gyro) const;
    bool step();
    void freeServos();

    Rcb4Link& link_;

    State state_ = State::IDLE;
    Request request_ = Request::FREE;

    float command_[3] = {0.0f, 0.0f, 0.0f};
    /// Which onboard motion-table slot Request::MOTION asks for, carried in
    /// the host frame's vx field (see acceptHostFrame) since it is never a
    /// velocity when the request is MOTION.
    uint8_t motion_number_ = 0;
    /// The slot beginMotion() was last actually called with, so a second,
    /// DIFFERENT motion asked for while still in Request::MOTION is its own
    /// edge to fire on -- last_seen_request_ alone does not change between
    /// two motion calls in a row, both are Request::MOTION. 0xFF is not a
    /// real slot (0..119), so the very first call always counts as new.
    uint8_t last_motion_number_ = 0xFF;
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

    /// Cached from buildObs()'s own readAttitude() call, so sendTelemetry()
    /// (called every tick, including every RUNNING/HOLDING control step) can
    /// publish attitude to the phone without a SECOND I2C transaction on top
    /// of the one buildObs() already paid for that same step -- real added
    /// control-loop latency for a value that is display-only. mutable
    /// because buildObs() is const. See sendTelemetry()'s own comment for
    /// the states where a fresh read is used instead.
    mutable float last_gravity_root_[3] = {0.0f, 0.0f, -1.0f};

    float joint_pos_[POLICY_ACT_DIM] = {0.0f};
    float joint_vel_[POLICY_ACT_DIM] = {0.0f};
    float last_action_[POLICY_ACT_DIM] = {0.0f};
    float last_target_[POLICY_ACT_DIM] = {0.0f};
    /// The pulse last read back for each REAL servo (sorted/servo order,
    /// same as g_sorted_ids -- NOT joint order, unlike the members above),
    /// cached from step()'s own read rather than read again: see
    /// sendTelemetry()'s own comment for why this is fresh only while
    /// RUNNING/HOLDING, the same reasoning last_gravity_root_ already
    /// relies on.
    uint16_t last_pulse_[POLICY_ACT_DIM] = {0};

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
    /// For edge-detecting a fresh CONNECTED in draw() -- see qr_until_ms_.
    net::Status last_net_status_ = net::Status::UNCONFIGURED;
    /// While in the future, draw() shows a QR of net::url() instead of the
    /// usual telemetry screen. Set for a while right after a fresh CONNECTED
    /// (joining a real Wi-Fi network from PROVISIONING or FAILED): typing an
    /// address by hand on a phone once it has to rejoin whatever network
    /// this robot just joined is exactly the friction a QR code exists to
    /// remove, and POLICY is the screen actually showing when that happens
    /// (see main.cpp's START_MODE_INDEX) -- switching to StatusMode's own QR
    /// view instead would mean leaving POLICY, and PolicyMode::exit() frees
    /// the servos (see its own comment), which is not a price this should
    /// ever cost. 0 means "not showing one".
    uint32_t qr_until_ms_ = 0;
    /// How long the last LCD repaint took. It happens on the control loop's
    /// core, so it is time the servos pay for -- and the only way to know
    /// whether that matters is to measure it rather than assume.
    uint32_t draw_us_ = 0;
    /// Host frames accepted, checksum and all. The one number that separates
    /// a quiet operator from a broken link.
    uint32_t host_frames_ = 0;

    const Step* sequence_ = nullptr;
    size_t sequence_len_ = 0;
    size_t sequence_at_ = 0;
    uint8_t sequence_ends_as_ = WALK;
    uint32_t sequence_step_until_ms_ = 0;

    float ramp_from_[POLICY_ACT_DIM] = {0.0f};
    float ramp_to_[POLICY_ACT_DIM] = {0.0f};
    uint32_t ramp_start_ms_ = 0;
    uint32_t ramp_ms_ = 0;

    /// Which actor is loaded. Selecting copies 200 KiB into SRAM, so it is
    /// done at a transition boundary and never inside a control step.
    ///
    /// WALK by default; GETUP is reached only through `rise`.
    uint8_t actor_ = WALK;

    /// Whether the observation carries the measured attitude or the loaded
    /// policy's stance constant. Host bit 0x80 of the request byte.
    ///
    /// The constant by default, because that is the configuration that has
    /// driven this robot: every successful run so far -- the crawl policy
    /// walking, the wheeled policy rolling -- was made from a host with no
    /// IMU, feeding a perfect stance gravity and a zero angular velocity.
    /// The measured attitude adds about 10 deg of bias AND closes a loop that
    /// did not exist before, where the hand shakes, the gyro sees it and the
    /// policy answers. It is worth having; it is not yet worth defaulting to.
    bool use_imu_ = false;

    /// The last raw request seen, so that a transition fires once per ask
    /// rather than once per frame -- the host repeats itself ten times a
    /// second.
    Request last_seen_request_ = Request::FREE;

    /// A transition that has been asked for but cannot start yet, because the
    /// hand is still homing or already in a sequence. Held rather than
    /// dropped: an ask that arrives a moment too early used to be recorded as
    /// seen and then never acted on, so pressing the key did nothing at all
    /// and pressing it again did nothing either.
    Request pending_transition_ = Request::FREE;
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
