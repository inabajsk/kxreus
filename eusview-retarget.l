;;;
;;; eusview-retarget.l : BVH -> robot (KXR / KHR / JSK) for eusview-bvh.l
;;;	2026.10.5
;;;
;;;  The same specification as the EusView app: mnist/eusview/bvh/RETARGET.md
;;;   method 1 (:names)  joint names: the bvh-robot-model classes of kxreus bvh/*-demo.l
;;;                      (lafan1-, mocopi-, sfu-, rikiya-bvh-robot-model; their :copy-state-to,
;;;                      as bvh-demo.l). The root orientation follows the BVH root.
;;;   method 2 (:gmr)    GMR-like: positions (and the foot orientation) of the body parts with IK.
;;;                      part position of the robot = robot root + C s (human part - human root)
;;;                      (C: human -> robot world at frame 0, s: leg / arm length ratio),
;;;                      limb IK (:inverse-kinematics, from the previous answer, :stop 10):
;;;                      feet: position + orientation, hands: position. Head / torso are not moved.
;;;   Both: the root follows the BVH root horizontally (x s_leg), the lower foot is put on the floor.
;;;
;;;   (eusview-bvh-export-retarget "mocopi/greeting1.bvh" "kxrl2l6a6h2" :names 0 100 10)
;;;      -> ~/.cache/eusview/retarget-<robot>-<kind>-<name>-<method>.json (for the apps' check)
;;;

;; the bvh-robot-model classes of kxreus bvh/*-demo.l (only their defclass / defmethod forms are read:
;; the demo files also define animate, demo, bvh2eus ... and require other files)
(defvar *eusview-bvh-classes*
  '(("lafan1" "lafan1-demo.l" lafan1-bvh-robot-model)
    ("mocopi" "mocopi-demo.l" mocopi-bvh-robot-model)
    ("sfu" "sfu-demo.l" sfu-bvh-robot-model)
    ("rikiya" "bvh-demo.l" rikiya-bvh-robot-model)
    ("tum-kitchen" nil tum-bvh-robot-model)))
(defvar *eusview-bvh-classes-loaded* nil)
;; method 1: kinds whose joint angles at frame 0 (a standing human) are far from a standing robot
;; (lafan1: the rest pose of the BVH joints is rotated, e.g. the hips -178 deg). For them the
;; robot angles are (angle - angle at frame 0) + reset-pose.
(defvar *eusview-bvh-names-calibrate* '("lafan1"))

(defun eusview-bvh-load-classes ()
  (unless *eusview-bvh-classes-loaded*
    (setq *eusview-bvh-classes-loaded* t)
    (dolist (e *eusview-bvh-classes*)
      (let ((f (and (cadr e) (format nil "~A/bvh/~A" *rcb4eus-dir* (cadr e)))) (eof (gensym)) x)
        (when (and f (probe-file f))
          (with-open-file (in f)
            (while (not (eq (setq x (read in nil eof)) eof))
              (when (and (consp x)
                         (or (and (memq (car x) '(defclass defmethod)) (eq (cadr x) (caddr e)))
                             (and (eq (car x) 'defun) (eq (cadr x) 'find-joint-method))))
                ;; bvh-demo.l uses (send robot m :axis) as a vector (its joint :axis), but the
                ;; joint :axis of kxreus utils.l returns the axis as is (:x, :-z ...)
                ;; mocopi (and others) have 6 channels per joint: (send .. :joint :joint-angle) is then
                ;; position and rotation; the demo methods take elements 0-2 -> use the rotation part
                (eval (eusview-tree-replace
                       (eusview-tree-replace x '(send robot m :axis) '(eusview-joint-axis-vector robot m))
                       '(send self limb joint :joint :joint-angle)
                       '(eusview-bvh-rot3 (send self limb joint :joint :joint-angle))))))))))))

(defun eusview-bvh-rot3 (v)
  (if (and (vectorp v) (= (length v) 6)) (subseq v 3 6) v))

(defun eusview-tree-replace (x old new)
  (cond ((equal x old) new)
        ((consp x) (cons (eusview-tree-replace (car x) old new) (eusview-tree-replace (cdr x) old new)))
        (t x)))
(defun eusview-joint-axis-vector (robot m)
  "axis of the joint (send robot m) as a vector ((send robot m :axis) may be :x, :-z ...)"
  (let ((ax (send robot m :axis)))
    (cond ((float-vector-p ax) ax)
          (t (case ax (:x #f(1 0 0)) (:-x #f(-1 0 0)) (:y #f(0 1 0)) (:-y #f(0 -1 0))
               (:z #f(0 0 1)) (:-z #f(0 0 -1)) (t #f(0 0 1)))))))

(defun eusview-bvh-class (kind)
  (eusview-bvh-load-classes)
  (let ((c (caddr (assoc kind *eusview-bvh-classes* :test #'equal))))
    (if (and c (boundp c)) (symbol-value c) bvh-robot-model)))

(defun eusview-bvh-names-p (kind)
  "method 1 (joint names) available: the class has its own :copy-state-to"
  (let ((c (eusview-bvh-class kind)))
    (and (not (eq c bvh-robot-model)) (assoc :copy-state-to (send c :methods)))))

;;; robots for the BVH viewer (RETARGET.md: KXR / KHR / JSK, default one per group)
(defvar *eusview-bvh-robot-names* '((:kxr . "kxrl2l6a6h2") (:khr . "khr20h2") (:jsk . "sample-robot")))
(defvar *eusview-bvh-robots* nil) ;; ((name . (robot1 robot2)) ...)

(defun eusview-bvh-make-robot (name)
  (if (member name *eusview-jsk-robots* :test #'string=)
      (eusview-make-jsk name)
    (kxr-make-robot name :viewer nil :model *eusview-kxr-model*)))

(defun eusview-bvh-robot-pair (name)
  "two instances of robot name (method 1, method 2)"
  (or (cdr (assoc name *eusview-bvh-robots* :test #'equal))
      (let ((p (list (eusview-bvh-make-robot name) (eusview-bvh-make-robot name))))
        (push (cons name p) *eusview-bvh-robots*)
        p)))

;;; parts of the human (bvh-robot-model limbs) and of the robot
(defun eusview-bvh-link-index (links keys)
  (position-if #'(lambda (l) (let ((n (string-downcase (string (send l :name)))))
                               (some #'(lambda (k) (substringp k n)) keys)))
               links))
(defun eusview-bvh-human-parts (m)
  "((limb start middle end) ...) links of the bvh model: shoulder elbow hand / hip knee ankle"
  (let (ret)
    (dolist (limb '(:larm :rarm :lleg :rleg))
      (let* ((ls (send m limb))
             (e (and ls (eusview-bvh-link-index ls (if (memq limb '(:larm :rarm)) '("hand" "wrist" "ha.")
                                                     '("foot" "ankle" "fu."))))))
        (when (and e (>= e 2))
          (push (list limb (elt ls (- e 2)) (elt ls (- e 1)) (elt ls e)) ret))))
    (nreverse ret)))
(defun eusview-bvh-limb-length (a b c) (+ (distance (send a :worldpos) (send b :worldpos)) (distance (send b :worldpos) (send c :worldpos))))
(defun eusview-bvh-robot-limb-length (r limb)
  (let ((ls (send r limb)))
    (if ls (distance (send (car ls) :worldpos) (send r limb :end-coords :worldpos)) 0)))

;;; the retarget state of one robot for one BVH model
(defclass eusview-retarget :super propertied-object
  :slots (robot method mcd model parts s-leg s-arm c-rot root-h0 root-r0 rot-h0 rot-r0
                foot-r0 foot-h0 hand-h0 hand-r0 av0 foot-offset base calib))

(defmethod eusview-retarget
  (:init
   (r meth m &key (offset (float-vector 0 0 0)))
   "r: robot, meth :names / :gmr, m: motion-capture-data at frame 0"
   (setq robot r method meth mcd m model (send m :model) base offset)
   ;; zero, then the reset pose (some :reset-pose set only a part of the joints)
   (send robot :angle-vector (instantiate float-vector (length (send robot :angle-vector))))
   (send robot :reset-pose)
   (send robot :newcoords (make-coords))
   (send robot :worldcoords)
   (setq av0 (copy-seq (send robot :angle-vector)))
   (send mcd :frame 0)
   (setq parts (eusview-bvh-human-parts model))
   (let ((hl (find :lleg parts :key #'car)) (ha (find :larm parts :key #'car)) rl ra)
     (setq rl (eusview-bvh-robot-limb-length robot :lleg) ra (eusview-bvh-robot-limb-length robot :larm))
     ;; legs: the height of the pelvis above the feet (robot at the reset pose / human at frame 0),
     ;; so that the robot stands like at its reset pose when the human stands
     (let ((hz (and hl (- (elt (send (car (send model :links)) :worldpos) 2)
                          (apply #'min (mapcar #'(lambda (p) (elt (send (elt p 3) :worldpos) 2))
                                               (remove-if-not #'(lambda (p) (memq (car p) '(:lleg :rleg))) parts))))))
           (rz (- (elt (send (car (send robot :links)) :worldpos) 2) (eusview-bvh-feet-z robot))))
       (setq s-leg (if (and hz (> hz 1) (> rz 1)) (/ rz hz)
                     (if (and hl (> rl 0)) (/ rl (apply #'eusview-bvh-limb-length (cdr hl))) 0.25))))
     (setq s-arm (if (and ha (> ra 0)) (/ ra (apply #'eusview-bvh-limb-length (cdr ha))) s-leg)))
   (setq root-h0 (copy-seq (send (car (send model :links)) :worldpos))
         rot-h0 (copy-matrix (send (car (send model :links)) :worldrot))
         root-r0 (copy-seq (send robot :worldpos))
         rot-r0 (copy-matrix (send robot :worldrot)))
   ;; C: human world directions -> robot world. The class coords of the bvh model (bvh/*-demo.l)
   ;; turn the rest pose to face like the robot; C removes the heading (yaw) of the human root
   ;; at frame 0 from the rest pose.
   (let* ((delta (m* rot-h0 (transpose (send (send model :copy-worldcoords) :worldrot))))
          (v (transform delta #f(1 0 0))) (yaw (atan (elt v 1) (elt v 0))))
     (setq c-rot (m* rot-r0 (rotation-matrix (- yaw) :z))))
   (setq foot-h0 (mapcar #'(lambda (p) (cons (car p) (copy-matrix (send (elt p 3) :worldrot)))) parts)
         foot-r0 (mapcar #'(lambda (p) (cons (car p) (and (send robot (car p)) (copy-matrix (send robot (car p) :end-coords :worldrot))))) parts))
   ;; sole: lowest body point below the lower foot end-coords at the reset pose
   (setq foot-offset (- (eusview-bvh-robot-min-z robot) (eusview-bvh-feet-z robot)))
   (setq calib nil)
   (when (and (eq method :names) (member (send self :kind) *eusview-bvh-names-calibrate* :test #'equal))
     (send model :copy-state-to robot t)
     (setq calib (v- (copy-seq (send robot :angle-vector)) av0))
     (send robot :angle-vector (copy-seq av0)))
   self)
  (:kind ()
   (let ((c (class model)))
     (car (find-if #'(lambda (e) (and (boundp (caddr e)) (eq (symbol-value (caddr e)) c))) *eusview-bvh-classes*))))
  (:robot () robot)
  (:apply
   (&optional (frame-done t))
   "robot pose of the current frame of mcd (frame set by the caller)"
   (let* ((hroot (send (car (send model :links)) :worldpos))
          (d (v- hroot root-h0)) z)
     (case method
       (:names
        (send robot :angle-vector (copy-seq av0))
        (send model :copy-state-to robot t) ;; joints (bvh/*-demo.l)
        (when calib
          (let ((av (v- (send robot :angle-vector) calib)) (jl (send robot :joint-list)))
            (dotimes (i (min (length av) (length jl)))
              (let ((j (elt jl i)))
                (setf (elt av i) (min (send j :max-angle) (max (send j :min-angle) (elt av i))))))
            (send robot :angle-vector av)))
        ;; root orientation: the rotation of the BVH root since frame 0 (as GMR; the absolute BVH root
        ;; rotation of :copy-state-to stay=nil lays the robot down when the BVH root frame is turned)
        (let* ((dr (m* (send (car (send model :links)) :worldrot) (transpose rot-h0)))
               (rr (m* (m* c-rot dr) (transpose c-rot))))
          (send robot :newcoords (make-coords :rot (m* rr rot-r0) :pos (send robot :worldpos)))))
       (t (send self :gmr)))
     ;; root: horizontal displacement x s_leg, then the lower foot on the floor
     (send robot :locate (v+ base (float-vector (* s-leg (elt d 0)) (* s-leg (elt d 1)) 0)) :world)
     (send robot :worldcoords)
     (setq z (+ (eusview-bvh-feet-z robot) foot-offset))
     (send robot :translate (float-vector 0 0 (- z)) :world)
     (send robot :worldcoords)
     robot))
  (:gmr
   ()
   (let* ((hroot-l (car (send model :links)))
          (dr (m* (send hroot-l :worldrot) (transpose rot-h0)))   ;; root rotation of the human (world)
          (rr (m* (m* c-rot dr) (transpose c-rot))))
     (send robot :newcoords (make-coords :rot (m* rr rot-r0) :pos (send robot :worldpos)))
     (send robot :worldcoords)
     (dolist (p parts)
       (let* ((limb (car p)) (hp (send (elt p 3) :worldpos))
              (s (if (memq limb '(:larm :rarm)) s-arm s-leg))
              ;; relative to the root link (pelvis) of the robot (the robot coords may be at the soles)
              (tgt (v+ (send (car (send robot :links)) :worldpos)
                       (transform c-rot (scale s (v- hp (send hroot-l :worldpos))))))
              rot c)
         (when (send robot limb)
           (when (memq limb '(:lleg :rleg))
             (setq rot (m* (m* (m* c-rot (m* (send (elt p 3) :worldrot) (transpose (cdr (assoc limb foot-h0)))))
                               (transpose c-rot))
                           (cdr (assoc limb foot-r0)))))
           (setq c (make-coords :pos tgt :rot (or rot (send robot limb :end-coords :worldrot))))
           (send robot limb :inverse-kinematics c
                 :rotation-axis (if rot t nil) :stop 10 :revert-if-fail nil :warnp nil
                 :thre 1.0 :rthre (deg2rad 2) :debug-view nil))))))
  )

(defun eusview-bvh-feet-z (r)
  (let ((zs nil))
    (dolist (l '(:lleg :rleg)) (if (send r l) (push (elt (send r l :end-coords :worldpos) 2) zs)))
    (if zs (apply #'min zs) (elt (send r :worldpos) 2))))
(defun eusview-bvh-robot-min-z (r)
  (let ((z 1e10))
    (dolist (b (send r :bodies))
      (when (find-method b :vertices)
        (dolist (v (send b :vertices)) (if (< (elt v 2) z) (setq z (elt v 2))))))
    (if (< z 1e9) z (eusview-bvh-feet-z r))))

;;;
;;; key frames for the robot panel (play as a motion; physics on: servo targets)
;;;
(defvar *eusview-key-roots* nil) ;; ((ms . coords) ...) root of the robot for the keys (physics off)

(defun eusview-bvh-retarget-keys (robot kind file method &key (fps 15) (max-sec 60))
  "((ms . angle-vector) ...) and sets *eusview-key-roots*"
  (let* ((l (eusview-bvh-load kind file)) (mcd (car l)) (ft (cadr l))
         (n (send mcd :frame-length)) (av-save (copy-seq (send robot :angle-vector)))
         (c-save (send robot :copy-worldcoords))
         rt keys roots (tm 0) (dtm (/ 1000.0 fps)))
    ;; the root path starts where the robot is now (horizontally)
    (setq rt (instance eusview-retarget :init robot method mcd
                       :offset (float-vector (elt (send c-save :worldpos) 0) (elt (send c-save :worldpos) 1) 0)))
    (while (and (< (floor (/ (* tm 0.001) ft)) n) (<= tm (* 1000 max-sec)))
      (send mcd :frame (floor (/ (* tm 0.001) ft)))
      (send rt :apply)
      (push (cons tm (copy-seq (send robot :angle-vector))) keys)
      (push (cons tm (send robot :copy-worldcoords)) roots)
      (setq tm (+ tm dtm)))
    (send robot :angle-vector av-save)
    (send robot :newcoords c-save)
    (send robot :worldcoords)
    (setq *eusview-key-roots* (nreverse roots))
    ;; look at the whole path
    (when *eusview-viewer*
      (let ((pts nil) (h 400))
        (dolist (r *eusview-key-roots*)
          (let ((p (send (cdr r) :worldpos)))
            (push (v+ p (float-vector h h h)) pts) (push (v- p (float-vector h h 0)) pts)))
        (if pts (send *eusview-viewer* :look-all (make-bounding-box pts)))))
    (nreverse keys)))

(defun eusview-key-root (tm)
  (let ((k *eusview-key-roots*))
    (while (and (cdr k) (<= (car (cadr k)) tm)) (setq k (cdr k)))
    (cdr (car k))))

;;;
;;; export of method 1 / 2 for the apps (JSON: joints in the eus2json order, deg / mm; root in m)
;;;
(defun eusview-bvh-export-retarget (file robot-name &optional (method :names) (start 0) (end 100) (step 10)
                                         &key out)
  "file: <kind>/<name>.bvh under kxreus/bvh (or a full path); returns the JSON file name"
  (let* ((full (if (probe-file file) file (format nil "~A/~A" (eusview-bvh-dir) file)))
         (rel (let ((pre (format nil "~A/" (eusview-bvh-dir))))
                (if (and (> (length full) (length pre)) (string= pre (subseq full 0 (length pre))))
                    (subseq full (length pre)) full)))
         (kind (subseq rel 0 (or (position #\/ rel) 0)))
         (l (eusview-bvh-load kind full)) (mcd (car l)) (ft (cadr l))
         (r (eusview-bvh-make-robot robot-name))
         (rt (instance eusview-retarget :init r method mcd))
         (jl (eusview-joints r)) (dir (format nil "~A/.cache/eusview" (unix:getenv "HOME")))
         (fname (or out (format nil "~A/retarget-~A-~A-~A-~A.json" dir robot-name kind
                                (substitute #\_ #\/ (eusview-bvh-name kind full))
                                (string-downcase (string method)))))
         (first t))
    (unix:system (format nil "mkdir -p ~A" dir))
    (with-open-file (o fname :direction :output)
      (format o "{\"file\":\"~A\",\"kind\":\"~A\",\"robot\":\"~A\",\"method\":\"~A\",\"frame_time\":~A,~%"
              rel kind robot-name (string-downcase (string method)) ft)
      (format o "\"joints\":[~A],~%\"frames\":[~%"
              (eusview-join (mapcar #'(lambda (j) (format nil "\"~A\"" (string-downcase (string (send j :name))))) jl)))
      (do ((i start (+ i step))) ((or (> i end) (>= i (send mcd :frame-length))))
        (send mcd :frame i)
        (send rt :apply)
        (let ((c (send (car (send r :links)) :worldcoords)) (m nil))
          (setq m (send c :worldrot))
          (format o "~A{\"frame\":~A,\"angles\":[~A],\"root\":[~A]}" (if first "" (format nil ",~%")) i
                  (eusview-join (mapcar #'(lambda (j) (eusview-num (send j :joint-angle))) jl))
                  (eusview-join (mapcar #'(lambda (x) (format nil "~A" (/ (round (* x 10000.0)) 10000.0)))
                                        (append (coerce (scale 0.001 (send c :worldpos)) cons)
                                                (list (aref m 0 0) (aref m 0 1) (aref m 0 2) (aref m 1 0) (aref m 1 1)
                                                      (aref m 1 2) (aref m 2 0) (aref m 2 1) (aref m 2 2)))))))
        (setq first nil))
      (format o "~%]}~%"))
    (format t ";; eusview-bvh-export-retarget: ~A~%" fname)
    fname))

(provide :eusview-retarget)
