// BalanceStabilizer.kt : QP + バランスの動作を物理 (PhysicsSim) で再生するときの安定化 (iOS 版 Physics/BalanceStabilizer.swift を移したもの)
//   計画した体 (ルートのリンク) の傾きと, 物理の体の傾きの差を, 床に着いている足の足首の関節で戻す
//   (実機の KHR / KXR のジャイロによる安定化と同じ考え. 足首の軸の向きは物理の今の姿勢から求めるので, ロボットごとの符号によらない)
//   Δq (度) = (kp (a · w) + kd (a · dw/dt)) · 180/π,  a = 足首の関節の軸 (ワールド), w = 物理の体の上向き → 計画の体の上向き の回転ベクトル.
//   着いている足 (contact: bit0 左, bit1 右) の足首の関節 (足のリンクから根元へ回転関節 2 つ) だけ, ±maxDeg で切る.
//   符号と大きさは iOS の qptest で決めた (lafan1 walk1 × KHR: 安定化なし 7.7 秒 → kp = 0.5, kd = 0 で 19.7 秒で倒れる. 試作)
package jp.jsk.eusview

import kotlin.math.asin
import kotlin.math.max
import kotlin.math.min

/** feet: 左・右の足のリンク (GMR の footLink) */
class BalanceStabilizer(val model: RobotModel, feet: List<Int>) {
    val rootLink = model.links.indexOfFirst { it.parent < 0 }.coerceAtLeast(0)
    /** ルートのリンクの座標での「上」(関節角 0 で) */
    private val bodyUp = M3.mv(M3.t(model.links[rootLink].rot), floatArrayOf(0f, 0f, 1f))
    /** 左・右の足の足首の関節 (足のリンクから根元へ 2 つ) */
    val ankles: List<IntArray> = feet.map { f ->
        val out = ArrayList<Int>(); var link = f
        while (out.size < 2 && link >= 0) {
            val k = model.joints.indexOfFirst { it.link == link && !it.linear }
            if (k >= 0) out.add(k)
            link = model.links[link].parent
        }
        out.toIntArray()
    }
    var kp = 0.5f      // 傾きの差 (rad) → 足首 (rad)
    var kd = 0f        // 傾きの差の速さ (rad/s) → 足首 (rad)
    var maxDeg = 20f
    private var prevW: FloatArray? = null

    fun reset() { prevW = null }

    /** targets: 計画の関節角 (度), planRoot: 計画のルートのリンクの姿勢, contact: 床に着いている足 (bit0 左, bit1 右),
     *  poses: 物理のリンクの姿勢 (列優先 4x4, PhysicsSim.linkPoses). 戻り値: 直した関節角 (度) */
    fun adjust(targets: FloatArray, planRoot: Tf, contact: Int, poses: List<FloatArray>, dt: Float): FloatArray {
        val ua = V3.norm(M3.mv(rot3(poses[rootLink]), bodyUp))
        val up = V3.norm(M3.mv(planRoot.r, bodyUp))
        var w = V3.cross(ua, up)
        val s = V3.len(w)
        if (s > 1e-6f) w = V3.scale(w, asin(min(1f, s)) / s)
        val pw = prevW
        val dw = if (pw != null) V3.scale(V3.sub(w, pw), 1f / max(dt, 1e-3f)) else FloatArray(3)
        prevW = w
        val out = targets.copyOf()
        for ((side, js) in ankles.withIndex()) {
            if (contact and (1 shl side) == 0) continue
            for (k in js) {
                val j = model.joints[k]
                val a = V3.norm(M3.mv(rot3(poses[j.link]), j.axis))
                val dq = (kp * V3.dot(a, w) + kd * V3.dot(a, dw)) * 180f / Math.PI.toFloat()
                out[k] += dq.coerceIn(-maxDeg, maxDeg)
            }
        }
        return out
    }

    companion object {
        /** 列優先 4x4 の回転 → 3x3 行優先 */
        fun rot3(m: FloatArray) = FloatArray(9) { val r = it / 3; val c = it % 3; m[c * 4 + r] }
    }
}
