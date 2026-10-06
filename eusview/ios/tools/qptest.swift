// qptest.swift : GMR と GMR + 全身 QP (wbqp, WholeBodyQP.swift) を Mac のコマンドラインで比べる
//   tools/build-qptest.sh && build/qptest/qptest [-physics 0|1] [-realservo 0|1] [-maxsec 60] [-p 名前=値 ...] [種類/名前.ebvh ...] [-robots a,b,c]
//     [-dump <フォルダ>]: コマごとの参照と答えを <フォルダ>/<ロボット>-<種類>_<名前>.csv に (Android / デスクトップ版の QpTest.kt と同じ形. 比べる: bvh/qpcompare.py)
//   1 本 × 1 体ごとに: 自己衝突 / 可動範囲の端 / 重心が支持多角形の外 のコマの割合 (前 = GMR, 後 = QP),
//   追従のずれ (関節角, 手足 (腰から見た位置)), 床に着いた足のすべり, 1 コマの計算時間,
//   物理 (PhysicsSim = ODE): 関節角をサーボの目標にして再生し, 倒れたか (腰の傾き) を出す
import Foundation
import simd

let eusview = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()   // ios/build/qptest/main.swift → eusview
let cache = eusview.appendingPathComponent("bvh/cache")
let tables = loadRetargetTables(url: eusview.appendingPathComponent("bvh/retarget_tables.json"))!
func robot(_ name: String) -> RobotModel {
  for g in ["kxr", "khr", "jsk"] {
    if let d = try? Data(contentsOf: eusview.appendingPathComponent("robots/\(g)/\(name).json")) { return try! JSONDecoder().decode(RobotModel.self, from: d) }
  }
  fatalError("no robot \(name)")
}

var args = Array(CommandLine.arguments.dropFirst())
var physics = true, maxSec = 60.0, realServo = false, balance = false, stabilize = true, mpcOn = false, recover = false, stopAtFall = false
var params = [String: Double]()
var files = [String](), robots = ["kxrl2l6a6h2", "khr20h2", "sample-robot"]
var jsonOut: String? = nil
var dumpDir: String? = nil
var saveRobot: String? = nil
while !args.isEmpty {
  let a = args.removeFirst()
  switch a {
  case "-physics": physics = args.removeFirst() != "0"
  case "-maxsec": maxSec = Double(args.removeFirst())!
  case "-realservo": realServo = args.removeFirst() != "0"
  case "-balance": balance = args.removeFirst() != "0"
  case "-stopatfall": stopAtFall = args.removeFirst() != "0"   // 初めて倒れたら物理を止める (長い動作を速く測る)
  case "-recover": recover = args.removeFirst() != "0"   // 倒れたら起き上がって続ける (FallRecovery) でも再生
  case "-mpc": mpcOn = args.removeFirst() != "0"; balance = balance || mpcOn   // 閉ループの MPC (wbqp_mpc_step) でも再生
  case "-stabilize": stabilize = args.removeFirst() != "0"   // QP+バランスの再生で足首の安定化 (BalanceStabilizer)
  case "-p": let kv = args.removeFirst().split(separator: "="); params[String(kv[0])] = Double(kv[1])!
  case "-robots": robots = args.removeFirst().split(separator: ",").map(String.init)
  case "-json": jsonOut = args.removeFirst()
  case "-dump": dumpDir = args.removeFirst()
  case "-saverobot": saveRobot = args.removeFirst()   // 動作 (GMR, GMR+QP, QP+バランス) を入れたロボットの JSON (rendervideo 用)
  default: files.append(a)
  }
}
if files.isEmpty {
  files = ["mocopi/greeting1.ebvh", "rikiya/rbvh_a_A01.ebvh", "lafan1/dance1_subject1.ebvh", "lafan1/fallAndGetUp1_subject1.ebvh", "sfu/0005_Walking001.ebvh"]
}

func pct(_ a: Int, _ n: Int) -> Double { n > 0 ? 100 * Double(a) / Double(n) : 0 }
func stats(_ v: [Float]) -> (Float, Float) {
  guard !v.isEmpty else { return (0, 0) }
  let s = v.sorted()
  return (v.reduce(0, +) / Float(v.count), s[min(s.count - 1, s.count * 95 / 100)])
}

/// 物理: 関節角の列をサーボの目標にして再生. 腰 (ルートのリンク) の傾きの列 (度) を返す
var traceKin: [QPFrame]? = nil
var recordedTargets: [[Float]] = []
var stopRef: [Float]? = nil   // -stopatfall 1: 参照の傾きの列. 参照が立っている (< 30°) のに 60° より傾いたら物理を止める (初めて倒れた時刻だけ測る)   // 閉ループの MPC がサーボに入れた目標 (rendervideo で同じ物理を再生する)
var traceFeet: [Int] = []
func simulate(_ m: RobotModel, _ frames: [[Float]], fps: Double, maxFrames: Int, plan: [QPFrame]? = nil, stab: BalanceStabilizer? = nil, mpc: WholeBodyQP? = nil) -> [Float] {
  let rl = m.links.firstIndex { $0.parent < 0 } ?? 0
  let b = m.links[rl].rest.rot3.transpose * SIMD3<Float>(0, 0, 1)
  let sim = PhysicsSim(model: m, angles: frames[0], realServo: realServo)
  sim.step(0.5)
  var tilt = [Float]()
  for (i, f) in frames.enumerated() where i < maxFrames {
    if let q = mpc, let pl = plan, i < pl.count {
      // 閉ループの MPC: 物理の今の状態から毎コマ計画し直す
      let qm = q.toQ(sim.jointValues()), rm = WholeBodyQP.pose12(sim.linkPoses()[rl])
      var qo = [Double](repeating: 0, count: m.joints.count), info = [Double](repeating: 0, count: 8)
      let st = wbqp_mpc_step(q.h, Int32(i), qm, rm, q.toQ(pl[i].q), WholeBodyQP.pose12(pl[i].root), &qo, &info)
      let tg = st >= 0 ? q.toAngles(qo) : f
      recordedTargets.append(tg)
      sim.setTargets(tg)
      if let r0 = ProcessInfo.processInfo.environment["QPTEST_MPC"].flatMap({ Int($0) }), i >= r0, i < r0 + 60, i % 3 == 0 {
        print(String(format: "M %d st %d com %.3f %.3f tgt %.3f %.3f off %.3f %.3f slack %.4f c%d", i, st, info[0], info[1], info[2], info[3], info[4], info[5], info[6], pl[i].diag.contact))
      }
    } else if let st = stab, let pl = plan, i < pl.count {
      sim.setTargets(st.adjust(f, planRoot: pl[i].root, contact: pl[i].diag.contact, poses: sim.linkPoses(), dt: Float(1 / fps)))
    } else { sim.setTargets(f) }
    sim.step(1 / fps)
    let w = sim.linkPoses()[rl]
    let up = w.rot3 * b
    if !up.z.isFinite { tilt.append(180); continue }
    tilt.append(acos(max(-1, min(1, up.z))) * 180 / .pi)
    if let r = stopRef, i < r.count, tilt.last! > 60, r[i] < 30 { break }
    if let tk = traceKin, i < tk.count, let r0 = ProcessInfo.processInfo.environment["QPTEST_TRACE"].flatMap({ Int($0) }), i >= r0, i < r0 + 90, i % 2 == 0 {
      let P = sim.linkPoses()
      var M: Float = 0, c = SIMD3<Float>(0, 0, 0)
      let pl = m.physics?.links ?? []
      for k in 0..<min(pl.count, P.count) { let ms = Float(pl[k].mass ?? 0); let cc = pl[k].com ?? [0, 0, 0]; M += ms; c += ms * (P[k] * SIMD4<Float>(Float(cc[0]), Float(cc[1]), Float(cc[2]), 1)).xyz }
      c /= max(M, 1e-6)
      let d = tk[i].diag
      let fz = traceFeet.map { String(format: "%.3f", P[$0].pos3.z) }.joined(separator: " ")
      print(String(format: "T %d tilt %.0f c%d simcom %.3f %.3f kincom %.3f %.3f simfeet %@ kinfoot %.3f %.3f slack %.4f", i, tilt.last!, d.contact, c.x, c.y, d.after.com.0, d.after.com.1, fz, d.after.foot_height.0, d.after.foot_height.1, d.slack_max))
    }
  }
  if ProcessInfo.processInfo.environment["QPTEST_TILT"] != nil { print("tilt", stride(from: 0, to: min(tilt.count, 60), by: 3).map { String(format: "%.0f", tilt[$0]) }.joined(separator: " ")) }
  return tilt
}

/// 倒れたら起き上がって続ける再生 (FallRecovery). 動作の最後まで (時間の上限 limit 秒) 進め, 倒れた回数などを返す
func simulateRecover(_ m: RobotModel, _ frames: [[Float]], fps: Double, maxFrames: Int, plan: [QPFrame]? = nil, stab: BalanceStabilizer? = nil, mpc: WholeBodyQP? = nil) -> (FallRecovery, Int, Double) {
  let rl = m.links.firstIndex { $0.parent < 0 } ?? 0
  var sim = PhysicsSim(model: m, angles: frames[0], realServo: realServo)
  sim.step(0.5)
  let rec = FallRecovery(model: m)
  var i = 0, ticks = 0
  let n = min(frames.count, maxFrames), limit = Int(Double(n) * 3 + fps * 60)
  while i < n && ticks < limit {
    ticks += 1
    let f = frames[i]
    if let ov = rec.step(sim: sim, dt: 1 / fps, resume: f, replace: { a in sim = PhysicsSim(model: m, angles: a, realServo: realServo); sim.step(0.3) }) {
      sim.setTargets(ov)
      if rec.phase == .blend, let q = mpc { wbqp_reset(q.h) }   // 起き上がったら MPC の速さの見積もりをやり直す
      sim.step(1 / fps)
      continue
    }
    if let q = mpc, let pl = plan, i < pl.count {
      let qm = q.toQ(sim.jointValues()), rm = WholeBodyQP.pose12(sim.linkPoses()[rl])
      var qo = [Double](repeating: 0, count: m.joints.count)
      let st = wbqp_mpc_step(q.h, Int32(i), qm, rm, q.toQ(pl[i].q), WholeBodyQP.pose12(pl[i].root), &qo, nil)
      sim.setTargets(st >= 0 ? q.toAngles(qo) : f)
    } else if let st = stab, let pl = plan, i < pl.count {
      sim.setTargets(st.adjust(f, planRoot: pl[i].root, contact: pl[i].diag.contact, poses: sim.linkPoses(), dt: Float(1 / fps)))
    } else { sim.setTargets(f) }
    sim.step(1 / fps)
    i += 1
  }
  return (rec, i, Double(ticks) / fps)
}

var results = [[String: Any]]()
for rn in robots {
  let m = robot(rn)
  let rl = m.links.firstIndex { $0.parent < 0 } ?? 0
  let bUp = m.links[rl].rest.rot3.transpose * SIMD3<Float>(0, 0, 1)
  var printedModel = false
  for f in files {
    guard let mo = try? BVHMotion(url: cache.appendingPathComponent(f)) else { print("!! no \(f)"); continue }
    let rt = BVHRetargeter(model: m, motion: mo, tables: tables)
    guard rt.gmrOK else { print("!! GMR not available \(f) \(rn)"); continue }
    let qp = WholeBodyQP(model: m, rt: rt, fps: mo.fps, params: params)
    if !printedModel {
      printedModel = true
      var names = [String]()
      for i in 0..<Int(wbqp_num_pairs(qp.h)) { var a: Int32 = 0, b: Int32 = 0; wbqp_pair(qp.h, Int32(i), &a, &b); names.append("\(m.links[Int(a)].name)|\(m.links[Int(b)].name)") }
      var sole = [Double](repeating: 0, count: 60)
      let ns = wbqp_sole(qp.h, 0, &sole, 20)
      print(String(format: "== %@: リンク %d 関節 %d, カプセル %d, 調べる組 %d, 質量 %.3f kg, 大きさ (脚) %.3f m, 足の裏の頂点 %d",
                   rn, m.links.count, m.joints.count, qp.capsules, qp.pairs, wbqp_total_mass(qp.h), qp.scale, ns))
      if ProcessInfo.processInfo.environment["QPTEST_PAIRS"] != nil { print("   組:", names.joined(separator: " ")) }
    }
    var out = [QPFrame]()
    if ProcessInfo.processInfo.environment["QPTEST_FEET"] != nil {
      var o0 = [QPFrame]()
      runGMRQP(rt: rt, qp: qp, emit: { i, fr in if i < 3 { o0.append(fr) } })
      for fr in o0.prefix(1) {
        let Wr = robotFK(m, fr.qRef, root: qp.rootT(fr.rootRef)), Wq = robotFK(m, fr.q, root: qp.rootT(fr.root))
        for ln in ["lleg", "rleg"] { if let L = rt.limbs[ln] { let k = L.footLink ?? L.endLink
          print(ln, m.links[k].name, "ref", Wr[k].pos3, "qp", Wq[k].pos3, "ref rot z-axis", Wr[k].rot3 * SIMD3<Float>(0,0,1)) } }
        print("root ref", Wr[rl].pos3, "qp", Wq[rl].pos3)
        let d = fr.diag
        print("before min", d.before.min_dist, m.links[Int(d.before.pair.0)].name, m.links[Int(d.before.pair.1)].name, "n", d.before.n_collide, "after min", d.after.min_dist, m.links[Int(d.after.pair.0)].name, m.links[Int(d.after.pair.1)].name, "slack", d.slack_max, "rows", d.n_collision_rows)
      }
      qp.reset()
    }
    let t0 = Date()
    runGMRQP(rt: rt, qp: qp, emit: { _, fr in out.append(fr) })
    let total = Date().timeIntervalSince(t0) * 1000
    let n = out.count
    if let dir = dumpDir {
      // frame,contact,support,status,coll_before,coll_after,min_dist_before,min_dist_after,com_margin_before,com_margin_after,root_ref(12),root(12),q_ref...,q...
      var csv = ""
      for (i, fr) in out.enumerated() {
        let d = fr.diag
        var row: [String] = [String(i), String(d.contact), String(d.support), String(d.status), String(d.before.n_collide), String(d.after.n_collide)]
        row += [d.before.min_dist, d.after.min_dist, d.before.com_margin, d.after.com_margin].map { String(format: "%.6f", $0) }
        row += (WholeBodyQP.pose12(fr.rootRef) + WholeBodyQP.pose12(fr.root)).map { String(format: "%.6f", $0) }
        row += (fr.qRef + fr.q).map { String(format: "%.4f", $0) }
        csv += row.joined(separator: ",") + "\n"
      }
      let base = f.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ".ebvh", with: "")
      try? csv.write(toFile: "\(dir)/\(rn)-\(base).csv", atomically: true, encoding: .utf8)
    }
    let qpMs = out.map { Float($0.diag.time_ms) }
    let (qpMean, qp95) = stats(qpMs)
    let qpMax = qpMs.max() ?? 0
    let gmrMs = (total - Double(qpMs.reduce(0, +))) / Double(n)
    var cB = 0, cA = 0, lB = 0, lA = 0, oB = 0, oA = 0, comB = 0, comA = 0, withC = 0, fail = 0
    var minB = 1e9, minA = 1e9
    var jerr = [Float](), herr = [Float](), ferr = [Float](), slipB = [Float](), slipA = [Float]()
    var prevFeetB: [SIMD3<Float>]? = nil, prevFeetA: [SIMD3<Float>]? = nil, prevC: Int32 = 0
    for fr in out {
      let d = fr.diag
      if d.before.n_collide > 0 { cB += 1 }
      if d.after.n_collide > 0 { cA += 1 }
      if d.before.n_at_limit > 0 { lB += 1 }
      if d.after.n_at_limit > 0 { lA += 1 }
      if d.before.n_limit > 0 { oB += 1 }
      if d.after.n_limit > 0 { oA += 1 }
      if d.status < 0 { fail += 1 }
      minB = min(minB, d.before.min_dist); minA = min(minA, d.after.min_dist)
      if d.contact != 0 {
        withC += 1
        if d.before.com_margin < 0 { comB += 1 }
        if d.after.com_margin < 0 { comA += 1 }
      }
      for k in 0..<m.joints.count where m.joints[k].type != "linear" { jerr.append(abs(fr.q[k] - fr.qRef[k])) }
      // 手足の位置 (腰から見た) のずれ
      let Wr = robotFK(m, fr.qRef, root: qp.rootT(fr.rootRef)), Wq = robotFK(m, fr.q, root: qp.rootT(fr.root))
      let ir = simd_inverse(Wr[rl]), iq = simd_inverse(Wq[rl])
      for (k, ln) in ["larm", "rarm", "lleg", "rleg"].enumerated() {
        guard let L = rt.limbs[ln] else { continue }
        let link: Int = k < 2 ? L.endLink : (L.footLink ?? L.endLink)
        let off: SIMD3<Float> = k < 2 ? L.endOffset : SIMD3<Float>(0, 0, 0)
        let a: SIMD3<Float> = (ir * (Wr[link] * SIMD4<Float>(off, 1))).xyz
        let b: SIMD3<Float> = (iq * (Wq[link] * SIMD4<Float>(off, 1))).xyz
        if k < 2 { herr.append(simd_distance(a, b) * 1000) } else { ferr.append(simd_distance(a, b) * 1000) }
      }
      // 床に着いた足のすべり (コマの間の水平の動き)
      let feetB = ["lleg", "rleg"].compactMap { rt.limbs[$0] }.map { Wr[$0.footLink ?? $0.endLink].pos3 }
      let feetA = ["lleg", "rleg"].compactMap { rt.limbs[$0] }.map { Wq[$0.footLink ?? $0.endLink].pos3 }
      if let pb = prevFeetB, let pa = prevFeetA {
        for s in 0..<min(2, feetB.count) where (d.contact & prevC & (1 << s)) != 0 {
          slipB.append(simd_length(SIMD2(feetB[s].x - pb[s].x, feetB[s].y - pb[s].y)) * 1000)
          slipA.append(simd_length(SIMD2(feetA[s].x - pa[s].x, feetA[s].y - pa[s].y)) * 1000)
        }
      }
      prevFeetB = feetB; prevFeetA = feetA; prevC = d.contact
    }
    let (jm, j95) = stats(jerr), (hm, h95) = stats(herr), (fm, f95) = stats(ferr)
    let (sbm, _) = stats(slipB), (sam, _) = stats(slipA)
    print(String(format: "-- %@ × %@: %d コマ (%.0f fps)  GMR %.2f ms/コマ, QP 平均 %.2f / 95%% %.2f / 最大 %.2f ms/コマ, 解けない %d",
                 f, rn, n, mo.fps, gmrMs, qpMean, qp95, qpMax, fail))
    print(String(format: "   自己衝突 %.1f%% → %.1f%% (最小距離 %.1f → %.1f mm), 可動範囲の端 %.1f%% → %.1f%% (外 %.1f%% → %.1f%%), 重心が外 %.1f%% → %.1f%% (足が着いたコマ %d)",
                 pct(cB, n), pct(cA, n), minB * 1000, minA * 1000, pct(lB, n), pct(lA, n), pct(oB, n), pct(oA, n), pct(comB, withC), pct(comA, withC), withC))
    print(String(format: "   追従のずれ: 関節 平均 %.1f° / 95%% %.1f°, 手 %.1f / %.1f mm, 足 %.1f / %.1f mm (腰から見た位置), 着いた足のすべり %.2f → %.2f mm/コマ",
                 jm, j95, hm, h95, fm, f95, sbm, sam))
    var r: [String: Any] = ["file": f, "robot": rn, "frames": n, "fps": mo.fps, "gmr_ms": gmrMs, "qp_ms_mean": qpMean, "qp_ms_p95": qp95, "qp_ms_max": qpMax,
                            "collide_before": pct(cB, n), "collide_after": pct(cA, n), "min_dist_before_mm": minB * 1000, "min_dist_after_mm": minA * 1000,
                            "at_limit_before": pct(lB, n), "at_limit_after": pct(lA, n), "out_limit_before": pct(oB, n), "out_limit_after": pct(oA, n),
                            "com_out_before": pct(comB, withC), "com_out_after": pct(comA, withC), "contact_frames": withC,
                            "joint_err_deg_mean": jm, "joint_err_deg_p95": j95, "hand_err_mm_mean": hm, "hand_err_mm_p95": h95,
                            "foot_err_mm_mean": fm, "foot_err_mm_p95": f95, "slip_before_mm": sbm, "slip_after_mm": sam, "qp_fail": fail]
    if physics {
      let maxF = Int(maxSec * mo.fps)
      let refTilt = out.prefix(maxF).map { fr -> Float in let up = fr.rootRef.rot3 * bUp; return acos(max(-1, min(1, up.z))) * 180 / .pi }
      stopRef = stopAtFall ? refTilt : nil
      let tG = simulate(m, out.map { $0.qRef }, fps: mo.fps, maxFrames: maxF)
      let tQ = simulate(m, out.map { $0.q }, fps: mo.fps, maxFrames: maxF)
      func fall(_ t: [Float]) -> (Double?, Double, Double) {   // 初めて倒れた時刻 (参照は立っているのに 60° より傾いた), 倒れていた割合, 参照との傾きの差の平均
        var first: Double? = nil, down = 0, diff: Float = 0
        for (i, v) in t.enumerated() {
          if v > 60 { down += 1; if first == nil && refTilt[i] < 30 { first = Double(i) / mo.fps } }
          diff += abs(v - refTilt[i])
        }
        return (first, pct(down, t.count), Double(diff) / Double(max(1, t.count)))
      }
      let (fG, dG, eG) = fall(tG), (fQ, dQ, eQ) = fall(tQ)
      if balance {
        // GMR + QP + バランス
        let qb = WholeBodyQP(model: m, rt: rt, fps: mo.fps, params: params)
        var outB = [QPFrame]()
        var slackFrames = 0
        let tb0 = Date()
        runGMRQPBalance(rt: rt, qp: qb, zmpSlack: &slackFrames, emit: { _, fr in outB.append(fr) })
        let msB = Date().timeIntervalSince(tb0) * 1000 / Double(max(1, outB.count))
        traceKin = outB
        traceFeet = ["lleg", "rleg"].compactMap { rt.limbs[$0] }.map { $0.footLink ?? $0.endLink }
        let feetLinks = ["lleg", "rleg"].compactMap { rt.limbs[$0] }.map { $0.footLink ?? $0.endLink }
        let tB = simulate(m, outB.map { $0.q }, fps: mo.fps, maxFrames: maxF, plan: outB, stab: stabilize ? BalanceStabilizer(model: m, feet: feetLinks) : nil)
        traceKin = nil
        let (fB, dB, eB) = fall(tB)
        var jb = [Float]()
        for fr in outB { for k in 0..<m.joints.count where m.joints[k].type != "linear" { jb.append(abs(fr.q[k] - fr.qRef[k])) } }
        let (jbm, jb95) = stats(jb)
        let collB = outB.filter { $0.diag.after.n_collide > 0 }.count
        print(String(format: "   QP+バランス: %@ (倒れていた %.0f%%, 傾きの差 %.0f°), ZMP を緩めたコマ %d, 衝突 %.1f%%, 関節のずれ %.1f° / %.1f°, %.2f ms/コマ",
                     fB.map { String(format: "%.1f 秒で倒れる", $0) } ?? "倒れない", dB, eB, slackFrames, pct(collB, outB.count), jbm, jb95, msB))
        if mpcOn {
          recordedTargets = []
          let tM = simulate(m, outB.map { $0.q }, fps: mo.fps, maxFrames: maxF, plan: outB, mpc: qb)
          let (fM, dM, eM) = fall(tM)
          print(String(format: "   GMR+MPC（閉ループ）: %@ (倒れていた %.0f%%, 傾きの差 %.0f°)", fM.map { String(format: "%.1f 秒で倒れる", $0) } ?? "倒れない", dM, eM))
          r["phys_fall_mpc"] = fM ?? -1; r["phys_down_mpc"] = dM
        }
        if let sp = saveRobot {
          var mm = m
          let fps = Float(mo.fps)
          mm.motions = [RobotMotion(name: "gmr", fps: fps, frames: out.map { $0.qRef }, root: nil),
                        RobotMotion(name: "gmrqp", fps: fps, frames: out.map { $0.q }, root: nil),
                        RobotMotion(name: "balance", fps: fps, frames: outB.map { $0.q }, root: nil)]
          if !recordedTargets.isEmpty { mm.motions!.append(RobotMotion(name: "mpc_targets", fps: fps, frames: recordedTargets, root: nil)) }
          if let d = try? JSONEncoder().encode(mm) { try? d.write(to: URL(fileURLWithPath: sp)); print("wrote \(sp)") }
        }
        if recover {
          func rs(_ x: (FallRecovery, Int, Double), _ n: Int) -> String {
            String(format: "%@, 最後まで %@ (%d / %d コマ, %.0f 秒かかった)", x.0.summary, x.1 >= n ? "再生できた" : "届かない", x.1, n, x.2)
          }
          let nF = min(out.count, maxF)
          print("   起き上がり つき: GMR+QP", rs(simulateRecover(m, out.map { $0.q }, fps: mo.fps, maxFrames: maxF), nF))
          print("   起き上がり つき: QP+バランス", rs(simulateRecover(m, outB.map { $0.q }, fps: mo.fps, maxFrames: maxF, plan: outB, stab: stabilize ? BalanceStabilizer(model: m, feet: feetLinks) : nil), nF))
          if mpcOn { print("   起き上がり つき: GMR+MPC", rs(simulateRecover(m, outB.map { $0.q }, fps: mo.fps, maxFrames: maxF, plan: outB, mpc: qb), nF)) }
        }
        r["phys_fall_bal"] = fB ?? -1; r["phys_down_bal"] = dB; r["phys_tiltdiff_bal"] = eB; r["bal_zmp_slack"] = slackFrames
        r["bal_collide"] = pct(collB, outB.count); r["bal_joint_err_mean"] = jbm; r["bal_joint_err_p95"] = jb95; r["bal_ms"] = msB
      }
      let refDown = pct(refTilt.filter { $0 > 60 }.count, refTilt.count)
      func ft(_ x: Double?) -> String { x.map { String(format: "%.1f 秒で倒れる", $0) } ?? "倒れない" }
      print(String(format: "   物理%@ (%.0f 秒): GMR %@ (倒れていた %.0f%%, 傾きの差 %.0f°) / GMR+QP %@ (倒れていた %.0f%%, 傾きの差 %.0f°)  参照が倒れている %.0f%%",
                   realServo ? "（KRS の公称のサーボ）" : "（アプリの既定のサーボ）", Double(tG.count) / mo.fps, ft(fG), dG, eG, ft(fQ), dQ, eQ, refDown))
      r["phys_sec"] = Double(tG.count) / mo.fps
      r["phys_fall_gmr"] = fG ?? -1; r["phys_fall_qp"] = fQ ?? -1
      r["phys_down_gmr"] = dG; r["phys_down_qp"] = dQ; r["phys_tiltdiff_gmr"] = eG; r["phys_tiltdiff_qp"] = eQ; r["ref_down"] = refDown
    }
    results.append(r)
    fflush(stdout)
  }
}
if let j = jsonOut, let d = try? JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]) {
  try? d.write(to: URL(fileURLWithPath: j))
  print("wrote \(j)")
}
