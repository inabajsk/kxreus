;;;
;;; eus2physics.l : physical parameters of a robot for the ODE simulation in EusView
;;;                 (JSON member "physics" added by eus2json :extra)
;;;
;;; Follows ~/prog/rcb4eus/odedyna.l (robot2drobot, ode-module, motor-module) as used by
;;; kxrdyna.l (kxr-dyna -> dyna-on -> d-init :max-contacts 1 :cmu 0.1, :soft-setting):
;;;  - collision: one box per body of a link = bounding box of the body's vertices in the
;;;    body's own frame (make-model-obb-cube body (list body) :thr -1 :grow 0);
;;;    bodies made by revolution (csg :revolution) become cylinders (revolution2cylinder).
;;;    All boxes of a link are fused into one ODE body (d-assoc). No self collision.
;;;  - mass: each box has the weight of its body (g -> kg, nil -> 10 g) as a uniform box.
;;;    Here: mass = link :weight (g) (= sum of the bodies' weights for kxreus),
;;;    com = weighted volume centroids of the bodies (link frame),
;;;    inertia = sum of the uniform boxes (= what ODE gets in odedyna) about the com.
;;;    (kxreus link :centroid / :inertia-tensor are not in the final link frame -> not used)
;;;  - servo: every dt, Vel = kp * (target - angle) [rad/s], FMax = fmax (dJointSetHingeParam)
;;;    target: angle command linearly interpolated over the command time (djoint :angle).
;;;
;;; usage: (load "eusview/eus2physics.l")
;;;        (eus2json r fname :extra (list (cons "physics" (eus2physics r))))
;;;

;;; odedyna.l values (kxr-dyna)
(defvar *e2p-world*
  '((:gravity . #f(0 0 -9.81)) (:dt . 0.01) (:erp . 0.2) (:cfm . 0.01)
    (:quickstep . nil) (:iterations . 30)))
(defvar *e2p-contact*
  '((:mu . 0.8) (:soft-erp . 0.2) (:soft-cfm . 0.001) (:bounce . 0.01) (:bounce-vel . 1.0)
    (:max-contacts . 4)))  ; kxr-dyna は mu 0.1 / 1 点だが, 立っているだけで滑るので 0.8 / 4 点にした
(defvar *e2p-odedyna-motor* '((:kp . 10.0) (:fmax . 500000.0)))
;;; KRS-3304R2 ICS (KXR standard servo), catalog values (公称): 13.9 kgf cm, 0.13 s/60deg @11.1V
(defvar *e2p-servo*
  (list (cons :fmax (* 13.9 0.0980665)) (cons :vmax (/ (/ pi 3) 0.13))
        (cons :kp 10.0) (cons :damping 0.0)))
(defvar *e2p-default-body-weight* 10.0) ;; g (odedyna :init-primitive)

(defun e2p-cdr (key alist) (cdr (assoc key alist)))

(defvar *e2p-density* nil) ;; g/mm^3: estimate the weights from the volumes (robots without :weight)

(defun e2p-body-weight (b)
  (if *e2p-density*
      (let ((v (cond ((find-method b :volume) (abs (send b :volume)))
                     ((and (find-method b :vertices) (send b :vertices)) ;; faceset: half the box
                      (let ((bb (make-bounding-box (send b :vertices))))
                        (* 0.5 (apply #'* (coerce (v- (send bb :maxpoint) (send bb :minpoint)) cons)))))
                     (t 0.0))))
        (max 1.0 (* *e2p-density* v)))
    (let ((w (cond ((find-method b :weight) (send b :weight))
                   (t (get b :weight)))))
      (if (and (numberp w) (> w 0)) w *e2p-default-body-weight*))))

(defun e2p-body-centroid (b link-cds default)
  "volume centroid of the body in the link frame (mm), else default"
  (let ((v (if (find-method b :volume) (send b :volume) 0)))
    (if (and (numberp v) (> (abs v) 1e-3) (find-method b :centroid))
        (send link-cds :inverse-transform-vector (send b :centroid))
      default)))

(defun e2p-body-shape (b link-cds)
  "(type size(mm) pos(mm, link frame) rot(link frame) weight(g) centroid(mm, link frame)) or nil"
  (let* ((bc (send b :copy-worldcoords))
         (rel (send (send link-cds :inverse-transformation) :transform bc))
         (csg (and (derivedp b body) (b . csg)))
         vv bb mn mx ctr)
    (cond
     ((and (derivedp b body) (assoc :revolution csg))
      ;; revolution2cylinder: radius = max x of the profile, length = z range, axis = body z
      (setq vv (mapcar #'(lambda (x) (send b :inverse-transform-vector x))
                       (cadr (assoc :revolution csg))))
      (setq bb (make-bounding-box vv) mn (send bb :minpoint) mx (send bb :maxpoint))
      (setq ctr (float-vector 0 0 (* 0.5 (+ (elt mn 2) (elt mx 2)))))
      (list :cylinder (float-vector (elt mx 0) (- (elt mx 2) (elt mn 2)))
            (send rel :transform-vector ctr) (send rel :worldrot) (e2p-body-weight b)
            (e2p-body-centroid b link-cds (send rel :transform-vector ctr))))
     ((and (find-method b :vertices) (send b :vertices)) ;; body or faceset (jskeus models)
      (setq vv (mapcar #'(lambda (v) (send bc :inverse-transform-vector v)) (send b :vertices)))
      (setq bb (make-bounding-box vv) mn (send bb :minpoint) mx (send bb :maxpoint))
      (setq ctr (scale 0.5 (v+ mn mx)))
      (list :box (v- mx mn) (send rel :transform-vector ctr) (send rel :worldrot)
            (e2p-body-weight b) (e2p-body-centroid b link-cds (send rel :transform-vector ctr))))
     (t nil))))

(defun e2p-shape-inertia (s)
  "inertia (g mm^2) of a uniform shape about its center, in the link frame"
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

(defun e2p-parallel-axis (m d)
  "m (|d|^2 E - d d^T)"
  (let ((i (make-matrix 3 3)) (dd (v. d d)))
    (dotimes (a 3)
      (dotimes (b 3)
        (setf (aref i a b) (* m (- (if (= a b) dd 0.0) (* (elt d a) (elt d b)))))))
    i))

(defun e2p-default-inertia-p (it)
  (or (null it) (< (norm (array-entity (m- it (unit-matrix 3)))) 1e-9)))

(defun e2p-link-physics (l &key use-link-inertia)
  "returns (mass-g com-mm inertia-gmm2 shapes info box-mass-sum link-centroid)
mass: link :weight (g) when set (> 1 g), else the sum of the bodies' weights;
com: weighted volume centroids of the bodies (link frame);
inertia: uniform boxes of the bodies (odedyna) about com, scaled to mass.
The kxreus links' :centroid / :inertia-tensor are not in the final link frame
(e.g. head-neck-p centroid 12 cm off), so they are not used unless use-link-inertia."
  (let* ((lc (send l :copy-worldcoords))
         (shapes (remove nil (mapcar #'(lambda (b) (e2p-body-shape b lc)) (send l :bodies))))
         (msum (apply #'+ (mapcar #'(lambda (s) (elt s 4)) shapes)))
         (lw (send l :weight))
         (mass (if (and (null *e2p-density*) (numberp lw) (> lw 1.0)) lw (if (> msum 0) msum 1.0)))
         (link-com (send l :inverse-transform-vector (send l :centroid)))
         (com (if (> msum 0)
                  (scale (/ 1.0 msum)
                         (reduce #'v+ (mapcar #'(lambda (s) (scale (elt s 4) (elt s 5))) shapes)))
                link-com))
         (it (send l :inertia-tensor))
         inertia info)
    (cond
     ((and use-link-inertia (not (e2p-default-inertia-p it)))
      (setq inertia it info :link-inertia com link-com))
     (shapes
      (setq inertia (make-matrix 3 3))
      (dolist (s shapes)
        (setq inertia (m+ inertia (m+ (e2p-shape-inertia s)
                                      (e2p-parallel-axis (elt s 4) (v- (elt s 2) com))))))
      ;; scale to the link mass if the boxes' sum differs
      (if (> msum 0) (setq inertia (scale-matrix (/ mass msum) inertia)))
      (setq info :boxes))
     (t
      (setq inertia (scale-matrix (* mass 100.0) (unit-matrix 3)) info :none)))
    (list mass com inertia shapes info msum link-com)))

(defun e2p-joint-motor (j &optional rotation-joints)
  "odedyna: :rotation when the child body name contains \"wheel\"; also the joints given
(export-motions.l: servos in rcb4-interface :wheel-sids / :rotate-sids)"
  (if (or (memq j rotation-joints)
          (substringp "wheel" (string-downcase (string (send (send j :child-link) :name)))))
      "rotation" "servo"))

(defun e2p-min-z (r links shapes-list)
  "min z (mm) of the collision shapes and of all body vertices at the current pose"
  (let ((zs 1e10) (zm 1e10))
    (dotimes (i (length links))
      (let ((lc (send (elt links i) :worldcoords)))
        (dolist (s (elt shapes-list i))
          (let ((c (send (send lc :copy-worldcoords) :transform
                         (make-coords :pos (elt s 2) :rot (elt s 3))))
                (sz (elt s 1)))
            (case (car s)
              (:box
               (dolist (sx '(-0.5 0.5))
                 (dolist (sy '(-0.5 0.5))
                   (dolist (sz2 '(-0.5 0.5))
                     (setq zs (min zs (elt (send c :transform-vector
                                                 (float-vector (* sx (elt sz 0)) (* sy (elt sz 1))
                                                               (* sz2 (elt sz 2))))
                                           2)))))))
              (:cylinder
               ;; conservative: bounding box of the cylinder
               (let ((rr (elt sz 0)) (h (elt sz 1)))
                 (dolist (sx '(-1 1))
                   (dolist (sy '(-1 1))
                     (dolist (sz2 '(-0.5 0.5))
                       (setq zs (min zs (elt (send c :transform-vector
                                                   (float-vector (* sx rr) (* sy rr) (* sz2 h)))
                                             2)))))))))))
        (dolist (b (send (elt links i) :bodies))
          (when (find-method b :vertices)
            (dolist (v (send b :vertices)) (setq zm (min zm (elt v 2))))))))
    (list zs zm)))

(defun eus2physics (r &key (pose :reset-pose) (servo *e2p-servo*) (world *e2p-world*)
                      (contact *e2p-contact*) (verbose t) rotation-joints use-link-inertia
                      estimate-density)
  "JSON string of the \"physics\" member (links/joints in the eus2json order).
estimate-density (g/cm^3): body weight = |volume| x density, link :weight not used
(robots without weights, e.g. jskeus models) -> \"estimated\":true"
  (let* ((*e2p-density* (if estimate-density (* 0.001 estimate-density) *e2p-density*))
         (av0 (send r :angle-vector))
         (root-cds (send r :copy-worldcoords))
         (links (e2j-sort-links (send r :links)))
         (jlist (remove-if-not #'e2j-joint-type (send r :joint-list)))
         (lp (mapcar #'(lambda (l) (e2p-link-physics l :use-link-inertia use-link-inertia)) links))
         (st (make-string-output-stream 4096))
         (total 0.0) minz)
    ;; initial height at pose
    (send r :newcoords (make-coords))
    (if (find-method r pose) (send r pose))
    (send r :newcoords (make-coords))
    (send r :worldcoords)
    (setq minz (e2p-min-z r links (mapcar #'(lambda (x) (elt x 3)) lp)))
    (send r :angle-vector av0)
    (send r :newcoords root-cds)
    (send r :worldcoords)
    ;; links
    (format st "{~%\"source\":\"eusview/eus2physics.l (odedyna.l robot2drobot / kxr-dyna settings)\",~%")
    (if estimate-density
        (format st "\"estimated\":true,\"density_g_cm3\":~a,~%" (json-num estimate-density 4)))
    (format st "\"units\":{\"mass\":\"kg\",\"length\":\"m\",\"inertia\":\"kg m^2\",\"fmax\":\"N m (N for linear)\",\"vmax\":\"rad/s (m/s)\",\"kp\":\"1/s\"},~%")
    (format st "\"links\":[~%")
    (dotimes (i (length links))
      (let* ((p (elt lp i)) (m (elt p 0)) (c (elt p 1)) (it (elt p 2)) (shapes (elt p 3)))
        (setq total (+ total m))
        (format st "{\"mass\":~a,\"com\":~a,\"inertia\":[~a],\"inertia_from\":\"~a\",\"shapes\":["
                (json-num (* 0.001 m) 6) (json-vec c 6 0.001)
                (e2j-join (mapcar #'(lambda (ab) (json-num (* 1e-9 (aref it (car ab) (cadr ab))) 11))
                                  '((0 0) (0 1) (0 2) (1 1) (1 2) (2 2))))
                (string-downcase (string (elt p 4))))
        (format st "~a"
                (e2j-join
                 (mapcar #'(lambda (s)
                             (case (car s)
                               (:box
                                (format nil "{\"type\":\"box\",\"size\":~a,\"pos\":~a,\"rot\":~a,\"mass\":~a}"
                                        (json-vec (elt s 1) 5 0.001) (json-vec (elt s 2) 5 0.001)
                                        (json-rot (elt s 3)) (json-num (* 0.001 (elt s 4)) 6)))
                               (:cylinder
                                (format nil "{\"type\":\"cylinder\",\"radius\":~a,\"length\":~a,\"pos\":~a,\"rot\":~a,\"mass\":~a}"
                                        (json-num (* 0.001 (elt (elt s 1) 0)) 5)
                                        (json-num (* 0.001 (elt (elt s 1) 1)) 5)
                                        (json-vec (elt s 2) 5 0.001)
                                        (json-rot (elt s 3)) (json-num (* 0.001 (elt s 4)) 6)))))
                         shapes)))
        (format st "]}~a~%" (if (< i (1- (length links))) "," ""))
        (when (and verbose (> (abs (- m (elt p 5))) 0.5))
          (format t ";; eus2physics ~A: link weight ~A g, boxes ~A g~%" (send (elt links i) :name)
                  m (elt p 5)))))
    (format st "],~%\"joints\":[~%")
    (dotimes (k (length jlist))
      (let ((j (elt jlist k)))
        (format st "{\"motor\":\"~a\",\"fmax\":~a,\"vmax\":~a,\"kp\":~a,\"damping\":~a}~a~%"
                (e2p-joint-motor j rotation-joints)
                (json-num (e2p-cdr :fmax servo) 4) (json-num (e2p-cdr :vmax servo) 4)
                (json-num (e2p-cdr :kp servo) 4) (json-num (e2p-cdr :damping servo) 4)
                (if (< k (1- (length jlist))) "," ""))))
    (format st "],~%\"odedyna_motor\":{\"kp\":~a,\"fmax\":~a},~%"
            (json-num (e2p-cdr :kp *e2p-odedyna-motor*) 4)
            (json-num (e2p-cdr :fmax *e2p-odedyna-motor*) 0))
    (format st "\"world\":{\"gravity\":~a,\"dt\":~a,\"erp\":~a,\"cfm\":~a,\"quickstep\":~a,\"iterations\":~a},~%"
            (json-vec (e2p-cdr :gravity world) 4) (json-num (e2p-cdr :dt world) 5)
            (json-num (e2p-cdr :erp world) 6) (json-num (e2p-cdr :cfm world) 8)
            (if (e2p-cdr :quickstep world) "true" "false") (e2p-cdr :iterations world))
    (format st "\"contact\":{\"mu\":~a,\"soft_erp\":~a,\"soft_cfm\":~a,\"bounce\":~a,\"bounce_vel\":~a,\"max_contacts\":~a,\"mode\":\"Bounce|SoftERP|SoftCFM|Approx1\"},~%"
            (json-num (e2p-cdr :mu contact) 4) (json-num (e2p-cdr :soft-erp contact) 6)
            (json-num (e2p-cdr :soft-cfm contact) 8) (json-num (e2p-cdr :bounce contact) 4)
            (json-num (e2p-cdr :bounce-vel contact) 4) (e2p-cdr :max-contacts contact))
    (format st "\"total_mass\":~a,~%" (json-num (* 0.001 total) 5))
    (format st "\"initial\":{\"pose\":\"~a\",\"root_pos\":[0,0,~a],\"shapes_min_z\":~a,\"meshes_min_z\":~a}~%}"
            (string-downcase (string pose)) (json-num (* -0.001 (elt minz 0)) 5)
            (json-num (* 0.001 (elt minz 0)) 5) (json-num (* 0.001 (elt minz 1)) 5))
    (when verbose
      (format t ";; eus2physics ~A: ~d links, total ~a kg, ~A shapes, min z at ~A: shapes ~a mm, meshes ~a mm~%"
              (send r :name) (length links) (json-num (* 0.001 total) 4)
              (apply #'+ (mapcar #'(lambda (x) (length (elt x 3))) lp))
              pose (json-num (elt minz 0) 2) (json-num (elt minz 1) 2)))
    (get-output-stream-string st)))

(provide :eus2physics)
