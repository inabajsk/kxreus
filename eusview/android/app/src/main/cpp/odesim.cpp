// odesim.cpp : odesim.h の実装 (ODE 0.16)
#include "odesim.h"
#include <ode/ode.h>
#include <vector>
#include <memory>
#include <cmath>
#include <algorithm>

struct Link {
  dBodyID body;
  dVector3 com;                       // リンク座標系での重心 (ボディの原点 = 重心)
  std::vector<float> verts;           // 三角形メッシュ (ODE が参照するので保持)
  std::vector<int> idx;
  std::vector<dTriMeshDataID> tm;
};
struct Joint { dJointID j; int type; int mode = 0; double q0, fmax, vmax, kp, target; };

struct OdeSim {
  dWorldID world; dSpaceID space; dGeomID plane; dJointGroupID contacts;
  double mu, soft_erp, soft_cfm, bounce;
  bool servo = true, quick = false;
  int maxc = 4;
  double bounce_vel = 0.05;
  int ncontact = 0;
  std::vector<std::unique_ptr<Link>> links;
  std::vector<Joint> joints;
};

static void rotToODE(const double r[9], dMatrix3 R)
{
  for (int i = 0; i < 3; i++) { for (int j = 0; j < 3; j++) R[i * 4 + j] = r[i * 3 + j]; R[i * 4 + 3] = 0; }
}

static int g_init = 0;

OdeSim *odesim_create(const double g[3], double erp, double cfm, double mu, double soft_erp, double soft_cfm, double bounce, int iterations)
{
  if (!g_init++) dInitODE2(0);
  OdeSim *s = new OdeSim();
  s->world = dWorldCreate();
  dWorldSetGravity(s->world, g[0], g[1], g[2]);
  dWorldSetERP(s->world, erp);
  dWorldSetCFM(s->world, cfm);
  dWorldSetQuickStepNumIterations(s->world, iterations);
  dWorldSetContactSurfaceLayer(s->world, 0.0005);
  s->space = dHashSpaceCreate(0);
  s->plane = dCreatePlane(s->space, 0, 0, 1, 0);
  s->contacts = dJointGroupCreate(0);
  s->mu = mu; s->soft_erp = soft_erp; s->soft_cfm = soft_cfm; s->bounce = bounce;
  return s;
}

void odesim_destroy(OdeSim *s)
{
  if (!s) return;
  dJointGroupDestroy(s->contacts);
  dSpaceDestroy(s->space);   // 中の形状もまとめて消える
  for (auto &l : s->links) for (auto t : l->tm) dGeomTriMeshDataDestroy(t);
  dWorldDestroy(s->world);
  delete s;
}

int odesim_add_link(OdeSim *s, double mass, const double com[3], const double I[6], const double pos[3], const double rot[9])
{
  auto l = std::make_unique<Link>();
  l->body = dBodyCreate(s->world);
  dMass m;
  dMassSetZero(&m);
  // 重心まわりの慣性で, 重心をボディの原点にする
  dMassSetParameters(&m, mass > 0 ? mass : 1e-3, 0, 0, 0, I[0], I[3], I[5], I[1], I[2], I[4]);
  if (!dMassCheck(&m)) dMassSetSphereTotal(&m, mass > 0 ? mass : 1e-3, 0.01);
  dBodySetMass(l->body, &m);
  dMatrix3 R; rotToODE(rot, R);
  dBodySetRotation(l->body, R);
  for (int i = 0; i < 3; i++) l->com[i] = com[i];
  // ボディの位置 = リンクの原点 + R com
  dBodySetPosition(l->body, pos[0] + rot[0] * com[0] + rot[1] * com[1] + rot[2] * com[2],
                   pos[1] + rot[3] * com[0] + rot[4] * com[1] + rot[5] * com[2],
                   pos[2] + rot[6] * com[0] + rot[7] * com[1] + rot[8] * com[2]);
  s->links.push_back(std::move(l));
  return (int)s->links.size() - 1;
}

void odesim_add_mesh(OdeSim *s, int li, const float *v, int nv, const int *ix, int ni)
{
  Link *l = s->links[li].get();
  if (nv < 3 || ni < 3) return;
  size_t v0 = l->verts.size() / 3;
  (void)v0;
  // メッシュごとに別のデータにする (ODE は配列を参照し続けるので, 確保し直さないよう別の vector に入れる)
  auto *vs = new std::vector<float>(v, v + nv * 3);
  auto *is = new std::vector<int>(ix, ix + ni);
  dTriMeshDataID d = dGeomTriMeshDataCreate();
  dGeomTriMeshDataBuildSingle(d, vs->data(), 3 * sizeof(float), nv, is->data(), ni, 3 * sizeof(int));
  l->tm.push_back(d);
  dGeomID g = dCreateTriMesh(s->space, d, 0, 0, 0);
  dGeomSetBody(g, l->body);
  dGeomSetOffsetPosition(g, -l->com[0], -l->com[1], -l->com[2]);
  dGeomSetData(g, (void *)(intptr_t)(li + 1));
}

void odesim_add_box(OdeSim *s, int li, const double size[3], const double pos[3], const double rot[9])
{
  Link *l = s->links[li].get();
  dGeomID g = dCreateBox(s->space, size[0], size[1], size[2]);
  dGeomSetBody(g, l->body);
  dGeomSetOffsetPosition(g, pos[0] - l->com[0], pos[1] - l->com[1], pos[2] - l->com[2]);
  dMatrix3 R; rotToODE(rot, R);
  dGeomSetOffsetRotation(g, R);
  dGeomSetData(g, (void *)(intptr_t)(li + 1));
}

void odesim_add_cylinder(OdeSim *s, int li, double radius, double length, const double pos[3], const double rot[9])
{
  Link *l = s->links[li].get();
  dGeomID g = dCreateCylinder(s->space, radius, length);
  dGeomSetBody(g, l->body);
  dGeomSetOffsetPosition(g, pos[0] - l->com[0], pos[1] - l->com[1], pos[2] - l->com[2]);
  dMatrix3 R; rotToODE(rot, R);
  dGeomSetOffsetRotation(g, R);
  dGeomSetData(g, (void *)(intptr_t)(li + 1));
}

void odesim_set_joint_mode(OdeSim *s, int k, int mode) { s->joints[k].mode = mode; }
void odesim_set_fmax(OdeSim *s, int k, double f) { s->joints[k].fmax = f; }
void odesim_set_options(OdeSim *s, int quick, int maxc, double bv) { s->quick = quick != 0; s->maxc = maxc < 1 ? 1 : (maxc > 16 ? 16 : maxc); s->bounce_vel = bv; }

int odesim_add_joint(OdeSim *s, int parent, int child, int type, const double a[3], const double ax[3],
                     double lo, double hi, double fmax, double vmax, double kp)
{
  dBodyID b1 = parent >= 0 ? s->links[parent]->body : 0, b2 = s->links[child]->body;
  Joint jt;
  jt.type = type; jt.fmax = fmax; jt.vmax = vmax; jt.kp = kp; jt.target = 0;
  // ODE の角度は「body2 が body1 に対して axis まわりに回った量」と符号を合わせるため, 子を body1 にする
  if (type == 0) {
    jt.j = dJointCreateHinge(s->world, 0);
    dJointAttach(jt.j, b2, b1);
    dJointSetHingeAnchor(jt.j, a[0], a[1], a[2]);
    dJointSetHingeAxis(jt.j, ax[0], ax[1], ax[2]);
  } else {
    jt.j = dJointCreateSlider(s->world, 0);
    dJointAttach(jt.j, b2, b1);
    dJointSetSliderAxis(jt.j, ax[0], ax[1], ax[2]);
  }
  jt.q0 = 0;
  s->joints.push_back(jt);
  (void)lo; (void)hi;
  return (int)s->joints.size() - 1;
}

/* 今の関節の値 (作った姿勢のときを 0 とする ODE の値に, 作ったときの角度 q0 を足す) */
static double jvalue(const Joint &j)
{
  return (j.type == 0 ? dJointGetHingeAngle(j.j) : dJointGetSliderPosition(j.j)) + j.q0;
}

double odesim_joint_value(OdeSim *s, int k) { return jvalue(s->joints[k]); }

/* 作ったときの関節の値と可動範囲をあとから設定する (q0 は odesim_add_joint の時点の姿勢の角度) */
extern "C" void odesim_set_joint_offset(OdeSim *s, int k, double q0, double lo, double hi)
{
  Joint &j = s->joints[k];
  j.q0 = q0;
  int lp = j.type == 0 ? dParamLoStop : dParamLoStop, hp = dParamHiStop;
  double l = lo - q0, h = hi - q0;
  if (j.type == 0) { l = std::max(l, -M_PI); h = std::min(h, M_PI); }
  if (h > l) {
    if (j.type == 0) { dJointSetHingeParam(j.j, lp, l); dJointSetHingeParam(j.j, hp, h); }
    else { dJointSetSliderParam(j.j, lp, l); dJointSetSliderParam(j.j, hp, h); }
  }
}

void odesim_set_targets(OdeSim *s, const double *t, int n)
{
  for (int k = 0; k < n && k < (int)s->joints.size(); k++) s->joints[k].target = t[k];
}

void odesim_set_servo(OdeSim *s, int on) { s->servo = on != 0; }

static void near_cb(void *data, dGeomID g1, dGeomID g2)
{
  OdeSim *s = (OdeSim *)data;
  // 床とロボットの当たりだけを扱う (自分どうしの当たりは見ない)
  if (g1 != s->plane && g2 != s->plane) return;
  dContact c[16];
  int n = dCollide(g1, g2, s->maxc, &c[0].geom, sizeof(dContact));
  for (int i = 0; i < n; i++) {
    c[i].surface.mode = dContactSoftERP | dContactSoftCFM | dContactApprox1 | (s->bounce > 0 ? dContactBounce : 0);
    c[i].surface.mu = s->mu;
    c[i].surface.soft_erp = s->soft_erp;
    c[i].surface.soft_cfm = s->soft_cfm;
    c[i].surface.bounce = s->bounce;
    c[i].surface.bounce_vel = s->bounce_vel;
    dJointID j = dJointCreateContact(s->world, s->contacts, &c[i]);
    dJointAttach(j, dGeomGetBody(c[i].geom.g1), dGeomGetBody(c[i].geom.g2));
  }
  s->ncontact += n;
}

void odesim_step(OdeSim *s, double dt, int n)
{
  for (int k = 0; k < n; k++) {
    for (auto &j : s->joints) {
      double v = 0, f = 0;
      if (j.mode == 1) {               // 車輪: 目標の値を回転の速さとして使う (eusdyna の d-joint-rotation)
        v = 20.0 * j.target / M_PI; f = 1e6;
      } else if (s->servo) {
        v = j.kp * (j.target - jvalue(j));
        if (v > j.vmax) v = j.vmax;
        if (v < -j.vmax) v = -j.vmax;
        f = j.fmax;
      } else f = std::min(j.fmax * 0.01, 0.05);   // 脱力: 少しだけ摩擦 (上限 0.05 N·m. fmax が実質無制限 (500000) でも崩れるように)
      if (j.type == 0) { dJointSetHingeParam(j.j, dParamVel, v); dJointSetHingeParam(j.j, dParamFMax, f); }
      else { dJointSetSliderParam(j.j, dParamVel, v); dJointSetSliderParam(j.j, dParamFMax, f); }
    }
    s->ncontact = 0;
    dSpaceCollide(s->space, s, near_cb);
    if (s->quick) dWorldQuickStep(s->world, dt); else dWorldStep(s->world, dt);
    dJointGroupEmpty(s->contacts);
  }
}

void odesim_link_pose(OdeSim *s, int li, double pos[3], double rot[9])
{
  Link *l = s->links[li].get();
  const dReal *p = dBodyGetPosition(l->body), *R = dBodyGetRotation(l->body);
  for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) rot[i * 3 + j] = R[i * 4 + j];
  // リンクの原点 = ボディの位置 - R com
  for (int i = 0; i < 3; i++) pos[i] = p[i] - (R[i * 4] * l->com[0] + R[i * 4 + 1] * l->com[1] + R[i * 4 + 2] * l->com[2]);
}

int odesim_contacts(OdeSim *s) { return s->ncontact; }
