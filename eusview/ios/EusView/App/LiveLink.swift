// LiveLink.swift : EusLisp (Mac など) から WebSocket で関節角を受け取る
//   受け取る JSON: {"angles": [...]}  関節角 (度・mm, JSON の関節の順)
//                  {"pose": "reset-pose"}  名前の付いた姿勢へ動かす
//                  {"root": [x y z r00..r22]}  ルートリンクの位置姿勢
import SwiftUI
import simd

struct LiveLink {
  var url = UserDefaults.standard.string(forKey: "liveURL") ?? "ws://192.168.1.59:8766/"
  var status = "未接続"
  var task: URLSessionWebSocketTask?
  mutating func disconnect() { task?.cancel(with: .goingAway, reason: nil); task = nil; status = "未接続" }
}

struct LiveView: View {
  @ObservedObject var st: RobotState
  var body: some View {
    Form {
      TextField("ws://<Mac の IP>:8766/", text: $st.live.url).textInputAutocapitalization(.never).autocorrectionDisabled()
      HStack {
        Button(st.live.task == nil ? "接続する" : "切断する") { st.live.task == nil ? connect() : st.live.disconnect() }
        Spacer()
        Text(st.live.status).font(.caption).foregroundStyle(.secondary)
      }
      Text("Mac で eusview/live.py を動かし, EusLisp から関節角を送ると, このロボットが同じように動きます。").font(.caption).foregroundStyle(.secondary)
    }
  }
  func connect() {
    guard let u = URL(string: st.live.url) else { st.live.status = "URL が正しくありません"; return }
    UserDefaults.standard.set(st.live.url, forKey: "liveURL")
    let t = URLSession.shared.webSocketTask(with: u)
    st.live.task = t
    st.live.status = "接続中…"
    t.resume()
    t.send(.string("{\"hello\": \"\(st.rs.model.name)\"}")) { _ in }
    receive(t)
  }
  func receive(_ t: URLSessionWebSocketTask) {
    t.receive { r in
      Task { @MainActor in
        switch r {
        case .failure(let e):
          if st.live.task === t { st.live.status = "切断: \(e.localizedDescription)"; st.live.task = nil }
        case .success(let m):
          st.live.status = "受信中"
          var data: Data?
          if case .string(let s) = m { data = s.data(using: .utf8) } else if case .data(let d) = m { data = d }
          if let d = data, let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            if let a = o["angles"] as? [Double] { st.stop(); st.set(a.map { Float($0) }) }
            if let p = o["pose"] as? String, let a = st.rs.model.poses?[p] { st.move(to: a) }
            if let rt = o["root"] as? [Double], rt.count >= 12, !st.physics {
              let m = RobotMotion(name: "live", fps: 30, frames: [st.angles], root: [rt.map { Float($0) }])
              st.rs.setFrame(m, 0)
            }
          }
          receive(t)
        }
      }
    }
  }
}
