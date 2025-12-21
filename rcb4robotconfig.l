;;;
;;;	robot config file for RCB4 controller
;;;
;;;	2019.7.2 kxrl2makabe update
;;;	2020.2.26 added (kxr-typed-config) to show config descriptors
;;;	2022.8.11 update merge-alist for kxr-typed-configs
#|
pprint (kxr-typed-configs) ;; 2022.8.11
((:l2
  (:3eye-rev 3)
  (:arm :j4)
  (:active-wheel :knee :crotch :ankle)
  (:ankle-sensor t :rev-c)
  (:ankle :y)
  (:body :l2l5 :l2l6w :lyp-low :dyp :l2l6 :dyp-zf :dyp-z :l2w2 :l2l6s
   :l2l6r :l2l6b :lyp-high :l2l6c :l4d :l4t)
  (:board :armh7 :rcb4)
  (:backpack :m5)
  (:backpack-function kxr-auv-back-pack kxr-auv-back-pack-nofloat)
  (:com-init-method (:arm-open :pid 24577) (:arm2-open) (:rcb4-open))
  (:crotch-z t)
  (:crotch-front t)
  (:eye-length 26)
  (:eye-y-rotate 3)
  (:gripper-inner t :rarm :larm nil)
  (:gripper t :larm :rarm)
  (:gripper-sensor
   nil ((:finger1 . :rev-c)) :larm t :rev-a (:finger2 :rev-b)
   (:finger1 :rev-a) ((:finger1 . :rev-a)) ((:finger1 :rev-a) (:finger2 . :rev-a))
   :finger1 :finger2 ((:finger1 . :rev-a) (:finger2 . :rev-c)) (:finger1))
  (:gripper-axis :p)
  (:head
   :h2s :h2-auv :m5us :m5u2s :m5sh :realsense-y :realsense :m5 :m3eye :my3eye
   :e :h2sf :h2sh :m5h :ir :m5i :h2sl :h2svi :h2svo :h2sv :h2sn :h2 :d2)
  (:head-length 20 26 38)
  (:head-sensor t)
  (:head-b nil)
  (:head-b-front nil)
  (:knee-type t :lp)
  (:leg :l6w :j4 :j1w :j3 :l2 :l6)
  (:marm :j1w :j3)
  (:m5stack 0)
  (:neck-jf :a :b :b-back)
  (:neck-front t)
  (:neck :y-p-r :y-r-p)
  (:neck-axis :p :z)
  (:passive-wheel :wrist (:shoulder :wrist) (:shoulder) :shoulder :gripper)
  (:project-file
   "kxrl2l5a4h2g" "kxr_auvrev2" "kxrl2l6a7h2w" "kxrl2l5a3h2g" "kxrl2l6anzai"
   "kxrl2makaberev3" "kxrl2makaberev2" "kxrl2makabe" "kxrl2l6a3h2w" "kxrl2w2l6a4h2"
   "kxrl2l6a4h2" "kxrl2w2l5a4h2" "kxrl2sonoyama" "kxrl2l5a3")
  (:shoulder :p-r-yr :cross :ly-p-r :y-p-r :uy-p-r :ly-p-rb :p :p-r-y)
  (:stand t)
  (:sole t :w :rleg :lleg)
  (:sole-sensor t :lleg :rleg)
  (:shoulder-width 38)
  (:shoulder-front t)
  (:type :l2)
  (:torso :ly-p :dy-p :dy-p2 :y-p-y :dy-p3 :ly-p-high :ly-pf :ly-pfy :y-r-p :y-p)
  (:upper-arm-length 38)
  (:wrist :y-cross :yw-cross :r :cross-y :y-p-y :y-p :cross :p)
  (:wrist-sensor t :rev-b :rarm :larm :rev-c nil)
  (:wing t :5inch)
  (:wrist-a t)
  (:wrist-len 38)
  (:wrist-inner t :y-)
  (:waist-len 38))
 (:l4
  (:3eye-rev 3)
  (:arm :j3w :j4 :l6w :j2 :j1w :j3)
  (:active-wheel :knee)
  (:body :l4m3 :l4m2 :l4m :l4d :l4b :l4t)
  (:board :armh7 :rcb4)
  (:com-init-method (:arm2-open))
  (:gripper-inner
   t (:larm :rarm) (:lleg :rarm) (:lleg :larm) (:lleg :rleg) (:larm :lleg) :larm :rarm)
  (:gripper-sensor :finger1 :finger2 :larm)
  (:gripper
   t (:rarm :rleg) (:rleg :larm) (:lleg :rarm) (:lleg :larm) (:lleg :rleg) (:larm :rarm))
  (:head
   :h3-new :h3 :d :h2s :m5sh :d2 :d1 :h2sh :h2sl :h2sn :m5us :m5usv2 :m3eye :h1 :e :h2)
  (:head-length 20 26)
  (:leg :j3w :j4 :j2 :j1w :j3)
  (:leg-frontal t)
  (:lego-bar 15)
  (:marm :r3 :r :j1w :j3 :j2)
  (:neck :y-r-p :y-p-r)
  (:neck-jf :b)
  (:project-file "kxrl4d" "kxrl4dr" "kxrl4r" "kxrl4t")
  (:passive-wheel :wrist :shoulder)
  (:shoulder :ly-p-r :cross :p)
  (:stand t)
  (:sole t)
  (:sole-sensor t)
  (:type :l4)
  (:torso :y-p :ly-p)
  (:tail :t2)
  (:wrist :r :y-cross :cross)
  (:wrist-sensor nil)
  (:wing t)
  (:wing-pos #f(-21.5 0.0 69.0)))
 (:l6
  (:arm :j3 :j1w :j2)
  (:body :l6)
  (:board :armh7 :rcb4)
  (:com-init-method (:rcb4-open :vid 5724 :pid 8 :parity 2) (:arm2-open))
  (:head :e :d2 :d1 :d :h2s)
  (:interface-class rcb4-interface)
  (:leg :j3 :j1w :j2)
  (:marm :j3 :j1w :j2)
  (:neck t)
  (:project-file "kxrl6")
  (:type :l6)
  (:wrist-sensor :larm)
  (:wing t)
  (:wing-pos #f(0.0 0.0 161.0))))
nil
|#

(require :utils)

(defvar *rcb4robotconfig-debug-message* t)
(defun format-if-needed (&rest args)
  (if *rcb4robotconfig-debug-message* (apply #'format *error-output* args)))
(defun classify-plists-old (plists &optional (type :type))
  (let (a b al ret)
    (dolist (pl plists)
      (if (setq a (assoc type (setq al (plist-to-alist pl))))
	  (if (setq b (assoc (cadr a) ret))
	      (nconc b (list pl))
	      (push (list (cadr a) pl) ret))
	  (push (nil nil) ret)))
    ret))

(defun classify-plists (plists &optional (type :type) &key (test #'equal))
  (let (a b al ret)
    (dolist (pl plists)
      (if (setq a (assoc type (setq al (plist-to-alist pl)) :test test))
	  (if (setq b (assoc (cadr a) ret :test test))
	      (nconc b (list pl))
	      (pushnew (list (cadr a) pl) ret :test #'equal))))
    ret))

(defun merge-alist (alist &key (test #'equal))
  (let (a ret)
    (dolist (al alist)
      (if (setq a (assoc (car al) ret :test test))
	  (rplacd a (union (cdr al) (cdr a) :test test))
	  (pushnew al ret :test test)))
    (sort ret #'<
	  #'(lambda (x) (elt (string (car x)) 0)))
    ))

(defun kxr-all-model-params (&optional (config-alist *kxr-body-config-alist*))
  (mapcar #'cadr config-alist))

(defun kxr-typed-configs (&optional (type :type) (config-alist *kxr-body-config-alist*))
  (mapcar #'(lambda (x) (cons (car x) (kxr-plist-configs (cdr x))))
	  (classify-plists (mapcar #'cadr config-alist) type)
	  ))

(defun kxr-config-key-values (&optional (type :type) (config-alist *kxr-body-config-alist*))
  (mapcar #'car (kxr-typed-configs type config-alist)))

(defun kxr-sorted-typed-configs (&key (config-alist *kxr-body-config-alist*) (type :type))
  (sort
   (kxr-typed-configs type config-alist)
   #'string<
   #'(lambda (x) (if (atom (car x)) (string (car x))
		     (string (caar x))))))

(defun kxr-plist-configs (plists)
  (merge-alist (mapcan #'plist-to-alist plists)))

(defun kxr-all-configs (&optional (config-alist *kxr-body-config-alist*))
  (kxr-plist-configs (mapcar #'cadr config-alist)))

(defun kxr-all-config-prop-keys (&optional (config-alist *kxr-body-config-alist*))
  (mapcar #'car (kxr-all-configs config-alist))
  )
(defun kxr-possible-model-params (&optional (config-alist *kxr-body-config-alist*))
  (mapcar
   #'(lambda (key) (list key (kxr-config-key-values key config-alist)))
   (kxr-all-config-prop-keys config-alist))
  )
(defun kxr-all-string-names (&optional (config-alist *kxr-body-config-alist*))
  (mapcar #'(lambda (rc) (if (consp (car rc)) (caar rc) (car rc))) config-alist))

(defun test-dump-robots  (&rest args)
  (kxr-draw-views :funcs (kxr-all-string-names) :dir "all-robots"))

(defun test-show-all-robots (&optional rotate)
  (let (rc r rob (alist (reverse *kxr-body-config-alist*)))
    (require :kxrviewer)
    (do-until-key
	(setq rc (pop alist))
      (if (null rc) (return 'test-show-all-robots))
      (setq r (car rc))
      (if (consp r) (setq r (car r)))
      (format t ";; robot =~A~%" r)
      (setq rob (kxr-create-robot r :model nil))
      (when rob
	(objects+ (list rob) :prop t)
	(send *irtviewer* :title r)
	(when rotate 
	  (unix::usleep 500000)
	  (dotimes (i (* 72 2))
	    (send rob :rotate (deg2rad 5) :z :world)
	    (send *irtviewer* :draw-objects)
	    (unix::usleep 30000)))))
    ))

(defun is-model-param? (prop alist &aux as)
  (cond
    ((atom prop) (assoc prop alist))
    ((setq as (assoc (car prop) alist))
     (member (cadr prop) (cdr as)))))

(defun kxr-find-robots-by-prop (&rest props)
  (mapcan
   #'(lambda (x)  
       (let* ((pms (cadr x))
	      (nm (if (atom (car x)) (car x) (caar x)))
	      (alist (plist-to-alist pms)))
	 (if (some #'(lambda (x) (is-model-param? x alist)) props)
	     (list nm) nil)))
   *kxr-body-config-alist*)
  )

(defun kxr-wheeled-robots nil
  (kxr-find-robots-by-prop :active-wheel :passive-wheel
			   '(:arm :j1w) '(:leg :j1w)))

(defparameter *kxr-body-config-alist*
  '(
;;; robot set models with magnet detachable modules
    (("kxrroboset1")
     (:robotset ("kxrl2body"   ;; "kxrl2a6h2body"
		 (:neck "d405eyes") ;; (:neck "d405cam")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:lleg "lleg5" "lsf")
		 (:rleg "rleg5" "rsf"))
		)
     )
    (("kxrroboset2")
     (:robotset ("kxrl2sbody"   ;; "kxrl2a6h2body"
		 (:neck "d405eyes") ;; (:neck "d405cam")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:lleg "llegs6" "lsf")
		 (:rleg "rlegs6" "rsf"))
		)
     )
    (("kxrroboset3")
     (:robotset ("kxrl27body"   ;; "kxrl2a6h2body"
		 (:neck "d405eyes")
		 (:larm "la7" "lg1sx") (:rarm "ra7" "rg1sx")
		 (:lleg "lleg5" "lsf")
		 (:rleg "rleg5" "rsf"))
		))
    (("kxrroboset4")
     (:robotset ("kxrl27sbody"   ;; "kxrl2a6h2body"
		 (:neck "d405eyes");; "d405cam"
		 (:larm "la7" "lg1sx") (:rarm "ra7" "rg1sx")
		 (:lleg "llegs6" "lsf")
		 (:rleg "rlegs6" "rsf"))
		))
    (("kxrroboset5")
     (:robotset ("kxrl27body"   ;; "kxrl2a6h2body"
		 (:neck "d405cam")
		 (:larm "la7" "lg1sx") (:rarm "ra7" "rg1sx")
		 (:lleg "kxrlleg1y" "lleg5" "lsf")
		 (:rleg "kxrrleg1y" "rleg5" "rsf"))
		))
    (("kxrroboset5b")
     (:robotset ("kxrl27body"   ;; "kxrl2a6h2body"
		 (:neck "d405cam")
		 (:larm "la7" "lg1sx") (:rarm "ra7" "rg1sx")
		 (:lleg "lleg6" "lsf")
		 (:rleg "rleg6" "rsf"))
		))
    ;;
    (("kxrroboset6b")
     (:robotset ("kxrl2a6h2body"
		 (:lleg "kxrlleg1y" "kxrlleg1rf")
		 (:rleg "kxrrleg1y" "kxrrleg1rf"))
		)
     )
    (("kxrroboset6")
     (:robotset ("kxrl2a6h2body"
		 (:lleg "kxrlleg5f")
		 (:rleg "kxrrleg5f"))
		)
     )
    (("kxrroboset5g")
     (:robotset ("kxrl2a6h2body"
		 (:larm "lg1sx") (:rarm "rg1sx")
		 (:lleg "kxrlleg5f")
		 (:rleg "kxrrleg5f"))
		)
     )
    (("kxrroboset6g")
     (:robotset ("kxrl2a6h2body"
		 (:larm "lg1sx") (:rarm "rg1sx")
		 (:lleg "kxrlleg5f")
		 (:rleg "kxrrleg5f"))
		)
     )
    (("kxrroboset")
     (:robotset ("kxrl2a6h2body"
		 (:larm "lg1sx") (:rarm "rg1sx")
		 (:lleg "kxrlleg1y" "kxrlleg5f")
		 (:rleg "kxrrleg1y" "kxrrleg5f"))
      )
     )
;;; wheel type robot
    (("kxrrobosetmw4")
     (:project-file
      "kxra6g"
      :robotset ("kxrl2body"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrmw4base")
		 ))
     )
    (("kxrrobosett1mw4")
     (:project-file
      "kxra6g"
      :robotset ("kxrl2body"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrt1mw4base")
		 ))
     )
    (("kxrrobosetmw4b")
     (:robotset ("kxrl2a6h2body"
		 (:larm "lg1sx") (:rarm "rg1sx")
		 (:mbase "kxrmw4base")
		 ))
     )
    (("kxrrobosett1mw4b")
     (:robotset ("kxrl2a6h2body"
		 (:larm "lg1sx") (:rarm "rg1sx")
		 (:mbase "kxrt1mw4base")
		 ))
     )
    (("kxrrobosetow4")
     (:robotset ("kxrl2body"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrow4base")
		 ))
     )
    (("kxrrobosett1ow4")
     (:robotset ("kxrl2body"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrt1ow4base")
		 ))
     )
    (("kxrrobosetow4b")
     (:robotset ("kxrl2a6h2body"
		 (:larm "lg1sx") (:rarm "rg1sx")
		 (:mbase "kxrow4base")
		 ))
     )
    (("kxrrobosett1ow4b")
     (:robotset ("kxrl2a6h2body"
		 (:larm "lg1sx") (:rarm "rg1sx")
		 (:mbase "kxrt1ow4base")
		 ))
     )
    (("kxrrobosetdw4")
     (:robotset ("kxrl2body"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrdw4base")
		 ))
     )
    (("kxrrobosett1dw4")
     (:robotset ("kxrl2body"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrt1dw4base")
		 ))
     )
    (("kxrrobosetdw4b")
     (:robotset ("kxrl2a6h2body"
		 (:larm "lg1sx") (:rarm "rg1sx")
		 (:mbase "kxrdw4base")
		 ))
     )
    (("kxrrobosett1dw4b")
     (:robotset ("kxrl2a6h2body"
		 (:larm "lg1sx") (:rarm "rg1sx")
		 (:mbase "kxrt1dw4base")
		 ))
     )
;;; quad leg type robot
    (("kxrrobosetl4t")
     (:project-file
      "kxra6g"
      :robotset ("kxrl2body" ;; "kxrl2a6h2body"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrl4tbase")
		 ))
     )
    (("kxrrobosett1l4t")
     (:project-file
      "kxra6g"
      :robotset ("kxrl2body"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrt1l4tbase")
		 ))
     )
    (("kxrrobosetkamakiri")
     (:project-file
      "kxra6g"
      :robotset ("kxrl2body"
		 (:neck "d405eyes")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrt1l4tbase")
		 ))
     )
    (("kxrrobosetkamakiri2")
     (:project-file
      "kxra6g"
      :robotset ("kxrl2body"
		 (:neck "d405eyes")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrl4tbase")
		 ))
     )
    (("kxrkamakiri") ;; same as kxrrobosetkamakiri
     (
      :project-file "kxrkamakiri" ;; "kxrl4tm"
      :body :t1l4tbase :torso :y :type :l4 :head :d405eyes
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :leg0 :j2-2m :leg1 :j2-2m
      :gripper t :gripper-straight t :gripper-axis :y)
     (2 :rarm-shoulder-p 1)      (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (22 :rarm-shoulder-y 1)     (23 :larm-shoulder-y 1)
     (26 :rarm-wrist-p 1)      (27 :larm-wrist-p -1)  
     (28 :rarm-wrist-r -1)     (29 :larm-wrist-r -1)
     (18 :rarm-gripper-r 1/2) (18 :rarm-gripper2-r 1/2)
     (19 :larm-gripper-r 1/2) (19 :larm-gripper2-r 1/2)
     ;;
     (24 :rleg0-crotch-y -1)   (25 :lleg0-crotch-y -1)
     (8  :rleg0-crotch-r -1)   (9 :lleg0-crotch-r 1)
     (20 :rleg1-crotch-y -1)   (21 :lleg1-crotch-y -1)
     (16 :rleg1-crotch-r -1)   (17 :lleg1-crotch-r 1)
     ;;
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     (33 :torso-chest-y -1)
     )
    (("kxrkamakiri2") ;; same as kxrrobosetkamakiri2
     (:project-file
      "kxrkamakiri" ;; "kxra6g"
      ;;:body :l4c :type :l4 :head :d405eyes
      :body :l4tbase :type :l4 :head :d405eyes
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :leg0 :j2-2m :leg1 :j2-2m
      :gripper t :gripper-straight t :gripper-axis :y)
     (2 :rarm-shoulder-p 1)      (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (22 :rarm-shoulder-y 1)     (23 :larm-shoulder-y 1)
     (26 :rarm-wrist-p 1)      (27 :larm-wrist-p -1)  
     (28 :rarm-wrist-r -1)     (29 :larm-wrist-r -1)
     (18 :rarm-gripper-r 1/2) (18 :rarm-gripper2-r 1/2)
     (19 :larm-gripper-r 1/2) (19 :larm-gripper2-r 1/2)
     ;;
     (24 :rleg0-crotch-y -1)   (25 :lleg0-crotch-y -1)
     (8  :rleg0-crotch-r -1)   (9 :lleg0-crotch-r 1)
     (20 :rleg1-crotch-y -1)   (21 :lleg1-crotch-y -1)
     (16 :rleg1-crotch-r -1)   (17 :lleg1-crotch-r 1)
     ;;
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    (("kxrkamakiri4") ;; 4DOF ARM
     (:project-file
      "kxrkamakiri" ;;"kxrl2l5a4h2g"
      :body :t1l4tbase :torso :y :type :l4 :head :d405eyes
      :shoulder :p-r-y :shoulder-front t :shoulder-low t :flat-shoulder nil
      ;;:elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :leg0 :j2-2m :leg1 :j2-2m
      :gripper t :gripper-straight t :gripper-axis :x
      :gripper-axis :y)
     (2 :rarm-shoulder-p 1 45)      (3 :larm-shoulder-p -1 45)
     (4 :rarm-shoulder-r -1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (22 :rarm-shoulder-y 1)     (23 :larm-shoulder-y 1)
     (18 :rarm-gripper-r 1/2) (18 :rarm-gripper2-r 1/2)
     (19 :larm-gripper-r 1/2) (19 :larm-gripper2-r 1/2)
     ;;
     (24 :rleg0-crotch-y -1)   (25 :lleg0-crotch-y -1)
     (8  :rleg0-crotch-r -1)   (9 :lleg0-crotch-r 1)
     (20 :rleg1-crotch-y -1)   (21 :lleg1-crotch-y -1)
     (16 :rleg1-crotch-r -1)   (17 :lleg1-crotch-r 1)
     ;;
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     (33 :torso-chest-y -1)
     )
;;; hexa leg type robot
    (("kxrrobosetl6")
     (:project-file
      "kxra6g"
      :robotset ("kxrl2body"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrl6base")
		 ))
     )
    (("kxrrobosett1l6")
     (:project-file
      "kxra6g"
      :robotset ("kxrl2body"
		 (:neck "d405eyes")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrt1l6base")
		 ))
     )
    (("kxrrobosetl6b")
     (:project-file
      "kxra6g"
      :robotset ("kxrl2a6h2body"
		 (:larm "lg1sx") (:rarm "rg1sx")
		 (:mbase "kxrl6base")
		 ))
     )
    (("kxrrobosett1l6b")
     (:project-file
      "kxra6g"
      :robotset ("kxrl2a6h2body"
		 (:larm "lg1sx") (:rarm "rg1sx")
		 (:mbase "kxrt1l6base")
		 ))
     )
;;; biped leg type robot
    (("kxrrobosetl2l2-old")
     (:robotset ("kxrl2a6h2body"
		 (:neck "d405echos")
		 (:larm "lg1sx") (:rarm "rg1sx")
		 (:mbase "kxrl2l2base")
		 ))
     )
    (("kxrrobosetl2l2")
     (:robotset ("kxrl2body"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrl2l2base")
		 ))
     )
    (("kxrrobosett1l2l2")
     (:robotset ("kxrl2body"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrt1l2l2base")
		 ))
     )
    (("kxrrobosetl2l5-old")
     (:robotset ("kxrl2a6h2body"
		 (:larm "lg1sx") (:rarm "rg1sx")
		 (:mbase "kxrl2l5base")
		 ))
     )
    (("kxrrobosetl2l5")
     (:robotset ("kxrl2body"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrl2l5base")
		 ))
     )
    (("kxrrobosett1l2l5")
     (:robotset ("kxrl2body"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrt1l2l5base")
		 ))
     )
    ;;
    (("llegs6")
     (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l6s :end :mag-7)
     (9 :lleg-crotch-r 1)
     (11 :lleg-crotch-p -1)
     (13 :lleg-knee-p 1)
     (15 :lleg-ankle-p -1)
     (17 :lleg-ankle-r -1)
     (25 :lleg-crotch-y 1)
     )
    (("rlegs6")
     (:body :mag+7 :type :module :noarm t :limb :rleg :leg :l6s :end :mag-7)
     (8 :rleg-crotch-r 1)
     (10 :rleg-crotch-p -1)
     (12 :rleg-knee-p 1)
     (14 :rleg-ankle-p -1)
     (16 :rleg-ankle-r -1)
     (24 :rleg-crotch-y 1)
     )
    (("lleg6") (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l6 :end :mag-7)
     (9 :lleg-crotch-r 1)
     (11 :lleg-crotch-p -1)
     (13 :lleg-knee-p 1)
     (15 :lleg-ankle-p -1)
     (17 :lleg-ankle-r -1)
     (25 :lleg-crotch-y 1)
     )
    (("lleg6s") (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l6 :end :mag-7)
     (9 :lleg-crotch-r 1)
     (11 :lleg-crotch-p -1)
     (13 :lleg-knee-p 1)
     (15 :lleg-ankle-p -1)
     (17 :lleg-ankle-r -1)
     (25 :lleg-crotch-y 1)
     (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("lleg6f") (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l6 :sole t)
     (9 :lleg-crotch-r 1)
     (11 :lleg-crotch-p -1)
     (13 :lleg-knee-p 1)
     (15 :lleg-ankle-p -1)
     (17 :lleg-ankle-r -1)
     (25 :lleg-crotch-y 1)
     )
    (("lleg6sf") (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l6 :sole t)
     (9 :lleg-crotch-r 1)
     (11 :lleg-crotch-p -1)
     (13 :lleg-knee-p 1)
     (15 :lleg-ankle-p -1)
     (17 :lleg-ankle-r -1)
     (25 :lleg-crotch-y 1)
     (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("rleg6") (:body :mag+7 :type :module :noarm t :limb :rleg :leg :l6 :end :mag-7)
     (8 :rleg-crotch-r 1)
     (10 :rleg-crotch-p -1)
     (12 :rleg-knee-p 1)
     (14 :rleg-ankle-p -1)
     (16 :rleg-ankle-r -1)
     (24 :rleg-crotch-y 1)
     )
    (("rleg6s") (:body :mag+7 :type :module :noarm t :limb :rleg :leg :l6 :end :mag-7)
     (8 :rleg-crotch-r 1)
     (10 :rleg-crotch-p -1)
     (12 :rleg-knee-p 1)
     (14 :rleg-ankle-p -1)
     (16 :rleg-ankle-r -1)
     (24 :rleg-crotch-y 1)
     (42 rleg-ankle-r-KJS-03)
     (44 rarm-wrist-r-KJS-03)
     )
    (("rleg6f") (:body :mag+7 :type :module :noarm t :limb :rleg :leg :l6 :sole t)
     (8 :rleg-crotch-r 1)
     (10 :rleg-crotch-p -1)
     (12 :rleg-knee-p 1)
     (14 :rleg-ankle-p -1)
     (16 :rleg-ankle-r -1)
     (24 :rleg-crotch-y 1)
     )
    (("rleg6sf") (:body :mag+7 :type :module :noarm t :limb :rleg :leg :l6 :sole t)
     (8 :rleg-crotch-r 1)
     (10 :rleg-crotch-p -1)
     (12 :rleg-knee-p 1)
     (14 :rleg-ankle-p -1)
     (16 :rleg-ankle-r -1)
     (24 :rleg-crotch-y 1)
     (42 rleg-ankle-r-KJS-03)
     (44 rarm-wrist-r-KJS-03)
     )
    (("lleg5")
     (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l5 :end :mag-7)
     (9 :lleg-crotch-r 1)
     (11 :lleg-crotch-p -1)
     (13 :lleg-knee-p 1)
     (15 :lleg-ankle-p -1)
     (17 :lleg-ankle-r -1)
;;     (25 :lleg-crotch-y 1)
     )
    (("rleg5")
     (:body :mag+7 :type :module :noarm t :limb :rleg :leg :l5 :end :mag-7)
     (8 :rleg-crotch-r 1)
     (10 :rleg-crotch-p -1)
     (12 :rleg-knee-p 1)
     (14 :rleg-ankle-p -1)
     (16 :rleg-ankle-r -1)
;;     (24 :rleg-crotch-y 1)
     )
    ;;
    (("llegs6f")
     (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l6s :sole t)
     (9 :lleg-crotch-r 1)
     (11 :lleg-crotch-p -1)
     (13 :lleg-knee-p 1)
     (15 :lleg-ankle-p -1)
     (17 :lleg-ankle-r -1)
     (25 :lleg-crotch-y 1)
     )
    (("rlegs6f")
     (:body :mag+7 :type :module :noarm t :limb :rleg :leg :l6s :sole t)
     (8 :rleg-crotch-r 1)
     (10 :rleg-crotch-p -1)
     (12 :rleg-knee-p 1)
     (14 :rleg-ankle-p -1)
     (16 :rleg-ankle-r -1)
     (24 :rleg-crotch-y 1)
     )
    ;;
    (("kxrrobosetl2l6s0")
     (:robotset ("kxrl2sbody"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:lleg "llegs6f")
		 (:rleg "rlegs6f"))
		))
    ;;
    (("kxrrobosetl2l6s")
     (:robotset ("kxrl2sbody"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:lleg "llegs6" "llegf")
		 (:rleg "rlegs6" "rlegf"))
		))
    ;;
    (("lsf")
     (:body :mag+7 :type :module :noarm t :limb :lleg :leg :foot :sole-sensor t)
     )
    (("rsf")
     (:body :mag+7 :type :module :noarm t :limb :rleg :leg :foot :sole-sensor t)
     )
    (("kxrrobosetl2l6s1")
     (:robotset ("kxrl2sbody"
		 ;;(:neck "d405echos")
		 (:neck "d405cam")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:lleg "llegs6" "lsf")
		 (:rleg "rlegs6" "rsf"))
		))
    (("kxrrobosetl2l6s2")
     (:robotset ("kxrl2sbody"
		 (:neck "d405cam")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:lleg "llegs6" "llegf")
		 (:rleg "rlegs6" "rlegf"))
		))
    ;;
    (("kxrrobosetl2l6")
     (:robotset ("kxrl2body"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrl2l6base")
		 ))
     )
    (("kxrrobosett1l2l6")
     (:robotset ("kxrl2body"
		 (:neck "d405echos")
		 (:larm "la6" "lg1sx") (:rarm "ra6" "rg1sx")
		 (:mbase "kxrt1l2l6base")
		 ))
     )
    (("kxrrobosetl2l6-2")
     (:robotset ("kxrl2a6body"
		 (:neck "d405cam")
		 (:larm "lg1sx") (:rarm "rg1sx")
		 (:mbase "kxrl2l6base")
		 ))
     )
;;;
    (("head-gripper")
     (:body :mag+7 :noleg t :noarm t :type :module  ;; :limb :head 
	    :limb :head
	    :neck nil
	    :head :gripper-y)
     (19 :head-gripper-p 1/2)   (19 :head-gripper2-p 1/2)
     )
    (("kxrl4nh4gir")
     (:robotset ("kxrl4nh4"
		 (:head "head-gripper"))))
;;;
;;; magnet modules body, base, limb
;;; body torso type
;;;
    (("kxrl2sbody")
     (:body :l2l6s :type :module :noleg t :noarm t
	    :crotch-front t :shoulder-front nil
	    :end :mag-7)
     )
    (("kxrl2body")
     (:body :l2l5m :type :module :noleg t :noarm t :end :mag-7)
     )
    (("kxrl27body")
     (:body :l2l5a :type :module :shoulder :ypry-cross :noleg t :noarm t :end :mag-7)
     )
    (("kxrl27sbody")
     (:body :l2l6s :type :module :shoulder :ypry-cross :noleg t :noarm t :end :mag-7)
     )
    (("kxrl2h2body")
     (:body :l2l5m :type :module :noleg t :noarm t :head :h1 :head-length 20 :end :mag-7)
     )
    (("kxrl2a6h2g1body")
     (:body :l2l5a :board :armh7 :noleg t :head :h1 :head-length 20 :end :mag-7
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :head-sensor :horn-mag-7 :wrist-sensor :mag-7 
	    :gripper t :gripper-straight t :gripper-axis :y
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    (("kxrl2a6h2body")
     (:body :l2l5m :type :module :noleg t :head :h1 :head-length 20;; :end :mag-7
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :head-sensor :horn-mag-7 :wrist-sensor nil ;;:mag-7 
	    ;;:gripper t :gripper-straight t :gripper-axis :y
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    (("kxrl2a6body")
     (:body :l2l5m :board :armh7 :noleg t :end :mag-7
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :wrist-sensor :horn-mag-7
	    ;;:gripper t :gripper-straight t :gripper-axis :y
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     ;;     (32 :head-neck-y -1)
     )
    (("kxrl2l6body")
     (:body :l2l6base :board :armh7 :noleg t :noarm t) ;;  :end :horn-mag-
     )
    (("kxrl2l6h2body")
     (:body :l2l6 :board :armh7 :noleg t :noarm t :head :h2 :head-length 20 :end :horn-mag-)
     )
;;;
;;; magnet modules body, base, limb
;;; l2 mobile base type
;;;
    (("kxrl2l2base")
     (
      :body :l2l6base :type :module
      :project-file "kxra6g"
      ;;:project-file "kxrl2l6a6h2"
      :noarm t :crotch-p nil ;; :crotch-low t :crotch-front t :flat-crotch t
      :leg :j2-pr :sole t 
      )
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)
     )
    (("kxrt1l2l2base")
     (
      :body :t1l2l6base :type :module
      :project-file "kxra6g"
      ;;:project-file "kxrl2l6a6h2"
      :noarm t :crotch-p nil ;; :crotch-low t :crotch-front t :flat-crotch t
      :torso :y
      :leg :j2-pr :sole t 
      )
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)
     (33 :torso-chest-y 1)
     )
    (("kxrl2l5base")
     (
      :body :l2l5base :type :module
      :project-file "kxra6g"
      ;;:project-file "kxrl2l6a6h2"
      :noarm t :crotch-p nil ;; :crotch-low t :crotch-front t :flat-crotch t
      :sole t 
      )
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     )
    (("kxrt1l2l5base")
     (
      :body :t1l2l5base :type :module
      :project-file "kxra6g"
      ;;:project-file "kxrl2l6a6h2"
      :noarm t :crotch-p nil ;; :crotch-low t :crotch-front t :flat-crotch t
      :torso :y
      :sole t 
      )
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (33 :torso-chest-y 1)
     )
    (("kxrl2l6base")
     (
      :body :l2l6base :type :module
      :project-file "kxra6g"
      ;;:project-file "kxrl2l6a6h2"
      :noarm t :crotch-p nil ;; :crotch-low t :crotch-front t :flat-crotch t
      :sole t 
      )
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     )
    (("kxrt1l2l6base")
     (
      :body :t1l2l6base :type :module
      :project-file "kxra6g"
      ;;:project-file "kxrl2l6a6h2"
      :noarm t :crotch-p nil ;; :crotch-low t :crotch-front t :flat-crotch t
      :torso :y
      :sole t 
      )
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (33 :torso-chest-y 1)
     )
;;; l4t mobile base type
    (("kxrl4tbase")
     (:body :l4tbase :type :module :leg0 :j2-2m :leg1 :j2-2m
	    :project-file "kxrl4tm" :noarm t ;; :battery-box t :neck nil
	    )
     (24 :rleg0-crotch-y -1)   (25 :lleg0-crotch-y -1)
     (8  :rleg0-crotch-r -1)   (9 :lleg0-crotch-r 1)
     (20 :rleg1-crotch-y -1)   (21 :lleg1-crotch-y -1)
     (16 :rleg1-crotch-r -1)   (17 :lleg1-crotch-r 1)
     )
    (("kxrt1l4tbase")
     (:body :t1l4tbase :type :module :leg0 :j2-2m :leg1 :j2-2m
	    :torso :y  :noarm t
	    :project-file "kxrl4tm"
	    )
     (24 :rleg0-crotch-y -1)   (25 :lleg0-crotch-y -1)
     (8  :rleg0-crotch-r -1)   (9 :lleg0-crotch-r 1)
     (20 :rleg1-crotch-y -1)   (21 :lleg1-crotch-y -1)
     (16 :rleg1-crotch-r -1)   (17 :lleg1-crotch-r 1)
     (33 :torso-chest-y 1)
     )
;;; l6 mobile base type
    (("kxrl6base")		;; 18
     (:body :l6base :type :module :leg0 :j3-3m :leg1 :j3-3m :leg2 :j3-3m
	    :noarm t :project-file "kxrl6"
	    )
     (24 :rleg0-crotch-y -1)     (25 :lleg0-crotch-y -1)
     (8  :rleg0-crotch-r -1)     (9  :lleg0-crotch-r -1)
     (10 :rleg0-knee-r 1)        (11 :lleg0-knee-r 1)
     (20 :rleg1-crotch-y -1)     (21 :lleg1-crotch-y -1)
     (12 :rleg1-crotch-r -1)     (13 :lleg1-crotch-r 1)
     (14 :rleg1-knee-r 1)        (15 :lleg1-knee-r -1)
     (0  :rleg2-crotch-y -1)     (1  :lleg2-crotch-y -1)
     (16 :rleg2-crotch-r 1)      (17 :lleg2-crotch-r  1)
     (30 :rleg2-knee-r -1)       (31 :lleg2-knee-r -1)
     )
    (("kxrt1l6base")		;; 18
     (:body :t1l6base :type :module :leg0 :j3-3m :leg1 :j3-3m :leg2 :j3-3m
	    :torso :y  :noarm t
	    :project-file "kxrl6"
	    )
     (24 :rleg0-crotch-y -1)     (25 :lleg0-crotch-y -1)
     (8  :rleg0-crotch-r -1)     (9  :lleg0-crotch-r -1)
     (10 :rleg0-knee-r 1)        (11 :lleg0-knee-r 1)
     (20 :rleg1-crotch-y -1)     (21 :lleg1-crotch-y -1)
     (12 :rleg1-crotch-r -1)     (13 :lleg1-crotch-r 1)
     (14 :rleg1-knee-r 1)        (15 :lleg1-knee-r -1)
     (0  :rleg2-crotch-y -1)     (1  :lleg2-crotch-y -1)
     (16 :rleg2-crotch-r 1)      (17 :lleg2-crotch-r  1)
     (30 :rleg2-knee-r -1)       (31 :lleg2-knee-r -1)
     (33 :torso-chest-y 1)
     )
;;; wheel mobile base type
    (("kxrmw4base")
     (:body :mw4base :type :module :noarm t :leg :j2m :lidar t
	    :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t :wheel-servo-stand t
	    )
     (0 :rleg-crotch-w 1)   (1 :lleg-crotch-w -1)
     (20 :rleg-knee-w 1)    (21 :lleg-knee-w -1)
     )
    (("kxrt1mw4base")
     (:body :t1mw4base :type :module :noarm t :leg :j2m :lidar t
	    :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t :wheel-servo-stand t
	    :torso :y
	    )
     (0 :rleg-crotch-w 1)   (1 :lleg-crotch-w -1)
     (20 :rleg-knee-w 1)    (21 :lleg-knee-w -1)
     (33 :torso-chest-y 1)
     )
    (("kxrow4base")
     (:body :ow4base :type :module :noarm t :leg :j2o :lidar t
	    :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t :wheel-servo-stand t
	    )
     (8 :rleg-crotch-w 1)     (9 :lleg-crotch-w 1)
     (16 :rleg-knee-w 1)       (17 :lleg-knee-w 1)
     )
    (("kxrt1ow4base")
     (:body :t1ow4base :type :module :noarm t :leg :j2o :lidar t
	    :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t :wheel-servo-stand t
	    :torso :y
	    )
     (8 :rleg-crotch-w 1)     (9 :lleg-crotch-w 1)
     (16 :rleg-knee-w 1)       (17 :lleg-knee-w 1)
     (33 :torso-chest-y 1)
     )
    (("kxrdw4base")
     (:body :dw4base :type :module :noarm t :leg :j2d :lidar t
	    :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t :wheel-servo-stand t
	    )
     (14 :rleg-crotch-w 1)     (15 :lleg-crotch-w 1)
     )
    (("kxrt1dw4base")
     (:body :t1dw4base :type :module :noarm t :leg :j2d :lidar t
	    :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t :wheel-servo-stand t
	    :torso :y
	    )
     (14 :rleg-crotch-w 1)     (15 :lleg-crotch-w 1)
     (33 :torso-chest-y 1)
     )
;;;
;;; magnet modules body, base, limb
;;; limb type module
;;;
    (("kxrlarma6")
     (:body :limb :noleg t :limb :larm :type :module
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    ;;:shoulder-p-sensor (:rev-a :flip) :shoulder-y-sensor (:rev-a :flip)
	    ;; :shoulder-r-sensor :rev-c :elbow-p-sensor :rev-c
	    ;;:wrist-p-sensor :rev-c :wrist-sensor :rev-c
	    ;;:gripper t :gripper-straight t :gripper-axis :y
	    ;;:gripper-sensor :rev-a ;;(:finger1 :rev-a) ;; :finger1 outside(drive :gripper-r), :finger2 inside(:gripper2-r)
	    )
     (3 :larm-shoulder-p -1)
     (5 :larm-shoulder-r 1)
     (7 :larm-elbow-p 1)
     (23 :larm-shoulder-y 1)
     (27 :larm-wrist-p -1)
     (29 :larm-wrist-r -1)
     )
    (("kxrrarma6")
     (:body :limb :noleg t :limb :rarm
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    )
     (2 :rarm-shoulder-p 1)
     (4 :rarm-shoulder-r 1)
     (6 :rarm-elbow-p 1)   
     (22 :rarm-shoulder-y 1)
     (26 :rarm-wrist-p 1)   
     (28 :rarm-wrist-r -1)
     )
    (("la6")
     (:body :mag+7 :noleg t :limb :larm :type :module 
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :end :horn-mag-
	    )
     (3 :larm-shoulder-p -1)
     (5 :larm-shoulder-r 1)
     (7 :larm-elbow-p 1)
     (23 :larm-shoulder-y 1)
     (27 :larm-wrist-p -1)
     (29 :larm-wrist-r -1)
     )
    (("ra6")
     (:body :mag+7 :noleg t :limb :rarm :type :module
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :end :horn-mag-
	    )
     (2 :rarm-shoulder-p 1)
     (4 :rarm-shoulder-r 1)
     (6 :rarm-elbow-p 1)   
     (22 :rarm-shoulder-y 1)
     (26 :rarm-wrist-p 1)   
     (28 :rarm-wrist-r -1)
     )
    ;;
    (("la7")
     (:body :mag-0 :noleg t :limb :larm :type :module 
	    :shoulder :ypry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :end :horn-mag-
	    )
     (31 :larm-shoulder-y 1)
     (3 :larm-shoulder-p -1)
     (5 :larm-shoulder-r 1)
     (7 :larm-elbow-p 1)
     (23 :larm-elbow-y 1)
     (27 :larm-wrist-p -1)
     (29 :larm-wrist-r -1)
     )
    (("ra7")
     (:body :mag-0 :noleg t :limb :rarm :type :module
	    :shoulder :ypry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :end :horn-mag-
	    )
     (30 :rarm-shoulder-y 1)
     (2 :rarm-shoulder-p 1)
     (4 :rarm-shoulder-r 1)
     (6 :rarm-elbow-p 1)   
     (22 :rarm-elbow-y 1)
     (26 :rarm-wrist-p 1)   
     (28 :rarm-wrist-r -1)
     )
    ;; dummy body-link
    (("kxrlleg2+") (:body :limb :type :module :noarm t :limb :lleg :leg :j2))
    (("kxrlleg3+") (:body :limb :noarm t :limb :lleg :leg :j3))
    (("kxrlleg4+") (:body :limb :noarm t :limb :lleg :leg :j4))
    (("kxrrleg4+") (:body :limb :noarm t :limb :rleg :leg :j4))
    ;; mag-joint body-link
    (("kxrlleg1y") (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l1y :end :horn-mag-)
     (25 :lleg-crotch-y 1))
    (("kxrrleg1y") (:body :mag+7 :type :module :noarm t :limb :rleg :leg :l1y :end :horn-mag-)
     (24 :rleg-crotch-y 1))
    ;;
    (("kxrlleg1r") (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l1r :end :mag-7)
     (17 :lleg-crotch-r -1))
    (("kxrrleg1r") (:body :mag+7 :type :module :noarm t :limb :rleg :leg :l1r :end :mag-7)
     (16 :rleg-crotch-r 1))
    (("kxrlleg1rf") (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l1r :sole t)
     (17 :lleg-crotch-r -1))
    (("kxrrleg1rf") (:body :mag+7 :type :module :noarm t :limb :rleg :leg :l1r :sole t)
     (16 :rleg-crotch-r 1))
    (("kxrlleg1yf") (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l1y :sole t)
     (15 :lleg-crotch-y 1))
    (("kxrrleg1yf") (:body :mag+7 :type :module :noarm t :limb :rleg :leg :l1y :sole t)
     (14 :rleg-crotch-y 1))
    ;;
    (("lleg2") (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l2 :end :mag-7)
     (15 :lleg-crotch-y 1)
     (17 :lleg-crotch-r -1)
     (43 lleg-crotch-r-KJS-03))
    (("rleg2") (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l2 :end :mag-7)
     (14 :rleg-crotch-y 1)
     (16 :rleg-crotch-r 1)
     (42 rleg-crotch-r-KJS-03))
    (("lleg2f") (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l2 :sole t)
     (15 :lleg-crotch-y 1)
     (17 :lleg-crotch-r -1)
     (43 lleg-crotch-r-KJS-03))
    (("rleg2f") (:body :mag+7 :type :module :noarm t :limb :rleg :leg :l2 :sole t)
     (14 :rleg-crotch-y 1)
     (16 :rleg-crotch-r 1)
     (42 rleg-crotch-r-KJS-03))
    ;;
    (("lleg5" "kxrlleg5")
     (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l5 :end :mag-7)
     (9 :lleg-crotch-r 1)
     (11 :lleg-crotch-p -1)
     (13 :lleg-knee-p 1)
     (15 :lleg-ankle-p -1)
     (17 :lleg-ankle-r -1)
     )
    (("rleg5" "kxrrleg5")
     (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l5 :end :mag-7)
     (8 :rleg-crotch-r 1)
     (10 :rleg-crotch-p -1)
     (12 :rleg-knee-p 1)
     (14 :rleg-ankle-p -1)
     (16 :rleg-ankle-r -1)
     )
    (("lleg5f" "kxrlleg5f")
     (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l5 :sole t)
     (9 :lleg-crotch-r 1)
     (11 :lleg-crotch-p -1)
     (13 :lleg-knee-p 1)
     (15 :lleg-ankle-p -1)
     (17 :lleg-ankle-r -1)
     )
    (("rleg5f" "kxrrleg5f")
     (:body :mag+7 :type :module :noarm t :limb :rleg :leg :l5 :sole t)
     (8 :rleg-crotch-r 1)
     (10 :rleg-crotch-p -1)
     (12 :rleg-knee-p 1)
     (14 :rleg-ankle-p -1)
     (16 :rleg-ankle-r -1)
     )
    ;;
    (("lleg6w" "kxrlleg6w") (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l6w :end :mag-7))
    (("rleg6w" "kxrrleg6w") (:body :mag+7 :type :module :noarm t :limb :rleg :leg :l6w :end :mag-7))
    (("lleg6wf" "kxrlleg6wf") (:body :mag+7 :type :module :noarm t :limb :lleg :leg :l6w :sole t))
    (("rleg6wf" "kxrrleg6wf") (:body :mag+7 :type :module :noarm t :limb :rleg :leg :l6w :sole t))
;;;
;;; whole-body robots
;;;
    (("kxrbackpack")
     (:body :backpack)
     )
    (("kxrarmh7")
     (:body :board :board :armh7)
     )
    (("drill")
     (:file "system-cobotta.l" :form (drill)
	    :board :armh7 :com-init-method (:arm2-open))
     (0 :joint-drill -1 15)
     (38 KJS-03) ;; sensor-board 21
     )
    (("cobotta-drill")
     (:file "system-cobotta.l" :form (cobotta-drill)
	    :board :armh7 :com-init-method (:arm2-open))
     (0 :joint-drill -1 15)
     (38 KJS-03) ;; sensor-board 21
     )
    (("cobotta_drill")
     (:file "models/cobotta_drill.l" :form (cobotta)
	    :board :armh7 :com-init-method (:arm2-open))
     (0 :joint-drill -1 15)
     (38 KJS-03) ;; sensor-board 21
     )
    (("cobotta-gripper")
     (:file "models/cobotta_gripper.l" :form (cobotta)
	    :board :armh7 :com-init-method (:arm2-open)
	    )
     )
    (("cobotta")
     (:file "models/cobotta.l" :form (cobotta)
	    :board :armh7 :com-init-method (:arm2-open)
	    )
     )
    (("kxrhead" "kxrhead1")
     (:body :backpack :board :armh7
	    :head :h1)
     (10 :head-neck-y 1)
     )
    (("kxrarm")
     (:file "irteus/demo/hanoi-arm.l" :form (progn  (setq *sarm* (instance sarmclass :init)))
	    :board :armh7 :com-init-method (:arm2-open)
	    )
     (2 :joint0 1) 
     (4 :joint1 1)
     (6 :joint2 1)
     (8 :joint3 1) 
     (10 :joint4 1)
     (12 :joint5 1)

     (18 :joint-fl 1/2)
     (20 :joint-fr 1/2)
     )
    (("kxrhead2")
     (:body :backpack :board :armh7
	    :head :h2)
     (10 :head-neck-y -1) (0 :head-neck-p -1)
     )
    (("kxrheadeye")
     (:body :backpack :board :armh7
	    ;;:head :m5usv2 :neck :y-r-p ;; :y-p-r ;; :h3s :m3eye :h2s 
	    ;;:head :m5u2s :neck :y-p-r ;; :y-p-r ;; :h3s :m3eye :h2s  :m5usv2
	    :head :m3eye :neck :y-p-r ;; :y-p-r ;; :h3s :m3eye :h2s  :m5usv2
	    :3eye-rev 3
	    )
     (1 :head-neck-p 1)
     (2 :head-neck-r 1)
     ;;(28 :head-leye-y -1)     (34 :head-reye-y -1)
     )
    (("kxrl6")		;; 18
     (:body :l6 :type :l6 :arm :j3 :marm :j3 :leg :j3
	    :backpack t :board :armh7)
     (2 :rarm-shoulder-y -1)    (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-p -1)    (5 :larm-shoulder-p -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rmarm-shoulder-y -1)   (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)  (11 :lmarm-shoulder-r 1)
     (12 :rmarm-elbow-r 1)      (13 :lmarm-elbow-r -1)
     (14 :rleg-crotch-y -1)     (15 :lleg-crotch-y -1)
     (16 :rleg-crotch-p 1)     (17 :lleg-crotch-p  1)
     (18 :rleg-knee-p -1)       (19 :lleg-knee-p -1)
     )
    (("kxrl6a6h2m")
     (:body :l6base :type :l6 :leg0 :j3-3m :leg1 :j3-3m :leg2 :j3-3m
	    :head :d405eyes
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :gripper t :gripper-straight t :gripper-axis :y
	    :project-file "kxrl6"
	    )
     (2 :rarm-shoulder-p 1)      (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (22 :rarm-shoulder-y 1)     (23 :larm-shoulder-y 1)
     (26 :rarm-wrist-p 1)      (27 :larm-wrist-p -1)  
     (28 :rarm-wrist-r -1)     (29 :larm-wrist-r -1)
     (18 :rarm-gripper-r 1/2) (18 :rarm-gripper2-r 1/2)
     (19 :larm-gripper-r 1/2) (19 :larm-gripper2-r 1/2)
     ;;
     (24 :rleg0-crotch-y -1)     (25 :lleg0-crotch-y -1)
     (8  :rleg0-crotch-r -1)     (9  :lleg0-crotch-r -1)
     (10 :rleg0-knee-r 1)        (11 :lleg0-knee-r 1)
     (20 :rleg1-crotch-y -1)     (21 :lleg1-crotch-y -1)
     (12 :rleg1-crotch-r -1)     (13 :lleg1-crotch-r 1)
     (14 :rleg1-knee-r 1)        (15 :lleg1-knee-r -1)
     (0  :rleg2-crotch-y -1)     (1  :lleg2-crotch-y -1)
     (16 :rleg2-crotch-r 1)      (17 :lleg2-crotch-r  1)
     (30 :rleg2-knee-r -1)       (31 :lleg2-knee-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    (("kxrt1l6a6h2m")
     (:body :t1l6base :leg0 :j3-3m :leg1 :j3-3m :leg2 :j3-3m
	    :head :d405eyes
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :gripper t :gripper-straight t :gripper-axis :y
	    :torso :y
	    :project-file "kxrl6"
	    )
     (2 :rarm-shoulder-p 1)      (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (22 :rarm-shoulder-y 1)     (23 :larm-shoulder-y 1)
     (26 :rarm-wrist-p 1)      (27 :larm-wrist-p -1)  
     (28 :rarm-wrist-r -1)     (29 :larm-wrist-r -1)
     (18 :rarm-gripper-r 1/2) (18 :rarm-gripper2-r 1/2)
     (19 :larm-gripper-r 1/2) (19 :larm-gripper2-r 1/2)
     ;;
     (24 :rleg0-crotch-y -1)     (25 :lleg0-crotch-y -1)
     (8  :rleg0-crotch-r -1)     (9  :lleg0-crotch-r -1)
     (10 :rleg0-knee-r 1)        (11 :lleg0-knee-r 1)
     (20 :rleg1-crotch-y -1)     (21 :lleg1-crotch-y -1)
     (12 :rleg1-crotch-r -1)     (13 :lleg1-crotch-r 1)
     (14 :rleg1-knee-r 1)        (15 :lleg1-knee-r -1)
     (0  :rleg2-crotch-y -1)     (1  :lleg2-crotch-y -1)
     (16 :rleg2-crotch-r 1)      (17 :lleg2-crotch-r  1)
     (30 :rleg2-knee-r -1)       (31 :lleg2-knee-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     (33 :torso-chest-y 1)
     )
    (("kxrl6s")		;; 18
     (:body :l6 :type :l6 :arm :j3 :marm :j3 :leg :j3
	    :backpack t :project-file "kxrl6"
	    :wrist-sensor :larm
	    )
     (2 :rarm-shoulder-y -1)    (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-p -1)    (5 :larm-shoulder-p -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rmarm-shoulder-y -1)   (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)  (11 :lmarm-shoulder-r 1)
     (12 :rmarm-elbow-r 1)      (13 :lmarm-elbow-r -1)
     (14 :rleg-crotch-y -1)     (15 :lleg-crotch-y -1)
     (16 :rleg-crotch-p 1)     (17 :lleg-crotch-p  1)
     (18 :rleg-knee-p -1)       (19 :lleg-knee-p -1)

     (42 larm-elbow-p-KJS-03) ;; sensor-board 21
     (44 rarm-elbow-p-KJS-03) ;; sensor-board 22
     (46 lmarm-elbow-r-KJS-03) ;; sensor-board 23
     (48 rmarm-elbow-r-KJS-03) ;; sensor-board 24
     (50 lleg-knee-p-KJS-03) ;; sensor-board 25
     (52 rleg-knee-p-KJS-03) ;; sensor-board 26
     ;; (42 ("larm-shoulder" "KJS")) ;; sensor-board 21
     ;; (44 ("rarm-shoulder" "KJS")) ;; sensor-board 22
     ;; (46 ("lmarm-shoulder" "KJS")) ;; sensor-board 23
     ;; (48 ("rmarm-shoulder" "KJS")) ;; sensor-board 24
     ;; (50 ("lleg-crotch" "KJS")) ;; sensor-board 25
     ;; (52 ("rleg-crotch" "KJS")) ;; sensor-board 26
     )
    (("kxrl6r")		;; 18
     (:body :l6 :type :l6 :arm :j3 :marm :j3 :leg :j3
	    :backpack t :project-file "kxrl6"
	    :com-init-method (:rcb4-open :vid #x165c :pid #x0008 :parity 2)
	    :board :rcb4
	    ;; same as :arm2-open, pid:#x6015 for Akizuki, :vid #x0403
	    :interface-class rcb4-interface
	    )
     (2 :rarm-shoulder-y -1)    (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-p -1)    (5 :larm-shoulder-p -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rmarm-shoulder-y -1)   (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)  (11 :lmarm-shoulder-r 1)
     (12 :rmarm-elbow-r 1)      (13 :lmarm-elbow-r -1)
     (14 :rleg-crotch-y -1)     (15 :lleg-crotch-y -1)
     (16 :rleg-crotch-p 1)     (17 :lleg-crotch-p  1)
     (18 :rleg-knee-p -1)       (19 :lleg-knee-p -1)
     )
    (("kxrl6dy1")
     (:body :l6 :type :l6 :arm :j3 :marm :j3 :leg :j3 :head :d2 :neck t :backpack t)
     (2 :rarm-shoulder-y 1)    (3 :larm-shoulder-y 1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-r 1)        (7 :larm-elbow-r -1)
     (8 :rmarm-shoulder-y -1)   (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)  (11 :lmarm-shoulder-r 1)
     (12 :rmarm-elbow-r 1)      (13 :lmarm-elbow-r -1)
     (14 :rleg-crotch-y 1)     (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r  1)
     (18 :rleg-knee-r 1)       (19 :lleg-knee-r -1)
     ;;
     (22 :head-neck-y 1)
     (19 :head-gripper-p -1/2)
     (19 :head-gripper2-p -1/2)
     )
    (("kxrl6d1")
     (:body :l6 :type :l6 :arm :j3 :marm :j3 :leg :j3 :head :d1 :backpack t)
     (2 :rarm-shoulder-y 1)    (3 :larm-shoulder-y 1)
     (4 :rarm-shoulder-p -1)    (5 :larm-shoulder-p 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     (8 :rmarm-shoulder-y -1)   (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)  (11 :lmarm-shoulder-r 1)
     (12 :rmarm-elbow-r 1)      (13 :lmarm-elbow-r -1)
     (14 :rleg-crotch-y 1)     (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-p -1)     (17 :lleg-crotch-p  1)
     (18 :rleg-knee-p 1)       (19 :lleg-knee-p -1)
     ;;
     (20 :head-neck-y 1)
     (22 :head-neck-p 1)
     (23 :head-gripper-p -1/2)
     (23 :head-gripper2-p -1/2)
     )
    (("kxrl6d2")
     (:body :l6 :type :l6 :arm :j3 :marm :j3 :leg :j3 :head :d2 :backpack t)
     (2 :rarm-shoulder-y 1)    (3 :larm-shoulder-y 1)
     (4 :rarm-shoulder-p -1)    (5 :larm-shoulder-p 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     (8 :rmarm-shoulder-y -1)   (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)  (11 :lmarm-shoulder-r 1)
     (12 :rmarm-elbow-r 1)      (13 :lmarm-elbow-r -1)
     (14 :rleg-crotch-y 1)     (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-p -1)     (17 :lleg-crotch-p  1)
     (18 :rleg-knee-p 1)       (19 :lleg-knee-p -1)
     ;;
     (0 :head-neck-y -1)
     (1 :head-neck-p -1)
     (20 :head-head-p 1)
     (21 :head-gripper-p 1/2)  (21 :head-gripper2-p 1/2)
     )
    (("kxrl6a2")
     (:body :l6 :type :l6 :arm :j2 :marm :j2 :leg :j2 :head :h2s :backpack t)
     (2 :rarm-shoulder-y -1)     (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)     (5 :larm-shoulder-r -1)
     (8 :rmarm-shoulder-y -1)    (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)   (11 :lmarm-shoulder-r 1)
     (14 :rleg-crotch-y -1)      (15 :lleg-crotch-y -1)
     (16 :rleg-crotch-r  1)      (17 :lleg-crotch-r  1)
     )
    (("kxrl6b")
     (:body :l6 :type :l6 :arm :j1w :marm :j3 :leg :j2 :head :d :backpack t)
     (2 :rarm-shoulder-y -1)     (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-w -1)     (5 :larm-shoulder-w -1)
     (8 :rmarm-shoulder-y -1)    (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)   (11 :lmarm-shoulder-r 1)
     (12 :rmarm-elbow-r -1)      (13 :lmarm-elbow-r 1)
     (14 :rleg-crotch-y -1)      (15 :lleg-crotch-y -1)
     (16 :rleg-crotch-r  1)      (17 :lleg-crotch-r  1)
     )
    (("kxrl6b1")
     (:body :l6 :type :l6 :arm :j1w :marm :j3 :leg :j2 :head :d1 :backpack t)
     (2 :rarm-shoulder-y -1)     (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-w -1)     (5 :larm-shoulder-w -1)
     (8 :rmarm-shoulder-y -1)    (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)   (11 :lmarm-shoulder-r 1)
     (12 :rmarm-elbow-r -1)      (13 :lmarm-elbow-r 1)
     (14 :rleg-crotch-y -1)      (15 :lleg-crotch-y -1)
     (16 :rleg-crotch-r  1)      (17 :lleg-crotch-r  1)
     )
    (("kxrl6b2")
     (:body :l6 :type :l6 :arm :j1w :marm :j3 :leg :j2 :head :d2 :backpack t)
     (2 :rarm-shoulder-y -1)     (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-w -1)     (5 :larm-shoulder-w -1)
     (8 :rmarm-shoulder-y -1)    (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)   (11 :lmarm-shoulder-r 1)
     (12 :rmarm-elbow-r -1)      (13 :lmarm-elbow-r 1)
     (14 :rleg-crotch-y -1)      (15 :lleg-crotch-y -1)
     (16 :rleg-crotch-r  1)      (17 :lleg-crotch-r  1)
     )
    (("kxrl6c")
     (:body :l6 :type :l6 :arm :j1w :marm :j3 :leg :j1w :head :h2s :backpack t)
     (2 :rarm-shoulder-y -1)     (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-w -1)     (5 :larm-shoulder-w -1)
     (8 :rmarm-shoulder-y -1)    (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)   (11 :lmarm-shoulder-r 1)
     (12 :rmarm-elbow-r -1)   (13 :lmarm-elbow-r 1)
     (14 :rleg-crotch-y -1)      (15 :lleg-crotch-y -1)
     (16 :rleg-crotch-w  1)      (17 :lleg-crotch-w  1)
     )
    (("kxrl6c1")
     (:body :l6 :type :l6 :arm :j1w :marm :j3 :leg :j1w :head :d1 :backpack t)
     (2 :rarm-shoulder-y -1)     (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-w -1)     (5 :larm-shoulder-w -1)
     (8 :rmarm-shoulder-y -1)    (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)   (11 :lmarm-shoulder-r 1)
     (12 :rmarm-elbow-r -1)   (13 :lmarm-elbow-r 1)
     (14 :rleg-crotch-y -1)      (15 :lleg-crotch-y -1)
     (16 :rleg-crotch-w  1)      (17 :lleg-crotch-w  1)
     )
    (("kxrl6c2")
     (:body :l6 :type :l6 :arm :j1w :marm :j3 :leg :j1w :head :d2 :backpack t)
     (2 :rarm-shoulder-y -1)     (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-w -1)     (5 :larm-shoulder-w -1)
     (8 :rmarm-shoulder-y -1)    (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)   (11 :lmarm-shoulder-r 1)
     (12 :rmarm-elbow-r -1)   (13 :lmarm-elbow-r 1)
     (14 :rleg-crotch-y -1)      (15 :lleg-crotch-y -1)
     (16 :rleg-crotch-w  1)      (17 :lleg-crotch-w  1)
     )
    (("kxrl6dw")
     (:body :l6 :type :l6 :arm :j2 :marm :j3 :leg :j1w :head :d :backpack t)
     (2 :rarm-shoulder-y -1)     (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)     (5 :larm-shoulder-r -1)
     (8 :rmarm-shoulder-y -1)    (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)   (11 :lmarm-shoulder-r 1)
     (12 :rmarm-elbow-r -1)   (13 :lmarm-elbow-r 1)
     (14 :rleg-crotch-y -1)      (15 :lleg-crotch-y -1)
     (16 :rleg-crotch-w  1)      (17 :lleg-crotch-w  1)
     (22 :head-neck-p 1)
     (19 :head-gripper-p -1/2)
     (19 :head-gripper2-p -1/2)
     )
    (("kxrl6d1w")
     (:body :l6 :type :l6 :arm :j2 :marm :j3 :leg :j1w :head :d1 :backpack t)
     (2 :rarm-shoulder-y -1)     (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)     (5 :larm-shoulder-r -1)
     (8 :rmarm-shoulder-y -1)    (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)   (11 :lmarm-shoulder-r 1)
     (12 :rmarm-elbow-r -1)   (13 :lmarm-elbow-r 1)
     (14 :rleg-crotch-y -1)      (15 :lleg-crotch-y -1)
     (16 :rleg-crotch-w  1)      (17 :lleg-crotch-w  1)
     (22 :head-neck-p 1)
     (19 :head-gripper-p -1/2)
     (19 :head-gripper2-p -1/2)
     )
    (("kxrl6d2w")
     (:body :l6 :type :l6 :arm :j2 :marm :j3 :leg :j1w :head :d2 :backpack t)
     (2 :rarm-shoulder-y -1)     (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)     (5 :larm-shoulder-r -1)
     (8 :rmarm-shoulder-y -1)    (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)   (11 :lmarm-shoulder-r 1)
     (12 :rmarm-elbow-r -1)   (13 :lmarm-elbow-r 1)
     (14 :rleg-crotch-y -1)      (15 :lleg-crotch-y -1)
     (16 :rleg-crotch-w  1)      (17 :lleg-crotch-w  1)
     (22 :head-neck-p 1)      (23 :head-neck-p 1)
     (19 :head-gripper-p -1/2)
     (19 :head-gripper2-p -1/2)
     )
    (("kxrl6e")
     (:body :l6 :type :l6 :arm :j1w :marm :j1w :leg :j1w :head :e :backpack t)
     (2 :rarm-shoulder-y -1)     (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-w -1)     (5 :larm-shoulder-w -1)
     (8 :rmarm-shoulder-y -1)    (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-w -1)   (11 :lmarm-shoulder-w 1)
     (14 :rleg-crotch-y -1)      (15 :lleg-crotch-y -1)
     (16 :rleg-crotch-w  1)      (17 :lleg-crotch-w 1)
     )
    ;;
    (("kxrl4tm")
     (:body :l4t :type :l4 :arm :j2 :leg :j2 :head :h2s
	    :project-file "kxrl4tm")
     (32 :head-neck-y -1)
     (24 :rarm-shoulder-y -1)  (25 :Larm-shoulder-y -1)
     (8  :rarm-shoulder-r -1)  (9 :larm-shoulder-r 1)
     (20 :rleg-crotch-y -1)    (21 :lleg-crotch-y -1)
     (16 :rleg-crotch-r -1)    (17 :lleg-crotch-r 1)
     )
    (("kxrl4tus")
     (:body :l4t :type :l4 :arm :j2 :leg :j2 :head :m5us
	    :project-file "kxrl4t"
	    ;;:board :armh7 :com-init-method (:arm2-open)
	    )
     (0 :head-neck-y -1)
     (2 :rarm-shoulder-y -1)  (3 :Larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (10 :head-neck-p -1)
     )
    (("kxrl4tvs")
     (:body :l4t :type :l4 :arm :j2 :leg :j2 :head :h2sn
	    :project-file "kxrl4t"
	    ;; :board :armh7 :com-init-method (:arm2-open)
	    )
     (0 :head-neck-y -1)
     (2 :rarm-shoulder-y -1)  (3 :Larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (10 :head-neck-p -1)
     )
    (("kxrl4th2s")
     (:body :l4t :type :l4 :arm :j2 :leg :j2 :head :h2s
	    :project-file "kxrl4t"
	    ;; :board :armh7 :com-init-method (:arm2-open)
	    )
     (0 :head-neck-y -1)
     (2 :rarm-shoulder-y -1)  (3 :Larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     )
    (("kxrl4th3s")
     (:body :l4t :type :l4 :arm :j2 :leg :j2
	    :head :h2s :neck :y-p-r ;; :h3s
	    :project-file "kxrl4t"
	    )
     (0 :head-neck-y -1)
     (2 :rarm-shoulder-y -1)  (3 :Larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)

     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     (26 :head-neck-r -1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)
     )
    (("kxrl4th3sn")	;; 10
     (:body :l4t :type :l4
	    :head :h2sn :neck :y-p-r ;; :h3sn 
	    :arm :j2 :leg :j2
	    :project-file "kxrl4t"
	    )
     (0 :head-neck-p 1)       (1 :head-neck-y -1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)

     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     (26 :head-neck-r -1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)
     )
    (("kxrl4t")		;; 9
     (:body :l4t :type :l4 :arm :j2 :leg :j2 :head :h1
	    :project-file "kxrl4t"
	    )
     (1 :head-neck-y -1)
     (2 :rarm-shoulder-y -1)  (3 :Larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     )
    ;;
    (("kxrl4th2")		;; 9
     (:body :l4t :type :l4 :arm :j2 :leg :j2 :head :h2
	    :project-file "kxrl4t"
	    :board :rcb4)
     (0 :head-neck-y 1)       (1 :head-neck-p -1)
     (2 :rarm-shoulder-y -1)  (3 :Larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     )
    (("kxrl4th2a")	;; 10
     (:body :l4t :type :l4 :head :m5sh :arm :j2 :leg :j2
	    :project-file "kxrl4t"
	    )
     (10 :head-neck-p -1)      (0 :head-neck-y -1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     )
    (("kxrl4t5s")		;; 9
     (:body :l4t :type :l4 :arm :j2 :leg :j2 :head :h2sh
	    :project-file "kxrl4t"
	    )
     (0 :head-neck-y -1)      (1 :head-neck-p -1)
     (2 :rarm-shoulder-y -1)  (3 :Larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     )
    (("kxrl4r")		;; 9
     (:body :l4t :type :l4 :arm :j1w :leg :j1w :head :h2s
	    )
     (0 :head-neck-y 1)	      (1 :head-neck-p 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-w -1)  (5 :larm-shoulder-w 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-w -1)    (9 :lleg-crotch-w 1)
     )
    (("kxrw4")		;; 9
     (:body :l4t :type :l4 :arm :j1w :leg :j1w :head :h2s
	    )
     (0 :larm-shoulder-w -1)  (1 :rarm-shoulder-w 1)
     (2 :lleg-crotch-w -1)    (3 :rleg-crotch-w 1)
     )
    (("kxrmw4")		;; mecanum wheel base
     (
      :file "models/kxrmw4.l" :form (kxrmw4)
      :body :l4mw :type :l4 :leg :j2m ;; :marm :j0m :leg :j0m
      :shoulder :pry-cross  :shoulder-center t
      :shoulder-front nil :shoulder-low nil :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y :lidar t
      :gripper-sensor (:finger1 :rev-a) 
      :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t :wheel-servo-stand t
      :head :d405eyes :3eye-rev 8 :3eye-front t :3eye-cover t :head-length 20
      :m5stickv nil
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1 )
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (0 :rleg-crotch-w 1)   (1 :lleg-crotch-w -1)
     (20 :rleg-knee-w 1)     (21 :lleg-knee-w -1)
     
     (8 :rarm-shoulder-y 1)     (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     ;;(38 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 19
     ;;(40 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 20
     )
    (("kuromitsu")
     (
      :body :l4mw-kuro :type :l4 :leg :j2m
      :shoulder t :shoulder-front t :shoulder-low nil :flat-shoulder t
      ;;:body-x 220 :body-y 250 :body-z 150
      :radius 60
      :wheel-battery-stand t :wheel-base-a t :wheel-base-wide nil :wheel-servo-stand t
      :head :d405eyes-iris :head-length 20
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1 )
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (0 :rleg-crotch-w 1)   (1 :lleg-crotch-w -1)
     (20 :rleg-knee-w 1)     (21 :lleg-knee-w -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    (("kashiwagi")
     (
      :body :l4mw-kashi :type :l4 :leg :j2m
	    :shoulder :kashiwagi-p-r :shoulder-front t :shoulder-low nil :flat-shoulder t
	    ;;:body-x 200 :body-y 250 :body-z 200
	    :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t :wheel-servo-stand nil
	    ;;:head :d405eyes-iris :head-length 20
	    :head :kashiwagi :head-length 20
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (0 :rleg-crotch-w 1)   (1 :lleg-crotch-w -1)
     (20 :rleg-knee-w 1)     (21 :lleg-knee-w -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    (("kxrmw4a7") ;; mecanum wheel base with 7DOF arm
     (
      :file "models/kxrmw4a7.l" :form (kxrmw4a7)
      :body :l4mw :type :l4 :leg :j2m ;; :marm :j0m :leg :j0m
      :shoulder :ypry-cross :shoulder-center nil
      :shoulder-front t :shoulder-low nil :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y :lidar t
      :gripper-sensor (:finger1 :rev-a) 
      :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t :wheel-servo-stand t
      ;;:head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t :head-length 20
      :head :m3deye :3eye-rev 10 :3eye-cover t :head-length 20
      :m5stickv nil
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1 )
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (0 :rleg-crotch-w 1)    (1 :lleg-crotch-w -1)
     (20 :rleg-knee-w 1)     (21 :lleg-knee-w -1)
     
     (22 :rarm-shoulder-y 1 -88) (23 :larm-shoulder-y  1 88)
     (8 :rarm-elbow-y 1)     (9 :larm-elbow-y  1)

     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     ;;(38 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 19
     ;;(40 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 20
     )
    (("kxrow4")		;; omuni wheel base
     (
      :file "models/kxrow4.l" :form (kxrow4)
      ;;:file "models/kxrow4inaba.l" :form (kxrow4inaba)
      :body :l4ow :type :l4 :leg :j2o
      :shoulder :pry-cross :shoulder-center t :lidar t
      :shoulder-low nil :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor (:finger1 :rev-c) 
      :wheel-battery-stand nil :wheel-base-a t
      :head :m3deye :3eye-rev 10 :head-lidar t :3eye-cover t :head-length 20
      :m5stickv nil
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1 )
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-w 1)     (15 :lleg-crotch-w 1)
     (16 :rleg-knee-w 1)       (17 :lleg-knee-w 1)
     
     (8 :rarm-shoulder-y 1)     (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 larm-gripper-r-KJS-03) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-03) ;; sensor-board 20
     ;;(38 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 19
     ;;(40 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 20
     )
    (("kxrow4a7") ;; omuni wheel base with 7DOF arm
     (
      :file "models/kxrow4a7.l" :form (kxrow4a7)
      :body :l4ow :type :l4 :leg :j2o
      :shoulder :ypry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor (:finger1 :rev-a) 
      :wheel-battery-stand t :wheel-base-a t :lidar t
      :head :m3deye :3eye-rev 10 :3eye-cover t :head-length 20
      ;;:head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t :head-length 20
      :m5stickv nil
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1 )
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-w 1)     (15 :lleg-crotch-w 1)
     (16 :rleg-knee-w 1)       (17 :lleg-knee-w 1)
     
     (22 :rarm-shoulder-y 1 -88) (23 :larm-shoulder-y  1 88)
     (8 :rarm-elbow-y 1)     (9 :larm-elbow-y  1)

     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     ;;(38 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 19
     ;;(40 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 20
     )
    (("kxrdw4a6h2m")		;; dual wheel and dual passive omuni wheel
     (
      :body :l4dw :type :l4 :leg :j2d
      :shoulder :pry-cross :shoulder-center t
      :shoulder-front nil :shoulder-low nil :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y :lidar t
      :gripper-sensor (:finger1 :rev-a) 
      :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t :wheel-servo-stand t
      :head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t :head-length 20
      :m5stickv nil
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1 )
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-w 1)     (15 :lleg-crotch-w 1)
     
     (8 :rarm-shoulder-y 1)     (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     ;;(38 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 19
     ;;(40 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 20
     )
    (("kxrdw4a7h2m")		;; dual wheel and dual passive omuni wheel
     (
      :body :l4dw :type :l4 :leg :j2d
      :shoulder :ypry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y :lidar t
      :gripper-sensor (:finger1 :rev-a) 
      :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t :wheel-servo-stand t
      :head :d405echos
      ;;:head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t :head-length 20
      :m5stickv nil
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1 )
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-w 1)     (15 :lleg-crotch-w 1)
     
     (22 :rarm-shoulder-y 1 -88) (23 :larm-shoulder-y  1 88)
     (8 :rarm-elbow-y 1)     (9 :larm-elbow-y  1)

     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     ;;(38 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 19
     ;;(40 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 20
     )
    (("guiga")
     (:body :l4t :type :l4 :arm :j1w :leg :j1w :head :h1
	    )
     (0 :head-neck-y -1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-w -1)  (5 :larm-shoulder-w 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-w -1)    (9 :lleg-crotch-w 1)
     )
    (("kxrl4rus")		;; 9
     (:body :l4t :type :l4 :arm :j1w :leg :j1w :head :m5us
	    :board :armh7
	    )
     (0 :head-neck-y 1)	      (1 :head-neck-p 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-w -1)  (5 :larm-shoulder-w 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-w -1)    (9 :lleg-crotch-w 1)
     )
    (("kxrl4rvs")		;; 9
     (:body :l4t :type :l4 :arm :j1w :leg :j1w
	    :head :h2sn :neck :y-p-r ;; :h3sn
	    :board :armh7
	    )
     (0 :head-neck-y 1)	      (1 :head-neck-p 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-w -1)  (5 :larm-shoulder-w 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-w -1)    (9 :lleg-crotch-w 1)
     )
    (("kxrl4rh2s")
     (:body :l4t :type :l4 :arm :j1w :leg :j1w :head :h2s
	    :board :armh7
	    )
     (0 :head-neck-y 1)	      (1 :head-neck-p 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-w -1)  (5 :larm-shoulder-w 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-w -1)    (9 :lleg-crotch-w 1)
     )
    (("kxrl4rh3s")
     (:body :l4t :type :l4 :arm :j1w :leg :j1w
	    :head :h2s :neck :y-p-r ;; :h3s
	    :board :armh7
	    )
     (0 :head-neck-y 1)	      (1 :head-neck-p 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-w -1)  (5 :larm-shoulder-w 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-w -1)    (9 :lleg-crotch-w 1)
     )
    (("kxrr4")		;; 9
     (:body :l4t :type :l4 :arm :j1w :leg :j1w :head :h2s
	    :project-file "kxrl4r")
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-w -1)  (5 :larm-shoulder-w 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-w -1)    (9 :lleg-crotch-w 1)
     )
    (("kxrr4m")		;; 9
     (:body :l4t :type :l4 :arm :j1w :leg :j1w :head :h1
	    :project-file "kxrl4r")
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-w -1)  (5 :larm-shoulder-w 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-w -1)    (9 :lleg-crotch-w 1)
     )
    (("kxrl4r2a3" "kxrl4r2a3h")
     (:body :l4t :type :l4 :arm :j3 :leg :j1w :head :h2sn)
     (1 :head-neck-y -1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (10 :rarm-shoulder-r 1)  (11 :larm-shoulder-r 1)
     (12 :rarm-elbow-r -1)    (13 :larm-elbow-r -1)

     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-w  1)    (9 :lleg-crotch-w -1)
     )
    (("kxrl4r2a3h2")
     (:body :l4t :type :l4 :arm :j3 :leg :j1w :head :e)
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (10 :rarm-shoulder-r 1)  (11 :larm-shoulder-r -1)
     (12 :rarm-elbow-r -1)    (13 :larm-elbow-r 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-w -1)    (9 :lleg-crotch-w 1)
     )
    (("kxrl4r2a3g")
     (:body :l4t :type :l4 :arm :j3 :leg :j1w :head :h2s :gripper-inner t :gripper-sensor :larm
	    :board :armh7
	    :passive-wheel :shoulder)
     (0  :head-neck-y -1)
     (2  :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (10 :rarm-shoulder-r 1) (11 :larm-shoulder-r 1)
     (12 :rarm-elbow-r -1)    (13 :larm-elbow-r -1)
     (18 :rarm-gripper-r -1/2)  (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2) (19 :larm-gripper2-r -1/2)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-w 1)    (9 :lleg-crotch-w -1)
     ;;
     (38 larm-gripper2-r-KJS-03) ;; sensor-board 19
     (40 larm-gripper-r-KJS-03) ;; sensor-board 20
     ;;(38 ("larm-elbow" "gripper-" "KJS")) ;; sensor-board 19
     ;;(40 ("larm-elbow" "gripper2" "KJS")) ;; sensor-board 20
     )
    (("kxrl4r2a3gr")
     (:body :l4t :type :l4 :arm :j3 :leg :j1w :head :h2s :gripper-inner :rarm :passive-wheel :shoulder)
     (0  :head-neck-y -1)
     (2  :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (10 :rarm-shoulder-r 1) (11 :larm-shoulder-r 1)
     (12 :rarm-elbow-r -1)    (13 :larm-elbow-r -1)
     (18 :rarm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-w 1)    (9 :lleg-crotch-w -1)
     )
    (("kxrl4r2a3gl")
     (:body :l4t :type :l4 :arm :j3 :leg :j1w :head :realsense :gripper-inner :larm
	    :board :armh7
	    :gripper-sensor :finger2 :passive-wheel :shoulder)
     (1  :head-neck-y -1)
     (2  :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (10 :rarm-shoulder-r 1) (11 :larm-shoulder-r 1)
     (12 :rarm-elbow-r -1)    (13 :larm-elbow-r -1)
     (19 :larm-gripper-r -1/2)
     (19 :larm-gripper2-r -1/2)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-w 1)    (9 :lleg-crotch-w -1)
     )
    (("kxrl4r2l3")
     (:body :l4t :type :l4 :arm :j1w :leg :j3 :head :m5us :passive-wheel :shoulder)
     (0  :head-neck-y 1)
     (2  :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (10 :rarm-shoulder-w -1)  (11 :larm-shoulder-w -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-w -1)    (9 :lleg-crotch-w 1)
     )
    (("kxrl4l3a3")
     (:body :l4t :type :l4 :arm :j3 :leg :j3 :head :m5s)
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (10 :rarm-elbow-r -1)    (11 :larm-elbow-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (12 :rleg-knee-r -1)     (13 :lleg-knee-r 1)
     )
    (("kxrl4l3a3g")
     (:body :l4t :type :l4 :arm :j3 :leg :j3 :head :h1 :gripper t)
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (10 :rarm-elbow-r -1)    (11 :larm-elbow-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (12 :rleg-knee-r -1)     (13 :lleg-knee-r 1)
     )
    (("kxrl4l3a3gi")
     (:body :l4t :type :l4 :arm :j3 :leg :j3 :head :h1 :gripper-inner t)
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (10 :rarm-elbow-r -1)    (11 :larm-elbow-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (12 :rleg-knee-r -1)     (13 :lleg-knee-r 1)
     )
    (("kxrl4l3a3gil")
     (:body :l4t :type :l4 :arm :j3 :leg :j3 :head :h1 :gripper-inner (:larm :lleg))
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (10 :rarm-elbow-r -1)    (11 :larm-elbow-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (12 :rleg-knee-r -1)     (13 :lleg-knee-r 1)
     )
    (("kxrl4l3a3ga")
     (:body :l4t :type :l4 :arm :j3 :leg :j3 :head :h1 :gripper (:larm :rarm))
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (10 :rarm-elbow-r -1)    (11 :larm-elbow-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (12 :rleg-knee-r -1)     (13 :lleg-knee-r 1)
     )
    (("kxrl4l3a3gb")
     (:body :l4t :type :l4 :arm :j3 :leg :j3 :head :h1 :gripper (:lleg :rleg))
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (10 :rarm-elbow-r -1)    (11 :larm-elbow-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (12 :rleg-knee-r -1)     (13 :lleg-knee-r 1)
     )
    (("kxrl4l3a3gl")
     (:body :l4t :type :l4 :arm :j3 :leg :j3 :head :h1 :gripper (:lleg :larm))
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (10 :rarm-elbow-r -1)    (11 :larm-elbow-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (12 :rleg-knee-r -1)     (13 :lleg-knee-r 1)
     )
    (("kxrl4l3a3gc")
     (:body :l4t :type :l4 :arm :j3 :leg :j3 :head :h1 :gripper (:lleg :rarm))
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (10 :rarm-elbow-r -1)    (11 :larm-elbow-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (12 :rleg-knee-r -1)     (13 :lleg-knee-r 1)
     )
    (("kxrl4l3a3gd")
     (:body :l4t :type :l4 :arm :j3 :leg :j3 :head :h1 :gripper (:rleg :larm))
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (10 :rarm-elbow-r -1)    (11 :larm-elbow-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (12 :rleg-knee-r -1)     (13 :lleg-knee-r 1)
     )
    (("kxrl4l3a3gr")
     (:body :l4t :type :l4 :arm :j3 :leg :j3 :head :h1 :gripper (:rarm :rleg))
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (10 :rarm-elbow-r -1)    (11 :larm-elbow-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (12 :rleg-knee-r -1)     (13 :lleg-knee-r 1)
     )
    (("kxrl4l3a3ia")
     (:body :l4t :type :l4 :arm :j3 :leg :j3 :head :h1 :gripper-inner (:larm :rarm))
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (10 :rarm-elbow-r -1)    (11 :larm-elbow-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (12 :rleg-knee-r -1)     (13 :lleg-knee-r 1)
     )
    (("kxrl4l3a3ib")
     (:body :l4t :type :l4 :arm :j3 :leg :j3 :head :h1 :gripper-inner (:lleg :rleg))
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (10 :rarm-elbow-r -1)    (11 :larm-elbow-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (12 :rleg-knee-r -1)     (13 :lleg-knee-r 1)
     )
    (("kxrl4l3a3il")
     (:body :l4t :type :l4 :arm :j3 :leg :j3 :head :h1 :gripper-inner (:lleg :larm))
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (10 :rarm-elbow-r -1)    (11 :larm-elbow-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (12 :rleg-knee-r -1)     (13 :lleg-knee-r 1)
     )
    (("kxrl4l3a3ic")
     (:body :l4t :type :l4 :arm :j3 :leg :j3 :head :h1 :gripper-inner (:lleg :rarm))
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (10 :rarm-elbow-r -1)    (11 :larm-elbow-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (12 :rleg-knee-r -1)     (13 :lleg-knee-r 1)
     )
    (("kxrl4l3a3id")
     (:body :l4t :arm :j3 :leg :j3 :head :h1 :gripper-inner (:rleg :larm))
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (10 :rarm-elbow-r -1)    (11 :larm-elbow-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (12 :rleg-knee-r -1)     (13 :lleg-knee-r 1)
     )
    (("kxrl4l3a3ir")
     (:body :l4t :arm :j3 :leg :j3 :head :h1 :gripper-inner (:rarm :rleg))
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (10 :rarm-elbow-r -1)    (11 :larm-elbow-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     (12 :rleg-knee-r -1)     (13 :lleg-knee-r 1)
     )
    (("kxrl4c")
     (:body :l4d :marm :j4 :leg :j4 :head :m5sh :torso :ly-p
	    :board :armh7 :shoulder :ly-p-r :wrist :r :gripper t)
     ;;(0 :head-neck-y 1)
     (2 :rarm-shoulder-p -1)  (3 :larm-shoulder-p -1)
     (6 :rarm-shoulder-r -1)  (7 :larm-shoulder-r -1)
     (8 :rarm-shoulder-y -1)  (9 :larm-shoulder-y -1)
     (10 :rarm-elbow-p -1)    (11 :larm-elbow-p -1)
     (12 :rarm-wrist-r -1)    (13 :larm-wrist-r -1)
     (14 :rarm-gripper-r  1/2) (15 :larm-gripper-r 1/2)
     (14 :rarm-gripper2-r 1/2) (15 :larm-gripper2-r 1/2)
     
     (0 :rarm-elbow-y 1)       (1 :larm-elbow-y  1)
     (32 :rarm-wrist-y 1)      (34 :larm-wrist-y 1)

     (4 :rmarm-shoulder-p 1)   (5 :lmarm-shoulder-p -1)
     (18 :rmarm-shoulder-r -1)  (19 :lmarm-shoulder-r 1)
     (20 :rmarm-elbow-p 1)      (21 :lmarm-elbow-p 1)
     (22 :rmarm-wrist-p 1)      (23 :lmarm-wrist-p 1)

     (24 :rleg-crotch-p 1)    (25 :lleg-crotch-p -1)
     (26 :rleg-crotch-r -1)   (27 :lleg-crotch-r 1)
     (28 :rleg-knee-p -1)     (29 :lleg-knee-p -1)
     (30 :rleg-ankle-p -1)    (31 :lleg-ankle-p -1)

     (16 :torso-chest-y 1)   (17 :torso-chest-p 1)
     (33 :head-neck-p 1)
     )
    (("kxrl4ch")
     (:body :l4d :marm :j4 :leg :j4 :head :m5sh :torso :ly-p
	    :shoulder :ly-p-r :wrist :r :gripper-inner t)

     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)     
     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)

     (0 :rmarm-shoulder-p 1)   (1 :lmarm-shoulder-p -1)
     (8 :rmarm-shoulder-r -1)  (9 :lmarm-shoulder-r 1)
     (10 :rmarm-elbow-p 1)     (11 :lmarm-elbow-p 1)
     (12 :rmarm-wrist-p 1)     (13 :lmarm-wrist-p 1)

     (14 :rleg-crotch-p 1)    (15 :lleg-crotch-p -1)
     (16 :rleg-crotch-r -1)   (17 :lleg-crotch-r 1)
     (20 :rleg-knee-p -1)     (21 :lleg-knee-p -1)
     (24 :rleg-ankle-p -1)    (25 :lleg-ankle-p -1)

     (32 :torso-chest-y 1)   (34 :torso-chest-p 1)
     (33 :head-neck-p 1)
     )
    (("kxrl4c2")
     (:body :l4t :type :l4 :marm :j2 :leg :j2 :head :h2sh :torso :ly-p
	    :shoulder :ly-p-r :wrist :r :gripper-inner t)
     ;;(0 :head-neck-y 1)
     (2 :rarm-shoulder-p -1)  (3 :larm-shoulder-p -1)
     (6 :rarm-shoulder-r -1)  (7 :larm-shoulder-r -1)
     (8 :rarm-shoulder-y -1)  (9 :larm-shoulder-y -1)
     (10 :rarm-elbow-p -1)    (11 :larm-elbow-p -1)
     (24 :rarm-wrist-r -1)    (25 :larm-wrist-r -1)
     (26 :rarm-gripper-r  1/2) (27 :larm-gripper-r 1/2)
     (26 :rarm-gripper2-r 1/2) (27 :larm-gripper2-r 1/2)

     (12 :rmarm-shoulder-y -1) (13 :lmarm-shoulder-y -1)
     (14 :rmarm-shoulder-r -1) (15 :lmarm-shoulder-r -1)
     (16 :rleg-crotch-y -1)    (17 :lleg-crotch-y -1)
     (18 :rleg-crotch-r -1)    (19 :lleg-crotch-r 1)

     (30 :torso-chest-y 1)   (31 :torso-chest-p 1)
     (33 :head-neck-p 1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)
     )
    (("kxrl4c3")
     (:body :l4t :type :l4 :marm :j3 :leg :j3 :head :h2sh :torso :ly-p
	    :shoulder :ly-p-r :wrist :r :gripper-inner (:larm :rarm))
     ;;(0 :head-neck-y 1)
     (2 :rarm-shoulder-p -1)  (3 :larm-shoulder-p -1)
     (6 :rarm-shoulder-r -1)  (7 :larm-shoulder-r -1)
     (8 :rarm-shoulder-y -1)  (9 :larm-shoulder-y -1)
     (10 :rarm-elbow-p -1)    (11 :larm-elbow-p -1)
     (26 :rarm-gripper-r  1/2) (27 :larm-gripper-r 1/2)
     (26 :rarm-gripper2-r 1/2) (27 :larm-gripper2-r 1/2)

     (12 :rmarm-shoulder-y -1) (13 :lmarm-shoulder-y -1)
     (14 :rmarm-shoulder-r -1) (15 :lmarm-shoulder-r -1)
     (22 :rmarm-elbow-r -1)    (23 :lmarm-elbow-r -1)
     (16 :rleg-crotch-y -1)    (17 :lleg-crotch-y -1)
     (18 :rleg-crotch-r -1)    (19 :lleg-crotch-r 1)
     (24 :rleg-knee-r -1)     (25 :lleg-knee-r 1)

     (30 :torso-chest-y 1)   (31 :torso-chest-p 1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)
     )
    (("kxrl4c3b")
     (:body :l4t :type :l2 :marm :j3 :leg :j3 :head :h2sh :torso :ly-p
	    :shoulder :ly-p-r :wrist :r :gripper-inner t)
     ;;(0 :head-neck-y 1)   (1 :head-neck-p 1)
     (2 :rarm-shoulder-p -1)  (3 :larm-shoulder-p -1)
     (6 :rarm-shoulder-r -1)  (7 :larm-shoulder-r -1)
     (8 :rarm-shoulder-y -1)  (9 :larm-shoulder-y -1)
     (10 :rarm-elbow-p -1)    (11 :larm-elbow-p -1)
     (26 :rarm-gripper-r  1/2) (27 :larm-gripper-r 1/2)
     (26 :rarm-gripper2-r 1/2) (27 :larm-gripper2-r 1/2)

     (12 :rmarm-shoulder-y -1) (13 :lmarm-shoulder-y -1)
     (14 :rmarm-shoulder-r -1) (15 :lmarm-shoulder-r -1)
     (22 :rmarm-elbow-r -1)    (23 :lmarm-elbow-r -1)
     (16 :rleg-crotch-y -1)    (17 :lleg-crotch-y -1)
     (18 :rleg-crotch-r -1)    (19 :lleg-crotch-r 1)
     (24 :rleg-knee-r -1)     (25 :lleg-knee-r 1)
     (30 :torso-chest-y 1)   (31 :torso-chest-p 1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)
     )
    (("kxrl4cw")
     (:body :l4t :type :l2 :marm :j1w :leg :j1w :head :h2sh :torso :ly-p
	    :shoulder :ly-p-r :wrist :r :gripper-inner t)
     ;;(0 :head-neck-p 1)  (1 :head-neck-y 1)
     (2 :rarm-shoulder-p -1)  (3 :larm-shoulder-p -1)
     (6 :rarm-shoulder-r -1)  (7 :larm-shoulder-r -1)
     (8 :rarm-shoulder-y -1)  (9 :larm-shoulder-y -1)
     (26 :rarm-elbow-y -1)    (27 :larm-elbow-y -1)
     (10 :rarm-elbow-p -1)    (11 :larm-elbow-p -1)
     (28 :rarm-wrist-r -1)    (29 :larm-wrist-r -1)

     (12 :rmarm-shoulder-y -1) (13 :lmarm-shoulder-y -1)
     (14 :rmarm-shoulder-w -1) (15 :lmarm-shoulder-w -1)
     (16 :rleg-crotch-y -1)    (17 :lleg-crotch-y -1)
     (18 :rleg-crotch-w -1)    (19 :lleg-crotch-w 1)

     (20 :rarm-gripper-r -1/2)  (21 :larm-gripper-r -1/2)
     (20 :rarm-gripper2-r -1/2) (21 :larm-gripper2-r -1/2)
     (30 :torso-chest-y 1)   (31 :torso-chest-p 1)

     (28 :head-leye-y -1)     (34 :head-reye-y -1)
     )
    (("kxrl4ct2a3h2")
     (:body :l4t :type :l2 :marm :j1w :leg :j1w 
	    :torso :y-p :shoulder :p
	    :head :d405eyes :neck-jf :b :gripper-inner t) ;; :h2s :d405
     (0 :head-neck-y 1)   (1 :head-neck-p 1)
     (2 :rarm-shoulder-p -1)  (3 :larm-shoulder-p -1)
     (6 :rarm-shoulder-r -1)  (7 :larm-shoulder-r -1)
     (8 :rarm-shoulder-y -1)  (9 :larm-shoulder-y -1)
     (10 :rarm-elbow-p -1)    (11 :larm-elbow-p -1)

     (12 :rmarm-shoulder-y -1) (13 :lmarm-shoulder-y -1)
     (14 :rmarm-shoulder-w -1) (15 :lmarm-shoulder-w -1)
     (16 :rleg-crotch-y -1)    (17 :lleg-crotch-y -1)
     (18 :rleg-crotch-w -1)    (19 :lleg-crotch-w 1)

     (20 :rarm-gripper-r -1/2)  (21 :larm-gripper-r -1/2)
     (20 :rarm-gripper2-r -1/2) (21 :larm-gripper2-r -1/2)
     (30 :torso-chest-y 1)   (31 :torso-chest-p 1)
     )
    (("kxrl4ct2a4pyrh2")
     (:body :l4t :type :l2 :marm :j1w :leg :j1w 
	    :torso :y-p :shoulder :cross
	    :head :m5sh :neck-jf :b :gripper-inner t)
     (0 :head-neck-y 1)   (1 :head-neck-p 1)
     (2 :rarm-shoulder-p -1)  (3 :larm-shoulder-p -1)
     (6 :rarm-shoulder-r -1)  (7 :larm-shoulder-r -1)
     (8 :rarm-shoulder-y -1)  (9 :larm-shoulder-y -1)
     (10 :rarm-elbow-p -1)    (11 :larm-elbow-p -1)

     (12 :rmarm-shoulder-y -1) (13 :lmarm-shoulder-y -1)
     (14 :rmarm-shoulder-w -1) (15 :lmarm-shoulder-w -1)
     (16 :rleg-crotch-y -1)    (17 :lleg-crotch-y -1)
     (18 :rleg-crotch-w -1)    (19 :lleg-crotch-w 1)

     (20 :rarm-gripper-r -1/2)  (21 :larm-gripper-r -1/2)
     (20 :rarm-gripper2-r -1/2) (21 :larm-gripper2-r -1/2)
     (30 :torso-chest-y 1)   (31 :torso-chest-p 1)
     )
    (("kxrl4ct2a4pryh2")
     (:body :l4t :type :l2 :marm :j1w :leg :j1w  ;; :type :l4 -> error
	    :torso :y-p :shoulder :p
	    :head :m5sh :neck-jf :b :gripper-inner t)
     (0 :head-neck-y 1)   (1 :head-neck-p 1)
     (2 :rarm-shoulder-p -1)  (3 :larm-shoulder-p -1)
     (6 :rarm-shoulder-r -1)  (7 :larm-shoulder-r -1)
     (8 :rarm-shoulder-y -1)  (9 :larm-shoulder-y -1)
     (10 :rarm-elbow-p -1)    (11 :larm-elbow-p -1)

     (12 :rmarm-shoulder-y -1) (13 :lmarm-shoulder-y -1)
     (14 :rmarm-shoulder-w -1) (15 :lmarm-shoulder-w -1)
     (16 :rleg-crotch-y -1)    (17 :lleg-crotch-y -1)
     (18 :rleg-crotch-w -1)    (19 :lleg-crotch-w 1)

     (20 :rarm-gripper-r -1/2)  (21 :larm-gripper-r -1/2)
     (20 :rarm-gripper2-r -1/2) (21 :larm-gripper2-r -1/2)
     (30 :torso-chest-y 1)   (31 :torso-chest-p 1)
     )
    (("kxrl4ct2a5pryh2")
     (:body :l4t :type :l4 :marm :j1w :leg :j1w 
	    :torso :y-p :shoulder :p :wrist :r
	    :head :m5sh :neck-jf :b :gripper-inner t)
     (0 :head-neck-y 1)   (1 :head-neck-p 1)
     (2 :rarm-shoulder-p -1)  (3 :larm-shoulder-p -1)
     (6 :rarm-shoulder-r -1)  (7 :larm-shoulder-r -1)
     (8 :rarm-elbow-p -1)     (9 :larm-elbow-p -1)
     (10 :rarm-wrist-r -1)    (11 :larm-wrist-r -1)

     (12 :rmarm-shoulder-y -1) (13 :lmarm-shoulder-y -1)
     (14 :rmarm-shoulder-w -1) (15 :lmarm-shoulder-w -1)
     (16 :rleg-crotch-y -1)    (17 :lleg-crotch-y -1)
     (18 :rleg-crotch-w -1)    (19 :lleg-crotch-w 1)

     (20 :rarm-gripper-r -1/2)  (21 :larm-gripper-r -1/2)
     (20 :rarm-gripper2-r -1/2) (21 :larm-gripper2-r -1/2)
     (30 :torso-chest-y 1)   (31 :torso-chest-p 1)
     )
    (("kxrl4ct2a5pyrh2")
     (:body :l4t :type :l4 :marm :j1w :leg :j1w 
	    :torso :y-p :shoulder :cross :wrist :r
	    :head :m5sh :neck-jf :b :gripper-inner t)
     (0 :head-neck-y 1)   (1 :head-neck-p 1)
     (2 :rarm-shoulder-p -1)  (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-y -1)  (5 :larm-shoulder-y -1)
     (6 :rarm-shoulder-r -1)  (7 :larm-shoulder-r -1)
     (8 :rarm-elbow-p -1)     (9 :larm-elbow-p -1)
     (10 :rarm-wrist-r -1)    (11 :larm-wrist-r -1)

     (12 :rmarm-shoulder-y -1) (13 :lmarm-shoulder-y -1)
     (14 :rmarm-shoulder-w -1) (15 :lmarm-shoulder-w -1)
     (16 :rleg-crotch-y -1)    (17 :lleg-crotch-y -1)
     (18 :rleg-crotch-w -1)    (19 :lleg-crotch-w 1)
     )
    (("kxrl4ct2a6h2")
     (:body :l4t :type :l4 :marm :j1w :leg :j1w 
	    :torso :y-p :shoulder :cross :wrist :cross
	    :head :m5sh :neck-jf :b :gripper-inner t)
     (0 :head-neck-y 1)
     (2 :rarm-shoulder-p -1)  (3 :larm-shoulder-p -1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p -1)    (7 :larm-elbow-p -1)
     (8 :rarm-wrist-p -1)    (9 :larm-wrist-p -1)
     (10 :rarm-wrist-r -1)    (11 :larm-wrist-r -1)
     (12 :rmarm-shoulder-y -1) (13 :lmarm-shoulder-y -1)
     (14 :rmarm-shoulder-w -1) (15 :lmarm-shoulder-w -1)
     (16 :rleg-crotch-y -1)    (17 :lleg-crotch-y -1)
     (18 :rleg-crotch-w -1)    (19 :lleg-crotch-w 1)
     )
    (("kxrl4ct2a7h2")
     (:body :l4t :type :l4 :marm :j1w :leg :j1w 
	    :torso :y-p :shoulder :cross :wrist :y-cross
	    :neck :y-r-p ;; :m5sh
	    :head :m3eye :3eye-rev 3 ;; :head :d405eyes 
	    :neck-jf :b :gripper-inner t)
     (0 :head-neck-y 1)      (1 :head-neck-p 1)
     (2 :rarm-shoulder-p -1)  (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p -1)    (7 :larm-elbow-p -1)
     (8 :rarm-wrist-p -1)    (9 :larm-wrist-p -1)
     (10 :rarm-wrist-r -1)    (11 :larm-wrist-r -1)
     (12 :rarm-wrist-r -1)    (13 :larm-wrist-r -1)
     (14 :rmarm-shoulder-y -1) (15 :lmarm-shoulder-y -1)
     (16 :rmarm-shoulder-w -1) (17 :lmarm-shoulder-w -1)
     (18 :rleg-crotch-y -1)    (19 :lleg-crotch-y -1)
     (20 :rleg-crotch-w -1)    (21 :lleg-crotch-w 1)
     )
    (("kxrl4l2a3g")
     (:body :l4t :type :l4 :arm :j3 :leg :j2 :head :h2s :gripper t :passive-wheel :shoulder :wrist-sensor nil)
     (0  :head-neck-y 1)
     (2  :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (10 :rarm-shoulder-r  1) (11 :larm-shoulder-r  1)
     (12 :rarm-elbow-r -1)    (13 :larm-elbow-r -1)
     (18 :rarm-gripper-r  1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2) (19 :larm-gripper2-r 1/2)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     )
    (("kxrl4rh")	;; 10
     (:body :l4t :type :l4 :head :h2s :arm :j1w :leg :j1w)
     (0 :head-neck-p 1)       (1 :head-neck-y 1)       
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-w -1)  (5 :larm-shoulder-w 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-w -1)    (9 :lleg-crotch-w 1)
     )
    (("kxrl4n")		;; 11
     (:body :l4t :type :l4 :head :h2s :arm :j2 :leg :j2)
     (2 :rarm-shoulder-y -1)  (3 :Larm-shoulder-y -1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)

     (22 :head-neck-p 1)
     (19 :head-gripper-p -1/2)
     (19 :head-gripper2-p -1/2)
     )
    (("kxrl4n1")	;; 12
     (:body :l4t :type :l4 :head :d1 :arm :j2 :leg :j2)
     (2 :rarm-shoulder-y -1)  (3 :Larm-shoulder-y -1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)

     (20 :head-neck-y 1) (22 :head-neck-p 1)
     (19 :head-gripper-p -1/2)
     (19 :head-gripper2-p -1/2)
     )
    (("kxrl4n2")	;; 12
     (:body :l4t :type :l4 :head :d2 :arm :j2 :leg :j2)
     (2 :rarm-shoulder-y -1)  (3 :Larm-shoulder-y -1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r -1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)

     (20 :head-neck-y 1) (22 :head-neck-p 1)
     (24 :head-head-p 1)
     (19 :head-gripper-p -1/2)
     (19 :head-gripper2-p -1/2)
     )
    (("kxrl4nh4-old")
     (:body :l4t :type :l4 :arm :j2 :leg :j2
	    :neck :y-p-p-p
	    )
     (11 :head-neck0-y 1)      (13 :head-neck0-p -1)
     (17 :head-neck1-p -1)      (21 :head-neck2-p 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     )
    (("kxrl4nh4")
     (:body :l4t :type :l4 :arm :j2 :leg :j2 ;; :head :h2s
	    :neck :y-p-p-p
	    )
     (11 :head-neck0-y 1)      (13 :head-neck0-p -1)
     (17 :head-neck1-p -1)      (21 :head-neck2-p 1)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     )
    (("kxrl4nh4g")
     (:body :l4t :type :l4 :arm :j2 :leg :j2
	    :neck :y-p-p-p
	    :head :gripper-y
	    )
     (11 :head-neck0-y 1)      (13 :head-neck0-p -1)
     (17 :head-neck1-p -1)      (21 :head-neck2-p 1)
     (19 :head-gripper-p 1/2)   (19 :head-gripper2-p 1/2)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     )
    (("kxrl4ng")
     (:body :l4t :type :l4 :arm :j2 :leg :j2
	    :head :gripper-y
	    )
     (19 :head-gripper-p 1/2)   (19 :head-gripper2-p 1/2)
     (2 :rarm-shoulder-y -1)  (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rleg-crotch-y -1)    (7 :lleg-crotch-y -1)
     (8 :rleg-crotch-r -1)    (9 :lleg-crotch-r 1)
     )
    (("kxrl4b1")
     (:body :l4b :type :l4 :head :h2s :neck :y-p-r ;; :y-r-p;; :h3sn
	    :arm :j4 :leg :j4
	    :stand t :leg-frontal t :tail :t2
	    :board :armh7 :project-file "kxrl4d"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-y -1)  (5 :larm-shoulder-y 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-y -1)   (13 :lleg-crotch-y 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     ;;
     ;;(1 :tail-roll-r 1) 
     (19 :tail-roll-p 1)
     ;;
     (0 :head-neck-y -1)  
     (32 :head-neck-p -1)
     (26 :head-neck-r -1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)
     )
    (("kxrl4b2")
     (:body :l4b :type :l4 :head :m5usv2 :neck :y-r-p;; :m5u3sv2
	    :arm :j4 :leg :j4 :lego-bar 15
	    :stand t :leg-frontal t :tail :t2 :project-file "kxrl4d"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-y -1)  (5 :larm-shoulder-y 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-y -1)   (13 :lleg-crotch-y 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     ;;
     (1 :tail-roll-r 1)      (19 :tail-roll-p 1)
     (0 :head-neck-y -1)    (30 :head-neck-r 1)
     (32 :head-neck-p -1)
     )
    (("kxrl4b21")
     (:body :l4b :type :l4 :head :m5us :neck :y-r-p;; :m5u3s
	    :arm :j4 :leg :j4
	    :stand t :leg-frontal t :tail :t2 :project-file "kxrl4d"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-y -1)  (5 :larm-shoulder-y 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-y -1)   (13 :lleg-crotch-y 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     ;;
     (1 :tail-roll-r 1)      (19 :tail-roll-p 1)
     (0 :head-neck-y -1)    (30 :head-neck-r 1)
     (32 :head-neck-p -1)
     )
    (("kxrl4b22")
     (:body :l4b :type :l4 :head :h2sn :neck :y-r-p ;; :h3sn
	    :arm :j4 :leg :j4
	    :stand t :leg-frontal t :tail :t2 :project-file "kxrl4d"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-y -1)  (5 :larm-shoulder-y 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-y -1)   (13 :lleg-crotch-y 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     ;;
     (1 :tail-roll-r 1)      (19 :tail-roll-p 1)
     (0 :head-neck-y -1)    (30 :head-neck-r 1)
     (32 :head-neck-p -1)
     )
    (("kxrl4b3")
     (:body :l4d :type :l4 :head :h2sn :neck :y-r-p;; :h3sn
	    :arm :j4 :leg :j4
	    :board :armh7 :project-file "kxrl4d"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)
     
     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     
     (0 :head-neck-r  -1)     (32 :head-neck-p 1)
     (26 :head-neck-y -1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)
     )
    (("kxrl4b4")
     (:body :l4d :type :l4 :head :m5us :neck :y-r-p;; :m5sh
	    :arm :j4 :leg :j4 ;; :m5u3s 
	    :board :armh7 :project-file "kxrl4d"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     ;;
     (1 :head-neck-r -1)  
     ;;     (31 :head-neck-y 1)
     (33 :head-neck-p 1)
     )
    (("kxrl4b2sn")
     (:body :l4b :type :l4 :head :h2sn :neck :y-r-p
	    :stand t;; :leg-frontal t
	    :arm :j4 :leg :j4
	    :board :armh7
	    ;;:project-file "kxrl4d"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)

     (30 :head-neck-r -1)     (32 :head-neck-p -1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)
     )
    (("kxrl4b2sh")		;; 18
     (:body :l4b :type :l4 :head :h2sh :arm :j4 :leg :j4
	    :board :armh7 :project-file "kxrl4d"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)

     (30 :head-neck-r -1)     (32 :head-neck-p -1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)
     )
    (("kxrl4d")		;; 18
     (:body :l4d :type :l4 :head :d :arm :j4 :leg :j4
	    :board :rcb4
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)

     (1 :head-neck-p -1)
     (19 :head-gripper-p -1/2)
     (19 :head-gripper2-p -1/2)
     )
    (("kxrl4da")		;; 18
     (:body :l4d :type :l4 :head :d :arm :j4 :leg :j4
	    :board :armh7 :project-file "kxrl4d"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)

     (1 :head-neck-p -1)
     (19 :head-gripper-p -1/2)
     (19 :head-gripper2-p -1/2)
     )
    (("kxrl4d1a")		;; 19
     (:body :l4d :type :l4 :head :d1 :arm :j4 :leg :j4
	    :board :armh7 :project-file "kxrl4dr" ) ;; extended with neck-y
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     
     (1 :head-neck-p -1)      (21 :head-neck-y -1)
     (19 :head-gripper-p 1/2)
     (19 :head-gripper2-p 1/2)
     )
    (("kxrl4d1r")		;; 19
     (:body :l4d :type :l4 :head :d1 :arm :j4 :leg :j4
	    :board :rcb4
	    :project-file "kxrl4dr") ;; extended with neck-y
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     
     (0 :head-neck-p -1)      (10 :head-neck-y -1)
     (19 :head-gripper-p -1/2)
     (19 :head-gripper2-p -1/2)
     )
    (("kxrl4dh2s")
     (:body :l4d :type :l4 :head :h2s :arm :j4 :leg :j4
	    :board :armh7
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     (1 :head-neck-p -1)
     )
    (("kxrl4dh2sn")
     (:body :l4d :type :l4 :head :h2sn :arm :j4 :leg :j4
	    :board :armh7
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     (1 :head-neck-p -1)
     )
    (("kxrl4dh2sl")
     (:body :l4d :type :l4 :head :h2sl :arm :j4 :leg :j4
	    :board :armh7
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     (1 :head-neck-p -1)
     )
    (("kxrl4dh2sh")
     (:body :l4d :type :l4 :head :h2sh :arm :j4 :leg :j4
	    :board :armh7
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     (1 :head-neck-p -1)
     )
    (("kxrl4dh3s")
     (:body :l4d :type :l4 :head :h2s :neck :y-r-p ;; :h3s 
	    :arm :j4 :leg :j4
	    :board :armh7
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     (1 :head-neck-p -1)
     )
    (("kxrl4d1")		;; 19
     (:body :l4d :type :l4 :head :d1 :arm :j4 :leg :j4)
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)

     (0 :head-neck-y -1)      (1 :head-neck-p -1)
     (19 :head-gripper-p 1/2)
     (19 :head-gripper2-p 1/2)
     )
    (("kxrl4d2")		;; 20
     (:body :l4d :type :l4 :head :d2 :arm :j4 :leg :j4)
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)

     (0 :head-neck-y -1)      (1 :head-neck-p -1)
     (18 :head-head-p 1)
     (19 :head-gripper-p 1/2)  (19 :head-gripper2-p 1/2)
     )
    (("kxrl4d3")
     (:body :l4d :type :l4 :head :m5sh :arm :j4 :leg :j4)
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)

     (0 :head-neck-y -1)      (1 :head-neck-p -1)
     ;;(18 :head-head-p 1)
     ;;(19 :head-gripper-p 1/2)  (19 :head-gripper2-p 1/2)
     )
    (("kxrl4d4")
     (:body :l4d :type :l2 :stand t :head :d2 :arm :j4 :leg :j4)
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)

     (0 :head-neck-y -1)      (1 :head-neck-p -1)
     (18 :head-head-p 1)
     (19 :head-gripper-p 1/2)  (19 :head-gripper2-p 1/2)
     )
    (("kxrl4d5")
     (:body :l4d :type :l2 :active-wheel :knee 
	    :board :armh7
	    :shoulder :cross
	    :wrist :r
	    :gripper t :gripper-inner t :wrist-sensor t :gripper-sensor :finger1 :sole t
	    :sole-sensor t :head :h2s :head-length 20)
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)

     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)

     (0 :head-neck-y -1)      (1 :head-neck-p -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)

     (38 larm-gripper2-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper2-r-KJS-01) ;; sensor-board 20
     (42 larm-wrist-r-KJS-03) ;; sensor-board 21
     (44 rarm-wrist-r-KJS-03) ;; sensor-board 22
     ;;(38 ("larm-elbow" "palm" "gripper" "KJS")) ;; sensor-board 19
     ;;(40 ("larm-elbow" "palm" "gripper" "KJS")) ;; sensor-board 20
     )
    (("kxrl4d6")
     (:body :l4d :type :l2 :stand t :active-wheel :knee 
	    :board :armh7
	    :shoulder :cross :wrist :r :gripper t :gripper-inner nil :gripper-sensor :finger1 :sole t
	    :sole-sensor t :head :h2s :head-length 38)
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)

     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)

     (0 :head-neck-y -1)      (1 :head-neck-p -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)

     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     ;;(42 larm-wrist-r-KJS-03) ;; sensor-board 21
     ;;(44 rarm-wrist-r-KJS-03) ;; sensor-board 22
     ;;(38 ("larm-elbow" "palm" "gripper" "KJS")) ;; sensor-board 19
     ;;(40 ("larm-elbow" "palm" "gripper" "KJS")) ;; sensor-board 20
     )
    (("kxrl4d7")
     (:body :l4d :type :l2 :active-wheel :knee 
	    :board :armh7
	    :shoulder :cross :wrist :r :gripper-inner t :gripper-sensor :finger1 :sole t
	    :sole-sensor t :head :h2s :head-length 20)
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)

     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)

     (0 :head-neck-y -1)      (1 :head-neck-p -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl4d8")
     (:body :l4d :type :l2 :stand t :active-wheel :knee 
	    :board :armh7
	    :shoulder :cross :wrist :r :gripper-inner t :gripper-sensor (:finger1) :sole t
	    :sole-sensor t :head :h2s :head-length 38)
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)

     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)

     (0 :head-neck-y -1)      (1 :head-neck-p -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl4d9")
     (:body :l4d :type :l4 :active-wheel :knee 
	    :shoulder :ly-p-r :wrist :r :passive-wheel :wrist
	    :board :armh7
	    :gripper-inner t :gripper-sensor :finger1 :sole t
	    :sole-sensor t :head :h2s :head-length 20)
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)

     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (0 :head-neck-y -1)      (1 :head-neck-p -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl4d10")
     (:body :l4d :type :l4 :stand t :active-wheel :knee 
	    :shoulder :ly-p-r :wrist :r :passive-wheel :wrist
	    :board :armh7
	    :gripper-inner t :gripper-sensor :finger1 :sole t
	    :sole-sensor t :head :h2s :head-length 26)
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)

     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl4d11")
     (:body :l4d :type :l2 :active-wheel :knee 
	    :shoulder :ly-p-r :wrist :r :passive-wheel :wrist
	    :board :armh7
	    :gripper-inner t :gripper-sensor :finger1 :sole t
	    :sole-sensor t :head :h2s :head-length 26)
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)

     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (0 :head-neck-y -1)      (1 :head-neck-p -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl4d12")
     (:body :l4d :type :l4 :active-wheel :knee :board :armh7
	    :arm :l6w :sole t :sole-sensor t :head :h2s :head-length 20)
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (7 :rarm-elbow-w 1)      (8 :larm-elbow-w 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)

     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    ("kxrl2l5a3" ;; 16
     (:body :l2l5 :type :l2 :neck-jf :b :sole t)
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     )
    ("kxrl2l5a3r" ;; 16
     (:body :l2l5 :type :l2 :neck-jf :b :sole t
	    :board :rcb4)
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1 s4)      (13 :lleg-knee-p 1 s4)
     (14 :rleg-ankle-p -1 s4)    (15 :lleg-ankle-p -1 s4)
     (16 :rleg-ankle-r -1 s4)    (17 :lleg-ankle-r -1 s4)
     )
    ("kxrl2l5a3g"   ;; 18
     (:body :l2l5 :type :l2 :gripper t :neck-jf :b :sole t
	    :project-file "kxrl2l5a3")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2) (19 :larm-gripper2-r 1/2)
     )
    ("kxrl2l5a3ga"   ;; 18
     (:body :l2l5 :type :l2 :gripper t :sole t
	    :head :d405cam ;; :head m3deye :3eye-rev 6
	    ;;	    :neck :y 
	    ;; :project-file "kxrl2l5a3"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2) (19 :larm-gripper2-r 1/2)
     )
    ("kxrl2l5a3gr"  ;; 18
     (:body :l2l5 :type :l2 :gripper t :neck-jf :b :sole t
	    :board :rcb4
	    :project-file "kxrl2l5a3")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2) (19 :larm-gripper2-r 1/2)
     )
    (("kxrl2l5a3h2" "kxrl2l5a3h2b") ;; 20
     (:body :l2l5 :type :l2 :gripper t :head :m5 :neck-jf :b :sole t
	    :board :armh7
	    :project-file "kxrl2l5a3")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y -1)      (32 :head-neck-p -1)
     )
    (("kxrl2l5a3wide")
     (:body :l2l5 :type :l2 :shoulder-width 38 :gripper t
	    :head :m5us :neck-jf :b-back :sole t
	    :shoulder-front t :neck-front t
	    :upper-arm-length 38 :board :armh7 :project-file "kxrl2l5a3")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y -1)      (32 :head-neck-p 1)
     )
    ("kxrl2l5a3h2e";; 20
     (:body :l2l5 :type :l2 :gripper t :head :h2s :neck-jf :b :sole t
	    :project-file "kxrl2l5a3")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :head-neck-y 1)      (22 :head-neck-p 1)
     )
    ("kxrl2l5a3h2g"
     (:body :l2l5 :type :l2 :gripper t :head :h2s :neck-jf :b :sole t
	    :project-file "kxrl2l5a3h2g"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y 1)      (32 :head-neck-p 1)
     )
    ("kxrl2l5a3h2ga"
     (:body :l2l5 :type :l2 :gripper t :head :m3eye :neck-jf :a :sole t ;; :head :m5sh :m5us  :h2s :m5u2s
	    :project-file "kxrl2l5a3h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1 s4)      (13 :lleg-knee-p 1 s4)
     (14 :rleg-ankle-p -1 s4)    (15 :lleg-ankle-p -1 s4)
     (16 :rleg-ankle-r -1 s4)    (17 :lleg-ankle-r -1 s4)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y 1)      (32 :head-neck-p 1)
     )
    (("kxrl2l5a3h2gu" "kxrl2l5unitv")
     (:body :l2l5 :type :l2 :gripper t :head :m5us :neck-jf :b :sole t
	    :project-file "kxrl2l5a3h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y 1)      (32 :head-neck-p -1)
     )
    ("kxrsemi2021"
     (:body :l2l5 :type :l2 :gripper t :head :m5us :m5stack 0 :neck-jf :b :sole t
	    :board :armh7
	    :project-file "kxrl2l5a3h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y 1)      (32 :head-neck-p -1)
     )
    ("kxrl2fujiia"
     (:body :l2l5 :type :l2 :gripper t :head :ir :neck-jf :b :sole t
	    :board :armh7
	    :project-file "kxrl2l5a3h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y 1)      (32 :head-neck-p 1)
     )
    ("kxrl2fujiir"
     (:body :l2l5 :type :l2 :gripper t :head :ir :neck-jf :b :sole t
	    :board :rcb4
	    :project-file "kxrl2l5a3h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y 1)      (32 :head-neck-p 1)
     )
    (("kxrl2l5a3h2gr"  "kxrl2g")
     (:body :l2l5 :type :l2 :gripper t :head :ir :neck-jf :a :sole t
	    :board :rcb4 :project-file "kxrl2l5a3h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y -1)      (32 :head-neck-p 1)
     )
    (("kxrl2l5a4h2g")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :gripper t :neck-jf :a :sole t
	    :backpack :m5 :head :m5u3s2	;; :m5sh  ;; :head :m5i 
	    :sole-sensor t 
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     ;;
     (44 ("rleg" "sole")) ;; sensor-board 22
     (52 ("lleg" "sole")) ;; sensor-board 26
     )
    (("kxrl2l5a4h2gm")
     (:body :l2l5m :type :l2 :shoulder :p-r-y :gripper t :neck-jf :a :sole t
	    :head :m3eye :3eye-rev 5 :m5stickv t
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     ;;
     (44 ("rleg" "sole")) ;; sensor-board 22
     (52 ("lleg" "sole")) ;; sensor-board 26
     )
    (("kxrl2l5semi")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :gripper t :neck-jf :a :sole t
	    :backpack :m5 :head :m5sh  ;; :head :m5i 
	    :sole-sensor t :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rarm-shoulder-y 1)    (21 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     ;;
     (44 ("rleg" "sole")) ;; sensor-board 22
     (52 ("lleg" "sole")) ;; sensor-board 26
     )
    (("kxrl2l5a4h2gr")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :gripper t :neck-jf :a :sole t
	    :head :h2 :board :rcb4
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2l5a4h2ga")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :gripper t :sole t :neck-jf :b
	    :board :armh7 :head :m5sh
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2l5inaba")	;; hight 385
     (:body :l2l5 :type :l2 :shoulder :p-r-y
	    :head :m3eye :3eye-rev 4 :m5stickv t;; :neck :y-r-p ;; :y-p-r :h2s
	    :gripper t :neck-jf :a :sole t ;; :m5h
	    :gripper-sensor :rev-a  ;; both :rev-a, (:finger1 :rev-a) for finger1 only :rev-a
	    :head-sensor t  
	    :wrist-sensor t  
	    :ankle-sensor t
	    :backpack :m5
	    ;; :com-init-method (:arm-open :pid #x6001) ;; same as :arm2-open, pid:#x6015 for Akizuki, :vid #x0403
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     ;;(32 :head-neck-y -1)       (33 :head-neck-p -1)
     ;;
     (39 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (43 larm-gripper2-r-KJS-01) ;; sensor-board 21
     (46 rarm-gripper2-r-KJS-01) ;; sensor-board 23
     (45 larm-elbow-p-KJS-03) ;; sensor-board 22
     (48 rarm-elbow-p-KJS-03) ;; sensor-board 24
     (51 lleg-ankle-r-KJS-03) ;; sensor-board 25
     (52 rleg-ankle-r-KJS-03) ;; sensor-board 26
     ;;
     ;; (38 ("larm-elbow" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-elbow" "gripper-" "KJS")) ;; sensor-board 20
     ;; (42 ("larm-elbow" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (46 ("rarm-elbow" "gripper2-" "KJS")) ;; sensor-board 23
     ;; (44 ("rarm" "elbow" "KJS")) ;; sensor-board 22
     ;; (48 ("larm" "elbow" "KJS")) ;; sensor-board 24
     ;; (50 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 25
     ;; (52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    (("kxrl2l5a6inaba")
     (
      ;;:file "models/kxrl2l5a6inaba.l" :form (kxrl2l5a6inaba)
      ;;:board :armh7 :com-init-method (:arm2-open)
      :project-file "kxrl2l5a4h2g"
      :body :l2l5 :type :l2
      :sole t 
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor :rev-a ;;(:finger1 :rev-a) ;; :finger1 outside(drive :gripper-r), :finger2 inside(:gripper2-r)
      ;;:head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t
      :head :d405cam :3eye-front t
      :head-length 20 :m5stickv t
      :shoulder-p-sensor (:rev-a :flip) :shoulder-y-sensor (:rev-a :flip)
      :shoulder-r-sensor :rev-c :elbow-p-sensor :rev-c
      :wrist-p-sensor :rev-c :wrist-sensor :rev-c
      :ankle-sensor t
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      )

     (2 :rarm-shoulder-p 1 60)  (3 :larm-shoulder-p -1 -60)
     (4 :rarm-shoulder-r 1 -3)  (5 :larm-shoulder-r 1 1)
     (6 :rarm-elbow-p 1 -6)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     ;;
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     ;;
     (38 rarm-gripper-r-KJS-01)  (39 larm-gripper-r-KJS-01)  ;; sensor-board 19 
     (40 rarm-gripper2-r-KJS-01) (41 larm-gripper2-r-KJS-01) ;; sensor-board 20
     (44 rarm-wrist-r-KJS-03)    (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     (46 rarm-shoulder-y-KJS-01) (47 larm-shoulder-y-KJS-01) ;; sensor-board 23
     (48 rarm-shoulder-p-KJS-01) (49 larm-shoulder-p-KJS-01) ;; sensor-board 24
     (50 rarm-shoulder-r-KJS-03) (51 larm-shoulder-r-KJS-03) ;; sensor-board 25
     (52 rarm-wrist-p-KJS-03)    (53 larm-wrist-p-KJS-03)    ;; sensor-board 26
     (54 rarm-elbow-p-KJS-03)    (55 larm-elbow-p-KJS-03)    ;; sensor-board 27
     ;;
     (42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     )
    (("kxrl2l6a6inaba1")
     (
      ;;:file "models/kxrl2l6a6inaba1.l" :form (kxrl2l6a6inaba1)
      :project-file "kxrl2l5a4h2g"
      :body :l2l6 :type :l2
      :sole t 
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor :rev-a ;;(:finger1 :rev-a) ;; :finger1 outside(drive :gripper-r), :finger2 inside(:gripper2-r)
      ;;:head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t
      :head :d405cam :3eye-front t
      :head-length 20 :m5stickv t
      :shoulder-p-sensor (:rev-a :flip) :shoulder-y-sensor (:rev-a :flip)
      :shoulder-r-sensor :rev-c :elbow-p-sensor :rev-c
      :wrist-p-sensor :rev-c :wrist-sensor :rev-c
      :ankle-sensor t
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      )

     (2 :rarm-shoulder-p 1 60)  (3 :larm-shoulder-p -1 -60)
     (4 :rarm-shoulder-r 1 -3)  (5 :larm-shoulder-r 1 1)
     (6 :rarm-elbow-p 1 -6)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     ;;
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     ;;
     (38 rarm-gripper-r-KJS-01)  (39 larm-gripper-r-KJS-01)  ;; sensor-board 19 
     (40 rarm-gripper2-r-KJS-01) (41 larm-gripper2-r-KJS-01) ;; sensor-board 20
     (44 rarm-wrist-r-KJS-03)    (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     (46 rarm-shoulder-y-KJS-01) (47 larm-shoulder-y-KJS-01) ;; sensor-board 23
     (48 rarm-shoulder-p-KJS-01) (49 larm-shoulder-p-KJS-01) ;; sensor-board 24
     (50 rarm-shoulder-r-KJS-03) (51 larm-shoulder-r-KJS-03) ;; sensor-board 25
     (52 rarm-wrist-p-KJS-03)    (53 larm-wrist-p-KJS-03)    ;; sensor-board 26
     (54 rarm-elbow-p-KJS-03)    (55 larm-elbow-p-KJS-03)    ;; sensor-board 27
     ;;
     (42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     )
    (("kxrl2l6a6inaba5")
     (
      ;;:file "models/kxrl2l6a6inaba1.l" :form (kxrl2l6a6inaba1)
      :project-file "kxrl2l5a4h2g"
      :body :l2l6b :type :l2
      :sole t 
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor :rev-a ;;(:finger1 :rev-a) ;; :finger1 outside(drive :gripper-r), :finger2 inside(:gripper2-r)
      ;;:head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t
      :head :d405cam :3eye-front t
      :head-length 20 :m5stickv t
      :shoulder-p-sensor (:rev-a :flip) :shoulder-y-sensor (:rev-a :flip)
      :shoulder-r-sensor :rev-c :elbow-p-sensor :rev-c
      :wrist-p-sensor :rev-c :wrist-sensor :rev-c
      :ankle-sensor t
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      )

     (2 :rarm-shoulder-p 1 60)  (3 :larm-shoulder-p -1 -60)
     (4 :rarm-shoulder-r 1 -3)  (5 :larm-shoulder-r 1 1)
     (6 :rarm-elbow-p 1 -6)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     ;;
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     ;;
     (38 rarm-gripper-r-KJS-01)  (39 larm-gripper-r-KJS-01)  ;; sensor-board 19 
     (40 rarm-gripper2-r-KJS-01) (41 larm-gripper2-r-KJS-01) ;; sensor-board 20
     (44 rarm-wrist-r-KJS-03)    (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     (46 rarm-shoulder-y-KJS-01) (47 larm-shoulder-y-KJS-01) ;; sensor-board 23
     (48 rarm-shoulder-p-KJS-01) (49 larm-shoulder-p-KJS-01) ;; sensor-board 24
     (50 rarm-shoulder-r-KJS-03) (51 larm-shoulder-r-KJS-03) ;; sensor-board 25
     (52 rarm-wrist-p-KJS-03)    (53 larm-wrist-p-KJS-03)    ;; sensor-board 26
     (54 rarm-elbow-p-KJS-03)    (55 larm-elbow-p-KJS-03)    ;; sensor-board 27
     ;;
     (42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     )
    (("kxrl2l5inaba0m5")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :head :h2 :neck-jf :b :sole t
	    ;; :board :armh7
	    :gripper t :gripper-inner nil
	    :gripper-sensor :finger1   ;; :finger1 
	    :head-sensor t  
	    :wrist-sensor nil
	    :backpack :m5
	    ;; :com-init-method (:arm-open :pid #x6001) ;; same as :arm2-open, pid:#x6015 for Akizuki, :vid #x0403
	    ;; :project-file "kxrl2l5inaba0"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rarm-shoulder-y 1)    (21 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)

     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (44 lleg-ankle-r-KJS-03) ;; sensor-board 22
     (52 rleg-ankle-r-KJS-03) ;; sensor-board 26
     ;;
     ;; (38 ("larm-elbow" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-elbow" "gripper-" "KJS")) ;; sensor-board 20
     ;; (44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    (("kxrl2l5inaba0")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :head :h2 :neck-jf :b :sole t
	    ;; :board :armh7
	    :gripper t :gripper-inner nil
	    :gripper-sensor :finger1   ;; :finger1 
	    :head-sensor t  
	    :wrist-sensor nil
	    ;; :com-init-method (:arm-open :pid #x6001) ;; same as :arm2-open, pid:#x6015 for Akizuki, :vid #x0403
	    ;;:project-file "kxrl2l5inaba0"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rarm-shoulder-y 1)    (21 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)

     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (44 lleg-ankle-r-KJS-03) ;; sensor-board 22
     (52 rleg-ankle-r-KJS-03) ;; sensor-board 26

     ;; (38 ("larm-elbow" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-elbow" "gripper-" "KJS")) ;; sensor-board 20
     ;; (44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    (("kxrl2l5inaba0f1")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :head :h2 :neck-jf :b :sole t
	    :gripper t :gripper-inner nil
	    :gripper-sensor :finger1   ;; :finger1 
	    :head-sensor t  
	    :wrist-sensor t
	    :backpack :m5
	    ;;      :project-file "kxrl2l5inaba0"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rarm-shoulder-y 1)    (21 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     )
    (("kxrl2l5inaba0f2")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :head :h2 :neck-jf :b :sole t
	    :gripper t :gripper-inner nil
	    :gripper-sensor :finger2
	    :head-sensor t  
	    :wrist-sensor t
	    :backpack :m5
	    ;;      :project-file "kxrl2l5inaba0"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rarm-shoulder-y 1)    (21 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     )
    (("kxrl2l5inaba0i")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :head :h2 :neck-jf :b :sole t
	    :gripper t :gripper-inner t
	    :gripper-sensor nil
	    :head-sensor t  
	    :wrist-sensor nil  
	    :backpack :m5
	    ;;      :project-file "kxrl2l5inaba0"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rarm-shoulder-y 1)    (21 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     )
    (("kxrl2l5inaba0is")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :head :m3deye :neck-jf :b :sole t
	    :gripper t :gripper-inner t
	    :gripper-sensor t
	    :head-sensor t  :ankle-sensor t
	    :wrist-sensor t
	    :backpack :m5
	    ;;:project-file "kxrl2l5inaba0"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rarm-shoulder-y 1)    (21 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     ;;
     (50 larm-gripper2-r-KJS-01)
     (48 rarm-gripper2-r-KJS-01)
     (42 larm-gripper-r-KJS-01)
     (40 rarm-gripper-r-KJS-01)
     (46 larm-elbow-p-KJS-03)
     (38 rarm-elbow-p-KJS-03)
     (52 lleg-ankle-r-KJS-03)
     (44 rleg-ankle-r-KJS-03)
     ;;
     ;; (38 ("rarm" "elbow" "KJS")) ;; sensor-board 19
     ;; (46 ("larm" "elbow" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     ;; (40 ("rarm-elbow" "KJS" "gripper-")) ;; sensor-board 20
     ;; (42 ("larm-elbow" "KJS" "gripper-")) ;; sensor-board 19
     ;; (48 ("rarm-elbow" "KJS" "gripper2-")) ;; sensor-board 24
     ;; (50 ("larm-elbow" "KJS" "gripper2-")) ;; sensor-board 25
     )
    (("kxrl2l5inaba0if1")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :head :h2 :neck-jf :b :sole t
	    :gripper t :gripper-inner t
	    :gripper-sensor :finger1   ;; :finger1 
	    :head-sensor t  
	    :wrist-sensor t
	    :backpack :m5
	    ;;:project-file "kxrl2l5inaba0"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rarm-shoulder-y 1)    (21 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)

     (38 rarm-elbow-p-KJS-03)
     (46 larm-elbow-p-KJS-03)
     (44 rleg-ankle-r-KJS-03)
     (52 lleg-ankle-r-KJS-03)
     (48 rarm-gripper2-r-KJS-01)
     (50 larm-gripper2-r-KJS-01)

     ;; (38 ("rarm" "elbow" "KJS")) ;; sensor-board 19
     ;; (46 ("larm" "elbow" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     ;; ;;(40 ("rarm-elbow" "KJS" "gripper-")) ;; sensor-board 20
     ;; ;;(42 ("larm-elbow" "KJS" "gripper-")) ;; sensor-board 19
     ;; (48 ("rarm-elbow" "KJS" "gripper2-")) ;; sensor-board 24
     ;; (50 ("larm-elbow" "KJS" "gripper2-")) ;; sensor-board 25
     )
    (("kxrl2l5inaba0if2")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :head :h2 :neck-jf :b :sole t
	    :gripper t :gripper-inner t
	    :gripper-sensor :finger2
	    :head-sensor t  
	    :wrist-sensor t
	    :backpack :m5
	    ;; :project-file "kxrl2l5inaba0"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rarm-shoulder-y 1)    (21 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     ;;
     (38 rarm-elbow-p-KJS-03)
     (46 larm-elbow-p-KJS-03)
     (44 rleg-ankle-r-KJS-03)
     (52 lleg-ankle-r-KJS-03)
     (48 rarm-gripper2-r-KJS-01)
     (50 larm-gripper2-r-KJS-01)
     ;;
     ;; (38 ("rarm" "elbow" "KJS")) ;; sensor-board 19
     ;; (46 ("larm" "elbow" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     ;; ;;(40 ("rarm-elbow" "KJS" "gripper-")) ;; sensor-board 20
     ;; ;;(42 ("larm-elbow" "KJS" "gripper-")) ;; sensor-board 19
     ;; (48 ("rarm-elbow" "KJS" "gripper2-")) ;; sensor-board 24
     ;; (50 ("larm-elbow" "KJS" "gripper2-")) ;; sensor-board 25
     )
    (("kxrl2l5inaba2")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :head :h2s :gripper t :neck-jf :a :sole t
	    :gripper-sensor t   ;; :finger1 
	    :head-sensor t  
	    :wrist-sensor t  
	    :backpack :m5
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     ;;(32 :head-neck-y -1)       (33 :head-neck-p -1)
     ;;
     (44 rarm-elbow-p-KJS-03)
     (48 larm-elbow-p-KJS-03)
     (38 lleg-ankle-r-KJS-03)
     (40 rleg-ankle-r-KJS-03)
     (42 larm-gripper2-r-KJS-01)
     (46 rarm-gripper2-r-KJS-01)
     ;;
     ;; (44 ("rarm" "elbow" "KJS")) ;; sensor-board 22
     ;; (48 ("larm" "elbow" "KJS")) ;; sensor-board 24
     ;; (38 ("larm-elbow" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-elbow" "gripper-" "KJS")) ;; sensor-board 20
     ;; (42 ("larm-elbow" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (46 ("rarm-elbow" "gripper2-" "KJS")) ;; sensor-board 23
     )
    (("kxrl2l5inaba3")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :head :h2s :neck :y-p-r ;; :h3s
	    :gripper t :neck-jf :a :sole t
	    ;;:gripper-sensor t ;;(:finger1 :rev-a)
	    :gripper-sensor ((:finger1 . :rev-a) (:finger2 . :rev-c))
	    ;;:head-sensor t  
	    :wrist-sensor :rev-c
	    :ankle-sensor :rev-c
	    :backpack :m5
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     (26 :head-neck-r -1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)
     ;;
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 larm-gripper2-r-KJS-01) ;; sensor-board 21
     (46 rarm-gripper2-r-KJS-01) ;; sensor-board 23
     (44 larm-elbow-p-KJS-03) ;; sensor-board 22
     (48 rarm-elbow-p-KJS-03) ;; sensor-board 24
     (50 lleg-ankle-r-KJS-03) ;; sensor-board 25
     (52 rleg-ankle-r-KJS-03) ;; sensor-board 26
     ;;
     ;; (38 ("larm-elbow" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-elbow" "gripper-" "KJS")) ;; sensor-board 20
     ;; (42 ("larm-elbow" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (44 ("rarm-elbow" "gripper2-" "KJS")) ;; sensor-board 22
     ;; (46 ("rarm-elbow" "s33" "KJS")) ;; sensor-board 23
     ;; (48 ("larm-elbow" "s33" "KJS")) ;; sensor-board 24
     ;; (50 ("rleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 25
     ;; (52 ("lleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    (("kxrl2l5inaba3n")  ;; :head :h3sn
     (:body :l2l5 :type :l2 :shoulder :p-r-y
	    :head :h2sn :neck :y-p-r ;; :h3sn
	    :gripper t :neck-jf :a :sole t
	    :gripper-sensor (:finger1 :rev-a)
	    :head-sensor t  
	    :wrist-sensor t  
	    :backpack :m5
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     (26 :head-neck-r -1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)

     ;;(32 :head-neck-y -1)       (33 :head-neck-p -1)
     ;;
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 larm-gripper2-r-KJS-01) ;; sensor-board 21
     (46 rarm-gripper2-r-KJS-01) ;; sensor-board 23
     ;;
     ;; (38 ("larm-elbow" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-elbow" "gripper-" "KJS")) ;; sensor-board 20
     ;; (42 ("larm-elbow" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (46 ("rarm-elbow" "gripper2-" "KJS")) ;; sensor-board 23
     )
    (("kxrl2l5inaba3v")  ;; :head :h3sv vertical
     (:body :l2l5 :type :l2 :shoulder :p-r-y
	    :head :h2sv :neck :y-p-r ;; :h3sv
	    :gripper t :neck-jf :a :sole t
	    :gripper-sensor (:finger1 :rev-a)
	    :head-sensor t  
	    :wrist-sensor t  
	    :backpack :m5
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     (26 :head-neck-r -1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)

     ;;(32 :head-neck-y -1)       (33 :head-neck-p -1)
     ;;
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 larm-gripper2-r-KJS-01) ;; sensor-board 21
     (46 rarm-gripper2-r-KJS-01) ;; sensor-board 23
     ;;
     ;; (38 ("larm-elbow" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-elbow" "gripper-" "KJS")) ;; sensor-board 20
     ;; (42 ("larm-elbow" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (46 ("rarm-elbow" "gripper2-" "KJS")) ;; sensor-board 23
     )
    (("kxrl2l5inaba3vo")  ;; :head :h3sv vertical out
     (:body :l2l5 :type :l2 :shoulder :p-r-y
	    :head :h2svo :neck :y-p-r ;; :h3svo
	    :gripper t :neck-jf :a :sole t
	    :gripper-sensor (:finger1 :rev-a)
	    :head-sensor t  
	    :wrist-sensor t  
	    :backpack :m5
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     (26 :head-neck-r -1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)

     ;;(32 :head-neck-y -1)       (33 :head-neck-p -1)
     ;;
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 larm-gripper2-r-KJS-01) ;; sensor-board 21
     (46 rarm-gripper2-r-KJS-01) ;; sensor-board 23
     ;;
     ;; (38 ("larm-elbow" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-elbow" "gripper-" "KJS")) ;; sensor-board 20
     ;; (42 ("larm-elbow" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (46 ("rarm-elbow" "gripper2-" "KJS")) ;; sensor-board 23
     )
    (("kxrl2l5inaba3vi")  ;; :head :h3sv vertical in
     (:body :l2l5 :type :l2 :shoulder :p-r-y
	    :head :h2svi :neck :y-p-r ;; :h3svi
	    :gripper t :neck-jf :a :sole t
	    :gripper-sensor (:finger1 :rev-a)
	    :head-sensor t  
	    :wrist-sensor t  
	    :backpack :m5
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     (26 :head-neck-r -1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)

     ;;(32 :head-neck-y -1)       (33 :head-neck-p -1)
     ;;
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 larm-gripper2-r-KJS-01) ;; sensor-board 21
     (46 rarm-gripper2-r-KJS-01) ;; sensor-board 23
     ;;
     ;; (38 ("larm-elbow" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-elbow" "gripper-" "KJS")) ;; sensor-board 20
     ;; (42 ("larm-elbow" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (46 ("rarm-elbow" "gripper2-" "KJS")) ;; sensor-board 23
     )
    (("kxrl2l5inaba3l")  ;; :head :h3sl
     (:body :l2l5 :type :l2 :shoulder :p-r-y
	    :head :h2sl :neck :y-p-r ;; :h3sl
	    :gripper t :neck-jf :a :sole t
	    :gripper-sensor (:finger1 :rev-a)
	    :head-sensor t  
	    :wrist-sensor t  
	    :backpack :m5
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     (26 :head-neck-r -1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)

     ;;(32 :head-neck-y -1)       (33 :head-neck-p -1)
     ;;
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 larm-gripper2-r-KJS-01) ;; sensor-board 21
     (46 rarm-gripper2-r-KJS-01) ;; sensor-board 23
     ;;
     ;; (38 ("larm-elbow" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-elbow" "gripper-" "KJS")) ;; sensor-board 20
     ;; (42 ("larm-elbow" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (46 ("rarm-elbow" "gripper2-" "KJS")) ;; sensor-board 23
     )
    (("kxrl2l5inaba3h")  ;; :head :h3sh
     (:body :l2l5 :type :l2 :shoulder :p-r-y :head :h2sh :neck :y-p-r ;; :h3sh
	    :gripper t :neck-jf :a :sole t
	    :gripper-sensor (:finger1 :rev-a)
	    :head-sensor t  
	    :wrist-sensor t  
	    :backpack :m5
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     (26 :head-neck-r -1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)

     ;;(32 :head-neck-y -1)       (33 :head-neck-p -1)
     ;;
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 larm-gripper2-r-KJS-01) ;; sensor-board 21
     (46 rarm-gripper2-r-KJS-01) ;; sensor-board 23
     ;;
     ;; (38 ("larm-elbow" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-elbow" "gripper-" "KJS")) ;; sensor-board 20
     ;; (42 ("larm-elbow" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (46 ("rarm-elbow" "gripper2-" "KJS")) ;; sensor-board 23
     )
    (("kxrl2l5rcb4")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :head :e :gripper t :neck-jf :a :sole t
	    :board :rcb4 :com-init-method (:rcb4-open)
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     )
    (("kxrl2l5inaba6")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :head :m3deye :3eye-rev 6 :neck :y-p-r ;; :h3s
	    :gripper t :neck-jf :a :sole t
	    ;;:gripper-sensor t ;;(:finger1 :rev-a)
	    :gripper-sensor ((:finger1 . :rev-a) (:finger2 . :rev-c))  ;;:head-sensor t  
	    :wrist-sensor :rev-c  :ankle-sensor :rev-c :backpack :m5
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     (26 :head-neck-r -1)
     ;;(28 :head-leye-y -1)     (34 :head-reye-y -1)
     ;;
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 larm-gripper2-r-KJS-01) ;; sensor-board 21
     (46 rarm-gripper2-r-KJS-01) ;; sensor-board 23
     (44 larm-elbow-p-KJS-03) ;; sensor-board 22
     (48 rarm-elbow-p-KJS-03) ;; sensor-board 24
     (50 lleg-ankle-r-KJS-03) ;; sensor-board 25
     (52 rleg-ankle-r-KJS-03) ;; sensor-board 26
     ;;
     ;; (38 ("larm-elbow" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-elbow" "gripper-" "KJS")) ;; sensor-board 20
     ;; (42 ("larm-elbow" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (44 ("rarm-elbow" "gripper2-" "KJS")) ;; sensor-board 22
     ;; (46 ("rarm-elbow" "s33" "KJS")) ;; sensor-board 23
     ;; (48 ("larm-elbow" "s33" "KJS")) ;; sensor-board 24
     ;; (50 ("rleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 25
     ;; (52 ("lleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    (("kxrl2l5inabamodel")
     (:file "models/kxrl2l5inaba.l" :form (kxrl2l5inaba)
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     ;;     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     ;;(32 :head-neck-y -1)       (33 :head-neck-p -1)
     ;;
     ;;(38 ("larm-elbow" "gripper-" "KJS")) ;; sensor-board 19
     ;;(40 ("rarm-elbow" "gripper-" "KJS")) ;; sensor-board 20
     ;;
     ;;(42 ("larm-elbow" "gripper2-" "KJS")) ;; sensor-board 21
     ;;(46 ("rarm-elbow" "gripper2-" "KJS")) ;; sensor-board 23
     )
    (("kxrl2l5inabafull")
     (:body :l2l5 :type :l2 :shoulder :p-r-y :head :m5i :gripper t :neck-jf :a :sole t
	    :gripper-sensor t   ;; :finger1 
	    :head-sensor t  
            :wrist-sensor t  
	    :sole-sensor t :backpack :m5
	    :project-file "kxrl2l5a4h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     ;;(32 :head-neck-y -1)       (33 :head-neck-p -1)
     ;;
     (38 larm-gripper-r-KJS-03) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-03) ;; sensor-board 20
     (42 larm-gripper2-r-KJS-03) ;; sensor-board 21
     (46 rarm-gripper2-r-KJS-03) ;; sensor-board 23
     (44 ("rleg" "sole")) ;; sensor-board 22
     (52 ("lleg" "sole")) ;; sensor-board 26
     (48 larm-elbow-p-KJS-03) ;; sensor-board 24
     (50 rarm-elbow-p-KJS-03) ;; sensor-board 25
     ;;
     ;; (38 ("larm-elbow" "KJS" "gripper-")) ;; sensor-board 19
     ;; (40 ("rarm-elbow" "KJS" "gripper-")) ;; sensor-board 20
     ;; (42 ("larm-elbow" "KJS" "gripper2-")) ;; sensor-board 21
     ;; (46 ("rarm-elbow" "KJS" "gripper2-")) ;; sensor-board 23
     ;; (44 ("rleg" "sole")) ;; sensor-board 22
     ;; (52 ("lleg" "sole")) ;; sensor-board 26
     ;; (48 ("rarm" "elbow" "KJS")) ;; sensor-board 24
     ;; (50 ("larm" "elbow" "KJS")) ;; sensor-board 25
     ;;(48 ("head" "joint" "neck")) ;; sensor-board 24
     )
    ("kxrl2semi2020"
     (:body :l2l5 :type :l2 :gripper t :head :m5 :neck-jf :b :sole t
	    :sole-sensor t
	    :project-file "kxrl2l5a3h2g")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y 1)      (32 :head-neck-p 1)
     ;;
     (44 ("rleg" "sole")) ;; sensor-board 22
     (52 ("lleg" "sole")) ;; sensor-board 26
     )
    
    ("kxrl2sonoyama"
     (:body :l2l5 :type :l2 :gripper t :head :m5 :neck-jf :b :sole t
            :sole-sensor t
            :project-file "kxrl2sonoyama")
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y 1)      (32 :head-neck-p 1)
     ;;                                                                                                                                                                                                     
     (44 ("rleg" "sole")) ;; sensor-board 22                                                                                                                                                                
     (52 ("lleg" "sole")) ;; sensor-board 26                                                                                                                                                                
     )
    (("kxrl2l5a3h2gar") ;; 
     (:body :l2l5 :type :l2 :gripper :rarm :head :e :neck-jf :b :sole t)
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)
     (30 :head-neck-y 1)      (32 :head-neck-p 1)
     )
    (("kxrl2l5a3h2gal") ;; 
     (:body :l2l5 :type :l2 :gripper :larm :head :e :neck-jf :b :sole t)
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (19 :larm-gripper-r 1/2)
     (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y 1)      (32 :head-neck-p 1)
     )
    (("kxrl2l5a4h2")
     (:body :l2l5 :type :l2 :wrist :r :head :ir :gripper t :neck-jf :a :sole t) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-wrist-r -1)    (23 :larm-wrist-r -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2l5a4h2y")
     (:body :l2l5 :type :l2 :shoulder :p-r-y
	    :project-file "kxrl2l5a4h2g"
	    :head :m5h :gripper t :neck-jf :a :sole t) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y -1)    (23 :larm-shoulder-y -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2w2l5a3" "kxrl2w2l5a3h2" "kxrl2w2l5a3h2b")
     (:body :l2l5 :type :l2 :active-wheel :ankle :gripper t :passive-wheel :gripper 
	    :neck-jf :b :head :e :sole t) ;; 22
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2wcl5a3")
     (:body :l2l5 :type :l2 :active-wheel :crotch :gripper t :passive-wheel :gripper 
	    :neck-jf :b :head :e :sole t) ;; 22
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-crotch-w 1)     (21 :lleg-crotch-w -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2w2l5a3i" "kxrl2w2l5a3h2i" "kxrl2w2l5a3h2bi")
     (:body :l2l5 :type :l2 :active-wheel :ankle :passive-wheel :gripper
	    :neck-jf :b :head :e :gripper-inner t :sole t) ;; 22
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2w2l5a4p" "kxrl2w2l5a4h2p" "kxrl2kimura0")
     (:body :l2l5 :type :l2 :active-wheel :ankle :head :e :wrist :p
	    :gripper t :gripper-axis :p :neck-jf :b :sole t) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-p -1)    (23 :larm-wrist-p -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2w2l5a4ps" "kxrl2kimura0f1")
     (:body :l2l5 :type :l2 :active-wheel :ankle :head :e :wrist :p
	    :gripper t :gripper-sensor :finger1 :gripper-axis :p :neck-jf :b :sole t) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-p -1)    (23 :larm-wrist-p -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2kimura0f2")
     (:body :l2l5 :type :l2 :active-wheel :ankle :head :e :wrist :p
	    :gripper t :gripper-sensor :finger2 :gripper-axis :p :neck-jf :b :sole t) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-p -1)    (23 :larm-wrist-p -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2w2l5a4pw" "kxrl2w2l5a4h2pw" "kxrl2kimura1")
     (:body :l2l5 :type :l2 :active-wheel :ankle :wrist :p
	    :gripper t :passive-wheel :gripper :head :e :neck-jf :b :sole t) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-p -1)    (23 :larm-wrist-p -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2kimura1f1")
     (:body :l2l5 :type :l2 :active-wheel :ankle :wrist :p
	    :gripper t :gripper-sensor :finger1 :passive-wheel :gripper :head :e :neck-jf :b :sole t) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-p -1)    (23 :larm-wrist-p -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2kimura1f2")
     (:body :l2l5 :type :l2 :active-wheel :ankle :wrist :p
	    :gripper t :gripper-sensor :finger2 :passive-wheel :gripper :head :e :neck-jf :b :sole t) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-p -1)    (23 :larm-wrist-p -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2w2inaba1") ;; kxrl2w2l5a4h2 with rcb4
     (:body :l2l5 :type :l2 :head :e :active-wheel :ankle :wrist :r
	    :project-file "kxrl2w2l5a4h2"
	    :gripper t :passive-wheel :gripper :neck-jf :a :sole t) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-r -1)    (23 :larm-wrist-r -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2w2l5a4h2s" "kxrl2w2inaba2") ;; kxrl2w2l5a4h2 with armh7 m5stickv stereo
     (:body :l2l5 :type :l2 :head :h2s :active-wheel :ankle :wrist :r
	    :gripper t :passive-wheel :gripper :neck-jf :a :sole t
	    :gripper-sensor t
	    :project-file "kxrl2w2l5a4h2"
	    )
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-r -1)    (23 :larm-wrist-r -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)
     ;;
     (38 larm-gripper-r-KJS-03) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-03) ;; sensor-board 20
     (42 larm-gripper2-r-KJS-03) ;; sensor-board 21
     (46 rarm-gripper2-r-KJS-03) ;; sensor-board 23
     ;;
     ;; (38 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 20
     ;; (42 ("larm-wrist" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (46 ("rarm-wrist" "gripper2-" "KJS")) ;; sensor-board 23
     )
    (("kxrl2w2l5a4h3s" "kxrl2w2inaba3") ;; kxrl2w2l5a4h2 with armh7 m5stickv stereo
     (:body :l2l5 :type :l2 :head :h2s :neck :y-p-r ;; :h3s
	    :active-wheel :ankle :wrist :r
	    :gripper t :passive-wheel :gripper :neck-jf :a :sole t
	    :project-file "kxrl2w2l5a4h2" :gripper-sensor :rev-a
	    :com-init-method (:arm2-open))
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-r -1)    (23 :larm-wrist-r -1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     (26 :head-neck-r -1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)
     ;;
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 larm-gripper2-r-KJS-01) ;; sensor-board 21
     (46 rarm-gripper2-r-KJS-01) ;; sensor-board 23
     ;;
     ;; (38 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 20
     ;; (42 ("larm-wrist" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (46 ("rarm-wrist" "gripper2-" "KJS")) ;; sensor-board 23
     )
    (("kxrl2w2l5a4h3s-no-project") ;; kxrl2w2l5a4h2 with 3D neck m5stickv stereo
     ;; WIP this should create trim-vector from offset
     (:body :l2l5 :type :l2 :head :h2s :neck :y-p-r ;; :h3s
	    :active-wheel :ankle :wrist :r :gripper-sensor :rev-a
	    :gripper t :passive-wheel :gripper :neck-jf :a :sole t
	    :com-init-method (:arm2-open))
     (2 :rarm-shoulder-p 1 43)   (3 :larm-shoulder-p -1 -43)
     (4 :rarm-shoulder-r -1 -90)  (5 :larm-shoulder-r 1 -90)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1  -3.3)   (11 :lleg-crotch-p -1 -3.3)
     (12 :rleg-knee-p 1 -70)      (13 :lleg-knee-p 1 -70)
     (14 :rleg-ankle-p -1 10)    (15 :lleg-ankle-p -1 10)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-r -1)    (23 :larm-wrist-r -1)
     (30 :head-neck-y -1)     (32 :head-neck-p -1)
     (26 :head-neck-r -1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)
     ;;
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 larm-gripper2-r-KJS-01) ;; sensor-board 21
     (46 rarm-gripper2-r-KJS-01) ;; sensor-board 23
     ;;
     ;; (38 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 20
     ;; (42 ("larm-wrist" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (46 ("rarm-wrist" "gripper2-" "KJS")) ;; sensor-board 23
     )
    (("kxrl2w2l5a4h2" "kxrl2w2l5a4h2rw" "kxrl2kimura2" "kxrl2sato")
     (:body :l2l5 :type :l2 :head :m5 :active-wheel :ankle :wrist :r
	    :gripper t :passive-wheel :gripper :neck-jf :a :sole t) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1 20)     (9 :lleg-crotch-r 1 -20)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1 30)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-r -1)    (23 :larm-wrist-r -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2kimura2f1" "kxrl2satof1")
     (:body :l2l5 :type :l2 :head :m5 :active-wheel :ankle :wrist :r
	    :board :armh7 :gripper-sensor :finger1
	    :gripper t :passive-wheel :gripper :neck-jf :a :sole t) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-r -1)    (23 :larm-wrist-r -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2kimura2f2" "kxrl2satof2")
     (:body :l2l5 :type :l2 :head :m5 :active-wheel :ankle :wrist :r
	    :board :armh7 :gripper-sensor :finger2
	    :gripper t :passive-wheel :gripper :neck-jf :a :sole t) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-r -1)    (23 :larm-wrist-r -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    ("kxrl2w2l5a4h2fly"
     (:body :l2l5 :type :l2 :wing t :head :e :active-wheel :ankle :wrist :r
	    :gripper t :passive-wheel :gripper :neck-jf :a :sole t) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-r -1)    (23 :larm-wrist-r -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    ("kxrl2w2l5a4h2i"
     (:type :l2 :head :e :active-wheel :ankle :wrist :r :gripper t :passive-wheel :gripper
	    :gripper-inner t :neck-jf :a :sole t) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-r -1)    (23 :larm-wrist-r -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    ("kxrl2w2l5a4h2il"
     (:body :l2l5 :type :l2 :head :e :active-wheel :ankle :wrist :r :gripper t :passive-wheel :gripper
	    :board :armh7
	    :wrist-sensor :larm :gripper-inner :larm :neck-jf :a :sole-sensor :rleg :sole :lleg) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-r -1)    (23 :larm-wrist-r -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    ("kxrl2w2l5a4h2ir"
     (:body :l2l5 :type :l2 :head :e :active-wheel :ankle :wrist :r
	    :board :armh7
	    :gripper t :passive-wheel :gripper :wrist-sensor :rarm
	    :gripper-sensor t ;; :gripper-sensor :rarm
	    :gripper-inner :rarm
	    :neck-jf :a :sole-sensor :lleg :sole :rleg) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-r -1)    (23 :larm-wrist-r -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    ("kxrl2w2l5a4h2pgr"
     (:body :l2l5 :type :l2 :head :e :active-wheel :ankle :wrist :r :gripper t
	    :passive-wheel :gripper :gripper-axis :p :neck-jf :a :sole t) ;; 24
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)     (21 :lleg-ankle-w -1)
     (22 :rarm-wrist-r -1)    (23 :larm-wrist-r -1)
     (30 :head-neck-y -1)     (32 :head-neck-p 1)
     )
    (("kxrl2l6a3")
     (:body :l2l6 :type :l2 :sole t)	;; 19
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)

     (8 :rleg-crotch-r 1)     (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)      (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)    (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)    (17 :lleg-ankle-r -1)
     (24 :rleg-crotch-y 1)    (25 :lleg-crotch-y 1)

     (30 :head-neck-y 1)
     )
    (("kxrl2l6a4")
     (:body :l2l6 :type :l2 :shoulder :p :head :e :neck-jf :b :sole t ;;  21
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (30 :head-neck-y 1)
     )
    (("kxrl2l6a4h2")
     (:body :l2l6 :type :l2 :shoulder :p :gripper t :head :e :neck-jf :b :sole t	       ;; 24
	    :project-file "kxrl2l6a4h2")
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)

     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (30 :head-neck-y -1)       (32 :head-neck-p 1)
     )
    (("kxrl2w2l6a4" "kxrl2w2l6a4h2")
     (:body :l2l6 :type :l2 :active-wheel :ankle :shoulder :p :gripper t
	    :head :e :neck-jf :b :passive-wheel :gripper :sole t   ;; 26
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)

     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-ankle-w 1)       (21 :lleg-ankle-w -1)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (30 :head-neck-y -1)       (32 :head-neck-p 1)
     )
    (("kxrl2w2l6a4h2c")		;; 26
     (:body :l2l6r :type :l2 :neck-jf :a :active-wheel :crotch :head :e
	    :board :rcb4
	    :shoulder :p :gripper t :sole t ;; :passive-wheel :gripper
	    :project-file "kxrl2w2l6a4h2")
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)

     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-crotch-w 1)      (21 :lleg-crotch-w -1)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (30 :head-neck-y -1)       (32 :head-neck-p 1)
     )
    (("kxrl2cinaba" "kxrl2w2l6a4h2ca")		;; 28
     (:body :l2l6r :type :l2 :neck-jf :a :active-wheel :crotch :head :h2sf
	    :board :armh7
	    :shoulder :p :gripper t :sole t ;; :passive-wheel :gripper
	    :project-file "kxrl2w2l6a4h2")
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)

     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-crotch-w 1)      (21 :lleg-crotch-w -1)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (30 :head-neck-y -1)       (32 :head-neck-p -1)
     (28 :head-leye-y -1)     (34 :head-reye-y -1)
     )
    (("kxrl2l6a5h2")    ;; 26
     (
      :file "models/kxrl2l6a5h2.l" :form (kxrl2l6a5h2)
      :body :l2l6 :type :l2 :shoulder :p :wrist :r :gripper t :sole t :head :e)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)

     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r 1)
     (30 :head-neck-y -1)       (32 :head-neck-p 1)
     )
    (("kxrl2w2l6a5h2")
     (:body :l2l6w :type :l2 :active-wheel :ankle :shoulder :p :wrist :r
	    :gripper t :head :m5u3sv2 :passive-wheel :gripper :sole t) ;; 28
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-ankle-w 1)       (21 :lleg-ankle-w -1)
     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r 1)
     (30 :head-neck-y -1)       (32 :head-neck-p 1)
     )
    (("kxrl2l6a6")
     (:body :l2l6w :type :l2 :shoulder :cross :wrist :cross :gripper t :sole t :head :m3eye) ;; 26
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (26 :rarm-wrist-p -1)      (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     )
    (("kxrl2l6a6h2-old")
     (:body :l2l6w :type :l2 :head :e :shoulder :cross :wrist :cross :gripper t :sole t
	    :board :armh7
	    ) ;; 28
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p -1)      (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     )
    (("kxrl2l6a6inaba")
     (
      :body :l2l6b :type :l2
      :head :m3deye :3eye-rev 9 :3eye-front t :3eye-cover t
      :head-length 20 :m5stickv nil
      :shoulder :pry-cross
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor (:finger1 :rev-a) ;; :finger1 outside(drive :gripper-r), :finger2 inside(:gripper2-r)
      :sole t
      :board :armh7
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-y 0) (:rarm-wrist-y  0)
			 )
      ) ;; 28
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p -1)      (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     )
    (("kxrl2l6a6inaba2")
     (
      :body :l2l6 :type :l2
      :head :m3deye :3eye-rev 9 :3eye-front t :3eye-cover t
      :head-length 20 :m5stickv nil
      :shoulder :pry-cross
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor (:finger1 :rev-a) ;; :finger1 outside(drive :gripper-r), :finger2 inside(:gripper2-r)
      :sole t
      :board :armh7
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-y 0) (:rarm-wrist-y  0)
			 )
      ) ;; 28
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p -1)      (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     )
    (("kxrl2l6a6inaba3") ;; compact 355mm height, normal body: 409mm
     (
      :body :l2l6s :type :l2
      :head :m3deye :3eye-rev 9 :3eye-front t :3eye-cover t
      :head-length 20 :m5stickv nil
      :shoulder :pry-cross
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor (:finger1 :rev-a) ;; :finger1 outside(drive :gripper-r), :finger2 inside(:gripper2-r)
      :sole t
      :board :armh7
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-y 0) (:rarm-wrist-y  0)
			 )
      ) ;; 28
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p -1)      (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     )
    (("kxrl2l6a6inaba4") ;; compact 355mm height, normal body: 409mm
     (
      :body :l2l6s :type :l2
      ;;:head :m3deye :3eye-rev 9 :3eye-front t :3eye-cover t
      :head :d405cam :3eye-rev 9 :3eye-front t :3eye-cover t
      :head-length 20 :m5stickv nil
      :shoulder :pry-cross
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor (:finger1 :rev-a) ;; :finger1 outside(drive :gripper-r), :finger2 inside(:gripper2-r)
      :sole t
      :board :armh7
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-y 0) (:rarm-wrist-y  0)
			 )
      ) ;; 28
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p -1)      (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     )
    (("kxrl2t2l6a7h2d405")
     (:body :l2l6c :type :l2 :torso :y-p :shoulder :cross :wrist :y-cross
	    :chest-worm t :head :d405cam :head-length 20
	    :neck-jf :b  :gripper t  :gripper-sensor :rev-a :sole t
	    )
     (2 :rarm-shoulder-p 1 30) (3 :larm-shoulder-p -1 -30)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1 90)     (7 :larm-elbow-p 1 90)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1 -45)    (13 :lleg-knee-p 1 -45)
     (14 :rleg-ankle-p -1 45)   (15 :lleg-ankle-p -1 45)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p -1)      (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (20 :rarm-wrist-y 1)       (21 :larm-wrist-y 1)
     (30 :torso-chest-y -1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     (34 :torso-chest-p 1)
     ;;
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 larm-gripper2-r-KJS-01) ;; sensor-board 21
     (42 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (44 rarm-gripper2-r-KJS-01) ;; sensor-board 23
     ;;
     ;; (38 ("larm-wrist" "KJS" "gripper-")) ;; sensor-board 19
     ;; (40 ("larm-wrist" "KJS" "gripper2")) ;; sensor-board 20
     ;; (42 ("rarm-wrist" "KJS" "gripper-")) ;; sensor-board 21
     ;; (44 ("rarm-wrist" "KJS" "gripper2-")) ;; sensor-board 22
     )
    (("kxrl2l6a6h2b") 		;; 28
     (:body :l2l6b :type :l2
	    :sole t :name "kxrl2l6a6h2inaba"
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
	    ;;:shoulder-p-sensor :horn-mag-
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :gripper t :gripper-straight t :gripper-axis :y
	    :head :d405cam :3eye-front t :head-length 20
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-r 0) (:rarm-wrist-r  0)
			       )
	    ;;      :init-form (print (list 'self= self 'args= args))
	    )
     (2 :rarm-shoulder-p 1 -45)     (3 :larm-shoulder-p -1 -45)
     (4 :rarm-shoulder-r 1 -7)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1 5)       (9 :lleg-crotch-r 1 -5)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1 -5)      (17 :lleg-ankle-r -1 5)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1 -5)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)

     (44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    ;;;
    (("kxrl2l6a6h2") 		;; 28
     (:body :l2l6 :type :l2 :sole t
	    :project-file "kxrl2l6a6h2"
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    ;;:shoulder-p-sensor :horn-mag-
	    ;;:elbow-p-sensor :mag-7      :wrist-sensor :mag-7
	    ;;:crotch-p-sensor :rev-a      :crotch-r-sensor :mag-7
	    ;;:crotch-y-sensor :rev-a      :knee-p-sensor :mag-7
	    ;;:ankle-r-sensor :mag-7      :ankle-sensor :mag-7
	    ;;:active-wheel :crotch ;; :ankle ;; :crotch
	    :gripper t :gripper-straight t :gripper-axis :y
	    :head :d405cam :3eye-front t :head-length 20
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-r 0) (:rarm-wrist-r  0)
			       )
	    ;;      :init-form (print (list 'self= self 'args= args))
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     ;;(20 :rleg-crotch-w 1)       (21 :lleg-crotch-w -1)
     ;;(20 :rleg-ankle-w 1)       (21 :lleg-ankle-w -1)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     (42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     (44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2l5a6h2m0") 		;; 28
     (:body :l2l5m :type :l2 :sole t
	    :project-file "kxrl2l5a6h2g"
	    :head :d405echos :3eye-front t :head-length 20
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :gripper t :gripper-straight t :gripper-axis :y
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:lleg-crotch-p -15) (:rleg-crotch-p -15)
			       (:lleg-knee-p 30) (:rleg-knee-p 30)
			       (:lleg-ankle-p -15) (:rleg-ankle-p -15)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-r 0) (:rarm-wrist-r  0)
			       )
	    ;;      :init-form (print (list 'self= self 'args= args))
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     )
    (("kxra6h2m") 		;; 28
     (:body :l2l6m :type :l2 :sole t
	    :project-file "kxra6g"
	    :head :d405echos :3eye-front t :head-length 20
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    ;;:shoulder-p-sensor :horn-mag-
	    ;;:elbow-p-sensor :mag-7      :wrist-sensor :mag-7
	    ;;:crotch-p-sensor :rev-a      :crotch-r-sensor :mag-7
	    ;;:crotch-y-sensor :rev-a      :knee-p-sensor :mag-7
	    ;;:ankle-r-sensor :mag-7      :ankle-sensor :mag-7
	    ;;:active-wheel :crotch ;; :ankle ;; :crotch
	    :gripper t :gripper-straight t :gripper-axis :y
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-r 0) (:rarm-wrist-r  0)
			       )
	    ;;      :init-form (print (list 'self= self 'args= args))
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     ;;     (20 :rleg-crotch-w 1)     (21 :lleg-crotch-w 1)
     ;;     (30 :rleg-knee-w 1)       (31 :lleg-knee-w 1)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     )
    (("kxrl2l6a6h2g") 		;; 28
     (:body :l2l6m :type :l2 :sole t
	    ;;:project-file "kxra6g"
	    :project-file "kxrl2l6a6h2g"
	    :head :d405echos :3eye-front t :head-length 20
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    ;;:shoulder-p-sensor :horn-mag-
	    ;;:elbow-p-sensor :mag-7      :wrist-sensor :mag-7
	    ;;:crotch-p-sensor :rev-a      :crotch-r-sensor :mag-7
	    ;;:crotch-y-sensor :rev-a      :knee-p-sensor :mag-7
	    ;;:ankle-r-sensor :mag-7      :ankle-sensor :mag-7
	    ;;:active-wheel :crotch ;; :ankle ;; :crotch
	    :gripper t :gripper-straight t :gripper-axis :y
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:lleg-crotch-p -15) (:rleg-crotch-p -15)
			       (:lleg-knee-p 30) (:rleg-knee-p 30)
			       (:lleg-ankle-p -15) (:rleg-ankle-p -15)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-r 0) (:rarm-wrist-r  0)
			       )
	    ;;      :init-form (print (list 'self= self 'args= args))
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     )
    (("kxrl2l6a6h2m")
     (:body :l2l6m :type :l2 :sole t
	    :project-file "kxra6g"
	    ;;:project-file "kxrl2l6a6h2g"
	    :head :d405echos :3eye-front t :head-length 20
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    ;;:shoulder-p-sensor :horn-mag-
	    ;;:elbow-p-sensor :mag-7      :wrist-sensor :mag-7
	    ;;:crotch-p-sensor :rev-a      :crotch-r-sensor :mag-7
	    ;;:crotch-y-sensor :rev-a      :knee-p-sensor :mag-7
	    ;;:ankle-r-sensor :mag-7      :ankle-sensor :mag-7
	    ;;:active-wheel :crotch ;; :ankle ;; :crotch
	    :gripper t :gripper-straight t :gripper-axis :y
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:lleg-crotch-p -15) (:rleg-crotch-p -15)
			       (:lleg-knee-p 30) (:rleg-knee-p 30)
			       (:lleg-ankle-p -15) (:rleg-ankle-p -15)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-r 0) (:rarm-wrist-r  0)
			       )
	    ;;      :init-form (print (list 'self= self 'args= args))
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     )
    (("kxrl2l6a7h2")
     (:body :l2l6 :type :l2 :sole t
	    ;;:project-file "kxrl2l6a6h2"
	    :shoulder :ypry-cross :shoulder-front t
	    ;;:shoulder-p-sensor :horn-mag-
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    ;;:elbow-p-sensor :mag-7      :wrist-sensor :mag-7
	    ;;:crotch-p-sensor :rev-a      :crotch-r-sensor :mag-7
	    ;;:crotch-y-sensor :rev-a      :knee-p-sensor :mag-7
	    ;;:ankle-r-sensor :mag-7      :ankle-sensor :mag-7
	    ;;:active-wheel :crotch ;; :ankle ;; :crotch
	    :gripper t :gripper-straight t :gripper-axis :y
	    :head :d405cam :3eye-front t :head-length 20
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-r 0) (:rarm-wrist-r  0)
			       )
	    ;;      :init-form (print (list 'self= self 'args= args))
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     ;;(20 :rleg-crotch-w 1)       (21 :lleg-crotch-w -1)
     ;;(20 :rleg-ankle-w 1)       (21 :lleg-ankle-w -1)

     (22 :rarm-elbow-y 1)       (23 :larm-elbow-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (30 :rarm-shoulder-y 1)    (31 :larm-shoulder-y 1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     (42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     (44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2l6a7h2m")
     (:body :l2l6m :type :l2 :sole t
	    :project-file "kxrl2l6a6h2g"
	    :head :d405echos :3eye-front t :head-length 20
	    :shoulder :ypry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil
	    :shoulder-p-sensor :horn-mag-
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    ;;:elbow-p-sensor :mag-7      :wrist-sensor :mag-7
	    ;;:crotch-p-sensor :rev-a      :crotch-r-sensor :mag-7
	    ;;:crotch-y-sensor :rev-a      :knee-p-sensor :mag-7
	    ;;:ankle-r-sensor :mag-7      :ankle-sensor :mag-7
	    ;;:active-wheel :crotch ;; :ankle ;; :crotch
	    :gripper t :gripper-straight t :gripper-axis :y
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-r 0) (:rarm-wrist-r  0)
			       )
	    ;;      :init-form (print (list 'self= self 'args= args))
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-elbow-y 1)       (23 :larm-elbow-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (30 :rarm-shoulder-y 1)    (31 :larm-shoulder-y 1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    (("kxrl2l5a6h2") 		;; 28
     (:body :l2l5 :type :l2 :sole t
	    :project-file "kxrl2l5a6h2g"
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
	    :shoulder-p-sensor :horn-mag-
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :elbow-p-sensor :mag-7
	    :wrist-sensor :mag-7
	    :crotch-p-sensor :rev-a
	    :crotch-r-sensor :mag-7
	    :crotch-y-sensor :rev-a
	    :knee-p-sensor :mag-7
	    :ankle-r-sensor :mag-7
	    :ankle-sensor :mag-7
	    ;;:active-wheel :crotch ;; :ankle ;; :crotch
	    :gripper t :gripper-straight t :gripper-axis :y
	    :head :d405cam :3eye-front t :head-length 20
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-r 0) (:rarm-wrist-r  0)
			       )
	    ;;      :init-form (print (list 'self= self 'args= args))
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     ;;(24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     (42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     (44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2l5a6h2m") 		;; 28
     (:body :l2l5m :type :l2 :sole t
	    :project-file "kxra6g"
	    ;;:project-file "kxrl2l5a6h2g"
	    :head :d405echos :3eye-front t :head-length 20
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t
	    :flat-shoulder nil ;;:shoulder :ly-p-rb
	    :shoulder-p-sensor :horn-mag-
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :elbow-p-sensor :mag-7 	:wrist-sensor :mag-7
	    :crotch-p-sensor :rev-a   :crotch-r-sensor :mag-7
	    :crotch-y-sensor :rev-a   :knee-p-sensor :mag-7
	    :ankle-r-sensor :mag-7    :ankle-sensor :mag-7
	    ;;:active-wheel :crotch ;; :ankle ;; :crotch
	    :gripper t :gripper-straight t :gripper-axis :y
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:lleg-crotch-p -15) (:rleg-crotch-p -15)
			       (:lleg-knee-p 30) (:rleg-knee-p 30)
			       (:lleg-ankle-p -15) (:rleg-ankle-p -15)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-r 0) (:rarm-wrist-r  0)
			       )
	    ;;      :init-form (print (list 'self= self 'args= args))
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     ;;(24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     ;;(42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     ;;(44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2l5a7h2")
     (:body :l2l5 :type :l2 :sole t
	    :project-file "kxrl2l6a6h2"
	    :shoulder :ypry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
	    :shoulder-p-sensor :horn-mag-
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :elbow-p-sensor :mag-7
	    :wrist-sensor :mag-7
	    :crotch-p-sensor :rev-a
	    :crotch-r-sensor :mag-7
	    :crotch-y-sensor :rev-a
	    :knee-p-sensor :mag-7
	    :ankle-r-sensor :mag-7
	    :ankle-sensor :mag-7
	    ;;:active-wheel :crotch ;; :ankle ;; :crotch
	    :gripper t :gripper-straight t :gripper-axis :y
	    :head :d405cam :3eye-front t :head-length 20
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-r 0) (:rarm-wrist-r  0)
			       )
	    ;;      :init-form (print (list 'self= self 'args= args))
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-elbow-y 1)       (23 :larm-elbow-y 1)
     ;;(24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (30 :rarm-shoulder-y 1)    (31 :larm-shoulder-y 1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     (42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     (44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2l5a7h2m")
     (:body :l2l5m :type :l2 :sole t
	    :project-file "kxrl2l5a6h2g"
	    :head :d405echos :3eye-front t :head-length 20
	    :shoulder :ypry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil
	    :shoulder-p-sensor :horn-mag-
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :elbow-p-sensor :mag-7
	    :wrist-sensor :mag-7
	    :crotch-p-sensor :rev-a
	    :crotch-r-sensor :mag-7
	    :crotch-y-sensor :rev-a
	    :knee-p-sensor :mag-7
	    :ankle-r-sensor :mag-7
	    :ankle-sensor :mag-7
	    ;;:active-wheel :crotch ;; :ankle ;; :crotch
	    :gripper t :gripper-straight t :gripper-axis :y
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-r 0) (:rarm-wrist-r  0)
			       )
	    ;;      :init-form (print (list 'self= self 'args= args))
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-elbow-y 1)       (23 :larm-elbow-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (30 :rarm-shoulder-y 1)    (31 :larm-shoulder-y 1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     ;;(42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     ;;(44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2l2a4h2")
     (
      ;; :file "models/kxrl2l2a4h2.l" :form (kxrl2l2a4h2)
      ;; :com-init-method (:com-init :devname "ttyAML1")
      :body :l2l6 :type :l2 :sole t
      :shoulder :p-r-y :gripper t :neck-jf :a 
      :project-file "kxrl2l5a4h2g"
      :leg :j2-pr :sole t 
      :head :d405cam :3eye-front t :head-length 20
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r 1)     (17 :lleg-crotch-r 1)
     
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     
     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    (("kxrl2l2a4h2m")
     (
      :body :l2l6 :type :l2 :sole t
      :shoulder :p-r-y :gripper t :neck-jf :a 
      :project-file "kxrl2l5a4h2g"
      :leg :j2-pr :sole t 
      :head :d405eyes
      :3eye-front t :head-length 20
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)
     
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     
     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    (("kxrl2l2a4h2mi")
     (
      :body :l2l6 :type :l2 :sole t
      :shoulder :p-r-y :gripper t :neck-jf :a 
      :project-file "kxrl2l5a4h2g"
      :leg :j2-pr :sole t 
      :head :d405eyes-iris ;;:textured eyes
      :3eye-front t :head-length 20
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)
     
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     
     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    (("kxrt1l2l2a4h2m")
     (
      :body :l2l6c :type :l2 :sole t :torso :y
      :shoulder :p-r-y :gripper t :neck-jf :a 
      :project-file "kxrl2l5a4h2g"
      :crotch-p nil :crotch-center-front t
      :crotch-side-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :head :d405eyes ;;:d405cam
      :3eye-front t :head-length 20
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)
     
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     
     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     (33 :torso-chest-y -1)
     )
    (("kxrl2l2a6h2") 		;; 28
     (
      ;; :file "models/kxrl2l2a6h2.l" :form (kxrl2l2a6h2)
      ;; (progn (load "additional-settings.l") (kxrl2l2a6h2))
      ;; :com-init-method (:com-init :devname "ttyAML1")
      :body :l2l6 :type :l2
      :project-file "kxra6g"
      ;;:project-file "kxrl2l6a6h2"
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      ;; :shoulder-p-sensor :horn-mag-
      ;; :elbow-p-sensor :mag-7 :wrist-sensor :mag-7
      ;; :crotch-r-sensor :mag-7 :crotch-y-sensor :rev-a
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :gripper t :gripper-straight t :gripper-axis :y
      :head :d405cam :3eye-front t :head-length 20
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      ;;      :init-form (print (list 'self= self 'args= args))
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     ;; (42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     ;; (44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl4l2a6h2m")
     (
      :body :l2l6m :type :l4
      :project-file "kxrl2l2a6h2g"
      :head :d405echos :3eye-front t :head-length 20
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      ;; :shoulder-p-sensor :horn-mag-
      ;; :elbow-p-sensor :mag-7 :wrist-sensor :mag-7
      ;; :crotch-r-sensor :mag-7 :crotch-y-sensor :rev-a
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      :legs (:j2 :j2)
      ;;:leg :j2-pr :sole t 
      :gripper t :gripper-straight t :gripper-axis :y
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      ;;      :init-form (print (list 'self= self 'args= args))
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     ;;(16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (20 :rleg-knee-y 1)        (21 :lleg-knee-y 1)
     (16 :rleg-knee-r -1)       (17 :lleg-knee-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     ;;(24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     ;;(42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     ;;(44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2l2a6h2i")
     (
      :body :l2l6m :type :l2
      :board :rcb4-acc-reverse
      :project-file "kxra6g"
      ;;:project-file "kxrl2l6a6h2"
      :head :d405eyes ;;:head :d405echos
      :3eye-front t :head-length 20
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      ;; :shoulder-p-sensor :horn-mag-
      ;; :elbow-p-sensor :mag-7 :wrist-sensor :mag-7
      ;; :crotch-r-sensor :mag-7 :crotch-y-sensor :rev-a
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :gripper t :gripper-straight t :gripper-axis :y
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      ;;      :init-form (print (list 'self= self 'args= args))
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     ;;(42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     ;;(44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2l2a6h2m") 		;; 28
     (
      :body :l2l6m :type :l2
      :project-file "kxra6g"
      ;;:project-file "kxrl2l6a6h2"
      :head :d405eyes ;;:head :d405echos
      :3eye-front t :head-length 20
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      ;; :shoulder-p-sensor :horn-mag-
      ;; :elbow-p-sensor :mag-7 :wrist-sensor :mag-7
      ;; :crotch-r-sensor :mag-7 :crotch-y-sensor :rev-a
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :gripper t :gripper-straight t :gripper-axis :y
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      ;;      :init-form (print (list 'self= self 'args= args))
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     ;;(42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     ;;(44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2l2a6h2mr")
     (
      :body :l2l6m :type :l2
      :project-file "kxra6g"
      ;;:project-file "kxrl2l6a6h2"
      :board :rcb4
      :head :d405eyes ;;:head :d405echos
      :3eye-front t :head-length 20
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      ;; :shoulder-p-sensor :horn-mag-
      ;; :elbow-p-sensor :mag-7 :wrist-sensor :mag-7
      ;; :crotch-r-sensor :mag-7 :crotch-y-sensor :rev-a
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :gripper t :gripper-straight t :gripper-axis :y
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      ;;      :init-form (print (list 'self= self 'args= args))
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p 1)
     
     ;;(42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     ;;(44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrkanehiro") 		;; rubik cube finger
     (
      :body :l2l6m :type :l2
      :project-file "kxra6g"
      :head :d405echos ;; :d405eyes ;;:head :d405echos
      :neck-jf :b-back
      :3eye-front t :head-length 20
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :wcross-pr :upper-arm-length 38 
      :shoulder-p-sensor :horn-mag-
      ;; :elbow-p-sensor :mag-7
      :wrist-sensor :horn-mag-
      ;; :crotch-r-sensor :mag-7 :crotch-y-sensor :rev-a
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :attachment :down
      :gripper t :gripper-straight t :gripper-axis (:y :p)
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      ;;      :init-form (print (list 'self= self 'args= args))
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     ;;(42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     ;;(44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2l2inaba") 		;; rubik cube finger
     (
      :body :l2l6m :type :l2
      :project-file "kxra6g"
      :head :d405echos ;; :d405eyes ;;:head :d405echos
      :neck-jf :b-back
      :3eye-front t :head-length 20
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :wcross-pr :upper-arm-length 38 
      :shoulder-p-sensor :horn-mag-
      ;; :elbow-p-sensor :mag-7
      :wrist-sensor :horn-mag-
      ;; :crotch-r-sensor :mag-7 :crotch-y-sensor :rev-a
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :attachment :down
      :gripper t :gripper-straight t :gripper-axis (:y :p)
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      ;;      :init-form (print (list 'self= self 'args= args))
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     ;;(42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     ;;(44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2l2a6h2mi") 		;; 28
     (
      :body :l2l6m :type :l2
      :project-file "kxra6g"
      ;;:project-file "kxrl2l6a6h2"
      :head :d405eyes-iris
      :3eye-front t :head-length 20
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      ;; :shoulder-p-sensor :horn-mag-
      ;; :elbow-p-sensor :mag-7 :wrist-sensor :mag-7
      ;; :crotch-r-sensor :mag-7 :crotch-y-sensor :rev-a
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :gripper t :gripper-straight t :gripper-axis :y
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      ;;      :init-form (print (list 'self= self 'args= args))
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     ;;(42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     ;;(44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2l2a6h2md") 		;; driver
     (
      :body :l2l6m :type :l2
      :project-file "kxra6g"
      :head :d405eyes ;;:head :d405echos
      :3eye-front t :head-length 20
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      :driver (:rarm)
      :gripper (:larm) :gripper-axis :y :gripper-straight t
      :leg :j2-pr :sole t 
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (18 :rarm-gripper-r 1)    (19 :larm-gripper-r 1)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    (("kxrl2l2a7h2m") 		;; 28
     (
      ;; (progn (load "additional-settings.l") (kxrl2l2a6h2))
      ;; :com-init-method (:com-init :devname "ttyAML1")
      :body :l2l6m :type :l2
      :project-file "kxrl2l2a6h2g"
      :head :d405echos :3eye-front t :head-length 20
      :shoulder :ypry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      ;; :shoulder-p-sensor :horn-mag-
      ;; :elbow-p-sensor :mag-7 :wrist-sensor :mag-7
      ;; :crotch-r-sensor :mag-7 :crotch-y-sensor :rev-a
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :gripper t :gripper-straight t :gripper-axis :y
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-elbow-y 1)       (23 :larm-elbow-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     
     (30 :rarm-shoulder-y 1 90) (31 :larm-shoulder-y 1 -90)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     )
    (("kxrt1l2l2a6h2m")
     (
      :body :l2l6c :type :l2 :torso :y
      :project-file "kxra6g"
      ;;:project-file "kxrl2l6a6h2"
      :head :d405eyes ;;:head :d405echos
      :3eye-front t :head-length 20
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :crotch-p t :crotch-side-front t :crotch-center-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :gripper t :gripper-straight t :gripper-axis :y
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      ;;      :init-form (print (list 'self= self 'args= args))
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     (33 :torso-chest-y -1)     
     )
    (("kxrt1l2l2e7h2m")  ;; elbow cross frame 3 and 15
     (
      :body :l2l6c :type :l2 :torso :y
      :project-file "kxre7g"
      :head :d405eyes ;;:head :d405echos
      :3eye-front t :head-length 20
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :cross-py :wrist :cross-pr :upper-arm-length 38 
      :crotch-p t :crotch-side-front t :crotch-center-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :gripper t :gripper-straight t :gripper-axis :y
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (30 :rarm-elbow-y 1)       (31 :larm-elbow-y 1)

     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     (33 :torso-chest-y -1)     
     )
    (("kxrt1l2l2d7h2m")  ;; elbow cross frame 3 and 15, wrist :cross-rpy
     (
      :body :l2l6c :type :l2 :torso :y
      :project-file "kxrd7g"
      :head :d405eyes ;;:head :d405echos
      :3eye-front t :head-length 20
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :cross-p :wrist :cross-rpy :upper-arm-length 38 
      :crotch-p t :crotch-side-front t :crotch-center-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :gripper t :gripper-straight t :gripper-axis :z
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      ;;      :init-form (print (list 'self= self 'args= args))
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-y 1)      (29 :larm-wrist-y 1)
     (30 :rarm-wrist-r -1)       (31 :larm-wrist-r -1)
     
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     (33 :torso-chest-y -1)     
     )
    (("kxrt1l2l2w7h2m")  ;; elbow cross frame 3 and 15, wrist :wcross-pr
     (
      :body :l2l6c :type :l2 :torso :y
      :project-file "kxrw7g"
      :head :d405eyes ;;:head :d405echos
      :3eye-front t :head-length 20
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :cross-py :wrist :wcross-pr :upper-arm-length 38 
      :crotch-p t :crotch-side-front t :crotch-center-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :gripper t :gripper-straight t :gripper-axis :y
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-elbow-y 0) (:rarm-elbow-y 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      ;;      :init-form (print (list 'self= self 'args= args))
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (30 :rarm-elbow-y 1)     (31 :larm-elbow-y 1)
     
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     (33 :torso-chest-y -1)     
     )
    (("kxrow4a6h2m")
     (
      ;; (progn (load "additional-settings.l") (kxrl2l2a6h2))
      ;; :com-init-method (:com-init :devname "ttyAML1")
      :project-file "kxra6g"
      :body :l4ow :type :l4 :leg :j2o
      :head :d405echos :3eye-front t :head-length 20
      :wheel-battery-stand t :wheel-base-a t  :lidar t
      :shoulder :pry-cross :shoulder-front t :shoulder-low t
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      ;; :shoulder-p-sensor :horn-mag-
      ;; :elbow-p-sensor :mag-7 :wrist-sensor :mag-7
      ;; :crotch-r-sensor :mag-7 :crotch-y-sensor :rev-a
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :gripper t :gripper-straight t :gripper-axis :y
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     ;;(6 :rarm-elbow-p 1 -90)     (7 :larm-elbow-p 1 -90)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)

     (8 :rleg-crotch-w 1)      (9 :lleg-crotch-w 1)
     (10 :rleg-knee-w 1)       (11 :lleg-knee-w 1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     )
    (("kxrow4a7h2m") 		;; 28
     (
      ;; (progn (load "additional-settings.l") (kxrl2l2a6h2))
      ;; :com-init-method (:com-init :devname "ttyAML1")
      :body :l4ow :type :l4 :leg :j2o
      :head :d405echos :3eye-front t :head-length 20
      :wheel-battery-stand t :wheel-base-a t  :lidar t
      :shoulder :ypry-cross :shoulder-front t :shoulder-low t
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      ;; :shoulder-p-sensor :horn-mag-
      ;; :elbow-p-sensor :mag-7 :wrist-sensor :mag-7
      ;; :crotch-r-sensor :mag-7 :crotch-y-sensor :rev-a
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :gripper t :gripper-straight t :gripper-axis :y
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1 -90)        (7 :larm-elbow-p 1 -90)

     (8 :rleg-crotch-w 1)      (9 :lleg-crotch-w 1)
     (10 :rleg-knee-w 1)       (11 :lleg-knee-w 1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-elbow-y 1)       (23 :larm-elbow-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     
     (30 :rarm-shoulder-y 1 90) (31 :larm-shoulder-y 1 -90)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     )
    (("kxrmw4a4h2m") 		;; 28
     (
      :body :l4mw :type :l4 :leg :j2m 
      :head :d405echos :3eye-front t :head-length 20
      :project-file "kxra6g"    ;;:project-file "kxrl2l6a6h2"
      :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t
      :wheel-servo-stand t :radius 60 :lidar t 
      :shoulder :p-r-y :shoulder-front t :shoulder-low t
      :gripper t :gripper-straight t :gripper-axis :x
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1 -90)     (7 :larm-elbow-p 1 -90)

     (0 :rleg-crotch-w 1)      (1 :lleg-crotch-w -1)
     (20 :rleg-knee-w 1)       (21 :lleg-knee-w -1)
     
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     )
    (("kxrt1mw4a4h2m") 		;; 28
     (
      :body :l4mw :type :l4 :leg :j2m :torso :y
      :head :d405echos :3eye-front t :head-length 20
      :project-file "kxra6g"    ;;:project-file "kxrl2l6a6h2"
      :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t
      :wheel-servo-stand t :radius 60 :lidar t 
      :shoulder :p-r-y :shoulder-front t :shoulder-low t
      ;; :elbow :angle ;; :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t ;; :gripper-axis :y
      ;;:crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      ;;:leg :j2-pr :sole t 
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1 -90)     (7 :larm-elbow-p 1 -90)

     (0 :rleg-crotch-w 1)      (1 :lleg-crotch-w -1)
     (20 :rleg-knee-w 1)       (21 :lleg-knee-w -1)
     
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     (33 :torso-chest-y 1)     
     )
    (("kxrmw4a6h2m") 		;; 28
     (
      ;; (progn (load "additional-settings.l") (kxrl2l2a6h2))
      ;; :com-init-method (:com-init :devname "ttyAML1")
      :body :l4mw :type :l4 :leg :j2m 
      :head :d405echos :3eye-front t :head-length 20
      :project-file "kxra6g"
      ;;:project-file "kxrl2l6a6h2"
      :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t
      :wheel-servo-stand t :radius 60 :lidar t 
      :shoulder :pry-cross :shoulder-front t :shoulder-low t
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      ;; :shoulder-p-sensor :horn-mag-
      ;; :elbow-p-sensor :mag-7 :wrist-sensor :mag-7
      ;; :crotch-r-sensor :mag-7 :crotch-y-sensor :rev-a
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :gripper t :gripper-straight t :gripper-axis :y
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     ;;(6 :rarm-elbow-p 1 -90)     (7 :larm-elbow-p 1 -90)
     (6 :rarm-elbow-p 1)     (7 :larm-elbow-p 1)

     (0 :rleg-crotch-w 1)      (1 :lleg-crotch-w -1)
     (20 :rleg-knee-w 1)       (21 :lleg-knee-w -1)
     
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)    (23 :larm-shoulder-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     )
    (("kxrmw4a7h2m") 		;; 28
     (
      ;; (progn (load "additional-settings.l") (kxrl2l2a6h2))
      ;; :com-init-method (:com-init :devname "ttyAML1")
      :body :l4mw :type :l4 :leg :j2m 
      :head :d405echos :3eye-front t :head-length 20
      :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t
      :wheel-servo-stand t :lidar t
      :shoulder :ypry-cross :shoulder-front t :shoulder-low t
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      ;; :shoulder-p-sensor :horn-mag-
      ;; :elbow-p-sensor :mag-7 :wrist-sensor :mag-7
      ;; :crotch-r-sensor :mag-7 :crotch-y-sensor :rev-a
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :gripper t :gripper-straight t :gripper-axis :y
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)

     (0 :rleg-crotch-w 1)      (1 :lleg-crotch-w 1)
     (20 :rleg-knee-w 1)       (21 :lleg-knee-w 1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-elbow-y 1)       (23 :larm-elbow-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     
     (30 :rarm-shoulder-y 1 90) (31 :larm-shoulder-y 1 -90)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     )
    (("kxrl2l2a7h2")
     (
      ;;:file "models/kxrl2l2a6h2.l" :form (kxrl2l2a6h2)
      ;; (progn (load "additional-settings.l") (kxrl2l2a6h2))
      ;; :com-init-method (:com-init :devname "ttyAML1")
      :body :l2l6m :type :l2
      :project-file "kxrl2l6a6h2"
      :shoulder :ypry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      ;; :shoulder-p-sensor :horn-mag-
      ;; :elbow-p-sensor :mag-7 :wrist-sensor :mag-7
      ;; :crotch-r-sensor :mag-7 :crotch-y-sensor :rev-a
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :gripper t :gripper-straight t :gripper-axis :y
      :head :d405cam :3eye-front t :head-length 20
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      ;;      :init-form (print (list 'self= self 'args= args))
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (20 :rarm-elbow-y 1)     (21 :larm-elbow-y  1)
     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (30 :rarm-shoulder-y 1 90) (31 :larm-shoulder-y 1 -90)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     (42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     (44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2l1a6h2") 		;; 28
     (:body :l2l5a :type :l2 :sole t
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
	    :shoulder-p-sensor :horn-mag-
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :elbow-p-sensor :mag-7
	    :wrist-sensor :mag-7
	    :crotch-p t :crotch-low t :crotch-front t :flat-crotch t :leg :j2-pr :sole t 
	    :crotch-r-sensor :mag-7
	    :crotch-y-sensor :rev-a
	    :gripper t :gripper-straight t :gripper-axis :y
	    :head :d405cam :3eye-front t :head-length 20
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-r 0) (:rarm-wrist-r  0)
			       )
	    ;;      :init-form (print (list 'self= self 'args= args))
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     ;;(42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     ;;(44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2mw4a6h2")	;; mechanum wheel base
     (
      :body :l2l6 :type :l4 :leg :j1-2mw
      :project-file "kxrl2l6a6h2"
      :board :armh7 :shoulder :pry-cross :shoulder-center t :lidar t
      :shoulder-low nil :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor (:finger1 :rev-c) 
      :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t :wheel-servo-stand t
      :head :d405cam :3eye-front t :head-length 20
      ;;:head :d405cam :3eye-front t :head-length 20
      ;;:head :m3deye :3eye-rev 10 :head-lidar t :3eye-cover t :head-length 20
      :m5stickv nil
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)

     (8 :rleg-crotch-w 1)      (9 :lleg-crotch-w 1)
     (10 :rleg-knee-w 1)       (11 :lleg-knee-w 1)
     
     (38 larm-gripper-r-KJS-03) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-03) ;; sensor-board 20
     ;;(38 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 19
     ;;(40 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 20
     )
    (("kxrmw4a6h2")		;; omuni wheel base
     (
      :body :l4mw :type :l4 :leg :j2m ;; :marm :j0m :leg :j0m
      :project-file "kxrl2l6a6h2"
      :board :armh7 :shoulder :pry-cross :shoulder-center t :lidar t
      :shoulder-low nil :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor (:finger1 :rev-c) 
      :wheel-battery-stand t :wheel-base-a nil :wheel-base-wide t :wheel-servo-stand t
      :head :d405cam :3eye-front t :head-length 20
      ;;:head :d405cam :3eye-front t :head-length 20
      ;;:head :m3deye :3eye-rev 10 :head-lidar t :3eye-cover t :head-length 20
      :m5stickv nil
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)

     (8 :rleg-crotch-w 1)      (9 :lleg-crotch-w 1)
     (10 :rleg-knee-w 1)       (11 :lleg-knee-w 1)

     (38 larm-gripper-r-KJS-03) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-03) ;; sensor-board 20
     ;;(38 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 19
     ;;(40 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 20
     )
    (("kxrow4a6h2")		;; omuni wheel base
     (
      :body :l4ow :type :l4 :leg :j2o
      :board :armh7 :shoulder :pry-cross :shoulder-center t :lidar t
      :shoulder-low nil :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor (:finger1 :rev-c) 
      :wheel-battery-stand nil :wheel-base-a t
      :head :d405cam :3eye-front t :head-length 20
      ;;:head :m3deye :3eye-rev 10 :head-lidar t :3eye-cover t :head-length 20
      :m5stickv nil
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)

     (8 :rleg-crotch-w 1)      (9 :lleg-crotch-w 1)
     (10 :rleg-knee-w 1)       (11 :lleg-knee-w 1)
     
     ;;(38 larm-gripper-r-KJS-03) ;; sensor-board 19
     ;;(40 rarm-gripper-r-KJS-03) ;; sensor-board 20
     ;;(38 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 19
     ;;(40 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 20
     )
    (("kxrl2l6a6h2v1") 		;; 28
     (:body :l2l6b :type :l2
	    :sole t :name "kxrl2l6a6h2inaba"
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
	    :shoulder-p-sensor :horn-mag-
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :elbow-p-sensor :mag-7
	    :wrist-sensor :sensor-mag+
	    :crotch-p-sensor :rev-a
	    :crotch-r-sensor :mag-7
	    :crotch-y-sensor :rev-a
	    :knee-p-sensor :mag-7
	    :ankle-r-sensor :mag-7
	    :ankle-sensor :mag-7
	    :gripper t :gripper-straight t :gripper-axis :y
	    :head :d405cam :3eye-front t :head-length 20
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-r 0) (:rarm-wrist-r  0)
			       )
	    ;;      :init-form (print (list 'self= self 'args= args))
	    )
     (2 :rarm-shoulder-p 1 -45)     (3 :larm-shoulder-p -1 -45)
     (4 :rarm-shoulder-r 1 -7)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1 5)       (9 :lleg-crotch-r 1 -5)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1 -5)      (17 :lleg-ankle-r -1 5)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1 -5)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)

     (44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2l6a6h2mag") 		;; 28
     (:body :l2l6b :type :l2
	    :sole t :name "kxrl2l6a6h2inaba"
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
	    :shoulder-p-sensor :horn-mag-
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :elbow-p-sensor :mag-7
	    :wrist-sensor :sensor-mag+
	    :crotch-p-sensor :rev-a
	    :crotch-r-sensor :mag-7
	    :crotch-y-sensor :rev-a
	    :knee-p-sensor :mag-7
	    :ankle-r-sensor :mag-7
	    :ankle-sensor :mag-7
	    :gripper t :gripper-straight t :gripper-axis :y
	    :head :d405cam :3eye-front t :head-length 20
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-r 0) (:rarm-wrist-r  0)
			       )
	    ;;      :init-form (print (list 'self= self 'args= args))
	    )
     (2 :rarm-shoulder-p 1 -45)     (3 :larm-shoulder-p -1 -45)
     (4 :rarm-shoulder-r 1 -7)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1 5)       (9 :lleg-crotch-r 1 -5)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1 -5)      (17 :lleg-ankle-r -1 5)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1 -5)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)

     (44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2l6a6h2n") 		;; 28
     (:body :l2l6 :type :l2 :shoulder :cross :wrist :y-p :gripper t
	    :head :e :neck-jf :b :sole t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p 1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     )
    (("kxrl2w2l6a6h2")
     (:body :l2l6b :type :l2
	    :sole t :name "kxrl2l6a6h2inaba"
	    :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
	    :shoulder-p-sensor :horn-mag-
	    :elbow :angle :wrist :cross-pr :upper-arm-length 38 
	    :elbow-p-sensor :mag-7
	    :wrist-sensor :mag-7
	    :crotch-p-sensor :rev-a
	    :crotch-r-sensor :mag-7
	    :crotch-y-sensor :rev-a
	    :knee-p-sensor :mag-7
	    :ankle-r-sensor :mag-7
	    :ankle-sensor :mag-7
	    :active-wheel :crotch ;; :ankle ;; :crotch
	    :gripper t :gripper-straight t :gripper-axis :y
	    :head :d405cam :3eye-front t :head-length 20
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-r 0) (:rarm-wrist-r  0)
			       )
	    ;;      :init-form (print (list 'self= self 'args= args))
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (20 :rleg-crotch-w 1)       (21 :lleg-crotch-w -1)
     ;;(20 :rleg-ankle-w 1)       (21 :lleg-ankle-w -1)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     (44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    (("kxrl2w2l6a6h2old" "kxrl2w2l6a6h2nold")		;; 30
     (:body :l2l6 :type :l2 :active-wheel :ankle :shoulder :cross :wrist :y-p :gripper t
	    :head :e :neck-jf :b :passive-wheel :gripper :sole t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)

     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)     (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)    (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w 1)       (21 :lleg-ankle-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p 1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     )
    (("kxrl2l6a7")	;; 29
     (:body :l2l6w :type :l2 :shoulder :cross :wrist :cross-y :gripper t :head :e :neck-jf :b :sole t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p -1)      (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :head-neck-y -1)
     )
    (("kxrl2l6a7h2n")
     (:body :l2l6 :type :l2 :shoulder :cross :wrist :cross-y :gripper t :head :h2s :neck-jf :b :sole t
	    :board :armh7
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p -1)      (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     )
    (("kxrl2l6a3h2w")		;;
     (:body :l2l6w :type :l2 :gripper t :head :e :neck-jf :b :sole t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     )
    (("kxrl2l6a3h2w-arm-no-projectfile")	;;
     (:body :l2l6w :type :l2 :gripper t :head :e :neck-jf :b :sole t
	    :gripper-sensor :finger1
	    )
     (2 :rarm-shoulder-p 1 45)    (3 :larm-shoulder-p -1 -45)
     (4 :rarm-shoulder-r -1 -90)  (5 :larm-shoulder-r 1 -90)
     (6 :rarm-elbow-p 1)          (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)       (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1 -70.8667)        (13 :lleg-knee-p 1 -66.0667)
     (14 :rleg-ankle-p -1 18.03)      (15 :lleg-ankle-p -1 20.43)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     ;;
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     ;;(38 ("larm-elbow" "KJS" "gripper-")) ;; sensor-board 19
     ;;(40 ("rarm-elbow" "KJS" "gripper-")) ;; sensor-board 20
     )
    (("kxrl2l6a3h2wa" "kxrl2l6inaba")	;;
     (:body :l2l6w :type :l2 :gripper t :head :e :neck-jf :b :sole t
	    :gripper-sensor :finger1
	    :project-file "kxrl2l6a3h2w"
	    )
     (2 :rarm-shoulder-p 1)    (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)          (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)       (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     ;;
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     ;;(38 ("larm-elbow" "KJS" "gripper-")) ;; sensor-board 19
     ;;(40 ("rarm-elbow" "KJS" "gripper-")) ;; sensor-board 20
     )

    (("kxrl2l6a7h2w")		;; 30
     (:body :l2l6w :type :l2 :shoulder :cross :wrist :y-cross :gripper t :head :e :neck-jf :b :sole t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p -1)      (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     )
    (("kxrl2l6a7h2ypy")		;; 30 no torso
     (:body :l2l6 :type :l2 :shoulder :cross :wrist :y-p-y :gripper t :neck-jf :a :sole t :head :m5sh)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     ;;(6 :rarm-elbow-p 1 90)    (7 :larm-elbow-p 1 90)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     ;;(12 :rleg-knee-p 1 -66)    (13 :lleg-knee-p 1 -66)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r  1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rarm-wrist-y 1)       (21 :larm-wrist-y 1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-elbow-y 1)      (27 :larm-elbow-y 1)
     (28 :rarm-wrist-p 1)      (29 :larm-wrist-p 1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     )
    (("kxrl2t2l6a3h2")	;; with 2D y-p torso
     (:body :l2l6c :type :l2 :torso :y-p :gripper t :neck-jf :b :sole t :head :m5sh)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (30 :torso-chest-y -1)
     (32 :head-neck-y -1)      (33 :head-neck-p -1)
     (34 :torso-chest-p 1)
     )
    (("kxrl2t2l6a7h2yprb" "kxrl2t2inaba")	;; 32 from kxrl2l6a7h2w's arm 2020.1.8
     (:body :l2l6c :type :l2 :torso :y-p :shoulder :cross :wrist :y-cross
	    :chest-worm t
	    :gripper t :head :m5sh :neck-jf :b :gripper-sensor :rev-a :sole t
	    )
     (2 :rarm-shoulder-p 1 30) (3 :larm-shoulder-p -1 -30)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1 90)     (7 :larm-elbow-p 1 90)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1 -45)    (13 :lleg-knee-p 1 -45)
     (14 :rleg-ankle-p -1 45)   (15 :lleg-ankle-p -1 45)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p -1)      (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (20 :rarm-wrist-y 1)       (21 :larm-wrist-y 1)
     (30 :torso-chest-y -1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     (34 :torso-chest-p 1)
     ;;
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 larm-gripper2-r-KJS-01) ;; sensor-board 21
     (42 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (44 rarm-gripper2-r-KJS-01) ;; sensor-board 23
     ;;
     ;; (38 ("larm-wrist" "KJS" "gripper-")) ;; sensor-board 19
     ;; (40 ("larm-wrist" "KJS" "gripper2")) ;; sensor-board 20
     ;; (42 ("rarm-wrist" "KJS" "gripper-")) ;; sensor-board 21
     ;; (44 ("rarm-wrist" "KJS" "gripper2-")) ;; sensor-board 22
     )
    (("kxrl2t2inaba2")	;;
     (:body :l2l6c :type :l2 :torso :y-p :shoulder :cross :wrist :y-cross
	    :gripper t :head :h2s :neck-jf :b :gripper-sensor :rev-a :sole t
	    )
     (2 :rarm-shoulder-p 1 30) (3 :larm-shoulder-p -1 -30)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1 90)     (7 :larm-elbow-p 1 90)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1 -45)    (13 :lleg-knee-p 1 -45)
     (14 :rleg-ankle-p -1 45)   (15 :lleg-ankle-p -1 45)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p -1)      (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (20 :rarm-wrist-y 1)       (21 :larm-wrist-y 1)
     (30 :torso-chest-y -1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     (34 :torso-chest-p 1)
     (31 :head-leye-y -1)     (35 :head-reye-y -1)
     ;;
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 larm-gripper2-r-KJS-01) ;; sensor-board 20
     (42 rarm-gripper-r-KJS-01) ;; sensor-board 21
     (44 rarm-gripper2-r-KJS-01) ;; sensor-board 22
     ;;
     ;; (38 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("larm-wrist" "gripper2" "KJS")) ;; sensor-board 20
     ;; (42 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 21
     ;; (44 ("rarm-wrist" "gripper2-" "KJS")) ;; sensor-board 22
     )
    (("kxrl2t2inaba3")	;;
     (:body :l2l6c :type :l2 :torso :y-p :shoulder :cross :wrist :y-cross
	    :head :h2sh :neck :y-p-r ;; :h3sh
	    :chest-worm t
	    :neck-jf :b :eye-length 26 :eye-y-rotate 3
	    :gripper t :gripper-sensor ((:finger1 :rev-a) (:finger2 . :rev-a)) ;;(:finger1 :rev-a :flip) 
	    :sole t)
     (2 :rarm-shoulder-p 1 30) (3 :larm-shoulder-p -1 -30)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1 90)     (7 :larm-elbow-p 1 90)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1 -45)    (13 :lleg-knee-p 1 -45)
     (14 :rleg-ankle-p -1 45)   (15 :lleg-ankle-p -1 45)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p -1)      (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (20 :rarm-wrist-y 1)       (21 :larm-wrist-y 1)
     (30 :torso-chest-y -1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     (34 :torso-chest-p 1)
     (1 :head-neck-r -1)
     (31 :head-leye-y -1)     (35 :head-reye-y -1)
     ;;
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 larm-gripper2-r-KJS-01) ;; sensor-board 20
     (42 rarm-gripper-r-KJS-01) ;; sensor-board 21
     (44 rarm-gripper2-r-KJS-01) ;; sensor-board 22
     ;;
     ;; (38 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 19
     ;; (40 ("larm-wrist" "gripper2" "KJS")) ;; sensor-board 20
     ;; (42 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 21
     ;; (44 ("rarm-wrist" "gripper2-" "KJS")) ;; sensor-board 22
     )
    (("kxrl2t2l6a7h2yprc" )	;; 32 sensor-board 2020.7.20
     (:body :l2l6c :type :l2 :torso :y-p :shoulder :cross :wrist :y-cross
	    :board :armh7
	    :gripper t :head :m5sh :neck-jf :b :gripper-sensor :larm :sole t) ;; :gripper-sensor :larm
     (2 :rarm-shoulder-p 1 30) (3 :larm-shoulder-p -1 -30)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1 90)     (7 :larm-elbow-p 1 90)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1 -45)    (13 :lleg-knee-p 1 -45)
     (14 :rleg-ankle-p -1 45)   (15 :lleg-ankle-p -1 45)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p -1)      (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (20 :rarm-wrist-y 1)       (21 :larm-wrist-y 1)
     (30 :torso-chest-y -1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     (34 :torso-chest-p 1)
     ;;
     (38 larm-gripper-r-KJS-03) ;; sensor-board 19
     (40 larm-gripper2-r-KJS-03) ;; sensor-board 20
     ;;(44 ("larm-wrist" "KJS" "gripper2")) ;; sensor-board 19 -> 22
     ;;(40 ("larm-wrist" "KJS" "gripper-")) ;; sensor-board 20
     )
    (("kxrl2t2l6a7h2" "kxrl2t2l6a7h2ypr")   ;; 32 with y-p torso 2019 first version
     (:body :l2l6c :type :l2 :head :h2s :torso :y-p :shoulder :cross
	    :board :armh7
	    :wrist :y-cross :gripper t :neck-jf :a :sole t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p -1 -90)   (7 :larm-elbow-p -1 -90)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r  -1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r -1/2)    (19 :larm-gripper2-r 1/2)
     (26 :rarm-wrist-y 1)       (27 :larm-wrist-y 1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (20 :rarm-wrist-r -1)       (21 :larm-wrist-r -1)
     (28 :rarm-wrist-p -1)       (29 :larm-wrist-p -1)
     (30 :torso-chest-y -1)     (31 :torso-chest-p 1)
     (32 :head-neck-y -1)
     (34 :head-neck-p -1)
     )
    (("kxrl2t2l6a7h2rhp3")   ;; 32 with y-p torso 2019 first version
     (:body :l2l6c :type :l2 :head :h2s :torso :y-p :shoulder :cross
	    :board :armh7
	    :wrist :y-cross :gripper t :neck-jf :a :sole t :sole-sensor t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p -1 -90)   (7 :larm-elbow-p -1 -90)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r  -1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r -1/2)    (19 :larm-gripper2-r 1/2)
     (26 :rarm-wrist-y 1)       (27 :larm-wrist-y 1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (20 :rarm-wrist-r -1)       (21 :larm-wrist-r -1)
     (28 :rarm-wrist-p -1)       (29 :larm-wrist-p -1)
     (30 :torso-chest-y -1)     (31 :torso-chest-p 1)
     (32 :head-neck-y -1)
     (34 :head-neck-p -1)
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (52 lleg-ankle-r-KJS-03) ;; sensor-board 26
     ;;(44 ("rleg" "sole" "KJS")) ;; sensor-board 22
     ;;(52 ("lleg" "sole" "KJS")) ;; sensor-board 26
     )
    (("kxrl2t2l6a7h2ypy")   ;; 32 with y-p torso
     (:body :l2l6c :type :l2 :head :e :torso :y-p
	    :shoulder :cross :wrist :y-p-y :gripper t :neck-jf :a :sole t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p -1 90)   (7 :larm-elbow-p -1 90)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r  1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)    (19 :larm-gripper2-r 1/2)
     (20 :rarm-wrist-y 1)       (21 :larm-wrist-y 1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y 1)
     (28 :rarm-wrist-p -1)       (29 :larm-wrist-p -1)
     (30 :torso-chest-y -1)     (31 :torso-chest-p 1)
     (32 :head-neck-y -1)      (33 :head-neck-p -1)
     )
    (("kxrl2t3l6a7h2ypy" "kxrl2t3")	;; 33 with 3D torso
     (:body :l2l6c :type :l2 :head :m5sh :torso :y-r-p :shoulder :cross
	    :board :armh7 :wrist :y-p-y :gripper t :neck-jf :a :sole t)
     (1 :torso-chest-r 1)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1 90)     (7 :larm-elbow-p 1 90)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r -1/2)  (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2) (19 :larm-gripper2-r -1/2)
     (20 :rarm-wrist-y 1)       (21 :larm-wrist-y 1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-elbow-y -1)      (27 :larm-elbow-y -1)
     (28 :rarm-wrist-p -1)      (29 :larm-wrist-p -1)
     (30 :torso-chest-y 1)      (31 :torso-chest-p 1)
     (32 :head-neck-y -1)       (34 :head-neck-p 1)
     )
    (("kxrl2t3max")	;; 35 with 3D torso
     (:body :l2l6c :type :l2 :head :h2sf :torso :y-r-p :shoulder :cross
	    :board :armh7 :wrist :y-p-y :gripper t :neck-jf :a :sole t)
     (1 :torso-chest-r 1)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1 90)     (7 :larm-elbow-p 1 90)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r -1/2)  (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2) (19 :larm-gripper2-r -1/2)
     (20 :rarm-wrist-y 1)       (21 :larm-wrist-y 1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-elbow-y -1)      (27 :larm-elbow-y -1)
     (28 :rarm-wrist-p -1)      (29 :larm-wrist-p -1)
     (30 :torso-chest-y 1)      (31 :torso-chest-p 1)
     (32 :head-neck-y -1)       (34 :head-neck-p 1)
     (33 :head-leye-y -1)       (0 :head-reye-y -1)
     )
    (("kxrl2w2l6a7h2w")		;; 32
     (:body :l2l6w :type :l2 :active-wheel :ankle :shoulder :cross :wrist :cross-y :gripper t
	    :passive-wheel :gripper :head :e :neck-jf :b :sole t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-ankle-w 1)       (21 :lleg-ankle-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p -1)      (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :head-neck-y -1)       (33 :head-neck-p -1)
     )
    ("kxrl2test1"
     (:body :lyp-high :type :l2 :knee-type t :active-wheel :knee 
	    :shoulder :ly-p-r :wrist :r :passive-wheel :wrist
	    :gripper t :gripper-inner t :torso :ly-p-high :head-length 20 :neck-axis :p
	    :board :armh7
	    :head :h2s :wrist-sensor t  :gripper-inner t :gripper-sensor ((:finger1 . :rev-a)) ;; :head :m5
	    :sole-sensor t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y -3/4)    (33 :torso-chest-y  -3/4)
     (32 :torso-chest-p 3/2)    (33 :torso-chest-p -3/2)
     (34 :head-neck-p   1)
     )
    (("kxrl2test2") ;;
     (:body :lyp-low :type :l2 :knee-type :lp :active-wheel :knee 
	    :shoulder :ly-p-r :wrist :r :passive-wheel :wrist
	    :gripper t :gripper-inner t :torso :ly-p :neck-axis :p :head :h2s :head-length 38
	    :board :armh7
	    :wrist-sensor t  :gripper-inner t :gripper-sensor ((:finger1 . :rev-a)) :sole-sensor t
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y -3/4)    (33 :torso-chest-y  -3/4)
     (32 :torso-chest-p 3/2)    (33 :torso-chest-p -3/2)
     (34 :head-neck-p   1)
     )
    (("kxrl2test3") ;; 
     (:body :dyp-z :type :l2 :knee-type :lp :active-wheel :knee 
	    :shoulder :ly-p-r :wrist :r :passive-wheel :shoulder
	    :gripper t :gripper-inner t :torso :ly-p :neck-axis :p :head :h2s :head-length 26 :sole t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y -3/4)    (33 :torso-chest-y  -3/4)
     (32 :torso-chest-p 3/2)    (33 :torso-chest-p -3/2)
     (34 :head-neck-p   1)
     )
    (("kxrl2test4") ;; 34
     (:body :lyp-low :type :l2 :knee-type :lp :active-wheel :knee 
	    :shoulder :ly-p-r :wrist :r :passive-wheel :wrist
	    :gripper t :gripper-inner t :torso :ly-p :neck-axis :p :head :h2s :head-length 20 :sole t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y -3/4)    (33 :torso-chest-y  -3/4)
     (32 :torso-chest-p 3/2)    (33 :torso-chest-p -3/2)
     (34 :head-neck-p   1)
     )
    (("kxrl2test5") ;; 34
     (:body :lyp-high :type :l2 :knee-type :lp :active-wheel :knee 
	    :shoulder :uy-p-r :wrist :r :passive-wheel :wrist
	    :gripper t :gripper-inner t :torso :ly-p-high
	    :neck-axis :z :head :m5 :head-length 20 :sole t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y -3/4)    (33 :torso-chest-y  -3/4)
     (32 :torso-chest-p 3/2)    (33 :torso-chest-p -3/2)
     (34 :head-neck-p   1)
     )
    ("kxrl2makabels"
     (:body :lyp-high :type :l2 :knee-type :lp :active-wheel :knee 
	    :shoulder :ly-p-r :wrist :r :passive-wheel :wrist :crotch-z t
	    :gripper t :gripper-inner t :torso :ly-p-high
	    :neck-axis :p :head-length 20  ;; :head :m5s
	    ;;:head :h2sn ;; :head :h2s :head :m5sh
	    :head :h2sn
	    ;;:head :m3deye :3eye-rev 6
	    :board :armh7
	    ;; :wrist-sensor t :gripper-inner t :gripper-sensor ((:finger1 . :rev-a))
	    :sole t       ;; :sole-sensor t
	    ;;:torso :dy-p
	    :project-file "kxrl2makabe")
     (2 :rarm-shoulder-p 1 s4)     (3 :larm-shoulder-p -1 s4)
     (4 :rarm-shoulder-r -1 s4)    (5 :larm-shoulder-r -1 s4)
     (6 :rarm-elbow-p 1 s4)        (7 :larm-elbow-p -1 s4)
     
     (8 :rleg-crotch-r -1 s4)      (9 :lleg-crotch-r -1 s4)
     (10 :rleg-crotch-p -3/2 s4)   (11 :lleg-crotch-p 3/2 s4)
     (12 :rleg-knee-p -1 s4)       (13 :lleg-knee-p -1 s4)
     (14 :rleg-ankle-p -1 s4)      (15 :lleg-ankle-p -1 s4)
     (16 :rleg-ankle-r -1 s4)      (17 :lleg-ankle-r -1 s4)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1 s2)       (21 :lleg-knee-w -1 s2)

     (22 :rarm-shoulder-y -1 s4)  (23 :larm-shoulder-y -1 s4)
     (24 :rleg-crotch-y 1 s4)      (25 :lleg-crotch-y 1 s4)
     (26 :rarm-elbow-y 1 s4)       (27 :larm-elbow-y  1 s4)
     (28 :rarm-wrist-r 1 s4)       (29 :larm-wrist-r -1 s4)
     (30 :rarm-wrist-y 1 s4)       (31 :larm-wrist-y 1 s4)
     (32 :torso-chest-y -3/4 s4)    (33 :torso-chest-y  -3/4 s4)
     (32 :torso-chest-p 3/2 s4)    (33 :torso-chest-p -3/2 s4)
     (34 :head-neck-p   1)
     )
    ("kxrl2makabelc"
     (:body :dyp-z :type :l2 :active-wheel :knee 
	    :shoulder :ly-p-r :wrist :r :passive-wheel :wrist :crotch-z t
	    :gripper t :gripper-inner t :torso :ly-p   ;; :torso :ly-p-high
	    :neck-axis :p
	    :head :d405cam
	    ;;:head :m3deye :3eye-rev 8 :head-length 20  ;; :head :m5 :h2s :m5sh
	    :board :armh7
	    :wrist-sensor t
	    ;; :gripper-inner t :gripper-sensor :finger1
	    :ankle-sensor t
	    :sole t
	    ;;:torso :dy-p
	    :project-file "kxrl2makabe")
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y -3/4)    (33 :torso-chest-y  -3/4)
     (32 :torso-chest-p 3/2)    (33 :torso-chest-p -3/2)
     (34 :head-neck-p   1)

     (38 rarm-wrist-r-KJS-03) ;; sensor-board 19
     (46 larm-wrist-r-KJS-03) ;; sensor-board 23
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (52 lleg-ankle-r-KJS-03) ;; sensor-board 26
     ;;
     ;; (38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;; (46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     ;;(38 ("rarm" "wrist" "KJS")) ;; sensor-board 19
     ;;(46 ("larm" "wrist" "KJS")) ;; sensor-board 23
     ;;(44 ("rleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;;(52 ("lleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    ("kxrl2makabelcw"
     (:body :dyp-z :type :l2 :active-wheel :knee 
	    :shoulder :ly-p-r :wrist :r :passive-wheel (:shoulder)
	    :crotch-z t
	    :gripper t :gripper-inner t :torso :ly-p   ;; :torso :ly-p-high
	    :neck-axis :p :head :m3eye :head-length 20  ;; :head :m5 :h2s :m5sh
	    :board :armh7
	    :wrist-sensor t
	    ;; :gripper-inner t :gripper-sensor :finger1
	    :ankle-sensor t
	    :sole t
	    ;;:torso :dy-p
	    :project-file "kxrl2makabe")
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y -3/4)    (33 :torso-chest-y  -3/4)
     (32 :torso-chest-p 3/2)    (33 :torso-chest-p -3/2)
     (34 :head-neck-p   1)

     (38 rarm-wrist-r-KJS-03) ;; sensor-board 19
     (46 larm-wrist-r-KJS-03) ;; sensor-board 23
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (52 lleg-ankle-r-KJS-03) ;; sensor-board 26
     ;;
     ;; (38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;; (46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    ("kxrl2semi2022"
     (
      :file "models/kxrl2semi2022.l" :form (kxrl2semi2022)
      :body :l2l6b :type :l2 
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t :leg :j2-pr :sole t 
      :ankle-sensor t
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor (:finger1 :rev-a) ;; ouside
      :wrist-link-replace t
      ;;:gripper-wrist-sensor t
      :head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t :head-length 20
      :m5stickv nil
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-y 0) (:rarm-wrist-y  0)
			 )
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1 )
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r 1)      (17 :lleg-crotch-r 1)
     
     (8 :rarm-shoulder-y 1)     (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 lleg-crotch-r-KJS-03) ;; sensor-board 21
     (44 rleg-crotch-r-KJS-03) ;; sensor-board 22
     )
    ("kxrl2inaba"
     (
      :file "models/kxrl2inaba.l" :form (kxrl2inaba)
      :body :l2l6 :type :l2 
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t :leg :j2-pr :sole t 
      :shoulder-p-sensor (:rev-a :flip) :shoulder-y-sensor (:rev-a :flip)
      :shoulder-r-sensor :rev-c :elbow-p-sensor :rev-c
      :wrist-p-sensor :rev-c :wrist-sensor :rev-c
      ;;      :wrist-link-replace t
      :ankle-sensor t
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor :rev-a ;;(:finger1 :rev-a) ;; :finger1 outside(drive :gripper-r), :finger2 inside(:gripper2-r)
      ;;:head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t
      :head :d405cam :3eye-front t
      :head-length 20 :m5stickv t
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      
      )
     (2 :rarm-shoulder-p 1 60)  (3 :larm-shoulder-p -1 -60)
     (4 :rarm-shoulder-r 1 -3)  (5 :larm-shoulder-r 1 1)
     (6 :rarm-elbow-p 1 -6)     (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r 1)      (17 :lleg-crotch-r 1)
     
     (8 :rarm-shoulder-y 1 -60)     (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 rarm-gripper-r-KJS-01)  (39 larm-gripper-r-KJS-01)  ;; sensor-board 19 
     (40 rarm-gripper2-r-KJS-01) (41 larm-gripper2-r-KJS-01) ;; sensor-board 20
     (42 rleg-crotch-r-KJS-03)   (43 lleg-crotch-r-KJS-03)   ;; sensor-board 21 
     (44 rarm-wrist-r-KJS-03)    (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     (46 rarm-shoulder-y-KJS-01) (47 larm-shoulder-y-KJS-01) ;; sensor-board 23
     (48 rarm-shoulder-p-KJS-01) (49 larm-shoulder-p-KJS-01) ;; sensor-board 24
     (50 rarm-shoulder-r-KJS-03) (51 larm-shoulder-r-KJS-03) ;; sensor-board 25
     (52 rarm-wrist-p-KJS-03)    (53 larm-wrist-p-KJS-03)    ;; sensor-board 26
     (54 rarm-elbow-p-KJS-03)    (55 larm-elbow-p-KJS-03)    ;; sensor-board 27
     )
    (("kxra6g") 		;; rubik cube finger
     (
      :body :l2l6m :type :l2
      :project-file "kxra6g"
      :head :d405echos ;; :d405eyes ;;:head :d405echos
      :board :rcb4-acc-reverse
      :neck-jf :b-back
      :3eye-front t :head-length 20
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :wcross-pr :upper-arm-length 38 
      :shoulder-p-sensor :horn-mag-
      ;; :elbow-p-sensor :mag-7
      :wrist-sensor :horn-mag-
      ;; :crotch-r-sensor :mag-7 :crotch-y-sensor :rev-a
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t
      :leg :j2-pr :sole t 
      :attachment :down
      :gripper t :gripper-straight t :gripper-axis (:y :p)
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      ;;      :init-form (print (list 'self= self 'args= args))
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (16 :rleg-crotch-r -1)     (17 :lleg-crotch-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-p 1)       (27 :larm-wrist-p -1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     
     ;;(42 rleg-ankle-r-KJS-03)   (43 lleg-ankle-r-KJS-03)   ;; sensor-board 21 
     ;;(44 rarm-wrist-r-KJS-03)   (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     )
    ("kxrl2inabafull"
     (
      ;;:file "models/kxrl2inaba.l" :form (kxrl2inaba)
      :body :l2l6b :type :l2 
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t :leg :j2-pr :sole t 
      :shoulder-p-sensor (:rev-a :flip) :shoulder-y-sensor (:rev-a :flip)
      :shoulder-r-sensor :rev-c :elbow-p-sensor :rev-c
      :wrist-p-sensor :rev-c :wrist-sensor :rev-c
      ;;      :wrist-link-replace t
      :ankle-sensor t
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor :rev-a ;;(:finger1 :rev-a) ;; :finger1 outside(drive :gripper-r), :finger2 inside(:gripper2-r)
      ;;:head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t
      :head :d405cam :3eye-front t
      :head-length 20 :m5stickv t
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      )
     (2 :rarm-shoulder-p 1 60)  (3 :larm-shoulder-p -1 -60)
     (4 :rarm-shoulder-r 1 -3)  (5 :larm-shoulder-r 1 1)
     (6 :rarm-elbow-p 1 -6)     (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r 1)      (17 :lleg-crotch-r 1)
     
     (8 :rarm-shoulder-y 1 -60)     (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 rarm-gripper-r-KJS-01)  (39 larm-gripper-r-KJS-01)  ;; sensor-board 19 
     (40 rarm-gripper2-r-KJS-01) (41 larm-gripper2-r-KJS-01) ;; sensor-board 20
     (42 rleg-crotch-r-KJS-03)   (43 lleg-crotch-r-KJS-03)   ;; sensor-board 21 
     (44 rarm-wrist-r-KJS-03)    (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     (46 rarm-shoulder-y-KJS-01) (47 larm-shoulder-y-KJS-01) ;; sensor-board 23
     (48 rarm-shoulder-p-KJS-01) (49 larm-shoulder-p-KJS-01) ;; sensor-board 24
     (50 rarm-shoulder-r-KJS-03) (51 larm-shoulder-r-KJS-03) ;; sensor-board 25
     (52 rarm-wrist-p-KJS-03)    (53 larm-wrist-p-KJS-03)    ;; sensor-board 26
     (54 rarm-elbow-p-KJS-03)    (55 larm-elbow-p-KJS-03)    ;; sensor-board 27
     )
    (("kxrl2semi2022inaba")
     (
      ;;:file "models/kxrl2l2a6inaba.l" :form (kxrl2l2a6inaba)
      :body :l2l6b :type :l2 
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t :leg :j2-pr :sole t 
      :shoulder-p-sensor (:rev-a :flip) :shoulder-y-sensor (:rev-a :flip)
      :shoulder-r-sensor :rev-c :elbow-p-sensor :rev-c
      :wrist-p-sensor :rev-c :wrist-sensor :rev-c
      ;;      :wrist-link-replace t
      :ankle-sensor t
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor :rev-a ;;(:finger1 :rev-a) ;; :finger1 outside(drive :gripper-r), :finger2 inside(:gripper2-r)
      :head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t
      :head-length 20 :m5stickv t
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      )
     (2 :rarm-shoulder-p 1 60)  (3 :larm-shoulder-p -1 -60)
     (4 :rarm-shoulder-r 1 -3)  (5 :larm-shoulder-r 1 1)
     (6 :rarm-elbow-p 1 -6)     (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r 1)      (17 :lleg-crotch-r 1)
     
     (8 :rarm-shoulder-y 1 -60)     (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 rarm-gripper-r-KJS-01)  (39 larm-gripper-r-KJS-01)  ;; sensor-board 19 
     (40 rarm-gripper2-r-KJS-01) (41 larm-gripper2-r-KJS-01) ;; sensor-board 20
     (42 rleg-crotch-r-KJS-03)   (43 lleg-crotch-r-KJS-03)   ;; sensor-board 21 
     (44 rarm-wrist-r-KJS-03)    (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     (46 rarm-shoulder-y-KJS-01) (47 larm-shoulder-y-KJS-01) ;; sensor-board 23
     (48 rarm-shoulder-p-KJS-01) (49 larm-shoulder-p-KJS-01) ;; sensor-board 24
     )
    ("kxrl2l2a6inaba"
     (
      :file "models/kxrl2l2a6inaba.l" :form (kxrl2l2a6inaba)
      :body :l2l6b :type :l2 
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t :leg :j2-pr :sole t 
      :shoulder-p-sensor (:rev-a :flip) :shoulder-y-sensor (:rev-a :flip)
      :shoulder-r-sensor :rev-c :elbow-p-sensor :rev-c
      :wrist-p-sensor :rev-c :wrist-sensor :rev-c
      ;;      :wrist-link-replace t
      :ankle-sensor t
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor :rev-a ;;(:finger1 :rev-a) ;; :finger1 outside(drive :gripper-r), :finger2 inside(:gripper2-r)
      ;;:head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t
      :head :d405cam :3eye-front t
      :head-length 20 :m5stickv t
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-r 0) (:rarm-wrist-r  0)
			 )
      )
     (2 :rarm-shoulder-p 1 60)  (3 :larm-shoulder-p -1 -60)
     (4 :rarm-shoulder-r 1 -3)  (5 :larm-shoulder-r 1 1)
     (6 :rarm-elbow-p 1 -6)     (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r 1)      (17 :lleg-crotch-r 1)
     
     (8 :rarm-shoulder-y 1 -60)     (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 rarm-gripper-r-KJS-01)  (39 larm-gripper-r-KJS-01)  ;; sensor-board 19 
     (40 rarm-gripper2-r-KJS-01) (41 larm-gripper2-r-KJS-01) ;; sensor-board 20
     (42 rleg-crotch-r-KJS-03)   (43 lleg-crotch-r-KJS-03)   ;; sensor-board 21 
     (44 rarm-wrist-r-KJS-03)    (45 larm-wrist-r-KJS-03)    ;; sensor-board 22
     (46 rarm-shoulder-y-KJS-01) (47 larm-shoulder-y-KJS-01) ;; sensor-board 23
     (48 rarm-shoulder-p-KJS-01) (49 larm-shoulder-p-KJS-01) ;; sensor-board 24
     (50 rarm-shoulder-r-KJS-03) (51 larm-shoulder-r-KJS-03) ;; sensor-board 25
     (52 rarm-wrist-p-KJS-03)    (53 larm-wrist-p-KJS-03)    ;; sensor-board 26
     (54 rarm-elbow-p-KJS-03)    (55 larm-elbow-p-KJS-03)    ;; sensor-board 27
     )
    ("kxrl2inabaold"
     (
      ;;:file "models/kxrl2inaba.l" :form (kxrl2inaba)
      :body :l2l6b :type :l2 
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t :leg :j2-pr :sole t 
      :ankle-sensor t
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor (:finger1 :rev-a) ;; :finger1 outside(drive :gripper-r), :finger2 inside(:gripper2-r)
      :head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t
      :head-length 20 :m5stickv nil
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-y 0) (:rarm-wrist-y  0)
			 )
      )
     (2 :rarm-shoulder-p 1 60)  (3 :larm-shoulder-p -1 -60)
     (4 :rarm-shoulder-r 1 -3)  (5 :larm-shoulder-r 1 1)
     (6 :rarm-elbow-p 1 -6)     (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r 1)      (17 :lleg-crotch-r 1)
     
     (8 :rarm-shoulder-y 1)     (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 lleg-crotch-r-KJS-03) ;; sensor-board 21
     (44 rleg-crotch-r-KJS-03) ;; sensor-board 22
     ;;
     ;; (38 ("larm-wrist" "gripper2-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-wrist" "gripper2-" "KJS")) ;; sensor-board 20
     ;; (42 ("lleg-crotch-y" "crotch-r" "KJS")) ;; sensor-board 21
     ;; (44 ("rleg-crotch-y" "crotch-r" "KJS")) ;; sensor-board 22
     )
    ("kxrl2semi2022matsuo"
     (
      :file "models/kxrl2semi2022.l" :form (kxrl2semi2022)
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1 )
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r 1)      (17 :lleg-crotch-r 1)
     
     (8 :rarm-shoulder-y 1 -60)     (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 lleg-crotch-r-KJS-03) ;; sensor-board 21
     (44 rleg-crotch-r-KJS-03) ;; sensor-board 22
     )
    ("kxrl2hoshino"
     (
      :file "models/kxrl2semi2022.l" :form (kxrl2semi2022)
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1 )
     (4 :rarm-shoulder-r 1 -5)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r 1)      (17 :lleg-crotch-r 1)
     
     (8 :rarm-shoulder-y 1)     (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 lleg-crotch-r-KJS-03) ;; sensor-board 21
     (44 rleg-crotch-r-KJS-03) ;; sensor-board 22
     )
    ("kxrl2sawada"
     (
      :file "models/kxrl2semi2022.l" :form (kxrl2semi2022)
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1 )
     (4 :rarm-shoulder-r 1 -5)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r 1)      (17 :lleg-crotch-r 1)
     
     (8 :rarm-shoulder-y 1)     (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)
     
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 lleg-crotch-r-KJS-03) ;; sensor-board 21
     (44 rleg-crotch-r-KJS-03) ;; sensor-board 22
     )
    ("kxrl2sonoda"
     (
      :file "models/kxrl2semi2022.l" :form (kxrl2semi2022)
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1 )
     (4 :rarm-shoulder-r 1 -5)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r 1)      (17 :lleg-crotch-r 1)
     
     (8 :rarm-shoulder-y 1)     (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)
     
     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 lleg-crotch-r-KJS-03) ;; sensor-board 21
     (44 rleg-crotch-r-KJS-03) ;; sensor-board 22
     )
    (("kxrl2semi2022r1" "kxrl2semi2022r2")
     (
      :file "models/kxrl2semi2022r1.l" :form (kxrl2semi2022r1)
      )
     ;;(2 :rarm-shoulder-p 1 -45) (3 :larm-shoulder-p -1 45)
     (2 :rarm-shoulder-p 1) (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r 1)  (17 :lleg-crotch-r 1)
     
     (8 :rarm-shoulder-y 1) (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)      (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 lleg-crotch-r-KJS-03) ;; sensor-board 21
     (44 rleg-crotch-r-KJS-03) ;; sensor-board 22
     )
    (("kxrl2semi2022upr1" "kxrl2semi2022upr2")
     (
      :body :l2l6b :type :l2 
      :crotch-p t :crotch-low t :crotch-front nil :flat-crotch t :leg :j2-pr :sole t 
      :ankle-sensor t
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor (:finger1 :rev-a) 
      :head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t :head-length 20
      :m5stickv nil
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-y 0) (:rarm-wrist-y  0)
			 )
      )
     ;;(2 :rarm-shoulder-p 1 -45) (3 :larm-shoulder-p -1 45)
     (2 :rarm-shoulder-p 1) (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r 1)  (17 :lleg-crotch-r 1)
     
     (8 :rarm-shoulder-y 1) (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)      (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 larm-gripper-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (42 lleg-crotch-r-KJS-03) ;; sensor-board 21
     (44 rleg-crotch-r-KJS-03) ;; sensor-board 22
     )
    ("kxrl2semi2022h"
     (
      :file "models/kxrl2semi2022h.l" :form (kxrl2semi2022h)
      )
     ;;( :body :l2l6b :type :l2 :noarm t :noleg t
     ;;:head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t :head-length 20
     ;;:m5stickv nil
     ;;:board :armh7 :com-init-method (:arm2-open)
     ;;)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)
     )
    ("kxrl2semi2022uph"
     (
      :body :l2l6b :type :l2 :noarm t :noleg t
      ;;:crotch-p t :crotch-low t :crotch-front t :flat-crotch t :leg :j2-pr :sole t 
      :head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t :head-length 20
      :m5stickv nil
      )
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)
     )
    ("kxrl2semi2022l"
     (
      :file "models/kxrl2semi2022l.l" :form (kxrl2semi2022l)
      )
     ;;( :body :l2l6b :type :l2 :noarm t :noleg t
     ;;:head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t :head-length 20
     ;;:crotch-p t :crotch-low t :crotch-front t :flat-crotch t :leg :j2-pr :sole t 
     ;;:m5stickv nil
     ;;:board :armh7 :com-init-method (:arm2-open)
     ;;)
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r 1)      (17 :lleg-crotch-r 1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)
     )
    ("kxrl2semi2022upl"
     (
      :body :l2l6b :type :l2 :noarm t
      :crotch-p t :crotch-low t :crotch-front nil :flat-crotch t :leg :j2-pr :sole t 
      :head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t :head-length 20
      :m5stickv nil
      )
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r -1)      (17 :lleg-crotch-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)
     )
    ("kxrl2semi2022s"
     (
      :body :l2l6b :type :l2 
      :crotch-p t :crotch-low t :crotch-front t :flat-crotch t :leg :j2-pr :sole t 
      :shoulder :pry-cross :shoulder-front t :shoulder-low t :flat-shoulder nil ;;:shoulder :ly-p-rb
      :elbow :angle :wrist :cross-pr :upper-arm-length 38 
      :gripper t :gripper-straight t :gripper-axis :y
      :gripper-sensor :rev-a ;; (:finger1 :rev-a) 
      :head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t :head-length 20
      :m5stickv t
      :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			 (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			 (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			 (:larm-elbow-p 0) (:rarm-elbow-p 0)
			 (:larm-wrist-p 0) (:rarm-wrist-p 0)
			 (:larm-wrist-y 0) (:rarm-wrist-y  0)
			 )
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1 )
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r 1)      (17 :lleg-crotch-r 1)
     
     (8 :rarm-shoulder-y 1)     (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)

     (38 larm-gripper2-r-KJS-01) ;; sensor-board 19
     (40 rarm-gripper2-r-KJS-01) ;; sensor-board 20
     (42 larm-gripper-r-KJS-01) ;; sensor-board 21
     (44 rarm-gripper-r-KJS-01) ;; sensor-board 22
     ;;
     ;; (38 ("larm-wrist" "gripper2-" "KJS")) ;; sensor-board 19
     ;; (40 ("rarm-wrist" "gripper2-" "KJS")) ;; sensor-board 20
     ;; (42 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 21
     ;; (44 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 22
     )
    ("kxrl2semi2022up-leg-wide"
     (:body :l2l6b :crotch-p t :flat-crotch nil :leg :j2-pr
	    :type :l2 :shoulder-front t :sole t :m5stickv nil :upper-arm-length 38 
	    :shoulder :pry-cross     ;;:shoulder :ly-p-rb
	    :elbow :angle
	    :wrist :cross-pr ;; :wrist-a t ;; :wrist-inner :y-
	    :gripper t :gripper-straight t :gripper-axis :y
	    :head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t
	    :head-length 20
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:lleg-crotch-r 0) (:rleg-crotch-r 0)
			       (:larm-elbow-p 0) (:rarm-elbow-p 0)
			       (:larm-wrist-p 0) (:rarm-wrist-p 0)
			       (:larm-wrist-y 0) (:rarm-wrist-y  0)
			       )
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1 )
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r 1)      (17 :lleg-crotch-r 1)
     
     (8 :rarm-shoulder-y 1)     (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-r -1)       (13 :larm-wrist-r -1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)
     )
    ("kxrl2semi2022up-straight-arm"
     (:body :l2l6b :crotch-p t :flat-crotch nil :leg :j2-pr 
	    :type :l2 :shoulder-front t :sole t :m5stickv nil :upper-arm-length 38 
	    :shoulder :pry-cross     ;;:shoulder :ly-p-rb
	    :wrist :cross-py ;; :wrist-a t ;; :wrist-inner :y-
	    :gripper t :gripper-straight t
	    :head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t
	    :head-length 20
	    #|
	    :reset-pose-alist ((:larm-shoulder-p 0) (:rarm-shoulder-p 0)
	    (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
	    (:lleg-crotch-r 0) (:rleg-crotch-r 0)
	    (:larm-elbow-p 0) (:rarm-elbow-p 0)
	    (:larm-wrist-p 0) (:rarm-wrist-p 0)
	    (:larm-wrist-y 0) (:rarm-wrist-y  0)
	    )
	    |#
	    :reset-pose-alist ((:larm-shoulder-p 10) (:rarm-shoulder-p 10)
			       (:larm-shoulder-r 10) (:rarm-shoulder-r -10)
			       (:larm-elbow-p -45) (:rarm-elbow-p -45)
			       (:larm-wrist-p -35) (:rarm-wrist-p -35)
			       (:larm-wrist-y 10) (:rarm-wrist-y  -10)
			       )
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1 )
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (18 :rarm-gripper-r 1/2)   (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)  (19 :larm-gripper2-r 1/2)
     
     (14 :rleg-crotch-y 1)      (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-r 1)      (17 :lleg-crotch-r 1)
     
     (8 :rarm-shoulder-y 1)     (9 :larm-shoulder-y  1)
     (10 :rarm-wrist-p 1)       (11 :larm-wrist-p -1)
     (12 :rarm-wrist-y 1)       (13 :larm-wrist-y 1)
     (0 :head-neck-y -1 )       (20 :head-neck-p   -1)
     )
    ("kxrl2semi2022-old"
     (:body :l2l5 ;; :l2l6s :l2w2 :l2l6w :l2l6
	    :type :l2 :shoulder-front t :active-wheel :crotch :crotch-front t
	    :shoulder :ly-p-rb :wrist :r :wrist-a t :wrist-len 38;; :wrist :r
	    :gripper t :gripper-inner t;; :torso :ly-pfy ;; :torso :ly-p  :torso :ly-p-high
	    ;; :waist-len 38 :neck-axis :p
	    :head :m3deye :3eye-rev 6 ;; :h2s ;; :m5u2s
	    :head-length 20;;:neck :y-p-r 
	    :wrist-inner :y-
	    :sole t
	    )
     (2 :rarm-shoulder-p 1 53)     (3 :larm-shoulder-p -1 -57)
     (4 :rarm-shoulder-r 1 0)    (5 :larm-shoulder-r 1 18)
     (6 :rarm-elbow-p 1 90)        (7 :larm-elbow-p -1 -90)
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1 7)   (11 :lleg-crotch-p -1 -5)
     (12 :rleg-knee-p 1 -70)       (13 :lleg-knee-p 1 -70)
     (14 :rleg-ankle-p -1 30)      (15 :lleg-ankle-p -1 26)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     ;;(20 :rleg-crotch-w 1)        (21 :lleg-crotch-w -1)
     ;;(22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1 -4)
     ;;(24 :rleg-crotch-y 1 5)      (25 :lleg-crotch-y 1)
     ;;(26 :rarm-elbow-y 1 16)       (27 :larm-elbow-y  1 -3)
     (26 :rarm-shoulder-y 1 16)       (27 :larm-shoulder-y  1 -3)
     (28 :rarm-wrist-r -1 0)     (29 :larm-wrist-r 1 0)
     (30 :rarm-wrist-y 1 -5)       (31 :larm-wrist-y 1)
     (34 :head-neck-y -1 5)      (0 :head-neck-p   1)
     )
    ("kxrsemi2022up-old" ;; no legs
     (:body :l2l6b :noleg t
	    :type :l2 :shoulder-front t :upper-arm-length 38 
	    :shoulder :pry-cross :wrist :cross-py ;;  :wrist-inner :y-
	    :gripper t :gripper-straight t
	    :head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t :m5stickv nil
	    :head-length 20
	    :reset-pose-alist ((:larm-shoulder-p 10) (:rarm-shoulder-p 10)
			       (:larm-shoulder-r 0) (:rarm-shoulder-r 0)
			       (:larm-elbow-p -80) (:rarm-elbow-p -80)
			       (:larm-wrist-p -20) (:rarm-wrist-p -20)
			       (:larm-wrist-y 0) (:rarm-wrist-y  0)
			       )
	    )
     (2 :rarm-shoulder-p 1 53)     (3 :larm-shoulder-p -1 -57)
     (4 :rarm-shoulder-r 1 0)    (5 :larm-shoulder-r 1 18)
     (6 :rarm-elbow-p 1 90)        (7 :larm-elbow-p -1 -90)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (26 :rarm-shoulder-y 1 16)       (27 :larm-shoulder-y  1 -3)
     (28 :rarm-wrist-p -1 0)     (29 :larm-wrist-p 1 0)
     (30 :rarm-wrist-y 1 -5)       (31 :larm-wrist-y 1)
     (34 :head-neck-y -1 5)      (0 :head-neck-p   1)
     )
    ("kxrl2semi2022up-old"
     (:body :l2l6b :crotch-p t :flat-crotch nil :leg :j2-pr 
	    :type :l2 :shoulder-front t :sole t :m5stickv nil
	    :shoulder :ly-p-rb :wrist :r :wrist-a t :wrist-len 38;; :wrist :r
	    :gripper t :gripper-inner t
	    :head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t
	    :head-length 20
	    :wrist-inner :y-
	    )
     (2 :rarm-shoulder-p 1 53)     (3 :larm-shoulder-p -1 -57)
     (4 :rarm-shoulder-r 1 0)    (5 :larm-shoulder-r 1 18)
     (6 :rarm-elbow-p 1 90)        (7 :larm-elbow-p -1 -90)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)

     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (16 :rleg-crotch-r -1)      (17 :lleg-crotch-r -1)

     (26 :rarm-shoulder-y 1 16)       (27 :larm-shoulder-y  1 -3)
     (28 :rarm-wrist-r -1 0)     (29 :larm-wrist-r 1 0)
     (30 :rarm-wrist-y 1 -5)       (31 :larm-wrist-y 1)
     (34 :head-neck-y -1 5)      (0 :head-neck-p   1)
     )
    ("kxrl2semi20226"
     (:body :l2l6 ;; :l2w2 :l2l6w :l2l6
	    :type :l2 :shoulder-front t
	    :shoulder :ly-p-rb :wrist :r :wrist-a t :wrist-len 38;; :wrist :r
	    :gripper t :gripper-inner t;; :torso :ly-pfy ;; :torso :ly-p  :torso :ly-p-high
	    ;; :waist-len 38 :neck-axis :p
	    :head :m3eye ;; :h2s ;; :m5u2s
	    :neck :y-p-r :3eye-rev 3
	    :wrist-inner :y-
	    :sole t
	    )
     (2 :rarm-shoulder-p 1 53)     (3 :larm-shoulder-p -1 -57)
     (4 :rarm-shoulder-r 1 0)    (5 :larm-shoulder-r 1 18)
     (6 :rarm-elbow-p 1 90)        (7 :larm-elbow-p -1 -90)
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1 7)   (11 :lleg-crotch-p -1 -5)
     (12 :rleg-knee-p 1 -70)       (13 :lleg-knee-p 1 -70)
     (14 :rleg-ankle-p -1 30)      (15 :lleg-ankle-p -1 26)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     ;;(20 :rleg-crotch-w 1)        (21 :lleg-crotch-w -1)
     ;;(22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1 -4)
     (24 :rleg-crotch-y 1 5)      (25 :lleg-crotch-y 1)
     (26 :rarm-elbow-y 1 16)       (27 :larm-elbow-y  1 -3)
     (28 :rarm-wrist-r -1 0)     (29 :larm-wrist-r 1 0)
     (30 :rarm-wrist-y 1 -5)       (31 :larm-wrist-y 1)
     (34 :head-neck-y -1 5)      (0 :head-neck-p   1)
     )
    ("kxrl2semi20225"
     (:body :l2l5 ;; :l2w2 :l2l6w :l2l6
	    :type :l2 :shoulder-front t
	    :shoulder :ly-p-rb :wrist :r :wrist-a t :wrist-len 38;; :wrist :r
	    :gripper t :gripper-inner t;; :torso :ly-pfy ;; :torso :ly-p  :torso :ly-p-high
	    ;; :waist-len 38 :neck-axis :p
	    :head :m3eye ;; :h2s ;; :m5u2s
	    :neck :y-p-r :3eye-rev 3
	    :wrist-inner :y-
	    :sole t
	    )
     (2 :rarm-shoulder-p 1 53)     (3 :larm-shoulder-p -1 -57)
     (4 :rarm-shoulder-r 1 0)    (5 :larm-shoulder-r 1 18)
     (6 :rarm-elbow-p 1 90)        (7 :larm-elbow-p -1 -90)
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1 7)   (11 :lleg-crotch-p -1 -5)
     (12 :rleg-knee-p 1 -70)       (13 :lleg-knee-p 1 -70)
     (14 :rleg-ankle-p -1 30)      (15 :lleg-ankle-p -1 26)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (26 :rarm-elbow-y 1 16)       (27 :larm-elbow-y  1 -3)
     (28 :rarm-wrist-r -1 0)     (29 :larm-wrist-r 1 0)
     (30 :rarm-wrist-y 1 -5)       (31 :larm-wrist-y 1)
     (34 :head-neck-y -1 5)      (0 :head-neck-p   1)
     )
    ("kxrl2semi2022b"
     (:body :l2l6b ;; :l2w2 :l2l6w :l2l6
	    :type :l2 :shoulder-front t
	    :shoulder :ly-p-rb :wrist :r :wrist-a t :wrist-len 38;; :wrist :r
	    :gripper t :gripper-inner t;; :torso :ly-pfy ;; :torso :ly-p  :torso :ly-p-high
	    ;; :waist-len 38 :neck-axis :p
	    :head :m3eye :3eye-rev 3 ;; :h2s ;; :m5u2s
	    :neck :y-p-r 
	    :wrist-inner :y-
	    :sole t
	    )
     (2 :rarm-shoulder-p 1 53)     (3 :larm-shoulder-p -1 -57)
     (4 :rarm-shoulder-r 1 0)    (5 :larm-shoulder-r 1 18)
     (6 :rarm-elbow-p 1 90)        (7 :larm-elbow-p -1 -90)
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1 7)   (11 :lleg-crotch-p -1 -5)
     (12 :rleg-knee-p 1 -70)       (13 :lleg-knee-p 1 -70)
     (14 :rleg-ankle-p -1 30)      (15 :lleg-ankle-p -1 26)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     ;;(20 :rleg-crotch-w 1)        (21 :lleg-crotch-w -1)
     ;;(22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1 -4)
     (24 :rleg-crotch-y 1 5)      (25 :lleg-crotch-y 1)
     (26 :rarm-elbow-y 1 16)       (27 :larm-elbow-y  1 -3)
     (28 :rarm-wrist-r -1 0)     (29 :larm-wrist-r 1 0)
     (30 :rarm-wrist-y 1 -5)       (31 :larm-wrist-y 1)
     (34 :head-neck-y -1 5)      (0 :head-neck-p   1)
     )
    ("kxrl2semi2022r"
     (:body :l2l6r ;; :l2w2 :l2l6w :l2l6
	    :type :l2 :shoulder-front t
	    :shoulder :ly-p-rb :wrist :r :wrist-a t :wrist-len 38;; :wrist :r
	    :gripper t :gripper-inner t;; :torso :ly-pfy ;; :torso :ly-p  :torso :ly-p-high
	    ;; :waist-len 38 :neck-axis :p
	    :head :m3eye ;; :h2s ;; :m5u2s
	    :neck :y-p-r :3eye-rev 3
	    :wrist-inner :y-
	    :sole t
	    )
     (2 :rarm-shoulder-p 1 53)     (3 :larm-shoulder-p -1 -57)
     (4 :rarm-shoulder-r 1 0)    (5 :larm-shoulder-r 1 18)
     (6 :rarm-elbow-p 1 90)        (7 :larm-elbow-p -1 -90)
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1 7)   (11 :lleg-crotch-p -1 -5)
     (12 :rleg-knee-p 1 -70)       (13 :lleg-knee-p 1 -70)
     (14 :rleg-ankle-p -1 30)      (15 :lleg-ankle-p -1 26)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     ;;(20 :rleg-crotch-w 1)        (21 :lleg-crotch-w -1)
     ;;(22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1 -4)
     (24 :rleg-crotch-y 1 5)      (25 :lleg-crotch-y 1)
     (26 :rarm-elbow-y 1 16)       (27 :larm-elbow-y  1 -3)
     (28 :rarm-wrist-r -1 0)     (29 :larm-wrist-r 1 0)
     (30 :rarm-wrist-y 1 -5)       (31 :larm-wrist-y 1)
     (34 :head-neck-y -1 5)      (0 :head-neck-p   1)
     )
    ("kxrl2semi2022ups"
     (:body :l2l6s ;; :l2w2 :l2l6w :l2l6
	    :type :l2 :shoulder-front t :crotch-front t
	    :shoulder :ly-p-rb :wrist :r :wrist-a t :wrist-len 38;; :wrist :r
	    :gripper t :gripper-inner t;; :torso :ly-pfy ;; :torso :ly-p  :torso :ly-p-high
	    ;; :waist-len 38 :neck-axis :p
	    :head :m3eye :3eye-rev 3 ;; :h2s ;; :m5u2s
	    ;;:neck :y-p-r 
	    :board :armh7 :wrist-inner :y-
	    :com-init-method (:arm-open :pid #x6001) ;; same as :arm2-open, pid:#x6015 for Akizuki
	    :sole t
	    )
     (2 :rarm-shoulder-p 1 53)     (3 :larm-shoulder-p -1 -57)
     (4 :rarm-shoulder-r 1 0)    (5 :larm-shoulder-r 1 18)
     (6 :rarm-elbow-p 1 90)        (7 :larm-elbow-p -1 -90)
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1 7)   (11 :lleg-crotch-p -1 -5)
     (12 :rleg-knee-p 1 -70)       (13 :lleg-knee-p 1 -70)
     (14 :rleg-ankle-p -1 30)      (15 :lleg-ankle-p -1 26)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     ;;(20 :rleg-crotch-w 1)        (21 :lleg-crotch-w -1)
     ;;(22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1 -4)
     (24 :rleg-crotch-y 1 5)      (25 :lleg-crotch-y 1)
     (26 :rarm-elbow-y 1 16)       (27 :larm-elbow-y  1 -3)
     (28 :rarm-wrist-r -1 0)     (29 :larm-wrist-r 1 0)
     (30 :rarm-wrist-y 1 -5)       (31 :larm-wrist-y 1)
     (34 :head-neck-y -1 5)      (0 :head-neck-p   1)
     )
    ("kxrl2semi2022w"
     (:body :l2l6w ;; :l2w2 :l2l6w :l2l6
	    :type :l2 :shoulder-front t
	    :shoulder :ly-p-rb :wrist :r :wrist-a t :wrist-len 38;; :wrist :r
	    :gripper t :gripper-inner t;; :torso :ly-pfy ;; :torso :ly-p  :torso :ly-p-high
	    ;; :waist-len 38 :neck-axis :p
	    :head :m3eye ;; :h2s ;; :m5u2s
	    :neck :y-p-r :3eye-rev 3
	    :board :armh7 :wrist-inner :y-
	    :com-init-method (:arm-open :pid #x6001) ;; same as :arm2-open, pid:#x6015 for Akizuki
	    :sole t
	    )
     (2 :rarm-shoulder-p 1 53)     (3 :larm-shoulder-p -1 -57)
     (4 :rarm-shoulder-r 1 0)    (5 :larm-shoulder-r 1 18)
     (6 :rarm-elbow-p 1 90)        (7 :larm-elbow-p -1 -90)
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1 7)   (11 :lleg-crotch-p -1 -5)
     (12 :rleg-knee-p 1 -70)       (13 :lleg-knee-p 1 -70)
     (14 :rleg-ankle-p -1 30)      (15 :lleg-ankle-p -1 26)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     ;;(20 :rleg-crotch-w 1)        (21 :lleg-crotch-w -1)
     ;;(22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1 -4)
     (24 :rleg-crotch-y 1 5)      (25 :lleg-crotch-y 1)
     (26 :rarm-elbow-y 1 16)       (27 :larm-elbow-y  1 -3)
     (28 :rarm-wrist-r -1 0)     (29 :larm-wrist-r 1 0)
     (30 :rarm-wrist-y 1 -5)       (31 :larm-wrist-y 1)
     (34 :head-neck-y -1 5)      (0 :head-neck-p   1)
     )
    ("kxrl2makabelw"
     (:body :l2w2 :type :l2
	    :shoulder :ly-p-rb :wrist :r :wrist-a t :wrist-len 38;; :wrist :r
	    :gripper t :gripper-inner t :torso :ly-pfy ;; :torso :ly-p  :torso :ly-p-high
	    :waist-len 38 :neck-axis :p
	    :head :m3eye ;; :h2s ;; :m5u2s
	    ;; :neck :y-p-r
	    ;; :m5u3sv2 :m5u3s :m3eye ;; :head :m5 :h2s :m5sh :m3eye :my3eye :h3sh
	    :3eye-rev 3 :head-b nil :head-b-front nil :head-length 38
	    :board :armh7 :wrist-inner :y-
	    :com-init-method (:arm-open :pid #x6001) ;; same as :arm2-open, pid:#x6015 for Akizuki
	    ;;:wrist-sensor t
	    ;; :gripper-inner t :gripper-sensor :finger1
	    ;;:ankle-sensor t
	    :sole t
	    ;;:torso :dy-p
	    ;; :project-file "kxrl2makabe"
	    )
     (2 :rarm-shoulder-p 1 53)     (3 :larm-shoulder-p -1 -57)
     (4 :rarm-shoulder-r 1 0)    (5 :larm-shoulder-r 1 18)
     (6 :rarm-elbow-p 1 90)        (7 :larm-elbow-p -1 -90)
     
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1 7)   (11 :lleg-crotch-p -1 -5)
     (12 :rleg-knee-p 1 -70)       (13 :lleg-knee-p 1 -70)
     (14 :rleg-ankle-p -1 30)      (15 :lleg-ankle-p -1 26)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     ;;(12 :rleg-knee-p 1 -70.8667)        (13 :lleg-knee-p 1 -66.0667)
     ;;(14 :rleg-ankle-p -1 18.03)      (15 :lleg-ankle-p -1 20.43)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-crotch-w 1)        (21 :lleg-crotch-w -1)
     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1 -4)
     (24 :rleg-crotch-y 1 5)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1 16)       (27 :larm-elbow-y  1 -3)
     (28 :rarm-wrist-r -1 0)     (29 :larm-wrist-r 1 0)
     (30 :rarm-wrist-y 1 -5)       (31 :larm-wrist-y 1)
     (35 :torso-chest-y -1)
     (32 :torso-chest-p -1)  (34 :head-neck-y -1 5) 
     ;; (35 :head-neck-r -1 5)
     (0 :head-neck-p   1)

     ;;(38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;;(46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;;(44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;;(52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26

     ;;     (44 ("rleg" "sole")) ;; sensor-board 22
     ;;     (52 ("lleg" "sole")) ;; sensor-board 26
     ;;(38 ("rarm" "wrist" "KJS")) ;; sensor-board 19
     ;;(46 ("larm" "wrist" "KJS")) ;; sensor-board 23
     ;;(44 ("rleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;;(52 ("lleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    ("kxrl2makabelwup"
     (:body :bodyplate :type :l2 :noleg t ;; :nobody t
	    :shoulder :ly-p-rb :wrist :r :wrist-a t :wrist-len 20
	    :gripper t :gripper-inner t :torso :ly-pf ;; :ly-pfy
	    :neck-axis :p :waist-len 20
	    :head :m3deye :3eye-rev 8 :3eye-front t :3eye-cover t
	    ;; :head-b nil :head-b-front nil :head-length 38
	    :board :armh7 :wrist-inner :y-
	    :com-init-method (:com-init :devname "ttyS0")
	    )
     (2 :rarm-shoulder-p 1 53)     (3 :larm-shoulder-p -1 -57)
     (4 :rarm-shoulder-r 1 0)    (5 :larm-shoulder-r 1 18)
     (6 :rarm-elbow-p 1 90)        (7 :larm-elbow-p -1 -90)
     
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1 -4)

     (26 :rarm-elbow-y 1 16)       (27 :larm-elbow-y  1 -3)
     (28 :rarm-wrist-r -1 0)     (29 :larm-wrist-r 1 0)
     (30 :rarm-wrist-y 1 -5)       (31 :larm-wrist-y 1)
     (35 :torso-chest-y -1)
     (32 :torso-chest-p -1)
     ;;(34 :head-neck-y -1 5) 
     ;; (35 :head-neck-r -1 5)
     (0 :head-neck-p   1)

     ;;(38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;;(46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;;(44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;;(52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26

     ;;     (44 ("rleg" "sole")) ;; sensor-board 22
     ;;     (52 ("lleg" "sole")) ;; sensor-board 26
     ;;(38 ("rarm" "wrist" "KJS")) ;; sensor-board 19
     ;;(46 ("larm" "wrist" "KJS")) ;; sensor-board 23
     ;;(44 ("rleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;;(52 ("lleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    ("kxrl2makabelw0"
     (:body :l2w2 :type :l2
	    :shoulder :ly-p-rb :wrist :r :wrist-a t :wrist-len 38;; :wrist :r
	    :gripper t :gripper-inner t :torso :ly-pfy ;; :torso :ly-p  :torso :ly-p-high
	    :neck-axis :p :head :m3eye :3eye-rev 3 :neck :y-r-p
	    ;;:head-length 20  ;; :head :m5 :h2s :m5sh :m3eye :my3eye :h3sh
	    :board :armh7 :wrist-inner :y-
	    :com-init-method (:arm-open :pid #x6001) ;; same as :arm2-open, pid:#x6015 for Akizuki
	    ;;:wrist-sensor t
	    ;; :gripper-inner t :gripper-sensor :finger1
	    ;;:ankle-sensor t
	    :sole t
	    ;;:torso :dy-p
	    ;; :project-file "kxrl2makabe"
	    )
     (2 :rarm-shoulder-p 1 53)     (3 :larm-shoulder-p -1 -57)
     (4 :rarm-shoulder-r 1 0)    (5 :larm-shoulder-r 1 18)
     (6 :rarm-elbow-p 1 90)        (7 :larm-elbow-p -1 -90)
     
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1 7)   (11 :lleg-crotch-p -1 -5)
     (12 :rleg-knee-p 1 -70)       (13 :lleg-knee-p 1 -70)
     (14 :rleg-ankle-p -1 30)      (15 :lleg-ankle-p -1 26)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     ;;(12 :rleg-knee-p 1 -70.8667)        (13 :lleg-knee-p 1 -66.0667)
     ;;(14 :rleg-ankle-p -1 18.03)      (15 :lleg-ankle-p -1 20.43)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-crotch-w 1)        (21 :lleg-crotch-w -1)
     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1 -4)
     (24 :rleg-crotch-y 1 5)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1 16)       (27 :larm-elbow-y  1 -3)
     (28 :rarm-wrist-r -1 0)     (29 :larm-wrist-r 1 0)
     (30 :rarm-wrist-y 1 -5)       (31 :larm-wrist-y 1)
     (35 :torso-chest-y -1)
     (32 :torso-chest-p -1)  (34 :head-neck-y -1) 
     (0 :head-neck-p   1)

     ;;(38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;;(46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;;(44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;;(52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26

     ;;     (44 ("rleg" "sole")) ;; sensor-board 22
     ;;     (52 ("lleg" "sole")) ;; sensor-board 26
     ;;(38 ("rarm" "wrist" "KJS")) ;; sensor-board 19
     ;;(46 ("larm" "wrist" "KJS")) ;; sensor-board 23
     ;;(44 ("rleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;;(52 ("lleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    ("kxrl2makabelw1"
     (:body :l2w2 :type :l2
	    :shoulder :ly-p-rb :wrist :r 
	    :gripper t :gripper-inner t :torso :ly-pf ;; :torso :ly-p  :torso :ly-p-high
	    :neck-axis :p :head :my3eye :3eye-rev 3
	    :head-length 20  ;; :head :m5 :h2s :m5sh :m3eye
	    :board :armh7 :wrist-inner :y-
	    :com-init-method (:arm-open :pid #x6001) ;; same as :arm2-open, pid:#x6015 for Akizuki
	    ;;:wrist-sensor t
	    ;; :gripper-inner t :gripper-sensor :finger1
	    ;;:ankle-sensor t
	    :sole t
	    ;;:torso :dy-p
	    ;; :project-file "kxrl2makabe"
	    )
     (2 :rarm-shoulder-p 1 -9)     (3 :larm-shoulder-p -1 6)
     (4 :rarm-shoulder-r 1 0)    (5 :larm-shoulder-r 1 18)
     (6 :rarm-elbow-p 1 90)        (7 :larm-elbow-p -1 -90)
     
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1 7)   (11 :lleg-crotch-p -1 -5)
     (12 :rleg-knee-p 1 -70)       (13 :lleg-knee-p 1 -70)
     (14 :rleg-ankle-p -1 30)      (15 :lleg-ankle-p -1 26)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     ;;(12 :rleg-knee-p 1 -70.8667)        (13 :lleg-knee-p 1 -66.0667)
     ;;(14 :rleg-ankle-p -1 18.03)      (15 :lleg-ankle-p -1 20.43)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-crotch-w 1)        (21 :lleg-crotch-w -1)
     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1 -4)
     (24 :rleg-crotch-y 1 5)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1 16)       (27 :larm-elbow-y  1 -3)
     (28 :rarm-wrist-r -1 9)     (29 :larm-wrist-r 1 11)
     (30 :rarm-wrist-y 1 -5)       (31 :larm-wrist-y 1)
     ;;(34 :head-neck-y -1) 
     (35 :torso-chest-y -1)
     (32 :torso-chest-p -1)
     (0 :head-neck-p   1)

     ;;(38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;;(46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;;(44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;;(52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26

     ;;     (44 ("rleg" "sole")) ;; sensor-board 22
     ;;     (52 ("lleg" "sole")) ;; sensor-board 26
     ;;(38 ("rarm" "wrist" "KJS")) ;; sensor-board 19
     ;;(46 ("larm" "wrist" "KJS")) ;; sensor-board 23
     ;;(44 ("rleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;;(52 ("lleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    ("kxrl2makabelw2"
     (:body :l2w2 :type :l2
	    :shoulder :ly-p-rb :wrist :r 
	    :gripper t :gripper-inner t :torso :ly-pf ;; :torso :ly-p  :torso :ly-p-high
	    :neck-axis :p :head :m3eye :3eye-rev 3
	    :head-length 20  ;; :head :m5 :h2s :m5sh
	    :board :armh7
	    :com-init-method (:arm-open :pid #x6001) ;; same as :arm2-open, pid:#x6015 for Akizuki
	    ;;:wrist-sensor t
	    ;; :gripper-inner t :gripper-sensor :finger1
	    ;;:ankle-sensor t
	    :sole t
	    ;;:torso :dy-p
	    ;; :project-file "kxrl2makabe"
	    )
     (2 :rarm-shoulder-p 1 -9)     (3 :larm-shoulder-p -1 6)
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1 90)        (7 :larm-elbow-p -1 -90)
     
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1 7)   (11 :lleg-crotch-p -1 -5)
     (12 :rleg-knee-p 1 -70)       (13 :lleg-knee-p 1 -70)
     (14 :rleg-ankle-p -1 30)      (15 :lleg-ankle-p -1 26)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     ;;(12 :rleg-knee-p 1 -70.8667)        (13 :lleg-knee-p 1 -66.0667)
     ;;(14 :rleg-ankle-p -1 18.03)      (15 :lleg-ankle-p -1 20.43)

     (18 :rarm-gripper-r 1/2 -22)    (19 :larm-gripper-r 1/2 -22)
     (18 :rarm-gripper2-r 1/2 -22)   (19 :larm-gripper2-r 1/2 -22)
     (20 :rleg-crotch-w 1)        (21 :lleg-crotch-w -1)
     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y 1 5)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1 7)
     (28 :rarm-wrist-r -1 9)     (29 :larm-wrist-r 1 11)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (35 :torso-chest-y -1)
     (32 :torso-chest-p -1)
     (0 :head-neck-p   1)

     ;;(38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;;(46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;;(44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;;(52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26

     ;;     (44 ("rleg" "sole")) ;; sensor-board 22
     ;;     (52 ("lleg" "sole")) ;; sensor-board 26
     ;;(38 ("rarm" "wrist" "KJS")) ;; sensor-board 19
     ;;(46 ("larm" "wrist" "KJS")) ;; sensor-board 23
     ;;(44 ("rleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;;(52 ("lleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    ("kxrl2makabelsw"
     (:body :lyp-low ;; :body :lyp-high
	    :type :l2 :knee-type :lp :active-wheel :knee  ;; :knee-type t 
	    :shoulder :ly-p-r :wrist :r ;; :passive-wheel (:shoulder :wrist)
	    :passive-wheel (:shoulder)
	    :gripper t :gripper-inner t ;; :gripper-sensor :finger1
	    :torso :ly-p-high :neck-axis :p :head :m3eye :head-length 20 ;; :head :m5sh
	    :board :armh7
	    :sole t ;; :sole-sensor t
	    ;;:torso :dy-p
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y 1)      (33 :torso-chest-p 1)
     (34 :head-neck-p   1)
     )
    (("kxrl2makabelw3") ;;
     (:body :lyp-low :type :l2 :knee-type :lp :active-wheel :knee 
	    :shoulder :ly-p-r :wrist :r :passive-wheel (:shoulder :wrist)
	    :gripper t :gripper-inner t :torso :ly-p :sole t
	    :neck-axis :p :head :m3eye :3eye-rev 3
	    :head-length 20)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y -3/4)    (33 :torso-chest-y  -3/4)
     (32 :torso-chest-p 3/2)    (33 :torso-chest-p -3/2)
     (34 :head-neck-p   1)
     )
    (("kxrl2himeno") ;;
     (
      ;;:file "models/kxrl2himeno.l" :form (kxrl2himeno)
      :body :dyp-zf :type :l2 :active-wheel :knee 
      :crotch-cross-back t
      :shoulder :uy-p-r      ;;:shoulder :ly-p-rb
      :wrist :r :passive-wheel (:torso :double) ;; (:torso) (:torso :double) (:shoulder)
      :gripper t :torso :ly-p ;; :ly-pl :ly-p-high
      :sole t :gripper-straight t
      :neck-axis :p :head-length 26 
      :head :d405 :3eye-front t
      ;;:head :m3deye :3eye-rev 9;; :m5sh
      :project-file "kxrl2himeno"
      :board :armh7 :com-init-method (:arm2-open)
      :gripper-sensor (:finger1 :rev-a)
      :wrist-sensor t
      :ankle-sensor t
      )
     (2 :rarm-shoulder-p 1 61)     (3 :larm-shoulder-p -1 -57)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-p 1)   
     (34 :torso-chest-y -1)    
     (0 :head-neck-p   -1)

     (42 rarm-gripper-r-KJS-01)
     (50 larm-gripper-r-KJS-01)
     (38 rarm-wrist-r-KJS-03)
     (46 larm-wrist-r-KJS-03)
     (44 rleg-ankle-r-KJS-03)
     (52 lleg-ankle-r-KJS-03)
     ;;
     ;; (42 ("rarm-wrist" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (50 ("larm-wrist" "gripper2-" "KJS")) ;; sensor-board 25
     ;; (38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;; (46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    (("kxrl2himeno!") ;;
     (
      :file "models/kxrl2himeno.l" :form (kxrl2himeno)
      :board :armh7 :com-init-method (:arm2-open)
      )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-p -1)   
     (34 :torso-chest-y -1)    
     (0 :head-neck-p   -1)

     (42 rarm-gripper-r-KJS-01)
     (50 larm-gripper-r-KJS-01)
     (38 rarm-wrist-r-KJS-03)
     (46 larm-wrist-r-KJS-03)
     (44 rleg-ankle-r-KJS-03)
     (52 lleg-ankle-r-KJS-03)
     ;;
     ;; (42 ("rarm-wrist" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (50 ("larm-wrist" "gripper2-" "KJS")) ;; sensor-board 25
     ;; (38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;; (46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    (("kxrl2himeno2") ;;
     (
      ;;:file "models/kxrl2himeno.l" :form (kxrl2himeno)
      :body :dyp-zf :type :l2 :active-wheel :knee 
      :crotch-cross-back t
      :shoulder :uy-p-r      ;;:shoulder :ly-p-rb
      :wrist :r :passive-wheel (:torso :double) ;; (:torso) (:torso :double) (:shoulder)
      :gripper t :chest-worm t
      :torso :ly-p ;; :ly-pl :ly-p-high
      :sole t ;; :gripper-straight t
      :neck-axis :p :head-length 26 :head :m3deye :3eye-rev 8;; :m5sh
      :project-file "kxrl2himeno"
      :board :armh7 :com-init-method (:arm2-open)
      :gripper-sensor (:finger1 :rev-a)
      :wrist-sensor t
      :ankle-sensor t
      )
     (2 :rarm-shoulder-p 1 61)     (3 :larm-shoulder-p -1 -57)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-p -1)   
     (34 :torso-chest-y -1)    
     (0 :head-neck-p   -1)

     (42 rarm-gripper-r-KJS-01)
     (50 larm-gripper-r-KJS-01)
     (38 rarm-wrist-r-KJS-03)
     (46 larm-wrist-r-KJS-03)
     (44 rleg-ankle-r-KJS-03)
     (52 lleg-ankle-r-KJS-03)
     ;;
     ;; (42 ("rarm-wrist" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (50 ("larm-wrist" "gripper2-" "KJS")) ;; sensor-board 25
     ;; (38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;; (46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    ("kxrl2makabel" ;; 34 makabe low cost structure
     (:body :lyp-low :type :l2 :knee-type :lp :active-wheel :knee 
	    :shoulder :uy-p-r :wrist :r :passive-wheel :wrist
	    :board :armh7
	    :gripper-inner t :torso :ly-p :sole-sensor t
	    :neck-axis :p :head :m5 :head-length 20 :sole t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y -3/4)    (33 :torso-chest-y  -3/4)
     (32 :torso-chest-p 3/2)    (33 :torso-chest-p -3/2)
     (34 :head-neck-p   1)
     )
    (("kxrl2makabe" "kxrl2w2t2l6a7h1")		;; 33
     (:body :dyp :type :l2 :active-wheel :knee
	    :shoulder :y-p-r :wrist :r :passive-wheel :wrist
	    :board :armh7
	    :wrist-sensor t :gripper t
	    :gripper-inner t ;;:gripper-sensor ((:finger1 . :rev-a))
	    :gripper-sensor (:finger1 :rev-a)
	    :sole t :ankle-sensor t
	    :sole-sensor t :torso :dy-p :neck-axis :p :head :m5sh :head-length 38)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y -3/4)    (33 :torso-chest-y  -3/4)
     (32 :torso-chest-p 3/2)    (33 :torso-chest-p -3/2)
     (34 :head-neck-p   1)
     ;;
     (42 rarm-gripper2-r-KJS-01) ;; sensor-board 21
     (50 larm-gripper2-r-KJS-01) ;; sensor-board 25
     (38 rarm-wrist-r-KJS-03) ;; sensor-board 19
     (46 larm-wrist-r-KJS-03) ;; sensor-board 23
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (52 lleg-ankle-r-KJS-03) ;; sensor-board 26
     ;;
     ;; (42 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 21
     ;; (50 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 25
     ;; (38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;; (46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg" "sole")) ;; sensor-board 22
     ;; (52 ("lleg" "sole")) ;; sensor-board 26
     )
    (("kxrl2makabefull")
     (:body :dyp :type :l2 :active-wheel :knee
	    :shoulder :y-p-r :wrist :r :passive-wheel :wrist :board :armh7
	    :board :armh7
	    :shoulder-p-sensor :rev-a :shoulder-r-sensor :rev-c
	    :elbow-p-sensor :rev-c :elbow-y-sensor :rev-a
	    :wrist-y-sensor :rev-a
	    :wrist-sensor t
	    :gripper-inner t ;;:gripper-sensor ((:finger1 . :rev-a))
	    :gripper-sensor :rev-a ;;(:finger1 :rev-a)
	    :neck-p-sensor :rev-c
	    :sole t
	    :chest-p-sensor t
	    :crotch-p-sensor :rev-a :crotch-r-sensor :rev-c :crotch-y-sensor :rev-a
	    :ankle-p-sensor t
	    :ankle-sensor t
	    :sole-sensor t :torso :dy-p :neck-axis :p :head :m5sh :head-length 38)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y -3/4)    (33 :torso-chest-y  -3/4)
     (32 :torso-chest-p 3/2)    (33 :torso-chest-p -3/2)
     (34 :head-neck-p   1)
     ;;
     (36 rarm-wrist-y-KJS-01)    (37 larm-wrist-y-KJS-01)
     (38 rarm-wrist-r-KJS-03)    (39 larm-wrist-r-KJS-03)
     (40 rarm-gripper-r-KJS-01)  (41 larm-gripper-r-KJS-01)
     (42 rarm-gripper2-r-KJS-01) (43 larm-gripper2-r-KJS-01)
     (44 rleg-ankle-r-KJS-03)    (45 lleg-ankle-r-KJS-03)
     (46 rleg-ankle-p-KJS-03)    (47 lleg-ankle-p-KJS-03)
     (48 rleg-crotch-p-KJS-01)   (49 lleg-crotch-p-KJS-01)
     (50 rleg-crotch-r-KJS-03)   (51 lleg-crotch-r-KJS-03)
     (52 rleg-crotch-y-KJS-01)   (53 lleg-crotch-y-KJS-01)
     (54 rarm-shoulder-p-KJS-01) (55 larm-shoulder-p-KJS-01)
     (56 rarm-shoulder-r-KJS-03) (57 larm-shoulder-r-KJS-03)
     (58 rarm-elbow-y-KJS-01)    (59 larm-elbow-y-KJS-01)
     (60 rleg-knee-p-KJS-03)    (61 lleg-knee-p-KJS-03)
     ;;     (60 rarm-elbow-p-KJS-03)    (61 larm-elbow-p-KJS-03)
     (62 torso-chest-p-KJS-03)
     (63 head-neck-p-KJS-03)
     ;;
     ;; (42 ("rarm-wrist" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (50 ("larm-wrist" "gripper2-" "KJS")) ;; sensor-board 25
     ;; (38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;; (46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg" "sole")) ;; sensor-board 22
     ;; (52 ("lleg" "sole")) ;; sensor-board 26
     )
    (("kxrl2makabeorig")		;; 33
     (:body :dyp :type :l2 :active-wheel :knee
	    :shoulder :y-p-r :wrist :r :passive-wheel :wrist :board :armh7
	    :board :armh7
	    :wrist-sensor t
	    :gripper-inner t :gripper-sensor ((:finger1 . :rev-a)) :sole t
	    :sole-sensor t :torso :dy-p3 :neck-axis :p :head :m5us :head-length 26)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y -3/4)    (33 :torso-chest-y  -3/4)
     (32 :torso-chest-p 3/2)    (33 :torso-chest-p -3/2)
     (34 :head-neck-p   1)
     ;;
     (42 rarm-gripper2-r-KJS-01) ;; sensor-board 21
     (50 larm-gripper2-r-KJS-01) ;; sensor-board 25
     (38 rarm-wrist-r-KJS-03) ;; sensor-board 19
     (46 larm-wrist-r-KJS-03) ;; sensor-board 23
     (44 rleg-ankle-r-KJS-01) ;; sensor-board 22
     (52 lleg-ankle-r-KJS-01) ;; sensor-board 26
     ;;
     ;; (42 ("rarm-wrist" "gripper2-" "KJS")) ;; sensor-board 21
     ;; (50 ("larm-wrist" "gripper2-" "KJS")) ;; sensor-board 25
     ;; (38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;; (46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg" "sole")) ;; sensor-board 22
     ;; (52 ("lleg" "sole")) ;; sensor-board 26
     )
    (("kxrl2makaberev2")		;; 33
     (:body :dyp-zf :type :l2 :active-wheel :knee
	    :shoulder :y-p-r :wrist :r :passive-wheel :wrist :board :armh7
	    :board :armh7
	    :wrist-sensor t
	    :gripper-inner t
	    ;;:gripper-sensor :finger1
	    :sole t
	    :project-file "kxrl2makaberev2"
	    :ankle-sensor t   ;;:sole-sensor t
	    :torso :y-p-y   ;; :torso :ly-p  :torso :dy-p     ;; :dy-p3
	    :neck-axis :p :head :m5s :head-length 26)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     
     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-p 1)
     (34 :torso-chest-y -1)
     (0 :head-neck-p   1)
     ;;
     (38 rarm-wrist-r-KJS-03) ;; sensor-board 19
     (46 larm-wrist-r-KJS-03) ;; sensor-board 23
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (52 lleg-ankle-r-KJS-03) ;; sensor-board 26
     ;;
     ;; (38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;; (46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     ;;     (44 ("rleg" "sole")) ;; sensor-board 22
     ;;     (52 ("lleg" "sole")) ;; sensor-board 26
     )
    (("kxrl2makaberev3")		;; 35
     (:body :dyp-zf :type :l2 :active-wheel :knee
	    :shoulder :y-p-r :wrist :r :passive-wheel :wrist :board :armh7
	    :board :armh7
	    :wrist-sensor t
	    :gripper-inner t
	    ;;:gripper-sensor :finger1
	    :sole t
	    :project-file "kxrl2makaberev2"
	    :ankle-sensor t   ;;:sole-sensor t
	    :torso :y-p-y   ;; :torso :ly-p  :torso :dy-p     ;; :dy-p3
	    :neck-axis :p :head :h2s :head-length 26)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     
     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-p 1)
     (34 :torso-chest-y  -1)
     (0 :head-neck-p   1)
     (1 :head-leye-y -1)     (33 :head-reye-y -1)
     ;;
     (38 rarm-wrist-r-KJS-03) ;; sensor-board 19
     (46 larm-wrist-r-KJS-03) ;; sensor-board 23
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (52 rleg-ankle-r-KJS-03) ;; sensor-board 26
     ;;
     ;; (38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;; (46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     ;;     (44 ("rleg" "sole")) ;; sensor-board 22
     ;;     (52 ("lleg" "sole")) ;; sensor-board 26
     )
    (("kxrl2makaberev2f1")		;; 33
     (:body :dyp-zf :type :l2 :active-wheel :knee
	    :shoulder :y-p-r :wrist :r :passive-wheel :wrist :board :armh7
	    :board :armh7
	    :wrist-sensor :rev-b
	    :gripper-sensor (:finger1 :rev-a)
	    :gripper-inner t
	    :sole t
	    :project-file "kxrl2makaberev2"
	    :ankle-sensor t   ;;:sole-sensor t
	    :torso :y-p-y   ;; :torso :ly-p  :torso :dy-p     ;; :dy-p3
	    :neck-axis :p :head :h2s :head-length 26)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     
     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-p 1)
     (34 :torso-chest-y  -1)
     (0 :head-neck-p   1)
     ;;
     (38 rarm-wrist-r-KJS-03) ;; sensor-board 19
     (46 larm-wrist-r-KJS-03) ;; sensor-board 23
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (52 lleg-ankle-r-KJS-03) ;; sensor-board 26
     (48 rarm-gripper-r-KJS-01) ;; sensor-board 24
     (50 larm-gripper-r-KJS-01) ;; sensor-board 25
     ;;
     ;; (38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;; (46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     ;; (48 ("rarm" "wrist" "KJS" "gripper2" "KJS")) ;; sensor-board 24
     ;; (50 ("larm" "wrist" "KJS" "gripper2" "KJS")) ;; sensor-board 25
     ;;     (44 ("rleg" "sole")) ;; sensor-board 22
     ;;     (52 ("lleg" "sole")) ;; sensor-board 26
     ;;(40 ("rarm" "KJS" "gripper-" "KJS")) ;; sensor-board 20
     ;;(42 ("larm" "KJS" "gripper-" "KJS")) ;; sensor-board 19
     ;;
     )
    (("kxrl2makaberev2f2")		;; 33
     (:body :dyp-zf :type :l2 :active-wheel :knee
	    :shoulder :y-p-r :wrist :r :passive-wheel :wrist :board :armh7
	    :board :armh7
	    :wrist-sensor t :gripper-sensor (:finger2 :rev-b)
	    :gripper-inner t
	    :sole t
	    :project-file "kxrl2makaberev2"
	    :ankle-sensor t   ;;:sole-sensor t
	    :torso :y-p-y   ;; :torso :ly-p  :torso :dy-p     ;; :dy-p3
	    :neck-axis :p :head :h2s :head-length 26)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     
     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-p 1)
     (34 :torso-chest-y  -1)
     (0 :head-neck-p   1)
     ;;
     (38 rarm-wrist-r-KJS-03) ;; sensor-board 19
     (46 larm-wrist-r-KJS-03) ;; sensor-board 23
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (52 lleg-ankle-r-KJS-03) ;; sensor-board 26
     (40 rarm-gripper-r-KJS-03) ;; sensor-board 24
     (52 larm-gripper-r-KJS-03) ;; sensor-board 25
     ;;
     ;; (38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;; (46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     ;; (40 ("rarm-wrist" "KJS" "gripper-" "KJS")) ;; sensor-board 20
     ;; (42 ("larm-wrist" "KJS" "gripper-" "KJS")) ;; sensor-board 19
     ;;
     ;;     (44 ("rleg" "sole")) ;; sensor-board 22
     ;;     (52 ("lleg" "sole")) ;; sensor-board 26
     ;;(48 ("rarm-wrist" "KJS" "gripper2" "KJS")) ;; sensor-board 24
     ;;(50 ("larm-wrist" "KJS" "gripper2" "KJS")) ;; sensor-board 25
     )
    (("kxrl2makaberev2s")		;; 33
     (:body :dyp-zf :type :l2 :active-wheel :knee
	    :shoulder :y-p-r :wrist :r :passive-wheel :wrist :board :armh7
	    :board :armh7
	    :wrist-sensor t :gripper-sensor :rev-a
	    :gripper-inner t
	    :sole t
	    :project-file "kxrl2makaberev2"
	    :ankle-sensor t   ;;:sole-sensor t
	    :torso :y-p-y   ;; :torso :ly-p  :torso :dy-p     ;; :dy-p3
	    :neck-axis :p :head :h2s :head-length 26)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     
     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-p 1)
     (34 :torso-chest-y  -1)
     (0 :head-neck-p   1)
     ;;
     (38 rarm-wrist-r-KJS-03) ;; sensor-board 19
     (46 larm-wrist-r-KJS-03) ;; sensor-board 23
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (52 lleg-ankle-r-KJS-03) ;; sensor-board 26
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 24
     (52 larm-gripper-r-KJS-01) ;; sensor-board 25
     (48 rarm-gripper2-r-KJS-01) ;; sensor-board 24
     (50 larm-gripper2-r-KJS-01) ;; sensor-board 25
     ;;
     ;; (38 ("rarm" "wrist-y" "KJS")) ;; sensor-board 19
     ;; (46 ("larm" "wrist-y" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg" "ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     ;; (40 ("rarm-wrist" "KJS" "gripper" "KJS")) ;; sensor-board 20
     ;; (42 ("larm-wrist" "KJS" "gripper" "KJS")) ;; sensor-board 19
     ;; (48 ("rarm-wrist" "KJS" "gripper2" "KJS")) ;; sensor-board 24
     ;; (50 ("larm-wrist" "KJS" "gripper2" "KJS")) ;; sensor-board 25
     ;;     (44 ("rleg" "sole")) ;; sensor-board 22
     ;;     (52 ("lleg" "sole")) ;; sensor-board 26
     )
    (("kxrl2makaberev4") ;; 33 with KJS-03
     (:body :dyp-zf :type :l2 :active-wheel :knee
	    :shoulder :y-p-r :wrist :r :passive-wheel :wrist :board :armh7
	    :board :armh7
	    :wrist-sensor t
	    :ankle-sensor t
	    :gripper t
	    :gripper-sensor t
	    ;;:gripper-sensor ((:finger1 . :rev-c) (:finger2 . :rev-c))
	    ;;:gripper-inner t
	    ;;:gripper-sensor :finger1
	    :sole t
	    :project-file "kxrl2makaberev3"
	    :torso :y-p-y   ;; :torso :ly-p  :torso :dy-p     ;; :dy-p3
	    :neck-axis :p :head :m5sh :head-length 26)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     
     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-p 1)
     (34 :torso-chest-y  -1)
     (0 :head-neck-p   1)
     ;; outer
     ;; (50 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 25
     ;; (42 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 21
     ;; ;; inner
     ;; (48 ("larm-wrist" "gripper2-" "KJS")) ;; sensor-board 24
     ;; (40 ("rarm-wrist" "gripper2-" "KJS")) ;; sensor-board 20
     ;;
     (38 rarm-wrist-r-KJS-03) ;; sensor-board 19
     (46 larm-wrist-r-KJS-03) ;; sensor-board 23
     ;;
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (52 lleg-ankle-r-KJS-03) ;; sensor-board 26
     ;;
     ;; (38 ("rarm-wrist-y" "wrist-r" "KJS")) ;; sensor-board 19
     ;; (46 ("larm-wrist-y" "wrist-r" "KJS")) ;; sensor-board 23
     ;; ;;
     ;; (44 ("rleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    (("kxrl2makaberev5") ;; 33 with KJS-03
     (:body :dyp-zf :type :l2 :active-wheel :knee
	    :shoulder :y-p-r :wrist :r :passive-wheel :wrist :board :armh7
	    :board :armh7
	    :wrist-sensor t
	    :ankle-sensor t
	    :gripper t
	    :gripper-sensor t
	    ;;:gripper-sensor ((:finger1 . :rev-c) (:finger2 . :rev-c))
	    ;;:gripper-inner t
	    ;;:gripper-sensor :finger1
	    :sole t
	    :project-file "kxrl2makaberev3"
	    :torso :y-p-y   ;; :torso :ly-p  :torso :dy-p     ;; :dy-p3
	    :neck-axis :p :head :m5us :head-length 26)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     
     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-p 1)
     (34 :torso-chest-y  -1)
     (0 :head-neck-p   1)
     ;; outer
     ;; (50 ("larm-wrist" "gripper-" "KJS")) ;; sensor-board 25
     ;; (42 ("rarm-wrist" "gripper-" "KJS")) ;; sensor-board 21
     ;; ;; inner
     ;; (48 ("larm-wrist" "gripper2-" "KJS")) ;; sensor-board 24
     ;; (40 ("rarm-wrist" "gripper2-" "KJS")) ;; sensor-board 20
     ;;
     (38 rarm-wrist-r-KJS-03) ;; sensor-board 19
     (46 larm-wrist-r-KJS-03) ;; sensor-board 23
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (52 lleg-ankle-r-KJS-03) ;; sensor-board 26
     ;;
     ;; (38 ("rarm-wrist-y" "wrist-r" "KJS")) ;; sensor-board 19
     ;; (46 ("larm-wrist-y" "wrist-r" "KJS")) ;; sensor-board 23
     ;; (44 ("rleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    (("kxr_transformer_rev3")		;; 35
     (:file "catkin_ws_src/kxr_pkgs/kxr_models/euslisp/kxr_transformer_rev3.l"
	    :form (progn (load "additional-settings.l") (kxr_transformer_rev3))
	    :board :armh7
	    ;;:project-file "kxr_transformer_rev3"
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     
     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     ;;(32 :torso-chest-w 1)
     (32 :torso-chest-w 1 0 sr 38 9918);;KRS-3304R2, ID 16, 1.25Mbps
     (34 :torso-chest-y  -1)
     (0 :head-neck-p   1)
     (1 :head-neck-y -1)
     ;;
     (38 rarm-wrist-r-KJS-03) ;; sensor-board 19
     (46 larm-wrist-r-KJS-03) ;; sensor-board 23
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (52 rleg-ankle-r-KJS-03) ;; sensor-board 26
     ;;torso sensor-board 27
     )
    (("kxr_transformer_rev3_normal_leg_6magnet_wheel")
     (:file "catkin_ws_src/kxr_pkgs/kxr_models/euslisp/kxr_transformer_rev3_normal_leg_6magnet_wheel.l"
	    :form (progn (load "additional-settings.l") (kxr_transformer_rev3_normal_leg_6magnet_wheel))
	    :board :armh7
	    ;;:project-file "kxr_transformer_rev3_normal_leg_6magnet_wheel"
	    )
     (2 :rarm-shoulder-p -1)     (3 :larm-shoulder-p 1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1 1.7)      (9 :lleg-crotch-r -1 1.4)
     (10 :rleg-crotch-p 1 7)   (11 :lleg-crotch-p 1 10.0)
     (12 :rleg-knee-p -1 -60)       (13 :lleg-knee-p -1 -64) 
     (14 :rleg-ankle-p -1 26)      (15 :lleg-ankle-p -1 22)
     (16 :rleg-ankle-r 1 -4.4)      (17 :lleg-ankle-r 1 -1.4)
     
     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     
     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     ;;(32 :torso-chest-w 1)
     (32 :torso-chest-w 1 0 sr sensor-id magenc-offset);;todo update params
     (34 :torso-chest-y  1)
     (0 :head-neck-p   1)
     (1 :head-neck-y 1)
     ;;
     (38 rarm-wrist-r-KJS-03) ;; sensor-board 19
     (39 larm-wrist-r-KJS-03) ;; sensor-board 19
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (45 lleg-ankle-r-KJS-03) ;; sensor-board 22
     (40 torso-KJS-03) ;;sensor-board 20
     )
    (("kxr_transformer_rev4");; 35
     (:file "catkin_ws_src/kxr_pkgs/kxr_models/euslisp/kxr_transformer_rev4_magnet.l"
	    :form (progn (load "additional-settings.l") (kxr_transformer_rev4_magnet))
	    :board :armh7
	    ;;:project-file "kxr_transformer_rev4"
	    )
     (2 :rarm-shoulder-p -1 45 s4)     (3 :larm-shoulder-p 1 -90 s4);;
     (4 :rarm-shoulder-r -1 0 s1)    (5 :larm-shoulder-r -1 s1);;
     (6 :rarm-elbow-p -1 90 s4)        (7 :larm-elbow-p -1 90 s4);;
     
     (16 :rleg-ankle-r 1 0 s1)      (17 :lleg-ankle-r 1 0 s1);;

     (18 :rarm-gripper-r -1/2 0 s1)    (19 :larm-gripper-r -1/2 0 s1);;
     (18 :rarm-gripper2-r -1/2 0 s1)   (19 :larm-gripper2-r -1/2 0 s1);;
     (20 :rleg-crotch-w 1 0 s1)        (21 :lleg-crotch-w -1 0 s1);;
     (22 :rarm-shoulder-y -1 90 s1)   (23 :larm-shoulder-y -1 -90 s1);;
     (24 :rleg-crotch-y 1 0 s1)      (25 :lleg-crotch-y 1 0 s1);;
     
     (26 :rarm-elbow-y 1 0 s1)       (27 :larm-elbow-y 1 0 s1);;
     (28 :rarm-wrist-p -1 0 s1)       (29 :larm-wrist-p -1 0 s1);;
     (30 :rarm-wrist-y 1 0 s1)       (31 :larm-wrist-y 1 0 s1);;
     (32 :torso-chest-w 1 0 sr 48 16192);;
     (34 :torso-chest-y 1 0 s4);;
     (0 :head-neck-p 1 0 s1);;
     (8 :head-neck-y -1 0 s1);;
     ;;
     (38 rarm-wrist-y-KJS-03) ;; sensor-board 19
     (39 larm-wrist-y-KJS-03) ;; sensor-board 19
     ;;     (40 torso-chest-y-KJS-03) ;; sensor-board 20
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (45 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (48 torso-chest-w-KJS-03) ;; sensor-board 24
     ;;torso sensor-board 27
     )
    (("kxr_transformer_rev5_6magnet")
     (:file "catkin_ws_src/kxr_pkgs/kxr_models/euslisp/kxr_transformer_rev5_6magnet.l"
	    :form (progn (load "additional-settings.l") (kxr_transformer_rev5_6magnet))
	    :board :armh7
	    )
     (2 :rarm-shoulder-p -1)     (3 :larm-shoulder-p 1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1 1.7)      (9 :lleg-crotch-r -1 1.4)
     (10 :rleg-crotch-p 1 7)   (11 :lleg-crotch-p 1 10.0)
     (12 :rleg-knee-p -1 -60)       (13 :lleg-knee-p -1 -64)
     (14 :rleg-ankle-p -1 26)      (15 :lleg-ankle-p -1 22)
     (16 :rleg-ankle-r 1 -4.4)      (17 :lleg-ankle-r 1 -1.4)
     
     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     
     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     ;;(32 :torso-chest-w 1)
     (32 :torso-chest-w 1 0 sr sensor-id magenc-offset);;todo update params
     (34 :torso-chest-y  1)
     (0 :head-neck-p 1)
     (1 :head-neck-y 1)
     ;;
     (38 rarm-wrist-r-KJS-03) ;; sensor-board 19
     (39 larm-wrist-r-KJS-03) ;; sensor-board 19
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (45 lleg-ankle-r-KJS-03) ;; sensor-board 22
     (40 torso-KJS-03) ;;sensor-board 20
     )
    (("kxr_transformer_rev5_8magnet")
     (:file "catkin_ws_src/kxr_pkgs/kxr_models/euslisp/kxr_transformer_rev5_8magnet.l"
	    :form (progn (load "additional-settings.l") (kxr_transformer_rev5_8magnet))
	    :board :armh7
	    )
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (2 :rarm-shoulder-p -1)     (3 :larm-shoulder-p 1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-p 1)       (31 :larm-wrist-p 1)
     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p 1)   (11 :lleg-crotch-p 1)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r 1)      (17 :lleg-ankle-r 1)
     
     (32 :torso-chest-w 1 0 sr sensor-id magenc-offset);;todo update params
     (34 :torso-chest-y  1)

     (33 :head-neck-p 1)
     (35 :head-neck-y 1)
     
     ;;sensor: ID:19~30
     (38 rarm-wrist-r-KJS-03) ;; sensor-board 19
     (39 larm-wrist-r-KJS-03) ;; sensor-board 19
     (40 rarm-gripper-r-KJS-01) ;; sensor-board 20
     (41 larm-gripper-r-KJS-01) ;; sensor-board 20
     (42 rarm-gripper2-r-KJS-01) ;; sensor-board 21
     (43 larm-gripper2-r-KJS-01) ;; sensor-board 21
     (48 rarm-wrist-r-KJS-03) ;; sensor-board 24
     (49 larm-wrist-r-KJS-03) ;; sensor-board 24
     (50 rarm-shoulder-w-KJS-03) ;; sensor-board 25
     (51 larm-shoulder-w-KJS-03) ;; sensor-board 25
     
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (45 lleg-ankle-r-KJS-03) ;; sensor-board 22
     (46 rleg-knee-p-KJS-03) ;; sensor-board 23
     (47 larm-knee-p-KJS-03) ;; sensor-board 23
     
     (52 torso-KJS-03) ;;sensor-board 26
     )
    ("kxr_l2g"   ;; 18
     (:file "models/kxr_l2g.l"
	    :form (progn (load "additional-settings.l") (kxr_l2g))
	    :board :armh7
	    )
     (2 :rarm-shoulder-p 1 -45 s2)   (3 :larm-shoulder-p 1 45 s2)
     (4 :rarm-shoulder-r -1 -90 s2)  (5 :larm-shoulder-r -1 -90 s2)
     (6 :rarm-elbow-p -1 0 s2)      (7 :larm-elbow-p -1 0 s2)
     (18 :rarm-gripper-r 1/2 0 s2)  (19 :larm-gripper-r 1/2 0 s2)
     (18 :rarm-gripper2-r 1/2 0 s2) (19 :larm-gripper2-r 1/2 0 s2)

     (8 :rleg-crotch-r -1 0 s2)      (9 :lleg-crotch-r -1 0 s2)
     (10 :rleg-crotch-p 1 7.82 s2)   (11 :lleg-crotch-p 1 7.82 s2)
     (12 :rleg-knee-p -1 -66.09 s4)  (13 :lleg-knee-p -1 -66.09 s4)
     (14 :rleg-ankle-p -1 16.0758 s4) (15 :lleg-ankle-p -1 16.0758 s4)
     (16 :rleg-ankle-r 1 0 s2)      (17 :lleg-ankle-r 1 0 s2)
     )
    ("kxr_mag_humanoid_2dof"
     (:file "models/kxr_mag_humanoid_2dof.l"
	    :form (progn (load "additional-settings.l") (kxr_mag_humanoid_2dof))
	    :board :armh7
	    )
     (34 :head-neck-p 1);;
     (32 :head-neck-y 1);;
     
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p 1);;
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1);;
     (22 :rarm-elbow-y 1)   (23 :larm-elbow-y 1);;
     (6 :rarm-elbow-p -1 90)        (7 :larm-elbow-p -1 90);;
     (26 :rarm-wrist-p -1 90)       (27 :larm-wrist-p -1 -90);;
     (28 :rarm-wrist-y 1)       (29 :larm-wrist-y 1);;
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2);;
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2);;

     (24 :rleg-crotch-y 1 0)      (25 :lleg-crotch-y 1 0)
     (16 :rleg-ankle-r 1 0)      (17 :lleg-ankle-r 1 0)
     )
    ("kxr_mag_humanoid_5dof"
     (:file "models/kxr_mag_humanoid_5dof.l"
	    :form (progn (load "additional-settings.l") (kxr_mag_humanoid_5dof))
	    :board :armh7
	    )
     (34 :head-neck-p 1);;
     (32 :head-neck-y 1);;
     
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p 1);;
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1);;
     (22 :rarm-elbow-y 1)   (23 :larm-elbow-y 1);;
     (6 :rarm-elbow-p -1 90)        (7 :larm-elbow-p -1 90);;
     (26 :rarm-wrist-p -1 90)       (27 :larm-wrist-p -1 -90);;
     (28 :rarm-wrist-y 1)       (29 :larm-wrist-y 1);;
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2);;
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2);;

     (8 :rleg-crotch-r -1 0)      (9 :lleg-crotch-r -1 0)
     (10 :rleg-crotch-p 1 7.82)   (11 :lleg-crotch-p 1 7.82)
     (12 :rleg-knee-p -1 -66.09)  (13 :lleg-knee-p -1 -66.09)
     (14 :rleg-ankle-p -1 16.0758) (15 :lleg-ankle-p -1 16.0758)
     (16 :rleg-ankle-r 1 0)      (17 :lleg-ankle-r 1 0)
     )
    ("kxr_mag_humanoid_6dof"
     (:file "models/kxr_mag_humanoid_6dof.l"
	    :form (progn (load "additional-settings.l") (kxr_mag_humanoid_6dof))
	    :board :armh7
	    )
     (34 :head-neck-p 1);;
     (32 :head-neck-y 1);;
     
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p 1);;
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1);;
     (22 :rarm-elbow-y 1)   (23 :larm-elbow-y 1);;
     (6 :rarm-elbow-p -1 90)        (7 :larm-elbow-p -1 90);;
     (26 :rarm-wrist-p -1 90)       (27 :larm-wrist-p -1 -90);;
     (28 :rarm-wrist-y 1)       (29 :larm-wrist-y 1);;
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2);;
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2);;

     (24 :rleg-crotch-y 1 0)      (25 :lleg-crotch-y 1 0)
     (8 :rleg-crotch-r -1 0)      (9 :lleg-crotch-r -1 0)
     (10 :rleg-crotch-p 1 7.82)   (11 :lleg-crotch-p 1 7.82)
     (12 :rleg-knee-p -1 -66.09)  (13 :lleg-knee-p -1 -66.09)
     (14 :rleg-ankle-p -1 16.0758) (15 :lleg-ankle-p -1 16.0758)
     (16 :rleg-ankle-r 1 0)      (17 :lleg-ankle-r 1 0)
     )
    ("kxr_mag_humanoid_mechanum"
     (:file "models/kxr_mag_humanoid_mechanum.l"
	    :form (progn (load "additional-settings.l") (kxr_mag_humanoid_mechanum))
	    :board :armh7
	    )
     (34 :head-neck-p 1);;
     (32 :head-neck-y 1);;
     
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p 1);;
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1);;
     (22 :rarm-elbow-y 1)   (23 :larm-elbow-y 1);;
     (6 :rarm-elbow-p -1 90)        (7 :larm-elbow-p -1 90);;
     (26 :rarm-wrist-p -1 90)       (27 :larm-wrist-p -1 -90);;
     (28 :rarm-wrist-y 1)       (29 :larm-wrist-y 1);;
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2);;
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2);;

     (8 :rleg-crotch-w 1)      (9 :lleg-crotch-w -1)
     (10 :rleg-knee-w 1)       (11 :lleg-knee-w -1)
     )
    (("kxr_magtest");; 35
     (:file "catkin_ws_src/kxr_pkgs/kxr_models/euslisp/kxr_transformer_rev4_magnet.l"
	    :form (progn (load "additional-settings.l") (kxr_transformer_rev4_magnet))
	    :board :armh7
	    ;;:project-file "kxr_transformer_rev4"
	    )
     (2 :rarm-shoulder-p -1)     (3 :larm-shoulder-p 1);;
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1);;
     (22 :rarm-elbow-y 1)   (23 :larm-elbow-y 1);;
     (6 :rarm-elbow-p -1 90)        (7 :larm-elbow-p -1 90);;
     (26 :rarm-wrist-p -1 90)       (27 :larm-wrist-p 1 90);;
     (28 :rarm-wrist-y 1)       (29 :larm-wrist-y 1);;
     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2);;
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2);;
     (0 :rarm-chest-w 1)        (1 :larm-chest-w -1);;
     
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1);;
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r 1);;
     (20 :rleg-crotch-w 1)        (21 :lleg-crotch-w -1);;
     
     (34 :head-neck-p   1);;
     (32 :head-neck-y -1);;
     )
    (("kxr-magnet-test");; 35
     (:file "catkin_ws_src/kxr_pkgs/kxr_models/euslisp/kxr-magnet-test.l"
    	    :form (progn (load "additional-settings.l") (kxr-magnet-test))
    	    :board :armh7
    	    ;;:project-file "kxr_transformer_rev4"
    	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p 1);;
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1);;
     (22 :rarm-elbow-y 1)   (23 :larm-elbow-y 1);;
     (6 :rarm-elbow-p -1 90)        (7 :larm-elbow-p -1 90);;
     (26 :rarm-wrist-p -1 90)       (27 :larm-wrist-p -1 -90);;
     (28 :rarm-wrist-y 1)       (29 :larm-wrist-y 1);;
     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2);;
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2);;
     
     (24 :singleyaw0-y 1)      (25 :singleyaw1-y 1);;
     (16 :singleroll0-r 1)      (17 :singleroll1-r 1);;
     
     (0 :rleg-ankle-w 1)        (1 :lleg-ankle-w -1);;
     (20 :rleg-ankle2-w 1)        (21 :lleg-ankle2-w -1);;
     
     (34 :head-neck-p 1);;
     (32 :head-neck-y 1);;
     ;;
     )
    (("kxr_spider_auv")		;; 18
     (:file "catkin_ws_src/kxr_pkgs/kxr_models/euslisp/kxr_spider_auv.l"
	    :form (progn (load "additional-settings.l") (kxr_spider_auv))
	    :board :armh7
	    :project-file "kxrl6"
	    )
     ;;new
     (2 :rarm-shoulder-y 1)    (3 :larm-shoulder-y 1)
     (4 :rarm-shoulder-p -1)    (5 :larm-shoulder-p -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rmarm-shoulder-y 1)   (9 :lmarm-shoulder-y 1)
     (10 :rmarm-shoulder-r -1)  (11 :lmarm-shoulder-r -1)
     (12 :rmarm-elbow-r 1)      (13 :lmarm-elbow-r 1)
     (14 :rleg-crotch-y 1)     (15 :lleg-crotch-y 1)
     (16 :rleg-crotch-p -1)     (17 :lleg-crotch-p -1)
     (18 :rleg-knee-p 1)       (19 :lleg-knee-p 1)

     (20 :head-neck-p 1);;
     (22 :head-neck-y 1);;

     (39 base_link-KJS-03) ;; sensor-board 19

     ;;old
     ;; (2 :larm-shoulder-y 1)    (3 :rarm-shoulder-y 1)
     ;; (4 :larm-shoulder-p -1)    (5 :rarm-shoulder-p -1)
     ;; (6 :larm-elbow-p 1)        (7 :rarm-elbow-p 1)
     ;; (8 :lmarm-shoulder-y 1)   (9 :rmarm-shoulder-y 1)
     ;; (10 :lmarm-shoulder-r -1)  (11 :rmarm-shoulder-r -1)
     ;; (12 :lmarm-elbow-r 1)      (13 :rmarm-elbow-r 1)
     ;; (14 :lleg-crotch-y 1)     (15 :rleg-crotch-y 1)
     ;; (16 :lleg-crotch-p -1)     (17 :rleg-crotch-p  -1)
     ;; (18 :lleg-knee-p 1)       (19 :rleg-knee-p 1)

     ;; (21 :head-neck-p 1);;
     ;; (23 :head-neck-y 1);;

     ;; (38 base_link-KJS-03) ;; sensor-board 19
     
     )
    (("kxrl2w2t2l6a7h10" "kxrl2makabe0")		;; 33
     (:body :dyp :type :l2 :knee-type t :active-wheel :knee 
	    :shoulder :y-p-r :wrist :r :passive-wheel :wrist :gripper-inner t
	    :torso :dy-p :neck-axis :p :head :m5 :head-length 20 :sole t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y -3/4)    (33 :torso-chest-y  -3/4)
     (32 :torso-chest-p 3/2)    (33 :torso-chest-p -3/2)
     (34 :head-neck-p   1)
     )

    (("kxrl2w2t2l6a7h1raspi" "kxrl2makaberaspi")         ;; 33
     (:body :dyp :type :l2 :knee-type t :active-wheel :knee 
	    :shoulder :y-p-r :wrist :r :passive-wheel :wrist :gripper t  :gripper-inner t
	    :torso :dy-p2 :neck-axis :p :head :realsense :head-length 20 :sole t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)

     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y -3/4)    (33 :torso-chest-y  -3/4)
     (32 :torso-chest-p 3/2)    (33 :torso-chest-p -3/2)
     (34 :head-neck-p   1)
     )
    (("kxrl2w2t2l6a7h1raspy" "kxrl2makaberaspy")         ;; 33
     (:body :dyp :type :l2 :knee-type t :active-wheel :knee 
	    :shoulder :y-p-r :wrist :r :passive-wheel :wrist :gripper t  :gripper-inner t
	    :torso :dy-p :head :realsense-y :neck nil :head-length 20 :sole t)
     ;;(0 :head-neck-y 1)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)

     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rarm-elbow-y 1)       (27 :larm-elbow-y  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y -3/4)    (33 :torso-chest-y  -3/4)
     (32 :torso-chest-p 3/2)    (33 :torso-chest-p -3/2)
     (34 :head-neck-p   1)
     )
    (("kxrl2l6anzai")    ;; 30 (kxrl2l6a7h2ypr)
     (:body :l2l6 :type :l2 :head :h2s :shoulder :cross :wrist :y-cross :gripper t :sole t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p -1 -90)   (7 :larm-elbow-p -1 -90)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rarm-wrist-r -1)      (21 :larm-wrist-r -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-y 1)       (27 :larm-wrist-y 1)
     (28 :rarm-wrist-p -1)      (29 :larm-wrist-p -1)
     (32 :head-neck-y -1)
     (34 :head-neck-p -1)
     )
    (("kxrl2l6anzais")    ;; 30 (kxrl2l6a7h2ypr) with sensor
     (:body :l2l6 :type :l2 :head :h2s :shoulder :cross :wrist :y-cross :gripper t
	    :board :armh7
	    :gripper-sensor :larm :sole t)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p -1 -90)   (7 :larm-elbow-p -1 -90)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rarm-wrist-r -1)      (21 :larm-wrist-r -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-y 1)       (27 :larm-wrist-y 1)
     (28 :rarm-wrist-p -1)      (29 :larm-wrist-p -1)
     (32 :head-neck-y -1)
     (34 :head-neck-p -1)

     (38 larm-gripper2-r-KJS-03) ;; sensor-board 19
     (40 larm-gripper-r-KJS-03) ;; sensor-board 23
     ;;
     ;; (38 ("larm-wrist" "KJS" "gripper2")) ;; sensor-board 19
     ;; (40 ("larm-wrist" "KJS" "gripper-")) ;; sensor-board 20
     )
    (("kxrl2l6anzai3")    ;; 30 (kxrl2l6a7h2ypr)
     (:body :l2l6 :type :l2 :head :h2s :shoulder :cross :wrist :y-cross :gripper t :sole t :project-file "kxrl2l6anzai")
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p -1 -90)   (7 :larm-elbow-p -1 -90)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rarm-wrist-r -1)      (21 :larm-wrist-r -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-y 1)       (27 :larm-wrist-y 1)
     (28 :rarm-wrist-p -1)      (29 :larm-wrist-p -1)
     (32 :head-neck-y -1)
     (34 :head-neck-p -1)
     (33 :head-leye-y 1)
     (35 :head-reye-y 1)
     )

    (("kxrl2l6anzaifly")
     (:body :l2l6 :type :l2 :wing t :head :m5sh :shoulder :cross
	    :board :armh7
	    :wrist :y-cross :gripper t :sole t :project-file "kxrl2l6anzai")
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p -1 -90)   (7 :larm-elbow-p -1 -90)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rarm-wrist-r -1)      (21 :larm-wrist-r -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-y 1)       (27 :larm-wrist-y 1)
     (28 :rarm-wrist-p -1)      (29 :larm-wrist-p -1)
     (30 :rwing-gimbal0-p 1)	(31 :lwing-gimbal0-p 1)
     (0 :rwing-gimbal0-w 1)	(1 :lwing-gimbal0-w 1)
     (32 :head-neck-y -1)
     (34 :head-neck-p -1)
     )
    (("kxrl2l6anzaifly5")
     (:body :l2l6 :type :l2 :wing :5inch :head :m5us :shoulder :cross
	    :board :armh7
	    :wrist :y-cross :gripper t :sole t :project-file "kxrl2l6anzai")
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p -1 -90)   (7 :larm-elbow-p -1 -90)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rarm-wrist-r -1)      (21 :larm-wrist-r -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-wrist-y 1)       (27 :larm-wrist-y 1)
     (28 :rarm-wrist-p -1)      (29 :larm-wrist-p -1)
     (30 :rwing-gimbal0-p 1)	(31 :lwing-gimbal0-p 1)
     (0 :rwing-gimbal0-w 1)	(1 :lwing-gimbal0-w 1)
     (32 :head-neck-y -1)
     (34 :head-neck-p -1)
     )
    (("kxrl2l5anzaifly")
     (:body :l2l5 :type :l2 :wing t :gripper t :head :m5u2s :neck-jf :b :sole t :project-file "kxrl2l5a3h2g")
     (2 :rarm-shoulder-p 1)    (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)   (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)       (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)    (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)       (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)     (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)     (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2) (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y 1)       (32 :head-neck-p 1)
     (28 :rwing-gimbal0-p 1)   (29 :lwing-gimbal0-p 1)
     (0 :rwing-gimbal0-w 1)    (1 :lwing-gimbal0-w 1)
     )
    ("kxrl2l5anzaifly5"
     (:body :l2l5 :type :l2 :wing :5inch :gripper t :head :m5us :neck-jf :b :sole t :project-file "kxrl2l5a3h2g")
     (2 :rarm-shoulder-p 1)    (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)   (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)       (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)    (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)       (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)     (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)     (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r 1/2)  (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2) (19 :larm-gripper2-r 1/2)
     (30 :head-neck-y 1)       (32 :head-neck-p 1)
     (28 :rwing-gimbal0-p 1)   (29 :lwing-gimbal0-p 1)
     (0 :rwing-gimbal0-w 1)    (1 :lwing-gimbal0-w 1)
     )
    (("kxrl2test")		;; 33  ;;  no :knee-type t in kxrl2makabe, WIP
     (:body :dyp :type :l2 :torso :dy-p :shoulder :y-p-r :leg :l6w
	    :passive-wheel :wrist 
	    :wrist :r :gripper-inner t :neck-axis :p :head :h2s :sole t
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-elbow-y -1)      (27 :larm-elbow-y -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y 1)      (33 :torso-chest-p 1)
     (34 :head-neck-p   1)
     )
    (("kxrl2test6")
     ;; 33  ;;  no :knee-type t in kxrl2makabe, WIP
     (:body :lyp-low :type :l2 :active-wheel :knee :torso :ly-p :shoulder :ly-p-r
	    :passive-wheel :wrist :wrist :r :gripper-inner t
	    :neck-axis :p :head :m5us :sole t
	    )
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)     (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rleg-crotch-r 1)       (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)     (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)        (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (20 :rleg-knee-w 1)        (21 :lleg-knee-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (26 :rarm-elbow-y -1)      (27 :larm-elbow-y -1)
     (28 :rarm-wrist-r -1)      (29 :larm-wrist-r -1)
     (30 :rarm-wrist-y 1)       (31 :larm-wrist-y 1)
     (32 :torso-chest-y 1)      (33 :torso-chest-p 1)
     (34 :head-neck-p   1)
     )
    ("kxrr4ll"		;; 12
     ()
     (2 :rarm-shoulder-y 1)   (3 :larm-shoulder-y 1)
     (4 :rarm-shoulder-p -1)  (5 :larm-shoulder-p 1)
     (6 :rarm-wrist-p 1)      (7 :larm-wrist-p -1)
     
     (8 :rleg-crotch-y 1)     (9 :lleg-crotch-y 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p 1)
     (12 :rleg-ankle-p 1)     (13 :lleg-ankle-p -1)
     )
    ("premaidai"		;; 25 servos
     ()
     (2 :rarm-shoulder-p 1)     (4 :larm-shoulder-p -1)
     (9 :rarm-shoulder-r 1)    (11 :larm-shoulder-r 1)
     (17 :rarm-elbow-p 1)       (19 :larm-elbow-p 1)
     (14 :rleg-crotch-p 1)      (12 :lleg-crotch-r 1)
     (10 :rleg-crotch-r 1)     (16 :lleg-crotch-p -1)
     (18 :rleg-knee-p -1)        (20 :lleg-knee-p 1)
     (22 :rleg-ankle-p 1)      (24 :lleg-ankle-p 1)
     (26 :rleg-ankle-r 1)      (28 :lleg-ankle-r 1)
     (13 :rarm-shoulder-y 1)    (15 :larm-shoulder-y 1)
     (6 :rleg-crotch-y 1)       (8 :lleg-crotch-y 1)
     (21 :rarm-wrist-y 1)      (23 :larm-wrist-y 1)
     (5 :head-neck-y 1)       (3 :head-neck-p 1)
     (7 :head-neck-r 1)
     )
    ;;
    ("khrnishio"
     (:body :l2l5 :head :m5sh :gripper t
	    :wing :5inch :wing-pos #f(-80.0 0.0 50.0)
	    :sole :b :sole-sensor t :passive-wheel :sole
	    :board :armh7 ;;:project-file "khr3"
	    :com-init-method (:arm-open :pid #x6001)
	    ) ;; same as :arm2-open, pid:#x6015 for Akizuki, :vid #x0403
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     ;;
     (44 ("RLEG_LINK4")) ;; sensor-board 22
     (52 ("LLEG_LINK4")) ;; sensor-board 26
     )
    ;;
    ("khrmain"		;;  ;; generated (khr2collada-robot) in eus2wrl.l
     (:file "models/KHRmain.l" :form (khr) :project-file "khr3" :board :armh7
	    :com-init-method (:arm-open :pid #x6001)) ;; same as :arm2-open, pid:#x6015 for Akizuki, :vid #x0403
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     ;;
     (44 ("RLEG_LINK4")) ;; sensor-board 22
     (52 ("LLEG_LINK4")) ;; sensor-board 26
     )
    ("khr"		;;
     (:file "KHR/khr.l" :form (khr) :project-file "khr3"
	    :board :armh7 :com-init-method (:arm2-open)) ;; same as :arm2-open, pid:#x6015 for Akizuki, :vid #x0403
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     ;;
     (44 ("RLEG_LINK4")) ;; sensor-board 22
     (52 ("LLEG_LINK4")) ;; sensor-board 26
     )
    ("khrh2"		;;
     (:file "KHR/khrh2.l" :form (khrh2) :project-file "khr3"
	    :board :armh7 :com-init-method (:arm2-open))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (22 :head-neck-p 1) 
     )
    ("khr20"
     ;;(:file "KHR/khr20.l" :form (khr20) :project-file "khr3" :board :armh7 :com-init-method (:arm2-open))
     (:body :l2l6 :wrist t :project-file "khr3semi" :board :armh7
	    :torso t :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (1 :torso-chest-y -1)
     ;;
     )
    ("khr20-cad"
     (:file "KHR/khr20.l" :form (khr20) :project-file "khr3" :board :armh7 :com-init-method (:arm2-open))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (1 :torso-chest-y -1)
     ;;
     )
    ("khr20h2"
     ;;(:file "KHR/khr20h2.l" :form (khr20h2) :project-file "khr3"
     ;;:board :armh7 :com-init-method (:arm2-open))
     (:body :l2l6 :head :m5sh :wrist t :project-file "khr3semi" :board :armh7
	    :torso t :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (1 :torso-chest-y -1)
     (22 :head-neck-p 1) 
     ;;
     )
    ("khr20h2-cad"
     (:file "KHR/khr20h2.l" :form (khr20h2) :project-file "khr3"
	    :board :armh7 :com-init-method (:arm2-open))
     ;;(:body :l2l6 :head :m5sh :wrist t :project-file "khr3semi" :board :armh7
     ;;:torso t :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (1 :torso-chest-y -1)
     (22 :head-neck-p 1) 
     ;;
     )
    ("khrl6a3h2" ;; no torso axis of khr20h2
     ;;(:file "KHR/khrl6a3h2.l" :form (khrl6a3h2) :project-file "khr3" :board :armh7 :com-init-method (:arm2-open))
     (:body :l2l6 :head :m5sh :wrist t :project-file "khr3semi" :board :armh7
	    :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)      (22 :head-neck-p 1) 
     ;;
     )
    ("khrl6a3h2m" ;; no torso axis of khr20h2
     ;;(:file "KHR/khrl6a3h2.l" :form (khrl6a3h2) :project-file "khr3" :board :armh7 :com-init-method (:arm2-open))
     (:body :l2l6 :head :d405echos :wrist t :project-file "khr3semi" :board :armh7
	    :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)      (22 :head-neck-p 1) 
     ;;
     )
    ("khrl6a3h2-cad" ;; no torso axis of khr20h2
     (:file "KHR/khrl6a3h2.l" :form (khrl6a3h2) :project-file "khr3" :board :armh7 :com-init-method (:arm2-open))
     ;;(:body :l2l6 :head :m5sh :wrist t :project-file "khr3semi" :board :armh7
     ;;:com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)      (22 :head-neck-p 1) 
     ;;
     )
    ("khrt1l6a3h2" ;; same as khr20h2
     ;;(:file "KHR/khrt1l6a3h2.l" :form (khrt1l6a3h2) :project-file "khr3" :board :armh7 :com-init-method (:arm2-open))
     (:body :l2l6 :head :m5sh :wrist t :project-file "khr3semi" :board :armh7
	    :torso t :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)      (1 :torso-chest-y -1)
     (22 :head-neck-p 1) 
     ;;
     )
    ("khrt1l6a3h2m" ;; same as khr20h2
     ;;(:file "KHR/khrt1l6a3h2.l" :form (khrt1l6a3h2) :project-file "khr3" :board :armh7 :com-init-method (:arm2-open))
     (:body :l2l6 :head :d405echos :wrist t :project-file "khr3semi" :board :armh7
	    :torso t :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)      (1 :torso-chest-y -1)
     (22 :head-neck-p 1) 
     ;;
     )
    ("khrt1l6a3h2-cad" ;; same as khr20h2
     (:file "KHR/khrt1l6a3h2.l" :form (khrt1l6a3h2) :project-file "khr3" :board :armh7 :com-init-method (:arm2-open))
     ;;(:body :l2l6 :head :m5sh :wrist t :project-file "khr3semi" :board :armh7
     ;;:torso t :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (1 :torso-chest-y -1)
     (22 :head-neck-p 1) 
     ;;
     )
    ("khr22"
     ;;(:file "KHR/khr22.l" :form (khr22) :project-file "khr3" :board :armh7 :com-init-method (:arm2-open))
     (:body :l2l6 :wrist t :project-file "khr3semi" :board :armh7
	    :torso t :shoulder :y :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (1 :torso-chest-y -1)
     ;;
     )
    ("khr22-cad"
     (:file "KHR/khr22.l" :form (khr22) :project-file "khr3" :board :armh7 :com-init-method (:arm2-open))
     ;;(:body :l2l6 :wrist t :project-file "khr3semi" :board :armh7
     ;;:torso t :shoulder :y :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     ;;     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     ;;     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1);;     (1 :torso-chest-y -1)
     ;;
     )
    ("khr22h2" 
     ;;(:file "KHR/khr22h2.l" :form (khr22h2) :project-file "khr3" :board :armh7 :com-init-method (:arm2-open))
     (:body :l2l6 :head :m5sh :wrist t :project-file "khr3semi" :board :armh7
	    :torso t :shoulder :y :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (1 :torso-chest-y -1)
     (22 :head-neck-p 1) 
     ;;
     )
    ("khrl6a4h2" ;; no torso axis of khr22h2
     ;;(:file "KHR/khrl6a4h2.l" :form (khrl6a4h2) :project-file "khr3"
     ;;:board :armh7 :com-init-method (:arm2-open))
     (:body :l2l6 :head :m5sh :wrist t :project-file "khr3semi" :board :armh7
	    :shoulder :y :com-init-method (:arm2-open))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p -1) 
     ;;
     )
    ("khrl6a4h2-cad" ;; no torso axis of khr22h2
     (:file "KHR/khrl6a4h2.l" :form (khrl6a4h2) :project-file "khr3"
	    :board :armh7 :com-init-method (:arm2-open))
     ;;(:body :l2l6 :head :m5sh :wrist t :project-file "khr3semi" :board :armh7
     ;;:shoulder :y :com-init-method (:arm2-open))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p -1) 
     ;;
     )
    (("khr23semi" "khrt1l6a4h2") ;; 23 servos
     ;;(:file "KHR/khrt1l6a4h2.l" :form (khrt1l6a4h2) :project-file "khr23semi"
     ;;:com-init-method (:arm2-open) :board :armh7)
     (:body :l2l6 :wrist t ;;:project-file "khr3semi" :board :armh7
	    :head :m3deye :3eye-rev 6 ;; :h2s ;; :m5u2s :head :m5sh 
	    :torso t :shoulder :y :com-init-method (:arm2-open)  ;;(:arm-open :pid #x6001)
	    )
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (1 :torso-chest-y -1)
     (22 :head-neck-p 1)
     )
    ("khr23semi-cad" ;; 23 servos
     (:file "KHR/khrt1l6a4h2.l" :form (khrt1l6a4h2) :project-file "khr23semi"
	    :com-init-method (:arm2-open) :board :armh7)
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (1 :torso-chest-y -1)
     (22 :head-neck-p 1)
     )
    (("khr23semi1") ;; 23 servos
     ;;(:file "KHR/khrt1l6a4h2u.l" :form (khrt1l6a4h2u) :project-file "khr23semi"
     ;;:com-init-method (:arm2-open) :board :armh7)
     (:body :l2l6 :head :m5u3sv2 :wrist t :project-file "khr3semi" :board :armh7
	    :torso t :shoulder :y :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (1 :torso-chest-y -1)
     (22 :head-neck-p 1)
     )
    (("khr23semi2") ;; 23 servos
     ;;(:file "KHR/khrt1l6a4h2u2.l" :form (khrt1l6a4h2u2) :project-file "khr23semi"
     ;;:com-init-method (:arm2-open) :board :armh7)
     (:body :l2l6 :head :m5u2s :wrist t :project-file "khr3semi" :board :armh7
	    :torso t :shoulder :y :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (1 :torso-chest-y -1)
     (22 :head-neck-p 1)
     )
    (("khr23semi3") ;; 23 servos
     ;;(:file "KHR/khrt1l6a4h2u3.l" :form (khrt1l6a4h2u3)
     ;;:project-file "khr23semi" :com-init-method (:arm2-open) :board :armh7)
     (:body :l2l6 :head :m5shv2 :wrist t :project-file "khr3semi" :board :armh7
	    :torso t :shoulder :y :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (1 :torso-chest-y -1)
     (22 :head-neck-p 1)
     )
    (("khr23semi4") ;; 23 servos
     ;;(:file "KHR/khrt1l6a4h2v3.l" :form (khrt1l6a4h2v3) :project-file "khr23semi"
     ;;:com-init-method (:arm2-open) :board :armh7)
     (:body :l2l6 :head :m5shv2 :wrist t :project-file "khr3semi" :board :armh7
	    :torso t :shoulder :y :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (1 :torso-chest-y -1)
     (22 :head-neck-p 1)
     )
    (("khr24semis3" ) ;; 24 servos
     ;;(:file "KHR/khrt1l6a4h2.l" :form (khrt1l6a4h2) :project-file "khr23semi"
     ;;:com-init-method (:arm2-open) :board :armh7)
     (:body :l2l6 :head :m5sh :wrist t :project-file "khr3semi" :board :armh7
	    :torso t :shoulder :y :com-init-method (:arm2-open))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (1 :torso-chest-y -1)
     (32 :head-neck-p -1)
     ;;(30 :head-neck-r 1)
     )
    ("khr3omori"
     (:file "KHR/khrt1l6a4h2.l" :form (khrt1l6a4h2) :project-file "khr3omori"
	    :com-init-method (:arm2-open) :board :armh7)
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (1 :torso-chest-y -1)
     (22 :head-neck-p -1) 
     )
    ("khr3"		;; 17 servos
     (:file "KHR/khr.l" :form (khr) :project-file "khr3" :board :armh7)
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     )
    ("khr3rcb4"		;; 17 servos
     (:file "KHR/khr.l" :form (khr) :project-file "khr3"
	    )
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     )
    ("khr3semircb4"		;; 18 servos
     (:file "KHR/khrh2.l" :form (khrh2) :project-file "khr3semi"
	    ;;:com-init-method (:rcb4-open) :board :rcb4)
	    )
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)      (22 :head-neck-p 1)
     )
    ("khr3semi"		;; 18 servos
     ;;(:file "KHR/khrh2.l" :form (khrh2) :project-file "khr3semi"
     (:body :l2l5 :head :m5sh :wrist t
	    :project-file "khr3semi" :board :armh7
	    :com-init-method (:arm-open :pid #x6001)
	    ) ;; same as :arm2-open, pid:#x6015 for Akizuki, :vid #x0403
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)      (22 :head-neck-p 1)
     )
    ("khr3semi-cad"		;; 18 servos
     (;;:file "KHR/khrh2.l" :form (khrh2)
      :project-file "khr3semi"
      ;;:com-init-method (:arm2-open) :board :armh7
      )
     ;;(:body :l2l5 :head :m5sh :wrist t
     ;;:project-file "khr3semi" :board :armh7
     ;;:com-init-method (:arm-open :pid #x6001)
     ;;) ;; same as :arm2-open, pid:#x6015 for Akizuki, :vid #x0403
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)      (22 :head-neck-p 1)
     )
    ("khr3semi1"		;; 18 servos
     (;;:file "KHR/khrh2u.l" :form (khrh2u)
      :project-file "khr3semi"
      ;;:board :armh7 :com-init-method (:arm2-open)
      )
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)  ;;    (22 :head-neck-p 1)
     )
    ("khr3semi2"		;; 18 servos
     ;;(:file "KHR/khrh2u2.l" :form (khrh2u2) :project-file "khr3semi"
     ;;:board :armh7 :com-init-method (:arm2-open))
     (:body :l2l5 :head :m5u2s :wrist t :head-offset #f(0 0 6)
	    :project-file "khr3semi"
	    ;; :board :armh7 :com-init-method (:arm-open :pid #x6001)
	    )
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)      (22 :head-neck-p 1)
     )
    ("khr3semi3"		;; 18 servos
     ;;(:file "KHR/khrh2u3.l" :form (khrh2u3) :project-file "khr3semi"
     (:body :l2l5 :head :m5u3sv2 :wrist t :head-offset #f(0 0 6)
	    :project-file "khr3semi"
	    ;;:board :armh7 :com-init-method (:arm-open :pid #x6001)
	    )
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)      (22 :head-neck-p 1)
     )
    ("khr3semi4"		;; 18 servos
     ;;(:file "KHR/khrh2v3.l" :form (khrh2v3) :project-file "khr3semi" 
     (:body :l2l5 :head :m5shv2 :wrist t :head-offset #f(0 0 6)
	    :project-file "khr3semi"
	    ;; :board :armh7 :com-init-method (:arm-open :pid #x6001)
	    )
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)      (22 :head-neck-p 1)
     )
    ("khr3sl5a3h2"	;; 18
     ( ;;:file "KHR/khrh2.l" :form (khrh2)
      ;;:project-file "khr3semi"
      ;; :com-init-method (:arm2-open) :board :armh7
      :body :l2l5 :head :m5sh
      )
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)      (22 :head-neck-p 1)
     )
    ("khrl5a3h2"	;; 18
     ( ;;:file "KHR/khrh2.l" :form (khrh2)
      :project-file
      "khr3semi"
      ;;:com-init-method (:arm2-open) :board :armh7
      :body :l2l5
      ;;:head :d405echos
      :head :m5sh
      )
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)      (22 :head-neck-p 1)
     )
    ;;
    ("khrl5a3h2g"
     (:body :l2l5 :head :m5sh :gripper t :gripper-straight t
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)
     )
    ("khrl5a3h2wg"
     (:body :l2l5 :head :m5sh :wrist t :gripper t  :gripper-straight t
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)
     )
    ("khrl5a4h2g"
     (:body :l2l5 :head :m5sh :shoulder :y :gripper t  :gripper-straight t
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)
     )
    ("khrl5a4h2wg"
     (:body :l2l5 :head :m5sh :shoulder :y :wrist t :gripper t  :gripper-straight t
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)
     )
    ("khrt1l5a3h2g"
     (:body :l2l5 :head :m5sh :torso t :gripper t :gripper-straight t
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)      (1 :torso-chest-y -1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)
     )
    ("khrt1l5a3h2wg"
     (:body :l2l5 :head :m5sh :torso t :wrist t :gripper t  :gripper-straight t
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)      (1 :torso-chest-y -1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)
     )
    ("khrt1l5a4h2g"
     (:body :l2l5 :head :m5sh :torso t :shoulder :y :gripper t  :gripper-straight t
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)      (1 :torso-chest-y -1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)
     )
    ("khrt1l5a4h2wg"
     (:body :l2l5 :head :m5sh :torso t :shoulder :y :wrist t :gripper t  :gripper-straight t
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)      (1 :torso-chest-y -1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)
     )
    ;;
    ("khrl6a3h2g"
     (:body :l2l6 :head :m5sh :gripper t  :gripper-straight t
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)
     )
    ("khrl6a3h2wg"
     (:body :l2l6 :head :m5sh :wrist t :gripper t  :gripper-straight t
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)
     )
    ("khrl6a4h2g"
     (:body :l2l6 :head :m5sh :shoulder :y :gripper t  :gripper-straight t
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)
     )
    ("khrl6a4h2wg"
     (:body :l2l6 :head :m5sh :shoulder :y :wrist t :gripper t  :gripper-straight t
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)
     )
    ("khrt1l6a3h2g"
     (:body :l2l6 :head :m5sh :torso t :gripper t  :gripper-straight t
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)      (1 :torso-chest-y -1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)
     )
    ("khrt1l6a3h2wg"
     (:body :l2l6 :head :m5sh :torso t :wrist t :gripper t  :gripper-straight t
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)      (1 :torso-chest-y -1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)
     )
    ("khrt1l6a4h2g"
     (:body :l2l6 :head :m5sh :torso t :shoulder :y :gripper t  :gripper-straight t
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)      (1 :torso-chest-y -1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)
     )
    ("khrt1l6a4h2wg"
     (:body :l2l6 :head :m5sh :torso t :shoulder :y :wrist t :gripper t  :gripper-straight t
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)      (1 :torso-chest-y -1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)
     )
    ;;
    ("khranzaifly" ;;17 servos + flight unit
     ;;(:file "KHR/khranzaifly.l" :form (khranzaifly-70mm) :board :armh7 :project-file "khr3" )
     (:body :l2l5 :wrist t :head-offset #f(0 0 6) :wing :70mm :wing-pos #f(-80 0 50)
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     )
    ("khranzaifly-cad" ;;17 servos + flight unit
     (:file "KHR/khranzaifly.l" :form (khranzaifly-70mm)
	    :board :armh7 :project-file "khr3" )
     ;;(:body :l2l5 :wrist t :head-offset #f(0 0 6) :wing :70mm :wing-pos #f(-80 0 50)
     ;;:project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     )
    ("khranzaifly5" ;;17 servos + flight unit
     ;;(:file "KHR/khranzaifly.l" :form (khranzaifly-5inch) :board :armh7 :project-file "khr3")
     (:body :l2l5 :wrist t :wing :5inch :wing-pos #f(-80 0 50)
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     )
    ("khranzaifly5-cad" ;;17 servos + flight unit
     (:file "KHR/khranzaifly.l" :form (khranzaifly-5inch) :board :armh7 :project-file "khr3")
     ;;(:body :l2l5 :wrist t :wing :5inch :wing-pos #f(-80 0 50)
     ;;:project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     )
    ("khrh2fly"		;; 18 servos
     ( :project-file "khr3semi"
		     :file "KHR/khrh2fly.l" :form (khrh2fly)
		     ;;:com-init-method (:arm2-open) :board :armh7
		     )
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)      (22 :head-neck-p 1)
     )
    ("khranzaiflys" ;;17 servos + flight unit
     (:file "KHR/khranzaifly.l" :form (khranzaifly)
	    :board :armh7
	    :project-file "khr3"
	    :sole t
	    :sole-sensor t
	    )
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)

     (44 ("RLEG" "LINK4")) ;; sensor-board 22
     (52 ("LLEG" "LINK4")) ;; sensor-board 26
     )
    ("khrh2ganzaiflys" ;;17 servos + flight unit
     ;;     (:file "KHR/khrh2ganzaifly.l" :form (khrh2ganzaifly-5inch)
     ;;      :board :armh7 :project-file "khr3" :sole t :sole-sensor t )
     (:body :l2l5 :head :m5sh :gripper t :wing :5inch :wing-pos #f(-80 0 50)
	    :project-file "khr3semi" :board :armh7 :com-init-method (:arm-open :pid #x6001))
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)
     (22 :head-neck-p 1)
     (24 :larm-gripper-r 1/2) (25 :rarm-gripper-r 1/2)

     (44 ("RLEG" "LINK4")) ;; sensor-board 22
     (52 ("LLEG" "LINK4")) ;; sensor-board 26
     )

    (("kxrl4dfly")		;; 18
     (:body :l4d :type :l4 :head :d :arm :j4 :leg :j4
	    :wing t :board :armh7 :project-file "kxrl4d" :wing-pos #f(-21.5 0 69))
     (2 :rarm-shoulder-p 1)   (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)  (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)      (7 :larm-elbow-p 1)
     (8 :rarm-wrist-p 1)      (9 :larm-wrist-p 1)

     (10 :rleg-crotch-p 1)    (11 :lleg-crotch-p -1)
     (12 :rleg-crotch-r -1)   (13 :lleg-crotch-r 1)
     (14 :rleg-knee-p -1)     (15 :lleg-knee-p -1)
     (16 :rleg-ankle-p -1)    (17 :lleg-ankle-p -1)

     (1 :head-neck-p -1)
     (19 :head-gripper-p -1/2)
     (19 :head-gripper2-p -1/2)

     (28 :rwing-gimbal0-p 1)   (29 :lwing-gimbal0-p 1)
     (30 :rwing-gimbal0-w 1)   (31 :lwing-gimbal0-w 1)

     )
    (("kxrl6fly")		;; 18
     (:body :l6 :type :l6 :arm :j3 :marm :j3 :leg :j3
	    :project-file "kxrl6"
	    :board :armh7 :wing t :wing-pos #f(0 0 161))
     (2 :rarm-shoulder-y -1)    (3 :larm-shoulder-y -1)
     (4 :rarm-shoulder-p -1)    (5 :larm-shoulder-p -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     (8 :rmarm-shoulder-y -1)   (9 :lmarm-shoulder-y -1)
     (10 :rmarm-shoulder-r -1)  (11 :lmarm-shoulder-r 1)
     (12 :rmarm-elbow-r 1)      (13 :lmarm-elbow-r -1)
     (14 :rleg-crotch-y -1)     (15 :lleg-crotch-y -1)
     (16 :rleg-crotch-p 1)     (17 :lleg-crotch-p  1)
     (18 :rleg-knee-p -1)       (19 :lleg-knee-p -1)

     (28 :rwing-gimbal0-p 1)   (29 :lwing-gimbal0-p 1)
     (30 :rwing-gimbal0-w 1)   (31 :lwing-gimbal0-w 1)

     )
    #|
    ("abc"	;; 18
    ()
    (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
    (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
    (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
    (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
    (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
    (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
    (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
    (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
    (0 :head-neck-y -1)      (22 :head-neck-p 1)
    )
    |#
    ("kxrl2l7a7"
     (:body :l2l6w :type :l2 :shoulder :cross :wrist :yw-cross
	    :board :armh7
	    :project-file "kxrl2l6a7h2w"
	    :gripper-inner t :ankle :y :sole t  :head :h2s :head-length 20)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     
     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (32 :rleg-ankle-y -1)      (33 :lleg-ankle-y -1)

     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-p 1)       (31 :larm-wrist-p 1)
     (0 :head-neck-p 1)      (1 :head-neck-y -1)
     )
    ("kxrl2l7a7w"
     (:body :l2l6w :type :l2 :shoulder :cross :wrist :yw-cross
	    :board :armh7
	    :project-file "kxrl2l6a7h2w"
	    :gripper-inner t :ankle :y :sole :w  :head :h2s :head-length 20)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     
     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)
     (32 :rleg-ankle-y -1)      (33 :lleg-ankle-y -1)
     
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-p 1)       (31 :larm-wrist-p 1)
     (0 :head-neck-p 1)      (1 :head-neck-y -1)
     )
    (("kxr_uav");; 36
     (:file "robot_assembler/kxr_uav_fullbody.l" :form (kxr_uav_fullbody)
	    ;;:project-file "kxrl2w2l6a7h2w"
	    :board :armh7
	    )
     #|
     (:body :dyp :type :l2 :active-wheel :knee
     :shoulder :y-p-r :wrist :r :passive-wheel :wrist
     :wrist-sensor t  :gripper-inner t :gripper-sensor :finger1 :sole t
     :sole-sensor t :torso :dy-p :neck-axis :p :head :h2s :head-length 20)
     |#
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-p 1)       (31 :larm-wrist-p 1)
     (0 :head-neck-p 1)      (1 :head-neck-y -1)
     ;;
     )
    (("kxr_uav_tilt");; 36
     (:file "robot_assembler/kxr_uav_fullbody_tilt.l" :form (kxr_uav_fullbody)
	    :board :armh7
	    ;;:project-file "kxrl2w2l6a7h2w"
	    )
     #|
     (:body :dyp :type :l2 :active-wheel :knee
     :shoulder :y-p-r :wrist :r :passive-wheel :wrist
     :wrist-sensor t  :gripper-inner t :gripper-sensor :finger1 :sole t
     :sole-sensor t :torso :dy-p :neck-axis :p :head :m5s :head-length 20)
     |#
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     ;;     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     ;;     (20 :rleg-foot-w 1)        (21 :lleg-foot-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     (26 :rtilt-w 1)       (27 :ltilt-w  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-p 1)       (31 :larm-wrist-p 1)
     (32 :rtilt-p 1)    (33 :ltilt-p 1)
     (34 :rtilt-r 1)    (35 :ltilt-r 1)
     (0 :head-neck-p 1)      (1 :head-neck-y -1)
     ;;
     )
    (("kxr_uav_fin");; 36
     (:file "robot_assembler/kxr_uav_fullbody_fin.l" :form (kxr_uav_fullbody_fin)
	    :board :armh7
	    )
     
     (2 :rarm-shoulder-p -1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)       (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p 1)      (15 :lleg-ankle-p 1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w -1)        (21 :lleg-ankle-w -1)
     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y -1)      (25 :lleg-crotch-y -1)

     (26 :rarm-elbow-y -1)    (27 :larm-elbow-y -1)
     
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-p 1)       (31 :larm-wrist-p 1)
     (0 :head-neck-p -1)      (32 :head-neck-y -1)
     ;;
     )
    (("kxr_uav_fin_nobackpack");; 36
     (:file "robot_assembler/kxr_uav_fullbody_fin_nobackpack.l" :form (kxr_uav_fullbody_fin_nobackpack)
	    :board :armh7
	    )
     
     (2 :rarm-shoulder-p -1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)       (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p 1)      (15 :lleg-ankle-p 1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     (20 :rleg-ankle-w -1)        (21 :lleg-ankle-w -1)
     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     (24 :rleg-crotch-y -1)      (25 :lleg-crotch-y -1)

     (26 :rarm-elbow-y -1)    (27 :larm-elbow-y -1)
     
     (28 :rarm-wrist-r -1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-p 1)       (31 :larm-wrist-p 1)
     (0 :head-neck-p -1)      (32 :head-neck-y -1)
     ;;
     )
    (("kxr_uav_fin_device");; 36
     (:file "robot_assembler/kxr_uav_fullbody_fin_device.l" :form (kxr_uav_fullbody_fin_device)
	    :board :armh7
	    )
     
     (2 :rarm-shoulder-p -1)  
     (4 :rarm-shoulder-r -1)  
     (6 :rarm-elbow-p 1)      
     
     (8 :rleg-crotch-r 1)     
     (10 :rleg-crotch-p -1)   
     (12 :rleg-knee-p 1)       
     (14 :rleg-ankle-p 1)      
     (16 :rleg-ankle-r -1)     

     (18 :rarm-gripper-r -1/2) 
     (18 :rarm-gripper2-r 1/2) 
     (20 :rleg-ankle-w -1)     
     (22 :rarm-shoulder-y 1)  
     (24 :rleg-crotch-y -1)   

     (26 :rarm-elbow-y -1)    
     
     (28 :rarm-wrist-r -1)    
     (30 :rarm-wrist-p 1)     
     (0 :head-neck-p -1)      (32 :head-neck-y -1)
     ;;
     )
    (("kxr_uav2");; 36
     (:body :l2l6w :type :l2
	    :wing t
	    :board :armh7
	    :shoulder :cross :wrist :y-cross
	    :gripper-inner t :gripper-sensor ((:finger1 . :rev-c))
	    :sole t :sole-sensor t
	    :head :h2s :head-length 20)
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r -1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r -1)      (9 :lleg-crotch-r -1)
     (10 :rleg-crotch-p -3/2)   (11 :lleg-crotch-p 3/2)
     (12 :rleg-knee-p -1)       (13 :lleg-knee-p -1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     ;;     (18 :rarm-gripper2-r -1/2)   (19 :larm-gripper2-r -1/2)
     ;;     (20 :rleg-foot-w 1)        (21 :lleg-foot-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     (24 :rleg-crotch-y 1)      (25 :lleg-crotch-y 1)

     ;;(26 :rtilt-w 1)       (27 :ltilt-w  1)
     (28 :rarm-wrist-r 1)       (29 :larm-wrist-r -1)
     (30 :rarm-wrist-p 1)       (31 :larm-wrist-p 1)
     ;;     (32 :rtilt-p 1)    (33 :ltilt-p 1)
     ;;     (34 :rtilt-r 1)    (35 :ltilt-r 1)
     (0 :head-neck-p 1)      (1 :head-neck-y -1)
     ;;

     )
    (("kxr_auv");; 22
     (:file "robot_assembler/kxr_auv_fullbody_initial.l" :form (kxr_auv_fullbody_initial)
	    :board :armh7
	    ;;:project-file "kxrl2w2l6a7h2w"
	    )
     (2 :rarm-shoulder-p -1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)       (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p 1)      (15 :lleg-ankle-p 1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     ;;     (20 :rleg-foot-w 1)        (21 :lleg-foot-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)
     
     (0 :head-neck-p -1)      (32 :head-neck-y -1)
     )
    ;;
    (("kxr_auvrev2");; 22
     (:body :l2l5 :type :l2 :shoulder :p-r-yr
	    :board :armh7
	    :project-file "kxrl2l5a4h2g"
	    :backpack-function kxr-auv-back-pack
	    :gripper-inner t
	    :gripper-sensor nil
	    :wrist-sensor t
	    :ankle-sensor t
	    :head :h2-auv :neck-jf :a :sole t) ;; 24
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)       (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     ;;     (20 :rleg-foot-w 1)        (21 :lleg-foot-w -1)
     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     
     (0 :head-neck-p -1)      (32 :head-neck-y -1)

     ;; outer
     (50 larm-gripper2-r-KJS-03) ;; sensor-board 25
     (42 rarm-gripper2-r-KJS-03) ;; sensor-board 21
     ;; inner
     (48 larm-gripper-r-KJS-03) ;; sensor-board 24
     (40 rarm-gripper-r-KJS-03) ;; sensor-board 20
     ;;
     (38 rarm-elbow-p-KJS-03) ;; sensor-board 19
     (46 larm-elbow-p-KJS-03) ;; sensor-board 23
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (52 lleg-ankle-r-KJS-03) ;; sensor-board 26

     ;; ;; outer
     ;; (50 ("larm-elbow" "gripper2-" "KJS")) ;; sensor-board 25
     ;; (42 ("rarm-elbow" "gripper2-" "KJS")) ;; sensor-board 21
     ;; ;; inner
     ;; (48 ("larm-elbow" "gripper-" "KJS")) ;; sensor-board 24
     ;; (40 ("rarm-elbow" "gripper-" "KJS")) ;; sensor-board 20
     ;; ;;
     ;; (38 ("rarm-elbow" "s33" "KJS")) ;; sensor-board 19
     ;; (46 ("larm-elbow" "s33" "KJS")) ;; sensor-board 23
     ;; ;;
     ;; (44 ("rleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    (("kxr_auvrev2nofloat");; 22
     (:body :l2l5 :type :l2 :shoulder :p-r-yr
	    :board :armh7
	    :project-file "kxr_auvrev2"
	    :backpack-function kxr-auv-back-pack-nofloat
	    :gripper-inner t
	    :wrist-inner t
	    :gripper-sensor nil
	    :wrist-sensor t
	    :ankle-sensor t
	    :head :h2-auv :neck-jf :a :sole t) ;; 24
     (2 :rarm-shoulder-p 1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r -1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p -1)
     
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)       (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p -1)      (15 :lleg-ankle-p -1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)
     
     (18 :rarm-gripper-r 1/2)    (19 :larm-gripper-r 1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     ;;     (20 :rleg-foot-w 1)        (21 :lleg-foot-w -1)
     (22 :rarm-shoulder-y 1)   (23 :larm-shoulder-y 1)
     
     (0 :head-neck-p -1)      (32 :head-neck-y -1)

     ;; outer
     (50 larm-gripper2-r-KJS-03) ;; sensor-board 25
     (42 rarm-gripper2-r-KJS-03) ;; sensor-board 21
     ;; inner
     (48 larm-gripper-r-KJS-03) ;; sensor-board 24
     (40 rarm-gripper-r-KJS-03) ;; sensor-board 20
     ;;
     (38 rarm-elbow-p-KJS-03) ;; sensor-board 19
     (46 larm-elbow-p-KJS-03) ;; sensor-board 23
     (44 rleg-ankle-r-KJS-03) ;; sensor-board 22
     (52 lleg-ankle-r-KJS-03) ;; sensor-board 26

     ;; ;; outer
     ;; (50 ("larm-elbow" "gripper2-" "KJS")) ;; sensor-board 25
     ;; (42 ("rarm-elbow" "gripper2-" "KJS")) ;; sensor-board 21
     ;; ;; inner
     ;; (48 ("larm-elbow" "gripper-" "KJS")) ;; sensor-board 24
     ;; (40 ("rarm-elbow" "gripper-" "KJS")) ;; sensor-board 20
     ;; ;;
     ;; (38 ("rarm-elbow" "s33" "KJS")) ;; sensor-board 19
     ;; (46 ("larm-elbow" "s33" "KJS")) ;; sensor-board 23
     ;; ;;
     ;; (44 ("rleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 22
     ;; (52 ("lleg-ankle-p" "ankle-r" "KJS")) ;; sensor-board 26
     )
    (("kxr_amv")
     (:body :l2l5 :type :l2 :shoulder :p-r-yr
	    :board :armh7
	    :project-file "kxrl2l5a4h2g"
	    :backpack-function kxr-auv-back-pack
	    :gripper-inner t
	    :head :h2-auv :neck-jf :a :sole t) ;; 24
     (2 :rarm-shoulder-p -1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)       (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p 1)      (15 :lleg-ankle-p 1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     ;;     (20 :rleg-foot-w 1)        (21 :lleg-foot-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)

     (33 :head-neck-p -1)      (32 :head-neck-y -1)
     ;;
     )
    (("kxr_amv2")
     (:body :l2l5 :type :l2 :shoulder :p-r-yr
	    :project-file "kxrl2l5a4h2g"
	    :backpack-function kxr-auv-back-pack
	    :gripper-inner t
	    :head :h2s :neck-jf :a :sole t) ;; 24
     (2 :rarm-shoulder-p -1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)       (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p 1)      (15 :lleg-ankle-p 1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     ;;     (20 :rleg-foot-w 1)        (21 :lleg-foot-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)

     (33 :head-neck-p -1)      (32 :head-neck-y -1)
     ;;
     )
    (("kxr_amv3")
     (:body :l2l5 :type :l2 :shoulder :p-r-yr
	    :project-file "kxrl2l5a4h2g"
	    :backpack-function kxr-auv-back-pack
	    :gripper-inner t
	    :head :h2s :neck :y-p-r ;; :h3s 
	    :neck-jf :a :sole t) ;; 24
     (2 :rarm-shoulder-p -1)     (3 :larm-shoulder-p -1)
     (4 :rarm-shoulder-r 1)    (5 :larm-shoulder-r 1)
     (6 :rarm-elbow-p 1)        (7 :larm-elbow-p 1)
     
     (8 :rleg-crotch-r 1)      (9 :lleg-crotch-r 1)
     (10 :rleg-crotch-p -1)   (11 :lleg-crotch-p -1)
     (12 :rleg-knee-p 1)       (13 :lleg-knee-p 1)
     (14 :rleg-ankle-p 1)      (15 :lleg-ankle-p 1)
     (16 :rleg-ankle-r -1)      (17 :lleg-ankle-r -1)

     (18 :rarm-gripper-r -1/2)    (19 :larm-gripper-r -1/2)
     (18 :rarm-gripper2-r 1/2)   (19 :larm-gripper2-r 1/2)
     ;;     (20 :rleg-foot-w 1)        (21 :lleg-foot-w -1)
     (22 :rarm-shoulder-y -1)   (23 :larm-shoulder-y -1)

     (33 :head-neck-p -1)      (32 :head-neck-y -1)
     ;;
     )
    (("kxrhandw1f4");; 5
     (:body :dyp-zf :type :l2 :active-wheel :knee
    	    :shoulder :y-p-r :wrist :r :passive-wheel :wrist :board :armh7
    	    :board :armh7
    	    :wrist-sensor t
    	    :gripper-inner t
    	    :sole t
    	    :project-file "kxrhandw1f4"
    	    :ankle-sensor t   ;;:sole-sensor t
    	    :torso :y-p-y   ;; :torso :ly-p  :torso :dy-p     ;; :dy-p3
    	    :neck-axis :p :head :m5us :head-length 26)

     ;; (:file "robot_assembler/kxrhandw1f4.l" :form (kxrhandw1f4)
     ;; 	    :project-file "kxrhandw1f4"
     ;; 	    :board :armh7
     ;; 	    );;todo:change

     (0 :rarm-wrist-r -1)
     (2 :rarm-gripper-r -1)
     (4 :rleg-crotch-r -1)
     (6 :larm-gripper-r -1)
     (8 :lleg-crotch-r -1)

     ;; (0 :hand-wrist-r 1)
     ;; (2 :hand-rfinger1-y 1)
     ;; (4 :hand-rfinger2-y 1)
     ;; (6 :hand-lfinger1-y 1)
     ;; (8 :hand-lfinger2-y 1)

     ;; (38 ("hand-wrist" "gripper-" "sensor")) ;; sensor-board 19
     ;; (40 ("hand-palm" "gripper-" "sensor")) ;; sensor-board 20
     ;; (42 ("hand-rfinger2" "gripper-" "sensor")) ;; sensor-board 21
     ;; (44 ("hand-lfinger2" "gripper-" "sensor")) ;; sensor-board 22

     )
    (("kxrdrill");; 5
     (:body :dyp-zf :type :l2 :active-wheel :knee
    	    :shoulder :y-p-r :wrist :r :passive-wheel :wrist :board :armh7
    	    :board :armh7
    	    :wrist-sensor t
    	    :gripper-inner t
    	    :sole t
    	    :project-file "kxrhandw1f4"
    	    :ankle-sensor t   ;;:sole-sensor t
    	    :torso :y-p-y   ;; :torso :ly-p  :torso :dy-p     ;; :dy-p3
    	    :neck-axis :p :head :m5us :head-length 26)

     ;; (:file "robot_assembler/kxrdrill.l" :form (kxrdrill)
     ;; 	    :project-file "kxrhandw1f4"
     ;; 	    :board :armh7
     ;; 	    );;todo:change
     
     (0 :rarm-wrist-r -1)

     ;; (0 :hand-wrist-r 1)

     ;; (38 ("hand-wrist" "gripper-" "sensor")) ;; sensor-board 19
     
     )
    (("kxrmamoru")
     (:body :l4m :type :l4 :marm :r :arm :j3w :leg :j3w :head :h3
	    :board :armh7
	    )
     (14 :head-neck-y -1)      (16 :head-neck-p -1)
     (18 :head-neck-r -1)
     (20 :head-reye-y 1)     (22 :head-leye-y 1)
     (1 :rmarm-shoulder-r -1)  (0 :lmarm-shoulder-r 1)
     (3 :rarm-shoulder-y 1)  (2 :larm-shoulder-y 1)
     (5 :rarm-shoulder-p -1)  (4 :larm-shoulder-p 1)
     (7 :rarm-elbow-w -1)    (6 :larm-elbow-w 1)
     (9 :rleg-crotch-y 1)    (8 :lleg-crotch-y 1)
     (11 :rleg-crotch-p -1)    (10 :lleg-crotch-p 1)
     (13 :rleg-knee-w -1)     (12 :lleg-knee-w 1)
     )

    (("kxrmamoru-new")
     (:body :l4m2 :type :l4 :marm :r3 :arm :j3w :leg :j3w :head :h3-new
	    :board :armh7
	    )
     (14 :head-neck-y -1)      (16 :head-neck-p -1)
     (18 :head-neck-r -1)
     (20 :head-reye-y 1)     (22 :head-leye-y 1)
     (1 :rmarm-elbow-w -1)  (0 :lmarm-elbow-w 1)
     (25 :rmarm-shoulder-p 1)  (24 :lmarm-shoulder-p -1)
     (27 :rmarm-shoulder-y -1)  (26 :lmarm-shoulder-y 1)
     (3 :rarm-shoulder-y 1)  (2 :larm-shoulder-y 1)
     (5 :rarm-shoulder-p -1)  (4 :larm-shoulder-p 1)
     (7 :rarm-elbow-w -1)    (6 :larm-elbow-w 1)
     (9 :rleg-crotch-y 1)    (8 :lleg-crotch-y 1)
     (11 :rleg-crotch-p -1)    (10 :lleg-crotch-p 1)
     (13 :rleg-knee-w -1)     (12 :lleg-knee-w 1)
     )

    (("kxrmamoru-2022")
     (:body :l4m3 :type :l4 :marm :r3 :arm :j3w :leg :j3w :head :h3-new
	    :board :armh7
	    )
     (14 :head-neck-y -1)      (16 :head-neck-p -1)
     (18 :head-neck-r -1)
     (20 :head-reye-y 1)     (22 :head-leye-y 1)
     (0 :rmarm-elbow-w -1)  (1 :lmarm-elbow-w 1)
     (24 :rmarm-shoulder-p 1)  (25 :lmarm-shoulder-p -1)
     (26 :rmarm-shoulder-y -1)  (27 :lmarm-shoulder-y 1)
     (2 :rarm-shoulder-y 1)  (3 :larm-shoulder-y 1)
     (4 :rarm-shoulder-p -1)  (5 :larm-shoulder-p 1)
     (6 :rarm-elbow-w -1)    (7 :larm-elbow-w 1)
     (9 :rleg-crotch-y 1)    (8 :lleg-crotch-y 1)
     (11 :rleg-crotch-p -1)    (10 :lleg-crotch-p 1)
     (13 :rleg-knee-w -1)     (12 :lleg-knee-w 1)
     )

    (("khr23oh") ;; 23 servos
     ;;(:file "KHR/khrt1l6a4h2.l" :form (khrt1l6a4h2) :project-file "khr23oh"
     (:body :l2l6 :head :m5sh :wrist t :project-file "khr3oh"
	    :torso t :shoulder :y
	    )
     (2 :larm-shoulder-p -1)  (3 :rarm-shoulder-p 1)
     (4 :larm-shoulder-r 1)   (5 :rarm-shoulder-r 1)
     (6 :larm-shoulder-y 1)   (7 :rarm-shoulder-y 1)
     (8 :larm-elbow-p 1)      (9 :rarm-elbow-p -1)
     (10 :lleg-crotch-y 1)    (11 :rleg-crotch-y 1)
     (12 :lleg-crotch-r 1)    (13 :rleg-crotch-r 1)
     (14 :lleg-crotch-p -1)   (15 :rleg-crotch-p 1)
     (16 :lleg-knee-p 1)      (17 :rleg-knee-p -1)
     (18 :lleg-ankle-p 1)     (19 :rleg-ankle-p -1)
     (20 :lleg-ankle-r -1)    (21 :rleg-ankle-r -1)
     (0 :head-neck-y -1)     (1 :torso-chest-y -1)
     (22 :head-neck-p -1)
     )
    (("attachable_arm");;6
     (:file "catkin_ws_src/kxr_pkgs/kxr_models/euslisp/attachable_arm.l";;set eus model
	    :form (progn (load "additional-settings.l") (attachable_arm));;set function name in eusmodel.l
	    :board :armh7
	    )
     ;;connect chain to J2, J3, J4
     (0 :rarm-shoulder-w 1);;KRS-3304R2, ID 0, 1.25Mbps
     (2 :rarm-elbow-w 1);;KRS-3304R2, ID:1, 1.25Mbps
     (4 :rarm-wrist-w 1);;KRS-3304R2, ID:2, 1.25Mbps
     (6 :rarm-wrist-y -1 -90);;ID:3, 1.25Mbps
     (8 :rarm-wrist-r -1);;ID:4, 1.25Mbps
     (26 :rarm-gripper-r -1/2);;ID:13, 1.25Mbps
     (26 :rarm-gripper2-r -1/2);;
     
     ;;
     ;; (38 rarm-shoulder-w-KJS-03) ;; sensor-board ID:19 1.25Mbps
     ;; (40 rarm-elbow-w-KJS-03) ;; sensor-board ID:20 1.25Mbps
     ;; (42 rarm-wrist-w-KJS-03) ;; sensor-board ID:21 1.25Mbps
     )
    (("single-worm");;1
     (:file "catkin_ws_src/kxr_pkgs/kxr_models/euslisp/single-worm.l";;set eus model
	    :form (progn (load "additional-settings.l") (single-worm));;set function name in eusmodel.l
	    :board :armh7
	    )
     ;;connect chain to J2, J3, J4
     (32 :output-w 1 0 sr 38 9918);;worm setting, (servo-id, joint-name, sign, offset, servo-type, sensor-id, magenc-offset)
     ;;
     (38 single-worm-KJS-03) ;; sensor-board ID:19 1.25Mbps
     )
    (("single-worm-kondoh7");;1
     (:file "catkin_ws_src/kxr_pkgs/kxr_models/euslisp/single-worm-kondoh7.l";;set eus model
	    :form (progn (load "additional-settings.l") (single-worm-kondoh7));;set function name in eusmodel.l
	    :board :armh7
	    )
     ;;connect chain to J2, J3, J4
     (32 :output-w 1 0 sr 38 9918);;worm setting, (servo-id, joint-name, sign, offset, servo-type, sensor-id, magenc-offset)
     ;;
     (38 single-worm-KJS-03) ;; sensor-board ID:19 1.25Mbps
     )
    (("single-worm-kondoh7-2");;1
     (:file "catkin_ws_src/kxr_pkgs/kxr_models/euslisp/single-worm-kondoh7-2.l";;set eus model
	    :form (progn (load "additional-settings.l") (single-worm-kondoh7-2));;set function name in eusmodel.l
	    :board :armh7
	    )
     ;;connect chain to J2, J3, J4
     (32 :output-w 1 0 sr 38 9918);;worm setting, (servo-id, joint-name, sign, offset, servo-type, sensor-id, magenc-offset)
     ;;
     (38 single-worm-KJS-03) ;; sensor-board ID:19 1.25Mbps
     )
    (("worm_and_servo_kondoh7_sample");;1
     (:file "models/worm_and_servo_kondoh7_sample.l";;set eus model
	    :form (progn (load "additional-settings.l") (worm_and_servo_kondoh7_sample));;set function name in eusmodel.l
	    :board :armh7
	    )
     ;;connect chain to J2, J3, J4
     (0 :rarm-shoulder-y 1 0 s1);;worm setting, (servo-id, joint-name, sign, offset, servo-type, sensor-id, magenc-offset)
     (32 :rarm-shoulder-p 1 0 sr 38 9918);;worm setting, (servo-id, joint-name, sign, offset, servo-type, sensor-id, magenc-offset)
     ;;
     (38 output-y-KJS-03) ;; sensor-board ID:19 1.25Mbps
     )
    (("single-worm-pitch");;1
     (:file "catkin_ws_src/kxr_pkgs/kxr_models/euslisp/single-worm-pitch.l";;set eus model
	    :form (progn (load "additional-settings.l") (single-worm-pitch));;set function name in eusmodel.l
	    :board :armh7
	    )
     ;;connect chain to J2, J3, J4
     (32 :output-p 1 0 sr 38 9918);;KRS-3304R2, ID 16, 1.25Mbps
     ;;
     (38 single-worm-KJS-03) ;; sensor-board ID:19 1.25Mbps
     )
    ;;
    (("la5")
     (:body :mag+7 :type :module :noleg t :limb :larm :arm :a5
	    :upper-arm-length 38 :elbow-p-sensor :mag-7 :wrist-sensor :mag-7
	    )
     (5 :larm-shoulder-r 1)
     (7 :larm-elbow-p 1)
     (23 :larm-shoulder-y 1)
     (27 :larm-wrist-p -1)
     (29 :larm-wrist-r -1)
     (45 larm-wrist-r-KJS-03)
     )
    (("ra5")
     (:body :mag+7 :type :module :noleg t :limb :rarm :arm :a5
	    :upper-arm-length 38 :elbow-p-sensor :mag-7 :wrist-sensor :mag-7
	    )
     (4 :rarm-shoulder-r 1)
     (6 :rarm-elbow-p 1)   
     (22 :rarm-shoulder-y 1)
     (26 :rarm-wrist-p 1)   
     (28 :rarm-wrist-r -1)  
     (44 rarm-wrist-r-KJS-03)
     )
    (("d405")
     (:body :mag+7 :type :module :noarm t :noleg t
	    :head :d405 :3eye-front t :head-length 20
	    )
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    (("d405cam")
     (:body :mag+7 :type :module :noarm t :noleg t
	    :head :d405cam :3eye-front t :head-length 20
	    )
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    (("d405echos")
     (:body :mag+7 :type :module :noarm t :noleg t
	    :head :d405echos :3eye-front t :head-length 20
	    )
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    (("d405eyes")
     (:body :mag+7 :type :module :noarm t :noleg t
	    :head :d405eyes :3eye-front t :head-length 20
	    )
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    (("h2d405cam")
     (:body :mag+7 :type :module :noarm t :noleg t
	    :head :d405cam :3eye-front t :head-length 20
	    )
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    (("h2d405echos")
     (:body :mag+7 :type :module :noarm t :noleg t
	    :head :d405echos :3eye-front t :head-length 20
	    )
     (32 :head-neck-y -1)       (34 :head-neck-p -1)
     )
    ;; gripper modules
    (("lg1")
     (:body :mag+7 :type :module :noleg t :arm :g1 :limb :larm :gripper t)
     (19 :larm-gripper-r 1/2) (19 :larm-gripper2-r 1/2))
    (("rg1")
     (:body :mag+7 :type :module :noleg t :arm :g1 :limb :rarm :gripper t)
     (18 :rarm-gripper-r 1/2) (18 :rarm-gripper2-r 1/2))
    (("lg1i")
     (:body :mag+7 :type :module :noleg t :arm :g1 :limb :larm :gripper t :gripper-inner t)
     (19 :larm-gripper-r 1/2) (19 :larm-gripper2-r 1/2))
    (("rg1i")
     (:body :mag+7 :type :module :noleg t :arm :g1 :limb :rarm :gripper t :gripper-inner t)
     (18 :rarm-gripper-r 1/2) (18 :rarm-gripper2-r 1/2))
    (("lg1s")
     (:body :mag+7 :type :module :noleg t :arm :g1 :limb :larm :gripper t :gripper-straight t)
     (19 :larm-gripper-r 1/2) (19 :larm-gripper2-r 1/2))
    (("rg1s")
     (:body :mag+7 :type :module :noleg t :arm :g1 :limb :rarm :gripper t :gripper-straight t)
     (18 :rarm-gripper-r 1/2) (18 :rarm-gripper2-r 1/2))
    (("rg1sz")
     (:body :mag+7 :type :module :noleg t :arm :g1 :limb :rarm
	    :gripper t :gripper-straight t :gripper-axis :z)
     (18 :rarm-gripper-r 1/2) (18 :rarm-gripper2-r 1/2))
    (("lg1sx")
     (:body :mag+7 :type :module :noleg t :arm :g1 :limb :larm
	    :gripper t :gripper-straight t :gripper-axis :y)
     (19 :larm-gripper-r 1/2) (19 :larm-gripper2-r 1/2))
    (("rg1sx")
     (:body :mag+7 :type :module :noleg t :arm :g1 :limb :rarm
	    :gripper t :gripper-straight t :gripper-axis :y)
     (18 :rarm-gripper-r 1/2) (18 :rarm-gripper2-r 1/2))
    ("worm_movebase_module"
     ;; (:file "catkin_ws_src/kxr_pkgs/kxr_models/euslisp/worm_movebase_module.l"
     (:file "models/worm_movebase_module.l"
	    :form (progn (load "additional-settings.l") (worm_movebase_module))
	    :board :armh7
	    )
     (0 :torso-fr-w 1 0 s4)      (21 :torso-fl-w -1 0 s4)
     (20 :torso-br-w 1 0 s4)       (1 :torso-bl-w -1 0 s4)
     (30 :torso-chest-p -1 0 sr 54 7553);;SIO1
     (33 :torso-waist-p -1 0 sr 55 9000);;SIO2
     (35 :torso-waist2-r 1 0 s2);;SIO2
     (48 rarm-cp0-KJS-03 "rarm-cp0");;24
     (49 larm-cp0-KJS-03 "larm-cp0");;24
     (54 torso-cp0torso-chest-PC-p-KJS-03);;27
     (55 torso-cp0torso-waist-PC-p-KJS-03);;27
     )
    )
  ) ;; end of (defparameter *kxr-body-config-alist* ..)

(defun config-type? (x type)
  (let* ((mparam (cadr x))
	 (alist (plist-to-alist mparam))
	 (typ (assoc :type alist)))
    (and typ (eq (cadr typ) type))))

(defun robotset-module-type? (x) (config-type? x :module))
(defun robotset-robot-type? (x)
  (let* ((mparam (cadr x))
	 (alist (plist-to-alist mparam))
	 (typ (assoc :robotset alist)))
    typ))

(defun khr-robot? (x) (name-head-robot? x "khr"))
(defun kxr-robot? (x) (name-head-robot? x "kxr"))
(defun name-head-robot? (x &optional (head "khr"))
  (let* ((names (car x)))
    (if (atom names) (setq names (list names)))
    (some #'(lambda (x) (substringp head x)) names)))

(setq *khr-robots* (remove-if-not #'khr-robot? *kxr-body-config-alist*))
(setq *kxr-robots* (remove-if-not #'kxr-robot? *kxr-body-config-alist*))

(setq *kxr-robotset-robots*
      (remove-if-not #'robotset-robot-type? *kxr-body-config-alist*))
(setq *kxr-robotset-modules*
      (remove-if-not #'robotset-module-type? *kxr-body-config-alist*))

(defun get-duplicates (seq &key (test #'equal) (key #'identity) (out #'identity) &aux v)
  (cond
    ((null seq) nil)
    ((setq v (member (funcall key (car seq)) (cdr seq) :test test :key key))
     (cons (list (funcall out (car seq)) (funcall out (car v)))
	   (get-duplicates (cdr seq) :test test :key key :out out)))
    (t (get-duplicates (cdr seq) :test test :key key :out out)))
  )

(defun check-duplicated-names (&optional (alist *kxr-body-config-alist*))
  (when
      (setq alist (get-duplicates (flatten (mapcar #'car alist))))
    (format-if-needed ";; Alarm!! duplicated robot names =~A~%" alist))
  )

(defun same-model-params (&optional (alist *kxr-body-config-alist*))
  (get-duplicates alist :test #'alist-equal
		  :key #'(lambda (x) (plist-to-alist (cadr x)))
		  ;; :out #'(lambda (x) (list (car x) (cadr x)))
		  )
  )
(defun check-same-model-params (&optional (alist *kxr-body-config-alist*))
  (when (setq alist (same-model-params alist))
    (format-if-needed ";; -- Alarm!! duplicated robot model params of *kxr-body-config-alist* in rcb4robotconfig.l: ----~%")
    (mapc #'(lambda (x) (format-if-needed "~A = ~A : ~A~%"
				(caar x) (car (cadr x))
				(cadr (car x))))
	  alist)
    (format-if-needed ";; -- end of Alarm!! ----------------------------------------------------------------------------~%")
    ))

(defun samples8 nil
  (make-kxr-robot "kxrroboset5g" :model nil)
  (send *ri* :robot :detach "kxrlleg5f")
  (send *ri* :robot :detach "kxrrleg5f")
  (send *ri* :robot :attach "kxrlleg1y" :lleg)
  (send *ri* :robot :attach "kxrrleg1y" :rleg)
  (send *ri* :robot :attach "kxrlleg5f" "kxrlleg1y")
  (send *ri* :robot :attach "kxrrleg5f" "kxrrleg1y")
  )

(defun samples7 nil
  (make-kxr-robot "kxrroboset" :model nil)
  (send *ri* :robot :detach "kxrlleg1y")
  (send *ri* :robot :detach "kxrrleg1y")
  (send *ri* :robot :attach "kxrlleg5f" :lleg)
  (send *ri* :robot :attach "kxrrleg5f" :rleg)
  )

(defun samples6 nil
  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2body" :model nil :viewer t))
  (send *robot* :attach "kxrlleg1y" :lleg)
  (send *robot* :attach "kxrrleg1y" :rleg)
  (send *robot* :attach "kxrlleg1r" "kxrlleg1y")
  (send *robot* :attach "kxrrleg1r" "kxrrleg1y")
  (send *robot* :attach "kxrlleg5f" "kxrlleg1r")
  (send *robot* :attach "kxrrleg5f" "kxrrleg1r")
  (send *robot* :detach "kxrlleg1r")
  (send *robot* :detach "kxrrleg1r")
  (send *robot* :attach "kxrlleg5f" "kxrlleg1y")
  (send *robot* :attach "kxrrleg5f" "kxrrleg1y")
  (objects (list *robot*))
  ;;(load "bvh/vault-demo.l")
  ;;(animate)
  )

(defun samples5 nil
  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1y" :lleg)
  (send *robot* :attach "kxrrleg1y" :rleg)
  (send *robot* :attach "kxrlleg1r" :lleg)
  (send *robot* :attach "kxrrleg1r" :rleg)
  (send *robot* :attach "kxrlleg5f" :lleg)
  (send *robot* :attach "kxrrleg5f" :rleg)
  (send *robot* :detach "kxrlleg1y")
  (send *robot* :detach "kxrrleg1y")
  (send *robot* :attach "kxrlleg5f" :lleg)
  (send *robot* :attach "kxrrleg5f" :rleg)
  (objects (list *robot*))
  (load "bvh/vault-demo.l")
  (animate)
  )

(defun samples4old nil
  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1y" :lleg)
  (send *robot* :attach "kxrrleg1y" :rleg)
  (send *robot* :attach "kxrlleg1r" "kxrlleg1y")
  (send *robot* :attach "kxrrleg1r" "kxrrleg1y")
  (send *robot* :attach "kxrlleg5f" "kxrlleg1r")
  (send *robot* :attach "kxrrleg5f" "kxrrleg1r")
  (send *robot* :detach "kxrlleg1y")
  (send *robot* :attach "kxrlleg1r" :lleg)
  (send *robot* :attach "kxrlleg5f" "kxrlleg1r")
  (objects (list *robot*))
  )

(defun samples4 nil
  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1y" :lleg)
  (send *robot* :attach "kxrrleg1y" :rleg)
  (send *robot* :attach "kxrlleg1r" :lleg)
  (send *robot* :attach "kxrrleg1r" :rleg)
  (send *robot* :attach "kxrlleg5f" :lleg)
  (send *robot* :attach "kxrrleg5f" :rleg)
  (send *robot* :detach "kxrlleg1y")
  (send *robot* :attach "kxrlleg1r" :lleg)
  (send *robot* :attach "kxrlleg5f" :lleg)
  (objects (list *robot*))
  )

(defun samples3old nil
  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1y" :lleg)
  (send *robot* :attach "kxrrleg1y" :rleg)
  (send *robot* :attach "kxrlleg5f" "kxrlleg1y") 
  (send *robot* :attach "kxrrleg5f" "kxrrleg1y")
  (send *robot* :detach "kxrlleg1y")
  (send *robot* :attach "kxrlleg5f" :lleg)
  (objects (list *robot*))
  )

(defun samples3 nil
  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1y" :lleg)
  (send *robot* :attach "kxrrleg1y" :rleg)
  (send *robot* :attach "kxrlleg5f" :lleg)
  (send *robot* :attach "kxrrleg5f" :rleg)
  (send *robot* :detach "kxrlleg1y")
  (send *robot* :attach "kxrlleg5f" :lleg)
  (objects (list *robot*))
  )

(defun samples2old nil
  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1y" :lleg)
  (send *robot* :attach "kxrrleg1y" :rleg)
  (send *robot* :attach "kxrlleg5f" "kxrlleg1y") 
  (send *robot* :attach "kxrrleg5f" "kxrrleg1y")
  (send *robot* :detach "kxrlleg1y")
  (send *robot* :detach "kxrlleg5f")
  (send *robot* :attach "kxrlleg5f" :lleg)
  (objects (list *robot*))
  )

(defun samples2 nil
  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1y" :lleg)
  (send *robot* :attach "kxrrleg1y" :rleg)
  (send *robot* :attach "kxrlleg5f" :lleg)
  (send *robot* :attach "kxrrleg5f" :rleg)
;;  (send *robot* :detach "kxrlleg1y")
;;  (send *robot* :detach "kxrlleg5f")
;;  (send *robot* :attach "kxrlleg5f" :lleg)
  (objects (list *robot*))
  )

(defun samples1 nil
  (make-kxr-robot "kxrl2a6h2g1body" :ri nil)
  (make-kxr-robot "kxrlleg1y" :ri nil)
  (make-kxr-robot "kxrrleg1y" :ri nil)
  ;;  (make-kxr-robot "kxrlleg1r" :ri nil)
  ;;  (make-kxr-robot "kxrrleg1r" :ri nil)
  (make-kxr-robot "kxrlleg1rf" :ri nil)
  (make-kxr-robot "kxrrleg1rf" :ri nil)
  (make-kxr-robot "kxrlleg5f" :ri nil)
  (make-kxr-robot "kxrrleg5f" :ri nil)
  ;;(make-kxr-robot "kxrlleg6f" :ri nil)
  ;;(make-kxr-robot "kxrrleg6f" :ri nil)
  (make-kxr-robot "kxrmw4base" :ri nil)
  (make-kxr-robot "kxrow4base" :ri nil)
  (make-kxr-robot "kxrdw4base" :ri nil)

  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrmw4base" :mbase)
  (objects (list *robot*))
  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrow4base" :mbase)
  (objects (list *robot*))
  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrdw4base" :mbase)
  (objects (list *robot*))

  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1rf" :lleg)
  (send *robot* :attach "kxrrleg1rf" :rleg)
  (objects (list *robot*))

  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1y" :lleg)
  (send *robot* :attach "kxrrleg1y" :rleg)
  (send *robot* :attach "kxrlleg1rf" :lleg)
  (send *robot* :attach "kxrrleg1rf" :rleg)
  (objects (list *robot*))

  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg5f" :lleg)
  (send *robot* :attach "kxrrleg5f" :rleg)
  (objects (list *robot*))

  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg6f" :lleg)
  (send *robot* :attach "kxrrleg6f" :rleg)
  (objects (list *robot*))

  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1y" :lleg)
  (send *robot* :attach "kxrrleg1y" :rleg)
  (send *robot* :attach "kxrlleg5f" :lleg)
  (send *robot* :attach "kxrrleg5f" :rleg)
  (objects (list *robot*))

  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1y" :lleg)
  (send *robot* :attach "kxrrleg1y" :rleg)
  (send *robot* :attach "kxrlleg1rf" :lleg)
  (send *robot* :attach "kxrrleg1rf" :rleg)
  (send *robot* :detach "kxrrleg1rf")
  (objects (list *robot*))

  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1y" :lleg)
  (send *robot* :attach "kxrrleg1y" :rleg)
  (send *robot* :attach "kxrlleg5f" :lleg)
  (send *robot* :attach "kxrrleg5f" :rleg)
  (send *robot* :detach "kxrlleg1y")
  (send *robot* :detach "kxrlleg5f")
  (objects (list *robot*))
  )

(defun samples1old nil
  (make-kxr-robot "kxrl2a6h2g1body" :ri nil)
  (make-kxr-robot "kxrlleg1y" :ri nil)
  (make-kxr-robot "kxrrleg1y" :ri nil)
  ;;  (make-kxr-robot "kxrlleg1r" :ri nil)
  ;;  (make-kxr-robot "kxrrleg1r" :ri nil)
  (make-kxr-robot "kxrlleg1rf" :ri nil)
  (make-kxr-robot "kxrrleg1rf" :ri nil)
  (make-kxr-robot "kxrlleg5f" :ri nil)
  (make-kxr-robot "kxrrleg5f" :ri nil)
  ;;(make-kxr-robot "kxrlleg6f" :ri nil)
  ;;(make-kxr-robot "kxrrleg6f" :ri nil)
  (make-kxr-robot "kxrmw4base" :ri nil)
  (make-kxr-robot "kxrow4base" :ri nil)
  (make-kxr-robot "kxrdw4base" :ri nil)

  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrmw4base" :mbase)
  (objects (list *robot*))
  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrow4base" :mbase)
  (objects (list *robot*))
  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrdw4base" :mbase)
  (objects (list *robot*))

  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1rf" :lleg)
  (send *robot* :attach "kxrrleg1rf" :rleg)
  (objects (list *robot*))

  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1y" :lleg)
  (send *robot* :attach "kxrrleg1y" :rleg)
  (send *robot* :attach "kxrlleg1rf" "kxrlleg1y")
  (send *robot* :attach "kxrrleg1rf" "kxrrleg1y") 
  (objects (list *robot*))

  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg5f" :lleg)
  (send *robot* :attach "kxrrleg5f" :rleg)
  (objects (list *robot*))

  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg6f" :lleg)
  (send *robot* :attach "kxrrleg6f" :rleg)
  (objects (list *robot*))

  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1y" :lleg)
  (send *robot* :attach "kxrrleg1y" :rleg)
  (send *robot* :attach "kxrlleg5f" "kxrlleg1y")
  (send *robot* :attach "kxrrleg5f" "kxrrleg1y")
  (objects (list *robot*))

  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1y" :lleg)
  (send *robot* :attach "kxrrleg1y" :rleg)
  (send *robot* :attach "kxrlleg1rf" "kxrlleg1y") 
  (send *robot* :attach "kxrrleg1rf" "kxrrleg1y")
  (send *robot* :detach "kxrrleg1rf")
  (objects (list *robot*))

  (setq *robot* (instance kxr-robotset :init "kxrl2a6h2g1body" :viewer t))
  (send *robot* :attach "kxrlleg1y" :lleg)
  (send *robot* :attach "kxrrleg1y" :rleg)
  (send *robot* :attach "kxrlleg5f" "kxrlleg1y")
  (send *robot* :attach "kxrrleg5f" "kxrrleg1y")
  (send *robot* :detach "kxrlleg1y")
  (send *robot* :detach "kxrlleg5f")
  (objects (list *robot*))
  )

(defun samples0 nil (show-robots *kxr-robotset-modules*)
       #|
       (make-kxr-robot "kxrl2l6a6h2" :ri nil)
       (make-kxr-robot "kxrl2l5a6h2" :ri nil)
       (make-kxr-robot "kxrl2l2a6h2" :ri nil)
       (make-kxr-robot "kxrl2l1a6h2" :ri nil)
       (make-kxr-robot "kxrl2mw4a6h2" :ri nil)
       (make-kxr-robot "kxrmw4a6h2" :ri nil)
       (make-kxr-robot "kxrow4a6h2" :ri nil)
       |#
       )
(defun sampler0 nil (show-robots *kxr-robotset-robots*))
(defun show-robots (&optional (robots *kxr-robotset-modules*))
  (let*
      ((x0 100) (y0 50) (x x0) (y y0)
       (sx 3) (sy 50)
       (root-w (- (send x::*root* :width) x0))
       (root-h (- (send x::*root* :height) y0))
       (w (round (- (sqrt (/ (* root-w root-h) (length robots))) sy)))
       (nx (round (- (/ root-w (+ w sx)) 1)))
       (ny (round (/ root-h (+ w sy))))
       (i 0) (j 0)
       )
    (dolist (r (mapcar #'caar robots))
      (print r)
      (make-kxr-robot r :ri nil :width w :height w) ;;  :model nil)
      (send *irtviewer* :move x y)
      (send *irtviewer* :draw-objects)
      (cond
       ((>= i nx)
	(setq i 0) (setq j (1+ j))
	(setq x x0)
	(setq y (+ y0 (* (+ w sy) j))))
       (t (incf i) (setq x (+ x0 (* i (+ sx w)))))))
    )
  )

#-:arm
(format t ";; (check-duplicated-names)~%")
#-:arm
(format t ";; (check-same-model-params)~%")

(defparameter *kxr-body-config-hashtable*
  (make-hash-table :size 1000 :test #'string=))

(defun rcb4robotconfig-init nil
  (dolist (conf *kxr-body-config-alist*)
    (cond
     ((listp (car conf));; names
      (dolist (name (car conf))
	(if (stringp name)
	    (setf (gethash name *kxr-body-config-hashtable*) conf)
	  (format t ";; not string conf=~A name=~A~%" conf name))))
     ((stringp (car conf))
      (setf (gethash (car conf) *kxr-body-config-hashtable*) conf)))
    ))

(rcb4robotconfig-init)

(defun kxr-find-config-by-name (nm)
  (gethash nm *kxr-body-config-hashtable*))

(defun kxr-model-params (nm) (cadr (kxr-find-config-by-name nm)))
(defun kxr-device-config (nm) (cddr (kxr-find-config-by-name nm)))

#|
(defun kxr-find-config-by-name (nm)
  (find-if #'(lambda (x)  
	       (let ((ns (car x)))
		 (if (stringp ns)
		     (string= ns nm)
		   (member nm ns :test #'string=))))
	   *kxr-body-config-alist*)
  )

(defun kxr-model-params (nm) (cadr (kxr-find-config-by-name nm)))
(defun kxr-device-config (nm) (cddr (kxr-find-config-by-name nm)))
|#

;;(setq *kxr-all-string-names* (kxr-all-string-names))
