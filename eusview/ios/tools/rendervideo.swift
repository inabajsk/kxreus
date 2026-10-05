// rendervideo.swift : ロボットの JSON を Mac の SceneKit で描いて動画 (mp4) にする (スライド用, オフライン・決定的)
//   アプリと同じ RobotModel.swift / PhysicsSim.swift (+ odesim) を使う. 物理は実時間 (1 コマ 1/fps 秒) で進める
//   ビルドと実行: tools/build-rendervideo.sh を見よ.  ./rendervideo job.json  (job の形式は下の VideoSpec)
//   - mode "pose": 姿勢のまま (orbit でカメラを回すとターンテーブル)
//   - mode "kinematic": 動作の関節角をそのまま表示 (アプリの物理なしモード, ルートは動かない. root があれば使う)
//   - mode "physics": PhysicsSim (ODE) で, 動作のフレーム (fps) をサーボの目標にして dt ごとに進める
//   - 比べるとき: panels を 2 つ並べ, mu / contacts / softCFM / worldCFM / realServo / servoOffAt を変える
//   - ラベルの {x} {y} {z} {dx} {dy} {t} {c} {up} はルートリンクの位置 (mm, x y は始めからの差), 時間, 接触点, 上向き成分
import AppKit
import SceneKit
import simd

var gWorldCFMOverride: Double? = nil   // build-rendervideo.sh が PhysicsSim.swift の写しに差し込む (比較用)

struct CamSpec: Codable {
  var az: Float?        // 方位 [度] (0 = ロボットの前 +x から, 90 = 左 +y から)
  var el: Float?        // 仰角 [度]
  var zoom: Float?      // 1 = 全体が入る, 小さいほど寄る
  var orbit: Float?     // 回る速さ [度/秒]
  var targetZ: Float?   // 注視点の高さ (ロボットの高さに対する割合). なければ中心
  var target: [Float]?  // 注視点を直接 (ワールド, m)
  var fov: Float?
  var follow: Bool?     // 物理: ルートの x y を追う
}
struct PanelSpec: Codable {
  var robot: String
  var mode: String?
  var pose: String?
  var motion: String?
  var motions: [String]?     // 続けて再生する動作 (間に gap 秒止まる)
  var gap: Double?
  var motionStart: Double?   // この時刻まで最初の姿勢のまま
  var loop: Bool?
  var label: String?
  var mu: Double?; var contacts: Int?; var softCFM: Double?; var worldCFM: Double?
  var realServo: Bool?; var servoOffAt: Double?; var fmax: Double?
  var cam: CamSpec?
  var floorTile: Float?
  var ground: Bool?          // 物理なし: コマごとにいちばん低い点を床 (z = 0) に合わせる (アプリはルートを動かさない)
}
struct VideoSpec: Codable {
  var out: String
  var width: Int; var height: Int
  var fps: Double?
  var seconds: Double
  var poster: Double?        // ポスター (PNG) の時刻
  var posterOut: String?
  var title: String?         // 左上の説明 (\n で改行)
  var cols: Int?; var rows: Int?
  var panels: [PanelSpec]
  var crf: Int?
  var bg: String?            // "light" (既定) | "dark"
  var log: Double?           // ログを出す間隔 [秒]
}

func motionMatch(_ m: RobotModel, _ key: String) -> RobotMotion? {
  m.motions?.first(where: { $0.name == key }) ?? m.motions?.first(where: { $0.name.contains(key) })
}

func gridImage() -> NSImage {
  let n = 256
  let img = NSImage(size: NSSize(width: n, height: n))
  img.lockFocus()
  NSColor(white: 0.93, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: n, height: n).fill()
  NSColor(white: 0.76, alpha: 1).setFill()
  NSRect(x: 0, y: 0, width: n, height: 3).fill(); NSRect(x: 0, y: 0, width: 3, height: n).fill()
  img.unlockFocus()
  return img
}
let gGrid = gridImage()

func meshGeometry(_ m: RobotMesh) -> SCNGeometry {
  let v = m.vertices
  var pos = [SCNVector3](), nor = [SCNVector3]()
  var i = 0
  while i + 2 < m.indices.count {
    let p = (0..<3).map { k -> SIMD3<Float> in let j = Int(m.indices[i + k]) * 3; return SIMD3(v[j], v[j + 1], v[j + 2]) }
    let n = simd_normalize(simd_cross(p[1] - p[0], p[2] - p[0]))
    let nn = n.x.isFinite ? n : SIMD3<Float>(0, 0, 1)
    for q in p { pos.append(SCNVector3(q)); nor.append(SCNVector3(nn)) }
    i += 3
  }
  let g = SCNGeometry(sources: [SCNGeometrySource(vertices: pos), SCNGeometrySource(normals: nor)],
                      elements: [SCNGeometryElement(indices: (0..<Int32(pos.count)).map { $0 }, primitiveType: .triangles)])
  let mat = SCNMaterial()
  let c = m.color + [1, 1, 1, 1].dropFirst(m.color.count)
  mat.diffuse.contents = NSColor(red: CGFloat(c[0]), green: CGFloat(c[1]), blue: CGFloat(c[2]), alpha: CGFloat(c[3]))
  mat.lightingModel = .physicallyBased; mat.metalness.contents = 0.1; mat.roughness.contents = 0.6; mat.isDoubleSided = true
  g.materials = [mat]
  return g
}

/// EusLisp の座標 (z が上) → SceneKit (y が上)
func e2s(_ v: SIMD3<Float>) -> SCNVector3 { SCNVector3(v.x, v.z, -v.y) }

final class Panel {
  let spec: PanelSpec
  var model: RobotModel
  let scene = SCNScene()
  let base = SCNNode()
  var nodes = [SCNNode]()
  let cam = SCNNode()
  let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
  var motion: RobotMotion?
  var segs = [(name: String, start: Int)]()
  var sim: PhysicsSim?
  var angles0: [Float]
  var lift: Float = 0
  var center = SIMD3<Float>(0, 0, 0), height: Float = 0.3, radius: Float = 0.2
  var root0 = SIMD3<Float>(0, 0, 0)
  var rootNow = matrix_identity_float4x4
  var simT = 0.0
  var servoOff = false

  init(_ s: PanelSpec, dark: Bool) {
    spec = s
    model = try! JSONDecoder().decode(RobotModel.self, from: Data(contentsOf: URL(fileURLWithPath: s.robot)))
    if let k = s.motion { motion = motionMatch(model, k); if motion == nil { print("!! motion not found:", k) } }
    if let ks = s.motions {   // つなぐ (ルートの root は使わない)
      var fr = [[Float]](); var fps: Float = 50
      for k in ks {
        guard let mo = motionMatch(model, k) else { print("!! motion not found:", k); continue }
        fps = mo.fps
        // 間 (gap 秒): 前の動作の最後から次の動作の最初へ直線でつなぐ (いきなり目標が飛ぶと物理が発散するため)
        if let g = s.gap, let last = fr.last, let first = mo.frames.first {
          let n = max(1, Int(g * Double(mo.fps)))
          for i in 0..<n { let u = Float(i + 1) / Float(n); fr.append(zip(last, first).map { $0 + ($1 - $0) * u }) }
        }
        segs.append((mo.name, fr.count))
        fr += mo.frames
      }
      motion = RobotMotion(name: ks.joined(separator: "+"), fps: fps, frames: fr, root: nil)
    } else if let m = motion { segs = [(m.name, 0)] }
    let pose = model.poses?[s.pose ?? "reset-pose"] ?? model.poses?["init-pose"] ?? [Float](repeating: 0, count: model.joints.count)
    angles0 = motion?.frames.first ?? pose
    if s.pose != nil && motion == nil { angles0 = pose }
    base.eulerAngles.x = -.pi / 2
    scene.rootNode.addChildNode(base)
    for l in model.links {
      let n = SCNNode(); n.simdTransform = l.rest
      for m in l.meshes { n.addChildNode(SCNNode(geometry: meshGeometry(m))) }
      nodes.append(n); (l.parent >= 0 ? nodes[l.parent] : base).addChildNode(n)
    }
    // 大きさ: 最初の姿勢の FK
    var rootM: simd_float4x4? = nil
    if let r = motion?.root?.first, r.count >= 12 { rootM = Panel.rootMatrix(r) }
    let w = forwardKinematics(model, angles0, root: rootM.map { $0 * simd_inverse(model.links[0].rest) })
    var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude), hi = -lo
    for (i, l) in model.links.enumerated() {
      for me in l.meshes { var k = 0; while k + 2 < me.vertices.count { let p = w[i] * SIMD4(me.vertices[k], me.vertices[k + 1], me.vertices[k + 2], 1); lo = simd_min(lo, SIMD3(p.x, p.y, p.z)); hi = simd_max(hi, SIMD3(p.x, p.y, p.z)); k += 3 } }
    }
    lift = -lo.z
    height = hi.z - lo.z
    center = (lo + hi) / 2; center.z += lift
    radius = max(simd_length(hi - lo) / 2, 0.05)
    // 物理
    if s.mode == "physics" {
      if model.physics == nil { model.physics = Physics(links: nil, joints: nil, world: nil, contact: nil, odedyna_motor: nil) }
      if model.physics?.contact == nil { model.physics?.contact = PhysContact(mu: nil, soft_erp: nil, soft_cfm: nil, bounce: nil, bounce_vel: nil, max_contacts: nil) }
      if let v = s.mu { model.physics?.contact?.mu = v }
      if let v = s.contacts { model.physics?.contact?.max_contacts = v }
      if let v = s.softCFM { model.physics?.contact?.soft_cfm = v }
      if let v = s.fmax { if model.physics?.odedyna_motor == nil { model.physics?.odedyna_motor = PhysMotor(kp: 10, fmax: v) } else { model.physics?.odedyna_motor?.fmax = v } }
      gWorldCFMOverride = s.worldCFM
      sim = PhysicsSim(model: model, angles: angles0, realServo: s.realServo ?? false)
      gWorldCFMOverride = nil
      let p = sim!.linkPoses()[0].columns.3
      root0 = SIMD3(p.x, p.y, p.z)
    }
    // 床 (薄い格子), 光
    let tile = s.floorTile ?? Panel.niceTile(height)
    let floor = SCNFloor(); floor.reflectivity = 0
    let fm0 = SCNMaterial(); fm0.diffuse.contents = NSColor(white: 0.93, alpha: 1); fm0.lightingModel = .lambert
    floor.materials = [fm0]
    let fnode = SCNNode(geometry: floor); fnode.position.y = -0.0005
    scene.rootNode.addChildNode(fnode)
    // 格子: 大きな板に繰り返しの模様 (1 マス = tile [m])
    let L = CGFloat(tile * 160)
    let plane = SCNPlane(width: L, height: L)
    let fm = SCNMaterial(); fm.diffuse.contents = gGrid; fm.diffuse.wrapS = .repeat; fm.diffuse.wrapT = .repeat
    fm.diffuse.mipFilter = .linear; fm.diffuse.maxAnisotropy = 16
    fm.diffuse.contentsTransform = SCNMatrix4MakeScale(160, 160, 1)
    fm.lightingModel = .lambert
    plane.materials = [fm]
    let pn = SCNNode(geometry: plane); pn.eulerAngles.x = -.pi / 2
    pn.position = SCNVector3(center.x - Float(tile) * 0.5, 0, -center.y)
    scene.rootNode.addChildNode(pn)
    let sun = SCNNode(); sun.light = SCNLight(); sun.light!.type = .directional; sun.light!.castsShadow = true
    sun.light!.intensity = 900; sun.light!.shadowMapSize = CGSize(width: 2048, height: 2048); sun.light!.shadowRadius = 3
    sun.light!.shadowSampleCount = 8; sun.light!.shadowColor = NSColor(white: 0, alpha: 0.35)
    sun.light!.orthographicScale = CGFloat(radius * 3); sun.light!.automaticallyAdjustsShadowProjection = false
    sun.light!.zNear = 0.01; sun.light!.zFar = CGFloat(radius * 20)
    sun.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 5, 0)
    sun.position = e2s(center) ; sun.simdPosition += sun.simdWorldFront * -radius * 6
    scene.rootNode.addChildNode(sun)
    let fill = SCNNode(); fill.light = SCNLight(); fill.light!.type = .directional; fill.light!.intensity = 300
    fill.eulerAngles = SCNVector3(-0.3, -2.4, 0); scene.rootNode.addChildNode(fill)
    let amb = SCNNode(); amb.light = SCNLight(); amb.light!.type = .ambient; amb.light!.intensity = 450; scene.rootNode.addChildNode(amb)
    // 背景
    let bg = NSImage(size: NSSize(width: 64, height: 256)); bg.lockFocus()
    let top = dark ? NSColor(red: 0.16, green: 0.20, blue: 0.28, alpha: 1) : NSColor(red: 0.80, green: 0.86, blue: 0.93, alpha: 1)
    let bot = dark ? NSColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 1) : NSColor(red: 0.97, green: 0.98, blue: 1.0, alpha: 1)
    NSGradient(starting: bot, ending: top)!.draw(in: NSRect(x: 0, y: 0, width: 64, height: 256), angle: 90)
    bg.unlockFocus()
    scene.background.contents = bg
    cam.camera = SCNCamera(); cam.camera!.fieldOfView = CGFloat(s.cam?.fov ?? 30); cam.camera!.zNear = 0.005; cam.camera!.zFar = 100
    scene.rootNode.addChildNode(cam)
    renderer.scene = scene; renderer.pointOfView = cam; renderer.autoenablesDefaultLighting = false
    apply(t: 0)
  }

  static func niceTile(_ h: Float) -> Float {
    for t: Float in [0.02, 0.05, 0.1, 0.2, 0.5, 1] where t >= h / 8 { return t }
    return 1
  }
  static func rootMatrix(_ v: [Float]) -> simd_float4x4 {
    simd_float4x4(columns: (SIMD4(v[3], v[6], v[9], 0), SIMD4(v[4], v[7], v[10], 0), SIMD4(v[5], v[8], v[11], 0), SIMD4(v[0], v[1], v[2], 1)))
  }

  func frameAt(_ t: Double) -> Int? {
    guard let m = motion else { return nil }
    let tt = t - (spec.motionStart ?? 0)
    if tt < 0 { return 0 }
    var i = Int(tt * Double(m.fps))
    if spec.loop ?? false { i %= m.frames.count } else { i = min(i, m.frames.count - 1) }
    return i
  }

  func setAngles(_ a: [Float]) {
    for (k, j) in model.joints.enumerated() where k < a.count {
      let ax = simd_normalize(SIMD3(j.axis[0], j.axis[1], j.axis[2]))
      var m = matrix_identity_float4x4
      if j.type == "linear" { m.columns.3 = SIMD4(ax * a[k] / 1000, 1) } else { m = simd_float4x4(simd_quatf(angle: a[k] * .pi / 180, axis: ax)) }
      nodes[j.link].simdTransform = model.links[j.link].rest * m
    }
  }

  /// 時刻 t の姿勢にする (物理は t まで dt ごとに進める)
  func apply(t: Double) {
    if let sim {
      while simT + 1e-9 < t {
        if let off = spec.servoOffAt, !servoOff, simT >= off { sim.setServo(false); servoOff = true }
        if let i = frameAt(simT) { sim.setTargets(motion!.frames[i]) }
        sim.step(sim.dt); simT += sim.dt
      }
      let w = sim.linkPoses()
      for (i, l) in model.links.enumerated() { nodes[i].simdTransform = l.parent >= 0 ? simd_inverse(w[l.parent]) * w[i] : w[i] }
      rootNow = w[0]
    } else {
      var a = angles0
      if let i = frameAt(t) { a = motion!.frames[i] }
      setAngles(a)
      var r = model.links[0].rest
      if let m = motion, let i = frameAt(t), let rr = m.root, i < rr.count, rr[i].count >= 12 { r = Panel.rootMatrix(rr[i]) }
      r.columns.3.z += lift
      if spec.ground ?? false {
        let w = forwardKinematics(model, a, root: r * simd_inverse(model.links[0].rest))
        var zmin = Float.greatestFiniteMagnitude
        for (i, l) in model.links.enumerated() {
          let row = SIMD4<Float>(w[i][0][2], w[i][1][2], w[i][2][2], w[i][3][2])
          for me in l.meshes { var k = 0; while k + 2 < me.vertices.count { zmin = min(zmin, simd_dot(row, SIMD4(me.vertices[k], me.vertices[k + 1], me.vertices[k + 2], 1))); k += 3 } }
        }
        if zmin.isFinite { r.columns.3.z -= zmin }
      }
      nodes[0].simdTransform = r
      rootNow = r
      if t == 0 { root0 = SIMD3(r.columns.3.x, r.columns.3.y, r.columns.3.z) }
    }
    // カメラ
    let c = spec.cam
    let az0: Float = c?.az ?? 35, orb: Float = c?.orbit ?? 0, el0: Float = c?.el ?? 18
    let az: Float = (az0 + orb * Float(t)) * Float.pi / 180
    let el: Float = el0 * Float.pi / 180
    var tg = center
    if let z = c?.targetZ { tg.z = height * z }
    if let v = c?.target, v.count == 3 { tg = SIMD3(v[0], v[1], v[2]) }
    if c?.follow ?? false { tg.x += rootNow.columns.3.x - root0.x; tg.y += rootNow.columns.3.y - root0.y }
    let fov: Float = (c?.fov ?? 30) * Float.pi / 180
    let zm: Float = c?.zoom ?? 1
    let d: Float = 1.3 * radius / sin(fov / 2) * zm   // 1.3: 余白
    let dir = SIMD3<Float>(cos(el) * cos(az), cos(el) * sin(az), sin(el))
    let p = tg + d * dir
    cam.position = e2s(p)
    cam.look(at: e2s(tg), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
  }

  func label(_ t: Double) -> String {
    guard var s = spec.label else { return "" }
    let p = rootNow.columns.3
    let f = { (v: Float) in String(format: "%+.0f", v) }
    s = s.replacingOccurrences(of: "{dx}", with: f((p.x - root0.x) * 1000))
    s = s.replacingOccurrences(of: "{dy}", with: f((p.y - root0.y) * 1000))
    s = s.replacingOccurrences(of: "{x}", with: f((p.x - root0.x) * 1000))
    s = s.replacingOccurrences(of: "{y}", with: f((p.y - root0.y) * 1000))
    s = s.replacingOccurrences(of: "{z}", with: String(format: "%.0f", p.z * 1000))
    s = s.replacingOccurrences(of: "{t}", with: String(format: "%.1f", t))
    s = s.replacingOccurrences(of: "{c}", with: "\(sim?.contacts ?? 0)")
    s = s.replacingOccurrences(of: "{up}", with: String(format: "%.2f", rootNow.columns.2.z))
    s = s.replacingOccurrences(of: "{servo}", with: servoOff ? "オフ（脱力）" : "オン")
    s = s.replacingOccurrences(of: "{name}", with: model.name)
    var mn = ""
    if let i = frameAt(t) { for g in segs where g.start <= i { mn = g.name } }
    // 先頭の番号 (XL2G_201_ など) を除く
    let parts = mn.split(separator: "_", omittingEmptySubsequences: false)
    if let k = parts.firstIndex(where: { $0.unicodeScalars.contains { $0.value > 127 } }) { mn = parts[k...].joined(separator: "_") }
    s = s.replacingOccurrences(of: "{motion}", with: mn)
    return s
  }
}

// ---------- 文字 ----------
func font(_ size: CGFloat, bold: Bool = false) -> NSFont {
  for n in bold ? ["BIZUDPGothic-Bold", "HiraginoSans-W6"] : ["BIZUDPGothic-Regular", "BIZUDPGothic", "HiraginoSans-W3"] {
    if let f = NSFont(name: n, size: size) { return f }
  }
  return NSFont.systemFont(ofSize: size)
}
/// 左上 (x, yTop) に複数行の文字を, 半透明の角丸の板の上に描く (CG の座標は左下が原点, H は全体の高さ)
func drawText(_ ctx: CGContext, _ text: String, x: CGFloat, yTop: CGFloat, H: CGFloat, size: CGFloat, dark: Bool, bold: Bool = false, bottom: Bool = false) {
  guard !text.isEmpty else { return }
  let lines = text.components(separatedBy: "\n")
  let fg = dark ? NSColor.white : NSColor(white: 0.08, alpha: 1)
  let attrs: [[NSAttributedString.Key: Any]] = lines.indices.map { i in
    [.font: font(i == 0 ? size : size * 0.82, bold: bold && i == 0), .foregroundColor: fg] }
  let strs = lines.indices.map { NSAttributedString(string: lines[$0], attributes: attrs[$0]) }
  let w = strs.map { $0.size().width }.max()! + size * 0.9
  let hs = strs.map { $0.size().height * 1.08 }
  let h = hs.reduce(0, +) + size * 0.5
  let y0 = bottom ? yTop : H - yTop - h   // bottom なら yTop は下からの位置
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
  (dark ? NSColor(white: 0, alpha: 0.55) : NSColor(white: 1, alpha: 0.78)).setFill()
  NSBezierPath(roundedRect: NSRect(x: x, y: y0, width: w, height: h), xRadius: size * 0.35, yRadius: size * 0.35).fill()
  var y = y0 + h - size * 0.25
  for (i, s) in strs.enumerated() { y -= hs[i]; s.draw(at: NSPoint(x: x + size * 0.45, y: y + hs[i] * 0.04)) }
  NSGraphicsContext.restoreGraphicsState()
}

// ---------- main ----------
let spec = try! JSONDecoder().decode(VideoSpec.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let W = spec.width, H = spec.height, fps = spec.fps ?? 30
let dark = spec.bg == "dark"
let cols = spec.cols ?? spec.panels.count, rows = spec.rows ?? 1
let pw = W / cols, ph = H / rows
let panels = spec.panels.map { Panel($0, dark: dark) }
let nframes = Int((spec.seconds * fps).rounded())

let ff = Process()
ff.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
ff.arguments = ["-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", "\(W)x\(H)", "-r", "\(fps)", "-i", "-",
                "-c:v", "libx264", "-preset", "slow", "-crf", "\(spec.crf ?? 24)", "-pix_fmt", "yuv420p", "-profile:v", "high", "-level", "4.0",
                "-movflags", "+faststart", "-an", spec.out]
let pipe = Pipe(); ff.standardInput = pipe
try! ff.run()

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let fs = CGFloat(H) / 720 * 24
var logNext = 0.0
for f in 0..<nframes {
  let t = Double(f) / fps
  ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
  for (k, p) in panels.enumerated() {
    p.apply(t: t)
    let img = p.renderer.snapshot(atTime: t, with: CGSize(width: pw, height: ph), antialiasingMode: .multisampling4X)
    let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let cx = k % cols, cy = k / cols
    let rect = CGRect(x: cx * pw, y: H - (cy + 1) * ph, width: pw, height: ph)
    ctx.draw(cg, in: rect)
    let lb = p.label(t)
    if !lb.isEmpty {
      let small = rows > 1 || cols > 2
      drawText(ctx, lb, x: rect.minX + fs * 0.5, yTop: rect.minY + fs * 0.5, H: CGFloat(H), size: small ? fs * 0.8 : fs * 0.9, dark: dark, bottom: true)
    }
  }
  if cols > 1 || rows > 1 {   // 仕切り
    ctx.setFillColor(CGColor(gray: 1, alpha: 0.9))
    for c in 1..<max(cols, 1) { ctx.fill(CGRect(x: c * pw - 1, y: 0, width: 2, height: H)) }
    for r in 1..<max(rows, 1) { ctx.fill(CGRect(x: 0, y: r * ph - 1, width: W, height: 2)) }
  }
  if let tt = spec.title { drawText(ctx, tt, x: fs * 0.6, yTop: fs * 0.6, H: CGFloat(H), size: fs, dark: dark, bold: true) }
  if let lg = spec.log, t + 1e-9 >= logNext {
    logNext += lg
    print(String(format: "t=%5.2f ", t) + panels.map { p in
      let r = p.rootNow.columns.3
      return String(format: "[dx %+.1f dy %+.1f z %.1f mm up %.2f c %d]", (r.x - p.root0.x) * 1000, (r.y - p.root0.y) * 1000, r.z * 1000, p.rootNow.columns.2.z, p.sim?.contacts ?? 0)
    }.joined(separator: " "))
  }
  let data = ctx.data!.assumingMemoryBound(to: UInt8.self)
  pipe.fileHandleForWriting.write(Data(bytes: data, count: W * H * 4))
  if let pt = spec.poster, f == Int((pt * fps).rounded()) {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    let po = spec.posterOut ?? (spec.out as NSString).deletingPathExtension + ".png"
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: po))
  }
}
try! pipe.fileHandleForWriting.close()
ff.waitUntilExit()
print("wrote", spec.out, nframes, "frames")
