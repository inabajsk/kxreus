// odesim_jni.cpp : odesim.h (ODE の薄い C の層) を Kotlin (jp.jsk.eusview.OdeNative) から呼ぶ JNI
#include <jni.h>
#include <vector>
#include "odesim.h"

#define F(name) Java_jp_jsk_eusview_OdeNative_##name
#define S(h) reinterpret_cast<OdeSim *>(h)

namespace {
struct D {   // double[] を一時的に取り出す
  JNIEnv *e; jdoubleArray a; jdouble *p;
  D(JNIEnv *e, jdoubleArray a) : e(e), a(a), p(a ? e->GetDoubleArrayElements(a, nullptr) : nullptr) {}
  ~D() { if (p) e->ReleaseDoubleArrayElements(a, p, JNI_ABORT); }
};
}

extern "C" {
JNIEXPORT jlong JNICALL F(create)(JNIEnv *e, jclass, jdoubleArray g, jdouble erp, jdouble cfm, jdouble mu,
                                  jdouble serp, jdouble scfm, jdouble bounce, jint it) {
  D gg(e, g);
  return reinterpret_cast<jlong>(odesim_create(gg.p, erp, cfm, mu, serp, scfm, bounce, it));
}
JNIEXPORT void JNICALL F(destroy)(JNIEnv *, jclass, jlong h) { odesim_destroy(S(h)); }
JNIEXPORT void JNICALL F(setOptions)(JNIEnv *, jclass, jlong h, jint quick, jint maxc, jdouble bv) {
  odesim_set_options(S(h), quick, maxc, bv);
}
JNIEXPORT jint JNICALL F(addLink)(JNIEnv *e, jclass, jlong h, jdouble mass, jdoubleArray com, jdoubleArray I,
                                  jdoubleArray pos, jdoubleArray rot) {
  D c(e, com), i(e, I), p(e, pos), r(e, rot);
  return odesim_add_link(S(h), mass, c.p, i.p, p.p, r.p);
}
JNIEXPORT void JNICALL F(addMesh)(JNIEnv *e, jclass, jlong h, jint li, jfloatArray v, jintArray ix) {
  jsize nv = e->GetArrayLength(v), ni = e->GetArrayLength(ix);
  std::vector<float> vv(nv); std::vector<int> ii(ni);
  e->GetFloatArrayRegion(v, 0, nv, vv.data());
  e->GetIntArrayRegion(ix, 0, ni, reinterpret_cast<jint *>(ii.data()));
  odesim_add_mesh(S(h), li, vv.data(), nv / 3, ii.data(), ni);   // odesim がコピーする
}
JNIEXPORT void JNICALL F(addBox)(JNIEnv *e, jclass, jlong h, jint li, jdoubleArray size, jdoubleArray pos, jdoubleArray rot) {
  D s(e, size), p(e, pos), r(e, rot);
  odesim_add_box(S(h), li, s.p, p.p, r.p);
}
JNIEXPORT void JNICALL F(addCylinder)(JNIEnv *e, jclass, jlong h, jint li, jdouble rad, jdouble len, jdoubleArray pos, jdoubleArray rot) {
  D p(e, pos), r(e, rot);
  odesim_add_cylinder(S(h), li, rad, len, p.p, r.p);
}
JNIEXPORT jint JNICALL F(addJoint)(JNIEnv *e, jclass, jlong h, jint parent, jint child, jint type, jdoubleArray anchor,
                                   jdoubleArray axis, jdouble lo, jdouble hi, jdouble fmax, jdouble vmax, jdouble kp) {
  D a(e, anchor), x(e, axis);
  return odesim_add_joint(S(h), parent, child, type, a.p, x.p, lo, hi, fmax, vmax, kp);
}
JNIEXPORT void JNICALL F(setJointOffset)(JNIEnv *, jclass, jlong h, jint k, jdouble q0, jdouble lo, jdouble hi) {
  odesim_set_joint_offset(S(h), k, q0, lo, hi);
}
JNIEXPORT void JNICALL F(setJointMode)(JNIEnv *, jclass, jlong h, jint k, jint mode) { odesim_set_joint_mode(S(h), k, mode); }
JNIEXPORT void JNICALL F(setTargets)(JNIEnv *e, jclass, jlong h, jdoubleArray t) {
  D tt(e, t);
  odesim_set_targets(S(h), tt.p, e->GetArrayLength(t));
}
JNIEXPORT void JNICALL F(setServo)(JNIEnv *, jclass, jlong h, jint on) { odesim_set_servo(S(h), on); }
JNIEXPORT void JNICALL F(step)(JNIEnv *, jclass, jlong h, jdouble dt, jint n) { odesim_step(S(h), dt, n); }
// 全リンクの位置姿勢: out[12 i ..] = x y z r00..r22
JNIEXPORT void JNICALL F(linkPoses)(JNIEnv *e, jclass, jlong h, jint n, jdoubleArray out) {
  std::vector<double> o(12 * n);
  for (int i = 0; i < n; i++) odesim_link_pose(S(h), i, &o[12 * i], &o[12 * i + 3]);
  e->SetDoubleArrayRegion(out, 0, 12 * n, o.data());
}
JNIEXPORT jdouble JNICALL F(jointValue)(JNIEnv *, jclass, jlong h, jint k) { return odesim_joint_value(S(h), k); }
JNIEXPORT jint JNICALL F(contacts)(JNIEnv *, jclass, jlong h) { return odesim_contacts(S(h)); }
}
