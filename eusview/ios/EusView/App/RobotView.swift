// RobotView.swift : ロボットの 3D 表示と操作 (関節・姿勢・動作・接続)
//   動作: JSON の動作と, BVH から移した動作 (種類 → ファイル → 方法 (関節名 / GMR / GMR + QP), BVHRetarget.swift, WholeBodyQP.swift)
//   起動の引数 -open <ロボット> -bvhmotion <種類>/<名前> -method names|gmr|gmrqp -physics 1 で BVH の動作を再生 (確認用)
import SwiftUI
import SceneKit
import simd

struct SceneViewRep: UIViewRepresentable {
  let rs: RobotScene
  var follow: RobotState? = nil
  final class Coordinator { weak var view: SCNView? }
  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeUIView(context: Context) -> SCNView {
    let v = SCNView()
    v.scene = rs.scene
    v.allowsCameraControl = true
    v.antialiasingMode = .multisampling4X
    v.backgroundColor = UIColor.systemBackground
    let cam = SCNNode()
    cam.camera = SCNCamera()
    cam.camera!.zNear = 0.005
    let (c, r) = rs.bounds()
    cam.position = SCNVector3(c.x + r * 1.6, c.y + r * 0.9, c.z + r * 2.2)
    cam.look(at: c)
    rs.scene.rootNode.addChildNode(cam)
    v.pointOfView = cam
    v.defaultCameraController.target = c
    context.coordinator.view = v
    return v
  }
  func updateUIView(_ v: SCNView, context: Context) { follow?.view = v }
}

@MainActor
final class RobotState: ObservableObject {
  let rs: RobotScene
  @Published var angles: [Float]
  @Published var playing: String?
  @Published var live = LiveLink()
  @Published var physics = false      // 物理モード (ODE)
  @Published var servoOn = true
  @Published var simInfo = ""
  // BVH から移した動作
  @Published var bvhProgress: Double?
  @Published var bvhInfo = ""
  @Published var bvhMotion: RobotMotion?
  final class CancelFlag: @unchecked Sendable { var cancelled = false }
  private var bvhToken = CancelFlag()
  weak var view: SCNView?
  private var lastRootXY: SIMD2<Float>?
  private var timer: Timer?
  private var sim: PhysicsSim?
  private var simTimer: Timer?
  init(rs: RobotScene) {
    self.rs = rs
    angles = rs.angles
    if let p = rs.model.poses?["reset-pose"] { set(p) }
  }
  /// 関節角の指令. 物理モードではサーボの目標, そうでなければそのまま表示
  func set(_ a: [Float]) {
    angles = a
    if let sim { sim.setTargets(a) } else { rs.setAngles(a) }
  }

  /// 物理モードを始める (今の姿勢で床に置く) / やめる
  func setPhysics(_ on: Bool) {
    simTimer?.invalidate(); simTimer = nil; sim = nil
    physics = on
    if !on { rs.setAngles(angles); return }
    let s = PhysicsSim(model: rs.model, angles: angles)
    s.setServo(servoOn)
    sim = s
    rs.setWorldPoses(s.linkPoses())
    simTimer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] _ in
      Task { @MainActor in
        guard let self, let sim = self.sim else { return }
        let t0 = Date()
        sim.step(1 / 60)
        let poses = sim.linkPoses()
        // 発散 (数でない・100 m より遠い) したら物理を止める (起き上がりの動作などで起きることがある)
        if poses.contains(where: { m in (0..<3).contains { k in !m.columns.3[k].isFinite || abs(m.columns.3[k]) > 100 } }) {
          let t = sim.time
          self.stop()
          self.setPhysics(false)
          self.simInfo = String(format: "物理の計算が発散したので止めました（%.1f 秒）", t)
          return
        }
        self.rs.setWorldPoses(poses)
        let ms = Date().timeIntervalSince(t0) * 1000
        self.simInfo = String(format: "%.1f 秒  接触 %d 点  計算 %.1f ms/コマ", sim.time, sim.contacts, ms)
      }
    }
  }
  func setServo(_ on: Bool) { servoOn = on; sim?.setServo(on) }
  /// 今の姿勢から目標の姿勢へ 0.6 秒で動かす
  func move(to target: [Float]) {
    stop()
    let from = angles, t0 = Date()
    timer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] t in
      Task { @MainActor in
        guard let self else { return }
        let s = Float(min(1, Date().timeIntervalSince(t0) / 0.6))
        let e = s * s * (3 - 2 * s)
        self.set(zip(from, target).map { $0 + ($1 - $0) * e })
        if s >= 1 { t.invalidate() }
      }
    }
  }
  func play(_ m: RobotMotion, follow: Bool = false) {
    stop()
    playing = m.name
    lastRootXY = nil
    var i = 0
    // 物理モード: 今の姿勢から初めのコマへ 0.8 秒かけて移ってから再生する (いきなり跳ぶと倒れる)
    let from = angles
    var lead = sim != nil && !m.frames.isEmpty ? Int(0.8 * max(m.fps, 1)) : 0
    let leadN = lead
    timer = Timer.scheduledTimer(withTimeInterval: Double(1 / max(m.fps, 1)), repeats: true) { [weak self] t in
      Task { @MainActor in
        guard let self else { return }
        if lead > 0 {
          let s = Float(leadN - lead + 1) / Float(leadN), e = s * s * (3 - 2 * s)
          self.set(zip(from, m.frames[0]).map { $0 + ($1 - $0) * e })
          lead -= 1
          return
        }
        if i >= m.frames.count { i = 0; self.lastRootXY = nil }
        if self.sim != nil { self.set(m.frames[i]) }   // 物理モード: 動作の関節角をサーボの目標にする
        else {
          self.rs.setFrame(m, i); self.angles = self.rs.angles
          if follow, let r = m.root, i < r.count { self.followCamera(SIMD2(r[i][0], r[i][1])) }
        }
        i += 1
      }
    }
  }

  /// カメラがルートの水平の動きについていく (BVH の動作は歩いて遠くへ行くので)
  private func followCamera(_ xy: SIMD2<Float>) {
    defer { lastRootXY = xy }
    guard let last = lastRootXY, let v = view, let cam = v.pointOfView else { return }
    let d = SIMD3<Float>(xy.x - last.x, 0, -(xy.y - last.y))    // EusLisp (z が上) → SceneKit
    if simd_length(d) > 0.5 { return }                          // 繰り返しの頭に戻ったときは動かさない
    cam.simdPosition += d
    let t = v.defaultCameraController.target
    v.defaultCameraController.target = SCNVector3(SIMD3<Float>(Float(t.x), Float(t.y), Float(t.z)) + d)
  }

  /// BVH を移して動作にし (全部のコマを先に計算する), 繰り返し再生する
  func playBVH(_ e: BVHEntry, method: RetargetMethod) {
    stop()
    bvhToken.cancelled = true
    let token = CancelFlag()
    bvhToken = token
    guard let root = bvhRoot(), let tables = loadRetargetTables() else { bvhInfo = "BVH のデータか retarget_tables.json がありません"; return }
    let model = rs.model
    let url = root.appendingPathComponent(e.file.file)
    let name = "BVH \(e.kind)/\(e.file.name)（\(method.title)）"
    bvhProgress = 0
    bvhInfo = "\(e.kind)/\(e.file.name) を\(method.title)で移しています"
    Task.detached(priority: .userInitiated) { [weak self] in
      let t0 = Date()
      var m: RobotMotion?
      var err: String?
      var qpInfo = ""
      do {
        let mo = try BVHMotion(url: url)
        let rt = BVHRetargeter(model: model, motion: mo, tables: tables)
        var lastP = -1.0
        let prog: (Double) -> Void = { p in
          if p - lastP >= 0.02 || p >= 1 { lastP = p; Task { @MainActor in self?.bvhProgress = p } }
        }
        if method == .gmrqp {
          // GMR + 全身 QP (自己衝突・可動範囲・重心, WholeBodyQP.swift / wbqp.cpp)
          if let (mm, fr) = makeGMRQPMotion(rt: rt, name: name, progress: prog, cancelled: { token.cancelled }) {
            m = mm
            let n = Double(max(1, fr.count))
            let coll = fr.filter { $0.diag.before.n_collide > 0 }.count, collA = fr.filter { $0.diag.after.n_collide > 0 }.count
            let com = fr.filter { $0.diag.contact != 0 && $0.diag.before.com_margin < 0 }.count, comA = fr.filter { $0.diag.contact != 0 && $0.diag.after.com_margin < 0 }.count
            qpInfo = String(format: "・QP %.2f ms/コマ・衝突 %.0f%%→%.0f%%・重心が外 %.0f%%→%.0f%%",
                            fr.map { $0.diag.time_ms }.reduce(0, +) / n, 100 * Double(coll) / n, 100 * Double(collA) / n, 100 * Double(com) / n, 100 * Double(comA) / n)
          }
        } else {
          m = rt.makeMotion(method, name: name, progress: prog, cancelled: { token.cancelled })
        }
      } catch { err = "\(error)" }
      let sec = Date().timeIntervalSince(t0)
      await MainActor.run {
        guard let self, !token.cancelled || m == nil else { return }
        self.bvhProgress = nil
        if let m {
          self.bvhMotion = m
          self.bvhInfo = String(format: "%d コマを %.1f 秒で計算（%.2f ms/コマ）", m.frames.count, sec, sec * 1000 / Double(max(1, m.frames.count))) + qpInfo
          NSLog("EusView BVH motion %@: %@", name, self.bvhInfo)
          self.play(m, follow: true)
        } else if let err { self.bvhInfo = "読めません: \(err)" }
        else { self.bvhInfo = "やめました" }
      }
    }
  }
  func cancelBVH() { bvhToken.cancelled = true }
  func stop() { timer?.invalidate(); timer = nil; playing = nil }
  /// 起動の引数で BVH の動作を再生する (確認用, 一度だけ)
  static var launchDone = false
  func launchBVH() {
    guard !RobotState.launchDone, let arg = UserDefaults.standard.string(forKey: "bvhmotion") else { return }
    RobotState.launchDone = true
    guard let index = loadBVHIndex() else { return }
    let all = index.kinds.flatMap { k in k.files.map { BVHEntry(kind: k.name, file: $0) } }
    guard let e = all.first(where: { "\($0.kind)/\($0.file.name)" == arg }) else { bvhInfo = "\(arg) がありません"; return }
    if UserDefaults.standard.string(forKey: "physics") == "1" { setPhysics(true) }
    let mm = UserDefaults.standard.string(forKey: "method")
    playBVH(e, method: mm == "names" ? .names : (mm == "gmrqp" || mm == "qp") ? .gmrqp : .gmr)
  }
  func shutdown() { stop(); simTimer?.invalidate(); simTimer = nil; sim = nil }
}

struct RobotView: View {
  @StateObject var st: RobotState
  @State var tab = 0
  @State var bvhPicker = false
  init(rs: RobotScene) { _st = StateObject(wrappedValue: RobotState(rs: rs)) }
  var model: RobotModel { st.rs.model }
  var body: some View {
    VStack(spacing: 0) {
      SceneViewRep(rs: st.rs, follow: st).ignoresSafeArea(edges: .horizontal)
        .overlay(alignment: .topLeading) {
          if st.physics { Text(st.simInfo).font(.caption2.monospacedDigit()).padding(6).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6)).padding(8) }
        }
      HStack {
        Toggle("物理（ODE）", isOn: Binding(get: { st.physics }, set: { st.setPhysics($0) })).fixedSize()
        if st.physics {
          Toggle("サーボ", isOn: Binding(get: { st.servoOn }, set: { st.setServo($0) })).fixedSize()
          Button("置き直す") { st.setPhysics(true) }
        }
        Spacer()
      }.font(.footnote).padding(.horizontal, 12).padding(.top, 6)
      Picker("", selection: $tab) {
        Text("関節").tag(0); Text("姿勢").tag(1); Text("動作").tag(2); Text("接続").tag(3)
      }.pickerStyle(.segmented).padding(8)
      Group {
        switch tab {
        case 0: jointList
        case 1: poseList
        case 2: motionList
        default: LiveView(st: st)
        }
      }.frame(height: 260)
    }
    .navigationTitle(model.name)
    .navigationBarTitleDisplayMode(.inline)
    .onDisappear { st.shutdown(); st.live.disconnect(); st.cancelBVH() }
    .onAppear {
      if UserDefaults.standard.string(forKey: "bvhmotion") != nil { tab = 2; st.launchBVH() }
      else if !RobotState.launchDone, UserDefaults.standard.string(forKey: "physics") == "1" { RobotState.launchDone = true; st.setPhysics(true) }   // 起動の引数 -physics 1 (確認用)
    }
    .sheet(isPresented: $bvhPicker) {
      BVHMotionPicker { e, method in bvhPicker = false; st.playBVH(e, method: method) }
    }
  }

  var jointList: some View {
    List(Array(model.joints.enumerated()), id: \.offset) { k, j in
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(j.name).font(.caption)
          Spacer()
          Text(String(format: j.type == "linear" ? "%.1f mm" : "%.1f°", st.angles[k])).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        Slider(value: Binding(get: { st.angles[k] }, set: { v in var a = st.angles; a[k] = v; st.stop(); st.set(a) }),
               in: (j.min ?? -180)...max((j.max ?? 180), (j.min ?? -180) + 0.1))
      }
    }.listStyle(.plain)
  }

  var poseList: some View {
    List {
      ForEach((model.poses ?? [:]).keys.sorted(), id: \.self) { name in
        Button(name) { st.move(to: model.poses![name]!) }
      }
      Button("すべて 0") { st.move(to: [Float](repeating: 0, count: model.joints.count)) }
    }.listStyle(.plain)
  }

  var motionList: some View {
    List {
      if robotSupportsRetarget(model) && loadBVHIndex() != nil {
        Section {
          if let p = st.bvhProgress {
            HStack {
              ProgressView(value: p) { Text(st.bvhInfo).font(.caption) }
              Button("やめる") { st.cancelBVH() }.font(.caption)
            }
          } else {
            Button { bvhPicker = true } label: { Label("BVH から選ぶ（種類 → ファイル → 関節名 / GMR / GMR + QP）", systemImage: "figure.walk") }
            if let m = st.bvhMotion {
              Button { st.playing == m.name ? st.stop() : st.play(m, follow: true) } label: {
                Label("\(m.name)（\(m.frames.count) コマ）", systemImage: st.playing == m.name ? "stop.fill" : "play.fill")
              }
            }
            if !st.bvhInfo.isEmpty { Text(st.bvhInfo + (st.physics ? "・物理オン: 関節角をサーボの目標に" : "・物理オフ: 腰も BVH のように動かす")).font(.caption2).foregroundStyle(.secondary) }
          }
        } header: { Text("BVH") }
      }
      Section {
        if (model.motions ?? []).isEmpty { Text("このロボットには動作が入っていません").foregroundStyle(.secondary) }
        ForEach(model.motions ?? [], id: \.name) { m in
          Button { st.playing == m.name ? st.stop() : st.play(m) } label: {
            Label("\(m.name)（\(m.frames.count) コマ）", systemImage: st.playing == m.name ? "stop.fill" : "play.fill")
          }
        }
      } header: { if robotSupportsRetarget(model) { Text("ロボットの動作") } }
    }.listStyle(.plain)
  }
}

/// ロボットの画面の「動作」→ BVH: 種類 → ファイル (名前で探す) → 方法 (関節名 / GMR)
struct BVHMotionPicker: View {
  let pick: (BVHEntry, RetargetMethod) -> Void
  let index = loadBVHIndex()
  @State var kind = ""
  @State var method = RetargetMethod.gmr
  @State var search = ""
  @Environment(\.dismiss) var dismiss
  var body: some View {
    NavigationStack {
      let kinds = index?.kinds ?? []
      let k = kinds.first { $0.name == kind } ?? kinds.first
      VStack(spacing: 0) {
        Picker("種類", selection: $kind) {
          ForEach(kinds, id: \.name) { Text("\($0.name)（\($0.files.count)）").tag($0.name) }
        }.pickerStyle(.segmented).padding(.horizontal).padding(.top, 8)
        Picker("方法", selection: $method) {
          Text("関節名").tag(RetargetMethod.names)
          Text("GMR").tag(RetargetMethod.gmr)
          Text("GMR + QP").tag(RetargetMethod.gmrqp)
        }.pickerStyle(.segmented).padding(.horizontal, 8).padding(.top, 8)
        Text(method == .names ? "関節名で対応（EusLisp の :copy-state-to と同じ）" : method == .gmr ? "GMR: 部位の位置を IK で合わせる"
             : "GMR のあと全身 QP で自己衝突・関節の可動範囲・重心を直し, 床に着いた足を止める")
          .font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 8).padding(.bottom, 4)
        List((k?.files ?? []).filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }, id: \.self) { f in
          Button {
            if let k { pick(BVHEntry(kind: k.name, file: f), method) }
          } label: {
            HStack {
              Text(f.name)
              Spacer()
              Text("\(bvhDuration(f.duration))・\(f.frames) コマ").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
          }
        }.listStyle(.plain)
      }
      .searchable(text: $search, prompt: "名前で探す")
      .navigationTitle("BVH の動作")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
      .onAppear { if kind.isEmpty { kind = kinds.first?.name ?? "" } }
    }
  }
}
