;;;
;;; eusview-physics.l : ODE physics for eusview.l without kxrdyna.l / odedyna.l
;;;	2026.10.5
;;;
;;;  Uses the C layer of the EusView app (eusview-ode/odesim.cpp, built by "make eusview-ode" into
;;;  $ARCHDIR/lib/libeusviewode.so; Ubuntu: sudo apt install libode-dev) through defforeign.
;;;  The robot model is made like eusview's eus2physics.l (= odedyna.l robot2drobot as used by
;;;  kxrdyna.l kxr-dyna):
;;;   - one rigid body per link (body origin = center of mass), collision: one box per body of
;;;     the link (bounding box in the body frame), bodies made by revolution -> cylinders.
;;;     Only robot - floor (z = 0) contacts.
;;;   - mass: link :weight (g) (kxreus); robots without weights (jskeus models): volume x 1 g/cm^3.
;;;     com: weighted volume centroids of the bodies; inertia: uniform boxes about the com.
;;;   - joints: hinge / slider at the child link origin, axis of the child link; servo every step
;;;     Vel = kp (target - angle), FMax = fmax (odedyna_motor: kp 10, fmax 500000 = unlimited).
;;;     Links without a joint are fixed (a hinge held at 0).
;;;   - world: dt 0.01 s, dWorldStep, erp 0.2, joint cfm 1e-5, contact mu 0.1, soft erp 0.2,
;;;     soft cfm 0.01, bounce 0.01, 1 contact point per pair (odedyna d-init :max-contacts 1).
;;;  The robot is put on the floor (lowest collision point 1 mm above z = 0) at the start pose.
;;;  Every frame the joint angles and the root link coords are set from the simulation.
;;;
;;;  (evp-start robot)         make the ODE model of robot at its current pose (returns t or nil)
;;;  (evp-set-targets av)      servo targets (angle-vector order of evp joints: deg / mm)
;;;  (evp-tick)                advance by the real time since the last tick and update the robot
;;;  (evp-stop)                destroy it and put the robot back to the start pose and coords
;;;

(defvar *evp* nil)          ;; the running simulation (evp-sim instance) or nil
(defvar *evp-lib* nil)
(defvar *evp-loaded* nil)
(defvar *evp-density* 1.0)  ;; g/cm^3 for robots without weights
(defvar *evp-world* '((:gravity . #f(0 0 -9.81)) (:dt . 0.01) (:erp . 0.2) (:cfm . 1e-5)
                      (:iterations . 30) (:quickstep . 0)))
(defvar *evp-contact* '((:mu . 0.1) (:soft-erp . 0.2) (:soft-cfm . 0.01) (:bounce . 0.01)
                        (:bounce-vel . 1.0) (:max-contacts . 1)))
(defvar *evp-motor* '((:kp . 10.0) (:fmax . 500000.0) (:vmax . 1e6)))
(defvar *evp-free-fmax* 2.0) ;; N m: servo off -> 0.02 N m of friction (KRS-3304: 1.36 N m)
(defvar *evp-default-body-weight* 10.0) ;; g (odedyna :init-primitive)
(defun evp-cdr (k al) (cdr (assoc k al)))
(defun evp-now-ms ()
  (let ((tv (unix:gettimeofday))) (+ (* 1000.0 (car tv)) (/ (cadr tv) 1000.0))))

(defun evp-lib-file ()
  (let ((arch (or (unix:getenv "ARCHDIR")
                  (cond ((memq :darwin *features*) "Darwin")
                        ((memq :x86_64 *features*) "Linux64")
                        (t "LinuxARM"))))
        (dirs (list (if (boundp '*rcb4eus-dir*) *rcb4eus-dir*) (unix:getwd))))
    (dolist (d dirs)
      (when d
        (let ((f (format nil "~A/~A/lib/libeusviewode.so" (string-right-trim "/" d) arch)))
          (if (probe-file f) (return-from evp-lib-file f)))))
    nil))

(defun evp-available-p () (or *evp-loaded* (evp-lib-file)))

(defun evp-load ()
  (unless *evp-loaded*
    (let ((f (evp-lib-file)) m)
      (unless f (error "libeusviewode.so not found (make eusview-ode)"))
      (setq m (load-foreign f))
      (defforeign evp-create m "odesim_create" (:string :float :float :float :float :float :float :integer) :integer)
      (defforeign evp-destroy m "odesim_destroy" (:integer) :integer)
      (defforeign evp-add-link m "odesim_add_link" (:integer :float :string :string :string :string) :integer)
      (defforeign evp-add-box m "odesim_add_box" (:integer :integer :string :string :string) :integer)
      (defforeign evp-add-cylinder m "odesim_add_cylinder" (:integer :integer :float :float :string :string) :integer)
      (defforeign evp-add-joint m "odesim_add_joint"
        (:integer :integer :integer :integer :string :string :float :float :float :float :float) :integer)
      (defforeign evp-set-joint-offset m "odesim_set_joint_offset" (:integer :integer :float :float :float) :integer)
      (defforeign evp-set-joint-mode m "odesim_set_joint_mode" (:integer :integer :integer) :integer)
      (defforeign evp-set-targets-c m "odesim_set_targets" (:integer :string :integer) :integer)
      (defforeign evp-set-servo m "odesim_set_servo" (:integer :integer) :integer)
      (defforeign evp-set-fmax m "odesim_set_fmax" (:integer :integer :float) :integer)
      (defforeign evp-set-options m "odesim_set_options" (:integer :integer :integer :float) :integer)
      (defforeign evp-step m "odesim_step" (:integer :float :integer) :integer)
      (defforeign evp-contacts m "odesim_contacts" (:integer) :integer)
      (defforeign evp-link-poses m "eusviewode_link_poses" (:integer :integer :string) :integer)
      (defforeign evp-joint-values m "eusviewode_joint_values" (:integer :integer :string) :integer)
      (defforeign evp-step-safe m "eusviewode_step_safe" (:integer :float :integer :integer) :integer)
      (setq *evp-lib* m *evp-loaded* f)))
  *evp-loaded*)

;;;
;;; physical parameters (eusview/eus2physics.l)
;;;
(defvar *evp-body-density* nil) ;; g/mm^3 when estimating from volumes

(defun evp-link-parent (l links)
  (let ((p (send l :parent)))
    (while (and p (not (memq p links))) (setq p (send p :parent)))
    p))
(defun evp-sort-links (links)
  "parents before children"
  (let ((done nil) (rest (copy-list links)) (changed t))
    (while (and rest changed)
      (setq changed nil)
      (dolist (l rest)
        (let ((p (evp-link-parent l links)))
          (when (or (null p) (memq p done))
            (setq done (append done (list l)) rest (remove l rest) changed t)))))
    (append done rest)))
(defun evp-axis-vector (ax)
  (cond ((float-vector-p ax) (normalize-vector ax))
        (t (case ax (:x #f(1 0 0)) (:-x #f(-1 0 0)) (:y #f(0 1 0)) (:-y #f(0 -1 0))
             (:z #f(0 0 1)) (:-z #f(0 0 -1)) (t #f(0 0 1))))))
(defun evp-target (j v)
  "v (deg / mm) clamped to the joint limits -> rad / m"
  (let ((mn (send j :min-angle)) (mx (send j :max-angle)))
    (if (< mn mx) (setq v (min mx (max mn v))))
    (* v (if (derivedp j linear-joint) 0.001 (/ pi 180.0)))))
(defun evp-joint-p (j) (or (derivedp j rotational-joint) (derivedp j linear-joint)))

(defun evp-body-weight (b)
  (if *evp-body-density*
      (let ((v (cond ((find-method b :volume) (abs (send b :volume)))
                     ((and (find-method b :vertices) (send b :vertices))
                      (let ((bb (make-bounding-box (send b :vertices))))
                        (* 0.5 (apply #'* (coerce (v- (send bb :maxpoint) (send bb :minpoint)) cons)))))
                     (t 0.0))))
        (if (evp-finite-p v) (max 1.0 (* *evp-body-density* v)) *evp-default-body-weight*))
    (let ((w (cond ((find-method b :weight) (send b :weight)) (t (get b :weight)))))
      (if (and (numberp w) (> w 0)) w *evp-default-body-weight*))))

(defun evp-finite-p (x)
  (cond ((numberp x) (and (= x x) (< (abs x) 1e30)))
        ((vectorp x) (every #'evp-finite-p x))
        ((arrayp x) (every #'evp-finite-p (array-entity x)))
        (t nil)))
(defun evp-body-centroid (b link-cds default)
  "volume centroid in the link frame, else default (also when it is not finite: some jskeus bodies)"
  (let ((v (if (find-method b :volume) (send b :volume) 0)) c)
    (if (and (numberp v) (evp-finite-p v) (> (abs v) 1e-3) (find-method b :centroid))
        (setq c (send link-cds :inverse-transform-vector (send b :centroid))))
    (if (and c (evp-finite-p c)) c default)))

(defun evp-body-shape (b link-cds)
  "(type size(mm) pos(mm, link frame) rot(link frame) weight(g) centroid(mm, link frame)) or nil"
  (let* ((bc (send b :copy-worldcoords))
         (rel (send (send link-cds :inverse-transformation) :transform bc))
         (csg (and (derivedp b body) (b . csg)))
         vv bb mn mx ctr)
    (cond
     ((and (derivedp b body) (assoc :revolution csg))
      (setq vv (mapcar #'(lambda (x) (send b :inverse-transform-vector x)) (cadr (assoc :revolution csg))))
      (setq bb (make-bounding-box vv) mn (send bb :minpoint) mx (send bb :maxpoint))
      (setq ctr (float-vector 0 0 (* 0.5 (+ (elt mn 2) (elt mx 2)))))
      (list :cylinder (float-vector (max 0.5 (elt mx 0)) (max 0.5 (- (elt mx 2) (elt mn 2))))
            (send rel :transform-vector ctr) (send rel :worldrot) (evp-body-weight b)
            (evp-body-centroid b link-cds (send rel :transform-vector ctr))))
     ((and (find-method b :vertices) (send b :vertices))
      (setq vv (mapcar #'(lambda (v) (send bc :inverse-transform-vector v)) (send b :vertices)))
      (setq bb (make-bounding-box vv) mn (send bb :minpoint) mx (send bb :maxpoint))
      (setq ctr (scale 0.5 (v+ mn mx)))
      (list :box (map float-vector #'(lambda (x) (max 0.5 x)) (v- mx mn))
            (send rel :transform-vector ctr) (send rel :worldrot)
            (evp-body-weight b) (evp-body-centroid b link-cds (send rel :transform-vector ctr))))
     (t nil))))

(defun evp-shape-inertia (s)
  (let* ((m (elt s 4)) (sz (elt s 1)) (r (elt s 3)) (i (make-matrix 3 3)))
    (case (car s)
      (:box
       (let ((x (elt sz 0)) (y (elt sz 1)) (z (elt sz 2)))
         (setf (aref i 0 0) (/ (* m (+ (* y y) (* z z))) 12.0))
         (setf (aref i 1 1) (/ (* m (+ (* x x) (* z z))) 12.0))
         (setf (aref i 2 2) (/ (* m (+ (* x x) (* y y))) 12.0))))
      (:cylinder
       (let ((rr (elt sz 0)) (h (elt sz 1)))
         (setf (aref i 0 0) (/ (* m (+ (* 3 rr rr) (* h h))) 12.0))
         (setf (aref i 1 1) (aref i 0 0))
         (setf (aref i 2 2) (/ (* m rr rr) 2.0)))))
    (m* (m* r i) (transpose r))))

(defun evp-parallel-axis (m d)
  (let ((i (make-matrix 3 3)) (dd (v. d d)))
    (dotimes (a 3)
      (dotimes (b 3)
        (setf (aref i a b) (* m (- (if (= a b) dd 0.0) (* (elt d a) (elt d b)))))))
    i))

(defun evp-link-physics (l)
  "(mass-g com-mm inertia-gmm2 shapes)"
  (let* ((lc (send l :copy-worldcoords))
         (shapes (remove nil (mapcar #'(lambda (b) (evp-body-shape b lc)) (send l :bodies))))
         (msum (apply #'+ (mapcar #'(lambda (s) (elt s 4)) shapes)))
         (lw (send l :weight))
         (mass (if (and (null *evp-body-density*) (numberp lw) (> lw 1.0)) lw (if (> msum 0) msum 1.0)))
         (com (if (> msum 0)
                  (scale (/ 1.0 msum) (reduce #'v+ (mapcar #'(lambda (s) (scale (elt s 4) (elt s 5))) shapes)))
                (float-vector 0 0 0)))
         inertia)
    (cond
     (shapes
      (setq inertia (make-matrix 3 3))
      (dolist (s shapes)
        (setq inertia (m+ inertia (m+ (evp-shape-inertia s) (evp-parallel-axis (elt s 4) (v- (elt s 2) com))))))
      (if (> msum 0) (setq inertia (scale-matrix (/ mass msum) inertia))))
     (t (setq inertia (scale-matrix (* mass 100.0) (unit-matrix 3)))))
    (unless (evp-finite-p mass) (setq mass 10.0))
    (unless (evp-finite-p com) (setq com (float-vector 0 0 0)))
    (unless (evp-finite-p inertia) (setq inertia (scale-matrix (* mass 100.0) (unit-matrix 3))))
    (list mass com inertia shapes)))

(defun evp-shape-corners (s)
  "corners (mm, link frame) of a box / the bounding box of a cylinder"
  (let* ((sz (elt s 1)) (c (make-coords :pos (elt s 2) :rot (elt s 3)))
         (h (if (eq (car s) :box) (scale 0.5 sz) (float-vector (elt sz 0) (elt sz 0) (* 0.5 (elt sz 1)))))
         (ret nil))
    (dolist (sx '(-1 1))
      (dolist (sy '(-1 1))
        (dolist (sz2 '(-1 1))
          (push (send c :transform-vector (float-vector (* sx (elt h 0)) (* sy (elt h 1)) (* sz2 (elt h 2)))) ret))))
    ret))

(defun evp-rot9 (m)
  (let ((v (instantiate float-vector 9)))
    (dotimes (i 3) (dotimes (j 3) (setf (elt v (+ (* 3 i) j)) (aref m i j))))
    v))

;;;
;;; simulation
;;;
(defclass evp-sim :super propertied-object
  :slots (sim robot links joints jidx nj targets dt time acc last-ms
              root-rel start-coords start-av poses jvals servo))

(defmethod evp-sim
  (:init
   (r)
   (let* ((ls (evp-sort-links (send r :links)))
          (jl (remove-if-not #'evp-joint-p (send r :joint-list)))
          (wsum (apply #'+ (mapcar #'(lambda (l) (let ((w (send l :weight))) (if (numberp w) w 0))) ls)))
          (*evp-body-density* (if (> wsum 100.0) nil (* 0.001 *evp-density*)))
          (lp nil) (minz 1e10) (dz 0) (mtotal 0.0)
          (w *evp-world*) (c *evp-contact*) (mo *evp-motor*))
     (setq robot r links ls dt (evp-cdr :dt w) time 0.0 acc 0.0 servo t)
     (setq start-coords (send r :copy-worldcoords) start-av (copy-seq (send r :angle-vector)))
     (send r :worldcoords)
     (setq lp (mapcar #'evp-link-physics links))
     ;; put it on the floor
     (dotimes (i (length links))
       (let ((lc (send (elt links i) :worldcoords)))
         (dolist (s (elt (elt lp i) 3))
           (dolist (v (evp-shape-corners s))
             (setq minz (min minz (elt (send lc :transform-vector v) 2)))))))
     (when (< minz 1e9) (setq dz (- 1.0 minz)))
     (send r :translate (float-vector 0 0 dz) :world)
     (send r :worldcoords)
     (setq root-rel (send (send r :worldcoords) :transformation (send (car links) :worldcoords)))
     (setq sim (evp-create (evp-cdr :gravity w) (evp-cdr :erp w) (evp-cdr :cfm w)
                           (evp-cdr :mu c) (evp-cdr :soft-erp c) (evp-cdr :soft-cfm c) (evp-cdr :bounce c)
                           (evp-cdr :iterations w)))
     (evp-set-options sim (evp-cdr :quickstep w) (evp-cdr :max-contacts c) (evp-cdr :bounce-vel c))
     ;; links
     (dotimes (i (length links))
       (let* ((l (elt links i)) (p (elt lp i)) (lc (send l :worldcoords)) (it (elt p 2))
              (li (evp-add-link sim (* 0.001 (elt p 0)) (scale 0.001 (elt p 1))
                                (scale 1e-9 (float-vector (aref it 0 0) (aref it 0 1) (aref it 0 2)
                                                          (aref it 1 1) (aref it 1 2) (aref it 2 2)))
                                (scale 0.001 (send lc :worldpos)) (evp-rot9 (send lc :worldrot)))))
         (setq mtotal (+ mtotal (elt p 0)))
         (dolist (s (elt p 3))
           (case (car s)
             (:box (evp-add-box sim li (scale 0.001 (elt s 1)) (scale 0.001 (elt s 2)) (evp-rot9 (elt s 3))))
             (:cylinder (evp-add-cylinder sim li (* 0.001 (elt (elt s 1) 0)) (* 0.001 (elt (elt s 1) 1))
                                          (scale 0.001 (elt s 2)) (evp-rot9 (elt s 3))))))))
     ;; joints (then fixed hinges for the links without a joint)
     (setq joints nil jidx nil)
     (dolist (j jl)
       (let* ((ch (send j :child-link)) (ci (position ch links))
              (pa (and ci (evp-link-parent ch links))) (pidx (if pa (position pa links) -1))
              (lin (derivedp j linear-joint)) (sc (if lin 0.001 (/ pi 180.0)))
              (lc (send ch :worldcoords)) k mn mx)
         (when ci
           (setq k (evp-add-joint sim pidx ci (if lin 1 0) (scale 0.001 (send lc :worldpos))
                                  (normalize-vector (send lc :rotate-vector (evp-axis-vector (j . axis))))
                                  0.0 0.0 (evp-cdr :fmax mo) (evp-cdr :vmax mo) (evp-cdr :kp mo)))
           (setq mn (max -1e6 (send j :min-angle)) mx (min 1e6 (send j :max-angle)))
           ;; the stops are 1 deg (1 mm) outside the joint limits and the targets are clamped to the
           ;; limits: a servo (fmax 500000) pushing into a stop blows up light links (h7 fingers)
           ;; (and include the start angle when it is outside the limits, e.g. h7 fingers at 0)
           (let ((q (send j :joint-angle)))
             (evp-set-joint-offset sim k (* sc q) (* sc (- (min mn q) 1.0)) (* sc (+ (max mx q) 1.0))))
           (if (substringp "wheel" (string-downcase (string (send ch :name))))
               (evp-set-joint-mode sim k 1))
           (push j joints) (push k jidx))))
     (setq joints (nreverse joints) jidx (nreverse jidx))
     (setq nj (length joints))
     (dotimes (i (length links))
       (let ((l (elt links i)))
         (when (and (> i 0) (not (find l joints :key #'(lambda (j) (send j :child-link)))))
           (let* ((pa (evp-link-parent l links)) (lc (send l :worldcoords))
                  (k (evp-add-joint sim (if pa (position pa links) -1) i 0 (scale 0.001 (send lc :worldpos))
                                    #f(0 0 1) 0.0 0.0 (evp-cdr :fmax mo) (evp-cdr :vmax mo) (evp-cdr :kp mo))))
             (evp-set-joint-offset sim k 0.0 -1e-4 1e-4)
             (incf nj)))))
     (setq targets (instantiate float-vector (max 1 nj)))
     (setq poses (instantiate float-vector (* 12 (length links))))
     (setq jvals (instantiate float-vector (max 1 nj)))
     (send self :set-targets-from-robot)
     (setq last-ms nil)
     (format t ";; eusview-physics: ~A: ~A links ~A joints, ~6,3f kg~A, lifted ~5,1f mm~%"
             (send r :name) (length links) (length joints) (* 0.001 mtotal)
             (if *evp-body-density* (format nil " (estimated ~A g/cm^3)" *evp-density*) "") dz)
     self))
  (:robot () robot)
  (:time () time)
  (:contacts () (evp-contacts sim))
  (:servo () servo)
  (:set-servo
   (on)
   ;; off: odesim keeps 1 % of fmax as friction -> with fmax *evp-free-fmax* the joints are free
   (setq servo on)
   (dotimes (k nj) (evp-set-fmax sim k (if on (evp-cdr :fmax *evp-motor*) *evp-free-fmax*)))
   (evp-set-servo sim (if on 1 0))
   servo)
  (:set-target-joint
   (j v)
   (let ((k (position j joints)))
     (when k
       (setf (elt targets k) (evp-target j v))
       (evp-set-targets-c sim targets nj))))
  (:set-targets-from-robot
   ()
   (dotimes (k (length joints))
     (let ((j (elt joints k)))
       (setf (elt targets k) (evp-target j (send j :joint-angle)))))
   (evp-set-targets-c sim targets nj))
  (:set-targets-av
   (av)
   "av: robot angle-vector order (all joints of :joint-list)"
   (let ((jl (send robot :joint-list)))
     (dotimes (k (length joints))
       (let* ((j (elt joints k)) (i (position j jl)))
         (when (and i (< i (length av)))
           (setf (elt targets k) (evp-target j (elt av i)))))))
   (evp-set-targets-c sim targets nj))
  (:step
   (n)
   (when (> n 0)
     (let ((ret (evp-step-safe sim dt n (length links))))
       (setq time (+ time (* dt (if (< ret 0) (- -1 ret) ret))))
       (if (< ret 0) (error "the simulation blew up (a link is not finite or 100 m away)")))))
  (:advance
   (&optional (max-sec 0.1))
   "advance by the real time since the last call (at most max-sec, slower than real time if late)"
   (let ((now (evp-now-ms)) n)
     (if last-ms (setq acc (+ acc (min max-sec (/ (- now last-ms) 1000.0)))))
     (setq last-ms now)
     (setq n (floor (/ acc dt)))
     (when (> n 0) (send self :step n) (setq acc (- acc (* n dt))))
     n))
  (:update-robot
   ()
   "joint angles and root coords of the robot from the simulation"
   (let (rc)
     (evp-joint-values sim nj jvals)
     (dotimes (k (length joints))
       (let* ((j (elt joints k)) (lin (derivedp j linear-joint))
              (v (* (elt jvals k) (if lin 1000.0 (/ 180.0 pi)))))
         (send j :joint-angle (min (send j :max-angle) (max (send j :min-angle) v)))))
     (evp-link-poses sim 1 poses)
     (setq rc (make-coords :pos (scale 1000.0 (subseq poses 0 3))
                           :rot (let ((m (make-matrix 3 3)))
                                  (dotimes (i 3) (dotimes (j 3) (setf (aref m i j) (elt poses (+ 3 (* 3 i) j)))))
                                  m)))
     (send robot :newcoords (send rc :transform (send root-rel :inverse-transformation)))
     (send robot :worldcoords)
     robot))
  (:root-pos () (send (car links) :worldpos))
  (:destroy
   ()
   (when sim (evp-destroy sim) (setq sim nil))
   (send robot :angle-vector start-av)
   (send robot :newcoords start-coords)
   (send robot :worldcoords)))

(defun evp-start (r)
  (evp-stop)
  (evp-load)
  (setq *evp* (instance evp-sim :init r))
  t)
(defun evp-stop ()
  (when *evp* (send *evp* :destroy) (setq *evp* nil)))

(provide :eusview-physics)
