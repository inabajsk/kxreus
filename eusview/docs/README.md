# EusView のスライド

- `eusview.pptx` : EusView（iPhone / Mac / Ubuntu / Android, ODE, BVH）の開発と使い方のスライド
- `build_eusview.js` : スライドを作るスクリプト（pptxgenjs）
- `eusview_media/` : スライドに入れる動画（mp4）と表紙の画像（png）, `media.json`（動画の一覧と説明）。
  `../ios/tools/make-videos.py` で作る（`../ios/tools/rendervideo.swift`, 物理の比較など）
- `logs/eusview_media/` : 動画を作ったときのログ（記録用）

## 作り直し方

```
cd eusview/docs
npm install                       # pptxgenjs, jszip（node_modules は git に入れない）
SKILL_DIR=<pptx スキルのディレクトリ> node build_eusview.js     # → eusview.pptx（出力先を引数で変えられる）
```

- `SKILL_DIR` の `scripts/apply_theme.js`（Claude の pptx スキル）でテーマを当てる。
- 動画と表紙は `eusview_media/` から読む。フォントは BIZ UDPGothic（コードは BIZ UDGothic）。
- 同じものができることは, 作り直した pptx を展開して比べて確かめた（違いは作った日時とセクションの id だけ）。
- もとは inabajsk/mnist（cuda-backend）の `docs/eusview.pptx`, `docs/src/build_eusview.js` にあったものを移した（2026-10-06）。
