// FallRecovery.swift : 物理 (PhysicsSim) で BVH などの動作を再生していて倒れたら, 起き上がってから倒れたコマの続きを再生する
//   1. 倒れた: 腰 (ルートのリンク) の上向きが fallDeg (60°) より fallHold (0.3 秒) 続けて傾いた → 動作の時間を止める
//   2. 起き上がり: 体の前 (ルートのリンクの前) が下を向いていれば うつ伏せ, 上なら 仰向け の起き上がりの動作 (RCB4 のプロジェクトの動作,
//      ロボットの JSON の motions. KHR は「起きあがり(うつぶせ)/(仰向け)」, KXR は「起き上がり（うつ伏せ）/（仰向け）」) をサーボの目標にして再生
//   3. 立てたか: 動作が終わってから settle (1 秒) までに傾きが standDeg (25°) 未満なら, blend (0.6 秒) かけて倒れたコマの姿勢へ移り, そこから続ける.
//      立てなければもう一度 (maxTries 回まで). 起き上がりの動作がないロボットや, 起き上がれないときは置き直す (今の続きの姿勢で床に置く)
//   Android・デスクトップ版は shared/kotlin/.../FallRecovery.kt (同じ作り)
import Foundation
import simd

final class FallRecovery {
  enum Phase: Equatable { case playing, getup, settle, blend }
  let model: RobotModel
  let rootLink: Int
  let bodyUp: SIMD3<Float>, bodyFwd: SIMD3<Float>
  let getupProne: RobotMotion?, getupSupine: RobotMotion?
  var fallDeg: Float = 60, standDeg: Float = 25
  var fallHold = 0.3, settleTime = 1.0, blendTime = 0.6
  var maxTries = 2
  private(set) var phase: Phase = .playing
  private(set) var falls = 0, getups = 0, replaces = 0
  /// 起き上がりの動作の名前 (表示用)
  private(set) var current: String = ""
  private var downFor = 0.0, t = 0.0, tries = 0
  private var motion: RobotMotion? = nil
  private var blendFrom: [Float] = []

  init(model: RobotModel) {
    self.model = model
    rootLink = model.links.firstIndex { $0.parent < 0 } ?? 0
    let R = model.links[rootLink].rest.rot3.transpose
    bodyUp = R * SIMD3<Float>(0, 0, 1)
    bodyFwd = R * SIMD3<Float>(1, 0, 0)
    func find(_ pats: [String]) -> RobotMotion? {
      model.motions?.first { m in pats.contains { m.name.contains($0) } }
    }
    getupProne = find(["起き上がり（うつ伏せ）", "起きあがり(うつぶせ)", "起き上がり(うつ伏せ)", "起きあがり（うつぶせ）"])
    getupSupine = find(["起き上がり（仰向け）", "起きあがり(仰向け)", "起き上がり(仰向け)", "起きあがり（仰向け）"])
  }

  var hasGetup: Bool { getupProne != nil || getupSupine != nil }
  /// 再生を最初からやり直すとき
  func reset() { phase = .playing; downFor = 0; t = 0; tries = 0; motion = nil; current = "" }

  func tilt(_ poses: [simd_float4x4]) -> Float {
    let up = poses[rootLink].rot3 * bodyUp
    return up.z.isFinite ? acos(max(-1, min(1, up.z))) * 180 / .pi : 180
  }

  /// 1 コマごとに呼ぶ. resume: 続きのコマの関節角 (度). 戻り値 nil = いつもどおり再生して進める, それ以外 = この関節角をサーボの目標にして, 動作の時間は止める.
  /// replace(angles) が呼ばれたら, 呼んだ側で物理を作り直す (置き直す)
  func step(sim: PhysicsSim, dt: Double, resume: [Float], replace: ([Float]) -> Void) -> [Float]? {
    let poses = sim.linkPoses()
    let tl = tilt(poses)
    switch phase {
    case .playing:
      downFor = tl > fallDeg ? downFor + dt : 0
      if downFor < fallHold { return nil }
      falls += 1; tries = 0
      return startGetup(poses, resume: resume, replace: replace)
    case .getup:
      t += dt
      guard let m = motion else { return resume }
      let k = Int(t * Double(m.fps))
      if k < m.frames.count { return m.frames[k] }
      phase = .settle; t = 0
      return m.frames.last
    case .settle:
      t += dt
      if tl < standDeg {
        getups += 1
        phase = .blend; t = 0; blendFrom = sim.jointValues()
        return blendFrom
      }
      if t < settleTime { return motion?.frames.last }
      tries += 1
      if tries < maxTries { return startGetup(poses, resume: resume, replace: replace) }
      replaces += 1; replace(resume); phase = .playing; downFor = 0; current = ""
      return resume
    case .blend:
      t += dt
      let a = Float(min(1, t / blendTime)), s = a * a * (3 - 2 * a)
      if a >= 1 { phase = .playing; downFor = 0; current = ""; return nil }
      return zip(blendFrom, resume).map { $0 + ($1 - $0) * s }
    }
  }

  private func startGetup(_ poses: [simd_float4x4], resume: [Float], replace: ([Float]) -> Void) -> [Float]? {
    let fwd = poses[rootLink].rot3 * bodyFwd
    let prone = fwd.z < 0   // 体の前が下 → うつ伏せ
    motion = prone ? (getupProne ?? getupSupine) : (getupSupine ?? getupProne)
    guard let m = motion, !m.frames.isEmpty else {
      replaces += 1; replace(resume); phase = .playing; downFor = 0; current = ""
      return resume
    }
    current = m.name
    phase = .getup; t = 0
    return m.frames[0]
  }

  /// 表示用: 「倒れた 2 回・起き上がり 2 回」など
  var summary: String {
    var s = "倒れた \(falls) 回"
    if getups > 0 { s += "・起き上がり \(getups) 回" }
    if replaces > 0 { s += "・置き直し \(replaces) 回" }
    return s
  }
}
