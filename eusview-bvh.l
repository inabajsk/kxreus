;;;
;;; eusview-bvh.l : BVH (motion capture) playback for eusview.l
;;;	2026.10.5
;;;
;;;  Plays the BVH files of kxreus/bvh/<kind>/ (lafan1, mocopi, rikiya, sfu, tum-kitchen ...) as the
;;;  BVH skeleton (jskeus irteus/irtbvh.l load-mcd -> bvh-robot-model; no retargeting to the robot).
;;;  Read like kxreus bvh/*-demo.l: scale 10 (tum-kitchen 1.0, see *eusview-bvh-scale*), BVH y-up is
;;;  turned to z-up (tum-kitchen is z-up), the skeleton is put on the floor (lowest point at frame 0)
;;;  with its root at the origin.
;;;
;;;   BVH panel (EusView panel -> "BVH"):
;;;     auto play        every file of every kind in turn (kind by kind) until stop
;;;     <kind> 1- 21- .. menus of the files (20 per menu); the chosen file repeats until stop
;;;     stop, speed (0.5x / 1x / 2x / 4x), robot: hide / show (the robot beside the skeleton)
;;;   (eusview-bvh-request :auto "lafan1" 0)    (eusview-bvh-request :repeat "sfu" 3)
;;;

(defvar *eusview-bvh-scale* '(("tum-kitchen" . 1.0)))   ;; others 10 (bvh/*-demo.l)
;; frame time of the files is used; TUM kitchen files say 0.4 s but were recorded at 25 Hz
(defvar *eusview-bvh-frame-time* '(("tum-kitchen" . 0.04)))
;; y-up BVH (most) are turned to z-up; TUM kitchen is z-up already
(defvar *eusview-bvh-z-up* '("tum-kitchen"))
(defvar *eusview-bvh-kinds* nil)   ;; (("lafan1" "/.../a.bvh" ...) ...)
(defvar *eusview-bvh-next* nil)    ;; (mode kind index) requested while something plays
(defvar *eusview-bvh-mode* nil)    ;; the skeleton is shown
(defvar *eusview-bvh-model* nil)
(defvar *eusview-bvh-speed* 1.0)
(defvar *eusview-bvh-show-robot* nil)
(defvar *eusview-bvh-panel* nil)
(defvar *eusview-bvh-status* "")

(defun eusview-bvh-dir () (format nil "~A/bvh" *rcb4eus-dir*))

(defun eusview-bvh-scan ()
  "kinds (subdirectories of kxreus/bvh with *.bvh files, recursively) and their files, sorted"
  (let ((f (format nil "/tmp/eusview-bvh-~A.txt" (unix:getpid))) (ret nil) l)
    (unix:system (format nil "cd ~A 2>/dev/null && find . -mindepth 2 -name '*.bvh' | sort > ~A"
                         (eusview-bvh-dir) f))
    (when (probe-file f)
      (with-open-file (in f)
        (while (setq l (read-line in nil nil))
          (let* ((p (subseq l 2)) (k (position #\/ p)) (kind (subseq p 0 k)) (e (assoc kind ret :test #'equal)))
            (unless e (setq e (list kind)) (setq ret (append ret (list e))))
            (nconc e (list (format nil "~A/~A" (eusview-bvh-dir) p))))))
      (unix:system (format nil "rm -f ~A" f)))
    (setq *eusview-bvh-kinds* ret)))

(defun eusview-bvh-files (kind) (cdr (assoc kind *eusview-bvh-kinds* :test #'equal)))

(defun eusview-bvh-name (kind file)
  "file name for the menus: path under bvh/<kind>/ without .bvh (tum-kitchen: 0-1/poses -> 0-1)"
  (let* ((pre (format nil "~A/~A/" (eusview-bvh-dir) kind))
         (s (if (and (> (length file) (length pre)) (string= pre (subseq file 0 (length pre))))
                (subseq file (length pre)) file)))
    (if (and (> (length s) 4) (string= ".bvh" (subseq s (- (length s) 4)))) (setq s (subseq s 0 (- (length s) 4))))
    (if (and (> (length s) 6) (string= "/poses" (subseq s (- (length s) 6)))) (setq s (subseq s 0 (- (length s) 6))))
    s))

(defun eusview-bvh-file-frame-time (file)
  (let (l v)
    (with-open-file (in file)
      (while (setq l (read-line in nil nil))
        (when (eusview-string-index "Frame Time" l)
          (setq v (read-from-string (subseq l (1+ (position #\: l))) nil nil))
          (return))))
    (if (and (numberp v) (> v 0)) v 0.033333)))

(defun eusview-bvh-load (kind file)
  "motion-capture-data of file (the skeleton on the floor at the origin) and its frame time"
  (let* ((sc (or (cdr (assoc kind *eusview-bvh-scale* :test #'equal)) 10.0))
         (ft (or (cdr (assoc kind *eusview-bvh-frame-time* :test #'equal)) (eusview-bvh-file-frame-time file)))
         (cls (eusview-bvh-class kind))
         ;; the classes of bvh/*-demo.l (and jskeus tum-) set their own coords (z up, facing the robots)
         (mcd (if (eq cls bvh-robot-model)
                  (load-mcd file :scale sc :coords (if (member kind *eusview-bvh-z-up* :test #'equal) (make-coords)
                                                     (make-coords :rpy (list 0 0 pi/2))))
                (load-mcd file :scale sc :bvh-robot-model-class cls)))
         (m (send mcd :model)) bb root dv)
    (send mcd :frame 0)
    (send m :worldcoords)
    (setq bb (make-bounding-box (mapcar #'(lambda (l) (copy-seq (send l :worldpos))) (send m :links))))
    (setq root (copy-seq (send (car (send m :links)) :worldpos)))
    (setq dv (float-vector (- (elt root 0)) (- (elt root 1)) (- (elt (send bb :minpoint) 2))))
    (send m :translate dv :world)
    (send m :worldcoords)
    (list mcd ft)))

(defvar *eusview-bvh-robot-group* :kxr)   ;; :kxr :khr :jsk or nil (RETARGET.md)
(defvar *eusview-bvh-show-names* t)        ;; method 1 robot
(defvar *eusview-bvh-show-gmr* t)          ;; method 2 robot
(defvar *eusview-bvh-retargets* nil)       ;; eusview-retarget instances of the current file

(defun eusview-bvh-make-retargets (kind mcd)
  "the method 1 / method 2 robots beside the skeleton (skeleton at y 0, then -gap, -2 gap)"
  (setq *eusview-bvh-retargets* nil)
  (let* ((name (cdr (assoc *eusview-bvh-robot-group* *eusview-bvh-robot-names*))) pair h gap)
    (when name
      (setq pair (eusview-bvh-robot-pair name))
      (send (car pair) :reset-pose)
      (setq h (- (elt (send (send (car pair) :worldcoords) :worldpos) 2) 0))
      (setq h (let ((bb (make-bounding-box (flatten (mapcar #'(lambda (b) (if (find-method b :vertices) (send b :vertices))) (send (car pair) :bodies))))))
                (elt (send bb :diagonal) 2)))
      (setq gap (+ 450 (* 0.6 h)))
      (when (and *eusview-bvh-show-names* (eusview-bvh-names-p kind))
        (push (instance eusview-retarget :init (car pair) :names mcd :offset (float-vector 0 (- gap) 0))
              *eusview-bvh-retargets*))
      (when *eusview-bvh-show-gmr*
        (push (instance eusview-retarget :init (cadr pair) :gmr mcd :offset (float-vector 0 (* -2 gap) 0))
              *eusview-bvh-retargets*))
      (dolist (rt *eusview-bvh-retargets*) (send rt :apply)))
    *eusview-bvh-retargets*))

(defun eusview-bvh-view (mcd &optional kind)
  "skeleton and the retarget robots in the viewer, looking at the root path of the whole file"
  (let* ((m (send mcd :model)) (n (send mcd :frame-length)) (pts nil) bb)
    (setq *eusview-bvh-model* m *eusview-bvh-mode* t)
    (send mcd :frame 0)
    (if kind (eusview-protect (eusview-bvh-make-retargets kind mcd)))
    (send *eusview-viewer* :objects
          (append (list m) (mapcar #'(lambda (rt) (send rt :robot)) *eusview-bvh-retargets*)))
    (do ((i 0 (+ i (max 1 (/ n 40))))) ((>= i n))
      (send mcd :frame i)
      (dolist (l (send m :links)) (push (copy-seq (send l :worldpos)) pts)))
    (send mcd :frame 0)
    (dolist (rt *eusview-bvh-retargets*)
      (dolist (b (send (send rt :robot) :bodies))
        (if (find-method b :vertices) (setq pts (append (mapcar #'copy-seq (send b :vertices)) pts)))))
    (setq bb (make-bounding-box pts))
    (send *eusview-viewer* :look-all bb)
    (send *eusview-viewer* :draw-objects)))

(defun eusview-bvh-leave ()
  "back to the robot"
  (when *eusview-bvh-mode*
    (setq *eusview-bvh-mode* nil *eusview-bvh-model* nil)
    (when *eusview-robot*
      (send *eusview-viewer* :objects (list *eusview-robot*))
      (send *eusview-viewer* :look-all)
      (send *eusview-viewer* :draw-objects))))

(defun eusview-bvh-show-status (str)
  (setq *eusview-bvh-status* str)
  (when *eusview-panel* (send *eusview-panel* :status-item :value str))
  (if *eusview-bvh-panel* (eusview-protect (send *eusview-bvh-panel* :show str))))

(defun eusview-bvh-play-file (kind file &optional (count 1))
  "play file once at *eusview-bvh-speed* (real time); t when it ended, nil when stopped"
  (let (ret mcd ft n (t0 0) (tlast 0) (i 0) name)
    (setq name (eusview-bvh-name kind file))
    (eusview-bvh-show-status
     (format nil (if (eusview-ja-p) "BVH 読み込み中: ~A/~A ..." "loading BVH: ~A/~A ...") kind name))
    (dotimes (k 3) (x::window-main-one))
    (x::xflush)
    (setq ret (eusview-protect (let ((l (eusview-bvh-load kind file))) (setq mcd (car l) ft (cadr l))) t))
    (unless (eq ret t)
      (eusview-message "BVH ~A/~A: ~A" kind name *eusview-last-error*)
      (return-from eusview-bvh-play-file t)) ;; skip this file
    (setq n (send mcd :frame-length))
    (eusview-bvh-view mcd kind)
    (setq t0 (eusview-now-ms))
    (while (and (< i n) (not *eusview-stop*))
      (send mcd :frame i)
      (dolist (rt *eusview-bvh-retargets*) (eusview-protect (send rt :apply)))
      (send *eusview-viewer* :draw-objects)
      (when (> (- (eusview-now-ms) tlast) 300)
        (setq tlast (eusview-now-ms))
        (eusview-bvh-show-status
         (format nil (if (eusview-ja-p) "BVH 再生中: ~A/~A（フレーム ~A/~A, ~A fps, ~Ax~A）"
                       "BVH playing: ~A/~A (frame ~A/~A, ~A fps, ~Ax~A)")
                 kind name (1+ i) n (round (/ 1.0 ft)) *eusview-bvh-speed*
                 (if (> count 1) (format nil (if (eusview-ja-p) ", ~A 回目" ", #~A") count) ""))))
      (x::window-main-one)
      (funcall *eusview-orig-usleep* 5000)
      ;; the frame of the elapsed time (frames are skipped when drawing is slower)
      (setq i (max (1+ i) (floor (/ (* (- (eusview-now-ms) t0) 0.001 *eusview-bvh-speed*) ft)))))
    (not *eusview-stop*)))

(defun eusview-bvh-run (mode kind idx)
  (let ((files (eusview-bvh-files kind)) (count 0))
    (cond
     ((null files) (eusview-message (if (eusview-ja-p) "BVH ~A: ファイルがありません" "BVH ~A: no files") kind))
     ((eq mode :repeat)
      (let ((f (elt files (min idx (1- (length files))))))
        (while (not *eusview-stop*)
          (incf count)
          (eusview-bvh-play-file kind f count))))
     (t ;; :auto: files of kind from idx, then the next kinds, around
      (let* ((kinds (mapcar #'car *eusview-bvh-kinds*)) (ki (or (position kind kinds :test #'equal) 0)) (fi idx))
        (while (not *eusview-stop*)
          (let* ((k (elt kinds ki)) (fs (eusview-bvh-files k)))
            (if (< fi (length fs))
                (progn (eusview-bvh-play-file k (elt fs fi)) (incf fi))
              (setq ki (mod (1+ ki) (length kinds)) fi 0)))))))))

(defun eusview-bvh-request (mode kind idx)
  "play (mode :auto / :repeat) from file idx of kind; while something plays: switch to it"
  (cond
   ((null *eusview-bvh-kinds*)
    (eusview-message (if (eusview-ja-p) "BVH がありません（~A/<種類>/*.bvh を置く）" "no BVH files (put them in ~A/<kind>/*.bvh)")
                     (eusview-bvh-dir)))
   (*eusview-playing*
    (setq *eusview-bvh-next* (list mode kind idx) *eusview-next-motion* nil *eusview-stop* t))
   (t
    (if (eusview-physics-on-p) (eusview-physics-stop))
    (setq *eusview-bvh-next* (list mode kind idx) *eusview-playing* t)
    (unwind-protect
        (while *eusview-bvh-next*
          (let ((r *eusview-bvh-next*))
            (setq *eusview-bvh-next* nil *eusview-stop* nil)
            (eusview-protect (apply #'eusview-bvh-run r))))
      (setq *eusview-playing* nil *eusview-stop* nil)
      (eusview-bvh-show-status (if (eusview-ja-p) "BVH を止めました" "BVH stopped")))
    ;; a robot motion chosen while the BVH played
    (when *eusview-next-motion*
      (let ((n *eusview-next-motion*)) (setq *eusview-next-motion* nil)
        (eusview-bvh-leave) (eusview-play-motion n))))))

;;;
;;; BVH panel
;;;
(defclass eusview-bvh-panel :super x::panel :slots (speed-item robot-item names-item gmr-item info-item))
(defmethod eusview-bvh-panel
  (:create
   (&rest args)
   (let ((width 1180) (nrows 0))
     (dolist (k *eusview-bvh-kinds*) (incf nrows (1+ (/ (length (cdr k)) 300))))
     (send-super* :create :width width :height (+ 110 (* 40 (max 1 nrows))) :title "EusView BVH" args)
     (send self :create-item x::button-item "auto play" self :auto)
     (send self :create-item x::button-item "stop" self :stop)
     (setq speed-item (send self :create-item x::button-item "speed: 1x  " self :speed))
     ;; robots beside the skeleton (RETARGET.md): group, method 1 (joint names), method 2 (GMR)
     (setq robot-item (send self :create-item x::button-item (eusview-bvh-robot-label) self :robot))
     (setq names-item (send self :create-item x::button-item "joint names: ON " self :names))
     (setq gmr-item (send self :create-item x::button-item "GMR: ON " self :gmr))
     (send self :create-item x::button-item "back to robot" self :leave)
     (send self :create-item x::button-item "close" self :close)
     (setq info-item (send self :create-item x::xft-label-item "" :width (- width 20)))
     (if (null *eusview-bvh-kinds*)
         (send info-item :value
               (format nil (if (eusview-ja-p) "BVH がありません（~A/<種類>/*.bvh を置く）" "no BVH files in ~A/<kind>/")
                       (eusview-bvh-dir)))
       (dolist (k *eusview-bvh-kinds*)
         (send self :kind-menus (car k) (cdr k) (- width 20))))
     self))
  (:kind-menus (kind files width) (eusview-bvh-file-menus self kind files width))
  (:show (str) (send info-item :value str))
  (:auto (&rest args) (eusview-bvh-request :auto (car (car *eusview-bvh-kinds*)) 0))
  (:play (sel &rest args) (eusview-bvh-request :repeat (car sel) (cadr sel)))
  (:stop (&rest args) (setq *eusview-stop* t *eusview-bvh-next* nil *eusview-next-motion* nil))
  (:speed
   (&rest args)
   (setq *eusview-bvh-speed*
         (let ((l '(0.5 1.0 2.0 4.0))) (or (cadr (member *eusview-bvh-speed* l :test #'=)) 0.5)))
   (send speed-item :label (format nil "speed: ~Ax" *eusview-bvh-speed*))
   (send speed-item :redraw))
  (:robot
   (&rest args)
   (setq *eusview-bvh-robot-group*
         (let ((l '(:kxr :khr :jsk nil))) (cadr (member *eusview-bvh-robot-group* l))))
   (send robot-item :label (eusview-bvh-robot-label))
   (send robot-item :redraw)
   (send self :changed))
  (:names
   (&rest args)
   (setq *eusview-bvh-show-names* (not *eusview-bvh-show-names*))
   (send names-item :label (if *eusview-bvh-show-names* "joint names: ON " "joint names: off"))
   (send names-item :redraw)
   (send self :changed))
  (:gmr
   (&rest args)
   (setq *eusview-bvh-show-gmr* (not *eusview-bvh-show-gmr*))
   (send gmr-item :label (if *eusview-bvh-show-gmr* "GMR: ON " "GMR: off"))
   (send gmr-item :redraw)
   (send self :changed))
  (:changed
   ()
   (eusview-bvh-show-status
    (if (eusview-ja-p) "ロボットの表示は次のファイル（次の繰り返し）から変わります"
      "the robots change from the next file (next repeat)")))
  (:leave (&rest args) (send self :stop) (eusview-bvh-leave))
  (:close (&rest args) (send self :stop) (eusview-bvh-leave) (send self :unmap)))

(defun eusview-bvh-robot-label ()
  (let ((n (cdr (assoc *eusview-bvh-robot-group* *eusview-bvh-robot-names*))))
    (if n (format nil "robot: ~A ~A" (string-upcase (string *eusview-bvh-robot-group*)) n) "robot: none")))

;;;
;;; BVH as a motion of the robot of the robot panel: kind -> file -> method (joint names / GMR)
;;;
(defvar *eusview-bvh-robot-method* :names)
(defvar *eusview-bvh-robot-panel* nil)
(defclass eusview-bvh-robot-panel :super x::panel :slots (kind method-item info-item))
(defmethod eusview-bvh-robot-panel
  (:create
   (k &rest args)
   (let ((width 1000) (files (eusview-bvh-files k)))
     (setq kind k)
     (send-super* :create :width width :height 140 :title (format nil "EusView BVH -> ~A: ~A" *eusview-name* k) args)
     (setq method-item (send self :create-item x::button-item (eusview-bvh-method-label) self :method))
     (send self :create-item x::button-item "stop" self :stop)
     (send self :create-item x::button-item "close" self :close)
     (setq info-item (send self :create-item x::xft-label-item
                           (if (eusview-ja-p) "ファイルを選ぶと、このロボットで繰り返し再生（physics ON ならサーボの目標）"
                             "choose a file: played repeatedly on this robot (physics ON: servo targets)")
                           :width (- width 20)))
     (eusview-bvh-file-menus self k files (- width 20))
     self))
  (:method
   (&rest args)
   (setq *eusview-bvh-robot-method* (if (eq *eusview-bvh-robot-method* :names) :gmr :names))
   (send method-item :label (eusview-bvh-method-label))
   (send method-item :redraw))
  (:play (sel &rest args) (eusview-play-motion (list :bvh (car sel) (cadr sel) *eusview-bvh-robot-method*)))
  (:stop (&rest args) (setq *eusview-stop* t *eusview-next-motion* nil))
  (:close (&rest args) (send self :stop) (send self :unmap)))
(defun eusview-bvh-method-label ()
  (if (eq *eusview-bvh-robot-method* :names) "method: joint names" "method: GMR        "))

(defun eusview-bvh-file-menus (pan kind files width)
  "a menubar of the files of kind (menus of 20); items call (send pan :play (list kind index))"
  (let ((bar (send pan :create-menubar :height 30 :width width)) (n (length files)) (rows 20))
    (send pan :locate-item bar)
    (dotimes (c (ceiling (/ (float n) rows)))
      (let ((menu (instance x::menu-panel :create :font (x::font-id "*-fixed-bold-r-normal-*-18-*"))))
        (dotimes (r rows)
          (let ((i (+ r (* rows c))))
            (when (< i n)
              (send menu :create-item (if (eusview-ja-p) x::xft-button-item x::button-item)
                    (format nil "~3D  ~A" (1+ i) (eusview-bvh-name kind (elt files i)))
                    pan (list :play kind i)))))
        (send bar :create-item x::menu-button-item
              (if (= c 0) (format nil " ~A (~A) 1- " kind n) (format nil " ~A- " (1+ (* rows c))))
              pan nil :menu menu :border-width 2)))
    bar))

(defun eusview-bvh-open-robot-panel (kind)
  (eusview-bvh-scan)
  (when *eusview-bvh-robot-panel* (eusview-protect (send *eusview-bvh-robot-panel* :unmap)))
  (setq *eusview-bvh-robot-panel* (instance eusview-bvh-robot-panel :create kind))
  (eusview-protect (send *eusview-bvh-robot-panel* :move 620 700)))

(defun eusview-bvh-open-panel ()
  (eusview-bvh-scan)
  (if *eusview-bvh-panel*
      (send *eusview-bvh-panel* :map)
    (progn
      (setq *eusview-bvh-panel* (instance eusview-bvh-panel :create))
      (eusview-protect (send *eusview-bvh-panel* :move 0 660))))
  (eusview-message (if (eusview-ja-p) "BVH: ~A 種類, ~A ファイル（~A）" "BVH: ~A kinds, ~A files (~A)")
                   (length *eusview-bvh-kinds*) (apply #'+ (mapcar #'(lambda (k) (length (cdr k))) *eusview-bvh-kinds*))
                   (eusview-bvh-dir)))

(provide :eusview-bvh)
