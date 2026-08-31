# edge_impulse — 音声コマンド認識モデルと学習データ

`../atom_s3_robot/atoms3_i2c_robot.ino`が使う、Edge Impulseで学習した
キーワード認識(音声コマンド判定)モデル一式。

## ここにあるもの

| パス | 内容 |
| --- | --- |
| `kxr-voice-commands_inferencing/` | **Edge Impulse Studioが生成したファイル本体**。学習済みモデルを含むArduinoライブラリ(下記参照) |
| `ei_data/{aisatsu,mae,ushiro,hidari,migi,noise}/` | 学習用の生録音データ(WAV、各単語ごとにフォルダ分け) |
| `collect_edge_impulse_data.py` | PC側で、ロボット側ATOM Echoから送られてくる生音声を受信してWAVとして保存する収集ツール |
| `atom_echo_voice_datacollect_robot.ino` | データ収集専用のATOM Echoファームウェア(ボタンやシリアルコマンドで単語ラベルを切り替えながら録音・PCへ送信する、`atoms3_i2c_robot.ino`とは別物) |
| `ei_label_cmd.txt` | 収集中に単語ラベルを切り替えるための「コマンドファイル」。ここに`0`-`5`の数字を1文字書き込むと(ポートを開き直さずに)`collect_edge_impulse_data.py`がロボットへラベル切替を伝える。中身の数字自体には意味は無く、直近に使っていたラベル番号が残っているだけ |

## Edge Impulseとは何をしているか

Edge Impulseは「音声(や他のセンサ波形)から特定のキーワード/クラスを
判定する小さなニューラルネットワークを、ノーコードに近い形でクラウド上で
学習し、マイコン向けC++ライブラリとして書き出せる」サービス(Studio)。
このプロジェクトでは、8kHz・1秒間の生PCM波形を入力に、6クラス
(aisatsu/mae/ushiro/hidari/migi/noise)のうちどれかを判定するキーワード
スポッティングモデルとして使っている。

## 「Edge Impulseが生成したファイル」とは何か

`kxr-voice-commands_inferencing/`フォルダそのもの。Edge Impulse Studioで
学習を終えた後、**Deploy(デプロイ)タブ → 「Arduino library」を選択して
Build**すると、学習済み・量子化済みのモデルと`run_classifier()`という
共通APIを持つC++ライブラリがzipでダウンロードされる。それを解凍して
`~/Arduino/libraries/`に置いたものが、このフォルダの中身(本リポジトリでは
`atom_s3_robot/flash.sh`が初回コンパイル時に自動で`~/Arduino/libraries/`へ
コピーする。`arduino-cli compile --library <path>`で直接指定する方法もあるが、
`~/Arduino/libraries/`に同名ライブラリが既にあると「Multiple libraries were
found」となりESP-NNのビルドキャッシュが壊れてリンクエラーになることを実機
確認したため、このプロジェクトでは使っていない)。中身は概ね:

- `library.properties` — Arduinoライブラリのメタ情報
- `src/` — モデル本体(量子化済み重み)・特徴量抽出・推論ランタイム(EON Compiler等)
- `examples/` — Edge Impulse側が用意したサンプルスケッチ(このプロジェクトでは未使用)

`atoms3_i2c_robot.ino`は`#include <kxr-voice-commands_inferencing.h>`で
このライブラリを取り込み、`run_classifier()`を呼んで判定結果
(`ei_impulse_result_t`、各クラスの確信度)を得ている。

## 新しい単語を追加する手順

1. **録音**: `atom_echo_voice_datacollect_robot.ino`をATOM Echoに書き込み、
   `collect_edge_impulse_data.py --port /dev/ttyUSBx`を起動。ロボット側へ
   ラベル切替コマンド(`ei_label_cmd.txt`へ数字を書き込むか、直接シリアルへ
   `0`-`5`等を送る)を送りながら、複数話者・複数距離・複数音量で数十回以上
   発話を録音する(新しい単語を増やす場合は、ロボット側ファームの
   ラベル一覧・録音対象を増やす修正も必要)。
2. **アップロード**: Edge Impulse Studioの該当プロジェクトに、録音した
   WAVを新しいラベルとしてアップロードする(Data acquisitionタブ)。
3. **再学習**: Impulse design → 特徴量抽出(MFE/Spectral等、既存設定を踏襲)
   → 分類器を、新しいクラスを含めて再学習する(Train impulse)。
4. **精度確認**: Model testingタブの混同行列(confusion matrix)で、新しい
   単語が他の単語と混同されていないか確認する。
5. **再エクスポート**: Deployタブから再度「Arduino library」でビルドし、
   このフォルダの`kxr-voice-commands_inferencing/`を新しいものに丸ごと
   置き換える。
6. **ファームウェア側の対応**: `../atom_s3_robot/atoms3_i2c_robot.ino`の
   `WORD_MOTIONS[]`テーブルに新しいラベル→`call-motion`番号の対応を追加し、
   `EI_CLASSIFIER_RAW_SAMPLE_COUNT`(サンプル数、学習設定を変えていなければ
   8000のまま)の`static_assert`が通ることを確認してから再コンパイル・
   再書き込みする(`../atom_s3_robot/flash.sh`)。

## 認識率を上げるには

現状(2026.8時点)の検証精度は約77.4%で、`atoms3_i2c_robot.ino`側の
確信度しきい値(`CONFIDENCE_THRESHOLD=0.6`)はこれを踏まえて設定している。
改善の一般的な方向性(Edge Impulseの標準的な運用知識。このリポジトリで
実証済みというわけではない):

- **各クラスのサンプル数・多様性を増やす**: 話者・発話距離・声量・
  周囲ノイズ条件を変えて録音する。特に実運用時に近い条件(ロボット周辺の
  環境音がある状態)のサンプルを増やすと効果が大きい。
- **noiseクラスを充実させる**: 実運用時に鳴る可能性のある環境音
  (モーター音、他の話し声、無音)を`noise`クラスとして十分な量録音して
  おかないと、誤発火(何もしていないのに単語と誤認識)が増える。
- **クラス間のサンプル数バランス**: 極端に少ないクラスがあると、そのクラスの
  再現率が落ちやすい。
- **混同行列で弱点を特定**: Model testingタブでどの単語同士が混同されやすいか
  確認し、その組み合わせを重点的に録音し直す。
- **それでも頭打ちなら**: Impulse designのウィンドウサイズ/ウィンドウ増分や、
  NNアーキテクチャ(層数・ユニット数)を調整する。ただしまずはデータの
  量・質の改善を優先する方が効果的なことが多い。
