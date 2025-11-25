;;;
;;;	Kondo Robot(KHR, KXR) program
;;;
;;;	2017.7.17 created M.I
;;;	2017.7.31 for kxrl2l6a4 with 1250000 BAUD 33 DOF
;;;	2017.8.2 create for kxrl4t model of quadruped
;;;	2017.8.2 (send *kxrl4t* :run-motion "後進")
;;;	2017.8.3 (send *kxrl4t* :draw-motion) 
;;;	2017.8.8 add kxrl2 to test for kxrl2l5a3 no head_joint
;;;	2017.8.17 add kxrl2l6a6
;;;	2017.8.29 add khr3
;;;	2017.11.19 change make-kxr**** to (make-robot robot-name-string)
;;;	2018.2.1  (send *robot* :check-rom-project) (send *robot* :draw-real-body)
;;;	2018.2.12 (send *ri* :project-file :mcode num {:methods})
;;;	2018.2.15 fix khr3 and and khr3sl5a3h2
;;;	2018.2.17 (make-kxr-robot model-str project-file-keystr)
;;;	2018.3.3  config file from limb joint to limb-joint
;;;	2018.3.11 add twin-init, twin-demo, twin-swap, twin-stop
;;;	2018.6.12 start building kxr-robot models
;;;	2018.6.17 kxr L2 robot-model genarates auto methods by joint name
;;;	2018.6.21 KXR L4 l4t l4r l4d l4n l4p
;;;	2018.6.29 KXR L6
;;;	2018.7.9  KXR L2 add mirror, wrist-r keyword options
;;;	2018.8.2  change config-alist (name-list arg-options (num joint-name sign) ...)
;;;	2023.10.29 (send *ri* :reform-project-file '((1 33) (2 24) (3 25)...)), (send *ri* :save-project-file)
;;;

(require :rcb4robotconfig)
(require :rcb4lisp)
(require :rcb4interface)
(require :rcb4file)
(require :kxrmodels)

(defmethod object (:describe nil (describe self)))
(defmethod object (:pprint nil (pprint self)))
(defmethod string (:length nil (length self)))

(defun rcb4-help nil
#|
  (format t "; (send *ri* :rom-table :acodes :pprint); show predefined robot-names~%")
  (format t "; (make-kxr-robot \"khr3sl5a3h2\"); model-name project-file~%")
  (format t "; (send *ri* :com-init)~%")
  (format t "; (send *ri* :timer-on)~%")
  (format t "; (send *ri* :call-motion <number>); execute motion <number>~%")
  
  (format t "; (send *ri* :free :arms)~%")
  (format t "; (send *ri* :free :head)~%")
  (format t "; (send *ri* :timer-off)~%")
  (format t "; (send *ri* :read-rom-all); read motions in rcb4 ROM~%")
  (format t "; (send *ri* :draw-rom-table); draw all motions in rom-table~%")
  (format t "; (send *ri* :draw-rom-table 10); draw motion (elt rom-table 10)~%")
  (format t "; (send *ri* :project-file :mcodes :pprint); show motion number and name~%")
  (format t "; (send *ri* :motion-files :mcodes :pprint); show motion files~%")
  
  (format t "; (send *ri* :rom-table :acodes :pprint); show servo-vector space codes of rom-table~%")
  (format t "; (send *ri* :rom-table 10 :acodes :pprint); show servo-vector space codes of 10th rom-table~%")
  (format t "; (send *ri* :rom-table :ccodes :pprint); show angle-vector space codes of rom-table~%")
  (format t "; (send *ri* :rom-table 20 :ccodes :pprint); show angle-vector space codes of 20th rom-table~%")
  
  (format t "; (send *ri* :draw-project-file \"右掴み歩行右旋回\"); emulate motions~%")
  (format t "; (send *ri* :draw-project-file 54); emulate project motion 54~%")  
  (format t "; (send *ri* :project-file :mcodes \"右掴み歩\" :pprint)~%")  
  (format t "; (kxr-all-robot-names)~%")  
  (format t "; (make-kxr-robot \"kxrl2w2l5a3h2\") ;; create and load files~%")
  (format t "; (make-kxr-robot-interface \"kxrl2w2l5a3h2\") ;; create and load files~%")
|#
  )

(defun reform-kxrl4t nil
  (make-kxr-robot "kxrl4t")
  (send *ri* :reform-project-file '((1 32) (2 24) (3 25) (4 8) (5 9) (6 20) (7 21) (8 16) (9 17)))
  (send *ri* :save-project-file)
  )
(defun reform-kxrl6 nil
  (make-kxr-robot "kxrl6" :model nil)
  (send *ri* :reform-project-file '((2 24) (3 25) (4 8) (5 9) (6 10) (7 11)
				    (8 20) (9 21) (10 12) (11 13) (12 14) (13  15)
				    (14 0) (15 1) (16 16) (17 17) (18 30) (19 31)
				    ))
  (send *ri* :save-project-file)
  )
(defun load-project-file (rname)
  (send (kxr-make-robot-interface rname) :project-file))
    
(defun kxr-body-config (name)
  (if (consp name) (setq name (car name)))
  (assoc name *kxr-body-config-alist* :test #'(lambda (a b) (eq-memq a b :test #'equal))))
(defun kxr-body-config-key (name key)
  (cadr (assoc key (plist-to-alist (cadr (kxr-body-config name))))))
(defun kxr-board (name) (kxr-body-config-key name :board))

(defun kxr-interface-class (name)
  (symbol-value (kxr-body-config-key name :interface-class)))
    
(defun rcb4-ack-check (&key (timeout 1000) (limit 100))
  (kxr-ack-check (rcb4-open) :timeout timeout :limit limit))
(defun armh7-ack-check (&key (timeout 1000) (limit 100))
  (kxr-ack-check (arm2-open) :timeout timeout :limit limit))
(defun kxr-ack-check (com-port &key (timeout 1000) (limit 100) &aux msg n)
  (when com-port
    (setq msg (rcb4-assemble-one '(:ack)))
    (setq n (ftdi_write_data com-port (coerce msg string) (length msg)))
    (let* ((str1 (ftdi-read-timeout com-port 1 :timeout timeout :limit limit))
	   n str v i cs)
      (if str1 (setq n (elt str1 0))
	  (return-from kxr-ack-check nil))
      (when (> n 0)
	(setq str (ftdi-read-data com-port (- n 1)))
	(subseq str 0 (- n 1)))
      str)))
(defun kxr-kondo-usb? ()
  (find-if #'(lambda (x) (substringp "kondo" x)) (lsusb-readlines)))
(defun kxr-future-usb? ()
  (find-if #'(lambda (x) (substringp "future" x)) (lsusb-readlines)))

(defvar *rcb4-interface-class*)
(setq *rcb4-interface-class* rcb4-interface)

(defun kxr-ri-class (name &aux b)
  (cond
    ((kxr-interface-class name))
    ((eq (setq b (kxr-board name)) :rcb4) rcb4-interface)
    (t *rcb4-interface-class*)))

(defun kxr-body-type (name) (kxr-body-config-key name :type))

(defun find-model-params (model-params)
  (find (plist-to-alist model-params) *kxr-body-config-alist*
	:key #'cadr
	:test #'(lambda (a b) (set-equal a (plist-to-alist b) :test #'equal))))

(defun kxr-config-name (model-params)
  (let* ((robot-config (find-model-params model-params))
	 (nm (car robot-config)))
    (if (atom nm) nm (car nm))))

(defun kxr-all-robot-names ()
  (flatten (mapcar #'(lambda (x) (if (atom (car x)) (list (car x)) (car x)))
		   *kxr-body-config-alist*)))

(defun robot-class-name (name-str)
  (read-from-string (string-upcase (format nil "~A-robot" name-str))))
(defun robot-model-file-name (name-str) (format nil "models/~a.l" name-str))

(defun load-robot (name-str)
  (let ((cls (robot-class-name name-str)))
    (unless (boundp cls)
      (load (robot-model-file-name name-str)))
    (instance (eval cls) :init)
    ))

(defun rcb4-robot-project-dir (robo)
  (if (derivedp robo robot-model) (setq robo (send robo :name)))
  (format nil "~A/projects/Hello_~A" (rcb4eus-dir) (string-downcase robo)))

(defun kxr-project-file-name (name-str &optional
				       (dir (rcb4-robot-project-dir
					     (or (kxr-body-config-key name-str
								      :project-file)
						 name-str)))
				       (project-file-keystr "") (ext "h4p"))
  (when (probe-file dir)
    (let* ((path (car (find-files :dir dir :subseq project-file-keystr :ext ext))))
      (if (probe-file path) path))))

(defun create-robot-model-from-file (name-str &optional form)
  (let* ((bconfig (kxr-body-config name-str))
	 (model-params (if bconfig (cadr bconfig) nil))
	 (mfile (format nil "~A/models/~A.l" (unix::getenv "EUSDIR") name-str))
	 (pfile (format nil "~A/prog/models/~A.l" (unix::getenv "HOME") name-str))
	 (hfile (format nil "~A/models/~A.l" (rcb4eus-dir) name-str))
	 (catkinfile (format nil "~A/catkin_ws_src/kxr_pkgs/kxr_models/euslisp/~A.l" (rcb4eus-dir) name-str))
	 (rfile (rcb4eus-file name-str))
	 r)
    (cond
      ((probe-file rfile) (load rfile) (format t ";; load rfile:~A~%" rfile))
      ((probe-file mfile) (load mfile) (format t ";; load mfile:~A~%" mfile))
      ((probe-file pfile) (load pfile) (format t ";; load pfile:~A~%" pfile))
      ((probe-file hfile) (load hfile) (format t ";; load hfile:~A~%" hfile))
      ((probe-file catkinfile) (load catkinfile) (format t ";; load catkinfile:~A~%" catkinfile))
      (bconfig (require :eus2wrl)
	       (eus2collada-robot name-str)
	       (load hfile)))
    (when (and (null form) name-str)
      (setq form (list (read-from-string name-str))))
    (when (and form (listp form)
	       (fboundp (car form)))
      (setq r (eval form))
      r)))
    
(defun kxr-create-robot (&optional name-str &key (model 0) generate head);;((:viewer create-viewer))
  (let* ((bconfig (kxr-body-config name-str))
	 (model-params (if bconfig (cadr bconfig) nil))
	 (file (cadr (assoc :file (plist-to-alist model-params))))
	 (form (cadr (assoc :form (plist-to-alist model-params))))
	 r)
    (when head (setq model-params
		     (replace-plist-key-value model-params :head head)))
    (when generate
      (require :eus2wrl)
      (eus2collada-robot name-str :head head)
      (setq model t))
    (cond
     #|
     ((member :robotset model-params)
      (let* ((alist (plist-to-alist model-params))
	     (set (cadr (assoc :robotset alist)))
	     (vw (cadr (assoc :viewer alist)))
	     target prop m)
	(setq r (instance kxr-robotset :init (car set)))
	(setf (get r :robotset) (copy-list set))
	(pop set)
	(dolist (s set)
	  (setq prop (pop s))
	  (while (setq target (pop s))
	    (send r :attach target prop)))
	))
     ((member :robotset model-params) ;; old
      (let* ((alist (plist-to-alist model-params))
	     (set (cadr (assoc :robotset alist)))
	     (vw (cadr (assoc :viewer alist)))
	     target prop m)
	(setq r (instance kxr-robotset :init (car set)))
	(setf (get r :robotset) (copy-list set))
	(pop set)
	(dolist (s set)
	  (setq prop (pop s))
	  (while (setq target (pop s))
	    (send r :attach target prop)
	    (setq prop target)))
	))
     |#
     ((null model)
      (when model-params
	(cond
	 ((member :robotset model-params)
	  (let* ((alist (plist-to-alist model-params))
		 (set (cadr (assoc :robotset alist)))
		 (vw (cadr (assoc :viewer alist)))
		 target prop m)
	    (setq r (instance kxr-robotset :init (car set)))
	    (setf (get r :robotset) (copy-list set))
	    (pop set)
	    ;;(format t ";;; r=~A, set=~A~%" r set)
	    (dolist (s set)
	      (send r :attach* (car s) (cdr s)))
	    ;;(dolist (s set)
	    ;;(setq prop (pop s)) (while (setq target (pop s)) (send r :attach target prop)))
	    ))
	 ((substringp "khr" name-str)
	  (require :khrmodels)	 
	  (setq r (apply 'khr-robot model-params))
	  ;;(setq r (instance* khr-robot :init :name name-str model-params))
	  )
	 (t (require :kxrmodels)
	    ;;(format t ";; call kxr-robot name-str=~A model-params=~A~%" name-str model-params)
	    (setq r (apply 'kxr-robot model-params))
	    ))
	))
     ((and file (member :file model-params) (probe-file (rcb4eus-file file)))
      (setq r (create-robot-model-from-file file form)))
     ((or (null bconfig) (null model-params) (eq model t) (eq model 0))
      (setq r (create-robot-model-from-file name-str)))
     ;;      ((and (eq model 0) (member :file model-params) (probe-file (rcb4eus-file file)))
     ;;       (setq r (create-robot-model-from-file name-str form)))
     ((substringp "khr" name-str)
      (require :khrmodels)	 
      (setq r (apply 'khr-robot model-params))
      ;;(setq r (instance* khr-robot :init :name name-str model-params))
      )
     (t (require :kxrmodels)
	;;(format t ";; call kxr-robot name-str=~A model-params=~A~%" name-str model-params)
	(setq r (apply 'kxr-robot model-params))
	))
    (when r
      (when bconfig
	(setf (get r :config) bconfig)	  
	(if (atom (car bconfig))
	    (setf (get r :config-name) (car bconfig))
	    (setf (get r :config-name) (caar bconfig)))
	)
      (setf (get r :model-params) model-params)
      (send r :joint-access-names)
      (send r :name name-str)
      #|
      (when ri
	(if share 
	    (send r :set-ri (instance (kxr-ri-class name-str)
				      :init r :create-viewer create-viewer :model model))
	  (send r :set-ri (instance (kxr-ri-class name-str)
				    :init name-str :create-viewer create-viewer :model model))))
      |#
      r)))

(defvar *robots-made*)

(defun kxr-make-robot (&optional name-str &key (initial-pos (float-vector 0 0 0))
				 ((:viewer vw) (xwindow-ready?))
				 (model 0) generate head)
  (let (r)
    (if (derivedp name-str robot-model) (setq name-str (send name-str :name)))
    (cond ((stringp name-str)
	   (setq name-str (string-downcase name-str))
	   (when (setq r (kxr-create-robot name-str :model model :generate generate
					   :head head))
	     (push (set (robot-gvar name-str) r) *robots-made*)
	     (send (car *robots-made*) :locate initial-pos :world)
	     (when vw
	       (setq *irtviewer* (make-irtviewer :width 400 :height 400))
	       (send *irtviewer* :change-background (float-vector 0 0.9 0.7))
	       (send *irtviewer* :title (send r :name))
	       (setf (get r :viewer) *irtviewer*)
	       (objects (list r))))
	   r)
	  (t (setq *kxr-model-panel* (instance x::kxr-model-panel :create))
	     *robot*))))

(defun kxr-make-robot-interface (&optional name-str
					   &key ((:viewer create-viewer)) (model 0) rcb4 head)
  (make-kxr-robot-interface name-str :viewer create-viewer :model model :rcb4 rcb4 :head head))

(defvar *ris-made*)
(defun make-kxr-robot-interface (&optional name-str &key ((:viewer create-viewer)) (model 0)
					   (rcb4 t) head)
  (if rcb4 (setq *rcb4-interface-class* rcb4-interface))
  (setq *ri* (instance *rcb4-interface-class* :init))
  (unless name-str (setq name-str (unix::getenv "ROBOT_NAME")))
  (unless name-str
    (send *ri* :com-init)
    (setq name-str (send *ri* :scan-robot-name)))
  (send *ri* :create-robot name-str :create-viewer create-viewer :model model :head head)
  (set (intern (format nil "*RI-~A*" (string-upcase name-str))) *ri*)
  (pushnew *ri* *ris-made*)
  *ri*)

(defun ri (str)
  (find-if #'(lambda (x) (substringp str (send x :robot :name))) *ris-made*)
  )

(defun make-kxr-model-panel nil
  (setq *kxr-model-panel* (instance x::kxr-model-panel :create)))

(defun make-kxr-robot (&optional name-str &key ((:viewer vw) (xwindow-ready?)) (ri t) (model 0)
				 (rcb4 t) generate head)
  (unless name-str (setq name-str (unix::getenv "ROBOT_NAME")))
  (unless
      name-str
    (when ri
      (if rcb4 (setq *rcb4-interface-class* rcb4-interface))
      (setq ri (instance *rcb4-interface-class* :init))
      (send ri :com-init)
      (setq name-str (send ri :scan-robot-name))
      (send ri :create-robot name-str :create-viewer vw :model model :head head)
      (setq *ri* ri)
      ))
  (cond
   ((and name-str
	 (setq *robot* (kxr-make-robot name-str :model model :generate generate
				       :viewer vw :head head)))
    (when ri
      (if (derivedp ri rcb4-interface)
	  (setq *ri* ri)
	(setq *ri* (send *robot* :create-ri :viewer vw :model (if generate t model) :rcb4 rcb4
			 :head head))))
    (when vw
      (if (and (boundp 'x::kxr-model-panel)
	       (memq :create-control-panel (send *robot* :methods)))
	  (send *robot* :create-control-panel))
      )
    (if (and (boundp 'euscollada-robot)
	     (derivedp *robot* euscollada-robot)
	     (find-method *robot* :setup-modeltorque))
	(send *robot* :setup-modeltorque))
    *robot*)
   ((and vw (xwindow-ready?) (boundp 'x::kxr-model-panel))
    (make-kxr-model-panel)
    (if (and (boundp 'euscollada-robot)
	     (derivedp *robot* euscollada-robot)
	     (find-method *robot* :setup-modeltorque))
	(send *robot* :setup-modeltorque))
    *robot*)
   ))

#|
(defun demo-rcb4-robot (&optional (name "kxrl2w2l5a3h2"))
  (setq *robot* (make-kxr-robot name))
  (send *ri* :com-init)
  (send *ri* :draw-rom-table)
  ;; (send *robot* :draw-motion-files)
  ;; (send *robot* :draw-project-file)
  (send *ri* :timer-on)
  (send *ri* :free :arms)
  *robot*)

;;;;;; twin robots
(defun twin-init nil
  ;;(setq *r1* (make-kxr-robot "kxrl2w2l5a3h2"))
  (setq *r1* (make-kxr-robot "kxrl2w2l6a6h2n"))
  (send *r1* :ri :com-init 0)
  (setq *r2* (make-kxr-robot "kxrl2l6a7h2w"))
  (send *r2* :ri :com-init 1)
  )
(defun twin-demo nil
  (send *r1* :ri :timer-on 'r1-update)
  (send *r2* :ri :timer-on 'r2-update)
  )

(defun twin-follow (r1 r2 &optional real)
  (dolist (j (send r1 :ri :robot :joint-list))
    (when (send r2 :joint (send j :name))
      (send (send r2 :joint (send j :name)) :joint-angle
	    (send j :joint-angle))))
  (r1-update)
  (r2-update)
  (send (get r2 :viewer) :draw-objects :flush t)
  (if real (send r2 :send-to-ri 10))
  )

(defun twin-stop nil
  (send *r1* :ri :timer-off 'r1-update)
  (send *r2* :ri :timer-off 'r2-update)
  )

(defun twin-swap nil (send *r1* :ri :com-swap (send *r2* :ri)))

(defun r1-update nil (ri-update (send *r1* :ri)))
(defun r2-update nil (ri-update (send *r2* :ri)))
      
(defun rcb4-symmetry-teach (&optional flag)
  (send *ri* :free :larm)
  (if flag (send *ri* :free :lleg))

  (do-until-key
   (if flag (rcb4-mirror)
     (rcb4-larm-mirror))
   (ri-viewer-update)
   )
  (send *robot* :read-from-ri)
  (send *ri* :hold :larm)
  (send *ri* :hold :lleg)
  (when (find-method *robot* :rleg-ankle-w)
    (send *robot* :legs :ankle-w :joint-angle 0)
    (send *robot* :send-to-ri 10)
    )
  )

(defun rcb4-larm-mirror nil
  (send *robot* :read-from-ri)

  (send *robot* :rarm-shoulder-p :joint-angle
	(send *robot* :larm-shoulder-p :joint-angle))
  (send *robot* :rarm-shoulder-r :joint-angle
	(- (send *robot* :larm-shoulder-r :joint-angle)))

  (send *robot* :rarm-elbow-p :joint-angle
	(send *robot* :larm-elbow-p :joint-angle))
  (send *robot* :rarm-gripper-r :joint-angle
	(- (send *robot* :larm-gripper-r :joint-angle)))

  (when (find-method *robot* :rleg-ankle-w)
    (send *robot* :legs :ankle-w :joint-angle 0)
    )
  (send *robot* :send-to-ri 10)  
  )

(defun rcb4-lleg-mirror nil
  (send *robot* :read-from-ri)
  (send *robot* :rleg-crotch-p :joint-angle
	(send *robot* :lleg-crotch-p :joint-angle))
  (send *robot* :rleg-crotch-r :joint-angle
	(send *robot* :lleg-crotch-r :joint-angle))
  (send *robot* :rleg-knee-p :joint-angle
	(send *robot* :lleg-knee-p :joint-angle))
  (send *robot* :rleg-ankle-p :joint-angle
	(send *robot* :lleg-ankle-p :joint-angle))
  (send *robot* :rleg-ankle-r :joint-angle
	(send *robot* :lleg-ankle-r :joint-angle))
  (send *robot* :rleg-ankle-w :joint-angle 0)
  (send *robot* :lleg-ankle-w :joint-angle 0)

  (send *robot* :send-to-ri 10)  
  )
;;;
(defun test-head (&optional (vel 10) (v 40) (j :neck-y))
  (send *robot* :read-from-ri)
  (if (find-method *robot* :rleg-ankle-w)
      (send *robot* :legs :ankle-w :joint-angle 0))
  (dotimes (i 5)
    (send *robot* :head j :joint-angle v)
    (send *robot* :send-to-ri vel)
    (ri-viewer-update)
    (send *robot* :head j :joint-angle (- v))
    (send *robot* :send-to-ri vel)
    (ri-viewer-update))
  (send *robot* :head j :joint-angle 0)
  (send *ri* :neutral vel))

(defun test-gripper (&optional (vel 10) (v 40) (j :gripper-r))
  (send *robot* :read-from-ri)
  (if (find-method *robot* :rleg-ankle-w)
      (send *robot* :legs :ankle-w :joint-angle 0))
  (dotimes (i 4)
    (send *robot* :rarm j :joint-angle v)
    (send *robot* :send-to-ri vel)
    (ri-viewer-update)
    (send *robot* :rarm j :joint-angle (- v))
    (send *robot* :send-to-ri vel)
    (ri-viewer-update)
    )
  )

(defun test-balance (&optional (vel 200))
  (send *robot* :read-from-ri)
  (if (find-method *robot* :rleg-ankle-w) (send *robot* :legs :ankle-w :joint-angle 0))
  (do-until-key
   (setq p-r (send *ri* :gravity-p-r))
   (send *robot* :legs :ankle-p :joint-angle (rad2deg (elt p-r 0)))
   (send *robot* :legs :ankle-r :joint-angle (rad2deg (elt p-r 1)))
   (send *robot* :send-to-ri vel)
   (ri-viewer-update)
   )
  )

(defun test-head2 (&optional (time 10) (v 40))
  (send *robot* :read-from-ri)
  (send *robot* :angle-vector (send *ri* :read-angle-vector))
  (when (find-method *robot* :rleg-ankle-w)
    (send *robot* :legs :ankle-w :joint-angle 0))
  (dotimes (i 4)
    (send *robot* :rarm-gripper-r :joint-angle v)
    (send *robot* :head-neck-y :joint-angle v)
    (send *ri* :push-servo-command (send *robot* :angle-vector) time)
    (ri-viewer-update)
    (send *robot* :rarm-gripper-r :joint-angle (- v))
    (send *robot* :head-neck-y :joint-angle (- v))
    (send *ri* :push-servo-command (send *robot* :angle-vector) time)
    (ri-viewer-update)
    )
  (send *ri* :write-codes-to-motion-table 100)
  (send *ri* :call-motion 100)
  (when (find-method *robot* :rleg-ankle-w)
    (send *robot* :legs :ankle-w :joint-angle 0)
    (send *ri* :angle-vector (send *robot* :angle-vector))
    )
  )

(defun test-gripper2 (&optional (time 10) (v 40) (j :gripper-r))
  (send *robot* :read-from-ri)
  (if (find-method *robot* :rleg-ankle-w)
      (send *robot* :legs :ankle-w :joint-angle 0))
  (dotimes (i 2)
    (send *robot* :rarm j :joint-angle v)
    (send *ri* :push-servo-command (send *robot* :angle-vector) time)
    (ri-viewer-update)
    (send *robot* :rarm j :joint-angle (- v))
    (send *ri* :push-servo-command (send *robot* :angle-vector) time)
    (ri-viewer-update)
    )
  (send *ri* :write-codes-to-motion-table 100)
  (send *ri* :call-motion 100)
  )

(defun test-head3 (&optional (v 10))
  (setq svids (send *ri* :servo-sorted-ids))
  (send *robot* :head-neck-p :joint-angle 0)
  (send *robot* :head-neck-y :joint-angle 30)
  (setq sv0 (send *robot* :servo-vector))
  (send *robot* :head-neck-y :joint-angle -30)
  (setq sv1 (send *robot* :servo-vector))
  (send *robot* :neutral)
  (send *robot* :head-neck-p :joint-angle -30)
  (setq sv2 (send *robot* :servo-vector))  
  (setq
   cc
   `(
     (:move (:lit 10) (:ram (:counter 0)))
     labloop
     (:servo ,svids ,v ,sv0)
     (:servo ,svids ,v ,sv1)
     (:sub (:lit 1) (:ram (:counter 0)))
     (:jump (:z :z=) labend)
     (:jump nil labloop)
     labend
     (:servo ,svids ,v ,sv2)
     (:return)
     ))
  (setq bb (rcb4-assemble cc 115))
  (send *ri* :write-motion-lst bb 115)
  (send *ri* :call-motion 115)
  t)

(defun prior-test (&optional (tab 115) (prior 3))
  (send *ri* :asm-to-rom `(:call nil (:motiontable ,tab 0)) `(:prioritymotion ,prior)))

(defun prior-reset (&optional (prior 3))
  (send *ri* :send-cmd
	`(:move (:lit #xff #xff #xff #xff) (:rom (:prioritymotion ,prior))) 1))

(defun prior-read (&optional (prior 3) (size 32))
  (send *ri* :asm-from-rom (rcb4-address (list :prioritymotion prior)) `(:rom size)))
	
(defun priorc-test (&optional (tab 115) (prior 3))
  (send *ri* :asm-to-rom `(:call nil (:motiontable ,tab 0)) `(:prioritymotioncall ,prior)))

(defun priorc-reset (&optional (prior 3))
  (send *ri* :send-cmd
	`(:move (:lit #xff #xff #xff #xff) (:rom (:prioritymotioncall ,prior))) 1))

(defun priorc-read (&optional (prior 3) (size 32))
  (send *ri* :asm-from-rom (rcb4-address (list :prioritymotioncall prior)) :rom size))

(defun write-prioritymotion nil
  (rcb4-disassemble-one
   (send *ri* :asm-from-rom (rcb4-address '(:prioritymotion 0)) :rom 40))
  )

(defun test-head4 (&optional (n 10) (vel 10))
  (setq svids (send *ri* :servo-sorted-ids))
  (send *robot* :head-neck-p :joint-angle 30)
  (setq sv0 (send *robot* :servo-vector))
  (send *robot* :head-neck-p :joint-angle -30)
  (setq sv1 (send *robot* :servo-vector))
  (send *robot* :neutral)
  (setq sv2 (send *robot* :servo-vector))  
  (setq
   cc
   `(
     (:move (:lit ,n) (:ram (:counter 0)))
     labloop
     (:servo ,svids ,vel ,sv0)
     (:servo ,svids ,vel ,sv1)
     (:sub (:lit 1) (:ram (:counter 0)))
     (:jump (:z :z=) labend)
     (:jump nil labloop)
     labend
     (:servo ,svids ,vel ,sv2)
     (:return)
     ))
  (setq bb (rcb4-assemble cc 114))
  (send *ri* :write-motion-lst bb 114)
  (send *ri* :call-motion 114)
  t)

(defun test-head5 (&key (n 50) (vel 10) (d 30))
  (setq svids (send *ri* :servo-sorted-ids))
  (send *robot* :head-neck-p :joint-angle d)
  (setq sids (send *ri* :robot :head-neck-p :servo-index))
  (setq sv0 (send *robot* :servo-vector))
  (send *robot* :head-neck-p :joint-angle (- d))
  (setq sv1 (send *robot* :servo-vector))
  (send *robot* :neutral)
  (setq sv2 (send *robot* :servo-vector))  
  (setq
   cc
   `(
     (:move (:lit ,n) (:ram (:counter 0)))
     labloop
     (:servo ,sids ,vel ,sv0)
     (:servo ,sids ,vel ,sv1)
     (:sub (:lit 1) (:ram (:counter 0)))
     (:jump (:z :z=) labend)
     (:jump nil labloop)
     labend
     (:servo ,sids ,vel ,sv2)
     (:return)
     ))
  (setq bb (rcb4-assemble cc 115))
  (pprint bb)
  (send *ri* :write-motion-lst bb 115)
  (send *ri* :call-motion 115)
  t)

(defun test-head6 (&key (n 50) (vel 10) (d 20))
  (setq svids (send *ri* :servo-sorted-ids))
  (setq sids (send *ri* :robot :head-neck-p :servo-index))
  (send *robot* :head-neck-y :joint-angle 0)
  (ri-viewer-update)
  (send *robot* :head-neck-p :joint-angle d)
  (ri-viewer-update)
  (setq sv0 (send *robot* :servo-vector))
  (send *robot* :head-neck-p :joint-angle (- d))
  (ri-viewer-update)
  (setq sv1 (send *robot* :servo-vector))
  (send *robot* :neutral)
  (ri-viewer-update)
  (send *robot* :head-neck-y :joint-angle 30)
  (ri-viewer-update)
  (setq sv2 (send *robot* :servo-vector))  
  (setq
   cc `(
	(:move (:lit ,n) (:ram (:counter 0)))
	countloop

	(:move (:ram (:ad 5) 2) (:ram (:user 0)))
	(:move (:ram (:adref 5) 2) (:ram (:user 2)))
	(:add (:ram (:user 2) 2) (:ram (:user 0)))
	(:sub  (:lit 69 1) (:ram (:user 0)))
	(:jump (:c :c=) skip1)
	;;(:servo , sids ,vel ,sv0)	
	(:servo ,svids ,vel ,sv0)	
	(:jump nil skip2)
	skip1
	;;(:servo ,sids ,vel ,sv1)
	(:servo ,svids ,vel ,sv1)
	skip2
	(:sub (:lit 1) (:ram (:counter 0)))
	(:jump (:z :z=) labend)
	(:jump nil countloop)
	labend
	;;(:servo ,sids ,vel ,sv2)
	(:servo ,svids ,vel ,sv2)
	(:return)
	))
  (setq bb (rcb4-assemble cc 116))
  (pprint bb)
  (send *ri* :write-motion-lst bb 116)
  (send *ri* :call-motion 116)
  t)

(defun test-gripper3 (&optional (v 10))
  (setq svids (send *ri* :servo-sorted-ids))
  (send *ri* :hold :arms)
  (send *robot* :rarm-gripper-r :joint-angle 30)
  (ri-viewer-update)
  (setq sv0 (send *robot* :servo-vector))
  (send *robot* :rarm-gripper-r :joint-angle -30)
  (ri-viewer-update)
  (setq sv1 (send *robot* :servo-vector))
  (send *robot* :neutral)
  (ri-viewer-update)
  (setq sv2 (send *robot* :servo-vector))  
  (setq
   cc
   `(
     (:move (:lit 5) (:ram (:counter 0)))
     labloop
     (:servo ,svids ,v ,sv0)
     (:servo ,svids ,v ,sv1)
     (:sub (:lit 1) (:ram (:counter 0)))
     (:jump (:z :z=) labend)
     (:jump nil labloop)
     labend
     (:servo ,svids ,v ,sv2)
     (:return)
     ))
  (setq bb (rcb4-assemble cc 113))
  (terpri)
  (send *ri* :write-motion-lst bb 113 "test-gripper3")
  ;;(prhex (equal (car (send *ri* :read-motion-lst 113)) bb))
  ;;(terpri)
  (send *ri* :call-motion 113)
  )

(defun test-gripper4 (&optional (v 10))
  (setq svids (send *ri* :servo-sorted-ids))
  (send *ri* :hold :arms)
  (send *robot* :rarm-gripper-r :joint-angle 30)
  (ri-viewer-update)
  (setq sv0 (send *robot* :servo-vector))
  (send *robot* :rarm-gripper-r :joint-angle -30)
  (ri-viewer-update)
  (setq sv1 (send *robot* :servo-vector))
  (send *robot* :neutral)
  (ri-viewer-update)
  (setq sv2 (send *robot* :servo-vector))  
  (setq cc
        `(let ((i 5))
           (while (< 0 i)
             (servo ,svids ,v ,sv0)
             (servo ,svids ,v ,sv1)
             (setq i (- i 1)))
           (servo ,svids ,v ,sv2)))

  (setq aa (rcb4lisp::compile cc))
  (setq bb (rcb4-assemble aa 114))
  (terpri)
  (send *ri* :write-motion-lst bb 114 "test-gripper4")
  ;;(prhex (equal (car (send *ri* :read-motion-lst 113)) bb))
  ;;(terpri)
  (send *ri* :call-motion 114)
  )

(defun test-call ()
  (setq cc
        `(call 114))

  (setq aa (rcb4lisp::compile cc))
  ;;(print aa)
  (setq bb (rcb4-assemble aa 115))
  (terpri)
  (send *ri* :write-motion-lst bb 115 "test-call")
  ;;(prhex (equal (car (send *ri* :read-motion-lst 113)) bb))
  ;;(terpri)
  (send *ri* :call-motion 115)
  )

(defun test-gripper6 (&optional (v 10))
  (unless (boundp '*ri*)
    (setq *ri* (make-kxr-robot-interface "kxrl2w2l5a4h2")))
  (send *ri* :timer-off)
  (setq svids (send *ri* :servo-sorted-ids))
  (send *ri* :robot :rarm-gripper-r :joint-angle 30)
  (ri-viewer-update)
  (setq sv0 (send *ri* :robot :servo-vector))
  (send *ri* :robot :rarm-gripper-r :joint-angle -30)
  (ri-viewer-update)
  (setq sv1 (send *ri* :robot :servo-vector))
  (send *ri* :robot :neutral)
  (ri-viewer-update)
  (setq sv2 (send *ri* :robot :servo-vector))  
  (setq cc `(let ((v (read-ad 0)))
	      (if (> v 0)
		  (servo ,svids ,v ,sv0)
		(servo ,svids ,v ,sv1))))

  (setq aa (rcb4lisp::compile cc))
  (setq bb (rcb4-assemble aa 116))
  (pprint cc)
  (terpri)
  (send *ri* :write-motion-lst bb 116 "test-gripper6")
  ;;(prhex (equal (car (send *ri* :read-motion-lst 113)) bb))
  ;;(terpri)
  (send *ri* :call-motion 116)
  )

(defun test-wheel (&optional (time 10) (v 40))
  (send *robot* :read-from-ri)
  (when (find-method *robot* :rleg-ankle-w)
    (send *robot* :legs :ankle-w :joint-angle 0)
    (dotimes (i 10)
      (send *robot* :legs :ankle-w :joint-angle v)
      (send *ri* :push-servo-command (send *robot* :angle-vector) time)
      (ri-viewer-update)
      (send *robot* :legs :ankle-w :joint-angle (- v))
      (send *ri* :push-servo-command (send *robot* :angle-vector) time)
      (ri-viewer-update)
      )
    (send *ri* :write-codes-to-motion-table 100)
    (send *ri* :call-motion 100)
    (send *robot* :legs :ankle-w :joint-angle 0)
    (send *ri* :angle-vector (send *robot* :angle-vector) time)
    )
  )

(defun test-balance3 (&key (n 100) (vel 10) (d 3))
  (setq svids (send *ri* :servo-sorted-ids))
  (setq svids
	(list
	 (send *ri* :robot :head-neck-y :servo-index)
	 (send *ri* :robot :lleg-ankle-p :servo-index)
	 (send *ri* :robot :rleg-ankle-p :servo-index)))
  (send *robot* :head-neck-y :joint-angle 0)
  (send *robot* :lleg-ankle-p :joint-angle 0)
  (send *robot* :rleg-ankle-p :joint-angle 0)

  (send *robot* :lleg-ankle-p :joint-angle d)
  (send *robot* :rleg-ankle-p :joint-angle d)
  (ri-viewer-update)
  (setq sv0 (send *robot* :servo-vector))
  (send *robot* :lleg-ankle-p :joint-angle (- d))
  (send *robot* :rleg-ankle-p :joint-angle (- d))
  (ri-viewer-update)
  (setq sv1 (send *robot* :servo-vector))
  (send *robot* :neutral)
  (ri-viewer-update)
  (send *robot* :head-neck-y :joint-angle 30)
  (ri-viewer-update)
  (setq sv2 (send *robot* :servo-vector))  
  (setq
   cc `(
	(:move (:lit ,n) (:ram (:counter 0)))
	countloop
	(:move (:ram (:ad 5) 2) (:ram (:user 0)))
	(:move (:ram (:adref 5) 2) (:ram (:user 2)))
	(:add (:ram (:user 2) 2) (:ram (:user 0)))
	(:sub  (:lit 69 1) (:ram (:user 0)))
	(:jump (:c= :c) skip1)
	(:servo ,svids ,vel ,sv0)	
	(:jump nil skip2)
	skip1
	(:servo ,svids ,vel ,sv1)
	skip2
	(:sub (:lit 1) (:ram (:counter 0)))
	(:jump (:z :z=) labend)
	(:jump nil countloop)
	labend
	(:servo ,svids ,vel ,sv2)
	(:return)
	))
  (setq bb (rcb4-assemble cc 117))
  (print bb)
  (send *ri* :write-motion-lst bb 117)
  (send *ri* :call-motion 117)
  t)

(defun test (&optional (v 40) (tab 111))
  (setq svids (send *ri* :servo-sorted-ids))
  (send *robot* :rarm-gripper-r :joint-angle 30)
  (setq sv0 (send *robot* :servo-vector))
  (send *robot* :rarm-gripper-r :joint-angle -30)
  (setq sv1 (send *robot* :servo-vector))
  (send *robot* :neutral)
  (setq sv2 (send *robot* :servo-vector))  
  (setq
   cc
   `(
     (:move (:lit 5) (:ram (:counter 0)))
     labloop
     (:servo ,svids ,v ,sv0)

     (:move (:ram (:ad 5) 2) (:ram (:user 0)))
     (:move (:ram (:user 0) 2) (:ram (:user 1)))
     (:move (:ram (:adref 5) 2) (:ram (:user 2)))
     (:add (:ram (:user 2) 2) (:ram (:user 0)))
     (:sub  (:lit 69 1) (:ram (:user 0)))

     (:move (:ram (:ad 3) 2) (:ram (:user 3)))
     (:move (:ram (:user 3) 2) (:ram (:user 4)))
     (:move (:ram (:adref 3) 2) (:ram (:user 5)))
     (:add (:ram (:user 5) 2) (:ram (:user 3)))
     (:sub  (:lit 69 1) (:ram (:user 3)))

     (:move (:ram (:ad 4) 2) (:ram (:user 6)))
     (:move (:ram (:user 6) 2) (:ram (:user 7)))
     (:move (:ram (:adref 4) 2) (:ram (:user 8)))
     (:add (:ram (:user 8) 2) (:ram (:user 6)))
     (:sub  (:lit 119 1) (:ram (:user 6)))

     (:servo ,svids ,v ,sv1)
     (:sub (:lit 1) (:ram (:counter 0)))
     (:jump (:z :z=) labend)
     (:jump nil labloop)
     labend
     (:servo ,svids ,v ,sv2)
     (:return)
     ))
  (setq bb (rcb4-assemble cc tab))
  (send *ri* :write-motion-lst bb tab "test")
  (send *ri* :call-motion tab)
  (do-until-key
   (dotimes (i 9)
     (setq adr (rcb4-address (list :user i)))
     (format t " ~A(~X):~A" i adr
	     (numseq-to-short (send *ri* :read-str adr :ram 2) 2))
     (if (= (mod i 3) 2) (format t "	")))
   (terpri))
  )

(defun test1 (&optional (d 8) (v 40))
  (setq svids (send *ri* :servo-sorted-ids))
  (send *robot* :neutral)
  (send *robot* :legs :ankle-r :joint-angle d)
  (setq sv0 (send *robot* :servo-vector))
  (send *robot* :legs :ankle-r :joint-angle (- d))
  (setq sv1 (send *robot* :servo-vector))
  (send *robot* :neutral)
  (setq sv2 (send *robot* :servo-vector))  
  (setq
   cc
   `(
     (:move (:lit 5) (:ram (:counter 0)))
     labloop
     (:servo ,svids ,v ,sv0)

     (:move (:ram (:ad 5) 2) (:ram (:user 0)))
     (:move (:ram (:user 0) 2) (:ram (:user 1)))
     (:move (:ram (:adref 5) 2) (:ram (:user 2)))
     (:add (:ram (:user 2) 2) (:ram (:user 0)))
     (:sub  (:lit 69 1) (:ram (:user 0)))

     (:move (:ram (:ad 3) 2) (:ram (:user 3)))
     (:move (:ram (:user 3) 2) (:ram (:user 4)))
     (:move (:ram (:adref 3) 2) (:ram (:user 5)))
     (:add (:ram (:user 5) 2) (:ram (:user 3)))
     (:sub  (:lit 69 1) (:ram (:user 3)))

     (:move (:ram (:ad 4) 2) (:ram (:user 6)))
     (:move (:ram (:user 6) 2) (:ram (:user 7)))
     (:move (:ram (:adref 4) 2) (:ram (:user 8)))
     (:add (:ram (:user 8) 2) (:ram (:user 6)))
     (:sub  (:lit 119 1) (:ram (:user 6)))

     (:servo ,svids ,v ,sv1)
     (:sub (:lit 1) (:ram (:counter 0)))
     (:jump (:z :z=) labend)
     (:jump nil labloop)
     labend
     (:servo ,svids ,v ,sv2)
     (:return)
     ))
  (setq bb (rcb4-assemble cc 111))
  (send *ri* :write-motion-lst bb 111 "test1")
  (send *ri* :call-motion 111)
  (do-until-key
   (dotimes (i 9)
     (setq adr (rcb4-address (list :user i)))
     (format t " ~A(~X):~A" i adr
	     (numseq-to-short (send *ri* :read-str adr :ram 2) 2))
     (if (= (mod i 3) 2) (format t "	")))
   (terpri))
  )


(defun test2 (&key (n 10) (d 8) (v 5) (j :ankle-w))
  (setq svids (send *ri* :servo-sorted-ids))
  (send *robot* :neutral)
  (send *robot* :legs j :joint-angle d)
  (setq sv0 (send *robot* :servo-vector))
  (send *robot* :legs j :joint-angle (- d))
  (setq sv1 (send *robot* :servo-vector))
  (send *robot* :neutral)
  (setq sv2 (send *robot* :servo-vector))  
  (setq
   cc
   `(
     (:move (:lit ,n) (:ram (:counter 0)))
     labloop
     (:servo ,svids ,v ,sv0)

     (:move (:ram (:ad 5) 2) (:ram (:user 0)))
     (:move (:ram (:user 0) 2) (:ram (:user 1)))
     (:move (:ram (:adref 5) 2) (:ram (:user 2)))
     (:add (:ram (:user 2) 2) (:ram (:user 0)))
     (:sub  (:lit 69 1) (:ram (:user 0)))

     (:move (:ram (:ad 3) 2) (:ram (:user 3)))
     (:move (:ram (:user 3) 2) (:ram (:user 4)))
     (:move (:ram (:adref 3) 2) (:ram (:user 5)))
     (:add (:ram (:user 5) 2) (:ram (:user 3)))
     (:sub  (:lit 69 1) (:ram (:user 3)))

     (:move (:ram (:ad 4) 2) (:ram (:user 6)))
     (:move (:ram (:user 6) 2) (:ram (:user 7)))
     (:move (:ram (:adref 4) 2) (:ram (:user 8)))
     (:add (:ram (:user 8) 2) (:ram (:user 6)))
     (:sub  (:lit 119 1) (:ram (:user 6)))

     (:servo ,svids ,v ,sv1)
     (:sub (:lit 1) (:ram (:counter 0)))
     (:jump (:z :z=) labend)
     (:jump nil labloop)
     labend
     (:servo ,svids ,v ,sv2)
     (:return)
     ))
  (setq bb (rcb4-assemble cc 111))
  (send *ri* :write-motion-lst bb 111 "test2")
  (send *ri* :call-motion 111)
  (do-until-key
   (dotimes (i 9)
     (setq adr (send *ri* :address (list :user i)))
     (format t " ~A(~X):~A" i adr
	     (numseq-to-short (send *ri* :read-str adr :ram 2) 2))
     (if (= (mod i 3) 2) (format t "	")))
   (terpri))
  )

(defun test3 (&key (n 10) (d 8) (v 10) (j :shoulder-p))
  (setq svids (send *ri* :servo-sorted-ids))
  (send *robot* :neutral)
  (send *robot* :arms j :joint-angle d)
  (setq sv0 (send *robot* :servo-vector))
  (send *robot* :arms j :joint-angle (- d))
  (setq sv1 (send *robot* :servo-vector))
  (send *robot* :neutral)
  (setq sv2 (send *robot* :servo-vector))  
  (setq
   cc
   `(
     (:move (:lit ,n) (:ram (:counter 0)))
     labloop
     (:servo ,svids ,v ,sv0)

     (:move (:ram (:ad 5) 2) (:ram (:user 0)))
     (:move (:ram (:user 0) 2) (:ram (:user 1)))
     (:move (:ram (:adref 5) 2) (:ram (:user 2)))
     (:add (:ram (:user 2) 2) (:ram (:user 0)))
     (:sub  (:lit 69 1) (:ram (:user 0)))

     (:move (:ram (:ad 3) 2) (:ram (:user 3)))
     (:move (:ram (:user 3) 2) (:ram (:user 4)))
     (:move (:ram (:adref 3) 2) (:ram (:user 5)))
     (:add (:ram (:user 5) 2) (:ram (:user 3)))
     (:sub  (:lit 69 1) (:ram (:user 3)))

     (:move (:ram (:ad 4) 2) (:ram (:user 6)))
     (:move (:ram (:user 6) 2) (:ram (:user 7)))
     (:move (:ram (:adref 4) 2) (:ram (:user 8)))
     (:add (:ram (:user 8) 2) (:ram (:user 6)))
     (:sub  (:lit 119 1) (:ram (:user 6)))

     (:servo ,svids ,v ,sv1)
     (:sub (:lit 1) (:ram (:counter 0)))
     (:jump (:z :z=) labend)
     (:jump nil labloop)
     labend
     (:servo ,svids ,v ,sv2)
     (:return)
     ))
  (setq bb (rcb4-assemble cc 111))
  (send *ri* :write-motion-lst bb 111 "test3")
  (send *ri* :call-motion 111)
  (do-until-key
   (dotimes (i 9)
     (setq adr (rcb4-address (list :user i)))
     (format t " ~A(~X):~A" i adr
	     (numseq-to-short (send *ri* :read-str adr :ram 2) 2))
     (if (= (mod i 3) 2) (format t "	")))
   (terpri))
  )


(defun test4 (&key (n 10) (d 8) (v 5) (j :ankle-p))
  (setq svids (send *ri* :servo-sorted-ids))
  (send *robot* :neutral)
  (send *robot* :legs j :joint-angle d)
  (setq sv0 (send *robot* :servo-vector))
  (send *robot* :legs j :joint-angle (- d))
  (setq sv1 (send *robot* :servo-vector))
  (send *robot* :neutral)
  (setq sv2 (send *robot* :servo-vector))  
  (setq
   cc
   `(
     (:move (:lit ,n) (:ram (:counter 0)))
     labloop
     (:servo ,svids ,v ,sv0)

     (:move (:ram (:ad 5) 2) (:ram (:user 0)))
     (:move (:ram (:user 0) 2) (:ram (:user 1)))
     (:move (:ram (:adref 5) 2) (:ram (:user 2)))
     (:add (:ram (:user 2) 2) (:ram (:user 0)))
     (:sub  (:lit 69 1) (:ram (:user 0)))

     (:move (:ram (:ad 3) 2) (:ram (:user 3)))
     (:move (:ram (:user 3) 2) (:ram (:user 4)))
     (:move (:ram (:adref 3) 2) (:ram (:user 5)))
     (:add (:ram (:user 5) 2) (:ram (:user 3)))
     (:sub  (:lit 69 1) (:ram (:user 3)))

     (:move (:ram (:ad 4) 2) (:ram (:user 6)))
     (:move (:ram (:user 6) 2) (:ram (:user 7)))
     (:move (:ram (:adref 4) 2) (:ram (:user 8)))
     (:add (:ram (:user 8) 2) (:ram (:user 6)))
     (:sub  (:lit 119 1) (:ram (:user 6)))

     (:servo ,svids ,v ,sv1)
     (:sub (:lit 1) (:ram (:counter 0)))
     (:jump (:z :z=) labend)
     (:jump nil labloop)
     labend
     (:servo ,svids ,v ,sv2)
     (:return)
     ))
  (setq bb (rcb4-assemble cc 111))
  (send *ri* :write-motion-lst bb 111 "test4")
  (send *ri* :call-motion 111)
  (do-until-key
   (dotimes (i 9)
     (setq adr (rcb4-address (list :user i)))
     (format t " ~A(~X):~A" i adr
	     (numseq-to-short (send *ri* :read-str adr :ram 2) 2))
     (if (= (mod i 3) 2) (format t "	")))
   (terpri))
  )

(defun test0-bug (&optional (vel 10) (limb :rarm) (joint :gripper-r))
  (let ((sv (send *ri* :servo-vector)))
    (send *ri* :set-sysreg-bits '((:response-on . 1)))
    (send *ri* :write (rcb4-assemble-one
		 (list :servo
		       (list (send *ri* limb joint :servo-index))
		       vel
		       sv
		       )))
    (send *ri* :read 4)
    (send *ri* :read 8))
  )
|#

(defmethod rcb4-interface
  (:rarm-follow
   ()
   (let (av)
     (send self :reset-pose)
     (send self :larm-hold)
     (send self :rarm-free)
     (do-until-key
      (setq av (send self :read-angle-vector))
      (send self :robot :angle-vector (copy-object av))
      (send self :robot :larm-shoulder-p :joint-angle
	    (send self :robot :rarm-shoulder-p :joint-angle))
      (send self :robot :larm-shoulder-r :joint-angle
	    (- (send self :robot :rarm-shoulder-r :joint-angle)))
      (send self :robot :larm-elbow-p :joint-angle
	    (send self :robot :rarm-elbow-p :joint-angle))
      (send self :robot :larm-gripper-r :joint-angle
	    (send self :robot :rarm-gripper-r :joint-angle))
      (send self :robot :lleg-ankle-w :joint-angle 0)
      (send self :robot :rleg-ankle-w :joint-angle 0)
      (send self :angle-vector (send self :robot :angle-vector) 2)
      )
     (send self :rarm-hold)
     (send self :reset-pose)
     ))
  )

(rcb4-help)

(provide :rcb4robots)

