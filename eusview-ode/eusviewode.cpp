/*
 * eusviewode.cpp : helpers for EusLisp (kxreus eusview.l / eusview-physics.l) on top of odesim.{h,cpp}
 *   EusLisp defforeign (64 bit): :integer = long, :float = double, a float-vector passed as :string
 *   = double * of its elements. OdeSim * is passed around as an :integer.
 *   These functions read many values in one call (fewer foreign calls per frame).
 */
#include "odesim.h"
#include <cmath>

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

}
