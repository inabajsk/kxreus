// BalanceStabilizer.swift : QP + バランスの動作を物理 (PhysicsSim) で再生するときの安定化
//   計画した体 (ルートのリンク) の傾きと, 物理の体の傾きの差を, 床に着いている足の足首の関節で戻す
//   (実機の KHR / KXR のジャイロによる安定化と同じ考え. 足首の軸の向きは物理の今の姿勢から求めるので, ロボットごとの符号によらない)
//   Δq = kp (a · w) + kd (a · dw/dt),  a = 足首の関節の軸 (ワールド), w = 体を計画の傾きに戻す回転 (ワールドの回転ベクトル).
//   符号と大きさは qptest で決めた (lafan1 walk1 × KHR: 安定化なし 7.7 秒 → kp = 0.5, kd = 0 で 19.7 秒で倒れる. 試作)
import Foundation
import simd

final class BalanceStabilizer {
  let model: RobotModel
  let rootLink: Int
  let bodyUp: SIMD3<Float>          // ルートのリンクの座標での「上」(関節角 0 で)
  let ankles: [[Int]]               // 左・右の足の足首の関節 (足のリンクから根元へ 2 つ)
  var kp: Float = 0.5               // 傾きの差 (rad) → 足首 (rad)
  var kd: Float = 0                 // 傾きの差の速さ (rad/s) → 足首 (rad)
  var maxDeg: Float = 20
  private var prevW: SIMD3<Float>? = nil

  /// feet: 左・右の足のリンク (GMR の footLink)
  init(model: RobotModel, feet: [Int]) {
    self.model = model
    rootLink = model.links.firstIndex { $0.parent < 0 } ?? 0
    bodyUp = model.links[rootLink].rest.rot3.transpose * SIMD3<Float>(0, 0, 1)
    ankles = feet.map { f -> [Int] in
      var out = [Int](), link = f
      while out.count < 2, link >= 0 {
        if let k = model.joints.firstIndex(where: { $0.link == link && $0.type != "linear" }) { out.append(k) }
        link = model.links[link].parent
      }
      return out
    }
  }

  func reset() { prevW = nil }

  /// targets: 計画の関節角 (度), planRoot: 計画のルートのリンクの姿勢, contact: 床に着いている足 (bit0 左, bit1 右), poses: 物理のリンクの姿勢
  func adjust(_ targets: [Float], planRoot: simd_float4x4, contact: Int32, poses: [simd_float4x4], dt: Float) -> [Float] {
    let ua = simd_normalize(poses[rootLink].rot3 * bodyUp), up = simd_normalize(planRoot.rot3 * bodyUp)
    var w = simd_cross(ua, up)
    let s = simd_length(w)
    if s > 1e-6 { w *= asin(min(1, s)) / s }
    let dw = prevW.map { (w - $0) / max(dt, 1e-3) } ?? .zero
    prevW = w
    var out = targets
    for (side, js) in ankles.enumerated() where (contact & Int32(1 << side)) != 0 {
      for k in js {
        let a = simd_normalize(poses[model.joints[k].link].rot3 * SIMD3(model.joints[k].axis[0], model.joints[k].axis[1], model.joints[k].axis[2]))
        let dq = (kp * simd_dot(a, w) + kd * simd_dot(a, dw)) * 180 / .pi
        out[k] += max(-maxDeg, min(maxDeg, dq))
      }
    }
    return out
  }
}
