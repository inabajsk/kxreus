;;;
;;; eusview-qp.l : GMR + whole-body QP for eusview-bvh.l (self-collision, joint limits, COM in the support polygon)
;;;	2026.10.5
;;;
;;;  The whole-body QP of the EusView app (eusview/bvh/QP.md; C++ eusview-ode/wbqp.{h,cpp}, copies of
;;;  eusview/ios/EusView/QP/) built into the same $ARCHDIR/lib/libeusviewode.so as the physics
;;;  ("make eusview-ode") and called by defforeign (eusviewqp_* of eusview-ode/eusviewode.cpp).
;;;  The reference is the kxreus GMR (eusview-retarget.l :gmr); every frame the QP changes it to
;;;  no self-collision, joints inside the limits (with a margin), the COM above the support polygon of the
;;;  feet on the floor, and the feet on the floor kept still.
;;;  The QP model is made from the EusLisp robot (like eusview-physics.l):
;;;   links: (send r :links) parents first, rest = coords of the link in its parent at the zero pose
;;;   joints: rotational / linear joints of :joint-list (axis in the child link frame, limits :min-angle / :max-angle)
;;;   mass / com: evp-link-physics (link :weight, or volume x 1 g/cm^3 for robots without weights)
;;;   collision capsules: made by wbqp from the vertices of the bodies of each link
;;;   hands: the parent link of :larm / :rarm :end-coords, feet (soles): the parent link of :lleg / :rleg :end-coords
;;;   pairs not checked: the pairs touching at the zero pose and the reset pose
;;;  Units of the C side: m, rad, kg; poses are 12 doubles (x y z, rotation row major) of the root link.
;;;
;;;   (setq q (instance eusview-qp :init robot :fps 30))
;;;   (send q :solve-robot gmr-robot :out qp-robot)   ;; one frame (the GMR robot -> the QP robot)
;;;   (send q :eval-robot robot)                       ;; (ev flags polygon) violations of a pose
;;;   (eusview-qp-show robot q ev flags poly)          ;; links red (collision) / orange (limit), COM, support polygon
;;;

(require :eusview-physics)

(defvar *evq-loaded* nil)
(defun evq-load ()
  (unless *evq-loaded*
    (evp-load)
    (let ((m *evp-lib*))
      (defforeign evq-create m "eusviewqp_create" () :integer)
      (defforeign evq-destroy m "eusviewqp_destroy" (:integer) :integer)
      (defforeign evq-add-link m "eusviewqp_add_link" (:integer :integer :string) :integer)
      (defforeign evq-add-link-vertices m "eusviewqp_add_link_vertices" (:integer :integer :string :integer) :integer)
      (defforeign evq-set-link-mass m "eusviewqp_set_link_mass" (:integer :integer :float :string) :integer)
      (defforeign evq-add-joint m "eusviewqp_add_joint" (:integer :integer :integer :string :float :float :float) :integer)
      (defforeign evq-set-hand m "eusviewqp_set_hand" (:integer :integer :integer :string) :integer)
      (defforeign evq-set-foot m "eusviewqp_set_foot" (:integer :integer :integer) :integer)
      (defforeign evq-set-param m "eusviewqp_set_param" (:integer :string :float) :integer)
      (defforeign evq-get-param m "eusviewqp_get_param" (:integer :string) :float)
      (defforeign evq-finalize m "eusviewqp_finalize" (:integer :string :integer) :integer)
      (defforeign evq-info m "eusviewqp_info" (:integer :string) :integer)
      (defforeign evq-eval m "eusviewqp_eval" (:integer :string :string :integer :string :string :string :integer) :integer)
      (defforeign evq-reset m "eusviewqp_reset" (:integer) :integer)
      (defforeign evq-solve m "eusviewqp_solve" (:integer :string :string :integer :integer :string :string :string) :integer)
      (defforeign evq-contact-of m "eusviewqp_contact_of" (:integer :string :string :integer) :integer)
      (defforeign evq-plan-contacts m "eusviewqp_plan_contacts" (:integer :integer :string :string :string :string) :integer))
    (setq *evq-loaded* t))
  *evq-loaded*)

(defun evq-pose12 (c &optional (v (instantiate float-vector 12)))
  "coords (mm) -> 12 doubles (m, rotation row major)"
  (let ((p (send c :worldpos)) (r (send c :worldrot)))
    (dotimes (i 3) (setf (elt v i) (* 0.001 (elt p i))))
    (dotimes (i 3) (dotimes (j 3) (setf (elt v (+ 3 (* 3 i) j)) (aref r i j))))
    v))
(defun evq-coords (v &optional (off 0))
  "12 doubles (m) -> coords (mm)"
  (let ((m (make-matrix 3 3)))
    (dotimes (i 3) (dotimes (j 3) (setf (aref m i j) (elt v (+ off 3 (* 3 i) j)))))
    (make-coords :pos (float-vector (* 1000.0 (elt v off)) (* 1000.0 (elt v (+ off 1))) (* 1000.0 (elt v (+ off 2))))
                 :rot m)))

;;; WbqpEval (14 doubles at off) accessors
(defun evq-ev-min-dist (ev &optional (o 0)) (elt ev o))
(defun evq-ev-collide (ev &optional (o 0)) (round (elt ev (+ o 3))))
(defun evq-ev-at-limit (ev &optional (o 0)) (round (elt ev (+ o 5))))
(defun evq-ev-com (ev &optional (o 0)) (float-vector (* 1000 (elt ev (+ o 7))) (* 1000 (elt ev (+ o 8))) (* 1000 (elt ev (+ o 9)))))
(defun evq-ev-com-margin (ev &optional (o 0)) (elt ev (+ o 10)))   ;; m, NaN: no foot on the floor
(defun evq-nan-p (x) (not (= x x)))

(defclass eusview-qp :super propertied-object
  :slots (h robot links lpos nl joints jpos jlin nj root-pos root-rel
            qref rref qo ro diag ev flags poly prev))

(defmethod eusview-qp
  (:init
   (r &key (fps 30.0) (params nil))
   "r: the robot (its pose is kept). fps: frames per second of the motion (speed limits)"
   (evq-load)
   (let* ((av-save (copy-seq (send r :angle-vector))) (c-save (send r :copy-worldcoords))
          (all (send r :links))
          (wsum (apply #'+ (mapcar #'(lambda (l) (let ((w (send l :weight))) (if (numberp w) w 0))) all)))
          (*evp-body-density* (if (> wsum 100.0) nil (* 0.001 *evp-density*)))
          (jl (send r :joint-list)) reset)
     (setq robot r h (evq-create))
     (send r :angle-vector (instantiate float-vector (length av-save)))
     (send r :newcoords (make-coords))
     (send r :worldcoords)
     (setq links (evp-sort-links all) nl (length links))
     (setq lpos (mapcar #'(lambda (l) (position l all)) links))
     ;; links: rest = coords in the parent link at the zero pose, vertices (m, link frame), mass and com
     (dotimes (i nl)
       (let* ((l (elt links i)) (p (evp-link-parent l links)) (lc (send l :copy-worldcoords))
              (rest (if p (send (send p :copy-worldcoords) :transformation lc) lc))
              (vs nil) phys)
         (evq-add-link h (if p (position p links) -1) (evq-pose12 rest))
         (dolist (b (send l :bodies))
           (send b :worldcoords)   ;; the vertices of the bodies are updated by their own :worldcoords
           (when (and (find-method b :vertices) (send b :vertices))
             (dolist (v (send b :vertices)) (push (scale 0.001 (send lc :inverse-transform-vector v)) vs))))
         (when (>= (length vs) 3)
           (evq-add-link-vertices h i (apply #'concatenate float-vector vs) (length vs)))
         (setq phys (evp-link-physics l))
         (if (and (> (elt phys 0) 0) (evp-finite-p (elt phys 1)))
             (evq-set-link-mass h i (* 0.001 (elt phys 0)) (scale 0.001 (elt phys 1))))))
     ;; joints (rotational / linear) in the :joint-list order
     (setq joints (remove-if-not #'(lambda (j) (and (evp-joint-p j) (memq (send j :child-link) links))) jl))
     (setq jpos (mapcar #'(lambda (j) (position j jl)) joints) nj (length joints))
     (setq jlin (mapcar #'(lambda (j) (derivedp j linear-joint)) joints))
     (dolist (j joints)
       (let* ((lin (derivedp j linear-joint)) (s (if lin 0.001 (/ pi 180.0)))
              (mn (send j :min-angle)) (mx (send j :max-angle)))
         (if (or (not (evp-finite-p mn)) (< mn -1e5)) (setq mn (if lin -1000 -180)))
         (if (or (not (evp-finite-p mx)) (> mx 1e5)) (setq mx (if lin 1000 180)))
         (evq-add-joint h (position (send j :child-link) links) (if lin 1 0) (evp-axis-vector (j . axis))
                        (* s mn) (* s mx) 0.0)))
     ;; hands and feet (soles)
     (dolist (e '((0 :larm) (1 :rarm)))
       (when (send r (cadr e))
         (let* ((ec (send r (cadr e) :end-coords)) (l (send ec :parent)))
           (when (memq l links)
             (evq-set-hand h (car e) (position l links)
                           (scale 0.001 (send (send l :worldcoords) :inverse-transform-vector (send ec :worldpos))))))))
     (dolist (e '((0 :lleg) (1 :rleg)))
       (when (send r (cadr e))
         (let ((l (send (send r (cadr e) :end-coords) :parent)))
           (if (memq l links) (evq-set-foot h (car e) (position l links))))))
     (evq-set-param h "dt" (/ 1.0 (max fps 1.0)))
     (dolist (p params) (evq-set-param h (string-downcase (string (car p))) (float (cdr p))))
     ;; root link of the QP and the robot coords
     (setq root-pos (car lpos))
     (setq root-rel (send (send r :copy-worldcoords) :transformation (send (car links) :copy-worldcoords)))
     ;; pairs touching at the reset pose are not checked
     (send r :reset-pose)
     (setq reset (send self :q-of r))
     (evq-finalize h reset 1)
     (send self :put :scale (evq-get-param h "scale"))   ;; leg length (m)
     (send r :angle-vector av-save)
     (send r :newcoords c-save)
     (send r :worldcoords)
     (setq qref (instantiate float-vector (max 1 nj)) qo (instantiate float-vector (max 1 nj))
           rref (instantiate float-vector 12) ro (instantiate float-vector 12)
           diag (instantiate float-vector 37) ev (instantiate float-vector 14)
           flags (instantiate float-vector (max 1 nl)) poly (instantiate float-vector 64) prev 0)
     self))
  (:destroy () (when h (evq-destroy h) (setq h nil)))
  (:robot () robot)
  (:links () links)
  (:link-positions () lpos)
  (:diag () diag)
  (:param (name) (evq-get-param h name))
  (:set-param (name v) (evq-set-param h name (float v)))
  (:info ()
   "(links joints capsules pairs total-mass-kg scale-m)"
   (let ((v (instantiate float-vector 6))) (evq-info h v) (coerce v cons)))
  (:reset () (setq prev 0) (evq-reset h))
  (:q-of
   (r &optional (v (instantiate float-vector (max 1 nj))))
   "joint angles of r (the same model as the QP robot) in rad / m"
   (let ((jl (send r :joint-list)))
     (dotimes (k nj)
       (setf (elt v k) (* (send (elt jl (elt jpos k)) :joint-angle) (if (elt jlin k) 0.001 (/ pi 180.0))))))
   v)
  (:root-of
   (r &optional (v (instantiate float-vector 12)))
   (evq-pose12 (send (elt (send r :links) root-pos) :worldcoords) v))
  (:apply
   (r q root &key (offset nil))
   "set r to the joint angles q (rad / m) and the root link pose root (12), moved by offset (mm)"
   (let ((jl (send r :joint-list)) rc)
     (dotimes (k nj)
       (send (elt jl (elt jpos k)) :joint-angle (* (elt q k) (if (elt jlin k) 1000.0 (/ 180.0 pi)))))
     (setq rc (evq-coords root))
     (if offset (send rc :translate offset :world))
     (send r :newcoords (send rc :transform (send root-rel :inverse-transformation)))
     (send r :worldcoords)
     r))
  (:contact-of
   (r)
   "feet on the floor of the pose of r (bit0 left, bit1 right, with hysteresis)"
   (setq prev (evq-contact-of h (send self :q-of r qref) (send self :root-of r rref) prev)))
  (:answer () "(q-out root-out) of the last solve (rad / m)" (list qo ro))
  (:solve
   (q root contact support)
   "one frame from the previous answer; returns (status q-out root-out diag)"
   (let ((s (evq-solve h q root contact support qo ro diag)))
     (list s qo ro diag)))
  (:solve-robot
   (ref &key out offset (contact nil))
   "the pose of the robot ref (GMR) -> the QP answer set to out (offset mm). contact: nil = from the feet heights"
   (let ((c (or contact (send self :contact-of ref))) s)
     (send self :q-of ref qref) (send self :root-of ref rref)
     (setq s (evq-solve h qref rref c c qo ro diag))
     (if out (send self :apply out qo ro :offset offset))
     s))
  (:eval
   (q root support)
   "(ev flags polygon) without changing the state. polygon: list of #f(x y) (mm)"
   (let ((n (evq-eval h q root support ev flags poly 32)) (pl nil))
     (dotimes (i (min n 32)) (push (float-vector (* 1000 (elt poly (* 2 i))) (* 1000 (elt poly (1+ (* 2 i))))) pl))
     (list ev flags (nreverse pl))))
  (:eval-robot
   (r &optional (support -1))
   (send self :eval (send self :q-of r (instantiate float-vector (max 1 nj))) (send self :root-of r) support))
  (:plan-contacts
   (qs roots)
   "qs, roots: lists of float-vectors (n frames) -> (contacts supports) with the preview of the support feet"
   (let* ((n (length qs)) (c (instantiate float-vector n)) (s (instantiate float-vector n)))
     (evq-plan-contacts h n (apply #'concatenate float-vector qs) (apply #'concatenate float-vector roots) c s)
     (list (map cons #'round c) (map cons #'round s))))
  )

;;;
;;; violations in irtviewer: link colors (red: collision, orange: at a joint limit),
;;; COM (ball cross and its projection on the floor) and the support polygon (green: inside, red: outside)
;;;
(defvar *eusview-qp-marks* nil) ;; ((com-mm polygon-mm ok size) ...) drawn by eusview-qp-draw-marks
(defvar *eusview-qp-red* (float-vector 0.95 0.1 0.1))
(defvar *eusview-qp-orange* (float-vector 1.0 0.5 0.0))

(defun eusview-qp-tint-body (b tint)
  "tint: nil (own color), :collide, :limit. the color is changed only when the tint changes"
  (unless (eq (get b :eusview-qp-tint) tint)
    (unless (get b :eusview-qp-color0) (setf (get b :eusview-qp-color0) (or (get b :face-color) :none)))
    (setf (get b :eusview-qp-tint) tint)
    (let ((c0 (get b :eusview-qp-color0)))
      (send b :set-color (case tint (:collide *eusview-qp-red*) (:limit *eusview-qp-orange*)
                           (t (if (eq c0 :none) nil c0)))))))

(defun eusview-qp-show (r qp ev flags poly &key (offset nil))
  "colors of the links of r (an instance of the QP model) and a mark (COM, support polygon) for the next draw.
   ev flags poly: of (send qp :eval ...), in the coordinates of the QP; offset (mm): where r is drawn"
  (let ((ls (send r :links)) (lp (send qp :link-positions)) com m pl)
    (dotimes (i (length lp))
      (let* ((f (round (elt flags i))) (l (elt ls (elt lp i)))
             (tint (cond ((/= 0 (logand f 1)) :collide) ((/= 0 (logand f 2)) :limit) (t nil))))
        (dolist (b (send l :bodies)) (eusview-qp-tint-body b tint))))
    (setq com (evq-ev-com ev) m (evq-ev-com-margin ev))
    (if offset (setq com (v+ com offset)))
    (setq pl (mapcar #'(lambda (p) (if offset (float-vector (+ (elt p 0) (elt offset 0)) (+ (elt p 1) (elt offset 1))) p)) poly))
    (push (list com pl (or (evq-nan-p m) (>= m 0)) (* 1000 (or (send qp :get :scale) 0.2))) *eusview-qp-marks*)))

(defun eusview-qp-clear (&optional robots)
  "forget the marks and give the bodies of robots their own colors"
  (setq *eusview-qp-marks* nil)
  (dolist (r robots)
    (dolist (b (send r :bodies)) (if (get b :eusview-qp-tint) (eusview-qp-tint-body b nil)))))

(defun eusview-qp-draw-marks (&rest args)
  "draw *eusview-qp-marks* with OpenGL after the objects (eusview-viewer :draw-objects, before the flush)"
  (when *eusview-qp-marks*
    (gl::glDisable gl::GL_LIGHTING)
    (gl::glEnable gl::GL_BLEND)
    (gl::glBlendFunc gl::GL_SRC_ALPHA gl::GL_ONE_MINUS_SRC_ALPHA)
    (dolist (mk *eusview-qp-marks*)
      (let* ((com (elt mk 0)) (pl (elt mk 1)) (ok (elt mk 2)) (sz (elt mk 3))
             (col (if ok (float-vector 0.2 0.78 0.35) (float-vector 1.0 0.23 0.19)))
             (r (* 0.06 sz)) (z 1.0))
        ;; support polygon: filled (translucent) and its outline
        (when (>= (length pl) 3)
          (gl::glColor4fv (concatenate float-vector col #f(0.45)))
          (gl::glBegin gl::GL_POLYGON)
          (dolist (p pl) (gl::glVertex3fv (float-vector (elt p 0) (elt p 1) z)))
          (gl::glEnd gl::GL_POLYGON)
          (gl::glLineWidth 2.0)
          (gl::glColor3fv col)
          (gl::glBegin gl::GL_LINE_LOOP)
          (dolist (p pl) (gl::glVertex3fv (float-vector (elt p 0) (elt p 1) (+ z 0.5))))
          (gl::glEnd gl::GL_LINE_LOOP))
        ;; COM: a disk on the floor, a line down to it and a cross at the COM (seen through the body)
        (gl::glColor3fv col)
        (gl::glBegin gl::GL_POLYGON)
        (dotimes (k 16)
          (let ((a (/ (* 2 pi k) 16)))
            (gl::glVertex3fv (float-vector (+ (elt com 0) (* 0.6 r (cos a))) (+ (elt com 1) (* 0.6 r (sin a))) (+ z 1.0)))))
        (gl::glEnd gl::GL_POLYGON)
        (gl::glDisable gl::GL_DEPTH_TEST)
        (gl::glLineWidth 3.0)
        (gl::glBegin gl::GL_LINES)
        (gl::glVertex3fv com) (gl::glVertex3fv (float-vector (elt com 0) (elt com 1) z))
        (dotimes (a 3)
          (let ((d (instantiate float-vector 3))) (setf (elt d a) r)
            (gl::glVertex3fv (v- com d)) (gl::glVertex3fv (v+ com d))))
        (gl::glEnd gl::GL_LINES)
        (gl::glEnable gl::GL_DEPTH_TEST)))
    (gl::glLineWidth 1.0)
    (gl::glDisable gl::GL_BLEND)
    (gl::glEnable gl::GL_LIGHTING)))

(defun eusview-qp-describe (ev)
  "short text of the violations of one robot"
  (let ((m (evq-ev-com-margin ev)))
    (format nil "~A~A~A"
            (if (> (evq-ev-collide ev) 0)
                (format nil (if (eusview-ja-p) "衝突 ~A (~A mm)" "collide ~A (~A mm)") (evq-ev-collide ev) (round (* 1000 (evq-ev-min-dist ev))))
              (format nil (if (eusview-ja-p) "衝突なし (~A mm)" "no collision (~A mm)") (round (* 1000 (min 9.999 (evq-ev-min-dist ev))))))
            (if (> (evq-ev-at-limit ev) 0) (format nil (if (eusview-ja-p) "・範囲の端 ~A" ", at limit ~A") (evq-ev-at-limit ev)) "")
            (cond ((evq-nan-p m) (if (eusview-ja-p) "・足が浮く" ", feet off"))
                  ((< m 0) (format nil (if (eusview-ja-p) "・重心 外 ~A mm" ", COM out ~A mm") (round (* -1000 m))))
                  (t (format nil (if (eusview-ja-p) "・重心 ~A mm" ", COM ~A mm") (round (* 1000 m))))))))

(provide :eusview-qp)
