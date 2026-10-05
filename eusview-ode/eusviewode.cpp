/*
 * eusviewode.cpp : helpers for EusLisp (kxreus eusview.l / eusview-physics.l) on top of odesim.{h,cpp}
 *   EusLisp defforeign (64 bit): :integer = long, :float = double, a float-vector passed as :string
 *   = double * of its elements. OdeSim * is passed around as an :integer.
 *   These functions read many values in one call (fewer foreign calls per frame).
 *   eusviewqp_* : the whole-body QP of the EusView app (wbqp.{h,cpp}, copies of eusview/ios/EusView/QP/)
 *   with long / double * arguments only (used by eusview-qp.l). WbqpEval -> 14 doubles, WbqpDiag -> 37 doubles
 *   (the same layout as the app's JNI wbqp_jni.cpp).
 */
#include "odesim.h"
#include "wbqp.h"
#include <cmath>
#include <vector>

extern "C" {

int eusviewode_version(void) { return 1; }

/* out[12 i ..]: link i origin x y z (m) and rotation r00..r22 (row major), i < n */
void eusviewode_link_poses(OdeSim *s, long n, double *out)
{
  for (long i = 0; i < n; i++) odesim_link_pose(s, (int)i, out + 12 * i, out + 12 * i + 3);
}

/* out[k]: joint value (rad / m, including q0), k < n */
void eusviewode_joint_values(OdeSim *s, long n, double *out)
{
  for (long k = 0; k < n; k++) out[k] = odesim_joint_value(s, (int)k);
}

/* odesim_step one step at a time, stopping before a step when a link is not finite or farther than
   100 m (a blown-up simulation would abort in ODE's collision AABB assertion).
   returns the number of steps done, or -1 - steps when it stopped */
long eusviewode_step_safe(OdeSim *s, double dt, long n, long nlinks)
{
  double p[3], r[9];
  for (long k = 0; k < n; k++) {
    for (long i = 0; i < nlinks; i++) {
      odesim_link_pose(s, (int)i, p, r);
      for (int a = 0; a < 3; a++) if (!std::isfinite(p[a]) || std::fabs(p[a]) > 100.0) return -1 - k;
      for (int a = 0; a < 9; a++) if (!std::isfinite(r[a])) return -1 - k;
    }
    odesim_step(s, dt, 1);
  }
  return n;
}


/* ---- whole-body QP (wbqp.h) ---- */
static void evq_put_eval(const WbqpEval &v, double *o)
{
  o[0] = v.min_dist; o[1] = v.pair[0]; o[2] = v.pair[1]; o[3] = v.n_collide; o[4] = v.n_limit; o[5] = v.n_at_limit;
  o[6] = v.max_limit_excess; o[7] = v.com[0]; o[8] = v.com[1]; o[9] = v.com[2]; o[10] = v.com_margin;
  o[11] = v.foot_height[0]; o[12] = v.foot_height[1]; o[13] = 0;
}
long eusviewqp_create(void) { return (long)wbqp_create(); }
long eusviewqp_destroy(long h) { wbqp_destroy((WbQP *)h); return 0; }
long eusviewqp_add_link(long h, long parent, double *rest) { return wbqp_add_link((WbQP *)h, (int)parent, rest); }
/* xyz: n points (m, link frame) as doubles */
long eusviewqp_add_link_vertices(long h, long link, double *xyz, long n)
{
  std::vector<float> f(3 * n);
  for (long i = 0; i < 3 * n; i++) f[i] = (float)xyz[i];
  wbqp_add_link_vertices((WbQP *)h, (int)link, f.data(), (int)n);
  return n;
}
long eusviewqp_set_link_mass(long h, long link, double mass, double *com) { wbqp_set_link_mass((WbQP *)h, (int)link, mass, com); return 0; }
long eusviewqp_add_joint(long h, long link, long type, double *axis, double lo, double hi, double vmax)
{
  return wbqp_add_joint((WbQP *)h, (int)link, (int)type, axis, lo, hi, vmax);
}
long eusviewqp_set_hand(long h, long side, long link, double *off) { wbqp_set_hand((WbQP *)h, (int)side, (int)link, off); return 0; }
long eusviewqp_set_foot(long h, long side, long link) { wbqp_set_foot((WbQP *)h, (int)side, (int)link); return 0; }
long eusviewqp_set_param(long h, char *name, double v) { return wbqp_set_param((WbQP *)h, name, v); }
double eusviewqp_get_param(long h, char *name) { return wbqp_get_param((WbQP *)h, name); }
long eusviewqp_finalize(long h, double *poses, long n) { return wbqp_finalize((WbQP *)h, n > 0 ? poses : nullptr, (int)n); }
/* out: links joints capsules pairs total-mass scale */
long eusviewqp_info(long h, double *out)
{
  WbQP *q = (WbQP *)h;
  out[0] = wbqp_num_links(q); out[1] = wbqp_num_joints(q); out[2] = wbqp_num_capsules(q); out[3] = wbqp_num_pairs(q);
  out[4] = wbqp_total_mass(q); out[5] = wbqp_get_param(q, "scale");
  return 0;
}
/* ev: 14, flags: number of links (doubles), poly: 2 * max. returns the number of polygon vertices */
long eusviewqp_eval(long h, double *q, double *root, long support, double *ev, double *flags, double *poly, long max)
{
  WbQP *w = (WbQP *)h;
  std::vector<int> f(wbqp_num_links(w));
  WbqpEval v{};
  int n = wbqp_eval(w, q, root, (int)support, &v, f.data(), poly, (int)max);
  evq_put_eval(v, ev);
  for (size_t i = 0; i < f.size(); i++) flags[i] = f[i];
  return n;
}
long eusviewqp_reset(long h) { wbqp_reset((WbQP *)h); return 0; }
/* diag: 37 (before 14, after 14, contact support status sqp_iters qp_iters n_constraints n_collision_rows slack_max time_ms) */
long eusviewqp_solve(long h, double *q_ref, double *root_ref, long contact, long support, double *q_out, double *root_out, double *diag)
{
  WbqpDiag d{};
  int s = wbqp_solve((WbQP *)h, q_ref, root_ref, (int)contact, (int)support, nullptr, q_out, root_out, &d);
  evq_put_eval(d.before, diag); evq_put_eval(d.after, diag + 14);
  double *x = diag + 28;
  x[0] = d.contact; x[1] = d.support; x[2] = d.status; x[3] = d.sqp_iters; x[4] = d.qp_iters;
  x[5] = d.n_constraints; x[6] = d.n_collision_rows; x[7] = d.slack_max; x[8] = d.time_ms;
  return s;
}
long eusviewqp_contact_of(long h, double *q, double *root, long prev) { return wbqp_contact_of((WbQP *)h, q, root, (int)prev); }
/* q: n x joints, root: n x 12; contact, support: n doubles */
long eusviewqp_plan_contacts(long h, long n, double *q, double *root, double *contact, double *support)
{
  std::vector<int> c(n), s(n);
  wbqp_plan_contacts((WbQP *)h, (int)n, q, root, c.data(), s.data());
  for (long i = 0; i < n; i++) { contact[i] = c[i]; support[i] = s[i]; }
  return n;
}

}
