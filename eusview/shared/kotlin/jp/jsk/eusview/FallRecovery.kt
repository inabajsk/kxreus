// FallRecovery.kt : 物理 (PhysicsSim) で BVH などの動作を再生していて倒れたら, 起き上がってから倒れたコマの続きを再生する
//   (iOS 版 Physics/FallRecovery.swift を移したもの. 同じ作り・同じ既定値)
//   1. 倒れた: 腰 (ルートのリンク) の上向きが fallDeg (60°) より fallHold (0.3 秒) 続けて傾いた → 動作の時間を止める
//   2. 起き上がり: 体の前 (ルートのリンクの前) が下を向いていれば うつ伏せ, 上なら 仰向け の起き上がりの動作 (RCB4 のプロジェクトの動作,
//      ロボットの JSON の motions. KHR は「起きあがり(うつぶせ)/(仰向け)」, KXR は「起き上がり（うつ伏せ）/（仰向け）」) をサーボの目標にして再生
//   3. 立てたか: 動作が終わってから settle (1 秒) までに傾きが standDeg (25°) 未満なら, blend (0.6 秒) かけて倒れたコマの姿勢へ移り, そこから続ける.
//      立てなければもう一度 (maxTries 回まで). 起き上がりの動作がないロボットや, 起き上がれないときは置き直す (今の続きの姿勢で床に置く)
//   使い方: 毎コマ step(sim, dt, resume = 今のコマの関節角 (度), replace = { a -> 物理を a で作り直す }) が null ならいつもどおり進め,
//   配列ならそれをサーボの目標にしてコマを進めない. 最初に戻すときは reset()
package jp.jsk.eusview

import kotlin.math.acos

class FallRecovery(val model: RobotModel) {
    enum class Phase { PLAYING, GETUP, SETTLE, BLEND }
    val rootLink = model.links.indexOfFirst { it.parent < 0 }.coerceAtLeast(0)
    private val bodyUp: FloatArray
    private val bodyFwd: FloatArray
    val getupProne: RobotMotion?
    val getupSupine: RobotMotion?
    var fallDeg = 60f; var standDeg = 25f
    var fallHold = 0.3; var settleTime = 1.0; var blendTime = 0.6
    var maxTries = 2
    var phase = Phase.PLAYING; private set
    var falls = 0; private set
    var getups = 0; private set
    var replaces = 0; private set
    /** 起き上がりの動作の名前 (表示用, 起き上がり中だけ) */
    var current = ""; private set
    private var downFor = 0.0; private var t = 0.0; private var tries = 0
    private var motion: RobotMotion? = null
    private var blendFrom = FloatArray(0)

    init {
        val R = M3.t(model.links[rootLink].rot)
        bodyUp = M3.mv(R, floatArrayOf(0f, 0f, 1f))
        bodyFwd = M3.mv(R, floatArrayOf(1f, 0f, 0f))
        fun find(pats: List<String>) = model.motions?.firstOrNull { m -> pats.any { m.name.contains(it) } }
        getupProne = find(listOf("起き上がり（うつ伏せ）", "起きあがり(うつぶせ)", "起き上がり(うつ伏せ)", "起きあがり（うつぶせ）"))
        getupSupine = find(listOf("起き上がり（仰向け）", "起きあがり(仰向け)", "起き上がり(仰向け)", "起きあがり（仰向け）"))
    }

    val hasGetup get() = getupProne != null || getupSupine != null
    val active get() = phase != Phase.PLAYING

    /** 再生を最初からやり直すとき */
    fun reset() { phase = Phase.PLAYING; downFor = 0.0; t = 0.0; tries = 0; motion = null; current = "" }

    /** ルートのリンクの傾き (度) */
    fun tilt(poses: List<FloatArray>): Float {
        val up = M3.mv(BalanceStabilizer.rot3(poses[rootLink]), bodyUp)
        return if (up[2].isFinite()) (acos(up[2].coerceIn(-1f, 1f)) * 180 / Math.PI).toFloat() else 180f
    }

    /** 1 コマごとに呼ぶ. resume: 続きのコマの関節角 (度). 戻り値 null = いつもどおり再生して進める, それ以外 = この関節角をサーボの目標にして,
     *  動作の時間は止める. replace(angles) が呼ばれたら, 呼んだ側で物理を作り直す (置き直す) */
    fun step(sim: PhysicsSim, dt: Double, resume: FloatArray, replace: (FloatArray) -> Unit): FloatArray? {
        val poses = sim.linkPoses()
        val tl = tilt(poses)
        when (phase) {
            Phase.PLAYING -> {
                downFor = if (tl > fallDeg) downFor + dt else 0.0
                if (downFor < fallHold) return null
                falls++; tries = 0
                return startGetup(poses, resume, replace)
            }
            Phase.GETUP -> {
                t += dt
                val m = motion ?: return resume
                val k = (t * m.fps).toInt()
                if (k < m.frames.size) return m.frames[k]
                phase = Phase.SETTLE; t = 0.0
                return m.frames.last()
            }
            Phase.SETTLE -> {
                t += dt
                if (tl < standDeg) {
                    getups++
                    phase = Phase.BLEND; t = 0.0; blendFrom = sim.jointValues()
                    return blendFrom
                }
                if (t < settleTime) return motion?.frames?.lastOrNull() ?: resume
                tries++
                if (tries < maxTries) return startGetup(poses, resume, replace)
                replaces++; replace(resume); phase = Phase.PLAYING; downFor = 0.0; current = ""
                return resume
            }
            Phase.BLEND -> {
                t += dt
                val a = minOf(1.0, t / blendTime).toFloat(); val s = a * a * (3 - 2 * a)
                if (a >= 1f) { phase = Phase.PLAYING; downFor = 0.0; current = ""; return null }
                return FloatArray(minOf(blendFrom.size, resume.size)) { blendFrom[it] + (resume[it] - blendFrom[it]) * s }
            }
        }
    }

    private fun startGetup(poses: List<FloatArray>, resume: FloatArray, replace: (FloatArray) -> Unit): FloatArray {
        val fwd = M3.mv(BalanceStabilizer.rot3(poses[rootLink]), bodyFwd)
        val prone = fwd[2] < 0   // 体の前が下 → うつ伏せ
        motion = if (prone) (getupProne ?: getupSupine) else (getupSupine ?: getupProne)
        val m = motion
        if (m == null || m.frames.isEmpty()) {
            replaces++; replace(resume); phase = Phase.PLAYING; downFor = 0.0; current = ""
            return resume
        }
        current = m.name
        phase = Phase.GETUP; t = 0.0
        return m.frames[0]
    }

    /** 表示用: 「倒れた 2 回・起き上がり 2 回」など */
    val summary: String get() {
        var s = "倒れた $falls 回"
        if (getups > 0) s += "・起き上がり $getups 回"
        if (replaces > 0) s += "・置き直し $replaces 回"
        return s
    }
}
