// EusView の開発と使い方のスライド生成 (iPhone / Mac / Ubuntu / Android, ODE)
const pptxgen = require("pptxgenjs");
const fs = require("fs");
const path = require("path");
const { applyTheme } = require(process.env.SKILL_DIR + "/scripts/apply_theme.js");

const W = __dirname;
const OUT = process.argv[2] || path.join(W, "eusview.pptx");
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
pres.title = "EusView — jskeus / kxreus のロボットを iPhone・Mac・Ubuntu・Android で";
pres.author = "Masayuki Inaba";
pres.subject = "EusView: robot viewer with ODE physics on iOS, macOS, Ubuntu (irteusgl) and Android";
const C = pres.SchemeColor;

// ---------- layouts ----------
const FOOT = "EusView — jskeus / kxreus のロボットを 4 つの環境で";
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

// =====================================================================
section("タイトル");
{
  const s = slide("TITLE_DARK", "EusView\njskeus / kxreus のロボットを 4 つの環境で");
  s.addText([
    { text: "EusLisp のロボットモデル（jskeus・kxreus）を iPhone・Mac・Ubuntu・Android で表示し、RCB4 の動作と ODE の物理で動かすアプリの開発・インストール・使い方・物理の実装", options: { breakLine: true } },
    { text: "iPhone 16 Pro ／ MacBook Pro（Intel）／ Ubuntu（irteusgl）／ Pixel 7a ・ ロボット 121 体（KXR 36・KHR 43・JSK 42）", options: { fontSize: 13, color: "8FA3C8" } },
  ], { placeholder: "body" });
  s.addText("2026-10-05", { x: 0.8, y: 6.6, w: 4, h: 0.4, fontSize: 12, color: "8FA3C8", margin: 0, isTextBox: true });
}
{
  const s = slide("CONTENT", "概要", "数はすべて書き出した JSON と計測した値。動作の数は KXR・KHR のプロジェクトを RCB4 エミュレーションで動かしたもの。");
  const st = [["4", "動く環境\niPhone・Mac・Ubuntu・Android", C.text1], ["121", "ロボット\nKXR 36・KHR 43・JSK 42", C.accent2], ["3,726", "動作（モーション）\n80 体分, KXR・KHR のプロジェクト", C.accent1], ["ODE", "物理シミュレーション\neusdyna と同じ考え方", C.accent4]];
  const xs = [0.6, 3.7, 6.8, 9.9];
  st.forEach(([b, l, c], i) => {
    card(s, xs[i], 1.45, 2.85, 2.0);
    s.addText(b, { x: xs[i] + 0.2, y: 1.55, w: 2.5, h: 0.9, fontSize: 36, bold: true, color: c, valign: "bottom", margin: 0, isTextBox: true, fit: "shrink", objectName: nm("stat") });
    s.addText(l, { x: xs[i] + 0.2, y: 2.5, w: 2.5, h: 0.85, fontSize: 12, color: C.accent6, valign: "top", margin: 0, isTextBox: true, objectName: nm("statlbl") });
  });
  head(s, 0.6, 3.75, 6, "1", "全体像と共通のソフトウェア", C.text1);
  head(s, 0.6, 4.2, 6, "2", "4 つの環境の開発環境とインストール", C.accent2);
  head(s, 0.6, 4.65, 6, "3", "使い方（スマートフォン・統合ウインドウ）", C.accent3);
  head(s, 0.6, 5.1, 6, "4", "ODE による物理の実装", C.accent4);
  head(s, 6.9, 3.75, 6, "5", "物理パラメータを変えると（動画）", C.accent1);
  head(s, 6.9, 4.2, 6, "6", "BVH の変換と移し替え（GMR + 全身 QP）", C.accent5);
  head(s, 6.9, 4.65, 6, "7", "まとめ", C.accent6);
  para(s, "ロボットは EusLisp で JSON に書き出して共通に使い、iPhone・Mac・Android はネイティブアプリ、Ubuntu は統合ウインドウのデスクトップ版と kxreus のデモ（irteusgl）で動かす。物理（odesim）と全身 QP（wbqp）は同じ C/C++ の層を全部の環境で使う。", 0.6, 5.65, 12.1, 1.1, { fontSize: 13.5, color: C.accent6, italic: true });
}

// =====================================================================
section("1. 全体像");
{
  const s = slide("SECTION", "全体像と共通のソフトウェア");
  s.addText("EusLisp → JSON → 4 つの環境。物理は ODE の C の層を共有", { placeholder: "body" });
  tile(s, 0.9, 2.75, "1", C.accent6, 1.2);
}
{
  const s = slide("CONTENT", "EusView のしくみ", "JSON はロボットの形（三角形）・関節・姿勢・動作・物理パラメータを 1 つのファイルにまとめたもの。Ubuntu は JSON を使わず kxreus がその場でロボットを作る。");
  box(s, 0.5, 1.35, 3.0, 1.15, "jskeus（EusLisp）", "irteusgl, irtstl（stl2eus）\neus/models のロボット", C.background2);
  box(s, 0.5, 2.7, 3.0, 1.15, "kxreus", "KXR / KHR のモデル\nRCB4 エミュレーション・プロジェクト", C.background2);
  box(s, 4.2, 1.35, 3.1, 2.5, "書き出し（Mac）", "eusview/eus2json.l\neus2physics.l, export-*.l\n→ robots/{kxr,khr,jsk}/*.json\n（形・関節・姿勢・動作・物理）", C.text1, C.background1);
  arrow(s, 3.5, 1.9, 4.2, 2.3); arrow(s, 3.5, 3.25, 4.2, 2.9);
  box(s, 8.0, 1.35, 2.25, 1.15, "iPhone", "SwiftUI + SceneKit\nODE（odesim）", C.accent1, C.background1);
  box(s, 10.45, 1.35, 2.3, 1.15, "Mac", "Mac Catalyst\n（iPhone と同じコード）", C.accent2, C.background1);
  box(s, 8.0, 2.7, 2.25, 1.15, "Android", "Kotlin + Compose\nOpenGL ES + ODE（JNI）", C.accent4, C.background1);
  box(s, 10.45, 2.7, 2.3, 1.15, "Ubuntu", "kxreus eusview.l\nirteusgl + ODE", C.accent3, C.text1);
  arrow(s, 7.3, 2.3, 8.0, 1.9); arrow(s, 7.3, 2.9, 8.0, 3.25);
  box(s, 4.2, 4.4, 8.55, 0.95, "live（実時間）", "EusLisp（Mac / Ubuntu）→ TCP 8767 → 中継 live.py → WebSocket 8766 → 各アプリ：関節角と体の位置を送ると同じように動く", C.background2);
  bullets(s, [
    "ロボットのデータは 1 度書き出せば、iPhone・Mac・Android で同じものを使う（アプリに入れて配る）",
    "Ubuntu は EusLisp がそのまま動くので、kxreus のデモとして irteusgl の画面とパネルで同じことをする",
    "物理は ODE の薄い C の層 odesim.{h,cpp} を全環境で共有（Swift はブリッジ, EusLisp は defforeign, Kotlin は JNI）",
  ], 0.6, 5.6, 12.1, 1.3, 13);
}
{
  const s = slide("CONTENT", "4 つの環境の比べ方", "Ubuntu のほかはこの Mac（Intel, macOS 15）でビルドした。Ubuntu の欄は kxreus に入れたデモの作り方（Ubuntu の実機では未確認）。");
  table(s, [["", "iPhone", "Mac", "Ubuntu", "Android"],
    ["画面", "SwiftUI", "SwiftUI（Mac Catalyst）", "irtviewer + X パネル（Xft で日本語）", "Jetpack Compose"],
    ["3D 表示", "SceneKit", "SceneKit", "irtviewer（OpenGL）", "OpenGL ES 3.0（自前）"],
    ["物理（ODE）", "odesim + ODE.xcframework", "同じ（Catalyst 用の ODE）", "odesim を libeusviewode.so に（defforeign）", "odesim + ODE（NDK, JNI）"],
    ["ロボット", "JSON（アプリに同梱）", "JSON（同梱）", "kxreus / jskeus がその場で作る", "JSON（APK に同梱）"],
    ["動作", "JSON の関節角の列", "同じ", "RCB4 エミュレーションをその場で", "JSON の関節角の列"],
    ["開発環境", "Xcode 26.2, XcodeGen", "Xcode 26.2", "EusLisp, jskeus, kxreus, libode-dev", "JDK 17, Android SDK 35, NDK 27, Gradle"],
    ["入れ方", "USB + devicectl（無料の Apple ID）", "~/Applications にコピー", "make eusview-desktop（アイコン）", "USB + adb install"],
    ["実機", "iPhone 16 Pro（iOS 26）", "MacBook Pro 2019（Intel）", "（Mac の XQuartz で確認）", "Pixel 7a（Android 17）"]],
    0.6, 1.35, 12.1, [1.5, 2.6, 2.4, 3.0, 2.6], 11.5, { rowH: 0.56 });
}
{
  const s = slide("CONTENT", "共通のソフトウェアの構成", "kxreus（inabajsk/kxreus）の eusview/ と、トップの EusView デモ（eusview.l）。ODE の C の層は 3 か所に同じものを置いている。");
  code(s, [
    "kxreus/eusview/",
    "├─ eus2json.l, eus2physics.l    ロボット → JSON（形・関節・姿勢・物理）",
    "├─ export-{demo,walk,jsk,kxr,motions}.l   書き出しの実行（run-eus.sh で）",
    "├─ kxr-env.l, run-eus.sh        jskeus / kxreus を動かす準備",
    "├─ verify.py                    JSON をアプリと同じ式で確かめる",
    "├─ live.py, eus2live.l, live-walk.l   EusLisp → アプリ（実時間）",
    "├─ robots/{kxr,khr,jsk}/*.json  ロボット 121 体（約 75 MB）",
    "├─ ios/                         iPhone・Mac アプリ",
    "│   ├─ EusView/App/*.swift      画面・3D（SceneKit）・live",
    "│   ├─ EusView/Physics/odesim.{h,cpp}, PhysicsSim.swift   物理",
    "│   ├─ third_party/ODE.xcframework, build-ode.sh",
    "│   └─ tools/physicstest.swift, rendericon.swift, rendervideo.swift",
    "└─ android/                     Android アプリ（Kotlin, OpenGL ES, JNI）",
  ].join("\n"), 0.6, 1.35, 7.1, 5.5, 11.5);
  code(s, [
    "kxreus/（Ubuntu・Mac の irteusgl）",
    "├─ eusview.l          EusView デモ",
    "├─ eusview-physics.l  ODE の物理",
    "├─ eusview-ode/       odesim.{h,cpp}",
    "│                      eusviewode.cpp",
    "├─ eusview-xft.l      日本語（Xft）",
    "├─ eusview.sh         起動スクリプト",
    "├─ eusview-live.py    中継",
    "├─ images/eusview.png アイコン",
    "├─ projects/Hello_khr3*/  KHR の動作",
    "└─ Makefile           eusview,",
    "     eusview-ode, eusview-desktop",
  ].join("\n"), 7.9, 1.35, 4.85, 5.5, 11.5);
}
{
  const s = slide("CONTENT", "ロボットのデータ（JSON）", "単位は m・度（直動は mm）、座標は EusLisp と同じ z が上。全 121 体を verify.py でアプリと同じ式で計算し、EusLisp の位置との差は 0.011 mm 以下。");
  code(s, [
    "{ \"name\": \"kxrl2l6a6h2\", \"group\": \"kxr\",",
    "  \"links\":  [ { \"name\", \"parent\", \"pos\", \"rot\",      // 関節 0 での親からの位置・姿勢",
    "                \"meshes\": [ { \"color\", \"vertices\", \"indices\" } ] } ],",
    "  \"joints\": [ { \"name\", \"link\"(子), \"type\", \"axis\", \"min\", \"max\" } ],",
    "  \"poses\":  { \"reset-pose\": [...], \"sit-pose\": [...], ... },",
    "  \"motions\": [ { \"name\": \"XL2G_201_挨拶\", \"fps\": 50,",
    "                 \"frames\": [[関節角...], ...] } ],",
    "  \"physics\": { \"links\": [ { \"mass\", \"com\", \"inertia\", \"shapes\": [箱/円柱] } ],",
    "               \"joints\": [ { \"motor\", \"fmax\", \"vmax\", \"kp\" } ],",
    "               \"world\": {...}, \"contact\": {...} } }",
  ].join("\n"), 0.6, 1.35, 7.4, 3.3, 11.5);
  bullets(s, [
    "子リンクの座標 = 親 × T(pos)·R(rot)·R(axis, 角度)。EusLisp の rotational-joint と同じ式",
    "形は物体ごとのメッシュ（面ごとに頂点を分けて平らな陰影）",
    "姿勢はロボットのクラスのメソッド（:reset-pose など）を呼んだ角度",
    "動作は kxreus の rcb4-interface で .h4p を読み、:emulate-motion-code で実行したサーボ命令を 50 fps に補間",
    "物理は eusdyna（odedyna.l / kxrdyna.l）と同じ作り方（次の節）",
  ], 8.3, 1.35, 4.45, 5.5, 12.5);
}

// =====================================================================
section("2. 開発環境とインストール");
{
  const s = slide("SECTION", "4 つの環境の開発環境とインストール");
  s.addText("iPhone・Mac はこの Mac の Xcode、Android は Android SDK、Ubuntu は kxreus の Makefile", { placeholder: "body" });
  tile(s, 0.9, 2.75, "2", C.accent2, 1.2);
}
{
  const s = slide("CONTENT", "iPhone — Xcode でビルドして USB で入れる", "無料の Apple ID（個人チーム）で 7 日間有効な署名。初回だけ iPhone 側の設定が要る。");
  head(s, 0.6, 1.35, 5.9, "A", "開発環境（Mac）", C.accent1);
  bullets(s, [
    "Xcode 26.2 と iOS プラットフォーム（xcodebuild -downloadPlatform iOS, 約 10 GB）",
    "XcodeGen（project.yml から .xcodeproj を作る）",
    "Xcode → Settings → Accounts に Apple ID（個人チーム）",
    "ODE.xcframework（ODE 0.16.5, 倍精度, build-ode.sh で作成済み）",
  ], 0.6, 1.9, 5.9, 2.2, 12.5);
  head(s, 0.6, 4.15, 5.9, "B", "iPhone の準備（初回）", C.accent1);
  bullets(s, [
    "USB でつなぎ「このコンピュータを信頼」",
    "設定 → プライバシーとセキュリティ → デベロッパモード をオン",
    "初めて起動するとき: 設定 → 一般 → VPN とデバイス管理 で開発者を「信頼」",
  ], 0.6, 4.7, 5.9, 2.1, 12.5);
  code(s, [
    "# Xcode プロジェクトを作る",
    "make -C eusview/ios project \\",
    "  DEVELOPMENT_TEAM=<チーム ID> XCODEGEN=<xcodegen>",
    "",
    "# ビルドして iPhone に入れる",
    "make -C eusview/ios device \\",
    "  DEVICE=<xcrun devicectl list devices の ID>",
    "",
    "# Xcode の画面からでも可:",
    "#  EusView.xcodeproj を開いて ▶",
  ].join("\n"), 6.8, 1.35, 5.95, 3.4, 12);
  bullets(s, [
    "画面がロックされていると起動できない（devicectl は Locked と返す）",
    "署名のときにキーチェーンの確認が出たら「常に許可」",
  ], 6.8, 5.0, 5.95, 1.8, 12.5);
}
{
  const s = slide("CONTENT", "Mac — 同じコードを Mac Catalyst で", "Intel の Mac では iPhone アプリをそのまま動かせないので、Mac Catalyst で Mac のアプリとしてビルドする。ODE も Catalyst 用を xcframework に入れた。");
  code(s, [
    "make -C eusview/ios mac",
    "#  → build/Build/Products/Release-maccatalyst/EusView.app",
    "",
    "# アプリケーションフォルダに置く（Spotlight・Launchpad から起動）",
    "cp -R eusview/ios/build/Build/Products/Release-maccatalyst/EusView.app ~/Applications/",
    "",
    "# ODE を作り直すとき（iPhone, シミュレータ, Mac, Mac Catalyst の 4 種）",
    "eusview/ios/third_party/build-ode.sh",
  ].join("\n"), 0.6, 1.35, 7.4, 3.0, 12);
  bullets(s, [
    "画面・操作は iPhone 版と同じ。マウスのドラッグで回転、ピンチで拡大",
    "左上の「計算 ○ ms/コマ」で物理の計算時間を比べられる",
    "コードを変えたら make mac のあと ~/Applications にコピーし直す",
  ], 0.6, 4.6, 7.4, 2.2, 13);
  video(s, "mac_catalyst_list", 8.3, 1.35, 4.45, 5.5);
}
{
  const s = slide("CONTENT", "Ubuntu — kxreus の EusView デモ", "Ubuntu には EusLisp（irteusgl）があるので、アプリを作らず kxreus のデモとして動かす。Mac の XQuartz で動作を確認（Ubuntu 実機は未確認）。");
  code(s, [
    "sudo apt install libode-dev fonts-noto-cjk",
    "cd ~/kxreus && git pull && make",
    "make eusview-ode       # ODE の C の層 → $ARCHDIR/lib/libeusviewode.so",
    "make eusview-desktop   # アプリ一覧とデスクトップにアイコン",
    "make eusview           # 端末から起動（irteusgl eusview.l \"(eusview)\"）",
  ].join("\n"), 0.6, 1.35, 7.4, 2.1, 12);
  bullets(s, [
    "eusview.sh が irteusgl か roseus を PATH・~/.bashrc・ROS の設定から探して起動",
    "アイコンに × が付いたら、右クリック →「起動を許可」",
    "物理: kxrdyna（eusdyna）があればそれ、なければ eusview-physics.l（odesim + ODE）",
    "日本語: eusview-xft.l（Xft + fontconfig, Noto Sans CJK JP など）。robot-control-panel の動作の名前にも使う",
    "KHR の動作のため KHR-3HV のプロジェクトを kxreus/projects に入れた",
  ], 0.6, 3.7, 7.4, 3.1, 12.5);
  video(s, "eusview_ubuntu_panel", 8.3, 1.35, 4.45, 5.5);
}
{
  const s = slide("CONTENT", "Android — Android SDK でビルドして adb で入れる", "Android Studio は使わずコマンドラインで。開発環境は Homebrew を使わず公式の配布物を入れた（合計 約 3 GB）。");
  head(s, 0.6, 1.35, 5.9, "A", "開発環境（Mac）", C.accent4);
  bullets(s, [
    "JDK 17（Temurin）: ~/Library/Java",
    "Android SDK: ~/Library/Android/sdk（cmdline-tools, platform-tools, platforms;android-35, build-tools;35.0.0）",
    "NDK 27.2, CMake 3.22（ODE と odesim の C/C++）",
    "Gradle はプロジェクトの gradlew が取ってくる",
  ], 0.6, 1.9, 5.9, 2.6, 12.5);
  head(s, 0.6, 4.55, 5.9, "B", "Pixel の準備（初回）", C.accent4);
  bullets(s, [
    "設定 → デバイス情報 → ビルド番号 を 7 回タップ",
    "開発者向けオプション → USB デバッグ をオン",
    "USB でつなぎ「このパソコンからは常に許可」",
    "入れるたびに Play プロテクトの確認が出たら「送信しない」",
  ], 0.6, 5.1, 5.9, 1.7, 12.5);
  code(s, [
    "export JAVA_HOME=~/Library/Java/jdk-17*/Contents/Home",
    "export ANDROID_HOME=~/Library/Android/sdk",
    "cd eusview/android",
    "make run              # assembleDebug → adb install -r → 起動",
    "make install-release  # リリース版（約 19 MB, 速い）",
    "",
    "# ODE を作り直すとき（arm64-v8a, x86_64）",
    "third_party/build-ode-android.sh",
  ].join("\n"), 6.8, 1.35, 5.95, 3.0, 12);
  video(s, "android_list", 6.8, 4.55, 5.95, 2.35, { noCaption: true });
}
{
  const s = slide("CONTENT", "ロボットの書き出し（Mac の irteusgl）", "~/jskeus（inabajsk/jskeus + inabajsk/EusLisp の glu-tess-collector をビルド）と最新の kxreus を使う。起動直後にまれに落ちるので run-eus.sh がやり直す。");
  code(s, [
    "cd ~/kxreus",
    "eusview/run-eus.sh eusview/export-demo.l            # irteus/demo の 4 体",
    "EUS_TIMEOUT=900 eusview/run-eus.sh eusview/export-jsk.l   # eus/models の 37 体",
    "EUSVIEW_ROBOTS=\"kxrl2l6a6h2\" eusview/run-eus.sh eusview/export-kxr.l",
    "EUSVIEW_PROJECTS=\"kxrl2l6a6h2 kxrl4r\" EUS_TIMEOUT=900 \\",
    "  eusview/run-eus.sh eusview/export-motions.l       # 動作 + 物理",
    "python3 eusview/verify.py eusview/robots/*/*.json   # アプリと同じ式で確認",
  ].join("\n"), 0.6, 1.35, 12.1, 2.6, 12);
  bullets(s, [
    "形: 物体の面を三角形に分ける（凸な面は扇形、穴のある面は face-to-triangle）。kxreus の部品の形は GLU のテッセレーション（eus_tess_*）で 82 秒 → 15 秒",
    "STL の部品（頭など）は jskeus の irtstl.l の stl2eus で読む",
    "動作: rcb4-interface で .h4p を読み、:emulate-motion-code でサーボ命令を記録して 50 fps に補間。ID にないサーボは今の角度のまま、待ちのループは静止として扱う",
    "kxreus の形のキャッシュは eusview/cache に書く（~/kxreus には書かない）",
  ], 0.6, 4.2, 12.1, 2.7, 12.5);
}

// =====================================================================
section("3. 使い方");
{
  const s = slide("SECTION", "使い方");
  s.addText("ロボットを選ぶ → 関節・姿勢・動作・接続。物理（ODE）をオンにすると床の上で動く", { placeholder: "body" });
  tile(s, 0.9, 2.75, "3", C.accent3, 1.2);
}
{
  const s = slide("CONTENT", "画面の使い方（iPhone・Mac・Android 共通）", "Ubuntu の kxreus 版も同じ項目をボタンとメニューで持つ。");
  table(s, [["場所", "できること"],
    ["一覧", "KXR / KHR / JSK のタブ、名前で検索。選ぶと 3D 表示"],
    ["3D", "1 本指で回転、2 本指で移動・拡大（Mac はマウスとトラックパッド）"],
    ["関節", "関節ごとのスライダー（可動範囲の中で）"],
    ["姿勢", "reset-pose・sit-pose などへ 0.6 秒でなめらかに"],
    ["動作", "プロジェクトの動作（挨拶・歩行・起き上がりなど）。選ぶと繰り返し、もう一度押すと止まる"],
    ["接続", "ws://<PC の IP>:8766/ に接続して EusLisp から送られる関節角で動く"],
    ["物理（ODE）", "オンにすると今の姿勢で床に置き、関節角はサーボの目標になる"],
    ["サーボ / 置き直す", "サーボを切ると脱力して崩れる。置き直すで今の姿勢から床に置き直す"]],
    0.6, 1.35, 7.0, [1.8, 5.2], 12, { rowH: 0.56 });
  video(s, "android_motion", 7.9, 1.35, 4.85, 5.5);
}
{
  const s = slide("CONTENT", "スマートフォンの画面 — iPhone", "同じアプリを iOS シミュレータ（iPhone 16 Pro）で撮ったもの。Android（Pixel 7a）の画面は「2. 開発環境」の動画を参照。");
  shot(s, "sim_list", 0.6, 1.3, 2.95, 5.35);
  shot(s, "sim_robot", 3.65, 1.3, 2.95, 5.35);
  shot(s, "sim_physics", 6.7, 1.3, 2.95, 5.35);
  shot(s, "sim_bvh_motion", 9.75, 1.3, 2.95, 5.35);
}
{
  const s = slide("CONTENT", "統合ウインドウ — Ubuntu デスクトップ版", "1 つのウインドウに 一覧・3D・物理・関節 / 姿勢 / 動作 / 接続・BVH をまとめた。Kotlin（Compose Desktop）で Android 版とコードを共有。画面は Mac で撮ったもの。");
  shot(s, "desk_main", 0.6, 1.3, 7.6, 5.6);
  code(s, [
    "# Ubuntu",
    "sudo apt install openjdk-17-jdk cmake g++ \\",
    "  libode-dev pkg-config fakeroot fonts-noto-cjk",
    "cd ~/kxreus/eusview/desktop",
    "make native   # ODE + odesim + wbqp (JNI)",
    "make run      # 起動",
    "make deb      # .deb（JRE・データ・アイコン）",
  ].join("\n"), 8.45, 1.3, 4.3, 2.45, 11);
  bullets(s, [
    "左: ロボットの一覧（KXR / KHR / JSK, 検索）・BVH・表示",
    "右: 3D（マウスで回転・移動・拡大）、物理・サーボ・置き直す、関節 / 姿勢 / 動作 / 接続",
    "3D は OpenGL で描いて画面に出す（Mac と Linux で同じ作り）",
    "Mac で KXR 50〜54 コマ/秒。Ubuntu の実機では未確認",
  ], 8.45, 3.95, 4.3, 2.9, 12);
}
{
  const s = slide("CONTENT", "統合ウインドウ — 物理・BVH・live", "どれも同じ 1 つのウインドウの中で切り替える。");
  shot(s, "desk_physics", 0.6, 1.3, 3.95, 5.6);
  shot(s, "desk_bvh_khr", 4.7, 1.3, 3.95, 5.6);
  shot(s, "desk_live", 8.8, 1.3, 3.95, 5.6);
}
{
  const s = slide("CONTENT", "動作の再生 — RCB4 エミュレーションの関節角の列", "KXR・KHR のプロジェクト（Heart-to-Heart 4 の .h4p）の動作テーブルを、kxreus の RCB4 エミュレータで実際に動かして得た関節角。");
  video(s, "motion_kxr_walk", 0.6, 1.35, 6.0, 5.5);
  video(s, "motion_khr_greet", 6.75, 1.35, 6.0, 5.5);
}
{
  const s = slide("CONTENT", "Android（Pixel 7a）で物理と動作", "左: kxra6g の挨拶・手を振る・喜ぶ・パンチ・防御（物理なし）。右: Pixel 7a で物理（ODE）をオンにして歩く（接触 4 点、計算 約 3 ms/コマ）。");
  video(s, "motion_kxr_rcb4", 0.6, 1.35, 6.0, 5.5);
  video(s, "android_physics", 6.75, 1.35, 6.0, 5.5);
}
{
  const s = slide("CONTENT", "Ubuntu（kxreus の EusView）の画面", "irtviewer と X のパネル。動作のメニューは Xft で日本語。physics / servo / live はトグルで、状態の行に経過時間や iPhone に入れるアドレスが出る。");
  video(s, "eusview_ubuntu_physics", 0.6, 1.35, 7.6, 5.5);
  bullets(s, [
    "ロボットのパネル: 姿勢のボタン、動作のメニュー（20 件ずつ）、stop、physics、servo、live、関節のスライダー",
    "動作を選ぶと stop まで繰り返す（「再生中: 名前（n 回目）」）",
    "physics: kxrdyna がなければ odesim + ODE",
    "live: 中継（eusview-live.py）を自動で起動し、iPhone に入れるアドレスと台数を表示",
  ], 8.5, 1.4, 4.25, 5.4, 12.5);
}
{
  const s = slide("CONTENT", "live — EusLisp で計算した動きを各アプリへ", "中継は標準ライブラリだけの Python。EusLisp は 1 行 1 つの JSON を TCP で送り、中継が WebSocket でアプリに配る。");
  code(s, [
    "# Mac / Ubuntu（中継）",
    "python3 eusview/live.py          # または kxreus の eusview-live.py",
    "",
    ";; EusLisp",
    "(load \"eusview/eus2live.l\")",
    "(live-connect)                   ; localhost:8767",
    "(send *robot* :reset-pose)",
    "(live-send *robot*)              ; {\"angles\":[...]} {\"root\":[...]}",
    "(live-pose \"sit-pose\")           ; {\"pose\":\"sit-pose\"}",
    "",
    "# アプリの「接続」に ws://<PC の IP>:8766/",
  ].join("\n"), 0.6, 1.35, 6.4, 4.0, 12);
  bullets(s, [
    "irtviewer で描くところで live-send を呼べば、同じ動きが iPhone・Mac・Android に出る",
    "確認: Mac の EusLisp で sample-robot の歩行を計算しながら送り、iPhone で歩いた",
    "確認: kxreus の EusView（live ボタン）から kxrl2l6a6h2 の歩行を送り、iPhone で 2 回歩いた",
    "物理モードのときは、関節角はサーボの目標として使う（体の位置は ODE が決める）",
  ], 7.3, 1.35, 5.45, 5.5, 12.5);
}

{
  const s = slide("CONTENT", "BVH（モーションキャプチャ）の再生", "kxreus/bvh の 5 種類 421 ファイル（417 MB）。アプリは Python で 30 fps に間引いた形（93 MB, git には入れない）に変換して同梱、Ubuntu 版は jskeus の load-mcd でそのまま読む。");
  table(s, [["種類", "ファイル", "長さ", "単位"],
    ["lafan1", "77", "4.6 時間", "cm"],
    ["mocopi", "9", "8.1 分", "cm"],
    ["rikiya", "300", "33.6 分", "inch"],
    ["sfu", "15", "3.7 分", "inch"],
    ["tum-kitchen", "20", "24.4 分", "mm（Z が上）"]],
    0.6, 1.35, 5.2, [1.6, 1.0, 1.4, 1.2], 12, { rowH: 0.42 });
  bullets(s, [
    "自動再生: 種類ごとにファイルを順に、最後まで行ったら最初へ（stop まで）",
    "メニュー: 種類 → ファイル（検索）→ 止めるまで繰り返す。速さ 0.5x〜2x（Ubuntu は 4x まで）",
    "骨格をそのまま表示（ロボットへの移し替えはしない）。Y が上のデータは Z が上に直し、床に立たせる",
    "アプリと Python の計算の差は全 421 本で 0.009 mm 以下。位置のチャンネルは「OFFSET を置き換える」読み方（jskeus は「足す」ので lafan1 などで違う）",
    "LAFAN1・SFU などはライセンスに制限があるので、データは公開リポジトリに入れない",
  ], 0.6, 4.1, 5.2, 2.8, 11.5);
  video(s, "bvh_mac", 6.1, 1.35, 6.65, 2.75, { noCaption: true });
  video(s, "bvh_android", 6.1, 4.2, 3.25, 2.7, { noCaption: true });
  video(s, "bvh_ubuntu", 9.5, 4.2, 3.25, 2.7, { noCaption: true });
}

// =====================================================================
section("4. ODE の実装");
{
  const s = slide("SECTION", "ODE による物理の実装");
  s.addText("eusdyna（odedyna.l / kxrdyna.l）と同じ考え方を、全環境で共有する C の層 odesim で", { placeholder: "body" });
  tile(s, 0.9, 2.75, "4", C.accent4, 1.2);
}
{
  const s = slide("CONTENT", "ロボットから ODE のモデルを作る", "作り方は odedyna.l の robot2drobot と同じ。値は eus2physics.l で JSON に書き出す（Ubuntu 版は同じ計算を EusLisp でその場で行う）。");
  table(s, [["EusLisp のロボット", "ODE", "作り方"],
    ["リンク", "剛体（dBody）", "質量 = :weight（部品の和）, 重心 = 部品の体積重心の重み付き平均, 慣性 = 部品の箱を重心まわりに合成"],
    ["部品（body）", "衝突形状", "部品ごとに外接直方体（回転体は円柱）。リンクの箱を 1 つの剛体にまとめる"],
    ["回転関節", "ヒンジ（dHinge）", "アンカー = 子リンクの原点, 軸 = 子リンクの軸をワールドに。作ったときの角度を 0 にずらす（q0）"],
    ["直動関節", "スライダ", "軸 = 子リンクの軸。mm ↔ m"],
    ["車輪（回転サーボ）", "速度モータ", "Vel = 20 × 目標 / π, FMax = 1e6（d-joint-rotation）"],
    ["床", "平面 z = 0", "ロボットと床の当たりだけ（自分どうしは当てない）"]],
    0.6, 1.35, 12.1, [2.5, 2.0, 7.6], 12, { rowH: 0.62 });
  bullets(s, [
    "始めの置き方: その姿勢で形のいちばん低い点が床から 1 mm 上になる高さに置く",
    "関節の可動範囲: 端（ストップ）は範囲より 1° 外、サーボの目標は範囲の中に収める（端に押し付けると軽いリンクで発散するため。h7 の指で起きた）",
  ], 0.6, 5.85, 12.1, 1.0, 12.5);
}
{
  const s = slide("CONTENT", "サーボの制御と時間の進め方（odesim.cpp）", "odedyna の motor-module → d-joint-servo と同じ。全環境で同じコード（Swift はブリッジ、EusLisp は defforeign、Kotlin は JNI で呼ぶ）。");
  code(s, [
    "// 毎ステップ（dt = 0.01 s）",
    "for (auto &j : s->joints) {",
    "  if (j.mode == 1) { v = 20 * j.target / M_PI; f = 1e6; }  // 車輪",
    "  else if (s->servo) {",
    "    v = j.kp * (j.target - jvalue(j));   // 角度の差に比例した速さ",
    "    v = clamp(v, -j.vmax, j.vmax);",
    "    f = j.fmax;                          // 力の上限",
    "  } else f = min(j.fmax * 0.01, 0.05);   // 脱力（0.05 N·m まで）",
    "  dJointSetHingeParam(j.j, dParamVel, v);",
    "  dJointSetHingeParam(j.j, dParamFMax, f);",
    "}",
    "dSpaceCollide(space, s, near_cb);        // 床との接触を作る",
    "dWorldStep(world, dt);                   // quickstep は使わない",
    "dJointGroupEmpty(contacts);",
  ].join("\n"), 0.6, 1.35, 7.3, 5.0, 12);
  table(s, [["呼び出し側", "つなぎ方"],
    ["iPhone・Mac（Swift）", "Bridging.h で C の関数を直接"],
    ["Ubuntu（EusLisp）", "libeusviewode.so を defforeign。float-vector を double* で渡す"],
    ["Android（Kotlin）", "JNI（NDK でビルドした .so）"]],
    8.2, 1.35, 4.55, [1.9, 2.65], 11.5, { rowH: 0.62 });
  bullets(s, [
    "画面のコマ（1/60 s）ごとに、たまった時間ぶん dt で進める（端数は次へ）",
    "毎コマ、各リンクの位置姿勢を ODE から読んで 3D を更新",
    "発散（数でない・100 m 先）を見つけたら止める",
  ], 8.2, 4.1, 4.55, 2.7, 12);
}

// =====================================================================
section("5. 物理パラメータ");
{
  const s = slide("SECTION", "物理パラメータを変えると");
  s.addText("摩擦・関節のやわらかさ・サーボの力で、ロボットの立ち方・歩き方がどう変わるか（動画）", { placeholder: "body" });
  tile(s, 0.9, 2.75, "5", C.accent1, 1.2);
}
{
  const s = slide("CONTENT", "物理パラメータの一覧と今の値", "eusdyna の値から変えたのは 3 つ。変えた理由は次のページ以降の動画。サーボの力の上限は eusdyna の既定（実質無制限）で、KRS の公称値にもできる。");
  table(s, [["パラメータ", "eusdyna（kxr-dyna）", "EusView（今の値）", "変えた理由"],
    ["接触の摩擦 mu", "0.1", hl("0.8"), "立っているだけで滑った（3 秒で 14〜29 mm, 条件による）"],
    ["接触点の数（1 組あたり）", "1", hl("4"), "mu と一緒に変えた（どちらが効いたかは切り分けていない）"],
    ["接触のやわらかさ soft_cfm", "0.01", hl("0.001"), "接触を少し固く（調整で選んだ値）"],
    ["関節の CFM（world）", "0.01", hl("1e-5"), "SI 単位では関節が伸びて 2 cm 沈む"],
    ["接触の soft_erp / bounce", "0.2 / 0.01", "同じ", ""],
    ["時間の刻み dt", "0.01 s, dWorldStep", "同じ", ""],
    ["サーボ kp", "10 /s", "同じ", ""],
    ["サーボの力 fmax", "500000 N·m（実質無制限）", "同じ（KRS 公称 1.36 N·m も選べる）", "実機に近づけるときは公称値"],
    ["重力", "−9.81 m/s²", "同じ", ""]],
    0.6, 1.35, 12.1, [3.0, 2.7, 3.0, 3.4], 12, { rowH: 0.5 });
}
const vslide = (title, notes, name, pts) => {
  const s = slide("CONTENT", title, notes);
  video(s, name, 0.6, 1.35, 8.4, 5.55);
  bullets(s, pts, 9.3, 1.4, 3.45, 5.4, 12.5);
  return s;
};
vslide("摩擦と接触点 — 立っているだけで滑るか", "左: eusdyna の値（mu 0.1, 接触点 1）。右: 今の値（mu 0.8, 接触点 4）。同じ kxrl2l6a6h2 の立ち姿と歩行。", "cmp_friction", [
  "mu 0.1・1 点: 立っているだけで 3 秒に +14 mm 滑り、歩いたあとも後ろへ滑る（+82 → +57 mm）",
  "mu 0.8・4 点: 立っていて +0.4 mm。歩いたあとは +82 mm で止まる",
  "実機は立っているだけでは滑らないので、今の値にした",
]);
vslide("関節のやわらかさ（CFM）— 体が沈むか", "左: 関節の CFM 0.01（eusdyna の値をそのまま SI 単位で）。右: 1e-5。", "cmp_cfm", [
  "CFM は拘束をどれだけ破ってよいか。0.01 だと関節がばねのように伸び、腰が 211.5 → 192 mm と約 2 cm 沈む",
  "1e-5 にすると、ODE と EusLisp の関節の位置の差は 0.02 mm",
  "eusdyna は mm・g の単位系で同じ値を使っていたと思われる（未確認）",
]);
vslide("サーボのオン・オフ", "動画は KRS の公称トルクで計算。既定（力の上限 500000）では脱力の力（上限の 1%）が大きすぎて崩れなかったので、脱力の力を 0.05 N·m までにした（直したあと既定でも 211 → 64 mm に崩れる）。", "cmp_servo", [
  "オン: Vel = kp(目標 − 角度), FMax = fmax で姿勢を保つ",
  "オフ: 2 秒で脱力すると約 1 秒で崩れる（腰 211.5 → 55.5 mm）",
  "アプリ: 「サーボ」のトグル、Ubuntu: servo ボタン",
]);
vslide("サーボの力 — 実質無制限と KRS の公称トルク", "左: eusdyna の fmax 500000 N·m。右: KRS-3304R2 の公称 1.363 N·m・8.06 rad/s（測った値ではない）。", "cmp_torque", [
  "「逆立ち」はどちらでも成功せず倒れ、動きはほぼ同じ。終わりの位置が x +305 mm と +392 mm で違う",
  "kxrl2l6a6h2 の「起き上がり（うつ伏せ）」は無制限だと計算が発散した（アプリは発散を見つけたら止めるようにした）。公称値では発散しないが起き上がれない",
  "公称値は KRS の仕様からの値。実機で測ってはいない",
]);
vslide("物理で歩く — 動作の関節角をサーボの目標に", "kxrl2l6a6h2 の「ゆっくり歩行前（5回）」を、関節角の列をサーボの目標にして ODE で動かす。", "physics_walk", [
  "関節角は RCB4 エミュレーションの値のまま。体の位置は ODE が決める",
  "足が床を押して前に進む（1 回目で +118 mm, 2 回で +163 mm）",
  "前転・腕立て伏せのあとは倒れたままになることがある（自分どうしの当たりを見ていない、など）",
]);
{
  const s = slide("CONTENT", "いろいろなロボットを物理で", "左: 起き上がり・前転など倒れる動作。右: JSK の h7（以前は発散）や 4 脚。", "");
  video(s, "physics_fall_getup", 0.6, 1.35, 6.0, 5.5);
  video(s, "physics_jsk_h7", 6.75, 1.35, 6.0, 5.5);
}
{
  const s = slide("CONTENT", "4 脚と JSK のロボット", "左: 4 脚の kxrl4d「一定歩行前（3歩）」×3 を物理で（約 11 cm 進む）。右: sample-robot の歩行（JSON の歩行パターン、体の位置も使う）。");
  video(s, "physics_kxrl4d", 0.6, 1.35, 6.0, 5.5);
  video(s, "sample-robot-walk", 6.75, 1.35, 6.0, 5.5);
}
{
  const s = slide("CONTENT", "ロボットの一覧（KXR・KHR・JSK）", "書き出した 121 体から。KXR・KHR は kxreus（最新）、JSK は jskeus の eus/models と irteus/demo。");
  video(s, "gallery_kxr", 0.6, 1.3, 5.9, 3.0);
  video(s, "gallery_khr", 6.85, 1.3, 5.9, 3.0);
  video(s, "gallery_jsk", 0.6, 4.2, 5.9, 2.75);
  bullets(s, [
    "KXR: kxrl2l6a6h2 など 36 体（kxreus の部品から組み立てたモデル）",
    "KHR: khr3, khr20h2, khrnishio など 43 体",
    "JSK: sample-robot, h7, darwin, hanzou, akira, macra など 42 体",
  ], 6.85, 4.35, 5.9, 2.5, 13);
}

// =====================================================================
section("6. BVH の変換と移し替え");
{
  const s = slide("SECTION", "BVH の変換と移し替え（GMR + 全身 QP）");
  s.addText("人の動き（BVH）をアプリ用に変換し、関節名・GMR でロボットに移し、全身 QP で自己衝突・可動範囲・重心を直す", { placeholder: "body" });
  tile(s, 0.9, 2.75, "6", C.accent5, 1.2);
}
{
  const s = slide("CONTENT", "BVH の変換 — convert_bvh.py", "Python の標準ライブラリだけ。~/kxreus/bvh（421 本・417 MB）→ eusview/bvh/cache/（93 MB, 約 4 分）。LAFAN1・SFU は非商用・改変禁止なので、BVH も変換したものも git には入れない。");
  table(s, [["種類", "本数", "関節", "fps", "長さ", "単位", "変換後"],
    ["lafan1", "77", "22", "30", "4.6 時間", "cm", "71.8 MB"],
    ["mocopi", "9", "27", "24", "8.1 分", "cm", "5.7 MB"],
    ["rikiya", "300", "18", "15〜30", "33.6 分", "inch", "8.0 MB"],
    ["sfu", "15", "25", "120 → 30", "3.7 分", "inch", "1.1 MB"],
    ["tum-kitchen", "20", "28", "25", "24.4 分", "mm（Z が上）", "6.7 MB"]],
    0.6, 1.3, 7.2, [1.4, 0.7, 0.7, 1.0, 1.1, 1.3, 1.0], 11.5, { rowH: 0.4 });
  code(s, [
    "python3 eusview/bvh/convert_bvh.py      # 全部",
    "python3 eusview/bvh/convert_bvh.py --kinds mocopi sfu",
    "",
    "# .ebvh = \"EBVH\" + ヘッダの長さ + JSON のヘッダ",
    "#   （関節・親・OFFSET・チャンネルの順・fps・照合値）",
    "#   + コマ: 位置 int32（0.1 mm）, 回転 int16（0.01°）",
    "# index.json: 種類ごとのファイル・コマ数・秒数",
  ].join("\n"), 0.6, 4.0, 7.2, 2.85, 11);
  bullets(s, [
    "回転: 関節のローカル = T(位置)·R(ch1)·R(ch2)·R(ch3)（チャンネルの順は何でも可）",
    "位置: 位置のチャンネルがあればその値（OFFSET を置き換える, Blender と同じ）。jskeus は「足す」ので lafan1 の腰が 2 倍の高さになる",
    "上の軸: Y が上 → Z が上（jskeus の rikiya-bvh-robot-model と同じ回転）、tum は Z が上のまま",
    "単位: 背の高さが 1.7 m に近い mm / cm / inch / m を種類ごとに選ぶ",
    "床: 全コマのいちばん低い点を z = 0 に。30 fps を超えるものは間引く",
    "確認: アプリ（Swift / Kotlin）の順運動学と 421 本で 0.009 mm 以内。jskeus の load-mcd と sfu で 0.0005 inch 以内",
  ], 8.1, 1.3, 4.65, 5.6, 11.5);
}
{
  const s = slide("CONTENT", "ロボットへの移し替え — 2 つの方法", "表 eusview/bvh/retarget_tables.json を iPhone・Mac・Android・デスクトップが共有。kxreus 版（eusview-retarget.l）は同じ考え方を EusLisp で。");
  box(s, 0.6, 1.3, 2.6, 1.3, "BVH の骨格", "関節のローカルの回転\n腰の位置・向き", C.background2);
  box(s, 3.8, 1.3, 4.0, 1.3, "方法 1: 関節名で対応", "kxreus bvh-demo.l の :copy-state-to と同じ。\n肩・肘・股・膝… の回転を\n<limb>-<joint>-r/p/y に写す", C.accent2, C.background1);
  box(s, 3.8, 2.8, 4.0, 1.3, "方法 2: GMR", "体節ごとに縮めた手首・肘・足首・膝の\n位置と向きを目標に、手足ごとの IK", C.accent1, C.background1);
  box(s, 8.4, 2.8, 4.35, 1.3, "方法 2 + 全身 QP（wbqp）", "自己衝突・関節の可動範囲・\n重心が足の上、を満たすように直す", C.accent4, C.background1);
  arrow(s, 3.2, 1.95, 3.8, 1.95); arrow(s, 3.2, 2.2, 3.8, 3.45); arrow(s, 7.8, 3.45, 8.4, 3.45);
  table(s, [["種類", "写す BVH の関節（左腕・左脚の例）", "r, p, y ←", "注意"],
    ["rikiya", "LeftCollar / LeftShoulder / LeftElbow / LeftWrist, LeftHip / LeftKnee / LeftAnkle", "w[2], w[0], w[1]", "軸が負なら反転して持ち越す（bvh-demo.l）"],
    ["mocopi", "l_up_arm / l_low_arm / l_hand, l_up_leg / l_low_leg / l_foot", "w[2], w[0], w[1]", "6 チャンネルの関節は回転の 3 つだけ"],
    ["sfu", "LeftShoulder（鎖骨）/ LeftArm / LeftForeArm, LeftUpLeg / LeftLeg / LeftFoot", "w[2], w[0], w[1]", ""],
    ["lafan1", "LeftShoulder / LeftArm / LeftForeArm, LeftUpLeg / LeftLeg / LeftFoot", "w[0], w[1], w[2]", "初期姿勢が回っているので「コマ 0 との差 + reset-pose」"],
    ["tum-kitchen", "（kxreus に :copy-state-to がない）", "—", "GMR だけ"]],
    0.6, 4.35, 12.15, [1.3, 5.6, 1.6, 3.65], 10.5, { rowH: 0.42 });
}
{
  const s = slide("CONTENT", "GMR の手順（小さなロボット向けに簡単にしたもの）", "GMR: Araujo, Ze ほか（2025）「Retargeting Matters: General Motion Retargeting for Humanoid Motion Tracking」。体の部位の対応・部位ごとのスケール・IK で人の動きを移す。");
  const steps = [
    ["1", "部位の対応", "腰・胸・頭、左右の肩・肘・手首、股・膝・足首を、人（BVH）とロボット（関節名 <limb>-<joint>）で対応させる"],
    ["2", "体節ごとのスケール", "肩→肘→手首、股→膝→足首の長さの比で、人の位置を縮める（胸・腰から見た向きはそのまま）"],
    ["3", "腰", "向き = 人の骨盤の回転（コマ 0 との差）、水平 = s_leg × 人の腰、高さ = 低い方の足首を床に"],
    ["4", "手足ごとの IK", "減衰付き最小二乗（λ 0.05, 1 コマ 10 回まで, 1 回 20° まで, 可動範囲で切る）。重み: 手首・足首 1, 肘・膝 0.3, 足の向き 0.6"],
    ["5", "解き直し", "目標から手足の長さの 15% より離れたら reset-pose から解き直して近い方を使う"],
    ["6", "胴と頭", "向きだけを合わせる。手首の向きは合わせない（手首の関節は reset-pose に弱く引く）"],
  ];
  steps.forEach(([n, t, d], i) => {
    const y = 1.3 + i * 0.92;
    tile(s, 0.6, y + 0.1, n, [C.accent1, C.accent2, C.accent3, C.accent4, C.accent5, C.accent6][i]);
    para(s, [{ text: t, options: { bold: true, fontSize: 14, breakLine: true } }, { text: d, options: { fontSize: 12, color: C.accent6 } }], 1.2, y, 7.0, 0.85);
  });
  shot(s, "sim_bvh_all", 8.5, 1.3, 4.25, 5.6);
}
{
  const s = slide("CONTENT", "全身 QP（wbqp）の定式化 — mc_rtc と同じ考え方", "コードは自前（C++17 の標準ライブラリだけ）。mc_rtc の Tasks（タスクの重み付き最小二乗 + 不等式制約）と CollisionConstraint（速度ダンパ）の考え方を、小さなロボット向けに。");
  code(s, [
    "変数 x = [ dp(3), dω(3), dq(n), s ≥ 0 ]   ルートの並進・回転, 関節角の変化, 緩め",
    "",
    "最小化   Σ w_i² ‖J_i x − e_i‖²  +  w_reg ‖x‖²  +  w_slack ‖s‖²",
    "",
    "制約     q_lo + 2° ≤ q + dq ≤ q_hi − 2°            関節の可動範囲",
    "         |q + dq − q_prev| ≤ v_max · dt            関節の速さ",
    "         z(足の裏の頂点) ≥ 0                        床より上",
    "         nᵀ(J_a − J_b) x + s ≥ −ξ (d − d_s)         自己衝突（速度ダンパ）",
    "         mᵀ(c + J_c x)_xy ≤ b − margin + s          重心が支持多角形の中",
    "",
    "1 コマに逐次 QP を 3 回（ヤコビアンは解析的に: 軸 × (点 − 関節)）",
  ].join("\n"), 0.6, 1.3, 7.6, 4.1, 11.5);
  table(s, [["タスク", "誤差", "重み"],
    ["関節角を GMR に", "q_ref − q", "1"],
    ["手首の位置", "(p* − p) / L", "2"],
    ["浮いた足の位置・向き", "(p* − p) / L, log", "3 / 1"],
    ["床に着いた足を止める", "止めた位置・向きとの差", "30 / 10"],
    ["ルートの向き・位置", "log(R_ref Rᵀ), Δp / L", "2 / 0.5"],
    ["緩め", "s", "1e6"]],
    8.45, 1.3, 4.3, [1.75, 1.75, 0.8], 10.5, { rowH: 0.42 });
  bullets(s, [
    "L = 脚の長さ（KXR 0.212 m, KHR 0.296 m, sample-robot 0.713 m）で割り、ロボットの大きさによらない重みにする",
    "解けないときは前のコマの答えを使う（実際には「解けない」は 0 件）",
  ], 0.6, 5.6, 12.15, 1.25, 12);
}
{
  const s = slide("CONTENT", "制約の中身 — 自己衝突・重心・接地", "パラメータは名前で変えられる（wbqp_set_param）。値は既定。");
  head(s, 0.6, 1.3, 6.0, "A", "自己衝突（カプセル）", C.accent1);
  bullets(s, [
    "リンクのメッシュの頂点の主成分から作る。箱の形の部品は断面を 1×1 / 2×1 / 2×2 に分け、頂点の 80% を覆う半径（KXR 46 個, KHR 36 個）",
    "調べない組: 木で 2 つ以内のリンク、関節角 0 と reset-pose で当たっている組（KXR 879 組を調べる）",
    "影響の距離 0.15 L より近い組だけ、近い順に 24 組。d_s = 0.01 L, ξ = 0.5",
  ], 0.6, 1.8, 6.0, 2.5, 11.5);
  head(s, 6.85, 1.3, 5.9, "B", "重心と支持多角形", C.accent4);
  bullets(s, [
    "足の裏 = 足のリンクのいちばん低い頂点の凸包（8 頂点まで）",
    "支持多角形 = 支える足の裏の凸包を 余裕 だけ内側に。重心の床への投影がその中",
    "質量・重心は JSON の physics（eusdyna と同じ作り方）",
    "ZMP の制約も試したが、先読みなしでは発散したので既定はオフ",
  ], 6.85, 1.8, 5.9, 2.5, 11.5);
  head(s, 0.6, 4.4, 12.15, "C", "接地と先読み", C.accent2);
  bullets(s, [
    "参照（GMR）の足の裏の高さ < 0.04 L で着く、> 0.08 L で離れる（ヒステリシス）。着いた足は水平にして、その位置で止める",
    "8 コマ先までずっと着いている足だけで支える（片足を上げる前に、重心を残る足に移しておく）",
    "止めた足と参照の足のずれ δ だけ、手・浮いた足・ルートの目標もずらす（足がすべらない分、全体が参照からずれる）",
  ], 0.6, 4.9, 12.15, 1.95, 11.5);
}
{
  const s = slide("CONTENT", "QP を解く — Goldfarb–Idnani 法と共通の C の層", "QP ソルバは Goldfarb & Idnani（1983）の双対有効制約法を論文から書いた（LGPL・GPL のコードは使っていない）。3000 個のでたらめな QP で、有効制約の全組み合わせの答えと一致。");
  code(s, [
    "WbQP *h = wbqp_create();",
    "wbqp_add_link(h, parent, rest12);           // リンク（根元から）",
    "wbqp_add_link_vertices(h, i, xyz, nv);      // カプセルを作る頂点",
    "wbqp_set_link_mass(h, i, mass, com);",
    "wbqp_add_joint(h, link, type, axis, lo, hi, vmax);",
    "wbqp_set_hand(h, 0, link, offset);  wbqp_set_foot(h, 0, link);",
    "wbqp_finalize(h, reset_pose, 1);            // 当たっている組を除く",
    "",
    "for (each frame)",
    "  wbqp_solve(h, q_ref, root_ref, contact, support,",
    "             NULL, q_out, root_out, &diag);",
    "wbqp_eval(h, q, root, support, &ev, flags, poly, 32);  // 違反の表示",
  ].join("\n"), 0.6, 1.3, 7.3, 4.3, 11);
  table(s, [["環境", "呼び方"],
    ["iPhone・Mac", "Swift（ブリッジ）WholeBodyQP.swift"],
    ["Android・デスクトップ", "Kotlin（JNI）WholeBodyQp.kt"],
    ["kxreus（irteusgl）", "EusLisp（defforeign）eusview-qp.l"]],
    8.2, 1.3, 4.55, [1.9, 2.65], 11, { rowH: 0.48 });
  bullets(s, [
    "Swift と Kotlin の答えの差: 関節角 0.0002° 以下、ルート 0.001 mm 以下",
    "時間: Mac 0.3〜1.6 ms/コマ、iPhone 0.85 ms/コマ（lafan1 dance1 × KXR 3945 コマを 3.8 秒）",
    "表示: 衝突のリンクは赤、可動範囲の端は橙、重心の球と床の投影、支持多角形（緑 = 中, 赤 = 外）",
  ], 8.2, 3.45, 4.55, 3.4, 11.5);
}
{
  const s = slide("CONTENT", "QP の前と後 — 違反の割合と追従のずれ", "Mac の qptest（全部のコマ）。前 → 後 = GMR → GMR + QP。判定はカプセル（少し太め）なので「GMR の衝突」は実際より多めに出る。");
  table(s, [["BVH × ロボット", "コマ", "QP ms/コマ", "自己衝突", "可動範囲の端", "重心が外", "関節のずれ 平均 / 95%"],
    ["mocopi greeting1 × KXR", "946", "0.65", "7.1% → 0%", "0 → 0", "0 → 0", "1.1° / 5.4°"],
    ["rikiya A01 × KXR", "131", "0.81", hl("100% → 1.5%"), "0 → 0", "0 → 0", "3.2° / 13.5°"],
    ["sfu Walking × KXR", "1173", "0.63", "46% → 3.6%", "0 → 0", "0 → 0", "3.5° / 16°"],
    ["lafan1 dance1 × KXR", "3945", "1.35", "89% → 12%", "3.0% → 0", "11% → 19%（増）", "29° / 115°"],
    ["rikiya A01 × KHR", "131", "0.37", "7.6% → 0%", "0 → 0", "2.3% → 0", "5.1° / 17°"],
    ["sfu Walking × KHR", "1173", "0.39", "0 → 0", "0 → 0", hl("9.8% → 0"), "5.0° / 17°"],
    ["lafan1 dance1 × KHR", "3945", "0.65", "42% → 16%", "27% → 0", "24% → 6%", "24° / 98°"],
    ["lafan1 fallAndGetUp1 × KHR", "5047", "0.76", "45% → 19%", "31% → 0", "49% → 11%", "34° / 125°"]],
    0.6, 1.3, 12.15, [3.0, 0.8, 1.2, 1.75, 1.6, 1.75, 2.05], 11, { rowH: 0.46 });
  bullets(s, [
    "可動範囲の端に来るコマは全部 0 に。歩く・挨拶では自己衝突と重心の違反がほぼなくなり、関節のずれは数度",
    "lafan1 の踊り・転んで起きる動きは、手をつく・寝転ぶ・跳ぶので「足の裏で支える」前提に合わない。腕が体をすり抜ける参照では局所の QP は反対側に引っかかる",
  ], 0.6, 5.65, 12.15, 1.25, 11.5);
}
{
  const s = slide("CONTENT", "物理（ODE）で再生すると倒れにくくなるか", "関節角の列をサーボの目標にして再生（アプリの既定のサーボ）。腰の傾きが 60° を超えたら「倒れた」。左: デスクトップ版の BVH の画面（棒人形・関節名・GMR・GMR+QP と違反の表示）。");
  shot(s, "desk_bvh_all", 0.6, 1.3, 6.4, 5.6);
  table(s, [["BVH", "KXR GMR → +QP", "KHR GMR → +QP"],
    ["mocopi greeting1", "0.6 → 0.6 秒", hl("0.8 秒 → 倒れない")],
    ["rikiya A01（歩く）", hl("0.3 秒 → 倒れない"), hl("0.1 秒 → 倒れない")],
    ["sfu Walking", "0.5 → 5.9 秒", "0.6 → 0.9 秒"],
    ["lafan1 dance1", "5.2 → 0.0 秒（悪化）", "5.3 → 21 秒"]],
    7.25, 1.3, 5.5, [1.9, 1.8, 1.8], 11, { rowH: 0.5 });
  bullets(s, [
    "立つ・ゆっくり歩く動きでは倒れにくくなった",
    "KXR の挨拶は最初に急におじぎするので、重心の位置だけの制約では足りない（動きの勢い = ZMP が要る）",
    "kxreus 版（EusLisp の GMR）でも同じ QP で: greeting1 × KHR 衝突 27% → 0.2%、rikiya × KHR 重心 21% → 0%",
  ], 7.25, 4.0, 5.5, 2.85, 11.5);
}
{
  const s = slide("CONTENT", "BVH の画面 — iPhone と kxreus（irteusgl）", "左: iPhone（シミュレータ）で rikiya A01 × KXR。右: kxreus の EusView（irteusgl, Mac の XQuartz）で greeting1 × KXR、GMR の衝突は赤、QP は衝突なし。");
  shot(s, "sim_bvh_rikiya", 0.6, 1.3, 2.95, 5.35);
  shot(s, "eus_bvh_qp", 3.85, 1.3, 8.9, 5.6);
}

// =====================================================================
section("7. まとめ");
{
  const s = slide("CONTENT", "これまでの経過と残っていること", "日付はすべて 2026-10-05。BVH の再生は 4 つの環境とも入れた（Ubuntu 版は Mac の XQuartz で確認）。GitHub は inabajsk/kxreus（master, eusview/。初めは inabajsk/mnist の cuda-backend で作った）。");
  table(s, [["", "状態"],
    ["iPhone（iPhone 16 Pro）", "ビルド・インストール・表示・動作・物理・live を確認"],
    ["Mac（Mac Catalyst）", "~/Applications に入れて確認"],
    ["Ubuntu（kxreus の EusView）", "Mac の XQuartz で確認。Ubuntu の実機では未確認"],
    ["Android（Pixel 7a）", "ビルド・インストール・表示・動作・物理・live を確認（物理の計算 1.5〜6 ms/コマ）。2 本指の操作は未確認"],
    ["デスクトップ版（統合ウインドウ）", "Mac で確認（Compose Desktop）。Ubuntu の実機では未確認"],
    ["BVH・GMR・全身 QP", "4 環境 + kxreus で再生・移し替え・QP。lafan1 の踊り・寝転ぶ動きは QP でも違反が残る"],
    ["ロボット", "121 体（KXR 36・KHR 43・JSK 42）。KHR の -cad 版は元のファイルがなく未対応"],
    ["物理", "eusdyna の作り方 + 摩擦・接触点・CFM を調整。自分どうしの当たりは未対応"]],
    0.6, 1.35, 12.1, [3.4, 8.7], 12, { rowH: 0.52 });
  bullets(s, [
    "次の候補: Ubuntu 実機での確認、ZMP（先読み）を入れた QP、ロボットどうしの当たり、実機 KXR の関節角を live で映す",
  ], 0.6, 6.15, 12.1, 0.75, 13);
}
{
  const s = slide("TITLE_DARK", "まとめ");
  const T = [
    "jskeus・kxreus のロボット 121 体を JSON にし、iPhone・Mac・Android のアプリと Ubuntu の kxreus デモで同じように表示できるようにした",
    "KXR・KHR の動作は RCB4 エミュレーションの関節角の列で再生し、EusLisp からの live でも動かせる",
    "物理は eusdyna と同じ考え方の ODE の C の層を全環境で共有。摩擦 0.8・接触点 4・関節 CFM 1e-5 で、立っていて滑らず歩けば進む",
    "BVH は関節名か GMR でロボットに移し、全身 QP で自己衝突・可動範囲・重心を直す。歩く・挨拶はほぼ違反なし、物理でも倒れにくくなった",
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
  fs.writeFileSync(OUT, await zip.generateAsync({ type: "nodebuffer", compression: "DEFLATE" }));
  console.log("wrote", OUT);
})();
