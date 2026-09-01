;;;
;;; atominterface.l -- ATOM Echo / AtomS3 / M5StickV 拡張
;;;
;;; rcb4interface.l(GitHub HEAD相当、汎用RCB4通信部分)を拡張し、ATOM Echo/
;;; AtomS3経由のESP-NOW無線ブリッジおよびM5StickV(IMU、ルービックキューブ
;;; 面検出、AprilTag、NN物体検出、発話)に依存する機能をすべてここへ分離
;;; RCB4/RCB4-miniのUARTは信号反転UARTのため通常のUSBシリアルアダプタがその
;;; ままでは使えない。AtomS3/AtomEchoなどでは、UARTの設定で信号反転設定が
;;; 可能で、それを用いると直接G1,G2,G5,G6などのポートをRCB4ボードのシリアル
;;; ポートへ接続して通信が可能となる。電圧が3.3Vと5Vと異なるが通信は可能。
;;;
;;; ここでは、
;;; PC-<USBC>-ATOMEcho-<ESP-NOW無線>-AtomS3-<UART G5,G6>-RCB4
;;; 　　　　　　　　　　　　　　　　　　　 -<I2C>-M5StickV 0x24
;;; 　　　　　　　　　　　　　　　　　　　 -<I2C>-M5StickV 0x25
;;; の構成で、PCとロボットの間を無線化することができ、簡易音声認識・発話
;;; ロボットIMU, M5StickVステレオ、機能をロボットに搭載する例となっている。
;;;
;;; atominterface.lの中で、:timer-onすると、M5StickVで検出した顔、NN、Apriltag,
;;; ルービックキューブ、ルービックキューブの操作時９面認識などの機能を
;;; euslispからON/OFF利用できる。ATOMS3は、IMUを持っており、その値を得て
;;; :timer-onでのロボットモデルの姿勢をMadgwickフィルタで表示する。
;;; apriltag, 顔などもcubeやcylinderをirtviewerに表示する。
;;; これらの実装には、RCB4のコマンドを拡張したRCB4命令を設けることで行っている。
;;; 横取りをして、
;;;
;;;   (load "rcb4robots.l")
;;;   (require :atominterface)
(require :rcb4interface)
;;;
;;; 【2026.9】以前ここで、無線経由の1バイト欠落によるハング対策として
;;; rcb4interface-debug.l(:read-dataへのタイムアウト+リシンク)の読み込みと
;;; :read-strへの独自リトライを追加していたが、実際の恒久的な無応答の原因は
;;; 別にあった(下記:viewer-update等のresponse-on復元忘れ)。リトライ/
;;; タイムアウト層を足すとリトライ中である旨のメッセージが常時出て挙動が
;;; 分かりにくくなるため撤去し、GitHub版rcb4interface.l/uart.lそのまま
;;; (静かでリトライ無し)の挙動に戻す。ROMテーブル全読み出し中に稀な1バイト
;;; 欠落で:read1が無限待ちする可能性自体は残るが、頻発していた恒久停止は
;;; 下記のresponse-on修正が原因だったため、まずはそちらの効果を確認する。
;;;
;;; 【2026.9、根本原因】GitHub版の:viewer-update/ri-update/ri-balance-update
;;; (いずれも:timer-on/:balance-onが毎tick呼ぶ)は、更新の最初に
;;; (:set-sysreg-bits '((:rom-on . 0) (:response-on . 0)))でRCB4からの応答を
;;; 止めるが、更新の最後は(:set-sysreg-bits '((:rom-on . 1)))とrom-onしか
;;; 戻しておらず、response-onを1へ戻し忘れている。:set-sysreg-bitsの
;;; :gen-sysreg-wordは「現在のsysreg値を読んでから指定ビットだけ変更する」
;;; 実装のため、response-onが一度0になった後は、まさにその「現在値を読む」
;;; こと自体が応答をもらえず失敗し、response-onは0のまま二度と戻らない。
;;; 結果、:read-analogは元よりRCB4への単純な:ackすら以後永久に無応答になる
;;; (実機確認、2026.9: make-kxr-robot直後は正常なのに:timer-onを実行した
;;; 瞬間から全RCB4通信が完全に無応答になる不具合として顕在化。ESP-NOW無線
;;; リンク自体は生きたまま(LEDは変化しない)なので、無線の切断/再送の問題
;;; ではなくRCB4側のsysreg状態の問題だった)。GitHub版(rcb4interface.l)
;;; 自体は変更しない方針のため、response-onも正しく1へ戻す版に差し替える。
(defmethod rcb4-interface
  (:viewer-update
   nil
   (when com-port
     (send self :set-sysreg-bits '((:rom-on . 0) (:response-on . 0)))
     (send self :real-orientation)
     (send self :read-sensors)
     (send robot :angle-vector (send self :read-angle-vector))
     (send self :set-sysreg-bits '((:rom-on . 1) (:response-on . 1))))
   (when (send self :viewer)
     (send self :viewer :viewer :draw-objects :flush nil)
     (send self :draw-torque :flush nil :size 1.0)
     (send self :draw-sensors :flush nil)
     (send self :draw-end-coords :flush nil)
     (send self :draw-zmp-coords :flush nil)
     (send self :viewer :viewer :flush))))
;; ri-update/ri-balance-update(:timer-on/:balance-onにfuncとして明示的に
;; 渡した場合のみ使われるプレーン関数版)も同じ理由で上書きする。
(setf (symbol-function 'ri-update)
      #'(lambda (ri)
	  (let (robot vwer)
	    (setq robot (send ri :robot))
	    (send ri :set-sysreg-bits '((:rom-on . 0) (:response-on . 0)))
	    (send ri :robot :angle-vector (send ri :read-angle-vector))
	    (send ri :real-orientation)
	    (when (send ri :viewer)
	      (setq vwer (send ri :viewer :viewer))
	      (send vwer :draw-objects :flush nil)
	      (send robot :draw-torque vwer
		    :torque-vector (send ri :read-torque-vector)
		    :flush nil :size 1.0)
	      (send ri :set-sysreg-bits '((:rom-on . 1) (:response-on . 1)))
	      (send ri :viewer :flush)))))
(setf (symbol-function 'ri-balance-update)
      #'(lambda ()
	  (let* ((ri (send *robot* :ri))
		 (vwer ((send ri :viewer) . x::viewer))
		 (robot (send ri :robot))
		 r p-r)
	    (send *irtviewer* :draw-objects :flush t)
	    (send ri :set-sysreg-bits '((:rom-on . 0) (:response-on . 0)))
	    (send robot :angle-vector (send ri :read-angle-vector))
	    (send ri :real-orientation)
	    (setq r (robot . rot))
	    (setq p-r (car (rpy-angle r)))
	    (send robot :legs :ankle-p :joint-angle (rad2deg (elt p-r 0)))
	    (send robot :legs :ankle-r :joint-angle (rad2deg (elt p-r 1)))
	    (send robot :legs :ankle-w :joint-angle 0)
	    (send robot :send-to-ri 20)
	    (send ri :set-sysreg-bits '((:rom-on . 1) (:response-on . 1)))
	    (send ri :viewer :draw-objects :flush t)
	    (send robot :draw-torque (send ri :viewer :viewer)
		  :torque-vector (send ri :read-torque-vector)
		  :flush nil :size 1.0)
	    (send ri :viewer :flush))))
;;;
;;; kondo-gravity-methodはATOM固有の値だが、rcb4-interfaceクラスの
;;; defclass自体はGitHub HEADのまま変更しない方針のため、クラススロットでは
;;; なくpropertied-objectのプロパティ((send self :get/:put :kondo-gravity-method))
;;; として保持する。
;;;

;; ---- ATOM Echoのデバイス自動検出(元は~/kxreus/ftdi.lにあったが、ATOM
;; Echo固有の識別ロジックなのでこちらへ移動、2026.8) ----
;; ATOM EchoとM5StickVはどちらも同一の純正FTDIチップ(idVendor=0403,
;; idProduct=6001)を使っているため、VID/PIDだけでは区別できない(実機確認、
;; 2026.8)。/dev/ttyUSB*の番号はプラグ順で変わりうる(実機で0/1/2が
;; 入れ替わる事例あり)ため、番号に頼らずこの属性ベースの検出を使うこと。
;; 製品名文字列(iProduct)はM5StickVの個体/ファームウェアによって
;; "M5stack"だったり"M5Stack Intf"だったりすることが実機比較で判明した
;; (2026.8: ATOM Echo単体接続時はproduct="M5stack"だったが、M5StickVを
;; 追加接続したらそちらがproduct="M5Stack Intf"で、ATOM Echoの方が
;; "M5stack"だった--最初は逆に思い込んでいた)。文字列だけに頼ると個体差で
;; 誤判定しうるため、シリアル番号(*atom-echo-serials*、実機で確認済みの
;; ものを追加していく)を優先して照合し、未知のシリアルの場合のみ
;; product="M5Stack Intf"(M5StickV側で確認済みの文字列)を除外する
;; フォールバックにする。
;; euslispの(position ... :from-end t)が使えないビルドがあるため、
;; パス/引用符からの値抽出はシェル側(basename/sed)で済ませる。
(defun ttyusb-devnames ()
  (let ((strm (piped-fork "ls -1 /dev/ttyUSB* 2>/dev/null | xargs -n1 basename"))
	ret v)
    (while (setq v (read-line strm nil nil))
      (push v ret))
    (reverse ret)))

(defun ttyusb-udev-attr (devname attr)
  (let* ((strm (piped-fork
		(format nil "udevadm info -a -n /dev/~A 2>/dev/null | grep -m1 'ATTRS{~A}' | sed -E 's/.*==\"([^\"]*)\"/\\1/'"
			devname attr)))
	 (line (read-line strm nil nil)))
    (when (and line (> (length line) 0)) line)))

;; 実機で確認済みのATOM EchoのFTDIシリアル番号。新しい個体を使う場合は
;; ここに追記する。
(defparameter *atom-echo-serials* '("3952C0AD8E" "055203A38E"))

(defun find-atom-echo-devname (&optional (exclude-product "M5Stack Intf"))
  (let (found fallback)
    (dolist (dev (ttyusb-devnames))
      (unless found
	(let ((vid (ttyusb-udev-attr dev "idVendor"))
	      (pid (ttyusb-udev-attr dev "idProduct"))
	      (product (ttyusb-udev-attr dev "product"))
	      (serial (ttyusb-udev-attr dev "serial")))
	  (when (and (equal vid "0403") (equal pid "6001"))
	    (cond
	     ((member serial *atom-echo-serials* :test #'equal)
	      (setq found dev))
	     ((and (null fallback) (not (equal product exclude-product)))
	      (setq fallback dev)))))))
    (or found fallback)))

;; ルービックキューブの色パレット(基準Lab値)。kxr_cube_solverのconfig.py同様、
;; 実機のキューブ・照明ごとに手動キャリブレーションが必要な値。以下は0x24
;; (左目)側で2面ぶん実測してサンプル数重み付き平均した値(2026.8)。
;; キューブ個体・照明が変わったら:m5stickv-calibrate-cube-colorで取り直すこと。
(defparameter *m5stickv-cube-colors* '((:white 67 -7 -17) (:yellow 81 -24 25)
					(:red 37 55 49) (:orange 59 38 50)
					(:blue 35 57 -90) (:green 63 -49 15)))

(defmethod rcb4-interface
  ;; ロボット側ATOM S3のIMU(MPU6886)を、RCB4の予約OPCODE(0x90)経由で読む。
  ;; ATOM S3ファームウェア側でこのリクエストを実RCB4には転送せず横取りして
  ;; IMU値を返す(atoms3_voice_ei_robot.ino の sendImuReply 参照)。
  ;; 戻り値は (:accel #f(ax ay az) :gyro #f(gx gy gz))。加速度の単位はg、
  ;; 角速度の単位はdeg/s。IMU非搭載機や通信失敗時はnilを返す。
  (:read-imu
   ()
   (send self :write (list 3 #x90 #x93))
   ;; :read-data は先頭の長さバイトを既に読み捨てて返すため、:read-msg :start 1 は
   ;; (opcode + 12データバイト + checksum) から opcode とchecksumを除いた
   ;; 12データバイトそのものを返す(:versionの解析と同じ規約)。
   (let ((resp (send self :read-msg :start 1)))
     (when (and resp (>= (length resp) 12))
       (let ((vals (make-array 6)))
	 (dotimes (i 6)
	   (let* ((lo (elt resp (* i 2)))
		  (hi (elt resp (+ 1 (* i 2)))))
	     (setf (aref vals i)
		   (reinterpret-as-nbyte-signed-int (logior lo (ash hi 8)) :n 2))))
	 (list :accel (float-vector (/ (aref vals 0) 1000.0)
				     (/ (aref vals 1) 1000.0)
				     (/ (aref vals 2) 1000.0))
	       :gyro (float-vector (/ (aref vals 3) 10.0)
				    (/ (aref vals 4) 10.0)
				    (/ (aref vals 5) 10.0)))))))
  ;; M5StickV(K210, ~/rcb4eus/Arduino/M5StickV/object_detection_I2C_slave)を、
  ;; RCB4の予約OPCODE(0x91)経由でATOM S3のI2C(G1/G2, atoms3_i2c_robot.ino参照)
  ;; 越しに読み書きする。i2c-addrはM5StickV側で固定設定されたスレーブアドレス
  ;; (旧ARM-H7版の慣例では0x24/0x25の2台構成、~/rcb4eus/Arduino/M5StickV/
  ;; object_detection_I2C_slave/README.md参照)。
  ;; M5StickV側のレジスタは書き込み専用の経路しか無く(READ(subcmd=0)は
  ;; 検出データ領域0x01以降専用で、制御レジスタ0x00自体は読み出せない)、
  ;; 「今のビット値を保持したまま特定のビットだけON/OFFする」には、EusLisp
  ;; 側で最後に書いた値を自分で覚えておく必要がある。i2c-addr毎・
  ;; レジスタ番地毎にalistで追跡する(:write-m5stickv-control/
  ;; :write-m5stickv-registerを通した書き込みは全てここに反映される)。
  (:m5stickv-reg-value
   (i2c-addr reg-addr &optional (default 0))
   (let ((entry (assoc (cons i2c-addr reg-addr) (send self :get :m5stickv-reg-values) :test #'equal)))
     (if entry (cdr entry) default)))
  (:m5stickv-track-reg-value
   (i2c-addr reg-addr value)
   (let* ((key (cons i2c-addr reg-addr))
	  (entry (assoc key (send self :get :m5stickv-reg-values) :test #'equal)))
     (if entry
	 (setf (cdr entry) value)
       (send self :put :m5stickv-reg-values
	     (cons (cons key value) (send self :get :m5stickv-reg-values))))))
  (:write-m5stickv-control
   (i2c-addr ctrl-value)
   (let* ((frame (list 6 #x91 i2c-addr 1 ctrl-value)) (cksum 0))
     (dolist (b frame) (setq cksum (logand (+ cksum b) #xff)))
     (send self :write (append frame (list cksum))))
   (send self :m5stickv-track-reg-value i2c-addr #x00 ctrl-value)
   (let ((resp (send self :read-msg :start 1)))
     (when (and resp (>= (length resp) 3))
       (list :addr (elt resp 0) :subcmd (elt resp 1) :i2c-ok (/= (elt resp 2) 0)))))
  ;; :write-m5stickv-controlは制御レジスタ(0x00)専用だが、それ以外の任意の
  ;; レジスタ(例: object_detection_I2C_slave.pyのADDR_SPEAK_ENABLE=0xFE)へ
  ;; 書き込むための汎用版(subcmd=3、2026.8 atoms3_i2c_robot.ino拡張に対応)。
  (:write-m5stickv-register
   (i2c-addr reg-addr value)
   (let* ((frame (list 7 #x91 i2c-addr 3 reg-addr value)) (cksum 0))
     (dolist (b frame) (setq cksum (logand (+ cksum b) #xff)))
     (send self :write (append frame (list cksum))))
   (send self :m5stickv-track-reg-value i2c-addr reg-addr value)
   (let ((resp (send self :read-msg :start 1)))
     (when (and resp (>= (length resp) 3))
       (list :addr (elt resp 0) :subcmd (elt resp 1) :i2c-ok (/= (elt resp 2) 0)))))
  ;; ---- 制御レジスタ(0x00)のビット単位ON/OFF(他のビットは保持する) ----
  (:m5stickv-set-ctrl-bit
   (i2c-addr bitmask on-p)
   (let ((cur (send self :m5stickv-reg-value i2c-addr #x00)))
     (send self :write-m5stickv-control i2c-addr
	   (if on-p (logior cur bitmask) (logand cur (lognot bitmask))))))
  ;; 「面配置を見つける処理」(3x3グリッドの色を読む、cube_face_en=bit7)。
  (:m5stickv-cube-face-enable
   (i2c-addr on-p)
   (send self :m5stickv-set-ctrl-bit i2c-addr #x80 on-p))
  (:m5stickv-nn-enable (i2c-addr on-p) (send self :m5stickv-set-ctrl-bit i2c-addr #x04 on-p))
  (:m5stickv-apriltag-enable (i2c-addr on-p) (send self :m5stickv-set-ctrl-bit i2c-addr #x08 on-p))
  ;; ---- 発話ON/OFFレジスタ(0xFE)のビット単位ON/OFF ----
  ;; bit0=キューブ発見時の発話, bit1=顔発見(こんにちは)の発話,
  ;; bit2=AprilTag発見の発話。ファームウェア起動直後のデフォルトは
  ;; 0x07(3つとも有効)だが、初回アクセス時に:m5stickv-reg-valueが
  ;; 追跡値を持っていない場合はこのデフォルトを土台にする。
  (:m5stickv-set-speak-bit
   (i2c-addr bitmask on-p)
   (let ((cur (send self :m5stickv-reg-value i2c-addr #xFE #x07)))
     (send self :write-m5stickv-register i2c-addr #xFE
	   (if on-p (logior cur bitmask) (logand cur (lognot bitmask))))))
  (:m5stickv-speak-cube-enable (i2c-addr on-p) (send self :m5stickv-set-speak-bit i2c-addr #x01 on-p))
  (:m5stickv-speak-face-enable (i2c-addr on-p) (send self :m5stickv-set-speak-bit i2c-addr #x02 on-p))
  (:m5stickv-speak-apriltag-enable (i2c-addr on-p) (send self :m5stickv-set-speak-bit i2c-addr #x04 on-p))
  ;; 「ルービックキューブを見つける処理」全体(色ブロブ検出・bbox計算・
  ;; LCDのn=/c=表示・見つかった時の発話)をまとめてON/OFFするマスター
  ;; スイッチ(ADDR_CUBE_DISCOVERY_ENABLE=0xFD、object_detection_I2C_slave.py
  ;; 側でも対応済み、2026.8)。これをOFFにすれば:m5stickv-speak-cube-enable
  ;; の設定に関わらず発話・表示とも完全に止まる。
  (:m5stickv-cube-discovery-enable
   (i2c-addr on-p)
   (send self :write-m5stickv-register i2c-addr #xFD (if on-p 1 0)))
  ;; I2Cバス上に実際に何が繋がっているかをスキャンする(0x24/0x25の決め打ちに
  ;; 頼らず確認するため)。見つかったスレーブアドレスのリストを返す。
  (:scan-m5stickv-i2c
   ()
   (let* ((frame (list 4 #x91 0 2)) (cksum 0))
     (dolist (b frame) (setq cksum (logand (+ cksum b) #xff)))
     (send self :write (append frame (list cksum))))
   (let ((resp (send self :read-msg :start 1)))
     (when (and resp (>= (length resp) 3))
       (let ((count (elt resp 2)))
	 (coerce (subseq resp 3 (min (length resp) (+ 3 count))) cons)))))
  ;; i2c-ok: そのi2c-addr宛のI2Cトランザクション自体が成功したか(nilなら
  ;; デバイス無応答=NACK。lenが0でもi2c-okがtならデバイスは存在し検出結果が
  ;; 単に空だったという意味なので区別すること)。
  (:read-m5stickv-raw
   (i2c-addr)
   (let* ((frame (list 5 #x91 i2c-addr 0)) (cksum 0))
     (dolist (b frame) (setq cksum (logand (+ cksum b) #xff)))
     (send self :write (append frame (list cksum))))
   (let ((resp (send self :read-msg :start 1)))
     (when (and resp (>= (length resp) 4))
       (let ((addr (elt resp 0)) (subcmd (elt resp 1))
	     (i2c-ok (/= (elt resp 2) 0)) (l (elt resp 3)))
	 (list :addr addr :subcmd subcmd :i2c-ok i2c-ok :len l
	       :data (subseq resp 4 (min (length resp) (+ 4 l))))))))
  ;; object_detection_I2C_slave.py側は、有効化されている検出タイプ(nn_en/
  ;; apriltag_en/cube_face_en等)を一つのdetection_dataバイト列に順番に
  ;; 連結して送ってくる(有効なタイプが複数あれば複数種類のレコードが混在
  ;; する)。各レコードはtypeバイト+固定長ペイロードなので、typeごとの
  ;; 既知の長さを使って先頭から順に分割できる。各:parse-m5stickv-*は、
  ;; 自分のtypeが常に先頭にあると決め打ちせず、この分割結果から自分の
  ;; typeのレコードだけを取り出して使うこと(実機確認、2026.8: nn_enと
  ;; apriltag_enを同時に有効化した際、決め打ちのままだと後発の
  ;; :parse-m5stickv-apriltagがnn側のバイトを誤ってapriltagとして
  ;; 読んでしまう不具合があった)。未知のtypeに出会ったら、それ以降は
  ;; オフセットが分からず安全に分割できないため打ち切る。
  (:m5stickv-record-size
   (type)
   (case type (0 11) (1 20) (6 28) (7 18) (t nil)))
  (:m5stickv-split-records
   (data)
   (let ((i 0) (n (length data)) recs)
     (while (< i n)
       (let* ((type (elt data i)) (size (send self :m5stickv-record-size type)))
	 (if (and size (<= (+ i size) n))
	     (progn (push (cons type (subseq data i (+ i size))) recs) (setq i (+ i size)))
	   (setq i n))))
     (reverse recs)))
  ;; AprilTagレコード(type=1, 20byte)をパースする。M5StickV側のバイト仕様は
  ;; object_detection_I2C_slave.py参照: corner0-3のx,yがu16 LE(QQVGA画像を
  ;; 400倍スケールしたピクセル座標)、続けてtag id(u16 LE)、confidence(1byte)。
  (:parse-m5stickv-apriltag
   (data &aux rec)
   (setq rec (cdr (assoc 1 (send self :m5stickv-split-records data))))
   (when (and rec (>= (length rec) 20))
     (flet ((u16 (i) (logior (elt rec i) (ash (elt rec (1+ i)) 8))))
       (list :type 1
	     :corners (list (cons (u16 1) (u16 3)) (cons (u16 5) (u16 7))
			    (cons (u16 9) (u16 11)) (cons (u16 13) (u16 15)))
	     :id (u16 17) :confidence (elt rec 19)))))
  ;; ルービックキューブ面(type=6, 28byte)をパースする。M5StickV側のバイト仕様は
  ;; object_detection_I2C_slave.py参照: 3x3グリッド9箇所それぞれの平均色を
  ;; Lab(各1byte、L=0-100の符号無し、a/bは符号付き2の補数-128〜127)で、
  ;; 左上から右下へ行優先(0,1,2 / 3,4,5 / 6,7,8)の順に9組。
  (:parse-m5stickv-cube-face
   (data &aux rec)
   (setq rec (cdr (assoc 6 (send self :m5stickv-split-records data))))
   (when (and rec (>= (length rec) 28))
     (let (stickers)
       (dotimes (i 9)
	 (let ((off (+ 1 (* i 3))))
	   (push (list :l (elt rec off)
		       :a (reinterpret-as-nbyte-signed-int (elt rec (+ off 1)))
		       :b (reinterpret-as-nbyte-signed-int (elt rec (+ off 2))))
		 stickers)))
       (reverse stickers))))
  ;; i2c-addrのM5StickVからルービックキューブ面の9箇所の色(Lab)を読み取る。
  ;; 事前に(send self :write-m5stickv-control i2c-addr #x80)でcube_face_en
  ;; (bit7)を有効にしておくこと。左目(0x24)の並び順(左上から行優先)を基準とし、
  ;; 右目(0x25)は機体取り付けが180度回転しているため、生の9個の並びが左目に
  ;; 対してちょうど反転(index i <-> 8-i)する(実機比較で9/9一致確認、2026.8)。
  ;; ここで揃えておくことで、呼び出し側はどちらのi2c-addrでも同じ並び順で
  ;; 扱える。
  (:read-m5stickv-cube-face
   (i2c-addr)
   (let ((raw (send self :read-m5stickv-raw i2c-addr)))
     (when raw
       (let ((stickers (send self :parse-m5stickv-cube-face (cadr (memq :data raw)))))
         (if (= i2c-addr #x25) (reverse stickers) stickers)))))
  ;; sticker(:l :a :bのplist)1個を*m5stickv-cube-colors*の中で最もLab距離が
  ;; 近い色名に分類する(qbrのCIEDE2000ほど厳密ではない単純ユークリッド距離)。
  (:m5stickv-classify-cube-color
   (sticker &optional (palette *m5stickv-cube-colors*))
   (let ((l (cadr (memq :l sticker))) (a (cadr (memq :a sticker))) (b (cadr (memq :b sticker)))
	 best best-d)
     (dolist (c palette)
       (let* ((cl (elt c 1)) (ca (elt c 2)) (cb (elt c 3))
	      (d (+ (* (- l cl) (- l cl)) (* (- a ca) (- a ca)) (* (- b cb) (- b cb)))))
	 (when (or (null best-d) (< d best-d)) (setq best-d d best (car c)))))
     best))
  ;; i2c-addrから読んだ9箇所を全て分類し、色名のリスト(9個、左上から行優先)で返す。
  (:read-m5stickv-cube-face-colors
   (i2c-addr &optional (palette *m5stickv-cube-colors*))
   (let ((stickers (send self :read-m5stickv-cube-face i2c-addr)))
     (when stickers (mapcar #'(lambda (s) (send self :m5stickv-classify-cube-color s palette))
			     stickers))))
  ;; 左目(0x24)と右目(0x25)で同じキューブ面を見ている前提で、両方の9マス色認識
  ;; 結果を読み取って突き合わせるダブルチェック。:read-m5stickv-cube-face-colors
  ;; 側で並び順は既に揃えてあるので、そのままindexごとに比較すればよい。
  ;; 事前に両方のcube_face_enを有効化しておくこと。
  ;; 戻り値はplist: (:ok t/nil :left 色名9個 :right 色名9個 :mismatches 不一致index番号のリスト)
  ;; 片方でも読めなければ :ok nil, :left/:rightのうち読めなかった方はnil。
  (:read-m5stickv-cube-face-colors-checked
   (&key (left-addr #x24) (right-addr #x25) (palette *m5stickv-cube-colors*))
   (let* ((left (send self :read-m5stickv-cube-face-colors left-addr palette))
	  (right (send self :read-m5stickv-cube-face-colors right-addr palette))
	  mismatches)
     (if (and left right)
	 (progn
	   (dotimes (i 9)
	     (unless (eq (elt left i) (elt right i)) (push i mismatches)))
	   (setq mismatches (nreverse mismatches))
	   (if mismatches
	       (format t "[m5stickv double-check] mismatch at index ~A~%" mismatches)
	     (format t "[m5stickv double-check] OK (9/9 match)~%")))
       (format t "[m5stickv double-check] read failed (left=~A right=~A)~%" (if left t nil) (if right t nil)))
     (list :ok (and left right (null mismatches))
	   :left left :right right :mismatches mismatches)))
  ;; 手動キャリブレーション用: 今i2c-addrに映っているsticker-index(0-8、行優先)の
  ;; 実測Lab値を読み取り、color-nameとして*m5stickv-cube-colors*に登録(既存なら
  ;; 上書き)する。kxr_cube_solverのREADMEにある「デバッグ画面を見て色を書き込む」
  ;; 手動キャリブレーション手順のEusLisp版。9箇所×6色を順に呼んで表を埋める。
  (:m5stickv-calibrate-cube-color
   (i2c-addr sticker-index color-name)
   (let* ((stickers (send self :read-m5stickv-cube-face i2c-addr))
	  (s (and stickers (elt stickers sticker-index))))
     (when s
       (let ((entry (assoc color-name *m5stickv-cube-colors*))
	     (lab (list (cadr (memq :l s)) (cadr (memq :a s)) (cadr (memq :b s)))))
	 (if entry
	     (setf (cdr entry) lab)
	   (setq *m5stickv-cube-colors* (cons (cons color-name lab) *m5stickv-cube-colors*))))
       (assoc color-name *m5stickv-cube-colors*))))
  ;; :parse-m5stickv-apriltagが返したtagの4隅中心から、カメラ光学系(標準ピンホール
  ;; 規約: Z前方、X右、Y下)でのレイ方向ベクトル(カメラローカル座標系、正規化済み)
  ;; を計算する。fx/fy/cx/cyはobject_detection_I2C_slave.py起動時のシリアル出力
  ;; (デフォルト構成では170 170 80 60)に合わせる。QQVGA_SCALE=400で送られてくる
  ;; ため、まず400で割って実ピクセル座標に戻す。
  (:m5stickv-apriltag-ray
   (tag &key (fx 170.0) (fy 170.0) (cx 80.0) (cy 60.0))
   (let* ((corners (cadr (memq :corners tag)))
	  (px (/ (float (reduce #'+ (mapcar #'car corners))) (* 4.0 400.0)))
	  (py (/ (float (reduce #'+ (mapcar #'cdr corners))) (* 4.0 400.0))))
     (normalize-vector (float-vector (/ (- px cx) fx) (/ (- py cy) fy) 1.0))))
  ;; armh7interface.lのapriltag-corner-4vectorsに相当。4隅それぞれについて
  ;; (:m5stickv-apriltag-rayと同じピンホール変換で)カメラローカル座標系での
  ;; レイ方向ベクトル(正規化済み)を、corners順(0,1,2,3)のリストで返す。
  (:m5stickv-apriltag-corner-vectors
   (tag &key (fx 170.0) (fy 170.0) (cx 80.0) (cy 60.0))
   (mapcar #'(lambda (c)
	       (let ((px (/ (float (car c)) 400.0)) (py (/ (float (cdr c)) 400.0)))
		 (normalize-vector (float-vector (/ (- px cx) fx) (/ (- py cy) fy) 1.0))))
	   (cadr (memq :corners tag))))
  ;; i2c-addrのカメラ座標(cam)を求める共通処理(軸規約補正込み)。kxrmodels.lの
  ;; m5stickhead-3eye系リンクの軸規約(URDF/リンクフレーム)から、カメラ光学規約
  ;; (Z前方)へ変換する補正をarmh7interface.lの:draw-m5stickv-object-stereo等と
  ;; 同じくコピーに対して適用する(元のcamera cascoordsは変更しない)。
  (:m5stickv-camera-coords
   (camera-name)
   (let* ((cam0 (find-if #'(lambda (c) (string= (send c :name) camera-name))
			  (send robot :cameras)))
	  (cam (and cam0 (send cam0 :copy-worldcoords))))
     (when cam
       (send cam :rotate -pi/2 :y :local)
       (send cam :rotate pi :x :local))
     cam))
  ;; i2c-addrのM5StickVで検出したAprilTagを、camera-nameで指定した
  ;; (send robot :cameras)中のカメラ位置からirtviewerへ描画する(単眼のため
  ;; 奥行きは不定、:lengthで指定した固定距離まで引く簡易表示。ステレオ
  ;; 三角測量ができるようになるまでの暫定表示)。中心へのレイ(1本)に加え、
  ;; armh7interface.lの:draw-m5stickv-object-stereo同様、4隅それぞれへのレイと
  ;; それらを結ぶ四角形も描画する。
  (:draw-m5stickv-apriltag-ray
   (i2c-addr camera-name &key (length 300) (color #f(1 1 0)) (corner-color #f(0 0 1)) (flush t))
   (let* ((raw (send self :read-m5stickv-raw i2c-addr))
	  (tag (and raw (send self :parse-m5stickv-apriltag (cadr (memq :data raw)))))
	  (cam (send self :m5stickv-camera-coords camera-name))
	  (vwer (and (send self :viewer) (send self :viewer :viewer))))
     (when (and tag cam vwer)
       (let* ((p0 (send cam :worldpos))
	      (dir-world (send cam :rotate-vector (send self :m5stickv-apriltag-ray tag)))
	      (p1 (v+ p0 (scale length dir-world)))
	      (corner-pts (mapcar #'(lambda (v) (v+ p0 (scale length (send cam :rotate-vector v))))
				  (send self :m5stickv-apriltag-corner-vectors tag))))
	 (send vwer :viewsurface :color color)
	 (send vwer :draw-line p0 p1)
	 (send vwer :viewsurface :color corner-color)
	 (dotimes (i 4)
	   (send vwer :draw-line (elt corner-pts i) (elt corner-pts (mod (1+ i) 4)))
	   (send vwer :draw-line p0 (elt corner-pts i)))
	 (when flush (send vwer :flush))))
     tag))
  ;; armh7interface.lのfind-closest-points相当。c0,c1はカメラcascoords、v0,v1は
  ;; それぞれのローカル座標系でのレイ方向ベクトル。2本の(一般にねじれの位置に
  ;; ある)直線の最近接点を、それぞれの直線上の点として2つ返す(実際の交点は
  ;; 無いのが普通なので、呼び出し側で平均するなどして1点に丸める)。
  (:m5stickv-find-closest-points
   (c0 v0 c1 v1)
   (let* ((p0 (send c0 :worldpos)) (p1 (send c1 :worldpos))
	  (o0 (send c0 :rotate-vector (normalize-vector v0)))
	  (o1 (send c1 :rotate-vector (normalize-vector v1)))
	  (p0-p1 (v- p0 p1)) (r01 (v. o0 o1)) (d (- 1 (* r01 r01))))
     (if (< (abs d) 1e-9)
	 (list p0 p1) ;; ほぼ平行(視線が交わらない)、フォールバックとして各カメラ位置を返す
       (let* ((s0 (/ (- (* (v. o1 p0-p1) r01) (v. o0 p0-p1)) d))
	      (s1 (/ (- (v. o1 p0-p1) (* (v. o0 p0-p1) r01)) d)))
	 (list (v+ p0 (scale s0 o0)) (v+ p1 (scale s1 o1)))))))
  ;; 左右2台のM5StickVで同じAprilTagが見えている前提で、4隅それぞれを
  ;; ステレオ三角測量し、実座標(ワールド座標系)での4隅の3D位置を返す。
  ;; corner順(0,1,2,3)は両カメラで一致している前提(タグの向きから解読される
  ;; 順序のため、正面寄りの視点であれば通常一致する)。
  (:triangulate-m5stickv-apriltag-corners
   (left-addr right-addr left-camera right-camera)
   (let* ((lraw (send self :read-m5stickv-raw left-addr))
	  (rraw (send self :read-m5stickv-raw right-addr))
	  (ltag (and lraw (send self :parse-m5stickv-apriltag (cadr (memq :data lraw)))))
	  (rtag (and rraw (send self :parse-m5stickv-apriltag (cadr (memq :data rraw)))))
	  (lcam (send self :m5stickv-camera-coords left-camera))
	  (rcam (send self :m5stickv-camera-coords right-camera)))
     (when (and ltag rtag lcam rcam (= (cadr (memq :id ltag)) (cadr (memq :id rtag))))
       (let ((lvecs (send self :m5stickv-apriltag-corner-vectors ltag))
	     (rvecs (send self :m5stickv-apriltag-corner-vectors rtag)))
	 (list :id (cadr (memq :id ltag))
	       :points (mapcar #'(lambda (lv rv)
				   (let ((cp (send self :m5stickv-find-closest-points
						   lcam lv rcam rv)))
				     (scale 0.5 (v+ (car cp) (cadr cp)))))
			       lvecs rvecs))))))
  ;; :triangulate-m5stickv-apriltag-cornersの4隅実座標から、タグ平面の正規直交
  ;; 座標系(中心位置+姿勢)と辺の実寸(タグの一辺の長さ、4辺の平均)を求める。
  (:m5stickv-tag-frame-from-points
   (pts)
   (let* ((center (scale 0.25 (reduce #'v+ pts)))
	  (xaxis (normalize-vector (v- (elt pts 1) (elt pts 0))))
	  (yaxis0 (normalize-vector (v- (elt pts 3) (elt pts 0))))
	  (zaxis (normalize-vector (v* xaxis yaxis0)))
	  (yaxis (v* zaxis xaxis))
	  (edge-len (/ (+ (norm (v- (elt pts 1) (elt pts 0)))
			  (norm (v- (elt pts 2) (elt pts 1)))
			  (norm (v- (elt pts 3) (elt pts 2)))
			  (norm (v- (elt pts 0) (elt pts 3))))
		       4.0)))
     (list :center center :rot (transpose (matrix xaxis yaxis zaxis)) :size edge-len)))
  ;; 左右のM5StickVでステレオ三角測量した実座標をもとに、AprilTagが印刷されて
  ;; いる立方体をmake-cubeで生成し、その位置(タグの実寸+四辺margin分だけ大きい
  ;; 一辺長)に配置してirtviewerへ表示する(初回生成したcubeオブジェクトを
  ;; *m5stickv-cube*に保持し、以降は:newcoordsで位置だけ更新して使い回す)。
  (:draw-m5stickv-apriltag-cube
   (&key (left-addr #x24) (right-addr #x25) (left-camera "camera1") (right-camera "camera0")
	 (margin 3.0) (color #f(0 1 0)) (flush t))
   (let* ((tri (send self :triangulate-m5stickv-apriltag-corners
		      left-addr right-addr left-camera right-camera))
	  ;; 注意: (send self :viewer)は:objects/:draw-objects等を持つ外側の
	  ;; x::irtviewerラッパー。(send self :viewer :viewer)はさらにもう1段
	  ;; 掘り下げた内側の低レベルviewer(:draw-line/:viewsurfaceのみ持つ、
	  ;; :objectsは無い)なので、ここでは前者(ivwer)を使う。
	  (ivwer (send self :viewer)))
     (when (and tri ivwer)
       (let* ((frame (send self :m5stickv-tag-frame-from-points (cadr (memq :points tri))))
	      (face-size (+ (cadr (memq :size frame)) (* 2 margin)))
	      (center (cadr (memq :center frame))) (rot (cadr (memq :rot frame)))
	      ;; 立方体の中心は、タグの面(手前の面)から法線方向(z軸)へ
	      ;; 一辺の半分だけ奥へ引いた位置にする(タグの面が立方体の表面に来るように)。
	      (zaxis (matrix-column rot 2))
	      (cube-pos (v+ center (scale (/ face-size 2.0) zaxis))))
	 (unless (boundp '*m5stickv-cube*)
	   (setq *m5stickv-cube* (make-cube face-size face-size face-size))
	   (send *m5stickv-cube* :set-color color)
	   (send ivwer :objects (append (send ivwer :objects) (list *m5stickv-cube*))))
	 (send *m5stickv-cube* :newcoords (make-coords :pos cube-pos :rot rot))
	 (when flush (send ivwer :draw-objects :flush t))))
     tri))

  ;; ==== テーブル上に置かれたルービックキューブの発見・3次元姿勢推定 ====
  ;; (object_detection_I2C_slave.pyの段階1〜4: 色ブロブクラスタリングで
  ;; キューブ候補を発見し、その外接bbox(軸並行、回転情報は無い)と片目簡易
  ;; ヨー角をtype=7としてI2C経由で送ってくる。ここではそれをステレオ
  ;; 三角測量して3次元位置を求め、「キューブの上面は水平」という前提を
  ;; 置くことで姿勢(ヨー角のみ)を推定し、irtviewerへ立方体として表示する)。
  ;;
  ;; 【現状の制約、今後の課題】
  ;;  - 個々のステッカーの左右カメラ対応点マッチングはまだ実装しておらず、
  ;;    bbox4隅(軸並行なので回転情報を持たない)だけをステレオ三角測量して
  ;;    いるため、位置はキューブの真の幾何中心ではなく見えている範囲の
  ;;    大まかな中心に過ぎない。
  ;;  - 回転(ヨー角)は片目(left-addr側)だけで求めたブロブ群の主軸角度
  ;;    (object_detection_I2C_slave.pyのcube_principal_axis_deg)を使っており、
  ;;    ステレオでの裏付けは無い。180度の曖昧さもある。
  ;;  - :size-consistency-ratioは、実サイズ(*m5stickv-cube-physical-size*)と
  ;;    ステレオ三角測量で求めた距離からピンホール投影で予測した見た目の
  ;;    サイズと、実際に検出されたbboxの対角線サイズとの比。1に近いほど
  ;;    整合的(まだ足切りはしておらず診断用の値として返すのみ)。
  (defparameter *m5stickv-cube-physical-size* 55.0) ;; mm、ユーザー申告の一辺5.5cm

  ;; type=7(段階4のbbox)をパースする。M5StickV側のバイト仕様は
  ;; object_detection_I2C_slave.py参照: 軸並行bbox4隅(左上,右上,右下,左下の順、
  ;; QVGA画像を200倍スケールしたピクセル座標、u16 LE)、続けて片目簡易ヨー角
  ;; (1byte、符号付き2の補数、度、-90〜90程度)。
  (:parse-m5stickv-cube-bbox
   (data &aux rec)
   (setq rec (cdr (assoc 7 (send self :m5stickv-split-records data))))
   (when (and rec (>= (length rec) 18))
     (flet ((u16 (i) (logior (elt rec i) (ash (elt rec (1+ i)) 8))))
       (list :type 7
	     :corners (list (cons (u16 1) (u16 3)) (cons (u16 5) (u16 7))
			    (cons (u16 9) (u16 11)) (cons (u16 13) (u16 15)))
	     :yaw-deg (reinterpret-as-nbyte-signed-int (elt rec 17))))))
  (:read-m5stickv-cube-bbox
   (i2c-addr)
   (let ((raw (send self :read-m5stickv-raw i2c-addr)))
     (when raw (send self :parse-m5stickv-cube-bbox (cadr (memq :data raw))))))
  ;; :m5stickv-apriltag-corner-vectorsと同じピンホール変換だが、bboxはQVGA画像
  ;; (320x240)を200倍スケールして送られてくるため、まず200で割って実ピクセル
  ;; 座標に戻す(AprilTagのQQVGA×400とはスケールが異なる)。fx/fy/cx/cyは
  ;; :m5stickv-nn-rayと同じQVGA用の値(QQVGAデフォルトの2倍)を使う。
  (:m5stickv-cube-bbox-corner-vectors
   (bboxrec &key (fx 340.0) (fy 340.0) (cx 160.0) (cy 120.0))
   (mapcar #'(lambda (c)
	       (let ((px (/ (float (car c)) 200.0)) (py (/ (float (cdr c)) 200.0)))
		 (normalize-vector (float-vector (/ (- px cx) fx) (/ (- py cy) fy) 1.0))))
	   (cadr (memq :corners bboxrec))))
  ;; 左右2台のM5StickVで同じキューブ候補領域が見えている前提で、bbox4隅を
  ;; ステレオ三角測量する(:triangulate-m5stickv-apriltag-cornersと同じ方式)。
  ;; ヨー角はleft-addr側の値をそのまま添えて返す。
  (:triangulate-m5stickv-cube-bbox
   (left-addr right-addr left-camera right-camera)
   (let* ((lbb (send self :read-m5stickv-cube-bbox left-addr))
	  (rbb (send self :read-m5stickv-cube-bbox right-addr))
	  (lcam (send self :m5stickv-camera-coords left-camera))
	  (rcam (send self :m5stickv-camera-coords right-camera)))
     (when (and lbb rbb lcam rcam)
       (let ((lvecs (send self :m5stickv-cube-bbox-corner-vectors lbb))
	     (rvecs (send self :m5stickv-cube-bbox-corner-vectors rbb)))
	 (list :points (mapcar #'(lambda (lv rv)
				    (let ((cp (send self :m5stickv-find-closest-points
						    lcam lv rcam rv)))
				      (scale 0.5 (v+ (car cp) (cadr cp)))))
				lvecs rvecs)
	       :yaw-deg (cadr (memq :yaw-deg lbb))
	       :left-bbox lbb)))))
  ;; bbox4隅(画像座標、corners順は左上,右上,右下,左下)の対角線の長さ(px)。
  (:m5stickv-cube-bbox-2d-diag
   (bboxrec)
   (let* ((c (cadr (memq :corners bboxrec)))
	  (dx (- (car (elt c 2)) (car (elt c 0))))
	  (dy (- (cdr (elt c 2)) (cdr (elt c 0)))))
     (sqrt (+ (* dx dx) (* dy dy)))))
  ;; :triangulate-m5stickv-cube-bboxの結果から、キューブの位置・簡易ヨー姿勢
  ;; ・サイズ整合診断値を求める。「上面は水平(法線がワールドZ)」という前提で
  ;; ヨー角だけの回転にしている。
  (:m5stickv-cube-pose
   (&key (left-addr #x24) (right-addr #x25) (left-camera "camera1") (right-camera "camera0")
	 (fx 340.0))
   (let ((tri (send self :triangulate-m5stickv-cube-bbox left-addr right-addr left-camera right-camera)))
     (when tri
       (let* ((pts (cadr (memq :points tri)))
	      (center (scale 0.25 (reduce #'v+ pts)))
	      (lcam (send self :m5stickv-camera-coords left-camera))
	      (dist (norm (v- center (send lcam :worldpos))))
	      (lbb (cadr (memq :left-bbox tri)))
	      (bbox-diag-px (send self :m5stickv-cube-bbox-2d-diag lbb))
	      (predicted-diag-px (if (> dist 0)
				      (/ (* *m5stickv-cube-physical-size* (sqrt 3.0) fx) dist)
				    0))
	      (ratio (if (> predicted-diag-px 0) (/ bbox-diag-px predicted-diag-px) nil))
	      (yaw-deg (cadr (memq :yaw-deg tri)))
	      (rot (rotation-matrix (deg2rad yaw-deg) :z)))
	 (list :center center :rot rot :yaw-deg yaw-deg
	       :distance dist :size-consistency-ratio ratio)))))
  ;; :m5stickv-cube-poseの結果を、実サイズの立方体としてirtviewerへ表示する
  ;; (:draw-m5stickv-apriltag-cubeと同じ、初回生成したオブジェクトを使い回す
  ;; パターン)。
  (:draw-m5stickv-cube-pose
   (&key (left-addr #x24) (right-addr #x25) (left-camera "camera1") (right-camera "camera0")
	 (color #f(0 1 1)) (flush t))
   (let* ((pose (send self :m5stickv-cube-pose :left-addr left-addr :right-addr right-addr
		       :left-camera left-camera :right-camera right-camera))
	  (ivwer (send self :viewer)))
     (when (and pose ivwer)
       (unless (boundp '*m5stickv-cube-pose-obj*)
	 (setq *m5stickv-cube-pose-obj*
	       (make-cube *m5stickv-cube-physical-size* *m5stickv-cube-physical-size*
			  *m5stickv-cube-physical-size*))
	 (send *m5stickv-cube-pose-obj* :set-color color)
	 (send ivwer :objects (append (send ivwer :objects) (list *m5stickv-cube-pose-obj*))))
       (send *m5stickv-cube-pose-obj* :newcoords
	     (make-coords :pos (cadr (memq :center pose)) :rot (cadr (memq :rot pose))))
       (when flush (send ivwer :draw-objects :flush t))
       (format t "[m5stickv-cube-pose] dist=~A yaw-deg=~A size-ratio=~A~%"
	       (cadr (memq :distance pose)) (cadr (memq :yaw-deg pose))
	       (cadr (memq :size-consistency-ratio pose))))
     pose))

  ;; i2c-addr(0x24/0x25、このプロジェクトの実機の慣例)ごとに対応するカメラ名。
  ;; :m5stickv-auto-updateがこの表を使って自動的にどちらが繋がっているか判定する。
  (:m5stickv-addr-camera-alist () '((#x24 . "camera1") (#x25 . "camera0")))
  ;; YOLO2物体検出(TYPE_NN=0、可変長: 検出数ぶん11byteレコードが連続)を
  ;; パースする。object_detection_I2C_slave.py参照: 各レコードはtype(1)+
  ;; x,y,w,h(各u16 LE、QVGA_SCALE=200倍)+confidence(1byte、0-255)+
  ;; classid(1byte)。x,y,w,hはQVGA(320x240、リサイズ無しの生画像)座標系
  ;; そのもの(AprilTagのQQVGA×400とはスケールも解像度も異なる点に注意)。
  ;; classidの意味(顔=0か等)はロードされているYOLO2モデル依存で未確認、
  ;; 単一クラスの顔検出モデルであればclassid=0のはず。
  (:parse-m5stickv-nn
   (data)
   (let (dets)
     (dolist (typed-rec (send self :m5stickv-split-records data))
       (when (= (car typed-rec) 0)
	 (let ((rec (cdr typed-rec)))
	   (flet ((u16 (off) (logior (elt rec off) (ash (elt rec (1+ off)) 8))))
	     (push (list :x (/ (float (u16 1)) 200.0)
			 :y (/ (float (u16 3)) 200.0)
			 :w (/ (float (u16 5)) 200.0)
			 :h (/ (float (u16 7)) 200.0)
			 :confidence (/ (elt rec 9) 255.0)
			 :classid (elt rec 10))
		   dets)))))
     (reverse dets)))
  ;; i2c-addrのM5StickVで検出した物体(YOLO2、TYPE_NN)一覧を読み取る。
  ;; 事前に(send self :write-m5stickv-control i2c-addr #x04)でnn_en
  ;; (bit2)を有効にしておくこと。
  (:read-m5stickv-nn
   (i2c-addr)
   (let ((raw (send self :read-m5stickv-raw i2c-addr)))
     (when raw (send self :parse-m5stickv-nn (cadr (memq :data raw))))))
  ;; 検出一覧の中から指定classid(デフォルト0=顔想定)のうち最も信頼度の
  ;; 高いものを1つ選ぶ。
  (:m5stickv-best-nn-detection
   (dets &optional (classid 0))
   (let (best best-conf)
     (dolist (d dets)
       (when (and (= (cadr (memq :classid d)) classid)
		  (or (null best-conf) (> (cadr (memq :confidence d)) best-conf)))
	 (setq best d best-conf (cadr (memq :confidence d)))))
     best))
  ;; :m5stickv-apriltag-rayと同じピンホール変換だが、NN検出のbboxは
  ;; QVGA(320x240)座標系そのものなので、デフォルトのfx/fy/cx/cyは
  ;; QQVGA用デフォルト(170,170,80,60)をそのまま2倍したもの(340,340,160,120)。
  ;; カメラ較正ファイルがある場合はobject_detection_I2C_slave.py起動時の
  ;; シリアル出力(fx fy cx cy、これは既に/2されたQQVGA値)を2倍して使うこと。
  (:m5stickv-nn-ray
   (det &key (fx 340.0) (fy 340.0) (cx 160.0) (cy 120.0))
   (let ((px (+ (cadr (memq :x det)) (/ (cadr (memq :w det)) 2.0)))
	 (py (+ (cadr (memq :y det)) (/ (cadr (memq :h det)) 2.0))))
     (normalize-vector (float-vector (/ (- px cx) fx) (/ (- py cy) fy) 1.0))))
  ;; 左右のM5StickVで同じ顔(classidの最良検出)が両方見えている前提で、
  ;; その中心をステレオ三角測量し、実座標(ワールド座標系)での3D位置を返す。
  ;; :triangulate-m5stickv-apriltag-cornersと同じ2直線最近接点方式
  ;; (:m5stickv-find-closest-points)を1点ぶんだけ使う。
  (:triangulate-m5stickv-nn-center
   (left-addr right-addr left-camera right-camera &key (classid 0))
   (let* ((ldets (send self :read-m5stickv-nn left-addr))
	  (rdets (send self :read-m5stickv-nn right-addr))
	  (ldet (send self :m5stickv-best-nn-detection ldets classid))
	  (rdet (send self :m5stickv-best-nn-detection rdets classid))
	  (lcam (send self :m5stickv-camera-coords left-camera))
	  (rcam (send self :m5stickv-camera-coords right-camera)))
     (when (and ldet rdet lcam rcam)
       (let* ((lv (send self :m5stickv-nn-ray ldet))
	      (rv (send self :m5stickv-nn-ray rdet))
	      (cp (send self :m5stickv-find-closest-points lcam lv rcam rv)))
	 (list :point (scale 0.5 (v+ (car cp) (cadr cp)))
	       :left ldet :right rdet)))))
  ;; 左右のM5StickVでステレオ三角測量した顔の3D位置に、円柱(make-cylinder)を
  ;; 配置してirtviewerへ表示する(:draw-m5stickv-apriltag-cubeと同じく、
  ;; 初回生成したオブジェクトを*m5stickv-face-cylinder*に保持し、以降は
  ;; :newcoordsで位置だけ更新して使い回す)。AprilTagと違い顔の向き(姿勢)は
  ;; 求まらないため、位置だけを更新し、姿勢は常に正立(ワールド座標系の
  ;; 向きなり)のままにする。
  (:draw-m5stickv-face-cylinder
   (&key (left-addr #x24) (right-addr #x25) (left-camera "camera1") (right-camera "camera0")
	 (classid 0) (radius 40.0) (height 200.0) (color #f(1 0.7 0.3)) (flush t))
   (let* ((tri (send self :triangulate-m5stickv-nn-center
		      left-addr right-addr left-camera right-camera :classid classid))
	  (ivwer (send self :viewer)))
     (when (and tri ivwer)
       (let ((pos (cadr (memq :point tri))))
	 (unless (boundp '*m5stickv-face-cylinder*)
	   (setq *m5stickv-face-cylinder* (make-cylinder radius height))
	   (send *m5stickv-face-cylinder* :set-color color)
	   (send ivwer :objects (append (send ivwer :objects) (list *m5stickv-face-cylinder*))))
	 ;; make-cylinderの原点は底面(ローカルz=0〜height)であり中心では
	 ;; ないため(実機確認、2026.8)、高さ方向中央が顔の3D位置に来るよう
	 ;; z方向に-height/2だけずらして配置する。
	 (send *m5stickv-face-cylinder*
	       :newcoords (make-coords :pos (v- pos (float-vector 0 0 (/ height 2.0)))))
	 (when flush (send ivwer :draw-objects :flush t))))
     tri))
  ;; ATOM S3のI2Cバスに実際に何台のM5StickVが繋がっているかを1回だけスキャンし
  ;; (:get :m5stickv-addrsに結果をキャッシュ)、見つかった各アドレスに
  ;; apriltag_enを立てる。:force tで再スキャンする(配線を変えた後など)。
  (:m5stickv-scan
   (&key force)
   (when (or force (not (send self :get :m5stickv-scanned)))
     (let ((addrs (send self :scan-m5stickv-i2c)))
       (send self :put :m5stickv-addrs addrs)
       (send self :put :m5stickv-scanned t)
       (dolist (a addrs)
	 (when (assoc a (send self :m5stickv-addr-camera-alist))
	   ;; bit3(apriltag_en, #x08)とbit2(nn_en, #x04)を同時に立てる。
	   (send self :write-m5stickv-control a (logior #x08 #x04))))))
   (send self :get :m5stickv-addrs))
  ;; カメラ単眼の四角錐線(:draw-m5stickv-apriltag-rayが描く、カメラ位置から
  ;; 4隅+中心へのレイと4隅を結ぶ四角形 -- 奥行き不定の固定長表示)を
  ;; :m5stickv-auto-updateで一緒に表示するかどうかのon/off。デフォルトはon。
  ;; :m5stickv-show-raysが未設定(nil)か:onなら表示、:offなら非表示。
  (:m5stickv-rays-on () (send self :put :m5stickv-show-rays :on) t)
  (:m5stickv-rays-off () (send self :put :m5stickv-show-rays :off) nil)
  (:m5stickv-show-rays-p () (not (eq (send self :get :m5stickv-show-rays) :off)))
  ;; :timer-on/:viewer-updateから毎ティック呼ばれる想定。M5StickVが(1台でも)
  ;; 接続されていればそのカメラのAprilTagレイ+四隅四角形(四角錐線、
  ;; :m5stickv-rays-off済みなら非表示)を描画し、2台とも接続されていてかつ
  ;; 同じタグが両方から見えていれば、ステレオ三角測量した実座標にタグキューブも
  ;; 重ねて表示する(こちらは:m5stickv-rays-offの影響を受けず常に表示)。
  ;; 何も繋がっていなければ何もしない(毎回スキャンし直すことはしない、
  ;; 初回のみ:m5stickv-scanでキャッシュ)。
  (:m5stickv-auto-update
   (&key (length 300))
   (let* ((addrs (send self :m5stickv-scan))
	  (alist (send self :m5stickv-addr-camera-alist)))
     (when addrs
       (when (send self :m5stickv-show-rays-p)
	 (dolist (a addrs)
	   (let ((cam-name (cdr (assoc a alist))))
	     (when cam-name
	       (send self :draw-m5stickv-apriltag-ray a cam-name
		     :color (if (= a #x24) #f(1 0 1) #f(1 1 0))
		     :corner-color (if (= a #x24) #f(0 1 1) #f(0 0 1))
		     :length length)))))
       (when (and (member #x24 addrs) (member #x25 addrs))
	 (send self :draw-m5stickv-apriltag-cube
	       :left-addr #x24 :right-addr #x25
	       :left-camera (cdr (assoc #x24 alist)) :right-camera (cdr (assoc #x25 alist))
	       :margin 3.0 :color #f(0 1 0))
	 ;; Tagの立方体と同様、人(顔、classid=0)が両カメラから見えていれば
	 ;; ステレオ三角測量した位置に円柱を重ねて表示する。
	 (send self :draw-m5stickv-face-cylinder
	       :left-addr #x24 :right-addr #x25
	       :left-camera (cdr (assoc #x24 alist)) :right-camera (cdr (assoc #x25 alist)))))))
  (:read-servo-connected
   (&key (retry 3) (confirm-retry 5)
	 (devname (or (find-atom-echo-devname)
		      (if (probe-file "/dev/ttyUSB0") "ttyUSB0")
		      (if (probe-file "/dev/ttyUSB1") "ttyUSB1")
		      ))
	 (baud 500000)
	 &aux prev cur)
   ;; com-portが未オープンだと:write/:read-msgが(when com-port ...)で
   ;; 静かに何もせずnilを返すだけなので、そのまま進むと無駄にリトライを
   ;; 繰り返した末に「RCB4の電源を確認してください」という的外れな
   ;; エラーになってしまう(実機確認、2026.8)。ここで早期に検出し、
   ;; make-kxr-robot-from-hardwareと同じ規約(ATOM Echo自動検出)で
   ;; :com-openしてから続行する。
   (unless com-port
     (format t ";; :read-servo-connected: com-port未オープンのため:com-open :devname ~A :baud ~A で開きます~%" devname baud)
     (send self :com-open :devname devname :baud baud)
     (unix::sleep 3))
   ;; RCB4の電源投入直後は初期化中でサーボアクセス系コマンドに応答できない
   ;; ことがある(実機確認、2026.8)。ここが接続シーケンスで最初にサーボへ
   ;; アクセスする箇所なので、軽い:ackコマンドで応答できる状態になった
   ;; ことを確認してから実際のスキャンに入る。
   (send self :wait-ack 1000 0.5 20 t)
   (dotimes (attempt confirm-retry)
     (unless cur
       (setq prev (send self :read-servo-connected-once :retry retry))
       (when (and prev (equal prev (send self :read-servo-connected-once :retry retry)))
	 (setq cur prev))))
   (unless cur
     (error "rcb4-interface :read-servo-connected: ~A回試しても2回連続で同じサーボID一覧が得られませんでした。RCB4の電源/LED状態を確認してください。" confirm-retry))
   cur)
  (:init-analog
   nil
   ;; :read-servo-connectedと同じ理由(実機確認、2026.8)で、ここも
   ;; サーボ/アナログアクセス系コマンド(:read-analog)を送る前にACKで
   ;; 応答できる状態を確認する。
   (send self :wait-ack 1000 0.5 20 t)
   (setq analog-neutral (send self :read-analog))
   (case
    control-board
    (:armh7
     (setq gravity-method :read-gravity))
    (t
     (if (< (elt analog-neutral 5) 4)
	 (setq gravity-method :read-gravity2)
       (setq gravity-method :read-gravity))))
   (send self :put :kondo-gravity-method gravity-method)
   ;; ロボット側がATOM S3(IMU搭載)の場合、:read-imuが有効な値を返す
   ;; (IMU非搭載/通信失敗時はnil)。搭載機ではヨーも取れるATOM S3の
   ;; IMU姿勢をデフォルトで使うようにする(実機で近藤科学アナログセンサに
   ;; 切り替えたい場合は:imu-orientation-offで戻せる)。
   (when (send self :read-imu)
     (send self :imu-orientation-on)))
  ;; Madgwick AHRSフィルタ(加速度+ジャイロのセンサフュージョン、磁力計無し版)。
  ;; 加速度だけから姿勢を出すと動作中/ノイズでフラフラするため、ジャイロの
  ;; 角速度積分と加速度による重力方向補正を相補的に組み合わせて安定化する。
  ;; 実装は Sebastian Madgwick の公開アルゴリズム(MadgwickAHRSupdateIMU)に準拠。
  ;; 状態(クォータニオン)は propertied-object の :imu-q プロパティに保持する。
  ;; クォータニオンを単位姿勢から始めると、実際の重力方向とかけ離れている
  ;; 場合に収束するまで数秒かかり不安定に見えるため、最初の加速度センサ値
  ;; から直接ウォームスタートする(基準ベクトル#f(0 0 1)を加速度方向へ
  ;; 向ける最短回転のクォータニオン)。
  (:madgwick-reset
   (&key (calib-n 10) (calib-wait 0.03))
   (let* ((imu (send self :read-imu))
	  (a0 (if imu (cadr (memq :accel imu)) #f(0.0 0.0 1.0)))
	  ;; :read-gravity-imu の :madgwick-update 呼び出しと同じくZ軸反転規約に揃える
	  (a (normalize-vector (float-vector (elt a0 0) (elt a0 1) (* -1 (elt a0 2)))))
	  (ref #f(0.0 0.0 1.0))
	  ;; gベクトル復元式(R^T*ref)と整合させるため、a→ref(refをaへではなく
	  ;; aをrefへ向ける)向きのクォータニオンにする。
	  (v (v* a ref))
	  (w (+ 1.0 (v. a ref)))
	  (q (float-vector w (elt v 0) (elt v 1) (elt v 2)))
	  (n (norm q))
	  (bsum (float-vector 0.0 0.0 0.0)) (bn 0))
     (send self :put :imu-q
	   (if (> n 1e-6) (scale (/ 1.0 n) q) (float-vector 1.0 0.0 0.0 0.0)))
     (send self :put :imu-yaw 0.0)
     (send self :put :imu-last-gettimeofday nil)
     ;; 静止状態であることを前提に、ジャイロの生値を複数回サンプリングして
     ;; 平均をバイアス(オフセット)として保存する。MEMSジャイロは静止時でも
     ;; ゼロにならず数〜十数deg/sの個体差オフセットを持つため、これを毎回
     ;; 差し引かないとヨー(補正手段の無い軸)は永遠に積分ドリフトし続け、
     ;; ロール/ピッチも収束が遅くなる(実機で「姿勢がゆっくり収束せず動き
     ;; 続ける」症状として確認済み)。
     (dotimes (i calib-n)
       (let* ((s (send self :read-imu)) (g (if s (cadr (memq :gyro s)) nil)))
	 (when g
	   (setq bsum (v+ bsum g))
	   (setq bn (1+ bn))))
       (unix::usleep (round (* calib-wait 1000000))))
     (send self :put :imu-gyro-bias
	   (if (> bn 0) (scale (/ 1.0 bn) bsum) (float-vector 0.0 0.0 0.0)))
     (format t ";; :madgwick-reset imu-gyro-bias(deg/s)=~A (n=~A)~%"
	     (send self :get :imu-gyro-bias) bn)
     (finish-output t)))
  (:madgwick-update
   (gx gy gz ax ay az &optional (dt 0.05) (beta 0.05))
   ;; gx,gy,gz: 角速度[rad/s]  ax,ay,az: 加速度(単位は任意、内部で正規化)
   (let* ((q (or (send self :get :imu-q) (float-vector 1.0 0.0 0.0 0.0)))
	  (q0 (elt q 0)) (q1 (elt q 1)) (q2 (elt q 2)) (q3 (elt q 3))
	  qdot1 qdot2 qdot3 qdot4 recip-norm)
     (setq qdot1 (* 0.5 (+ (* -1 q1 gx) (* -1 q2 gy) (* -1 q3 gz))))
     (setq qdot2 (* 0.5 (+ (* q0 gx) (* q2 gz) (* -1 q3 gy))))
     (setq qdot3 (* 0.5 (+ (* q0 gy) (* -1 q1 gz) (* q3 gx))))
     (setq qdot4 (* 0.5 (+ (* q0 gz) (* q1 gy) (* -1 q2 gx))))
     (unless (and (= ax 0.0) (= ay 0.0) (= az 0.0))
       (setq recip-norm (/ 1.0 (sqrt (+ (* ax ax) (* ay ay) (* az az)))))
       (setq ax (* ax recip-norm) ay (* ay recip-norm) az (* az recip-norm))
       (let* ((_2q0 (* 2 q0)) (_2q1 (* 2 q1)) (_2q2 (* 2 q2)) (_2q3 (* 2 q3))
	      (_4q0 (* 4 q0)) (_4q1 (* 4 q1)) (_4q2 (* 4 q2))
	      (_8q1 (* 8 q1)) (_8q2 (* 8 q2))
	      (q0q0 (* q0 q0)) (q1q1 (* q1 q1)) (q2q2 (* q2 q2)) (q3q3 (* q3 q3))
	      s0 s1 s2 s3)
	 (setq s0 (+ (* _4q0 q2q2) (* _2q2 ax) (* _4q0 q1q1) (* -1 _2q1 ay)))
	 (setq s1 (+ (* _4q1 q3q3) (* -1 _2q3 ax) (* 4 q0q0 q1) (* -1 _2q0 ay)
		     (* -1 _4q1) (* _8q1 q1q1) (* _8q1 q2q2) (* _4q1 az)))
	 (setq s2 (+ (* 4 q0q0 q2) (* _2q0 ax) (* _4q2 q3q3) (* -1 _2q3 ay)
		     (* -1 _4q2) (* _8q2 q1q1) (* _8q2 q2q2) (* _4q2 az)))
	 (setq s3 (+ (* 4 q1q1 q3) (* -1 _2q1 ax) (* 4 q2q2 q3) (* -1 _2q2 ay)))
	 (setq recip-norm (/ 1.0 (sqrt (+ (* s0 s0) (* s1 s1) (* s2 s2) (* s3 s3)))))
	 (setq s0 (* s0 recip-norm) s1 (* s1 recip-norm)
	       s2 (* s2 recip-norm) s3 (* s3 recip-norm))
	 (setq qdot1 (- qdot1 (* beta s0)))
	 (setq qdot2 (- qdot2 (* beta s1)))
	 (setq qdot3 (- qdot3 (* beta s2)))
	 (setq qdot4 (- qdot4 (* beta s3)))))
     (setq q0 (+ q0 (* qdot1 dt)))
     (setq q1 (+ q1 (* qdot2 dt)))
     (setq q2 (+ q2 (* qdot3 dt)))
     (setq q3 (+ q3 (* qdot4 dt)))
     (setq recip-norm (/ 1.0 (sqrt (+ (* q0 q0) (* q1 q1) (* q2 q2) (* q3 q3)))))
     (setq q0 (* q0 recip-norm) q1 (* q1 recip-norm)
	   q2 (* q2 recip-norm) q3 (* q3 recip-norm))
     (send self :put :imu-q (float-vector q0 q1 q2 q3))
     ;; クォータニオンから、センサ座標系での推定重力方向(=フィルタ後の
     ;; 加速度ベクトル相当)を復元して返す。
     (float-vector (* 2 (- (* q1 q3) (* q0 q2)))
		   (* 2 (+ (* q0 q1) (* q2 q3)))
		   (+ (* q0 q0) (* -1 q1 q1) (* -1 q2 q2) (* q3 q3)))))
  ;; ロボット側ATOM S3のIMU(:read-imu)から得た加速度・角速度をMadgwick
  ;; フィルタで統合し、既存のgravity-method機構(:real-orientation,
  ;; :viewer-updateから汎用的に呼ばれる)に載せるためのアダプタ。RCB4の
  ;; 拡張アナログ端子につないだジャイロ/加速度センサ(:read-gravity,
  ;; :read-gravity2)の代わりにこれをgravity-methodに設定すれば、:timer-on
  ;; で起動するビューア更新が自動的にIMU姿勢(フィルタ済み)を反映する。
  ;; ATOM S3の実装向き(上下逆さ取り付け)に合わせて、実機で確認した
  ;; 補正回転(Z軸-90度、X軸+90度)をかけている。
  (:read-gravity-imu
   ()
   (let* ((imu (send self :read-imu)) (c (make-coords))
	  (now (unix::gettimeofday))
	  (last (send self :get :imu-last-gettimeofday))
	  (dt (if last
		  (+ (- (car now) (car last)) (* 0.000001 (- (cadr now) (cadr last))))
		0.05)))
     (send self :put :imu-last-gettimeofday now)
     (when (or (<= dt 0) (> dt 1.0)) (setq dt 0.05))
     (if imu
	 (let* ((accel (cadr (memq :accel imu)))
		(gyro0 (cadr (memq :gyro imu)))
		;; :madgwick-resetで校正した静止時バイアスを毎回差し引く
		;; (詳細はmadgwick-resetのコメント参照)。
		(bias (or (send self :get :imu-gyro-bias) (float-vector 0.0 0.0 0.0)))
		(gyro (float-vector (- (elt gyro0 0) (elt bias 0))
				     (- (elt gyro0 1) (elt bias 1))
				     (- (elt gyro0 2) (elt bias 2))))
		;; ピッチが逆だったので加速度Z軸のみ反転する。ジャイロ(角速度)は
		;; 軸性ベクトル(疑ベクトル)のため、通常のベクトルとは逆に「反転軸
		;; 以外の2軸」を反転するのが物理的に正しい変換(加速度は反転軸その
		;; ものを反転、ジャイロは反転軸以外=X,Yを反転しZは保持)。
		(g (send self :madgwick-update
			 (deg2rad (* -1 (elt gyro 0))) (deg2rad (* -1 (elt gyro 1))) (deg2rad (elt gyro 2))
			 (elt accel 0) (elt accel 1) (* -1 (elt accel 2))
			 dt)))
	   ;; ヨー(鉛直軸まわりの回転)は加速度からは求まらないため、静止時に
	   ;; 鉛直に近いセンサY軸まわりの角速度(ジャイロ)を積分して別途保持する。
	   ;; :real-orientation側でこの値を使って最後にワールドZ軸回転として足す。
	   (send self :put :imu-yaw
		 (+ (or (send self :get :imu-yaw) 0.0) (* -1 (deg2rad (elt gyro 1)) dt)))
	   (send c :rotate (deg2rad -90) :z)
	   (send c :rotate (deg2rad 90) :x)
	   (send c :rotate-vector g))
       #f(0 0 -1))))
  (:imu-orientation-on
   ()
   (send self :madgwick-reset)
   (setq gravity-method :read-gravity-imu))
  (:imu-orientation-off
   ()
   (send self :init-analog))
  (:real-orientation
   (&optional v)
   ;;(unless com-port (send self :com-init))
   (when com-port
     (let ((g (send self gravity-method)) (m (make-coords))
	   (s (send robot :worldcoords)))
       ;; (send robot :imu-sensor "gsensor") if modeled in gravity-method
       (orient-coords-to-axis m #f(0 0 -1) (normalize-vector g))
       ;; IMUモードのときだけ、加速度からは求まらないヨー(鉛直軸回転)を
       ;; ジャイロ積分値(:read-gravity-imu で更新)からワールドZ回転として追加する。
       (when (eq gravity-method :read-gravity-imu)
	 (send m :rotate (or (send self :get :imu-yaw) 0.0) :z :world))
       (send robot :move-coords m s)
       (if (and v (float-vector-p v))
	   (send robot :rotate-vector v)
	   (send robot :worldcoords)))))
  ;; 近藤科学アナログセンサ(kondo-gravity-method)とATOM S3内蔵IMU
  ;; (:read-gravity-imu、Madgwickフィルタ+ジャイロヨー積分)の姿勢推定を
  ;; 両方その場で計算し、比較用にroll/pitch/yaw(度)を返す。ヨーは重力
  ;; ベクトルだけからは求まらないため、近藤科学側は常にnilになる。
  (:compare-orientation-values
   ()
   (let* ((kondo-g (send self :get :kondo-gravity-method))
	  (kondo-m (make-coords))
	  (kondo-rpy (progn
		       (orient-coords-to-axis kondo-m #f(0 0 -1) (normalize-vector kondo-g))
		       (car (send kondo-m :rpy-angle))))
	  (imu-g (send self :read-gravity-imu))
	  (imu-yaw (or (send self :get :imu-yaw) 0.0))
	  (imu-m (make-coords))
	  (imu-rpy (progn
		     (orient-coords-to-axis imu-m #f(0 0 -1) (normalize-vector imu-g))
		     (send imu-m :rotate imu-yaw :z :world)
		     (car (send imu-m :rpy-angle)))))
     (list :kondo (list :roll (rad2deg (elt kondo-rpy 2))
			 :pitch (rad2deg (elt kondo-rpy 1))
			 :yaw nil)
	   :atoms3-imu (list :roll (rad2deg (elt imu-rpy 2))
			      :pitch (rad2deg (elt imu-rpy 1))
			      :yaw (rad2deg (elt imu-rpy 0))))))
  ;; :timer-onの周期関数として使う想定(例: (send *ri* :timer-on :compare-orientation))。
  ;; 比較値を1行にプリントしつつ、通常通り:viewer-updateも呼んでビューア/角度は
  ;; 従来通り更新する(モデルを実際に駆動するのは現在のgravity-method側のまま)。
  (:compare-orientation
   ()
   (when com-port
     (let* ((v (send self :compare-orientation-values))
	    (k (cadr (memq :kondo v))) (a (cadr (memq :atoms3-imu v))))
       (format t "kondo: roll=~A pitch=~A yaw=N/A   |   atoms3-imu: roll=~A pitch=~A yaw=~A~%"
	       (round (cadr (memq :roll k))) (round (cadr (memq :pitch k)))
	       (round (cadr (memq :roll a))) (round (cadr (memq :pitch a))) (round (cadr (memq :yaw a))))
       (finish-output t))
     (send self :viewer-update)))
  (:viewer-update
   nil
   ;;(send *irtviewer* :draw-objects :flush t)
   (when
       com-port
     (send self :set-sysreg-bits '((:rom-on . 0) (:response-on . 0)))
     (send self :real-orientation)
     (send self :read-sensors)
     (send robot :angle-vector (send self :read-angle-vector))
     (send self :set-sysreg-bits '((:rom-on . 1)))
     (send self :m5stickv-auto-update)
     )
   (when (send self :viewer)
     (send self :viewer :viewer :draw-objects :flush nil)
     (send self :draw-torque :flush nil :size 1.0)
     (send self :draw-sensors :flush nil)
     (send self :draw-end-coords :flush nil)
     (send self :draw-zmp-coords :flush nil)
     (send self :viewer :viewer :flush)
     )
   )
  )

;; ~/rcb4eus/rubikcube.l のrubik-cube クラス(kociembaのpython実装を
;; piped-forkで呼ぶ:kociembaメソッドを持つ)を使って、M5StickVで読み取った
;; 色配置からキューブを揃える手順を求める。*rcb4eus-dir*(kxreus)の
;; *load-path*には乗っていない場所にあるため、フルパス指定で明示的にload
;; する(require :rubikcubeはrcb4eus内から読んだ場合のみ解決できるため)。
(defparameter *rubikcube-loaded* nil)
(defun ensure-rubikcube-loaded ()
  (unless *rubikcube-loaded*
    (load "/home/inaba/rcb4eus/rubikcube.l")
    (setq *rubikcube-loaded* t)))

;; irtviewer表示用に使い回す、永続的なrubik-cubeインスタンス。
;; (:draw-m5stickv-apriltag-cube用の*m5stickv-cube*と同じパターン。)
(defparameter *m5stickv-rubik-cube* nil)
(defun ensure-m5stickv-rubik-cube ()
  (ensure-rubikcube-loaded)
  (unless *m5stickv-rubik-cube*
    (setq *m5stickv-rubik-cube* (instance rubik-cube :init :dim 3))
    (send *m5stickv-rubik-cube* :clear-colors)
    (objects (list *m5stickv-rubik-cube*)))
  *m5stickv-rubik-cube*)

(defmethod rcb4-interface
  ;; face-colors: ((axis . 9色名リスト) ...) のalist。
  ;; axisはrubik-cubeクラスの:set-colorsが受け付ける軸名(:x :x- :y :y- :z :z-)。
  ;; rubik-cube側の軸とkociembaのU/R/F/D/L/Bの対応は :z->u :y->r :x->f
  ;; :z->-d :y-->l :x-->b (rubikcube.lの:axis2face参照)。実機のどのカメラ面
  ;; (0x24/0x25、あるいは今後追加するロボット手首回転での他の面)がどの軸に
  ;; あたるか、また9マスの読み取り順がrubik-cube側の並び順(:select-bssの
  ;; ソート順)と一致しているかは未検証。実機で1面ずつ既知のパターンを見せて
  ;; 対応を確認してから使うこと(0x24/0x25の並び順統一で行ったのと同様の
  ;; 手順)。
  ;; fill-missingが非nilで6面揃っていない場合、rubik-cube側の:fill-allで
  ;; 残りの面を消去法的に推定する(rubikdemo.lのdemo-cube0などと同じ手順)。
  ;; 戻り値はSingmaster記法の手順シンボルのリスト(例: (u r u- r- ...))。
  ;; 無効な配置だった場合はnilを返す。
  (:m5stickv-cube-solve
   (face-colors &key (fill-missing t))
   (ensure-rubikcube-loaded)
   (let ((rc (instance rubik-cube :init :dim 3)))
     ;; rubik-cube側の:state(:kociembaが内部で呼ぶ)は(send *irtviewer*
     ;; :draw-objects)を無条件に呼ぶため、objectsで*irtviewer*に登録して
     ;; おく必要がある(rubikdemo.l/rubikcube.lのデモ関数と同じ手順)。
     (objects (list rc))
     (send rc :clear-colors)
     (dolist (fc face-colors)
       (send rc :set-colors (car fc) (cdr fc)))
     (when (and fill-missing (< (length face-colors) 6))
       (send rc :fill-all))
     (let ((moves (send rc :kociemba)))
       (if moves
	   (format t "[m5stickv-cube-solve] ~A steps: ~A~%" (length moves) moves)
	 (format t "[m5stickv-cube-solve] failed (invalid or incomplete cube state)~%"))
       moves)))
  ;; i2c-addrのM5StickVで今見えている面の9マスを読み取り、永続的な
  ;; rubik-cube表示モデル(*m5stickv-rubik-cube*)のaxis面に反映して
  ;; irtviewerに描画する。同じインスタンスを使い回すので、複数回・複数の
  ;; 面(axisを変えて)呼べば、それまでに読んだ面の色が累積して表示される。
  ;; axisの実機カメラとの対応(0x24/0x25がどの軸にあたるか)は:m5stickv-
  ;; cube-solveと同様まだ未検証で、デフォルト:zは仮値。呼び出し側で明示的に
  ;; axisを指定して使うこと。読み取れなかった場合はnilを返し、表示も変えない。
  (:m5stickv-cube-show-face
   (i2c-addr &key (axis :z) (palette *m5stickv-cube-colors*))
   (let ((colors (send self :read-m5stickv-cube-face-colors i2c-addr palette))
	 (rc (ensure-m5stickv-rubik-cube)))
     (when colors
       (send rc :set-colors axis colors)
       (send *irtviewer* :draw-objects)
       (format t "[m5stickv-cube-show-face] addr=0x~X axis=~A colors=~A~%" i2c-addr axis colors))
     colors))
  ;; *m5stickv-rubik-cube*表示モデルを初期状態(全面グレー)に戻す。
  ;; 新しいキューブ/新しいスキャンをやり直す時に使う。
  (:m5stickv-cube-reset-viewer
   ()
   (let ((rc (ensure-m5stickv-rubik-cube)))
     (send rc :clear-colors)
     (send *irtviewer* :draw-objects)))
  )



