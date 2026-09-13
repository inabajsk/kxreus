# m5UnitV — M5Stack UnitV(K210/MaixPy)版 AprilTag/物体検出ファームウェア

`../m5stickv/`と同じ`object_detection_I2C_slave.py`をそのまま使う(コピーであり、
2026.9時点で差分なし)。この1ファイルが実機のI2C1バス(LCD用, scl=28/sda=29)を
起動時にスキャンし、応答がなければUnitVと自動判定(`is_m5unitv`)して以下を
切り替える:

- LCD初期化をスキップ(UnitVにLCDは無い)
- カメラを上下反転(`sensor.set_vflip(1)`) -- UnitVはStickVと実装の向きが違う
- 起動時にWS2812 LEDを一瞬青く点灯 -- UnitV側の「起動しました」インジケータ

ホスト(M5Stack FIRE / AtomS3)向けの外部I2Cスレーブインターフェース
(`I2C.I2C0`, scl=34/sda=35, レジスタマップ、AprilTag/NN/色物体検出、
I2Cアドレス0x24・0x25の使い分け)はStickV/UnitVで全く同じ。詳細は
`../m5stickv/README.md`のI2Cレジスタマップの節を参照。

## m5stickvとの違い

- **LCD無し**: UnitVは画面を持たないため、StickV版で画面に出していた
  情報(検出結果のオーバーレイ、ルービックキューブのスウォッチ表示等)は
  実機上では見えない。I2C経由でホスト(FIRE等)側に渡る検出データ自体は
  変わらない。
- **内蔵スピーカー無し**: `object_detection_I2C_slave.py`はI2S出力の初期化を
  無条件に行う(board_infoの定義はStickV系ファームウェア共通のため実行は
  失敗しない)が、UnitVには物理的にスピーカーが無いため単に無音になるだけ。
  このため`flash.sh`はStickV版と違いWAVクリップを一切書き込まない
  (`sd_clips/`もこのディレクトリには置いていない)。
- **ボタン無し**: StickV側にあった物理ボタンはUnitVには無い。この
  ファームウェアはそもそもボタン入力を使っていないため影響なし。

## 書き込み

```bash
./flash.sh /dev/ttyUSB0 0x25   # M5Stack FIRE/AtomS3側のM5STICKV_DEFAULT_ADDRと同じ既定値
```

## 動作確認(2026.9)

実機で`I2C ID 0x25` / `device: unitv` / `find ov7740`まで起動を確認済み。
M5Stack FIRE側からのI2C経由AprilTag検出は、FIRE側の配線トラブル
(M5StickV個体の異常発熱・USB過電流)対応中のため未検証。配線を再確認して
から、FIRE側のSTATUS画面(`drawAprilTag()`)で確認すること。
