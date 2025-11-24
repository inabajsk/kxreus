;;;
;;; 	Robot body modeling for KXR robots
;;;
;;;	2018.6.12 created JSK M.I
;;;	2018.6.17 kxr L2 robot-model genarates auto methods by joint name
;;;	2018.6.21 KXR L4 l4t l4r l4d l4n l4p
;;;	2018.6.29 KXR L6
;;;	2018.7.9  KXR L2 add wrist-r
;;;	2018.7.13 add gripper2-r joint, right end-coords for gripper
;;;	2019.7.13 starting building kxrl2makabe robot model
;;;	2020.3.15 reduction kxr-xx-robots to kxr-robot class 1781 from 1966(2020.3.10)
;;;	in :init skip make-pqpmodel in :init-ending of irtmodel.l
;;;	2020.4.3 reduction with :push-joint, :add-link, kxr-create-link 1084 ls
;;;	2020.4.4 :limb update. kxrmodels.l total lines: 1159
;;;	2020.6.12 starting anzai bicopter robot extentions :wing
;;;	2021.11.22 starting tail limb for animal-like robots
;;;


;;(load "colladainit.l")
#|
(defmethod cascaded-link
  (:init-ending
   ()
   "This method is to called finalize the instantiation of the cascaded-link. This update bodies and child-link and parent link from joint-list"
   (setq bodies (flatten (send-all links :bodies)))
   (dolist (j joint-list)
     (send (send j :child-link) :add-joint j)
     (send (send j :child-link) :add-parent-link (send j :parent-link))
     (send (send j :parent-link) :add-child-links (send j :child-link))
     )
   (send self :update-descendants)
   ;; Make default collision shape by pqp
   (dolist (l (send self :links)) (send l :make-pqpmodel))
   )
  )
|#
(require :m5models)
(require :kxrlinks)
;;(require :kxrextentions)

(defvar *torque-vector-scale* 1.0)
(defun show-calc-torque (&key (size 200) (width 4))
  (when (and (boundp '*robot*) (boundp '*irtviewer*))
    (send *robot* :calc-torque)
    (send *irtviewer* :draw-objects :flush nil)
    (send *robot* :draw-torque (send *irtviewer* :viewer)
	  :torque-vector (scale *torque-vector-scale*
				(send *robot* :torque-vector))
	  :flush t :size size :width width))
  )


(defun kxr-head-sensor (hd &key 3eye-rev (lego-bar 13) m5stack
			     (front t) (cover t) (m5stickv t) lidar)
  (case
      hd
    (:e (kxr-euclid-head))
    (:ir (kxr-irsensor-head-bodyset))
    ;;
    (:m5 (kxr-m5head))
    (:m5h (kxr-m5head-horizontal-bodyset t))
    (:m5i (kxr-m5-irsensor-head-bodyset))
    (:m5s (kxr-m5head-stereo))
    (:m5sh (m5stickv-stereo))
    (:m5shv2 (m5stickv-stereo :m5unitv2 t))
    ;;
    (:m5us (m5unitv-stereo :m5stack m5stack :base nil :n lego-bar))
    (:m5u2s (m5unitv2-stereo :base nil :n lego-bar))
    (:m5usv2 (m5unitv-stereo :m5stack m5stack :base nil :m5unitv2 t :n lego-bar))
    ((:m5u3s :m5u3sb) (m5unitv-stereo :m5stack m5stack :base nil :n lego-bar))
    (:m5u3s2 (m5unitv2-stereo :base nil :n lego-bar))
    (:m5u3sv2 (m5unitv-stereo :m5stack m5stack :base nil :m5unitv2 t :n lego-bar))
    ;;
    (:m3eye (m5stickhead-3eye :rev 3eye-rev :m5stickv m5stickv))
    (:my3eye (m5stickhead-3eye :y-servo t :rev 3eye-rev :front front :cover cover
			       :m5stickv m5stickv))
    (:m3deye (3dusb-3eye-link :rev 3eye-rev :front front :cover cover
			      :m5stickv m5stickv :lidar lidar))
    ;;
    (:d405 (d405-head-link :front front))
    (:d405cam (kxr-d405-link))
    (:d405eyes (d405-m5stamp-eyes-link))
    (:d405eyes-iris (d405-m5stamp-eyes-iris-link))
    (:kashiwagi (kashiwagi-head-link))
    (:d405echos (d405-echos-link))
    (:realsense (kxr-realsense-head))
    (:realsense-y (kxr-realsense-head-yaw))
    (:h2-auv (kxr-auv-head))
    (t nil)))

(defclass kxr-robot :super robot-model
  :slots (body-link limbs type lst-alist jlst-alist lst jlst
		    collision-avoidance-links-alist name-joint-list
		    sensor-coords-alist end-coords-alist root-link-alist))

(defmethod kxr-robot
  (:setup-cboard
   (&rest
    args &key board &allow-other-keys)
   (let ((imu (send* self :find-imu args)))
     (when imu
       (send self :setup-gsensor
	     (make-cascoords :name "gsensor" :coords (send imu :worldcoords)))
       (send self :setup-gyrometer
	     (make-cascoords :name "gyrometer" :coords (send imu :worldcoords))))
     imu))
  (:setup-sensor-boards
   nil
   (let ((bb (reverse (send self :find-named-bodies "KJS"))) b
	 kjs-imu-sensors pressure-sensors proximity-sensors button-sensors)
     (dolist (b bb)
       (when (find-method (send b :parent) :joint)
	 (send b :name
	       (format nil "~A-~A" (string (send (send (send b :parent) :joint) :name))
		       (send b :name)))
	 (push b imu-sensors)))
     (dolist (b bb)
       (if (substringp "KJS-03" (send b :name))
	   (dolist (c (send b :find-named-objects "adc"))
	     (send c :name (format nil "~A ~A ~A"
				   (send ((c . parent) . parent) :name)
				   (send (c . parent) :name) (send c :name)))
	     (push c pressure-sensors))
	   (push b button-sensors)))
     (setf (get self :pressure-sensors) pressure-sensors)
     (setf (get self :button-sensors) button-sensors)
     (dolist (b bb)
       (dolist (c (send b :find-named-objects "ps"))
	 (send c :name (format nil "~A ~A ~A"
			       (send ((c . parent) . parent) :name)
			       (send (c . parent) :name) (send c :name)))
	 (push c proximity-sensors)))
     (setf (get self :proximity-sensors) proximity-sensors)
     (dolist (b bb)
       (dolist (c (send b :find-named-objects "imu"))
	 (send c :name (format nil "~A ~A ~A"
			       (send ((c . parent) . parent) :name)
			       (send (c . parent) :name) (send c :name)))
	 (push c kjs-imu-sensors)))
     (setf (get self :kjs-imu-sensors) kjs-imu-sensors)
     )
   )
  (:backpack-link
   nil
   (let (bp cb cc imu ls)
     (setq ls (send self :links))
     (dolist (l ls)
       (when (send l :find-named-body "back-pack")
	 (return-from :backpack-link l)))
     body-link))
  (:cboard-coords
   nil
   (let (bp cc)
     (setq bp (send self :find-named-body "back-pack"))
     (setq cc (send bp :find-named-coords "board"))))
  (:find-imu
   (&rest args &key (board :armh7) &allow-other-keys)
   (let (bp cb cc imu (bl (send self :backpack-link)))
     (when
	 (and (setq bp (send self :find-named-body "back-pack"))
	      (setq cc (send bp :find-named-coords "board")))
       (cond
	 ((eq board :rcb4)
	  (if (find-if #'(lambda (n) (substringp n (string (send bp :name)))) '("small" "raspi"))
	      (setq imu (send bp :find-named-coords "imu"))))
	 ((eq board :armh7)
	  (require :kxrboards)
	  (setq cb (kxr-armh7-board-bodyset))
	  (send cb :newcoords (send cc :copy-worldcoords))
	  (setq imu (send cb :find-named-body "imu"))
	  )
	 ((eq board :max10)
	  (require :kxrboards)
	  (setq cb (kxr-max10-board-bodyset))
	  (send cb :newcoords (send cc :copy-worldcoords))
	  (setq imu (send cb :find-named-body "imu"))
	  )
	 )
       imu))
   )
  (:body-link (&rest args) (forward-message-to body-link args))
  (:sensor-coords
   (&optional key)
   (if key (assocdr key sensor-coords-alist)
       (flatten (mapcar #'cdr sensor-coords-alist))))
  (:end-coords
   (&optional key)
   (if key (assocdr key end-coords-alist) (flatten (mapcar #'cdr end-coords-alist))))
  (:root-link
   (&optional key)
   (if key (assocdr key root-link-alist) (flatten (mapcar #'cdr root-link-alist))))
  (:collision-check-pairs
   (&key &rest args &allow-other-keys)
   (remove
    (cons (send self :link "head-gripper-p") (send self :link "head-gripper2-p"))
    (remove
     (cons (send self :link "larm-gripper-r") (send self :link "larm-gripper2-r"))
     (remove
      (cons (send self :link "rarm-gripper-r") (send self :link "rarm-gripper2-r"))
      (send-super* :collision-check-pairs args)
      :test #'(lambda (a b) (or (equal a b) (equal (cons (cdr a) (car a)) b))))
     :test #'(lambda (a b) (or (equal a b) (equal (cons (cdr a) (car a)) b))))
    :test #'(lambda (a b) (or (equal a b) (equal (cons (cdr a) (car a)) b)))))
  (:faces-intersect-with-point-vector
   (point vector)
   (mapcan #'(lambda (b) (send b :faces-intersect-with-point-vector point vector))
	   (send self :bodies))
   )
  (:setup-gsensor
   (&optional (c (make-cascoords :name "gsensor" :coords (send body-link :copy-worldcoords)))
	      (lnk (send self :backpack-link)))
   (send c :put :sensor-type :base_imu)
   (setq imu-sensors (remove-if #'(lambda (x) (string= "gsensor" (send x :name))) imu-sensors))
   (push c imu-sensors)
   (send lnk :assoc c)
   )
  (:setup-gyrometer
   (&optional (c (make-cascoords :name "gyrometer" :coords (send body-link :copy-worldcoords)))
	      (lnk (send self :backpack-link)))	      
   (send c :put :sensor-type :base_imu)
   (setq imu-sensors (remove-if #'(lambda (x) (string= "gyrometer" (send x :name))) imu-sensors))
   (push c imu-sensors)
   (send lnk :assoc c)
   )
  (:limbs nil limbs)
  (:reset nil (send self :neutral))
  (:volume nil (apply #'+ (send-all links :volume)))
  (:inertia-matrix
   (&optional (c (make-cascoords)))
   (let* ((ls (send self :links))
	  (im (copy-object (send (car ls) :inertia-matrix c))))
     (dolist (b (cdr ls))
       (m+ im (send b :inertia-matrix c) im))
     im))
  (:dump-to-file
   (func-name)
   (let ((sym (robot-gvar func-name)) (r self))
     (dump-structure (format nil "~A.l" func-name)
		     `(require :kxrmodels)
		     `(setq ,sym ',r))))
  (:change-visual
   (&optional (visual :fine))
   (dolist (lk (send self :links))
     (dolist (bd (send lk :bodies))
       (when (derivedp bd kxr-body)
         (send bd :change-visual visual)))))
  (:neutral
   nil
   (send self :angle-vector
	 (instantiate float-vector (length (send self :angle-vector)))))
  (:init-limb ;; for dynamic modification e.g. :limb :larm :upper-y t
   (limb &rest args &key &allow-other-keys)
   (case
       limb
     (:head (send* self :setup-head args))
     (:tail (send* self :setup-tail args))
     ((:larm :rarm) (send* self :setup-arm :l/r limb args))
     ((:lwing :rwing) (send* self :setup-wing :l/r limb args))
     (:arms (send* self :setup-arm :l/r :larm args)
	    (send* self :setup-arm :l/r :rarm args))
     ((:lmarm :rmarm) (send* self :setup-arm :l/r limb args))
     (:torso
      (send* self :setup-torso args))
     (:marms
      (send* self :setup-arm :l/r :lmarm args)
      (send* self :setup-arm :l/r :rmarm args))
     ((:lleg :rleg :lleg0 :lleg1 :lleg2 :rleg0 :rleg1 :rleg2)
      (send* self :setup-leg :l/r limb args))
     (:legs (send* self :setup-leg :l/r :lleg args)
	    (send* self :setup-leg :l/r :rleg args))
     )
   (setq end-coords-list nil)
   (send self :init-limbs)
   (send self :init-ending)
   )
  (:init-limbs ;; kxr-robot
   (&rest args &key arm marm leg mirrored &allow-other-keys)
   (let (v)
     (dolist (p '(:lleg :rleg :larm :rarm :lmarm :rmarm
			:lleg0 :lleg1 :lleg2 :rleg0 :rleg1 :rleg2))
       (if (setq v (assocdr p sensor-coords-alist))
	   (push v force-sensors)))
     (dotimes (i (length force-sensors))
       (setf (get (elt force-sensors i) :sensor-id) i))
     (dolist (p '(:gsensor :gyrometer))
       (if (setq v (assocdr p sensor-coords-alist))
	   (push v imu-sensors)))
     (dotimes (i (length imu-sensors))
       (setf (get (elt imu-sensors i) :sensor-id) 0))
     
     (setq joint-list (flatten (mapcar #'cdr jlst-alist)))
     (setq links (cons body-link (flatten (mapcar #'cdr lst-alist))))
     (setq limbs (mapcar #'car lst-alist))
     ))
  (:type () type)
  (:init ;; kxr-robot
   (&rest args &key (name "kxr-robot") ((:type typ)) init-form limb leg0 leg1 leg2
	  reset-pose-alist wing marm mirrored &allow-other-keys)
   (setq type typ)
   ;; (if (null config) (setq config (cddr args)))
   ;; (format t ";; ~A~%" (cons (cadr args) config))
   (send-super* :init :name name args)
   (setf (get self :mirrored) mirrored)

   (send* self :setup-body args)
   (unless typ
     (when
	 (memq limb '(:lwing :rwing :larm :rarm :lmarm :rmarm :lleg :rleg :leg))
       (setq typ :limb)))
   (cond
    ((memq limb '(:lwing :rwing))
     (send* self :setup-wing :l/r limb args))
    ((memq limb '(:larm :rarm :lmarm :rmarm))
     (send* self :setup-arm :l/r limb args))
    ((memq limb '(:lleg :rleg :lleg0 :lleg1 :lleg2 :rleg0 :rleg1 :rleg2))
     (send* self :setup-leg :l/r limb args))
    ((memq limb '(:leg :l6 :l5))
     )
    (t
     (send* self :setup-torso args)
     (send* self :setup-neck args)
     (send* self :setup-head args)
     (send* self :setup-tail args)
     (when wing
       (send* self :setup-wing :l/r :lwing args)
       (send* self :setup-wing :l/r :rwing args))
     
     (when marm
       (send* self :setup-arm :l/r :lmarm args)
       (send* self :setup-arm :l/r :rmarm args))
     
     (cond
      ((or leg0 leg1 leg2)
       (when leg0
	 (send* self :setup-leg :l/r :lleg0 args)
	 (send* self :setup-leg :l/r :rleg0 args))
       (when leg1
	 (send* self :setup-leg :l/r :lleg1 args)
	 (send* self :setup-leg :l/r :rleg1 args))
       (when leg2
	 (send* self :setup-leg :l/r :lleg2 args)
	 (send* self :setup-leg :l/r :rleg2 args))
       )
      (t
       (send* self :setup-leg :l/r :lleg args)
       (send* self :setup-leg :l/r :rleg args)))
     (send* self :setup-arm :l/r :larm args)
     (send* self :setup-arm :l/r :rarm args)
     ))
   
   (send* self :init-limbs args)
   (send self :assoc body-link)

   (send self :init-ending)
   (send* self :setup-cboard args)
   (send self :setup-sensor-boards)
   (send self :cal-weight)
   (send self :inertia-matrix)
   (send self :cal-height)
   (send self :reset-pose)
   (when
       reset-pose-alist
     (send self :put :reset-pose-alist reset-pose-alist)
     (send self :reset-pose-alist)
     )
   (send self :foot-stand)
   (when init-form (format *error-output* ":init-form ~A~%" init-form) (eval init-form))
   self)
  (:foot-stand
   nil
   (cond
     ((memq type (list :base :limb :module)))
     ((eq type :l6) (send self :reset-pose))
     ((and (send self :lleg-end-coords) (send self :rleg-end-coords))
      (send body-link
	    :translate (v- (scale 0.5 (v+ (send self :lleg-end-coords :worldpos) ;; (assocdr :lleg end-coords-alist)
					  (send self :rleg-end-coords :worldpos)))) ;; (assocdr :rleg end-coords-alist)
	    :world)
      ))
   )
  )

(defun kxr-robot (&rest args &key (name "kxr-robot") init-form &allow-other-keys)
  (let ((r (instance* kxr-robot :init :name name args)))
    (when (and init-form (listp init-form)
	       (fboundp (car init-form)))
      (setq r (eval init-form)))
    r))

(defun kxr-create-defmethod (&optional (cls-name 'kxr-robot))
  (let ((jorder '(((:larm :rarm :lmarm :rmarm)
		   (:shoulder :elbow :wrist :gripper :gripper2))
		  ((:lleg :rleg :lleg0 :rleg0 :lleg1 :rleg1 :lleg2 :rleg2) (:crotch :knee :ankle :foot))
		  ((:lwing :rwing) (:gimbal0 :gimbal1 :gimbal2 :gimbal3))
		  ((:torso) (:chest))
		  ((:tail) (:roll))
		  ((:head) (:leye :reye :neck :head :gripper :gripper2))))
	methname)
    (dolist (jo jorder)
      (dolist (limb (car jo))
	(setq methname (read-from-string (format nil ":~A-end-coords" (string limb))))
	(eval `(defmethod ,cls-name
		   (,methname (&rest args)
				 (forward-message-to
				  (cdr (assoc ,limb end-coords-alist))
				  args))))
	(setq methname (read-from-string (format nil ":~A-root-link" (string limb))))
	(eval `(defmethod ,cls-name
		   (,methname (&rest args)
				 (forward-message-to
				  (cdr (assoc ,limb root-link-alist))
				  args))))
	(dolist (jb (cadr jo))
	  (dolist (a '(:r :p :y :w))
	    (setq methname
		  (read-from-string
		   (format nil ":~A-~A-~A" (string limb) (string jb) (string a))))
	    (eval `(defmethod ,cls-name
		       (,methname (&rest args)
				     ;; (forward-message-to head-head-y args)
				     (forward-message-to
				      (cdr (assoc ,methname name-joint-list)) 
				      args))))))))))
(kxr-create-defmethod 'kxr-robot)
;;(kxr-create-defmethod 'robot-model)

(defun kxr-limb-joint-name (limb i)
  (cond
    ((memq limb '(:lwing :rwing)) (format nil "gimbal~A" i))
    ((memq limb '(:larm :rarm :lmarm :rmarm)) (elt '("shoulder" "elbow" "wrist") i))
    ((memq limb '(:lleg :rleg :lleg0 :rleg0 :lleg1 :rleg1 :lleg2 :rleg2))
     (elt '("crotch" "knee" "ankle") i))))

(defmethod robot-model
  (:link-joint-check
   nil
   (let ((ln (length links))
	 (jn (length joint-list)))
     (cond
      ((= ln (1+ jn)) (format t ";; OK ln=jn=~A~%" ln))
      (t
       (format t ";; NG ln=~A jn=~A~% links=~A~% joint-list=~A~%" ln jn links joint-list)))))
  )

(defmethod kxr-robot
  (:jlst-alist nil jlst-alist)
  (:lst-alist nil lst-alist)
  (:name-joint-list nil name-joint-list)
  (:end-coords-alist nil end-coords-alist)
  (:sensor-coords-alist nil sensor-coords-alist)
  (:root-link-alist nil root-link-alist)
  (:head-gripper-p
   (&rest args)
   (prog1 (forward-message-to (cdr (assoc :head-gripper-p name-joint-list)) args)
     (forward-message-to (cdr (assoc :head-gripper2-p name-joint-list)) args)))
  (:larm-gripper-r
   (&rest args)
   (prog1 (forward-message-to (cdr (assoc :larm-gripper-r name-joint-list)) args)
     (forward-message-to (cdr (assoc :larm-gripper2-r name-joint-list)) args)))
  (:rarm-gripper-r
   (&rest args)
   (prog1 (forward-message-to (cdr (assoc :rarm-gripper-r name-joint-list)) args)
     (forward-message-to (cdr (assoc :rarm-gripper2-r name-joint-list)) args)))
  ;;
  (:head-gripper-r
   (&rest args)
   (prog1 (forward-message-to (cdr (assoc :head-gripper-r name-joint-list)) args)
     (forward-message-to (cdr (assoc :head-gripper2-r name-joint-list)) args)))
  ;;
  (:sit-pose ;; kxr-robot
   (&optional (knee 130))
   (let ((mpconf (send self :model-params))
	 (sign (if (get self :mirrored) 1 -1)) v)
     (case
	 type
       (:l2
	(send self :neutral)
	(send self :head :neck-p :joint-angle 10)
	(send self :arms :wrist-p :joint-angle -30)
	(send self :arms :shoulder-p :joint-angle 30)
	(send self :arms :elbow-p :joint-angle -90)
	(send self :legs :crotch-p :joint-angle (- (/ knee 2.0)))
	(send self :legs :ankle-p :joint-angle  (- (/ knee 2.0)))
	(send self :legs :knee-p :joint-angle knee)
	(send self :legs :ankle-r :joint-angle 0)
	(send self :legs :crotch-w :joint-angle 0)
	(send self :legs :ankle-w :joint-angle 0))
       )))
  (:reset-pose-alist
   (&optional (alist t))
   (when
       (consp alist)
     (send self :put :reset-pose-alist alist))
   (send self :angle-alist (get self :reset-pose-alist)))
  (:reset-pose ;; kxr-robot
   (&optional (knee 40))
   (let ((mpconf (send self :model-params))
	 (sign (if (get self :mirrored) 1 -1)) v)
     (when
	 (get self :reset-pose-alist)
       (send self :reset-pose-alist)
       (return-from :reset-pose (send self :angle-vector)))
     (case
	 type
       (:l2
	(send self :neutral)
	(send self :head :neck-p :joint-angle 10)
	(send self :arms :wrist-p :joint-angle -30)
	(send self :arms :shoulder-p :joint-angle 30)
	(send self :arms :elbow-p :joint-angle -40)
	(send self :legs :crotch-p :joint-angle (- (/ knee 2.0)))
	(send self :legs :ankle-p :joint-angle  (- (/ knee 2.0)))
	(send self :legs :knee-p :joint-angle knee)
	(send self :legs :ankle-r :joint-angle 0)
	(send self :legs :crotch-w :joint-angle 0)
	(send self :legs :ankle-w :joint-angle 0))
       (:l4
	(case
	    (and (setq v (memq :arm mpconf)) (cadr v))
	  (:j2
	   (send self :rarm :shoulder-r :joint-angle 90)
	   (send self :larm :shoulder-r :joint-angle -90))
	  (:j3
	   (send self :larm :shoulder-r :joint-angle knee)
	   (send self :rarm :shoulder-r :joint-angle (- knee))
	   (send self :larm :elbow-r :joint-angle (* -3 knee))
	   (send self :rarm :elbow-r :joint-angle (* 3 knee))))
	(case
	    (or (and (eq type :l6) (null (memq :marm mpconf))
		     (setq v (memq :arm mpconf)) (cadr v))
		(and (setq v (memq :marm mpconf)) (cadr v)))
	  (:j2
	   (send self :rmarm :shoulder-r :joint-angle 90)
	   (send self :lmarm :shoulder-r :joint-angle -90))
	  (:j3
	   (send self :lmarm :shoulder-r :joint-angle knee)
	   (send self :rmarm :shoulder-r :joint-angle (- knee))
	   (send self :lmarm :elbow-r :joint-angle (* -3 knee))
	   (send self :rmarm :elbow-r :joint-angle (* 3 knee))))
	(case
	    (and (setq v (memq :leg mpconf)) (cadr v))
	  (:j2 
	   (send self :rleg :crotch-r :joint-angle  90)
	   (send self :lleg :crotch-r :joint-angle -90))
	  (:j3
	   (send self :lleg :crotch-r :joint-angle knee)
	   (send self :rleg :crotch-r :joint-angle (- knee))
	   (send self :lleg :knee-r :joint-angle (* -3 knee))
	   (send self :rleg :knee-r :joint-angle (* 3 knee))))
	)
       (:l6
	(case
	    (and (setq v (memq :arm mpconf)) (cadr v))
	  (:j2
	   (send self :rarm :shoulder-p :joint-angle 90)
	   (send self :larm :shoulder-p :joint-angle -90))
	  (:j3
	   (send self :larm :shoulder-p :joint-angle (- knee))
	   (send self :rarm :shoulder-p :joint-angle (- knee))
	   (send self :larm :elbow-p :joint-angle (* 3 knee))
	   (send self :rarm :elbow-p :joint-angle (* 3 knee))))
	(case
	    (or (and (eq type :l6) (null (memq :marm mpconf))
		     (setq v (memq :arm mpconf)) (cadr v))
		(and (setq v (memq :marm mpconf)) (cadr v)))
	  (:j2
	   (send self :rmarm :shoulder-p :joint-angle 90)
	   (send self :lmarm :shoulder-p :joint-angle -90))
	  (:j3
	   (send self :lmarm :shoulder-r :joint-angle knee)
	   (send self :rmarm :shoulder-r :joint-angle (- knee))
	   (send self :lmarm :elbow-r :joint-angle (* -3 knee))
	   (send self :rmarm :elbow-r :joint-angle (* 3 knee))))
	(case
	    (and (setq v (memq :leg mpconf)) (cadr v))
	  (:j2 
	   (send self :rleg :crotch-p :joint-angle  90)
	   (send self :lleg :crotch-p :joint-angle -90))
	  (:j3
	   (send self :lleg :crotch-p :joint-angle knee)
	   (send self :rleg :crotch-p :joint-angle knee)
	   (send self :lleg :knee-p :joint-angle (* -3 knee))
	   (send self :rleg :knee-p :joint-angle (* -3 knee))))
	(send self :larm :shoulder-y :joint-angle 30)
	(send self :rarm :shoulder-y :joint-angle (* sign 30))
	(send self :rleg :crotch-y :joint-angle (* sign -30))
	(send self :lleg :crotch-y :joint-angle -30)
	)))
   )
  (:lmarm (&rest args) (unless args (setq args (list nil))) (send* self :limb :lmarm args))
  (:rmarm (&rest args) (unless args (setq args (list nil))) (send* self :limb :rmarm args))
  (:lleg0 (&rest args) (unless args (setq args (list nil))) (send* self :limb :lleg0 args))
  (:rleg0 (&rest args) (unless args (setq args (list nil))) (send* self :limb :rleg0 args))
  (:lleg1 (&rest args) (unless args (setq args (list nil))) (send* self :limb :lleg1 args))
  (:rleg1 (&rest args) (unless args (setq args (list nil))) (send* self :limb :rleg1 args))
  (:lleg2 (&rest args) (unless args (setq args (list nil))) (send* self :limb :lleg2 args))
  (:rleg2 (&rest args) (unless args (setq args (list nil))) (send* self :limb :rleg2 args))
  (:lwing (&rest args) (unless args (setq args (list nil))) (send* self :limb :lwing args))
  (:rwing (&rest args) (unless args (setq args (list nil))) (send* self :limb :rwing args))
  (:limb
   (limb method &rest args)
   (let (ret)
     (case method
       (:end-coords 
	(user::forward-message-to (assocdr limb end-coords-alist) args))
       (:root-link
	(user::forward-message-to (assocdr limb root-link-alist) args))
       (:angle-vector
	(if args
	    (progn
	      (mapcar #'(lambda (l a)
			  (send l :joint :joint-angle a))
		      (send self limb) (coerce (car args) cons))
	      (send self limb :angle-vector))
	    (coerce (mapcar #'(lambda (l) (send l :joint :joint-angle))
			    (send self limb)) float-vector)))
       (:inverse-kinematics
	(let* ((link-list (if (memq :link-list args)
			      (cadr (memq :link-list args))
			      (send self :link-list
				    (send self limb :end-coords :parent)
				    (send self limb :root-link))))
	       (collision-avoidance-link-pair
		(if (memq :collision-avoidance-link-pair args)
		    (cadr (memq :collision-avoidance-link-pair args))
		    (send self :collision-avoidance-link-pair-from-link-list link-list
			  :collision-avoidance-links (send self limb :collision-avoidance-links)))))
	  (send* self :inverse-kinematics (car args)
		 :move-target (if (memq :move-target args)
				  (cadr (memq :move-target args))
				  (send self limb :end-coords))
		 :collision-avoidance-link-pair collision-avoidance-link-pair
		 :link-list link-list
		 (cdr args))))
       (:move-end
	(send* self limb :inverse-kinematics args))
       (:move-end-rot
	(let ((coords (send self limb :end-coords :copy-worldcoords))
	      (angle (pop args)) (axis (pop args)) (wrt (pop args)))
	  (unless wrt (setq wrt :local))
	  (send* self limb :move-end
		 (send coords :rotate (deg2rad angle) axis wrt) args)))
       (:move-end-pos
	(let ((coords (send self limb :end-coords :copy-worldcoords))
	      (pos (pop args)) (wrt (pop args)))
	  (unless wrt (setq wrt :local))
	  (send* self limb :move-end (send coords :translate pos wrt) args)))
       (:look-at
        (if (send self :head :links) (send* self :inverse-kinematics-loop-for-look-at limb args)))
       (:collision-avoidance-links
	(user::forward-message-to
	 (assocdr limb collision-avoidance-links-alist)
	 ;;(cdr (assoc (intern (format nil "~A-COLLISION-AVOIDANCE-LINKS"
	 ;;(string-upcase limb))) (send self :slots)))
	 args))
       (:links ;; (send self :limb limb nil))
	(user::forward-message-to (assocdr limb lst-alist) args))
       (:joint-list (send-all (send self :limb limb :links) :joint))
       (:gripper (send* self :gripper limb args))
       (:joint-order (send self :joint-order limb))
       (:cameras (send self :get-sensors-method-by-limb :cameras limb))
       (:imu-sensors (send self :get-sensors-method-by-limb :imu-sensors limb))
       (:force-sensors (send self :get-sensors-method-by-limb :force-sensors limb))
       (:pressure-sensors (send self :get-sensors-method-by-limb :pressure-sensors limb))
       (:proximity-sensors (send self :get-sensors-method-by-limb :proximity-sensors limb))
       (:button-sensors (send self :get-sensors-method-by-limb :button-sensors limb))
       (t
	(cond
	  ((or (null method) (send bodyset-link :method method))
	   (if method
	       (send-all (assocdr limb lst-alist) method)
	       (assocdr limb lst-alist)))
	  (t
	   (let ((limb-joint-name
		  (intern (format nil "~A-~A" (string-upcase limb)
				  (string-upcase method)) *keyword-package*)))
	     (if (find-method self limb-joint-name)
		 (user::forward-message-to (send self limb-joint-name) args)
	       (warn ";; error: cannot find method ~A~%" method))
	     ))))
       ) ;; case method
     )) ;; defmethod
  
  (:add-gripper-p
   (&key head-sensor &aux (l (car lst)))
   (let* ((ls (kxr-fingers-links :l/r :head :sensor head-sensor))
	  (l0 (car ls)) (l1 (cadr ls)))
     (send l1 :translate (float-vector 0 0 (sqrt (+ (* 21 21) (* 10.5 10.5)))) :world)
     (send l0 :assoc l1)
     (send l0 :rotate (+ (deg2rad -45) (atan2 10.5 21.0)) :y)
     (send self :push-joint :head "gripper" :y -100 100 :child-link l0 :parent-link l)
     (send self :push-joint :head "gripper2" :-y -100 100 :child-link l1 :parent-link l :parent-name nil :active nil)
     (setq head-end-coords (make-cascoords :rot (rotation-matrix (atan2 -10.5 21.0) :y)
					   :pos (send l0 :worldpos)))
     (send head-end-coords :translate (float-vector -1 0 18) :local)
     l))
  (:add-gripper-y
   (&key head-sensor)
   (let* ((ls (kxr-fingers-links :l/r :head :magbase (eq :mag-irsensor head-sensor)))
	  (l0 (car ls)) (l1 (cadr ls))
	  j l (g (kxr-gripper-servo-bodyset :straight t :base-b nil)))
     (send g :rotate pi :y :world)
     (setq l (send self :add-link (kxr-link-create (send g :bodies) :joint-coord (get g :joint-coord))
		   :target-link body-link))
     ;;(format t ";;;; l=~A (get l :joint-coord) =~A ;;;;~% " l (get l :joint-coord))
     (send l1 :translate (float-vector 0 0 (sqrt (+ (* 21 21) (* 10.5 10.5)))) :world)
     (send l0 :assoc l1)
     (send l0 :rotate pi/2 :x :world)
     (send l0 :rotate -pi/2 :y :world)
     (send l0 :locate (send (get l :joint-coord) :worldpos))
     ;;
     (setq j (send self :push-joint :head "gripper" :y -100 100 :child-link l0
		   :parent-link l :parent-name :joint-coord))
     ;;(format t ";;;;;;;;;;;;;;;;; l=~A (l . joint)=~A ;;;;~% links=~A joint-list=~A" l (l . joint) links joint-list)
     ;;(setq (l . joint) j)
     (send self :push-joint :head "gripper2" :-y -100 100
	   :child-link l1 :parent-link l :parent-name nil :active nil)
     ;;(format t ";;;;;;;;;;;;;;;;; l=~A ;;;;;;;;;;; ~% links=~A joint-list=~A" l links joint-list)
     (setq head-end-coords (make-cascoords :rot (rotation-matrix (atan2 -10.5 21.0) :y)
					   :pos (send l0 :worldpos)))
     (send head-end-coords :translate (float-vector -1 0 18) :local)
     l))
  (:limb-top-link (limb) (or (car (last (send self limb))) body-link))
  (:torso-top-link () (or (car (last (assocdr :torso lst-alist))) body-link))
  (:neck-top-link () (or (car (last (assocdr :neck lst-alist))) (send self :torso-top-link)))
  (:setup-tail ;; kxr-robot
   (&rest args &key stand ((:body bod)) tail &allow-other-keys)
   (when
       tail
     (setq lst nil jlst nil)
     (send self :push-joint :tail "roll" :x -120 120 :parent-link body-link ;; (send self :torso-top-link)
	   :parent-name :tail :child-link (kxr-l2-neck-base-link :apply-list (list (list :rotate -pi/2 :y :world))))
     (case
	 tail
       (:t2
	(send self :push-joint :tail "roll" :y -120 120
	      :child-link (kxr-l2-head-link :head nil :len 26 :apply-list (list (list :rotate -pi/2 :y :world))))
	))
     (setq tail (reverse lst))
     (push (cons :tail (car tail)) root-link-alist)
     (push (cons :tail tail) lst-alist)
     (push (cons :tail (reverse jlst)) jlst-alist)
     ))
  (:setup-neck ;; kxr-robot
   (&rest args &key stand neck-jf ((:body bod)) torso neck-p-sensor horn
	  (neck :y-p) head-b (neck-axis :p) (head-length 26) ((:head hd)) m5stack &allow-other-keys)
   (let (n)
     (setq lst nil jlst nil)
     (when neck  ;; hd 2025
       (cond
	 ((memq bod '(:backpack))
	  (send self :add-link 
		(kxr-link-create (setq n (kxr-servo-bottom-supporter-bodyset :flip-axis :x)))
		:parent-name :joint-coord :target-link body-link)
	  (setf (get body-link :neck) (get n :joint-coord))
	  )
	 ((and (eq bod :l4b) (null stand))
	  (send self :push-joint :head "neck" :x -170 170
		:parent-link (send self :torso-top-link)
		:parent-name :neck :child-link 
		(kxr-l2-neck-base-link :rotate (eq hd :realsense-y) :base-b (eq neck-jf :b) :pitch t))
	  )
	 ((memq torso '(:y-p-y :dy-p :dy-p2 :dy-p3 :ly-p :ly-pf :ly-p-high))
	  (unless (null neck) (setq neck :p))))
       (format t ";; neck=~A self=~A~%" neck self)
       (case
	neck
	(:y
	 (send self :push-joint :head "neck" :z -170 170
	       :parent-link (setq n (send self :torso-top-link))
	       :parent-name (if (get n :neck) :neck :joint-coord)
	       :child-link 
	       (kxr-l2-neck-base-link :servo nil :rotate (eq hd :realsense-y)
				      :base-b neck-jf ;; (eq neck-jf :b)
				      ;; :sensor neck-p-sensor
				      :horn t
				      ))
	 )
	((:y-p :y-p-no-horn)
	 (send self :push-joint :head "neck" :z -170 170
	       :parent-link (setq n (send self :torso-top-link))
	       :parent-name (if (get n :neck) :neck :upper-coord)
	       :child-link 
	       (kxr-l2-neck-base-link :rotate (eq hd :realsense-y) :base-b neck-jf :horn t))
	 (send self :push-joint :head "neck" :y -120 120 :child-link
	       (kxr-l2-head-link :roll (and (eq bod :l4b) (null stand)) :head nil :len head-length))
	 )
	(:y-r-p ;;(:m5u3s :m5u3s2 :m5u3sv2 :m5u3sb)
	 (if (and (eq bod :l4b) (null stand))
	     (send self :push-joint :head "neck" :x -170 170 :parent-link (send self :torso-top-link)
		   :parent-name :neck :child-link
		   (kxr-arm-base-link :from :z :to :x :len 28 :apply-list (list (list :rotate pi/2 :y :world))))
	   (send self :push-joint :head "neck" :z -170 170 :parent-link (send self :torso-top-link)
		 :parent-name :neck :child-link (kxr-arm-base-link :from :z :to :x :len 28)))
	 (if (and (eq bod :l4b) (null stand))
	     (send self :push-joint :head "neck" :z -120 120 :child-link
		   (kxr-cross-servo-link :apply-list (list (list :rotate -pi/2 :y :world) )))
	   (if (eq hd :m5u3sb)
	       (send self :push-joint :head "neck" :x -120 120 :child-link
		     (kxr-cross-servo-link :apply-list (list (list :rotate pi :x :world) (list :rotate pi :z :world))))
	     (send self :push-joint :head "neck" :x -120 120 :child-link
		   (kxr-cross-servo-link :apply-list (list (list :rotate pi :x :world))))))
	 (send self :push-joint :head "neck" :y -120 120
	       :child-link (kxr-l2-head-link :roll (and (eq bod :l4b) (null stand))
					     :head nil :len 38))
	 )
	(:y-p-r ;; (:h3s :h3sn :h3sl :h3sh :h3sv :h3svo :h3svi)
	 (if (and (eq bod :l4b) (null stand))
	     (send self :push-joint :head "neck" :x -170 170 :parent-link (send self :torso-top-link)
		   :parent-name :neck :child-link
		   (kxr-arm-base-link :from :z :to :y :len 38 :apply-list (list (list :rotate pi/2 :y :world))))
	   (send self :push-joint :head "neck" :z -170 170 :parent-link (send self :torso-top-link)
		 :parent-name :neck :child-link
		 (kxr-arm-base-link :from :z :to :y :len 38)))
	 (send self :push-joint :head "neck" :y -120 120 :child-link
	       (if (and (eq bod :l4b) (null stand))
		   ;;(kxr-cross-servo-link :apply-list (list (list :rotate pi :z :world)))
		   (kxr-cross-servo-link :apply-list (list (list :rotate pi :z :world) (list :rotate pi/2 :y :world)))
		 (kxr-cross-servo-link)))
	 (send self :push-joint :head "neck" :x -120 120
	       :child-link (kxr-l2-head-link :roll (and (eq bod :l4b) (null stand))
					     :apply-list (list (list :rotate pi/2 :z :world))
					     :head nil :len 28))
	 )
	(:y-p-p-p
	 (send self :push-joint :head "neck0" :z -170 170 :parent-link (send self :torso-top-link)
	       :parent-name :neck :child-link
	       (kxr-arm-base-link :from :z :to :-y :len 38))
	 ;;(format t ";;;; parent-link=~A (parent-link . joint)=~A ~%" (send self :torso-top-link)
	 ;;((send self :torso-top-link) . joint))
	 (send self :push-joint :head "neck0" :y -140 140 :child-link
	       (kxr-kxrl4n-neck1-link))
	 ;;(format t ";;;; (car lst)=~A ((car lst) . joint)=~A ~%" (car lst) ((car lst) . joint))
	 (send self :push-joint :head "neck1" :y -140 140
	       :child-link
	       (kxr-kxrl4n-neck2-link))
	 (let* ((l0 (kxr-arm-base-link :from :-z :to :y :len 38 :horn nil))
		l (c (make-cascoords)))
	   (send l0 :assoc c)
	   (send l0 :translate (v- (send (get l0 :joint-coord) :worldpos)) :world)
	   (setq l (kxr-link-create (send l0 :bodies) :joint-coord c))
	   (setf (get l :joint-coord) c)
	   (send l :assoc (get l :joint-coord))
	   (send self :push-joint :head "neck2" :y -140 140 :child-link l)
	   ))
	(:p
	 (send self :push-joint :head "neck" :y -120 120
	       :parent-link (setq n (send self :torso-top-link))
	       :parent-name (if (get n :neck) :neck :joint-coord)
	       :child-link (kxr-l2-head-link :roll (and (eq bod :l4b) (null stand))
					     ;; :sensor neck-p-sensor
					     :head nil :len head-length))
	 ))
       (case
	   hd
	 ((:h3 :h3-new)
	  ;;(pop lst) (pop jlst)
	  ;;(send self :push-joint :head "neck" :y -120 120 :child-link (kxr-l2-head-link :head nil :len head-length))
	  (send self :add-link (if (eq hd :h3) (kxr-l2-neck-base-r-link) (kxr-l2-neck-base-link))))
	 (:d
	  (pop lst) (pop jlst) (pop lst) (pop jlst)
	  (send self :push-joint :head "neck" :y -120 120 :parent-link (send self :torso-top-link)
		:parent-name :neck
		:child-link (kxr-l4d-neck-link :long t))
	  ;;(send self :add-link (kxr-l4d-neck-link :long t))
	  )
	 (:d1
	  (pop lst) (pop jlst)
	  (send self :push-joint :head "neck" :y -120 120 :child-link (kxr-l4d-neck-link :long t))
	  )
	 (:d2
	  (pop lst) (pop jlst)	  
	  (send self :push-joint :head "neck" :y -120 120 :child-link
		(kxr-double-arm-base-link :l/r :head :up 38 :low 38 :angle pi))
	  (send self :push-joint :head "head" :y -120 120 :child-link (kxr-l4d-neck-link))
	  )
	 (:h0 (pop lst) (pop jlst))
	 )
       )
     ;;(setq neck-end-coords (get (car lst) :joint-coord))
     ;;(push (cons :neck neck-end-coords) end-coords-alist)
     ;;(push (cons :neck (car (reverse lst))) root-link-alist)
     ;;(push (cons :neck (reverse lst)) lst-alist)
     ;;(push (cons :neck (reverse jlst)) jlst-alist)
     ))
  (:setup-head ;; kxr-robot
   (&rest args &key stand neck-jf ((:body bod)) torso (eye-length 26) (eye-y-rotate 3) (lego-bar 13)
	  neck head-sensor (neck-axis :p) head-b head-b-front (3eye-rev 8) (3eye-front t) (3eye-cover t)
	  head-lidar (head-length 26) ((:head hd)) m5stack (m5stickv t) &allow-other-keys)
   (let (l hc hl leye reye)
     (case
	 hd
       ((:d :d1 :d2)
	(send self :add-gripper-p :head-sensor head-sensor))
       ((:gripper-y)
	(setq lst nil jlst nil)
	(send self :add-gripper-y :head-sensor nil))
       ((:my3eye)
	;;(send self :push-joint :head "neck" :y -120 120 :parent-link (send self :neck-top-link)
	;;:child-link (kxr-l2-head-link :head nil :len head-length))
	(send self :push-joint :head "neck" :z -120 120 :child-link
	      (m5stickhead-3eye-link :y-servo t :rev 3eye-rev :front 3eye-front :cover 3eye-cover))
	)
       (:realsense-y
	(setq l (kxr-l2-head-link :head (kxr-head-sensor hd) :len head-length))
	(send l :rotate pi/2 :y :world)
	(send self :push-joint :head "neck" :y -120 120 :child-link l
	      :parent-link (send self :neck-top-link)))
       (:h0 (when (get body-link :neck) (setq hc (get body-link :neck))))
       (:h1 )
       ((:h3 :h3-new)
	(setq hl (if (eq hd :h3) (kxr-mamoru-head-link :len head-length)
		     (kxr-mamoru-head-link-new :len head-length)))
	(send self :push-joint :head "neck" :x -120 120 :child-link hl)
	(setq leye (if (eq hd :h3) (kxr-mamoru-leye-link) (kxr-mamoru-leye-link-new)))
	(send self :push-joint :head "leye" :z -90 90 :child-link leye :parent-name :leye)
	(setq reye (if (eq hd :h3) (kxr-mamoru-reye-link) (kxr-mamoru-reye-link-new)))
	(send self :push-joint :head "reye" :z -90 90 :parent-link hl :parent-name :reye :child-link reye)
	(setq cameras (append (get leye :cameras) (get reye :cameras)))
	(send (car cameras) :name "leye") (send (cadr cameras) :name "reye")
	cameras)
       ((:h2s :h2sf :h2sn :h2sl :h2sh :h2sv :h2svo :h2svi)
	(let ((l (if (and (eq bod :l4b) (null stand))
		     (kxr-yaw-double-servo-link :base nil :rotate t :roll t)
		     (if (eq hd :h2sf)
			 (kxr-yaw-double-servo-flat-link :base nil)
			 (kxr-yaw-double-servo-link :base nil :rotate t)))))
	  (send self :add-link l)
	  (dolist (n '(:leye :reye)) (setf (get (car lst) n) (get l n)))
	  (setq l (car lst))
	  (send self :push-joint :head "leye" :z -90 90 :parent-link l
		:parent-name :leye
		:child-link (setq leye (kxr-m5stickv-eye-link :l/r :leye :len eye-length
							      :front (eq-memq hd '(:h2sn :h2snl :h2snh))
							      :vertical (eq-memq hd '(:h2sv :h2svo :h2svi))
							      :frame (case hd (:h2sl :low) (:h2sh :high)
									   (:h2svo :out) (:h2svi :in)))))
	  (send self :push-joint :head "reye" :z -90 90 :parent-link l
		:parent-name :reye
		:child-link (setq reye (kxr-m5stickv-eye-link :l/r :reye :len eye-length
							      :front (eq-memq hd '(:h2sn :h2snl :h2snh))
							      :vertical (eq-memq hd '(:h2sv :h2svo :h2svi))
							      :frame (case hd (:h2sl :low) (:h2sh :high)
									   (:h2svo :out) (:h2svi :in)))))
	  (setq cameras (append (get leye :cameras) (get reye :cameras)))
	  (send-all cameras :rotate (deg2rad eye-y-rotate) :y)
	  (send (car cameras) :name "leye") (send (cadr cameras) :name "reye")
	  cameras))
       (nil (when (get body-link :neck) (setq hc (get body-link :neck))))
       (t ;;(:e :m5 :m5s :m5sh :realsense :m5h :m5i :ir :m3eye :h2-auv :h2
	;; :m5u3s :m5u3s2 :m5u3sv2 :m5u3sb :m5us :m5u2s :m5usv2)
	(let ((h 
	       (kxr-head-sensor hd :lego-bar lego-bar :m5stack m5stack :3eye-rev 3eye-rev
				:front 3eye-front :cover 3eye-cover
				:m5stickv m5stickv :lidar head-lidar)
		:target-link (send self :neck-top-link)))
	  (send self :add-link h :add-props (list :cameras))
	  (dolist (c (get h :cameras)) (send (car lst) :assoc c))
	  )
	))
     (when (or hd neck)
       (unless head-end-coords
	 (cond
	  ((> (length cameras) 1) ;; stereo head
	   (if hl
	       (setq hc (get hl :joint-coord))
	     (setq hc (get (send self :neck-top-link) :joint-coord))))
	  ((null hc) (setq hc (get (car lst) :joint-coord))))
	 (if (null hc)
	     (format t ";; alarm! head-end-coords becomes body-link origin~%"))
	 (setq head-end-coords
	       (make-cascoords :pos (if hc (send hc :worldpos) (float-vector 0 0 0))
			       :rot (m*
				     (rotation-matrix pi/2 :y)
				     (rotation-matrix -pi/2 :z))
			       :name :head-end-coords)))
       (unless cameras
	 (setq cameras (get (car lst) :cameras)))

       (when cameras
	 ;;(format t ";;; debug inaba cameras=~A~%" cameras)
	 (setq head-end-coords
	       (make-cascoords :pos
			       (if (> (length cameras) 1)
				   (apply #'midpoint 0.5 (send-all cameras :worldpos))
				 (car (send-all cameras :worldpos)))
			       :rot (m*
				     (rotation-matrix pi/2 :y)
				     (rotation-matrix -pi/2 :z))
			       :name :head-end-coords))
	 )
       (cond
	((and cameras (cdr lst) (caddr lst))
	 (send (caddr lst) :assoc head-end-coords))	 
	(lst
	 (send (car lst) :assoc head-end-coords))
	((get body-link :neck)
	 (send (get body-link :neck) :assoc head-end-coords)))
       ;;
       (push (cons :head head-end-coords) end-coords-alist)
       (setq head (reverse lst))
       (push (cons :head (car head)) root-link-alist)
       (push (cons :head head) lst-alist)
       (push (cons :head (reverse jlst)) jlst-alist)
       )
     ))
  (:setup-body
   (&rest args &key ((:body bod) :l2l5) ((:head hd)) stand backpack tail nobody
	  (body-x 200) (body-y 250) (body-z 200) (body-segments 10)
	  crotch-front crotch-p crotch-low (flat-crotch t) narrow-crotch
	  crotch-center-front crotch-side-front limb
	  lidar shoulder end shoulder-center shoulder-low
	  (backpack-function 'kxr-back-pack)
	  flat-shoulder shoulder-front neck-front battery-box
	  wheel-battery-stand wheel-base-a wheel-base-wide wheel-servo-stand
	  wing neck-jf ((:torso trso)) (waist-cut t) &allow-other-keys)
   (setq lst nil jlst nil)
   (when nobody (setq bod :bodyplate))
   (case
    bod
    ;; crotch-axis = pitch, shoulder-axis = pitch
    (:l4b (if stand
	      (setq body-link (kxr-l4b-body-stand-link :head hd :base-b (eq neck-jf :b) :shoulder-front t :neck-front t :tail tail))
	    (setq body-link (kxr-l4b-body-horizontal-link :head hd :base-b (eq neck-jf :b) :torso trso))))
    (:l4d (if stand
	      (setq body-link (kxr-l4d-body-stand-link :head hd :base-b (eq neck-jf :b)))
	      (setq body-link (kxr-l4d-body-horizontal-link :head hd :base-b (eq neck-jf :b) :torso trso))))
    ;;(:backpack (setq body-link (kxr-link-create (list (kxr-back-pack)) :joint-coord (make-cascoords))))
    (:backpack (setq body-link (kxr-link-create (list (kxr-back-pack)) :joint-coord "uph0"))
	       (setf (get body-link :neck) (get body-link :joint-coord))
	       (setf (get body-link :torso) (get body-link :joint-coord))
	       )
    (:bodyplate (let ((p (kxr-body-plate)))
		  (setq body-link (kxr-link-create (list p) :joint-coord (get p :joint-coord)))
		  (setf (get body-link :neck) (get body-link :joint-coord))
		  (setf (get body-link :torso) (get body-link :joint-coord)))
		)
    (:flatplate (let ((p (kxr-body-plate)))
		  (setq body-link (kxr-link-create (list p) :joint-coord (get p :joint-coord)))
		  (setf (get body-link :neck) (get body-link :joint-coord))
		  (setf (get body-link :torso) (get body-link :joint-coord)))
		)
    (:board
      (let* ((bs (kxr-armh7-board-bodyset)) imu)
	(setq body-link (kxr-link-create (send bs :bodies) :joint-coord (make-cascoords)))
	(setq imu (send body-link :find-named-body "imu"))
	(when imu
	  (send self :setup-gsensor (make-cascoords :name "gsensor" :coords (send imu :worldcoords)))
	  (send self :setup-gyrometer (make-cascoords :name "gyrometer" :coords (send imu :worldcoords))))
	))
     ;; crotch-axis = pitch
     (:dyp  (setq body-link (kxr-l2-dyp-waist-link)))
     (:dyp-z  (setq body-link (kxr-l2-dyp-z-waist-link)))
     (:dyp-zf  (setq body-link (kxr-l2-dyp-z-waist-link t)))
     (:lyp-low (setq body-link (kxr-l2-lyp-waist-link :low-axis t)))
     (:lyp-high (setq body-link (kxr-l2-lyp-waist-link :low-axis nil)))
     ;; crotch-axis = yaw
     (:l2l6b
      (setq body-link (kxr-l4b-body-stand-link
		       :shoulder-front shoulder-front :shoulder-low shoulder-low :flat-shoulder flat-shoulder
		       :neck-front neck-front :tail nil
		       :flat-crotch flat-crotch :crotch-front crotch-front :crotch-p crotch-p
		       :crotch-low crotch-low)))
     (:l2l6 (setq body-link (kxr-l2l6-body-link
			     :wide-crotch nil :rotate-crotch nil :shoulder-center shoulder-center
			     :shoulder-servo (not (eq shoulder :ypry-cross))
			     :shoulder-front shoulder-front :neck-front neck-front))
	    (when end
	      (send self :add-link (kxr-mag-link end) :target-link body-link :parent-name :lleg)
	      (send self :add-link (kxr-mag-link end) :target-link body-link :parent-name :rleg))
	    )
     (:l2l6w (setq body-link (kxr-l2l6-body-link
			      :wide-crotch t :rotate-crotch nil :shoulder-center shoulder-center
			      :shoulder-servo (not (eq shoulder :ypry-cross))
			      :shoulder-front shoulder-front :neck-front neck-front)))
     (:l2l6m (setq body-link (kxr-l2l6-body-link
			      :mag-plate t :wide-crotch (not narrow-crotch)
			      :rotate-crotch nil :shoulder-center shoulder-center
			      :shoulder-servo (not (eq shoulder :ypry-cross))
			      :shoulder-front shoulder-front :neck-front neck-front)))
     (:l2l6base (setq body-link (kxr-l2l6-body-link
				 :no-upper-body t
				 :mag-plate t :wide-crotch (not narrow-crotch)
				 :rotate-crotch nil :shoulder-center shoulder-center
				 :shoulder-servo (not (eq shoulder :ypry-cross))
				 :shoulder-front shoulder-front :neck-front neck-front)))
     ((:t1l2l6base :t1l2l5base :t1l2l2base)
      (setq body-link (kxr-l2l6-cut-waist-link
		       :center-front t :side-front t :torso-origin t)))
     (:l2l6r (setq body-link (kxr-l2l6-body-link
			      :wide-crotch nil :rotate-crotch t :shoulder-center shoulder-center
			      :shoulder-servo (not (eq shoulder :ypry-cross))
			      :shoulder-front shoulder-front :neck-front neck-front)))
     (:l2l6c (setq body-link (kxr-l2l6-cut-waist-link
			      :center-front (or crotch-center-front
						(eq trso :y-r))
			      :side-front crotch-side-front)))
     (:l2l6s (setq body-link (kxr-l2w2-body-link
			      :shoulder-front shoulder-front
			      :crotch-front crotch-front
			      :shoulder-center shoulder-center)))
     ;;
     (:l2w2 (setq body-link (kxr-l2w2-body-link :shoulder-front t)))
     ;; crotch-axis = roll
     (:l2l5a (setq body-link (kxr-l2l5-body-link
			      :leg-arms nil
			      :backpack (funcall backpack-function) :neck-front neck-front
			      :shoulder-servo (not (eq shoulder :ypry-cross))
			      :shoulder-center shoulder-center :shoulder-front shoulder-front))
	     (when end
	       (let* ((l1 (kxr-mag-link end))
		      (h (elt (send (send l1 :bounding-box) :diagonal) 2))
		      (l2 (kxr-mag-link end)))
		 (send l1 :name "lleg-mag") (send l2 :name "rleg-mag")
		 (send self :add-link l1 :target-link body-link :parent-name :lleg)
		 (send self :add-link l2 :target-link body-link :parent-name :rleg)
		 (setf (get body-link :mbase)
		       (make-cascoords :pos (midpoint 0.5
						      (send l1 :worldpos)
						      (send l2 :worldpos))))
		 (send (get body-link :mbase) :translate (float-vector 0 0 (- h)) :world)
		 (send (get body-link :lleg) :translate (float-vector 0 0 (- h)) :world)
		 (send (get body-link :rleg) :translate (float-vector 0 0 (- h)) :world)
		 ))
	     )
     (:l2l5 (setq body-link (kxr-l2l5-body-link
			     :leg-arms t
			     :backpack (funcall backpack-function) :neck-front neck-front
			     :shoulder-servo (not (eq shoulder :ypry-cross))
			     :shoulder-center shoulder-center :shoulder-front shoulder-front))
	    )
     (:l2l5m (setq body-link (kxr-l2l5-body-link
			      :leg-arms nil
			      :backpack (funcall backpack-function) :neck-front neck-front
			      :mag-plate t :shoulder-servo (not (eq shoulder :ypry-cross))
			      :shoulder-center shoulder-center :shoulder-front shoulder-front))
	     )
     (:l2l5base (setq body-link (kxr-l2l5-body-link
				 :leg-arms t :no-upper-body t
				 :backpack (funcall backpack-function) :neck-front neck-front
				 :mag-plate t :shoulder-servo (not (eq shoulder :ypry-cross))
				 :shoulder-center shoulder-center
				 :shoulder-front shoulder-front))
	     )
     ;; crotch-axis = yaw
     (:l4m (setq body-link (kxr-mamoru-body-link :torso trso)))
     (:l4m2 (setq body-link (kxr-mamoru-body-link-new :torso trso)))
     (:l4m3 (setq body-link (kxr-mamoru-body-link-new-2022 :torso trso)))
     (:l4c (setq body-link (kxr-l4tr-body-link :torso :dualarm :backpack nil :neck nil)))
     (:l4t (setq body-link (kxr-l4tr-body-link :torso trso :backpack t :neck t)))
     (:l4tbase (setq body-link (kxr-l4tr-body-link :backpack nil :neck nil :magmodule t
						   :neck-origin t :battery-box battery-box)))
     (:t1l4tbase (setq body-link (kxr-l4tr-body-link :backpack nil :magmodule nil
						     :neck-origin t
						     :neck-align (not neck-front))))
     (:l4mw-kuro
      (setq body-link
	    (kxr-tsm-body-link
	     :x body-x :y body-y :z body-z :segments body-segments
	     :shoulder-front shoulder-front :shoulder-center shoulder-center
	     :servo-stand wheel-servo-stand
	     :wheel-base-a wheel-base-a :wheel-base-wide wheel-base-wide)))
     (:l4mw-kashi
      (setq body-link
	    (kxr-tsm-body-link
	     :x body-x :y body-y :z body-z :segments body-segments
	     :shoulder-front shoulder-front :shoulder-center shoulder-center
	     :servo-stand wheel-servo-stand
	     :wheel-base-a wheel-base-a :wheel-base-wide wheel-base-wide)))
     (:l4mw (setq body-link (kxr-l4mw-body-link
			     :shoulder-front shoulder-front :shoulder-center shoulder-center
			     :shoulder-servo (not (eq shoulder :ypry-cross))
			     :backpack (funcall backpack-function)
			     :servo-stand wheel-servo-stand :lidar lidar
			     :battery-stand wheel-battery-stand :base-a wheel-base-a :base-wide wheel-base-wide)))
     (:l4ow (setq body-link (kxr-l4ow-body-link
			     :shoulder-front shoulder-front :shoulder-center shoulder-center
			     :shoulder-servo (not (eq shoulder :ypry-cross))
			     :backpack (funcall backpack-function)
			     :battery-stand wheel-battery-stand :lidar lidar)))
     (:l4dw (setq body-link (kxr-l4dw-body-link
			     :shoulder-front shoulder-front :shoulder-center shoulder-center
			     :shoulder-servo (not (eq shoulder :ypry-cross))
			     :backpack (funcall backpack-function)
			     :battery-stand wheel-battery-stand :lidar lidar
			     )))
     (:l6  (setq body-link (kxr-l6-body-link :neck neck-jf :backpack backpack)))
     (:l6base (setq body-link (kxr-l6-body-link :neck neck-jf :backpack nil :magmodule t)))
     (:t1l6base (setq body-link (kxr-l6-body-link :neck t :backpack nil :magmodule nil
						  :torso-origin t)))
     (:mw4base
      (setq body-link
	    (kxr-l4mw-body-link
	     :no-upper-body t :magmodule t ;; :mag-joint :mag+7
	     :servo-stand wheel-servo-stand :lidar lidar
	     :battery-stand wheel-battery-stand :base-a wheel-base-a
	     :base-wide wheel-base-wide)))
     (:t1mw4base
      (setq body-link
	    (kxr-l4mw-body-link
	     :no-upper-body t :magmodule nil :torso-origin t :neck-front t
	     :servo-stand nil :lidar lidar :battery-stand nil :base-a wheel-base-a
	     :base-wide wheel-base-wide)))
     (:ow4base
      (setq body-link
	    (kxr-l4ow-body-link
	     :no-upper-body t :magmodule t ;; :mag-joint :mag+7
	     :battery-stand wheel-battery-stand :lidar lidar)))
     (:t1ow4base
      (setq body-link
	    (kxr-l4ow-body-link
	     :no-upper-body t :magmodule nil :torso-origin t :neck-front t
	     :battery-stand nil :lidar t)))
     (:dw4base
      (setq body-link
	    (kxr-l4dw-body-link
	     :no-upper-body t :magmodule t ;; :mag-joint :mag+7
	     :battery-stand wheel-battery-stand :lidar lidar)))
     (:t1dw4base
      (setq body-link
	    (kxr-l4dw-body-link
	     :no-upper-body t :magmodule t :torso-origin t :neck-front t
	     :battery-stand wheel-battery-stand :lidar nil)))
     (:magbase (setq body-link (kxr-twinmagbase-link)))
     (:magbase-n (setq body-link (kxr-twinmagbase-link :narrow t)))
     (:limb (let* ((c (make-cube 10 10 10))
		   (p (kxr-make-kxr-body "dummy" c c nil :color :white)))
	      (setq body-link (kxr-link-create (list p) :joint-coord (get p :joint-coord)))
	      (setf (get body-link :neck) (get body-link :joint-coord))
	      (setf (get body-link :torso) (get body-link :joint-coord)))
	    )
     ((:mag-4 :mag-7 :mag+7 :horn-mag- :horn-mag+ :sensor-mag+ :horn-sensor-mag+)
      (setq body-link (kxr-mag-link bod)))
     )
   (when backpack
     (let ((bp (find-if #'(lambda (x) (substringp "back-pack" (send x :name)))
			(send body-link :bodies)))
	   bds m5)
       (case
	backpack
	((:m5 :m5fire)
	 (setq m5 (m5stackFIRE-bodyset))
	 )
	((:m5gray)
	 (setq m5 (m5stackGRAY-bodyset))
	 ))
       (when m5
	 (send m5 :move-named-coords "connect0" bp "uph1") 
	 (setq bds (send body-link :bodies))
	 (dolist (b (cdr bds)) (send (car bds) :assoc b))
	 (setq (body-link . geo::bodies) (append bds (send m5 :bodies))))
       ))
   
   (when wing
       (let ((wing-pos (float-vector -18 0 0)))
         (when (memq :wing-pos args)
           (setq wing-pos (cadr (memq :wing-pos args))))
	 (require :kxrextentions)
         (send self :add-link (main-shaft-link wing-pos) :parent-name :back-panel
               :target-link body-link
               :add-props (list :left-joint-coord :right-joint-coord))
       ))
   (send body-link :name (if limb
			     (format nil "~A-link-~A" (string-downcase (string limb)) (string-downcase (string bod)))
			   (format nil "torso-link-~A" (string-downcase (string bod)))))
   body-link)
  (:reset-manip-pose nil (send self :reset-pose 30))
  (:setup-wing ;; kxr-robot
   (&rest args &key type wing l/r &allow-other-keys)
   (let (l (axisy :y) c ec)
     (unless
	 (get self l/r)
       (setq lst nil jlst nil)
       (when wing
	 (send self :push-joint l/r 0 axisy -100 100
	       :parent-link body-link
	       :child-link (ducted-motor-link :l/r l/r :fan wing)
	       :parent-name (if (kxr-left-limb? l/r)
				:left-joint-coord :right-joint-coord))
	 (send self :push-joint l/r 0
	       (if (kxr-left-limb? l/r) :z :-z) -100 100
	       :joint-type :thrust
	       :climit 30  ;; A
	       :gear-ratio 1
	       :torque-const 0.0043 ;; Nm/A
	       :max-joint-torque (* 0.0043 30)
	       :child-link (ducted-fan-link :l/r l/r :fan wing)))
       ;; end-coords
       (setq ec (make-cascoords
		 :rot (rotation-matrix 0 :x)
		 :pos (send (get (car lst) :joint-coord) :worldpos)
		 :name (format nil "~A-end-coords" l/r)))
       (push (cons l/r ec) end-coords-alist)
       (send (car lst) :assoc ec)
       (unless (assoc l/r end-coords-alist)
	 (push (cons l/r c) end-coords-alist))
       (send self :ln-ending type l/r nil nil nil (car lst)) ;; :setup-wing
       ))
   )
  (:setup-torso ;; kxr-robot
   (&rest args &key (neck-axis :p) ((:torso trso)) wing passive-wheel chest-p-sensor
	  ((:body bod)) neck-front shoulder shoulder-center shoulder-front
	  noarm chest-worm (waist-len 38) &allow-other-keys)
   (let (l j)
     (setq lst nil jlst nil)
     (when trso
       (case
	 trso
       ((:ly-pfy) 	;; pitch-yaw torso link
	(send self :push-joint :torso "chest" :z -181 181 :parent-link body-link
	      :parent-name :torso
	      :child-link (kxr-l2-lyp-chest-base-link :len waist-len))
	(send self :push-joint :torso "chest" :y -120 120
	      :child-link (kxr-l2-lypy-chest-link :front t :rotate nil)))
       ((:ly-pf :ly-pf-high) 	;; low-cost chest front
	(send self :push-joint :torso "chest" :z -181 181 :parent-link body-link
	      :parent-name :torso :child-link
	      (if chest-worm
		  (kxr-worm-rotation-link :apply-list `((:rotate ,pi :z :world)))
		  (kxr-l2-lyp-chest-base-link :len (if (eq trso :ly-p-high) 38 26))))
	(send self :push-joint :torso "chest" :y -120 120
	      :child-link (kxr-l2-lyp-chest-link :front t :side-up t
						 :bottom-arm chest-worm)))
       ((:ly-p :ly-p-high) 	;; low-cost chest
	(send self :push-joint :torso "chest" :z -181 181 :parent-link body-link
	      :parent-name :torso :child-link
	      (if chest-worm
		  (kxr-worm-rotation-link :apply-list `((:rotate ,pi :z :world)))
		  (kxr-l2-lyp-chest-base-link :len (if (eq trso :ly-p-high) 38 26))))
	(send self :push-joint :torso "chest" :y -120 120
	      :child-link (kxr-l2-lyp-chest-link
			   :side-up t :bottom-arm chest-worm
			   :wheel-arms (eq-memq :torso passive-wheel)))
	(when (eq-memq :torso passive-wheel)
	  (setq l (pop lst) j (pop jlst))
	  (send self :push-joint :larm "shoulder" :w -120 120  :active nil
		:parent-link l :parent-name :lwheel
		:child-link
		(kxr-wheel-link :l/r :larm :offset (if (eq-memq :double passive-wheel) -6 0)
				:double (eq-memq :double passive-wheel) :horn nil))
	  (send self :push-joint :rarm "shoulder" :w -120 120  :active nil
		:parent-link l :parent-name :rwheel
		:child-link
		(kxr-wheel-link :l/r :rarm :offset (if (eq-memq :double passive-wheel) -6 0)
				:double (eq-memq :double passive-wheel) :horn nil))
	  (push l lst) (push j jlst)
	  )
	)
       ((:ly-pl :ly-pl-high) ;; low-cost chest single bottom-spacer
	(send self :push-joint :torso "chest" :z -181 181 :parent-link body-link
	      :parent-name :torso :child-link
	      (if chest-worm
		  (kxr-worm-rotation-link :apply-list `((:rotate ,pi :z :world)))
		  (kxr-l2-lyp-chest-base-link :len (if (eq trso :ly-p-high) 38 26))))
	(send self :push-joint :torso "chest" :y -120 120
	      :child-link (kxr-l2-lyp-chest-link :bottom-arm chest-worm)))
       ((:ly-plf :ly-plf-high) 	;; low-cost chest single bottom-spacer
	(send self :push-joint :torso "chest" :z -181 181 :parent-link body-link
	      :parent-name :torso :child-link
	      (if chest-worm
		  (kxr-worm-rotation-link :apply-list `((:rotate ,pi :z :world)))
		  (kxr-l2-lyp-chest-base-link :len (if (eq trso :ly-p-high) 38 26))))
	(send self :push-joint :torso "chest" :y -120 120
	      :child-link (kxr-l2-lyp-chest-link :front t :bottom-arm chest-worm)))
       ((:dy-p :dy-p2 :dy-p3) ;; kxrl2makabe differential chest
	(send self :push-joint :torso "chest" :z -181 181 :parent-link body-link
	      ;; :parent-name :joint-coord
	      :child-link (kxr-l2-dyp-chest-base-link))
	(send self :push-joint :torso "chest" :y -120 120 :child-link
	      (cond ((eq trso :dy-p)
		     (kxr-l2-dyp-chest-link :neck-axis neck-axis
					    :sensor chest-p-sensor))
		    ((eq trso :dy-p3)
		     (kxr-l2-dyp-chest-link
		      :frame (kxr-dyp-chest-frame-bodyset-orig) :neck-axis neck-axis))
		    (t
		     (kxr-l2-dyp-chest-link2 :neck-axis neck-axis)))))
       (:y-p-y  ;; normal y-p chest double shoulder :y new 2021.9.7
	(send self :push-joint :torso "chest" :z -170 170 :parent-link body-link
	      :parent-name :torso :child-link (kxr-l2-neck-base-link))
	(send self :push-joint :torso "chest" :y -120 120 :child-link
	      (kxr-l2-dyp-chest-link :frame (kxr-dyp-chest-frame-bodyset-orig)
				     :neck-axis neck-axis :no-dyp t)))
       (:y-p  ;; normal y-p chest shoulder :p
	(send self :push-joint :torso "chest" :z -170 170 :parent-link body-link
	      :parent-name :torso
	      :child-link (if chest-worm
			      (kxr-worm-rotation-link)
			      (kxr-l2-neck-base-link)))
	(send self :push-joint :torso "chest" :y -120 120 :child-link
	      (kxr-l2l6-chest-link :front-cut nil :len 38)))
       (:y-r  ;; normal y-p chest shoulder :p
	(send self :push-joint :torso "chest" :z -170 170 :parent-link body-link
	      :parent-name :torso :child-link (kxr-l2-neck-base-r-link))
	(send self :push-joint :torso "chest" :x -120 120 :child-link
	      (kxr-l2l6-chest-r-link :len 38)))
       (:y-r-p
	(send self :push-joint  :torso "chest" :z -180 180 :parent-link body-link
	      :parent-name :torso :child-link (kxr-arm-base-link :from :z :to :x :len 28))
	(send self :push-joint  :torso "chest" :x -180 180 :child-link
	      (kxr-torso-cross-servo-link :no-backpack t))
	(send self :push-joint :torso "chest" :y -90 90 :child-link
	      (kxr-l2l6-chest-upperback-link :len 38)))
       (:p-r
	)
       (:y-p-r
	)
       (:y
	(send self :push-joint  :torso "chest" :z -180 180 :parent-link body-link
	      :parent-name :torso :child-link (kxr-twinmagbase-link :joint t))
	(unless noarm
	  (send self :add-link
		(kxr-l2l5-body-link
		 :leg-arms nil
		 :backpack t :neck-front neck-front
		 :mag-plate t :shoulder-servo (not (eq shoulder :ypry-cross))
		 :shoulder-center shoulder-center :shoulder-front shoulder-front)
		:add-props '(:larm :rarm :neck)))
	)
       )
       (when (and (not trso) (not (member type '(:l4 :module :l6))))
	 (warn ";; :setup-torso trso=~A bod=~A type=~A~%" trso bod type)
	 (send self :add-link
	       (kxr-l2l5-body-link
		:leg-arms nil
		:backpack t :neck-front neck-front
		:mag-plate t :shoulder-servo (not (eq shoulder :ypry-cross))
		:shoulder-center shoulder-center :shoulder-front shoulder-front)
	       :target-link body-link
	       :add-props '(:larm :rarm :neck)))
       (setq torso-end-coords (get (car lst) :joint-coord))
       (push (cons :torso torso-end-coords) end-coords-alist)
       (setq torso (reverse lst))
       (push (cons :torso (car torso)) root-link-alist)
       (push (cons :torso torso) lst-alist)
       (push (cons :torso (reverse jlst)) jlst-alist)
       (when (and wing trso)
	 (let ((wing-pos (float-vector -18 0 0)))
	   (when (memq :wing-pos args)
	     (setq wing-pos (cadr (memq :wing-pos args))))
	   (require :kxrextentions)
	   (send self :add-link (main-shaft-link wing-pos) :parent-name :back-panel
		 :target-link body-link
		 :add-props (list :left-joint-coord :right-joint-coord))
	   ))
       )))
  (:add-link-to-limb
   (add-child-link &key limb (offset (float-vector 0 0 0))
		   add-props replace &aux llinks)
   (if llinks 
       (send self :add-link add-child-link :target-link (car (last llinks))
	     :parent-name :joint-coord)
       (send self :add-link add-child-link :target-link body-link
	     :parent-name limb))
   )
  (:add-link
   (add-child-link &key (parent-name :joint-coord) (offset (float-vector 0 0 0))
		   (target-link (car lst)) add-props replace)
   (when target-link
     (let* ((l target-link) (tobs (send l :bodies))
	    (m 0) (mc (float-vector 0 0 0)) (frombs (send add-child-link :bodies)))
       (cond
	(replace
	 (send add-child-link :locate (v+ offset (send l :worldpos)) :world)
	 ;;(dolist (d (send add-child-link :descendants)) (send l :assoc d)) ;; 2024.1.6 for :robotset
	 ;;(dolist (d (send add-child-link :child-links)) (send l :assoc d))
	 (dolist (b frombs) (send (send l :parent) :assoc b))
	 (setq (l . geo::bodies) frombs)
	 )
	(t
	 (when (get l parent-name)
	   (send add-child-link :locate (v+ offset (send (get l parent-name) :worldpos)) :world)
	   ;;(dolist (d (send add-child-link :descendants)) (send l :assoc d)) ;; 2024.1.6 for :robotset
	   ;;(dolist (d (send add-child-link :child-links)) (send l :assoc d))
	   )
	 ))
       (dolist (b frombs) (send (car tobs) :assoc b))
       (setq (l . geo::bodies) (append tobs frombs))
       (dolist (b (send l :bodies))
	 (setq mc (v+ mc (scale (send b :weight) (send b :centroid))))
	 (setq m (+ m (send b :weight))))
       (setq (l . acentroid) (scale (/ 1.0 m) mc))
       (setq (l . weight) m)
       (dolist (p (append (list :joint-coord :origin-coord :upper-coord parent-name)
			  add-props))
	 (when (get add-child-link p)
	   (setf (get l p) (get add-child-link p))
	   (when (derivedp (get l p) cascaded-coords)
	     (send l :assoc (get l p)))))
       (when jlst
	 (send (send (car jlst) :parent-link) :assoc l))
       l)))
  (:reset-link
   (lnk)
   (when (and (derivedp lnk bodyset-link) (get lnk :org))
     (replace-object lnk (get lnk :org)))
   )
  (:add-link-try ;; create new link with :org link to be resettable
   (add-child-link &key (parent-name :joint-coord) (offset (float-vector 0 0 0))
		   (target-link (car lst)) add-props replace)
   (let* ((l target-link) (tobs (send l :bodies))
	  (m 0) (mc (float-vector 0 0 0)) (frombs (send add-child-link :bodies)))
     (setf (get l :org) (copy-object target-link))
     (cond
       (replace
	(send add-child-link :locate (v+ offset (send l :worldpos)) :world)
	(dolist (b frombs) (send (send l :parent) :assoc b))
	(setq (l . geo::bodies) frombs)
	)
       (t
	(if (get l parent-name)
	    (send add-child-link :locate (v+ offset (send (get l parent-name) :worldpos)) :world))
	(dolist (b frombs) (send (car tobs) :assoc b))
	(setq (l . geo::bodies) (append tobs frombs))))
     (dolist (b (send l :bodies))
       (setq mc (v+ mc (scale (send b :weight) (send b :centroid))))
       (setq m (+ m (send b :weight))))
     (setq (l . acentroid) (scale (/ 1.0 m) mc))
     (setq (l . weight) m)
     (dolist (p (append (list :joint-coord :origin-coord :upper-coord parent-name)
			add-props))
       (when (get add-child-link p)
	 (setf (get l p) (get add-child-link p))
	 (when (derivedp (get l p) cascaded-coords)
	   (send l :assoc (get l p)))))
     (when jlst
       (send (send (car jlst) :parent-link) :assoc l))
     l))
  (:create-joint
   (&optional limb i-str axis min max
	      &rest args
	      &key (joint-type (if (eq-memq axis '(:w :wx :wy :wz)) :wheel :hinge))
	      (max-joint-torque (* 12 9.8 (/ 1.0 100))) ;; Nm
	      ;; (max-joint-torque 0.7098) ;; Nm KRS3302
	      ;; (max-joint-torque 1.4726) ;; Nm KRS3304R2
	      (max-joint-velocity (/ (/ (* 2 pi) 6.0) 0.14 )) ;; rad/s
	      (gear-ratio 289.22)
	      (offset-v (float-vector 0 0 0))
	      (climit 4)
	      (torque-const (/ max-joint-torque climit gear-ratio))
	      (rotor-inertia 7.2e-9)
	      parent-link child-link (active t) (parent-name :joint-coord)
	      (axis-name
	       (if (eq joint-type :thrust) "w"
		 (case axis ((:x :-x) "r") ((:y :-y) "p") ((:z :-z) "y")
		       ((:w :-w :wx :wy :wz :-wx :-wy :-wz) "w"))))
	      (str (if (numberp i-str) (kxr-limb-joint-name limb i-str) i-str))
	      (name (read-from-string (format nil "~A-~A-~A" limb str axis-name)))
	      )
   (let* ((vaxis
	   (case axis
		 ((:x :xx :wx) #f(1 0 0)) ((:y :yy :w :wy) #f(0 1 0)) ((:z :zz :wz) #f(0 0 1))
		 ((:-x :-wx) #f(-1 0 0)) ((:-y :-w :-wy) #f(0 -1 0)) ((:-z :-wz) #f(0 0 -1))
		 (t axis)))
	  l j v1 v2)
     (when parent-link
       (send parent-link :worldcoords)
       (cond
	((null parent-name))
	((and (symbolp parent-name) (get parent-link parent-name))
	 (send (get parent-link parent-name) :worldcoords)
	 (send child-link :locate (v+ offset-v (send (get parent-link parent-name) :worldpos)) :world))
	((derivedp parent-name cascaded-coords)
	 (send child-link :locate (v+ offset-v (send parent-name :worldpos)) :world)))
       (send parent-link :assoc child-link))
     (send child-link :name (string-downcase (string name)))
     (setq j (instance rotational-joint :init :name name :axis vaxis
		       :min min :max max :parent-link parent-link :child-link child-link
		       :max-joint-torque max-joint-torque
		       :max-joint-velocity max-joint-velocity))
     (send j :put :axis-key axis)
     (send j :put :joint-name str)
     (if (member name name-joint-list) (error ";; duplicate name ~A~%" name))
     (push (cons name j) name-joint-list)
     ;;(setslot self (class self) (read-from-string (symbol-name name)) j)
     (send j :put :joint-method-name name)
     (send j :put :joint-type joint-type)
     (send j :put :active active)
     (send j :put :robot self)
     (send j :put :gear-ratio gear-ratio)
     (send j :put :climit climit)
     (send j :put :torque-Const torque-const)
     (send j :put :rotor-inertia rotor-inertia)
     j))
  (:push-joint
   (&optional limb i-str axis min max &rest args &key parent-link &allow-other-keys &aux j)
   (if (and (null parent-link) jlst) (setq parent-link (send (car jlst) :child-link)))
   (setq j (send* self :create-joint limb i-str axis min max :parent-link parent-link args))
   (push (send j :child-link) lst)
   (push j jlst)
   j)
  (:setup-arm
   (&rest args &key (l/r :larm) shoulder elbow wrist gripper gripper-axis passive-wheel
	  (shoulder-width 26) (upper-arm-length 26) (wrist-len 26) wrist-a driver
	  ((:body bod)) wrist-sensor gripper-sensor gripper-inner
	  ((:torso trso)) marm arm noarm mirrored &allow-other-keys)
   (let ((z-axis :z) (x-axis :x))
     (setq lst nil jlst nil)
     (if (and (get self :mirrored) (eq l/r :rarm)) (setq z-axis :-z x-axis :-x))
     (if arm (return-from :setup-arm (send* self :setup-ln-limb args)))
     (if noarm (return-from :setup-arm nil))
     (if (and marm (memq l/r '(:lmarm :rmarm)))
	 (return-from :setup-arm (send* self :setup-ln-limb args)))
     (if (eq-memq gripper-axis '(:p :-p :y :-y)) (setq gripper-axis :y) (setq gripper-axis x-axis))
     (send* self :setup-shoulder :l/r l/r args)
     (send* self :setup-elbow :l/r l/r args)     
     (send* self :setup-wrist :l/r l/r args)     
     (send* self :setup-gripper :l/r l/r args)
     (send* self :setup-driver :l/r l/r args)
     ))
  (:setup-shoulder
   (&rest args &key (l/r :larm) shoulder elbow wrist gripper gripper-axis passive-wheel
	  type (shoulder-width 26) (upper-arm-length 26) (wrist-len 26) wrist-a
	  ((:body bod)) wrist-sensor gripper-sensor gripper-inner
	  shoulder-p-sensor shoulder-r-sensor shoulder-y-sensor elbow-y-sensor
	  ((:torso trso)) marm arm mirrored &allow-other-keys)
   (let ((z-axis :z) (x-axis :x) (parent-name l/r) (horn t))
     (when (substringp "MAG" (string (send body-link :name)))
       (setq parent-name :joint-coord horn nil)
       (if (eq l/r :larm) (send body-link :rotate pi/2 :x :world)
	 (send body-link :rotate -pi/2 :x :world)))
     (case
      shoulder
      ((:cross :p-y-r)
       (send self :push-joint l/r 0 :y -180 180 :parent-link (send self :torso-top-link) :parent-name parent-name
	     :child-link (kxr-arm-base-link :from :y :to :z :l/r l/r :len 28 :sensor shoulder-p-sensor :horn horn))
      (send self :push-joint l/r 0 z-axis -110 110 :child-link
	    (kxr-cross-servo-link
	     :l/r l/r :apply-list (list (list :rotate pi/2 :y :world)
					(list :rotate pi/2 (if (eq l/r :larm) :-z :z) :world))))
      (send self :push-joint l/r 0 x-axis
	    (if (eq l/r :larm) -30 -120) (if (eq l/r :larm) 120 30)
	    :child-link (kxr-shoulder-cross-r-link :l/r l/r :len 26))
      )
     (:ypry-cross
      (send self :push-joint l/r 0 :z -180 180
	    :parent-link (send self :torso-top-link) :parent-name parent-name
	    :child-link (kxr-cross-servo-link :l/r l/r
					      :servo-flip (kxr-left-limb? l/r) :frame-b t
					      :apply-list (list (list :rotate -pi/2 :y :world)
								(list :rotate pi :z :world))))
      (send self :push-joint l/r 0 :y -180 180
	    :parent-name :upper-coord
	    :child-link (kxr-arm-base-link :from :y :to :x :l/r l/r :len 28 :sensor shoulder-p-sensor))
      (send self :push-joint l/r 0 :x -110 110
	    :child-link ;;(kxr-shoulder-cross-p-link :l/r l/r))
	    (kxr-cross-servo-link
	     :l/r l/r :servo-flip (eq l/r :larm)
	     :apply-list (list (list :rotate pi/2 (if (eq l/r :larm) :x :-x) :world))))
      (send self :push-joint l/r 1 :z -135 135 :parent-name :upper-coord
	    :child-link (kxr-arm-base-link :from :-z :to :y :l/r :larm :len upper-arm-length :sensor shoulder-y-sensor))
      )
     (:pry-cross
      (send self :push-joint l/r 0 :y -180 180 :parent-link (send self :torso-top-link) :parent-name parent-name
	    :child-link (kxr-arm-base-link :from :y :to :x :l/r l/r :len 28 :sensor shoulder-p-sensor :horn horn))
      (send self :push-joint l/r 0 :x -110 110 :child-link ;;(kxr-shoulder-cross-p-link :l/r l/r))
	    (kxr-cross-servo-link
	     :l/r l/r :sensor shoulder-r-sensor :servo-flip (eq l/r :larm)
	     :apply-list (list (list :rotate pi/2 (if (eq l/r :larm) :x :-x) :world))))
      (send self :push-joint l/r 0 :z -135 135
	    :parent-name :upper-coord
	    :child-link (kxr-arm-base-link :from :-z :to :y :l/r :larm :len upper-arm-length :sensor shoulder-y-sensor))
      )
     ((:p :y :p-r-y :p-r-yr)
      (send self :push-joint  l/r 0 :y -180 180 :parent-link (send self :torso-top-link)
	    :parent-name parent-name :child-link
	    (kxr-arm-base-link :from :y :to :x :len 26 :l/r l/r :sensor shoulder-p-sensor :horn horn))
      (send self :push-joint l/r 0 x-axis
	    (if (eq l/r :larm) -30 -185) (if (eq l/r :larm) 185 30)
	    :child-link (kxr-servo-wrist-y-link :axis :x :l/r l/r
						:y-rotate (eq shoulder :p-r-yr)))
      (send self :push-joint  l/r 0 z-axis -180 180 :child-link
	    (kxr-arm-base-link :from :-z :to :y :l/r l/r :len 26))
      )
     (:p-r
      (send self :push-joint  l/r 0 :y -180 180
	    :parent-link (send self :torso-top-link) :parent-name parent-name
	    :child-link (kxr-arm-base-link :from :y :to :x :len shoulder-width
					   :l/r l/r :sensor shoulder-p-sensor
					   :horn horn))
      (send self :push-joint l/r 0 x-axis
	    (if (eq l/r :larm) -30 -185) (if (eq l/r :larm) 185 30)
	    :child-link (kxr-shoulder-r-link :l/r l/r :len upper-arm-length))
      )
     (:kashiwagi-p-r
      (send self :push-joint  l/r 0 :y -180 180
	    :offset-v (if (kxr-left-limb? l/r) #f(0 70 0) #f(0 -70 0))
	    :parent-link (send self :torso-top-link) :parent-name parent-name
	    :child-link (kxr-arm-base-link :from :y :to :x :len 38
					   :l/r l/r :sensor shoulder-p-sensor
					   :horn horn))
      (send self :push-joint l/r 0 x-axis
	    (if (eq l/r :larm) -30 -185) (if (eq l/r :larm) 185 30)
	    :child-link
	    (kashiwagi-hand-link :l/r l/r)
	    )
      )
     ((:ly-p-r :ly-p-rb :uy-p-r) ;; kxrl2makabel :setup-arm shoulder
      (when trso
	(send self :push-joint  l/r 0 :z -180 180 :parent-link (send self :torso-top-link) 
	      :parent-name parent-name :child-link
	      (kxr-servo-luy-p-link :l/r l/r :up (eq shoulder :uy-p-r)
				    :wheel (eq-memq :shoulder passive-wheel))))
      (send self :push-joint  l/r 0 :y -180 180
	    ;;:parent-link (if (eq bod :l4d) body-link (send (car jlst) :child-link))
	    :parent-link (if trso (car lst) body-link)
	    :parent-name (if (car lst) :joint-coord l/r)
	    :child-link (kxr-arm-base-link :from :y :to :x :len 28 :l/r l/r))
      (if (eq shoulder :ly-p-rb)
	  (send self :push-joint l/r 0 :x -135 135 :child-link
		(kxr-cross-servo-link
		 :l/r l/r :canti (if (eq l/r :larm) :-y)
		 :apply-list (list (list :rotate pi/2 (if (eq l/r :larm) :x :-x) :world))))
	  (send self :push-joint l/r 0 :x -135 135 :child-link
		(kxr-cross-servo-link
		 ;;:l/r l/r :canti (if (eq l/r :rarm) :-y :y)
		 :l/r l/r :canti (if (eq l/r :rarm) :-y)
		 :apply-list (list (list :rotate pi :z :world)
				   (list :rotate pi/2 (if (eq l/r :larm) :x :-x) :world)))))
      ;; elbow :y-p
      (if trso
	  (send self :push-joint l/r 1 :z -180 180 :parent-name :upper-coord :child-link
		(kxr-arm-base-link :from :-z :to :y :len 28 :l/r l/r))
	  (send self :push-joint l/r 0 :z -180 180 :parent-name :upper-coord :child-link
		(kxr-arm-base-link :from :-z :to :y :len 28 :l/r l/r))
	  )
      )
     (:y-p-r  ;; kxrl2makabe
      (send self :push-joint l/r 0 :z -180 180 :parent-link (send self :torso-top-link)
	    :parent-name parent-name :child-link (kxr-servo-y-p-link :l/r l/r))
      (send self :push-joint l/r 0 :y -180 180 :child-link
	    (kxr-arm-base-link :from :y :to :x :len 28 :l/r l/r :sensor shoulder-p-sensor))
      (send self :push-joint l/r 0 :x -135 135 :child-link
	    (kxr-cross-servo-link
	     ;;:l/r l/r :canti (if (eq l/r :rarm) :-y :y)
	     :l/r l/r :canti (if (eq l/r :rarm) :-y)
	     :sensor shoulder-r-sensor
	     :apply-list (list (list :rotate pi :z :world)
			       (list :rotate pi/2 (if (eq l/r :larm) :x :-x) :world))))
      ;; elbow :y-p
      (send self :push-joint l/r 1 :z -180 180
	    :parent-name :upper-coord :child-link
	    (kxr-arm-base-link :from :-z :to :y :len 28 :l/r l/r :sensor elbow-y-sensor))
      )
     (:r
      (send self :push-joint  l/r 0 :-y -180 180 :parent-link (send self :torso-top-link)
	    :parent-name (if (kxr-left-limb? l/r) :lmarm :rmarm)
	    :child-link (kxr-arm-base-link :from :y :to :x :len 38 :sensor shoulder-p-sensor
					   :l/r (if (kxr-left-limb? l/r) :rmarm :lmarm)))
      )
     (:p-only
      (send self :push-joint  l/r 0 :y -180 180 :parent-link (send self :torso-top-link)
	    :parent-name parent-name
	    :child-link (kxr-arm-base-link :from :y :to :x :len shoulder-width
					   :l/r l/r :sensor shoulder-p-sensor
					   :horn horn))
      )
     ((t nil)
      (when (not (memq bod '(:backpack :board))) ;; (:p-r)
	(send self :push-joint  l/r 0 :y -180 180 :parent-link (send self :torso-top-link)
	      :parent-name parent-name
	      :child-link (kxr-arm-base-link :from :y :to :x :len shoulder-width
					     :l/r l/r :sensor shoulder-p-sensor
					     :horn horn))
	(send self :push-joint l/r 0 x-axis
	      (if (eq l/r :larm) -30 -185) (if (eq l/r :larm) 185 30)
	      :child-link (kxr-shoulder-r-link :l/r l/r :len upper-arm-length))
	))
     ))
   )
  (:setup-elbow
   (&rest args &key (l/r :larm) shoulder elbow wrist gripper gripper-axis passive-wheel
	  (shoulder-width 26) (upper-arm-length 26) (wrist-len 26) wrist-a elbow-p-sensor 
	  ((:body bod)) wrist-sensor gripper-sensor gripper-inner
	  ((:torso trso)) marm arm mirrored &allow-other-keys)
   (let (l j (z-axis :z) (x-axis :x))
     (cond
       ((memq bod '(:backpack :board)))
       ((eq elbow :angle) 
	(send self :push-joint l/r 1 :y -170 170
	      :child-link (kxr-angle-arm-link :l/r l/r :rotate nil :arm-len 28 :sensor elbow-p-sensor)))
       ((eq elbow :cross-py) 
	(send self :push-joint l/r 1 :y -140 140
	      :child-link
	      (kxr-cross-servo-link
	       :l/r l/r :servo-flip (eq l/r :rarm)
	       :apply-list
	       `((:rotate ,pi/2 ,(if (eq l/r :larm) :-z :z) :world)
		 (:rotate ,pi/2 :y :world)
		 )))
	(send self :push-joint l/r 1 :z -135 135
	      :parent-name :upper-coord
	      :child-link
	      (kxr-arm-base-link :from :-z :to :y :l/r l/r :len 38)))
       ((eq elbow :cross-p) 
	(send self :push-joint l/r 1 :y -140 140
	      :child-link
	      (kxr-cross-servo-link :l/r l/r :servo-flip (eq l/r :rarm)
				    :apply-list
				    `((:rotate ,pi/2 ,(if (eq l/r :larm) :-z :z) :world)
				      ))))
       ((memq shoulder (list :ly-p-r :ly-p-rb :uy-p-r)) ;; kxrl2makabel :setup-arm shoulder       
	(send self :push-joint l/r 1 :y -135 135 :child-link
	      (kxr-cross-servo-link
	       ;;:l/r l/r :canti (if (eq l/r :rarm) :-y :y)
	       :l/r l/r :canti (if (eq l/r :rarm) :-y)
	       :apply-list (list (list :rotate pi/2 (if (eq l/r :rarm) :z :-z) :world)
				 (list :rotate pi/2 :y :world))))
	)
       ((eq shoulder :y-p-r)  ;; kxrl2makabe       
	(send self :push-joint  l/r 1 :y -135 135 :child-link
	      (kxr-cross-servo-link
	       ;;:l/r l/r :canti (if (eq l/r :rarm) :-y :y)
	       :l/r l/r :canti (if (eq l/r :rarm) :-y) :sensor elbow-p-sensor
	       :apply-list (list (list :rotate pi/2 (if (eq l/r :rarm) :z :-z) :world)
				 (list :rotate pi/2 :y :world))))
	)
       ((memq shoulder '(:p-r :p-only :kashiwagi-p-r)))
       (t 
	;;(memq wrist (list :y-r :y-p :y :y-p-y :y-cross :cross-y :cross :cross-py :yb-cross :yw-cross :p :-p :r t nil))
	(send self :push-joint l/r 1 :y -170 170 :child-link (kxr-elbow-p-link :l/r l/r :sensor wrist-sensor)))
       )
     ))
  (:setup-wrist
   (&rest args &key (l/r :larm) shoulder elbow wrist gripper gripper-axis passive-wheel
	  (shoulder-width 26) (upper-arm-length 26) (wrist-len 26) wrist-a
	  ((:body bod)) wrist-sensor gripper-sensor gripper-inner wrist-y-sensor wrist-p-sensor
	  ((:torso trso)) marm arm mirrored &allow-other-keys)
   (let (l j (z-axis :z) (x-axis :x))
     (case
	 wrist
       ((:cross-y :cross)
	(send self :add-link (kxr-arm-base-link :to :y :len 38))
	(send self :push-joint l/r 2 :y -90 90 :child-link
	      (kxr-cross-servo-link :l/r l/r :apply-list (list (list :rotate pi :x :world))))
	(case
	    wrist
	  (:cross-y
	   (send self :push-joint l/r 2 x-axis -90 90 :child-link (kxr-wrist-cross-r-link :l/r l/r))
	   (send self :push-joint l/r 2 z-axis -90 90 :child-link (kxr-joint-base-link :l/r l/r)))
	  (:cross
	   (send self :push-joint l/r 2 x-axis -90 90
		 :child-link (kxr-wrist-link :len 28 :l/r l/r :sensor wrist-sensor))
	   )))
       (:cross-py
	(send self :add-link (kxr-arm-base-link :to :y :len 28 :horn nil))
	(send self :push-joint l/r 2 :y -120 90 :child-link
	      (kxr-cross-servo-link :l/r l/r  :servo-flip (eq l/r :rarm)
				    :apply-list (list (list :rotate pi/2 (if (eq l/r :larm) :-z :z) :world)
						      (list :rotate pi/2 :y :world))))
	(send self :push-joint l/r 2 z-axis -135 135
	      :parent-name :upper-coord
	      :child-link (kxr-joint-base-link
			   :l/r l/r :sensor wrist-sensor
			   :apply-list `((:rotate ,pi :y :world))
			   :horn t))
	)
       (:cross-pr ;; semi2022
	;;(send self :add-link (kxr-arm-base-link :to :y :len 28))
	(send self :push-joint l/r 2 :y -125 100 :child-link
	      (kxr-cross-servo-link
	       :l/r l/r :sensor wrist-p-sensor :servo-flip (eq l/r :rarm)
	       :apply-list
	       (list (list :rotate pi/2 (if (eq l/r :larm) :-z :z) :world)
		     )))
	(send self :push-joint l/r 2 :x -135 135
	      :parent-name :upper-coord
	      :child-link
	      (kxr-joint-base-link
	       :l/r l/r :sensor (or wrist-sensor wrist-y-sensor)
	       :apply-list `((:rotate ,pi/2 :y :world)(:rotate ,pi :x :world))
	       :horn t
	       )))
       (:wcross-pr ;; wide cross-frame in :cross-pr
	;;(send self :add-link (kxr-arm-base-link :to :y :len 28))
	(send self :push-joint l/r 2 :y -135 135 :child-link
	      (kxr-wcross-servo-link
	       :l/r l/r :sensor wrist-p-sensor))
	(send self :push-joint l/r 2 :x -135 135
	      :parent-name :upper-coord
	      :child-link
	      (kxr-joint-base-link
	       :l/r l/r :sensor (or wrist-sensor wrist-y-sensor)
	       :apply-list `((:rotate ,pi/2 :y :world)(:rotate ,pi :x :world))
	       :horn t
	       )))
       (:cross-rpy ;; semi2023 wrist :cross-pry
	(send self :push-joint l/r 2 :x -135 135
	      :parent-name :upper-coord :child-link
	      (kxr-arm-base-link :from :y :to :-y :l/r l/r :len 38))
	(send self :push-joint l/r 2 :y -125 100 :child-link
	      (kxr-cross-servo-link
	       :l/r l/r :sensor wrist-p-sensor :servo-flip (eq l/r :larm)
	       :apply-list
	       (list (list :rotate pi/2 (if (eq l/r :larm) :-z :z) :world)
		     (list :rotate pi/2 :-y :world)
		     )))
	(send self :push-joint l/r 2 :z -135 135
	      :parent-name :upper-coord
	      :child-link
	      (kxr-joint-base-link
	       :l/r l/r :sensor (or wrist-sensor wrist-y-sensor)
	       :apply-list `((:rotate ,pi/2 :y :world)(:rotate ,pi :x :world))
	       :horn t
	       )))
       (:y-r
	(send self :add-link (kxr-wrist-y-servo-link :l/r l/r))
	(send self :push-joint l/r 2 z-axis -90 90 :child-link (kxr-y-wrist-r-link :l/r l/r))
	(send self :push-joint l/r 2 x-axis -90 90
	      :child-link (kxr-wrist-link :l/r l/r :sensor wrist-sensor)))
       (:y-p
	(send self :add-link (kxr-wrist-y-servo-link :l/r l/r))
	(send self :push-joint l/r 2 z-axis -90 90 :child-link (kxr-y-wrist-p-link :l/r l/r))
	(send self :push-joint l/r 2 :y -90 90 :child-link (kxr-wrist-link :l/r l/r :axis :p)))
       (:y-p-y
	(send self :add-link (kxr-wrist-y-servo-link :l/r l/r))
	(send self :push-joint l/r 1 z-axis -90 90 :child-link (kxr-y-wrist-p-link :l/r l/r))
	(send self :push-joint l/r 2 :y -90 90 :child-link (kxr-wrist-p-y-link :l/r l/r))
	(send self :push-joint l/r 2 z-axis -90 90 :child-link (kxr-joint-base-link :l/r l/r)))
       (:y-cross
	(send self :add-link (kxr-wrist-y-servo-link :l/r l/r))
	(send self :push-joint l/r 2 z-axis -170 170 :child-link
	      (kxr-arm-base-link :l/r l/r :len 38 :to :-y))
	(send self :push-joint l/r 2 :y -90 90 :child-link
	      (kxr-cross-servo-link :l/r l/r :apply-list (list (list :rotate pi :x :world))))
	(send self :push-joint l/r 2 x-axis -90 90
	      :child-link (kxr-wrist-link :len 28 :l/r l/r :sensor wrist-sensor)))
       (:y
	(send self :add-link (kxr-wrist-y-servo-link :l/r l/r))
	(send self :push-joint l/r 2 z-axis -90 90 :child-link (kxr-joint-base-link :l/r l/r)))
       (:yb-cross
	(send self :add-link (kxr-wrist-y-servo-link :l/r l/r :y-rotate t))
	;;(kxr-servo-bottom-supporter-bodyset :align t :rotate-z (if (kxr-left-limb? l/r) -pi/2 pi/2)))
	(send self :push-joint l/r 2 z-axis -170 170 :child-link
	      (kxr-arm-base-link :l/r l/r :len 38 :to :-y))
	(send self :push-joint l/r 2 :y -90 90 :child-link
	      (kxr-cross-servo-link :l/r l/r :apply-list (list (list :rotate pi :x :world))))
	(send self :push-joint l/r 2 x-axis -90 90
	      :child-link (kxr-wrist-link :len 28 :l/r l/r :sensor wrist-sensor)))
       (:yw-cross
	(send self :add-link (kxr-wrist-y-servo-link :l/r l/r :y-rotate t))
	;;(kxr-servo-bottom-supporter-bodyset :align t :rotate-z (if (kxr-left-limb? l/r) -pi/2 pi/2)))
	(send self :push-joint l/r 2 z-axis -170 170 :child-link
	      (kxr-arm-base-link :len 28 :to (if (kxr-left-limb? l/r) :-y :y)))
	(send self :push-joint l/r 2 :y -90 90 :child-link
	      (kxr-cross-servo-link :apply-list (list (list :rotate pi/2 (if (kxr-left-limb? l/r) :-z :z) :world))))
	(send self :push-joint l/r 2 x-axis -90 90
	      :child-link (kxr-wrist-link :len 38 :l/r l/r :sensor wrist-sensor)))
       ((:r :p) ;; :setup-arm wrist
	(cond
	  ((memq shoulder '(:y-p-r :ly-p-r :ly-p-rb :uy-p-r))
	   (send self :push-joint l/r 2 :z -180 180 :parent-name :upper-coord
		 :child-link (kxr-y-wrist-r-link :l/r l/r :base-b (not wrist-a) :sensor wrist-y-sensor))
	   (send self :push-joint l/r 2 :x -150 150
		 :child-link (kxr-wrist-link :l/r l/r :len wrist-len :sensor wrist-sensor))
	   (when (eq-memq :wrist passive-wheel)      ;; kxrl2makabe
	     (setq l (pop lst) j (pop jlst))
	     (send self :push-joint l/r 2 :wx -100000 100000 :parent-link l :active nil
		   :offset-v (if (eq l/r :larm)
				 (float-vector -25 0 (if wrist-sensor 28 12))
				 (float-vector -25 0 (if wrist-sensor 28 12)))
		   :child-link (kxr-passive-wheel-link :axis :x :l/r l/r :horn t :horn-height 8))
	     (push l lst) (push j jlst)))
	  ((memq shoulder '(:p-r :p-only)))
	  (t
	   (send self :add-link (kxr-wrist-r-servo-link :l/r l/r :axis wrist))
	   (send self :push-joint l/r 2 x-axis -150 150
		 :child-link (kxr-wrist-link :l/r l/r :sensor wrist-sensor :axis wrist)))))
       )))
  (:setup-driver
   (&rest args &key l/r driver
	  ((:body bod)) wrist-sensor type wrist-inner wrist-link-replace 
	  &allow-other-keys &aux l ec)
   (when driver
     (send self :add-link (kxr-driver-servo-link) :replace wrist-link-replace)
     (if (eq driver t) (setq driver '(:larm :rarm)))
     (when (eq-memq l/r driver)
       (send self :push-joint l/r "gripper" :x -10000 10000 :child-link (kxr-driver-link)))
     )
   (when
       (not (memq bod '(:backpack :board)))
     (when
	 (and (setq l (car lst)) (get l :joint-coord))
       (setq ec (make-cascoords
		 :rot (rotation-matrix 0 :x)
		 :pos (send (get l :joint-coord) :worldpos)
		 :name (format nil "~A-end-coords" l/r)))
       (push (cons l/r ec) end-coords-alist)
       (send l :assoc ec)
       (send self :ln-ending type l/r nil nil nil l) ;; :setup-driver
       ))
   )
  (:setup-gripper
   (&rest args &key l/r shoulder elbow wrist gripper gripper-axis passive-wheel gripper-straight
	  attachment
	  ((:body bod)) wrist-sensor gripper-sensor gripper-inner type wrist-inner
	  wrist-link-replace gripper-wrist-sensor ;; (gripper-horn (memq wrist '(:cross-py :cross-pr)))
	  ((:torso trso)) marm arm mirrored &allow-other-keys)
   (let ((axis+ :x) (axis- :-x) gs l ec mag magj)
     (if (eq gripper t) (setq gripper (list :larm :rarm)))
     (when
	 (or (eq gripper t)
	     (eq-memq l/r gripper)
	     (eq wrist-inner t)
	     (eq gripper-inner t)
	     (eq gripper-straight t)
	     (eq-memq l/r gripper-inner))
       (when (setq mag (find-if #'(lambda (b) (substringp "mag" (send b :name))) (send (car lst) :bodies)))
	 ;;(format t ";; setup-gripper has mag=~A in (car lst)=~A~%" mag (car lst))
	 (cond
	  ((substringp "sensor" (send mag :name))
	   (setq magj :mag-7))
	  ((substringp "+" (send mag :name)) ;; horn-mag+
	   (setq magj :mag-7))
	  (t (setq magj :mag+7))))
       (when (eq-memq l/r gripper)
	 (setq gs (kxr-wrist-gripper-links
		   :l/r l/r :gripper-axis gripper-axis
		   :attachment attachment
		   :gripper-inner gripper-inner ;; :wrist-sensor wrist-sensor
		   :wrist-sensor nil ;; (if gripper-horn wrist-sensor nil)
		   :gripper-straight gripper-straight ;; :horn gripper-horn
		   :magjoint magj
		   :base-b
		   (if gripper-straight nil
		     (if (not (memq shoulder '(:y-p-r :ly-p-r :ly-p-rb :uy-p-r))) (if wrist-inner :y- :y+)
		       wrist-inner))
		   :passive-wheel passive-wheel :gripper-sensor gripper-sensor))
	 ;; gs= (l:base l0:finger1 l1:finger2 {l2:passive-wheel})
	 ;;(setq l (send self :add-link (elt gs 0) :replace (if gripper-horn t wrist-link-replace)))
	 (setq l (send self :add-link (elt gs 0) :replace wrist-link-replace))
	 (setq ec (get (elt gs 0) :end-coords))
	 (send l :assoc ec)
	 ;;
	 (send self :push-joint l/r "gripper" axis+ -100 100
	       :child-link (elt gs 1) :parent-link l)
	 (send self :push-joint l/r "gripper2" axis+ -100 100
	       :child-link (elt gs 2) :parent-link l :parent-name nil :active nil)
	 (when (eq-memq :gripper passive-wheel)
	   (if (eq-memq gripper-inner (list t l/r))
	       (send self :push-joint l/r "gripper" :wy -100000 100000
		     :parent-link (elt gs 2) :child-link (elt gs 3) :active nil)
	     (send self :push-joint l/r "gripper" :wy -100000 100000
		   :parent-link (elt gs 1) :child-link (elt gs 3) :active nil))
	   )
	 (push (cons l/r ec) end-coords-alist)
	 (when (and (null l)
		    (not (memq bod '(:backpack :board))))
	   ;;(format t ";; l=null ec=~A~%" ec)
	   (setq l (car lst))
	   (setq ec (make-cascoords
		     :rot (rotation-matrix 0 :x)
		     :pos (send (get (car lst) :joint-coord) :worldpos)
		     :name (format nil "~A-end-coords" l/r)))
	   (push (cons l/r ec) end-coords-alist)
	   (send l :assoc ec)
	   )
	 (when
	     (not (memq bod '(:backpack :board)))
	   (send self :ln-ending type l/r gripper gripper-inner gripper-straight l) ;; :setup-arm
	   (setq lst nil)
	   )))
     ))
  (:ln-ending
   (type l/r gripper gripper-inner gripper-straight sensor-link)
   (let (c)
     (setq c (make-cascoords
	      :name
	      (case l/r (:larm "lhsensor") (:rarm "rhsensor")
		    (:lleg "lfsensor") (:rleg "rfsensor")
		    (t (format nil "~A-sensor" (string-downcase (string l/r)))))
	      :rot (rotation-matrix
		    (if gripper-straight 0
			(if (kxr-left-limb? l/r)
			    (if gripper-inner -23 23)
			    (if gripper-inner 23 -23)))
		    :x)
	      :pos (send sensor-link :worldpos)))
     ;;(send c :translate #f(0 0 -30) :local)
     (send c :put :sensor-type :base_force6d)
     (send sensor-link :assoc c)
     (unless (assoc l/r sensor-coords-alist)
       (push (cons l/r c) sensor-coords-alist))
     (unless (assoc l/r end-coords-alist)
       (push (cons l/r c) end-coords-alist))
     ;;(setslot self (class self) (read-from-string (symbol-name l/r)) (reverse lst))
     #|
     (when (eq type :l6)
     (format t ";; type==l6 l/r=~A~%" l/r)
     (case
     l/r
     ((:larm :rleg) (send (car (reverse lst)) :rotate pi/2 :-z))
     ((:rarm :lleg) (send (car (reverse lst)) :rotate pi/2 :z))
     ))
     |#
     (unless (assoc l/r root-link-alist)
       (push (cons l/r (car (reverse lst))) root-link-alist))
     (cond
      ((eq l/r :rmarm)
       (let ((l (assoc :rarm lst-alist))
	     (j (assoc :rarm jlst-alist)))
	 (if l (rplacd l (append (reverse lst) (cdr l)))
	   (push (cons :rarm (reverse lst)) lst-alist))
	 (if j (rplacd j (append (reverse jlst) (cdr j)))
	   (push (cons :rarm (reverse jlst)) jlst-alist))
	 ))
      ((eq l/r :lmarm)
       (let ((l (assoc :larm lst-alist))
	     (j (assoc :larm jlst-alist)))
	 (if l (rplacd l (append (reverse lst) (cdr l)))
	   (push (cons :larm (reverse lst)) lst-alist))
	 (if j (rplacd j (append (reverse jlst) (cdr j)))
	   (push (cons :larm (reverse jlst)) jlst-alist))
	 ))
      ((memq l/r '(:lleg0 :lleg1 :lleg2))
       (let ((l (assoc :lleg lst-alist))
	     (j (assoc :lleg jlst-alist)))
	 (if l (rplacd l (append (reverse lst) (cdr l)))
	   (push (cons :lleg (reverse lst)) lst-alist))
	 (if j (rplacd j (append (reverse jlst) (cdr j)))
	   (push (cons :lleg (reverse jlst)) jlst-alist))
	))
      ((memq l/r '(:rleg0 :rleg1 :rleg2))
       (let ((l (assoc :rleg lst-alist))
	     (j (assoc :rleg jlst-alist)))
	 (if l (rplacd l (append (reverse lst) (cdr l)))
	   (push (cons :rleg (reverse lst)) lst-alist))
	 (if j (rplacd j (append (reverse jlst) (cdr j)))
	   (push (cons :rleg (reverse jlst)) jlst-alist))
	 ))
      (t
       (let ((l (assoc l/r lst-alist))
	     (j (assoc l/r jlst-alist)))
	 (if l (rplacd l (append (reverse lst) (cdr l)))
	   (push (cons l/r (reverse lst)) lst-alist))
	 (if j (rplacd j (append (reverse jlst) (cdr j)))
	   (push (cons l/r (reverse jlst)) jlst-alist))
	 )))))
  (:setup-ln-limb
   (&rest args &key l/r ((:body bod)) type marm arm leg passive-wheel leg0 leg1 leg2
	  shoulder (upper-arm-length 26) shoulder-p-sensor shoulder-y-sensor shoulder-r-sensor
	  elbow-p-sensor wrist-y-sensor wrist-p-sensor wrist-inner wrist-sensor 
	  gripper-axis gripper-straight gripper gripper-sensor gripper-inner
	  leg-frontal crotch-r-sensor knee-type knee-p-sensor ankle-r-sensor end ;; end: end-link 
          (radius 48) ankle-sensor sole-sensor sole &allow-other-keys)
   (let (l l0 l1 l2 ls j j0 j2 (z-axis :z) (x-axis :x) v ec
	   (limb-type (case l/r
			    ((:lleg0 :rleg0) leg0)
			    ((:lleg1 :rleg1) leg1)
			    ((:lleg2 :rleg2) leg2)
			    ((:lleg :rleg) leg)
			    ((:larm :rarm) arm)
			    ((:lmarm :rmarm) (or marm arm)))))
     (setq lst nil jlst nil)
     (if (and (get self :mirrored) (kxr-right-limb? l/r))
	 (setq z-axis :-z x-axis :-x))
     (case
	 limb-type
       (:r
	(send self :push-joint l/r 0 :x -90 90 :parent-link (send self :torso-top-link)
	      :parent-name l/r 
	      :child-link (kxr-l6-foot-link :l/r l/r :axis :x :sensor wrist-sensor))
	)
       (:r2
	(send self :push-joint l/r 0 :y -90 90 :parent-link (send self :torso-top-link)
	      :parent-name l/r 
	      :child-link (kxr-mamoru-marm-link :l/r l/r))
	(send self :push-joint l/r 0 :x -90 90
	      :child-link (kxr-mamoru-marm-shell-link :l/r l/r))
	;;(send self :push-joint l/r 0 :x -90 90
	;;:child-link (kxr-l6-foot-link :l/r l/r :axis :x))
	;;(send self :add-link (kxr-mamoru-marm-shell-link :l/r l/r))
	(send self :push-joint l/r 1 :w -10000 10000
	      :child-link (kxr-l6-foot-link :l/r l/r :axis :x :sensor wrist-sensor))
	)
       (:r3
	(send self :push-joint l/r 0 :y -90 90 :parent-link (send self :torso-top-link)
	      :parent-name l/r
	      :child-link (kxr-mamoru-marm-link-2022 :l/r l/r))
	(send self :push-joint l/r 0 :z -90 90
	      :child-link (kxr-mamoru-marm-shell-link-2022 :l/r l/r))
	(send self :push-joint l/r 1 :w -10000 10000
	      :child-link (kxr-l6-foot-link :l/r l/r :axis :x :sensor wrist-sensor))
	)

       (:j6w
	(cond
	  ((substringp "MAG" (string (send (car (send body-link :bodies)) :name)))
	   (let ((org (make-cascoords)))
	     (send org :assoc body-link)
	     (if (kxr-left-limb? l/r)
		 (send org :rotate pi/2 :x :world)
		 (send org :rotate -pi/2 :x :world))
	     (send self :push-joint l/r 0 :y -181 181 :parent-link body-link
		   :child-link (kxr-arm-base-link :from :y :to :x :l/r l/r :len 28 :horn nil))))
	  (t 
	   (send self :push-joint l/r 0 :y -181 181 :parent-link body-link :parent-name l/r
		 :child-link (kxr-arm-base-link :from :y :to :x :l/r l/r :len 28))))
	(send self :push-joint l/r 0 x-axis -90 90 :child-link
	      (kxr-cross-servo-link
	       ;;:l/r l/r :canti (if (eq l/r :rleg) :-y t)
	       :l/r l/r :canti (if (eq l/r :rleg) :-y)
	       :apply-list
	       (list (list :rotate pi :z :world)
		     (list :rotate pi/2 (if (eq l/r :rleg) :-x :x) :world))))
	(send self :push-joint l/r 0 :z -170 170 :parent-name :upper-coord :child-link
	      (kxr-y-wrist-p-link
	       :l/r l/r :base-b (not (eq knee-type :lp))
	       :apply-list (list (list :rotate pi :z :world))))
	(send self :push-joint l/r 1 :y -181 181 :child-link
	      (if (eq knee-type :lp)
		  (kxr-wheel-knee-lp-link
		   :l/r l/r :len-u 26 :len-d 38 :wheel-offset 6)
		  (kxr-wheel-knee-p-link
		   :l/r l/r :len-u 38 :len-d 38 :wheel-offset 6)))
	(setq l (car lst) j (car jlst))
	(send self :push-joint l/r 1 :w -10000 10000 :parent-name :upper-coord :child-link
	      (kxr-wheel-link :l/r l/r :offset 6.5))
	(send self :push-joint l/r 2 :y -105 105 :parent-link l :child-link
	      (kxr-cross-servo-link :l/r l/r :apply-list (list (list :rotate pi :x :world))))
	(send self :push-joint l/r 2 x-axis -170 170 :child-link
	      (kxr-foot-link :l/r l/r :sole sole :sole-sensor sole-sensor)))
       (:j4
	(send self :push-joint l/r 0 :y -135 135 :parent-link body-link :parent-name l/r :child-link 
	      (if leg-frontal
		  (kxr-arm-base-link :from :y :to :z :l/r l/r :len 26)
		  (kxr-arm-base-link :from :y :to :x :l/r l/r :len 26)))
	(send self :push-joint l/r 0 (if leg-frontal :z :x) -80 120
	      :child-link (kxr-shoulder-r-link :l/r l/r :len 26 :frontal leg-frontal))
	(send self :push-joint l/r 1 :y -170 170
	      :child-link (kxr-angle-arm-link :l/r l/r :frontal leg-frontal))
	(send self :push-joint l/r 2 :y -90 90 :child-link (kxr-l4d-ankle-link :l/r l/r :frontal leg-frontal)))
       ;;
       (:l1y
	;;(send self :push-joint l/r 0 :z -90 90 :parent-link body-link :child-link (kxr-wrist-y-link))
	(send self :add-link (kxr-wrist-y-link) :target-link body-link)
	(cond
	  (sole
	   (send self :push-joint l/r 0 :z -110 110 :offset-v (float-vector 0 0 -3)
		 :parent-link body-link
		 :child-link
		 (kxr-foot-link :l/r l/r :sole sole :arm nil
				:sole-sensor sole-sensor :ankle-sensor ankle-sensor)))
	  (end (send self :push-joint l/r 0 z-axis -110 110
		     :parent-link body-link :child-link (kxr-mag-link end))
	       (setf (get self :joint-coord) (get (car lst) :joint-coord))
	       ))
	)
       (:l1r
	;;(send self :push-joint l/r 0 :z -90 90 :parent-link body-link :child-link (kxr-wrist-y-link))
	(send self :add-link (kxr-wrist-r-servo-link) :target-link body-link)
	(send self :push-joint l/r 0 x-axis -110 110 :parent-link body-link :child-link
	      (kxr-foot-link :l/r l/r :sole sole :sole-sensor sole-sensor :ankle-sensor ankle-sensor))
	(when end
	  (send self :add-link (kxr-mag-link end))
	  (setf (get self :joint-coord) (get (car lst) :joint-coord))
	  )
	)
       (:l2
	;;(send self :push-joint l/r 0 :z -90 90 :parent-link body-link :child-link (kxr-wrist-y-link))
	(send self :add-link (kxr-wrist-y-link) :target-link body-link)
	(send self :push-joint l/r 0 z-axis -110 110 :offset-v (float-vector 0 0 -3)
	      :parent-link body-link :child-link (kxr-wrist-r-servo-link))
	(send self :push-joint l/r 0 x-axis -110 110 :child-link
	      (kxr-foot-link :l/r l/r :sole sole :sole-sensor sole-sensor :ankle-sensor ankle-sensor))
	(when end (send self :add-link (kxr-mag-link end)))
	)
       (:l5
	;;(send self :push-joint l/r 0 x-axis -135 133 :parent-link body-link :child-link (kxr-arm-base-link :len 28 :horn nil))
	(send self :add-link (kxr-arm-base-link :len 28 :horn nil) :target-link body-link)
	(send self :push-joint l/r 0 x-axis -135 133 :parent-link body-link
	      :child-link (kxr-cross-servo-link :l/r l/r :sensor crotch-r-sensor))
	(send self :push-joint l/r 0 :y -135 90 :child-link (kxr-double-arm-base-link :l/r l/r))
	(send self :push-joint l/r 1 :y -100 160 :child-link (kxr-angle-arm-link :l/r l/r :sensor knee-p-sensor))
	(send self :push-joint l/r 2 :y -105 105 :child-link
	      (kxr-cross-servo-link :l/r l/r :apply-list (list (list :rotate pi :x :world))
				    :sensor ankle-r-sensor))
	(send self :push-joint l/r 2 x-axis -170 170 :parent-link l :child-link
	      (kxr-foot-link :l/r l/r :sole sole :sole-sensor sole-sensor :ankle-sensor ankle-sensor))
	(when end (send self :add-link (kxr-mag-link end)))
	)
       (:l6s
	;;(send self :push-joint l/r 0 :z -90 90 :parent-link body-link :child-link (kxr-wrist-y-link))
	(send self :push-joint l/r 0 :z -135 133 :parent-link body-link 
	      :child-link (kxr-arm-base-link :len 28 :horn nil))
	(send self :push-joint l/r 0 x-axis -135 133
	      :child-link (kxr-cross-servo-link :l/r l/r :sensor crotch-r-sensor))
	(send self :push-joint l/r 0 :y -135 90 :child-link (kxr-double-arm-base-link :l/r l/r))
	(send self :push-joint l/r 1 :y -100 160 :child-link (kxr-angle-arm-link :l/r l/r :sensor knee-p-sensor))
	(send self :push-joint l/r 2 :y -105 105 :child-link
	      (kxr-cross-servo-link :l/r l/r :apply-list (list (list :rotate pi :x :world))
				    :sensor ankle-r-sensor))
	(send self :push-joint l/r 2 x-axis -170 170 :parent-link l :child-link
	      (kxr-foot-link :l/r l/r :sole sole :sole-sensor sole-sensor :ankle-sensor ankle-sensor))
	(when end (send self :add-link (kxr-mag-link end)))
	)
       (:l6
	;;(send self :push-joint l/r 0 :z -90 90 :parent-link body-link :child-link (kxr-wrist-y-link))
	(send self :add-link (kxr-wrist-y-link) :target-link body-link)
	(send self :push-joint l/r 0 x-axis -135 133 :parent-link body-link 
	      :child-link (kxr-arm-base-link :len 28 :horn nil))
	(send self :push-joint l/r 0 x-axis -135 133
	      :child-link (kxr-cross-servo-link :l/r l/r :sensor crotch-r-sensor))
	(send self :push-joint l/r 0 :y -135 90 :child-link (kxr-double-arm-base-link :l/r l/r))
	(send self :push-joint l/r 1 :y -100 160 :child-link (kxr-angle-arm-link :l/r l/r :sensor knee-p-sensor))
	(send self :push-joint l/r 2 :y -105 105 :child-link
	      (kxr-cross-servo-link :l/r l/r :apply-list (list (list :rotate pi :x :world))
				    :sensor ankle-r-sensor))
	(send self :push-joint l/r 2 x-axis -170 170 :parent-link l :child-link
	      (kxr-foot-link :l/r l/r :sole sole :sole-sensor sole-sensor :ankle-sensor ankle-sensor))
	(when end (send self :add-link (kxr-mag-link end)))
	)
       (:g1
	(let ((gs (kxr-wrist-gripper-links
		   :l/r l/r :gripper-axis gripper-axis
		   :gripper-inner gripper-inner ;; :wrist-sensor wrist-sensor
		   :wrist-sensor nil ;; (if gripper-horn wrist-sensor nil)
		   :gripper-straight gripper-straight ;; :horn gripper-horn
		   :base-b
		   (if gripper-straight nil
		       (if (not (memq shoulder '(:y-p-r :ly-p-r :ly-p-rb :uy-p-r))) (if wrist-inner :y- :y+)
			   wrist-inner))
		   :gripper-sensor gripper-sensor)))
	  (if (eq gripper-axis :y)
	      (send body-link :rotate -pi/2 :y :world))
	  ;; gs= (l:base l0:finger1 l1:finger2 {l2:passive-wheel})
	  (setq l (send self :add-link (elt gs 0) :target-link body-link))
	  (setq ec (get (elt gs 0) :end-coords))
	  (send body-link :assoc ec)
	  ;;
	  (send self :push-joint l/r "gripper" :x -100 100
		:child-link (elt gs 1) :parent-link l)
	  (send self :push-joint l/r "gripper2" :x -100 100
		:child-link (elt gs 2) :parent-link l :parent-name nil :active nil)
	  ))
       (:a5 ;; :shoulder :pry-cross
	(if (kxr-left-limb? l/r) (send body-link :rotate pi/2 :x :world)
	    (send body-link :rotate -pi/2 :x :world))
	(send self :add-link
	      (kxr-arm-base-link :from :y :to :x :l/r l/r :len 28 :sensor shoulder-p-sensor :horn nil)
	      :target-link body-link)
	(send self :push-joint l/r 0 :x -110 110 :parent-link body-link
	      :child-link ;;(kxr-shoulder-cross-p-link :l/r l/r))
	      (kxr-cross-servo-link
	       :l/r l/r :sensor shoulder-r-sensor :servo-flip (eq l/r :larm)
	       :apply-list (list (list :rotate pi/2 (if (eq l/r :larm) :x :-x) :world))))
	(send self :push-joint l/r 0 :z -135 135
	      :parent-name :upper-coord
	      :child-link
	      (kxr-arm-base-link :from :-z :to :y :l/r :larm :len upper-arm-length :sensor shoulder-y-sensor))
	;; :elbow :angle
	(send self :push-joint l/r 1 :y -170 170
	      :child-link (kxr-angle-arm-link :l/r l/r :rotate nil :arm-len 28 :sensor elbow-p-sensor))
	;; :wrist :cross-pr
	(send self :push-joint l/r 2 :y -125 100 :child-link
	      (kxr-cross-servo-link
	       :l/r l/r :sensor wrist-p-sensor :servo-flip (eq l/r :rarm)
	       :apply-list
	       (list (list :rotate pi/2 (if (eq l/r :larm) :-z :z) :world)
		     )))
	(send self :push-joint l/r 2 :x -135 135
	      :parent-name :upper-coord
	      :child-link
	      (kxr-joint-base-link
	       :l/r l/r :sensor (or wrist-sensor wrist-y-sensor)
	       :apply-list `((:rotate ,pi/2 :y :world)(:rotate ,pi :x :world))
	       :horn t
	       ))
	(when end (send self :add-link (kxr-mag-link end)))
	)
       ;;
       (:j0o
	(send self :push-joint l/r 0 (if (memq l/r '(:lmarm :rmarm)) :wx :w)
	      -100000 100000 :parent-link body-link :parent-name l/r
	      :child-link (kxr-wheel-link :l/r l/r :double t :offset (if (eq l/r :rmarm) -1 1)
					  :apply-list (if (eq l/r :lmarm) (list (list :rotate pi :z :world)))
					  :axis (if (memq l/r '(:lmarm :rmarm)) :x :y))))
       (:j2o
	(case
	    l/r
	  (:lleg
	   (send self :push-joint l/r 1 :wx -100000 100000 :parent-link body-link :parent-name :lmarm
		 :child-link (kxr-wheel-link :l/r l/r :double t :offset 1 :axis :x
					     :apply-list (list (list :rotate pi :z :world))))
	   (send self :push-joint l/r 0 :w -100000 100000 :parent-link body-link :parent-name l/r
		 :child-link (kxr-wheel-link :l/r l/r :double t :offset 1 :axis :y)))
	  (:rleg
	   (send self :push-joint l/r 1 :wx -100000 100000 :parent-link body-link :parent-name :rmarm
		 :child-link (kxr-wheel-link :l/r l/r :double t :offset -1 :axis :x))
	   (send self :push-joint l/r 0 :w -100000 100000 :parent-link body-link :parent-name l/r
		 :child-link (kxr-wheel-link :l/r l/r :double t :offset 1 :axis :y)))
	  ))
       (:j0d
	(send self :push-joint l/r 0 :w -100000 100000 :parent-link body-link :parent-name l/r
	      :child-link (kxr-wheel-link :l/r l/r :double t :offset -6)))
       (:j2d
	(case
	    l/r
	  (:lleg
	   (send self :push-joint l/r 0 :w -100000 100000 :parent-link body-link :parent-name :lmarm
		 :child-link (kxr-wheel-link :l/r l/r :double nil :offset 3))
	   (send self :push-joint l/r 1 :w -100000 100000 :parent-link body-link :parent-name l/r
		 :child-link (kxr-wheel-link :l/r l/r :double t :offset -6)))
	  (:rleg
	   (send self :push-joint l/r 0 :w -100000 100000 :parent-link body-link :parent-name :rmarm
		 :child-link (kxr-wheel-link :l/r l/r :double nil :offset 3))
	   (send self :push-joint l/r 1 :w -100000 100000 :parent-link body-link :parent-name l/r
		 :child-link (kxr-wheel-link :l/r l/r :double t :offset -6)))
	  ))
       (:j0m
	(send self :push-joint l/r 0 :w -100000 100000 :parent-link body-link :parent-name l/r
	      :child-link (kxr-wheel-link :l/r l/r :double t :offset 3)))
       (:j1-2mw ;; front :crotch, back :knee
	(send self :push-joint l/r 0 z-axis -110 110 :parent-link body-link :parent-name l/r
	      :child-link (kxr-double-servo-joint-base-link :l/r l/r))
	(setq l (car lst))
	(cond
	  ((eq l/r :lleg)
	   (send self :push-joint l/r 0 :w -100000 100000 :parent-name :lmarm
		 :child-link (kxr-wheel-link :l/r l/r :double t :offset 0 :radius 60))
	   (send self :push-joint l/r 1 :w -100000 100000 :parent-link l :parent-name :lleg
		 :child-link (kxr-wheel-link :l/r l/r :double t :offset 0 :radius 60)))
	  (t
	   (send self :push-joint l/r 0 :w -100000 100000 :parent-name :rmarm
		 :child-link (kxr-wheel-link :l/r l/r :double t :offset 0 :radius 60))
	   (send self :push-joint l/r 1 :w -100000 100000 :parent-link l :parent-name :rleg
		 :child-link (kxr-wheel-link :l/r l/r :double t :offset 0 :radius 60)))))
       (:j2m ;; front :crotch, back :knee
	(cond
	  ((eq l/r :lleg)
	   (send self :push-joint l/r 0 :w -100000 100000 :parent-link body-link :parent-name :lmarm
		 :child-link (kxr-wheel-link :l/r l/r :double t :offset 3 :radius radius))
	   (send self :push-joint l/r 1 :w -100000 100000 :parent-link body-link :parent-name :lleg
		 :child-link (kxr-wheel-link :l/r l/r :double t :offset 3 :radius radius))
	   )
	  (t
	   (send self :push-joint l/r 0 :w -100000 100000 :parent-link body-link :parent-name :rmarm
		 :child-link (kxr-wheel-link :l/r l/r :double t :offset 3 :radius radius))
	   (send self :push-joint l/r 1 :w -100000 100000 :parent-link body-link :parent-name :rleg
		 :child-link (kxr-wheel-link :l/r l/r :double t :offset 3 :radius radius))
	   ))
	)
       (:j0w
	(send self :push-joint l/r 0 :w -100000 100000 :parent-link body-link :parent-name l/r
	      :child-link (kxr-wheel-link :l/r l/r :double nil :offset 3)))
       (:j1w
	(send self :push-joint l/r 0 z-axis -110 110 :parent-link body-link :parent-name l/r
	      :child-link (kxr-l4r-crotch-link :l/r l/r))
	(send self :push-joint l/r 0 :w -100000 100000 :child-link (kxr-wheel-link :l/r l/r :offset 3)))
       (:j2w
	(send self :push-joint l/r 0 z-axis -110 110 :parent-link body-link :parent-name l/r
	      :child-link (kxr-l4r-crotch-link :l/r l/r))
	(send self :push-joint l/r 0 :w -100000 100000 :child-link (kxr-wheel-link :l/r l/r :offset 3)))
       (:j3w
	(send self :push-joint l/r 0 z-axis -130 130 :parent-link body-link :parent-name l/r :child-link 
	      (kxr-arm-base-link :from :-z :to :y :l/r l/r :len 26))
	(send self :push-joint l/r 0 :y -110 110 :child-link (kxr-mamoru-leg-link :l/r l/r))
	(send self :push-joint l/r 1 :w -100000 100000 :child-link (kxr-wheel-link :l/r l/r :offset 22.5)))
       (:j2
	(send self :push-joint l/r 0 z-axis -110 110 :parent-link body-link :parent-name l/r :child-link
	      (kxr-l4t-crotch-link :l/r l/r :l6 (eq type :l6)))
	(send self :push-joint l/r 0 x-axis -110 110 :child-link
	      (kxr-servo-frame-base-a-link :axis :x :l/r l/r)))
       (:j2-pr
	(send self :push-joint l/r 0 z-axis -110 110 :parent-link body-link :parent-name l/r
	      :offset-v (float-vector 0 0 -3) :child-link (kxr-wrist-r-servo-link :horn t))
	(send self :push-joint l/r 0 x-axis -110 110 :child-link
	      (kxr-foot-link :l/r l/r :sole sole :sole-sensor sole-sensor :ankle-sensor ankle-sensor)))
       (:j2-2m
	(setq lst nil jlst nil)
	(send self :push-joint l/r 0 z-axis -110 110 :parent-link body-link
	      :parent-name l/r :child-link (kxr-l4t-crotch-link :l/r l/r :l6 (eq type :l6)))
	(send self :push-joint l/r 0 x-axis -110 110
	      :child-link (kxr-servo-frame-base-a-link :axis :x :l/r l/r)))
       (:j3-3m
	(setq lst nil jlst nil)
	(send self :push-joint l/r 0 z-axis -112 112 :parent-link body-link :parent-name l/r
	      :child-link (kxr-l4t-crotch-link :len0 20 :len1 38 :l/r l/r :l6 (eq type :l6)))
	(send self :push-joint l/r 0 :x -170 170
	      :child-link (kxr-l6-knee-link :l/r l/r :axis :x))
	(send self :push-joint l/r 1 :x -170 170
	      :child-link (kxr-l6-foot-link :l/r l/r :axis :x :sensor wrist-sensor))
	)
       (:j3
	(send self :push-joint l/r 0 z-axis -112 112 :parent-link body-link :parent-name l/r
	      :child-link (kxr-l4t-crotch-link :len0 20 :len1 38 :l/r l/r :l6 (eq type :l6)))
	(setq l (car lst) j (car jlst))
	(when
	    (or (eq-memq :shoulder passive-wheel) (eq-memq :crotch passive-wheel))
	  (setq l2 (kxr-passive-wheel-link :axis :x :offset (+ 13.0 6 6.5) :l/r l/r))
	  (send l :assoc l2)
	  (send self :push-joint l/r 0 :wx -100000 100000 :child-link l2)
	  (setq j2 (car jlst)))
	(if (and (eq type :l6) (not (memq l/r '(:lmarm :rmarm))))
	    (send self :push-joint l/r 0 :y -170 170 :parent-link l
		  :child-link (kxr-l6-knee-link :l/r l/r :axis :y))
	    (send self :push-joint l/r 0 x-axis -170 170 :parent-link l
		  :child-link (kxr-l6-knee-link :l/r l/r :axis :x)))
	;; end-foot
	(if (and (eq type :l6) (not (memq l/r '(:lmarm :rmarm))))
	    (send self :push-joint l/r 1 :y -170 170
		  :child-link (kxr-l6-foot-link :l/r l/r :axis :y :sensor wrist-sensor))
	    (send self :push-joint l/r 1 x-axis -170 170
		  :child-link (kxr-l6-foot-link :l/r l/r :axis :x :sensor wrist-sensor)))
	;;
	(when (or (eq gripper t)
		  (eq-memq l/r gripper)
		  (eq gripper-inner t)
		  (eq gripper-straight t)
		  (eq-memq l/r gripper-inner))
	  (pop lst) (pop jlst)
	  (setq l (car lst) j (car jlst))
	  (send self :push-joint l/r 1 x-axis -170 170
		:child-link (kxr-wrist-r-gripper-link
			     :l/r l/r :len 38 :inner gripper-inner :axis :r :sensor wrist-sensor))
	  (setq l (car lst) j (car jlst))
	  ;;
	  (setq ls (kxr-fingers-links :l/r l/r :gripper-inner gripper-inner :sensor gripper-sensor))
	  (setq l0 (car ls) l1 (cadr ls))
	  (send l :assoc l0)
	  (if (or (eq gripper-inner t) (eq-memq l/r gripper-inner))
	      (if (kxr-right-limb? l/r)
		  (send l1 :translate (float-vector 0 (- (sqrt (+ (* 21 21) (* 10.5 10.5)))) 0) :world)
		  (send l1 :translate (float-vector 0 (sqrt (+ (* 21 21) (* 10.5 10.5))) 0) :world))
	      (if (kxr-left-limb? l/r)
		  (send l1 :translate (float-vector 0 (- (sqrt (+ (* 21 21) (* 10.5 10.5)))) 0) :world)
		  (send l1 :translate (float-vector 0 (sqrt (+ (* 21 21) (* 10.5 10.5))) 0) :world)))
	  (send l0 :assoc l1)
	  (if (kxr-left-limb? l/r) (send l0 :rotate pi/2 :x) (send l0 :rotate pi/2 :-x))
	  (if (or (eq gripper-inner t) (eq-memq l/r gripper-inner))
	      (if (kxr-right-limb? l/r)
		  (send l0 :rotate (atan2 10.5 21.0) :x)
		  (send l0 :rotate (atan2 -10.5 21.0) :x))
	      (if (kxr-left-limb? l/r)
		  (send l0 :rotate (atan2 10.5 21.0) :x)
		  (send l0 :rotate (atan2 -10.5 21.0) :x)))
	  (send self :push-joint l/r "gripper" x-axis -100 100 :parent-link l :child-link l0)
	  (send l :assoc l1)
	  (send self :push-joint l/r "gripper2"	x-axis -100 100	:parent-link l
		:child-link l1 :parent-name nil :active nil)
	  )))
     ;; end-coords
     (setq ec (make-cascoords
	       :rot (rotation-matrix 0 :x)
	       :pos (send (get (car lst) :joint-coord) :worldpos)
	       :name (format nil "~A-end-coords" l/r)))
     (push (cons l/r ec) end-coords-alist)
     (send (car lst) :assoc ec)
     (if (null l0) (setq l0 (car lst)))
     (send self :ln-ending type l/r gripper gripper-inner gripper-straight l0) ;; :setup-ln-limb
     ))
  (:setup-leg
   (&rest args &key (l/r :lleg) knee-type active-wheel ankle type crotch-z
	  crotch-cross-back
	  crotch-p-sensor crotch-r-sensor crotch-y-sensor knee-p-sensor ankle-r-sensor
	  ((:body bod)) leg leg0 leg1 leg2
	  noleg ankle-sensor sole sole-sensor &allow-other-keys)
   (let (l j (z-axis :z) (x-axis :x) ec)
     (setq lst nil jlst nil)
     (if (and (get self :mirrored) (eq l/r :rleg)) (setq z-axis :-z x-axis :-x))
     (if (or leg leg0 leg1 leg2) (return-from :setup-leg (send* self :setup-ln-limb args)))
     (unless noleg
       (cond
	 ;; crotch pitch type
	 ((memq bod '(:l4d :dyp :dyp-z :dyp-zf :lyp-low :lyp-high))	;; makabe
	  (send self :push-joint l/r 0 :y -181 181 :parent-link body-link :parent-name l/r :child-link 
		(kxr-arm-base-link :from :y :to :x :l/r l/r :len 28 :sensor crotch-p-sensor))
	  (send self :push-joint l/r 0 x-axis -90 90
		:child-link
		(if crotch-cross-back
		    (kxr-cross-servo-link
		     ;;:l/r l/r :canti (if (eq l/r :rleg) :-y t)
		     :l/r l/r :canti (if (eq l/r :lleg) :-y) :sensor crotch-r-sensor
		     :apply-list (list (list :rotate pi :z :world)
				       (list :rotate pi/2 (if (eq l/r :rleg) :-x :x) :world)
				       (list :rotate pi :y :world)
				       ))
		    (kxr-cross-servo-link
		     ;;:l/r l/r :canti (if (eq l/r :rleg) :-y t)
		     :l/r l/r :canti (if (eq l/r :rleg) :-y) :sensor crotch-r-sensor
		     :apply-list (list (list :rotate pi :z :world)
				       (list :rotate pi/2 (if (eq l/r :rleg) :-x :x) :world)))))
	  (send self :push-joint l/r 0 :z -170 170 :parent-name :upper-coord :child-link
		(if crotch-z (kxr-y-wrist-p-link :l/r l/r :base-b (not (eq knee-type :lp)))
		    (kxr-y-wrist-p-link :l/r l/r :base-b (not (eq knee-type :lp)) :sensor crotch-y-sensor
					:apply-list (list (list :rotate pi :z :world))))
		))
	 ;; crotch pitch type
	 ((eq-memq bod '(:l2l5 :l2l5base))
	  (cond
	   ((eq-memq :crotch active-wheel)
	    (send self :push-joint l/r 0 x-axis -170 170 :parent-link body-link :parent-name l/r
		  :child-link (kxr-crotch-cross-wheel-link :l/r l/r :sensor crotch-r-sensor))
	    (setq l (car lst) j (car jlst))
	    (send self :push-joint l/r 0 :w -10000 10000
		  :child-link (kxr-wheel-link :l/r l/r :offset (+ 3.5 10.5)))
	    (send self :push-joint l/r 0 :y -135 90 :parent-link l :parent-name :origin-coord
		  :child-link (kxr-double-arm-base-link :l/r l/r)))
	   (t
	    (send self :push-joint l/r 0 x-axis -135 133 :parent-link body-link :parent-name l/r
		  :child-link (kxr-cross-servo-link :l/r l/r :sensor crotch-r-sensor))
	    (send self :push-joint l/r 0 :y -135 90 :child-link (kxr-double-arm-base-link :l/r l/r)))))
	 ((eq-memq bod '(:l2w2))
	  (send self :push-joint l/r 0 :w -10000 10000 :parent-link body-link
		:parent-name (case l/r (:lleg :lwheel) (:rleg :rwheel))
		:child-link (kxr-wheel-link :l/r l/r :offset (+ 6.5 1.5)))
	  (send self :push-joint l/r 0 z-axis -90 90 :parent-link body-link :parent-name l/r :child-link 
		(kxr-arm-base-link :from :-z :to :x :l/r l/r :len 28))
	  (send self :push-joint l/r 0 x-axis -95 95 :child-link (kxr-cross-servo-link :l/r l/r :sensor crotch-r-sensor))
	  (send self :push-joint l/r 0 :y -135 90 :child-link (kxr-double-arm-base-link :l/r l/r))
	  )
	 ((not (memq bod '(:backpack :board)))
	  (send self :push-joint l/r 0 z-axis -90 90 :parent-link body-link :parent-name l/r :child-link 
		(kxr-arm-base-link :from :-z :to :x :l/r l/r :len 28))
	  (cond
	    ((eq-memq :crotch active-wheel)
	     (send self :push-joint l/r 0 x-axis -170 170
		   :child-link (kxr-crotch-cross-wheel-link :l/r l/r :sensor crotch-r-sensor))
	     (setq l (car lst) j (car jlst))
	     (send self :push-joint l/r 0 :w -10000 10000 :child-link (kxr-wheel-link :l/r l/r :offset (+ 3.5 10.5)))
	     (send self :push-joint l/r 0 :y -135 90 :parent-link l :parent-name :origin-coord
		   :child-link (kxr-double-arm-base-link :l/r l/r)))
	    (t
	     (send self :push-joint l/r 0 x-axis -95 95 :child-link (kxr-cross-servo-link :l/r l/r :sensor crotch-r-sensor))
	     (send self :push-joint l/r 0 :y -135 90 :child-link (kxr-double-arm-base-link :l/r l/r))
	     ))))
       ;; knee joint
       (cond
	 ((eq-memq :knee active-wheel)
	  (cond
	    ((eq-memq bod '(:l4d :dyp :dyp-z :dyp-zf :lyp-low :lyp-high))
	     (send self :push-joint l/r 1 :y -181 181 :child-link
		   (if (eq knee-type :lp)
		       (kxr-wheel-knee-lp-link :l/r l/r :len-u 26 :len-d 38 :wheel-offset 0)
		       (kxr-wheel-knee-p-link :l/r l/r :len-u 38 :len-d 38 :wheel-offset 0)))
	     (setq l (pop lst) j (pop jlst))
	     (send self :push-joint l/r 1 :w -10000 10000 :parent-name :upper-coord
		   :parent-link l :child-link (kxr-wheel-link :l/r l/r :offset 0 :horn-height 5))
	     (push l lst) (push j jlst))
	    (t
	     (send self :push-joint l/r 1 :y -181 181 :child-link
		   (kxr-knee-wheel-link :l/r l/r :wheel-offset 0))
	     (setq l (pop lst) j (pop jlst))
	     (send self :push-joint l/r 1 :w -10000 10000 :parent-link l :parent-name :upper-coord :child-link
		   (kxr-wheel-link :l/r l/r :offset 0 :horn-height 5))
	     (push l lst) (push j jlst))))
	 ((eq-memq bod '(:l2w2))
	  (setq l (car lst) j (car jlst))	
	  (send self :push-joint l/r 1 :w -10000 10000 :active nil
		;;:parent-link l :parent-name :upper-coord
		:child-link (kxr-wheel-link :l/r l/r :offset (+ 6.5 19.5)))
	  (send self :push-joint l/r 1 :y -100 160 :parent-link l
		:child-link (kxr-angle-arm-link :l/r l/r))
	  )
	 ((not (memq bod '(:backpack :board)))
	  (send self :push-joint l/r 1 :y -100 160 :child-link (kxr-angle-arm-link :l/r l/r :sensor knee-p-sensor))))
       ;; ankle
       (cond
	 ((eq-memq :ankle active-wheel)
	  (send self :push-joint l/r 2 :y -105 105
		:child-link (kxr-ankle-cross-wheel-link :l/r l/r :sensor ankle-r-sensor))
	  (setq l (car lst) j (car jlst))
	  (send self :push-joint l/r 2 :w -10000 10000 :child-link (kxr-wheel-link :l/r l/r :horn t :offset (+ 3.5 10.5)))
	  (send self :push-joint l/r 2 x-axis -170 170 :parent-link l :parent-name :origin-coord
		:child-link
		(kxr-foot-link :l/r l/r :sole sole :sole-sensor sole-sensor :ankle-sensor ankle-sensor)))
	 ((not (memq bod '(:backpack :board)))
	  (send self :push-joint l/r 2 :y -105 105 :child-link
		(kxr-cross-servo-link :l/r l/r :apply-list (list (list :rotate pi :x :world))
				      :sensor ankle-r-sensor))
	  (setq l (car lst) j (car jlst))
	  (cond
	    ((memq ankle (list :y))
	     (send self :push-joint l/r 2 x-axis -170 170 :parent-link l :child-link
		   (kxr-foot-link :l/r l/r :sole nil :ankle-sensor ankle-sensor))
	     (send self :add-link (kxr-servo-bottom-supporter-bodyset :align t))
	     (if (eq sole :w)
		 (send self :push-joint l/r 2 :z -170 170 :child-link
		       (kxr-passive-wheel-link :l/r l/r :axis :z :offset 7))
		 (send self :push-joint l/r 2 :z -170 170 :child-link
		       (kxr-foot-link :l/r l/r :sole sole :sole-sensor sole-sensor :arm nil :ankle-sensor ankle-sensor))))
	    (t (send self :push-joint l/r 2 x-axis -170 170 :parent-link l :child-link
		     (kxr-foot-link :l/r l/r :sole sole :sole-sensor sole-sensor :ankle-sensor ankle-sensor))))))
       )
     ;; end-coords
     (when lst
       (setq ec (make-cascoords
		 :rot (rotation-matrix 0 :x)
		 :pos (send (get (car lst) :joint-coord) :worldpos)
		 :name (format nil "~A-end-coords" l/r)))
       (push (cons l/r ec) end-coords-alist)
       (send (car lst) :assoc ec)
       (send self :ln-ending type l/r nil nil nil (car lst)) ;; :setup-leg
       )
     ))
  )

(defun dump-kxr-model (r &key glvertices (erase t) (dir "glbodies"))
  (let* ((rname (send r :name)) fname
	 (sym (robot-gvar rname))
	 (funcname (read-from-string rname))
	 (func-body (symbol-function funcname)))
    (when glvertices ;; generate glvertices
      (dolist (b (send r :bodies))
	(if (memq :generate-glvertices (send b :methods))
	    (send b :generate-glvertices dir))))
    (cond
      (dir (setq dir (rcb4eus-mkdir dir))
	   (setq fname (rcb4eus-file rname :dir dir)))
      (t (setq fname (rcb4eus-file rname :ext ".l"))))
    (dump-structure fname
		    `(require :kxrmodels)
		    #|
		    (defclass-form kxr-robot)
		    (defclass-form kxr-body)
		    (defclass-form (class r))
		    (defmethods-form kxr-robot)
		    (defmethods-form (class r))
		    (kxr-defun-form r)
		    |#
		    `(setq ,sym ',r))
    ;;(dump-structure fname `(require :kxrmodels) `(defun ,rname nil (setq ,sym ',r)))
    ;;(dump-structure fname `(require :kxrmodels) `(setf (symbol-function ',rname) ,func-body) `(setq ,sym ',r))
    ))

(defun defclass-form (cls)
  `(defclass ,(metaclass-name cls) :super ,(metaclass-name (metaclass-super cls))
     :slots ,(coerce (subseq (metaclass-vars cls)
			     (length (metaclass-vars (metaclass-super cls))))
		     cons)))

(defun defmethod-form (cls mthd)
  `(defmethod ,(metaclass-name cls) ,(assoc mthd (metaclass-methods cls))))

(defun defmethods-form (cls)
  `(defmethod ,(metaclass-name cls) ,@(metaclass-methods cls)))

(defun kxr-color-setup (&optional (r *robot*) &rest args)
  (dolist (b (send r :bodies)) (send b :set-color #f(0.3 0.3 0.3)))
  (kxr-change-body-color r '("plate" "back-pack" "ring") #f(0.8 0.8 0.8))
  (kxr-change-body-color r '("battery") #f(0.7 0.7 0.7) 0.9)
  (while args (kxr-change-body-color r (pop args) (pop args))))

(defun kxr-change-body-color (&optional r names (color #f(0.3 0.3 0.3)) transparency)
  (dolist (b (remove-if-not
	      #'(lambda (b)
		  (member
		   (string (send b :name))
		   names
		   :test #'(lambda (x y) (substringp y x))))
	      (send r :bodies)))
    (send b :set-color color)
    (if transparency (gl::transparent b transparency))
    ))

(defclass kxr-robotset :super kxr-robot
  :slots (base-robot
	  (robots :type cons)
	  (detached-robots :type cons)))

(defmethod kxr-robotset
  (:doc () "set of kxr-robots")
  (:mbase nil (get self :mbase))
  (:base-robot nil base-robot)
  (:robots nil robots)
  (:detached-robots nil detached-robots)
  (:init (base-robot-name
	  &rest args
	  &key (name (intern (format nil "robotset~A" (sys::address self)) "KEYWORD"))
	  ri
	  &allow-other-keys)
	 (setq base-robot (kxr-create-robot base-robot-name :model nil))
	 (replace-object self base-robot)
	 (setq robots (list base-robot))
	 (dolist (prop (list :lleg :rleg :neck :head :larm :rarm :lmarm :rmarm
			     :lwing :rwing :mbase))
	   (when (and base-robot (get (base-robot . body-link) prop))
	     (setf (get self prop) (get (base-robot . body-link) prop))
	     ))
	 self)
  (:merge-slot-alist
   (method)
   (let (key-list ret)
     (dolist (r robots)
       (dolist (alist (send r method))
	 (pushnew (car alist) key-list)
	 (setf (get (car alist) method) (append (get (car alist) method) (cdr alist)))))
     (dolist (k key-list)
       (push (cons k (get k method)) ret)
       (setf (get k method) nil))
     ret))
  (:merge-lst-alist nil (setq lst-alist (send self :merge-slot-alist :lst-alist)))
  (:merge-jlst-alist nil (setq jlst-alist (send self :merge-slot-alist :jlst-alist)))
  (:merge-slot-key-value
   (method)
   (let (key-list ret)
     (dolist (r robots)
       (dolist (alist (send r method))
	 (pushnew (car alist) key-list)
	 (setf (get (car alist) method) (cdr alist))))
     (dolist (k key-list)
       (push (cons k (get k method)) ret)
       (setf (get k method) nil))
     ret))
  (:merge-name-joint-list
   nil (setq name-joint-list (send self :merge-slot-key-value :name-joint-list)))
  (:merge-end-coords-alist
   nil (setq end-coords-alist (send self :merge-slot-key-value :end-coords-alist)))
  (:merge-sensor-coords-alist
   nil (setq sensor-coords-alist (send self :merge-slot-key-value :sensor-coords-alist)))
  (:merge-root-link-alist
   nil (setq root-link-alist (send self :merge-slot-key-value :root-link-alist)))
  (:init-ending
   nil
   (send self :merge-lst-alist)
   (send self :merge-jlst-alist)
   (send self :merge-name-joint-list)
   (send self :merge-end-coords-alist)
   (send self :merge-sensor-coords-alist)
   (send self :merge-root-link-alist)
   (setq joint-list (apply #'append (mapcar #'(lambda (r) (send r :joint-list)) robots)))
   (dolist (j joint-list) (send (send j :parent-link) :assoc (send j :child-link))
	   (setq (j . default-coords) (send (send j :child-link) :copy-coords)))
   ;;(dolist (j joint-list) (pushnew (send j :child-link) links))
   (setq links (apply #'append (mapcar #'(lambda (r) (send r :links)) robots)))

   (setq limbs (mapcar #'car lst-alist))
   (send-super :init-ending)
   (let ((ri (get self :ri)))
     (when ri
       (send ri :setup-vectors (ri . robot) nil)
       (send ri :config (kxr-find-config-by-name (send (ri . robot) :name)))
       (send ri :init-trim-vector)
       ))
   )
  (:update-objects
   nil
   (when (get self :viewer)
     (send (get self :viewer) :objects (list self))
     (send (get self :viewer) :draw-objects)
     ))
  (:find-robot-by-link
   (lnk)
   (find-if #'(lambda (x) (memq lnk (send x :links))) robots))
  (:attach (r prop &aux m n ls c l j top base)
	   (when (stringp r)
	     (cond
	      #|
	      ((setq m
	      (find-if #'(lambda (x) (string= r (send x :name))) detached-robots))
	      (setq detached-robots (remove-if 
	      #'(lambda (x) (string= r (send x :name)))
	      detached-robots))
	      (setq r m))
	      |#
	      ((setq m (find-if #'(lambda (x) (string= r (send x :name))) robots))
	       (setq r m))
	      (t
	       ;;(format t ";; :attach r=~A prop=~A~%" r prop)
	       (setq r (kxr-create-robot r :model nil)))))
	   (cond
	    ((keywordp prop)
	     (setq ls (send self prop))
	     (cond
	      #|
	      ((null ls)
	       (warn ";; :attach ls=nil, self=~A, prop=~A, r=~A~%" self prop r)
	       (when
		   (setq c (get self prop))
		 (when
		     r
		   (send r :locate (send c :worldpos) :world)
		   (send self :add-link r :parent-name prop
			 :target-link (base-robot . body-link))
		   (when (r . links) (setq (r . links) (cdr (r . links))))
		   )))
	      |#
	      ;;
	      ((coordinates-p ls)  ;; prop=:mbase
	       ;;(format t ";;ls=coordinates :attach prop=~A ls=~A~%" prop ls)
	       (let (pt ptj (offset (float-vector 0 0 0)))
		 (setq top (send r :torso-top-link))
		 (setq pt (send top :worldpos))
		 ;;(format t ";; torso-top-link pos pt=~A~%" pt)
		 (cond
		  ((eq top (base-robot . body-link))
		   (dolist (cl (top . child-links))
		     (setq ((cl . joint) . parent-link) (base-robot . body-link)))
		   )
		  ((setq j (send top :joint)) ;; t1 has torso joint ;;((eq base (r . body-link)) ;; t1 has torso
		   (cond
		    ((get top :joint-coord)
		     (setq ptj (v- (send (get top :joint-coord) :worldpos) (send top :worldpos)))
		     ;;(setq ptj (send (get top :joint-coord) :worldpos))
		     (setq offset (v- pt ptj))
		     ;;(format t ";; has torso ptj=~A, pt=~A, offset=~A~%" ptj pt offset)
		     )
		    (t
		     ;;(format t ";; :attach top:~A does not have :joint-coord~%" top)
		     ))
		   (setq l (send self :add-link top :parent-name prop
				 :offset offset :target-link (base-robot . body-link)))
		   (setq (r . links) (remove top (r . links)))
		   (setq base (send j :parent-link))
		   ;;(format t ";; l=base?=~A l=~A, base=~A~%" (eq l base) l base)
		   (send base :dissoc top)
		   (send base :dissoc (get base :torso))
		   (send base :translate offset :world) ;; 2024.1.5
		   (send l :assoc base)
		   (send self :assoc l)
		   (setq (j . child-link) base)
		   (setq (j . parent-link) l)
		   (setf (get base :torso) l)
		   (send l :assoc (j . child-link))
		   (send (j . parent-link) :assoc base)
		   (setq (base . child-links) (remove top (base . child-links))) ;; 2024.1.8
		   )
		  (t
		   (setq l (send self :add-link top :parent-name prop :target-link (base-robot . body-link)))
		   ;;(format t ";;; top=~A, offset=~A~%" top offset)
		   (dolist (cl (top . child-links))
		     (setq ((cl . joint) . parent-link) l)
		     (send l :assoc (send (cl . joint) :child-link))
		     )
		   (setq (r . links) (cdr (r . links)))
		   ))
		 ))
	      ((and r (consp ls))   ;; larm, rarm, prop=keyword, grippers
	       (setq l (car (last ls)))
	       (setq c (get l :joint-coord))
	       ;;(format t ";; ls=consp l=~A ls=~A, c=~A, prop=~A~%" l ls c prop)
	       ;;
	       (setq top (send r :torso-top-link))
	       (when (and top (top . child-links))
		 (setq m (send self :add-link top :target-link l))
		 ;; (send m :assoc top) ;; 2024.1.8
		 ;;(format t ";; top =~A, (top . child-links) =~A~%" top (top . child-links))
		 (dolist (cl (top . child-links))
		   (when (cl . joint)
		     (setq ((cl . joint) . parent-link) m))
		   )
		 ;;(format t ";; r=~A, (r . links) =~A~%" r (r . links))
		 (when (r . links)
		   (setq (r . links) (cdr (r . links)))
		   ;;(format t ";;2 r=~A, (r . links) =~A, m=~A~%" r (r . links) m)
		   (when 
		       m
		     ;;(format t ";;3 m=~A, (m . child-links) =~A~%" m (m . child-links))
		     (setq (m . child-links) (top . child-links))
		     ;;(setq ((r . body-link) . parent-link) m)
		     (when 
			 (setq n (send self :find-robot-by-link l))
		       ;;(format t ";;4 n=~A (get n :attached) =~A~%" n (get n :attached))
		       (setf (get n :attached) (append (get n :attached) (list r)))
		       ;;(format t ";;5 n=~A (get n :attached) =~A~%" n (get n :attached))
		       )))
		 )
	       )
	      ((null ls)
	       (setq c (get self prop))  ;; neck ls=nil
	       ;;(format t ";;;;;; ls=~A :attach r=~A c=~A, prop=~A~%" ls r c prop)
	       (when (coordinates-p c)
		 (setq top (send r :torso-top-link))
		 ;;(format t ";; :attach c=~A, top=~A~%" c top)
		 (setq (body-link . child-links)
		       (append ((r . body-link) . child-links) (body-link . child-links)))
		 (setq ((r . body-link) . parent-link) body-link)
		 (cond
		  ((eq body-link top)
		   ;;(format t ";; :attach not :add-link top=body-link =~A~%" top)
		   (dolist (cl (top . child-links))
		     (setq ((cl . joint) . parent-link) m))
		   )
		  (t
		   ;;(format t ";; :attach :add-link top=~A body-link=~A prop=~A~%" top body-link prop)
		   (setq m (send self :add-link top :parent-name prop
				 :target-link body-link))
		   (dolist (cl (top . child-links))
		     (setq ((cl . joint) . parent-link) m))
		   (setq (r . links) (cdr (r . links)))
		   (send body-link :assoc r) ;; arm case
		   ))
		 ;;(format t ";; :attach after :add-link top=~A body-link=~A prop=~A~%" top body-link prop)
		 ))))
	    )
	   (unless (memq r robots)
	     (setq robots (append robots (list r))))
	   (send self :init-ending)
	   (send self :update-objects)
	   ;; (format t ";; after :update-objects self=~A r=~A prop=~A~%" self r prop)
	   )
  (:find-from-robots
   (r)
   (cond
     ((stringp r)
      (find-if #'(lambda (x) (string= r (send x :name))) robots))
     (t (find r robots))))
  (:detach (r)
	   (setq r (send self :find-from-robots r))
	   (cond
	     ((derivedp r kxr-robot)
	      (dolist (m (get r :attached))
		(send self :detach m))
	      (setf (get r :attached) nil)
	      (setq robots (remove r robots))
	      (send ((r . body-link) . parent) :dissoc (r . body-link))
	      ;;(send self :reset-link (r . body-link))
	      (setq detached-robots (cons r detached-robots))
	      (send self :init-ending)
	      (send self :update-objects)
	      )
	     (t (format *error-output* "r=~A is not kxr-robot~%" r)))
	   )
  )

(provide :kxrmodels)

