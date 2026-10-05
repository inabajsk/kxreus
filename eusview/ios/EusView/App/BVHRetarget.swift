// BVHRetarget.swift : BVH の人の動きをロボット (eus2json.l の JSON, 関節名 <limb>-<joint>-<r|p|y>) に移す
//   仕様: eusview/bvh/RETARGET.md, 表: eusview/bvh/retarget_tables.json (Android の BvhRetarget.kt と同じ)
//   方法 1 (関節名): jskeus irtbvh.l / kxreus bvh/bvh-demo.l の :copy-state-to と同じ考え方.
//     ロボットの <limb>-<joint>-<r|p|y> = 符号 · w[x|y|z],  w = B · log(BVH の関節のローカルの回転) (度)
//     符号: ロボットの関節軸の該当成分が負なら −1, head-neck と :mirrored のロボットの右手足はさらに −1. 可動範囲で切る
//     EusLisp (eusview/bvh/retarget-ref.l) の結果と比べて確かめる
//   方法 2 (GMR): 人とロボットの部位 (腰・胸・頭・肩・肘・手首・股・膝・足首) を対応させ, 体節ごとのスケールを掛けた
//     人の部位の位置を目標に, 手足ごとに減衰付き最小二乗の IK (前のコマの答えから始める). 胴と頭は向きだけ合わせる
//   Foundation と simd だけを使う (Mac のコマンドラインで EusLisp と照合するテストに使えるように)
import Foundation
import simd

// MARK: - 表 (retarget_tables.json)

struct RetargetTables: Codable {
  struct Robots: Codable { var defaults: [String: String]; var mirrored: [String]; var supported: [String: [String]]? }
  struct Method1: Codable { var order: [[String]]; var axes: [String: Int] }
  /// データの種類ごとの写し方 (kxreus の bvh/*-demo.l の :copy-joint-to): src = r/p/y に使う w の要素,
  /// axisSign "cumulative" (bvh-demo.l の rikiya: 軸の成分が負なら符号を反転し, 次の r → p → y に持ち越す) / "none" (符号 1),
  /// signs = 初めの符号 (head-neck: −1), calibrate = コマ 0 の角度を引いて reset-pose を足す (lafan1)
  struct M1Rule: Codable { var src: [String: Int]; var axisSign: String; var signs: [String: Float]; var calibrate: Bool }
  struct Dataset: Codable { var eusClass: String?; var method1: [String: String]; var method1Rule: M1Rule?; var gmr: [String: String] }
  struct GMRParams: Codable {
    var lambda: Float; var iterations: Int; var wEnd: Float; var wMid: Float; var wFootRot: Float
    var wTorsoRot: Float; var wHeadRot: Float; var wRest: Float
  }
  var robots: Robots
  var method1: Method1
  var datasets: [String: Dataset]
  var gmrParams: GMRParams
}

/// アプリに入っている表 (bvh/retarget_tables.json, なければバンドルの直下)
func loadRetargetTables(url: URL? = nil) -> RetargetTables? {
  let u = url ?? bvhRoot()?.appendingPathComponent("retarget_tables.json")
    ?? Bundle.main.url(forResource: "retarget_tables", withExtension: "json")
  guard let u, let d = try? Data(contentsOf: u) else {
    if let b = Bundle.main.url(forResource: "retarget_tables", withExtension: "json"), let d = try? Data(contentsOf: b) {
      return try? JSONDecoder().decode(RetargetTables.self, from: d)
    }
    return nil
  }
  return try? JSONDecoder().decode(RetargetTables.self, from: d)
}

enum RetargetMethod: String, CaseIterable { case names, gmr, gmrqp
  var title: String { switch self { case .names: return "関節名"; case .gmr: return "GMR"; case .gmrqp: return "GMR + QP" } }
}

/// 関節名が <limb>-<joint>-<r|p|y> の決まりのロボットか (両脚と片腕以上)
func robotSupportsRetarget(_ m: RobotModel) -> Bool {
  let limbs = ["larm", "rarm", "lleg", "rleg", "head", "torso"]
  var have = Set<String>()
  for j in m.joints {
    let p = j.name.split(separator: "-")
    if p.count == 3, limbs.contains(String(p[0])), ["r", "p", "y"].contains(String(p[2])) { have.insert(String(p[0])) }
  }
  return have.contains("lleg") && have.contains("rleg") && (have.contains("larm") || have.contains("rarm"))
}

// MARK: - 小さな数学

/// 回転行列の対数 (回転ベクトル, ラジアン). EusLisp の matrix-log と同じ ([-π, π])
func rotLog(_ r: simd_float3x3) -> SIMD3<Float> {
  let c = r.columns
  let q = simd_quatd(simd_double3x3(simd_double3(c.0), simd_double3(c.1), simd_double3(c.2)))
  let v = SIMD3<Double>(q.imag.x, q.imag.y, q.imag.z)
  let n = simd_length(v)
  if n < 1e-12 { return .zero }
  var th: Double = 2 * atan2(n, q.real)
  if th > Double.pi { th -= 2 * Double.pi } else if th < -Double.pi { th += 2 * Double.pi }
  return SIMD3<Float>(v / n * th)
}

func rotExp(_ w: SIMD3<Float>) -> simd_float3x3 {
  let a = simd_length(w)
  return a < 1e-9 ? matrix_identity_float3x3 : simd_float3x3(simd_quatf(angle: a, axis: w / a))
}

extension simd_float4x4 {
  var rot3: simd_float3x3 { simd_float3x3(columns.0.xyz, columns.1.xyz, columns.2.xyz) }
  var pos3: SIMD3<Float> { columns.3.xyz }
  init(rot r: simd_float3x3, pos p: SIMD3<Float>) {
    self.init(columns: (SIMD4(r.columns.0, 0), SIMD4(r.columns.1, 0), SIMD4(r.columns.2, 0), SIMD4(p, 1)))
  }
  /// [x y z r00..r22] (RobotMotion の root の形)
  var rootArray: [Float] {
    let r = rot3
    return [columns.3.x, columns.3.y, columns.3.z, r[0][0], r[1][0], r[2][0], r[0][1], r[1][1], r[2][1], r[0][2], r[1][2], r[2][2]]
  }
}

/// 列ベクトル x (左右), z (上) の近似から右手系の回転を作る (x = y × z の向き)
func frameFromYZ(_ y: SIMD3<Float>, _ up: SIMD3<Float>) -> simd_float3x3 {
  let yy = simd_normalize(y)
  let x = simd_normalize(simd_cross(yy, up))
  let z = simd_cross(x, yy)
  return simd_float3x3(x, yy, z)
}

/// 対称な n×n の連立一次方程式 (ガウスの消去法, n は小さい)
func solveLinear(_ a: inout [Double], _ b: inout [Double], _ n: Int) -> Bool {
  for c in 0..<n {
    var p = c
    for r in (c + 1)..<max(n, c + 1) where abs(a[r * n + c]) > abs(a[p * n + c]) { p = r }
    if abs(a[p * n + c]) < 1e-12 { return false }
    if p != c { for k in 0..<n { a.swapAt(c * n + k, p * n + k) }; b.swapAt(c, p) }
    for r in 0..<n where r != c {
      let f = a[r * n + c] / a[c * n + c]
      if f == 0 { continue }
      for k in c..<n { a[r * n + k] -= f * a[c * n + k] }
      b[r] -= f * b[c]
    }
  }
  for c in 0..<n { b[c] /= a[c * n + c] }
  return true
}

/// ロボットの順運動学 (PhysicsSim の forwardKinematics と同じ. ここでは Foundation と simd だけで書く)
func robotFK(_ m: RobotModel, _ angles: [Float], root: simd_float4x4) -> [simd_float4x4] {
  var local = m.links.map { $0.rest }
  for (k, j) in m.joints.enumerated() where k < angles.count {
    let ax = simd_normalize(SIMD3(j.axis[0], j.axis[1], j.axis[2]))
    var t = matrix_identity_float4x4
    if j.type == "linear" { t.columns.3 = SIMD4(ax * angles[k] / 1000, 1) } else { t = simd_float4x4(simd_quatf(angle: angles[k] * .pi / 180, axis: ax)) }
    local[j.link] = local[j.link] * t
  }
  var w = [simd_float4x4]()
  w.reserveCapacity(m.links.count)
  for (i, l) in m.links.enumerated() { w.append(l.parent >= 0 ? w[l.parent] * local[i] : root * local[i]) }
  return w
}

// MARK: - 移し替え

/// 1 本の BVH を 1 体のロボットに移す. method1(i) / gmr(i) が i コマ目の関節角 (度, JSON の順) とルートの変換を返す
final class BVHRetargeter {
  let model: RobotModel
  let motion: BVHMotion
  let tables: RetargetTables
  let dataset: RetargetTables.Dataset?
  let mirrored: Bool
  let B: simd_float3x3                         // BVH の軸 → 世界
  let parents: [Int]                           // リンクの親
  private var jointIndex = [String: Int]()
  private var rootLink = 0
  // 方法 1 の写し方: (BVH の関節, ロボットの関節, 世界の軸 0..2, 符号)
  private(set) var m1: [(bvh: Int, joint: Int, axis: Int, sign: Float)] = []
  // ロボットの部位
  struct Limb {
    var name: String
    var chain: [Int]          // IK に使う関節 (JSON の番号, 根元から)
    var first: Int            // 付け根のリンク
    var mid: Int?             // 肘 / 膝のリンク
    var endLink: Int          // 手首 / 足首 (の点を持つリンク)
    var endOffset: SIMD3<Float>
    var footLink: Int?        // 足の向きを合わせるリンク
    var len1: Float = 0, len2: Float = 0
  }
  private(set) var limbs = [String: Limb]()
  private var chestLink = 0, headLink: Int?
  private var torsoChain = [Int](), headChain = [Int]()
  private var zeroW = [simd_float4x4]()
  private var restAngles = [Float]()
  private var ankleHeight: Float = 0           // ロボットの足首の点の床からの高さ (関節角 0)
  private var rootHeight: Float = 0            // ロボットのルートの床からの高さ (関節角 0)
  // 人の部位 (BVH の関節の番号)
  private var h = [String: Int]()
  private var hEnd = [String: Int]()           // "end:<関節>" の End Site の番号
  private var F0 = matrix_identity_float3x3    // 人の初期姿勢の体の向き (x 前, y 左, z 上)
  private var restW = [simd_float4x4]()
  private var hLen = [String: Float]()         // 人の体節の長さ
  private var h0: Float = 0.08                 // 人の足首の立っているときの高さ
  private var footSlope: [String: Float] = ["l": 0.3, "r": 0.3]
  /// 初期姿勢が立った姿勢 (体が上向き・脚が下向き) か. そうでない (lafan1) ときは足の向きをつま先の点から決める
  private(set) var restUpright = true
  private(set) var sLeg: Float = 1, sArm: Float = 1
  private var calib: [Float]? = nil            // 方法 1 の lafan1: コマ 0 の角度 − reset-pose
  private var root0 = SIMD3<Float>.zero, rot0 = matrix_identity_float3x3, C = matrix_identity_float3x3
  /// GMR の最後のコマの, 手首・足首の目標とのずれ (m, 確認用)
  private(set) var residual = [String: Float]()
  // GMR の前のコマの答え
  private var q: [Float]
  private var lastFrame = -10
  let gmrOK: Bool
  let method1OK: Bool

  init(model: RobotModel, motion: BVHMotion, tables: RetargetTables) {
    self.model = model
    self.motion = motion
    self.tables = tables
    let ds = tables.datasets[motion.header.kind]
    dataset = ds
    mirrored = tables.robots.mirrored.contains(model.name)
    B = motion.baseRotation
    parents = model.links.map { $0.parent }
    for (k, j) in model.joints.enumerated() { jointIndex[j.name] = k }
    rootLink = model.links.firstIndex { $0.parent < 0 } ?? 0
    q = [Float](repeating: 0, count: model.joints.count)
    let bvhIndex = Dictionary(motion.joints.enumerated().map { ($1.name, $0) }, uniquingKeysWith: { a, _ in a })
    // 方法 1 (kxreus eusview-retarget.l の :names と同じ)
    var m1ok = false
    if let ds, let rule = ds.method1Rule {
      for lj in tables.method1.order where lj.count == 2 {
        let key = "\(lj[0])-\(lj[1])"
        guard let bn = ds.method1[key], let b = bvhIndex[bn] else { continue }
        var s: Float = rule.signs[key] ?? 1
        if mirrored, lj[0] == "rarm" || lj[0] == "rleg" { s = -s }
        for c in ["r", "p", "y"] {
          guard let ax = tables.method1.axes[c], let src = rule.src[c], let k = jointIndex["\(key)-\(c)"], model.joints[k].type != "linear" else { continue }
          if rule.axisSign == "cumulative", model.joints[k].axis[ax] < 0 { s = -s }
          m1.append((b, k, src, s))
          m1ok = true
        }
      }
    }
    method1OK = m1ok
    // 人の部位
    if let ds {
      for (k, n) in ds.gmr {
        if n.hasPrefix("end:") {
          if let p = bvhIndex[String(n.dropFirst(4))], let e = motion.header.ends.firstIndex(where: { $0.parent == p }) { hEnd[k] = e }
        } else if let j = bvhIndex[n] { h[k] = j }
      }
    }
    // ロボットの部位 (関節角 0 の姿勢で)
    zeroW = robotFK(model, q, root: matrix_identity_float4x4)
    restAngles = model.poses?["reset-pose"] ?? q
    if restAngles.count != q.count { restAngles = q }
    let resetW = robotFK(model, restAngles, root: matrix_identity_float4x4)   // 床からの高さは reset-pose で (kxreus と同じ)
    var zmin = Float.greatestFiniteMagnitude
    for (i, l) in model.links.enumerated() {
      for me in l.meshes { var k = 0; while k + 2 < me.vertices.count { zmin = min(zmin, (resetW[i] * SIMD4(me.vertices[k], me.vertices[k + 1], me.vertices[k + 2], 1)).z); k += 3 } }
    }
    if !zmin.isFinite { zmin = 0 }
    rootHeight = resetW[rootLink].pos3.z - zmin
    for limb in ["larm", "rarm", "lleg", "rleg"] {
      if let L = BVHRetargeter.makeLimb(model, limb, zeroW) { limbs[limb] = L }
    }
    if let lf = limbs["lleg"] ?? limbs["rleg"] { ankleHeight = (resetW[lf.endLink] * SIMD4(lf.endOffset, 1)).z - zmin }
    // 胸 = 腕の付け根のリンクの親, 頭 = 頭の関節のいちばん先のリンク
    if let a = limbs["larm"] ?? limbs["rarm"] { chestLink = parents[a.first] >= 0 ? parents[a.first] : rootLink } else { chestLink = rootLink }
    torsoChain = BVHRetargeter.chain(model, prefix: "torso-", to: chestLink)
    let headJoints = model.joints.indices.filter { model.joints[$0].name.hasPrefix("head-") }
    if let deepest = headJoints.max(by: { BVHRetargeter.depth(model, model.joints[$0].link) < BVHRetargeter.depth(model, model.joints[$1].link) }) {
      headLink = model.joints[deepest].link
      headChain = BVHRetargeter.chain(model, prefix: "head-", to: model.joints[deepest].link)
    }
    let needed = ["pelvis", "chest", "neck", "lhip", "rhip", "lknee", "rknee", "lankle", "rankle"]
    let hh = h
    gmrOK = ds != nil && needed.allSatisfy { hh[$0] != nil } && limbs["lleg"] != nil && limbs["rleg"] != nil
    restW = motion.restPose()
    if let lh = h["lhip"], let rh = h["rhip"], let pv = h["pelvis"], let nk = h["neck"] {
      F0 = frameFromYZ(restW[lh].pos3 - restW[rh].pos3, restW[nk].pos3 - restW[pv].pos3)
    }
    if let lh = h["lhip"], let lk = h["lknee"] {
      restUpright = F0.columns.2.z > 0.9 && simd_normalize(restW[lk].pos3 - restW[lh].pos3).z < -0.9
    }
    if gmrOK { prepareHuman() }
    q = restAngles
    // 方法 1 のルート: コマ 0 の腰の向き (yaw) を除く回転 C (kxreus と同じ)
    let w0 = motion.frame(0)
    let pr = h["pelvis"] ?? 0
    root0 = w0[pr].pos3
    rot0 = w0[pr].rot3
    let v = rot0 * B.transpose * SIMD3<Float>(1, 0, 0)
    C = simd_float3x3(simd_quatf(angle: -atan2(v.y, v.x), axis: SIMD3(0, 0, 1)))
    if dataset?.method1Rule?.calibrate == true {
      let a0 = method1Raw(motion.pose(0).local)
      calib = zip(a0, restAngles).map { $0 - $1 }
    }
  }

  static func depth(_ m: RobotModel, _ link: Int) -> Int { var d = 0, l = link; while l >= 0 { l = m.links[l].parent; d += 1 }; return d }

  static func isAncestorOrSelf(_ m: RobotModel, _ a: Int, of l: Int) -> Bool {
    var x = l
    while x >= 0 { if x == a { return true }; x = m.links[x].parent }
    return false
  }

  /// prefix の関節のうち, リンク to の根元側 (自分を含む) にあるもの (根元から)
  static func chain(_ m: RobotModel, prefix: String, to: Int) -> [Int] {
    m.joints.indices.filter { m.joints[$0].name.hasPrefix(prefix) && m.joints[$0].type != "linear" && isAncestorOrSelf(m, m.joints[$0].link, of: to) }
      .sorted { depth(m, m.joints[$0].link) < depth(m, m.joints[$1].link) }
  }

  static func makeLimb(_ m: RobotModel, _ limb: String, _ w: [simd_float4x4]) -> Limb? {
    let js = m.joints.indices.filter { m.joints[$0].name.hasPrefix(limb + "-") && m.joints[$0].type != "linear" }
    guard !js.isEmpty else { return nil }
    func minDepth(_ c: [Int]) -> Int? { c.min { depth(m, m.joints[$0].link) < depth(m, m.joints[$1].link) } }
    guard let firstJ = minDepth(js) else { return nil }
    let arm = limb.hasSuffix("arm")
    let midJ = minDepth(js.filter { m.joints[$0].name.contains(arm ? "-elbow-" : "-knee-") })
    let endJ = minDepth(js.filter { m.joints[$0].name.contains(arm ? "-wrist-" : "-ankle-") })
    var endLink: Int, endOff = SIMD3<Float>.zero
    if let e = endJ { endLink = m.joints[e].link }
    else {
      // 手首の関節がない (KHR など): 肘から先のリンクのいちばん低い点 (関節角 0 で腕は下を向く)
      let base = midJ.map { m.joints[$0].link } ?? m.joints[js.max { depth(m, m.joints[$0].link) < depth(m, m.joints[$1].link) }!].link
      var best: (Float, Int, SIMD3<Float>)? = nil
      for (i, l) in m.links.enumerated() where isAncestorOrSelf(m, base, of: i) {
        for me in l.meshes { var k = 0; while k + 2 < me.vertices.count {
          let v = SIMD3(me.vertices[k], me.vertices[k + 1], me.vertices[k + 2]); let p = (w[i] * SIMD4(v, 1)).z
          if best == nil || p < best!.0 { best = (p, i, v) }; k += 3 } }
      }
      if let b = best { endLink = b.1; endOff = b.2 } else { endLink = base }
    }
    var foot: Int? = nil
    if !arm {
      let deepest = js.filter { isAncestorOrSelf(m, endLink, of: m.joints[$0].link) || isAncestorOrSelf(m, m.joints[$0].link, of: endLink) }
        .max { depth(m, m.joints[$0].link) < depth(m, m.joints[$1].link) }
      foot = deepest.map { m.joints[$0].link }
    }
    let tip = foot.map { depth(m, $0) > depth(m, endLink) ? $0 : endLink } ?? endLink
    let ch = chain(m, prefix: limb + "-", to: tip)
    var L = Limb(name: limb, chain: ch, first: m.joints[firstJ].link, mid: midJ.map { m.joints[$0].link }, endLink: endLink, endOffset: endOff, footLink: foot)
    let p0 = w[L.first].pos3, pe = (w[endLink] * SIMD4(endOff, 1)).xyz
    if let mid = L.mid { let pm = w[mid].pos3; L.len1 = simd_distance(p0, pm); L.len2 = simd_distance(pm, pe) }
    else { L.len1 = simd_distance(p0, pe) / 2; L.len2 = L.len1 }
    return L
  }

  // MARK: 人の準備 (GMR)

  private func hp(_ w: [simd_float4x4], _ ends: [SIMD3<Float>]?, _ k: String) -> SIMD3<Float>? {
    if let j = h[k] { return w[j].pos3 }
    if let e = hEnd[k], let ends { return ends[e] }
    return nil
  }

  private func prepareHuman() {
    let w0 = motion.frame(0)
    func d(_ a: String, _ b: String) -> Float { guard let pa = hp(w0, nil, a), let pb = hp(w0, nil, b) else { return 0 }; return simd_distance(pa, pb) }
    for s in ["l", "r"] {
      hLen[s + "arm1"] = d(s + "shoulder", s + "elbow"); hLen[s + "arm2"] = d(s + "elbow", s + "wrist")
      hLen[s + "leg1"] = d(s + "hip", s + "knee"); hLen[s + "leg2"] = d(s + "knee", s + "ankle")
    }
    let hl = (hLen["lleg1"]! + hLen["lleg2"]! + hLen["rleg1"]! + hLen["rleg2"]!) / 2
    let rl = ((limbs["lleg"].map { $0.len1 + $0.len2 } ?? 0) + (limbs["rleg"].map { $0.len1 + $0.len2 } ?? 0)) / 2
    sLeg = hl > 0.01 && rl > 0 ? rl / hl : 1
    let ha = (hLen["larm1"]! + hLen["larm2"]! + hLen["rarm1"]! + hLen["rarm2"]!) / 2
    let ra = ((limbs["larm"].map { $0.len1 + $0.len2 } ?? 0) + (limbs["rarm"].map { $0.len1 + $0.len2 } ?? 0)) / Float(max(1, [limbs["larm"], limbs["rarm"]].compactMap { $0 }.count))
    sArm = ha > 0.01 && ra > 0 ? ra / ha : sLeg
    // 足首の立っているときの高さと, 足が床にあるときの足首 → つま先の傾き (人ごと・データごとに違う)
    var zs = [Float](), sl: [String: [Float]] = ["l": [], "r": []]
    let n = motion.frames, step = max(1, n / 300)
    var samples = [(String, Float, Float, Float)]()
    for i in stride(from: 0, to: n, by: step) {
      let w = motion.frame(i), e = motion.endPositions(w)
      for s in ["l", "r"] {
        guard let a = hp(w, e, s + "ankle") else { continue }
        zs.append(a.z)
        if let t = hp(w, e, s + "toe") {
          let dxy = simd_length(SIMD2(t.x - a.x, t.y - a.y))
          samples.append((s, a.z, t.z, atan2(a.z - t.z, max(dxy, 1e-4))))
        }
      }
    }
    zs.sort()
    if !zs.isEmpty { h0 = zs[zs.count / 10] }
    for (s, az, tz, slope) in samples where az < h0 + 0.03 && tz < 0.05 { sl[s]!.append(slope) }
    for s in ["l", "r"] {
      var v = sl[s]!
      if v.isEmpty { continue }
      v.sort(); footSlope[s] = v[v.count / 2]
    }
  }

  /// 体節の今の向き = G · G_rest^T · F0 (初期姿勢で体の向き F0 になる)
  private func segFrame(_ w: [simd_float4x4], _ k: String) -> simd_float3x3? {
    guard let j = h[k] else { return nil }
    return w[j].rot3 * restW[j].rot3.transpose * F0
  }

  // MARK: 方法 1 (関節名)

  /// reset-pose に, 写す関節だけ BVH の角度を入れる (可動範囲で切る)
  private func method1Raw(_ local: [simd_float3x3]) -> [Float] {
    var a = restAngles
    var cache = [Int: SIMD3<Float>]()
    for e in m1 {
      let w: SIMD3<Float>
      if let c = cache[e.bvh] { w = c } else { w = rotLog(local[e.bvh]) * (180 / .pi); cache[e.bvh] = w }
      let j = model.joints[e.joint]
      a[e.joint] = min(max(e.sign * w[e.axis], j.min ?? -1e9), j.max ?? 1e9)
    }
    return a
  }

  func method1(_ i: Int) -> (angles: [Float], root: simd_float4x4) {
    let p = motion.pose(i)
    var a = method1Raw(p.local)
    if let calib {
      for (k, j) in model.joints.enumerated() { a[k] = min(max(a[k] - calib[k], j.min ?? -1e9), j.max ?? 1e9) }
    }
    // ルートの向き = C · (コマ 0 からの腰の回転) · C^T (kxreus と同じ. 初めはロボットが +x を向く)
    let pr = h["pelvis"] ?? 0
    let R = C * (p.world[pr].rot3 * rot0.transpose) * C.transpose
    let pv = p.world[pr].pos3
    var T = simd_float4x4(rot: R, pos: SIMD3(sLeg * pv.x, sLeg * pv.y, 0))
    T.columns.3.z = placeHeight(a, T, p.world)
    return (a, T)
  }

  private func footPoint(_ W: [simd_float4x4], _ L: Limb) -> SIMD3<Float> { (W[L.endLink] * SIMD4(L.endOffset, 1)).xyz }

  /// ルートの高さ: 足首が床から (足首の高さ + s_leg · 人の足首が上がった分) になるように. 両足のうち高くなる方に合わせる (床に埋まらない)
  private func placeHeight(_ a: [Float], _ T: simd_float4x4, _ w: [simd_float4x4]) -> Float {
    let W = robotFK(model, a, root: T)
    var z: Float = -Float.greatestFiniteMagnitude
    let ends = motion.endPositions(w)
    for s in ["l", "r"] {
      guard let L = limbs[s + "leg"] else { continue }
      let hz = hp(w, ends, s + "ankle").map { $0.z } ?? h0
      let want = ankleHeight + sLeg * max(0, hz - h0)
      z = max(z, want - (footPoint(W, L).z - T.columns.3.z))   // T の今の高さによらない (GMR は T.z を入れてから呼ぶ)
    }
    return z.isFinite ? z : rootHeight
  }

  // MARK: 方法 2 (GMR)

  func resetGMR() { q = restAngles; lastFrame = -10 }

  func gmr(_ i: Int) -> (angles: [Float], root: simd_float4x4) {
    guard gmrOK else { return method1(i) }
    if abs(i - lastFrame) > 30 { q = restAngles }    // 大きく飛んだら初めから (前のコマの答えから始めると遠い)
    lastFrame = i
    let prm = tables.gmrParams
    let w = motion.frame(i), ends = motion.endPositions(w)
    let P = segFrame(w, "pelvis")!
    let C = segFrame(w, "chest") ?? P
    let Hd = segFrame(w, "head")
    let pv = w[h["pelvis"]!].pos3
    let Rroot = P
    var T = simd_float4x4(rot: Rroot, pos: SIMD3(sLeg * pv.x, sLeg * pv.y, 0))
    // 胴と頭: 向きだけ
    if !torsoChain.isEmpty {
      solve(torsoChain, root: T, tasks: [.rot(link: chestLink, target: C * zeroW[chestLink].rot3, w: prm.wTorsoRot)], scale: 1)
    }
    if let hl = headLink, !headChain.isEmpty, let Hd {
      solve(headChain, root: T, tasks: [.rot(link: hl, target: Hd * zeroW[hl].rot3, w: prm.wHeadRot)], scale: 1)
    }
    // 腕: 胸から見た人の肘・手首の向き (体節ごとにスケール) を, ロボットの肩から
    var W = robotFK(model, q, root: T)
    let Cr = W[chestLink].rot3 * zeroW[chestLink].rot3.transpose   // ロボットの胸の向き
    let CrCt = Cr * C.transpose
    for s in ["l", "r"] {
      guard let L = limbs[s + "arm"], let hs = hp(w, ends, s + "shoulder"), let he = hp(w, ends, s + "elbow"), let hw = hp(w, ends, s + "wrist") else { continue }
      let l1 = hLen[s + "arm1"] ?? 0, l2 = hLen[s + "arm2"] ?? 0
      guard l1 > 1e-4, l2 > 1e-4 else { continue }
      let ps = W[L.first].pos3
      let el = ps + CrCt * ((he - hs) * (L.len1 / l1))
      let wr = el + CrCt * ((hw - he) * (L.len2 / l2))
      var tasks: [IKTask] = [.pos(link: L.endLink, offset: L.endOffset, target: wr, w: prm.wEnd)]
      if let m = L.mid { tasks.append(.pos(link: m, offset: .zero, target: el, w: prm.wMid)) }
      residual[s + "arm"] = solveLimb(L, root: T, tasks: tasks, target: wr)
    }
    // 脚: 股から人の膝・足首の向き (体節ごとにスケール). 高さは足首が床より下にならないように決める
    W = robotFK(model, q, root: T)
    var targets = [String: (SIMD3<Float>, SIMD3<Float>, simd_float3x3?)]()
    var rootZ: Float = -Float.greatestFiniteMagnitude
    for s in ["l", "r"] {
      guard let L = limbs[s + "leg"], let hh = hp(w, ends, s + "hip"), let hk = hp(w, ends, s + "knee"), let ha = hp(w, ends, s + "ankle") else { continue }
      let l1 = hLen[s + "leg1"] ?? 0, l2 = hLen[s + "leg2"] ?? 0
      guard l1 > 1e-4, l2 > 1e-4 else { continue }
      let ph = W[L.first].pos3
      let kn = ph + (hk - hh) * (L.len1 / l1)
      let an = kn + (ha - hk) * (L.len2 / l2)
      let want = ankleHeight + sLeg * max(0, ha.z - h0)
      rootZ = max(rootZ, want - an.z)
      var fr: simd_float3x3? = nil
      if let ft = L.footLink {
        if restUpright, let F = segFrame(w, s + "ankle") {
          fr = F * zeroW[ft].rot3            // 足の回転から (初期姿勢の足 = 床に平ら)
        } else if let toe = hp(w, ends, s + "toe") {
          let d = toe - ha                   // つま先の点から: 向き (yaw) と, 床にあるときの傾きからの差 (pitch)
          let dxy = simd_length(SIMD2(d.x, d.y))
          if dxy > 1e-3 {
            let yaw = atan2(d.y, d.x)
            let pitch = max(-0.8, min(0.8, atan2(-d.z, dxy) - (footSlope[s] ?? 0)))
            fr = simd_float3x3(simd_quatf(angle: yaw, axis: SIMD3(0, 0, 1))) * simd_float3x3(simd_quatf(angle: pitch, axis: SIMD3(0, 1, 0))) * zeroW[ft].rot3
          }
        }
      }
      targets[s] = (kn, an, fr)
    }
    if !rootZ.isFinite { rootZ = rootHeight }
    T.columns.3.z = rootZ
    for s in ["l", "r"] {
      guard let L = limbs[s + "leg"], let t = targets[s] else { continue }
      let dz = SIMD3<Float>(0, 0, rootZ)
      var tasks: [IKTask] = [.pos(link: L.endLink, offset: L.endOffset, target: t.1 + dz, w: prm.wEnd)]
      if let m = L.mid { tasks.append(.pos(link: m, offset: .zero, target: t.0 + dz, w: prm.wMid)) }
      if let fr = t.2, let ft = L.footLink { tasks.append(.rot(link: ft, target: fr, w: prm.wFootRot)) }
      residual[s + "leg"] = solveLimb(L, root: T, tasks: tasks, target: t.1 + dz)
    }
    // 表示: 低い方の足を (人に合わせた) 高さに置き直す
    T.columns.3.z = placeHeight(q, T, w)
    return (q, T)
  }

  /// 手足の IK. 前のコマの答えから解いて手首 / 足首が目標から手足の長さの 15% より離れたら (局所解),
  /// 初期の姿勢 (reset-pose) から解き直して近い方を使う. 戻り値は手首 / 足首と目標の距離 (m)
  private func solveLimb(_ L: Limb, root: simd_float4x4, tasks: [IKTask], target: SIMD3<Float>) -> Float {
    let len = L.len1 + L.len2
    let q0 = q
    solve(L.chain, root: root, tasks: tasks, scale: len)
    let e1 = simd_distance(footPoint(robotFK(model, q, root: root), L), target)
    if e1 < 0.15 * len { return e1 }
    let q1 = q
    q = q0
    for k in L.chain { q[k] = restAngles[k] }
    solve(L.chain, root: root, tasks: tasks, scale: len)
    let e2 = simd_distance(footPoint(robotFK(model, q, root: root), L), target)
    if e2 < e1 { return e2 }
    q = q1
    return e1
  }

  enum IKTask {
    case pos(link: Int, offset: SIMD3<Float>, target: SIMD3<Float>, w: Float)
    case rot(link: Int, target: simd_float3x3, w: Float)
  }

  /// 減衰付き最小二乗の IK (関節 chain だけを動かす, q を書き換える). 位置の誤差は scale (手足の長さ) で割って向きと同じ大きさにそろえる
  private func solve(_ chain: [Int], root: simd_float4x4, tasks: [IKTask], scale: Float) {
    let n = chain.count
    guard n > 0 else { return }
    let prm = tables.gmrParams
    let sc = max(scale, 1e-3)
    let lam2 = Double(prm.lambda * prm.lambda), wr = Double(prm.wRest)
    for _ in 0..<max(1, prm.iterations) {
      let W = robotFK(model, q, root: root)
      var Hm = [Double](repeating: 0, count: n * n), g = [Double](repeating: 0, count: n)
      var err: Float = 0
      let axes = chain.map { k -> (SIMD3<Float>, SIMD3<Float>) in
        let j = model.joints[k]
        return (simd_normalize(W[j.link].rot3 * SIMD3(j.axis[0], j.axis[1], j.axis[2])), W[j.link].pos3)
      }
      for t in tasks {
        var e: SIMD3<Float>, w: Float
        var J = [SIMD3<Float>](repeating: .zero, count: n)
        switch t {
        case let .pos(link, off, target, ww):
          let p = (W[link] * SIMD4(off, 1)).xyz
          e = (target - p) / sc; w = ww
          for (c, k) in chain.enumerated() where BVHRetargeter.isAncestorOrSelf(model, model.joints[k].link, of: link) {
            J[c] = simd_cross(axes[c].0, p - axes[c].1) / sc
          }
        case let .rot(link, target, ww):
          e = rotLog(target * W[link].rot3.transpose); w = ww
          for (c, k) in chain.enumerated() where BVHRetargeter.isAncestorOrSelf(model, model.joints[k].link, of: link) { J[c] = axes[c].0 }
        }
        err = max(err, simd_length(e) * w)
        let w2 = Double(w * w)
        for a in 0..<n {
          g[a] += w2 * Double(simd_dot(J[a], e))
          for b in a..<n { Hm[a * n + b] += w2 * Double(simd_dot(J[a], J[b])) }
        }
      }
      if err < 1e-4 { break }
      for a in 0..<n {
        for b in 0..<a { Hm[a * n + b] = Hm[b * n + a] }
        Hm[a * n + a] += lam2 + wr
        g[a] -= wr * Double((q[chain[a]] - restAngles[chain[a]]) * .pi / 180)
      }
      guard solveLinear(&Hm, &g, n) else { break }
      for (c, k) in chain.enumerated() {
        let j = model.joints[k]
        let v = q[k] + max(-20, min(20, Float(g[c]) * 180 / .pi))   // 1 回に 20° まで
        q[k] = min(max(v, j.min ?? -180), j.max ?? 180)
      }
    }
  }

  /// ルートの変換 (robotFK の root) → ルートのリンクのワールドの変換 (RobotScene.setFrame の root)
  func rootLinkPose(_ T: simd_float4x4) -> simd_float4x4 { T * model.links[rootLink].rest }

  // MARK: 全部のコマ (動作として再生する用)

  /// 全部のコマの関節角とルート (RobotMotion). progress(0..1) を途中で呼ぶ. cancelled() が true なら nil
  func makeMotion(_ method: RetargetMethod, name: String, progress: ((Double) -> Void)? = nil, cancelled: (() -> Bool)? = nil) -> RobotMotion? {
    var frames = [[Float]](), roots = [[Float]]()
    var xy0: SIMD2<Float>? = nil                // 初めのコマの腰の水平の位置を 0 にする (ロボットの今の場所から歩き出す)
    frames.reserveCapacity(motion.frames); roots.reserveCapacity(motion.frames)
    resetGMR()
    for i in 0..<motion.frames {
      if i % 200 == 0 { if cancelled?() == true { return nil }; progress?(Double(i) / Double(max(1, motion.frames))) }
      let r = method == .names ? method1(i) : gmr(i)   // GMR + QP の QP は WholeBodyQP.swift (makeGMRQPMotion)
      var T = r.root
      if xy0 == nil { xy0 = SIMD2(T.columns.3.x, T.columns.3.y) }
      T.columns.3.x -= xy0!.x; T.columns.3.y -= xy0!.y
      frames.append(r.angles); roots.append(rootLinkPose(T).rootArray)
    }
    progress?(1)
    return RobotMotion(name: name, fps: Float(motion.fps), frames: frames, root: roots)
  }
}
