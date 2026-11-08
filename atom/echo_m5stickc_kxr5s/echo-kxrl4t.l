;;;
;;; echo-kxrl4t.l -- PC側ATOM Echo経由(ESP-NOW無線)でkxrl4tに接続し、
;;;                  :timer-onで実機の姿勢をirtviewerに表示する
;;;
;;; 経路: PC --USB(500000bps)--> ATOM Echo ~~ESP-NOW ch1~~> M5StickC --UART--> RCB4
;;;
;;; 使い方 (~/kxreus で irteusgl を起動):
;;;   $ cd ~/kxreus
;;;   $ irteusgl atom/echo_m5stickc_kxr5s/echo-kxrl4t.l
;;;   1.irteusgl$ (echo-init)              ;; モデル+viewer作成、Echoのポートをオープン
;;;   2.irteusgl$ (send *ri* :timer-on)    ;; 0.1秒ごとに実機の角度を読みviewerを更新
;;;   3.irteusgl$ (send *ri* :timer-off)   ;; 更新停止
;;;
;;; 事前準備:
;;;   - ATOM Echo を usbipd で WSL に attach しておく(/dev/ttyUSB* として見える)。
;;;     Windows管理者PowerShell: usbipd attach --wsl --busid <EchoのBUSID>
;;;   - M5StickC は WiFi 認証情報を消去した状態(net!)で起動していること
;;;     (../README.md の「注意: M5StickC の WiFi 設定」参照)。
;;;
;;; 2026-11-08 実機確認: サーボID 2-9 が応答(ID 1 = head-neck-y は未接続)。
;;; ID 2-9 は rcb4robotconfig.l の "kxrl4t" (4脚・各2自由度) の割り当てと一致する。
;;;

(load "semi2024.l")
;; :read-imu (RCB4拡張命令0x90 -> M5StickCが横取りして内蔵IMUの値を返す)、
;; Madgwickフィルタ、:init-analogでのIMU姿勢自動有効化、ヨーを足す
;; :real-orientation、:viewer-update(sysreg復元修正版)を使う。
(require :atominterface)

;;; ---- M5StickC 内蔵IMUによる姿勢推定 ----
;;; atominterface.l の :read-gravity-imu / :madgwick-reset は「ロボット側AtomS3を
;;; 上下逆さに取り付けた」機体用の軸補正(加速度Z反転、Z-90度、X+90度、ヨーはセンサY軸)
;;; が埋め込まれている。M5StickC は取り付け向きが違うので、このファイルを読んだ
;;; irteusgl の中だけ、この2メソッドを「生のセンサ値 + *echo-imu-mount* で
;;; センサ座標->ロボット胴体座標へ回す」汎用版に置き換える(atominterface.l 自体は変更しない)。
;;; メソッド名は :read-gravity-imu のままにしてあるので、atominterface.l の
;;; :real-orientation のヨー加算(gravity-method が :read-gravity-imu の時だけ)もそのまま効く。
;;;
;;; *echo-imu-mount*: M5StickC のセンサ座標をロボット胴体座標へ移す回転。
;;;   2026-11-08 時点、机に置いた静止状態で accel ≈ (-0.1 -0.1 1.02) なので
;;;   センサZ ≈ 胴体の上向き。水平面内の向き(Z軸まわり)は実機で傾けて合わせる:
;;;     (echo-imu-mount :yaw 90)          ; Z軸まわり90度
;;;     (echo-imu-mount :yaw 0 :flip t)   ; 上下逆さ(X軸まわり180度)取り付け
;;;   2026-11-08 実機で傾けて確認: Z軸まわり -90度 で胴体の前後左右と一致。
(defparameter *echo-imu-mount* (make-coords :rpy (list (deg2rad -90) 0 0)))

(defun echo-imu-mount (&key (yaw 0) flip)
  "M5StickCの取り付け向きを設定し、Madgwickフィルタを初期化し直す。"
  (setq *echo-imu-mount* (make-coords))
  (send *echo-imu-mount* :rotate (deg2rad yaw) :z)
  (when flip (send *echo-imu-mount* :rotate pi :x))
  (when (and (boundp '*ri*) *ri* (*ri* . com-port))
    (send *ri* :madgwick-reset))
  *echo-imu-mount*)

(defmethod rcb4-interface
  (:madgwick-reset
   (&key (calib-n 10) (calib-wait 0.03))
   ;; 生の加速度(静止時は上向き=重力の反力)からクォータニオンをウォームスタートし、
   ;; 静止時のジャイロ平均をバイアスとして保存する(atominterface.l版と同じ手順、軸反転なし)。
   (let* ((imu (send self :read-imu))
          (a0 (if imu (cadr (memq :accel imu)) #f(0.0 0.0 1.0)))
          (a (normalize-vector a0))
          (ref #f(0.0 0.0 1.0))
          (v (v* a ref))
          (w (+ 1.0 (v. a ref)))
          (q (float-vector w (elt v 0) (elt v 1) (elt v 2)))
          (n (norm q))
          (bsum (float-vector 0.0 0.0 0.0)) (bn 0))
     (send self :put :imu-q
           (if (> n 1e-6) (scale (/ 1.0 n) q) (float-vector 1.0 0.0 0.0 0.0)))
     (send self :put :imu-yaw 0.0)
     (send self :put :imu-last-gettimeofday nil)
     (dotimes (i calib-n)
       (let* ((s (send self :read-imu)) (g (if s (cadr (memq :gyro s)) nil)))
         (when g (setq bsum (v+ bsum g) bn (1+ bn))))
       (unix::usleep (round (* calib-wait 1000000))))
     (send self :put :imu-gyro-bias
           (if (> bn 0) (scale (/ 1.0 bn) bsum) (float-vector 0.0 0.0 0.0)))
     (format t ";; :madgwick-reset (M5StickC) imu-gyro-bias(deg/s)=~A (n=~A)~%"
             (send self :get :imu-gyro-bias) bn)
     (finish-output t)))
  (:read-gravity-imu
   ()
   ;; 戻り値: ロボット胴体座標での重力方向(下向き)。:real-orientation がこれを
   ;; #f(0 0 -1) に合わせるように胴体を回す。
   (let* ((imu (send self :read-imu))
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
                (bias (or (send self :get :imu-gyro-bias) (float-vector 0.0 0.0 0.0)))
                (gyro (v- gyro0 bias))
                ;; センサ座標での推定「上向き」ベクトル(静止時の加速度と同じ向き)
                (up-s (send self :madgwick-update
                            (deg2rad (elt gyro 0)) (deg2rad (elt gyro 1)) (deg2rad (elt gyro 2))
                            (elt accel 0) (elt accel 1) (elt accel 2)
                            dt))
                (rot (send *echo-imu-mount* :worldrot))
                (up-b (transform rot up-s))
                (gyro-b (transform rot gyro)))
           ;; ヨーは加速度から求まらないので、胴体Z軸まわりの角速度を積分する
           (send self :put :imu-yaw
                 (+ (or (send self :get :imu-yaw) 0.0) (* (deg2rad (elt gyro-b 2)) dt)))
           (scale -1.0 up-b))
       #f(0 0 -1)))))

;;; ---- sysreg の扱い (:call-motion / :jump-motion / :viewer-update) ----
;;; 2026-11-08 実機 (RCB4 電源投入直後) で確認した事実:
;;;   - 正常な待機状態は sysreg=#xC293 (ics-on=1, rom-on=1, response-on=0)。
;;;     プログラムカウンタは RAM #x44B〜#x46D を回っている。
;;;   - RAM の読み出し (:move (:ram ..) (:com)) は response-on=0 でも、ROM モーション
;;;     再生中でも、正しい長さの応答が返る。
;;;   - rcb4interface.l の :call-motion (最後に rom-on=1, response-on=0) ではモーション0が
;;;     約2.8秒 PC #xBA3〜#xC8F を進んで正常終了する。ただし response-on=0 の区間で ACK を
;;;     待つので ";; (:read-msg :start 1) str=\"\" str.len=-1" が出る(無害な待ち時間)。
;;;   - response-on=1 のまま ROM モーションを走らせると、ROM 命令の応答が COM に流れ出し、
;;;     PC 側の読み出しフレームが壊れ(13バイトの不正応答)、モーションも約0.5秒で途中終了する。
;;;     atominterface.l の :viewer-update は毎tick最後に response-on=1 にするので、
;;;     :timer-on 中の :call-motion でこれが起き、読み出しがずれてハングした。
;;;     さらに壊れた応答を sysreg として読んで書き戻し、com/frame ビットまで壊れた (#x8266)。
;;; 方針:
;;;   - :viewer-update は sysreg に一切触らない (RAM と IMU を読むだけ)。
;;;   - :call-motion は応答を待たずに送り、最後は rom-on=1, response-on=0 に戻す。
;;;     書き込む値の com/frame/ics ビットは echo-init 時の正常値 *echo-sysreg* と照合する。
(defvar *echo-sysreg* nil)  ;; echo-init 時に読んだ正常な sysreg

;; sysreg のうち、通信速度・フレーム周期・ICS 設定 (壊れると通信不能になるビット)
(defconstant +echo-sysreg-config-mask+ (logior (ash 1 0) (ash #b1111 4) (ash #b11 13)))

(defun echo-sysreg-sane-p (v)
  (and (integerp v) *echo-sysreg*
       (= (logand v +echo-sysreg-config-mask+)
          (logand *echo-sysreg* +echo-sysreg-config-mask+))))

(defmethod rcb4-interface
  (:send-sysreg-no-wait (lo-hi)
   (send self :send-cmd-no-wait `(:move (:lit ,(car lo-hi) ,(cadr lo-hi)) (:ram #x0))))
  (:read-sysreg-safe
   ()
   ;; 応答を待ってハングしないよう、時間切れ付きで読む
   (send com-port :read-all 50)
   (send self :send-cmd-no-wait '(:move (:ram 0 2) (:com)))
   (let ((r (send com-port :read-all 100)))
     (when (= (length r) 5) (+ (elt r 2) (ash (elt r 3) 8)))))
  (:rom-motion-safe
   (op num)
   (when com-port
     (let* ((cur (send self :read-sysreg-safe))
            (base (if (echo-sysreg-sane-p cur) cur
                    (progn
                      (warn ";; :~A-motion: sysreg=~A が正常値 ~A と食い違うので正常値を使います~%"
                            (string-downcase (string op)) cur *echo-sysreg*)
                      *echo-sysreg*))))
       (unless base
         (warn ";; :rom-motion-safe: 正常な sysreg が未取得です。(echo-init) し直してください。~%")
         (return-from :rom-motion-safe nil))
       (send self :send-sysreg-no-wait
             (send self :gen-sysreg-word '((:rom-on . 0) (:response-on . 0)) base))
       (unix:usleep 20000)
       (send self :send-cmd-no-wait `(,op nil (:motiontable ,num)))
       (unix:usleep 20000)
       (send self :send-sysreg-no-wait
             (send self :gen-sysreg-word '((:rom-on . 1) (:response-on . 0)) base))
       (send com-port :read-all 100)  ;; 念のため残りを読み捨てる
       num)))
  (:call-motion (num) (send self :rom-motion-safe :call num))
  (:jump-motion (num) (send self :rom-motion-safe :jump num))
  (:read-pc
   ()
   (send self :send-cmd-no-wait '(:move (:ram #x02 3) (:com)))
   (let ((r (send com-port :read-all 100)))
     (when (= (length r) 6) (+ (elt r 2) (ash (elt r 3) 8) (ash (elt r 4) 16)))))
  (:rom-motion-playing
   ()
   (let ((pc (send self :read-pc)))
     (and pc (>= pc #x0B80) (< pc #x3cb80))))
  (:viewer-update
   nil
   (when com-port
     ;; sysreg には触らない (上のコメント参照)
     (send self :real-orientation)
     (send self :read-sensors)
     (send robot :angle-vector (send self :read-angle-vector)))
   (when (send self :viewer)
     (send self :viewer :viewer :draw-objects :flush nil)
     (send self :draw-torque :flush nil :size 1.0)
     (send self :draw-sensors :flush nil)
     (send self :draw-end-coords :flush nil)
     (send self :draw-zmp-coords :flush nil)
     (send self :viewer :viewer :flush))))

(defun echo-pc ()
  "RCB4 のプログラムカウンタ・sysreg と、ROMモーション再生中と判定されるかを表示する(確認用)。"
  (let ((pc (send *ri* :read-pc)) (sr (send *ri* :read-sysreg-safe)))
    (format t ";; pc=~A sysreg=~A playing=~A~%"
            (if pc (format nil "#x~X" pc) pc) (if sr (format nil "#x~X" sr) sr)
            (and pc (>= pc #x0B80) (< pc #x3cb80)))
    pc))

(defun echo-recover ()
  "sysreg を echo-init 時の正常値 (rom-on=1, response-on=0) に応答を待たずに書き戻し、
   読み出しで復帰を確認する。"
  (unless *echo-sysreg* (error "echo-recover: 正常時の sysreg が未取得です。RCB4 の電源を入れ直してください。"))
  (send *ri* :send-sysreg-no-wait
        (send *ri* :gen-sysreg-word '((:rom-on . 1) (:response-on . 0)) *echo-sysreg*))
  (send (*ri* . com-port) :read-all 200)
  (let ((sr (send *ri* :read-sysreg-safe)))
    (if (echo-sysreg-sane-p sr)
        (progn (format t ";; echo-recover: 復帰しました sysreg=#x~X~%" sr) t)
      (progn (warn ";; echo-recover: sysreg=~A のままです。RCB4 の電源を入れ直してください。~%" sr) nil))))


;; このATOM EchoのFTDIシリアル番号(udevadmで確認済み)。
(defparameter *echo-serial* "4D5217E152")

(defun echo-find-devname (&optional (serial *echo-serial*))
  "FTDIシリアル番号が一致する /dev/ttyUSB* を返す。無ければ ttyUSB0。"
  (let (found)
    (dolist (dev (ttyusb-devnames-echo))
      (when (and (null found)
                 (equal (echo-udev-attr dev "serial") serial))
        (setq found dev)))
    (or found
        (progn
          (warn ";; echo-find-devname: serial ~A の ttyUSB が見つからないため ttyUSB0 を使います~%" serial)
          "ttyUSB0"))))

(defun ttyusb-devnames-echo ()
  (let ((strm (piped-fork "ls -1 /dev/ttyUSB* 2>/dev/null | xargs -n1 basename"))
        ret v)
    (while (setq v (read-line strm nil nil)) (push v ret))
    (close strm)
    (reverse ret)))

(defun echo-udev-attr (devname attr)
  (let* ((strm (piped-fork
                (format nil "udevadm info -a -n /dev/~A 2>/dev/null | grep -m1 'ATTRS{~A}' | sed -E 's/.*==\"([^\"]*)\"/\\1/'"
                        devname attr)))
         (line (read-line strm nil nil)))
    (close strm)
    (when (and line (> (length line) 0)) line)))

(defun echo-init (&key (name "kxrl4t") devname (baud 500000) ((:viewer vw) (xwindow-ready?)))
  "ロボットモデルとviewerを作り、ATOM Echoのポートを開いてRCB4と初期化ハンドシェイクする。
   この後 (send *ri* :timer-on) で姿勢表示を開始する。"
  (unless devname (setq devname (echo-find-devname)))
  (format t ";; echo-init: robot=~A devname=/dev/~A baud=~A~%" name devname baud)
  ;; *robot* (緑のviewer) と *ri* (紫のviewer) を作る。ポートはまだ開かない。
  (make-kxr-robot name :viewer vw)
  ;; :timer-on は com-port が既に開いていると :com-init(=既定の近藤USBアダプタ探索)を
  ;; 飛ばすので、先にEchoのポートを開いて :rcb4-open のハンドシェイクだけ行う。
  (send *ri* :com-open :devname devname :baud baud)
  (unix:sleep 1)
  ;; :rcb4-open -> :init-analog が :read-imu の応答を見て自動で :imu-orientation-on
  ;; (= :madgwick-reset + gravity-method を :read-gravity-imu に) する。
  ;; Madgwick初期化時のジャイロバイアス校正のため、ここではロボットを静止させておくこと。
  (send *ri* :rcb4-open)
  (setq *echo-sysreg* (send *ri* :read-sysreg-safe))
  (format t ";; echo-init: sysreg=~A~%" (if *echo-sysreg* (format nil "#x~X" *echo-sysreg*)))
  (unless (eq (*ri* . gravity-method) :read-gravity-imu)
    (if (send *ri* :read-imu)
        (send *ri* :imu-orientation-on)
      (warn ";; echo-init: M5StickCのIMUが応答しません。RCB4アナログ入力の姿勢を使います。~%")))
  (format t ";; echo-init: gravity-method=~A mount=~A~%"
          (*ri* . gravity-method) (send *echo-imu-mount* :worldrot))
  (format t ";; echo-init: 接続しました。(send *ri* :timer-on) で表示を開始します。~%")
  *ri*)

(format t "~%;; echo-kxrl4t.l loaded.~%;;   (echo-init)~%;;   (send *ri* :timer-on)~%;;   (send *ri* :timer-off)~%")
