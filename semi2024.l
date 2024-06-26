(defun free-arms nil
  (send *ri* :free :larm-elbow-p :rarm-elbow-p)
  )
(defun rest-pose nil
  (send *ri* :neutral)
  (free-arms)
  )
(defun init-pose nil
  (send *ri* :hold)
  (send *robot* :angle-alist
	'((:rarm-shoulder-p -27.405)
	  (:rarm-shoulder-r -3.07125)
	  (:rarm-shoulder-y 43.0987)
	  (:rarm-elbow-p 30.5775)
	  (:rarm-wrist-p -58.725)
	  (:rarm-wrist-r -33.3113)
	  (:rarm-gripper-r 28.8225)
	  (:rarm-gripper2-r 28.8225)
	  (:larm-shoulder-p -37.9688)
	  (:larm-shoulder-r -0.30375)
	  (:larm-shoulder-y -42.795)
	  (:larm-elbow-p 67.3988)
	  (:larm-wrist-p -84.78)
	  (:larm-wrist-r 8.9775)
	  (:larm-gripper-r 29.0925)
	  (:larm-gripper2-r 29.0925)
	  (:rleg-crotch-y 5.644583e-14)
	  (:rleg-crotch-r -0.135)
	  (:lleg-crotch-y 0.135)
	  (:lleg-crotch-r 0.135)
	  (:head-neck-y 6.615)
	  (:head-neck-p 50.3212)))
  (send *ri* :angle-vector (send *robot* :angle-vector) 2000)
  )

(defclass sample-crank
  :super cascaded-link
  :slots (handle crank-joint)
  )

(defmethod sample-crank
  (:init
   (&rest args
	  &key (root-bar-height 150) (handle-base-radius 30) (handle-bar-height 70)
	  &allow-other-keys)
   (send-super* :init args)
   (setq handle nil)
   ;; 1. make links links and assoc all links
   (let ((rl (send self :make-root-link root-bar-height))
	 (cl (send self :make-crank-link handle-base-radius handle-bar-height)))
     (send cl :translate (float-vector 0 0 root-bar-height) :world)
     ;; 2. assoc links
     ;;    Root link should be associated with "self".
     (send self :assoc rl)
     (send rl :assoc cl)
     ;; 3. make all joints
     ;;    Before making joints, you should :assoc all links.
     (setq crank-joint (instance rotational-joint :init
				 :parent-link rl :child-link cl
				 :name :crank-joint :axis :z
				 :min *-inf* :max *inf*))
     ;; 4. define slots for robot class
     ;;    links and joint-list for cascaded-link.
     (setq links (list rl cl))
     (setq joint-list (list crank-joint))
     ;; 5. call :init-ending after defining links and joint-list and return "self"
     (send self :init-ending)
     self))
  ;; Methods to define robot links
  (:make-root-link
   (root-bar-height)
   (instance bodyset-link :init (make-cascoords)
	     :bodies (list (make-cylinder 5 root-bar-height))
	     :name :crank-root-link))
  (:make-crank-link
   (handle-base-radius handle-bar-height)
   (let* ((handle-base-thickness 10)
	  (handle-bar-radius 5)
	  (handle-base (make-cube (* handle-bar-radius 2) handle-base-radius handle-base-thickness))
	  (handle-bar (make-cylinder handle-bar-radius handle-bar-height)))
     (send handle-bar :translate
	   (float-vector 0 (- handle-bar-radius handle-base-radius) (/ handle-base-thickness 2.0)))
     (send handle-base :translate (float-vector 0 (/ handle-base-radius -2.0) 0))
     (send handle-base :assoc handle-bar)
     (send handle-base :translate (float-vector 0 0 (/ handle-base-thickness 2.0)))
     (let* ((br (instance bodyset-link :init (make-cascoords)
			  :bodies (list handle-base handle-bar) :name :crank-handle-link))
	    (ahandle
	     (make-cascoords :coords
			     (send (send handle-base :copy-worldcoords)
				   :translate (float-vector 0 (* -0.5 handle-base-radius) (/ handle-bar-height 2.0)))
			     :name :crank-handle)))
       (send br :assoc ahandle)
       (push ahandle handle)
       br)))
  (:handle () handle)
  (:crank-handle () (car handle))
  (:crank-joint (&rest args) (forward-message-to crank-joint args))
  )

(defclass sample-broom
  :super cascaded-link
  :slots (handle)
  )

(defmethod sample-broom
  (:init
   (&rest args
	  &key (sweep-height 50) (sweep-width 26) (sweep-thickness 20)
          (bar-length 300) (bar-width 10)
	  &allow-other-keys)
    (send-super* :init args)
    (setq handle nil)
    ;; 1. make links links and assoc all links
    (let ((rl (send self :make-broom-link
                    sweep-height sweep-width sweep-thickness
                    bar-length bar-width)))
      ;; 2. assoc links
      ;;    Root link should be associated with "self".
      (send self :assoc rl)
      ;; 3. make all joints
      ;;    Before making joints, you should :assoc all links.

      ;; 4. define slots for robot class
      ;;    links and joint-list for cascaded-link.
      (setq links (list rl))
      (setq joint-list nil)
      ;; 5. call :init-ending after defining links and joint-list and return "self"
      (send self :init-ending)
      self))
  ;; Methods to define robot links
  (:make-broom-link
    (sh ;; sw = Sweep Height
     sw ;; sw = Sweep Width
     st ;; st = Sweep Thickness
     bl ;; bl = Bar Length
     bw) ;; bw = Bar Width
   (let* ((bar (make-cylinder (/ bw 2.0) bl))
	  (sweep (make-prism (list (float-vector sw (- sh) 0)
				   (float-vector (- sw) (- sh) 0)
				   (float-vector (* -0.5 bw) 0 0)
				   (float-vector (* 0.5 bw) 0 0))
                             st)))
     (send bar :locate (float-vector 0 0 sh) :world)
     (send sweep :rotate pi/2 :x)
     (send sweep :locate (float-vector 0 10 sh) :world)
     (send bar :set-color :brown)
     (send sweep :set-color :red)
     (send bar :assoc sweep)
     (let ((br (instance bodyset-link :init (make-cascoords)
			 :bodies (list bar sweep))))
       (dolist (rate (list 0.8 0.6))
	 (push (make-cascoords :pos (float-vector 0 0 (+ (* rate bl) sh))) handle))
       (dolist (hc handle) (send br :assoc hc))
       br)))
  (:handle () handle)
  )

(when (and (not (boundp '*robot*))
	   (probe-file "models/kxrl2l6a6h2m.l"))
  (load "models/kxrl2l6a6h2m.l")
  (setq *robot* (instance kxrl2l6a6h2m-robot :init)))

(defmethod robot-model
  (:shake-cocktail
   (&key (target-pos (float-vector 120 0 0))
	 (offset-z 50)
	 (swing-x 30)
	 (swing-y 5)
	 (obj (make-cylinder 15 100)))
   (send self :reset-pose)
   (send self :newcoords (make-coords))
   
   (setq *obj* obj)
   (send obj :set-color (float-vector 1 1 0))
   (send self :reset-pose)
   (objects (list self obj))
   
   (send self :inverse-kinematics
	 (list (make-coords :pos target-pos))
	 :move-target
	 (list (send self :larm :end-coords))
	 :link-list
	 (list (send self :link-list
		     (send (send self :larm :end-coords) :parent)
		     (car (send self :larm :links))))
	 :translation-axis (list t)
	 :rotation-axis (list nil))
   (let* ((cnt 0.0))
     (do-until-key
      (incf cnt 0.1)
      (send self
	    :inverse-kinematics
	    (list (make-coords :pos target-pos)
		  ;;:pos (v+ target-pos
		  ;;(float-vector (* swing-x (sin cnt))
		  ;;(* swing-y (cos cnt)) 0)))
		  #'(lambda ()
		      (send (send (send self :larm :end-coords) :copy-worldcoords)
			    :translate (float-vector 0 0 offset-z) :local)))
	    :move-target
	    (list (send self :larm :end-coords)
		  (send self :rarm :end-coords))
	    :link-list
	    (list (send self :link-list
			(send (send self :larm :end-coords) :parent)
			(car (send self :larm :links)))
		  (send self :link-list
			(send (send self :rarm :end-coords) :parent)
			(car (send self :rarm :links))))
	    :translation-axis (list :z t)
	    :rotation-axis (list nil :z))
      (send obj :newcoords (send (send self :larm :end-coords) :copy-worldcoords))
      (send *irtviewer* :draw-objects))))
  (:crank-motion
   ()
   "crank motion using full body ik"
   (send self :reset-pose)
   (send self :newcoords (make-coords))
   (send self :fix-leg-to-coords (make-coords))
   (send self :update-descendants)
   (setq *crank* (instance sample-crank :init))
   (send *crank* :locate #f(100 70 0) :world)
   (objects (list *crank* self))
   (let* ((cog-target-pos
	   (if (some #'null (send self :legs))
	       (send (car (send self :links)) :worldpos)
	     (apply #'midpoint 0.5 (send self :legs :end-coords :worldpos))))
	  (fix-leg-coords
	   (unless (some #'null (send self :legs))
	     (send self :legs :end-coords :copy-worldcoords)))
	  ;; append legs' parameters for move-target, link-list, thre, rotation-axis, and target-coords
	  ;;  all parameter list -> (list larm rleg lleg)
	  (move-target (append (list (send self :larm :end-coords))
			       (send self :legs :end-coords)))
	  (link-list (mapcar #'(lambda (l) (send self :link-list (send l :parent)))
			     move-target))
	  (thre (list 15 1 1))
	  (rotation-axis (list nil t t))
	  (fp (apply #'midpoint 0.5 (send-all fix-leg-coords :worldpos))))
     (do-until-key
      (send *crank* :crank-joint :joint-angle 15 :relative t)
      (let* ((target-coords (append (list (send *crank* :crank-handle)) fix-leg-coords)))
	(send self :fullbody-inverse-kinematics target-coords
	      :move-target move-target :link-list link-list
	      :rotation-axis rotation-axis :thre thre
	      :look-at-target t :centroid-thre 10.0
	      :dump-command nil)
	;; draw
	(send *irtviewer* :draw-objects :flush nil)
	(send (send self :support-polygon '(:rleg :lleg)) :draw-on :flush nil :width 4)
	(mapcar #'(lambda (act ref)
		    (send act :draw-on :flush nil :size 100)
		    (send ref :draw-on :flush nil :color #f(1 0 0)))
		(append (list (let ((ac (send self :centroid)))
				(setf (elt ac 2) 0) ac))
			(send-all move-target :worldpos))
		(append (list cog-target-pos) target-coords))
	(send self :draw-torque *viewer*)
	(send *irtviewer* :flush)
	(x::window-main-one)
	))
     ))
  (:full-body-ik
   (&key (target-pos (float-vector 0 0 400))
	 (target (make-coords :pos target-pos))
	 (use-torso t) (use-leg) (debug-view :no-flush))
   "full body ik"
   (send self :reset-pose)
   (if (= (length (car (send self :legs))) 6)
       (send self :legs :angle-vector #f(0 0 -10 20 0 -10)))
   (if (some #'null (send self :legs))
       (send self :newcoords (make-coords))
     (send self :fix-leg-to-coords (make-coords) :lleg))
   (send self :update-descendants)
   (let* ((move-target (send self :larm :end-coords))
	  (link-list
	   (send self :link-list
		 (send move-target :parent)
		 (cond
		  (use-leg (send self :lleg :end-coords :parent))
		  (use-torso (send self :torso :root-link))
		  (t (send self :larm :root-link))))))
     (objects (list self))
     (setq *viewer* (send *irtviewer* :viewer))
     (do-until-key
      (let ((dif-pos (send move-target :difference-position target
			   :translation-axis t))
	    (dif-rot (send move-target :difference-rotation target
			   :rotation-axis nil)))
	(send* self :inverse-kinematics-loop dif-pos dif-rot
               :link-list link-list
               :target-coords target
               :move-target (send self :larm :end-coords)
               :rotation-axis nil :translation-axis t
               :manipulability-gain 0.05
               :debug-view debug-view
               (if use-leg '(:manipulability-limit 0.5)))
       (send self :head :look-at
             (send self :larm :end-coords :worldpos))
       (if (some #'null (send self :legs))
           (send self :newcoords (make-coords))
         (send self :fix-leg-to-coords (make-coords) :lleg))
       (if use-leg (send *irtviewer* :draw-objects :flush nil))
       (send *irtviewer* :viewer :viewsurface :color #f(1 1 1))
       (send *irtviewer* :viewer :viewsurface :line-width 2)
       (send *irtviewer* :viewer :viewsurface :3d-line
             (send self :larm :end-coords :worldpos)
             (send self :rarm :end-coords :worldpos))
       (send *irtviewer* :flush)
       )
      ))
   )
  (:dual-arm-ik
   nil
   (let ((i 0) link-list move-target target-coords)
     (send self :reset-pose)
     (send self :fix-leg-to-coords (make-coords))
     (send self :update-descendants)
    ;; setup move-target and link-list
     (setq move-target (send self :arms :end-coords))
     (setq link-list (mapcar #'(lambda (mt) (send self :link-list mt)) (send-all move-target :parent)))
     ;;
     (setq *broom* (instance sample-broom :init))
     (send *broom* :locate #f(100 0 0))
     (setq *viewer* (send *irtviewer* :viewer))
     (send self :head :look-at (apply #'midpoint 0.5 (send-all (send *broom* :handle) :worldpos)))
     (objects (list self *broom* (send self :head :end-coords)
		    (apply #'midcoords 0.5 (send-all (send *broom* :handle) :worldcoords))))
     (do-until-key
      (send self :inverse-kinematics (send *broom* :handle)
	    :link-list link-list :move-target move-target
	    :stop 500 :thre '(10 10)
	    :rotation-axis '(nil nil) :debug-view nil :dump-command nil)
      (send self :head :look-at
	    (apply #'midpoint 0.5 (send-all (send *broom* :handle) :worldpos))
	    )
      (send *broom* :orient (* 0.2 (sin (/ i 10.0))) :x :world)
      (send *broom* :locate (float-vector 100 (* 100 (sin (/ (incf i) 10.0))) 0) :world)
      (send *irtviewer* :draw-objects)
      (x::window-main-one)
      (incf i)
      )
     ))
  (:dual-manip-ik
   (&key (n 10) (obj (make-cube 20 40 50))
	 (obj-pos (float-vector 150 0 240))
	 &rest args)
   "dual-armed object manipulation"
   (send obj :newcoords (make-coords :pos obj-pos))
   (objects (append (list obj self) (send self :head :end-coords)))
   (setq *viewer* (send *irtviewer* :viewer))
   (send self :reset-pose)
   (send self :fix-leg-to-coords (make-coords))
   (send self :update-descendants)
   (setq *obj* obj)
   (dolist (l '(:rarm :larm))
     (send obj :put l ;; generate target coords
	   (make-cascoords
	    :coords
	    (send (send (send obj :copy-worldcoords)
			:rotate (case l (:rarm pi/2) (:larm -pi/2)) :z)
		  :translate (float-vector -20 0 0))))
     (send obj :assoc (send obj :get l)))
   (send obj :set-color :blue)
   (send self :head :look-at (send obj :worldpos))
   (let ((i 0))
     (do-until-key
      ;; rotate target coords
      (when (/= i 0)
	(let ((l (cond
		  ((or (= (mod i 4) 1) (= (mod i 4) 2)) :rarm)
		  ((or (= (mod i 4) 3) (= (mod i 4) 0)) :larm)))
	      (rot (if (oddp (mod i 4)) (* (case (mod i 4) (1 1) (3 -1)) (deg2rad 90))))
	      (trs (float-vector (* (expt -1 (mod i 2)) 10) 0 0)))
	  (send obj :dissoc (send obj :get l))
	  (send obj :assoc (send obj :get l))
	  (if (oddp (mod i 4))
	      (send (send obj :get l) :rotate rot :x))
	  (send (send obj :get l) :translate trs)))
      (with-move-target-link-list
       (mt robot-ll self '(:rarm :larm))
       (let* ((ret
	       (append-obj-virtual-joint
		robot-ll (mapcar #'(lambda (l) (send obj :get l)) '(:rarm :larm))
		:joint-class 6dof-joint))
	      (ll (car ret)) (ot (cadr ret))
	      (rotation-axis
	       (cond
		((= (mod i 4) 1) '(:x t))
		((= (mod i 4) 3) '(t :x))
		(t '(t t))))
	      (weight
	       (fill (instantiate float-vector
				  (send self :calc-target-joint-dimension ll))
		     1.0)))
	 (dotimes (i 3)
	   (setf (elt weight (+ (- (send self :calc-target-joint-dimension ll) 6) i)) 0.001))
	 (send (send (car ot) :parent) :assoc obj)
	 (send* self :inverse-kinematics ot
		:link-list ll :move-target mt
		:rotation-axis rotation-axis
		:weight weight
		:union-link-list
		#'(lambda (tmp-ll)
		    (apply #'append
			   (mapcar
			    #'(lambda (f)
				(send self :calc-union-link-list
				      (mapcar #'(lambda (l)
						  (funcall
						   f
						   #'(lambda (x) (member x (send self :links))) l))
					      tmp-ll)))
			    (list #'remove-if-not #'remove-if))))
		:jacobi #'(lambda (tmp-ll tmp-mt tmp-ta tmp-ra)
			    (calc-jacobian-from-link-list-including-robot-and-obj-virtual-joint
			     tmp-ll tmp-mt ot self :rotation-axis tmp-ra))
		;;:debug-view t
		:debug-view :no-message
		:dump-command nil
		(append (if (= i 0) '(:stop 100)) args))
	 (send (send (car ot) :parent) :dissoc obj)
	 ))
      (incf i)
      (send self :head :look-at (send obj :worldpos))
      (when (> i n) (return-from :dual-manip-ik nil))
      )
     ))
  (:walk-forward
   (&key (step-height 5) (step 25) (n 3) (th 0))
   "walking motion using preview-control, gait-generator, and fullbody ik"
   (let (footstep-list)
     (send self :reset-pose)
     (send self :legs :move-end-pos #f(0 0 20))
     (send self :fix-leg-to-coords (make-coords))
     (dotimes (i n)
       (push (make-coords :coords
			  (send
			   (send (send self (if (evenp i) :rleg :lleg)
				       :end-coords :copy-worldcoords)
				 :rotate (deg2rad th) :z)
			   :translate (float-vector (* i step) 0 0))
			  :name (if (evenp i) :rleg :lleg))
	     footstep-list))
     (push
      (make-coords :coords
		   (send (send (send self (if (evenp n) :rleg :lleg)
				     :end-coords :copy-worldcoords)
			       :rotate (deg2rad th) :z)
			 :translate (float-vector (* n step) 0 0))
		   :name (if (evenp n) :rleg :lleg))
      footstep-list)
     (push
      (make-coords :coords
		   (send (send (send self (if (evenp n) :lleg :rleg)
				     :end-coords :copy-worldcoords)
			       :rotate (deg2rad th) :z)
			 :translate (float-vector (* n step) 0 0))
		   :name (if (evenp n) :lleg :rleg))
      footstep-list)
     (setq footstep-list (reverse footstep-list))
     (objects (append (list self) footstep-list))
     ;; This should have :l/r method or :l/r name.
     (setq *viewer* (send *irtviewer* :viewer))
     (send self :calc-walk-pattern-from-footstep-list
	   footstep-list :debug-view :no-message :default-step-height step-height)
     (length footstep-list)))
  (:walk-motion
   (&key (x 100) (y 50) (th 45) (ratio 1.0) (step-height 5))
   (send self :reset-pose)
   (send self :legs :move-end-pos #f(0 0 20))
   (send self :fix-leg-to-coords (make-coords))
   (setq *footstep-list*
	 (send self :go-pos-params->footstep-list x y th))
   (objects (cons self *footstep-list*))
   (send self :gen-footstep-parameter :ratio ratio)
   (setq *viewer* (send *irtviewer* :viewer))
   (setq *walk-pattern-list*
	 (send self :calc-walk-pattern-from-footstep-list
	       *footstep-list*
	       :debug-view :no-message :default-step-height step-height))
   (length *walk-pattern-list*))
  )

;; semi2023 2023.12.29
;;
;;	toshima_ws/devel/setup.bash
;;	roslaunch rosserial_python eyes_serial_node.launch
;;	roslaunch realsense2_camera rs_camera.launch enable_infra1:true enable_infra2:=true
;;
;; Semi2023 2023.9.7
;; Semi2022 2022.5.4
;; Semi2021 2021.10.24
;;	
(require :rcb4robots)

(in-package "IMAGE")

(export '(d405-2d-to-3d))
(setq *d405-scale* (/ 180.0 330.0 220.0))

(defun d405-2d-to-3d  (x y d)
  (float-vector (* *d405-scale* (- x (/ 848 2)) d)
		(* *d405-scale* (- y (/ 480 2)) d)
		d))

(defmethod color-image16
 (:init (w h &optional img) (send-super :init w h img 16 3))
 (:pixel (x y)
	 (sys:peek entity (+ (* x pixel-bytes) (* y dim1)) :short))
 (:set-pixel (x y val)
	     (sys:poke val entity (+ (* x pixel-bytes) (* y dim1)) :short))
 (:3dpos (x y)
	 (d405-2d-to-3d x y
			(send self :pixel (round x) (round y))))
 )

(in-package "USER")

;;(require :kxrviewer) ;; when you need GUI
(defmethod x::xwindow
  (:left-button (ev)
		(setq lpos (x::event-pos ev))
		(setq *circle-pos* (float-vector (elt lpos 0) (elt lpos 1)))
		(format t ";; *circle-pos* =~A~%" *circle-pos*))
  )

(setq *flag* t)
(setq *pos* (float-vector (/ 848 2) (/ 480 2) 0))
(setq *3dpos* (float-vector 0 0 300))
(setq *len* 820)
(setq *wrange* '(50 300))
(setq *drange* '(100 800))
(setq *angle* 0)
(setq *show* t)
(defun sprint (x) (if *show* (print x)))

(defun cbrgb (msg)
  (if *flag*
      (let (width height)
	(setq width (send msg :width) height (send msg :height))
	;;(ros::ros-info "w: ~A, h: ~A, encoding: ~A" width height (send msg :encoding))
	(setq rgb (instance color-image24 :init width height (send msg :data)))
	(if (not (boundp '*v-color*))
	    (setq *v-color* (instance x::xwindow :create :width width :height height)))
	(swap-rgb rgb)
	(send *v-color* :putimage (rgb . entity))
	(send *v-color* :flush)
	)))

(defun cb (msg)
  (if *flag*
      (let (width height)
	(setq width (send msg :width) height (send msg :height))
	(setq img (instance color-image16 :init width height (send msg :data)))
	(when (not (boundp '*v-gray*))
	  (setq *v-gray* (instance x::xwindow :create :width width :height height))
	  (send *v-gray* :set-event-proc :buttonrelease-left :left-button *v-gray*)
	  )
	(when (and (boundp '*pos*) *pos*)
	  (setq poss (send img :detect-bar *pos* *len* *angle* :val -1 :wrange *wrange*))
	  )
	(setq gray-image (send img :monochromize))
	(send *v-gray* :putimage ((send gray-image :to24). entity)) ;; to24 for x::window????
	(send *v-gray* :flush)
	)))

(defclass target-pos :super propertied-object
  :slots (2dpos depth 3dpos scan-angle bar-2dwidth))

(defmethod target-pos
  (:init (x y dep)
	 (setq 2dpos (float-vector x y) depth dep)
	 (setq 3dpos (image:d405-2d-to-3d x y dep))
	 self)
  (:2dpos nil 2dpos)
  (:depth nil depth)
  (:3dpos nil 3dpos)
  (:scan-angle nil scan-angle)
  (:bar-2dwidth nil bar-2dwidth)
  )

(defun limage-semishold (li &optional (range '(0 #x10000)))
  (let (l ret (min (car range)) (max (cadr range)))
    (while li
      (setq l (pop li))
      (if (< min l max) (push l ret) (push 0 ret)))
    (nreverse ret)))
(defun limage-select-blob (li &optional (range '(0 10)))
  (let (l (cnt 0) ret (min (car range)) (max (cadr range)))
    (while li
      (setq l (pop li))
      (cond
       ((> l 0) (incf cnt) (push 0 ret))
       ((< min cnt max)
	(push cnt ret)
	(setq cnt 0))
       (t (setq cnt 0) (push 0 ret))))
    (nreverse ret)))

(defmethod image-2d
  (:scan-line-image-2p
   (x0 y0 x1 y1 &optional (val 10000))
   (cond ((>= x0 (send self :width)) (setq x0 (1- (send self :width))))
	 ((< x0 0) (setq x0 0)))
   (cond ((>= x1 (send self :width)) (setq x1 (1- (send self :width))))
	 ((< x1 0) (setq x1 0)))
   (cond ((>= y0 (send self :height)) (setq y0 (1- (send self :height))))
	 ((< y0 0) (setq y0 0)))
   (cond ((>= y1 (send self :height)) (setq y1 (1- (send self :height))))
	 ((< y1 0) (setq y1 0)))
   (setq x0 (round x0) y0 (round y0) x1 (round x1) y1 (round y1))
   (let* ((dx (abs (- x1 x0))) (dy (abs (- y1 y0)))
	  ret err sx sy e2 (flag t))
     (declare (type :integer err dx dy sx sy e2))
     (if (<= x0 x1) (setq sx 1) (setq sx -1))
     (if (<= y0 y1) (setq sy 1) (setq sy -1))
     (setq err (- dx dy))
     (while flag
       (push (send self :pixel x0 y0) ret)
       (if (>= val 0) (send self :set-pixel x0 y0 val))
       (if (and (= x0 x1) (= y0 y1)) (setq flag nil)
	 (progn
	   (setq e2 (* 2 err))
	   (if (> e2 (- dy))
	       (setq err (- err dy) x0 (+ x0 sx)))
	   (if (< e2 dx)
	       (setq err (+ err dx) y0 (+ y0 sy)))
	   )))
     (reverse ret)
     ;;(if (> (* sx sy) 0)
     ;;(reverse ret)
     ;;(if (> dy dx) ret (reverse ret)))
     ))
  (:detect-bar
   (2dp len deg &key (drange *drange*) (wrange *wrange*) (val 10000))   
   (let* ((xc (elt 2dp 0)) (yc (elt 2dp 1))
	  (idx 0) (l2 (/ len 2.0)) (rad (deg2rad deg))
	  x y pidx li0 li (c (* l2 (cos rad))) (s (* l2 (sin rad)))
	  llen l (x0 (- xc c)) (y0 (- yc s)) (x1 (+ xc c)) (y1 (+ yc s)))
     (setq ret nil)
     (setq li0 (send self :scan-line-image-2p x0 y0 x1 y1 val))
     (setq llen (length li0))
     (setq li (limage-semishold li0 drange))
     (setq li (limage-select-blob li wrange))
     (while li
       (setq l (pop li))
       (incf idx)
       (when
	   (> l 0)
	 (setq pidx (- idx (/ l 2.0)))
	 (setq x (+ x0 (* (- x1 x0) (/ pidx llen))))
	 (setq y (+ y0 (* (- y1 y0) (/ pidx llen))))
	 (setq tpos (instance target-pos :init x y (elt li0 (round pidx))))
	 (setq *3dpos* (send tpos :3dpos))
	 (setq (tpos . scan-angle) deg)
	 (setq (tpos . bar-2dwidth) l)
	 ;;(push tpos ret)
	 (setq ret (list tpos)))
       )
     ret))
    )

;; for kxrmw4 mecanam wheel base
(defun mw-stop nil
  (send *robot* :rleg-knee-w :joint-angle 0)
  (send *robot* :lleg-knee-w :joint-angle 0)
  (send *robot* :rleg-crotch-w :joint-angle 0)
  (send *robot* :lleg-crotch-w :joint-angle 0)
  (send *ri* :wheel-angle-vector (send *robot* :angle-vector) 100)
  )
(defun mw-move-xy (&optional (xv 5) (yv 5) (v 5) &key (scale-trans 1.0) (scale-theta 1.0) (tm 1000))
  (send *ri* :hold)
  (send *robot* :rleg-crotch-w :joint-angle (+ (* scale-trans (+ xv (- yv))) (* scale-theta v)))
  (send *robot* :rleg-knee-w :joint-angle (+ (* scale-trans (+ xv yv)) (* scale-theta v)))
  (send *robot* :lleg-crotch-w :joint-angle (+ (* scale-trans (+ xv yv)) (* scale-theta (- v))))
  (send *robot* :lleg-knee-w :joint-angle (+ (* scale-trans (+ xv (- yv))) (* scale-theta (- v))))
  (send *ri* :wheel-angle-vector (send *robot* :angle-vector) tm)
  (mw-stop)
  )

(defun mw-fore (&optional (v 10) &key (scale-trans 1.0) (scale-theta 1.0) (tm 1000))
  (mw-move-xy v 0 0 :scale-trans scale-trans :scale-theta scale-theta :tm tm)
  )
(defun mw-right (&optional (v 10) &key (scale-trans 1.0) (scale-theta 1.0) (tm 1000))
  (mw-move-xy 0 v 0 :scale-trans scale-trans :scale-theta scale-theta :tm tm)
  )
(defun mw-turn (&optional (v 10) &key (scale-trans 1.0) (scale-theta 1.0) (tm 1000))
  (mw-move-xy 0 0 v :scale-trans scale-trans :scale-theta scale-theta :tm tm)
  )
  
;; for kxr2r dual active wheel and dual passive wheel
(defun dw-stop nil
  (send *robot* :rleg-crotch-w :joint-angle 0)
  (send *robot* :lleg-knee-w :joint-angle 0)
  (send *robot* :send-to-ri)
  )

(defun dw-fore (&optional (v 10))
  (send *robot* :rleg-crotch-w :joint-angle v)
  (send *robot* :lleg-knee-w :joint-angle v)
  (send *robot* :send-to-ri)
  (unix::usleep (* 100 1000))
  (dw-stop))

(defun dw-turn (&optional (v 10))
  (send *robot* :rleg-crotch-w :joint-angle v)
  (send *robot* :lleg-knee-w :joint-angle (- v))
  ;;(send *robot* :send-to-ri)
  (send *ri* :wheel-angle-vector (send *robot* :angle-vector))
  (unix::usleep (* 100 1000))
  (dw-stop))
  
;;; for kxrow4 omniwheel base
(defun ow-stop nil
  (send *robot* :rleg-knee-w :joint-angle 0)
  (send *robot* :lleg-knee-w :joint-angle 0)
  (send *robot* :rleg-crotch-w :joint-angle 0)
  (send *robot* :lleg-crotch-w :joint-angle 0)
  ;;(send *robot* :send-to-ri)
  (send *ri* :wheel-angle-vector (send *robot* :neutral))
  )
(defun ow-move (&optional (x 10) (y 0) (th 0) (msec 10))
  (send *robot* :rleg-crotch-w :joint-angle (+ x th))
  (send *robot* :lleg-crotch-w :joint-angle (- th x))
  (send *robot* :rleg-knee-w :joint-angle (+ y th))
  (send *robot* :lleg-knee-w :joint-angle (- th y))
  ;;(send *robot* :send-to-ri)
  (send *ri* :wheel-angle-vector (send *robot* :angle-vector))
  (unix::usleep (* msec 1000))
  (ow-stop)
  )
(defun ow-fore (&optional (v 10) (msec 10))
  (send *robot* :rleg-crotch-w :joint-angle v)
  (send *robot* :lleg-crotch-w :joint-angle (- v))
  (send *robot* :rleg-knee-w :joint-angle 0)
  (send *robot* :lleg-knee-w :joint-angle 0)
  ;;(send *robot* :send-to-ri)
  (send *ri* :wheel-angle-vector (send *robot* :angle-vector))
  (unix::usleep (* msec 1000))
  (ow-stop)
  )
(defun ow-right (&optional (v 10) (msec 10))
  (send *robot* :rleg-crotch-w :joint-angle 0)
  (send *robot* :lleg-crotch-w :joint-angle 0)
  (send *robot* :rleg-knee-w :joint-angle v)
  (send *robot* :lleg-knee-w :joint-angle (- v))
  ;;(send *robot* :send-to-ri)
  (send *ri* :wheel-angle-vector (send *robot* :angle-vector))
  (unix::usleep (* msec 1000))
  (ow-stop)
  )
(defun ow-turn (&optional (v 10) (msec 10))
  (send *robot* :rleg-knee-w :joint-angle v)
  (send *robot* :lleg-knee-w :joint-angle v)
  (send *robot* :rleg-crotch-w :joint-angle v)
  (send *robot* :lleg-crotch-w :joint-angle v)
  ;; (send *robot* :send-to-ri)
  (send *ri* :wheel-angle-vector (send *robot* :angle-vector))
  (unix::usleep (* msec 1000))
  ;;(ow-stop)
  (send *ri* :wheel-stop)
  )


(defvar *semi2022-setup*)

(defun my-robot (&optional name)
  (cond
    ((null name) *my-robot-name*)
    ((stringp name)
     (setq *my-robot-name* name))
    ((symbolp name)
     (setq *my-robot-name* (string-downcase (string name)))))
  *my-robot-name*)
      
(unless (boundp '*my-robot-name*)
  (my-robot "kxrl2semi2022"))

(defun kxr-connect nil
  (unless (boundp '*ri*)
    (make-kxr-robot (my-robot) :viewer nil)
    (format *error-output* ";; ~A is created~%" (my-robot))
    )
  (unless (*ri* . com-port)
    (format *error-output* ";; :com-init connect ~A~%"
	    (if (member :arm *features*)
		(send *ri* :com-init :devname "ttyS0")
		(send *ri* :com-init)))
    (send *ri* :neutral)
    )
  )


(defun semi-send (&rest args)
  (kxr-connect)
  (when (*ri* . com-port)
    (format t "semi-send ~A~%" args)
    (send* *ri* args)
    ))

(defvar *pose-memory-list*)
(defun save-motion (sym &optional (fname (format nil "~A-motions.l" *my-robot-name*)))
  (let* (objs voice-key)
    (if (probe-file fname) (setq objs (read-lists fname)))
    (setq objs (append objs `((setq ,sym ',(reverse *pose-memory-list*)))))
    (apply #'dump-structure fname objs)
    sym))
(defun load-motion (&optional (fname (format nil "~A-motions.l" *my-robot-name*)))
  (mapcar #'(lambda (l) (eval l) (cadr l)) (read-lists fname)))
(defun run-motion (vlist &optional (time 500))
  (dolist (v vlist) (send *ri* :angle-vector v time))
  )

;;;
;;; lisp motion
;;;
(defmacro servo (ri poses &optional time)
  `(let* ((methods ',poses)
	  (robo (send ,ri :robot)))
     (cond
       ((symbolp methods)
	(send ,ri methods))
       (t
	(cond
	  ((listp (car methods))
	   (mapc #'(lambda (method) (send* robo method)) methods))
	  ((find-method robo (car methods))
	   (send* robo methods))
	  (t (send* ,ri methods)))
	(dolist (j (send robo :joint-list))
	  (if (eq (send j :joint-type) :wheel) (send j :joint-angle 0)))
	(send ,ri :angle-vector (send robo :angle-vector) ,time)))
     ))

(defun lisp-hold nil (semi-send :hold))
(defun lisp-free nil (semi-send :free))
(defun lisp-hello nil
  (semi-send :hold)
  (semi-send :neutral)
  (semi-send :pose-methods
	     '((:neutral)
	       (:angle-plist
		:head-neck-p 45	:larm-shoulder-p 30 :rarm-shoulder-p 30
		:larm-shoulder-r 10 :rarm-shoulder-r -10)) 300)
  (semi-send :pose-methods
	     '((:angle-plist
		:head-neck-p 0 :larm-shoulder-p 0 :rarm-shoulder-p 0)) 300)
  )
(defun lisp-right-hand nil
  (semi-send :hold)
  (semi-send :pose-methods
	     '((:angle-plist
		:rarm-shoulder-p -170 :rarm-elbow-p -20 :rarm-wrist-p 80)) 1000)
  )
(defun lisp-left-hand nil
  (semi-send :hold)
  (semi-send :pose-methods
	     '((:angle-plist
		:larm-shoulder-p -170 :larm-elbow-p -20 :larm-wrist-p 80)) 1000)
  )
(defun lisp-both-hand (&optional (time 1500))
  (semi-send :hold)
  (semi-send :pose-methods
	     '((:angle-plist
		:rarm-shoulder-p -170 :rarm-elbow-p -20 :rarm-wrist-p 80
		:larm-shoulder-p -170 :larm-elbow-p -20 :larm-wrist-p 80)) time)
  )
(defun lisp-neutral (&optional (time 1500))
  (semi-send :hold)
  (semi-send :neutral time))
(defun lisp-release nil
  (semi-send :release))

(setq *walk-step-time* 500)
(defun lean-right (&key (angle 18) (time *walk-step-time*))
  (semi-send :pose-methods `((:lean-right-pose ,angle)) time))
(defun lean-left (&key (angle 18) (time *walk-step-time*))
  (semi-send :pose-methods `((:lean-left-pose ,angle)) time))
(defun fore-right (&key (angle 18) (time *walk-step-time*))
  (semi-send :pose-methods `((:fore-right-pose ,angle)) time))
(defun fore-left (&key (angle 18) (time *walk-step-time*))
  (semi-send :pose-methods `((:fore-left-pose ,angle)) time))
(defun walk-step (&key (step 2) (fore-angle 20) (lean-angle 18)
		    (time *walk-step-time*))
  (while (>= step 1)
    (lean-left :angle lean-angle :time time)
    (fore-right :angle fore-angle :time time)
    (lean-left :angle 0)
    (lean-right :angle lean-angle :time time)
    (setq step (1- step))
    (if (= step 0)
	(fore-left :angle 0 :time time)
	(fore-left :angle fore-angle :time time))
    (lean-right :angle 0 :time time))
  )
;;;
;;; Voice Word functions
;;;
(defvar *voice-function-list*)
(defmacro defun-voice (func voice-list &rest body)
  ;;(unless *semi2022-setup* (semi2022-setup))
  `(progn
     (if (atom ',voice-list)
	 (pushnew ,voice-list (get ',func :voice-words))
	 (setf (get ',func :voice-words)
	       (remove-duplicates (append ',voice-list (get ',func :voice-words)) :test #'equal)))
     (pushnew ',func *voice-function-list*)
     (defun ,func (&optional word)
       (format *error-output* ";; ~A is called by a word ~A in ~A~%" ',func word
	       (get ',func :voice-words))
       ,@body)
     ',func))

(defun voice-words (func) (get func :voice-words))
(defun find-voice-function (str)
  (find-if #'(lambda (vlist)
	       (some #'(lambda (x) (substringp x str)) vlist))
	   *voice-function-list*
	   :key #'(lambda (x) (get x :voice-words))))

(defun execute-word (str)
  (let ((f (find-voice-function str)))
    (cond
      (f
       (format *error-output* ";; execute-word ~A and execute func=~A~%" str f)
       (funcall f str))
      (t
       (setq *last-word* str)
       (format *error-output* ";; voice-function for ~A is not defined~%" str))))
  )

(defun-voice semi-hold ("ホールド")
  (lisp-hold)  ;; or (rcb-hold)
  )
(defun-voice semi-connect ("コネクト" "接続" "初期 化" "初期")
  (kxr-connect))
(defun-voice semi-free ("フリー" "楽にして" "休んで")
  (lisp-free) ;; or (rcb-free)
  )
(defun-voice semi-release ("リリース" "止まれ" "止まって")
  ;;(rcb-release) ;; or (send-send :release)
  (lisp-release))
(defun-voice semi-neutral ("ニュートラル" "ゼロ" "戻れ" "もと に" "もとに")
  (lisp-neutral) ;; or (rcb-neutral)
  )
(defun-voice semi-hello ("挨拶" "こんにちは" "こんにちわ" "今日 は" "今日は")
  (lisp-hello)  ;; or (rcb-hello)
  )
(defun-voice semi-left-hand ("左手" "左 て" "左て")
  ;;(rcb-left-hand) ;; or (lisp-left-hand)
  (lisp-left-hand)
  )
(defun-voice semi-right-hand ("右手" "右 て" "右て")
  ;;(rcb-right-hand)  ;; or (lisp-right-hand)
  (lisp-right-hand)
  )
(defun-voice semi-both-hand ("万歳" "両手" "バンザイ")
  ;;(rcb-both-hand)
  (lisp-both-hand)
  )

(defun-voice semi-cube ("ルービックキューブ" "キューブ")
  ;;(rcb-cube-both)
  (servo *ri* ((:cube-larm-pose) (:cube-rarm-pose)) 500)
  )
(defun-voice semi-fore ("前 へ" "前" "前へ")
  ;;(rcb-walk-fore) ;; or (walk-step :fore-angle 18 :step 2 :lean-angle 15)
  (walk-step :fore-angle 18 :step 2 :lean-angle 15)  
  )
(defun-voice semi-back ("後ろ へ" "後" "後ろへ")
  ;; (rcb-walk-back) ;; or (walk-step :fore-angle -18 :step 2 :lean-angle 15)
  (walk-step :fore-angle -18 :step 2 :lean-angle 15)
  )
(defun-voice semi-right ("右 へ" "右へ")
  ;;(rcb-cube-right)
  (servo *ri* (:cube-rarm-pose) 500)
  )
(defun-voice semi-left ("左 へ" "左へ")
  ;;(rcb-cube-left)
  (servo *ri* (:cube-larm-pose) 500)
  )

(defun-voice semi-demo ("でも" "で も" "動け")
  (demo-all))
(defun-voice semi-close ("閉じて" "とじて" "持って")
  ;;(rcb-cube-close)
  (servo *ri* (:close-hand -10) 200)
  )
(defun-voice semi-open ("開いて" "開けて" "ください" "下さい")
  ;;(rcb-cube-open)
  (servo *ri* (:open-hand 10) 200)
  )
(defun-voice semi-place ("置いて" "おいて")
  ;;(rcb-cube-place)
  (servo *ri* (:cube-up-pose) 200)
  (servo *ri* (:close-hand -10) 200)
  (servo *ri* (:cube-down-pose) 200)
  (servo *ri* (:open-hand 10) 200)
  (servo *ri* (:cube-up-pose) 200)
  )
(defun-voice semi-grasp ("持ち上げて" "上げて" "取って")
  ;;(rcb-cube-grasp)
  (servo *ri* (:open-hand 10) 200)
  (servo *ri* ((:cube-up-pose)
	       (:larm :move-end-pos #f(0 0 -20))
	       (:rarm :move-end-pos #f(0 0 -20)))
	 200)
  (servo *ri* (:close-hand -10) 200)
  (servo *ri* ((:larm :move-end-pos #f(0 0 20))
	       (:rarm :move-end-pos #f(0 0 20)))
	 200)
  )

;;;
(defun-voice semi-memory ("記憶" "おぼえて" "覚えて" "メモリー" "ここ")
  (push (copy-object (send *ri* :read-angle-vector)) *pose-memory-list*)
  ;;(speak-jp "はい 覚えたよ")
  )
(defun-voice semi-pop ("忘れて" "ぽっぷ")
  (pop *pose-memory-list*)
  ;;(speak-jp "はい さっきのを 忘れたよ")
  )

(defun-voice semi-clear ("クリアー" "クリア" "全部" "全部忘れて" "忘却")
  (setq *pose-memory-backup-list* *pose-memory-list*)
  (setq *pose-memory-list* nil)
  ;;(speak-jp "はい 全部 忘れたよ")
  )

(defun save-motion-word (str &optional (fname (format nil "~A-word-motions.l" *my-robot-name*)))
  (let* (objs v)
    (if (probe-file fname) (setq objs (read-lists fname)))
    (if (setq v (assoc str objs :test #'string=))
	(rplacd v (reverse *pose-memory-list*))
	(setq objs (append objs (list (cons str (reverse *pose-memory-list*))))))
    (apply #'dump-structure fname objs)
    str))

(defun-voice semi-store ("保存して" "保存")
  (let ((word (get-next-word "動作名は？")))
    (save-motion-word *next-word*)
    (format *error-output*
	    ";; ~A was stored to ~A~%" *next-word* (format nil "~A-word-motions.l" *my-robot-name*))
    )
  )
(defun exec-motion-word (str &optional (fname (format nil "~A-word-motions.l" *my-robot-name*)))
  (let* (objs v)
    (if (probe-file fname) (setq objs (read-lists fname)))
    (when
	(setq v (assoc str objs :test #'string=))
      (send *ri* :hold)
      (dolist (v (cdr v))
	(if (derivedp v float-vector)
	    (send *ri* :angle-vector v *memory-motion-speed*)
	    (format *error-output* ";; av not float-vector ~A~%" v)
	    )
	str))
    )
  )
(defun-voice semi-call ("呼び出して" "呼び出し")
  (let ((word (get-next-word "動作名は")))
    (format *error-output*
	    ";; ~A in ~A will be executed~%" *next-word* (format nil "~A-word-motions.l" *my-robot-name*))
    (exec-motion-word *next-word*)
    )
  )

(defvar *memory-motion-speed*)
(setq *memory-motion-speed* 700)
(defun-voice semi-replay ("再現" "再現して" "再現してみて" "やってみて")
  (send *ri* :hold)
  (dolist (v (reverse *pose-memory-list*))
    (if (derivedp v float-vector)
	(send *ri* :angle-vector v *memory-motion-speed*)
	(format *error-output* ";; av not float-vector ~A~%" v)
	)
    ))

(defun-voice semi-faster ("早く" "いそいで")
  (decf *memory-motion-speed* 200)
  (if (< *memory-motion-speed* 100) (setq *memory-motion-speed* 50))
  ;;(speak-jp "はい 全部 忘れたよ")
  )

(defun-voice semi-slower ("遅く" "ゆっくり")
  (incf *memory-motion-speed* 200)
  (if (> *memory-motion-speed* 1500) (setq *memory-motion-speed* 1500))
  ;;(speak-jp "はい 全部 忘れたよ")
  )
;;;
(defun demo-all nil
  (demo-head)
  (demo-gripper)
  (demo-arm)
  (demo-leg)
  (demo-head)
  (demo-gripper)
  (demo-cube)
  (send *ri* :neutral)
  )

(defun demo-cube (&optional (tm 1000))
  (send *robot* :neutral)
  (send *robot* :cube-neutral-pose)
  (send *robot* :send-to-ri tm)
  (send *robot* :cube-rarm-pose)
  (send *robot* :send-to-ri tm)
  (send *robot* :cube-both-pose)
  (send *robot* :send-to-ri tm)
  (send *robot* :cube-larm-pose)
  (send *robot* :send-to-ri tm)
  (dotimes (i 3)
    (send *robot* :cube-up-pose)
    (send *robot* :send-to-ri tm)
    (send *robot* :cube-down-pose)
    (send *robot* :send-to-ri tm))
  )

(defun demo-head (&optional (angle 45) (tm 500))
  (send *ri* :hold)
  (send *robot* :neutral)
  (send *robot* :head-neck-y :joint-angle angle)
  (send *robot* :send-to-ri (/ tm 2))
  (send *robot* :head-neck-y :joint-angle (- angle))
  (send *robot* :send-to-ri tm)  
  (send *robot* :head-neck-y :joint-angle 0)
  (send *robot* :send-to-ri (/ tm 2))
  (send *robot* :head-neck-p :joint-angle (- angle))
  (send *robot* :send-to-ri (/ tm 2))
  (send *robot* :head-neck-p :joint-angle angle)
  (send *robot* :send-to-ri tm )
  (send *robot* :head-neck-p :joint-angle 0)
  (send *robot* :send-to-ri (/ tm 2))
  (send *ri* :free :head)
  )

(defun demo-leg (&optional (angle 25) (tm 700))
  (send *ri* :hold)
  (send *robot* :lleg-crotch-r :joint-angle (- angle))
  (send *robot* :rleg-crotch-r :joint-angle (/ angle -2))
  (send *robot* :send-to-ri tm)
  (send *robot* :lleg-crotch-r :joint-angle 0)
  (send *robot* :rleg-crotch-r :joint-angle 0)
  (send *robot* :send-to-ri tm)
  (send *robot* :rleg-crotch-r :joint-angle angle)
  (send *robot* :lleg-crotch-r :joint-angle (/ angle 2))
  (send *robot* :send-to-ri tm)
  (send *robot* :lleg-crotch-r :joint-angle 0)
  (send *robot* :rleg-crotch-r :joint-angle 0)
  (send *robot* :send-to-ri tm)
  (send *ri* :free)
  )
(defun demo-gripper (&key (tm 100) (n 5))
  (dotimes (i n)
    (send *robot* :larm-gripper-r :joint-angle 23)
    (send *robot* :rarm-gripper-r :joint-angle 23)
    (send *robot* :send-to-ri tm)
    (send *robot* :larm-gripper-r :joint-angle -20)
    (send *robot* :rarm-gripper-r :joint-angle -20)
    (send *robot* :send-to-ri tm))
  (send *robot* :larm-gripper-r :joint-angle 0)
  (send *robot* :rarm-gripper-r :joint-angle 0)
  (send *robot* :send-to-ri tm)
  (send *robot* :larm-wrist-r :joint-angle 90)
  (send *robot* :rarm-wrist-r :joint-angle (- 90))
  (send *robot* :send-to-ri (* 4 tm))
  (send *robot* :larm-wrist-r :joint-angle (- 90))
  (send *robot* :rarm-wrist-r :joint-angle 90)
  (send *robot* :send-to-ri (* 4 tm))
  (send *robot* :larm-wrist-r :joint-angle 0)
  (send *robot* :rarm-wrist-r :joint-angle 0)
  (send *robot* :send-to-ri (* 4 tm))
  )

(defun demo-arm (&optional (angle 40) (tm 500))
  (let ((angle2 (/ angle 2)))
    (send *ri* :hold)
    (send *ri* :neutral)
    (send *robot* :larm-shoulder-r :joint-angle angle2)
    (send *robot* :rarm-shoulder-r :joint-angle (- angle2))
    (send *robot* :send-to-ri tm)
    (send *robot* :larm-wrist-r :joint-angle angle2)
    (send *robot* :rarm-wrist-r :joint-angle (- angle2))
    (send *robot* :send-to-ri tm)
    (send *robot* :larm-wrist-r :joint-angle (- angle2))
    (send *robot* :rarm-wrist-r :joint-angle angle2)
    (send *robot* :send-to-ri tm)
    (send *robot* :larm-shoulder-p :joint-angle (- angle))
    (send *robot* :rarm-shoulder-p :joint-angle (- angle))  
    (send *robot* :send-to-ri tm)
    (send *robot* :larm-elbow-p :joint-angle angle)
    (send *robot* :rarm-elbow-p :joint-angle angle)
    (send *robot* :send-to-ri tm)
    (send *robot* :larm-wrist-p :joint-angle angle)
    (send *robot* :rarm-wrist-p :joint-angle angle)
    (send *robot* :send-to-ri tm)
    (send *robot* :larm-wrist-p :joint-angle 0)
    (send *robot* :rarm-wrist-p :joint-angle 0)
    (send *robot* :send-to-ri tm)
    (send *robot* :larm-elbow-p :joint-angle (- angle))
    (send *robot* :rarm-elbow-p :joint-angle (- angle))
    (send *robot* :send-to-ri tm)
    (send *robot* :larm-shoulder-p :joint-angle angle)
    (send *robot* :rarm-shoulder-p :joint-angle angle)
    (send *robot* :send-to-ri tm)
    (send *ri* :neutral)
    ;;(send *ri* :free)
    )
  )

(defmethod robot-model
    (:demo-head
     (&optional (angle 45) (tm 500))
	`(((:neutral) (:angle-plist :head-neck-y ,angle)  ,(/ tm 2))
	  ((:angle-plist :head-neck-y ,(- angle)) ,tm)
	  ((:angle-plist :head-neck-y 0) ,(/ tm 2))
	  ((:angle-plist :head-neck-p ,(- angle)) ,(/ tm 2))
	  ((:angle-plist :head-neck-p ,angle) ,tm)
	  ((:angle-plist :head-neck-p 0) ,(/ tm 2))
	  ))
  (:demo-leg
   (&optional (angle 25) (tm 700))
   '(((:angle-plist :lleg-crotch-r ,(- angle) :rleg-crotch-r ,(/ angle -2)) ,tm)
     ((:angle-plist :lleg-crotch-r 0 :rleg-crotch-r 0) , tm)
     ((:angle-plist :rleg-crotch-r ,angle :lleg-crotch-r ,(/ angle 2)) ,tm)
     ((:angle-plist :lleg-crotch-r 0 :rleg-crotch-r 0) ,tm)))
  (:demo-gripper
   (&key (tm 100) (n 5))
   (dotimes (i n)
     (send robot :larm-gripper-r :joint-angle 23)
     (send robot :rarm-gripper-r :joint-angle 23)
     (send robot :send-to-ri tm)
     (send robot :larm-gripper-r :joint-angle -20)
     (send robot :rarm-gripper-r :joint-angle -20)
     (send robot :send-to-ri tm))
   (send *robot* :larm-gripper-r :joint-angle 0)
   (send *robot* :rarm-gripper-r :joint-angle 0)
   (send *robot* :send-to-ri tm)
   (send *robot* :larm-wrist-r :joint-angle 90)
   (send *robot* :rarm-wrist-r :joint-angle (- 90))
   (send *robot* :send-to-ri (* 4 tm))
   (send *robot* :larm-wrist-r :joint-angle (- 90))
   (send *robot* :rarm-wrist-r :joint-angle 90)
   (send *robot* :send-to-ri (* 4 tm))
   (send *robot* :larm-wrist-r :joint-angle 0)
   (send *robot* :rarm-wrist-r :joint-angle 0)
   (send *robot* :send-to-ri (* 4 tm))
   )
  )
;;;
;; teleoperation
(defun init-teleop ()
  (setup-ris "kxrl2semi2022" "kxrl2semi2022")
  (setup-coms)
  )

(defun hold (&rest args) 
  (dolist (id args) (send (elt *ris* id) :hold)))
(defun free (&rest args) 
  (dolist (id args) (send (elt *ris* id) :free)))

(defun follow-self (&optional (idx 0))
  (do-until-key
   (send (elt *ris* idx) :angle-alist (send (elt *ris* idx) :read-angle-alist) 1)
   ))

(defun bi-demo (&key (stretch 8) (scale 1.0))
  (dolist (ri *ris*) (send ri :send-stretch stretch) (send ri :hold))
  (do-until-key
   (setq al1 (send (elt *ris* 0) :read-angle-alist))
   (setq al2 (send (elt *ris* 1) :read-angle-alist))
   (send (elt *ris* 0) :angle-alist (angle-alist+ al1 (angle-alist-scale scale (angle-alist- al2 al1))) 1)
   (send (elt *ris* 1) :angle-alist (angle-alist+ al2 (angle-alist-scale scale (angle-alist- al1 al2))) 1)
   )
  (dolist (ri *ris*) (send ri :send-stretch 127))
  )
(defun uni-demo (&key (stretch 50))
  (dolist (ri (cdr *ris*)) (send ri :send-stretch stretch) (send ri :hold))
  (do-until-key
   (mapc #'(lambda (ri)
	     (send ri :angle-alist (send (car *ris*) :read-angle-alist) 1))
	 (cdr *ris*))
   )
  (dolist (ri *ris*) (send ri :send-stretch 127))
  )
;;;
(defun standing-p (&optional (angle 60))
  (and (stable-p) (send *ri* :standing-p angle)))
(defun fall-down-p (&optional (angle 30))
  (and (stable-p) (send *ri* :fall-down-p angle)))
(defun face-down-p (&optional (angle -60))
  (and (fall-down-p) (send *ri* :face-down-p angle)))
(defun face-up-p (&optional (angle 60))
  (and (fall-down-p) (send *ri* :face-up-p angle)))
(defun gyro-norm nil
  (unless (send *ri* :com-port) (send *ri* :com-init))
  (norm (coerce (send *ri* :cstruct-slot madgwick-cstruct 'gyro) float-vector)))
(defun stable-p (&optional (th 1))
  (cond
   ((< (gyro-norm) th) t)
   (t (madgwick-calib) (< (gyro-norm) th))))
    

(unless (boundp '*box*)
  (setq *box* (make-cube 60 60 60)))

(when (or (not (boundp '*boxes*)) (not (consp *boxes*)))
  (setq *boxes* nil)
  (dolist (c (list :red :green :blue))
    (push (make-cube 65 65 65) *boxes*)
    (send (car *boxes*) :set-color c))
  (setq *boxes* (reverse *boxes*)))

(defun make-box2 ()
  (make-cube 60 60 60 :pos (float-vector (+ 200 (random 200)) (- (random 400) 200) (random 300))))

(defun objects-move-end-pos (dv)
  (send (send *robot* :larm-end-coords) :assoc *box*)
  (send *robot* :legs :move-end-pos dv :world)
  (send *robot* :fix-leg-to-coords (make-coords))
  (objects-centroid))

(defun objects-centroid nil
  (let* ((objs (objects))
	 (w (reduce #'+ (send-all objs :weight)))
	 (c (reduce
	     #'v+
	     (mapcar #'(lambda (o) (scale (send o :weight) (send o :centroid)))
		     objs))))
    (scale (/ 1.0 w) c)))

(defun semi-look-demo ()
  (setq *box2* (make-box2))
  (pickup-pose :z (random 300))
  (send *robot* :look-at-target *box2*)
  (objects (list *box2* *robot*))
  (send *robot* :show-collisions)
  )

(defun semi-look-at (&optional (v *target*))
  (if (null v) (setq v (float-vector 300 0 30)))
  (if (derivedp v coordinates) (setq v (send v :worldpos)))
  (setq *detected-objects* nil)
  (send *robot* :fix-leg-to-coords (make-coords))
  (send *robot* :look-at-target v)
  (send *robot* :send-to-ri)
  (send *ri* :find-stereo-tags)
  )

(defun semi-pickup-demo (&key real-body)
  (unless *semi2021-setup* (semi2021-setup))
  (send *ri* :hold)
  (send *ri* :neutral)
  (setq *target* nil)
  (approach-box)
  (pickup)
  )

(defun semi-face-demo (&key real-body)
  (unless *semi2021-setup* (semi2021-setup))
  (send *ri* :hold)
  (send *ri* :neutral)
  (setq *face* nil)
  (look-for-face)
  )

(defun semi-find-box nil
  (when (setq objs (send *ri* :find-stereo-tags))
    (push-objects objs)
    ))

(defparameter *motion-log* nil)
(defvar *target*)

(defclass log-data
  :slots (time lend rend coords angle-vector objects))

(defun register-reset nil (setq *motion-log* nil))
(defun register-print nil (mapc #'(lambda (x) (print x *error-output*)) (reverse *motion-log*)))
(defun register-data (&optional (time 1000))
  (let*
      ((lp (send (send (send *robot* :larm-end-coords) :copy-worldcoords) :worldpos))
       (rp (send (send (send *robot* :rarm-end-coords) :copy-worldcoords) :worldpos))
       (fl (assocdr :larm (car *motion-log*)))
       (fr (assocdr :rarm (car *motion-log*))))
    ;;(when (and fl fr) (send *box* :translate (midpoint 0.5 (v- lp fl) (v- rp fr)) :world))
    (send *robot* :fix-leg-to-coords (make-coords))
    (send *robot* :viewer :look-all)
    (push
     (list
      (cons :time time)
      (cons :box (send (send *box* :copy-worldcoords) :worldpos))
      (cons :larm lp)
      (cons :rarm rp))
     *motion-log*)
    *motion-log*))

(defun neutral-pose (&key (time 2000) limbs mi real-body)
  (send *robot* :assoc *box*)
  (if limbs (send *robot* :neutral limbs)
    (send *robot* :neutral))
  (send *robot* :fix-leg-to-coords (make-coords))
  (send *robot* :viewer :look-all)
  (when mi (send *ri* :push-angle-vector-codes (send *robot* :angle-vector) time limbs))
  (when real-body (send *ri* :neutral time limbs))
  (unless (or real-body mi) (unix::usleep (* time 1000)))
  (register-data time)
  )

(defun rcb4-asm-program? (aa)
  (every #'(lambda (a) (or (symbolp a) (and (listp a) (keywordp (car a))))) aa))

(defvar *rcb-motion-bin-check*)
(defun store-rcb4-motion (name aa no)
  (let (old bin)
    (if (rcb4-asm-program? aa)
	(setf (get name :rcb4-asm) aa)
	(setf (get name :rcb4-asm) (rcb4lisp::compile aa)))
    (setf (get name :motion-table-no) no)
    (setq old (get name :rcb4-bin))
    (setq bin (rcb4-assemble (get name :rcb4-asm) no))
    (cond
      ((and *rcb-motion-bin-check* (equal old bin))
       (format *error-output* ";; already defined ~A :rcb4-bin is same~%" name))
      (t (setf (get name :rcb4-bin) bin)
	 (send *ri* :write-motion-lst (get name :rcb4-bin) no (format nil "(~A ~A)" no name))
	 (format *error-output* ";; def-rcb-motion ~A = ~A~%" name no)))
    t))
;;;
(defvar *rcb-motion-functions*)
(defmacro def-rcb-motion (name num body)
  `(progn
     (setf (get ',name :rcb4-prog) ,body)
     (defun ,name nil (if (get ',name :motion-table-no)
			  (send *ri* :call-motion (get ',name :motion-table-no))))
     (push ',name *rcb-motion-functions*)
     (store-rcb4-motion ',name ,body ,num)))

(defun rcb-erase (&optional fun)
  (cond
    ((and fun 
	  (member fun *rcb-motion-functions*))
     (setq *rcb-motion-functions* (remove *rcb-motion-functions*))
     (setf (get fun :rcb4-bin) nil))
    (t
     (mapcar #'(lambda (x) (rcb-erase x)) 
	     *rcb-motion-functions*))))

(defun kxr-hold nil (send *ri* :hold))
(defun kxr-free nil (send *ri* :free))

(defmethod robot-model
    (:cube-neutral-pose
     nil
     (let ((args
	    (list
	     :angle-plist
	     :larm-shoulder-r 20 :rarm-shoulder-r -20
	     :larm-wrist-r -20 :rarm-wrist-r 20))
	   )
       (send self :neutral)
       (send* self args)
       (send self :angle-plist)))
  (:cube-both-pose
   nil
   (append (send self :cube-rarm-pose)
	   (send self :cube-larm-pose)))
  (:cube-rarm-pose
   nil
   (let ((args (list :angle-plist
		     :rarm-shoulder-p -60 :rarm-shoulder-r -42
		     :rarm-shoulder-y 86 :rarm-elbow-p -89
		     :rarm-wrist-p 51 :rarm-wrist-r 60)))
     (send* self args)
     args))
  (:cube-larm-pose
   nil
   (let ((args (list
		:angle-plist
		:larm-shoulder-p -60 :larm-shoulder-r 42
		:larm-shoulder-y -86 :larm-elbow-p -89
		:larm-wrist-p 51 :larm-wrist-r -60)))
     (send* self args)
     args))
  (:close-hand
   (&optional (angle -10))
   (let ((args (list
		:angle-plist
		:larm-gripper-r angle :rarm-gripper-r angle
		:larm-gripper2-r angle :rarm-gripper2-r angle)))
     (send* self args)
     args))
  (:open-hand
   (&optional (angle 10))
   (let ((args (list :angle-plist
		     :larm-gripper-r angle :rarm-gripper-r angle
		     :larm-gripper2-r angle :rarm-gripper2-r angle)))
     (send* self args)
     args))
  (:cube-up-pose
   ()
   (let ((args (list :angle-plist
		     :larm-shoulder-p -70 :larm-shoulder-r 46
		     :larm-shoulder-y -86 :larm-elbow-p -97
		     :larm-wrist-p 54 :larm-wrist-r -70
		     :rarm-shoulder-p -70 :rarm-shoulder-r -46
		     :rarm-shoulder-y 86 :rarm-elbow-p -97
		     :rarm-wrist-p 54 :rarm-wrist-r 70)))
     (send* self args)
     args))
  (:cube-down-pose
   ()
   (let ((args (list :angle-plist
		     :larm-shoulder-p -50 :larm-shoulder-r 42
		     :larm-shoulder-y -86 :larm-elbow-p -89
		     :larm-wrist-p 50 :larm-wrist-r -50
		     :rarm-shoulder-p -50 :rarm-shoulder-r -42
		     :rarm-shoulder-y 86 :rarm-elbow-p -89
		     :rarm-wrist-p 50 :rarm-wrist-r 50)))
     (send* self args)
     args))
  (:bow-pose
   nil
   (let ((args (list :angle-plist :head-neck-p 45
		     :larm-shoulder-p 30 :rarm-shoulder-p 30
		     :larm-shoulder-r 10 :rarm-shoulder-r -10
		     :larm-wrist-r -10 :rarm-wrist-r 10)))
     (send self :neutral)
     (send* self args)
     (send self :angle-plist)))
  (:rarm-high-pose
   nil
   (let ((args (list :angle-plist :rarm-shoulder-p -170
		     :rarm-elbow-p -20 :rarm-wrist-p 80)))
     (send* self args)
     (send self :angle-plist :rarm)))
  (:larm-high-pose
   nil
   (let ((args (list :angle-plist :larm-shoulder-p -170
		     :larm-elbow-p -20 :larm-wrist-p 80)))
     (send* self args)
     (send self :angle-plist :larm)))
  (:both-high-pose
   nil
   (append (send self :rarm-high-pose) (send self :larm-high-pose))
   )
  (:lean-left-pose
   (&optional (angle 18))
   (let ((args (list
		:angle-plist :rleg-crotch-r (* 2 angle) :lleg-crotch-r angle)))
     (send* self args)
     args))
  (:lean-right-pose
   (&optional (angle 18))
   (let ((args (list :angle-plist :lleg-crotch-r (- (* 2 angle)) :rleg-crotch-r (- angle))))
     (send* self args)
     args))
  (:fore-right-pose
   (&optional (angle 18))
   (let ((args (list :angle-plist
		     :lleg-crotch-y (- angle) :rleg-crotch-y (- angle) :rleg-crotch-r angle)))
     (send* self args)
     args))
  (:fore-left-pose
   (&optional (angle 18))
   (let ((args (list :angle-plist
		     :rleg-crotch-y angle :lleg-crotch-y angle :lleg-crotch-r (- angle))))
     (send* self args)
     args))
  (:lean-stand-pose nil (send self :lean-right-pose 0))
  (:fore-stand-pose nil (send self :fore-left-pose 0))
  )

(defvar *semi2022-setup*)
(defun setup (&optional (*rcb-motion-bin-check* t))
  (send *robot* :set-ri *ri*)
  (semi2022-setup *rcb-motion-bin-check*))
(defun semi2022-setup (&optional (*rcb-motion-bin-check* t))
  (kxr-connect)
  (def-rcb-motion rcb-free 80
    `((:servo ,(send *ri* :servo-sorted-ids) 1
	      ,(make-sequence integer-vector 36 :initial-element #x8000))
      (:return)))
  (def-rcb-motion rcb-hold 81
    `((:servo ,(send *ri* :servo-sorted-ids) 1
	      ,(make-sequence integer-vector 36 :initial-element #x7fff))
      (:return)))
  (def-rcb-motion rcb-release 82
    `((:servo ,(send *ri* :servo-sorted-ids) 1
	      ,(make-sequence integer-vector 36 :initial-element #x8000))
      (:servo ,(send *ri* :servo-sorted-ids) 1
	      ,(make-sequence integer-vector 36 :initial-element #x7fff))
      (:return)))
  
  (def-rcb-motion rcb-both-hand 83
    `(progn (servo *ri* (:both-high-pose) 100)))
  (def-rcb-motion rcb-hello 92
    `(progn (servo *ri* ((:neutral) (:bow-pose)) 100)
	    (servo *ri* (:neutral) 100)))
  (def-rcb-motion rcb-right-hand 93
    `(progn (servo *ri* (:rarm-high-pose) 100)))
  (def-rcb-motion rcb-neutral 94
    `(progn (servo *ri* (:neutral) 100)))
  (def-rcb-motion rcb-left-hand 95
    `(progn (servo *ri* (:larm-high-pose) 100)))
  (def-rcb-motion rcb-walk-fore 96
    `(let ((i 2))
       (while (> i 0)
	 (servo *ri* (:lean-left-pose 18) 100)
	 (servo *ri* (:fore-right-pose 18) 100)
	 (servo *ri* (:lean-stand-pose) 100)
	 (servo *ri* (:lean-right-pose 18) 100)
	 (setq i (- i 1))
	 (if (= i 0)
	     (servo *ri* (:fore-stand-pose) 100)
	     (servo *ri* (:fore-left-pose 18) 100))
	 )
       (servo *ri* ((:lean-stand-pose) (:fore-stand-pose)) 100)))
  (def-rcb-motion rcb-walk-back 97
    `(let ((i 2))
       (while (> i 0)
	 (servo *ri* (:lean-left-pose 18) 100)
	 (servo *ri* (:fore-right-pose -18) 100)
	 (servo *ri* (:lean-stand-pose) 100)
	 (servo *ri* (:lean-right-pose 18) 100)
	 (setq i (- i 1))
	 (if (= i 0)
	     (servo *ri* (:fore-stand-pose) 100)
	     (servo *ri* (:fore-left-pose -18) 100)))
       (servo *ri* ((:lean-stand-pose) (:fore-stand-pose)) 100)
       ))
  (def-rcb-motion rcb-head 103
    `(progn
       (servo *ri* (:angle-plist :head-neck-y 60) 50)
       (servo *ri* (:angle-plist :head-neck-y -60) 50)
       (servo *ri* (:angle-plist :head-neck-y 0) 50)
       ))
  (def-rcb-motion rcb-head-swing 104
    `(let ((i 3))
       (while (> i 0)
	 (servo *ri* (:angle-plist :head-neck-y 60 :head-neck-p 20) 40)
	 (servo *ri* (:angle-plist :head-neck-y -60) 40)
	 (setq i (- i 1)))
       (servo *robot* (:angle-plist :head-neck-y 0 :head-neck-p 0) 40)
       ))
  (def-rcb-motion rcb-cube-neutral 105
    `(progn (servo *ri* (:cube-neutral-pose) 200)))
  (def-rcb-motion rcb-cube-both 106
    `(progn (servo *ri* ((:cube-larm-pose) (:cube-rarm-pose)) 100)))
  (def-rcb-motion rcb-cube-right 107
    `(progn (servo *ri* ((:cube-rarm-pose)) 100)))
  (def-rcb-motion rcb-cube-left 108
    `(progn (servo *ri* ((:cube-larm-pose)) 100)))
  (def-rcb-motion rcb-cube-close 109
    `(progn (servo *ri* (:close-hand -10) 50)))
  (def-rcb-motion rcb-cube-open 110
    `(progn (servo *ri* (:open-hand 10) 50)))
  (def-rcb-motion rcb-cube-place 111
    `(progn
       (servo *ri* (:close-hand -10) 100)
       (servo *ri* (:cube-down-pose) 100)
       (servo *ri* (:open-hand 10) 100)
       (servo *ri* (:cube-up-pose) 100))
    )
  (def-rcb-motion rcb-cube-grasp 112
    `(progn
       (servo *ri* (:open-hand 10) 100)
       (servo *ri* ((:cube-up-pose)
		    (:larm :move-end-pos #f(0 0 -20))
		    (:rarm :move-end-pos #f(0 0 -20)))
	      100)
       (servo *ri* (:close-hand -10) 100)
       (servo *ri* ((:larm :move-end-pos #f(0 0 20))
		    (:rarm :move-end-pos #f(0 0 20)))
	      100)
       ))
  (def-rcb-motion rcb-cube-regrasp 113
    `(progn
       (servo *ri* (:open-hand 10) 100)
       (servo *ri* (:cube-up-pose) 100)
       (servo *ri* (:cube-down-pose) 100)
       (servo *ri* (:close-hand -10) 100)
       (servo *ri* (:cube-up-pose) 100)))
  (setq *semi2022-setup* t)
  (format *error-output* ";; semi2022-setup done~%")
  )

;;;
(defun semi-jswing (&key (n 3)	;; repeat count
			 (tm 20)   ;; time(frame count)
			 (v 40)	;; relative angle(deg)
			 (j :head-neck-y)) ;; joint-method
  (send *ri* :hold-all)
  (send *robot* :copy-from-ri)
  (dotimes (i n)
    (send *robot* j :joint-angle v)
    (send *robot* :send-to-ri tm)
    (send *robot* j :joint-angle (- v))
    (send *robot* :send-to-ri tm)
    )
  (send *robot* j :joint-angle 0)
  (send *robot* :send-to-ri tm)
  )

(defun semi-mirror (&key
		    (tm 1)   ;; time (frame count)
		    )
  (send *ri* :free :larm)
  (send *ri* :hold :rarm)
  (do-until-key
   (send *robot* :copy-from-ri)
   (dolist (j '(:shoulder-p :elbow-p))
     (send *robot* :rarm j :joint-angle
	   (send *robot* :larm j :joint-angle))
     (send *robot* :send-to-ri tm)   
     )
   (send *robot* :rarm :shoulder-r :joint-angle
	 (- (send *robot* :larm :shoulder-r :joint-angle)))
   (send *robot* :send-to-ri tm)
   )
  (send *ri* :hold :larm)
  )

(defun semi-l2r-mirror (&key
		    (tm 5)   ;; time (frame count)
		    )
  (send *ri* :free :larm)
  (send *ri* :hold :rarm)
  (send *ri* :free :lleg)
  (send *ri* :hold :rleg)
  (do-until-key
   (send *robot* :copy-from-ri)
   (dolist (j '(:shoulder-p :elbow-p :gripper-r))
     (send *robot* :rarm j :joint-angle
	   (send *robot* :larm j :joint-angle)))
   (dolist (j '(:crotch-p :knee-p))
     (send *robot* :rleg j :joint-angle
	   (send *robot* :lleg j :joint-angle)))
   (send *robot* :rarm :shoulder-r :joint-angle
	 (- (send *robot* :larm :shoulder-r :joint-angle)))
   (send *robot* :rleg :crotch-r :joint-angle
	 (- (send *robot* :lleg :crotch-r :joint-angle)))
   (send *robot* :rleg :ankle-r :joint-angle
	 (- (send *robot* :lleg :ankle-r :joint-angle)))
   (send *robot* :send-to-ri tm)   
   )
  (send *ri* :hold :larm)
  (send *ri* :hold :lleg)
  )

(defun semi-relmove (&key
		     (dx 0) (dy 0) (dz 0)
		     gpos    ;; goal position in world coords
		     (limb :larm)
		     (tm 10)
		     (debug nil)
		     )
  ;; limb end-coords relative move
  (send *ri* :hold-all)
  (setq p (send *robot* limb :end-coords :worldpos))
  (unless gpos (setq gpos (v+ p (float-vector dx dy dz))))
  (let* ((tc (make-coords :pos gpos))
	 (mt (send *robot* limb :end-coords))
	 (l-list (send *robot* :link-list (send mt :parent))))
    (send *robot* :inverse-kinematics  tc
	  :move-target mt
	  :link-list l-list
	  :rotation-axis nil  ;; not constraint in rotation
	  :debug-view debug
	  )
    (setq cp (send *robot* limb :end-coords :worldpos))
    (if debug (format *error-output* ";; p=~A gpos=~A cp=~A~%" p gpos cp))
    (send *robot* :send-to-ri tm)
    )
  )

(defmethod robot-model
  (:relmove-ri
   (&rest args)
   (send self :ri :hold-all)
   (send self :copy-from-ri)
   (send* self :relmove args)
   (send self :send-to-ri)   
   )
  (:normal (dmm &optional (limb :rarm))
	   (send self :relmove :dz dmm :limb limb))
  (:slide (dmm &optional (limb :rarm)) (send self :relmove :dy dmm :limb limb))
  (:reach (dmm &optional (limb :rarm)) (send self :relmove :dx dmm :limb limb))
  (:roll (dmm &optional (limb :rarm))
	 (send self :relmove :roll dmm :limb limb))
  (:yaw (dmm &optional (limb :rarm))
	(send self :relmove :yaw dmm :limb limb))
  (:pitch (dmm &optional (limb :rarm))
	  (send self :relmove :pitch dmm :limb limb))
  (:relmove
   (&key
    (dx 0) (dy 0) (dz 0)
    (reach 0) (slide 0) (normal 0)
    roll yaw pitch ;; deg
    (dv (float-vector dx dy dz))
    (limb :larm)
    rotation-axis
    (origin (send self limb :end-coords :worldpos))
    gpos
    wrt
    (tm 10)
    (debug nil)
    )
   (let (gpos cp tc l-list mt)
     (setq mt (send self limb :end-coords))
     (when (or (not (zerop reach)) (not (zerop normal)) (not (zerop slide)))
       (setq dv (float-vector reach slide normal)))
     (setq gpos (send mt :transform-vector dv))
     (if roll (send mt :rotate (deg2rad roll) :x))
     (if pitch (send mt :rotate (deg2rad pitch) :y))
     (if yaw (send mt :rotate (deg2rad yaw) :z))
     ;;(if (or roll pitch yaw) (setq rotation-axis t))
     (setq tc (make-coords :pos gpos :rot (mt . rot)))
     (format t ";; tc=~A gpos=~A~%" tc gpos)
     (setq l-list (send self :link-list (send mt :parent)))
     (send self
	   :inverse-kinematics  tc
	   :move-target mt
	   :link-list l-list
	   ;;:rotation-axis nil  ;; not constraint in rotation
	   :rotation-axis rotation-axis
	   :debug-view debug
	   )
     (setq cp (send self limb :end-coords :worldpos))
     (if debug (format *error-output* ";; origin=~A gpos=~A cp=~A~%" origin gpos cp))
     ;;(if debug (format *error-output* ";; mt=~A mtw=~A ~%" mt mtw))
     )
   )
  (:relmove-xyz
   (&key
    (dx 0) (dy 0) (dz 0)
    (dv (float-vector dx dy dz))
    (limb :larm)
    rotation-axis
    (origin (send self limb :end-coords :worldpos))
    gpos    ;; goal position in world coords
    (tm 10)
    (debug nil)
    )
   (let (gpos cp tc mt l-list)
     (unless gpos (setq gpos (v+ origin dv)))
     (setq tc (make-coords :pos gpos))
     (setq mt (send self limb :end-coords))
     (setq l-list (send self :link-list (send mt :parent)))
     (send self
	   :inverse-kinematics  tc
	   :move-target mt
	   :link-list l-list
	   ;;:rotation-axis nil  ;; not constraint in rotation
	   :rotation-axis rotation-axis
	   :debug-view debug
	   )
     (setq cp (send self limb :end-coords :worldpos))
     (if debug (format *error-outpu* ";; origin=~A gpos=~A cp=~A~%" origin gpos cp)))
   )
  )

(defun semi-circle (&key
		    (limb :larm)
		    (method :relmove-ri)
		    (tm 10)
		    (da 30) ;; delta angle
		    (r 15) ;; radius[mm]
		    (mi 100))
  (let* ((p (send *robot* limb :end-coords :worldpos))
	 (w (make-coords))
	 (n (round (/ 360 da)))
	 (a 0) tc mt l-list)
    (dotimes (i n)
      (send *robot* method
	    :origin p
	    :dv (rotate-vector (float-vector 0 r 0) (deg2rad a) :x))
      (send *irtviewer* :draw-objects)
      (setq a (+ a da)))
    ))


(defmethod rcb4-interface
  (:joint-servo-cmds
   (j v tm)
   (send self :robot j :joint-angle v)
   (mapcar #'(lambda (iv)
	       (list :servo (car iv) tm (cadr iv)))
	   (send self :joint-servo-index-value j)))
  (:joint-servo-cmd
   (j v tm &optional (cmd :servo))
   (send self :make-servo-cmd :methods (list (list j :joint-angle v)) :cmd cmd :tm tm))
  (:make-servo-cmd
   (&key (methods (list :angle-vector)) (cmd :servo) (tm 10))
   (let ((svids (send self :servo-sorted-ids))
	 sv)
     (if (listp (car methods))
	 (mapc #'(lambda (method) (send* robot method)) methods)
       (send* robot methods))
     (dolist (j (send robot :joint-list))
       (if (eq (send j :joint-type) :wheel) (send j :joint-angle 0)))
     (setq sv (copy-seq (send self :angle-vector-to-servo-vector
			      (send robot :angle-vector))))
     (list cmd svids tm sv)))
  (:joint-servo-index-value
   (jname) ;; jname: ex. :lleg-ankle-r
   (let ((j (send robot jname))
	 (sv (copy-seq (send self :angle-vector-to-servo-vector
			     (send robot :angle-vector)))))
     (mapcar #'(lambda (i) (list i (round (elt sv i))))
	     (send j :servo-index))
     ))
  )

(defun semi-asm-jswing0 (&key (n 3)    ;; repeat count
			      (tm 30)   ;; time (frame count)
			      (v 40)   ;; relative angle(deg)
			      (j :head-neck-y) ;; joint-method
			      (mt 110))  ;; motion table number
  (def-rcb-motion
    asm-jswing0
    mt
    `(
      (:move (:lit ,n) (:ram (:counter 0)))
      labloop
      ,@(send *ri* :joint-servo-cmds j v tm)
      ,@(send *ri* :joint-servo-cmds j (- v) tm)
      (:sub (:lit 1) (:ram (:counter 0)))
      (:jump (:z :z=) labend)
      (:jump nil labloop)
      labend
      ,(send *ri* :joint-servo-cmd j 0 tm)
      (:return)
      ))
  )

(defun semi-asm-jswing1 (&key (n 3)    ;; repeat count
			      (tm 10)   ;; time (frame count)
			      (v 40)   ;; relative angle(deg)
			      (j :head-neck-y) ;; joint-method
			      (mt 111))  ;; motion table number
  (def-rcb-motion
    asm-jswing1
    mt
   `(
     (:move (:lit ,n) (:ram (:counter 0)))
     labloop
     ,(send *ri* :joint-servo-cmd j v tm)
     ,(send *ri* :joint-servo-cmd j (- v) tm)
     (:sub (:lit 1) (:ram (:counter 0)))
     (:jump (:z :z=) labend)
     (:jump nil labloop)
     labend
     ,(send *ri* :joint-servo-cmd j 0 tm)
     (:return)
     )))

(defun semi-asm-jswing2 (&key (n 3)    ;; repeat count
			      (tm 10)   ;; time (frame count)
			      (v 40)   ;; relative angle(deg)
			      (j :head-neck-y) ;; joint-method
			      (mt 112))  ;; motion table number
  (def-rcb-motion
    asm-jswing2
    mt
    `(
      (:move (:lit ,n) (:ram (:counter 0)))
      labloop
      ,(send *ri* :joint-servo-cmd j v tm)
      ,(send *ri* :joint-servo-cmd j (- v) tm)
      (:sub (:lit 1) (:ram (:counter 0)))
      (:jump (:z :z<>) labloop)
      labend
      ,(send *ri* :joint-servo-cmd j 0 tm)
      (:return)
      ))
  )
  
(defun semi-asm-jswing3 (&key (n 3)    ;; repeat count
			      (tm 10)   ;; time (frame count)
			      (v 40)   ;; relative angle(deg)
			      (j :head-neck-y) ;; joint-method
			      (mt 113))  ;; motion table number
  (def-rcb-motion
    asm-jswing3
    mt
    `(
      (:move (:lit ,n) (:ram (:counter 0)))
      (:jump nil labsub)
      labloop
      ,(send *ri* :joint-servo-cmd j v tm)
      ,(send *ri* :joint-servo-cmd j (- v) tm)
      labsub
      (:sub (:lit 1) (:ram (:counter 0)))
      (:jump (:c :c=) labend) ;; jump if carry on (--n < 0)
      (:jump nil labloop)
      labend
      ,(send *ri* :joint-servo-cmd j 0 tm)
      (:return)
      )
    ))

(defun semi-asm-jswing33 (&key (n 3)    ;; repeat count
			       (tm 10)   ;; time (frame count)
			       (v 40)   ;; relative angle(deg)
			       (j :head-neck-y) ;; joint-method
			       (mt 114))  ;; motion table number
  (def-rcb-motion
    asm-jswing33
    mt
    `(
      (:move (:lit ,n) (:ram (:counter 2)))
      labloop
      ,(send *ri* :joint-servo-cmd j v tm)
      ,(send *ri* :joint-servo-cmd j (- v) tm)
      (:sub (:lit 1) (:ram (:counter 2)))
      (:move (:lit 0) (:ram (:counter 0)))
      (:sub (:ram (:counter 2) 1) (:ram (:counter 0)) t)
      (:jump (:c :c=) labloop)  ;; jump if carry on (0 - n <0)
      labend
      ,(send *ri* :joint-servo-cmd j 0 tm)
      (:return)
      )
    ))

(defun semi-asm-jswing32 (&key (n 3)    ;; repeat count
			       (tm 10)   ;; time (frame count)
			       (v 40)   ;; relative angle(deg)
			       (j :head-neck-y) ;; joint-method
			       (mt 115))  ;; motion table number
  (def-rcb-motion
    asm-jswing32
    mt
    `(
      (:move (:lit ,n 0) (:ram (:user 2)))
      labloop
      ,(send *ri* :joint-servo-cmd j v tm)
      ,(send *ri* :joint-servo-cmd j (- v) tm)
      (:sub (:lit 1 0) (:ram (:user 2)))
      (:move (:lit 0 0) (:ram (:user 0)))
      (:sub (:ram (:user 2) 2) (:ram (:user 0)) t)
      (:jump (:c :c=) labloop) ;; jump if carry on (0 - n < 0)
      labend
      ,(send *ri* :joint-servo-cmd j 0 tm)
      (:return)
      )
    ))

(defun semi-asm-jswing4 (&key (n 3)    ;; repeat count
			      (tm 10)   ;; time (frame count)
			      (v 40)   ;; relative angle(deg)
			      (j :head-neck-y) ;; joint-method
			      (mt 115))  ;; motion table number
  (def-rcb-motion
    asm-jswing4
    mt
    `(
      (:move (:lit ,n) (:ram (:counter 0)))
      (:jump nil labsub)
      labloop
      ,(send *ri* :joint-servo-cmd j v tm)
      ,(send *ri* :joint-servo-cmd j (- v) tm)
      labsub
      (:sub (:lit 1) (:ram (:counter 0)))
      (:jump (:c :c<>) labloop) ;; jump if no carry (--n<0)
      labend
      ,(send *ri* :joint-servo-cmd j 0 tm)
      (:return)
      )
    ))

(defun semi-asm-jswing44 (&key (n 3)    ;; repeat count
			      (tm 10)   ;; time (frame count)
			      (v 40)   ;; relative angle(deg)
			      (j :head-neck-y) ;; joint-method
			      (mt 115))  ;; motion table number
  (def-rcb-motion
    asm-jswing44
    mt
    `(
      (:move (:lit ,n) (:ram (:counter 2)))
      labloop
      ,(send *ri* :joint-servo-cmd j v tm)
      ,(send *ri* :joint-servo-cmd j (- v) tm)
      (:sub (:lit 1) (:ram (:counter 2)))
      (:move (:lit 0) (:ram (:counter 0)))
      (:sub (:ram (:counter 2) 1) (:ram (:counter 0)) t)
      (:jump (:c :c<>) labend) ;; jump if no carry
      (:jump nil labloop)
      labend
      ,(send *ri* :joint-servo-cmd j 0 tm)
      (:return)
      )
    ))

(defun semi-asm-jswing42 (&key (n 3)    ;; repeat count
			      (tm 10)   ;; time (frame count)
			      (v 40)   ;; relative angle(deg)
			      (j :head-neck-y) ;; joint-method
			      (mt 115))  ;; motion table number
  (def-rcb-motion
    asm-jswing42
    mt
    `(
      (:move (:lit ,n 0) (:ram (:user 2)))
      labloop
      ,(send *ri* :joint-servo-cmd j v tm)
      ,(send *ri* :joint-servo-cmd j (- v) tm)
      (:sub (:lit 1 0) (:ram (:user 2)))
      (:move (:lit 0 0) (:ram (:user 0)))
      (:sub (:ram (:user 2) 2) (:ram (:user 0)) t)
      (:jump (:c :c<>) labend) ;; jump if no carry
      (:jump nil labloop)
      labend
      ,(send *ri* :joint-servo-cmd j 0 tm)
      (:return)
      )
    ))

(defun semi-asm-remocon (&key (bt 2048)
			      (tm 10)   ;; time (frame count)
			      (v 40) ;; delta angle(deg)
			      (j :head-neck-y) ;; joint name
			      (mt 113) ;; motion table no
			      (end 4096))
  (def-rcb-motion
    asm-remocon
    mt
    `(
      labstart
      (:move (:ram :button 2) (:ram (:user 4)))
      (:sub (:lit ,(ash bt -8) ,(mod bt 256)) (:ram (:user 4)) t) ;; shift-3
      ;;(:sub (:lit ,(ash bt -8) ,(mod bt 256)) (:ram (:user 4)))
      (:jump (:z :z=) labswing)
      (:move (:ram :button 2) (:ram (:user 4)))
      (:sub (:lit ,(ash end -8) ,(mod end 256)) (:ram (:user 4)) t) ;; shift-4 button
      ;;(:sub (:lit ,(ash end -8) ,(mod end 256)) (:ram (:user 4))) ;; shift-4 button
      (:jump (:z :z=) labend)
      (:jump nil labstart)     
      labswing
      ,(send *ri* :joint-servo-cmd j v tm)
      ,(send *ri* :joint-servo-cmd j (- v) tm)
      (:jump nil labstart)
      labend
      ,(send *ri* :joint-servo-cmd j 0 tm)
      (:return)
      )
    ))

(defun semi-asm-rom-jsetting (&key (j :head-neck-p)
				   (v 30)  ;; relative angle(deg)
				   (motion 20) ;; greeting
				   rom
				   (mt 110)
				   tm )   ;; time (frame count)
  (let (c20 m20 cds aa)
    (if rom 
	(setq m20 (send *ri* :rom-table motion)) ;; 20: greeting motion
      (setq m20 (send *ri* :project-file :mcodes motion))) ;; 20: greeting motion    
    (setq c20 (m20 . ccodes)) ;; conversion codes
    (setq cds nil)
    (dolist (c c20)
      (cond
       ((atom c) (push c cds))
       ((eq :angle-vector (car c))
	(send *robot* :angle-vector (cadr c))
	(send *robot* j :joint-angle (+ (send *robot* j :joint-angle) v))
	(push (list :angle-vector
		    (copy-object (send *robot* :angle-vector))
		    (or tm (elt c 2)) ;; time
		    (setq aids (elt c 3)) ;; effect flags
		    )
	      cds)
	)
       ((eq :return (car c))
	(send *robot* j :joint-angle (- (send *robot* j :joint-angle) v))  
	(if aids
	    (push (list :angle-vector
			(copy-object (send *robot* :angle-vector))
			(or tm 10)
			aids
			)
		  cds))
	(push c cds)
	)
       (t (push c cds))))
    (setq cds (reverse cds))
    (setq aa (rcb4-conversion cds *ri* mt))
    (store-rcb4-motion aa mt))
  )
  
(defun semi-vsetting (&key (motion 20) ;; greeting
			rom
			exec
			(mt 110)
			(tm 200))   ;; time (frame count)
  (let (c20 m20 cds aa)
    (if rom 
	(setq m20 (send *ri* :rom-table motion)) ;; 20: greeting motion
      (setq m20 (send *ri* :project-file :mcodes motion))) ;; 20: greeting motion    
    (setq c20 (m20 . ccodes)) ;; conversion codes
    (setq cds nil)
    (dolist (c c20)
      (cond
       ((atom c) (push c cds))
       ((eq :angle-vector (car c))
	(send *robot* :angle-vector (cadr c))
	(push (list :angle-vector
		    (copy-object (send *robot* :angle-vector))
		    ;;(or tm (elt c 2)) ;; time
		    tm
		    (setq aids (elt c 3)) ;; effect flags
		    )
	      cds)
	)
       ((eq :return (car c))
	(if aids
	    (push (list :angle-vector
			(copy-object (send *robot* :angle-vector))
			;;(or tm 10)
			tm
			aids
			)
		  cds))
	(push c cds)
	)
       (t (push c cds))))
    (setq cds (reverse cds))
    (setq aa (rcb4-conversion cds *ri* mt))
    (store-rcb4-motion aa mt exec))
  )

(defun semi-asm-circle1 (&key
			 (limb :larm)
			 (method :relmove-ri)
			 (tm 10)
			 (da 30) ;; delta angle
			 (r 15) ;; radius[mm]
			 (mi 100))
  (let* ((p (send *robot* limb :end-coords :worldpos))
	 (w (make-coords))
	 (n (round (/ 360 da)))
	 (a 0) tc mt l-list)
    (send *robot* :ri :start-logging tm)
    (dotimes (i n)
      (send *robot* method
	    :origin p
	    :dv (rotate-vector (float-vector 0 r 0) (deg2rad a) :x))
      (send *irtviewer* :draw-objects)
      (setq a (+ a da)))
    (send *robot* :ri :write-logging mi t)
    ))

(defun semi-asm-circle2 (&key
			(limb :larm)
			(method :relmove)
			(tm 10)
			(da 30) ;; delta angle
			(r 15) ;; radius[mm]
			(mi 100))
  (let* ((p (send *robot* limb :end-coords :worldpos))
	 (w (make-coords))
	 (n (round (/ 360 da)))
	 (a 0) tc mt l-list)
    (send *robot* :ri :start-logging tm)
    (dotimes (i n)
      (send *robot* method
	    :origin p
	    :dv (rotate-vector (float-vector 0 r 0) (deg2rad a) :x))
      (send *irtviewer* :draw-objects)
      (send *ri* :push-servo-command (send *robot* :angle-vector) tm)
      (setq a (+ a da)))
    (send *robot* :ri :write-logging mi t)
    ))


(defun semi-asm-adcheck (&key (tm 10) ;; time frame count
			      (v 40) ;; delta angle(deg)
			      (j :head-neck-y) ;; joint name
			      (mt 113) ;; motion table no
			      (ad 1)
			      )
  (def-rcb-motion
    asm-jswing1
    mt
    `(
      labstart
      (:move (:ram (:ad 1) 2) (:ram (:user 2))) ;; AD1.0
      (:move (:ram :button 2) (:ram (:user 3)))
      (:move (:ram (:ad 1) 2) (:ram (:user 4))) ;; AD1.1
      (:add  ,(if (eq (send *ri* :board) :armh7)
		  '(:lit 0 80) '(:lit 100 0))
	     (:ram (:user 2))) ;; AD1.0 + diff
      (:sub  (:ram (:user 4) 2) (:ram (:user 2))) ;; (AD1.0 + 100) - AD1.1
      (:jump (:c :c=) labswing)
      (:sub (:lit #x10 #x00) (:ram (:user 3)) t) ;; shift-4 button
      (:jump (:z :z=) labend)
      (:jump nil labstart)     
      labswing
      ,(send *ri* :joint-servo-cmd j v tm)
      ,(send *ri* :joint-servo-cmd j (- v) tm)
      (:jump nil labstart)
      labend
      ,(send *ri* :joint-servo-cmd j 0 tm)
      (:return)
      )
    ))

;;;
;;; Example use of rcb4lisp
;;;
(require :rcb4lisp)
;;;
(defun rcb4-compile-on-rom (cc &optional no (exec t) (name (format nil "(motion ~A)" no)))
  (let ((aa (rcb4lisp::compile cc)))
    (cond
     (aa
      (when no
	(send *ri* :write-motion-lst (rcb4-assemble aa no) no name)
	(when exec (send *robot* :read-from-ri)
	      (send *ri* :call-motion no))))
     (t (format *error-output* ";; rcb4lisp::compile error~%"))))
  (unix::sleep 1)
  t)

(defun semi-comp-start-grasp (&key (limb :larm)
				   (n 3)     ;; repeat count
				   (tm 50)  ;; time (frame count)
				   (v 40)    ;; relative angle(deg)
				   (j :gripper2-r) ;; joint method
				   (mt 114))  ;; motion table number
  (rcb4-compile-on-rom
   `(let ((i ,n) a)
      (while (< 0 i)
	,(send *ri* :joint-servo-cmd j v tm 'servo)
	(setq a (read-servo-pos ,(send *ri* :joint-servo-index j)))
	(setq i (- i 1)))
      ,(send *ri* :joint-servo-cmd j 0 tm 'servo)
      )
   mt))


(defun semi-comp-jswing (&key (n 3)     ;; repeat count
			      (tm 10)  ;; time (frame count)
			      (v 40)    ;; relative angle(deg)
			      (j :head-neck-y) ;; joint method
			      (mt 114))  ;; motion table number
  (def-rcb-motion
    comp-jswing
    mt
    `(let ((i ,n))
       (while (< 0 i)
	 (servo *robot* (,j :joint-angle ,v) ,tm)
	 (servo *robot* (,j :joint-angle ,(- v)) ,tm)
	 (setq i (- i 1)))
       (servo *robot* (,j :joint-angle 0) ,tm)
       )
    ))

(defun semi-comp-jswing1 (&key (n 3)     ;; repeat count
			       (tm 20)  ;; time (frame count)
			       (v 40)    ;; relative angle(deg)
			       (j :head-neck-y) ;; joint method
			       (mt 111))  ;; motion table number
  (def-rcb-motion
    comp-jswing1
    mt
    `(let ((i ,n))
       (while (< 0 i)
	 ,(send *ri* :joint-servo-cmd j v tm 'servo)
	 ,(send *ri* :joint-servo-cmd j (- v) tm 'servo)
	 (setq i (- i 1)))
       ,(send *ri* :joint-servo-cmd j 0 tm 'servo)
       )
    ))

(defun semi-comp-jswing2 (&key (n 3)     ;; repeat count
			       (tm 10)  ;; time (frame count)
			       (v 40)    ;; relative angle(deg)
			       (j :head-neck-y) ;; joint method
			       (mt 114))  ;; motion table number
  (def-rcb-motion
    comp-jswing2
    mt
    `(let ((i ,n))
       (while (< 0 i)
	 ,(send *ri* :make-servo-cmd :methods
		(list j :joint-angle v) :cmd 'servo :tm tm)
	 ,(send *ri* :make-servo-cmd :methods
		(list j :joint-angle (- v)) :cmd 'servo :tm tm)
	 (setq i (- i 1)))
       ,(send *ri* :make-servo-cmd :methods
	      (list j :joint-angle 0)  :cmd 'servo :tm tm))
    ))

(defun semi-comp-jswing3 (&key (n 3)     ;; repeat count
			       (tm 10)  ;; time (frame count)
			       (v 40)    ;; relative angle(deg)
			       (j :head-neck-y) ;; joint method
			       (mt 114))  ;; motion table number
  (def-rcb-motion
    comp-jswing3
    mt
    `(let ((i ,n))
       (while (< 0 i)
	 (servo *robot* (,j :joint-angle ,v) ,tm)
	 (servo *robot* (,j :joint-angle ,(- v)) ,tm)
	 (setq i (- i 1)))
       (servo *robot* (,j :joint-angle 0) ,tm))
    ))

(defun semi-comp-jswing-aux (&optional
			     (f '<) (a 3) (b 5)
			     &key (n 3)     ;; repeat count
			     (tm 10)  ;; time (frame count)
			     (v 40)    ;; relative angle(deg)
			     (j :head-neck-y) ;; joint method
			     (mt 114))  ;; motion table number
  (def-rcb-motion
    comp-jswing-aux
    mt
    `(let ((ca ,a) (cb ,b) (d (if (> ,a ,b) 1 -1)))
       (servo *robot* (,j :joint-angle ,v) ,tm)
       (servo *robot* (,j :joint-angle ,(- v)) ,tm)
       (while (,f ca cb)
	 (servo *robot* (,j :joint-angle ,v) ,tm)
	 (servo *robot* (,j :joint-angle ,(- v)) ,tm)
	 (setq cb (+ cb d)))
       (servo *robot* (,j :joint-angle ,v) ,tm)
       )
    ))

(defun semi-comp3 () (semi-comp-jswing-aux '<= 3 5))
(defun semi-comp4 () (semi-comp-jswing-aux '!= 3 5))
(defun semi-comp5 () (semi-comp-jswing-aux '> 5 3))
(defun semi-comp6 () (semi-comp-jswing-aux '>= 5 3))
(defun semi-comp7 () (semi-comp-jswing-aux '== 5 5))

(defun remocon-code (num &aux (sum 0))
  (cond
   ((numberp num)
    (+ (ash num -8) (ash (mod num 256) 8)))
   ((symbolp num)
    (case num
	  ((:shift-1 shift-1 l-shift-u :l-shift-u) (remocon-code 512))
	  ((:shift-2 shift-2 l-shift-d :l-shift-d) (remocon-code 1024))
	  ((:shift-3 shift-3 r-shift-u :r-shift-u) (remocon-code 2048))
	  ((:shift-4 shift-4 r-shift-d :r-shift-d) (remocon-code 4096))
	  ((:sp1 sp1) (remocon-code '(1 2 4 8)))
	  ((:sp2 sp2) (remocon-code '(16 32 64 256)))
	  ((:l-forward l-forward) (remocon-code 1))
	  ((:l-backward l-backward) (remocon-code 2))
	  ((:l-right l-right) (remocon-code 4))
	  ((:l-left l-left) (remocon-code 8))
	  ((:r-forward r-forward) (remocon-code 16))
	  ((:r-backward r-backward) (remocon-code 32))
	  ((:r-right r-right) (remocon-code 64))
	  ((:r-left r-left) (remocon-code 256))
	  ))
   ((consp num)
    (dolist (n num) (setq sum (+ sum (remocon-code n))))
    sum)))
   
(defun semi-comp-adcheck (&key (n 3)     ;; repeat count
			       (bt (remocon-code :r-forward))
			       (tm 20)  ;; time (frame count)
			       (v 10)    ;; relative angle(deg)
			       (j :head-neck-y) ;; joint method
			       (ad 1) ;; 
			       (th (if (eq :armh7 (send *ri* :board)) 9000 50))
			       (mt 114))  ;; motion table number
  (def-rcb-motion
    comp-adcheck
    mt
    `(let (a b)
       (while (!= (read-button) ,bt)
	 (setq a (read-ad ,ad))
	 (setq a (+ a ,th))
	 (setq b (read-ad ,ad))
	 (if (> b a)
	     (progn
	       (servo *robot* (,j :joint-angle ,v) ,tm)
	       (servo *robot* (,j :joint-angle ,(- v)) ,tm))))
       (servo *robot* (,j :joint-angle 0) ,tm))
    ))

(defun semi-comp-fall-check (&key (n 3)     ;; repeat count
				  (tm 20)  ;; time (frame count)
				  (bt (remocon-code :r-forward))
				  (ad 4)    ;; acc x- axis
				  (j :head-neck-p) ;; joint method
				  (v 80)    ;; relative angle(deg)
				  (mt 101))  ;; motion table number
  (send *robot* :neutral)
  (def-rcb-motion
    comp-fall-check
    mt
    `(let (a)
       (while (!= (read-button) ,bt)
	 (setq a (read-ad ,ad))
	 (if (> a 3000)            ;; face up
	     (servo *robot* (,j :joint-angle ,(- v)) ,tm)
	   (if (< a -3000)   ;; face down
	       (servo *robot* (,j :joint-angle ,v) ,tm)
	     (servo *robot* (,j :joint-angle 0) ,tm))))
       (servo *robot* (,j :joint-angle 0) ,tm))
    ))


(defun semi2021-setup-slow-standup nil
  (send *robot* :neutral)
  (semi-vsetting :motion 14 :tm 200 :mt 114) ;; change speed
  (semi-vsetting :motion 15 :tm 200 :mt 115) ;; change speed
  )

(defun semi-comp-standup (&key (n 3)     ;; repeat count
			       (tm 20)  ;; time (frame count)
			       (end (remocon-code :r-forward))
			       (bt (remocon-code :r-shift-u))
			       (ad 4)    ;; acc x- axis
			       (mt 101))  ;; motion table number
  (send *robot* :neutral)
  (def-rcb-motion
    comp-standup
    mt
    `(let (a)
       (while (!= (read-button) ,end)
	 (if (= (read-button) ,bt)
	     (progn
	       (setq a (read-ad ,ad))
	       (if (> a 3000)            ;; face up
		   (call 114)     ;; standup from face down
		 (if (< a -3000)   ;; face down
		     (call 115)   ;;  standup from face up
		   (servo *robot* (:neutral) ,tm))))))
       (servo *robot* (:neutral) ,tm))
    ))

(defun semi-comp-remocon0 (&key (tm 10)  ;; time (frame count)
			       (v 40)    ;; relative angle(deg)
			       (end (remocon-code :r-forward))
			       (bt (remocon-code :r-shift-u))
			       (j :head-neck-y) ;; joint method
			       (mt 114))  ;; motion table number
  (def-rcb-motion
    comp-remocon0
    mt
    `(progn
       (while (!= (read-button) ,end)
	 (if (= (read-button) ,bt) ;; shift-3
	     (progn
	       (servo *robot* (,j :joint-angle ,v) ,tm)
	       (servo *robot* (,j :joint-angle ,(- v)) ,tm))))
       (servo *robot* (,j :joint-angle 0) ,tm))
    ))

(defun make-servo-vector (i v)
  (let ((sv (make-sequence float-vector 36)))
    (setf (elt sv i) v) sv))

(defun semi-comp-read-servo (&key (tm 10)  ;; time (frame count)
				  (v 40)    ;; relative angle(deg)
				  (end (remocon-code :r-forward))
				  (si 18) ;; rarm-gripper-r
				  (offset 4) ;; current angle
				  (j :head-neck-y) ;; joint method
				  (mt 114))  ;; motion table number
  (def-rcb-motion
    comp-read-servo
    mt
    `(let (a)
       (while (!= (read-button) ,end)
	 (setq a (read-servo ,si ,offset))
	 (if (> a 7500)
	     (servo *robot* (,j :joint-angle ,v) ,tm)
	   (servo *robot* (,j :joint-angle ,(- v)) ,tm)))
       (servo *robot* (,j :joint-angle 0) ,tm))
    ))

(defun semi-comp-read-effort (&key (tm 10)  ;; time (frame count)
				   (bt (remocon-code :r-shift-u))
				   (th 80)  ;; effort threshold
				   (j1 :rarm-gripper-r)
				   (j2 :head-neck-y)
				   (mt 114))  ;; motion table number
  (let ((idx1 (car (send *ri* :robot j1 :servo-index)))
	(idx2 (car (send *ri* :robot j2 :servo-index))))
    (rcb4-compile-on-rom
     `(let (e p)
	(while (!= (read-button) ,bt)
	  (setq e (- (read-servo-ref ,idx1)
		     (read-servo-pos ,idx1)))
	  (setq p (read-servo-pos ,idx2))
	  (if (> e ,th)
	      (write-servo-ref ,idx2 (+ p e))
	    (if (< e ,(- th))
		(write-servo-ref ,idx2 (+ p e)))))
	(servo *robot* (,j2 :joint-angle 0) ,tm))
     mt)))

(defun semi-comp-jmirror (&key (tm 10)  ;; time (frame count)
			       (bt (remocon-code :r-shift-u))
			       (j1 :rarm-gripper-r) ;; joint method
			       (j2 :larm-gripper-r) ;; joint method
			       (mt 115))  ;; motion table number
  (let ((idx1 (car (send *ri* :robot j1 :servo-index)))
	(idx2 (car (send *ri* :robot j2 :servo-index))))
    (send *robot* :neutral)
    (rcb4-compile-on-rom
     `(let (a)
	(write-servo-ref ,idx1 ,#x8000) ;; free
	(while (!= (read-button) ,bt)
	  (write-servo-ref ,idx2 (read-servo-pos ,idx1)))
	(write-servo-ref ,idx1 ,#x7fff) ;; hold
	(servo *robot* (,j2 :joint-angle 30) ,tm))
     mt)))

(defun semi-comp-amirror nil
  (semi-comp-jmirror :j1 :rarm-shoulder-p :j2 :larm-shoulder-p :mt 116))

(defun semi-comp-emirror nil
  (semi-comp-jmirror :j1 :rarm-elbow-p :j2 :larm-elbow-p :mt 115))

(defun semi-comp-gmirror nil
  (semi-comp-jmirror :j1 :rarm-gripper-r :j2 :larm-gripper-r :mt 116))

(defun arm-servo-index-list (arm)
  (mapcar
   #'(lambda (j) (car (send *ri* :robot arm j :servo-index)))
   (list :shoulder-p :shoulder-r :elbow-p :gripper-r)))
(defun leg-servo-index-list (leg)
  (mapcar
   #'(lambda (j) (car (send *ri* :robot leg j :servo-index)))
   (list :crotch-p :crotch-r :knee-p :ankle-r :ankle-p)))

(defun mirror-limb (j)
  (case
   j
   (:larm :rarm)
   (:rarm :larm)
   (:lleg :rleg)
   (:rleg :lleg)
   (:lwing :rwing)
   (:rwing :lwing)
   (:mlleg :mrleg)
   (:mrleg :mlleg)))

(defun semi-comp-mirror (&key (tm 10)  ;; time (frame count)
			      (bt (remocon-code :r-shift-u))
			      (arm :rarm) (leg :rleg)
			      (mt 114))  ;; motion table number
  (let ((aids1 (arm-servo-index-list arm))
	(lids1 (leg-servo-index-list leg))
	(aids2 (arm-servo-index-list (mirror-limb arm)))
	(lids2 (leg-servo-index-list (mirror-limb leg))))
    (rcb4-compile-on-rom
     `(progn
	,@(mapcar #'(lambda (idx1) (list 'write-servo-ref idx1 #x8000))
		  aids1)
	,@(mapcar #'(lambda (idx1) (list 'write-servo-ref idx1 #x8000))
		  lids1)
	(while (!= (read-button) ,bt)
	  ,@(mapcar
	     #'(lambda (idx1 idx2)
		 (list 'write-servo-ref idx2 (list 'read-servo-pos idx1)))
	     aids1 aids2)
	  ,@(mapcar
	     #'(lambda (idx1 idx2)
		 (list 'write-servo-ref idx2 (list 'read-servo-pos idx1)))
	     lids1 lids2))
	,@(mapcar #'(lambda (idx1) (list 'write-servo-ref idx1 #x7fff))
		  aids1)
	,@(mapcar #'(lambda (idx1) (list 'write-servo-ref idx1 #x7fff))
		  lids1))
     mt)))
  
  
(defun semi-comp-effort (&key (tm 10)  ;; time (frame count)
			      (bt (remocon-code :r-shift-u))
			      (th 50)  ;; effort threshold
			      (limb :rarm)
			      (j :elbow-p)
			      (mt 114))  ;; motion table number
  (let ((idx1 (car (send *ri* :robot limb j :servo-index)))
	(idx2 (car (send *ri* :robot (mirror-limb limb) j :servo-index))))
    (rcb4-compile-on-rom
     `(let (e p (p0 (read-servo-ref ,idx2)))
	(while (!= (read-button) ,bt)
	  (setq e (- (read-servo-ref ,idx1) (read-servo-pos ,idx1)))
	  ;;(setq p (read-servo-pos ,idx2))
	  (setq p (read-servo-ref ,idx2))
	  (if (> e ,th)
	      (write-servo-ref ,idx2 (- p e))
	    (if (< e ,(- th))
		(write-servo-ref ,idx2 (- p e)))))
	(write-servo-ref ,idx2 p0))
     mt)))


(defun semi-comp-remocon (&key (tm 10)  ;; time (frame count)
			       (bt1 (remocon-code :r-shift-u))
			       (bt2 (remocon-code :l-shift-u))
			       (end (remocon-code :r-forward))
			       (v 40)    ;; relative angle(deg)
			       (mt 114))  ;; motion table number
  (def-rcb-motion
    comp-remocon
    mt
    `(progn
       (while (!= (read-button) ,end)
	 (if (= (read-button) ,bt1)
	     (progn
	       (servo *robot* ((:head-neck-p :joint-angle 0)
			       (:head-neck-y :joint-angle ,v)) ,tm)
	       (servo *robot* (:head-neck-y :joint-angle ,(- v)) ,tm)))
	 (if (= (read-button) ,bt2)
	     (progn
	       (servo *robot* ((:head-neck-y :joint-angle 0)
			       (:head-neck-p :joint-angle ,v)) ,tm)
	       (servo *robot* (:head-neck-p :joint-angle ,(- v)) ,tm))))
       (servo *robot* ((:head-neck-y :joint-angle 0)
		       (:head-neck-p :joint-angle 0))
	      ,tm))
    ))

(defun semi-comp-side-swing (&key (tm 30)   ;; time (frame count)
				  (bt (remocon-code :r-shift-u))
				  (end (remocon-code :r-forward))
				  (a 20) ;; degree
				  (mt 114))	;; msec
  (def-rcb-motion
    comp-side-swing
    mt
    `(progn
       (while (!= (read-button) ,end)
	 (if (= (read-button) ,bt)
	     (progn
	       (servo *robot*
		      ((:rleg-crotch-r :joint-angle ,a)
		       (:lleg-crotch-r :joint-angle ,a))
		      ,tm)
	       (servo *robot*
		      ((:rleg-crotch-r :joint-angle ,(- a))
		       (:lleg-crotch-r :joint-angle ,(- a)))
		      ,tm))))
       (servo *robot* (:reset-pose) ,tm))
    ))

(defun semi-comp-iksquat (&key (tm 40)   ;; time (frame count)
			       (bt (remocon-code :r-shift-u))
			       (end (remocon-code :r-forward))
			       (d 40)   ;; depth [mm]
			       (mt 118)) ;; motion table index
  (send *robot* :reset-pose)
  (def-rcb-motion
    comp-iksquat
    mt
    `(progn
       (while (!= (read-button) ,end)
	 (if (= (read-button) ,bt)
	     (progn
	       (servo *robot* ((:relmove :dz ,d :limb :lleg :rotation-axis t)
			       (:relmove :dz ,d :limb :rleg :rotation-axis t))
		      ,tm)
	       (servo *robot* (:reset-pose) ,tm))))
       (servo *robot* (:neutral) ,tm)))
  )

(defun semi-comp-ikpush (&key (tm 40)   ;; time (frame count)
			      (bt (remocon-code :r-shift-u))
			      (end (remocon-code :r-forward))
			      (d 25)    ;; depth [mm]
			      (mt 118)) ;; motion table index
  (send *robot* :reset-pose)
  (def-rcb-motion
    comp-ikpush
    mt
    `(progn
       (while (!= (read-button) ,end)
	 (if (= (read-button) ,bt)
	     (progn
	       (servo *robot* ((:relmove :dx ,d :limb :larm :rotation-axis nil)
			       (:relmove :dx ,d :limb :rarm :rotation-axis nil))
		      ,tm)
	       (servo *robot* ((:relmove :dx ,(* -2 d) :limb :larm :rotation-axis nil)
			       (:relmove :dx ,(* -2 d) :limb :rarm :rotation-axis nil))
		      ,tm)
	       (servo *robot* (:reset-pose) ,tm))))
       (servo *robot* (:neutral) ,tm)))
  )

(defun semi-comp-squat (&key (tm 40)   ;; time (frame count)
			     (bt (remocon-code :r-shift-u))
			     (end (remocon-code :r-forward))
			     (d 40)   ;; depth [mm]
			     (mt 118)) ;; motion table index
  (send *robot* :reset-pose)
  (def-rcb-motion
    comp-squat
    mt
   `(progn
      (while (!= (read-button) ,end)
	(if (= (read-button) ,bt) 
	    (progn
	      (servo *robot*
		     ((:lleg-crotch-p :joint-angle -60)
		      (:rleg-crotch-p :joint-angle -60)
		      (:lleg-knee-p :joint-angle 120)
		      (:rleg-knee-p :joint-angle 120)
		      (:lleg-ankle-p :joint-angle -60)
		      (:rleg-ankle-p :joint-angle -60))
		     ,tm)
	      (servo *robot* (:reset-pose) ,tm))))
      (servo *robot* (:neutral) ,tm)))
  )

(defun semi-comp-balance-arm (&key (tm 30)  ;; tm:time(frame count)
				   (a 20) ;; swing deg
				   (bt1 (remocon-code :r-shift-u))
				   (bt2 (remocon-code :l-shift-u))
				   (end (remocon-code :r-forward))
				   (mt 114)
				   (ad (if (eq :armh7 (send *ri* :board)) 2 3))
				   (th (if (eq :armh7 (send *ri* :board)) 0 370)))
  (def-rcb-motion
    comp-balance-arm
    mt
    `(progn
       (while (!= (read-button) ,end)
	 (if (> (read-ad ,ad) ,th)
	     (servo *robot*
		    ((:larm-shoulder-r :joint-angle 30)
		     (:rarm-shoulder-r :joint-angle 0))
		    ,tm)
	   (servo *robot*
		  ((:larm-shoulder-r :joint-angle 0)
		   (:rarm-shoulder-r :joint-angle -30))
		  ,tm))
	 (if (= (read-button) ,bt1) ;; shift-3
	     (progn
	       (servo *robot*
		      ((:rleg-crotch-r :joint-angle ,a)
		       (:lleg-crotch-r :joint-angle ,a))
		      ,tm)
	       (servo *robot*
		      ((:rleg-crotch-r :joint-angle ,(- a))
		       (:lleg-crotch-r :joint-angle ,(- a)))
		      ,tm)))
	 (if (= (read-button) ,bt2) ;; shift-1
	     (servo *robot* (:reset-pose) ,tm)))
       (servo *robot* (:reset-pose) ,tm))
    ))

(defun semi-comp-balance-foot0 (&key (tm 5)  ;; tm:time(frame count)
				   (mt 114)
				   (dr 10) (dp 5) ;; deg
				   (end 16) ;; shift-4
				   (adr (if (eq :armh7 (send *ri* :board)) 4 3))
				   (offr (if (eq :armh7 (send *ri* :board)) 100 10))
				   (adp (if (eq :armh7 (send *ri* :board)) 2 5))
				   (offp (if (eq :armh7 (send *ri* :board)) 100 10)))
  ;; rcb4   ad[3]:y-axis(roll), ad[4]:z-axis, ad[5]:x-axis(pitch)
  ;; armh7  ad[2]:x-axis(pitch),ad[3]:z-axis, ad[4]:y-axis(roll)
  (rcb4-compile-on-rom
   `(let ((thr (read-ad ,adr)) (thp (read-ad ,adp)))
      (while (!= (read-button) ,end)
	(if (> (read-ad ,adp) (+ thp ,offp))
	    (servo *robot*
		   ((:reset-pose)
		    (:lleg-ankle-p :joint-angle ,dp)
		    (:rleg-ankle-p :joint-angle ,dp))
		   ,tm)
	  (if (< (read-ad ,adp) (- thp ,offp))
	      (servo *robot*
		     ((:reset-pose)
		      (:lleg-ankle-p :joint-angle ,(- dp))
		      (:rleg-ankle-p :joint-angle ,(- dp)))
		     ,tm)))
	(if (> (read-ad ,adr) (+ thr ,offr))
	    (servo *robot*
		   ((:reset-pose)
		    (:lleg-ankle-r :joint-angle ,dr)
		    (:rleg-ankle-r :joint-angle ,dr))
		   ,tm)
	  (if (< (read-ad ,adr) (- thr ,offr))
	      (servo *robot*
		     ((:reset-pose)
		      (:lleg-ankle-r :joint-angle ,(- dr))
		      (:rleg-ankle-r :joint-angle ,(- dr)))
		     ,tm))))
      (servo *robot* (:reset-pose) ,tm))
   mt))

(defun semi-comp-balance-foot (&key (tm 5)  ;; tm:time(frame count)
				   (mt 114)
				   (end 16)
				   (dr 10) (dp 5) ;; deg
				   (adr (if (eq :armh7 (send *ri* :board)) 4 3))
				   (offr (if (eq :armh7 (send *ri* :board)) 100 10))
				   (adp (if (eq :armh7 (send *ri* :board)) 2 5))
				   (offp (if (eq :armh7 (send *ri* :board)) 100 10)))
  ;; rcb4   ad[3]:y-axis(roll), ad[4]:z-axis, ad[5]:x-axis(pitch)
  ;; armh7  ad[2]:x-axis(pitch),ad[3]:z-axis, ad[4]:y-axis(roll)
  (rcb4-compile-on-rom
   `(let ((thr (read-ad ,adr)) (thp (read-ad ,adp)))
      (while (!= (read-button) ,end)
	(if (> (read-ad ,adp) thp)
	    (servo *robot*
		   ((:reset-pose)
		    (:lleg-ankle-p :joint-angle ,dp)
		    (:rleg-ankle-p :joint-angle ,dp))
		   ,tm)
	  (if (< (read-ad ,adp) thp)
	      (servo *robot*
		     ((:reset-pose)
		      (:lleg-ankle-p :joint-angle ,(- dp))
		      (:rleg-ankle-p :joint-angle ,(- dp)))
		     ,tm)))
	(if (> (read-ad ,adr) thr)
	    (servo *robot*
		   ((:reset-pose)
		    (:lleg-ankle-r :joint-angle ,dr)
		    (:rleg-ankle-r :joint-angle ,dr))
		   ,tm)
	  (if (< (read-ad ,adr) thr)
	      (servo *robot*
		     ((:reset-pose)
		      (:lleg-ankle-r :joint-angle ,(- dr))
		      (:rleg-ankle-r :joint-angle ,(- dr)))
		     ,tm))))
      (servo *robot* (:reset-pose) ,tm))
   mt))

;;; Added by T. Anzai

(defun register-angle-vector-motion (angle-vectors &key (motion-num nil) (time 2000))
  (send *ri* :flush-codes)
  (dolist (state angle-vectors)
    (progn
        (print state *error-output*)
        (send *robot* :angle-vector state)
        (send *robot* :fix-leg-to-coords (make-coords))
        (send *robot* :viewer :draw-objects :flush t)
        (unix:sleep 1)
        (send *ri* :push-servo-command (send *robot* :angle-vector) time)
        ))

  (if motion-num
      (send *ri* :write-codes-to-motion-table motion-num)
    (send *ri* :flush-codes))
  )

;;;
;;; help
;;;
(defun semi-help nil
  (format *error-output* "
")
  )

(semi-help)
