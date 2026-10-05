/* Copied from EusView (iPhone/Mac app, ios/EusView/Physics/odesim.h, M. Inaba 2026)
 * for kxreus eusview.l (libeusviewode.so via defforeign). Uses ODE (Open Dynamics Engine,
 * https://www.ode.org, BSD or LGPL license; Ubuntu: libode-dev). Keep in sync with the app. */
/*
 * odesim.h : ODE (Open Dynamics Engine) でロボットを動かす薄い C の層 (Swift から呼ぶ)
 *   eusdyna (odedyna.l) と同じ考え方: リンク = 剛体, 関節 = ヒンジ / スライダ, サーボ = 角速度モータ
 *   単位: m, kg, s, rad。座標は z が上 (EusLisp と同じ)。床は z = 0 の平面
 */
#ifndef ODESIM_H
#define ODESIM_H
#ifdef __cplusplus
extern "C" {
#endif

typedef struct OdeSim OdeSim;

OdeSim *odesim_create(const double gravity[3], double erp, double cfm,
                      double mu, double soft_erp, double soft_cfm, double bounce, int iterations);
void odesim_destroy(OdeSim *s);

/* リンク (剛体) を加える. pos/rot: リンク座標系のワールドでの位置と回転 (3x3 行優先).
   com: リンク座標系での重心, inertia: 重心まわり (リンク座標系の軸) Ixx Ixy Ixz Iyy Iyz Izz.
   形状: 三角形メッシュ (リンク座標系) を床との当たり判定に使う. 箱は odesim_add_box */
int odesim_add_link(OdeSim *s, double mass, const double com[3], const double inertia[6],
                    const double pos[3], const double rot[9]);
void odesim_add_mesh(OdeSim *s, int link, const float *vertices, int nv, const int *indices, int ni);
void odesim_add_box(OdeSim *s, int link, const double size[3], const double pos[3], const double rot[9]);
/* 円柱: 軸は形状の座標系の z */
void odesim_add_cylinder(OdeSim *s, int link, double radius, double length, const double pos[3], const double rot[9]);

/* 関節: type 0 = 回転 (ヒンジ), 1 = 直動 (スライダ). anchor・axis はワールド座標.
   lo/hi: 可動範囲 (rad / m). サーボ: 速度 = clamp(kp (目標 - 今), ±vmax), 力の上限 fmax */
int odesim_add_joint(OdeSim *s, int parent, int child, int type, const double anchor[3], const double axis[3],
                     double lo, double hi, double fmax, double vmax, double kp);
void odesim_set_targets(OdeSim *s, const double *targets, int n);
void odesim_set_servo(OdeSim *s, int on);   /* 0: 脱力 */
/* 関節の動かし方: 0 = サーボ (角度), 1 = 回転 (車輪, eusdyna の d-joint-rotation: Vel = 20 目標/π, FMax = 1e6) */
void odesim_set_joint_mode(OdeSim *s, int joint, int mode);
/* サーボの力の上限を変える (全関節) */
void odesim_set_fmax(OdeSim *s, int joint, double fmax);
/* quickstep: 0 = dWorldStep (eusdyna と同じ), 1 = dWorldQuickStep.  max_contacts: 1 組あたりの接触点の数 */
void odesim_set_options(OdeSim *s, int quickstep, int max_contacts, double bounce_vel);

/* dt で n 回進める */
void odesim_step(OdeSim *s, double dt, int n);

/* リンク座標系のワールドでの位置・回転 (3x3 行優先) */
void odesim_link_pose(OdeSim *s, int link, double pos[3], double rot[9]);
double odesim_joint_value(OdeSim *s, int joint);
int odesim_contacts(OdeSim *s);   /* 直前のステップの接触点の数 */
/* 作ったときの関節の値 q0 と可動範囲 (lo, hi) を設定する. 関節の値 = ODE の角度 + q0 */
void odesim_set_joint_offset(OdeSim *s, int joint, double q0, double lo, double hi);

#ifdef __cplusplus
}
#endif
#endif
