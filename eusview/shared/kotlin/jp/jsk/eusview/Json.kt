// Json.kt : JSON をストリームで読む小さな読み手 (android.util.JsonReader と同じ使い方, Android とデスクトップの両方で使う)
//   ロボットの JSON (数十 MB, 数の配列がほとんど) を速く読むため, 数は 10 進の仮数と指数から直接作る
//   (仮数 < 2^53 かつ |指数| <= 22 なら 1 回の丸めで正確. それ以外は Double.parseDouble)
package jp.jsk.eusview

import java.io.Closeable
import java.io.IOException
import java.io.Reader

enum class JsonToken { BEGIN_ARRAY, END_ARRAY, BEGIN_OBJECT, END_OBJECT, NAME, STRING, NUMBER, BOOLEAN, NULL, END_DOCUMENT }

class JsonReader(private val input: Reader) : Closeable {
    private var buf = CharArray(1 shl 16)
    private var pos = 0
    private var lim = 0
    private var eof = false
    private var stack = IntArray(32)
    private var depth = 0
    private var peeked: JsonToken? = null

    private companion object {
        const val EMPTY_ARRAY = 1; const val NONEMPTY_ARRAY = 2
        const val EMPTY_OBJECT = 3; const val DANGLING_NAME = 4; const val NONEMPTY_OBJECT = 5
        const val EMPTY_DOC = 6; const val NONEMPTY_DOC = 7
        val P10 = DoubleArray(23) { Math.pow(10.0, it.toDouble()) }
    }

    init { push(EMPTY_DOC) }

    private fun push(s: Int) {
        if (depth == stack.size) stack = stack.copyOf(depth * 2)
        stack[depth++] = s
    }

    /** buf に少なくとも n 文字 (ファイルの終わりまで) あるようにする */
    private fun ensure(n: Int): Boolean {
        if (lim - pos >= n) return true
        if (eof) return lim > pos
        if (pos > 0) { System.arraycopy(buf, pos, buf, 0, lim - pos); lim -= pos; pos = 0 }
        if (buf.size < n) buf = buf.copyOf(maxOf(n, buf.size * 2))
        while (lim < n) {
            val r = input.read(buf, lim, buf.size - lim)
            if (r < 0) { eof = true; break }
            lim += r
        }
        return lim > pos
    }

    private fun nextNonWs(): Int {
        while (true) {
            if (pos >= lim && !ensure(1)) return -1
            val c = buf[pos]
            if (c == ' ' || c == '\n' || c == '\r' || c == '\t') pos++ else return c.code
        }
    }

    private fun syntax(msg: String): Nothing = throw IOException("JSON: $msg (位置 $pos)")

    fun peek(): JsonToken {
        peeked?.let { return it }
        when (stack[depth - 1]) {
            EMPTY_ARRAY -> {
                stack[depth - 1] = NONEMPTY_ARRAY
                if (nextNonWs() == ']'.code) { pos++; return set(JsonToken.END_ARRAY) }
            }
            NONEMPTY_ARRAY -> when (nextNonWs()) {
                ']'.code -> { pos++; return set(JsonToken.END_ARRAY) }
                ','.code -> pos++
                else -> syntax("',' か ']' がありません")
            }
            EMPTY_OBJECT, NONEMPTY_OBJECT -> {
                if (stack[depth - 1] == NONEMPTY_OBJECT) when (nextNonWs()) {
                    '}'.code -> { pos++; return set(JsonToken.END_OBJECT) }
                    ','.code -> pos++
                    else -> syntax("',' か '}' がありません")
                }
                val c = nextNonWs()
                if (c == '}'.code && stack[depth - 1] == EMPTY_OBJECT) { pos++; return set(JsonToken.END_OBJECT) }
                if (c != '"'.code) syntax("名前がありません")
                stack[depth - 1] = DANGLING_NAME
                return set(JsonToken.NAME)
            }
            DANGLING_NAME -> {
                if (nextNonWs() != ':'.code) syntax("':' がありません")
                pos++
                stack[depth - 1] = NONEMPTY_OBJECT
            }
            EMPTY_DOC -> stack[depth - 1] = NONEMPTY_DOC
            NONEMPTY_DOC -> {
                if (nextNonWs() == -1) return set(JsonToken.END_DOCUMENT)
                syntax("余分な文字があります")
            }
        }
        return set(when (nextNonWs()) {
            '{'.code -> JsonToken.BEGIN_OBJECT
            '['.code -> JsonToken.BEGIN_ARRAY
            '"'.code -> JsonToken.STRING
            't'.code, 'f'.code -> JsonToken.BOOLEAN
            'n'.code -> JsonToken.NULL
            -1 -> syntax("途中で終わっています")
            else -> JsonToken.NUMBER
        })
    }

    private fun set(t: JsonToken): JsonToken { peeked = t; return t }

    private fun expect(t: JsonToken) { if (peek() != t) syntax("$t ではなく ${peeked}") ; peeked = null }

    fun beginArray() { expect(JsonToken.BEGIN_ARRAY); pos++; push(EMPTY_ARRAY) }
    fun endArray() { expect(JsonToken.END_ARRAY); depth-- }
    fun beginObject() { expect(JsonToken.BEGIN_OBJECT); pos++; push(EMPTY_OBJECT) }
    fun endObject() { expect(JsonToken.END_OBJECT); depth-- }

    fun hasNext(): Boolean { val t = peek(); return t != JsonToken.END_ARRAY && t != JsonToken.END_OBJECT && t != JsonToken.END_DOCUMENT }

    fun nextName(): String { expect(JsonToken.NAME); return readString() }

    fun nextString(): String = when (peek()) {
        JsonToken.STRING -> { peeked = null; readString() }
        JsonToken.NUMBER -> { peeked = null; numberText() }
        else -> syntax("文字列ではありません")
    }

    fun nextBoolean(): Boolean {
        expect(JsonToken.BOOLEAN)
        return if (literal("true")) true else if (literal("false")) false else syntax("true / false ではありません")
    }

    fun nextNull() { expect(JsonToken.NULL); if (!literal("null")) syntax("null ではありません") }

    fun nextDouble(): Double = when (peek()) {
        JsonToken.NUMBER -> { peeked = null; readNumber() }
        JsonToken.STRING -> { peeked = null; readString().trim().toDouble() }
        else -> syntax("数ではありません")
    }

    fun nextLong(): Long {
        val d = nextDouble()
        val l = d.toLong()
        if (l.toDouble() != d) throw NumberFormatException("整数ではありません: $d")
        return l
    }

    fun nextInt(): Int {
        val d = nextDouble()
        val i = d.toInt()
        if (i.toDouble() != d) throw NumberFormatException("整数ではありません: $d")
        return i
    }

    fun skipValue() {
        when (peek()) {
            JsonToken.BEGIN_ARRAY -> { beginArray(); while (hasNext()) skipValue(); endArray() }
            JsonToken.BEGIN_OBJECT -> { beginObject(); while (hasNext()) { nextName(); skipValue() }; endObject() }
            JsonToken.NAME -> { nextName(); skipValue() }
            JsonToken.STRING -> nextString()
            JsonToken.NUMBER -> nextDouble()
            JsonToken.BOOLEAN -> nextBoolean()
            JsonToken.NULL -> nextNull()
            else -> syntax("読み飛ばせません")
        }
    }

    override fun close() { peeked = null; depth = 0; input.close() }

    private fun literal(s: String): Boolean {
        ensure(s.length)
        if (lim - pos < s.length) return false
        for (i in s.indices) if (buf[pos + i] != s[i]) return false
        pos += s.length
        return true
    }

    /** pos は '"' の上 */
    private fun readString(): String {
        pos++
        val sb = StringBuilder()
        while (true) {
            if (pos >= lim && !ensure(1)) syntax("文字列が閉じていません")
            var p = pos
            while (p < lim && buf[p] != '"' && buf[p] != '\\') p++
            sb.append(buf, pos, p - pos)
            pos = p
            if (p >= lim) continue
            if (buf[p] == '"') { pos++; return sb.toString() }
            // エスケープ
            ensure(6)
            pos++
            when (val c = buf[pos++]) {
                'n' -> sb.append('\n'); 't' -> sb.append('\t'); 'r' -> sb.append('\r')
                'b' -> sb.append('\b'); 'f' -> sb.append('\u000c')
                'u' -> { sb.append(String(buf, pos, 4).toInt(16).toChar()); pos += 4 }
                else -> sb.append(c)
            }
        }
    }

    private fun isNumChar(c: Char) = (c in '0'..'9') || c == '-' || c == '+' || c == '.' || c == 'e' || c == 'E'

    private fun numberText(): String {
        ensure(512)
        val s = pos
        while (pos < lim && isNumChar(buf[pos])) pos++
        return String(buf, s, pos - s)
    }

    private fun readNumber(): Double {
        ensure(512)
        val start = pos
        var p = pos
        var neg = false
        if (p < lim && buf[p] == '-') { neg = true; p++ }
        var mant = 0L; var nd = 0; var exp10 = 0; var exact = true; var any = false
        while (p < lim && buf[p] in '0'..'9') {
            any = true
            val d = buf[p] - '0'
            if (nd < 18) { if (mant != 0L || d != 0) { mant = mant * 10 + d; nd++ } } else { exp10++; if (d != 0) exact = false }
            p++
        }
        if (p < lim && buf[p] == '.') {
            p++
            while (p < lim && buf[p] in '0'..'9') {
                any = true
                val d = buf[p] - '0'
                if (nd < 18) { if (mant != 0L || d != 0) { mant = mant * 10 + d; nd++ }; exp10-- } else if (d != 0) exact = false
                p++
            }
        }
        if (p < lim && (buf[p] == 'e' || buf[p] == 'E')) {
            p++
            var eneg = false
            if (p < lim && (buf[p] == '+' || buf[p] == '-')) { eneg = buf[p] == '-'; p++ }
            var e = 0
            while (p < lim && buf[p] in '0'..'9') { if (e < 100000) e = e * 10 + (buf[p] - '0'); p++ }
            exp10 += if (eneg) -e else e
        }
        pos = p
        if (!any) syntax("数ではありません")
        if (exact && mant < (1L shl 53) && exp10 >= -22 && exp10 <= 22) {
            val v = if (exp10 >= 0) mant * P10[exp10] else mant / P10[-exp10]
            return if (neg) -v else v
        }
        return String(buf, start, p - start).toDouble()
    }
}
