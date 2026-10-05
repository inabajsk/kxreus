// BVHView.swift : BVH（モーションキャプチャ）の骨格を再生する画面
//   ・種類の一覧 → ファイルの一覧 (名前で探す) → 再生 (止めるまで繰り返す)
//   ・自動再生 (全部): 種類ごと・ファイルごとに順に再生し, 最後まで行ったら最初に戻る
//   ・表示: 骨 (カプセル) と関節 (球), 床. カメラは腰の水平の動きを追う (切り替えられる)
//   ・ロボット (KXR / KHR / JSK) に移して並べる: 棒人形 (左)・関節名で対応 (EusLisp の :copy-state-to と同じ)・GMR・GMR + QP (右)
//     (BVHRetarget.swift, eusview/bvh/RETARGET.md). GMR + QP は全身 QP (WholeBodyQP.swift / wbqp.cpp, eusview/bvh/QP.md) で
//     自己衝突・関節の可動範囲・重心を直したもの. 開いたときに裏で全部のコマを計算する (再生より速いので, 計算したコマから見せる)
//   ・違反の表示 (GMR と GMR + QP): 衝突しているリンクを赤, 可動範囲の端のリンクを橙, 重心 (球) と床への投影, 支持多角形 (緑 = 中, 赤 = 外)
//   起動の引数 -robot kxr|khr|jsk|<名前> -method all|both|names|gmr|qp|gmrqp -violations 0|1
import SwiftUI
import SceneKit
import simd

// MARK: - 一覧

struct BVHHomeView: View {
  let index = loadBVHIndex()
  var body: some View {
    Group {
      if let index, !index.kinds.isEmpty {
        let all = index.kinds.flatMap { k in k.files.map { BVHEntry(kind: k.name, file: $0) } }
        List {
          Section {
            NavigationLink { BVHPlayerView(list: all, start: 0, auto: true) } label: {
              Label("自動再生（全部）", systemImage: "play.circle.fill")
            }
          } footer: {
            Text("\(index.kinds.count) 種類・\(all.count) 本を, 種類ごと・ファイルごとに順に再生します（止めるまで繰り返し）")
          }
          Section("種類") {
            ForEach(index.kinds, id: \.name) { k in
              NavigationLink { BVHFileListView(kind: k) } label: {
                VStack(alignment: .leading, spacing: 2) {
                  Text("\(k.name)（\(k.files.count) 本）")
                  Text(k.title).font(.caption).foregroundStyle(.secondary)
                  Text(String(format: "計 %@・単位 %@・背の高さ %.2f m", bvhDuration(k.duration), k.unit, k.height))
                    .font(.caption2).foregroundStyle(.secondary)
                }
              }
            }
          }
        }
      } else {
        VStack(alignment: .leading, spacing: 12) {
          Text("BVH のデータが入っていません").font(.headline)
          Text("BVH のファイル（~/kxreus/bvh）は git に入れていないので, Mac で変換してからアプリをビルドし直してください。")
          Text("python3 eusview/bvh/convert_bvh.py").font(.system(.footnote, design: .monospaced))
          Text("eusview/bvh/cache/ に書き出され, ビルドのときにアプリに入ります（全部で約 90 MB）。").font(.footnote).foregroundStyle(.secondary)
        }.padding()
      }
    }
    .navigationTitle("BVH")
  }
}

/// 起動の引数 -bvh で開く画面: home / auto / <種類> / <種類>/<名前>
struct BVHLaunchView: View {
  let arg: String
  var body: some View {
    let index = loadBVHIndex()
    let all = (index?.kinds ?? []).flatMap { k in k.files.map { BVHEntry(kind: k.name, file: $0) } }
    if arg == "auto", !all.isEmpty { BVHPlayerView(list: all, start: 0, auto: true) }
    else if let i = all.firstIndex(where: { "\($0.kind)/\($0.file.name)" == arg }) { BVHPlayerView(list: [all[i]], start: 0, auto: false) }
    else if let k = index?.kinds.first(where: { $0.name == arg }) { BVHFileListView(kind: k) }
    else if arg.hasPrefix("auto:"), let i = all.firstIndex(where: { $0.kind == arg.dropFirst(5) }) { BVHPlayerView(list: all, start: i, auto: true) }
    else { BVHHomeView() }
  }
}

func bvhDuration(_ s: Double) -> String {
  s >= 3600 ? String(format: "%.1f 時間", s / 3600) : s >= 60 ? String(format: "%.1f 分", s / 60) : String(format: "%.1f 秒", s)
}

struct BVHFileListView: View {
  let kind: BVHIndexKind
  @State var search = ""
  var shown: [BVHIndexFile] { kind.files.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) } }
  var body: some View {
    let list = kind.files.map { BVHEntry(kind: kind.name, file: $0) }
    List {
      if search.isEmpty {
        NavigationLink { BVHPlayerView(list: list, start: 0, auto: true) } label: {
          Label("自動再生（\(kind.name) を順に）", systemImage: "play.circle")
        }
      }
      ForEach(shown, id: \.self) { f in
        NavigationLink { BVHPlayerView(list: [BVHEntry(kind: kind.name, file: f)], start: 0, auto: false) } label: {
          HStack {
            Text(f.name)
            Spacer()
            Text("\(bvhDuration(f.duration))・\(f.frames) コマ").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
          }
        }
      }
    }
    .listStyle(.plain)
    .overlay { if shown.isEmpty { Text("見つかりません").foregroundStyle(.secondary) } }
    .navigationTitle(kind.name)
    .navigationBarTitleDisplayMode(.inline)
    .searchable(text: $search, prompt: "名前で探す")
  }
}

// MARK: - 3D 表示 (SceneKit)

/// BVH の骨格のノード: 関節ごとに 1 つ (base の子, ワールドの変換をそのまま入れる). 骨は親の関節のノードの子
final class BVHScene {
  let scene = SCNScene()
  let base = SCNNode()          // EusLisp の座標 (z が上) → SceneKit (y が上)
  let stick = SCNNode()         // 棒人形 (base の子, 横にずらす)
  private(set) var nodes = [SCNNode]()
  static let boneColor = UIColor(red: 0.93, green: 0.60, blue: 0.40, alpha: 1)
  static let jointColor = UIColor(red: 0.22, green: 0.42, blue: 0.80, alpha: 1)

  init() {
    base.eulerAngles.x = -.pi / 2
    scene.rootNode.addChildNode(base)
    base.addChildNode(stick)
    addFloorAndLights()
  }

  static func material(_ c: UIColor) -> SCNMaterial {
    let m = SCNMaterial()
    m.diffuse.contents = c
    m.lightingModel = .physicallyBased
    m.metalness.contents = 0.05
    m.roughness.contents = 0.55
    return m
  }

  /// 骨格を作り直す (モーションが変わったとき)
  func setSkeleton(_ h: BVHHeader) {
    nodes.forEach { $0.removeFromParentNode() }
    nodes = []
    let boneMat = BVHScene.material(BVHScene.boneColor), jointMat = BVHScene.material(BVHScene.jointColor)
    func bone(_ to: SIMD3<Float>, _ r: Float) -> SCNNode? {
      let l = simd_length(to)
      guard l > 0.005 else { return nil }
      let g = SCNCapsule(capRadius: CGFloat(r), height: CGFloat(l + 2 * r))
      g.radialSegmentCount = 12
      g.materials = [boneMat]
      let n = SCNNode(geometry: g)
      n.simdPosition = to / 2
      n.simdOrientation = simd_quatf(from: SIMD3(0, 1, 0), to: to / l)
      return n
    }
    for j in h.joints {
      let n = SCNNode()
      n.name = j.name
      let s = SCNSphere(radius: 0.022)
      s.segmentCount = 16
      s.materials = [jointMat]
      n.addChildNode(SCNNode(geometry: s))
      nodes.append(n)
      stick.addChildNode(n)
    }
    for (j, jt) in h.joints.enumerated() where jt.parent >= 0 {
      if let b = bone(SIMD3(jt.offset[0], jt.offset[1], jt.offset[2]) / 1000, 0.016) { nodes[jt.parent].addChildNode(b) }
    }
    for e in h.ends {
      let o = SIMD3(e.offset[0], e.offset[1], e.offset[2]) / 1000
      if let b = bone(o, 0.014) { nodes[e.parent].addChildNode(b) }
    }
  }

  func setFrame(_ w: [simd_float4x4]) {
    for (i, m) in w.enumerated() where i < nodes.count {
      var m = m
      m.columns.3.z += 0.02   // 関節の球が床に埋まらないように (球の半径くらい上げる)
      nodes[i].simdTransform = m
    }
  }

  func addFloorAndLights() {
    let floor = SCNFloor()
    floor.reflectivity = 0.05
    let fm = SCNMaterial()
    fm.diffuse.contents = BVHScene.gridImage()
    fm.diffuse.wrapS = .repeat; fm.diffuse.wrapT = .repeat
    fm.diffuse.contentsTransform = SCNMatrix4MakeScale(100, 100, 1)   // 1 m の格子 (床の模様は 100 m で 1 枚)
    floor.materials = [fm]
    floor.width = 100; floor.length = 100
    scene.rootNode.addChildNode(SCNNode(geometry: floor))
    let sun = SCNNode()
    sun.light = SCNLight()
    sun.light!.type = .directional
    sun.light!.castsShadow = true
    sun.light!.intensity = 900
    sun.light!.orthographicScale = 4
    sun.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
    scene.rootNode.addChildNode(sun)
    self.sun = sun
    let amb = SCNNode()
    amb.light = SCNLight()
    amb.light!.type = .ambient
    amb.light!.intensity = 350
    scene.rootNode.addChildNode(amb)
  }
  private(set) var sun: SCNNode?

  /// 1 m の格子の模様 (薄い灰色に線)
  static func gridImage() -> UIImage {
    let n: CGFloat = 128
    return UIGraphicsImageRenderer(size: CGSize(width: n, height: n)).image { ctx in
      UIColor(white: 0.92, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: n, height: n))
      UIColor(white: 0.80, alpha: 1).setFill()
      ctx.fill(CGRect(x: 0, y: 0, width: n, height: 2)); ctx.fill(CGRect(x: 0, y: 0, width: 2, height: n))
    }
  }

  /// EusLisp の座標 (z が上) → SceneKit の座標
  static func sk(_ p: SIMD3<Float>) -> SIMD3<Float> { SIMD3(p.x, p.z, -p.y) }
}

struct BVHSceneRep: UIViewRepresentable {
  let st: BVHPlayer
  func makeUIView(context: Context) -> SCNView {
    let v = SCNView()
    v.scene = st.bs.scene
    v.allowsCameraControl = true
    v.antialiasingMode = .multisampling4X
    v.backgroundColor = UIColor.systemBackground
    let cam = SCNNode()
    cam.camera = SCNCamera()
    cam.camera!.zNear = 0.01
    cam.camera!.zFar = 200
    st.bs.scene.rootNode.addChildNode(cam)
    v.pointOfView = cam
    st.view = v
    st.resetCamera()
    return v
  }
  func updateUIView(_ v: SCNView, context: Context) {}
}

// MARK: - ロボットに移した姿 (BVH の画面)

/// 1 体のロボットの表示: RobotScene のノードの木を BVH の場面に移し, holder (EusLisp の座標) で横にずらして拡大する
@MainActor
final class RetargetFigure {
  let rs: RobotScene
  let holder = SCNNode()
  let rootLink: Int
  init(model: RobotModel, parent: SCNNode) {
    rs = RobotScene(model: model)
    rootLink = model.links.firstIndex { $0.parent < 0 } ?? 0
    for c in rs.base.childNodes { c.removeFromParentNode(); holder.addChildNode(c) }
    parent.addChildNode(holder)
  }
  func set(_ a: [Float], rootLinkPose: simd_float4x4) {
    rs.setAngles(a)
    rs.nodes[rootLink].simdTransform = rootLinkPose
  }
  func remove() { holder.removeFromParentNode() }

  // MARK: 違反の表示 (衝突のリンク = 赤, 可動範囲の端 = 橙, 重心と支持多角形)
  private var tint = [Int32]()
  private var marks: (ball: SCNNode, dot: SCNNode, poly: SCNNode)?
  private var polyKey = [SIMD2<Float>]()
  private var polyOK = true

  /// v = nil で消す. size: 印の大きさ (ロボットの脚の長さ, m)
  func showViolations(_ v: QPView?, size: Float) {
    let n = rs.nodes.count
    let flags = v?.flags ?? [Int32](repeating: 0, count: n)
    if tint.count != n { tint = [Int32](repeating: -1, count: n) }
    for i in 0..<min(n, flags.count) {
      let f = flags[i] & 3
      guard f != tint[i] else { continue }
      tint[i] = f
      let c: UIColor = f & 1 != 0 ? UIColor(red: 0.95, green: 0.05, blue: 0.05, alpha: 1) : f & 2 != 0 ? UIColor(red: 1, green: 0.5, blue: 0, alpha: 1) : .black
      for ch in rs.nodes[i].childNodes where ch.geometry != nil { ch.geometry?.materials.forEach { $0.emission.contents = c } }
    }
    guard let v else { marks.map { $0.ball.isHidden = true; $0.dot.isHidden = true; $0.poly.isHidden = true }; return }
    if marks == nil {
      func mat(_ c: UIColor) -> SCNMaterial { let m = SCNMaterial(); m.diffuse.contents = c; m.lightingModel = .constant; m.isDoubleSided = true; return m }
      let b = SCNNode(geometry: SCNSphere(radius: CGFloat(0.035 * size)))
      let d = SCNNode(geometry: SCNCylinder(radius: CGFloat(0.03 * size), height: 0.0005))
      d.eulerAngles.x = .pi / 2          // 円柱の軸 (y) を z (上) に
      let p = SCNNode()
      for x in [b, d, p] { holder.addChildNode(x) }
      b.geometry?.materials = [mat(.systemGreen)]; d.geometry?.materials = [mat(.systemGreen)]
      b.renderingOrder = 10; b.geometry?.firstMaterial?.readsFromDepthBuffer = false   // 体の中でも見えるように
      marks = (b, d, p)
    }
    guard let mk = marks else { return }
    let e = v.eval
    let ok = !(e.com_margin < 0)          // 支える足がない (NAN) ときは緑
    let col: UIColor = ok ? .systemGreen : .systemRed
    mk.ball.isHidden = false; mk.dot.isHidden = false
    mk.ball.simdPosition = SIMD3(Float(e.com.0), Float(e.com.1), Float(e.com.2))
    mk.dot.simdPosition = SIMD3(Float(e.com.0), Float(e.com.1), 0.0012)
    mk.ball.geometry?.firstMaterial?.diffuse.contents = col
    mk.dot.geometry?.firstMaterial?.diffuse.contents = col
    // 支持多角形 (変わったときだけ作り直す)
    if v.polygon.count >= 3 {
      mk.poly.isHidden = false
      if v.polygon != polyKey || ok != polyOK {
        polyKey = v.polygon; polyOK = ok
        let path = UIBezierPath()
        path.move(to: CGPoint(x: CGFloat(v.polygon[0].x), y: CGFloat(v.polygon[0].y)))
        for p in v.polygon.dropFirst() { path.addLine(to: CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))) }
        path.close()
        path.flatness = 0.0001
        let sh = SCNShape(path: path, extrusionDepth: 0.0004)
        let m = SCNMaterial(); m.lightingModel = .constant; m.isDoubleSided = true
        m.diffuse.contents = (ok ? UIColor.systemGreen : UIColor.systemRed).withAlphaComponent(0.45)
        sh.materials = [m]
        mk.poly.geometry = sh
        mk.poly.simdPosition = SIMD3(0, 0, 0.0008)
      }
    } else { mk.poly.isHidden = true }
  }
}

/// GMR + QP を裏で計算した結果 (別のスレッドから足す)
final class QPCache: @unchecked Sendable {
  private let lock = NSLock()
  private var frames = [QPFrame]()
  private(set) var total: Int
  init(total: Int) { self.total = total; frames.reserveCapacity(total) }
  func append(_ f: QPFrame) { lock.lock(); frames.append(f); lock.unlock() }
  func frame(_ i: Int) -> QPFrame? { lock.lock(); defer { lock.unlock() }; return i < frames.count ? frames[i] : nil }
  var count: Int { lock.lock(); defer { lock.unlock() }; return frames.count }
  /// 計算したコマの集計: (QP の ms/コマ, 衝突の割合 前・後, 重心が外の割合 前・後)
  func summary() -> (Double, Double, Double, Double, Double) {
    lock.lock(); defer { lock.unlock() }
    let n = Double(max(1, frames.count))
    let ms = frames.reduce(0) { $0 + $1.diag.time_ms } / n
    let cb = Double(frames.filter { $0.diag.before.n_collide > 0 }.count) / n, ca = Double(frames.filter { $0.diag.after.n_collide > 0 }.count) / n
    let wc = Double(max(1, frames.filter { $0.diag.contact != 0 }.count))
    let ob = Double(frames.filter { $0.diag.contact != 0 && $0.diag.before.com_margin < 0 }.count) / wc
    let oa = Double(frames.filter { $0.diag.contact != 0 && $0.diag.after.com_margin < 0 }.count) / wc
    return (ms, cb * 100, ca * 100, ob * 100, oa * 100)
  }
}

/// BVH の画面で選べるロボット: なし / グループの既定 / 同じ関節名の決まりのほかのロボット
struct RetargetRobotChoice: Hashable {
  var group: String   // "" = なし
  var name: String
  var title: String { group.isEmpty ? "なし" : "\(group.uppercased()) \(name)" }
}

func retargetRobotURL(group: String, name: String) -> URL? {
  if let u = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "robots/\(group)") { return u }
  return robotFiles().first { $0.name == name }?.url
}

// MARK: - 再生

@MainActor
final class BVHPlayer: ObservableObject {
  let bs = BVHScene()
  let list: [BVHEntry]
  let auto: Bool
  @Published var current: Int
  @Published var motion: BVHMotion?
  @Published var frame = 0
  @Published var playing = true
  @Published var speed = 1.0
  @Published var follow = true
  @Published var error: String?
  @Published var checkInfo = ""
  // ロボットに移す
  let tables = loadRetargetTables()
  @Published var robot = RetargetRobotChoice(group: "", name: "")
  @Published var showStick = true { didSet { layout(); show() } }
  @Published var showNames = true { didSet { layout(); show() } }
  @Published var showGMR = true { didSet { layout(); show() } }
  @Published var showQP = true { didSet { layout(); show() } }
  @Published var showViolations = true { didSet { show() } }
  @Published var qpProgress: Double?
  @Published var qpInfo = ""
  @Published var frameInfo = ""
  @Published var lifeSize = true { didSet { layout(); show() } }
  @Published var robotInfo = ""
  @Published var gmrMs = 0.0
  private var robotModel: RobotModel?
  private var rt: BVHRetargeter?
  private var figNames: RetargetFigure?, figGMR: RetargetFigure?, figQP: RetargetFigure?
  private var qpCache: QPCache?
  private var qpEval: WholeBodyQP?        // 表示の評価用 (計算用とは別)
  final class Flag: @unchecked Sendable { var cancelled = false }
  private var qpToken = Flag()
  private var loadingRobot = false
  weak var view: SCNView?
  private var timer: Timer?
  private var time = 0.0          // モーションの中の時刻 (秒)
  private var last = Date()
  private var lastRoot: SIMD3<Float>?

  init(list: [BVHEntry], start: Int, auto: Bool) {
    self.list = list
    self.auto = auto
    current = start
    load()
    // 起動の引数 -robot kxr|khr|jsk|<名前> -method both|names|gmr (確認用)
    if let r = UserDefaults.standard.string(forKey: "robot") { setRobot(launchChoice(r)) }
    switch UserDefaults.standard.string(forKey: "method") ?? "all" {
    case "names": showGMR = false; showQP = false
    case "gmr": showNames = false; showQP = false
    case "qp": showNames = false; showGMR = false
    case "gmrqp": showNames = false
    case "both": showQP = false
    default: break
    }
    if UserDefaults.standard.string(forKey: "violations") == "0" { showViolations = false }
    if UserDefaults.standard.string(forKey: "stick") == "0" { showStick = false }
    if let sp = UserDefaults.standard.string(forKey: "speed"), let v = Double(sp) { speed = v }
    timer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.tick() }
    }
  }

  var entry: BVHEntry { list[current] }

  /// グループごとの選べるロボット (表の supported, 既定を先頭に)
  func choices(_ group: String) -> [RetargetRobotChoice] {
    let def = tables?.robots.defaults[group]
    var names = tables?.robots.supported?[group] ?? []
    if let def { names.removeAll { $0 == def }; names.insert(def, at: 0) }
    return names.map { RetargetRobotChoice(group: group, name: $0) }
  }

  func launchChoice(_ s: String) -> RetargetRobotChoice {
    if robotGroups.contains(s), let d = tables?.robots.defaults[s] { return RetargetRobotChoice(group: s, name: d) }
    for g in robotGroups where (tables?.robots.supported?[g] ?? []).contains(s) { return RetargetRobotChoice(group: g, name: s) }
    return RetargetRobotChoice(group: "", name: "")
  }

  /// ロボットを選ぶ (JSON は別のスレッドで読む)
  func setRobot(_ c: RetargetRobotChoice) {
    robot = c
    robotModel = nil
    rebuild()
    guard !c.group.isEmpty, let url = retargetRobotURL(group: c.group, name: c.name) else { return }
    robotInfo = "\(c.name) を読み込み中…"
    loadingRobot = true
    Task.detached(priority: .userInitiated) {
      let m = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(RobotModel.self, from: $0) }
      await MainActor.run {
        guard self.robot == c else { return }
        self.loadingRobot = false
        if let m, robotSupportsRetarget(m) { self.robotModel = m; self.rebuild() }
        else { self.robotInfo = "\(c.name): 関節名が <limb>-<joint>-<r|p|y> ではないので移せません" }
      }
    }
  }

  /// モーションかロボットが変わったとき: 移し替えとロボットの表示を作り直す
  func rebuild() {
    figNames?.remove(); figGMR?.remove(); figQP?.remove(); figNames = nil; figGMR = nil; figQP = nil; rt = nil
    qpToken.cancelled = true; qpCache = nil; qpEval = nil; qpProgress = nil; qpInfo = ""; frameInfo = ""
    if robot.group.isEmpty { robotInfo = "" }
    if let m = robotModel, let mo = motion, let t = tables {
      let r = BVHRetargeter(model: m, motion: mo, tables: t)
      rt = r
      if r.method1OK { figNames = RetargetFigure(model: m, parent: bs.base) }
      if r.gmrOK {
        figGMR = RetargetFigure(model: m, parent: bs.base)
        figQP = RetargetFigure(model: m, parent: bs.base)
        qpEval = WholeBodyQP(model: m, rt: r, fps: mo.fps)
        startQP(model: m, motion: mo, tables: t)
      }
      robotInfo = String(format: "%@・脚の比 %.2f・腕の比 %.2f%@", m.name, r.sLeg, r.sArm,
                         r.method1OK ? "" : "・関節名の表がない種類")
    } else if robotModel != nil, tables == nil { robotInfo = "retarget_tables.json がありません" }
    layout()
    show()
  }

  /// GMR + QP を裏で全部のコマ計算する (計算したコマから表示する)
  func startQP(model: RobotModel, motion mo: BVHMotion, tables t: RetargetTables) {
    let token = Flag()
    qpToken = token
    let cache = QPCache(total: mo.frames)
    qpCache = cache
    qpProgress = 0
    let name = "\(entry.kind)/\(entry.file.name)"
    Task.detached(priority: .userInitiated) { [weak self] in
      let t0 = Date()
      let rt2 = BVHRetargeter(model: model, motion: mo, tables: t)
      let qp = WholeBodyQP(model: model, rt: rt2, fps: mo.fps)
      var lastP = -1.0
      let done = runGMRQP(rt: rt2, qp: qp, progress: { p in
        if p - lastP >= 0.02 { lastP = p; Task { @MainActor in if !token.cancelled { self?.qpProgress = p } } }
      }, cancelled: { token.cancelled }, emit: { _, f in cache.append(f) })
      let sec = Date().timeIntervalSince(t0)
      guard done else { return }
      let s = cache.summary()
      NSLog("EusView GMR+QP %@ %@: %d frames in %.2f s, QP %.3f ms/frame, collide %.1f%% -> %.1f%%, COM out %.1f%% -> %.1f%%",
            name, model.name, cache.count, sec, s.0, s.1, s.2, s.3, s.4)
      await MainActor.run {
        guard let self, !token.cancelled else { return }
        self.qpProgress = nil
        self.qpInfo = String(format: "GMR+QP %.2f ms/コマ・衝突 %.0f%%→%.0f%%・重心が外 %.0f%%→%.0f%%", s.0, s.1, s.2, s.3, s.4)
      }
    }
  }

  /// 並べ方: 見えているものを (棒人形, 関節名, GMR) の順に人の左右 (EusLisp の y) に並べる. 前 (+x) から見て左から右
  func layout() {
    let k: Float = lifeSize ? 1 / max(rt?.sLeg ?? 1, 0.05) : 1
    let d: Float = lifeSize ? 1.2 : 0.6
    var items = [SCNNode]()
    if showStick { items.append(bs.stick) }
    bs.stick.isHidden = !showStick
    if let f = figNames { f.holder.isHidden = !showNames; if showNames { items.append(f.holder) } }
    if let f = figGMR { f.holder.isHidden = !showGMR; if showGMR { items.append(f.holder) } }
    if let f = figQP { f.holder.isHidden = !showQP; if showQP { items.append(f.holder) } }
    for (i, n) in items.enumerated() {
      let off = (Float(i) - Float(items.count - 1) / 2) * d
      let sc: Float = n === bs.stick ? 1 : k
      n.simdTransform = simd_float4x4(rot: matrix_identity_float3x3 * sc, pos: SIMD3(0, off, 0))
    }
  }

  func load() {
    guard let root = bvhRoot() else { error = "BVH のデータがありません"; return }
    do {
      let m = try BVHMotion(url: root.appendingPathComponent(entry.file.file))
      motion = m
      error = nil
      bs.setSkeleton(m.header)
      time = 0; frame = 0; lastRoot = nil
      if let e = m.checkError() {
        checkInfo = String(format: "照合 %.2f mm", e)
        NSLog("EusView BVH %@/%@ check: max error %.3f mm (frame %d)", entry.kind, entry.file.name, e, m.header.check?.frame ?? -1)
      }
      rebuild()
      resetCamera()
    } catch {
      self.error = "\(entry.file.file) を読めません: \(error)"
      motion = nil
    }
  }

  /// カメラ: 人 (背の高さ約 1.7 m) と並べたロボットが収まる距離で, 前から少し斜めに
  func resetCamera() {
    guard let v = view, let cam = v.pointOfView else { return }
    var c = SIMD3<Float>(0, 0, 0.9)
    if let m = motion { let w = m.frame(frame); c.x = w[0].columns.3.x; c.y = w[0].columns.3.y }
    let n = Float([showStick, figNames != nil && showNames, figGMR != nil && showGMR, figQP != nil && showQP].filter { $0 }.count)
    let r: Float = 1.2 + 0.6 * max(0, n - 1)
    let t = BVHScene.sk(c)
    cam.simdPosition = t + BVHScene.sk(SIMD3(r * 2.3, -r * 0.7, r * 0.8))
    cam.simdLook(at: t, up: SIMD3(0, 1, 0), localFront: SIMD3(0, 0, -1))
    v.defaultCameraController.target = SCNVector3(t)
    lastRoot = SIMD3(c.x, c.y, 0)
    bs.sun.map { $0.simdPosition = t }
  }

  func tick() {
    let now = Date()
    let dt = now.timeIntervalSince(last)
    last = now
    guard playing, let m = motion, m.frames > 0 else { return }
    time += min(dt, 0.1) * speed
    let n = Int(time * m.fps)
    if n >= m.frames {
      if auto && list.count > 1 { next(); return }
      time = 0; frame = 0          // 1 本だけのときは止めるまで繰り返す
    } else { frame = n }
    show()
  }

  func show() {
    guard let m = motion else { return }
    let w = m.frame(frame)
    bs.setFrame(w)
    if let rt {
      if let f = figNames, showNames { let r = rt.method1(frame); f.set(r.angles, rootLinkPose: rt.rootLinkPose(r.root)) }
      // GMR + QP を計算したコマは, GMR もその計算に使った参照を出す (同じもの同士で比べる)
      let cached = qpCache?.frame(frame)
      let size = Float(qpEval?.scale ?? 0.3)
      var vG: QPView? = nil, vQ: QPView? = nil
      if let f = figGMR, showGMR {
        var a: [Float], pose: simd_float4x4
        if let c = cached { a = c.qRef; pose = c.rootRef }
        else {
          let t0 = Date()
          let r = rt.gmr(frame)
          let ms = Date().timeIntervalSince(t0) * 1000
          gmrMs = gmrMs == 0 ? ms : gmrMs * 0.95 + ms * 0.05
          a = r.angles; pose = rt.rootLinkPose(r.root)
        }
        f.set(a, rootLinkPose: pose)
        if showViolations, let e = qpEval { vG = e.view(angles: a, rootLinkPose: pose, support: cached?.diag.contact ?? -1) }
        f.showViolations(vG, size: size)
      }
      if let f = figQP, showQP {
        if let c = cached {
          f.holder.opacity = 1
          f.set(c.q, rootLinkPose: c.root)
          if showViolations, let e = qpEval { vQ = e.view(angles: c.q, rootLinkPose: c.root, support: c.diag.contact) }
          f.showViolations(vQ, size: size)
        } else { f.holder.opacity = 0.25 }    // まだ計算していないコマ
      }
      // このコマの違反 (GMR → GMR + QP)
      func d(_ v: QPView?) -> String {
        guard let v else { return "—" }
        let e = v.eval
        var s = e.n_collide > 0 ? String(format: "衝突 %d (%.0f mm)", e.n_collide, e.min_dist * 1000) : String(format: "衝突なし (%.0f mm)", min(e.min_dist, 9.999) * 1000)
        s += e.n_at_limit > 0 ? "・範囲の端 \(e.n_at_limit)" : ""
        s += e.com_margin.isNaN ? "・足が浮く" : String(format: "・重心 %@%.0f mm", e.com_margin < 0 ? "外 " : "", abs(e.com_margin) * 1000)
        return s
      }
      frameInfo = showViolations && (vG != nil || vQ != nil) ? "GMR: \(d(vG))\nQP: \(d(vQ))" : ""
    }
    // カメラが腰の水平の動きについていく
    let root = SIMD3<Float>(w[0].columns.3.x, w[0].columns.3.y, 0)
    if follow, let lr = lastRoot, let v = view, let cam = v.pointOfView {
      let d = BVHScene.sk(root - lr)
      cam.simdPosition += d
      let t = v.defaultCameraController.target
      v.defaultCameraController.target = SCNVector3(SIMD3<Float>(Float(t.x), Float(t.y), Float(t.z)) + d)
      bs.sun.map { $0.simdPosition += d }
    }
    lastRoot = root
  }

  func seek(_ f: Int) { guard let m = motion else { return }; frame = max(0, min(m.frames - 1, f)); time = Double(frame) / m.fps; show() }
  func next() { current = (current + 1) % list.count; load() }
  func prev() { current = (current - 1 + list.count) % list.count; load() }
  func shutdown() { timer?.invalidate(); timer = nil; qpToken.cancelled = true }
}

struct BVHPlayerView: View {
  @StateObject var st: BVHPlayer
  init(list: [BVHEntry], start: Int, auto: Bool) { _st = StateObject(wrappedValue: BVHPlayer(list: list, start: start, auto: auto)) }
  var body: some View {
    VStack(spacing: 0) {
      BVHSceneRep(st: st).ignoresSafeArea(edges: .horizontal)
        .overlay(alignment: .topLeading) { info }
      controls
    }
    .navigationTitle(st.auto ? "自動再生" : st.entry.file.name)
    .navigationBarTitleDisplayMode(.inline)
    .onDisappear { st.shutdown() }
  }

  var info: some View {
    VStack(alignment: .leading, spacing: 2) {
      if st.auto { Text("自動再生 \(st.current + 1) / \(st.list.count)").bold() }
      Text("\(st.entry.kind) / \(st.entry.file.name)").bold()
      if let m = st.motion {
        Text(String(format: "コマ %d / %d・%.0f fps・%.1f / %.1f 秒", st.frame + 1, m.frames, m.fps, Double(st.frame) / m.fps, Double(m.frames) / m.fps))
        Text("関節 \(m.joints.count)・\(st.checkInfo)").foregroundStyle(.secondary)
      }
      if !st.robot.group.isEmpty {
        Text(st.robotInfo).foregroundStyle(.secondary)
        Text(legend + (st.showGMR && st.gmrMs > 0 ? String(format: "・GMR %.2f ms/コマ", st.gmrMs) : "")).foregroundStyle(.secondary)
        if let p = st.qpProgress { Text(String(format: "GMR + QP を計算中 %.0f%%", p * 100)).foregroundStyle(.orange) }
        if !st.qpInfo.isEmpty { Text(st.qpInfo).foregroundStyle(.secondary) }
        if !st.frameInfo.isEmpty { Text(st.frameInfo) }
      }
      if let e = st.error { Text(e).foregroundStyle(.red) }
    }
    .font(.caption2.monospacedDigit())
    .padding(6).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6)).padding(8)
  }

  var legend: String {
    var a = [String]()
    if st.showStick { a.append("棒人形") }
    if st.showNames { a.append("関節名") }
    if st.showGMR { a.append("GMR") }
    if st.showQP { a.append("GMR+QP") }
    return "左から " + a.joined(separator: "・")
  }

  var robotMenu: some View {
    Menu {
      Button("なし") { st.setRobot(RetargetRobotChoice(group: "", name: "")) }
      ForEach(robotGroups, id: \.self) { g in
        let cs = st.choices(g)
        if let d = cs.first {
          Button("\(g.uppercased())（\(d.name)）") { st.setRobot(d) }
          if cs.count > 1 {
            Menu("\(g.uppercased()) のほかのロボット") {
              ForEach(cs.dropFirst(), id: \.self) { c in Button(c.name) { st.setRobot(c) } }
            }
          }
        }
      }
    } label: {
      Label(st.robot.group.isEmpty ? "ロボット: なし" : "ロボット: \(st.robot.name)", systemImage: "figure.stand")
    }
  }

  var controls: some View {
    VStack(spacing: 8) {
      if let m = st.motion, m.frames > 1 {
        Slider(value: Binding(get: { Double(st.frame) }, set: { st.seek(Int($0)) }), in: 0...Double(m.frames - 1))
      }
      HStack(spacing: 14) {
        if st.list.count > 1 {
          Button { st.prev() } label: { Image(systemName: "backward.end.fill") }
        }
        Button { st.playing.toggle() } label: {
          Label(st.playing ? "止める" : "再生", systemImage: st.playing ? "stop.fill" : "play.fill").frame(minWidth: 70)
        }.buttonStyle(.borderedProminent)
        if st.list.count > 1 {
          Button { st.next() } label: { Image(systemName: "forward.end.fill") }
        }
        Picker("速さ", selection: $st.speed) {
          Text("0.5x").tag(0.5); Text("1x").tag(1.0); Text("2x").tag(2.0)
        }.pickerStyle(.segmented).frame(maxWidth: 160)
        Spacer(minLength: 0)
      }
      ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 10) {
        robotMenu
        if !st.robot.group.isEmpty {
          Toggle("棒人形", isOn: $st.showStick).fixedSize()
          Toggle("関節名", isOn: $st.showNames).fixedSize()
          Toggle("GMR", isOn: $st.showGMR).fixedSize()
          Toggle("GMR+QP", isOn: $st.showQP).fixedSize()
          Toggle("違反", isOn: $st.showViolations).fixedSize()
        }
        Spacer(minLength: 0)
      } }.font(.footnote).toggleStyle(.button)
      HStack {
        Toggle("カメラが追う", isOn: $st.follow).fixedSize()
        if !st.robot.group.isEmpty { Toggle("人の大きさに", isOn: $st.lifeSize).fixedSize() }
        Spacer()
        Button("カメラを戻す") { st.resetCamera() }
      }.font(.footnote)
    }
    .padding(.horizontal, 12).padding(.vertical, 10)
  }
}
