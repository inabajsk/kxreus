// wbqp_jni.cpp : wbqp.h (全身の QP, ios/EusView/QP/wbqp.{h,cpp} のコピー) を Kotlin (jp.jsk.eusview.WbqpNative) から呼ぶ JNI
//   Android 版とデスクトップ版で共通 (odesim_jni.cpp と同じ libeusviewode に入れる). 使い方は shared/kotlin/.../WholeBodyQp.kt
//   閉ループの MPC は mpcStep (wbqp_mpc_step).
//   WbqpEval は 14 個の double, WbqpDiag は 37 個の double に並べて返す (WholeBodyQp.kt の WbqpEval.of / WbqpDiag.of)
#include <jni.h>
#include <cmath>
#include <vector>
#include "wbqp.h"

#define F(name) Java_jp_jsk_eusview_WbqpNative_##name
#define S(h) reinterpret_cast<WbQP *>(h)

namespace {
struct D {   // double[] を取り出す (write = true なら戻すときに書き戻す)
  JNIEnv *e; jdoubleArray a; jdouble *p; bool write;
  D(JNIEnv *e, jdoubleArray a, bool w = false) : e(e), a(a), p(a ? e->GetDoubleArrayElements(a, nullptr) : nullptr), write(w) {}
  ~D() { if (p) e->ReleaseDoubleArrayElements(a, p, write ? 0 : JNI_ABORT); }
};
struct I {
  JNIEnv *e; jintArray a; jint *p; bool write;
  I(JNIEnv *e, jintArray a, bool w = false) : e(e), a(a), p(a ? e->GetIntArrayElements(a, nullptr) : nullptr), write(w) {}
  ~I() { if (p) e->ReleaseIntArrayElements(a, p, write ? 0 : JNI_ABORT); }
};
struct Str {
  JNIEnv *e; jstring s; const char *p;
  Str(JNIEnv *e, jstring s) : e(e), s(s), p(e->GetStringUTFChars(s, nullptr)) {}
  ~Str() { e->ReleaseStringUTFChars(s, p); }
};
const int NEVAL = 14;
void putEval(const WbqpEval &v, double *o) {
  o[0] = v.min_dist; o[1] = v.pair[0]; o[2] = v.pair[1]; o[3] = v.n_collide; o[4] = v.n_limit; o[5] = v.n_at_limit;
  o[6] = v.max_limit_excess; o[7] = v.com[0]; o[8] = v.com[1]; o[9] = v.com[2]; o[10] = v.com_margin;
  o[11] = v.foot_height[0]; o[12] = v.foot_height[1]; o[13] = 0;
}
void putDiag(const WbqpDiag &d, double *o) {
  putEval(d.before, o); putEval(d.after, o + NEVAL);
  double *x = o + 2 * NEVAL;
  x[0] = d.contact; x[1] = d.support; x[2] = d.status; x[3] = d.sqp_iters; x[4] = d.qp_iters;
  x[5] = d.n_constraints; x[6] = d.n_collision_rows; x[7] = d.slack_max; x[8] = d.time_ms;
}
}

extern "C" {
JNIEXPORT jlong JNICALL F(create)(JNIEnv *, jclass) { return reinterpret_cast<jlong>(wbqp_create()); }
JNIEXPORT void JNICALL F(destroy)(JNIEnv *, jclass, jlong h) { wbqp_destroy(S(h)); }
JNIEXPORT jint JNICALL F(addLink)(JNIEnv *e, jclass, jlong h, jint parent, jdoubleArray rest) {
  D r(e, rest);
  return wbqp_add_link(S(h), parent, r.p);
}
JNIEXPORT void JNICALL F(addLinkVertices)(JNIEnv *e, jclass, jlong h, jint link, jfloatArray v) {
  jsize n = e->GetArrayLength(v);
  std::vector<float> vv(n);
  e->GetFloatArrayRegion(v, 0, n, vv.data());
  wbqp_add_link_vertices(S(h), link, vv.data(), n / 3);
}
JNIEXPORT void JNICALL F(setLinkMass)(JNIEnv *e, jclass, jlong h, jint link, jdouble mass, jdoubleArray com) {
  D c(e, com);
  wbqp_set_link_mass(S(h), link, mass, c.p);
}
JNIEXPORT jint JNICALL F(addJoint)(JNIEnv *e, jclass, jlong h, jint link, jint type, jdoubleArray axis, jdouble lo, jdouble hi, jdouble vmax) {
  D a(e, axis);
  return wbqp_add_joint(S(h), link, type, a.p, lo, hi, vmax);
}
JNIEXPORT jint JNICALL F(addCapsule)(JNIEnv *e, jclass, jlong h, jint link, jdoubleArray p0, jdoubleArray p1, jdouble r) {
  D a(e, p0), b(e, p1);
  return wbqp_add_capsule(S(h), link, a.p, b.p, r);
}
JNIEXPORT void JNICALL F(setHand)(JNIEnv *e, jclass, jlong h, jint side, jint link, jdoubleArray off) {
  D o(e, off);
  wbqp_set_hand(S(h), side, link, o.p);
}
JNIEXPORT void JNICALL F(setFoot)(JNIEnv *, jclass, jlong h, jint side, jint link) { wbqp_set_foot(S(h), side, link); }
JNIEXPORT void JNICALL F(excludePair)(JNIEnv *, jclass, jlong h, jint a, jint b) { wbqp_exclude_pair(S(h), a, b); }
JNIEXPORT jint JNICALL F(setParam)(JNIEnv *e, jclass, jlong h, jstring name, jdouble v) {
  Str s(e, name);
  return wbqp_set_param(S(h), s.p, v);
}
JNIEXPORT jdouble JNICALL F(getParam)(JNIEnv *e, jclass, jlong h, jstring name) {
  Str s(e, name);
  return wbqp_get_param(S(h), s.p);
}
JNIEXPORT jint JNICALL F(finalizeModel)(JNIEnv *e, jclass, jlong h, jdoubleArray poses, jint n) {
  D p(e, poses);
  return wbqp_finalize(S(h), p.p, n);
}
JNIEXPORT jint JNICALL F(numLinks)(JNIEnv *, jclass, jlong h) { return wbqp_num_links(S(h)); }
JNIEXPORT jint JNICALL F(numJoints)(JNIEnv *, jclass, jlong h) { return wbqp_num_joints(S(h)); }
JNIEXPORT jint JNICALL F(numCapsules)(JNIEnv *, jclass, jlong h) { return wbqp_num_capsules(S(h)); }
JNIEXPORT jint JNICALL F(numPairs)(JNIEnv *, jclass, jlong h) { return wbqp_num_pairs(S(h)); }
// out: link, p0 (3), p1 (3), radius
JNIEXPORT void JNICALL F(capsule)(JNIEnv *e, jclass, jlong h, jint i, jdoubleArray out) {
  D o(e, out, true);
  int link = 0;
  wbqp_capsule(S(h), i, &link, o.p + 1, o.p + 4, o.p + 7);
  o.p[0] = link;
}
JNIEXPORT void JNICALL F(pair)(JNIEnv *e, jclass, jlong h, jint i, jintArray out) {
  I o(e, out, true);
  int a = 0, b = 0;
  wbqp_pair(S(h), i, &a, &b);
  o.p[0] = a; o.p[1] = b;
}
JNIEXPORT jint JNICALL F(sole)(JNIEnv *e, jclass, jlong h, jint side, jdoubleArray xyz, jint max) {
  D o(e, xyz, true);
  return wbqp_sole(S(h), side, o.p, max);
}
JNIEXPORT jdouble JNICALL F(totalMass)(JNIEnv *, jclass, jlong h) { return wbqp_total_mass(S(h)); }
// ev: 14 個. flags (null 可): リンクの数. poly (null 可): 2 × max
JNIEXPORT jint JNICALL F(eval)(JNIEnv *e, jclass, jlong h, jdoubleArray q, jdoubleArray root, jint support, jdoubleArray ev,
                               jintArray flags, jdoubleArray poly, jint max) {
  D qq(e, q), rr(e, root), oo(e, ev, true), pp(e, poly, true);
  I ff(e, flags, true);
  WbqpEval v{};
  int n = wbqp_eval(S(h), qq.p, rr.p, support, &v, reinterpret_cast<int *>(ff.p), pp.p, max);
  putEval(v, oo.p);
  return n;
}
JNIEXPORT void JNICALL F(fk)(JNIEnv *e, jclass, jlong h, jdoubleArray q, jdoubleArray root, jdoubleArray poses) {
  D qq(e, q), rr(e, root), oo(e, poses, true);
  wbqp_fk(S(h), qq.p, rr.p, oo.p);
}
JNIEXPORT void JNICALL F(reset)(JNIEnv *, jclass, jlong h) { wbqp_reset(S(h)); }
// diag: 37 個 (before 14, after 14, contact support status sqp_iters qp_iters n_constraints n_collision_rows slack_max time_ms)
JNIEXPORT jint JNICALL F(solve)(JNIEnv *e, jclass, jlong h, jdoubleArray qRef, jdoubleArray rootRef, jint contact, jint support,
                                jdoubleArray targets, jdoubleArray qOut, jdoubleArray rootOut, jdoubleArray diag) {
  D q(e, qRef), r(e, rootRef), t(e, targets), qo(e, qOut, true), ro(e, rootOut, true), dg(e, diag, true);
  WbqpDiag d{};
  int s = wbqp_solve(S(h), q.p, r.p, contact, support, t.p, qo.p, ro.p, &d);
  if (dg.p) putDiag(d, dg.p);
  return s;
}
JNIEXPORT jint JNICALL F(contactOf)(JNIEnv *e, jclass, jlong h, jdoubleArray q, jdoubleArray root, jint prev) {
  D qq(e, q), rr(e, root);
  return wbqp_contact_of(S(h), qq.p, rr.p, prev);
}
JNIEXPORT void JNICALL F(planContacts)(JNIEnv *e, jclass, jlong h, jint n, jdoubleArray q, jdoubleArray root, jintArray contact, jintArray support) {
  D qq(e, q), rr(e, root);
  I c(e, contact, true), s(e, support, true);
  wbqp_plan_contacts(S(h), n, qq.p, rr.p, reinterpret_cast<int *>(c.p), reinterpret_cast<int *>(s.p));
}
// GMR + QP + バランス: 全部のコマの参照 (q_ref n×nj, root_ref n×12) から重心の軌道を決める. contact, support, comOut (n×5) に書く.
//   戻り値: ZMP の制約を緩めたコマの数 (wbqp.h の wbqp_plan_balance)
JNIEXPORT jint JNICALL F(planBalance)(JNIEnv *e, jclass, jlong h, jint n, jdoubleArray q, jdoubleArray root, jintArray contact, jintArray support,
                                      jdoubleArray comOut) {
  D qq(e, q), rr(e, root), co(e, comOut, true);
  I c(e, contact, true), s(e, support, true);
  return wbqp_plan_balance(S(h), n, qq.p, rr.p, reinterpret_cast<int *>(c.p), reinterpret_cast<int *>(s.p), co.p);
}
// 次の solve の重心の目標 (com: 5 個. null で外す)
JNIEXPORT void JNICALL F(setComTarget)(JNIEnv *e, jclass, jlong h, jdoubleArray com) {
  D c(e, com);
  wbqp_set_com_target(S(h), c.p);
}
// 閉ループの MPC (wbqp_mpc_step): planBalance のあとで, 再生中に毎コマ呼ぶ. qMeas / qPlan: 関節角 (rad / m, 関節の数),
//   rootMeas / rootPlan: ルートのリンクの姿勢 (12 個: 位置, 回転 3x3 行優先), qOut: サーボの目標 (rad / m), info: 8 個 (null 可).
//   戻り値: QP の状態 (負なら qOut を使わない. -2 = 計画がない)
JNIEXPORT jint JNICALL F(mpcStep)(JNIEnv *e, jclass, jlong h, jint i, jdoubleArray qMeas, jdoubleArray rootMeas, jdoubleArray qPlan,
                                  jdoubleArray rootPlan, jdoubleArray qOut, jdoubleArray info) {
  D qm(e, qMeas), rm(e, rootMeas), qp(e, qPlan), rp(e, rootPlan), qo(e, qOut, true), in(e, info, true);
  return wbqp_mpc_step(S(h), i, qm.p, rm.p, qp.p, rp.p, qo.p, in.p);
}
}
