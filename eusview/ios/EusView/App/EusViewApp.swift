// EusView: jskeus / kxreus のロボットモデル (eus2json.l で書き出した JSON) を iPhone で表示するアプリ
//   ・ロボットを選ぶ (KXR / KHR / JSK → 身体の形の分類 → 画像と名前, RobotPicker.swift) → SceneKit で表示 (1 本指で回転, 2 本指で移動・拡大)
//   ・関節角のスライダー, 姿勢 (reset-pose など), 動作の再生
//   ・接続: Mac などの EusLisp から WebSocket で関節角を受け取って動かす ({"angles": [...]} など)
//   ・BVH (BVHView.swift): 棒人形・関節名・GMR・GMR + QP・QP + バランスを並べる. QP + バランス = 動作全体を先に見て
//     両足が浮かない一歩ずつの接地と ZMP が足の裏に入る重心の軌道を決め (wbqp_plan_balance), 重心を最優先にして解く (eusview/bvh/QP.md).
//     「物理で比べる」で GMR + QP と QP + バランスと GMR + MPC を ODE で動かし, 倒れるまでの秒数を出す (QP + バランスは BalanceStabilizer で足首を直す.
//     GMR + MPC は QP + バランスの計画に対して毎コマ物理の今の状態から閉ループの MPC (wbqp_mpc_step) を解く)
//   ・ロボットの画面の BVH の動作に「GMR + QP + バランス」(物理オンでは BalanceStabilizer を通す) と「GMR + MPC」(物理オンのときだけ閉ループ)
//   起動の引数 (確認用): -bvh <種類/名前> -robot <名前> -method balance|mpc -bvhphysics 1 / -open <名前> -bvhmotion <種類/名前> -method balance|mpc -physics 1
import SwiftUI
import SceneKit

@main
struct EusViewApp: App {
  var body: some Scene { WindowGroup { RobotListView() } }
}

/// アプリに入っているロボット (robots/<グループ>/*.json) と, 受け取って保存したロボット (Documents/*.json)
struct RobotFile: Hashable { var url: URL; var group: String; var name: String }

let robotGroups = ["kxr", "khr", "jsk"]

func robotGroup(of url: URL) -> String {
  let dir = url.deletingLastPathComponent().lastPathComponent
  if robotGroups.contains(dir) { return dir }
  let n = url.lastPathComponent   // フォルダに分けていないファイルは名前から決める
  return n.hasPrefix("khr") ? "khr" : n.hasPrefix("kxr") ? "kxr" : "jsk"
}

func robotFiles() -> [RobotFile] {
  var urls = [URL]()
  if let root = Bundle.main.url(forResource: "robots", withExtension: nil),
     let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) {
    for case let u as URL in e where u.pathExtension == "json" { urls.append(u) }
  }
  let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  urls += (try? FileManager.default.contentsOfDirectory(at: doc, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }) ?? []
  return urls.map { RobotFile(url: $0, group: robotGroup(of: $0), name: $0.deletingPathExtension().lastPathComponent) }
    .sorted { $0.name < $1.name }
}

struct RobotListView: View {
  @State var files = robotFiles()
  @AppStorage("robotGroup") var group = "kxr"
  @State var search = ""
  /// 起動の引数 -bvh <home | auto | 種類 | 種類/名前> で BVH の画面を開く (確認用)
  @State var bvhLaunch = UserDefaults.standard.string(forKey: "bvh") != nil
  /// 起動の引数 -open <ロボットの名前> でそのロボットの画面を開く (確認用, RobotView の -bvhmotion と組み合わせる)
  @State var openLaunch = UserDefaults.standard.string(forKey: "open") != nil && UserDefaults.standard.string(forKey: "bvh") == nil
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        Picker("グループ", selection: $group) {
          ForEach(robotGroups, id: \.self) { g in Text("\(g.uppercased())（\(files.filter { $0.group == g }.count)）").tag(g) }
        }
        .pickerStyle(.segmented).padding(.horizontal).padding(.vertical, 8)
        // 身体の形の分類 → 画像と名前 (RobotPicker.swift)
        RobotPickerView(files: files, group: $group, search: search)
      }
      .navigationTitle("EusLisp ロボット")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink { BVHHomeView() } label: { Label("BVH", systemImage: "figure.walk").labelStyle(.titleAndIcon) }
        }
      }
      .searchable(text: $search, prompt: "名前で探す")
      .refreshable { files = robotFiles() }
      .navigationDestination(isPresented: $bvhLaunch) { BVHLaunchView(arg: UserDefaults.standard.string(forKey: "bvh") ?? "home") }
      .navigationDestination(isPresented: $openLaunch) {
        if let f = files.first(where: { $0.name == UserDefaults.standard.string(forKey: "open") }) { RobotLoaderView(url: f.url) }
        else { Text("ロボットがありません") }
      }
    }
  }
}

struct RobotLoaderView: View {
  let url: URL
  @State var model: RobotModel?
  @State var error: String?
  var body: some View {
    Group {
      if let m = model { RobotView(rs: RobotScene(model: m)) }
      else if let e = error { Text(e).padding() }
      else { ProgressView("読み込み中") }
    }
    .task {
      do {
        let d = try Data(contentsOf: url)
        let m = try JSONDecoder().decode(RobotModel.self, from: d)
        await MainActor.run { model = m }
      } catch { self.error = "読み込めません: \(error)" }
    }
  }
}
