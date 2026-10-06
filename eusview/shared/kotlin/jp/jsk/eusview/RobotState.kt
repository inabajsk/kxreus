// RobotState.kt : ロボットの表示の状態と操作 (関節角, 姿勢へ動かす, 動作の再生, 物理モード). iOS 版 RobotView.swift の RobotState
package jp.jsk.eusview

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.min

class RobotState(val model: RobotModel) {
    val scene = RobotScene(model)
    var angles by mutableStateOf(FloatArray(model.joints.size)); private set
    var playing by mutableStateOf<String?>(null); private set
    var physics by mutableStateOf(false); private set
    var servoOn by mutableStateOf(true); private set
    var simInfo by mutableStateOf("")
    val live = LiveLink(this)
    // BVH から移した動作 (BvhRetarget.kt)
    var bvhProgress by mutableStateOf<Double?>(null); private set
    var bvhInfo by mutableStateOf(""); private set
    var bvhMotion by mutableStateOf<RobotMotion?>(null); private set
    /** BVH の動作を物理で再生していて倒れたとき: 「倒れた n 回・起き上がり n 回」と起き上がり中の動作の名前 */
    var recoverInfo by mutableStateOf(""); private set
    private var bvhJob: Job? = null
    // GMR + QP + バランスの動作: 物理で再生するときの安定化 (コマごとの contact と計画のルートは plan のコマ)
    private var balancePlan by mutableStateOf<Triple<RobotMotion, List<QpFrame>, BalanceStabilizer>?>(null)
    /** 今の BVH の動作が GMR + QP + バランス (物理オンなら足首で安定化する) */
    val balanceMotion get() = balancePlan != null && balancePlan?.first === bvhMotion
    // GMR + MPC (閉ループ): 動作 (関節角は QP + バランスの答え), そのコマの計画, 計画を持った WholeBodyQp (メインのスレッドだけで使う)
    private var mpcPlan by mutableStateOf<Triple<RobotMotion, List<QpFrame>, WholeBodyQp>?>(null)
    /** 今の BVH の動作が GMR + MPC (物理オンなら毎コマ MPC, オフなら QP + バランスの関節角) */
    val mpcMotion get() = mpcPlan != null && mpcPlan?.first === bvhMotion
    /** 3D 表示 (BVH の動作でカメラが腰についていく) */
    var glView: SceneView? = null

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var timer: Job? = null
    private var sim: PhysicsSim? = null
    private var simJob: Job? = null

    init { model.poses?.get("reset-pose")?.let { set(it) } }

    /** 関節角の指令. 物理モードではサーボの目標, そうでなければそのまま表示 */
    fun set(a: FloatArray) {
        angles = a
        val s = sim
        if (s != null) s.setTargets(a) else scene.setAngles(a)
    }

    /** 物理モードを始める (今の姿勢で床に置く) / やめる */
    fun enablePhysics(on: Boolean) {
        simJob?.cancel(); simJob = null
        sim?.destroy(); sim = null
        physics = on
        if (!on) { scene.resetRoot(); scene.setAngles(angles); return }
        val s = try { PhysicsSim(model, angles) } catch (e: Throwable) {
            physics = false; simInfo = "物理モードを始められません: $e"; return
        }
        s.setServo(servoOn)
        sim = s
        scene.setWorldPoses(s.linkPoses())
        simJob = scope.launch {
            var last = System.nanoTime()
            while (isActive) {
                delay(16)
                val now = System.nanoTime()
                val t0 = now
                s.step(min((now - last) / 1e9, 0.1))   // 実時間で進める (止まっていたときは 0.1 秒まで)
                last = now
                val poses = s.linkPoses()
                // 発散 (数でない・100 m より遠い) したら物理を止める (起き上がりの動作などで起きることがある)
                if (poses.any { m -> (12..14).any { k -> !m[k].isFinite() || kotlin.math.abs(m[k]) > 100f } }) {
                    val t = s.time
                    enablePhysics(false)
                    simInfo = String.format("物理の計算が発散したので止めました（%.1f 秒）。置き直すか、別の動作で", t)
                    break
                }
                scene.setWorldPoses(poses)
                val ms = (System.nanoTime() - t0) / 1e6
                simInfo = String.format("%.1f 秒  接触 %d 点  計算 %.1f ms/コマ", s.time, s.contacts, ms)
            }
        }
    }

    fun enableServo(on: Boolean) { servoOn = on; sim?.setServo(on) }

    /** 今の姿勢から目標の姿勢へ 0.6 秒で動かす */
    fun move(target: FloatArray) {
        stop()
        val from = angles.copyOf()
        val t0 = System.nanoTime()
        timer = scope.launch {
            while (isActive) {
                val s = min(1.0, (System.nanoTime() - t0) / 0.6e9).toFloat()
                val e = s * s * (3 - 2 * s)
                set(FloatArray(from.size) { k -> val b = target.getOrElse(k) { from[k] }; from[k] + (b - from[k]) * e })
                if (s >= 1f) break
                delay(16)
            }
        }
    }

    /** 動作を繰り返し再生する (止めるまで). 物理モードでは動作の関節角をサーボの目標にする */
    fun play(m: RobotMotion, follow: Boolean = false) {
        stop()
        if (m.frames.isEmpty()) return
        playing = m.name
        val fps = maxOf(m.fps, 1f)
        timer = scope.launch {
            // 物理モード: 今の姿勢から初めのコマへ 0.8 秒かけて移ってから再生する (いきなり跳ぶと倒れる. iOS 版と同じ)
            if (sim != null) {
                val from = angles.copyOf(); val to = m.frames[0]; val tb = System.nanoTime()
                while (isActive) {
                    val s = min(1.0, (System.nanoTime() - tb) / 0.8e9).toFloat()
                    val e = s * s * (3 - 2 * s)
                    set(FloatArray(from.size) { k -> val b = to.getOrElse(k) { from[k] }; from[k] + (b - from[k]) * e })
                    if (s >= 1f) break
                    delay(16)
                }
            }
            val bp = balancePlan?.takeIf { it.first === m }
            bp?.third?.reset()
            val mp = mpcPlan?.takeIf { it.first === m }
            mp?.third?.reset()
            // BVH の動作を物理で再生するとき: 倒れたら起き上がりの動作をしてから倒れたコマの続きを再生する (FallRecovery)
            val isBvh = m === bvhMotion
            val rec = if (isBvh) FallRecovery(model) else null
            recoverInfo = ""
            var mt = 0.0                     // 動作の時刻 (起き上がりの間は止める)
            var lastT = System.nanoTime()
            var shown = -1
            var last: FloatArray? = null
            while (isActive) {
                val now = System.nanoTime()
                val dt = min((now - lastT) / 1e9, 0.1); lastT = now
                val i = ((mt * fps).toLong() % m.frames.size).toInt()
                val s = sim
                if (s != null && rec != null) {
                    val r = rec.step(s, dt, m.frames[i]) { a -> angles = a; enablePhysics(true) }   // 置き直す
                    val s2 = sim
                    if (r != null) { if (s2 != null) set(r); bp?.third?.reset(); mp?.third?.reset(); shown = -1 }   // MPC: 続きに戻るとき初めから
                    else {
                        mt += dt
                        val j = ((mt * fps).toLong() % m.frames.size).toInt()
                        if (j != shown && s2 != null) {
                            shown = j
                            val pf = bp?.second?.getOrNull(j)
                            val mf = mp?.second?.getOrNull(j)
                            if (mp != null && mf != null) set(mp.third.mpcStep(j, s2, mf))   // GMR + MPC: 物理の今の状態から目標を出す
                            else if (bp != null && pf != null) set(bp.third.adjust(m.frames[j], pf.root, pf.diag.contact, s2.linkPoses(), 1f / fps))
                            else set(m.frames[j])
                        }
                    }
                    recoverInfo = if (rec.falls == 0) "" else rec.summary + (if (rec.current.isNotEmpty()) "・起き上がり中: ${rec.current}" else "")
                    delay(16)
                    continue
                }
                mt += dt
                val k = ((mt * fps).toLong() % m.frames.size).toInt()
                if (k != shown) {
                    shown = k
                    if (s != null) {
                        // GMR + QP + バランス: 計画の体の傾きと物理の体の傾きの差を, 着いた足の足首で戻す (BalanceStabilizer)
                        val pf = bp?.second?.getOrNull(k)
                        val mf = mp?.second?.getOrNull(k)
                        if (mp != null && mf != null) set(mp.third.mpcStep(k, s, mf))
                        else if (bp != null && pf != null) set(bp.third.adjust(m.frames[k], pf.root, pf.diag.contact, s.linkPoses(), 1f / fps))
                        else set(m.frames[k])
                    } else {
                        scene.setFrame(m, k); angles = scene.angles.copyOf()
                        // BVH の動作は歩いて遠くへ行くので, カメラがルートの水平の動きについていく (繰り返しの頭に戻ったときは動かさない)
                        val r = m.root?.getOrNull(k)
                        if (follow && r != null) {
                            val l = last; val v = glView
                            if (l != null && v != null && kotlin.math.hypot(r[0] - l[0], r[1] - l[1]) < 0.5f) v.follow(r[0] - l[0], r[1] - l[1], 0f)
                            last = floatArrayOf(r[0], r[1])
                        }
                    }
                }
                delay(maxOf(4L, (500 / fps).toLong()))
            }
        }
    }

    fun stop() { timer?.cancel(); timer = null; playing = null }

    /** BVH を移して動作にし (全部のコマを先に計算する), 繰り返し再生する */
    fun playBVH(e: BvhEntry, method: RetargetMethod) {
        stop()
        bvhJob?.cancel()
        val tables = loadRetargetTables() ?: run { bvhInfo = "retarget_tables.json がありません"; return }
        val name = "BVH ${e.kind}/${e.file.name}（${method.title}）"
        bvhProgress = 0.0
        bvhInfo = "${e.kind}/${e.file.name} を${method.title}で移しています"
        bvhJob = scope.launch {
            val t0 = System.nanoTime()
            val job = coroutineContext[Job]
            var qpInfo = ""
            var plan: Triple<RobotMotion, List<QpFrame>, BalanceStabilizer>? = null
            var kept: WholeBodyQp? = null      // GMR + MPC: 計画を持った QP (渡せなかったら放す)
            var mplan: Triple<RobotMotion, List<QpFrame>, WholeBodyQp>? = null
            try {
                val m = try {
                    withContext(Dispatchers.Default) {
                        val mo = BvhMotion.load(e.file.file)
                        val rt = BvhRetargeter(model, mo, tables)
                        var lastP = -1.0
                        val prog = { p: Double -> if (p - lastP >= 0.02 || p >= 1) { lastP = p; scope.launch { bvhProgress = p } }; Unit }
                        if (method == RetargetMethod.GMRQP || method == RetargetMethod.BALANCE || method == RetargetMethod.MPC) {
                            // GMR + 全身 QP (自己衝突・可動範囲・重心, WholeBodyQp.kt / wbqp.cpp). BALANCE, MPC は重心の軌道を先に決める
                            //   MPC は計画を持った WholeBodyQp を残し, 物理で再生するとき毎コマ mpcStep
                            val isMpc = method == RetargetMethod.MPC
                            val bal = method == RetargetMethod.BALANCE || isMpc
                            makeGmrQpMotion(rt, name, prog, { job?.isActive != true }, bal, if (isMpc) { q -> kept = q } else null)?.let { (mm, fr) ->
                                val s = qpSummary(fr)
                                qpInfo = String.format("・QP %.2f ms/コマ・衝突 %.0f%%→%.0f%%・重心が外 %.0f%%→%.0f%%", s[0], s[1], s[2], s[3], s[4])
                                val k = kept
                                if (isMpc && k != null) mplan = Triple(mm, fr, k)
                                else if (bal) {
                                    val feet = listOf("lleg", "rleg").mapNotNull { rt.limbs[it] }.map { it.footLink ?: it.endLink }
                                    plan = Triple(mm, fr, BalanceStabilizer(model, feet))
                                }
                                mm
                            }
                        } else rt.makeMotion(method, name, prog, { job?.isActive != true })
                    }
                } catch (ex: Throwable) { bvhProgress = null; bvhInfo = "読めません: $ex"; Platform.logError("BVH motion", ex); return@launch }
                val sec = (System.nanoTime() - t0) / 1e9
                bvhProgress = null
                if (m == null) { bvhInfo = "やめました"; return@launch }
                bvhMotion = m
                balancePlan = plan
                mpcPlan?.third?.destroy()
                mpcPlan = mplan; kept = null
                bvhInfo = String.format("%d コマを %.1f 秒で計算（%.2f ms/コマ）", m.frames.size, sec, sec * 1000 / maxOf(1, m.frames.size)) + qpInfo
                Platform.log("BVH motion $name: $bvhInfo")
                play(m, follow = true)
            } finally { kept?.destroy() }
        }
    }
    fun cancelBVH() { bvhJob?.cancel(); bvhJob = null; if (bvhProgress != null) { bvhProgress = null; bvhInfo = "やめました" } }

    /** 起動の引数 bvhmotion で BVH の動作を再生する (確認用, 一度だけ) */
    fun launchBVH() {
        if (launchDone) return
        val arg = Launch.get("bvhmotion") ?: return
        launchDone = true
        val all = loadBvhIndex().orEmpty().flatMap { k -> k.files.map { BvhEntry(k.name, it) } }
        val e = all.firstOrNull { "${it.kind}/${it.file.name}" == arg } ?: run { bvhInfo = "$arg がありません"; return }
        if (Launch.get("physics") == "1") enablePhysics(true)
        playBVH(e, when (Launch.get("method")) { "names" -> RetargetMethod.NAMES; "gmrqp", "qp" -> RetargetMethod.GMRQP; "balance" -> RetargetMethod.BALANCE; "mpc" -> RetargetMethod.MPC; else -> RetargetMethod.GMR })
    }
    companion object { var launchDone = false }

    fun shutdown() {
        stop(); live.disconnect(); bvhJob?.cancel()
        mpcPlan?.third?.destroy(); mpcPlan = null
        simJob?.cancel(); simJob = null; sim?.destroy(); sim = null
        scope.cancel()
    }
}
