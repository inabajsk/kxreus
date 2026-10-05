// wbqp.cpp : 全身の 2 次計画法 (wbqp.h の実装. C++17 の標準ライブラリだけ, 外部のライブラリなし)
//   1. 小さな 3 次元の数学 (V3, M3, Pose)
//   2. QP ソルバ: Goldfarb & Idnani (1983) "A numerically stable dual method for solving strictly convex quadratic programs"
//      の双対有効制約法を論文の手順どおりに自分で書いたもの (密行列, Cholesky + Givens 回転で J = L^-T Q と R を更新)
//   3. モデル: リンクの木・関節・カプセル・足の裏・質量
//   4. 評価 (衝突・可動範囲・重心) と, コマごとの逐次 QP
#include "wbqp.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>
#include <limits>
#include <string>
#include <vector>

namespace {

// MARK: - 1. 数学

struct V3 {
  double x = 0, y = 0, z = 0;
  V3() {}
  V3(double a, double b, double c) : x(a), y(b), z(c) {}
  V3 operator+(const V3 &o) const { return {x + o.x, y + o.y, z + o.z}; }
  V3 operator-(const V3 &o) const { return {x - o.x, y - o.y, z - o.z}; }
  V3 operator*(double s) const { return {x * s, y * s, z * s}; }
  V3 &operator+=(const V3 &o) { x += o.x; y += o.y; z += o.z; return *this; }
  double operator[](int i) const { return i == 0 ? x : i == 1 ? y : z; }
};
inline double dot(const V3 &a, const V3 &b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
inline V3 cross(const V3 &a, const V3 &b) { return {a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x}; }
inline double norm(const V3 &a) { return std::sqrt(dot(a, a)); }

struct M3 {
  double m[9] = {1, 0, 0, 0, 1, 0, 0, 0, 1};   // 行優先
  static M3 from(const double *r) { M3 a; std::memcpy(a.m, r, sizeof(a.m)); return a; }
  V3 operator*(const V3 &v) const { return {m[0] * v.x + m[1] * v.y + m[2] * v.z, m[3] * v.x + m[4] * v.y + m[5] * v.z, m[6] * v.x + m[7] * v.y + m[8] * v.z}; }
  M3 operator*(const M3 &b) const {
    M3 c;
    for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) c.m[i * 3 + j] = m[i * 3] * b.m[j] + m[i * 3 + 1] * b.m[3 + j] + m[i * 3 + 2] * b.m[6 + j];
    return c;
  }
  M3 T() const { M3 c; for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) c.m[i * 3 + j] = m[j * 3 + i]; return c; }
  V3 col(int j) const { return {m[j], m[3 + j], m[6 + j]}; }
};

/// 軸 (単位ベクトル) まわりに角度 a の回転
M3 rotAxis(const V3 &u, double a) {
  double c = std::cos(a), s = std::sin(a), t = 1 - c;
  M3 r;
  r.m[0] = t * u.x * u.x + c;       r.m[1] = t * u.x * u.y - s * u.z; r.m[2] = t * u.x * u.z + s * u.y;
  r.m[3] = t * u.x * u.y + s * u.z; r.m[4] = t * u.y * u.y + c;       r.m[5] = t * u.y * u.z - s * u.x;
  r.m[6] = t * u.x * u.z - s * u.y; r.m[7] = t * u.y * u.z + s * u.x; r.m[8] = t * u.z * u.z + c;
  return r;
}
M3 expw(const V3 &w) { double a = norm(w); return a < 1e-12 ? M3() : rotAxis(w * (1 / a), a); }
/// 回転の対数 (回転ベクトル, |w| <= π). 四元数を経由する (π の近くでも安定)
V3 logR(const M3 &R) {
  const double *m = R.m;
  double tr = m[0] + m[4] + m[8], qw, qx, qy, qz;
  if (tr > 0) { double s = std::sqrt(tr + 1) * 2; qw = s / 4; qx = (m[7] - m[5]) / s; qy = (m[2] - m[6]) / s; qz = (m[3] - m[1]) / s; }
  else if (m[0] > m[4] && m[0] > m[8]) { double s = std::sqrt(1 + m[0] - m[4] - m[8]) * 2; qw = (m[7] - m[5]) / s; qx = s / 4; qy = (m[1] + m[3]) / s; qz = (m[2] + m[6]) / s; }
  else if (m[4] > m[8]) { double s = std::sqrt(1 + m[4] - m[0] - m[8]) * 2; qw = (m[2] - m[6]) / s; qx = (m[1] + m[3]) / s; qy = s / 4; qz = (m[5] + m[7]) / s; }
  else { double s = std::sqrt(1 + m[8] - m[0] - m[4]) * 2; qw = (m[3] - m[1]) / s; qx = (m[2] + m[6]) / s; qy = (m[5] + m[7]) / s; qz = s / 4; }
  if (qw < 0) { qw = -qw; qx = -qx; qy = -qy; qz = -qz; }
  double n = std::sqrt(qx * qx + qy * qy + qz * qz);
  if (n < 1e-12) return {};
  double th = 2 * std::atan2(n, qw);
  return V3(qx, qy, qz) * (th / n);
}
/// 3x3 を正規直交に戻す (グラム・シュミット, 列)
M3 orthonormalize(const M3 &R) {
  V3 x = R.col(0), y = R.col(1);
  x = x * (1 / norm(x));
  y = y - x * dot(x, y); y = y * (1 / norm(y));
  V3 z = cross(x, y);
  M3 o;
  o.m[0] = x.x; o.m[3] = x.y; o.m[6] = x.z; o.m[1] = y.x; o.m[4] = y.y; o.m[7] = y.z; o.m[2] = z.x; o.m[5] = z.y; o.m[8] = z.z;
  return o;
}

struct Pose {
  M3 R; V3 p;
  Pose operator*(const Pose &b) const { return {R * b.R, R * b.p + p}; }
  V3 apply(const V3 &v) const { return R * v + p; }
  Pose inv() const { M3 t = R.T(); return {t, (t * p) * -1}; }
  static Pose from12(const double *a) { Pose P; P.p = {a[0], a[1], a[2]}; P.R = M3::from(a + 3); return P; }
  void to12(double *a) const { a[0] = p.x; a[1] = p.y; a[2] = p.z; std::memcpy(a + 3, R.m, sizeof(R.m)); }
};

double yawOf(const M3 &R) { return std::atan2(R.m[3], R.m[0]); }   // x 軸の水平の向き
M3 rotZ(double a) { return rotAxis({0, 0, 1}, a); }

// MARK: - 2. QP ソルバ (Goldfarb–Idnani)
//   min 1/2 x^T H x + g^T x   s.t.  C x >= c  (C は m 行 n 列, 行優先)
//   戻り値 0: 最適, 1: 反復の上限, -1: 解なし / 数値の破綻.  H は壊す

struct GIQP {
  std::vector<double> J, R, d, z, r, u, Cn, cn;
  std::vector<int> A;
  std::vector<char> active;

  static bool cholesky(int n, double *a) {
    for (int j = 0; j < n; j++) {
      double s = a[j * n + j];
      for (int k = 0; k < j; k++) s -= a[j * n + k] * a[j * n + k];
      if (!(s > 1e-14)) return false;
      double dd = std::sqrt(s);
      a[j * n + j] = dd;
      for (int i = j + 1; i < n; i++) {
        double t = a[i * n + j];
        for (int k = 0; k < j; k++) t -= a[i * n + k] * a[j * n + k];
        a[i * n + j] = t / dd;
      }
    }
    return true;
  }

  int solve(int n, std::vector<double> &H, const std::vector<double> &g, int m, const std::vector<double> &C,
            const std::vector<double> &c, std::vector<double> &x, int maxit, int &iters) {
    iters = 0;
    x.assign(n, 0);
    if (!cholesky(n, H.data())) return -1;
    // J = L^-T (上三角): L^-1 を前進代入で求めて転置
    J.assign(n * n, 0);
    for (int col = 0; col < n; col++) {
      for (int i = col; i < n; i++) {
        double s = (i == col) ? 1 : 0;
        for (int k = col; k < i; k++) s -= H[i * n + k] * J[col * n + k];   // J の行 col に L^-1 の列 col を仮に置く
        J[col * n + i] = s / H[i * n + i];
      }
    }
    // いま J[col][i] = (L^-1)[i][col] = (L^-T)[col][i] なので J はそのまま L^-T (行優先)
    // 制約なしの最小: x = -J J^T g
    std::vector<double> t(n, 0);
    for (int k = 0; k < n; k++) { double s = 0; for (int i = 0; i < n; i++) s += J[i * n + k] * g[i]; t[k] = s; }
    for (int i = 0; i < n; i++) { double s = 0; for (int k = 0; k < n; k++) s += J[i * n + k] * t[k]; x[i] = -s; }
    // 行を長さ 1 にそろえる
    Cn.assign(C.begin(), C.end()); cn.assign(c.begin(), c.end());
    active.assign(m, 0);
    for (int i = 0; i < m; i++) {
      double s = 0;
      for (int k = 0; k < n; k++) s += Cn[i * n + k] * Cn[i * n + k];
      s = std::sqrt(s);
      if (s < 1e-12) { active[i] = 2; continue; }      // 中身のない行は使わない
      for (int k = 0; k < n; k++) Cn[i * n + k] /= s;
      cn[i] /= s;
    }
    R.assign(n * n, 0); d.assign(n, 0); z.assign(n, 0); r.assign(n, 0); u.assign(n + 1, 0);
    A.clear();
    int q = 0;
    const double tol = 1e-10;
    for (;;) {
      // 手順 1: いちばん破っている制約
      int p = -1; double smin = -tol;
      for (int i = 0; i < m; i++) {
        if (active[i]) continue;
        double s = -cn[i];
        const double *ci = &Cn[i * n];
        for (int k = 0; k < n; k++) s += ci[k] * x[k];
        if (s < smin) { smin = s; p = i; }
      }
      if (p < 0) return 0;
      const double *np = &Cn[p * n];
      double uplus = 0;
      // 手順 2
      for (;;) {
        if (++iters > maxit) return 1;
        for (int k = 0; k < n; k++) { double s = 0; for (int i = 0; i < n; i++) s += J[i * n + k] * np[i]; d[k] = s; }
        double d2 = 0;
        for (int k = q; k < n; k++) d2 += d[k] * d[k];
        for (int i = 0; i < n; i++) { double s = 0; for (int k = q; k < n; k++) s += J[i * n + k] * d[k]; z[i] = s; }
        for (int k = q - 1; k >= 0; k--) {
          double s = d[k];
          for (int l = k + 1; l < q; l++) s -= R[k * n + l] * r[l];
          r[k] = s / R[k * n + k];
        }
        double t1 = std::numeric_limits<double>::infinity(); int l = -1;
        for (int k = 0; k < q; k++) if (r[k] > 1e-12) { double v = u[k] / r[k]; if (v < t1) { t1 = v; l = k; } }
        double t2 = std::numeric_limits<double>::infinity();
        if (d2 > 1e-14) {
          double s = -cn[p];
          for (int k = 0; k < n; k++) s += np[k] * x[k];
          t2 = -s / d2;                          // z^T n = |d2|^2
        }
        if (std::isinf(t1) && std::isinf(t2)) return -1;
        if (std::isinf(t2)) {                    // 双対だけ動かす
          for (int k = 0; k < q; k++) u[k] -= t1 * r[k];
          uplus += t1;
          drop(n, q, l);
          continue;
        }
        double st = std::min(t1, t2);
        for (int i = 0; i < n; i++) x[i] += st * z[i];
        for (int k = 0; k < q; k++) u[k] -= st * r[k];
        uplus += st;
        if (t2 <= t1) {                          // 全部のステップ: p を有効にする
          if (!add(n, q)) return -1;
          u[q - 1] = uplus;
          A.push_back(p);
          active[p] = 1;
          break;
        }
        drop(n, q, l);                           // 部分のステップ: l を外して手順 2 へ
      }
    }
  }

  /// d (= J^T n) の q 番目より下を Givens 回転で消して R に列を足す
  bool add(int n, int &q) {
    for (int k = n - 1; k > q; k--) {
      double a = d[k - 1], b = d[k];
      if (b == 0) continue;
      double h = std::hypot(a, b), cs = a / h, sn = b / h;
      d[k - 1] = h; d[k] = 0;
      for (int i = 0; i < n; i++) {
        double ja = J[i * n + k - 1], jb = J[i * n + k];
        J[i * n + k - 1] = cs * ja + sn * jb;
        J[i * n + k] = -sn * ja + cs * jb;
      }
    }
    if (std::fabs(d[q]) < 1e-12) return false;  // いまの制約と 1 次従属
    for (int k = 0; k <= q; k++) R[k * n + q] = d[k];
    q++;
    return true;
  }

  /// 有効な制約の l 番目を外す (R の列を消し, Givens 回転で上三角に戻す)
  void drop(int n, int &q, int l) {
    active[A[l]] = 0;
    for (int k = l; k < q - 1; k++) { u[k] = u[k + 1]; A[k] = A[k + 1]; }
    A.pop_back();
    for (int col = l; col < q - 1; col++) for (int k = 0; k < q; k++) R[k * n + col] = R[k * n + col + 1];
    for (int k = 0; k < q; k++) R[k * n + q - 1] = 0;
    for (int k = l; k < q - 1; k++) {
      double a = R[k * n + k], b = R[(k + 1) * n + k];
      if (b == 0) continue;
      double h = std::hypot(a, b), cs = a / h, sn = b / h;
      for (int col = k; col < q - 1; col++) {
        double ra = R[k * n + col], rb = R[(k + 1) * n + col];
        R[k * n + col] = cs * ra + sn * rb;
        R[(k + 1) * n + col] = -sn * ra + cs * rb;
      }
      for (int i = 0; i < n; i++) {
        double ja = J[i * n + k], jb = J[i * n + k + 1];
        J[i * n + k] = cs * ja + sn * jb;
        J[i * n + k + 1] = -sn * ja + cs * jb;
      }
    }
    q--;
    u[q] = 0;
  }
};

// MARK: - 3. モデル

struct Link {
  int parent = -1;
  Pose rest;
  int joint = -1;
  double mass = -1; V3 com;
  std::vector<V3> verts;
  std::vector<int> ancJoints;   // 自分から根元までの関節
  int depth = 0;
  int ncaps = 0; bool noCollision = false;
};
struct Joint { int link; int type; V3 axis; double lo, hi, vmax; };
struct Capsule { int link; V3 a, b; double r; };
struct Hand { int link = -1; V3 off; };
struct Foot { int link = -1; std::vector<V3> sole; M3 flat; };   // flat: 関節角 0 でのワールドの向き (裏が水平)

struct Param { const char *name; double value; };

enum {
  P_DT, P_ITER, P_W_POSTURE, P_W_HAND, P_W_FOOT, P_W_FOOT_ROT, P_W_STANCE, P_W_STANCE_ROT, P_W_ROOT_ROT, P_W_ROOT_POS, P_W_REG, P_W_SLACK,
  P_JOINT_MARGIN, P_VMAX_DEFAULT, P_VEL_SCALE, P_D_SAFE, P_D_INFL, P_XI, P_COM_MARGIN, P_CONTACT_ON, P_CONTACT_OFF,
  P_PREVIEW, P_EXCLUDE_TREE, P_CAPSULE_COVER, P_LIMIT_TOL, P_AT_LIMIT_TOL, P_SCALE, P_EN_COLL, P_EN_COM, P_EN_STANCE, P_EN_LIMITS,
  P_REANCHOR_DIST, P_REANCHOR_YAW, P_SOLE_TOL, P_DELTA_GAIN, P_SOLE_MAX, P_CAPSULE_SHRINK, P_CAPSULE_GRID, P_CAPSULE_MINLEN, P_MAX_COLL, P_EN_ZMP, P_ZMP_MARGIN, P_N
};
const Param kDefaults[P_N] = {
  {"dt", 1.0 / 30}, {"iterations", 3}, {"w_posture", 1.0}, {"w_hand", 2.0}, {"w_foot", 3.0}, {"w_foot_rot", 1.0},
  {"w_stance", 30.0}, {"w_stance_rot", 10.0}, {"w_root_rot", 2.0}, {"w_root_pos", 0.5}, {"w_reg", 1e-3}, {"w_slack", 1e6},
  {"joint_margin", 0.035}, {"vmax_default", 8.0}, {"vel_scale", 1.0}, {"d_safe", 0.01}, {"d_influence", 0.15}, {"xi", 0.5},
  {"com_margin", 0.04}, {"contact_on", 0.04}, {"contact_off", 0.08}, {"preview", 8}, {"exclude_tree", 2}, {"capsule_cover", 0.8},
  {"limit_tol", 0.0017}, {"at_limit_tol", 0.0087}, {"scale", 0}, {"collision", 1}, {"com", 1}, {"stance", 1}, {"limits", 1},
  {"reanchor_dist", 0.3}, {"reanchor_yaw", 0.5}, {"sole_tol", 0.02}, {"delta_gain", 0.2}, {"sole_max", 8}, {"capsule_shrink", 0.0}, {"capsule_grid", 2}, {"capsule_min_len", 0.15}, {"max_collision_rows", 24}, {"zmp", 0}, {"zmp_margin", 0.0},
};

}  // namespace

struct WbQP {
  std::vector<Link> links;
  std::vector<Joint> joints;
  std::vector<Capsule> caps;
  std::vector<std::pair<int, int>> pairs;          // カプセルの番号の組
  std::vector<std::pair<int, int>> excluded;       // リンクの番号の組 (使う人が足したもの)
  Hand hands[2];
  Foot feet[2];
  double prm[P_N];
  bool finalized = false;
  double L = 0.3, totalMass = 0;
  // コマの間の状態
  bool hasPrev = false;
  std::vector<double> qPrev;
  Pose rootPrev;
  bool anchored[2] = {false, false};
  Pose anchor[2];
  double delta[2] = {0, 0};
  int prevContact = 0;
  V3 comHist[2];        // 前のコマ, その前のコマの答えの重心
  int nComHist = 0;
  GIQP qp;
  WbQP() { for (int i = 0; i < P_N; i++) prm[i] = kDefaults[i].value; }
  double P(int i) const { return prm[i]; }
};

namespace {

// MARK: - 順運動学・ヤコビアン

void fk(const WbQP &h, const double *q, const Pose &root, std::vector<Pose> &W) {
  W.resize(h.links.size());
  for (size_t i = 0; i < h.links.size(); i++) {
    const Link &l = h.links[i];
    if (l.parent < 0) { W[i] = root; continue; }
    Pose local = l.rest;
    if (l.joint >= 0) {
      const Joint &j = h.joints[l.joint];
      if (j.type == 1) local.p = local.p + local.R * (j.axis * q[l.joint]);
      else local.R = local.R * rotAxis(j.axis, q[l.joint]);
    }
    W[i] = W[l.parent] * local;
  }
}

int rootLink(const WbQP &h) { for (size_t i = 0; i < h.links.size(); i++) if (h.links[i].parent < 0) return (int)i; return 0; }

/// 点 p (ワールド, link に固定) の位置のヤコビアン: 3 行 x nv (列: ルートの並進 3, 回転 3, 関節). out は行優先で加算しない (上書き)
void pointJac(const WbQP &h, const std::vector<Pose> &W, int link, const V3 &p, int nv, double *out) {
  std::memset(out, 0, sizeof(double) * 3 * nv);
  int rl = rootLink(h);
  V3 rp = p - W[rl].p;
  for (int k = 0; k < 3; k++) {
    out[k * nv + k] = 1;
    V3 e; if (k == 0) e = {1, 0, 0}; else if (k == 1) e = {0, 1, 0}; else e = {0, 0, 1};
    V3 c = cross(e, rp);
    out[0 * nv + 3 + k] = c.x; out[1 * nv + 3 + k] = c.y; out[2 * nv + 3 + k] = c.z;
  }
  for (int j : h.links[link].ancJoints) {
    const Joint &jt = h.joints[j];
    const Pose &Wj = W[jt.link];
    V3 a = Wj.R * jt.axis;
    V3 c = jt.type == 1 ? a : cross(a, p - Wj.p);
    out[0 * nv + 6 + j] = c.x; out[1 * nv + 6 + j] = c.y; out[2 * nv + 6 + j] = c.z;
  }
}
/// 回転のヤコビアン (3 行 x nv)
void rotJac(const WbQP &h, const std::vector<Pose> &W, int link, int nv, double *out) {
  std::memset(out, 0, sizeof(double) * 3 * nv);
  for (int k = 0; k < 3; k++) out[k * nv + 3 + k] = 1;
  for (int j : h.links[link].ancJoints) {
    const Joint &jt = h.joints[j];
    if (jt.type == 1) continue;
    V3 a = W[jt.link].R * jt.axis;
    out[0 * nv + 6 + j] = a.x; out[1 * nv + 6 + j] = a.y; out[2 * nv + 6 + j] = a.z;
  }
}

// MARK: - 幾何

/// 2 つの線分の最も近い点 (Ericson, Real-Time Collision Detection 5.1.9 の考え方). s, t は 0..1
double segSeg(const V3 &p1, const V3 &q1, const V3 &p2, const V3 &q2, V3 &c1, V3 &c2) {
  V3 d1 = q1 - p1, d2 = q2 - p2, r = p1 - p2;
  double a = dot(d1, d1), e = dot(d2, d2), f = dot(d2, r), s, t;
  const double eps = 1e-12;
  if (a <= eps && e <= eps) { c1 = p1; c2 = p2; return norm(c1 - c2); }
  if (a <= eps) { s = 0; t = std::clamp(f / e, 0.0, 1.0); }
  else {
    double c = dot(d1, r);
    if (e <= eps) { t = 0; s = std::clamp(-c / a, 0.0, 1.0); }
    else {
      double b = dot(d1, d2), den = a * e - b * b;
      s = den > eps ? std::clamp((b * f - c * e) / den, 0.0, 1.0) : 0;
      t = (b * s + f) / e;
      if (t < 0) { t = 0; s = std::clamp(-c / a, 0.0, 1.0); }
      else if (t > 1) { t = 1; s = std::clamp((b - c) / a, 0.0, 1.0); }
    }
  }
  c1 = p1 + d1 * s; c2 = p2 + d2 * t;
  return norm(c1 - c2);
}

struct P2 { double x, y; };
double cross2(const P2 &o, const P2 &a, const P2 &b) { return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x); }
/// 凸包 (反時計回り, Andrew の方法)
std::vector<P2> hull2(std::vector<P2> p) {
  std::sort(p.begin(), p.end(), [](const P2 &a, const P2 &b) { return a.x < b.x || (a.x == b.x && a.y < b.y); });
  p.erase(std::unique(p.begin(), p.end(), [](const P2 &a, const P2 &b) { return std::fabs(a.x - b.x) < 1e-9 && std::fabs(a.y - b.y) < 1e-9; }), p.end());
  if (p.size() < 3) return p;
  std::vector<P2> hh(2 * p.size());
  size_t k = 0;
  for (size_t i = 0; i < p.size(); i++) { while (k >= 2 && cross2(hh[k - 2], hh[k - 1], p[i]) <= 0) k--; hh[k++] = p[i]; }
  for (size_t i = p.size() - 1, t = k + 1; i > 0; i--) { while (k >= t && cross2(hh[k - 2], hh[k - 1], p[i - 1]) <= 0) k--; hh[k++] = p[i - 1]; }
  hh.resize(k - 1);
  return hh;
}
/// 凸多角形の頂点を max 個まで減らす (いちばん小さい三角形の頂点から消す)
void simplify(std::vector<P2> &h, int maxv) {
  while ((int)h.size() > maxv && h.size() > 3) {
    size_t best = 0; double ba = 1e300;
    for (size_t i = 0; i < h.size(); i++) {
      double a = std::fabs(cross2(h[(i + h.size() - 1) % h.size()], h[i], h[(i + 1) % h.size()]));
      if (a < ba) { ba = a; best = i; }
    }
    h.erase(h.begin() + best);
  }
}
/// 点と凸多角形 (反時計回り) の符号付きの距離 (中が正)
double polyMargin(const std::vector<P2> &h, const P2 &c) {
  if (h.empty()) return std::nan("");
  if (h.size() == 1) return -std::hypot(c.x - h[0].x, c.y - h[0].y);
  bool inside = h.size() >= 3;
  double mind = 1e300, minout = 1e300;
  for (size_t i = 0; i < h.size(); i++) {
    const P2 &a = h[i], &b = h[(i + 1) % h.size()];
    double ex = b.x - a.x, ey = b.y - a.y, len = std::hypot(ex, ey);
    if (len < 1e-12) continue;
    double sd = ((c.x - a.x) * ey - (c.y - a.y) * ex) / len;   // 外向き (右) が正
    if (sd > 0) inside = false;
    mind = std::min(mind, -sd);
    double t = std::clamp(((c.x - a.x) * ex + (c.y - a.y) * ey) / (len * len), 0.0, 1.0);
    minout = std::min(minout, std::hypot(c.x - a.x - t * ex, c.y - a.y - t * ey));
    if (h.size() == 2) break;
  }
  return inside ? mind : -minout;
}

int treeDist(const WbQP &h, int a, int b) {
  int da = 0;
  for (int x = a; x >= 0; x = h.links[x].parent, da++) {
    int db = 0;
    for (int y = b; y >= 0; y = h.links[y].parent, db++) if (x == y) return da + db;
  }
  return 1000;
}

/// 3x3 対称行列の固有ベクトル (ヤコビ法, 固有値の大きい順に列 u[0], u[1], u[2])
void eigSym3(const double S[9], V3 u[3]) {
  double a[9], v[9] = {1, 0, 0, 0, 1, 0, 0, 0, 1};
  std::memcpy(a, S, sizeof(a));
  for (int sweep = 0; sweep < 30; sweep++) {
    double off = a[1] * a[1] + a[2] * a[2] + a[5] * a[5];
    if (off < 1e-24) break;
    for (int p = 0; p < 2; p++) for (int q = p + 1; q < 3; q++) {
      double apq = a[p * 3 + q];
      if (std::fabs(apq) < 1e-30) continue;
      double th = (a[q * 3 + q] - a[p * 3 + p]) / (2 * apq);
      double t = (th >= 0 ? 1 : -1) / (std::fabs(th) + std::sqrt(th * th + 1)), c = 1 / std::sqrt(t * t + 1), s = t * c;
      for (int k = 0; k < 3; k++) {   // a = J^T a J
        double akp = a[k * 3 + p], akq = a[k * 3 + q];
        a[k * 3 + p] = c * akp - s * akq; a[k * 3 + q] = s * akp + c * akq;
      }
      for (int k = 0; k < 3; k++) {
        double apk = a[p * 3 + k], aqk = a[q * 3 + k];
        a[p * 3 + k] = c * apk - s * aqk; a[q * 3 + k] = s * apk + c * aqk;
      }
      for (int k = 0; k < 3; k++) {
        double vkp = v[k * 3 + p], vkq = v[k * 3 + q];
        v[k * 3 + p] = c * vkp - s * vkq; v[k * 3 + q] = s * vkp + c * vkq;
      }
    }
  }
  int idx[3] = {0, 1, 2};
  std::sort(idx, idx + 3, [&](int x, int y) { return a[x * 4] > a[y * 4]; });
  for (int k = 0; k < 3; k++) u[k] = {v[idx[k]], v[3 + idx[k]], v[6 + idx[k]]};
}

double percentile(std::vector<double> a, double f) {
  if (a.empty()) return 0;
  size_t k = std::min(a.size() - 1, (size_t)(f * (a.size() - 1) + 0.5));
  std::nth_element(a.begin(), a.begin() + k, a.end());
  return a[k];
}

/// 頂点からカプセルを作る: 主軸 u0 の向きの線分 + 半径. 断面 (u1, u2 の広がり) が平たい・太いときは
/// 断面を n1 x n2 の升に分け, 升ごとに u0 の向きのカプセルを 1 つ (箱の形に近づける). cover: 半径で覆う頂点の割合
void fitCapsules(const std::vector<V3> &v, int link, double cover, double shrink, int maxGrid, double minLen, std::vector<Capsule> &out) {
  if (v.size() < 4) return;
  V3 m;
  for (auto &p : v) m += p;
  m = m * (1.0 / v.size());
  double S[9] = {0};
  for (auto &p : v) { V3 d = p - m; double a[3] = {d.x, d.y, d.z}; for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) S[i * 3 + j] += a[i] * a[j]; }
  V3 u[3];
  eigSym3(S, u);
  std::vector<double> t[3];
  for (auto &p : v) { V3 d = p - m; for (int k = 0; k < 3; k++) t[k].push_back(dot(d, u[k])); }
  double lo[3], hi[3], e[3];
  for (int k = 0; k < 3; k++) { lo[k] = percentile(t[k], 0.02); hi[k] = percentile(t[k], 0.98); e[k] = std::max(hi[k] - lo[k], 1e-6); }
  // 升の数: 断面 e1 x e2 の箱をカプセルで包むと, 升の対角の半分 r が升の短い辺の半分より出っ張る (o = r - 短い辺 / 2).
  //   小さいリンク (主軸 < minLen) は 1 つ. ほかは o <= 0.3 e2 になる最小の升 (1x1, 2x1, 2x2), なければ o の最も小さいもの
  int n1 = 1, n2 = 1;
  if (maxGrid > 1 && e[0] >= minLen) {
    const int cand[3][2] = {{1, 1}, {2, 1}, {2, 2}};
    double best = 1e300;
    for (auto &cd : cand) {
      if (cd[0] > maxGrid || cd[1] > maxGrid) continue;
      double w = e[1] / cd[0], hh = e[2] / cd[1];
      double o = std::hypot(w / 2, hh / 2) - std::min(w, hh) / 2;
      if (o <= 0.3 * e[2]) { n1 = cd[0]; n2 = cd[1]; break; }
      if (o < best) { best = o; n1 = cd[0]; n2 = cd[1]; }
    }
  }
  for (int a = 0; a < n1; a++) for (int b = 0; b < n2; b++) {
    double c1 = lo[1] + e[1] * (a + 0.5) / n1, c2 = lo[2] + e[2] * (b + 0.5) / n2;
    std::vector<double> ts, rho;
    for (size_t i = 0; i < v.size(); i++) {
      int ia = std::clamp((int)((t[1][i] - lo[1]) / e[1] * n1), 0, n1 - 1), ib = std::clamp((int)((t[2][i] - lo[2]) / e[2] * n2), 0, n2 - 1);
      if (ia != a || ib != b) continue;
      ts.push_back(t[0][i]);
      rho.push_back(std::hypot(t[1][i] - c1, t[2][i] - c2));
    }
    if (ts.size() < 3) continue;
    double r = std::max(percentile(rho, cover) * (1 - shrink), 1e-4);
    double t0 = percentile(ts, 0.02), t1 = percentile(ts, 0.98), len = t1 - t0;
    V3 base = m + u[1] * c1 + u[2] * c2;
    Capsule c; c.link = link;
    if (len <= 2 * r) { c.a = c.b = base + u[0] * ((t0 + t1) / 2); c.r = std::max(r, len / 2); }
    else { c.a = base + u[0] * (t0 + r); c.b = base + u[0] * (t1 - r); c.r = r; }
    out.push_back(c);
  }
}

// MARK: - 評価

struct Scratch {
  std::vector<Pose> W;
};

std::vector<P2> supportPolygon(const WbQP &h, const std::vector<Pose> &W, int mask, const Pose *feetPose) {
  std::vector<P2> pts;
  for (int s = 0; s < 2; s++) {
    if (!(mask & (1 << s)) || h.feet[s].link < 0) continue;
    const Pose &F = feetPose ? feetPose[s] : W[h.feet[s].link];
    for (auto &v : h.feet[s].sole) { V3 w = F.apply(v); pts.push_back({w.x, w.y}); }
  }
  return hull2(pts);
}

V3 comOf(const WbQP &h, const std::vector<Pose> &W) {
  V3 c; double M = 0;
  for (size_t i = 0; i < h.links.size(); i++) { c += W[i].apply(h.links[i].com) * h.links[i].mass; M += h.links[i].mass; }
  return M > 0 ? c * (1 / M) : c;
}

double footHeight(const WbQP &h, const std::vector<Pose> &W, int s) {
  if (h.feet[s].link < 0) return 1e9;
  double z = 1e9;
  for (auto &v : h.feet[s].sole) z = std::min(z, W[h.feet[s].link].apply(v).z);
  return z;
}

void evaluate(const WbQP &h, const double *q, const std::vector<Pose> &W, int support, WbqpEval *ev, int *flags, std::vector<P2> *polyOut) {
  WbqpEval e;
  std::memset(&e, 0, sizeof(e));
  e.min_dist = 1e9; e.pair[0] = e.pair[1] = -1;
  if (flags) for (size_t i = 0; i < h.links.size(); i++) flags[i] = 0;
  double ds = h.P(P_D_SAFE) * h.L;
  for (auto &pr : h.pairs) {
    const Capsule &a = h.caps[pr.first], &b = h.caps[pr.second];
    V3 c1, c2;
    double d = segSeg(W[a.link].apply(a.a), W[a.link].apply(a.b), W[b.link].apply(b.a), W[b.link].apply(b.b), c1, c2) - a.r - b.r;
    if (d < e.min_dist) { e.min_dist = d; e.pair[0] = a.link; e.pair[1] = b.link; }
    if (d < 0) { e.n_collide++; if (flags) { flags[a.link] |= 1; flags[b.link] |= 1; } }
    else if (d < ds && flags) { flags[a.link] |= 4; flags[b.link] |= 4; }
  }
  for (size_t j = 0; j < h.joints.size(); j++) {
    const Joint &jt = h.joints[j];
    double ex = std::max(jt.lo - q[j], q[j] - jt.hi);
    if (ex > h.P(P_LIMIT_TOL)) e.n_limit++;
    if (ex > 0) e.max_limit_excess = std::max(e.max_limit_excess, ex);
    if (ex > -h.P(P_AT_LIMIT_TOL)) { e.n_at_limit++; if (flags) flags[jt.link] |= 2; }
  }
  V3 c = comOf(h, W);
  e.com[0] = c.x; e.com[1] = c.y; e.com[2] = c.z;
  for (int s = 0; s < 2; s++) e.foot_height[s] = footHeight(h, W, s);
  if (support < 0) {
    support = 0;
    for (int s = 0; s < 2; s++) if (e.foot_height[s] < h.P(P_CONTACT_ON) * h.L) support |= 1 << s;
  }
  std::vector<P2> poly = supportPolygon(h, W, support, nullptr);
  e.com_margin = poly.empty() ? std::nan("") : polyMargin(poly, {c.x, c.y});
  if (polyOut) *polyOut = poly;
  *ev = e;
}

/// 足の向きを水平にした姿勢 (向き = 今の足の水平の向き, 高さ = 裏が床)
Pose flatFoot(const WbQP &h, int s, const Pose &F) {
  const Foot &f = h.feet[s];
  M3 rel = F.R * f.flat.T();
  Pose P;
  P.R = rotZ(yawOf(rel)) * f.flat;
  P.p = F.p;
  double zmin = 1e9;
  for (auto &v : f.sole) zmin = std::min(zmin, (P.R * v).z);
  P.p.z = -zmin;
  return P;
}

}  // namespace

// MARK: - C API: モデル

extern "C" {

WbQP *wbqp_create(void) { return new WbQP(); }
void wbqp_destroy(WbQP *h) { delete h; }

int wbqp_add_link(WbQP *h, int parent, const double rest[12]) {
  Link l;
  l.parent = parent;
  l.rest = Pose::from12(rest);
  h->links.push_back(l);
  h->finalized = false;
  return (int)h->links.size() - 1;
}

void wbqp_add_link_vertices(WbQP *h, int link, const float *xyz, int nv) {
  if (link < 0 || link >= (int)h->links.size()) return;
  auto &v = h->links[link].verts;
  for (int i = 0; i < nv; i++) v.push_back({xyz[i * 3], xyz[i * 3 + 1], xyz[i * 3 + 2]});
}

void wbqp_set_link_mass(WbQP *h, int link, double mass, const double com[3]) {
  if (link < 0 || link >= (int)h->links.size()) return;
  h->links[link].mass = mass;
  h->links[link].com = {com[0], com[1], com[2]};
}

int wbqp_add_joint(WbQP *h, int link, int type, const double axis[3], double lo, double hi, double vmax) {
  if (link < 0 || link >= (int)h->links.size()) return -1;
  Joint j;
  j.link = link; j.type = type;
  V3 a(axis[0], axis[1], axis[2]);
  double n = norm(a);
  j.axis = n > 0 ? a * (1 / n) : V3(0, 0, 1);
  j.lo = std::min(lo, hi); j.hi = std::max(lo, hi); j.vmax = vmax;
  h->joints.push_back(j);
  h->links[link].joint = (int)h->joints.size() - 1;
  h->finalized = false;
  return (int)h->joints.size() - 1;
}

int wbqp_add_capsule(WbQP *h, int link, const double p0[3], const double p1[3], double radius) {
  if (link < 0 || link >= (int)h->links.size()) return -1;
  if (radius <= 0) { h->links[link].noCollision = true; return -1; }
  h->caps.push_back({link, {p0[0], p0[1], p0[2]}, {p1[0], p1[1], p1[2]}, radius});
  h->links[link].ncaps++;
  return (int)h->caps.size() - 1;
}

void wbqp_set_hand(WbQP *h, int side, int link, const double offset[3]) {
  if (side < 0 || side > 1) return;
  h->hands[side].link = link;
  h->hands[side].off = offset ? V3(offset[0], offset[1], offset[2]) : V3();
}

void wbqp_set_foot(WbQP *h, int side, int link) { if (side >= 0 && side <= 1) h->feet[side].link = link; }

void wbqp_exclude_pair(WbQP *h, int a, int b) { h->excluded.push_back({std::min(a, b), std::max(a, b)}); }

static int paramIndex(const char *name) {
  for (int i = 0; i < P_N; i++) if (std::strcmp(kDefaults[i].name, name) == 0) return i;
  return -1;
}
int wbqp_set_param(WbQP *h, const char *name, double value) { int i = paramIndex(name); if (i < 0) return 0; h->prm[i] = value; return 1; }
double wbqp_get_param(WbQP *h, const char *name) {
  if (std::strcmp(name, "scale") == 0) return h->L;
  int i = paramIndex(name); return i < 0 ? std::nan("") : h->prm[i];
}

int wbqp_finalize(WbQP *h, const double *poses, int n) {
  const size_t nl = h->links.size(), nj = h->joints.size();
  // 木の深さと, 根元までの関節
  for (size_t i = 0; i < nl; i++) {
    Link &l = h->links[i];
    if (l.parent >= (int)i) return -1;   // 根元から順でない
    l.depth = l.parent < 0 ? 0 : h->links[l.parent].depth + 1;
    l.ancJoints.clear();
    for (int x = (int)i; x >= 0; x = h->links[x].parent) if (h->links[x].joint >= 0) l.ancJoints.push_back(h->links[x].joint);
  }
  // 質量 (なければ頂点の外接箱 × 400 kg/m^3, PhysicsSim.massProps と同じ)
  h->totalMass = 0;
  for (auto &l : h->links) {
    if (l.mass < 0) {
      if (l.verts.empty()) { l.mass = 0.005; l.com = {}; }
      else {
        V3 lo(1e9, 1e9, 1e9), hi(-1e9, -1e9, -1e9);
        for (auto &v : l.verts) { lo = {std::min(lo.x, v.x), std::min(lo.y, v.y), std::min(lo.z, v.z)}; hi = {std::max(hi.x, v.x), std::max(hi.y, v.y), std::max(hi.z, v.z)}; }
        V3 s = hi - lo;
        l.mass = std::max(0.005, s.x * s.y * s.z * 400);
        l.com = (hi + lo) * 0.5;
      }
    }
    h->totalMass += l.mass;
  }
  // 関節角 0 の姿勢
  std::vector<double> q0(nj, 0);
  std::vector<Pose> W;
  fk(*h, q0.data(), Pose(), W);
  // 足の裏: いちばん低い頂点から sole_tol · (大きさ) 以内の点の凸包
  double zfoot = 1e9;
  for (int s = 0; s < 2; s++) {
    Foot &f = h->feet[s];
    if (f.link < 0) continue;
    for (auto &v : h->links[f.link].verts) zfoot = std::min(zfoot, W[f.link].apply(v).z);
  }
  int rl = rootLink(*h);
  if (h->P(P_SCALE) > 0) h->L = h->P(P_SCALE);
  else h->L = zfoot < 1e8 && W[rl].p.z - zfoot > 0.02 ? W[rl].p.z - zfoot : 0.3;
  for (int s = 0; s < 2; s++) {
    Foot &f = h->feet[s];
    f.sole.clear();
    if (f.link < 0) continue;
    const Pose &F = W[f.link];
    f.flat = F.R;
    double zmin = 1e9;
    for (auto &v : h->links[f.link].verts) zmin = std::min(zmin, F.apply(v).z);
    std::vector<P2> pts;
    for (auto &v : h->links[f.link].verts) { V3 w = F.apply(v); if (w.z < zmin + h->P(P_SOLE_TOL) * h->L) pts.push_back({w.x, w.y}); }
    if (pts.empty()) { V3 w = F.p; pts.push_back({w.x, w.y}); zmin = w.z; }
    std::vector<P2> hl = hull2(pts);
    simplify(hl, (int)h->P(P_SOLE_MAX));
    Pose Fi = F.inv();
    for (auto &p : hl) f.sole.push_back(Fi.apply({p.x, p.y, zmin}));
  }
  // カプセル: 足していないリンクは頂点から 1 つ
  std::vector<Capsule> auto_;
  for (size_t i = 0; i < nl; i++) {
    Link &l = h->links[i];
    if (l.ncaps > 0 || l.noCollision) continue;
    fitCapsules(l.verts, (int)i, h->P(P_CAPSULE_COVER), h->P(P_CAPSULE_SHRINK), (int)h->P(P_CAPSULE_GRID), h->P(P_CAPSULE_MINLEN) * h->L, auto_);
  }
  // 手で足したものを残し, 自動のものを後ろに
  std::vector<Capsule> manual;
  for (auto &c : h->caps) if (h->links[c.link].ncaps > 0) manual.push_back(c);
  h->caps = manual;
  h->caps.insert(h->caps.end(), auto_.begin(), auto_.end());
  // 調べる組: 木で exclude_tree より遠く, 与えた姿勢で当たっておらず, 使う人が外していないもの
  h->pairs.clear();
  std::vector<std::vector<double>> ps;
  ps.push_back(q0);
  for (int k = 0; k < n; k++) ps.push_back(std::vector<double>(poses + k * nj, poses + (k + 1) * nj));
  std::vector<std::vector<Pose>> Ws;
  for (auto &qq : ps) { std::vector<Pose> w; fk(*h, qq.data(), Pose(), w); Ws.push_back(w); }
  double ds = h->P(P_D_SAFE) * h->L;
  for (size_t a = 0; a < h->caps.size(); a++) {
    for (size_t b = a + 1; b < h->caps.size(); b++) {
      int la = h->caps[a].link, lb = h->caps[b].link;
      if (la == lb || treeDist(*h, la, lb) <= (int)h->P(P_EXCLUDE_TREE)) continue;
      bool ex = false;
      for (auto &e : h->excluded) if (e.first == std::min(la, lb) && e.second == std::max(la, lb)) ex = true;
      if (ex) continue;
      bool hit = false;
      for (auto &w : Ws) {
        const Capsule &A = h->caps[a], &B = h->caps[b];
        V3 c1, c2;
        double d = segSeg(w[la].apply(A.a), w[la].apply(A.b), w[lb].apply(B.a), w[lb].apply(B.b), c1, c2) - A.r - B.r;
        if (d < ds) { hit = true; break; }
      }
      if (!hit) h->pairs.push_back({(int)a, (int)b});
    }
  }
  h->finalized = true;
  wbqp_reset(h);
  return (int)h->pairs.size();
}

int wbqp_num_links(WbQP *h) { return (int)h->links.size(); }
int wbqp_num_joints(WbQP *h) { return (int)h->joints.size(); }
int wbqp_num_capsules(WbQP *h) { return (int)h->caps.size(); }
void wbqp_capsule(WbQP *h, int i, int *link, double p0[3], double p1[3], double *radius) {
  const Capsule &c = h->caps[i];
  *link = c.link; p0[0] = c.a.x; p0[1] = c.a.y; p0[2] = c.a.z; p1[0] = c.b.x; p1[1] = c.b.y; p1[2] = c.b.z; *radius = c.r;
}
int wbqp_num_pairs(WbQP *h) { return (int)h->pairs.size(); }
void wbqp_pair(WbQP *h, int i, int *a, int *b) { *a = h->caps[h->pairs[i].first].link; *b = h->caps[h->pairs[i].second].link; }
int wbqp_sole(WbQP *h, int side, double *xyz, int max) {
  if (side < 0 || side > 1) return 0;
  int k = 0;
  for (auto &v : h->feet[side].sole) { if (k >= max) break; xyz[k * 3] = v.x; xyz[k * 3 + 1] = v.y; xyz[k * 3 + 2] = v.z; k++; }
  return (int)h->feet[side].sole.size();
}
double wbqp_total_mass(WbQP *h) { return h->totalMass; }

void wbqp_fk(WbQP *h, const double *q, const double root[12], double *poses) {
  std::vector<Pose> W;
  fk(*h, q, Pose::from12(root), W);
  for (size_t i = 0; i < W.size(); i++) W[i].to12(poses + i * 12);
}

int wbqp_eval(WbQP *h, const double *q, const double root[12], int support, WbqpEval *ev, int *flags, double *poly, int max) {
  std::vector<Pose> W;
  fk(*h, q, Pose::from12(root), W);
  std::vector<P2> pl;
  WbqpEval e;
  evaluate(*h, q, W, support, &e, flags, &pl);
  if (ev) *ev = e;
  if (poly) for (int i = 0; i < (int)pl.size() && i < max; i++) { poly[i * 2] = pl[i].x; poly[i * 2 + 1] = pl[i].y; }
  return (int)pl.size();
}

void wbqp_reset(WbQP *h) {
  h->hasPrev = false;
  h->anchored[0] = h->anchored[1] = false;
  h->delta[0] = h->delta[1] = 0;
  h->prevContact = 0;
  h->nComHist = 0;
}

int wbqp_contact_of(WbQP *h, const double *q_ref, const double root_ref[12], int prev) {
  std::vector<Pose> W;
  fk(*h, q_ref, Pose::from12(root_ref), W);
  int m = 0;
  for (int s = 0; s < 2; s++) {
    if (h->feet[s].link < 0) continue;
    double z = footHeight(*h, W, s);
    double th = ((prev >> s) & 1) ? h->P(P_CONTACT_OFF) : h->P(P_CONTACT_ON);
    if (z < th * h->L) m |= 1 << s;
  }
  return m;
}

void wbqp_plan_contacts(WbQP *h, int n, const double *q_ref, const double *root_ref, int *contact, int *support) {
  int nj = (int)h->joints.size(), prev = 0;
  for (int i = 0; i < n; i++) { prev = wbqp_contact_of(h, q_ref + (size_t)i * nj, root_ref + (size_t)i * 12, prev); contact[i] = prev; }
  int P = std::max(0, (int)h->P(P_PREVIEW));
  for (int i = 0; i < n; i++) {
    int s = contact[i];
    for (int k = i + 1; k <= std::min(n - 1, i + P); k++) {   // この先で離れる足を先に外す (全部外れるなら手前で止める)
      int t = s & contact[k];
      if (t == 0) break;
      s = t;
    }
    support[i] = s;
  }
}

// MARK: - コマごとの QP

int wbqp_solve(WbQP *h, const double *q_ref, const double root_ref[12], int contact, int support,
               const double *targets, double *q_out, double root_out[12], WbqpDiag *diag) {
  auto t0 = std::chrono::steady_clock::now();
  WbqpDiag dg;
  std::memset(&dg, 0, sizeof(dg));
  const int nj = (int)h->joints.size(), nv0 = 6 + nj;
  const double L = h->L;
  Pose rootRef = Pose::from12(root_ref);
  std::vector<Pose> Wr;
  fk(*h, q_ref, rootRef, Wr);
  if (contact < 0) contact = wbqp_contact_of(h, q_ref, root_ref, h->prevContact);
  if (support < 0) support = contact;
  support &= contact;
  h->prevContact = contact;
  dg.contact = contact; dg.support = support;
  evaluate(*h, q_ref, Wr, contact, &dg.before, nullptr, nullptr);
  // 手足の目標 (参照の順運動学か与えたもの)
  Pose tgt[4];
  for (int s = 0; s < 2; s++) {
    if (targets) { tgt[s] = Pose::from12(targets + s * 12); tgt[2 + s] = Pose::from12(targets + (2 + s) * 12); }
    else {
      if (h->hands[s].link >= 0) { tgt[s] = Wr[h->hands[s].link]; tgt[s].p = Wr[h->hands[s].link].apply(h->hands[s].off); }
      if (h->feet[s].link >= 0) tgt[2 + s] = Wr[h->feet[s].link];
    }
  }
  // 床に着いた足を止める (anchor). 参照の足が止めた所から大きく離れたら (すべり・その場で回る) 置き直す
  bool stance = h->P(P_EN_STANCE) > 0;
  double dnew[2] = {0, 0}; int na = 0;
  for (int s = 0; s < 2; s++) {
    if (h->feet[s].link < 0) continue;
    if (!stance || !(contact & (1 << s))) { h->anchored[s] = false; continue; }
    Pose cand = tgt[2 + s];
    cand.p.x += h->delta[0]; cand.p.y += h->delta[1];
    cand = flatFoot(*h, s, cand);
    if (!h->anchored[s]) { h->anchor[s] = cand; h->anchored[s] = true; }
    else {
      double dp = std::hypot(cand.p.x - h->anchor[s].p.x, cand.p.y - h->anchor[s].p.y);
      double dy = std::fabs(logR(cand.R * h->anchor[s].R.T()).z);
      if (dp > h->P(P_REANCHOR_DIST) * L || dy > h->P(P_REANCHOR_YAW)) h->anchor[s] = cand;
    }
    dnew[0] += h->anchor[s].p.x - tgt[2 + s].p.x; dnew[1] += h->anchor[s].p.y - tgt[2 + s].p.y; na++;
  }
  if (na > 0) {
    double g = h->hasPrev ? h->P(P_DELTA_GAIN) : 1;
    for (int k = 0; k < 2; k++) h->delta[k] += g * (dnew[k] / na - h->delta[k]);
  }
  for (int k = 0; k < 4; k++) { tgt[k].p.x += h->delta[0]; tgt[k].p.y += h->delta[1]; }
  Pose rootTgt = rootRef;
  rootTgt.p.x += h->delta[0]; rootTgt.p.y += h->delta[1];
  // 始める姿勢: 前のコマの答え (初めは参照)
  std::vector<double> q(nj);
  Pose root;
  if (h->hasPrev) { q = h->qPrev; root = h->rootPrev; }
  else { for (int j = 0; j < nj; j++) q[j] = q_ref[j]; root = rootTgt; }
  const double dt = h->P(P_DT), margin = h->P(P_JOINT_MARGIN);
  const double ds = h->P(P_D_SAFE) * L, di = h->P(P_D_INFL) * L, xi = h->P(P_XI);
  std::vector<Pose> W;
  std::vector<double> Hm, g, C, c, x, Jt(3 * nv0), Jr(3 * nv0), Jc(3 * nv0);
  int iters = std::max(1, (int)h->P(P_ITER));
  int status = 1;
  for (int it = 0; it < iters; it++) {
    fk(*h, q.data(), root, W);
    // 衝突の候補 (影響の距離より近い組)
    struct CollRow { int pa; V3 ca, cb, n; double d; int la, lb; };
    std::vector<CollRow> coll;
    if (h->P(P_EN_COLL) > 0) {
      for (auto &pr : h->pairs) {
        const Capsule &A = h->caps[pr.first], &B = h->caps[pr.second];
        V3 c1, c2;
        double dist = segSeg(W[A.link].apply(A.a), W[A.link].apply(A.b), W[B.link].apply(B.a), W[B.link].apply(B.b), c1, c2);
        double d = dist - A.r - B.r;
        if (d >= di) continue;
        V3 nn = c1 - c2;
        if (dist < 1e-9) { nn = W[A.link].apply((A.a + A.b) * 0.5) - W[B.link].apply((B.a + B.b) * 0.5); }
        double nl = norm(nn);
        nn = nl > 1e-12 ? nn * (1 / nl) : V3(0, 0, 1);
        coll.push_back({0, c1, c2, nn, d, A.link, B.link});
      }
      // リンクの組ごとにいちばん近いカプセルの組だけ, 近い順に max_collision_rows まで
      std::sort(coll.begin(), coll.end(), [](const CollRow &a, const CollRow &b) { return a.d < b.d; });
      std::vector<CollRow> kept;
      for (auto &cr : coll) {
        bool dup = false;
        for (auto &k : kept) if ((k.la == cr.la && k.lb == cr.lb) || (k.la == cr.lb && k.lb == cr.la)) { dup = true; break; }
        if (!dup) kept.push_back(cr);
        if ((int)kept.size() >= (int)h->P(P_MAX_COLL)) break;
      }
      coll.swap(kept);
    }
    // 支持多角形 (止めた足の位置で)
    std::vector<P2> poly;
    bool useCom = h->P(P_EN_COM) > 0 && support != 0;
    if (useCom) {
      Pose fp[2];
      for (int s = 0; s < 2; s++) if (h->feet[s].link >= 0) fp[s] = h->anchored[s] ? h->anchor[s] : W[h->feet[s].link];
      poly = supportPolygon(*h, W, support, fp);
      if (poly.empty()) useCom = false;
    }
    const int ncoll = (int)coll.size();
    const bool useZmp = useCom && h->P(P_EN_ZMP) > 0 && h->nComHist >= 2;
    const int nslack = ncoll + (useCom ? 1 : 0) + (useZmp ? 1 : 0);
    const int nv = nv0 + nslack;
    Hm.assign(nv * nv, 0); g.assign(nv, 0);
    auto addRows = [&](const double *J, const double *e, int rows, double w) {   // w^2 |J x - e|^2
      double w2 = w * w;
      for (int r = 0; r < rows; r++) {
        const double *jr = J + r * nv0;
        for (int a = 0; a < nv0; a++) {
          if (jr[a] == 0) continue;
          g[a] -= w2 * jr[a] * e[r];
          for (int b = 0; b < nv0; b++) if (jr[b] != 0) Hm[a * nv + b] += w2 * jr[a] * jr[b];
        }
      }
    };
    // 関節角を参照に
    for (int j = 0; j < nj; j++) { double w2 = h->P(P_W_POSTURE) * h->P(P_W_POSTURE); Hm[(6 + j) * nv + 6 + j] += w2; g[6 + j] -= w2 * (q_ref[j] - q[j]); }
    // ルートの向きと位置
    {
      V3 er = logR(rootTgt.R * root.R.T());
      double e3[3] = {er.x, er.y, er.z};
      std::fill(Jr.begin(), Jr.end(), 0.0);
      for (int k = 0; k < 3; k++) Jr[k * nv0 + 3 + k] = 1;
      addRows(Jr.data(), e3, 3, h->P(P_W_ROOT_ROT));
      V3 ep = (rootTgt.p - root.p) * (1 / L);
      double p3[3] = {ep.x, ep.y, ep.z};
      std::fill(Jt.begin(), Jt.end(), 0.0);
      for (int k = 0; k < 3; k++) Jt[k * nv0 + k] = 1 / L;
      addRows(Jt.data(), p3, 3, h->P(P_W_ROOT_POS));
    }
    // 手 (位置)
    for (int s = 0; s < 2; s++) {
      const Hand &hd = h->hands[s];
      if (hd.link < 0) continue;
      V3 p = W[hd.link].apply(hd.off);
      pointJac(*h, W, hd.link, p, nv0, Jt.data());
      for (auto &v : Jt) v /= L;
      V3 e = (tgt[s].p - p) * (1 / L);
      double e3[3] = {e.x, e.y, e.z};
      addRows(Jt.data(), e3, 3, h->P(P_W_HAND));
    }
    // 足 (位置と向き). 止めた足は強く
    for (int s = 0; s < 2; s++) {
      const Foot &f = h->feet[s];
      if (f.link < 0) continue;
      bool st = h->anchored[s];
      const Pose &T = st ? h->anchor[s] : tgt[2 + s];
      const Pose &F = W[f.link];
      pointJac(*h, W, f.link, F.p, nv0, Jt.data());
      for (auto &v : Jt) v /= L;
      V3 e = (T.p - F.p) * (1 / L);
      double e3[3] = {e.x, e.y, e.z};
      addRows(Jt.data(), e3, 3, st ? h->P(P_W_STANCE) : h->P(P_W_FOOT));
      rotJac(*h, W, f.link, nv0, Jr.data());
      V3 er = logR(T.R * F.R.T());
      double r3[3] = {er.x, er.y, er.z};
      addRows(Jr.data(), r3, 3, st ? h->P(P_W_STANCE_ROT) : h->P(P_W_FOOT_ROT));
    }
    for (int a = 0; a < nv0; a++) Hm[a * nv + a] += h->P(P_W_REG);
    for (int k = 0; k < nslack; k++) Hm[(nv0 + k) * nv + nv0 + k] += h->P(P_W_SLACK);
    // 制約 C x >= c
    C.clear(); c.clear();
    auto row = [&]() -> double * { C.resize(C.size() + nv, 0.0); c.push_back(0); return &C[C.size() - nv]; };
    // 関節の可動範囲 (余裕つき) と速さ
    for (int j = 0; j < nj; j++) {
      const Joint &jt = h->joints[j];
      double lo = -1e9, hi = 1e9;
      if (h->P(P_EN_LIMITS) > 0) {
        lo = jt.lo + margin; hi = jt.hi - margin;
        if (lo > hi) lo = hi = (jt.lo + jt.hi) / 2;
      }
      double lb = lo - q[j], ub = hi - q[j];
      if (h->hasPrev) {
        double v = (jt.vmax > 0 ? jt.vmax : h->P(P_VMAX_DEFAULT)) * h->P(P_VEL_SCALE) * dt;
        double vlo = h->qPrev[j] - v - q[j], vhi = h->qPrev[j] + v - q[j];
        if (vhi < lb) lb = ub = vhi;
        else if (vlo > ub) lb = ub = vlo;
        else { lb = std::max(lb, vlo); ub = std::min(ub, vhi); }
      }
      if (ub - lb < 1e-7) lb = ub - 1e-7;
      double *r1 = row(); r1[6 + j] = 1; c.back() = lb;
      double *r2 = row(); r2[6 + j] = -1; c.back() = -ub;
    }
    // 足の裏は床より上
    for (int s = 0; s < 2; s++) {
      const Foot &f = h->feet[s];
      if (f.link < 0) continue;
      for (auto &v : f.sole) {
        V3 p = W[f.link].apply(v);
        pointJac(*h, W, f.link, p, nv0, Jt.data());
        double *r = row();
        for (int a = 0; a < nv0; a++) r[a] = Jt[2 * nv0 + a];
        c.back() = -p.z;
      }
    }
    // 自己衝突 (速度ダンパ): n^T (J_a - J_b) x + s >= -xi (d - d_s)
    for (int k = 0; k < ncoll; k++) {
      const CollRow &cr = coll[k];
      double *r = row();
      pointJac(*h, W, cr.la, cr.ca, nv0, Jt.data());
      pointJac(*h, W, cr.lb, cr.cb, nv0, Jc.data());
      for (int a = 0; a < nv0; a++) r[a] = (cr.n.x * (Jt[a] - Jc[a]) + cr.n.y * (Jt[nv0 + a] - Jc[nv0 + a]) + cr.n.z * (Jt[2 * nv0 + a] - Jc[2 * nv0 + a])) / L;
      r[nv0 + k] = 1;
      c.back() = -xi * (cr.d - ds) / L;
    }
    // 重心: 支持多角形の各辺 (内側に com_margin 縮める) m^T (c + J x) <= b - margin
    if (useCom) {
      std::fill(Jc.begin(), Jc.end(), 0.0);
      double M = 0;
      for (size_t i = 0; i < h->links.size(); i++) {
        const Link &l = h->links[i];
        if (l.mass <= 0) continue;
        pointJac(*h, W, (int)i, W[i].apply(l.com), nv0, Jt.data());
        for (int a = 0; a < 3 * nv0; a++) Jc[a] += l.mass * Jt[a];
        M += l.mass;
      }
      for (auto &v : Jc) v /= M;
      V3 cm = comOf(*h, W);
      // 縮める量: 多角形の中心から辺までの最小の距離の 4 割まで
      P2 ctr{0, 0};
      for (auto &p : poly) { ctr.x += p.x; ctr.y += p.y; }
      ctr.x /= poly.size(); ctr.y /= poly.size();
      double inr = poly.size() >= 3 ? std::max(0.0, polyMargin(poly, ctr)) : 0;
      double mg = std::min(h->P(P_COM_MARGIN) * L, 0.4 * inr);
      size_t ne = poly.size() >= 3 ? poly.size() : (poly.size() == 2 ? 2 : 0);
      for (size_t i = 0; i < ne; i++) {
        const P2 &a = poly[i], &b = poly[(i + 1) % poly.size()];
        double ex = b.x - a.x, ey = b.y - a.y, len = std::hypot(ex, ey);
        if (len < 1e-9) continue;
        double mx = ey / len, my = -ex / len;            // 外向きの法線 (反時計回り)
        double bb = mx * a.x + my * a.y;
        double *r = row();
        for (int k = 0; k < nv0; k++) r[k] = -(mx * Jc[k] + my * Jc[nv0 + k]) / L;
        r[nv0 + ncoll] = 1;
        c.back() = (mx * cm.x + my * cm.y - bb + mg) / L;
        // ZMP (台車の模型): p = c - (z_c / g) c'',  c'' = (c_new - 2 c_1 + c_2) / dt^2,  c_new = c + J x
        //   m^T p <= b - zmp_margin  →  -(1 - k) m^T J x >= (1 - k) m^T c + k m^T (2 c_1 - c_2) - b + margin,  k = z_c / (g dt^2)
        if (useZmp) {
          double k = std::max(0.0, cm.z) / (9.81 * dt * dt);
          V3 c1 = h->comHist[0], c2 = h->comHist[1];
          double *z = row();
          for (int kk = 0; kk < nv0; kk++) z[kk] = -(1 - k) * (mx * Jc[kk] + my * Jc[nv0 + kk]) / L;
          z[nv0 + ncoll + 1] = 1;
          c.back() = ((1 - k) * (mx * cm.x + my * cm.y) + k * (mx * (2 * c1.x - c2.x) + my * (2 * c1.y - c2.y)) - bb + h->P(P_ZMP_MARGIN) * L) / L;
        }
      }
      if (poly.size() == 1) {   // 1 点: その点に近づける (x, y の両方の向き)
        for (int sgn = -1; sgn <= 1; sgn += 2) for (int ax = 0; ax < 2; ax++) {
          double *r = row();
          for (int k = 0; k < nv0; k++) r[k] = -sgn * Jc[ax * nv0 + k] / L;
          r[nv0 + ncoll] = 1;
          c.back() = sgn * ((ax == 0 ? cm.x - poly[0].x : cm.y - poly[0].y)) / L;
        }
      }
    }
    // 緩める量は 0 以上
    for (int k = 0; k < nslack; k++) { double *r = row(); r[nv0 + k] = 1; c.back() = 0; }
    const int m = (int)c.size();
    dg.n_constraints = m; dg.n_collision_rows = ncoll;
    int qpit = 0;
    int st = h->qp.solve(nv, Hm, g, m, C, c, x, 20 * (m + nv), qpit);
    dg.qp_iters += qpit;
    dg.sqp_iters = it + 1;
    if (st < 0) { status = -1; break; }
    double slack = 0;
    for (int k = 0; k < nslack; k++) slack = std::max(slack, x[nv0 + k] * L);
    dg.slack_max = slack;
    // 進める
    double step = 0;
    root.p = root.p + V3(x[0], x[1], x[2]);
    root.R = orthonormalize(expw({x[3], x[4], x[5]}) * root.R);
    for (int j = 0; j < nj; j++) { q[j] += x[6 + j]; step = std::max(step, std::fabs(x[6 + j])); }
    step = std::max(step, std::max(std::fabs(x[3]), std::max(std::fabs(x[4]), std::fabs(x[5]))));
    step = std::max(step, std::max(std::fabs(x[0]), std::max(std::fabs(x[1]), std::fabs(x[2]))) / L);
    if (step < 1e-4) { status = 0; break; }
    if (it == iters - 1) status = 0;   // 決めた回数を回した (いつもこの終わり方)
  }
  if (status < 0) {
    if (h->hasPrev) { q = h->qPrev; root = h->rootPrev; } else { for (int j = 0; j < nj; j++) q[j] = q_ref[j]; root = rootTgt; }
  }
  for (int j = 0; j < nj; j++) q[j] = std::clamp(q[j], h->joints[j].lo, h->joints[j].hi);
  h->qPrev = q; h->rootPrev = root; h->hasPrev = true;
  for (int j = 0; j < nj; j++) q_out[j] = q[j];
  root.to12(root_out);
  fk(*h, q.data(), root, W);
  evaluate(*h, q.data(), W, contact, &dg.after, nullptr, nullptr);
  h->comHist[1] = h->comHist[0];
  h->comHist[0] = V3(dg.after.com[0], dg.after.com[1], dg.after.com[2]);
  h->nComHist = std::min(2, h->nComHist + 1);
  dg.status = status;
  dg.time_ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
  if (diag) *diag = dg;
  return status;
}

}  // extern "C"
