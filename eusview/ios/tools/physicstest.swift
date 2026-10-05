// physicstest.swift : Mac で PhysicsSim (ODE) を試す
//   ロボットを reset-pose で床に置いて数秒動かし, 倒れないか・関節の符号が EusLisp と合うかを見る
import Foundation
import simd

let a = CommandLine.arguments
let m = try! JSONDecoder().decode(RobotModel.self, from: Data(contentsOf: URL(fileURLWithPath: a[1])))
let pose = m.poses?["reset-pose"] ?? [Float](repeating: 0, count: m.joints.count)
let sim = PhysicsSim(model: m, angles: pose)
func rootZ() -> Float { sim.linkPoses()[0].columns.3.z }
func rootXY() -> String { let p = sim.linkPoses()[0].columns.3; return String(format: "x %.1f y %.1f mm", p.x * 1000, p.y * 1000) }
print("links", m.links.count, "joints", m.joints.count, "root z", rootZ())
for t in 0..<6 { sim.step(0.5); print(String(format: "t=%.1f root z %.4f %@ contacts %d  max |q-target| %.2f deg", sim.time, rootZ(), rootXY(), sim.contacts,
  zip(sim.jointValues(), sim.targets).map { abs($0 - $1) }.max() ?? 0)) }
// 符号の確認: ODE が出したリンクの姿勢と, 関節の値から EusLisp の式で求めた姿勢が合うか
var tgt = pose; if tgt.count > 2 { tgt[2] += 20 }
sim.setTargets(tgt); sim.step(1.0)
let w = sim.linkPoses(), q = sim.jointValues()
var root = w[0]; root = root * simd_inverse(m.links[0].rest)
let fk = forwardKinematics(m, q, root: root)
let err = zip(w, fk).map { simd_distance($0.columns.3, $1.columns.3) }.max()!
print(String(format: "joint[2] target %.1f now %.1f deg; FK vs ODE link position max error %.2f mm", tgt[2], q[2], err * 1000))
// 動作を 1 つ物理で再生して, 倒れないかを見る (引数 2 番目: 動作の名前の一部)
if a.count > 2, let mo = m.motions?.first(where: { $0.name.contains(a[2]) }) {
  let s2 = PhysicsSim(model: m, angles: mo.frames[0])
  for f in mo.frames { s2.setTargets(f); s2.step(1 / Double(mo.fps)) }
  s2.step(1.0)
  let w = s2.linkPoses()[0]
  print(String(format: "motion %@ (%d frames): root at (%.3f, %.3f, %.3f), up-z %.2f", mo.name, mo.frames.count, w.columns.3.x, w.columns.3.y, w.columns.3.z, w.columns.2.z))
}
