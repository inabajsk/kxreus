;;
;; Ichiro Arm for PU-Toyama 2025.11.12 M.I 
;;
(require :khrmodels)
(provide :iarm)

(defun iarm-link0 (&optional (coords (make-cascoords)))
  (let* ((s0 (khr-servo-s2552))
	 (ds0 (khr-servo-dummy))
	 (ds1 (khr-servo-dummy))
	 (offset 26)
	 l)
    (dolist (s (list s0 ds0 ds1))
      (send s :rotate pi :z) (send s :translate #f(0 0 -20)))
    (send ds0 :locate (float-vector 0 offset 0))
    (send ds1 :locate (float-vector 0 (- offset) 0))
    (setq l (instance bodyset-link :init coords :bodies (list s0 ds0 ds1)))
    (setf (get l :joint-coord) (get s0 :upper-coord))
    l))

(defun iarm-link1 (&optional (coords (make-cascoords)))
  (let ((am (khr-arm-link))
	l)
    (setq l (instance bodyset-link :init coords :bodies (send am :bodies)))
    (setf (get l :joint-coord) (get am :joint-coord))
    l))

(defun iarm-link2 (&optional (coords (make-cascoords)))
  (let ((sv0 (khr-servo-s2552))
	(sv1 (khr-servo-s2552))
	l)
    (send sv0 :rotate pi/2 :x :world)
    (send sv0 :rotate pi/2 :y :world)
    (send sv0 :locate #f(0 0 0) :world)
    (send sv1 :rotate pi/2 :x :world)
    (send sv1 :locate #f(0 0 -65) :world)
    (send sv1 :rotate (deg2rad -60) :y :world)
    (send sv0 :assoc sv1)
    (send sv0 :rotate -pi/2 :y :world)
    (setq l (instance bodyset-link :init coords :bodies (list sv0 sv1)))
    (setf (get l :joint-coord) (get sv1 :joint-coord))
    l))

(defun iarm-link3 (&optional (coords (make-cascoords)))
  (let ((am (khr-arm-link))
	(sv (khr-servo-s2552))
	blist)
    (send sv :rotate pi :z :world)
    (send sv :rotate -pi/2 :x :world)
    (send sv :locate #f(-20 0 -36.9) :world)
    (send sv :rotate (deg2rad 130) :y :world)
    (send am :assoc sv)
    (send am :rotate (deg2rad -110) :y :world)
    (send am :locate (v- (send (get am :joint-coord) :worldpos)) :world)
    (setq blist (cons sv (send am :bodies)))
    (dolist (b (cdr blist)) (send (car blist) :assoc b))
    (setq l (instance bodyset-link :init coords :bodies blist))
    (setf (get l :joint-coord) (get sv :joint-coord))
    l))

(defun iarm-link4 (&optional (coords (make-cascoords)))
  (let ((am (khr-arm-link)) blist l)
    (send am :rotate -pi/2 :y :world)
    (send am :locate #f(25 0 0) :world)
    (setq blist (send am :bodies))
    (dolist (b (cdr blist)) (send (car blist) :assoc b))
    (setq l (instance bodyset-link :init coords :bodies blist))
    (setf (get l :joint-coord) (send am :worldcoords))
    l))

(defclass iarmclass
  :super robot-model
  :slots (end-coords joint0 joint1 joint2 joint3
		     iarm-b0 iarm-b1 iarm-b2 iarm-b3 iarm-b4)
  )

(defmethod iarmclass
  (:end-coords (&rest args) (forward-message-to end-coords args))
  (:joint0 (&rest args) (forward-message-to joint0 args))
  (:joint1 (&rest args) (forward-message-to joint1 args))
  (:joint2 (&rest args) (forward-message-to joint2 args))
  (:joint3 (&rest args) (forward-message-to joint3 args))
  (:init
   (&rest args)
   (send-super* :init args)
   (setq iarm-b0 (iarm-link0))
   (setq iarm-b1 (iarm-link1))
   (setq iarm-b2 (iarm-link2))
   (setq iarm-b3 (iarm-link3))
   (setq iarm-b4 (iarm-link4))
   ;;
   (send iarm-b4 :locate (send (get iarm-b3 :joint-coord) :worldpos) :world)
   (send iarm-b3 :assoc iarm-b4)
   (send iarm-b3 :locate (send (get iarm-b2 :joint-coord) :worldpos) :world)
   (send iarm-b2 :assoc iarm-b3)
   (send iarm-b2 :locate (send (get iarm-b1 :joint-coord) :worldpos) :world)
   (send iarm-b1 :assoc iarm-b2)
   (send iarm-b1 :locate (send (get iarm-b0 :joint-coord) :worldpos) :world)
   (send iarm-b0 :assoc iarm-b1)
   ;;
   (setq joint0 (instance rotational-joint
			  :init :parent-link iarm-b0 :child-link iarm-b1 :name :joint0 :axis :z :min -135 :max 135))
   (setq joint1 (instance rotational-joint
			  :init :parent-link iarm-b1 :child-link iarm-b2 :name :joint1 :axis :y :min -135 :max 135))
   (setq joint2 (instance rotational-joint
			  :init :parent-link iarm-b2 :child-link iarm-b3 :name :joint2 :axis :y :min -135 :max 135))
   (setq joint3 (instance rotational-joint
			  :init :parent-link iarm-b3 :child-link iarm-b4 :name :joint3 :axis :y :min -135 :max 135))
   ;;
   (setq end-coords (make-cascoords :coords (send iarm-b4 :copy-worldcoords)))
   (send end-coords :translate #f(25 0 0) :world)
   (send iarm-b4 :assoc end-coords)
   (setq links (list iarm-b0 iarm-b1 iarm-b2 iarm-b3 iarm-b4))
   (setq joint-list (list joint0 joint1 joint2 joint3))
   (send self :init-ending)
   self
   )
  )

(defun iarm nil (setq *iarm* (instance iarmclass :init)))
