;;;
;;; eusview.l : EusView デモ（irteusgl / roseus で動く版）
;;;	2026.10.5
;;;
;;;  iPhone / Mac の EusView アプリ（ロボットの形・姿勢・モーション・物理）と同じことを
;;;  irtviewer と EusLisp の X パネルで行うデモ。kxreus の部品を使う:
;;;    ロボットの生成     (kxr-make-robot name :model nil)  rcb4robots.l, *kxr-body-config-alist*
;;;    モーション         rcb4-interface の RCB4 エミュレーション (:emulate-motion-code)
;;;                       projects/Hello_<project>/*.h4p のモーション表（:set-project-file）
;;;    モーションのメニュー  kxrviewer.l の :create-2d-menu-buttons と同じ形（ラベルは Xft で日本語）
;;;    物理               kxrdyna.l / odedyna.l（eusdyna, libeusode があるとき）, なければ
;;;                       eusview-physics.l（EusView アプリと同じ ODE の C 層 eusview-ode/ を
;;;                       make eusview-ode で $ARCHDIR/lib/libeusviewode.so にしたもの）
;;;    日本語の表示       eusview-xft.l（libXft + fontconfig。日本語フォントがなければ ASCII だけ）
;;;
;;; 使い方:
;;;   cd ~/kxreus
;;;   make eusview-ode                    ;; 物理用（Ubuntu: 先に sudo apt install libode-dev）
;;;   irteusgl eusview.l "(eusview)"      ;; roseus eusview.l "(eusview)" でもよい
;;;   (eusview "kxrl4t")                  ;; 最初に出すロボットを指定
;;;   make eusview                        ;; 同じ（端末から）
;;;   make eusview-desktop                ;; デスクトップとアプリ一覧のアイコン（Ubuntu）を作る。
;;;                                       ;; クリックで eusview.sh が起動（出力は ~/.cache/eusview.log）
;;;   make eusview-desktop EUSVIEW_TERMINAL=true  ;; 端末（REPL）つきで起動するアイコン
;;;   ./eusview.sh [name]                 ;; irteusgl / roseus を探して起動（ROS や ~/jskeus/bashrc.eus も見る）
;;;   日本語（モーション名・状態の行）は Xft で描く。Ubuntu: libxft2 と fonts-noto-cjk
;;;   （か fonts-ipafont / fonts-takao）。フォントは EUSVIEW_FONT="Noto Sans CJK JP" で指定できる。
;;;
;;;   EusView ウィンドウ（パネル）:
;;;     KXR / KHR / JSK のメニュー  ロボットを選ぶ（KXR/KHR は kxreus, JSK は $EUSDIR/models と irteus/demo）
;;;     name:                       ロボット名を入れて Enter（kxreus の (kxr-all-robot-names) のどれでも,
;;;                                 JSK のモデル名, .l ファイルのパス）
;;;     list all                    kxreus で作れるロボット名を端末に表示
;;;   ロボットのパネル（ロボットごと）:
;;;     zero / reset-pose / init-pose ...   そのロボットにある姿勢
;;;     motion 0- / 20- ...         プロジェクトのモーション表（RCB4 のエミュレーションで再生）。
;;;                                 選んだ動作を stop まで繰り返す（アプリと同じ）。再生中に別の動作を選ぶと
;;;                                 切り替わる。パネルに「再生中: 番号 名前（n 回目）」。
;;;                                 プロジェクトは projects/Hello_<:project-file>/*.h4p（KHR: Hello_khr3,
;;;                                 khr3semi のロボットは Hello_khr3sl5a3h2 の KHR-3HV サンプルを使う
;;;                                 *eusview-project-alias*）。見つからなければ探した場所を表示する
;;;     stop                        再生を止める
;;;     physics: off / ON           トグル。ODE で動かす / もう一度押すと止めて元の姿勢に戻す。床は z = 0,
;;;                                 今の姿勢で床に置く。姿勢・スライダー・モーションはサーボの目標になる。
;;;                                 状態の行に経過時間・接触点の数・腰の位置
;;;     servo: on / OFF             トグル。サーボ on / off（脱力）（eusview-physics.l のとき）
;;;     live: off / ON              トグル。関節角を EusView アプリへ送る（eusview-live.py が中継, 下を参照）
;;;     関節のスライダー
;;;
;;;   live: 中継（TCP 8767 / WebSocket 8766）が動いていなければ kxreus の eusview-live.py を
;;;         python3 でバックグラウンドに起動する（ログ ~/.cache/eusview-live.log, quit で止める。
;;;         ほかで動いている中継があればそれを使う）。パネルに iPhone に入れるアドレス
;;;         「ws://<この PC の LAN の IP>:8766/」と、つながっている iPhone の台数（eusview-live.py のとき）
;;;         を出す。iPhone の EusView の「接続」にそのアドレスを入れ、アプリでも同じロボットを選ぶ。
;;;         送り先は環境変数 EUSVIEW_LIVE_HOST（既定 localhost）, EUSVIEW_LIVE_PORT（既定 8767）。
;;;
;;;   変数: *eusview-kxr-model*  kxr-make-robot の :model（既定 nil = kxr-robot をそのまま作る,
;;;                               models/ にファイルを書かない。:auto にすると models/*.l を使う）
;;;         *eusview-fps*        再生のフレーム数 / 秒
;;;
(require :rcb4robots)
(require :kxrviewer) ;; panel :create-2d-menu-buttons
(require :eusview-physics) ;; ODE without kxrdyna.l (libeusviewode.so, make eusview-ode)
(require :eusview-xft)     ;; Japanese labels (motion names, status) with Xft

(defvar *eusview-kxr-robots*
  '("kxrl2l5a3h2" "kxrl2l6a6h2" "kxrl4t" "kxrl4r" "kxrl4d" "kxrl6" "kxra6g"
    "kxrl2l2a6h2m" "kxrl2l5a3" "kxrl2l5a3h2g" "kxrl2l5a4h2g" "kxrl2l5a6h2m0" "kxrl2l6a4"
    "kxrl2l6a5h2" "kxrl2l6a6" "kxrl2l6a6h2g" "kxrl2l6a6h2n" "kxrl2l6a7" "kxrl2l6a7h2"
    "kxrl2l6a7h2n" "kxrl2l6a7h2w" "kxrl2w2l5a3h2" "kxrl2w2l5a4h2" "kxrl2w2l6a4h2"
    "kxrl2w2l6a5h2" "kxrl2w2l6a7h2w" "kxrl4l2a6h2m" "kxrl4nh4" "kxrl4r2a3" "kxrl4r2a3g"
    "kxrl4rh" "kxrl4tm" "kxrmw4a6h2m" "kxrt1l2l2d7h2m" "kxrt1l2l2e7h2m" "kxrt1l2l2w7h2m"))
(defvar *eusview-khr-robots*
  '("khr3" "khr3sl5a3h2" "khr20" "khr20h2" "khr22" "khr22h2" "khr23oh" "khr23semi1"
    "khr23semi2" "khr23semi3" "khr23semi4" "khr24semis3" "khr3semi" "khr3semi2" "khr3semi3"
    "khr3semi4" "khranzaifly" "khranzaifly5" "khrh2ganzaiflys" "khrl5a3h2" "khrl5a3h2g"
    "khrl5a3h2wg" "khrl5a4h2g" "khrl5a4h2wg" "khrl6a3h2" "khrl6a3h2g" "khrl6a3h2m"
    "khrl6a3h2wg" "khrl6a4h2" "khrl6a4h2g" "khrl6a4h2wg" "khrnishio" "khrt1l5a3h2g"
    "khrt1l5a3h2wg" "khrt1l5a4h2g" "khrt1l5a4h2wg" "khrt1l6a3h2" "khrt1l6a3h2g"
    "khrt1l6a3h2m" "khrt1l6a3h2wg" "khrt1l6a4h2" "khrt1l6a4h2g" "khrt1l6a4h2wg"))
;; JSK: $EUSDIR/models/<name>-robot.l (darwin.l) と irteus/demo のロボット
(defvar *eusview-demo-robots*
  '(("sample-robot" "irteus/demo/sample-robot-model.l" sample-robot)
    ("sample-arm" "irteus/demo/sample-arm-model.l" sarmclass)
    ("sample-hand" "irteus/demo/sample-hand-model.l" sample-hand)
    ("sample-multidof-arm" "irteus/demo/sample-multidof-arm-model.l" sample-multidof-arm-robot)))
(defvar *eusview-jsk-robots*
  '("sample-robot" "sample-arm" "sample-hand" "sample-multidof-arm"
    "akira" "akira2" "akira3" "ape" "ape3" "bishamon" "chibikaz" "darwin" "h3" "h3s" "h4" "h6" "h7"
    "hanzou" "hanzous" "human" "igoid" "igoid2" "igoid3" "ikuo-haru" "jrob1" "kaz" "kaz2" "kaz3"
    "kuma" "macket" "macra" "miharu" "millennium" "patra" "penguin" "saizo" "tama" "tamaii" "taro"
    "tot" "zero"))
;; KHR のプロジェクトは kxreus にないことが多いので、ここも探す（Hello_<project>/*.h4p）
(defvar *eusview-project-dirs*
  (list (format nil "~A/prog/rcb4eus/projects" (unix:getenv "HOME"))))

(defvar *eusview-kxr-model* nil)
(defvar *eusview-fps* 30)
(defvar *eusview-menu-rows* 25)
(defvar *eusview-max-motion-sec* 30.0)

(defvar *eusview-viewer* nil)
(defvar *eusview-panel* nil)
(defvar *eusview-robot-panel* nil)
(defvar *eusview-old-panels* nil)
(defvar *eusview-robot* nil)
(defvar *eusview-ri* nil)
(defvar *eusview-name* nil)
(defvar *eusview-group* nil)
(defvar *eusview-playing* nil)
(defvar *eusview-stop* nil)
(defvar *eusview-physics* nil)
(defvar *eusview-running* nil)
(defvar *eusview-live* nil)
(defvar *eusview-live-last* nil)
(defvar *eusview-live-time* 0)

;;;
;;; errors: an error in one robot must not kill the panel
;;;
(defvar *eusview-last-error* nil)
(defun eusview-error-handler (code msg1 form &optional msg2)
  (let ((s (format nil "~A~A~A" msg1 (if msg2 (format nil " ~A" msg2) "")
                   (if form (format nil " in ~S" form) ""))))
    (if (> (length s) 300) (setq s (subseq s 0 300)))
    (setq *eusview-last-error* s)
    (format *error-output* ";; eusview: error: ~A~%" s)
    (throw :eusview-error :error)))
(defmacro eusview-protect (&rest body)
  `(catch :eusview-error
     (let ((*error-handler* 'eusview-error-handler))
       ,@body)))

;; status messages in Japanese when Xft has a Japanese font (else English, ASCII only)
(defvar *eusview-ja*
  '(("stop the motion first" . "モーションを止めてから選んでください")
    ("making ~A (~A) ..." . "~A (~A) を作っています...")
    ("could not make ~A: ~A" . "~A を作れませんでした: ~A")
    ("~A: no rcb4-interface (no motions): ~A" . "~A: rcb4-interface を作れません（モーションなし）: ~A")
    ("~A (~A): ~A joints, ~A motions" . "~A (~A): 関節 ~A, モーション ~A")
    ("~A ~A" . "~A ~A")
    ("~A ~A: ~A" . "~A ~A: ~A")
    ("no motion ~A" . "モーション ~A はありません")
    ("playing (press stop)" . "再生中です（stop で止める）")
    ("~A: emulating motion ~A ~A ..." . "~A: モーション ~A ~A を計算しています...")
    ("motion ~A: ~A" . "モーション ~A: ~A")
    ("motion ~A ~A: no servo command" . "モーション ~A ~A: サーボ命令がありません")
    ("playing: ~A ~A (~A, ~4,1f s~A)" . "再生中: ~A ~A（~A 回目, ~4,1f 秒~A）")
    ("stop the motion" . "モーションを止めました。もう一度ロボットを選んでください")
    ("no motion project (searched: ~A)" . "動作のプロジェクトが見つかりません（探した場所: ~A）")
    ("physics ~A: t ~5,1f s, contacts ~A, root x ~4,0f y ~4,0f z ~4,0f mm~A" .
     "物理 ~A: ~5,1f 秒, 接触点 ~A, 腰 x ~4,0f y ~4,0f z ~4,0f mm~A")
    ("physics stopped: ~A" . "物理を止めました: ~A")
    ("physics (kxrdyna, ODE) started" . "物理（kxrdyna, ODE）を始めました")
    ("could not start physics: ~A" . "物理を始められません: ~A")
    ("no physics: no libeusviewode.so (make eusview-ode; Ubuntu: sudo apt install libode-dev), kxrdyna: ~A" .
     "物理は使えません: libeusviewode.so がありません（make eusview-ode。Ubuntu は sudo apt install libode-dev）。kxrdyna: ~A")
    ("physics stopped" . "物理を止めました")
    ("servo ~A" . "サーボ ~A")
    ("servo: start physics first" . "サーボ: 先に physics を押してください")
    ("live: connected to ~A:~A" . "live: ~A:~A につながりました")
    ("live: cannot connect to ~A:~A (run python3 eusview-live.py)" .
     "live: ~A:~A につながりません（python3 eusview-live.py を動かす）")
    ("live: closed" . "live: off（切りました）")
    ("live: no python3 (install python3 to relay to the iPhone)" .
     "live: python3 がありません（iPhone への中継 eusview-live.py には python3 が要ります）")
    ("live: no ~A" . "live: ~A がありません")
    ("live: started the relay ~A (pid ~A, log ~A)" . "live: 中継 ~A を起動しました（pid ~A, ログ ~A）")
    ("live: send failed (closed)" . "live: 送れませんでした（切りました）")
    ("robot names printed in the terminal (~A + JSK ~A)" . "ロボット名の一覧を端末に出しました（~A + JSK ~A）")
    ("stop" . "止めました")
    ("could not make the robot panel: ~A" . "ロボットのパネルを作れません: ~A")))
(defvar *eusview-ja-words*
  '((", truncated" . ", 打ち切り") (", servo off" . ", サーボ off") ("on" . "on") ("off (free)" . "off（脱力）")))
(defun eusview-ja-p () (and (boundp '*xft-font*) *xft-font*))
(defun eusview-message (fmt &rest args)
  (let* ((ja (and (eusview-ja-p) (cdr (assoc fmt *eusview-ja* :test #'equal))))
         (s (if ja
                (apply #'format nil ja
                       (mapcar #'(lambda (a) (or (and (stringp a) (cdr (assoc a *eusview-ja-words* :test #'equal))) a))
                               args))
              (apply #'format nil fmt args))))
    (format t ";; eusview: ~A~%" s)
    ;; without Xft the X core fonts have no Japanese: drop non-ASCII characters (motion names)
    (when (and *eusview-panel* (send *eusview-panel* :status-item))
      (send *eusview-panel* :status-item :value
            (if (eusview-ja-p) s (remove-if #'(lambda (c) (> c 127)) s))))
    s))

(defun eusview-now-ms ()
  (let ((tv (unix:gettimeofday)))
    (+ (* 1000.0 (car tv)) (/ (cadr tv) 1000.0))))

(defun eusview-group-of (name)
  (cond
   ((member name *eusview-jsk-robots* :test #'string=) "JSK")
   ((and (>= (length name) 3) (string= (subseq name 0 3) "khr")) "KHR")
   ((kxr-body-config name) "KXR")
   (t "JSK")))

;;;
;;; viewer (irtviewer) : sends the angles to the app when "live" is on
;;;
(defvar *eusview-background* (float-vector 0.85 0.92 1.0))
(defclass eusview-viewer :super x::irtviewer :slots ())
(defmethod eusview-viewer
  ;; rcb4-machine :create-viewer paints it purple: keep the EusView color
  (:change-background (&rest args) (send-super :change-background *eusview-background*))
  (:draw-objects
   (&rest args)
   (prog1 (send-super* :draw-objects args)
     (if *eusview-live* (eusview-live-send)))))

(defun eusview-make-viewer ()
  (unless *eusview-viewer*
    (setq *eusview-viewer* (instance eusview-viewer :create :title "EusView" :width 600 :height 600
                                     :draw-floor 500))
    (send *eusview-viewer* :change-background *eusview-background*)
    (setq *irtviewer* *eusview-viewer*))
  *eusview-viewer*)

;;;
;;; robots
;;;
(defun eusview-file-name-p (name)
  (let ((n (length name)))
    (and (> n 2) (string= (subseq name (- n 2)) ".l") (probe-file name))))
(defun eusview-jsk-file (name)
  (let ((demo (assoc name *eusview-demo-robots* :test #'string=)))
    (cond
     (demo (cadr demo))
     ((eusview-file-name-p name) name)
     (t (format nil "~A/models/~A.l" (string-right-trim "/" *eusdir*)
                (if (string= name "darwin") "darwin" (format nil "~A-robot" name)))))))

(defun eusview-make-jsk (name)
  (let ((demo (assoc name *eusview-demo-robots* :test #'string=))
        (file (eusview-jsk-file name)) r)
    (cond
     (demo (load file) (setq r (instance (symbol-value (caddr demo)) :init)))
     ((eusview-file-name-p name) ;; a file defining a robot: the last robot-model made by its function
      (load name)
      (let ((f (intern (string-upcase (pathname-name (pathname name))) "USER")))
        (if (fboundp f) (setq r (funcall f)))))
     ((probe-file file)
      (load file)
      (setq r (funcall (intern (string-upcase name) "USER"))))
     (t (error (format nil "no robot file ~A" file))))
    (unless (derivedp r robot-model) (error (format nil "~A is not a robot-model" r)))
    r))

;; servo vector entries not in a servo command keep the current position (the disassembler
;; fills them with 7500 = 0 deg), like the RCB4 itself
(defconstant +eusview-keep+ -1)
(defvar *eusview-cur-sv* nil)
(defvar *eusview-recording* nil)
(defun eusview-ri-class (cls)
  (let ((sub (intern (format nil "EUSVIEW-~A" (send cls :name)))))
    (unless (boundp sub)
      (eval `(defclass ,sub :super ,(send cls :name)))
      (eval `(defmethod ,sub
               (:servo-vector-to-angle-vector
                (sv &rest args)
                (if (and *eusview-recording* *eusview-cur-sv*)
                    (let ((m (copy-seq *eusview-cur-sv*)))
                      (dotimes (i (min (length sv) (length m)))
                        (let ((v (elt sv i)))
                          (unless (or (= v +eusview-keep+) (>= v #x7fff)) (setf (elt m i) v))))
                      (setq *eusview-cur-sv* m)
                      (setq servo-vector (copy-seq m))
                      (send-super :servo-vector-to-angle-vector m))
                  (send-super* :servo-vector-to-angle-vector sv args))))))
    (symbol-value sub)))

;; projects of robots whose :project-file has no projects/Hello_<name> (KHR: "khr3semi" robots use the
;; KHR-3HV sample Hello_KHR3(V2.3) of Hello_khr3sl5a3h2, copied into kxreus/projects)
(defvar *eusview-project-alias* '(("khr3semi" . "khr3sl5a3h2")))
(defvar *eusview-project-searched* nil) ;; directories searched for the last robot (for the message)
(defun eusview-find-project (proj)
  "projects/Hello_<proj>/*.h4p of kxreus, then *eusview-project-dirs*; also the alias of proj"
  (setq *eusview-project-searched* nil)
  (dolist (pr (remove nil (list proj (cdr (assoc proj *eusview-project-alias* :test #'equal)))))
    (dolist (d (cons (format nil "~A/projects" *rcb4eus-dir*) *eusview-project-dirs*))
      (let ((dir (format nil "~A/Hello_~A" d pr)))
        (push dir *eusview-project-searched*)
        (when (probe-file dir)
          (let ((f (car (sort (find-files :dir dir :ext "h4p") #'string<))))
            (if (and f (probe-file f)) (return-from eusview-find-project f)))))))
  (setq *eusview-project-searched* (nreverse *eusview-project-searched*))
  nil)

(defun eusview-make-ri (r name)
  (let ((ri (instance (eusview-ri-class (kxr-ri-class name)) :init r :create-viewer nil)))
    (setq *eusview-project-searched* nil)
    (unless (send ri :project-file)
      ;; not found by kxreus (projects/Hello_<:project-file>): alias, *eusview-project-dirs*
      (let* ((proj (or (kxr-body-config-key name :project-file) name))
             (fn (eusview-find-project proj)) p rm)
        (when fn
          (setq p (instance rcb4-project-file :init ri fn))
          (setq rm (send ri :rcb4machine))
          (dolist (mc (send p :mcodes)) (send rm :set-rom-table (send mc :number) mc))
          (send rm :scan-jump-vectors)
          (setq (ri . project-file) p)
          (send ri :trim-vector (send p :trim-vector)))))
    ri))

(defun eusview-select (name)
  "build robot name (KXR/KHR: kxreus, JSK: models) and show it"
  (when *eusview-playing*
    (setq *eusview-stop* t *eusview-next-motion* nil)
    (eusview-message "stop the motion") (return-from eusview-select nil))
  (setq name (string-trim " " (string-downcase name)))
  (when (eusview-physics-on-p) (eusview-physics-stop))
  (let ((group (eusview-group-of name)) r ri ret)
    (eusview-message "making ~A (~A) ..." name group)
    (setq ret
          (eusview-protect
           (setq r (if (string= group "JSK") (eusview-make-jsk name)
                     (kxr-make-robot name :viewer nil :model *eusview-kxr-model*)))
           (unless r (error (format nil "kxr-make-robot ~A returned nil" name)))
           t))
    (unless (eq ret t)
      (eusview-message "could not make ~A: ~A" name *eusview-last-error*)
      (return-from eusview-select nil))
    (when (and (not (string= group "JSK")) (kxr-body-config name))
      (setq ret (eusview-protect (setq ri (eusview-make-ri r name)) t))
      (unless (eq ret t)
        (setq ri nil)
        (eusview-message "~A: no rcb4-interface (no motions): ~A" name *eusview-last-error*)))
    (setq *eusview-robot* r *eusview-ri* ri *eusview-name* name *eusview-group* group)
    (setq *robot* r)
    (if ri (setq *ri* ri))
    (eusview-make-viewer)
    (send *eusview-viewer* :objects (list r))
    (send *eusview-viewer* :look-all)
    (send *eusview-viewer* :title (format nil "EusView ~A" name))
    (when ri ;; the emulator draws into this viewer
      (send ri :rcb4machine :create-viewer :viewer *eusview-viewer*)
      (send *eusview-viewer* :change-background *eusview-background*)
      (send *eusview-viewer* :title (format nil "EusView ~A" name)))
    (eusview-make-robot-panel)
    (send *eusview-viewer* :draw-objects)
    (eusview-message "~A (~A): ~A joints, ~A motions" name group (length (eusview-joints r))
                     (if (and ri (send ri :project-file)) (length (send ri :project-file :mcodes)) 0))
    r))

(defun eusview-joints (r)
  (remove-if-not #'(lambda (j) (or (derivedp j rotational-joint) (derivedp j linear-joint)))
                 (send r :joint-list)))

(defun eusview-pose-methods (r)
  (let ((ms (send r :methods)) (ret nil))
    (dolist (m '(:reset-pose :init-pose :reset-manip-pose :sit-pose :stand-pose))
      (if (memq m ms) (push m ret)))
    (dolist (m ms)
      (let ((s (string m)))
        (when (and (> (length s) 5) (string= "-POSE" (subseq s (- (length s) 5)))
                   (not (memq m ret))
                   (not (substringp "DEF" s)) (not (substringp "SAVE" s))
                   (not (substringp "ALIST" s)) (not (substringp "PLIST" s))
                   (< (length ret) 12))
          (push m ret))))
    (nreverse ret)))

(defun eusview-pose (pose)
  (let ((r *eusview-robot*))
    (when (and r (not *eusview-playing*))
      (if (eq (eusview-protect
               (if (eq pose :zero)
                   (send r :angle-vector (instantiate float-vector (length (send r :angle-vector))))
                 (send r pose))
               t) t)
          (eusview-message "~A ~A" *eusview-name* pose)
        (eusview-message "~A ~A: ~A" *eusview-name* pose *eusview-last-error*))
      (eusview-after-move))))

(defun eusview-after-move ()
  (case (eusview-physics-on-p)
    (:ode (eusview-protect (send *evp* :set-targets-from-robot)))
    (:kxrdyna
     (eusview-protect (send *eusview-robot* :send-ode 500) (send *eusview-robot* :wait-ode))))
  (if *eusview-robot-panel* (send *eusview-robot-panel* :update-sliders))
  (send *eusview-viewer* :draw-objects))

;;;
;;; motions: RCB4 emulation (rcb4-interface :emulate-motion-code) -> key frames -> playback
;;;   The emulator sets the angles of a servo command, sleeps (speed x 10 ms), draws, sleeps again.
;;;   It is run with unix:usleep replaced and a recorder as its viewer: a key frame is the angles
;;;   at the first draw after a change, at the time (ms) slept until then (the second sleep of
;;;   the same command is skipped). Timer waits are sleeps (holds).
;;;
(defvar *eusview-rec-time* 0)
(defvar *eusview-rec-skip* nil)
(defvar *eusview-rec-keys* nil)
(defvar *eusview-rec-robot* nil)
(defvar *eusview-rec-truncated* nil)
(defvar *eusview-orig-usleep* (symbol-function 'unix:usleep))

(defclass eusview-recorder :super propertied-object :slots (robot))
(defmethod eusview-recorder
  (:init (r) (setq robot r) self)
  (:objects (&rest args) (list robot))
  (:draw-objects (&rest args) (eusview-rec-frame))
  (:strings (&rest args) nil)
  (:nomethod (&rest args) nil))

(defun eusview-rec-frame ()
  (let ((av (send *eusview-rec-robot* :angle-vector)))
    (unless (and *eusview-rec-keys* (equal av (cdr (car *eusview-rec-keys*))))
      (push (cons *eusview-rec-time* (copy-seq av)) *eusview-rec-keys*)
      (setq *eusview-rec-skip* t))
    (when (or (> *eusview-rec-time* (* 1000 *eusview-max-motion-sec*))
              (> (length *eusview-rec-keys*) 3000))
      (setq *eusview-rec-truncated* t)
      (throw :eusview-rec-stop nil))))

(defun eusview-rec-usleep (us)
  (if *eusview-rec-skip* (setq *eusview-rec-skip* nil)
    (setq *eusview-rec-time* (+ *eusview-rec-time* (/ us 1000.0))))
  0)

(defvar *eusview-patched* nil)
(defun eusview-patch-codes (mc)
  "servo commands: servos not in the id list -> keep; velocity vectors -> max"
  (unless (memq mc *eusview-patched*)
    (dolist (a (send mc :acodes))
      (when (and (consp a) (eq (car a) :servo) (listp (elt a 1)) (>= (length a) 4)
                 (vectorp (elt a 3)))
        (let* ((ids (elt a 1)) (sv (copy-seq (elt a 3))))
          (dotimes (i (length sv))
            (unless (member i ids) (setf (elt sv i) +eusview-keep+)))
          (setf (elt a 3) sv)
          (unless (numberp (elt a 2))
            (setf (elt a 2) (let ((mx 0)) (dolist (i ids) (setq mx (max mx (elt (elt a 2) i)))) mx))))))
    ;; timer wait loops "(:sub (:lit 0 128) (:ram (:timer ..)) t) (:jump .. back)": the emulator
    ;; does not count the timer down (it sleeps when the timer is set) -> drop the jump
    (let ((prev nil))
      (dolist (a (send mc :acodes))
        (when (consp a)
          (when (and (eq (car a) :jump) prev (eq (car prev) :sub)
                     (consp (elt prev 2)) (eq (car (elt prev 2)) :ram)
                     (consp (cadr (elt prev 2))) (eq (car (cadr (elt prev 2))) :timer))
            (setf (elt a 0) :eusview-nop))
          (setq prev a))))
    (push mc *eusview-patched*)))

(defun eusview-record (ri mc)
  "key frames ((msec . angle-vector) ...) of motion code mc"
  (let* ((r (send ri :robot)) (rm (send ri :rcb4machine))
         (vw (rm . vwer)) (ode (get r :ode-ci)))
    (dolist (m (send ri :project-file :mcodes)) (eusview-patch-codes m))
    (setq *eusview-rec-keys* nil *eusview-rec-time* 0 *eusview-rec-skip* nil
          *eusview-rec-robot* r *eusview-rec-truncated* nil)
    ;; the servo vector of the current angles (servos not in a command keep these values)
    (setq *eusview-cur-sv*
          (map integer-vector #'round (send ri :angle-vector-to-servo-vector (send r :angle-vector))))
    (push (cons 0 (copy-seq (send r :angle-vector))) *eusview-rec-keys*)
    (setq (rm . vwer) (instance eusview-recorder :init r))
    (setf (get r :ode-ci) nil)
    (setq *eusview-recording* t)
    (setf (symbol-function 'unix:usleep) (symbol-function 'eusview-rec-usleep))
    (unwind-protect
        (catch :eusview-rec-stop
          (send ri :emulate-motion-code mc :loopmax 3000))
      (setf (symbol-function 'unix:usleep) *eusview-orig-usleep*)
      (setq *eusview-recording* nil)
      (setq (rm . vwer) vw)
      (setf (get r :ode-ci) ode))
    (reverse *eusview-rec-keys*)))

(defun eusview-interpolate (keys tm)
  (let ((k keys))
    (while (and (cdr k) (<= (car (cadr k)) tm)) (setq k (cdr k)))
    (cond
     ((null (cdr k)) (cdr (car k)))
     (t (let* ((t0 (car (car k))) (t1 (car (cadr k)))
               (a (if (> t1 t0) (/ (- tm t0) (float (- t1 t0))) 1.0)))
          (midpoint (min 1.0 (max 0.0 a)) (cdr (car k)) (cdr (cadr k))))))))

(defun eusview-play-keys (keys)
  (let* ((r *eusview-robot*) (tend (car (car (last keys)))) (t0 (eusview-now-ms)) (tm 0))
    (cond
     ((eq (eusview-physics-on-p) :ode)
      ;; eusview-physics.l: the interpolated angles are the servo targets at the simulation time;
      ;; the simulation runs in steps of dt, drawn every 30 ms and not faster than real time
      (let* ((dt (* 1000.0 (evp-cdr :dt *evp-world*))) (tsim 0) (tdraw 0))
        (while (and (<= tsim (+ tend 200)) (not *eusview-stop*))
          (send *evp* :set-targets-av (eusview-interpolate keys tsim))
          (send *evp* :step 1)
          (setq tsim (+ tsim dt))
          (when (>= (- tsim tdraw) 30)
            (setq tdraw tsim)
            (send *evp* :update-robot)
            (send *eusview-viewer* :draw-objects)
            (eusview-physics-status)
            (x::window-main-one)
            (let ((ahead (- tsim (- (eusview-now-ms) t0))))
              (if (> ahead 1) (funcall *eusview-orig-usleep* (round (* 1000 ahead)))))))
        (setq (*evp* . last-ms) nil)))
     ((eusview-physics-on-p) ;; kxrdyna: send each key frame with its time (:send-ode)
      (let ((prev 0))
        (dolist (k (cdr keys))
          (if *eusview-stop* (return))
          (send r :angle-vector (copy-seq (cdr k)))
          (send r :send-ode (max 10 (round (- (car k) prev))))
          (send r :wait-ode)
          (setq prev (car k))
          (send *eusview-viewer* :draw-objects)
          (x::window-main-one))))
     (t
      (while (and (<= tm tend) (not *eusview-stop*))
        (send r :angle-vector (copy-seq (eusview-interpolate keys tm)))
        (send *eusview-viewer* :draw-objects)
        (x::window-main-one)
        (funcall *eusview-orig-usleep* (round (/ 1000000.0 *eusview-fps*)))
        (setq tm (- (eusview-now-ms) t0)))
      (unless *eusview-stop* (send r :angle-vector (copy-seq (cdr (car (last keys))))))))))

(defun eusview-mc-name (mc)
  (let ((n (send mc :name))) (if (consp n) (cadr n) (format nil "~A" n))))

(defvar *eusview-next-motion* nil) ;; motion number to play next (another motion chosen while playing)
(defvar *eusview-motion-label* "")
(defun eusview-show-playing (str)
  (setq *eusview-motion-label* str)
  (if *eusview-robot-panel* (send *eusview-robot-panel* :show-playing str)))

(defun eusview-play-motion (num)
  "play motion num repeatedly (like the EusView app) until stop or another motion is chosen"
  (cond
   (*eusview-playing* ;; called from the event loop of the playback: switch to num
    (setq *eusview-next-motion* num *eusview-stop* t))
   (t
    (setq *eusview-playing* t *eusview-next-motion* num)
    (unwind-protect
        (while *eusview-next-motion*
          (let ((n *eusview-next-motion*))
            (setq *eusview-next-motion* nil *eusview-stop* nil)
            (eusview-play-motion-loop n)))
      (setq *eusview-playing* nil *eusview-stop* nil)
      (eusview-show-playing "")
      (if *eusview-robot-panel* (send *eusview-robot-panel* :update-sliders))
      (send *eusview-viewer* :draw-objects)))))

(defun eusview-play-motion-loop (num)
  (let* ((ri *eusview-ri*) (mc (and ri (send ri :project-file)
                                     (find num (send ri :project-file :mcodes)
                                           :key #'(lambda (m) (send m :number)))))
         keys ret (count 0))
    (cond
     ((null mc) (eusview-message "no motion ~A" num))
     (t
      (eusview-message "~A: emulating motion ~A ~A ..." *eusview-name* num (eusview-mc-name mc))
      (setq ret (eusview-protect (setq keys (eusview-record ri mc)) t))
      (cond
       ((not (eq ret t))
        (eusview-message "motion ~A: ~A" num *eusview-last-error*))
       ((< (length keys) 2)
        (eusview-message "motion ~A ~A: no servo command" num (eusview-mc-name mc)))
       (t
        (while (not *eusview-stop*)
          (incf count)
          (eusview-show-playing (format nil (if (eusview-ja-p) "~A ~A（~A 回目）" "~A ~A (~A)") num (eusview-mc-name mc) count))
          (eusview-message "playing: ~A ~A (~A, ~4,1f s~A)" num (eusview-mc-name mc) count
                           (/ (car (car (last keys))) 1000.0)
                           (if *eusview-rec-truncated* ", truncated" ""))
          (setq ret (eusview-protect (eusview-play-keys keys) t))
          (unless (eq ret t)
            (eusview-message "motion ~A: ~A" num *eusview-last-error*)
            (setq *eusview-stop* t)))))))))

;;;
;;; physics
;;;   1. kxrdyna.l / odedyna.l (eusdyna, ~/prog/rcb4eus) when it and libeusode.so / libode.so are found
;;;   2. else eusview-physics.l: ODE through libeusviewode.so (make eusview-ode, the EusView app's
;;;      C layer eusview-ode/odesim.cpp; Ubuntu: sudo apt install libode-dev)
;;;
(defun eusview-archdir () (or (unix:getenv "ARCHDIR") "Linux64"))
(defun eusview-dyna-dir ()
  "directory of kxrdyna.l (kxreus, *load-path*, ~/prog/rcb4eus)"
  (dolist (d (append (list (format nil "~A/" *rcb4eus-dir*)) *load-path*
                     (list (format nil "~A/prog/rcb4eus/" (unix:getenv "HOME")))))
    (when (and (stringp d) (probe-file (format nil "~A/kxrdyna.l" (string-right-trim "/" d))))
      (return-from eusview-dyna-dir (string-right-trim "/" d))))
  nil)
(defun eusview-physics-check ()
  "nil if kxrdyna can be used, else the reason"
  (let* ((dir (eusview-dyna-dir)) (arch (eusview-archdir))
         (eusode1 (and dir (format nil "~A/~A/libeusode.so" dir arch)))
         (eusode2 (format nil "~A/~A/lib/libeusode.so" (string-right-trim "/" *eusdir*) arch))
         (ode (format nil "~A/~A/lib/libode.so" (string-right-trim "/" *eusdir*) arch)))
    (cond
     ((fboundp 'kxr-dyna-start) nil)
     ((null dir) "kxrdyna.l not found (kxreus or ~/prog/rcb4eus)")
     ((not (or (probe-file eusode1) (probe-file eusode2)))
      (format nil "no libeusode.so (~A or ~A)" eusode1 eusode2))
     ((not (probe-file ode)) (format nil "no libode.so (~A)" ode))
     (t nil))))
(defun eusview-load-dyna ()
  (unless (fboundp 'kxr-dyna-start)
    (let ((dir (eusview-dyna-dir)) (cwd (unix:getwd)))
      (pushnew (format nil "~A/" dir) *load-path* :test #'equal)
      (unwind-protect
          (progn (unix:chdir dir) ;; odedyna.l loads ./$ARCHDIR/libeusode.so
                 (load (format nil "~A/kxrdyna.l" dir)))
        (unix:chdir cwd))))
  (fboundp 'kxr-dyna-start))
(defun eusview-physics-on-p ()
  "nil, :ode (eusview-physics.l) or :kxrdyna"
  (cond
   ((null (and *eusview-physics* *eusview-robot*)) nil)
   ((eq *eusview-physics* :ode) (if *evp* :ode))
   ((get *eusview-robot* :ode-ci) :kxrdyna)))
(defvar *eusview-selector-interval* nil)
(defvar *eusview-status-time* 0)
(defun eusview-physics-status (&optional force)
  (let ((now (eusview-now-ms)))
    (when (and *evp* (or force (> (- now *eusview-status-time*) 500)))
      (setq *eusview-status-time* now)
      (let ((p (send *evp* :root-pos)))
        (eusview-message "physics ~A: t ~5,1f s, contacts ~A, root x ~4,0f y ~4,0f z ~4,0f mm~A"
                         *eusview-name* (send *evp* :time) (send *evp* :contacts)
                         (elt p 0) (elt p 1) (elt p 2) (if (send *evp* :servo) "" ", servo off"))))))
(defun eusview-physics-tick ()
  "timer job (*timer-job*): advance the simulation by the real time and draw"
  (when (and (eq (eusview-physics-on-p) :ode) (not *eusview-playing*))
    (let ((ret (eusview-protect
                (when (> (send *evp* :advance) 0)
                  (send *evp* :update-robot)
                  (send *eusview-viewer* :draw-objects)
                  (eusview-physics-status))
                t)))
      (unless (eq ret t)
        (eusview-physics-stop)
        (eusview-message "physics stopped: ~A" *eusview-last-error*)))))
(defun eusview-physics-start ()
  (let ((why (eusview-physics-check)) ret)
    (cond
     ((null *eusview-robot*) nil)
     ((null why) ;; kxrdyna
      (setq ret
            (eusview-protect
             (eusview-load-dyna)
             (setq *robot* *eusview-robot* *irtviewer* *eusview-viewer*)
             (if *eusview-ri* (setq *ri* *eusview-ri*))
             (send *eusview-viewer* :objects (list *eusview-robot*))
             (setq *loop* t *mm* nil)
             (dyna-on *eusview-viewer*)
             (send *dworld* :soft-setting)
             (d-start)
             (push-itimer 'kxr-dyna-motion)
             t))
      (cond
       ((eq ret t) (setq *eusview-physics* :kxrdyna) (eusview-update-toggles)
        (eusview-message "physics (kxrdyna, ODE) started"))
       (t (eusview-message "could not start physics: ~A" *eusview-last-error*))))
     ((not (evp-available-p))
      (eusview-message "no physics: no libeusviewode.so (make eusview-ode; Ubuntu: sudo apt install libode-dev), kxrdyna: ~A" why))
     (t ;; eusview-physics.l
      (setq ret (eusview-protect (evp-start *eusview-robot*) t))
      (cond
       ((eq ret t)
        (setq *eusview-physics* :ode)
        (unless *eusview-selector-interval*
          (setq *eusview-selector-interval* (if (boundp '*top-selector-interval*) *top-selector-interval* 10.0)))
        (setq *top-selector-interval* 0.02)
        (pushnew 'eusview-physics-tick *timer-job*)
        (eusview-update-toggles)
        (send *eusview-viewer* :draw-objects)
        (eusview-physics-status t))
       (t (eusview-protect (evp-stop))
          (eusview-message "could not start physics: ~A" *eusview-last-error*)))))))
(defun eusview-physics-stop ()
  (case *eusview-physics*
    (:ode
     (setq *timer-job* (remove 'eusview-physics-tick *timer-job*))
     (when *eusview-selector-interval*
       (setq *top-selector-interval* *eusview-selector-interval* *eusview-selector-interval* nil))
     (eusview-protect (evp-stop)))
    (t
     (eusview-protect
      (setq *loop* nil)
      (setq *timer-job* (remove 'kxr-dyna-motion *timer-job*))
      (if (boundp '*dworld*) (send *dworld* :stop)))))
  (setq *eusview-physics* nil)
  (eusview-update-toggles)
  (when *eusview-robot*
    (setf (get *eusview-robot* :ode-ci) nil)
    (send *eusview-viewer* :objects (list *eusview-robot*))
    (if *eusview-robot-panel* (send *eusview-robot-panel* :update-sliders))
    (send *eusview-viewer* :draw-objects))
  (eusview-message "physics stopped"))
(defun eusview-servo-toggle ()
  (cond
   ((eq (eusview-physics-on-p) :ode)
    (send *evp* :set-servo (not (send *evp* :servo)))
    (eusview-update-toggles)
    (eusview-message "servo ~A" (if (send *evp* :servo) "on" "off (free)")))
   (t (eusview-message "servo: start physics first"))))

;;;
;;; live: the angles to the EusView app through eusview-live.py (TCP, one JSON per line)
;;;
(defvar *eusview-live-relay-pid* nil) ;; pid of the eusview-live.py this EusView started
(defvar *eusview-live-clients* nil)   ;; iPhones connected to the relay (nil: unknown, old live.py)
(defvar *eusview-live-addr* nil)      ;; ws://<LAN IP>:8766/
(defvar *eusview-live-ws-port* 8766)

(defun eusview-shell-line (cmd)
  "first line of the output of the shell command cmd (or nil)"
  (let ((f (format nil "/tmp/eusview-~A.out" (unix:getpid))) l)
    (unix:system (format nil "(~A) > ~A 2>/dev/null" cmd f))
    (when (probe-file f)
      (with-open-file (in f) (setq l (read-line in nil nil)))
      (unix:system (format nil "rm -f ~A" f)))
    (if (and l (> (length (string-trim " " l)) 0)) (string-trim " " l))))

(defun eusview-lan-ip ()
  "IPv4 address of this PC on the LAN (Linux: ip route / hostname -I, macOS: ipconfig getifaddr)"
  (eusview-shell-line
   (concatenate string
    "ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"src\") {print $(i+1); exit}}' | grep . || "
    "hostname -I 2>/dev/null | awk '{print $1}' | grep . || "
    "ipconfig getifaddr en0 || ipconfig getifaddr en1 || ipconfig getifaddr en2")))

(defun eusview-live-open (host port)
  (let ((s (eusview-protect
            (make-client-socket-stream (make-socket-address :domain af_inet :host host :port port)))))
    (if (streamp s) s nil)))

(defun eusview-live-start-relay (port)
  "start kxreus eusview-live.py in the background (log ~/.cache/eusview-live.log); pid or nil"
  (let ((py (eusview-shell-line "command -v python3"))
        (script (format nil "~A/eusview-live.py" *rcb4eus-dir*))
        (log (format nil "~A/.cache/eusview-live.log" (unix:getenv "HOME"))) pid)
    (cond
     ((null py) (eusview-message "live: no python3 (install python3 to relay to the iPhone)") nil)
     ((not (probe-file script)) (eusview-message "live: no ~A" script) nil)
     (t
      (unix:system (format nil "mkdir -p ~A/.cache" (unix:getenv "HOME")))
      (setq pid (eusview-shell-line
                 (format nil "nohup ~A ~A ~A ~A < /dev/null > ~A 2>&1 & echo $!"
                         py script *eusview-live-ws-port* port log)))
      (setq pid (and pid (read-from-string pid)))
      (when (integerp pid)
        (eusview-message "live: started the relay ~A (pid ~A, log ~A)" script pid log))
      (if (integerp pid) pid nil)))))

(defun eusview-live-stop-relay ()
  (when *eusview-live-relay-pid*
    (unix:system (format nil "kill ~A 2>/dev/null" *eusview-live-relay-pid*))
    (format t ";; eusview: live relay (pid ~A) stopped~%" *eusview-live-relay-pid*)
    (setq *eusview-live-relay-pid* nil)))

(defun eusview-live-connect ()
  (let* ((host (or (unix:getenv "EUSVIEW_LIVE_HOST") "localhost"))
         (port (read-from-string (or (unix:getenv "EUSVIEW_LIVE_PORT") "8767")))
         (s (eusview-live-open host port)))
    ;; no relay running: start kxreus eusview-live.py (only for this PC) and wait up to 5 s
    (when (and (null s) (member host '("localhost" "127.0.0.1") :test #'equal)
               (null *eusview-live-relay-pid*))
      (setq *eusview-live-relay-pid* (eusview-live-start-relay port))
      (when *eusview-live-relay-pid*
        (dotimes (i 25)
          (if (setq s (eusview-live-open host port)) (return))
          (funcall *eusview-orig-usleep* 200000))))
    (cond
     (s
      (setq *eusview-live* s *eusview-live-last* nil *eusview-live-clients* nil)
      (setq *eusview-live-addr*
            (format nil "ws://~A:~A/" (or (eusview-lan-ip) "<this PC's IP>") *eusview-live-ws-port*))
      (pushnew 'eusview-live-poll *timer-job*)
      (funcall *eusview-orig-usleep* 100000)
      (eusview-live-poll)
      (eusview-live-show)
      t)
     (t (setq *eusview-live* nil)
        (eusview-message "live: cannot connect to ~A:~A (run python3 eusview-live.py)" host port)
        nil))))

(defun eusview-live-show ()
  (let ((str (if *eusview-live*
                 (format nil (if (eusview-ja-p)
                                 "live: ON  iPhone の EusView の「接続」に ~A を入れる~A"
                               "live: ON  enter ~A in Connect of EusView on the iPhone~A")
                         *eusview-live-addr*
                         (cond ((null *eusview-live-clients*) "")
                               ((eusview-ja-p) (format nil "（つながっている iPhone: ~A 台）" *eusview-live-clients*))
                               (t (format nil " (iPhones connected: ~A)" *eusview-live-clients*))))
               "")))
    (when *eusview-panel* (send *eusview-panel* :status-item :value str))
    (format t ";; eusview: ~A~%" str)
    (if *eusview-robot-panel* (eusview-protect (send *eusview-robot-panel* :show-live str)))
    (eusview-update-toggles)))

(defun eusview-string-index (sub str)
  (let ((n (length sub)))
    (dotimes (i (1+ (- (length str) n)) nil)
      (if (string= sub (subseq str i (+ i n))) (return-from eusview-string-index i)))))
(defun eusview-live-poll ()
  "read the relay's {\"relay\":\"eusview-live\",\"clients\":n} lines (timer job)"
  (when *eusview-live*
    (let ((changed nil))
      (eusview-protect
       (while (select-stream (list *eusview-live*) 0.001) ;; 0.0 waits forever
         (let ((l (read-line *eusview-live* nil nil)) k)
           (cond
            ((null l) (setq *eusview-live* nil) (return))
            ((setq k (eusview-string-index "\"clients\":" l))
             (let ((n (let ((v nil))   ;; digits after "clients": ("0}" reads as a symbol)
                        (dotimes (i (- (length l) k 10))
                          (let ((c (elt l (+ k 10 i))))
                            (cond ((and (>= c #\0) (<= c #\9)) (setq v (+ (* 10 (or v 0)) (- c #\0))))
                                  ((and v (not (= c #\space))) (return)))))
                        v)))
               (when (and (integerp n) (not (equal n *eusview-live-clients*)))
                 (setq *eusview-live-clients* n changed t))))))))
      (cond
       ((null *eusview-live*)
        (setq *timer-job* (remove 'eusview-live-poll *timer-job*))
        (eusview-message "live: send failed (closed)")
        (eusview-update-toggles))
       (changed (eusview-live-show))))))

(defun eusview-live-close ()
  (when *eusview-live* (eusview-protect (close *eusview-live*)))
  (setq *eusview-live* nil *eusview-live-clients* nil)
  (setq *timer-job* (remove 'eusview-live-poll *timer-job*))
  (if *eusview-robot-panel* (eusview-protect (send *eusview-robot-panel* :show-live "")))
  (eusview-update-toggles)
  (eusview-message "live: closed"))
(defun eusview-num (x)
  (let ((v (/ (round (* x 100.0)) 100.0))) (format nil "~A" (if (= v 0) 0 v))))
(defun eusview-join (strs)
  (let ((st (make-string-output-stream 256)) (first t))
    (dolist (x strs) (unless first (princ "," st)) (princ x st) (setq first nil))
    (get-output-stream-string st)))
(defun eusview-live-send (&optional force)
  (let ((r *eusview-robot*) (now (eusview-now-ms)) av c p m)
    (when (and r *eusview-live* (or force (> (- now *eusview-live-time*) 30)))
      (setq av (mapcar #'(lambda (j) (send j :joint-angle)) (eusview-joints r)))
      (setq c (send (car (send r :links)) :worldcoords))
      (setq p (scale 0.001 (send c :worldpos)) m (send c :worldrot))
      (unless (and (not force) (equal (cons p av) *eusview-live-last*))
        (setq *eusview-live-last* (cons p av) *eusview-live-time* now)
        (unless (eq t (eusview-protect
                       (format *eusview-live* "{\"angles\":[~A]}~%" (eusview-join (mapcar #'eusview-num av)))
                       (format *eusview-live* "{\"root\":[~A]}~%"
                               (eusview-join
                                (mapcar #'(lambda (x) (format nil "~A" (/ (round (* x 10000.0)) 10000.0)))
                                        (append (coerce p cons)
                                                (list (aref m 0 0) (aref m 0 1) (aref m 0 2)
                                                      (aref m 1 0) (aref m 1 1) (aref m 1 2)
                                                      (aref m 2 0) (aref m 2 1) (aref m 2 2))))))
                       (finish-output *eusview-live*)
                       t))
          (setq *eusview-live* nil)
          (eusview-message "live: send failed (closed)")
          (eusview-update-toggles))))))

;;;
;;; panels
;;;
(defclass eusview-panel :super x::panel :slots (status-item name-item))
(defmethod eusview-panel
  (:create
   (&rest args)
   (send-super* :create :width 900 :height 80 :title "EusView" args)
   (send self :create-item x::button-item "quit" self :quit-eusview)
   (if (eusview-ja-p) (send self :create-item x::xft-label-item "ロボット:" :width 80))
   (dolist (g (list (list "KXR" *eusview-kxr-robots*) (list "KHR" *eusview-khr-robots*)
                    (list "JSK" *eusview-jsk-robots*)))
     (let* ((names (remove-if-not #'(lambda (n) (or (string= (car g) "JSK") (kxr-body-config n)))
                                  (cadr g)))
            (i 0) menu)
       (while names
         (setq menu (instance x::menu-panel :create))
         (dotimes (k *eusview-menu-rows*)
           (when names
             (send menu :create-item x::button-item (car names) self (list :select (car names)))
             (pop names)))
         (send self :create-item x::menu-button-item
               (format nil "~A ~A-" (car g) (1+ (* i *eusview-menu-rows*))) nil nil :menu menu
               :border-width 2)
         (incf i))))
   (setq name-item (send self :create-item x::text-item "name:" self :select-name
                         :columns 18 :initial-value ""))
   (send self :create-item x::button-item "list all" self :list-all)
   ;; status line: Xft label (Japanese motion names); without Xft it shows ASCII only
   (setq status-item (send self :create-item x::xft-label-item "" :width 880))
   self)
  (:status-item (&rest args) (user::forward-message-to status-item args))
  (:status (&rest args) nil)
  (:select (sel &rest args) (eusview-select (car sel)))
  (:select-name (obj val &rest args)
                (if (and (stringp val) (> (length (string-trim " " val)) 0)) (eusview-select val)))
  (:list-all (&rest args)
             (format t ";; kxreus robots (~A): ~A~%" (length (kxr-all-robot-names)) (kxr-all-robot-names))
             (format t ";; JSK: ~A~%" *eusview-jsk-robots*)
             (eusview-message "robot names printed in the terminal (~A + JSK ~A)"
                              (length (kxr-all-robot-names)) (length *eusview-jsk-robots*)))
  (:quit-eusview (&rest args) (eusview-quit))
  (:quit (&rest args) (eusview-quit)))

(defclass eusview-robot-panel :super x::panel
  :slots (robot sliders physics-item servo-item live-item playing-item live-info))
(defmethod eusview-robot-panel
  (:create
   (r &rest args)
   (let* ((joints (eusview-joints r)) (ncol (if (> (length joints) 50) 3 2))
          (has-motion (and *eusview-ri* (send *eusview-ri* :project-file)))
          (nmotion-rows (if has-motion 2 0))
          (rows (+ 4 nmotion-rows (ceiling (/ (float (length joints)) ncol))))
          (width (* ncol 600)))
     (setq robot r sliders nil)
     (send-super* :create :width width :height (min 1000 (+ 20 (* rows 34)))
                  :title (format nil "EusView: ~A" (send r :name)) args)
     (if (eusview-ja-p) (send self :create-item x::xft-label-item "姿勢:" :width 50))
     (send self :create-item x::button-item "zero" self (list :pose :zero))
     (dolist (m (eusview-pose-methods r))
       (send self :create-item x::button-item (string-downcase (string m)) self (list :pose m)))
     (send self :create-item x::button-item "look-all" self :look-all)
     (send self :create-item x::button-item "stop" self :stop)
     ;; toggles: the label shows the state
     (setq physics-item (send self :create-item x::button-item "physics: off" self :physics))
     (setq servo-item (send self :create-item x::button-item "servo: on " self :servo))
     (setq live-item (send self :create-item x::button-item "live: off" self :live))
     (setq playing-item (send self :create-item x::xft-label-item "" :width (- width 20)))
     (setq live-info (send self :create-item x::xft-label-item "" :width (- width 20)))
     (when (and (not has-motion) (not (string= *eusview-group* "JSK")))
       (send playing-item :value
             (format nil (if (eusview-ja-p) "動作のプロジェクトが見つかりません（探した場所: ~A）"
                           "no motion project (searched: ~A)")
                     (eusview-searched-string))))
     (when has-motion
       (let ((table (instantiate vector 120)))
         (dolist (mc (send *eusview-ri* :project-file :mcodes))
           (if (< -1 (send mc :number) 120) (setf (elt table (send mc :number)) mc)))
         ;; like kxrviewer.l panel :create-2d-menu-buttons (robot-control-panel " project motion"),
         ;; with Xft labels (the motion names are Japanese)
         (eusview-motion-menus self table 20 (- width 20))))
     (dolist (j joints)
       (let* ((lin (derivedp j linear-joint))
              (lim (if lin 500 180))
              (mn (max (- lim) (send j :min-angle))) (mx (min lim (send j :max-angle))))
         (if (>= mn mx) (setq mn (- lim) mx lim))
         (push (cons j (send self :create-item x::slider-item
                             (format nil "~22A" (send j :name)) self (list :joint j)
                             :span 150 :value-format "~6,1f" :min mn :max mx
                             :min-label (let ((x (format nil "~A" (round mn)))) (while (< (length x) 4) (setq x (concatenate string " " x))) x) :max-label (format nil "~4A" (round mx))
                             :initial-value (min mx (max mn (send j :joint-angle)))))
               sliders)))
     (setq sliders (nreverse sliders))
     self))
  (:pose (sel &rest args) (eusview-pose (car sel)))
  (:look-all (&rest args) (send *eusview-viewer* :look-all) (send *eusview-viewer* :draw-objects))
  (:stop (&rest args) (setq *eusview-stop* t *eusview-next-motion* nil) (eusview-message "stop"))
  (:show-playing
   (str)
   (send playing-item :value
         (if (string= str "") "" (format nil (if (eusview-ja-p) "再生中: ~A（stop で止める）" "playing: ~A (stop)") str))))
  (:update-toggles
   ()
   (let ((on (eusview-physics-on-p)))
     (send physics-item :label (if on "physics: ON " "physics: off"))
     (send physics-item :redraw)
     (send servo-item :label (if (and (eq on :ode) (not (send *evp* :servo))) "servo: OFF" "servo: on "))
     (send servo-item :redraw)
     (send live-item :label (if *eusview-live* "live: ON " "live: off"))
     (send live-item :redraw)))
  (:show-live (str) (send live-info :value str))
  (:physics (&rest args) (if (eusview-physics-on-p) (eusview-physics-stop) (eusview-physics-start)))
  (:servo (&rest args) (eusview-servo-toggle))
  (:live (&rest args) (if *eusview-live* (eusview-live-close) (if (eusview-live-connect) (eusview-live-send t))))
  (:play-motion (sel &rest args) (if (numberp (car sel)) (eusview-play-motion (car sel))))
  (:joint
   (sel obj val &rest args)
   (unless *eusview-playing*
     (eusview-protect
      (send (car sel) :joint-angle val)
      (case (eusview-physics-on-p)
        (:ode (send *evp* :set-target-joint (car sel) val))
        (:kxrdyna (send robot :send-ode 100)))
      (send *eusview-viewer* :draw-objects))))
  (:update-sliders
   ()
   (dolist (s sliders)
     (eusview-protect
      (let ((mn ((cdr s) . x::min-value)) (mx ((cdr s) . x::max-value)))
        (send (cdr s) :value (min mx (max mn (send (car s) :joint-angle))))))))
  (:quit (&rest args) (send self :unmap)))

(defun eusview-motion-menus (pan table rows width)
  "menubar of menus (rows motions each) of the motion table; items call (:play-motion number)"
  (let ((bar (send pan :create-menubar :height 30 :width width))
        (cols (ceiling (/ (float (length table)) rows))))
    (send pan :locate-item bar)
    (dotimes (c cols)
      (let ((menu nil))
        (dotimes (r rows)
          (let* ((n (+ r (* rows c))) (mc (and (< n (length table)) (elt table n))))
            (when mc
              (unless menu (setq menu (instance x::menu-panel :create :font (x::font-id "*-fixed-bold-r-normal-*-18-*"))))
              (send menu :create-item (if (eusview-ja-p) x::xft-button-item x::button-item)
                    (let ((s (format nil "~3D  ~A" n (eusview-mc-name mc))))
                      (if (eusview-ja-p) s (remove-if #'(lambda (ch) (> ch 127)) s)))
                    pan (list :play-motion n)))))
        (if menu
            (send bar :create-item x::menu-button-item (format nil " motion ~A- " (* rows c))
                  pan nil :menu menu :border-width 2))))
    bar))

(defun eusview-searched-string ()
  (let ((dirs (or *eusview-project-searched*
                  (let ((p (and *eusview-name* (or (kxr-body-config-key *eusview-name* :project-file) *eusview-name*))))
                    (if p (progn (eusview-find-project p) *eusview-project-searched*))))))
    (let ((st (make-string-output-stream 256)) (first t))
      (dolist (d dirs) (unless first (princ ", " st)) (princ d st) (setq first nil))
      (get-output-stream-string st))))
(defun eusview-update-toggles ()
  (if *eusview-robot-panel* (eusview-protect (send *eusview-robot-panel* :update-toggles))))

(defun eusview-make-robot-panel ()
  ;; the old panel is unmapped, not destroyed (X events for a destroyed window -> BadDrawable)
  (when *eusview-robot-panel*
    (eusview-protect (send *eusview-robot-panel* :unmap))
    (push *eusview-robot-panel* *eusview-old-panels*)
    (setq *eusview-robot-panel* nil))
  (let ((ret (eusview-protect
              (setq *eusview-robot-panel* (instance eusview-robot-panel :create *eusview-robot*))
              (send *eusview-robot-panel* :move 620 120)
              (if *eusview-live* (eusview-live-show) (eusview-update-toggles))
              t)))
    (unless (eq ret t)
      (setq *eusview-robot-panel* nil)
      (eusview-message "could not make the robot panel: ~A" *eusview-last-error*))))

;;;
;;; entry
;;;
(defun eusview (&optional (name (or (unix:getenv "EUSVIEW_ROBOT") "kxrl2l5a3h2")))
  "EusView demo: robot chooser (KXR/KHR/JSK), poses, motions, physics, live"
  (eusview-make-viewer)
  (xft-init)
  (unless *eusview-panel*
    (setq *eusview-panel* (instance eusview-panel :create))
    (eusview-protect (send *eusview-viewer* :move 0 0) (send *eusview-panel* :move 620 0)))
  (setq *eusview-running* t)
  (if name (eusview-select name))
  t)

(defun eusview-quit ()
  (setq *eusview-stop* t)
  (setq *eusview-running* nil)
  (if (eusview-physics-on-p) (eusview-physics-stop))
  (if *eusview-live* (eusview-live-close))
  (eusview-live-stop-relay)
  (dolist (w (list *eusview-robot-panel* *eusview-panel*))
    (if w (eusview-protect (send w :destroy))))
  (setq *eusview-robot-panel* nil *eusview-panel* nil)
  (when *eusview-viewer*
    (eusview-protect (send *eusview-viewer* :destroy))
    (setq *eusview-viewer* nil))
  (x::xflush)
  (format t ";; eusview: quit~%")
  (if (get 'eusview :exit-on-quit) (exit))
  t)

(defun eusview-main (&optional name)
  "for the desktop launcher (no terminal): run the X events and timer jobs until quit, then exit"
  (setf (get 'eusview :exit-on-quit) t)
  (eusview (or name (unix:getenv "EUSVIEW_ROBOT") "kxrl2l5a3h2"))
  (while *eusview-running*
    (eusview-protect
     (x::window-main-one)
     (dolist (j *timer-job*) (funcall j)))
    (funcall *eusview-orig-usleep* 10000))
  (exit))

(provide :eusview)
