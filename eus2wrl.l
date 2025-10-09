;;;
;;;	converter robot-model to euscollada-robot created 2018.8.11 M.I
;;;
;;;	(eus2wrl object "file.wrl")       -> wrls/file.wrl
;;;	(eus2collada-robot robot {name})  -> wrls/robot.wrl daes/robot.dae models/robot.l
;;;	(setup-robot-joint-method-name)   -> put joint-method to :joint-method-name property
;;;	(eus2proto *ri*/*robot*)  -> protos/robot-name.proto	 2021.4.8
;;;
(provide :eus2wrl)

(require :rcb4robots)

(eval-when (eval load)
  (require :kxrextentions))

;; (setq *kxr-all-names* (mapcar #'car *kxr-all-options*))
;; (setq *kxr-l2s-names* (mapcar #'car *kxr-l2s-options*))
;; (setq *kxr-l2l5all-names* (mapcar #'car *kxr-l2l5all-options*))
;; (setq *kxr-l2l6all-names* (mapcar #'car *kxr-l2l6all-options*))
;; (setq *kxr-l2nl6all-names* (mapcar #'car *kxr-l2nl6all-options*))
;; (setq *kxr-l2wl6all-names* (mapcar #'car *kxr-l2wl6all-options*))
;; (setq *kxr-l4all-names* (mapcar #'car *kxr-l4all-options*))
;; (setq *kxr-l6all-names* (mapcar #'car *kxr-l6all-options*))
;; (load "llib/vrmlNodeSpec.l")
;; (in-package :vrml)
;; (defmethod vrml-object
;;     (:dump (&optional (strm t))
;; 	      )
;;   )
(in-package :user)

(defun create-collada-robots (&key (robots *kxr-all-names*) (erase t) no-check)
  (let ((len (length robots)) (i 0) rname)
    (format t ";; convert ~A robots~%" len)
    (catch :loop-exit
      (do-until-key
       (if (>= i len) (throw :loop-exit i))
       (setq rname (elt robots i))
       (cond
	((and (null no-check) (probe-file (format nil "models/~A.l" rname)))
	 (format t ";; ---- ~A/~A ~A exists. ~%" i len rname))
	(t
	 (eus2collada-robot rname :erase erase)
	 (unless (probe-file (format nil "models/~A.l" rname))
	   (format t ";; ---- ~A/~A ~A is not created.~%" i len rname)
	   (throw :loop-exit i))
	 (format t ";; ---- ~A/~A ~A created.~%" i len rname)))
       (incf i)
       ))
    )
  )

(defun eus2collada-robot
    (robo &key
	  head
	  (fname (string-downcase
		  (cond ((derivedp robo rcb4-interface)
			 (setq robo (send robo :robot))
			 (send robo :name))
			((stringp robo)
			 (setq robo (send (kxr-make-robot-interface robo :model nil :head head) :robot))
			 (send robo :name))
			(t (send robo :name)))))
	  (wrl (format nil "wrls/~A.wrl" fname))
	  (dae (format nil "daes/~A.dae" fname))
	  (yaml (format nil "yamls/~A.yaml" fname))
	  (mode :openhrp3)
	  (model (format nil "models/~A.l" fname))
	  (urdf t)
	  erase
	  (actuator-joint-check nil)
	  (joint-numbered-name t)
	  )
  (unix::chdir *rcb4eus-dir*)
  (if fname (send robo :name fname))
  (when robo
    (send robo :angle-vector (instantiate float-vector (length (send robo :angle-vector)))))
  (mkdir-unless "wrls")
  (when urdf
    (mkdir-unless "urdfs")
    (mkdir-unless (format nil "urdfs/~A" fname))
    (mkdir-unless (format nil "urdfs/~A/urdf" fname))
    (setq urdf (format nil "urdfs/~A/urdf/~A.urdf" fname fname)))
  (cond
    ;;((substringp "khr" fname)
    ;;(khr2model fname))
   ((derivedp robo kxr-robot)
    (eus2wrl robo wrl :mode mode :actuator-joint-check actuator-joint-check
	     :joint-numbered-name joint-numbered-name)
    (export-collada wrl dae)
    (eus2yaml robo :yaml yaml :actuator-joint-check actuator-joint-check)
    (collada2eus fname :dae dae :yaml yaml :model model)
    (when urdf (collada2urdf fname))
    (when erase (eus2erase-files fname)))
   ((derivedp robo robot-model)
    (eus2wrl robo wrl :mode mode :actuator-joint-check actuator-joint-check
	     :joint-numbered-name joint-numbered-name)
    (export-collada wrl dae)
    (eus2yaml robo :yaml yaml :actuator-joint-check actuator-joint-check)
    (collada2eus fname :dae dae :yaml yaml :model model)
    (when urdf (collada2urdf fname))
    (when erase (eus2erase-files fname)))
   ))


(defun eus2erase-files (fname)
  (unlink-format "daes/~A.dae" fname)
  (unlink-format "wrls/~A.wrl" fname)
  ;;(unlink-format "urdf/~A.urdf" fname)
  (unlink-format "protos/~A.proto" fname)
  ;;(unlink-format "yamls/~A.yaml" fname)
  ;;(unlink-format "dumped-robots/~A.l" fname)
  )

(defun export-collada (wrl dae)
  (unless (unix::getenv "ROS_DISTRO")
    (error ";; You need ROS environment. install ROS and do again"))
  (unless (read (piped-fork "rospack find openhrp3") nil nil)
    (system-format "sudo apt-get install -y ros-~A-openhrp3" (unix::getenv "ROS_DISTRO")))
  (mkdir-unless "daes")
  (system-format "export-collada -i ~A -o ~A" wrl dae))

(defun joint-method-candidates (r)
  (remove-if-not
   #'(lambda (x)
       (member (subseq (symbol-name x) 0 5)
	       '("LLEG-" "RLEG-" "LARM-" "RARM-" "HEAD-" "TORSO" "WING-" "LMARM" "RMARM")
	       :test #'string-equal))
   (send r :methods)))

(defun setup-robot-joint-method-name (r)
  (let ((meths (joint-method-candidates r)))
    (dolist (j (send r :joint-list))
      (send j :put :joint-method-name
	    (find-if #'(lambda (m) (eq j (send r m))) meths)))))

(defun active-joint-methods (r)
  (let ((meths (joint-method-candidates r))
	m res)
    (dolist (j (send r :joint-list))
      (if (setq m (find-if #'(lambda (m)
			       (and (eq j (send r m))
				    (get j :active)))
			   meths))
	  (push m res)))
    res))

(defun joint-methods (r)
  (mapcar #'(lambda (j) (get j :joint-method-name))
	  (send r :joint-list)))

(defun find-joint-method (r j)
  (find-if #'(lambda (m) (eq j (send r m)))
	   (joint-method-candidates r)))

(defun eus2yaml (robo &key
			(name (string-downcase (send robo :name)))
			(yaml (format nil "yamls/~A.yaml" name))
			(scale 0.001)
			(actuator-joint-check nil)
			(limbs '(:head :larm :rarm :lleg :rleg :torso))
			&aux av)
  (when (derivedp robo robot-model)
    (send robo :angle-vector)
    (mkdir-unless "yamls")
    (with-open-file
     (strm yaml :direction :output)
     (if (find-method robo :limbs) (setq limbs (send robo :limbs)))
     (format strm "#~%# this file is automatically generated by eus2yaml ~A robot~%#~%" yaml)
     (dolist (lim limbs)  ;;'(:head :torso :larm :rarm :lleg :rleg)
       (when (send robo lim)
	 (format strm "~A:~%" (string-downcase (string lim))))
       (dolist (l (send robo lim)) ;;(assocdr lim (robo . lst-alist))  ;;(slot robo (class robo) lim))
	 (when (if actuator-joint-check
		   (get (send l :joint) :active) 	;; (get (send l :joint) :servo-index)
		 t)
	   (format strm " - ~A : ~A~%"
		   (send (send l :joint) :name)
		   (read-from-string
		    (symbol-name 
		     (or
		      (get (send l :joint) :joint-method-name)
		      (find-joint-method robo (send l :joint))
		      )
		     ))))))
     ;;
     (format strm "#~%# end-coords ~%#~%")
     (if (find-method robo :limbs) (setq limbs (send robo :limbs)))
     (dolist (lim limbs) ;; (rleg lleg rarm larm head))
      (when (send robo lim)
       (let* ((sym (read-from-string (format nil "~A-end-coords" (string lim))))
	      (ec (send robo (intern (symbol-name sym) *keyword-package*)))
	      par pos ori v a)
	 (when ec
	   (setq par (send ec :parent))
	   (setq pos (send par :inverse-transform-vector (send ec :worldpos)))
	   (setq ori (matrix-log (send ec :rot)))
	   (setq v (normalize-vector ori) a (norm ori))
	   (if (= a 0.0) (setf (elt v 0) 1.0))
	   (scale scale pos pos)
	   (format strm "~A:~%  translate : [~A, ~A, ~A]~%  rotate : [~A, ~A, ~A, ~A]~%  parent : ~A~%"
		   sym (elt pos 0) (elt pos 1) (elt pos 2)
		   (elt v 0) (elt v 1) (elt v 2) (rad2deg a) ;; notice!!
		   (send par :name)))))
      )
     ;;
     (format strm "~%angle-vector:~%")
     (dolist (m (list :reset-pose :reset-manip-pose :neutral))
       (when
	   (find-method robo m)
	 (send robo m)
	 (format strm "     ~A: [" (read-from-string (symbol-name m)))
	 (dolist (lim ;;'(head torso larm rarm lleg rleg))
		  ;;'(:head :torso :larm :rarm :lleg :rleg))
		  limbs)
	   (format strm "~%             " )
	   (dolist (l ;;(slot robo (class robo) lim))
		    (send robo lim))
	     (when (if actuator-joint-check
		       ;;(get (send l :joint) :servo-index)
		       (get (send l :joint) :active)
		     t)
	       (format strm "~A, " (send (send l :joint) :joint-angle))))
	   (format strm "## ~A" lim)
	   )
	 (format strm "~%             ]~%")
	 )))
    (send robo :angle-vector av)
    ))
#|
(defun eus2proto (ri &key joint-numbered-name)
  (eus2collada-robot ri :joint-numbered-name joint-numbered-name)
  (if (derivedp ri rcb4-interface) (setq ri (send ri :robot)))
  (collada2proto (send ri :name)))
|#
(defun eus2proto (scene &key
			  (robot-name (if (stringp scene) scene (string-downcase (send scene :name))))
			  (wrl (format nil "protos/~A-test.proto" robot-name))
			  (fixed nil) (actuator-joint-check t)
			  (joint-numbered-name t))
  (if (stringp scene) (setq scene (kxr-make-robot scene)))
  (with-open-file 
   (f wrl :direction :output)
   (when (derivedp scene robot-model)
     (if joint-numbered-name
	 (change-joint-names-to-limb-numbered scene)
       (change-joint-names-to-downcase-string scene)) )
   (format f "#VRML V2.0 utf8~%~%")
   (format f "# Produced by ~A~%" (lisp-implementation-version))
   (format f "# Date: ~A~%~%" (unix:asctime (unix:localtime)))
   (print-webots-proto f (format nil "~A-test" robot-name))
   (print-webots-header
    f (format nil "~A" (if robot-name robot-name (string-downcase (send scene :name)))))
   (setq *eus2wrl-camera-index* 0)
   (if (not (find-method scene :dump-to-wrl))
       (progn
	 (when (not (send scene :name))
	   (warn "Abort!! Please set :name to bodies~%")
	   (return-from eus2proto nil))
	 (dump-object-to-wrl scene f))
     (send scene :dump-to-wrl :strm f :mode :webots :fixed fixed :robot scene
	   :actuator-joint-check actuator-joint-check)
     )
   (print-webots-footer f))
  )

(defun eus2wrl (scene wrl &key (mode :openhrp3) (fixed nil)
			    robot-name
			    (actuator-joint-check nil)
			    (joint-numbered-name t))
  (if (stringp scene)
      (setq robot-name scene scene (kxr-make-robot robot-name))
      (setq robot-name (send scene :name)))
  (with-open-file 
   (f wrl :direction :output)
    (when (derivedp scene robot-model)
      (if joint-numbered-name
	  (change-joint-names-to-limb-numbered scene)
	(change-joint-names-to-downcase-string scene)))
    (format f "#VRML V2.0 utf8~%~%")
    (format f "# Produced by ~A~%" (lisp-implementation-version))
    (format f "# Date: ~A~%~%" (unix:asctime (unix:localtime)))
    (print-hanim-proto f mode)
    (print-hrp-setting f)
    (print-hanim-header
     f
     (string-left-trim
      ":"
      (format nil "~A" (if robot-name
			   robot-name (string-downcase (send scene :name))))))
    (setq *eus2wrl-camera-index* 0)
    (setq *eus2wrl-kjs-index* 0)
    (if (not (find-method scene :dump-to-wrl))
	(progn
	  (when (not (send scene :name))
	    (warn "Abort!! Please set :name to bodies~%")
	    (return-from eus2wrl nil))
	  (dump-object-to-wrl scene f))
	(send scene :dump-to-wrl :strm f :mode mode :fixed fixed :robot scene
	      :actuator-joint-check actuator-joint-check)
	)
    (if (memq mode (list :openhrp2 :openhrp3)) (print-hanim-footer scene f))
    )
  )

(defun change-joint-names-to-limb-numbered (robo &aux
						 (limbs 
						  (if (find-method robo :limbs)
						      (send robo :limbs)
						    (list :rleg :lleg :mrarm :mlarm :rarm :larm :head :torso))))
  (dolist (limb limbs)
    (when (find-method robo limb)
      (dolist (l (send robo limb))
	(send l :name (format nil "~A_LINK~A" (symbol-name limb)
			      (position l (send robo limb))))
	(when (send l :joint)
	  (send (send l :joint) :name (format nil "~A_JOINT~A" (symbol-name limb)
					      (position l (send robo limb))))))))
  ;;(dolist (j (send robo :joint-list))
  ;;(send j :name (string-left-trim ":" (send j :name))))
  )

(defun change-joint-names-to-downcase-string (robo)
  (dolist (j (send robo :joint-list))
    (send j :name (string-downcase (string (send j :joint-method-name)))))
  )

;;;
(defmethod cascaded-link
  (:dump-to-wrl 
   (&key (strm t) (mode :normal) (fixed nil) robot actuator-joint-check)
   ;; set joint-id tempolariry because robot-model's joints do not have :servo :no
   (let ((jl joint-list))
     ;;(remove-if-not
     ;;#'(lambda (x) (and actuator-joint-check (get x :servo-index)))
     ;;joint-list)))
     ;;(format t ";; cascaded-link :dump-to-wrl is called, jl=~A~%" jl)
     (mapc #'(lambda (x)
	       (send x :put :joint-id-for-dump (position x jl)))
	   jl)
     (send
      (send self :body-link)
      :dump-to-wrl :strm strm :mode mode :fixed fixed :robot robot)      
     #|
     (send (find-if
     #'(lambda (x) (derivedp x bodyset-link))
     (send self :descendants))
     :dump-to-wrl :strm strm :mode mode :fixed fixed :robot robot)
     |#
     (mapc #'(lambda (x) (send x :remprop :joint-id-for-dump)) jl)
     )
   )
  )

;;
;; (make-kxr-robot "khr3")
;; (eus2collada-robot *robot* :fname "khr" :wrl "KHR/KHRmain.wrl")
;; -> models/khr.l

(defun gen-khrh2u (&key (replace t) (names *khr-ufunc-names*) (lego-bar 13))
  (gen-khrh2-aux (m5unitv-stereo :m5stack 0 :n lego-bar) "HEAD_LINK3"
		 names "" replace #f(-4 0 15)))

(defun gen-khrh2u2 (&key (replace t) (names *khr-u2func-names*) (lego-bar 13))
  (gen-khrh2-aux (m5unitv2-stereo :n lego-bar)
		 "HEAD_LINK3" names "" replace #f(-4 0 15)))

(defun gen-khrh2u3 (&key (replace t) (names *khr-u3func-names*) (lego-bar 13))
  (gen-khrh2-aux (m5unitv-stereo :n lego-bar :m5unitv2 t)
		 "HEAD_LINK3" names "" replace #f(-4 0 15)))

(defun gen-khrh2v (&key (replace t) (names *khr-vfunc-names*))
  (gen-khrh2-aux (m5stickv-stereo) "HEAD_LINK3" names "" replace #f(-4 0 24)))

(defun gen-khrh2v3 (&key (replace t) (names *khr-v3func-names*))
  (gen-khrh2-aux (m5stickv-stereo :m5unitv2 t) "HEAD_LINK3" names "" replace #f(-4 0 24)))

(defun gen-khrh2-aux (h-model &optional (fname "HEAD_LINK3")
			      (func-names *khr-func-names*)
			      (type "") (replace t) (offset #f(0 0 0)))
  (gen-camera-wrl h-model offset)
  (with-open-file (f (format nil "KHR/~A.wrl" fname) :direction :output)
		  (send h-model :dump-to-wrl :strm f :wpos offset))
  (dolist (func func-names)
    (khr2model func type replace)))

(defun gen-camera-wrl (&optional (h-model (m5stickv-stereo)) (offset #f(0 0 0)))
  (let* ((cams (get h-model :cameras))
	 (lcam (car cams))
	 (rcam (cadr cams)))
    (with-open-file (f "KHR/HEAD_CAMERA.wrl" :direction :output)
      (send lcam :translate offset :world)
      (send lcam :rotate pi :x)
      ;;(send lcam :rotate -pi/2 :z)
      (send lcam :rotate -pi :z)
      (dump-camera (send lcam :worldcoords) :name "camera0" :sensor-id 0 :strm f)
      (send rcam :rotate pi :x)
      ;;(send rcam :rotate -pi/2 :z)
      (send rcam :rotate -pi :z)
      (send rcam :translate offset :world)
      (dump-camera (send rcam :worldcoords) :name "camera1" :sensor-id 1 :strm f)
      )
    ))

(defun khr2collada-robot (&key (fname "KHRmain")
			       (wrl (format nil "KHR/~A.wrl" fname))
			       (dae (format nil "daes/~A.dae" fname))
			       (yaml (format nil "yamls/~A.yaml" fname))
			       (model (format nil "models/~A.l" fname))
			       )
  (export-collada wrl dae)
  (collada2eus fname :dae dae :yaml yaml :model model)
  fname)

(defun khr2model (robo-name &optional (type "") (replace t))
  (mkdir-unless "yamls")  
  (unix:system (format nil "cp KHR/~A~A.yaml yamls" robo-name type))
  (mkdir-unless "daes")  
  (export-collada (format nil "KHR/~A~Amain.wrl" robo-name type)
		  (format nil "daes/~A~A.dae" robo-name type))
  (collada2eus (format nil "~A~A" robo-name type))
  (if replace (unix:system (format nil "cp models/~A~A.l KHR" robo-name type))))

(setq *khr-ufunc-names*
      '(khrh2u khr20h2u khr22h2u khrl6a3h2u khrl6a4h2u khrt1l6a3h2u khrt1l6a4h2u))

(setq *khr-u2func-names*
      '(khrh2u2 khr20h2u2 khr22h2u2 khrl6a3h2u2 khrl6a4h2u2 khrt1l6a3h2u2 khrt1l6a4h2u2))

(setq *khr-u3func-names*
      '(khrh2u3 khr20h2u3 khr22h2u3 khrl6a3h2u3 khrl6a4h2u3 khrt1l6a3h2u3 khrt1l6a4h2u3))

(setq *khr-vfunc-names*
      '(khrh2v khr20h2v khr22h2v khrl6a3h2v khrl6a4h2v khrt1l6a3h2v khrt1l6a4h2v))

(setq *khr-v3func-names*
      '(khrh2v3 khr20h2v3 khr22h2v3 khrl6a3h2v3 khrl6a4h2v3 khrt1l6a3h2v3 khrt1l6a4h2v3))

(setq *khr-no-h2* '(khr khr20 khr22))

(setq *khr-func-names*
      '(khrh2 khr20h2 khr22h2 khrl6a3h2 khrl6a4h2 khrt1l6a3h2 khrt1l6a4h2))

(defun check-khrh2 (&key (xs 400) (ys 400))
  (require :kxranimate)
  (setq *khr-robots* nil)
  (dolist (f *khr-func-names*)
    (load (format nil "models/~A.l"f))
    (push (funcall f) *khr-robots*))
  (show-2d-arrange *khr-robots* :xs xs :ys ys)
  )

(defun bodyset2wrl (bs fname &optional (wpos (send bs :worldpos)))
  (with-open-file (f fname :direction :output)
    (send bs :dump-to-wrl :strm f :wpos wpos))
  )

(defun dump-camera (coord &key (name "camera") (sensor-id 0) (strm t) (scale 0.001))
  (let* ((wpos (scale scale (send coord :worldpos)))
	 (lrot (let ((rx (matrix-log (send coord :rot))))
		 (list (norm rx) (normalize-vector rx))))
	 rot-v rot-a)
    (if (eps= (car lrot) 0.0)
	(setq rot-v (float-vector 0 0 1) rot-a 0)
	(setq rot-v (cadr lrot) rot-a (car lrot)))
    (format strm " DEF ~A VisionSensor {~%" name)
    (format strm "  translation ~8,6f ~8,6f ~8,6f~%" 
	    (elt wpos 0) (elt wpos 1) (elt wpos 2))
    (format strm "  rotation ~A ~A ~A ~A~%"
	    (elt rot-v 0) (elt rot-v 1) (elt rot-v 2) rot-a)
    (format strm "    name \"~A\"~%" name)
    (format strm "    sensorId ~A }~%" sensor-id)
    ))

(defmethod bodyset
  (:dump-to-wrl-old 
   (&rest args
	  &key (strm t) (mode :normal) robot
	  (wpos (send self :worldpos))
	  (scale 0.001) (name (string (send self :name)))
	  &allow-other-keys)
   (dolist (b (send self :bodies))
     (send* b :dump-to-wrl :wpos wpos :robot robot args))
   )
  (:dump-to-wrl
   (&rest args
	  &key (strm t) (mode :normal) robot
	  (wpos (send self :worldpos))
	  (scale 0.001) (name (string (send self :name)))
	  &allow-other-keys)
   (let ((lrot (let ((rx (matrix-log (send self :rot))))
		 (list (norm rx) (normalize-vector rx))))
	 rot-v rot-a)
     (if (eps= (car lrot) 0.0)
	 (setq rot-v (float-vector 0 0 1) rot-a 0)
	 (setq rot-v (cadr lrot) rot-a (car lrot)))
     (format strm "DEF ~A Transform {~%" name)
     ;;(setq pos (scale scale (v- wpos (send parent :worldpos))))
     ;;(setq pos (scale scale (send self :pos)))
     (setq wpos (scale scale wpos))
     (format strm "  translation ~8,6f ~8,6f ~8,6f~%" 
	     (elt wpos 0) (elt wpos 1) (elt wpos 2))
     (format strm "  rotation ~A ~A ~A ~A~%"
	     (elt rot-v 0) (elt rot-v 1) (elt rot-v 2) rot-a)
     (format strm "  children [~%")
     ;;(send* self :dump-imu-sensors :robot robot args)
     ;; dump shapes
     (dolist (b (send self :bodies))
       (send* b :dump-to-wrl :wpos wpos :robot robot args))
     (format strm "] # children of ~%")
     (format strm "} #~%")
     ))
  )


(defmethod bodyset-link
  (:dump-to-wrl 
   (&rest
    args
    &key (strm t) (mode :openhrp3) robot (fixed nil) (scale 0.001) &allow-other-keys)
   (let* ((name (if (get self :abbrev-name)(get self :abbrev-name)
		  (if (send self :name) (string (send self :name)))))
	  (wpos (send self :worldpos))
	  pos
	  (rot (let ((rx (matrix-log (send self :rot))))
		 (list (norm rx) (normalize-vector rx))))
	  (vnum 0)
	  (jname (if joint (send (send self :joint) :name) "WAIST"))
	  rot-v rot-a diffuse link-vs centroid im)
     (if (eps= (car rot) 0.0)
	 (setq rot-v (float-vector 0 0 1) rot-a 0)
       (setq rot-v (cadr rot) rot-a (car rot)))
     (case mode
	   ((:openhrp2 :openhrp3)
	    (setq centroid (scale scale (or (get self :centroid) (self . acentroid)))
		  im (scale-matrix
		      (* scale scale scale)
		      (or (get self :inertia-tensor) (send self :inertia-tensor)))
		  )
	    ;;(format strm "DEF ~A Joint {~%" (if (send self :parent-link) name "WAIST"))
	    (format strm "DEF ~A Joint { # ~A ~%" jname jname)
	    (if (derivedp parent bodyset-link)
		(if (derivedp (send self :joint) linear-joint)
		    (format strm "  jointType \"slide\"~%")
		  (format strm "  jointType \"rotate\"~%"))
	      (if fixed
		  (format strm "  jointType \"fixed\"~%")
		(format strm "  jointType \"free\"~%")))
	    (format strm "  dh [0 0 0 0]~%")
	    ;;
	    (when (derivedp parent bodyset-link)
	      (let* ((ajoint (send self :joint))
		     (tmpid (if (find-method ajoint :servo)
				(send ajoint :servo :no)
			      (send ajoint :get :joint-id-for-dump))))
		(when ajoint
		  (format strm "  jointAxis ~A~%"
			  (if (eq mode :openhrp2)
			      (format nil "\"~A\"" (string (ajoint . axis)))
			    (let ((tmp-axis ;; if eq mode :openhrp3
				   (case (ajoint . axis)
					 (:x #f(1 0 0)) (:y #f(0 1 0)) (:z #f(0 0 1))
					 (:-x #f(-1 0 0)) (:-y #f(0 -1 0)) (:-z #f(0 0 -1))
					 (t (ajoint . axis)))))
			      (setq tmp-axis (send self :rotate-vector tmp-axis))
			      (format nil "~A ~A ~A" (elt tmp-axis 0) (elt tmp-axis 1) (elt tmp-axis 2)))))
		  (format strm "  jointId ~A~%" tmpid)
		  (format strm "  ulimit [~A]~%" (deg2rad (send ajoint :max-angle)))
		  ;;(send ajoint :angle-to-speed (send ajoint :max-angle)))
		  (format strm "  llimit [~A]~%" (deg2rad (send ajoint :min-angle)))
		  ;;(send ajoint :angle-to-speed (send ajoint :min-angle)))
		  (format strm "  uvlimit [~A]~%" (send ajoint :max-joint-velocity))
		  (format strm "  lvlimit [~A]~%"  (- (send ajoint :max-joint-velocity)))
		  (when
		      tmpid
		    (format strm "  climit [~A]~%" (get ajoint :climit))
		    (format strm "  torqueConst ~A~%" (get ajoint :torque-const))
		    (format strm "  gearRatio ~A~%" (get ajoint :gear-ratio))
		    (format strm "  rotorInertia ~A~%" (get ajoint :rotor-inertia)))
		  )))
	    ;;(setq pos (scale scale (if (derivedp parent bodyset-link) 
	    ;;(send self :pos) (send self :worldpos))))
	    (setq pos (scale scale (v- wpos (send parent :worldpos))))
	    (format strm "  translation ~8,6f ~8,6f ~8,6f~%" 
		    (elt pos 0) (elt pos 1) (elt pos 2))
	    ;;(format strm "  translation 0.0 0.0 0.0~%")
	    ;;(format strm "  rotation ~A ~A ~A ~A~%"
	    ;;(elt rot-v 0) (elt rot-v 1) (elt rot-v 2) rot-a)
	    (format strm "  rotation 0.0 0.0 1.0 0.0~%")
	    (format strm "  children [ # ~A~%" jname)
	    ;; segments
	    (format strm "DEF ~A Segment {~%" name)
	    (format strm "  centerOfMass ~A ~A ~A~%" 
		    (elt centroid 0)(elt centroid 1) (elt centroid 2))
	    (format strm "  mass ~A~%" (* scale (or (get self :weight) (send self :weight))))
	    
	    (format strm "  momentsOfInertia [ ~A ~A ~A ~A ~A ~A ~A ~A ~A ]~%" 
		    (aref im 0 0) (aref im 0 1) (aref im 0 2)
		    (aref im 1 0) (aref im 1 1) (aref im 1 2)
		    (aref im 2 0) (aref im 2 1) (aref im 2 2))
	    )
	   ;;
	   ((:webots)
	    (setq centroid (scale scale (or (get self :centroid) (self . acentroid)))
		  im (scale-matrix
		      (* scale scale scale)
		      (or (get self :inertia-tensor) (send self :inertia-tensor)))
		  )
	    ;;(format strm "DEF ~A Joint {~%" (if (send self :parent-link) name "WAIST"))
	    (when (derivedp parent bodyset-link)
	      (let* ((ajoint (send self :joint))
		     (tmpid (if (find-method ajoint :servo)
				(send ajoint :servo :no)
			      (send ajoint :get :joint-id-for-dump))))
		(when ajoint
		  (format strm "HingeJoint { # ~A ~%" jname)
		  (format strm "  jointParameters HingeJointParameters {~%")
		  (format strm "  axis ~A~%"
			  (let ((tmp-axis
				 (case (ajoint . axis)
				       (:x #f(1 0 0)) (:y #f(0 1 0)) (:z #f(0 0 1))
				       (:-x #f(-1 0 0)) (:-y #f(0 -1 0)) (:-z #f(0 0 -1))
				       (t (ajoint . axis)))))
			    (setq tmp-axis (send self :rotate-vector tmp-axis))
			    (format nil "~A ~A ~A"
				    (elt tmp-axis 0) (elt tmp-axis 1) (elt tmp-axis 2))))
		  (format strm "anchor 0 0 0~%")
		  (format strm "}~%")
		  (when
		      tmpid
		    (format strm "  device [~%")
		    (format strm "  RotationalMotor{~%")
		    (format strm "    name ~S~%" (string (send ajoint :name)))
		    (format strm "    maxVelocity ~A~%" (send ajoint :max-joint-velocity))
		    (format strm "    maxTorque ~A~%" (send ajoint :max-joint-torque))
		    (format strm "  }~%")
		    (format strm "  PositionSensor {~%")
		    (format strm "    name ~S~%" (format nil "~A_Sensor" (send ajoint :name)))
		    (format strm "  }~%]")
		    )
		  (setq pos (scale scale (v- wpos (send parent :worldpos))))
		  (format strm "  endPoint Solid {~%")
		  (format strm "  children [ # ~A~%" jname)
		  (format strm "  Transform {~%") 
		  (format strm "  translation ~8,6f ~8,6f ~8,6f~%" 
			  (elt pos 0) (elt pos 1) (elt pos 2))
		  (format strm "  rotation 0.0 0.0 1.0 0.0~%")
		  ))))
	   ((:normal)
	    (format strm "DEF ~A Transform {~%" name)
	    (setq pos (scale scale (send self :pos)))
	    (format strm "  translation ~8,6f ~8,6f ~8,6f~%" 
		    (elt pos 0)(elt pos 1) (elt pos 2))
	    (format strm "  rotation ~A ~A ~A ~A~%"
		    (elt rot-v 0) (elt rot-v 1) (elt rot-v 2) rot-a))
	   (:robotbrowser
	    (format strm "DEF ~A Transform {~%" name)
	    (setq pos (scale scale (v- wpos (send parent :worldpos))))
	    (format strm "  translation ~8,6f ~8,6f ~8,6f~%" 
		    (- (elt pos 0)) (elt pos 2) (elt pos 1))
	    (format strm "  rotation 0.0 0.0 1.0 0.0~%"))
	   ) ;; case mode
     
     (format strm "  children [~%")
     (send* self :dump-animation args)
     ;;; dump sensors
     (send* self :dump-camera-sensors :robot robot args)
     (send* self :dump-force-sensors :robot robot args)
     (send* self :dump-imu-sensors :robot robot args)
     ;;(send* self :dump-KJS-sensors :robot robot args)
     ;; dump shapes
     (dolist (b (send self :bodies))
       (send* b :dump-to-wrl :wpos wpos :robot robot args))
     ;;
     (when (memq mode (list :openhrp2 :openhrp3))
       (format strm "  ]~%") ;; children[
       (format strm "} #Segment ~A~%" name)
       )
     (dolist (d child-links) 	 ;;(d (send self :descendants))
       (when (derivedp d bodyset-link)
	 (send d :dump-to-wrl :strm strm :mode mode :robot robot))
       )
     (format strm "] # children of ~A~%" jname)
     (format strm "} # ~A~%" jname)
     ))
  (:dump-camera-sensors ;;
   (&rest args &key strm (mode :openhrp3) robot (scale 0.001) &allow-other-keys)
   (let* (sensor-names sensors (i 0) pos ori v a)
     (dolist (c (send robot :cameras))
       (when (null (send c :name))
	 (send c :name (format nil "camera~A" i))
	 (incf i))
       (push (send c :name) sensor-names))
     (setq sensors (remove-if-not #'(lambda (x) (member (send x :name) sensor-names :test #'equal))
				  descendants))
     (case mode
       ((:openhrp2 :openhrp3)
	(when sensors
	  (dotimes (i (length sensors))
	    (setq pos (scale 0.001 (send (elt sensors i) :pos)))
	    ;;(setq ori (matrix-log (send (elt sensors i) :rot)))  2022.10.21
	    (setq ori (matrix-log (rotate-matrix (send (elt sensors i) :rot) pi :x)))
	    (setq v (normalize-vector ori) a (norm ori))
	    (if (eps= a 0) (setq v (float-vector 1 0 0)))
	    (if (eq mode :webots)
		(format strm "    DEF camera~A Camera {~%        translation " (+ i *eus2wrl-camera-index*))
		(format strm "    DEF camera~A VisionSensor {~%        translation " (+ i *eus2wrl-camera-index*)))
	    (format strm "~A ~A ~A~%" (elt pos 0) (elt pos 1) (elt pos 2))
	    (format strm "        rotation ~A ~A ~A ~A~%" (elt v 0) (elt v 1) (elt v 2) a)
	    (format strm "        name \"camera~A\" ~%" (+ i *eus2wrl-camera-index*))
	    ;;	 (format strm "        type \"base_pinhole_camera\" ~%")
	    (format strm "        sensorId ~A }~%" (+ i *eus2wrl-camera-index*)))
	  (setq *eus2wrl-camera-index* (length sensors))))
       ((:webots)
	(when sensors
	  (dotimes (i (length sensors))
	    (setq pos (scale 0.001 (send (elt sensors i) :pos)))
	    (setq ori (matrix-log (send (elt sensors i) :rot)))
	    (setq v (normalize-vector ori) a (norm ori))
	    (if (eps= a 0) (setq v (float-vector 1 0 0)))
	    (if (eq mode :webots)
		(format strm "    DEF camera~A Camera {~%        translation " (+ i *eus2wrl-camera-index*))
		(format strm "    DEF camera~A VisionSensor {~%        translation " (+ i *eus2wrl-camera-index*)))
	    (format strm "~A ~A ~A~%" (elt pos 0) (elt pos 1) (elt pos 2))
	    (format strm "        rotation ~A ~A ~A ~A~%" (elt v 0) (elt v 1) (elt v 2) a)
	    (format strm "        name \"camera~A\" ~%}~%" (+ i *eus2wrl-camera-index*))
	    (setq *eus2wrl-camera-index* (length sensors))))
	))
     ))
  (:dump-force-sensors ;;
   (&rest args &key strm (mode :openhrp3) robot (scale 0.001) &allow-other-keys)
   (let* ((sensor-names (send-all (send robot :force-sensors) :name))
	  (sensor (find-if #'(lambda (x) (member (send x :name) sensor-names :test #'equal))
			   descendants))
	  pos)
     (case mode
       ((:openhrp2 :openhrp3)
	(when sensor
	  (format strm "    DEF ~A ForceSensor {~%        translation " (send sensor :name))
	  (format strm "~A ~A ~A~%" 0.0 0.0 0.0)
	  (format strm "        rotation ~A ~A ~A ~A~%" 1 0 0 0)
	  (format strm "        sensorId ~A }~%" (position (send sensor :name)
							   sensor-names :test #'equal))
	  ))
       ((:webots)
	(when sensor
	  (format strm "    DEF ~A TouchSensor {~%        translation " (send sensor :name))
	  (format strm "~A ~A ~A~%" 0.0 0.0 0.0)
	  (format strm "        rotation ~A ~A ~A ~A~%" 1 0 0 0)
	  (format strm "        type \"force-3d\"~%")
	  (format strm "        name ~A }~%" (position (send sensor :name)
						       sensor-names :test #'equal))
	  )))
     )
   )
  (:dump-imu-sensors ;;
   (&rest args &key strm (mode :openhrp3) robot (scale 0.001) &allow-other-keys)
   (let* ((sensor-names (send-all (send robot :imu-sensors) :name))
	  (sensors (remove-if-not #'(lambda (x) (member (send x :name) sensor-names :test #'equal))
				  descendants))
	  pos rx rot-v rot-a)
     (case mode
       ((:openhrp2 :openhrp3)
	    ;;(format t ";; dump descendants=~A~%;;  imus=~A~%;;  sensors=~A~%" descendants (send robot :imu-sensors) sensors))
	    (dolist (sensor sensors)
	      (when sensor
		(if (eq mode :webots)
		    (if	(string-equal (send sensor :name) "gyrometer")
			(format strm "    DEF ~A Gyro {~%        translation " (send sensor :name))
			(format strm "    DEF ~A Accelerometer {~%        translation " (send sensor :name)))
		    (if
		     (string-equal (send sensor :name) "gyrometer")
		     (format strm "    DEF ~A Gyro {~%        translation " (send sensor :name))
		     (format strm "    DEF ~A AccelerationSensor {~%        translation " (send sensor :name))))
		;;(setq pos (scale scale (send sensor :pos)))
		(setq pos (scale scale (v- (send sensor :worldpos) (send (send sensor :parent) :worldpos)))) 
		(setq rx (matrix-log (send sensor :worldrot)))
		(if (eps= (norm rx) 0.0) (setq rot-v (float-vector 0 0 1) rot-a 0)
		    (setq rot-v (normalize-vector rx) rot-a (norm rx)))
		(format strm "~A ~A ~A~%" (elt pos 0) (elt pos 1) (elt pos 2))
		(format strm "        rotation ~A ~A ~A ~A~%" (elt rot-v 0) (elt rot-v 1) (elt rot-v 2) rot-a)
		(format strm "        sensorId ~A }~%" (or (send sensor :get :sensor-id) 0)))
	      ))
	   ((:webots)
	    (dolist (sensor sensors)
	      (when sensor
		(if (eq mode :webots)
		    (if
			(string-equal (send sensor :name) "gyrometer")
			(format strm "    DEF ~A Gyro {~%        translation " (send sensor :name))
		      (format strm "    DEF ~A Accelerometer {~%        translation " (send sensor :name)))
		  (if
		      (string-equal (send sensor :name) "gyrometer")
		      (format strm "    DEF ~A Gyro {~%        translation " (send sensor :name))
		    (format strm "    DEF ~A AccelerationSensor {~%        translation " (send sensor :name))))
		(setq pos (scale scale (send sensor :pos)))
		(setq rx (matrix-log (send sensor :worldrot)))
		(if (eps= (norm rx) 0.0)
		    (setq rot-v (float-vector 0 0 1) rot-a 0)
		  (setq rot-v (normalize-vector rx) rot-a (norm rx)))
		(format strm "~A ~A ~A~%" (elt pos 0) (elt pos 1) (elt pos 2))
		(format strm "        rotation ~A ~A ~A ~A~%}~%"
			(elt rot-v 0) (elt rot-v 1) (elt rot-v 2) rot-a))
	      )))
     )
   )
  (:dump-KJS-sensors ;;
   (&rest args &key strm (mode :openhrp3) robot (scale 0.001) &allow-other-keys)
   (let* ((kjss (send robot :kjs-sensors))
	  (sensor-names (send-all kjss :name))
	  (dess (send self :find-named-objects "KJS" :method :bodies))
	  (sensor (find-if #'(lambda (x) (member (send x :name) sensor-names :test #'substringp))
			   dess))
	  sensor-name pos rx rot-a rot-v)
     ;;(format t ";; pressure-sensors=~A~%" sensor-names)
     ;;(format t ";; dess=~A~%" dess)
     ;;(format t ";; pressure-sensors parent=~A~%" (send-all (send robot :pressure-sensors) :parent))
     ;;(format t ";; descendants=~A~%" dess) ;; (send-all descendants :name)
     (case mode
       ((:openhrp2 :openhrp3)
	(when sensor
	  (setq sensor-name (send sensor :name))
	  ;;(format t ";; sensor=~A kjs=~A~%" (send sensor :name)  *eus2wrl-kjs-index*)
	  (format strm "    DEF ~A Gyro {~%        translation "
		  sensor-name
		  ;;(format nil "~A-~A" (send sensor :name) *eus2wrl-kjs-index*)
		  )
	  (setq pos (scale scale (send sensor :pos)))
	  (setq rx (matrix-log (send sensor :worldrot)))
	  (if (eps= (norm rx) 0.0) (setq rot-v (float-vector 0 0 1) rot-a 0)
	      (setq rot-v (normalize-vector rx) rot-a (norm rx)))
	  (format strm "~A ~A ~A~%" (elt pos 0) (elt pos 1) (elt pos 2))
	  (format strm "        rotation ~A ~A ~A ~A~%" (elt rot-v 0) (elt rot-v 1) (elt rot-v 2) rot-a)
	  (format strm "        sensorId ~A }~%"
		  (or (send sensor :get :sensor-id)
		      (position (send sensor :name) sensor-names :test #'substringp)
		      0))
	  #|
	  (format strm "    DEF ~A AccelerationSensor {~%        translation "
		  (format nil "gsensor-~A-~A" (send sensor :name) *eus2wrl-kjs-index*))
	  (setq pos (scale scale (send sensor :pos)))
	  (setq rx (matrix-log (send sensor :worldrot)))
	  (if (eps= (norm rx) 0.0) (setq rot-v (float-vector 0 0 1) rot-a 0)
	      (setq rot-v (normalize-vector rx) rot-a (norm rx)))
	  (format strm "~A ~A ~A~%" (elt pos 0) (elt pos 1) (elt pos 2))
	  (format strm "        rotation ~A ~A ~A ~A~%" (elt rot-v 0) (elt rot-v 1) (elt rot-v 2) rot-a)
	  (format strm "        sensorId ~A }~%"
		  (or (send sensor :get :sensor-id)
		      (position (send sensor :name) sensor-names :test #'substringp)
		      0))
	  ;;
	  (format strm "    DEF ~A PressureSensor {~%        translation " (send sensor :name))
	  (setq pos (scale scale (send sensor :pos)))
	  (setq rx (matrix-log (send sensor :worldrot)))
	  (if (eps= (norm rx) 0.0)
	      (setq rot-v (float-vector 0 0 1) rot-a 0)
	      (setq rot-v (normalize-vector rx) rot-a (norm rx)))
	  (format strm "~A ~A ~A~%" (elt pos 0) (elt pos 1) (elt pos 2))
	  (format strm "        rotation ~A ~A ~A ~A~%"
		  (elt rot-v 0) (elt rot-v 1) (elt rot-v 2) rot-a)
	  ;;(format strm "~A ~A ~A~%" 0.0 0.0 0.0)
	  ;;(format strm "        rotation ~A ~A ~A ~A~%" 1 0 0 0)
	  (format strm "        sensorId ~A }~%"
		  (or (position (send sensor :name) sensor-names :test #'substringp)
		      0))
	  |#
	  (incf *eus2wrl-kjs-index*)
	  ))
       ((:webots)
	(when sensor
	  (format strm "    DEF ~A TouchSensor {~%        translation " (send sensor :name))
	  (format strm "~A ~A ~A~%" 0.0 0.0 0.0)
	  (format strm "        rotation ~A ~A ~A ~A~%" 1 0 0 0)
	  (format strm "        type \"force-3d\"~%")
	  (format strm "        name ~A }~%" (position (send sensor :name)
						       sensor-names :test #'equal))
	  )))
     )
   )
  (:dump-animation
   (&rest args &key strm name &allow-other-keys)
   (when 
       (get self :animation)
     (let (p r ang v)
       (format strm "    DEF ~A-POS-INTERP PositionInterpolator {~%" name)
       (format strm "      key [")
       (dolist (a (get self :animation))
	 (format strm "~A, ") (car a))
       (format strm "        ~%]~%")
       (format strm "      keyvalue [")
       (dolist (a (get self :animation))
	 (setq p (send (cdr a) :pos))
	 (format strm "~A ~A ~A, " (elt p 0) (elt p 1) (elt p 2)))
       (format strm "        ] },~%")
       ;;					
       (format strm "    DEF ~A-ROT-INTERP OrientationInterpolator {~%" name)
       (format strm "      key [")
       (dolist (a (get self :animation))
	 (format strm "~A, ") (car a))
       (format strm "        ~%]~%")
       (format strm "      keyvalue [")
       (dolist (a (get self :animation))
	 (setq r (send (cdr a) :rotation-angle))
	 (if (null r) (setq r 0 v #f(1 0 0))
	   (setq ang (car r) v (cadr r)))
	 (format strm "~A ~A ~A ~A, " 
		 ang (elt v 0) (elt v 1) (elt v 2)))
       (format strm "        ] },~%")
       ))
   )
  )

(defmethod faceset
    (:dump-to-wrl
     (&rest args &key wpos (strm t) robot (mode :openhrp3) (scale 0.001) &allow-other-keys)
		   (let ((glb (generate-glbody self)))
		     (send* glb :dump-to-wrl args)
		     self)
		   ))

(defun generate-glbody (bod)
  (let (mat (col (get bod :face-color)) (glbod (instantiate gl::glbody)))
    (when col
      (unless (vectorp col) (setq col (gl::find-color col)))
      (setq mat
	    (list
	     (list :ambient
		   (float-vector (elt col 0) (elt col 1) (elt col 2)))
	     (list :diffuse
		   (float-vector (elt col 0) (elt col 1) (elt col 2))))))
    (replace-object glbod bod)
    (send glbod :set-color col)
    (send glbod :init-mass-property)
    
    (setq (glbod . gl::aglvertices) (gl::make-glvertices-from-faceset bod :material mat))
    (setf (get (glbod . gl::aglvertices) :face-color) (get bod :face-color))
    glbod))
    
(defmethod gl::glbody
  (:dump-to-wrl 
   (&rest args &key wpos strm robot (mode :openhrp3) (scale 0.001) &allow-other-keys)
   #|
   (when
       (get self :dump-to-wrl)
     (format t ";; :dump-to-wrl glbody ~A already?=~A~%" (send self :name) (get self :dump-to-wrl))
     (return-from :dump-to-wrl nil))
   |#
   (let* ((glv (send self :glvertices))
	  ;;(name (symbol-name (gensym (string (send self :name))))))
	  (name (string (send self :name))))
     (dolist (minfo (glv . gl::mesh-list))
       (when
	   (string-equal name "wheel")
	 (if (eq mode :webots)
	     (format strm "    Solid {~%")
	   (format strm "    Surface {~%"))
	 (format strm "    collision [~%")
	 (let (offset cyl r h b rot-a rot-v rotav)
	   (cond
	    ((assoc :revolution csg)
	     (setq b (revolution2cylinder self))
	     (setq cyl (assoc :cylinder (b . csg))))
	    (t (setq b self) (setq cyl (assoc :cylinder csg))))
	   ;;
	   (setq offset
		 (scale scale
			(v- (send self :worldpos) (send (send self :parent) :worldpos))))
	   (setq rotav (rotation-angle (m* rot (send b :rot))))
	   (if (or (null rotav) (memq *nan* (coerce (cadr rotav) cons)))
	       (setq rot-v (float-vector 0 0 1) rot-a 0)
	     (setq rot-v (cadr rotav) rot-a (car rotav)))
	   (setq r (cadr cyl) h (caddr cyl))
	   (format strm "      Transform {~%")
	   (format strm "        translation ~A ~A ~A~%"
		   (elt offset 0) (elt offset 1) (elt offset 2))
	   (format strm "        rotation ~A ~A ~A ~A~%"
		   (elt rot-v 0) (elt rot-v 1) (elt rot-v 2) rot-a)
	   ;;
	   (format strm "        children [~%" )
	   (format strm "    Shape {~%")
	   (format strm "      geometry Cylinder {~%")
	   (format strm "        radius ~A~%" (* scale r))
	   (format strm "        height ~A }~%" (* scale h))
	   (format strm "} # Shape~%" )
	   (format strm "      ] # children~%")
	   (format strm "} # Transform~%" )
	   (format strm "] # collision~%" ))
	 (format strm "    visual [~%")
	 )
       (format strm "    Shape {~%")
       (format strm "      appearance Appearance {~%")
       ;; FIXME: use other material info
       (let ((mat (cadr (assoc :material minfo))))
	 (let ((diff (cadr (assoc :diffuse mat))))
	   (format strm "        material Material {~%")
	   #|
	   (cond
	   ((= (length diff) 4)
	   (format strm "          diffuseColor ~A ~A ~A ~A~%"
	   (elt diff 0) (elt diff 1) (elt diff 2) (elt diff 3)))
	   ((= (length diff) 3)
	   (format strm "          diffuseColor ~A ~A ~A~%"
	   (elt diff 0) (elt diff 1) (elt diff 2))))
	   |#
	   (format strm "          diffuseColor ~A ~A ~A~%"
		   (elt diff 0) (elt diff 1) (elt diff 2))
	   (format strm "          ambientIntensity 0.2~%")
	   (format strm "        }~%")
	   ))
       (format strm "      }~%") ;; appearance
       (format strm "      geometry DEF ~A-FACES IndexedFaceSet {~%" name)
       (format strm "        ccw TRUE~%")
       ;;(format strm "        ccw FALSE~%") ;;???
       (format strm "        solid TRUE~%")
       
       (format strm "        coord DEF ~A-COORD Coordinate {~%" name)
       (format strm "          point[~%")
       (let* ((vmat (cadr (assoc :vertices minfo)))
	      pt
	      (size (array-dimension vmat 0)))
	 (dotimes (i size)
	   (setq pt (instantiate float-vector 3))
	   (user::c-matrix-row vmat i pt)
	   (setq pt (v- (send glv :transform-vector pt) wpos)) ;; glv not self important 2022.6.2
	   (scale scale pt pt)
	   (format strm "            ~A ~A ~A,~%"
		   (elt pt 0) (elt pt 1) (elt pt 2)))
	 )
       (format strm "          ]~%")
       (format strm "        }~%") ;; Coordinate {
       (let ((nmat (cadr (assoc :normals minfo))))
	 (when nmat
	   (let ((pt (instantiate float-vector 3))
		 (size (array-dimension nmat 0)))
	     (format strm "        normal Normal {~%")
	     (format strm "          vector[~%")
	     (dotimes (i size)
	       (user::c-matrix-row nmat i pt)
	       (setq pt (send self :rotate-vector pt))
	       (format strm "            ~A ~A ~A,~%"
		       (elt pt 0) (elt pt 1) (elt pt 2)))
	     )
	   (format strm "          ]~%")
	   (format strm "        }~%") ;; Normal {
	   ))
       (format strm "        coordIndex [~%")
       (let ((vidx (cadr (assoc :indices minfo)))
	     (tp (cadr (assoc :type minfo)))
	     (step 3) (cntr 0))
	 (case tp
	       (:lines     (setq step 2))
	       (:triangles (setq step 3))
	       (:quads     (setq step 4))
	       (t ))
	 (dotimes (i (/ (length vidx) step))
	   (format strm "        ")
	   (dotimes (j step)
	     (format strm "~A, " (elt vidx cntr))
	     (incf cntr))
	   (format strm "-1,~%"))
	 )
       (format strm "        ] #coordIndex ~%") ;; coordIndex
       (format strm "      } #IndexedFaceSet ~%") ;; IndexedFaceSet
       (format strm "    } # Shape ~%")
       (when
	   (string-equal name "wheel")
	 (format strm "] # visual ~%")
	 (format strm "} # Surface ~%")
	 )
       )
     ;;(setf (get self :dump-to-wrl) t)
     ))
  )

(defun dump-object-to-wrl (obj strm &key ((:scale sc) 0.001) actuator-joint-check)
  (let* ((pos (scale sc (send obj :pos)))
	 (rot (rotation-angle (send obj :rot)))
	 (children (send obj :descendants))
	 (color (get obj :face-color))
	 name material diffuse fs vs vlist v rot-v rot-a)
    (if (get obj :abbrev-name) (setq name (get obj :abbrev-name))
      (if (send obj :name)(setq name (send obj :name))
	(return-from dump-object-to-wrl nil)))
    (if (or (null rot) (memq *nan* (coerce (cadr rot) cons)))
	(setq rot-v (float-vector 0 0 1) rot-a 0)
      (setq rot-v (cadr rot) rot-a (car rot)))

    (format strm "DEF ~A Transform {~%" name)
    (format strm "  translation ~A ~A ~A~%" 
	    (elt pos 0) (elt pos 1) (elt pos 2))
    (format strm "  rotation ~A ~A ~A ~A~%"
	    (elt rot-v 0) (elt rot-v 1) (elt rot-v 2) rot-a)
    (format strm "  children [~%")
    (when (derivedp obj body)
      (setq fs (flatten (mapcar #'eus2iv-tessel-aux (send obj :faces)))
	    vs (body-model-vertices obj)
	    vlist vs)
      (format strm "    Shape {~%")
      (format strm "      appearance Appearance {~%")
      (when (and color (find-package "GL"))
	(setq material (gl::find-color color)
	      diffuse (send material :diffuse))
	(format strm "        material Material {~%")
	(format strm "          diffuseColor ~A ~A ~A~%"
		(elt diffuse 0) (elt diffuse 1) (elt diffuse 2))
	(format strm "          ambientIntensity 0.2~%")
	(format strm "        }~%")
	)
      (format strm "      }~%")
      (format strm "      geometry DEF ~A-FACES IndexedFaceSet {~%" name)
      (format strm "        ccw TRUE~%")
      (format strm "        solid TRUE~%")
      (format strm "        coord DEF ~A-COORD Coordinate {~%" name)
      (format strm "          point[~%")
      (while vlist
	(setq v (scale sc (pop vlist)))
	(if vlist
	    (format strm "            ~A ~A ~A,~%"
		    (elt v 0) (elt v 1) (elt v 2))
	  (format strm "            ~A ~A ~A~%"
		  (elt v 0) (elt v 1) (elt v 2))
	  )
	)
      (format strm "          ]~%")
      (format strm "        }~%")
      (format strm "        coordIndex [~%")
      (while fs
	(format strm "        ")
	(dolist
	    (p (cdr (send (pop fs) :vertices)))
	  (format strm "~A, " 
		  (position (send obj :inverse-transform-vector p) vs
			    :test #'eps-v=))
	  )
	(if fs (format strm "-1,~%") (format strm "-1~%"))
	)
      (format strm "        ]~%")
      (format strm "      }~%")
      (format strm "    }~%")
      )
    (while children
      (if (and (dump-object-to-wrl (pop children) strm :scale sc :actuator-joint-check actuator-joint-check)
	       (< 1 (length children)))
	  (format strm "    ,~%"))
      )
    (format strm "  ]~%") ;; children[
    (format strm "}~%") ;; DEF
    t))

(defun print-webots-proto (&optional (strm t) name)
  (format strm
	  "
PROTO ~A [
  field  SFVec3f     translation     0 0 0
  field  SFRotation  rotation        0 1 0 0
  field  SFString    name            \"~A\"  # Is `Robot.name`.
  field  SFString    controller      \"void\"         # Is `Robot.controller`.
  field  MFString    controllerArgs  []             # Is `Robot.controllerArgs`.
  field  SFString    customData      \"\"             # Is `Robot.customData`.
  field  SFBool      supervisor      FALSE          # Is `Robot.supervisor`.
  field  SFBool      synchronization TRUE           # Is `Robot.synchronization`.
  field  SFBool      selfCollision   FALSE          # Is `Robot.selfCollision`.
  field  MFNode      extensionSlot   []             # Is `Robot.extensionSlot`.
]
"
	  name name)
  )

(defun print-webots-header (&optional (strm t) (model-name "HRP1"))
  (format strm "{
  Robot {
    translation IS translation
    rotation IS rotation
    controller IS controller
    controllerArgs IS controllerArgs
    customData IS customData
    supervisor IS supervisor
    synchronization IS synchronization
    selfCollision IS selfCollision
#    children [
")
  )

(defun print-webots-footer (&optional (strm t))
  (format strm "} # Robot
} # END of proto~%")
  )

(defun print-hanim-proto (&optional (strm t) (mode :openhrp2))
  (format strm "PROTO Joint [~%")
  (format strm " exposedField     SFVec3f      center              0 0 0~%")
  (format strm " exposedField     MFNode       children            []~%")
  (format strm " exposedField     MFFloat      llimit              []~%")
  (format strm " exposedField     MFFloat      lvlimit             []~%")
  (format strm " exposedField     SFRotation   limitOrientation    0 0 1 0~%")
  (format strm " exposedField     SFString     name                \"\"~%")
  (format strm " exposedField     SFRotation   rotation            0 0 1 0~%")
  (format strm " exposedField     SFVec3f      scale               1 1 1~%")
  (format strm " exposedField     SFRotation   scaleOrientation    0 0 1 0~%")
  (format strm " exposedField     MFFloat      stiffness           [ 0 0 0 ]~%")
  (format strm " exposedField     SFVec3f      translation         0 0 0~%")
  (format strm " exposedField     MFFloat      ulimit              []~%")

  (format strm " exposedField     MFFloat      climit              []~%")
  (format strm " exposedField     MFFloat      uvlimit             []~%")

  (format strm " exposedField     MFFloat      dh                  [0 0 0 0]~%")
  (format strm " exposedField     SFString     jointType           \"\"~%")
  (format strm " exposedField     SFInt32      jointId             -1~%")

  (case mode
	(:openhrp2 (format strm " exposedField     SFString     jointAxis           \"Z\"~%"))
	(:openhrp3 (format strm " exposedField     SFVec3f     jointAxis           0 0 1~%")))

  (format strm " exposedField     SFFloat      gearRatio     1~%")
  (format strm " exposedField     SFFloat      rotorInertia  0~%")
  (format strm " exposedField     SFFloat      rotorResistor 0~%")
  (format strm " exposedField     SFFloat      torqueConst   1~%")
  (format strm " exposedField     SFFloat      encoderPulse  1~%")

  (format strm "]~%")
  (format strm "{~%")
  (format strm "   Transform {~%")
  (format strm "      center           IS center~%")
  (format strm "      children         IS children~%")
  (format strm "      rotation         IS rotation~%")
  (format strm "      scale            IS scale~%")
  (format strm "      scaleOrientation IS scaleOrientation~%")
  (format strm "      translation      IS translation~%")
  (format strm "   }~%")
  (format strm "}~%")
  (format strm "~%")
  (format strm "PROTO Segment [~%")
  (format strm " field           SFVec3f     bboxCenter        0 0 0~%")
  (format strm " field           SFVec3f     bboxSize          -1 -1 -1~%")
  (format strm " exposedField    SFVec3f     centerOfMass      0 0 0~%")
  (format strm " exposedField    MFNode      children          [ ]~%")
  (format strm " exposedField    SFNode      coord             NULL~%")
  (format strm " exposedField    MFNode      displacers        [ ]~%")
  (format strm " exposedField    SFFloat     mass              0~%")
  (format strm " exposedField    MFFloat     momentsOfInertia  [ 0 0 0 0 0 0 0 0 0 ]~%")
  (format strm " exposedField    SFString    name              \"\"~%")
  (format strm " eventIn         MFNode      addChildren~%")
  (format strm " eventIn         MFNode      removeChildren~%")
  (format strm "]~%")
  (format strm "{~%")
  (format strm "   Group {~%")
  (format strm "      addChildren    IS addChildren~%")
  (format strm "      bboxCenter     IS bboxCenter~%")
  (format strm "      bboxSize       IS bboxSize~%")
  (format strm "      children       IS children~%")
  (format strm "      removeChildren IS removeChildren~%")
  (format strm "   }~%")
  (format strm "}~%")
  (format strm "~%")
  (format strm "PROTO Surface [~%")
  (format strm " field           SFVec3f     bboxCenter        0 0 0~%")
  (format strm " field           SFVec3f     bboxSize          -1 -1 -1~%")
  (format strm " exposedField    MFNode      visual            [ ]~%")
  (format strm " exposedField    MFNode      collision         [ ]~%")
  (format strm " eventIn         MFNode      addChildren~%")
  (format strm " eventIn         MFNode      removeChildren~%")
  (format strm "]~%")
  (format strm "{~%")
  (format strm "   Group {~%")
  (format strm "      addChildren    IS addChildren~%")
  (format strm "      bboxCenter     IS bboxCenter~%")
  (format strm "      bboxSize       IS bboxSize~%")
  (format strm "      children       IS visual~%")
  (format strm "      removeChildren IS removeChildren~%")
  (format strm "   }~%")
  (format strm "}~%")
  (format strm "~%")
  (format strm "~%")
  (format strm "PROTO Humanoid [~%")
  (format strm " field           SFVec3f    bboxCenter            0 0 0~%")
  (format strm " field           SFVec3f    bboxSize              -1 -1 -1~%")
  (format strm " exposedField    SFVec3f    center                0 0 0~%")
  (format strm " exposedField    MFNode     humanoidBody          [ ]~%")
  (format strm " exposedField    MFString   info                  [ ]~%")
  (format strm " exposedField    MFNode     joints                [ ]~%")
  (format strm " exposedField    SFString   name                  \"\"~%")
  (format strm " exposedField    SFRotation rotation              0 0 1 0~%")
  (format strm " exposedField    SFVec3f    scale                 1 1 1~%")
  (format strm " exposedField    SFRotation scaleOrientation      0 0 1 0~%")
  (format strm " exposedField    MFNode     segments              [ ]~%")
  (format strm " exposedField    MFNode     sites                 [ ]~%")
  (format strm " exposedField    SFVec3f    translation           0 0 0~%")
  (format strm " exposedField    SFString   version               \"1.1\"~%")
  (format strm " exposedField    MFNode     viewpoints            [ ]~%")
  (format strm "]~%")
  (format strm "{~%")
  (format strm "   Transform {~%")
  (format strm "      bboxCenter       IS bboxCenter~%")
  (format strm "      bboxSize         IS bboxSize~%")
  (format strm "      center           IS center~%")
  (format strm "      rotation         IS rotation~%")
  (format strm "      scale            IS scale~%")
  (format strm "      scaleOrientation IS scaleOrientation~%")
  (format strm "      translation      IS translation~%")
  (format strm "      children [~%")
  (format strm "         Group {~%")
  (format strm "            children IS viewpoints~%")
  (format strm "         }~%")
  (format strm "         Group {~%")
  (format strm "            children IS humanoidBody~%")
  (format strm "         }~%")
  (format strm "      ]~%")
  (format strm "   }~%")
  (format strm "}~%")
  (format strm "~%")
  (format strm "~%")
  (format strm "PROTO VisionSensor [~%")
  (format strm "  exposedField SFVec3f    translation       0 0 0~%")
  (format strm "  exposedField SFRotation rotation              0 0 1 0~%")
  (format strm "  #exposedField SFRotation orientation       0 0 1 0~%")
  (format strm "  exposedField SFFloat    fieldOfView       0.785398~%")
  (format strm "  exposedField SFString   name              \"\"~%")
  (format strm "  exposedField SFFloat    frontClipDistance 0.01~%")
  (format strm "  exposedField SFFloat    backClipDistance  10.0~%")
  (format strm "  exposedField SFString   type              \"NONE\"~%")
  (format strm "  exposedField SFInt32    sensorId          -1~%")
  (format strm "  exposedField SFInt32    width             320  # ~%")
  (format strm "  exposedField SFInt32    height            240  # ~%")
  (format strm "  exposedField SFFloat    frameRate         30  ~%")
  (format strm "  exposedField MFNode     children            [] # for me~%")
  (format strm "]~%")
  (format strm "{~%")
  (format strm "  Transform {~%")
  (format strm "    rotation         IS rotation~%")
  (format strm "    translation      IS translation~%")
  (format strm "    children IS children # for me~%")
  (format strm "  }~%")
  (format strm "}~%")
  (format strm "~%")
  (format strm "~%")
  (format strm "PROTO ForceSensor [~%")
  (format strm "  exposedField SFVec3f maxForce -1 -1 -1~%")
  (format strm "  exposedField SFVec3f maxTorque -1 -1 -1~%")
  (format strm "  exposedField SFVec3f translation 0 0 0~%")
  (format strm "  exposedField SFRotation rotation 0 0 1 0~%")
  (format strm "  exposedField SFInt32 sensorId -1~%")
  (format strm "]~%")
  (format strm "{~%")
  (format strm "  Transform {~%")
  (format strm "translation IS translation~%")
  (format strm "    rotation IS rotation~%")
  (format strm "  }~%")
  (format strm "}~%")
  (format strm "~%")
  (format strm "PROTO Gyro [~%")
  (format strm "  exposedField SFVec3f maxAngularVelocity -1 -1 -1~%")
  (format strm "  exposedField SFVec3f translation 0 0 0~%")
  (format strm "  exposedField SFRotation rotation 0 0 1 0~%")
  (format strm "  exposedField SFInt32 sensorId -1~%")
  (format strm "]~%")
  (format strm "{~%")
  (format strm "  Transform {~%")
  (format strm "    translation IS translation~%")
  (format strm "    rotation IS rotation~%")
  (format strm "  }~%")
  (format strm "}~%")
  (format strm "~%")
  (format strm "PROTO AccelerationSensor [~%")
  (format strm "  exposedField SFVec3f maxAcceleration -1 -1 -1~%")
  (format strm "  exposedField SFVec3f translation 0 0 0~%")
  (format strm "  exposedField SFRotation rotation 0 0 1 0~%")
  (format strm "  exposedField SFInt32 sensorId -1~%")
  (format strm "]~%")
  (format strm "{~%")
  (format strm "  Transform {~%")
  (format strm "    translation IS translation~%")
  (format strm "    rotation IS rotation~%")
  (format strm "  }~%")
  (format strm "}~%")
  (format strm "~%")
  (format strm "PROTO PressureSensor [~%")
  (format strm "  exposedField SFFloat maxPressure -1~%")
  (format strm "  exposedField SFVec3f translation 0 0 0~%")
  (format strm "  exposedField SFRotation rotation 0 0 1 0~%")
  (format strm "  exposedField SFInt32 sensorId -1~%")
  (format strm "]~%")
  (format strm "{~%")
  (format strm "  Transform {~%")
  (format strm "    translation IS translation~%")
  (format strm "    rotation IS rotation~%")
  (format strm "  }~%")
  (format strm "}~%")
  (format strm "~%")
  (format strm "PROTO ProximitySensor [~%")
  (format strm "  exposedField SFFloat maxProximity -1~%")
  (format strm "  exposedField SFVec3f translation 0 0 0~%")
  (format strm "  exposedField SFRotation rotation 0 0 1 0~%")
  (format strm "  exposedField SFInt32 sensorId -1~%")
  (format strm "]~%")
  (format strm "{~%")
  (format strm "  Transform {~%")
  (format strm "    translation IS translation~%")
  (format strm "    rotation IS rotation~%")
  (format strm "  }~%")
  (format strm "}~%")
  (format strm "~%")

  (format strm "~%")
  )

(defun print-hanim-header (&optional (strm t) (model-name "HRP1"))
  (format strm "DEF ~A Humanoid {~%" model-name)
  (format strm "humanoidBody [~%")
  )

(defun print-hanim-footer (scene &optional (strm t))
  (format strm "] # END of HumanoidBody~%")
  (format strm "~%")
  (when
      (find-method scene :links)
    (format strm "joints [~%")
    (cond
     ((derivedp scene cascaded-link)
      (let ((ls (send scene :links)) l)
	(while ls
	  (setq l (pop ls))
	  (format strm "  USE ~A"
		  (if (send l :joint) (send (send l :joint) :name) "WAIST"))
	  (if ls (format strm ",~%") (format strm "~%")))))
     ((derivedp scene bodyset-link)
      (format strm "  USE ~A~%]~%" (send scene :name))
      )
     )
    (format strm " ]~%")
    (format strm "segments [~%")
    (cond
     ((derivedp scene cascaded-link)
      (let ((ls (send scene :links)) l)
	(while ls
	  (setq l (pop ls))
	  (format strm "  USE ~A" (string (send l :name)))
	  (if ls (format strm ",~%") (format strm "~%")))))
     ((derivedp scene bodyset-link)
      (format strm "  USE ~A~%]~%" (send scene :name)))
     )
    (format strm " ]~%"))
  (format strm "}~%")
  )

(defun print-hrp-setting (&optional (strm t))
  (format strm "NavigationInfo {~%")
  (format strm "avatarSize    0.5~%")
  (format strm "headlight     TRUE~%")
  (format strm "type  [\"EXAMINE\", \"ANY\"]~%")
  (format strm "}~%")
  (format strm "Viewpoint {~%")
  (format strm "position    3 0 0.835~%")
  (format strm "orientation 0.5770 0.5775 0.5775 2.0935~%")
  (format strm "}~%")
  )

;;;	tessel
(defun eus2iv-tessel-aux (f)
  (cond
   ((= (length (send f :edges)) 3) (list f))
   (t (eus2iv-tessel-divide-triangle f))))

(defun eus2iv-tessel-divide-triangle (f)
  (let* ((start 0) 
	 (poly (eus2iv-tessel-triangle f start)))
    (while (null poly)
      (incf start)
      (if (>= start (length (send f :vertices))) (return-from eus2iv-tessel-divide-triangle nil))
      (setq poly (eus2iv-tessel-triangle f start)))
    (cons poly 
	  (eus2iv-tessel-aux (eus2iv-tessel-rest-polygon f start)))))

;; return polygon if triangable ,unless return nil.
;; this function = sharpp + trianglable + insidep
(defun eus2iv-tessel-triangle (f num)
  (let* ((vers (send f :vertices))
	 (len (length (cdr vers)))
	 (v0 (nth (mod (1- (+ num len)) len) vers))
	 (v1 (nth (mod num len) vers))
	 (v2 (nth (mod (1+  num) len) vers)))
    (unless (> (v. (v* (v- v1 v0) (v- v2 v1)) (send f :normal)) 0)
      (return-from eus2iv-tessel-triangle nil))
    (let ((poly (instance polygon :init :vertices (list v0 v1 v2)))
	  (rvers (remove v0 (remove v1 (remove v2 vers)))))
      (if (every #'(lambda (x) (eq ':outside (send poly :insidep x))) rvers)
	  poly
	nil))))

(defun eus2iv-tessel-rest-polygon (f num)
  (let* ((vers (butlast (send f :vertices)))
	 (len (length vers))
	 (rvers (remove (nth (mod num len) vers) vers)))
    (instance polygon :init :vertices rvers)))

(defparameter *yaml-emit-offset* 0)

(defun write-string (&optional strm &rest args)
  (dotimes (i *yaml-emit-offset*) (format strm " "))
  (apply #'format strm args))

(defun yaml-emit (&optional (strm t) value (level (cnoid-offset)) &aux l (s strm))
  (when (numberp strm)
    (setq level strm)
    (setq strm (make-string-output-stream 100)))
  (cnoid-offset level)
  (cond
   ((null value)
    (write-string strm "false"))
   ((eq t value)
    (write-string strm "true"))
   ((symbolp value)
    (write-string strm "~A" value))
   ((numberp value)
    (write-string strm "~A" value))
   ((stringp value)
    (write-string strm "~A" value))
   ((derivedp value yaml-cons)
    (cond
     ((not (atom (cdr value)))
      (write-string strm "~A: ~%" (car value))
      (cnoid-offset (+ (cnoid-offset) 2)))
     (t (write-string strm "~A: " (car value))))
    (if (string-equal (car value) "children")
	(cnoid-offset (+ (cnoid-offset) 2)))
    (yaml-emit strm (cdr value) (cnoid-offset))
    (if (string-equal (car value) "children")
	(cnoid-offset (- (cnoid-offset) 2)))
    (cond
     ((not (atom (cdr value)))
      (cnoid-offset (- (cnoid-offset) 2)))
     (t (write-string strm "~%"))))
   ((consp value)
    (let ((o (cnoid-offset)))
      (dolist (l value)
	(yaml-emit strm l (+ o 2)))))
   ((or (derivedp value yaml-vector) (float-vector-p value))
    (let ((offset *yaml-emit-offset*))
      (setq *yaml-emit-offset* 0)
      (write-string strm "[ ")
      (when (> (length value) 0)
	(dotimes (i (1- (length value)))
	  (yaml-emit strm (elt value i))
	  (write-string strm ", "))
	(yaml-emit strm (elt value (1- (length value)))))
      (write-string strm "]")
      (cnoid-offset offset)))
   ((vectorp value)
    (write-string strm "~%")
    (dotimes (i (length value))
      (yaml-emit strm "- " level)
      (write-string strm "~%")
      (yaml-emit strm (elt value i) (+ level 2))))
   ((matrixp value)
    (yaml-emit strm (coerce (value . entity) yaml-vector)))
   ((hash-table-p value)
    (let ((keys (send value :list-keys)))
      (write-string strm "{ ")
      (while (setq l (pop keys))
	(yaml-emit strm l)
	(write-string strm ": ")
	(yaml-emit strm (gethash l value))
	(when (cdr keys)
	  (write-string strm ", ")))
      (write-string strm " }~%"))))
  (cond
   ((numberp s)
    (cnoid-offset s)
    (get-output-stream-string strm))
   (t
    (cnoid-offset (- (cnoid-offset) level))
    strm)))

(defparameter *cnoid-id* -1)
(defun cnoid-id (&optional (num (1+ *cnoid-id*)))
  (setq *cnoid-id* num)
  *cnoid-id*)

(defun cnoid-offset (&optional n)
  (if (null n) (setq n *yaml-emit-offset*))
  (setq *yaml-emit-offset* n))

(defclass yaml-vector :super vector :slots nil)
(defmethod yaml-vector
  (:init (&rest args)
	 (send-super* :init args)
	 self)
  )
(defclass yaml-cons :super cons :slots nil)
(defmethod yaml-cons
  (:init (&rest args)
	 (send-super* :init args)
	 self)
  )

(defun yaml-vector (&rest vlist)
  (let* ((size (length vlist)) (vec (instantiate yaml-vector size)) (i 0))
    (while (< i size) (setf (aref vec i) (pop vlist)) (inc i)) vec))
(defun yaml-cons (a b)
  (let ((h (instantiate yaml-cons)))
    (setq (h . car) a (h . cdr) b)
    h))

(defun eus2cnoid (robo &optional (name (send robo :name)))
  (mkdir-unless "cnoids")
  (with-open-file
   (strm (format nil "cnoids/~A-gen.cnoid" name) :direction :output)
   (format strm "#~%# this file is automatically generated by eus2cnoid for ~A robot simulation~%#~%" name)
   (cnoid-id -1)
   (cnoid-offset 0)
   (format
    strm
    (yaml-emit
     0
     (yaml-cons
      "items"
      (list
       (yaml-cons "id" (cnoid-id))
       (yaml-cons "name" "\"Root\"")
       (yaml-cons "plugin" "Base")
       (yaml-cons "class" "RootItem")
       (yaml-cons
	"children"
	(yaml-emit
	 6
	 (vector 
	  (list
	   (yaml-cons "id" (cnoid-id))
	   (yaml-cons "name" "\"World\"")
	   (yaml-cons "plugin" "Body")
	   (yaml-cons "class" "WorldItem")
	   (yaml-cons
	    "data"
	    (list
	     (yaml-cons "collisionDetection" "false")
	     (yaml-cons "collisionDetector" "AISTCollisionDetector")
	     (yaml-cons "materialTableFile" "\"${SHARE}/default/materials.yaml\"")))
	   (yaml-cons
	    "children"
	    (vector
	     (list
	      (yaml-cons "id" (cnoid-id))
	      (yaml-cons "name" "\"AISTSimulator\"")
	      (yaml-cons "plugin" "Body")
	      (yaml-cons "class" "AISTSimulatorItem")
	      (yaml-cons
	       "data"
	       (list
		(yaml-cons "timeStep" 0.001)
		(yaml-cons "realtimeSync" "true")
		(yaml-cons "recording" "full")
		(yaml-cons "timeRangeMode" "Unlimited")
		(yaml-cons "timeLength" 180)
		(yaml-cons "allLinkPositionOutputMode" "true")
		(yaml-cons "deviceStateOutput" "true")
		(yaml-cons "controllerThreads" "true")
		(yaml-cons "recordCollisionData" "false")
		(yaml-cons "controllerOptions" "\"\"")
		(yaml-cons "dynamicsMode" "\"Forward dynamics\"")
		(yaml-cons "integrationMode" "\"Runge Kutta\"")
		(yaml-cons "gravity" (yaml-vector  0 0 -9.80665))
		(yaml-cons "staticFriction" 1)
		(yaml-cons "dynamicFriction" 1)
		(yaml-cons "cullingThresh" 0.005)
		(yaml-cons "contactCullingDepth" 0.05)
		(yaml-cons "errorCriterion" 0.001)
		(yaml-cons "maxNumIterations" 1000)
		(yaml-cons "contactCorrectionDepth" 0.0001)
		(yaml-cons "contactCorrectionVelocityRatio" 1)
		(yaml-cons "kinematicWalking" "false")
		(yaml-cons "2Dmode" "false")
		(yaml-cons "oldAccelSensorMode" "false"))))
	     (list
	      (yaml-cons "id" (cnoid-id))
	      (yaml-cons "name" "\"Floor\"")
	      (yaml-cons "plugin" "Body")
	      (yaml-cons "class" "BodyItem")
	      (yaml-cons
	       "data"
	       (list
		(yaml-cons "modelFile" "\"${SHARE}/model/misc/floor.body\"")
		(yaml-cons "currentBaseLink" "\"Floor\"")
		(yaml-cons "rootPosition" (yaml-vector 0 0 -0.1))
		(yaml-cons "rootAttitude" (unit-matrix 3))
		(yaml-cons "jointPositions" (yaml-vector))
		(yaml-cons "initialRootPosition" (yaml-vector 0 0 -0.1))
		(yaml-cons "initialRootAttitude" (unit-matrix 3))
		(yaml-cons "zmp" (yaml-vector 0 0 0))
		(yaml-cons "collisionDetection" "true")
		(yaml-cons "selfCollisionDetection" "false")
		(yaml-cons "isEditable" "false"))))
	     (cnoid-robot-node robo (cnoid-id))
	     ))))))))))
   (cnoid-id -1)
   (yaml-emit
    strm
    (yaml-cons
     "views"
     (vector       
      (list 
       (yaml-cons "id" (cnoid-id))
       (yaml-cons "plugin" "\"Base\"")
       (yaml-cons "class" "ItemPropertyView")
       (yaml-cons "mounted" "true"))
      (list
       (yaml-cons "id" (cnoid-id))
       (yaml-cons "plugin" "\"Base\"")
       (yaml-cons "class" "ItemTreeView")
       (yaml-cons "mounted" "true")
       (yaml-cons "state"
		  (list
		   (yaml-cons "selected" (yaml-vector 4))
		   (yaml-cons "checked" (yaml-vector 1 2 3 4 5 6 7 8 9))
		   (yaml-cons "expanded" (yaml-vector 1 4)))))
      (list
       (yaml-cons "id" (cnoid-id))
       (yaml-cons "plugin" "\"Base\"")
       (yaml-cons "class" "MessageView")
       (yaml-cons "mounted" "true"))
      (list
       (yaml-cons "id" (cnoid-id))
       (yaml-cons "plugin" "Base")
       (yaml-cons "class" "ScreenView")
       (yaml-cons "mounted" "true")
       (yaml-cons
	"state"
	(list
	 (yaml-cons "editMode" "false")
	 (yaml-cons "viewpointControlMode" "thirdPerson")
	 (yaml-cons "collisionLines" "false")
	 (yaml-cons "polygonMode" "fill")
	 (yaml-cons "cullingMode" "enabled")
	 (yaml-cons "defaultHeadLight" "true")
	 (yaml-cons "defaultHeadLightIntensity" 0.75)
	 (yaml-cons "headLightLightingFromBack" "false")
	 (yaml-cons "worldLight" "true")
	 (yaml-cons "worldLightIntensity" 0.5)
	 (yaml-cons "worldLightAmbient" 0.3)
	 (yaml-cons "additionalLights" "true")
	 (yaml-cons "fog" "true")
	 (yaml-cons "floorGrid" "true")
	 (yaml-cons "floorGridSpan" 10)
	 (yaml-cons "floorGridInterval" 0.5)
	 (yaml-cons "xzGridSpan" 10)
	 (yaml-cons "xzGridInterval" 0.5)
	 (yaml-cons "xzGrid" "false")
	 (yaml-cons "yzGridSpan" 10)
	 (yaml-cons "yzGridInterval" 0.5)
	 (yaml-cons "texture" "true")
	 (yaml-cons "lineWidth" 1)
	 (yaml-cons "pointSize" 1)
	 (yaml-cons "normalVisualization" "false")
	 (yaml-cons "normalLength" 0.01)
	 (yaml-cons "coordinateAxes" "true")
	 (yaml-cons "fpsTestIteration" 1)
	 (yaml-cons "showFPS" "false")
	 (yaml-cons "enableNewDisplayListDoubleRendering" "false")
	 (yaml-cons "useBufferForPicking" "true")
	 (yaml-cons "upsideDown" "false")
	 (yaml-cons
	  "cameras" 
	  (vector
	   (list
	    (yaml-cons "camera" (yaml-vector "System" "Perspective"))
	    (yaml-cons "isCurrent" "true")
	    (yaml-cons "fieldOfView" 0.698132)
	    (yaml-cons "near" 0.04)
	    (yaml-cons "far" 200)
	    (yaml-cons "eye" (yaml-vector 2 1 1.0))
	    (yaml-cons "direction" (float-vector -0.888888889 -0.444444444 -0.111111111))
	    (yaml-cons "up" (float-vector -0.0993807989 -0.0496903995 0.99380799)))
	   (list
	    (yaml-cons "camera" (yaml-vector "System" "Orthographic"))
	    (yaml-cons "orthoHeight" 20)
	    (yaml-cons "near" 0.04)
	    (yaml-cons "far" 200)
	    (yaml-cons "backgroundColor" (float-vector 0.100000001 0.100000001 0.300000012))
	    (yaml-cons "gridColor" (float-vector 0.899999976 0.899999976 0.899999976 1))
	    (yaml-cons "xzgridColor" (float-vector 0.899999976 0.899999976 0.899999976 1))
	    (yaml-cons "yzgridColor" (float-vector 0.899999976 0.899999976 0.899999976 1))
	    (yaml-cons "dedicatedItemTreeViewChecks" "false")))))))))
    ))
  )

(defun cnoid-robot-node (robo id &optional (scale 0.001))
  (list
   (yaml-cons "id" id)
   (yaml-cons "name" (format nil "~S" (send robo :name)))
   (yaml-cons "plugin" "Body")
   (yaml-cons "class" "BodyItem")
   (yaml-cons
    "data"
    (list
     (yaml-cons "modelFile" "\"${PROJECT_DIR}/../wrls/kxrl2w2l5a4.wrl\"")
     (yaml-cons "currentBaseLink" "\"WAIST\"")
     (yaml-cons "rootPosition" (scale scale (send robo :worldpos)))
     (yaml-cons "rootAttitude" (unit-matrix 3))
     (yaml-cons "jointPositions" (scale (/ pi 360.0) (send robo :angle-vector)))
     (yaml-cons "initialRootPosition" (scale scale (send robo :worldpos)))
     (yaml-cons "initialRootAttitude" (unit-matrix 3))
     (yaml-cons "initialJointPositions" (scale (/ pi 360.0) (send robo :neutral)))
     (yaml-cons "zmp" (yaml-vector 0 0 0))
     (yaml-cons "collisionDetection" "true")
     (yaml-cons "selfCollisionDetection" "false")
     (yaml-cons "isEditable" "true")
     (yaml-cons
      "children"
      (vector
       (list
	(yaml-cons "id" (1+ id))
	(yaml-cons "name" "\"BodyPublisher\"")
	(yaml-cons "plugin" "ROS")
	(yaml-cons "class" "BodyPublisherItem")
	(yaml-cons
	 "data"
	 (list
	  (yaml-cons "isNoDelayMode" "false")
	  (yaml-cons "controllerOptions"
		     "\"HEAD_JOINT0:50:0:0.5 HEAD_JOINT1:50:0:0.5 RARM_JOINT0:100:0:1 RARM_JOINT1:100:0:1 RARM_JOINT2:100:0:1 RARM_JOINT3:100:0:1 RARM_JOINT4:100:0:1 RARM_JOINT5:50:0:0.5 LARM_JOINT0:100:0:1 LARM_JOINT1:100:0:1 LARM_JOINT2:100:0:1 LARM_JOINT3:100:0:1 LARM_JOINT4:100:0:1 LARM_JOINT5:50:0:0.5 RLEG_JOINT0:100:0:1 RLEG_JOINT1:100:0:1 RLEG_JOINT2:100:0:1 RLEG_JOINT3:100:0:1 RLEG_JOINT5:100:0:1 LLEG_JOINT0:100:0:1 LLEG_JOINT1:100:0:1 LLEG_JOINT2:100:0:1 LLEG_JOINT3:100:0:1 LLEG_JOINT5:100:0:1\"")
	  (yaml-cons "maxPublishRate" 30))))
       (list
	(yaml-cons "id" (+ id 2))
	(yaml-cons "name" "\"SimpleController\"")
	(yaml-cons "plugin" "Body")
	(yaml-cons "class" "SimpleControllerItem")
	(yaml-cons
	 "data"
	 (list
	  (yaml-cons "isNoDelayMode" "false")
	  (yaml-cons "controllerOptions"
		     "\"gyro:gyrometer accel:gsensor body:WAIST wheel_l:LLEG_JOINT4 wheel_r:RLEG_JOINT4\"")
	  (yaml-cons "controller" "\"${PROJECT_DIR}/InvPendulumController.so\"")
	  (yaml-cons "reloading" "false")
	  (yaml-cons "isOldTargetVariableMode" "false")))))))))
  )

(defun kxr2urdf-old (name &key (wrl (format nil "wrls/~A.wrl" name))
			    (daes-dir "daes")
			    (dae (format nil "~A/~A.dae" daes-dir name))
			    (actuator-joint-check t) (joint-numbered-name t)
			    (package-dir "kxr_controller/urdf")
			    (robo (kxr-make-robot name)))
  (mkdir-unless "wrls")
  (send robo :neutral)
  (eus2wrl robo wrl :mode :openhrp3 :actuator-joint-check actuator-joint-check
	   :joint-numbered-name joint-numbered-name)
  (export-collada wrl dae)
  (collada2urdf name :package-dir package-dir)
  )

#+:ros
(defun kxr2urdf (name &key (wrl (format nil "wrls/~A.wrl" name))
			(dae (format nil "daes/~A.dae" name))
			(actuator-joint-check t) (joint-numbered-name t)
			(robo (kxr-make-robot name)))
  (load "package://eusurdf/euslisp/convert-eus-to-urdf.l")
  (send robo :neutral)
  
  )

(defun collada2urdf (name &key (daes-dir "daes")
			  (urdf-dir (format nil "urdfs/~A/urdf" name))
			  (package-dir "package:/") ;;(package-dir "package://kxr_models")
			  (mesh-dir (format nil "urdfs/~A/meshes" name))
			  (mesh-prefix (format nil "~A/~A/meshes" package-dir name)))
  (mkdir-unless "urdfs")
  (mkdir-unless (format nil "urdfs/~A" name))
  (mkdir-unless urdf-dir)
  (mkdir-unless mesh-dir)
  (let ((euscollada-dir (read-line (piped-fork "rospack find euscollada") nil nil))
	(kxr_models-dir (read-line (piped-fork "rospack find kxr_models") nil nil))
        (collada-to-urdf-pkg "collada_urdf"))
    ;; if collada_to_urdf exist at euscollada, you will use it.
    (cond
     ((and euscollada-dir
	   (probe-file (format nil "~A/scripts/collada_to_urdf" euscollada-dir)))
      (setq collada-to-urdf-pkg "euscollada")
      (system-format
       "rosrun ~A collada_to_urdf ~A/~A.dae -O ~A/~A.urdf --mesh_output_dir ~A --mesh_prefix ~A"
       collada-to-urdf-pkg daes-dir name urdf-dir name mesh-dir mesh-prefix))
     (t
      (system-format
       "rosrun collada_urdf collada_to_urdf ~A/~A.dae -O ~A/~A.urdf --mesh_output_dir ~A --mesh_prefix ~A"
       daes-dir name urdf-dir name mesh-dir mesh-prefix)
      ))
    (with-open-file
     (f (format nil "urdfs/~A/package.xml" name) :direction :output)
     (package-xml name f))
    (with-open-file
     (f (format nil "urdfs/~A/CMakeLists.txt" name) :direction :output)
     (cmakelists-txt name f))
    (mkdir-unless (format nil "urdfs/~A/launch" name)) 
    (with-open-file
     (f (format nil "urdfs/~A/launch/display.launch" name) :direction :output)
     (display-launch name f))
    ;;(with-open-file
    ;;(f (format nil "urdfs/~A/urdf.rviz" name) :direction :output)
    ;;(rviz-config f))
    (when kxr_models-dir
      (system-format
       "cd ~A; ln -s ~A/meshes/~A meshes; ln -s ~A/urdf/~A.urdf urdf"
       kxr_models-dir *rcb4eus-dir* name *rcb4eus-dir* name))
    ))

(defun cmakelists-txt (name &optional (strm t))
  (format
   strm
   "
cmake_minimum_required(VERSION 2.8.3)
project(~A)
find_package(catkin REQUIRED)
catkin_package()
find_package(roslaunch)
foreach(dir config launch meshes urdf)
	install(DIRECTORY ${dir}/
		DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/${dir})
endforeach(dir)
"
   name)
  )

(defun display-launch (name &optional (strm t))
  (format
   strm
   "
<launch>
  <arg name=\"model\" />
  <param name=\"robot_description\" textfile=\"$(find ~A)/urdf/~A.urdf\" />
  <node name=\"joint_state_publisher_gui\" pkg=\"joint_state_publisher_gui\" type=\"joint_state_publisher_gui\" />
  <node name=\"robot_state_publisher\" pkg=\"robot_state_publisher\" type=\"robot_state_publisher\" />
  <node name=\"rviz\" pkg=\"rviz\" type=\"rviz\" args=\"-d $(find ~A)/urdf.rviz\" />
</launch>
"
   name name name)
  )

(defun package-xml (name strm)
  (format
   strm
   "
<package format=\"2\">
  <name>~A</name>
  <version>1.0.0</version>
  <description>
    <p>URDF Description package for ~A</p>
  </description>
  <maintainer email=\"euslisp@jsk.t.u-tokyo.ac.jp\">Euslisp developer</maintainer>
  <license>Euslisp</license>
  <buildtool_depend>catkin</buildtool_depend>
  <depend>roslaunch</depend>
  <depend>robot_state_publisher</depend>
  <depend>rviz</depend>
  <depend>joint_state_publisher_gui</depend>
  <export>
    <architecture_independent />
  </export>
</package>
"
   name name)
  )



(defun param-split (str &optional (delim '(#\Space #\Tab 10 13)))
  (let (ret sub c in-str)
    (with-input-from-string (s str)
      (while t
	(cond
	  ((null (setq c (read-char s nil)))
	   (unless (null sub)
	     (push (coerce (reverse sub) string) ret))
	   (return-from param-split (reverse ret)))
	  ((eq c #\")
	   (if sub
	       (push (coerce (reverse sub) string) ret))
	   (setq sub nil)
	   (setq in-str (null in-str)))
	  ((memq c delim)
	   (if in-str
	       (push c sub)
	       (progn
		 (if sub
		     (push (coerce (reverse sub) string) ret))
		 (setq sub nil))))
	  (t (push c sub)))))))
#|
(unless (find-package "XMLNS")
  (make-package "XMLNS"))
(in-package "XMLNS")
(export 'xi=)
(in-package "USER")
|#
(defun surdf-data (urdf str)
  (mapcan
   #'(lambda (x)
       (when (listp (car x))
	 (if (substringp str (caar x))
	     (list (str2list x)))))
   (car (get-tag-data "robot" urdf)))
  )
(defun surdf-links (urdf) (surdf-data urdf "link"))
(defun surdf-joints (urdf) (surdf-data urdf "joint"))

(defun str2list-old (str)
  (let ((st (make-string-input-stream str))
	s ret)
    (while (setq s (read st nil nil)) (push s ret))
    (if (= (length ret) 1) (car ret) (reverse ret))
    ))
(defun str2list (str)
  (setq str (param-split str))
  (if (= (length str) 1) (car str) str))
(defun strlist2list (strlist)
  (cond
    ((null strlist) nil)
    ((stringp strlist) (str2list strlist))
    ((stringp (car strlist))
     (if (string= "!--" (car strlist))
	 strlist
	 (cons (str2list (car strlist)) (strlist2list (cdr strlist)))))
    (t (cons (strlist2list (car strlist))
	     (strlist2list (cdr strlist))))))

(defun urdf-robot-data (urdf)
  (car (get-tag-data "robot" urdf)))
(defun urdf-tag-name (urdf tag &optional filter)
  (let* ((r (caar (get-tag-data tag urdf)))
	 (n (assoc "name=" r :test #'equal)))
    (when n
      (if filter
	  (if (setq n (funcall filter n)) n)
	  (cadr n)))))
(defun urdf-robot-name (urdf) (urdf-tag-name urdf "robot"))
(defun urdf-links (urdf) (get-tag-data "link" urdf))
(defun urdf-joints (urdf) (get-tag-data "joint" urdf))
(defun urdf-tag-data (urdf tag &optional (filter #'identity))
  (remove-if-not filter
		 (mapcar #'car (get-tag-data tag urdf))))
(defun urdf-link-tags (urdf &optional filter)
  (urdf-tag-data urdf "link" filter))
(defun urdf-joint-tags (urdf &optional filter)
  (urdf-tag-data urdf "joint" filter))
(defun urdf-rotation-joints (urdf &optional (joint-subname ""))
  (urdf-tag-data urdf "joint"
		 #'(lambda (x)
		     (let* ((alist (plist-to-alist (cadr x)))
			    (name (cadr (assoc "name=" alist :test #'equal))))
		       (and
			(substringp joint-subname name)
			(not (equal "-w" (subseq name (- (length name) 2))))
			(assoc "type=" alist :test #'equal)
			(not (equal "fixed" (cadr (assoc "type=" alist :test #'equal))))
			)))))
(defun urdf-wheel-joints (urdf &optional (substr ""))
  (urdf-tag-data urdf "joint"
		 #'(lambda (x)
		     (let* ((alist (plist-to-alist (cadr x)))
			    (name (cadr (assoc "name=" alist :test #'equal))))
		       (and
			(substringp substr name)
			(equal "-w" (subseq name (- (length name) 2)))
			(not (equal "fixed" (cadr (assoc "type=" alist :test #'equal))))
			)))))
(defun urdf-rotation-wheel-joints (urdf &optional (limb ""))
  (urdf-tag-data urdf 'joint
		 #'(lambda (x)
		     (let* ((alist (plist-to-alist (cadr x)))
			    (name (cadr (assoc "name=" alist :test #'equal))))
		       (and
			(substringp limb name)
			(not (equal "fixed" (cadr (assoc "type=" alist :test #'equal))))
			)))))

(defun urdf2yaml (fname  &key (wheel nil) (limbs '("head" "torso" "larm" "rarm" "lleg" "rleg")) joint-subname)
  (mkdir-unless "yamls")
  (let* ((ufname (format nil "urdf/~A.urdf" fname))
	 (yfname (format nil "yamls/~A.yaml" fname))
	 (urdf (strlist2list (tiny-xml::parse ufname)))
	 js n (len 0))
    (cond (wheel (format *error-output* ";; robot with wheel joint~%"))
	  (t (format *error-output* ";; robot without wheel joint~%"))
	  )
    (with-open-file
	(strm yfname :direction :output)
      (format strm "#~%# this file is automatically generated by urdf2yaml ~A robot~%#~%" fname)
      (dolist (lim limbs)
	(cond (wheel (setq js (urdf-rotation-wheel-joints urdf lim)))
	      ((not wheel) (setq js (urdf-rotation-joints urdf lim)))
	      )
	(when js
	  (setq len (+ len (length js)))
	  (format strm "~A:~%" lim)
	  (dolist (j js)
	    (when (setq n (assoc "name=" j :test #'equal))
	      (format strm " - ~A : ~A~%" (cadr n) (cadr n))
	      ))))
      (format strm "~%angle-vector:~% neutral: [~%")
      (dotimes (i (1- len)) (format strm "0.0, "))
      (format strm "0.0]~%")
      )
    ))

(defun urdf2part (fname)
  (let* ((ufname (format nil "urdf/~A.urdf" fname))
	 (urdf (strlist2list (tiny-xml::parse ufname)))
	 )
    urdf))

(defun urdf2collada (fname)
  (mkdir-unless "daes")
  (system-format
   "rosrun collada_urdf urdf_to_collada urdf/~A.urdf daes/~A.dae"
   fname fname))

(defun xacro2urdf (fname &optional (to fname) arg)
  (mkdir-unless "urdf")
  (system-format "xacro ~A/xacros/~A.xacro ~A > ~A/urdf/~A.urdf"
		 *rcb4eus-dir* fname (if arg (format nil "~A" arg) "")
		 *rcb4eus-dir* to)
  )

(defun collada2eus (fname &key
			  (dae (format nil "daes/~A.dae" fname))
			  (yaml (format nil "yamls/~A.yaml" fname))
			  (model (format nil "models/~A.l" fname)))
  (unless (read (piped-fork "bash which export-collada") nil nil)
    (system-format
     "sudo apt-get install -y ros-~A-openhrp3" (unix::getenv "ROS_DISTRO")))
  (unless (read (piped-fork "rospack find euscollada") nil nil)
    (system-format "sudo apt-get install -y ros-~A-euscollada" (unix::getenv "ROS_DISTRO")))
  (mkdir-unless "models")
  (system-format "rosrun euscollada collada2eus ~A ~A ~A" dae yaml model))

(defun urdf2collada-robot (fname &key (limbs '("head" "torso" "larm" "rarm" "lleg" "rleg"))
				   joint-subname wheel)
  (urdf2collada fname)
  (urdf2yaml fname :limbs limbs :joint-subname joint-subname :wheel wheel)
  (collada2eus fname))

(defun xacro2eus (fname &optional (to fname) &key arg (limbs '("head" "torso" "larm" "rarm" "lleg" "rleg"))
					       joint-subname)
  (xacro2urdf fname to arg)
  (urdf2collada-robot to :limbs limbs :joint-subname joint-subname))

(defun rviz-urdf (fname)
  (if (derivedp fname cascaded-link) (setq fname (send fname :name)))
  ;;(system-format "rosrun rviz rviz urdf/~A.urdf" fname)
  (system-format "roslaunch urdf_tutorial display.launch model:=urdf/~A.urdf" fname)
  fname)

(defun rviz-robot (name)
  (system-format "roslaunch kxr_models display.launch model:=~A &" name))
;;
#|
(format t "; (gen-khrh2u) ;; to generate khr with m5unitv-stereo head~%")
(format t "; (gen-khrh2u2) ;; to generate khr with m5unitv-stereo head~%")
(format t "; (gen-khrh2u3) ;; to generate khr with m5unitv-stereo + m5unitv2 head~%")
(format t "; (gen-khrh2v) ;; to generate khr with m5stickv-stereo head~%")
(format t "; (gen-khrh2v3) ;; to generate khr with m5stickv-stereo with m5unitv2 head~%")
(format t "; (khr2model \"khrh2\") ;; to generate KHR/khrh2.l from KHR/khrh2main.wrl~%")
|#
