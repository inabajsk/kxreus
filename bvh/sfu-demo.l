;;;
;;; Mocap data from https://mocap.cs.sfu.cas/
;;;
(require :rcb4robots)

(defun sfu-bvh2eus (fname &rest args &key (scale 10) ((:objects obj) nil))
  (apply #'bvh2eus fname :scale scale :objects obj
	 :bvh-robot-model-class sfu-bvh-robot-model args))

(defclass sfu-bvh-robot-model
  :super bvh-robot-model
  :slots ())
(defmethod sfu-bvh-robot-model
    (:init (&rest args)
	      (send-super* :init :coords (make-coords :rpy (float-vector pi/2 0 pi/2)) args)
	      (setq larm (list
			  (find 'leftshoulder  links :key #'(lambda (x) (send x :name)))
			  (find 'leftarm       links :key #'(lambda (x) (send x :name)))
			  (find 'leftforearm   links :key #'(lambda (x) (send x :name)))
			  (find 'lefthand      links :key #'(lambda (x) (send x :name)))
			  (find 'lefthandthumb       links :key #'(lambda (x) (send x :name))))
		    rarm (list
			  (find 'rightshoulder links :key #'(lambda (x) (send x :name)))
			  (find 'rightarm      links :key #'(lambda (x) (send x :name)))
			  (find 'rightforearm  links :key #'(lambda (x) (send x :name)))
			  (find 'righthand     links :key #'(lambda (x) (send x :name)))
			  (find 'righthandthumb links :key #'(lambda (x) (send x :name))))
		    lleg (list
			  (find 'leftupleg     links :key #'(lambda (x) (send x :name)))
			  (find 'leftleg	    links :key #'(lambda (x) (send x :name)))
			  (find 'leftfoot      links :key #'(lambda (x) (send x :name)))
			  (find 'lefttoebase   links :key #'(lambda (x) (send x :name)))
			  )
		    rleg (list
			  (find 'rightupleg    links :key #'(lambda (x) (send x :name)))
			  (find 'rightleg	    links :key #'(lambda (x) (send x :name)))
			  (find 'rightfoot     links :key #'(lambda (x) (send x :name)))
			  (find 'righttoebase  links :key #'(lambda (x) (send x :name))))
		    torso (list
			   (find 'spine    links :key #'(lambda (x) (send x :name)))
			   (find 'spine1        links :key #'(lambda (x) (send x :name))))
		    head  (list
			   (find 'neck        links :key #'(lambda (x) (send x :name)))
			   (find 'head        links :key #'(lambda (x) (send x :name)))))
	      ;;
	      (send self :init-end-coords)
	      (send self :init-root-link)
	      self) ;; init
  (:larm-shoulder (&rest args) (forward-message-to (elt larm 0) args))
  (:larm-elbow (&rest args)    (forward-message-to (elt larm 1) args))
  (:larm-wrist (&rest args)    (forward-message-to (elt larm 2) args))
  (:rarm-shoulder (&rest args) (forward-message-to (elt rarm 0) args))
  (:rarm-elbow (&rest args)    (forward-message-to (elt rarm 1) args))
  (:rarm-wrist (&rest args)    (forward-message-to (elt rarm 2) args))
  ;;
  (:lleg-crotch (&rest args)   (forward-message-to (elt lleg 0) args))
  (:lleg-knee (&rest args)     (forward-message-to (elt lleg 1) args))
  (:lleg-ankle (&rest args)    (forward-message-to (elt lleg 2) args))
  (:rleg-crotch (&rest args)   (forward-message-to (elt rleg 0) args))
  (:rleg-knee (&rest args)     (forward-message-to (elt rleg 1) args))
  (:rleg-ankle (&rest args)    (forward-message-to (elt rleg 2) args))
  (:torso-chest (&rest args)   (forward-message-to (elt torso 0) args))
  (:head-neck (&rest args)     (forward-message-to (elt head 0) args))
  (:copy-joint-to
   (robot limb joint &optional (sign 1))
   (if (find-method robot (intern (format nil "~A-~A-R" (symbol-name limb) (symbol-name joint)) "KEYWORD"))
       (send robot limb (intern (format nil "~A-R" (symbol-name joint)) "KEYWORD") :joint-angle
             (* sign (elt (send self limb joint :joint :joint-angle) 2))))
   (if (find-method robot (intern (format nil "~A-~A-P" (symbol-name limb) (symbol-name joint)) "KEYWORD"))
       (send robot limb (intern (format nil "~A-P" (symbol-name joint)) "KEYWORD") :joint-angle
             (* sign (elt (send self limb joint :joint :joint-angle) 0))))
   (if (find-method robot (intern (format nil "~A-~A-Y" (symbol-name limb) (symbol-name joint)) "KEYWORD"))
       (send robot limb (intern (format nil "~A-Y" (symbol-name joint)) "KEYWORD") :joint-angle
             (* sign (elt (send self limb joint :joint :joint-angle) 1)))))
  (:copy-state-to
   (robot &optional stay)
   (let (sign)
     (dolist (arm '(:larm :rarm))
       (dolist (joint '(:shoulder :elbow :wrist))
	 (cond
	   ((send self arm joint)
	    (send self :copy-joint-to robot arm joint))
	   (t (format t ";; (send ~A ~A ~A)=nil~%" self arm joint)))
	 ))
     (dolist (leg '(:lleg :rleg))
       (dolist (joint '(:crotch :knee :ankle))
	 (cond
	   ((send self leg joint)
	    (send self :copy-joint-to robot leg joint))
	   (t (format t ";; (send ~A ~A ~A)=nil~%" self leg joint)))
	 ))
     (dolist (limb '(:torso))
       (dolist (joint '(:chest))
	 (cond
	   ((send self limb joint)
	    (send self :copy-joint-to robot limb joint))
	   (t (format t ";; (send ~A ~A ~A)=nil~%" self limb joint)))
	 ))
     (dolist (limb '(:head))
       (dolist (joint '(:neck))
	 (cond
	   ((send self limb joint)
	    (send self :copy-joint-to robot limb joint))
	   (t (format t ";; (send ~A ~A ~A)=nil~%" self limb joint)))
	 ))
     (unless stay
       (let ((p (send robot :worldpos))
	     (c (send self :transformation (car links) :world))
	     )
	 (send robot :newcoords (c . rot) p)
	 ))
     )) ;; copy-state-to
  )

;;
(setq *bvh-files*
      (list
       "bvh/sfu/0005_SideSkip001.bvh"
       "bvh/sfu/0005_SlowTrot001.bvh"
       "bvh/sfu/0005_Jogging001.bvh"
       "bvh/sfu/0005_Walking001.bvh"
       "bvh/sfu/0007_Crawling001.bvh"
       "bvh/sfu/0007_Walking001.bvh"
       "bvh/sfu/0008_Walking001.bvh"
       "bvh/sfu/0008_Skipping001.bvh"
       ;;
       "bvh/sfu/0012_SpeedVault001.bvh"
       "bvh/sfu/0012_SpeedVault002.bvh"
       "bvh/sfu/0015_HopOverObstacle001.bvh"
       "bvh/sfu/0015_JumpOverObstacle001.bvh"
       "bvh/sfu/0017_SpeedVault001.bvh"
       "bvh/sfu/0017_SpeedVault002.bvh"
       "bvh/sfu/0017_MonkeyVault001.bvh"
       ;;
       ))

(defun demo (&key robot (files *bvh-files*))
  (dolist (file (if (atom files) (list files) files))
    (sfu-bvh2eus file :objects robot)))

(defun animate (&key (files *bvh-files*) (model t)
		     (color (float-vector 0.7 1.0 1.0))
		     (scale 10))
  (let (mcd (objs (objects)))
    (send *irtviewer* :change-background color)
    (send *irtviewer* :draw-objects)
    (dolist (f (if (atom files) (list files) files))
      (setq mcd (load-mcd f :bvh-robot-model-class sfu-bvh-robot-model :scale scale))
      (if model (objects (cons (send mcd :model) objs)))
      (send mcd :animate))))
;;
(defun demo2 (&key (files *bvh-files*) ;; "bvh/sfu/0012_SpeedVault001.bvh"
		   (xs 600) (ys xs) (model t) base
		   (color (float-vector 0.7 1.0 1.0))
		   (scale 8))
  (show-2d-arrange (list (kxr-create-robot "kxrl2t2l6a7h2yprb")
			 (kxr-create-robot "kxrl2l6a7h2m"))
		   :xs xs :ys ys :base base)
  (animate :files files :model model :color color :scale scale))
;;
  
