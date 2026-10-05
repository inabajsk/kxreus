// retargettest.swift : BVHRetarget.swift (アプリの BVH → ロボットの移し替え) を Mac のコマンドラインで確かめる
//   tools/build-retargettest.sh && build/retargettest/retargettest [kxreus | gmr | all]
//   kxreus: 方法 1 を kxreus (~/kxreus/eusview-retarget.l の eusview-bvh-export-retarget, eusview/bvh/retarget-kxreus.l
//           → ~/.cache/eusview/retarget-*-names.json) と比べる (全部の関節角とルートの向き)
//   gmr: 方法 2 (GMR) を全部のコマで解き, 時間・数でない値・可動範囲・手首 / 足首の目標とのずれを出す
import Foundation
import simd

let top = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let eusview = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()   // ios/build/retargettest/main.swift → eusview
let cache = eusview.appendingPathComponent("bvh/cache")
let tables = loadRetargetTables(url: eusview.appendingPathComponent("bvh/retarget_tables.json"))!
func robot(_ name: String) -> RobotModel {
  for g in ["kxr", "khr", "jsk"] {
    let u = eusview.appendingPathComponent("robots/\(g)/\(name).json")
    if let d = try? Data(contentsOf: u) { return try! JSONDecoder().decode(RobotModel.self, from: d) }
  }
  fatalError("no robot \(name)")
}
func ebvhName(_ kind: String, _ file: String) -> String {   // convert_bvh.py の name_of
  var n = String(file.dropFirst(kind.count + 1))
  if n.lowercased().hasSuffix(".bvh") { n = String(n.dropLast(4)) }
  if n.hasSuffix("/poses") { n = String(n.dropLast(6)) }
  return "\(kind)/" + n.replacingOccurrences(of: "/", with: "_") + ".ebvh"
}
let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "all"
var models = [String: RobotModel]()
func model(_ n: String) -> RobotModel { if let m = models[n] { return m }; let m = robot(n); models[n] = m; return m }

if mode == "kxreus" || mode == "all" {
  struct KX: Codable { struct F: Codable { var frame: Int; var angles: [Float]; var root: [Float] }; var file: String; var kind: String; var robot: String; var joints: [String]; var frames: [F] }
  let dir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".cache/eusview")
  let fs = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasPrefix("retarget-") && $0.hasSuffix("-names.json") }.sorted()
  print("== 方法 1 (関節名) と kxreus eusview-retarget.l :names の差 (\(fs.count) ファイル)")
  var sum = [String: (Float, Float, Int, String)]()   // kind robot → (関節角の最大, ルートの向きの最大, 数, どこ)
  for f in fs {
    guard let d = try? Data(contentsOf: dir.appendingPathComponent(f)), let kx = try? JSONDecoder().decode(KX.self, from: d) else { print("!! read", f); continue }
    let mo = try! BVHMotion(url: cache.appendingPathComponent(ebvhName(kx.kind, kx.file)))
    let m = model(kx.robot)
    let rt = BVHRetargeter(model: m, motion: mo, tables: tables)
    let key = "\(kx.kind) \(kx.robot)"
    var cur = sum[key] ?? (0, 0, 0, "")
    for fr in kx.frames {
      guard fr.frame % mo.header.step == 0 else { continue }
      let r = rt.method1(fr.frame / mo.header.step)
      for (k, n) in kx.joints.enumerated() {
        guard let j = m.joints.firstIndex(where: { $0.name == n }) else { print("!! joint", n); continue }
        // KXR のハンド (gripper) は BVH では動かさない. JSON の reset-pose (−21.9°) と kxreus の :reset-pose (0°) が違うので除く
        if n.contains("gripper") { continue }
        let dd = abs(r.angles[j] - fr.angles[k])
        cur.2 += 1
        if dd > cur.0 { cur.0 = dd; cur.3 = "\(kx.file) frame \(fr.frame) \(n): app \(r.angles[j]) eus \(fr.angles[k])" }
      }
      let R = rt.rootLinkPose(r.root).rot3
      let E = simd_float3x3(rows: [SIMD3(fr.root[3], fr.root[4], fr.root[5]), SIMD3(fr.root[6], fr.root[7], fr.root[8]), SIMD3(fr.root[9], fr.root[10], fr.root[11])])
      cur.1 = max(cur.1, simd_length(rotLog(R.transpose * E)) * 180 / .pi)
    }
    sum[key] = cur
  }
  for k in sum.keys.sorted() { let v = sum[k]!; print(String(format: "%-28@ 関節角 max %.4f° (%d)  ルートの向き max %.3f°  %@", k as NSString, v.0, v.2, v.1, v.3 as NSString)) }
}

if mode == "gmr" || mode == "all" {
  print("== 方法 2 (GMR)")
  let files = ["mocopi/greeting1.ebvh", "rikiya/rbvh_a_A01.ebvh", "sfu/0005_Jogging001.ebvh", "tum-kitchen/0-0.ebvh", "lafan1/walk1_subject1.ebvh", "lafan1/dance1_subject1.ebvh"]
  for f in files {
    let mo = try! BVHMotion(url: cache.appendingPathComponent(f))
    for rn in ["kxrl2l6a6h2", "khr20h2", "sample-robot"] {
      let m = model(rn)
      let rt = BVHRetargeter(model: m, motion: mo, tables: tables)
      var nan = 0, lim = 0
      var res = [String: [Float]]()
      let n = mo.frames
      let t0 = Date()
      for i in 0..<n {
        let r = rt.gmr(i)
        if r.angles.contains(where: { !$0.isFinite }) || !(0..<16).allSatisfy({ r.root[$0 / 4][$0 % 4].isFinite }) { nan += 1 }
        for (k, j) in m.joints.enumerated() where r.angles[k] < (j.min ?? -1e9) - 1e-3 || r.angles[k] > (j.max ?? 1e9) + 1e-3 { lim += 1 }
        for (k, v) in rt.residual { res[k, default: []].append(v) }
      }
      let ms = Date().timeIntervalSince(t0) * 1000 / Double(n)
      var s = ""
      for k in ["larm", "rarm", "lleg", "rleg"] {
        guard var v = res[k], !v.isEmpty else { continue }
        v.sort()
        s += String(format: " %@ 中央 %.1f / 95%% %.1f mm", k, v[v.count / 2] * 1000, v[v.count * 95 / 100] * 1000)
      }
      print(String(format: "%-28@ %-13@ %5d コマ %.3f ms/コマ  NaN %d  範囲外 %d  s_leg %.3f s_arm %.3f |%@", f as NSString, rn as NSString, n, ms, nan, lim, rt.sLeg, rt.sArm, s as NSString))
    }
  }
}
