#include "policy.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#include <Arduino.h>  // ESP.getFreeHeap(), for beginUpload()'s own budget check
#include <Preferences.h>

#include "policy_spec_kxrl4twalk.h"
#include "policy_spec_kxrl4dwalk.h"
#include "policy_spec_kxrl4dgetup.h"
#include "policy_spec_kxrl6walk.h"
#include "policy_spec_kxrl2gwalk.h"
#include "policy_weights_kxrl4twalk.h"
#include "policy_weights_kxrl4dwalk.h"
#include "policy_weights_kxrl4dgetup.h"
#include "policy_weights_kxrl6walk.h"
#include "policy_weights_kxrl2gwalk.h"

namespace {

// Ping-pong buffers sized to the widest layer of ANY of the four robots'
// own actors (POLICY_WIDEST_LAYER, see policy.h -- all four happen to
// share the same 256 today, confirmed against each one's own
// policy_spec_*.h rather than assumed). Static rather than on the stack:
// the control task's stack is not large, and there is only ever one
// forward pass in flight.
float g_a[POLICY_WIDEST_LAYER];
float g_b[POLICY_WIDEST_LAYER];

/// Everything that distinguishes one trained actor from another.
///
/// The weights themselves stay in flash -- there is room for many, and
/// kxr5s carries every one of kxrl4t/kxrl4d/kxrl6/kxrl2g's own trained
/// actors (five in all) this way, at no RAM cost. What there is not room
/// for is two of them in SRAM: the RAM budget holds one policy's largest
/// layers and nothing more. So a policy is SELECTED, and selecting copies
/// it in; only the active one is fast.
struct Actor {
    const char* name;
    const float* mean;
    const float* inv_std;
    const float* const* weights;
    const float* const* biases;
    const uint16_t* layer_in;
    const uint16_t* layer_out;
    size_t layers;
    const float* home_rad;
    const float* joint_low;
    const float* joint_high;
    const uint8_t* servo_ids;
    float action_scale;
    float phase_period_s;
    float phase_stand_threshold;
    float command_vx_min;
    float command_vx_max;
    float command_wz_max;
    float standing_fraction;
    const float* stance_gravity;
    const float* root_to_gyro;
    // See kxreus/rcb4robotconfig.l's own per-servo direction annotation
    // (next to each joint name there) -- hand-transcribed, same order as
    // servo_ids. Multiplied into a joint's own clamped target angle right
    // before the RCB-4 pulse conversion (see PolicyMode::
    // writeJointTargets()).
    const int8_t* servo_direction;

    // Only ever set for the "uploaded" actor (see finishUpload()) -- every
    // compiled-in actor below passes false/nullptr explicitly (this struct
    // stays a plain aggregate, no default member initializers, since this
    // toolchain's default C++ standard predates aggregates being allowed
    // to have those). weights/biases above are unused when this is true;
    // qweights/qbiases (same per-layer shape) are used instead, each entry
    // read back as `raw * scale[layer]` -- see policy.h's own
    // beginUpload() comment for why fixed-point at all.
    bool quantized;
    const int16_t* const* qweights;
    const int16_t* const* qbiases;
    const float* weight_scale;  // one per layer
    const float* bias_scale;    // one per layer
};

// =======================================================================
// kxrl4t (Kondo KXR-L4T, 10 DOF: 2-DOF legs + 2-DOF arms + 2-DOF head, all
// four limbs standing on their tips) -- one actor, no getup trained.
// =======================================================================

const float* const kKxrl4TWalkW[POLICY_KXRL4TWALK_LAYERS] = {
        kPolicyWKxrl4Twalk0, kPolicyWKxrl4Twalk1, kPolicyWKxrl4Twalk2,
        kPolicyWKxrl4Twalk3};
const float* const kKxrl4TWalkB[POLICY_KXRL4TWALK_LAYERS] = {
        kPolicyBKxrl4Twalk0, kPolicyBKxrl4Twalk1, kPolicyBKxrl4Twalk2,
        kPolicyBKxrl4Twalk3};

// See kxreus/rcb4robotconfig.l's own per-servo direction annotation (next
// to each joint name there) -- hand-transcribed, same order as
// kPolicyServoIdsKxrl4Twalk. Multiplied into a joint's own clamped target
// angle right before the RCB-4 pulse conversion (see PolicyMode::
// writeJointTargets()).
const int8_t kServoDirectionKxrl4Twalk[10] = {
    1, 1, -1, 1, -1, 1, -1, -1, -1, -1,
};

const Actor kKxrl4TActors[] = {
        {"walk", kPolicyObsMeanKxrl4Twalk, kPolicyObsInvStdKxrl4Twalk,
         kKxrl4TWalkW, kKxrl4TWalkB, kPolicyLayerInKxrl4Twalk,
         kPolicyLayerOutKxrl4Twalk, POLICY_KXRL4TWALK_LAYERS,
         kPolicyHomeRadKxrl4Twalk, kPolicyJointLowRadKxrl4Twalk,
         kPolicyJointHighRadKxrl4Twalk, kPolicyServoIdsKxrl4Twalk,
         POLICY_KXRL4TWALK_ACTION_SCALE, POLICY_KXRL4TWALK_PHASE_PERIOD_S,
         POLICY_KXRL4TWALK_PHASE_STAND_THRESHOLD,
         POLICY_KXRL4TWALK_COMMAND_VX_MIN, POLICY_KXRL4TWALK_COMMAND_VX_MAX,
         POLICY_KXRL4TWALK_COMMAND_WZ_MAX, POLICY_KXRL4TWALK_STANDING_FRACTION,
         kPolicyStanceGravityKxrl4Twalk, kPolicyRootToGyroKxrl4Twalk,
         kServoDirectionKxrl4Twalk,
         /*quantized=*/false, nullptr, nullptr, nullptr, nullptr},
};
constexpr size_t kKxrl4TActorCount =
        sizeof(kKxrl4TActors) / sizeof(kKxrl4TActors[0]);

// Extracted from kxrl4t's own Heart to Heart project by
// tools/motions_from_h4p.py -- see that script for how, and its own comment
// for why most of the 120 onboard slots are not here (factory-empty).
const policy::Motion kKxrl4TMotions[] = {
    {0, "一定歩行前（3回)"},
    {1, "一定歩行後（3回）"},
    {2, "左旋回（３回）"},
    {3, "右旋回（3回）"},
    {4, "前進"},
    {5, "後進"},
    {6, "左移動"},
    {7, "右移動"},
    {8, "旋回左"},
    {9, "旋回右"},
    {10, "ゆっくり歩行前"},
    {11, "ゆっくり歩行後"},
    {20, "手を振る"},
    {21, "バタバタする"},
    {22, "首を振る"},
    {30, "ホームポジション"},
    {31, "電圧低下"},
};
constexpr size_t kKxrl4TMotionCount =
        sizeof(kKxrl4TMotions) / sizeof(kKxrl4TMotions[0]);

// =======================================================================
// kxrl4d (Kondo KXR-L4D, 19 DOF: 2 legs + 2 arms + 3-DOF head) -- walk and
// getup both trained.
// =======================================================================

const float* const kKxrl4DWalkW[POLICY_KXRL4DWALK_LAYERS] = {
        kPolicyWKxrl4Dwalk0, kPolicyWKxrl4Dwalk1, kPolicyWKxrl4Dwalk2,
        kPolicyWKxrl4Dwalk3};
const float* const kKxrl4DWalkB[POLICY_KXRL4DWALK_LAYERS] = {
        kPolicyBKxrl4Dwalk0, kPolicyBKxrl4Dwalk1, kPolicyBKxrl4Dwalk2,
        kPolicyBKxrl4Dwalk3};
const float* const kKxrl4DGetupW[POLICY_KXRL4DGETUP_LAYERS] = {
        kPolicyWKxrl4Dgetup0, kPolicyWKxrl4Dgetup1, kPolicyWKxrl4Dgetup2,
        kPolicyWKxrl4Dgetup3};
const float* const kKxrl4DGetupB[POLICY_KXRL4DGETUP_LAYERS] = {
        kPolicyBKxrl4Dgetup0, kPolicyBKxrl4Dgetup1, kPolicyBKxrl4Dgetup2,
        kPolicyBKxrl4Dgetup3};

// See kxreus/rcb4robotconfig.l's own per-servo direction annotation (next
// to each joint name there) -- hand-transcribed, same order as
// kPolicyServoIdsKxrl4Dwalk/kPolicyServoIdsKxrl4Dgetup.
const int8_t kServoDirectionKxrl4Dwalk[19] = {
    1, 1, 1, 1, -1, 1, 1, -1, 1, -1, -1, -1, 1, 1, 1, 1, -1, -1, -1,
};
const int8_t kServoDirectionKxrl4Dgetup[19] = {
    1, 1, 1, 1, -1, 1, 1, -1, 1, -1, -1, -1, 1, 1, 1, 1, -1, -1, -1,
};

const Actor kKxrl4DActors[] = {
        {"walk", kPolicyObsMeanKxrl4Dwalk, kPolicyObsInvStdKxrl4Dwalk,
         kKxrl4DWalkW, kKxrl4DWalkB, kPolicyLayerInKxrl4Dwalk,
         kPolicyLayerOutKxrl4Dwalk, POLICY_KXRL4DWALK_LAYERS,
         kPolicyHomeRadKxrl4Dwalk, kPolicyJointLowRadKxrl4Dwalk,
         kPolicyJointHighRadKxrl4Dwalk, kPolicyServoIdsKxrl4Dwalk,
         POLICY_KXRL4DWALK_ACTION_SCALE, POLICY_KXRL4DWALK_PHASE_PERIOD_S,
         POLICY_KXRL4DWALK_PHASE_STAND_THRESHOLD,
         POLICY_KXRL4DWALK_COMMAND_VX_MIN, POLICY_KXRL4DWALK_COMMAND_VX_MAX,
         POLICY_KXRL4DWALK_COMMAND_WZ_MAX, POLICY_KXRL4DWALK_STANDING_FRACTION,
         kPolicyStanceGravityKxrl4Dwalk, kPolicyRootToGyroKxrl4Dwalk,
         kServoDirectionKxrl4Dwalk,
         /*quantized=*/false, nullptr, nullptr, nullptr, nullptr},
        {"getup", kPolicyObsMeanKxrl4Dgetup, kPolicyObsInvStdKxrl4Dgetup,
         kKxrl4DGetupW, kKxrl4DGetupB, kPolicyLayerInKxrl4Dgetup,
         kPolicyLayerOutKxrl4Dgetup, POLICY_KXRL4DGETUP_LAYERS,
         kPolicyHomeRadKxrl4Dgetup, kPolicyJointLowRadKxrl4Dgetup,
         kPolicyJointHighRadKxrl4Dgetup, kPolicyServoIdsKxrl4Dgetup,
         POLICY_KXRL4DGETUP_ACTION_SCALE, POLICY_KXRL4DGETUP_PHASE_PERIOD_S,
         POLICY_KXRL4DGETUP_PHASE_STAND_THRESHOLD,
         POLICY_KXRL4DGETUP_COMMAND_VX_MIN,
         POLICY_KXRL4DGETUP_COMMAND_VX_MAX, POLICY_KXRL4DGETUP_COMMAND_WZ_MAX,
         POLICY_KXRL4DGETUP_STANDING_FRACTION,
         kPolicyStanceGravityKxrl4Dgetup, kPolicyRootToGyroKxrl4Dgetup,
         kServoDirectionKxrl4Dgetup,
         /*quantized=*/false, nullptr, nullptr, nullptr, nullptr},
};
constexpr size_t kKxrl4DActorCount =
        sizeof(kKxrl4DActors) / sizeof(kKxrl4DActors[0]);

// Extracted from kxrl4d's own Heart to Heart project by
// tools/motions_from_h4p.py.
const policy::Motion kKxrl4DMotions[] = {
    {0, "一定歩行前（3歩）"},
    {1, "一定歩行後（3歩）"},
    {2, "一定歩行左（3歩）"},
    {3, "一定歩行右（3歩）"},
    {4, "RC歩行前"},
    {5, "RC歩行後"},
    {6, "RC歩行左"},
    {7, "RC歩行右"},
    {8, "RC歩行左旋回"},
    {9, "RC歩行右旋回"},
    {10, "起き上がり左"},
    {11, "起き上がり右"},
    {20, "挨拶"},
    {21, "しゃがむ"},
    {22, "威嚇する"},
    {23, "喜ぶ"},
    {24, "伏せ"},
    {25, "足踏み"},
    {26, "シュート（左足）"},
    {27, "シュート（右足）"},
    {30, "ものを掴む"},
    {31, "掴みRC歩行前"},
    {32, "掴みRC歩行後"},
    {33, "掴みRC歩行左"},
    {34, "掴みRC歩行右"},
    {35, "掴みRC歩行左旋回"},
    {36, "掴みRC歩行右旋回"},
    {37, "放り投げる"},
    {39, "ホームポジション"},
    {40, "電圧低下"},
};
constexpr size_t kKxrl4DMotionCount =
        sizeof(kKxrl4DMotions) / sizeof(kKxrl4DMotions[0]);

// =======================================================================
// kxrl6 (Kondo KXR-L6, 18 DOF: 6 limbs x 3-DOF each) -- one actor, no
// getup trained.
// =======================================================================

const float* const kKxrl6WalkW[POLICY_KXRL6WALK_LAYERS] = {
        kPolicyWKxrl6Walk0, kPolicyWKxrl6Walk1, kPolicyWKxrl6Walk2,
        kPolicyWKxrl6Walk3};
const float* const kKxrl6WalkB[POLICY_KXRL6WALK_LAYERS] = {
        kPolicyBKxrl6Walk0, kPolicyBKxrl6Walk1, kPolicyBKxrl6Walk2,
        kPolicyBKxrl6Walk3};

// See kxreus/rcb4robotconfig.l's own per-servo direction annotation (next
// to each joint name there) -- hand-transcribed, same order as
// kPolicyServoIdsKxrl6Walk.
const int8_t kServoDirectionKxrl6Walk[18] = {
    -1, -1, 1, -1, 1, -1, -1, 1, -1, -1, -1, 1, -1, 1, -1, -1, -1, 1,
};

const Actor kKxrl6Actors[] = {
        {"walk", kPolicyObsMeanKxrl6Walk, kPolicyObsInvStdKxrl6Walk,
         kKxrl6WalkW, kKxrl6WalkB, kPolicyLayerInKxrl6Walk,
         kPolicyLayerOutKxrl6Walk, POLICY_KXRL6WALK_LAYERS,
         kPolicyHomeRadKxrl6Walk, kPolicyJointLowRadKxrl6Walk,
         kPolicyJointHighRadKxrl6Walk, kPolicyServoIdsKxrl6Walk,
         POLICY_KXRL6WALK_ACTION_SCALE, POLICY_KXRL6WALK_PHASE_PERIOD_S,
         POLICY_KXRL6WALK_PHASE_STAND_THRESHOLD,
         POLICY_KXRL6WALK_COMMAND_VX_MIN, POLICY_KXRL6WALK_COMMAND_VX_MAX,
         POLICY_KXRL6WALK_COMMAND_WZ_MAX, POLICY_KXRL6WALK_STANDING_FRACTION,
         kPolicyStanceGravityKxrl6Walk, kPolicyRootToGyroKxrl6Walk,
         kServoDirectionKxrl6Walk,
         /*quantized=*/false, nullptr, nullptr, nullptr, nullptr},
};
constexpr size_t kKxrl6ActorCount =
        sizeof(kKxrl6Actors) / sizeof(kKxrl6Actors[0]);

// Extracted from kxrl6's own Heart to Heart project by
// tools/motions_from_h4p.py.
const policy::Motion kKxrl6Motions[] = {
    {0, "一定歩行前（3回）"},
    {1, "一定歩行後（3回）"},
    {2, "一定歩行左（3回）"},
    {3, "一定歩行右（3回）"},
    {4, "RC歩行前"},
    {5, "RC歩行後"},
    {6, "RC歩行左"},
    {7, "RC歩行右"},
    {8, "RC歩行左旋回"},
    {9, "RC歩行右旋回"},
    {10, "ゆっくり歩行前"},
    {11, "ゆっくり歩行後"},
    {12, "高姿勢歩行スタンバイ"},
    {13, "高姿勢歩行前"},
    {14, "高姿勢歩行後"},
    {15, "高姿勢歩行左"},
    {16, "高姿勢移動右"},
    {17, "高姿勢歩行左旋回"},
    {18, "高姿勢歩行右旋回"},
    {20, "手を振る"},
    {21, "バタバタする"},
    {22, "威嚇する"},
    {30, "ホームポジション"},
    {31, "電圧低下"},
};
constexpr size_t kKxrl6MotionCount =
        sizeof(kKxrl6Motions) / sizeof(kKxrl6Motions[0]);

// =======================================================================
// kxrl2g (Kondo KXR-L2G, 22 DOF: 2 legs (5-DOF) + 2 arms (3-DOF +
// 2-gripper) + 2-DOF head) -- one actor, no getup trained.
// =======================================================================

const float* const kKxrl2GWalkW[POLICY_KXRL2GWALK_LAYERS] = {
        kPolicyWKxrl2Gwalk0, kPolicyWKxrl2Gwalk1, kPolicyWKxrl2Gwalk2,
        kPolicyWKxrl2Gwalk3};
const float* const kKxrl2GWalkB[POLICY_KXRL2GWALK_LAYERS] = {
        kPolicyBKxrl2Gwalk0, kPolicyBKxrl2Gwalk1, kPolicyBKxrl2Gwalk2,
        kPolicyBKxrl2Gwalk3};

// See kxreus/rcb4robotconfig.l's own per-servo direction annotation (next
// to each joint name there) -- hand-transcribed, same order as
// kPolicyServoIdsKxrl2Gwalk. Entries for ids the policy carries but this
// robot has no real servo at (255 in kPolicyServoIdsKxrl2Gwalk) are left
// at 1 -- never read.
const int8_t kServoDirectionKxrl2Gwalk[22] = {
    1, 1, -1, 1, 1, 1, 1, 1, -1, 1, -1, -1, 1, -1, 1, 1, 1, 1, -1, 1, -1, -1,
};

const Actor kKxrl2GActors[] = {
        {"walk", kPolicyObsMeanKxrl2Gwalk, kPolicyObsInvStdKxrl2Gwalk,
         kKxrl2GWalkW, kKxrl2GWalkB, kPolicyLayerInKxrl2Gwalk,
         kPolicyLayerOutKxrl2Gwalk, POLICY_KXRL2GWALK_LAYERS,
         kPolicyHomeRadKxrl2Gwalk, kPolicyJointLowRadKxrl2Gwalk,
         kPolicyJointHighRadKxrl2Gwalk, kPolicyServoIdsKxrl2Gwalk,
         POLICY_KXRL2GWALK_ACTION_SCALE, POLICY_KXRL2GWALK_PHASE_PERIOD_S,
         POLICY_KXRL2GWALK_PHASE_STAND_THRESHOLD,
         POLICY_KXRL2GWALK_COMMAND_VX_MIN, POLICY_KXRL2GWALK_COMMAND_VX_MAX,
         POLICY_KXRL2GWALK_COMMAND_WZ_MAX, POLICY_KXRL2GWALK_STANDING_FRACTION,
         kPolicyStanceGravityKxrl2Gwalk, kPolicyRootToGyroKxrl2Gwalk,
         kServoDirectionKxrl2Gwalk,
         /*quantized=*/false, nullptr, nullptr, nullptr, nullptr},
};
constexpr size_t kKxrl2GActorCount =
        sizeof(kKxrl2GActors) / sizeof(kKxrl2GActors[0]);

// Extracted from kxrl2g's own Heart to Heart project by
// tools/motions_from_h4p.py.
const policy::Motion kKxrl2GMotions[] = {
    {0, "微細歩行前"},
    {1, "微細歩行後"},
    {2, "微細歩行左"},
    {3, "微細歩行右"},
    {4, "ゆっくり歩行前（5回）"},
    {5, "ゆっくり歩行後（5回）"},
    {6, "ゆっくり歩行左（5回）"},
    {7, "ゆっくり歩行右（5回）"},
    {8, "高速歩行前"},
    {9, "高速歩行後"},
    {10, "高速歩行左"},
    {11, "高速歩行右"},
    {12, "高速歩行左旋回"},
    {13, "高速歩行右旋回"},
    {14, "起き上がり（仰向け）"},
    {15, "起き上がり（うつ伏せ）"},
    {16, "起き上がり（方向判別）"},
    {20, "挨拶"},
    {21, "手を振る"},
    {22, "腕立伏せ"},
    {23, "喜ぶ"},
    {24, "がっかり"},
    {25, "シュート左"},
    {26, "シュート右"},
    {27, "パス（左）"},
    {28, "パス（右）"},
    {29, "ゴールキーパー"},
    {30, "パンチ前左"},
    {31, "パンチ前右"},
    {32, "パンチ左"},
    {33, "パンチ右"},
    {34, "防御"},
    {35, "逆立ち"},
    {36, "前転"},
    {38, "ホームポジション"},
    {39, "電圧低下"},
    {40, "ものを掴む→放す左"},
    {41, "左掴み歩行前"},
    {42, "左掴み歩行後"},
    {43, "左掴み歩行左"},
    {44, "左掴み歩行右"},
    {45, "左掴み歩行左旋回"},
    {46, "左掴み歩行右旋回"},
    {47, "左放り投げる"},
    {48, "XL2G_309ものを掴む→放す右"},
    {49, "右掴み歩行前"},
    {50, "右掴み歩行後"},
    {51, "右掴み歩行左"},
    {52, "右掴み歩行右"},
    {53, "右掴み歩行左旋回"},
    {54, "右掴み歩行右旋回"},
    {55, "右放り投げる"},
    {56, "首振り（左右）"},
    {57, "首振りくりかえし"},
    {58, "首振りリモコン"},
    {59, "赤外線あいさつ"},
};
constexpr size_t kKxrl2GMotionCount =
        sizeof(kKxrl2GMotions) / sizeof(kKxrl2GMotions[0]);

// =======================================================================
// kxra6g (Kondo KXR-A6G, modular: arms and lower body both swap
// independently) -- NO trained actor at all (see policy::RobotId's own
// comment on why: there is no one fixed body to train a walking policy
// against). Movement is entirely the RCB-4's own onboard motion table,
// including the auto-detecting front/back/left/right dispatcher slots
// (62-65, see ~/kxreus/tmp_scripts_archive/README.md) that pick the right
// walk for whichever lower body is actually attached -- exposed here the
// same way every other robot's own named motions are, through
// motionCount()/motion(), and called through PolicyMode's own
// Request::MOTION exactly as for the other four, just with no walk/getup
// actor ever selectable alongside it.
// =======================================================================

// Extracted from kxra6g's own Heart to Heart project
// (~/kxreus/projects/Hello_kxra6g/Hello_kxra6g.h4p) by
// tools/motions_from_h4p.py, same as every other robot's own table --
// unedited, including whatever oddities (a repeated "挨拶", the leftover
// "XL2G_309..." name prefix at 48) that project file's own naming already
// carried. Slots 62-67 are the auto-detecting dispatcher itself (front/
// right/back/left/turn-right/turn-left -- see this section's own top
// comment); slots 0-3's own names below ("微細歩行前" etc) are inherited
// from the kxrl2g project this one was built from and do NOT describe
// what is actually programmed at those addresses any more (the prior
// session's own dispatcher work wrote there directly, bypassing Heart to
// Heart's own naming) -- kept as extracted rather than hand-edited, same
// as this tool's own convention for every other robot.
const policy::Motion kKxra6GMotions[] = {
    {0, "微細歩行前"},
    {1, "微細歩行後"},
    {2, "微細歩行左"},
    {3, "微細歩行右"},
    {4, "ゆっくり歩行前（5回）"},
    {5, "ゆっくり歩行後（5回）"},
    {6, "ゆっくり歩行左（5回）"},
    {7, "ゆっくり歩行右（5回）"},
    {8, "高速歩行前"},
    {9, "高速歩行後"},
    {10, "高速歩行左"},
    {11, "高速歩行右"},
    {12, "高速歩行左旋回"},
    {13, "高速歩行右旋回"},
    {14, "起き上がり（仰向け）"},
    {15, "起き上がり（うつ伏せ）"},
    {16, "起き上がり（方向判別）"},
    {17, "XL4R_105(前進)"},
    {18, "挨拶"},
    {19, "XL4R_106(後進)"},
    {20, "挨拶"},
    {21, "手を振る"},
    {22, "腕立伏せ"},
    {23, "喜ぶ"},
    {24, "がっかり"},
    {25, "シュート左"},
    {26, "シュート右"},
    {27, "パス（左）"},
    {28, "パス（右）"},
    {29, "ゴールキーパー"},
    {30, "パンチ前左"},
    {31, "パンチ前右"},
    {32, "パンチ左"},
    {33, "パンチ右"},
    {34, "防御"},
    {35, "逆立ち"},
    {36, "前転"},
    {38, "ホームポジション"},
    {39, "電圧低下"},
    {40, "ものを掴む→放す左"},
    {41, "左掴み歩行前"},
    {42, "左掴み歩行後"},
    {43, "左掴み歩行左"},
    {44, "左掴み歩行右"},
    {45, "左掴み歩行左旋回"},
    {46, "左掴み歩行右旋回"},
    {47, "左放り投げる"},
    {48, "XL2G_309ものを掴む→放す右"},
    {49, "右掴み歩行前"},
    {50, "右掴み歩行後"},
    {51, "右掴み歩行左"},
    {52, "右掴み歩行右"},
    {53, "右掴み歩行左旋回"},
    {54, "右掴み歩行右旋回"},
    {55, "右放り投げる"},
    {57, "L2高速歩行前"},
    {58, "L2高速歩行後"},
    {62, "XL4R_105(前進)"},
    {63, "XL4R_105(右進)"},
    {64, "XL4R_106(後進)"},
    {65, "XL4R_106(左進)"},
    {66, "XL4R_105(右転)"},
    {67, "XL4R_105(左転)"},
};
constexpr size_t kKxra6GMotionCount =
        sizeof(kKxra6GMotions) / sizeof(kKxra6GMotions[0]);

// The union of every servo id ANY of kxra6g's own swappable parts uses --
// both arms' largest (6-axis) shape, every lower-body variant, neck and
// gripper (see the request that added this robot: ra6/la6, l2l2/l2l5/
// l2l6/mw4, neck 32/34, gripper 18/19). Used ONLY by servoIdsOfRobot()
// for RobotSelectMode's own hardware auto-detect hint -- unlike the other
// four robots' own fixed, single, trained-against servo set, kxra6g has
// no ONE expected layout to compare a live scan against, so this is
// deliberately a superset rather than any one real configuration: a
// smaller sub-assembly (say, 3-axis arms and l2l2 legs only) will still
// show a nonzero diff against this union, same as an incomplete kxrl2g
// build already does against ITS own fixed set (see RobotSelectMode's own
// header comment) -- a suggestion, not an answer, confirmed by hand
// either way.
constexpr uint8_t kKxra6GDetectIds[] = {
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
    20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 34,
};
constexpr size_t kKxra6GDetectCount =
        sizeof(kKxra6GDetectIds) / sizeof(kKxra6GDetectIds[0]);

// =======================================================================
// Robot table -- one row per policy::RobotId. Index order MUST match the
// enum exactly (KXRL4T, KXRL4D, KXRL6, KXRL2G, KXRA6G): kRobots[
// static_cast<size_t>(id)] is how every accessor below reaches "the
// configured robot's own slice", with no name lookup on the hot path.
// =======================================================================

struct RobotEntry {
    const char* name;
    const Actor* actors;
    size_t actor_count;
    const policy::Motion* motions;
    size_t motion_count;
    /// This robot's own LCD mounting -- see policy::displayRotation().
    int display_rotation;
    /// Observation/action width every actor of THIS robot shares (kxrl4d's
    /// own walk and getup agree, confirmed against their own
    /// policy_spec_*.h rather than assumed) -- not a per-actor field,
    /// since nothing here trains two actors of the same robot to
    /// different widths. 0 for a robot with no actor at all (kxra6g).
    size_t obs_dim;
    size_t act_dim;
    /// Exact upload byte count for THIS robot -- see
    /// policy::uploadExpectedBytes(). An upload always replaces actor 0
    /// ("walk"), whichever robot is configured, so this is sized from
    /// that actor's own OBS_DIM/LAYERS/WEIGHT_FLOATS. 0 for kxra6g: there
    /// is no "walk" actor of its own for an upload to replace.
    size_t upload_bytes;
    /// Servo ids for RobotSelectMode's own hardware-guess scoring (see
    /// servoIdsOfRobot()) -- actors[0].servo_ids for the four fixed-body
    /// robots (kept in sync there, not duplicated: servoIdsOfRobot()
    /// reads actors[0] directly whenever actor_count > 0 and only falls
    /// back to this pair when it is 0). kxra6g is the only row where
    /// these are ever actually read.
    const uint8_t* detect_ids;
    size_t detect_count;
};

const RobotEntry kRobots[] = {
        {"kxrl4t", kKxrl4TActors, kKxrl4TActorCount, kKxrl4TMotions,
         kKxrl4TMotionCount, /*display_rotation=*/0,
         POLICY_KXRL4TWALK_OBS_DIM, POLICY_KXRL4TWALK_ACT_DIM,
         2 * POLICY_KXRL4TWALK_OBS_DIM * sizeof(float) +
                 POLICY_KXRL4TWALK_LAYERS * 2 * sizeof(float) +
                 POLICY_KXRL4TWALK_WEIGHT_FLOATS * sizeof(int16_t),
         nullptr, 0},
        {"kxrl4d", kKxrl4DActors, kKxrl4DActorCount, kKxrl4DMotions,
         kKxrl4DMotionCount, /*display_rotation=*/0,
         POLICY_KXRL4DWALK_OBS_DIM, POLICY_KXRL4DWALK_ACT_DIM,
         2 * POLICY_KXRL4DWALK_OBS_DIM * sizeof(float) +
                 POLICY_KXRL4DWALK_LAYERS * 2 * sizeof(float) +
                 POLICY_KXRL4DWALK_WEIGHT_FLOATS * sizeof(int16_t),
         nullptr, 0},
        {"kxrl6", kKxrl6Actors, kKxrl6ActorCount, kKxrl6Motions,
         kKxrl6MotionCount, /*display_rotation=*/0, POLICY_KXRL6WALK_OBS_DIM,
         POLICY_KXRL6WALK_ACT_DIM,
         2 * POLICY_KXRL6WALK_OBS_DIM * sizeof(float) +
                 POLICY_KXRL6WALK_LAYERS * 2 * sizeof(float) +
                 POLICY_KXRL6WALK_WEIGHT_FLOATS * sizeof(int16_t),
         nullptr, 0},
        // This unit's AtomS3 sits mounted upside down on the body, so the
        // LCD needs a 180 degree flip to read right side up -- the same
        // 2 the standalone atoms3_m5stickv_kxrl2g tree's own
        // platformio.ini used to hardcode. Retune here if a differently
        // mounted kxrl2g body turns up.
        {"kxrl2g", kKxrl2GActors, kKxrl2GActorCount, kKxrl2GMotions,
         kKxrl2GMotionCount, /*display_rotation=*/2, POLICY_KXRL2GWALK_OBS_DIM,
         POLICY_KXRL2GWALK_ACT_DIM,
         2 * POLICY_KXRL2GWALK_OBS_DIM * sizeof(float) +
                 POLICY_KXRL2GWALK_LAYERS * 2 * sizeof(float) +
                 POLICY_KXRL2GWALK_WEIGHT_FLOATS * sizeof(int16_t),
         nullptr, 0},
        // No actors (nullptr/0): see this table's own top comment and
        // policy::RobotId's own comment on kxra6g. display_rotation 2,
        // confirmed on real hardware this same session as
        // atoms3_kxra6g's own standalone tree uses (that AtomS3 also
        // sits mounted upside down).
        {"kxra6g", nullptr, 0, kKxra6GMotions, kKxra6GMotionCount,
         /*display_rotation=*/2, /*obs_dim=*/0, /*act_dim=*/0,
         /*upload_bytes=*/0, kKxra6GDetectIds, kKxra6GDetectCount},
};
constexpr size_t kRobotCount = sizeof(kRobots) / sizeof(kRobots[0]);
static_assert(kRobotCount == static_cast<size_t>(policy::RobotId::COUNT),
              "kRobots[] must have exactly one row per policy::RobotId");

// The largest of the five robots' own upload_bytes above (kxrl2g's, today
// -- kxra6g's own is 0, having no actor to replace) -- what g_upload_buf
// is actually malloc'd to, once, in begin(), same as every other robot's
// own build did for its one shape. Sized to the worst case rather than to
// whichever robot ends up configured on THIS unit: the same compiled
// firmware image is flashed onto all of them, before setRobotId() has
// said which, and the buffer cannot grow later.
constexpr size_t kUploadBufBytes =
        2 * POLICY_KXRL2GWALK_OBS_DIM * sizeof(float) +
        POLICY_KXRL2GWALK_LAYERS * 2 * sizeof(float) +
        POLICY_KXRL2GWALK_WEIGHT_FLOATS * sizeof(int16_t);

// -----------------------------------------------------------------------
// Robot identity -- see policy.h's own RobotId/robotId()/setRobotId()
// comments. Read from NVS once, lazily, the first time anything asks
// (ensureRobotLoaded()) rather than only from begin(): main.cpp sets the
// LCD rotation from displayRotation() before it calls policy::begin(), and
// that must not silently see the KXRL4T default because begin() had not
// run yet.
//
// The NVS namespace string below stays "kxr4s", not "kxr5s", on purpose:
// kxr5s is atoms3_m5stickv_kxr4s plus a fifth robot, not a new device --
// reflashing an already-configured kxrl4t/kxrl4d/kxrl6/kxrl2g unit with
// THIS firmware should keep the robot identity it already has in NVS
// rather than reverting to unconfigured, and Preferences namespaces are
// just a storage key with no version meaning of their own.
// -----------------------------------------------------------------------

policy::RobotId g_robot_id = policy::RobotId::KXRL4T;
bool g_robot_configured = false;
bool g_robot_loaded = false;

void ensureRobotLoaded() {
    if (g_robot_loaded) return;
    g_robot_loaded = true;
    Preferences prefs;
    prefs.begin("kxr4s", /*readOnly=*/true);
    const String stored = prefs.getString("robot", "");
    prefs.end();
    if (stored.length() > 0) {
        const policy::RobotId id = policy::robotIdFromName(stored.c_str());
        if (id != policy::RobotId::COUNT) {
            g_robot_id = id;
            g_robot_configured = true;
        }
    }
}

const RobotEntry& currentRobot() {
    ensureRobotLoaded();
    return kRobots[static_cast<size_t>(g_robot_id)];
}

size_t g_selected = 0;

// ---------------------------------------------------------------------
// The "uploaded" actor -- see policy.h's own beginUpload()/appendUpload()/
// finishUpload() comments. Unlike kRobots[] above, whose weights are
// `.rodata` that costs nothing to keep around, this one exists only
// because a phone fetched it, so its data has to live somewhere: one
// kUploadBufBytes buffer, sized to the LARGEST of the four robots' own
// shapes (see its own comment) so it has room regardless of which one
// setRobotId() ends up naming.
//
// Allocated ONCE, in begin() -- called at boot, before Wi-Fi/BT/ESP-NOW
// have made a single allocation of their own -- and never freed, rather
// than malloc'd fresh on every beginUpload(). See the m5stickc trees' own
// comment on why: a fragmented heap can refuse a single allocation this
// size even with plenty of TOTAL free heap left, and it only gets worse
// the longer the device runs.
uint8_t* g_upload_buf = nullptr;  // null only if the early malloc failed
size_t g_upload_received = 0;
bool g_upload_active = false;

const int16_t* g_uploaded_weights[POLICY_MAX_LAYERS];
const int16_t* g_uploaded_biases[POLICY_MAX_LAYERS];
float g_uploaded_weight_scale[POLICY_MAX_LAYERS];
float g_uploaded_bias_scale[POLICY_MAX_LAYERS];
Actor g_uploaded_actor;                 // valid only once g_uploaded_ready
bool g_uploaded_ready = false;

/// Actors, compiled-in and uploaded, indexed as one contiguous range over
/// THE CONFIGURED ROBOT's own slice -- count()'s own extra slot when
/// g_uploaded_ready is what makes index actor_count valid. Every *Of()
/// accessor and select() itself goes through this rather than
/// currentRobot().actors directly, so neither has to know which kind of
/// actor it was handed.
const Actor& actorAt(size_t index) {
    const RobotEntry& r = currentRobot();
    return index < r.actor_count ? r.actors[index] : g_uploaded_actor;
}

/// index if it is currently valid, else whatever is selected -- the same
/// fallback homeRadOf()/commandVxMinOf() et al. already gave a
/// too-large index before the uploaded actor existed, just now also
/// covering "the uploaded actor that finishUpload() has not run yet".
size_t effectiveIndex(size_t index) {
    const RobotEntry& r = currentRobot();
    return index < r.actor_count + (g_uploaded_ready ? 1 : 0) ? index
                                                               : g_selected;
}

// What run() actually reads. Points into flash until select() moves it.
const float* g_weights[POLICY_MAX_LAYERS];
const float* g_biases[POLICY_MAX_LAYERS];
bool g_in_ram = false;

// What run() reads instead, for a quantized (see Actor::quantized) actor
// -- currently only ever the "uploaded" one. Kept fully separate from
// g_weights/g_biases above rather than reusing POLICY_WEIGHTS_IN_RAM's own
// g_ram cache: that cache is an OPTIONAL speed-up over flash a compiled-in
// actor can always fall back from, while this is the uploaded actor's only
// copy of its own data, period.
const int16_t* g_qweights[POLICY_MAX_LAYERS];
const int16_t* g_qbiases[POLICY_MAX_LAYERS];
float g_weight_scale[POLICY_MAX_LAYERS];
float g_bias_scale[POLICY_MAX_LAYERS];

#ifdef POLICY_WEIGHTS_IN_RAM
// Not defined for this tree's own platformio.ini -- kxr5s's ~123 KiB
// upload buffer already leaves too little RAM for Wi-Fi/BT on top of a
// second, speed-only cache this size (see kxrl4d(UnitV)'s own real-hardware
// boot-crash-loop finding, which is why every m5stickc_*/atoms3_* tree
// this one was assembled from made the same choice). Left compiled in
// (rather than deleted) only so a future build config that DOES have the
// RAM to spare can still ask for it, sized to the worst case the same way
// kUploadBufBytes is.
#ifndef POLICY_RAM_WEIGHT_BYTES
#define POLICY_RAM_WEIGHT_BYTES (POLICY_KXRL2GWALK_WEIGHT_FLOATS * 4)
#endif
constexpr size_t kRamFloats = POLICY_RAM_WEIGHT_BYTES / sizeof(float);
float g_ram[kRamFloats];
size_t g_layers_in_ram = 0;
#endif

/// ELU with alpha = 1, which is what the ONNX Elu node defaults to.
inline float elu(float x) { return x > 0.0f ? x : expm1f(x); }

}  // namespace

namespace policy {

const char* robotIdName(RobotId id) {
    const size_t index = static_cast<size_t>(id);
    return index < kRobotCount ? kRobots[index].name : "";
}

RobotId robotIdFromName(const char* name) {
    for (size_t i = 0; i < kRobotCount; i++) {
        if (strcmp(name, kRobots[i].name) == 0) {
            return static_cast<RobotId>(i);
        }
    }
    return RobotId::COUNT;
}

bool robotConfigured() {
    ensureRobotLoaded();
    return g_robot_configured;
}

RobotId robotId() {
    ensureRobotLoaded();
    return g_robot_id;
}

bool setRobotId(RobotId id) {
    if (static_cast<size_t>(id) >= kRobotCount) return false;
    Preferences prefs;
    prefs.begin("kxr4s", /*readOnly=*/false);  // see ensureRobotLoaded()'s own comment on why
    const bool ok = prefs.putString("robot", robotIdName(id)) > 0;
    prefs.end();
    // Deliberately NOT updated here: g_robot_id/g_robot_configured stay
    // whatever ensureRobotLoaded() read at boot until the next reboot --
    // see this function's own header comment for why switching live is
    // not something to do while POLICY mode might be running.
    return ok;
}

int displayRotation() { return currentRobot().display_rotation; }

size_t count() {
    return currentRobot().actor_count + (g_uploaded_ready ? 1 : 0);
}

const char* name(size_t index) {
    const RobotEntry& r = currentRobot();
    if (index < r.actor_count) return r.actors[index].name;
    return index == r.actor_count && g_uploaded_ready ? g_uploaded_actor.name
                                                       : "";
}

size_t selected() { return g_selected; }

bool select(size_t index) {
    if (index >= count()) return false;
    g_selected = index;
    const Actor& a = actorAt(index);

    if (a.quantized) {
        // The "uploaded" actor's own data already lives in RAM -- the
        // upload buffer itself, malloc'd whole in finishUpload() -- so
        // there is no flash-vs-RAM choice for the block below to make,
        // and nothing to do with g_weights/g_biases: run() reads
        // g_qweights/g_qbiases instead whenever a.quantized is set.
        for (size_t i = 0; i < a.layers; i++) {
            g_qweights[i] = a.qweights[i];
            g_qbiases[i] = a.qbiases[i];
            g_weight_scale[i] = a.weight_scale[i];
            g_bias_scale[i] = a.bias_scale[i];
        }
        g_in_ram = true;
#ifdef POLICY_WEIGHTS_IN_RAM
        g_layers_in_ram = a.layers;
#endif
        return true;
    }

    for (size_t i = 0; i < a.layers; i++) {
        g_weights[i] = a.weights[i];
        g_biases[i] = a.biases[i];
    }
    g_in_ram = false;

#ifdef POLICY_WEIGHTS_IN_RAM
    // Largest layer first. The cost being avoided is cache line fills, which
    // is proportional to bytes read, so a partial budget buys the most by
    // taking the biggest matrices -- and a layer left in flash still works,
    // just slower.
    size_t order[POLICY_MAX_LAYERS];
    for (size_t i = 0; i < a.layers; i++) order[i] = i;
    for (size_t i = 1; i < a.layers; i++) {
        const size_t key = order[i];
        const size_t key_size =
                static_cast<size_t>(a.layer_in[key]) * a.layer_out[key];
        size_t j = i;
        while (j > 0 && static_cast<size_t>(a.layer_in[order[j - 1]]) *
                                        a.layer_out[order[j - 1]] < key_size) {
            order[j] = order[j - 1];
            j--;
        }
        order[j] = key;
    }

    size_t at = 0;
    g_layers_in_ram = 0;
    for (size_t i = 0; i < a.layers; i++) {
        const size_t layer = order[i];
        const size_t n_in = a.layer_in[layer];
        const size_t n_out = a.layer_out[layer];
        const size_t need = n_in * n_out + n_out;
        if (at + need > kRamFloats) continue;  // stays in flash
        memcpy(g_ram + at, a.weights[layer], n_in * n_out * sizeof(float));
        g_weights[layer] = g_ram + at;
        at += n_in * n_out;
        memcpy(g_ram + at, a.biases[layer], n_out * sizeof(float));
        g_biases[layer] = g_ram + at;
        at += n_out;
        g_layers_in_ram++;
    }
    g_in_ram = g_layers_in_ram > 0;
#endif
    return true;
}

bool begin() {
    ensureRobotLoaded();
    // Before select() copies anything into g_ram, and long before
    // net::begin()/EspNowLink::begin() -- see kUploadBufBytes' own comment
    // on why the timing matters, not just the size.
    if (g_upload_buf == nullptr) {
        g_upload_buf = static_cast<uint8_t*>(malloc(kUploadBufBytes));
    }
    return select(g_selected);
}

size_t layers() { return actorAt(g_selected).layers; }

size_t layersInRam() {
#ifdef POLICY_WEIGHTS_IN_RAM
    return g_layers_in_ram;
#else
    return 0;
#endif
}

bool weightsInRam() { return g_in_ram; }

size_t motionCount() { return currentRobot().motion_count; }
const Motion& motion(size_t index) {
    const RobotEntry& r = currentRobot();
    static const Motion kNoMotion = {0xFF, "none"};
    return index < r.motion_count ? r.motions[index] : kNoMotion;
}

size_t obsDim() { return currentRobot().obs_dim; }
size_t actDim() { return currentRobot().act_dim; }

const float* homeRad() { return actorAt(g_selected).home_rad; }

const float* homeRadOf(size_t index) {
    return actorAt(effectiveIndex(index)).home_rad;
}
const float* jointLowRad() { return actorAt(g_selected).joint_low; }
const float* jointHighRad() { return actorAt(g_selected).joint_high; }
const uint8_t* servoIds() { return actorAt(g_selected).servo_ids; }

const uint8_t* servoIdsOfRobot(RobotId id, size_t* count) {
    const size_t index = static_cast<size_t>(id);
    if (index >= kRobotCount) {
        *count = 0;
        return nullptr;
    }
    const RobotEntry& r = kRobots[index];
    // A robot with no actor at all (kxra6g) has no actors[0] to read --
    // see RobotEntry's own detect_ids/detect_count comment.
    if (r.actor_count == 0) {
        *count = r.detect_count;
        return r.detect_ids;
    }
    *count = r.act_dim;
    return r.actors[0].servo_ids;
}
const int8_t* servoDirection() { return actorAt(g_selected).servo_direction; }
float actionScale() { return actorAt(g_selected).action_scale; }
float phasePeriodS() { return actorAt(g_selected).phase_period_s; }
float phaseStandThreshold() {
    return actorAt(g_selected).phase_stand_threshold;
}
float commandVxMin() { return actorAt(g_selected).command_vx_min; }
float commandVxMax() { return actorAt(g_selected).command_vx_max; }
float commandWzMax() { return actorAt(g_selected).command_wz_max; }

float commandVxMinOf(size_t index) {
    return actorAt(effectiveIndex(index)).command_vx_min;
}
float commandVxMaxOf(size_t index) {
    return actorAt(effectiveIndex(index)).command_vx_max;
}
float commandWzMaxOf(size_t index) {
    return actorAt(effectiveIndex(index)).command_wz_max;
}
float standingFraction() { return actorAt(g_selected).standing_fraction; }
const float* stanceGravity() { return actorAt(g_selected).stance_gravity; }
const float* rootToGyro() { return actorAt(g_selected).root_to_gyro; }

void run(const float* obs, float* action) {
    const Actor& a = actorAt(g_selected);
    const size_t obs_dim = currentRobot().obs_dim;
    const size_t act_dim = currentRobot().act_dim;
    for (size_t i = 0; i < obs_dim; i++) {
        g_a[i] = (obs[i] - a.mean[i]) * a.inv_std[i];
    }

    const float* in = g_a;
    float* out = g_b;
    for (size_t layer = 0; layer < a.layers; layer++) {
        const size_t n_in = a.layer_in[layer];
        const size_t n_out = a.layer_out[layer];
        const bool last = layer + 1 == a.layers;
        if (a.quantized) {
            // The uploaded actor's own weights/biases (see policy.h's own
            // beginUpload() comment): int16 fixed-point, one scale per
            // layer for each of the two. Dequantized right here, one
            // element at a time, rather than ever expanding a whole
            // layer back into a second float32 buffer -- that buffer is
            // exactly the RAM this format exists to avoid holding twice.
            const int16_t* w = g_qweights[layer];
            const int16_t* bias = g_qbiases[layer];
            const float wscale = g_weight_scale[layer];
            const float bscale = g_bias_scale[layer];
            for (size_t o = 0; o < n_out; o++) {
                const int16_t* row = w + o * n_in;
                float sum = bias[o] * bscale;
                for (size_t i = 0; i < n_in; i++) {
                    sum += row[i] * wscale * in[i];
                }
                out[o] = last ? sum : elu(sum);
            }
        } else {
            const float* w = g_weights[layer];
            const float* bias = g_biases[layer];
            // The weight matrix is row major as (out x in), so each
            // output is one contiguous sweep -- which is what keeps the
            // flash cache useful.
            for (size_t o = 0; o < n_out; o++) {
                const float* row = w + o * n_in;
                float sum = bias[o];
                for (size_t i = 0; i < n_in; i++) sum += row[i] * in[i];
                out[o] = last ? sum : elu(sum);
            }
        }
        in = out;
        out = (out == g_b) ? g_a : g_b;
    }

    for (size_t i = 0; i < act_dim; i++) action[i] = in[i];
}

size_t uploadExpectedBytes() { return currentRobot().upload_bytes; }

bool beginUpload() {
    g_upload_active = false;
    g_upload_received = 0;

    // Either the early malloc in begin() failed (see kUploadBufBytes' own
    // comment -- this device genuinely does not have ~123 KiB to spare
    // right now) or the buffer this would write into is the one run() is
    // reading from on every control step right now (the uploaded actor is
    // the one currently selected). Either way, a caller sees this the same
    // way an out-of-RAM failure already looks: select a different
    // (compiled-in) actor first, then retry.
    if (g_upload_buf == nullptr) return false;
    if (g_uploaded_ready && g_selected == currentRobot().actor_count) {
        return false;
    }

    g_upload_active = true;
    return true;
}

bool appendUpload(const uint8_t* data, size_t len) {
    if (!g_upload_active) return false;
    const size_t expected = currentRobot().upload_bytes;
    if (g_upload_received + len > expected) {
        // More bytes than expected: caller and firmware disagree about
        // what is being sent (wrong file, stale build) -- abort outright
        // rather than accept a truncated, silently-wrong mix of old and
        // new data.
        g_upload_active = false;
        g_upload_received = 0;
        return false;
    }
    memcpy(g_upload_buf + g_upload_received, data, len);
    g_upload_received += len;
    return true;
}

size_t uploadBytesReceived() { return g_upload_active ? g_upload_received : 0; }

bool finishUpload() {
    const size_t expected = currentRobot().upload_bytes;
    if (!g_upload_active || g_upload_received != expected) {
        g_upload_active = false;
        g_upload_received = 0;
        return false;
    }
    g_upload_active = false;
    g_upload_received = 0;

    // Same per-layer shapes as the configured robot's own compiled-in
    // "walk" actor (index 0) -- an upload is a different trained
    // checkpoint of it, not a different network (see policy.h's own
    // comment on beginUpload()).
    const Actor& shape = currentRobot().actors[0];
    const size_t obs_dim = currentRobot().obs_dim;

    // The whole float region -- mean, inv_std, then every layer's two
    // scales -- sits first and is 4-byte aligned from g_upload_buf
    // (malloc's own return address) onward, so it is safe to read
    // straight through as one float array.
    const float* floats = reinterpret_cast<const float*>(g_upload_buf);
    const float* mean = floats;
    const float* inv_std = floats + obs_dim;
    const float* wscale = inv_std + obs_dim;
    const float* bscale = wscale + shape.layers;
    for (size_t i = 0; i < shape.layers; i++) {
        g_uploaded_weight_scale[i] = wscale[i];
        g_uploaded_bias_scale[i] = bscale[i];
    }

    // The int16 region starts right after (a multiple of 4 bytes in, so
    // also 2-byte aligned) and is weight/bias per layer, back to back, in
    // layer order.
    const int16_t* ints =
            reinterpret_cast<const int16_t*>(bscale + shape.layers);
    size_t at = 0;
    for (size_t i = 0; i < shape.layers; i++) {
        const size_t n_in = shape.layer_in[i];
        const size_t n_out = shape.layer_out[i];
        g_uploaded_weights[i] = ints + at;
        at += n_in * n_out;
        g_uploaded_biases[i] = ints + at;
        at += n_out;
    }

    g_uploaded_actor = Actor{
            "uploaded",        mean,
            inv_std,           nullptr,
            nullptr,           shape.layer_in,
            shape.layer_out,   shape.layers,
            shape.home_rad,    shape.joint_low,
            shape.joint_high,  shape.servo_ids,
            shape.action_scale, shape.phase_period_s,
            shape.phase_stand_threshold, shape.command_vx_min,
            shape.command_vx_max, shape.command_wz_max,
            shape.standing_fraction, shape.stance_gravity,
            shape.root_to_gyro, shape.servo_direction,
            /*quantized=*/true, g_uploaded_weights, g_uploaded_biases,
            g_uploaded_weight_scale, g_uploaded_bias_scale};
    g_uploaded_ready = true;
    return true;
}

}  // namespace policy
