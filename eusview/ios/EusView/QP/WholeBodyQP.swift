// WholeBodyQP.swift : 全身の QP (wbqp.h, C++) を Swift から使う. RobotModel と BVHRetargeter (GMR) から QP のモデルを作り,
//   GMR の答えをコマごとに直す (自己衝突なし・関節の可動範囲 (余裕つき) の中・重心が足の裏の中・床に着いた足を止める)
//   仕様: eusview/bvh/QP.md.  Foundation と simd だけ (Mac のコマンドライン qptest でも使う)
import Foundation
import simd

/// 1 コマ: 参照 (GMR) と QP の答え (関節角は度・mm, 姿勢はルートのリンクのワールドの姿勢) と評価
struct QPFrame {
  var qRef: [Float]
  var rootRef: simd_float4x4
  var q: [Float]
  var root: simd_float4x4
  var diag: WbqpDiag
}

/// 評価 (表示用): 衝突しているリンクなど
struct QPView {
  var eval = WbqpEval()
  var flags = [Int32]()            // リンクごと: bit0 衝突, bit1 可動範囲の端, bit2 衝突の手前
  var polygon = [SIMD2<Float>]()   // 支持多角形 (縮める前)
}

final class WholeBodyQP {
  let model: RobotModel
  let h: OpaquePointer
  let rootLink: Int
  private let rootRest: simd_float4x4
  private let linear: [Bool]

  /// rt: 手と足のリンクを GMR の部位 (BVHRetargeter.limbs) から決める. fps: 動作のコマの速さ (速さの上限に使う)
  init(model: RobotModel, rt: BVHRetargeter, fps: Double, params: [String: Double] = [:]) {
    self.model = model
    h = wbqp_create()
    rootLink = model.links.firstIndex { $0.parent < 0 } ?? 0
    rootRest = model.links[rootLink].rest
    linear = model.joints.map { $0.type == "linear" }
    let ph = model.physics
    for (i, l) in model.links.enumerated() {
      _ = wbqp_add_link(h, Int32(l.parent), WholeBodyQP.pose12(l.rest))
      for me in l.meshes where me.vertices.count >= 3 {
        me.vertices.withUnsafeBufferPointer { wbqp_add_link_vertices(h, Int32(i), $0.baseAddress, Int32(me.vertices.count / 3)) }
      }
      if let p = ph?.links?[safe: i], let m = p.mass, let c = p.com, m > 0, c.count == 3 { wbqp_set_link_mass(h, Int32(i), m, c) }
    }
    for (k, j) in model.joints.enumerated() {
      let lin = j.type == "linear", s: Double = lin ? 0.001 : .pi / 180
      let vmax = ph?.joints?[safe: k]?.vmax ?? 0
      _ = wbqp_add_joint(h, Int32(j.link), lin ? 1 : 0, j.axis.map { Double($0) }, Double(j.min ?? -180) * s, Double(j.max ?? 180) * s, vmax)
    }
    for (side, n) in ["larm", "rarm"].enumerated() {
      if let L = rt.limbs[n] { wbqp_set_hand(h, Int32(side), Int32(L.endLink), [Double(L.endOffset.x), Double(L.endOffset.y), Double(L.endOffset.z)]) }
    }
    for (side, n) in ["lleg", "rleg"].enumerated() {
      if let L = rt.limbs[n] { wbqp_set_foot(h, Int32(side), Int32(L.footLink ?? L.endLink)) }
    }
    _ = wbqp_set_param(h, "dt", 1 / max(fps, 1))
    for (k, v) in params { _ = wbqp_set_param(h, k, v) }
    // 衝突を調べない組: 関節角 0 と reset-pose で当たっている組
    var poses = [Double]()
    if let r = model.poses?["reset-pose"], r.count == model.joints.count { poses = WholeBodyQP.toQ(r, linear) }
    poses.withUnsafeBufferPointer { _ = wbqp_finalize(h, $0.baseAddress, poses.isEmpty ? 0 : 1) }
  }
  deinit { wbqp_destroy(h) }

  var scale: Double { wbqp_get_param(h, "scale") }
  var pairs: Int { Int(wbqp_num_pairs(h)) }
  var capsules: Int { Int(wbqp_num_capsules(h)) }

  static func toQ(_ a: [Float], _ linear: [Bool]) -> [Double] { zip(a, linear).map { Double($0) * ($1 ? 0.001 : .pi / 180) } }
  func toQ(_ a: [Float]) -> [Double] { WholeBodyQP.toQ(a, linear) }
  func toAngles(_ q: [Double]) -> [Float] { zip(q, linear).map { Float($0 * ($1 ? 1000 : 180 / .pi)) } }
  /// 姿勢 → 12 個 (位置, 回転 行優先)
  static func pose12(_ m: simd_float4x4) -> [Double] {
    let c = m.columns
    return [c.3.x, c.3.y, c.3.z, c.0.x, c.1.x, c.2.x, c.0.y, c.1.y, c.2.y, c.0.z, c.1.z, c.2.z].map { Double($0) }
  }
  static func mat(_ a: [Double]) -> simd_float4x4 {
    let f = a.map { Float($0) }
    return simd_float4x4(columns: (SIMD4(f[3], f[6], f[9], 0), SIMD4(f[4], f[7], f[10], 0), SIMD4(f[5], f[8], f[11], 0), SIMD4(f[0], f[1], f[2], 1)))
  }

  func reset() { wbqp_reset(h) }
  func contact(_ angles: [Float], rootLinkPose: simd_float4x4, prev: Int32) -> Int32 {
    wbqp_contact_of(h, toQ(angles), WholeBodyQP.pose12(rootLinkPose), prev)
  }

  /// 1 コマを解く (前のコマの答えから続ける)
  func solve(angles: [Float], rootLinkPose: simd_float4x4, contact: Int32 = -1, support: Int32 = -1) -> QPFrame {
    var qo = [Double](repeating: 0, count: model.joints.count), ro = [Double](repeating: 0, count: 12)
    var d = WbqpDiag()
    _ = wbqp_solve(h, toQ(angles), WholeBodyQP.pose12(rootLinkPose), contact, support, nil, &qo, &ro, &d)
    return QPFrame(qRef: angles, rootRef: rootLinkPose, q: toAngles(qo), root: WholeBodyQP.mat(ro), diag: d)
  }

  /// 評価 (状態を変えない). support: bit0 左, bit1 右 (-1 = 足の高さで決める)
  func view(angles: [Float], rootLinkPose: simd_float4x4, support: Int32 = -1) -> QPView {
    var v = QPView()
    v.flags = [Int32](repeating: 0, count: model.links.count)
    var poly = [Double](repeating: 0, count: 64)
    let n = wbqp_eval(h, toQ(angles), WholeBodyQP.pose12(rootLinkPose), support, &v.eval, &v.flags, &poly, 32)
    v.polygon = (0..<Int(min(n, 32))).map { SIMD2(Float(poly[$0 * 2]), Float(poly[$0 * 2 + 1])) }
    return v
  }

  /// ルートのリンクの姿勢 → robotFK の root (BVHRetargeter の T)
  func rootT(_ rootLinkPose: simd_float4x4) -> simd_float4x4 { rootLinkPose * simd_inverse(rootRest) }
}

/// GMR → QP を全部のコマで (または途中まで) 計算する. 足の先読み (preview コマ) のため GMR を少し先まで解く.
///   emit(i, frame) をコマごとに呼ぶ (別のスレッド). cancelled() が true ならやめる. 戻り値: 最後まで計算したか
@discardableResult
func runGMRQP(rt: BVHRetargeter, qp: WholeBodyQP, from start: Int = 0, progress: ((Double) -> Void)? = nil,
              cancelled: (() -> Bool)? = nil, emit: (Int, QPFrame) -> Void) -> Bool {
  let n = rt.motion.frames
  let P = max(0, Int(wbqp_get_param(qp.h, "preview")))
  var refs = [([Float], simd_float4x4)](), contacts = [Int32]()
  refs.reserveCapacity(n); contacts.reserveCapacity(n)
  rt.resetGMR()
  for _ in 0..<8 { _ = rt.gmr(0) }   // 初めのコマの IK を収束させる (reset-pose から数コマで大きく動くのを避ける)
  qp.reset()
  var prev: Int32 = 0
  func ref(_ i: Int) {
    while refs.count <= min(i, n - 1) {
      let r = rt.gmr(refs.count)
      let pose = rt.rootLinkPose(r.root)
      prev = qp.contact(r.angles, rootLinkPose: pose, prev: prev)
      refs.append((r.angles, pose)); contacts.append(prev)
    }
  }
  for i in 0..<n {
    if i % 50 == 0 { if cancelled?() == true { return false }; progress?(Double(i) / Double(max(1, n))) }
    ref(i + P)
    var s = contacts[i]
    for k in stride(from: i + 1, through: min(n - 1, i + P), by: 1) { let t = s & contacts[k]; if t == 0 { break }; s = t }
    let f = qp.solve(angles: refs[i].0, rootLinkPose: refs[i].1, contact: contacts[i], support: s)
    emit(i, f)
  }
  progress?(1)
  return true
}

/// GMR + QP の全部のコマを動作 (RobotMotion) にする (ロボットの画面の「動作」用)
func makeGMRQPMotion(rt: BVHRetargeter, name: String, progress: ((Double) -> Void)? = nil, cancelled: (() -> Bool)? = nil) -> (RobotMotion, [QPFrame])? {
  let qp = WholeBodyQP(model: rt.model, rt: rt, fps: rt.motion.fps)
  var out = [QPFrame]()
  out.reserveCapacity(rt.motion.frames)
  guard runGMRQP(rt: rt, qp: qp, progress: progress, cancelled: cancelled, emit: { _, f in out.append(f) }) else { return nil }
  var frames = [[Float]](), roots = [[Float]]()
  let xy0 = out.first.map { SIMD2($0.root.columns.3.x, $0.root.columns.3.y) } ?? .zero
  for f in out {
    var T = f.root
    T.columns.3.x -= xy0.x; T.columns.3.y -= xy0.y
    frames.append(f.q); roots.append(T.rootArray)
  }
  return (RobotMotion(name: name, fps: Float(rt.motion.fps), frames: frames, root: roots), out)
}
