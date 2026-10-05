// PhysicsSim.swift : RobotModel から ODE の物理モデルを作って動かす (eusdyna と同じ: 剛体リンク + サーボ + 床)
//   JSON に "physics" (eus2physics.l が書く質量・重心・慣性・サーボ) があれば使い, なければ形から見積もる
import Foundation
import simd

struct PhysLink: Codable { var mass: Double?; var com: [Double]?; var inertia: [Double]?; var shapes: [PhysShape]? }
struct PhysShape: Codable { var type: String; var size: [Double]?; var radius: Double?; var length: Double?; var pos: [Double]?; var rot: [Double]? }
struct PhysJoint: Codable { var motor: String?; var fmax: Double?; var vmax: Double?; var kp: Double? }
struct PhysWorld: Codable { var gravity: [Double]?; var dt: Double?; var erp: Double?; var cfm: Double?; var quickstep: Bool?; var iterations: Int? }
struct PhysContact: Codable { var mu: Double?; var soft_erp: Double?; var soft_cfm: Double?; var bounce: Double?; var bounce_vel: Double?; var max_contacts: Int? }
struct PhysMotor: Codable { var kp: Double?; var fmax: Double? }
struct Physics: Codable { var links: [PhysLink]?; var joints: [PhysJoint]?; var world: PhysWorld?; var contact: PhysContact?; var odedyna_motor: PhysMotor? }

/// 関節角 (度・mm) からリンクのワールドの位置姿勢 (z が上, m) を求める
func forwardKinematics(_ m: RobotModel, _ angles: [Float], root: simd_float4x4? = nil) -> [simd_float4x4] {
  var local = m.links.map { $0.rest }
  for (k, j) in m.joints.enumerated() where k < angles.count {
    let ax = simd_normalize(SIMD3(j.axis[0], j.axis[1], j.axis[2]))
    var t = matrix_identity_float4x4
    if j.type == "linear" { t.columns.3 = SIMD4(ax * angles[k] / 1000, 1) } else { t = simd_float4x4(simd_quatf(angle: angles[k] * .pi / 180, axis: ax)) }
    local[j.link] = local[j.link] * t
  }
  var w = [simd_float4x4]()
  for (i, l) in m.links.enumerated() { w.append(l.parent >= 0 ? w[l.parent] * local[i] : (root ?? matrix_identity_float4x4) * local[i]) }
  return w
}

final class PhysicsSim {
  let model: RobotModel
  private var sim: OpaquePointer?
  let dt: Double
  private(set) var time = 0.0
  var targets: [Float]

  let realServo: Bool
  private var acc = 0.0

  /// realServo: サーボの力と速さを KRS の公称値に制限する (false なら eusdyna と同じく実質無制限)
  init(model: RobotModel, angles: [Float], realServo: Bool = false) {
    self.realServo = realServo
    self.model = model
    let ph = model.physics
    dt = ph?.world?.dt ?? 0.001
    targets = angles
    let g = ph?.world?.gravity ?? [0, 0, -9.8]
    // 関節の CFM: JSON の 0.01 (SI 単位) だと関節が伸びて 2 cm 沈むので 1e-5 以下にする (odedyna.l の他の設定は 1e-6〜1e-7)
    sim = odesim_create(g, ph?.world?.erp ?? 0.2, min(ph?.world?.cfm ?? 1e-5, 1e-5),
                                      ph?.contact?.mu ?? 1.0, ph?.contact?.soft_erp ?? 0.2, ph?.contact?.soft_cfm ?? 1e-4,
                                      ph?.contact?.bounce ?? 0, Int32(ph?.world?.iterations ?? 50))
    odesim_set_options(ptr, (ph?.world?.quickstep ?? (ph == nil)) ? 1 : 0, ph?.contact?.max_contacts.map { Int32($0) } ?? 4, ph?.contact?.bounce_vel ?? 0.05)
    // 初めの姿勢: 足の裏 (メッシュのいちばん低い点) が床に触れる高さに置く
    var w = forwardKinematics(model, angles)
    var zmin = Float.greatestFiniteMagnitude
    for (i, l) in model.links.enumerated() {
      for me in l.meshes { var k = 0; while k + 2 < me.vertices.count { zmin = min(zmin, (w[i] * SIMD4(me.vertices[k], me.vertices[k + 1], me.vertices[k + 2], 1)).z); k += 3 } }
      for sh in ph?.links?[safe: i]?.shapes ?? [] { for c in PhysicsSim.corners(sh) { zmin = min(zmin, (w[i] * SIMD4(c, 1)).z) } }
    }
    if zmin.isFinite { let lift = 0.001 - zmin; for i in w.indices { w[i].columns.3.z += lift } }
    for (i, l) in model.links.enumerated() {
      let p = ph?.links?[safe: i]
      let (mass, com, inertia) = PhysicsSim.massProps(l, p)
      let T = w[i]
      let pos = [Double(T.columns.3.x), Double(T.columns.3.y), Double(T.columns.3.z)]
      let rot = (0..<3).flatMap { r in (0..<3).map { c in Double(T[c][r]) } }
      let li = odesim_add_link(ptr, mass, com, inertia, pos, rot)
      let shapes = p?.shapes ?? [PhysShape(type: "mesh")]
      for s in shapes {
        if s.type == "box", let size = s.size {
          odesim_add_box(ptr, li, size, s.pos ?? [0, 0, 0], s.rot ?? [1, 0, 0, 0, 1, 0, 0, 0, 1])
        } else if s.type == "cylinder", let r = s.radius, let len = s.length {
          odesim_add_cylinder(ptr, li, r, len, s.pos ?? [0, 0, 0], s.rot ?? [1, 0, 0, 0, 1, 0, 0, 0, 1])
        } else {
          for me in l.meshes where me.indices.count >= 3 {
            let idx = me.indices.map { Int32($0) }
            me.vertices.withUnsafeBufferPointer { v in idx.withUnsafeBufferPointer { ix in
              odesim_add_mesh(ptr, li, v.baseAddress, Int32(me.vertices.count / 3), ix.baseAddress, Int32(idx.count)) } }
          }
        }
      }
    }
    for (k, j) in model.joints.enumerated() {
      let child = j.link, parent = model.links[child].parent
      let T = w[child]
      let ax = simd_normalize(T * SIMD4(j.axis[0], j.axis[1], j.axis[2], 0))
      let jp = ph?.joints?[safe: k]
      let lin = j.type == "linear"
      // 既定は eusdyna (odedyna_motor: kp 10, 力は実質無制限). realServo なら KRS の公称トルク
      let em = ph?.odedyna_motor
      let fmax = realServo ? (jp?.fmax ?? 1.36) : (em?.fmax ?? jp?.fmax ?? (lin ? 20 : 2.0))
      let vmax = realServo ? (jp?.vmax ?? 8.0) : 1e6, kp = em?.kp ?? jp?.kp ?? 30
      _ = odesim_add_joint(ptr, Int32(parent), Int32(child), lin ? 1 : 0,
                           [Double(T.columns.3.x), Double(T.columns.3.y), Double(T.columns.3.z)],
                           [Double(ax.x), Double(ax.y), Double(ax.z)], 0, 0, fmax, vmax, kp)
      let s = lin ? 0.001 : Double.pi / 180
      // 可動範囲の端 (ストップ) は 1° (1 mm) 外側に置く. サーボが端に押し付けると軽いリンクで発散するため
      // (h7 の指など). 始めの角度が範囲の外なら, それも含める. 目標は setTargets で範囲の中に収める
      let q = Double(angles[safe: k] ?? 0), lo = Double(j.min ?? -180), hi = Double(j.max ?? 180)
      odesim_set_joint_offset(ptr, Int32(k), q * s, (min(lo, q) - 1) * s, (max(hi, q) + 1) * s)
      if jp?.motor == "rotation" { odesim_set_joint_mode(ptr, Int32(k), 1) }
    }
    setTargets(angles)
  }

  deinit { odesim_destroy(ptr) }
  private var ptr: OpaquePointer { sim! }

  /// 質量・重心・慣性: JSON の値, なければメッシュの外接箱から密度で見積もる
  static func massProps(_ l: RobotLink, _ p: PhysLink?) -> (Double, [Double], [Double]) {
    if let m = p?.mass, let c = p?.com, let I = p?.inertia, m > 0 { return (m, c, I) }
    var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude), hi = -lo
    for me in l.meshes { var k = 0; while k + 2 < me.vertices.count { let v = SIMD3(me.vertices[k], me.vertices[k + 1], me.vertices[k + 2]); lo = simd_min(lo, v); hi = simd_max(hi, v); k += 3 } }
    if !lo.x.isFinite { return (0.005, [0, 0, 0], [1e-7, 0, 0, 1e-7, 0, 1e-7]) }
    let s = simd_double3(hi - lo), c = simd_double3((hi + lo) / 2)
    let mass = max(0.005, s.x * s.y * s.z * 400)   // 樹脂の部品とサーボで平均 400 kg/m³ くらい (目安)
    let I = [mass * (s.y * s.y + s.z * s.z) / 12, 0, 0, mass * (s.x * s.x + s.z * s.z) / 12, 0, mass * (s.x * s.x + s.y * s.y) / 12]
    return (mass, [c.x, c.y, c.z], I)
  }

  /// サーボの目標 (度・mm)
  func setTargets(_ a: [Float]) {
    targets = a
    let t = model.joints.enumerated().map { k, j -> Double in
      var v = Double(a[safe: k] ?? 0)
      if model.physics?.joints?[safe: k]?.motor != "rotation" { v = min(max(v, Double(j.min ?? -1e6)), Double(j.max ?? 1e6)) }
      return v * (j.type == "linear" ? 0.001 : .pi / 180)
    }
    odesim_set_targets(ptr, t, Int32(t.count))
  }
  func setServo(_ on: Bool) { odesim_set_servo(ptr, on ? 1 : 0) }

  /// 実時間で seconds だけ進める (dt の端数は次に持ち越す)
  func step(_ seconds: Double) {
    acc += seconds
    let n = Int(acc / dt)
    if n > 0 { odesim_step(ptr, dt, Int32(n)); acc -= Double(n) * dt; time += Double(n) * dt }
  }

  /// 形状の頂点 (リンク座標系, 床に置く高さを決めるため)
  static func corners(_ s: PhysShape) -> [SIMD3<Float>] {
    let h: SIMD3<Double>
    if s.type == "box", let z = s.size { h = SIMD3(z[0], z[1], z[2]) / 2 }
    else if s.type == "cylinder", let r = s.radius, let l = s.length { h = SIMD3(r, r, l / 2) }
    else { return [] }
    let p = s.pos ?? [0, 0, 0], r = s.rot ?? [1, 0, 0, 0, 1, 0, 0, 0, 1]
    var out = [SIMD3<Float>]()
    for sx in [-1.0, 1.0] { for sy in [-1.0, 1.0] { for sz in [-1.0, 1.0] {
      let v = SIMD3(sx * h.x, sy * h.y, sz * h.z)
      out.append(SIMD3<Float>(Float(p[0] + r[0] * v.x + r[1] * v.y + r[2] * v.z), Float(p[1] + r[3] * v.x + r[4] * v.y + r[5] * v.z), Float(p[2] + r[6] * v.x + r[7] * v.y + r[8] * v.z)))
    } } }
    return out
  }

  /// リンクのワールドの位置姿勢 (z が上)
  func linkPoses() -> [simd_float4x4] {
    (0..<model.links.count).map { i in
      var p = [Double](repeating: 0, count: 3), r = [Double](repeating: 0, count: 9)
      odesim_link_pose(ptr, Int32(i), &p, &r)
      return simd_float4x4(columns: (SIMD4(Float(r[0]), Float(r[3]), Float(r[6]), 0), SIMD4(Float(r[1]), Float(r[4]), Float(r[7]), 0),
                                     SIMD4(Float(r[2]), Float(r[5]), Float(r[8]), 0), SIMD4(Float(p[0]), Float(p[1]), Float(p[2]), 1)))
    }
  }
  /// 関節の今の値 (度・mm)
  func jointValues() -> [Float] {
    model.joints.enumerated().map { k, j in Float(odesim_joint_value(ptr, Int32(k))) * (j.type == "linear" ? 1000 : 180 / .pi) }
  }
  var contacts: Int { Int(odesim_contacts(ptr)) }
}

extension Array { subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil } }
