// GMR + MPC (倒れないための全身 QP・ZMP の MPC・閉ループ・起き上がり) のスライド生成. 部品は build_eusview.js と同じ
const pptxgen = require("pptxgenjs");
const fs = require("fs");
const path = require("path");
const { applyTheme } = require(process.env.SKILL_DIR + "/scripts/apply_theme.js");

const W = __dirname;
const OUT = process.argv[2] || path.join(W, "gmr_mpc.pptx");
const fig = (f) => path.join(W, "fig", f);

const THEME = {
  name: "MNIST Ink",
  headFontFace: "BIZ UDPGothic",
  bodyFontFace: "BIZ UDPGothic",
  colors: {
    dk1: "14213D", lt1: "FFFFFF", dk2: "2B3A55", lt2: "EEF1F6",
    accent1: "E4572E", accent2: "3A6EA5", accent3: "F2A541",
    accent4: "5B8C5A", accent5: "8E7DBE", accent6: "5B6577",
    hlink: "3A6EA5", folHlink: "8E7DBE",
  },
};
const HEX = THEME.colors;
const MONO = "BIZ UDGothic";

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE"; // 13.333 x 7.5
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
pres.title = "GMR + MPC — BVH の動作をロボットで倒れずに再生する";
pres.author = "Masayuki Inaba";
pres.subject = "GMR retargeting + whole-body QP + ZMP MPC (closed loop) + fall recovery in EusView";
const C = pres.SchemeColor;

// ---------- layouts ----------
const FOOT = "GMR + MPC — BVH の動作を倒れずに再生する";
pres.defineSlideMaster({
  title: "TITLE_DARK",
  background: { color: C.text1 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.8, y: 2.1, w: 11.7, h: 1.6, fontSize: 34, bold: true, color: C.background1, valign: "bottom", align: "left", margin: 0 }, text: "" } },
    { placeholder: { options: { name: "body", type: "body", x: 0.8, y: 3.9, w: 11.7, h: 1.6, fontSize: 18, color: "CADCFC", valign: "top", align: "left", margin: 0 }, text: "" } },
  ],
});
pres.defineSlideMaster({
  title: "SECTION",
  background: { color: C.text1 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 2.6, y: 2.75, w: 10.0, h: 1.0, fontSize: 36, bold: true, color: C.background1, valign: "bottom", align: "left", margin: 0 }, text: "" } },
    { placeholder: { options: { name: "body", type: "body", x: 2.6, y: 3.9, w: 10.0, h: 1.2, fontSize: 16, color: "CADCFC", valign: "top", align: "left", margin: 0 }, text: "" } },
  ],
  slideNumber: { x: 12.3, y: 7.0, w: 0.6, h: 0.3, fontSize: 9, color: "8090B0", align: "right" },
});
pres.defineSlideMaster({
  title: "CONTENT",
  background: { color: C.background1 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 0.3, w: 12.1, h: 0.8, fontSize: 28, bold: true, color: C.text1, valign: "middle", align: "left", margin: 0 }, text: "" } },
    { text: { text: FOOT, options: { x: 0.6, y: 7.02, w: 8, h: 0.3, fontSize: 9, color: C.accent6, margin: 0 } } },
  ],
  slideNumber: { x: 12.1, y: 7.02, w: 0.6, h: 0.3, fontSize: 9, color: C.accent6, align: "right" },
});
pres.defineSlideMaster({
  title: "SHEET",
  background: { color: "0B0F1A" },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.4, y: 0.12, w: 12.5, h: 0.5, fontSize: 18, bold: true, color: C.background1, valign: "middle", align: "left", margin: 0 }, text: "" } },
  ],
  slideNumber: { x: 12.3, y: 7.1, w: 0.6, h: 0.3, fontSize: 9, color: "8090B0", align: "right" },
});

// ---------- helpers ----------
let curSection = null;
function section(title) { pres.addSection({ title }); curSection = title; }
function slide(master, title, notes) {
  const s = pres.addSlide({ masterName: master, sectionTitle: curSection });
  if (title) s.addText(title, { placeholder: "title" });
  if (notes) s.addNotes(notes);
  return s;
}
let objN = 0;
const nm = (p) => `${p}-${++objN}`;
function card(s, x, y, w, h, fill) {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: 0.08, fill: { color: fill || C.background2 }, line: { type: "none" }, objectName: nm("card") });
}
// motif: 「画素タイル」— 角丸の小正方形に番号/記号
function tile(s, x, y, label, fill, size) {
  const z = size || 0.42;
  s.addText(label, { x, y, w: z, h: z, shape: pres.shapes.ROUNDED_RECTANGLE, rectRadius: 0.06, fill: { color: fill || C.text1 }, color: C.background1, fontSize: z > 0.6 ? 28 : 13, bold: true, align: "center", valign: "middle", margin: 0, isTextBox: true, objectName: nm("tile") });
}
function head(s, x, y, w, label, text, fill) {
  tile(s, x, y, label, fill);
  s.addText(text, { x: x + 0.55, y, w: w - 0.55, h: 0.42, fontSize: 17, bold: true, color: C.text1, valign: "middle", margin: 0, isTextBox: true, objectName: nm("head") });
}
function bullets(s, items, x, y, w, h, fs) {
  const arr = items.map((t, i) => {
    const o = { bullet: true, breakLine: i < items.length - 1, paraSpaceAfter: 5 };
    if (Array.isArray(t)) return { text: t[0], options: Object.assign(o, { bullet: { indent: 18 }, indentLevel: 1, fontSize: (fs || 14) - 1, color: C.accent6 }) };
    return { text: t, options: o };
  });
  s.addText(arr, { x, y, w, h, fontSize: fs || 14, color: C.text1, valign: "top", margin: 0, isTextBox: true, objectName: nm("bullets") });
}
function para(s, text, x, y, w, h, opts) {
  s.addText(text, Object.assign({ x, y, w, h, fontSize: 14, color: C.text1, valign: "top", margin: 0, isTextBox: true, objectName: nm("text") }, opts || {}));
}
function code(s, text, x, y, w, h, fs) {
  s.addText(text, { x, y, w, h, shape: pres.shapes.ROUNDED_RECTANGLE, rectRadius: 0.06, fill: { color: "1B2433" }, color: "E8ECF3", fontFace: MONO, fontSize: fs || 11, valign: "top", margin: 0.15, isTextBox: true, objectName: nm("code") });
}
function stat(s, x, y, w, big, small, color) {
  s.addText(big, { x, y, w, h: 0.9, fontSize: 40, bold: true, color: color || C.accent1, margin: 0, valign: "bottom", isTextBox: true, objectName: nm("stat") });
  s.addText(small, { x, y: y + 0.95, w, h: 0.6, fontSize: 12, color: C.accent6, margin: 0, valign: "top", isTextBox: true, objectName: nm("statlbl") });
}
function table(s, rows, x, y, w, colW, fs, opt) {
  const hdr = rows[0].map((t) => ({ text: t, options: { bold: true, color: HEX.lt1, fill: { color: HEX.dk1 } } }));
  const body = rows.slice(1).map((r, i) => r.map((t) => {
    if (t && typeof t === "object") return t;
    return { text: String(t), options: { fill: { color: i % 2 ? HEX.lt1 : HEX.lt2 } } };
  }));
  s.addTable([hdr, ...body], Object.assign({ x, y, w, colW, fontSize: fs || 12, color: HEX.dk1, border: { type: "solid", pt: 0.5, color: "D5DAE3" }, margin: [3, 6, 3, 6], valign: "middle", objectName: nm("table") }, opt || {}));
}
const hl = (t) => ({ text: String(t), options: { bold: true, color: HEX.accent1, fill: { color: "FDECE7" } } });
const chartBase = () => ({
  catAxisLabelColor: HEX.accent6, valAxisLabelColor: HEX.accent6, catAxisLabelFontFace: "+mn-lt", valAxisLabelFontFace: "+mn-lt",
  catAxisLabelFontSize: 11, valAxisLabelFontSize: 11, valGridLine: { color: "E2E6EE", size: 0.5 }, catGridLine: { style: "none" },
  titleFontFace: "+mn-lt", legendFontFace: "+mn-lt", dataLabelFontFace: "+mn-lt", titleColor: HEX.dk1, titleFontSize: 13,
});
const fmt = (x, d) => Number(x).toFixed(d);
const pct = (x, d) => (x * 100).toFixed(d === undefined ? 2 : d) + "%";


// ---- EusView のスライド本体 ----
const MED = path.join(W, "eusview_media");
const MEDIA = fs.existsSync(path.join(MED, "media.json")) ? JSON.parse(fs.readFileSync(path.join(MED, "media.json"))) : [];
const mediaOf = (n) => (Array.isArray(MEDIA) ? MEDIA : MEDIA.videos || []).find((m) => m.name === n) || {};
function pngSize(p) { const b = fs.readFileSync(p); return [b.readUInt32BE(16), b.readUInt32BE(20)]; }
/** 動画を枠 (x, y, w, h) に縦横比を保って置き, 下に説明を付ける. 動画がまだなければ枠だけ */
function video(s, name, x, y, w, h, opt) {
  const o = opt || {};
  const mp4 = path.join(MED, name + ".mp4"), png = path.join(MED, name + ".png");
  const capH = o.noCaption ? 0 : 0.5;
  const bh = h - capH;
  if (fs.existsSync(mp4) && fs.existsSync(png)) {
    const [pw, ph] = pngSize(png);
    let vw = w, vh = (w * ph) / pw;
    if (vh > bh) { vh = bh; vw = (bh * pw) / ph; }
    const vx = x + (w - vw) / 2;
    s.addMedia({ type: "video", path: mp4, cover: "data:image/png;base64," + fs.readFileSync(png).toString("base64"), x: vx, y, w: vw, h: vh, objectName: nm("video-" + name) });
    if (!o.noCaption) para(s, o.caption || mediaOf(name).caption_ja || mediaOf(name).title_ja || "", x, y + vh + 0.06, w, capH - 0.06, { fontSize: 11, color: C.accent6 });
  } else {
    s.addText(`動画: ${name}（作成中）`, { x, y, w, h: bh, shape: pres.shapes.ROUNDED_RECTANGLE, rectRadius: 0.06, fill: { color: "1B2433" }, color: "8FA3C8", fontSize: 14, align: "center", valign: "middle", isTextBox: true, objectName: nm("video-missing") });
  }
}
const SHOTS = path.join(MED, "shots");
const SHOTJ = fs.existsSync(path.join(SHOTS, "shots.json")) ? JSON.parse(fs.readFileSync(path.join(SHOTS, "shots.json"))) : [];
const shotOf = (n) => (Array.isArray(SHOTJ) ? SHOTJ : SHOTJ.shots || []).find((m) => m.name === n) || {};
/** 画面の画像を枠に縦横比を保って置く（なければ枠だけ）。下に説明 */
function shot(s, name, x, y, w, h, opt) {
  const o = opt || {};
  const capH = o.noCaption ? 0 : 0.42;
  const bh = h - capH;
  const f = ["png", "jpg"].map((e) => path.join(SHOTS, `${name}.${e}`)).find((f) => fs.existsSync(f));
  if (f) {
    let pw = 16, ph = 9;
    if (f.endsWith(".png")) [pw, ph] = pngSize(f);
    let vw = w, vh = (w * ph) / pw;
    if (vh > bh) { vh = bh; vw = (bh * pw) / ph; }
    const vx = x + (w - vw) / 2;
    s.addImage({ path: f, x: vx, y, w: vw, h: vh, objectName: nm("shot-" + name) });
    if (!o.noCaption) para(s, o.caption || shotOf(name).caption_ja || shotOf(name).title_ja || "", x, y + vh + 0.05, w, capH - 0.05, { fontSize: 10.5, color: C.accent6, align: "center" });
  } else {
    s.addText(`画面: ${name}（準備中）`, { x, y, w, h: bh, shape: pres.shapes.ROUNDED_RECTANGLE, rectRadius: 0.06, fill: { color: HEX.lt2 }, color: HEX.accent6, fontSize: 12, align: "center", valign: "middle", isTextBox: true, objectName: nm("shot-missing") });
  }
}
const box = (s, x, y, w, h, t, sub, fill, tc, fs1) => s.addText([{ text: t, options: { bold: true, fontSize: fs1 || 14, breakLine: true } }, { text: sub, options: { fontSize: 11 } }],
  { x, y, w, h, shape: pres.shapes.ROUNDED_RECTANGLE, rectRadius: 0.08, fill: { color: fill }, color: tc || C.text1, valign: "middle", margin: 0.1, isTextBox: true, objectName: nm("box") });
const arrow = (s, x1, y1, x2, y2) => s.addShape(pres.shapes.LINE, { x: x1, y: y1, w: x2 - x1 || 0.001, h: y2 - y1 || 0.001, flipV: y2 < y1, line: { color: HEX.accent6, width: 1.5, endArrowType: "triangle" }, objectName: nm("arrow") });

// =====================================================================// =====================================================================
section("タイトル");
{
  const s = slide("TITLE_DARK", "GMR + MPC — BVH の動作をロボットで倒れずに再生する");
  s.addText([
    { text: "人の動き（lafan1）を KXR・KHR に移し（GMR）、全身 QP・ZMP の MPC・閉ループの MPC・足首の安定化・起き上がりで、物理（ODE）の中で倒れないようにする試み", options: { breakLine: true } },
    { text: "数値はすべて Mac（Intel）の qptest と、アプリ（Android・デスクトップ）で測ったもの。2026-10-06", options: { fontSize: 13, color: "8FA3C8" } },
  ], { placeholder: "body" });
}
{
  const s = slide("CONTENT", "結論", "倒れるまでの時間は、関節角をサーボの目標にして ODE で再生し、腰（ルートのリンク）の上向きが 60° より傾いた時刻。lafan1 の 77 本 × 2 体（最後まで, 1 本 2〜4 分）と、30 秒までの比べ。");
  stat(s, 0.6, 1.3, 3.0, "4〜5%", "GMR+MPC で lafan1 の動作の何割の所で倒れるか（中央値, 77 本 × KXR・KHR, 最後まで倒れないのは 0 本）", C.accent1);
  stat(s, 3.75, 1.3, 2.9, "19.7 秒", "walk1 × KHR の倒れるまで: GMR+QP 6.8 秒 → QP+バランス 19.7 秒（30 秒まで）", C.accent2);
  stat(s, 6.8, 1.3, 2.9, "倒れない", "aiming1（立って狙う）× KHR: GMR+QP・QP+バランスとも 30 秒", C.accent4);
  stat(s, 9.85, 1.3, 2.9, "38 / 39 回", "walk1 × KHR で倒れて起き上がれた回数（GMR+MPC, 60 秒ぶん）", C.accent5);
  bullets(s, [
    "立って腕を動かす動き（aiming）は、静的な重心の制約と左右の股の誤判定の修正だけで倒れなくなった",
    "歩く・走るは、計画（QP + ZMP の MPC）でも閉ループの MPC でも 20 秒以内に倒れる。人の歩く速さは小さなロボットには速すぎ、足の置き場所を変えない限り立て直せない",
    "倒れたら起き上がりの動作（RCB4）で立ち、倒れたコマから続ける。KHR はほぼ毎回起き上がれる。KXR は起き上がれず置き直しになることが多い",
    "キャプチャポイントで着地をずらし、MPC の出力をなめらかにすると walk1 × KHR は 26.6 秒まで立つ（30 秒まで）。まだ倒れる",
  ], 0.6, 3.45, 12.15, 3.4, 14);
}

// =====================================================================
section("1. 方法");
{
  const s = slide("SECTION", "1. 3 つの方法");
  s.addText("GMR + QP（開ループ）、QP + バランス（動作全体を先に見て計画）、GMR + MPC（物理の今の状態から毎コマ計画し直す）", { placeholder: "body" });
  tile(s, 0.9, 2.75, "1", C.accent2, 1.2);
}
{
  const s = slide("CONTENT", "3 つの方法と、倒れないための制約", "どれも同じ C++ の全身 QP（wbqp.cpp, Goldfarb–Idnani）を iPhone・Mac・Android・デスクトップで使う。BVH の画面のボタン「GMR+QP」「QP+バランス」「物理で比べる」。");
  table(s, [["", "GMR + QP", "QP + バランス", "GMR + MPC（閉ループ）"],
    ["いつ解く", "コマごと（前から順に）", "動作全体を先に計画 → コマごと", "再生中に毎コマ（物理の今の状態から）"],
    ["倒れない制約", "重心の床への投影が支持多角形の中（静的, 緩めの重み 1e6）", "ZMP が支持多角形の中（MPC, 1.5 秒先まで）。その重心を最優先（1e8）", "同じ MPC を、測った重心・速さから解き直す"],
    ["接地", "参照の足が低ければ着く", "一歩ずつ。両足が浮かない。両足で支える時間 4 コマ", "計画の接地。着いた足は今の場所"],
    ["足の振り出し", "参照どおり", "水平にして 0.06 L 持ち上げる", "計画（座標を合わせて）"],
    ["再生", "関節角をそのまま", "足首の安定化（傾きの差を戻す）", "MPC の答えの関節角"],
    ["倒れたら", hl("起き上がって倒れたコマから続ける（3 つとも同じ FallRecovery）"), "", ""]],
    0.6, 1.3, 12.15, [1.7, 3.3, 3.6, 3.55], 11.5, { rowH: 0.62 });
  bullets(s, ["L = 脚の長さ（KXR 0.212 m, KHR 0.296 m）。位置・余裕は L で割って、ロボットの大きさによらない値にする"], 0.6, 6.25, 12.15, 0.6, 12);
}
{
  const s = slide("CONTENT", "QP + バランス — 動作全体を先に見て計画する（wbqp_plan_balance）", "API: wbqp_plan_balance(h, n, q_ref, root_ref, contact, support, com_out) → コマごとに wbqp_set_com_target(&com_out[i*5]) → wbqp_solve。");
  const steps = [
    ["1", "接地を一歩ずつ", "着いた足は、参照の足が 0.2 L 離れる・20° 回る・0.12 L 上がるときだけ離す。もう片足が 4 コマ以上着いているときだけ（両足は浮かない）。6 コマ以上たって参照の足が低くなったら着く"],
    ["2", "一度解いて集める", "今の QP（静的な重心）で全部のコマを解き、重心の参照と、着いた足の位置（支持多角形）を集める"],
    ["3", "重心の軌道（ZMP の MPC）", "1.5 秒先まで見て、ZMP が支持多角形（0.06 L 内側）に入る重心の軌道を決める（次のスライド）"],
    ["4", "重心を最優先に解く", "|重心 − 計画| ≤ 0.005 L を緩めの重み 1e8（衝突などは 1e6）。静的な重心の制約は外す"],
    ["5", "振り出す足", "水平にし、足の裏の高さ = max(参照, 0.06 L · sin(π 位相)) に。重み 15（ふだんは 3）"],
    ["6", "移動を縮める", "水平の移動を 0.5 倍に（人の歩く速さは小さなロボットには速い。参照より遅れて進む）"],
  ];
  steps.forEach(([n, t, d], i) => {
    const y = 1.3 + i * 0.93;
    tile(s, 0.6, y + 0.08, n, [C.accent1, C.accent2, C.accent3, C.accent4, C.accent5, C.accent6][i]);
    para(s, [{ text: t, options: { bold: true, fontSize: 14, breakLine: true } }, { text: d, options: { fontSize: 12, color: C.accent6 } }], 1.2, y, 11.55, 0.88);
  });
}
{
  const s = slide("CONTENT", "ZMP の MPC（台車の模型）", "コードは wbqp.cpp の comMpc（自前, C++17 の標準ライブラリだけ）。QP は全身 QP と同じ Goldfarb–Idnani 法。変数 45 個（躍度 x・y 15 ブロック + 緩め 15）。");
  code(s, [
    "状態（x, y ごと）  s = (c, c', c'')    1 コマ dt = 1/30 秒",
    "                   s+ = A s + B u      u = 躍度（3 コマのブロックごとに一定）",
    "先読み             15 ブロック = 45 コマ = 1.5 秒",
    "",
    "ZMP                p = c − (z_c / g) c''      z_c = 計画の重心の高さ",
    "",
    "最小化   Σ_k |c_k − c_ref,k|² / L²  +  w_v Σ_k |c'_k − c'_ref,k|²",
    "         +  w_j Σ_b |u_b|²  +  w_s Σ_b s_b²",
    "制約     m_eᵀ p_b ≤ b_e − margin + s_b    （支持多角形の各辺 e, ブロックの終わり b）",
    "         s_b ≥ 0",
    "",
    "w_v = 1e-3,  w_j = 1e-6,  w_s = 1e6,  margin = min(0.06 L, 内接半径の 6 割)",
    "毎コマ解いて, 初めのブロックの躍度で 1 コマだけ進める（後退ホライズン）",
  ].join("\n"), 0.6, 1.3, 7.6, 4.6, 11.5);
  bullets(s, [
    "支持多角形は、計画（手順 2）で着いた足の裏の凸包。片足を上げる前に重心を残る足へ移す",
    "緩めは解けないときだけ使う。walk1 × KHR では 7840 コマのうち 853 コマで緩めた（ZMP が外に出る計画）",
    "台車の模型なので、腕や胴を速く回す角運動量は入っていない",
    "計算: QP+バランス全体（計画 + コマごとの QP）で 1.7〜2.9 ms/コマ（Mac, qptest）。Pixel 7a は 7,000〜8,000 コマを 20 秒以内",
  ], 8.45, 1.3, 4.3, 5.6, 12);
}
{
  const s = slide("CONTENT", "GMR + MPC — 閉ループ（wbqp_mpc_step）", "物理（ODE）の今の関節角とルートの姿勢を入れると、次のコマのサーボの目標を返す。実機ならエンコーダと IMU の値を入れる。");
  box(s, 0.6, 1.4, 2.6, 1.2, "測る", "物理の関節角・ルートの姿勢\n→ 重心, 速さ（差分をならす）", C.background2);
  box(s, 3.55, 1.4, 2.8, 1.2, "座標を合わせる", "着いた足の 今 と 計画 の\n位置・向き → ヨー + 平行移動", C.accent3, C.text1);
  box(s, 6.7, 1.4, 2.8, 1.2, "MPC", "今の重心・速さから ZMP の MPC\n→ 0.05 秒先の重心を狙う", C.accent2, C.background1);
  box(s, 9.85, 1.4, 2.9, 1.2, "全身 QP", "着いた足はその場, 浮いた足と\n手は計画, 重心を最優先", C.accent4, C.background1);
  arrow(s, 3.2, 2.0, 3.55, 2.0); arrow(s, 6.35, 2.0, 6.7, 2.0); arrow(s, 9.5, 2.0, 9.85, 2.0);
  code(s, [
    "int wbqp_mpc_step(WbQP *h, int i,",
    "                  const double *q_meas, const double root_meas[12],",
    "                  const double *q_plan, const double root_plan[12],",
    "                  double *q_out, double info[8]);",
    "// 先に wbqp_plan_balance で計画を作っておく",
    "// info: 今の重心, 狙う重心, ずれ, ZMP の緩め, MPC の状態",
  ].join("\n"), 0.6, 2.95, 6.6, 1.95, 11);
  bullets(s, [
    "初めの版は平行移動だけで合わせていた。物理は機体の正面、計画はモーションキャプチャの向きから始まるので、計画の重心・支持多角形が違う向きに置かれていた → 向きも合わせた",
    "サーボ（速度 = kp ×（目標 − 今）, kp 10〜30）は 30〜100 ms 遅れるので、0.05 秒先の重心を狙う（mpc_lead）",
    "足の置き場所は計画のまま（変えない）。押されて重心が足から出たときに、踏み出して立て直すことはできない",
  ], 7.45, 2.95, 5.3, 3.95, 12);
  para(s, "結果（30 秒まで）: aiming1 × KXR は倒れない（GMR は 5.1 秒）。aiming1 × KHR 24.4 秒、walk1 × KHR 6.7 秒、walk1 × KXR 6.5 秒で倒れる。", 0.6, 5.1, 6.6, 1.0, { fontSize: 12.5, color: C.accent1 });
}
{
  const s = slide("CONTENT", "キャプチャポイントで足の置き場所を変える", "wbqp_mpc_step の中. ω = √(g / z), z = 今の重心の高さ。パラメータ: cp_gain 1, cp_max 0.3 L, cp_filter 0.5, mpc_dq_max 0.06 rad, mpc_smooth 0.7。");
  code(s, [
    "キャプチャポイント   ξ = c + c' / ω          （止まるために足を置く点）",
    "ずれ                 e = ξ_今 − ξ_計画",
    "着地のずらし         Δ = cp_gain · e · e^{ω T}   T = 着地までの時間",
    "                     |Δ| ≤ cp_max · L,  前の値となめらかに",
    "振り出し中の足       目標 = 計画 + (離したときのずらし → Δ) を位相で",
    "MPC の支持多角形     ずらした足の裏で作り直し, 重心の参照もずらす",
  ].join("\n"), 0.6, 1.3, 7.4, 1.75, 11.5);
  bullets(s, [
    "初めの版は、両足の平均で計画と物理の座標を合わせていた。足がずらした目標まで届かないと、その差が座標合わせに入り「ずれ → さらにずらす」が繰り返された（ずれ 0.1〜0.2 m, ずらしが上限に張り付く）",
    "→ 座標は先に着いていた 1 本の足で合わせ、もう片方は実際に着いた位置をずらしとして覚える",
    "毎コマ今の姿勢から解くので、脚の関節の目標が 1 コマで 10〜26° 振動していた → 1 コマ 0.06 rad まで、前の目標から 3 割ずつ近づける",
    "踏み出す予定のない両足立ちのときは、足の置き場所を変えない（押されたときの踏み出しはまだ）",
  ], 0.6, 3.25, 7.4, 3.65, 12);
  table(s, [["30 秒まで", "MPC", "+ キャプチャ", "+ なめらか", "+ 移動 0.25"],
    ["walk1 × KHR", "6.3 秒", "7.4 秒", "15.0 秒", hl("26.6 秒")],
    ["aiming1 × KHR", "24.3 秒", hl("倒れない"), "20.5 秒", "20.8 秒"],
    ["walk1 × KXR", "6.0 秒", "6.4 秒", "6.8 秒", "9.2 秒"],
    ["aiming1 × KXR", hl("倒れない"), hl("倒れない"), "23.4 秒", hl("倒れない")]],
    8.2, 1.3, 4.55, [1.35, 0.75, 0.85, 0.8, 0.8], 10.5, { rowH: 0.48 });
  bullets(s, [
    "左から順に足していったもの（qptest, Mac）",
    "設定を少し変えるだけで倒れる時刻が大きく変わる（歩行はまだ安定していない）",
    "4 本の合計（30 秒で打ち切り）は 「+ 移動 0.25」が最長（86.6 秒 / 120 秒）",
  ], 8.2, 3.95, 4.55, 2.95, 11.5);
}
{
  const s = slide("CONTENT", "足首の安定化と、起き上がり", "BalanceStabilizer（Swift / Kotlin）と FallRecovery（Swift / Kotlin）。どちらもロボットの関節の名前によらない作り。");
  head(s, 0.6, 1.3, 6.0, "A", "足首の安定化（QP + バランスの再生）", C.accent2);
  bullets(s, [
    "w = 物理の体の上向き → 計画の体の上向き の回転ベクトル",
    "着いている足の足首の関節（足のリンクから根元へ回転関節 2 つ）を Δq = 0.5 (a · w) 回す（a = 関節の軸, 物理の今の姿勢から）",
    "±20° で切る。実機のジャイロの安定化と同じ考え",
    "walk1 × KHR: 安定化なし 7.7 秒 → あり 19.7 秒で倒れる（qptest）。Kotlin では 7.7 → 20.0 秒",
    "符号を逆（−0.5）にすると 6 秒前後で倒れる",
  ], 0.6, 1.8, 6.0, 4.0, 12);
  head(s, 6.85, 1.3, 5.9, "B", "倒れたら起き上がって続ける", C.accent5);
  bullets(s, [
    "腰の上向きが 60° より 0.3 秒傾いたら倒れた → 動作の時間を止める",
    "体の前が下ならうつ伏せ、上なら仰向けの起き上がりの動作（RCB4 のプロジェクト, ロボットの JSON の動作）をサーボの目標に",
    "終わってから 1 秒以内に傾き 25° 未満なら、0.6 秒かけて倒れたコマの姿勢へ移り、そこから続ける。立てなければもう一度（2 回まで）、だめなら置き直す",
    "起き上がりの動作がある: KXR 27 / 36 体, KHR 43 / 43 体（ないロボットは置き直す）",
  ], 6.85, 1.8, 5.9, 4.0, 12);
  para(s, "名前の例: KHR「HLO014_起きあがり(うつぶせ)」「HLO015_起きあがり(仰向け)」, KXR「XL2G_116_起き上がり（うつ伏せ）」「XL2G_115_起き上がり（仰向け）」", 0.6, 6.2, 12.15, 0.6, { fontSize: 11.5, color: C.accent6 });
}

// =====================================================================
section("2. 結果");
{
  const s = slide("SECTION", "2. 物理（ODE）で倒れるか");
  s.addText("Mac の qptest（アプリと同じ Swift・C++ のコード）。関節角をサーボの目標にして 1 コマ 1/30 秒で進める", { placeholder: "body" });
  tile(s, 0.9, 2.75, "2", C.accent4, 1.2);
}
{
  const s = slide("CONTENT", "30 秒まで — 倒れるまでの時間", "「倒れない」は 30 秒まで立っていた。初めのコマの姿勢で 0.5 秒置いてから再生。アプリの既定のサーボ（eusdyna と同じ, kp 10〜30, 力の上限 5e5）。");
  table(s, [["BVH × ロボット", "GMR", "GMR + QP", "QP + バランス", "GMR + MPC"],
    ["aiming1 × KHR（khr20h2）", "19.0 秒", hl("倒れない"), hl("倒れない"), "24.4 秒"],
    ["aiming1 × KXR（kxrl2l6a6h2）", "5.1 秒", hl("倒れない"), "24.5 秒", hl("倒れない")],
    ["walk1 × KHR", "5.3 秒", "6.8 秒", hl("19.7 秒"), "6.7 秒"],
    ["walk1 × KXR", "5.0 秒", "6.5 秒", "7.0 秒", "6.5 秒"]],
    0.6, 1.3, 7.4, [2.6, 1.1, 1.2, 1.3, 1.2], 12, { rowH: 0.5 });
  s.addChart(pres.charts.BAR, [
    { name: "GMR", labels: ["aiming1 KHR", "aiming1 KXR", "walk1 KHR", "walk1 KXR"], values: [19.0, 5.1, 5.3, 5.0] },
    { name: "GMR+QP", labels: ["aiming1 KHR", "aiming1 KXR", "walk1 KHR", "walk1 KXR"], values: [30, 30, 6.8, 6.5] },
    { name: "QP+バランス", labels: ["aiming1 KHR", "aiming1 KXR", "walk1 KHR", "walk1 KXR"], values: [30, 24.5, 19.7, 7.0] },
    { name: "GMR+MPC", labels: ["aiming1 KHR", "aiming1 KXR", "walk1 KHR", "walk1 KXR"], values: [24.4, 30, 6.7, 6.5] },
  ], Object.assign(chartBase(), { x: 8.2, y: 1.2, w: 4.6, h: 3.6, barDir: "col", barGrouping: "clustered", chartColors: [HEX.accent6, HEX.accent2, HEX.accent4, HEX.accent5],
    showLegend: true, legendPos: "b", legendFontSize: 10, valAxisMaxVal: 30, valAxisTitle: "倒れるまで（秒, 30 = 倒れない）", showValAxisTitle: true, valAxisTitleFontSize: 10, catAxisLabelFontSize: 10, objectName: nm("chart") }));
  bullets(s, [
    "Android・デスクトップ（Kotlin + JNI）でも同じ値: walk1 × KHR の GMR+QP 6.8 秒、QP+バランス 20.0 秒、aiming1 は 2 つとも倒れない",
    "KXR の GMR+QP は、初めは再生してすぐ倒れていた。左右の股のカプセルが太めで「当たっている」と判定され、脚を開いてしゃがむ答えになっていた → 標準の姿勢で 0.03 L より近い組は調べない（exclude_dist）",
    "lafan1 を最後まで（1 本 2〜4 分）: GMR・GMR+QP とも 77 本 × 2 体 すべて倒れる（倒れるまでの中央値 KHR: GMR 5.6 秒, GMR+QP 8.0 秒）",
  ], 0.6, 4.05, 7.4, 2.85, 12);
}
{
  const s = slide("CONTENT", "起き上がりつき — walk1 の 60 秒ぶん（1800 コマ）", "倒れたら起き上がって倒れたコマから続ける（FallRecovery）。時間の上限 240 秒の間にどこまで再生できたか。");
  table(s, [["ロボット × 方法", "倒れた", "起き上がり", "置き直し", "再生できたコマ（240 秒で）"],
    ["KHR × GMR + QP", "29 回", "28 回", "1 回", "1261 / 1800"],
    ["KHR × QP + バランス", "37 回", "37 回", "0", "1661 / 1800"],
    ["KHR × GMR + MPC", "39 回", hl("38 回"), "0", hl("1726 / 1800")],
    ["KXR × GMR + QP", "32 回", "18 回", "13 回", "1297 / 1800"],
    ["KXR × QP + バランス", "26 回", "4 回", "21 回", "1507 / 1800"],
    ["KXR × GMR + MPC", "30 回", "11 回", "18 回", "1222 / 1800"]],
    0.6, 1.3, 8.0, [2.6, 1.0, 1.2, 1.1, 2.1], 12, { rowH: 0.5 });
  bullets(s, [
    "KHR はほぼ毎回、起き上がりの動作で立てる",
    "KXR は起き上がりの動作のあと 25° 未満にならないことが多く、置き直しになる",
    "続きを再生するとまたすぐ倒れる（同じコマから同じ速い動き）。起き上がりは「倒れたまま進む」のをなくすが、倒れにくくはしない",
  ], 8.85, 1.3, 3.9, 5.6, 12.5);
}
{
  const s = slide("CONTENT", "アプリの画面 — 物理で比べる", "BVH の画面: 「QP+バランス」で 5 体目、「物理で比べる」で GMR+QP と QP+バランスを物理で並べて動かし「x.x 秒で倒れた」「立っている」を出す。");
  shot(s, "desk_balance_walk", 0.6, 1.3, 5.95, 5.6);
  shot(s, "desk_recover", 6.8, 1.3, 5.95, 5.6, { caption: "物理 24.7 秒: 2 体とも倒れたあと起き上がりの動作で立ち、倒れたコマから walk1 を続けている（GMR+QP 倒れた 2 回・起き上がり 2 回, QP+バランス 1 回・1 回）" });
}
{
  const s = slide("CONTENT", "アプリの画面 — iPhone と Android", "iPhone はシミュレータ（iPhone 16 Pro, Release）、Android は Pixel 7a（release 版）。倒れるまでの時間は Mac の qptest と同じ（walk1 × KHR: GMR+QP 6.8 秒, QP+バランス 19.7 秒。Pixel は 20.5 秒）。");
  shot(s, "sim_balance_aiming", 0.6, 1.3, 2.9, 5.6, { caption: "iPhone: aiming1, 30.7 秒で 2 体とも立っている" });
  shot(s, "sim_balance_walk", 3.65, 1.3, 2.9, 5.6, { caption: "iPhone: walk1, GMR+QP は 6.8 秒で倒れて起き上がり中" });
  shot(s, "sim_recover", 6.7, 1.3, 2.9, 5.6, { caption: "iPhone: 47 秒, 4 回倒れて 4 回起き上がり続きを再生" });
  shot(s, "and_balance", 9.85, 1.3, 2.9, 5.6, { caption: "Pixel 7a: 22.1 秒, GMR+QP は 2 回倒れて 2 回起き上がり" });
}

{
  const s = slide("CONTENT", "アプリの画面 — GMR+MPC も物理で比べる", "BVH の画面の「物理で比べる」が 3 体（GMR+QP・QP+バランス・GMR+MPC）。GMR+MPC は毎コマ物理の今の状態から wbqp_mpc_step。起動の引数 -method mpc -bvhphysics 1。");
  shot(s, "desk_mpc_walk", 0.6, 1.3, 5.6, 4.0, { caption: "デスクトップ: walk1 × khr20h2, 物理 19.8 秒。GMR+QP 6.8 秒・GMR+MPC 8.9 秒で倒れて起き上がり、QP+バランスは立っている" });
  shot(s, "sim_mpc_walk", 6.4, 1.3, 2.9, 5.6, { caption: "iPhone: 13.7 秒, GMR+QP は起き上がり中" });
  shot(s, "and_mpc_walk", 9.85, 1.3, 2.9, 5.6, { caption: "Pixel 7a: 24.4 秒, GMR+MPC 8.9 秒" });
  table(s, [["walk1 × KHR", "GMR+QP", "QP+バランス", "GMR+MPC"],
    ["iPhone（Swift）・qptest", "6.8 秒", "19.7 秒", "15.0 秒"],
    ["Android・デスクトップ", "6.8 秒", "20.0 秒", hl("8.9 秒")]],
    0.6, 5.3, 5.6, [2.3, 1.0, 1.15, 1.15], 10.5, { rowH: 0.33 });
  para(s, "Kotlin と Swift の MPC の目標は 150 コマまで 0.0003° 以内で一致し、209 コマで 0.1°, 260 コマで 10° と離れる（物理の小さな差が広がる）。aiming1 は両方 20.5 秒。", 0.6, 6.4, 5.6, 0.55, { fontSize: 9.5, color: C.accent6 });
}

// =====================================================================
section("3. 全体の何割で倒れるか");
// 計測: logs/mpc_full_<ロボット>.json (qptest -physics 1 -mpc 1 -stopatfall 1 -maxsec 100000, lafan1 の 77 本を最後まで)
const FULL = {};
for (const rb of ["khr20h2", "kxrl2l6a6h2"]) {
  const f = path.join(W, "logs", `mpc_full_${rb}.json`);
  if (fs.existsSync(f)) FULL[rb] = JSON.parse(fs.readFileSync(f));
}
const METH = [["gmr", "GMR"], ["qp", "GMR+QP"], ["bal", "QP+バランス"], ["mpc", "GMR+MPC"]];
const HAND = ["fallAndGetUp", "ground", "pushAndFall"];
const kindOf = (a) => a.file.replace(/^lafan1\//, "").replace(/\d.*$/, "");
const durOf = (a) => a.frames / a.fps;
const fallOf = (a, k) => { const t = a["phys_fall_" + k]; return t < 0 ? durOf(a) : t; };
const fracOf = (a, k) => fallOf(a, k) / durOf(a);
const median = (v) => { const s = [...v].sort((x, y) => x - y); const n = s.length; return n ? (n % 2 ? s[(n - 1) / 2] : (s[n / 2 - 1] + s[n / 2]) / 2) : 0; };
const pc = (x) => (x * 100).toFixed(1) + "%";
if (FULL.khr20h2 && FULL.kxrl2l6a6h2) {
  {
    const s = slide("SECTION", "3. 全体の何割で倒れるか");
    s.addText("lafan1 の 77 本（1 本 1.7〜5 分）を最後まで再生し、初めて倒れた時刻 ÷ 動作の長さ。KHR（khr20h2）と KXR（kxrl2l6a6h2）", { placeholder: "body" });
    tile(s, 0.9, 2.75, "3", C.accent5, 1.2);
  }
  {
    const s = slide("CONTENT", "倒れるまでの割合 — 4 つの方法", "倒れた = 腰の上向きが 60° より傾いた（参照が立っているとき）。倒れたら物理を止めて測った（-stopatfall 1）。起き上がりなし。");
    const rows = [["ロボット × 方法", "倒れるまで（中央値）", "割合（中央値）", "割合（最大）", "10% より後", "25% より後", "最後まで"]];
    for (const [rb, rn] of [["khr20h2", "KHR"], ["kxrl2l6a6h2", "KXR"]]) {
      for (const [k, kn] of METH) {
        const r = FULL[rb];
        const fr = r.map((a) => fracOf(a, k));
        const cell = (t) => (k === "mpc" ? hl(t) : t);
        rows.push([cell(`${rn} × ${kn}`), cell(median(r.map((a) => fallOf(a, k))).toFixed(1) + " 秒"), cell(pc(median(fr))), cell(pc(Math.max(...fr))),
          cell(fr.filter((x) => x > 0.1).length + " 本"), cell(fr.filter((x) => x > 0.25).length + " 本"), cell(fr.filter((x) => x >= 1).length + " 本")]);
      }
    }
    table(s, rows, 0.6, 1.3, 7.6, [2.2, 1.25, 1.0, 0.85, 0.8, 0.8, 0.7], 10.5, { rowH: 0.39 });
    // 割合の分布 (GMR+MPC, 本数)
    const binsL = ["〜5%", "5〜10%", "10〜25%", "25〜50%", "50%〜", "最後まで"];
    const binOf = (x) => (x >= 1 ? 5 : x >= 0.5 ? 4 : x >= 0.25 ? 3 : x >= 0.1 ? 2 : x >= 0.05 ? 1 : 0);
    const series = [["khr20h2", "KHR × GMR+MPC"], ["kxrl2l6a6h2", "KXR × GMR+MPC"], ["khr20h2", "KHR × GMR+QP", "qp"]].map(([rb, nm, k]) => {
      const v = [0, 0, 0, 0, 0, 0];
      for (const a of FULL[rb]) v[binOf(fracOf(a, k || "mpc"))]++;
      return { name: nm, labels: binsL, values: v };
    });
    s.addChart(pres.charts.BAR, series, Object.assign(chartBase(), { x: 8.4, y: 1.25, w: 4.4, h: 3.9, barDir: "col", barGrouping: "clustered",
      chartColors: [HEX.accent5, HEX.accent2, HEX.accent6], showLegend: true, legendPos: "b", legendFontSize: 10, catAxisLabelFontSize: 10,
      showValue: true, dataLabelFontSize: 9, valAxisTitle: "本数（77 本中）", showValAxisTitle: true, valAxisTitleFontSize: 10, objectName: nm("chart") }));
    bullets(s, [
      "どの方法でも、最後まで倒れずに再生できた動作は 0 本。GMR+MPC は動作の中央値 4〜5%（7.9〜9.4 秒）で倒れる",
      "GMR と比べると倒れるまでが 1.4〜1.7 倍に延びるが、1 本 2〜4 分の動作に対しては最初の 1 割で倒れるものがほとんど",
      "割合の最大 98% は ground1（床で過ごす動作。参照が立っている間しか倒れを数えないので大きく出る）。GMR+MPC の最大は 33〜34%",
    ], 0.6, 5.2, 12.2, 1.7, 12);
  }
  {
    const s = slide("CONTENT", "動作の種類ごと — GMR+MPC が何割で倒れるか", "中央値。「手」= 床に手をつく・倒れる動作（fallAndGetUp・ground・pushAndFall）。倒れるまで = 初めて倒れた時刻。");
    const kinds = [...new Set(FULL.khr20h2.map(kindOf))];
    const rows = [["動作の種類", "本数", "長さ", "KHR 倒れるまで", "KHR 割合", "KXR 倒れるまで", "KXR 割合", "KHR GMR+QP"]];
    const order = kinds.map((k) => [k, median(FULL.khr20h2.filter((a) => kindOf(a) === k).map((a) => fracOf(a, "mpc")))]).sort((a, b) => b[1] - a[1]);
    for (const [k] of order) {
      const a = FULL.khr20h2.filter((x) => kindOf(x) === k), b = FULL.kxrl2l6a6h2.filter((x) => kindOf(x) === k);
      const nmk = HAND.includes(k) ? k + "（手）" : k;
      rows.push([nmk, String(a.length), median(a.map(durOf)).toFixed(0) + " 秒",
        median(a.map((x) => fallOf(x, "mpc"))).toFixed(1) + " 秒", pc(median(a.map((x) => fracOf(x, "mpc")))),
        median(b.map((x) => fallOf(x, "mpc"))).toFixed(1) + " 秒", pc(median(b.map((x) => fracOf(x, "mpc")))),
        median(a.map((x) => fallOf(x, "qp"))).toFixed(1) + " 秒"]);
    }
    table(s, rows, 0.6, 1.3, 8.6, [1.95, 0.6, 0.8, 1.15, 0.95, 1.15, 0.95, 1.05], 10, { rowH: 0.33 });
    bullets(s, [
      "いちばん長く立つのは踊り（dance）: 約 22 秒・全体の 11%。上体の動きが中心で足の踏み替えが少ない",
      "戦う・走る・全力で走る（fight, run, sprint）は 2〜4%（5〜11 秒）で倒れる",
      "歩く（walk）は 11 秒前後・5% 弱。障害物を越える（obstacles, 17 本）も 4% 前後",
      "床に手をつく動作（手）も同じくらいの所で倒れる（倒れる判定は参照が立っている間だけ）",
    ], 9.45, 1.3, 3.3, 5.6, 11.5);
  }
  {
    const s = slide("CONTENT", "1 本ずつ — GMR+MPC が倒れた位置（全体に対する割合）", "77 本を KHR の割合の大きい順に並べた。棒が短いほど早く倒れた（100% = 最後まで）。");
    const r1 = FULL.khr20h2, r2 = Object.fromEntries(FULL.kxrl2l6a6h2.map((a) => [a.file, a]));
    const sorted = [...r1].sort((a, b) => fracOf(b, "mpc") - fracOf(a, "mpc"));
    const labels = sorted.map((a) => a.file.replace(/^lafan1\//, "").replace("_subject", "_s"));
    s.addChart(pres.charts.BAR, [
      { name: "KHR × GMR+MPC", labels, values: sorted.map((a) => +(fracOf(a, "mpc") * 100).toFixed(1)) },
      { name: "KXR × GMR+MPC", labels, values: sorted.map((a) => +(fracOf(r2[a.file], "mpc") * 100).toFixed(1)) },
    ], Object.assign(chartBase(), { x: 0.5, y: 1.2, w: 12.3, h: 5.75, barDir: "col", barGrouping: "clustered", barGapWidthPct: 30,
      chartColors: [HEX.accent5, HEX.accent2], showLegend: true, legendPos: "t", legendFontSize: 10,
      catAxisLabelFontSize: 6, catAxisLabelRotate: -90, valAxisMaxVal: 40, valAxisTitle: "倒れた位置（動作の長さに対する %）", showValAxisTitle: true, valAxisTitleFontSize: 10, objectName: nm("chart") }));
  }
}

// =====================================================================
section("3. まとめ");
{
  const s = slide("CONTENT", "限界と、次にやること", "");
  head(s, 0.6, 1.3, 6.0, "!", "なぜ歩く・走るで倒れるか", C.accent1);
  bullets(s, [
    "人の歩く速さを脚の長さで縮めても、片足で支える時間は約 0.2 秒。KHR・KXR には速すぎる",
    "着地はキャプチャポイントでずらすが、届く範囲（0.3 L）と振り出しの時間（約 0.2 秒）が足りない",
    "台車の模型は腕・胴の角運動量を見ていない。サーボの遅れも MPC の外",
    "物理なしで再生すると、計画した動き自体は立って歩けている",
  ], 0.6, 1.8, 6.0, 4.5, 12.5);
  head(s, 6.85, 1.3, 5.9, "→", "次", C.accent4);
  bullets(s, [
    "両足立ちで押されたときの踏み出し（予定にない一歩）を足す",
    "MPC の模型にサーボの遅れと角運動量を入れる",
    "歩く速さを、ロボットの速さの上限に合わせて落とす（遅れを許す）",
    "学習した追従の方策（GMR の論文と同じ, 規模が大きい）",
    "lafan1 の 77 本 × 2 体を、方法ごと・起き上がりつきで最後まで測る",
  ], 6.85, 1.8, 5.9, 4.5, 12.5);
}
{
  const s = slide("TITLE_DARK", "まとめ");
  const T = [
    "倒れないための制約を、静的な重心（GMR+QP）→ ZMP の MPC で計画した重心を最優先（QP+バランス）→ 物理の今の状態から毎コマ解き直す（GMR+MPC）と強めた",
    "立って腕を動かす動きは倒れなくなった。歩行は QP+バランスで倒れるまでが 6.8 → 19.7 秒に延びたが、まだ倒れる",
    "倒れたら起き上がりの動作をして、倒れたコマから BVH を続ける（KHR はほぼ毎回起き上がれる）",
    "iPhone・Mac・Android・デスクトップで同じ C++ を使い、ボタンで比べられる",
  ];
  s.addText(T.map((t, i) => ({ text: t, options: { bullet: true, breakLine: i < T.length - 1, paraSpaceAfter: 6 } })),
    { x: 0.8, y: 3.85, w: 11.7, h: 3.15, fontSize: 15.5, color: "CADCFC", valign: "top", margin: 0, isTextBox: true, objectName: "conclusion" });
}

(async () => {
  await pres.writeFile({ fileName: OUT });
  await applyTheme(OUT, THEME);
  const JSZip = require("jszip");
  const zip = await JSZip.loadAsync(fs.readFileSync(OUT));
  for (const f of Object.keys(zip.files).filter((f) => /ppt\/theme\/theme\d+\.xml$/.test(f))) {
    let x = await zip.file(f).async("string");
    x = x.replace(/<a:ea typeface="[^"]*"\s*\/>/g, `<a:ea typeface="${THEME.bodyFontFace}"/>`);
    zip.file(f, x);
  }
  // 動画: スライドを開いたらそのページの動画を全部同時に再生し, 繰り返す (pptxgenjs はクリックで再生のみ)
  //   1 本目 = 前の後 (自動), 2 本目から = 1 本目と同時. p:video で繰り返し
  for (const f of Object.keys(zip.files).filter((f) => /ppt\/slides\/slide\d+\.xml$/.test(f))) {
    let x = await zip.file(f).async("string");
    const ids = [...x.matchAll(/<p:pic>\s*<p:nvPicPr>\s*<p:cNvPr id="(\d+)"[\s\S]*?<\/p:nvPicPr>/g)].filter((m) => m[0].includes("<a:videoFile")).map((m) => m[1]);
    if (!ids.length || x.includes("<p:timing>")) continue;
    // 動画の <p:pic> を spTree の最後 (いちばん手前) へ移す. 後ろにほかの図形があると LibreOffice は 1 本しか再生しない
    const pics = [...x.matchAll(/<p:pic>[\s\S]*?<\/p:pic>/g)].map((m) => m[0]).filter((t) => t.includes("<a:videoFile"));
    for (const t of pics) x = x.replace(t, "");
    x = x.replace("</p:spTree>", pics.join("") + "</p:spTree>");
    let n = 4;
    const calls = ids.map((id, i) => {
      const a = n++, b = n++;
      return `<p:par><p:cTn id="${a}" presetID="1" presetClass="mediacall" presetSubtype="0" fill="hold" nodeType="${i ? "withEffect" : "afterEffect"}"><p:stCondLst><p:cond delay="0"/></p:stCondLst><p:childTnLst>` +
        `<p:cmd type="call" cmd="playFrom(0.0)"><p:cBhvr><p:cTn id="${b}" dur="1" fill="hold"/><p:tgtEl><p:spTgt spid="${id}"/></p:tgtEl></p:cBhvr></p:cmd></p:childTnLst></p:cTn></p:par>`;
    }).join("");
    const media = ids.map((id) => `<p:video><p:cMediaNode vol="80000" mute="1"><p:cTn id="${n++}" repeatCount="indefinite" fill="hold"><p:stCondLst><p:cond delay="indefinite"/></p:stCondLst></p:cTn><p:tgtEl><p:spTgt spid="${id}"/></p:tgtEl></p:cMediaNode></p:video>`).join("");
    const timing = `<p:timing><p:tnLst><p:par><p:cTn id="1" dur="indefinite" restart="never" nodeType="tmRoot"><p:childTnLst>` +
      `<p:seq concurrent="1" nextAc="seek"><p:cTn id="2" dur="indefinite" nodeType="mainSeq"><p:childTnLst>` +
      `<p:par><p:cTn id="3" fill="hold"><p:stCondLst><p:cond delay="indefinite"/><p:cond evt="onBegin" delay="0"><p:tn val="2"/></p:cond></p:stCondLst><p:childTnLst>` +
      `<p:par><p:cTn id="${n++}" fill="hold"><p:stCondLst><p:cond delay="0"/></p:stCondLst><p:childTnLst>${calls}</p:childTnLst></p:cTn></p:par>` +
      `</p:childTnLst></p:cTn></p:par></p:childTnLst></p:cTn>` +
      `<p:prevCondLst><p:cond evt="onPrev" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:prevCondLst>` +
      `<p:nextCondLst><p:cond evt="onNext" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:nextCondLst></p:seq>` +
      media + `</p:childTnLst></p:cTn></p:par></p:tnLst></p:timing>`;
    x = x.includes("</p:clrMapOvr>") ? x.replace("</p:clrMapOvr>", "</p:clrMapOvr>" + timing) : x.replace("</p:cSld>", "</p:cSld>" + timing);
    zip.file(f, x);
  }
  fs.writeFileSync(OUT, await zip.generateAsync({ type: "nodebuffer", compression: "DEFLATE" }));
  // 最後に pptx-video-sync（~/.claude/skills/pptx-video-sync）を通す: 動画を最前面へ・一斉再生・繰り返し・クリックで一時停止.
  //   上の後処理はツールがないときの代わり (ツールがあれば timing を作り直す)
  const { execFileSync } = require("child_process");
  const sync = [process.env.HOME + "/.local/bin/pptx-video-sync", process.env.HOME + "/.claude/skills/pptx-video-sync/pptx-video-sync"].find((f) => fs.existsSync(f));
  if (sync) {
    execFileSync(sync, [OUT], { stdio: "inherit" });
    execFileSync(sync, ["--check", OUT], { stdio: "inherit" });
  } else console.warn("pptx-video-sync がありません: 動画の timing は簡易版 (README の入れ方を参照)");
  console.log("wrote", OUT);
})();
