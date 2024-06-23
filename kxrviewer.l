;;;
;;; KXR remote controller emulator 2018.11.7
;;;	2020.3.2 added kxr-model-panel to make kxr-robot
;;;

(in-package "USER")

(require :kxranimate)

;;;
(in-package "X")

(defmethod panel
    (:create-menu-buttons
     (label lst &rest args
	    &key (font (font-id "*-fixed-bold-r-normal-*-18-*"))
	    (border-width 2)
	    &allow-other-keys)
	      (let ((menu (instance menu-panel :create :font font)))
		(dolist (l lst)  ;; l= method-name-string
		  (send menu :create-item button-item l self
			(intern (string-upcase l) *keyword-package*)))
		(send self :create-item menu-button-item label nil nil :menu menu
		      :border-width border-width)
		menu))
  (:create-2D-menu-buttons
   (label method
	  motion-table rows &rest args &key (height 30) (width 1030) (color *maroon*)
	  (border-width 2) (font (font-id "*-fixed-bold-r-normal-*-18-*")) &allow-other-keys)
   (let* ((bar (send self :create-menubar :height height :width width))
	  ;;(instance* menubar-panel :create :font font :map nil :parent self args))
	  (len (length motion-table))
	  (cols (/ len rows))
	  (menus (instantiate vector cols))
	  )
     (send self :locate-item bar)
     (dotimes (j cols)
       (setf (elt menus j) 
	     (instance menu-panel :create :font font :color color))
       (dotimes (i rows)
	 (when (< (+ i (* rows j)) (length motion-table))
	   (send (elt menus j) :create-item button-item
		 (format nil "~A ~60A button: ~38A" (+ i (* rows j))
			 (if (elt motion-table (+ i (* rows j)))
			     (send (elt motion-table (+ i (* rows j))) :name))
			 (if (elt motion-table (+ i (* rows j)))
			     (cddr (send (elt motion-table (+ i (* rows j))) :buttondata)))
			 )
		 self (list method (+ (* rows j) i))
		 :font font)))
       (send bar :create-item menu-button-item
	     (format nil "~A ~A- " label (* rows j))
	     self nil :menu (elt menus j) :border-width border-width)
       )
     bar)
   )
  )
    
(defclass robot-control-panel :super panel
  :slots (robot dworld editmenu playmenu posemenu timermenu commenu freemenu holdmenu buttoncmd
		projectmenu rommenu remoconmenu remocon-view motionmenubar
		jvectors pmenubar rommenubar jointmenu joint-slider pmotion-table
		time loop-project project-mcodes motion-table rom-table remocon-table sync-mode
		motion-number motion-name loop-rom rom-mcodes motion-number-item motion-name-item
		save-item load-item sliders animate-flag mirror-flag pose-list pose-list-index))

(defmethod robot-control-panel
  (:remocon-view (&rest args) (user::forward-message-to remocon-view args))
  (:pose-list nil pose-list)
  (:motion-number (&optional n) (if n (setq motion-number n) motion-number))
  (:motion-name (&optional n) (if n (setq motion-name n) motion-name))
  (:time (&optional n) (if n (setq time n) time))
  (:rom-table (&rest args) (if (numberp (car args))
			       (user::forward-message-to (elt rom-table (car args)) (cdr args))
			     (user::forward-message-to rom-table args)))
  (:robot (&rest args) (user::forward-message-to robot args))
  (:set-robot (v) (if v (setq robot v)) robot)
  (:quit (&rest args) (when remocon-view (send remocon-view :quit))
	 (send self :write-to-flash)
	 (send-super :quit))
  (:create ;; robot-control-panel
   (&optional rob &rest args &key (width 910) &allow-other-keys)
   (let (jlen maxnamelen (int 0) (rows 10))
     (setq robot rob time 70)
     (setq jlen (/ (length (send robot :joint-list)) 2))
     (setq mirror-flag :mirror)
     (setq maxnamelen
	   (apply #'max (mapcar #'length (mapcar #'string (send robot :joint-list :name)))))
     ;;
     (send-super* :create :width width :height (* rows 35) args)
     (send-super :create-item button-item "quit" self :quit)
     
     (send-super :create-item button-item " sync set " self :toggle-sync)
     
     (setq commenu (send self :create-menu-buttons "com init"
			 '("com-init" "arm2-open" "rcb4-open" "arm-open" "dyna-start" "dyna-stop")))
     (setq timermenu (send self :create-menu-buttons "timer on/off"
			   '("timer-on" "timer-off" "madgwick-calib" "bvh-animate")))
     (setq freemenu (send self :create-menu-buttons " free "
			  '("free-all" "free-arms" "free-larm" "free-rarm"
			    "free-lgripper" "free-rgripper"
			    "free-legs" "free-lleg" "free-rleg" "free-head"
			    "free-head-y" "free-head-p" "free-leye" "free-reye"
			    "free-torso" "free-torso-y" "free-torso-p"
			    )))
     (setq holdmenu (send self :create-menu-buttons " hold "
			  '("hold-all" "hold-arms" "hold-larm" "hold-rarm"
			    "hold-lgripper" "hold-rgripper"
			    "hold-legs" "hold-lleg"  "hold-rleg" "hold-head"
			    "hold-head-y" "hold-head-p" "hold-leye" "hold-reye"
			    "hold-torso" "hold-torso-y" "hold-torso-p"
			    )))
     (setq posemenu (send self :create-menu-buttons "make pose"
			  '("reset-pose" "neutral-pose"
			    "stand-pose" "car-pose" "hand-close" "hand-open"
			    "centroid-on-left-foot"
			    "centroid-on-right-foot" "centroid-on-left-foot-no-arm"
			    "centroid-on-right-foot-no-arm" "step-left-foot-1"
			    "step-left-foot-2" "step-left-foot-3"
			    "step-right-foot-1" "step-right-foot-2" "step-right-foot-3"
			    )))
     (setq playmenu (send self :create-menu-buttons "send to ri"
			  '("send-to-ri" "read-from-ri" "copy-from-ri" "play-pose-list"
			    "write-pose-list" "call-pose-list")))
     (setq projectmenu (send self :create-menu-buttons "project"
			     '("project-write-to-rom" "start-project-file"
			       "stop-project-file" "reset-project-file")))
     (setq rommenu (send self :create-menu-buttons " rom "
			 '("read-rom-table" "write-to-flash" "start-rom-table" "stop-rom-table" "reset-rom-table")))
     
     ;;
     (setq pmotion-table (instantiate user::rcb4-motion-table 120))
     (dolist (mc (send robot :ri :project-file :mcodes))
       (setf (elt pmotion-table (send mc :number)) mc))
     ;;
     (setq pmenubar (send self :create-2d-menu-buttons " project motion"
			  :emulate-motion-code pmotion-table 30 :width 800))
     ;;
     (setq motion-number 101)
     (setq rom-table (copy-object pmotion-table))
     (setq rommenubar (send self :create-2d-menu-buttons "call rom motion"
			    :call-motion rom-table 30 :width 800))
     ;;
     (setq remoconmenu (send self :create-menu-buttons " remocon "
			     '("jump-vector-flag" "jump-vector-on" "jump-vector-off"
			       "remocon-play-project" "remocon-play-rom" "remocon-teach")))
     
     (setq jvectors (send robot :ri :project-file :jump-vectors))
     (dotimes (i 31)
       (send remoconmenu :create-item button-item
	     (if (elt jvectors i)
		 (format nil "motion:~3A ~40A"
			 (cadr (caddr (elt jvectors i))) (cdddr (cadr (elt jvectors i))))
		 "nil")
	     self (list :remocon-show i))
       )
     ;;
     (setq jointmenu (instance menu-panel :create
			       :font (font-id "*-fixed-bold-r-normal-*-18-*")
			       :width 500))
     (dolist (j (send robot :ri :robot :joint-list))
       (send jointmenu :create-item button-item
	     (format nil
		     (concatenate string "~" (string (+ maxnamelen 2)) "A servo:~8A")
		     (send j :name) (send j :servo-index))
	     self (list :select-joint-slider j))
       )
     ;;
     (send-super :create-item menu-button-item "select joint"
		 nil nil :menu jointmenu :border-width 2)
     ;;
     (let ((j (car (send robot :ri :robot :joint-list))))
       (setq joint-slider (send-super :create-item slider-item
				      (format nil " ~25A" (send j :name))
				      self :set-joint-slider :span 500
				      :value-format "~5A" :initial-value (send j :joint-angle)
				      :min (send j :min-angle)
				      :min-label (format nil "~7A" (send j :min-angle))
				      :max (send j :max-angle)
				      :max-label (format nil "~7A" (send j :max-angle))
				      )))
     ;;
     (send-super :create-item choice-item "dual move" self :dual-move :choices
		 '("MIRROR" " + " " - " "OFF"))
     (send-super :create-item slider-item "time [frame]" self :slider-time :span 200
		 :value-format "~5A" :initial-value time :min 1 :max 200)
     ;;
     (setq editmenu (send self :create-menu-buttons " edit list "
			  '("pose-push" "pose-pop" "pose-animate" "pose-print" "pose-clear"
			    "pose-replace" "pose-store" "pose-load" "pose-next"
			    "pose-previous" "pose-start" "pose-end")))
     ;;
     (setq save-item
	   (send-super :create-item text-item "pose save:" self :pose-save-file
		       ;;:background "white" :columns 20 :y 5 :font font-a14
		       :initial-value "poselist"
		       ;;:background "blue"
		       :columns 20 :font font-a14))
     (setq load-item
	   (send-super :create-item text-item "pose load:" self :pose-load-file
		       :initial-value "poselist"
		       ;;:background "blue"
		       :columns 20 :font font-a14))
     ;;
     (send-super :create-item button-item "show collisions" self :show-collisions)       
     ;;
     (setq motion-table (copy-object pmotion-table))
     (setq motionmenubar (send self :create-2d-menu-buttons "  edit motion table"
			       :edit-motion motion-table 30 :width 900))
     ;;
     (setq motion-number-item
	   (send-super :create-item text-item "set motion number" self :set-motion-number
		       :initial-value (string motion-number) :columns 5 :font font-a14))
     (setq motion-name "pose-list")
     (setq motion-name-item
	   (send-super :create-item text-item "set motion name" self :set-motion-name
		       :initial-value motion-name :columns 70 :font font-a14))
     ;;
     (setq remocon-view (user::kxr-remocon-view))
     ;;(send-super :create-item choice-item "choice" self :choice :choices
     ;;(mapcar #'(lambda (x) (string (send x :name))) (send robot :joint-list)))
     ;;(send-super :create-item joystick-item "joy" self :joy :return t)
     ;;(setq posemenu (instance menu-panel :create))
     ;;(send posemenu :create-item button-item "aho" self :men)
     ;;(send-super :create-item menu-button-item "baka" nil nil :menu posemenu :border-width 2)
     self))
  ;;
  (:set-joint-slider
   (obj val)
   ;;(format t ";slider: ~S ~s~%" obj val)
   (let* ((oldval (send obj :value))
	  (collisions
	   (apply #'append
		  (mapcar #'(lambda (x)
			      (let ((a (send (car x) :name))
				    (b (send (cdr x) :name)))
				(list (if (symbolp a) a (read-from-string a))
				      (if (symbolp b) b (read-from-string b)))))
			  (send robot :self-collision-check))))
	  (sname (string (read-from-string (send obj :name))))
	  (jname (intern sname *keyword-package*))
	  (slast (1- (length sname)))
	  (mname (user::mirror-method jname)))
     ;;(format t "mirror-flag=~A, mname=~A~%" mirror-flag mname)
     (send robot jname :joint-angle val)
     ;;(format t ";; obj=~A jname=~A~%" obj jname)
     (when mname
       (case
	mirror-flag
	(:same (send robot mname :joint-angle val))
	(:minus (send robot mname :joint-angle (- val)))
	(:mirror
	 (if
	     (memq (elt sname slast) (list #\R #\Y))
	     (send robot mname :joint-angle (- val))
	   (send robot mname :joint-angle val)))))
     (send self :show-collisions)
     )
   )
  (:select-joint-slider
   (jo &rest args)
   (let* ((j (car jo)) sname)
     (setq sname (format nil " ~30A" (send j :name)))
     ;;(format t ";; :select-joint-slider jo=~A sname=~A args=~A~%" jo sname args)
     (setq (joint-slider . label) sname)
     (send joint-slider :name sname)
     (send joint-slider :value (send j :joint-angle))
     (send joint-slider :new-range
	   (send j :min-angle) (format nil "~7A" (send j :min-angle))
	   (send j :max-angle) (format nil "~7A" (send j :max-angle)))
     (send joint-slider :redraw)
     )
   )
  (:edit-motion
   (mc &rest args)
   (setq motion-number (send (car mc) :number))
   ;;(format t ";; edit motion ~A, args=~A~%" motion-number args)
   (send motion-number-item :value (string motion-number))
   (setq motion-name (send (elt motion-table motion-number) :name))
   (if (consp motion-name) (setq motion-name (cadr motion-name)))
   (send motion-name-item :value motion-name)
   )
  (:call-motion
   (mci &rest args)
   (format t ";; :call-motion mci =~A~%" mci)
   (when (and (listp mci) (car mci))
     (send robot :ri :call-motion (car mci))))
  (:emulate-motion-code
   (mc &rest args)
   (when (and (listp mc) (numberp (car mc)))
     (format t ";; :emulate-motion-code mc=~A pmotion-table =~A~%" mc (elt pmotion-table (car mc)))
     (send robot :ri :emulate-motion-code (elt pmotion-table (car mc)) :send-to-ri sync-mode))
   )
  ;;
  (:car-pose (&rest msg) (send robot :car-pose))
  (:stand-pose (&rest msg) (send robot :stand-pose))
  (:hand-close (&rest msg) (send robot :hand-close))
  (:hand-open (&rest msg) (send robot :hand-open))
  ;;
  (:step-left-foot-1
   (&rest msg)
   (let ((step-height 10) (step-offset 10))
     (send robot :lleg :move-end-pos (float-vector 0 0 (+ step-height step-offset)))
     (send robot :move-centroid-on-foot
	   :both '(:rleg :lleg)
	   :target-centroid-pos (send (send robot :rleg :end-coords) :worldpos))
     (send self :show-collisions)))
  (:step-left-foot-2
   (&rest msg)
   (let ((step-distance 30))
     (send robot :lleg :move-end-pos (float-vector step-distance 0 0))
     (send robot :move-centroid-on-foot
	   :both '(:rleg :lleg)
	   :target-centroid-pos (send (send robot :rleg :end-coords) :worldpos))
     (send self :show-collisions)))
  (:step-left-foot-3
   (&rest msg)
   (let ((step-offset 10))
     (send robot :lleg :move-end-pos (float-vector 0 0 (* step-offset -1)))
     (send robot :move-centroid-on-foot
	   :both '(:rleg :lleg)
	   :target-centroid-pos (send (send robot :rleg :end-coords) :worldpos))
     (send self :show-collisions)))
  (:step-right-foot-1
   (&rest msg)
   (let ((step-height 10) (step-offset 10))
     (send robot :rleg :move-end-pos (float-vector 0 0 (+ step-height step-offset)))
     (send robot :move-centroid-on-foot
	   :both '(:rleg :lleg)
	   :target-centroid-pos (send (send robot :lleg :end-coords) :worldpos))
     (send self :show-collisions)))
  (:step-right-foot-2
   (&rest msg)
   (let ((step-distance 30))
     (send robot :rleg :move-end-pos (float-vector step-distance 0 0))
     (send robot :move-centroid-on-foot
	   :both '(:rleg :lleg)
	   :target-centroid-pos (send (send robot :lleg :end-coords) :worldpos))
     (send self :show-collisions)))
  (:step-right-foot-3
   (&rest msg)
   (let ((step-offset 10))
     (send robot :rleg :move-end-pos (float-vector 0 0 (* step-offset -1)))
     (send robot :move-centroid-on-foot
	   :both '(:rleg :lleg)
	   :target-centroid-pos (send (send robot :lleg :end-coords) :worldpos))
     (send self :show-collisions)))
  (:centroid-on-left-foot
   (&rest msg)
   (let* ((k '(:rleg :lleg :rarm :larm))
	  (mt (mapcar #'(lambda (k) (send robot k :end-coords)) k))
	  (ll (mapcar #'(lambda (m) (send robot :link-list (send m :parent))) mt))
	  (tc (send-all mt :copy-worldcoords)))
     (send robot :fullbody-inverse-kinematics tc
	   :move-target mt :link-list ll
	   :translation-axis '(t t t nil)
	   :rotation-axis '(t t nil nil)
	   :target-centroid-pos (copy-seq (send (cadr tc) :worldpos))
	   ;; :cog-thre 10
	   :debug-view :no-message)
     (send self :show-collisions))
   )
  (:centroid-on-right-foot
   (&rest msg)
   (let* ((k '(:rleg :lleg :rarm :larm))
	  (mt (mapcar #'(lambda (k) (send robot k :end-coords)) k))
	  (ll (mapcar #'(lambda (m) (send robot :link-list (send m :parent))) mt))
	  (tc (send-all mt :copy-worldcoords)))
     (send robot :fullbody-inverse-kinematics tc
	   :move-target mt :link-list ll
	   :translation-axis '(t t nil t)
	   :rotation-axis '(t t nil nil)
	   :target-centroid-pos (copy-seq (send (car tc) :worldpos))
	   ;; :cog-thre 10
	   :debug-view :no-message)
     (send self :show-collisions))
   )
  (:centroid-on-left-foot-no-arm
   (&rest msg)
   (let* ((k '(:rleg :lleg))
	  (mt (mapcar #'(lambda (k) (send robot k :end-coords)) k))
	  (ll (mapcar #'(lambda (m) (send robot :link-list (send m :parent))) mt))
	  (tc (send-all mt :copy-worldcoords)))
     (send robot :fullbody-inverse-kinematics tc
	   :move-target mt :link-list ll
	   :translation-axis '(t t)
	   :rotation-axis '(t t)
	   :target-centroid-pos (copy-seq (send (cadr tc) :worldpos))
	   ;; :cog-thre 10
	   :debug-view :no-message)
     (send self :show-collisions))
   )
  (:centroid-on-right-foot-no-arm
   (&rest msg)
   (let* ((k '(:rleg :lleg))
	  (mt (mapcar #'(lambda (k) (send robot k :end-coords)) k))
	  (ll (mapcar #'(lambda (m) (send robot :link-list (send m :parent))) mt))
	  (tc (send-all mt :copy-worldcoords)))
     (send robot :fullbody-inverse-kinematics tc
	   :move-target mt :link-list ll
	   :translation-axis '(t t)
	   :rotation-axis '(t t)
	   :target-centroid-pos (copy-seq (send (car tc) :worldpos))
	   ;; :cog-thre 10
	   :debug-view :no-message)
     (send self :show-collisions))
   )
  (:set-motion-number
   (&rest msg)
   (let ((v (send motion-number-item :value)))
     (when (numberp (setq motion-number (read-from-string v)))
       (setq motion-number (round motion-number))
       (format t ";; motion number=~S~%" motion-number)
       (send self :write-pose-list))))
  (:set-motion-name
   (&rest msg)
   (when (stringp (setq motion-name (send motion-name-item :value)))
     (format t ";; motion name=~S~%" motion-name)
     (send self :write-pose-list)))
  (:pose-save-file
   (&rest msg)
   (let ((v (format nil "poses/~A" (send save-item :value))))
     (unix:mkdir "poses")
     (user::dump-object v pose-list)
     (format t ";; pose-save-file v=~S~%" v)))
  (:pose-load-file
   (&rest msg)
   (let ((v (format nil "poses/~A" (send save-item :value))))
     (cond
      ((probe-file v)
       (setq pose-list (with-open-file (f v :direction :input) (read f)))
       (format t ";; pose-load-file v=~S~%" v))
      (t (format t ";; pose-load-file no file=~A.~%" v)))))
  ;;
  (:pose-menu
   (&rest msg)   
   (send self :show-collisions)
   (format t ";; pose-list-index=~A length of pose-list=~A~%"
	   pose-list-index (length pose-list)))
  (:pose-next
   (&rest msg)
   (when (and pose-list pose-list-index (< pose-list-index (length pose-list)))
     (unless (>= pose-list-index (length pose-list)) 
       (setq pose-list-index (1+ pose-list-index)))
     (send robot :angle-vector (car (elt (reverse pose-list) pose-list-index))))
   (send self :pose-menu))
  (:pose-previous
   (&rest msg)
   (when (and pose-list pose-list-index (< pose-list-index (length pose-list)))
     (unless (> pose-list-index 0)
       (setq pose-list-index (1+ pose-list-index)))
     (send robot :angle-vector (car (elt (reverse pose-list) pose-list-index)))
     )
   (send self :pose-menu))
  (:pose-replace
   (&rest msg)
   (format t ";; pose-replace msg=~A~%" msg)
   )
  (:pose-start
   (&rest msg)
   (cond
     (pose-list
      (send robot :angle-vector (caar (last pose-list)))
      (setq pose-list-index 0)
      )
     (t (format t ";; press push before! pose-list len=~A~%" (length pose-list)))       )
   (send self :pose-menu))
  (:pose-end
   (&rest msg)
   (cond
     (pose-list
      (send robot :angle-vector (caar pose-list))
      (setq pose-list-index (1- pose-list))
      )
     (t (format t ";; press push before! pose-list len=~A~%" (length pose-list))))       
   (send self :pose-menu))
  (:pose-print
   (&rest msg)
   (print pose-list)
   (send self :pose-menu))
  (:pose-clear
   (&rest msg)
   (setq pose-list nil)
   (setq pose-list-index nil)
   (send self :pose-menu))
  (:pose-push
   (&rest msg)
   (push (list (copy-object (send robot :angle-vector)) time) pose-list)
   (setq pose-list-index (1- (length pose-list)))
   (send self :pose-menu))
  (:pose-pop
   (&rest msg)
   (pop pose-list)
   (if (null pose-list) (setq pose-list-index nil)
       (setq pose-list-index (1- (length pose-list))))
   (send self :pose-menu))
  (:pose-animate
   (&rest msg)
   (dolist (avt (reverse pose-list))
     (send robot :angle-vector (car avt))
     (unix::usleep (* (cadr avt) 10 1000))
     (send self :show-collisions))
   (send self :pose-menu))
  (:play-pose-list
   (&rest msg)
   (dolist (avt (reverse pose-list))
     (send robot :angle-vector (car avt))
     (send robot :send-to-ri (cadr avt)) ;; time
     ))
  (:write-pose-list
   (&rest msg)
   (when (and pose-list (> 120 motion-number -1))
     (send robot :ri :flush-codes)
     (dolist (avt (reverse pose-list))
       (send robot :ri :push-servo-command (car avt) (cadr avt)))
     (send robot :ri :write-codes-to-motion-table motion-number :flush nil)
     ;;motionmenubar
     (let* ((mi (elt (send motionmenubar :items) (/ motion-number 30)))
	    (items (reverse (send (mi . menu-window) :items))))
       (send (elt items (mod motion-number 30)) :label
	     (format nil "~A length= ~A motion-name= ~A " motion-number (length pose-list) motion-name)))
     ))
  (:call-pose-list
   (&rest msg)
   (send robot :ri :call-motion motion-number))
  (:pose-store
   (&rest msg)
   (user::dump-object "dumped-pose-list" pose-list)
   (send self :pose-menu))
  (:pose-load
   (&rest msg)
   (if (probe-file "dumped-pose-list")
       (setq pose-list (with-open-file (f "dumped-pose-list" :direction :input) (read f)))
       (format t ";; press store button before load!~%"))
   (send self :pose-menu))
  ;;
  (:dual-move
   (obj val)
   (format t ":dual-move obj=~A val=~A~%" obj val)
   (case val
     (0 (setq mirror-flag :mirror))
     (1 (setq mirror-flag :same))
     (2 (setq mirror-flag :minus))
     (3 (setq mirror-flag nil))))
  (:slider-time
   (obj val)
   (setq time (round val)))
  (:show-collisions (&rest msg &aux cols)
		    (setq cols (send robot :show-collisions))
		    (send robot :move-on-ground)
		    (if (and sync-mode (null cols)) (send robot :send-to-ri time))
		    )
  (:toggle-sync
   (&rest msg)
   (cond
     (sync-mode
      (setq sync-mode nil)
      (send (car msg) :label "sync to on ")
      (send (car msg) :color (send self :color))
      )
     (t (setq sync-mode t)
	(send (car msg) :label "sync to off")))
   )
  ;;
  (:send-to-ri ;; robot-control-panel
   (&rest msg)
   (send robot :send-to-ri time))
  (:read-from-ri (&rest msg)
		 (format t "msg :name=~A~%" (get (car msg) :name))
		 (send robot :ri :robot :angle-vector (send robot :ri :read-angle-vector))
		 (send robot :ri :viewer :draw-objects :flush t)
		 )
  (:copy-from-ri (&rest msg)
		 (send self :read-from-ri)
		 (let ((rv (send robot :ri :robot :angle-vector))
		       (tv (send robot :ri :robot :joint-list :joint-type)))
		   (dotimes (i (length rv))
		     (if (equal :wheel (elt tv i)) (setf (elt rv i) 0)))
		   (send robot :angle-vector rv))
		 (send (get robot :viewer) :draw-objects :flush t)
		 )
  (:project-write-to-rom (&rest msg) (send robot :ri :write-project-to-rom-table))
  (:read-rom-table
   (&rest msg)
   (send robot :ri :read-rom-table)
   (setq rom-table (send robot :ri :rom-table))
   ;;(send (elt rom-table (+ (* 30 j) i)) :name))
   (let ((rommenus (reverse (send rommenubar :items)))) ;; 4 menu-button-items
     (dotimes (j (length rommenus))
       (let ((items (reverse (send ((elt rommenus j) . menu-window) :items)))) ;; 30 button-items
	 (dotimes (i 30)
	   (send (elt items i) :label
		 (format nil "~A ~60A button= ~40A" (string (+ (* 30 j) i))
			 (if (elt rom-table (+ (* 30 j) i))
			     (send (elt rom-table (+ (* 30 j) i)) :name))
			 (if (elt rom-table (+ (* 30 j) i))
			     (cddr (send (elt rom-table (+ (* 30 j) i)) :buttondata)))
			 )))))
     )
   )
  ;;
  (:create-remocon-view
   (&rest msg)
   (unless remocon-view (setq remocon-view (user::kxr-remocon-view)))
   (send remocon-view :redraw))
  (:jump-vector-flag (&rest msg) (format t ";; :jump-vector-flag = ~A~%" (send robot :ri :jump-vector-flag)))
  (:jump-vector-on (&rest msg) (send robot :ri :jump-vector-flag t) (send self :jump-vector-flag))
  (:jump-vector-off (&rest msg) (send robot :ri :jump-vector-flag nil) (send self :jump-vector-flag))
  (:remocon-play-project
   (&rest msg)
   (send self :create-remocon-view)
   (send robot :ri :emulate-motion-code 
	 (send robot :ri :project-file :motion-table
	       :button-mc (send remocon-view :buttoncmd))
	 :copy-viewer remocon-view :send-to-ri sync-mode))
  (:remocon-play-rom
   (&rest msg)
   (send self :create-remocon-view)
   (send robot :ri :emulate-motion-code 
	 (send rom-table
	       :button-mc (send remocon-view :buttoncmd))
	 :send-to-ri sync-mode))
  (:remocon-show
   (i &rest msg)
   (format t ":remoconshow i=~A label=~A~%" i (elt jvectors (car i)))
   (send robot :ri :emulate-motion-code 
	 (send robot :ri :project-file :motion-table
	       :button-mc (cdddr (assoc :button (elt jvectors (car i)))))
	 :copy-viewer remocon-view :send-to-ri sync-mode))
  (:remocon-teach
   (&rest msg)
   (send self :create-remocon-view)
   (format t ";; :teach motion-number=~A~%" motion-number)
   (send robot :ri :rcb4machine :motion-table
	 :set-button-motion (send remocon-view :buttoncmd) motion-number)
   (send robot :ri :set-motion-button motion-number (send remocon-view :buttoncmd))
   (send self :write-to-flash)
   )
  (:write-to-flash
   (&rest msg)
   (send robot :ri :write-to-flash)
   )
  ;;
  (:start-project-file
   (&rest msg)
   (if (null project-mcodes) (send self :reset-project-file))
   (setq loop-project t)
   (while (and project-mcodes loop-project)
     (send robot :ri :emulate-motion-code (pop project-mcodes) :send-to-ri sync-mode)
     (x::window-main-one)
     (unix::usleep (* 100 1000))))
  (:stop-project-file (&rest msg) (setq loop-project nil))
  (:reset-project-file
   (&rest msg) (setq project-mcodes (send robot :ri :project-file :mcodes "")))
  ;;
  (:start-rom-table
   (&rest msg)
   (if (null rom-mcodes) (send self :reset-rom-table))
   (setq loop-rom t)
   (while (and rom-mcodes loop-rom)
     (send robot :ri :emulate-motion-code (pop rom-mcodes) :send-to-ri sync-mode)
     (x::window-main-one)
     (unix::usleep (* 100 1000))))
  (:stop-rom-table (&rest msg) (setq loop-rom nil))
  (:reset-rom-table
   (&rest msg)
   (setq rom-mcodes (coerce (send robot :ri :rom-table) cons)))
  ;;
  (:timer-on (&rest msg) (send robot :ri :timer-on))
  (:timer-off (&rest msg) (send robot :ri :timer-off))
  (:free-all (&rest msg) (send robot :ri :free-all))
  (:free-arms (&rest msg) (send robot :ri :free :arms))
  (:free-larm (&rest msg) (send robot :ri :free :larm))
  (:free-rarm (&rest msg) (send robot :ri :free :rarm))
  (:free-lgripper(&rest msg) (send robot :ri :free :larm-gripper-r))
  (:free-rgripper(&rest msg) (send robot :ri :free :rarm-gripper-r))
  (:free-legs (&rest msg) (send robot :ri :free :legs))
  (:free-lleg (&rest msg) (send robot :ri :free :lleg))
  (:free-rleg (&rest msg) (send robot :ri :free :rleg))
  (:free-head (&rest msg) (send robot :ri :free :head))
  (:free-head-y (&rest msg) (send robot :ri :free :head-neck-y))
  (:free-head-p (&rest msg) (send robot :ri :free :head-neck-p))
  (:free-leye (&rest msg) (send robot :ri :free :head-leye-y))
  (:free-reye (&rest msg) (send robot :ri :free :head-reye-y))
  (:free-torso (&rest msg) (send robot :ri :free :torso))
  (:free-torso-y (&rest msg) (send robot :ri :free :torso-chest-y))
  (:free-torso-p (&rest msg) (send robot :ri :free :torso-chest-p))

  (:hold-all (&rest msg) (send robot :ri :hold-all))
  (:hold-arms (&rest msg) (send robot :ri :hold :arms))
  (:hold-larm (&rest msg) (send robot :ri :hold :larm))
  (:hold-rarm (&rest msg) (send robot :ri :hold :rarm))
  (:hold-lgripper(&rest msg) (send robot :ri :hold :larm-gripper-r))
  (:hold-rgripper(&rest msg) (send robot :ri :hold :rarm-gripper-r))
  (:hold-legs (&rest msg) (send robot :ri :hold :legs))
  (:hold-lleg (&rest msg) (send robot :ri :hold :lleg))
  (:hold-rleg (&rest msg) (send robot :ri :hold :rleg))
  (:hold-head (&rest msg) (send robot :ri :hold :head))
  (:hold-head-y (&rest msg) (send robot :ri :hold :head-neck-y))
  (:hold-head-p (&rest msg) (send robot :ri :hold :head-neck-p))
  (:hold-leye (&rest msg) (send robot :ri :hold :head-leye-y))
  (:hold-reye (&rest msg) (send robot :ri :hold :head-reye-y))
  (:hold-torso (&rest msg) (send robot :ri :hold :torso))
  (:hold-torso-y (&rest msg) (send robot :ri :hold :torso-chest-y))
  (:hold-torso-p (&rest msg) (send robot :ri :hold :torso-chest-p))

  (:arm2-open (&rest msg) (send robot :ri :arm2-open))
  (:com-init (&rest msg) (send robot :ri :com-init))
  (:arm-open (&rest msg) (send robot :ri :arm-open))
  (:rcb4-open (&rest msg) (send robot :ri :com-init))
  (:reset-pose (&rest msg) (send robot :reset-pose)
	       (send self :show-collisions))
  (:neutral-pose (&rest msg) (send robot :neutral)
		 (send self :show-collisions))
  (:madgwick-calib (&rest msg) (send robot :ri :madgwick-calib))
  (:bvh-animate (&rest msg)
		(unless (fboundp 'user::animate) (load "bvh/bvh-demo.l"))
		(cond
		  ((null animate-flag)
		   (setq animate-flag t)
		   (user::animate))
		  (t (setq animate-flag nil)
		     (throw :animate nil))))
  ;;
  (:dyna-start
   (&rest args)
   ;;(user::dyna-on (send robot :ri :viewer))
   (user::dyna-on)
   (setq dworld user::*dworld*)
   (send dworld :soft-setting)
   (send dworld :start)
   )
  (:dyna-stop
   (&rest args)
   (send user::*dworld* :stop)
   (send user::*irtviewer* :objects (list user::*robot*))
   )
  )


(in-package "IMAGE")

(defmethod color-image
  (:halve
   (&optional (simage)) 	;512*512->256x256
   (let* ((swidth (/ (send self :width) 2))
	  (sheight (/ (send self :height) 2)))
     (if (null simage)
	 (setq simage (instance class :init swidth sheight)))
     ;;(halve-image self simage pixel-bytes)
     (halve-image self simage) ;; inaba 2018.11.16
     simage))
  (:double
   (&optional (simage)) 	;512*512->256x256
   (let* ((swidth (* (send self :width) 2))
	  (sheight (* (send self :height) 2)))
     (if (null simage)
	 (setq simage (instance class :init swidth sheight)))
     ;;(halve-image self simage pixel-bytes)
     (double-image self simage) ;; inaba 2018.11.16
     simage))
  (:convolve
   (&optional (c (make-array '(3 3) :element-type :byte
			     :initial-contents '((1 0 -1) (1 0 -1) (1 0 -1)))))
   (let ((j (copy-object self)))
     (convolve3 c 1 self j)
     j))
  )

(in-package "USER")

(setq *kxr100image*
      (image::read-image-file (format nil "~A/kxr100.png" *rcb4eus-dir*)))

(defun make-kxrviewer nil
  (setq *kxrviewer* (instance kxrviewer :create :name "kxrviewer"))
  (send *kxrviewer* :change-background (float-vector 1 0 0.5))
  )

(defun kxrobjects (&rest args) (send *kxrviewer* :objects args))

(defun kxr-remocon-view nil
  ;;(setq *kxrimage* (image::read-image-file "kxrl2w2l5a3h2.png"))
  ;;(setq *remocon-viewer* (make-irtviewer :name "Remocon"))

  ;;(setq *error-handler* #'kxr-error)
  (setq *kxr-remocon* (kxr-remocon))
  (setq *remocon-viewer* (instance kxrviewer :create :name "Remocon" :width 400 :height 400))
  (send (send *remocon-viewer* :viewer)
	:viewsurface :set-event-proc :buttonrelease-right :draw-event-right *remocon-viewer*)
  ;;(send (send *remocon-viewer* :viewer)
  ;;:viewsurface :set-event-proc :buttonrelease-middle :draw-event *remocon-viewer*)

  (send *remocon-viewer* :objects (list *kxr-remocon*))
  
  ;;(show-2d-arrange (list (kxr-servo-s3300)))
  (send *remocon-viewer* :change-background (float-vector 1 0 0.7))

  (send *remocon-viewer* :viewer :viewsurface :putimage	*kxr100image* :depth 24)

  (send *remocon-viewer* :viewpoint #f(-300 0 450))
  (send *remocon-viewer* :look1 #f(-50 0 0) 0 120)
  ;;(send *irtviewer* :viewer :viewsurface :getimage))
  ;;(image::write-image-file "test.pnm" img)
  (send *remocon-viewer* :draw-objects)
  *remocon-viewer*
  )

(defclass kxrviewer :super x::irtviewer
  :slots (pick-face-pos pick-facesets buttoncmd))

(defmethod kxrviewer ;; stop :move-coords-event method
    (:set-cursor-pos-event
   (event)
   (setq x::previous-cursor-pos (x::event-pos event))
   (send self :draw-objects)
   )
  (:move-coords-event
   (event)
   (if (null x::previous-cursor-pos)
       (setq x::previous-cursor-pos (x::event-pos event)))
   (send self :draw-objects)
   )
  (:buttoncmd nil buttoncmd)
  (:pick-face
   (spos objs)
   (let* ((eye (send self :viewer :viewing))
	  (vp (send self :viewer :viewport :screen-point-to-ndc spos)))
     (bodies-vector-limit-face-pos x::objects
				   (send eye :viewpoint)
				   (send eye :view-orient vp)
				   #'<)))
  (:string (x y str &optional ;;(fid x::font-helvetica-bold-12))
	      (fid x::font-a14))
	   (send-all x::subwindows :2d-mode)
	   ;;(gl::glxUseXfont fid 32 96 (+ 1000 32))
	   (gl::glxUseXfont fid 32 96 (+ 1000 32))
	   (gl::glRasterPos2i (round x) (- (send self :height) (round y)))
	   (gl::glListBase 1000)
	   (gl::glCallLists (length str) gl::GL_UNSIGNED_BYTE str)
	   (send-all x::subwindows :3d-mode)
	   (send self :flush)
	   )
  (:draw-event-right
   (event)
   (send self :draw-objects)
   (send self :draw-images)
   )
  (:draw-event
   (event)
   ;;(when (= (x::event-button event) 1) ;; left-button
   ;;(print (list self :draw-event event "event-button=" (x::event-button event)))
   (send self :pick-facesets)
   (send self :draw-objects)
   (send self :draw-images)
   )
  (:pick-facesets
   (&optional (objs (set-difference x::objects pick-facesets :test #'faceset-equal)))
   (let (remove-facesets pick-face pick-faceset)
     (when (setq pick-face-pos
		 (send self :pick-face
		       (float-vector (elt x::previous-cursor-pos 0) (elt x::previous-cursor-pos 1) 0)
		       objs))
       (setq pick-face (car pick-face-pos))
       (dolist (pfs pick-facesets)
	 (if (member pick-face (send pfs :faces) :test #'user::face-equal)
	     (pushnew pfs remove-facesets :test #'user::faceset-equal)))
       (cond
	 (remove-facesets
	  (setq pick-facesets (set-difference pick-facesets remove-facesets :test #'user::faceset-equal))
	  (setq remove-facesets nil)
	  )
	 (t
	  (setq pick-faceset (instance faceset :init :faces (list pick-face)))
	  (send pick-faceset :set-color :red)
	  (pushnew pick-faceset pick-facesets :test #'user::faceset-equal))
	 ))
     (setq objs (remove-if-not #'(lambda (x) (derivedp x body)) (send self :objects)))
     (send self :objects (union pick-facesets objs :test #'user::faceset-equal))
     (send self :draw-objects)))
  (:draw-images
   (&aux objs im)
   (setq objs (remove-if-not #'(lambda (x) (derivedp x body)) (send self :objects)))
   (setq buttoncmd nil)
   (dolist (pfs pick-facesets)
     (dolist (o objs)
       (dolist (h (get o :holes))
	 (when (and h (elt h 4) (member (elt h 4) (send pfs :faces) :test #'user::face-equal))
	   (setq buttoncmd (union (elt h 0) buttoncmd))
	   (send self :format-at-3dpos (cadr (send (car (send pfs :faces)) :centroid))
		 "~A" (elt h 0))))))
   ;; (let ((2dpos
   ;;(send self :viewer :point-to-screen (cadr (send (car (send pfs :faces)) :centroid)))))
   ;;(send self :string (round (elt 2dpos 0)) (round (elt 2dpos 1))
   ;;(format nil "~A" (elt h 0))))
   (send self :string 105 20 (format nil ":draw-event ~A" x::previous-cursor-pos))
   (send self :string 105 60 (format nil "~A" (car pick-face-pos)))
   (send self :string 105 80 (format nil "~A" (cadr pick-face-pos)))
   (send self :string 5 100 (format nil "button = ~A" buttoncmd))
   (when (boundp '*ri*)
     ;;(format t ";; motion=~A~%" (send *ri* :project-file :motion-table :button-mc buttoncmd))
     (send self :string 5 150
	   (format nil "motion = ~A"
		   (send (send *ri* :project-file :motion-table :button-mc buttoncmd) :name)
		   )))
   (cond
     ((boundp 'user::*ri*)
      (setq im (send (send user::*ri* :viewer) :viewer :viewsurface :getglimage))
      #|
      (unwind-protect
      (catch
      :kxr-exit
      (setq im (send im :halve))
      (setq im (send im :convolve))
      ;;(error 10 "abc")
      )
      (format t ";; unwind :halve~%")
      )
      (send self :viewer :viewsurface :putimage im :depth 24)
      |#
      )
     (t 
      ;;(send self :viewer :viewsurface :putimage user::*kxr100image* :depth 24)
      (send self :viewer :viewsurface :putimage user::*kxr100image* :depth 24)
      ))
   #|
   (when (and (boundp 'user::*ri*) buttoncmd)
   (catch :loop
   (dolist (mc (send user::*ri* :project-file :mcodes))
   (when (user::set-equal buttoncmd (send mc :buttoncmd))
   (send user::*ri* :emulate-motion-code mc :loopmax 200 :copy-viewer *remocon-viewer*)
   (send user::*ri* :emulate-motion-code mc :send-to-ri sync-mode)
   (throw :loop nil)))))
   |#
   )
  )

(defun kxr-error (code msg &rest args)
  (format nil "code=~A, msg=~A, args:~A~%" code msg args)
  (throw :kxr-exit msg)
  )

;;;
(defun kxr-remocon nil
  (let* ((bod (make-cube 55 160 30))
	 (psbutton (make-cube 25 10 20))
	 (powerbutton  (make-cube 15 7 20))
	 (fbbutton  (make-cube 10 5 20))
	 (lrbutton  (make-cube 5 10 20))
	 (cbutton1  (make-cylinder 25 20))
	 (cbutton2  (make-cylinder 20 40))
	 (shiftbutton  (make-cube 10 30 7))
	 (cyl-  (make-cube 20 8 20))
	 (buttons1 (list
		    (list '(:l-shift-u) #f(-30 -60 7) :-x shiftbutton nil)
		    (list '(:l-shift-d) #f(-30 -60 -7) :-x shiftbutton nil)
		    (list '(:r-shift-u) #f(-30  60 7) :-x shiftbutton nil)
		    (list '(:r-shift-d) #f(-30  60 -7) :-x shiftbutton nil)
		    
		    (list '(:l-fore :l-back :l-right :l-left) #f(0 -15 10) :z psbutton nil)
		    (list '(:r-fore :r-back :r-right :r-left) #f(0  15 10) :z psbutton nil)
		    
		    (list '(:l-fore) #f(-8  -50 10) :z fbbutton nil)
		    (list '(:l-back   ) #f( 8  -50 10) :z fbbutton nil)
		    (list '(:l-right  ) #f( 0  -42 10) :z lrbutton nil)
		    (list '(:l-left   ) #f( 0  -58 10) :z lrbutton nil)
		    
		    (list '(:r-fore) #f(-8   50 10) :z fbbutton nil)
		    (list '(:r-back   ) #f( 8   50 10) :z fbbutton nil)
		    (list '(:r-right  ) #f( 0   58 10) :z lrbutton nil)
		    (list '(:r-left   ) #f( 0   42 10) :z lrbutton nil)
		    ))
	 (buttons2
	  (list
	   (list '(:l-fore :l-left)
		 (float-vector (* 22.5 (sin (deg2rad -135)))
			       (- (* 22.5 (cos (deg2rad -135))) 50) 0)
		 :z nil nil)
	   (list '(:l-fore :l-right)
		 (float-vector (* 22.5 (sin (deg2rad -45)))
			       (- (* 22.5 (cos (deg2rad -45))) 50) 0)
		 :z nil nil)
	   (list '(:l-back :l-left)
		 (float-vector (* 22.5 (sin (deg2rad 135)))
			       (- (* 22.5 (cos (deg2rad 135))) 50) 0)
		 :z nil nil)
	   (list '(:l-back :l-right)
		 (float-vector (* 22.5 (sin (deg2rad 45)))
			       (- (* 22.5 (cos (deg2rad 45))) 50) 0)
		 :z nil nil)
	   ;;;
	   (list '(:r-fore :r-left) 
		 (float-vector (* 22.5 (sin (deg2rad -135)))
			       (+ (* 22.5 (cos (deg2rad -135))) 50) 0)
		 :z nil nil)
	   (list '(:r-fore :r-right)
		 (float-vector (* 22.5 (sin (deg2rad -45)))
			       (+ (* 22.5 (cos (deg2rad -45))) 50) 0)
		 :z nil nil)
	   (list '(:r-back :r-left)
		 (float-vector (* 22.5 (sin (deg2rad 135)))
			       (+ (* 22.5 (cos (deg2rad 135))) 50) 0)
		 :z nil nil)
	   (list '(:r-back :r-right)
		 (float-vector (* 22.5 (sin (deg2rad 45)))
			       (+ (* 22.5 (cos (deg2rad 45))) 50)  0)
		 :z nil nil))
	  )
	 cyl buttons)
    
    (setq cyl (body- cbutton1 cbutton2))
    (send cyl- :locate #f(-22 0 20) :world)
    (setq cyl (body- cyl cyl-))
    (send cyl- :locate #f(22 0 20) :world)
    (setq cyl (body- cyl cyl-))
    (send cyl- :rotate pi/2 :z :world)
    (send cyl- :locate #f(0 -22 20) :world)
    (setq cyl (body- cyl cyl-))
    (send cyl- :locate #f(0 22 20) :world)
    (setq cyl (body- cyl cyl-))

    (send cyl :locate #f(0 -50 0) :world)
    (setq bod (body+ bod cyl))
    (send cyl :locate #f(0 50 0) :world)
    (setq bod (body+ bod cyl))

    (setq buttons (append buttons1 buttons2))
    (dolist (b buttons)
      ;;    (list '(:l-fore) #f(-8  -50 10) :z fbbutton nil)
      (let ((bbody (elt b 3)) fp)
	(when bbody
	  (send bbody :locate (cadr b) :world)
	  (setq bod (body+ bod bbody)))
	(setq fp
	      (bodies-vector-limit-face-pos (list bod) (cadr b)
					    (axis2vector (caddr b)) ;; :-x, :z
					    ))
	(setf (cadr b) (cadr fp))  ;; pos
	(setf (elt b 4) (car fp))  ;; face
	))
    (send bod :name "remocon")
    (kxr-assoc-holes bod buttons)
    bod))

;;;
;;; 2020.2.19
;;;

(in-package "X")

(defun kxr-robot-type (nm &optional (nm-head "kxrl2"))
  (let ((hlen (length nm-head)))
    (or
     (and (stringp nm) (>= (length nm) hlen)
	  (string-equal nm-head (subseq nm 0 hlen)))
     (and (listp nm)
	  (some #'(lambda (n)
		    (and (stringp n) (>= (length n) hlen)
			 (string-equal nm-head (subseq n 0 hlen))))
		nm)))))

(defclass kxr-model-panel :super panel
  :slots (robot kxrmenu textitem
		kxr-create-func options
		configs
		build-buttons
		part-viewer))

(defmethod kxr-model-panel
    (:kxr-type
     (bitem)
     ;;(format t ";; kxr-type args=~A~%" bitem)
     (setq kxr-create-func (read-from-string (send bitem :label))))
  (:create ;; kxr-model-panel
   (&rest args &key (width 1100) &allow-other-keys)
   (let (nm i config)
     (send-super* :create :title "kxr robot creator" :width width :height 460 args)
     (setq textitem (send-super :create-item text-item "robot name" self
				:make-kxr-robot
				:initial-value "kxrl2w2l5a4h2" :columns 80 :font font-a14))
     (send-super :create-item button-item "quit" self :quit)
     (send-super :create-item button-item "copy to *robot*" self :copy-to-robot)
     (send-super :create-item button-item "create ri" self :create-ri)
     (send-super :create-item button-item "listup bodies" self :listup-bodies)
     ;;(send-super :create-item button-item "listup links" self :listup-links)
     (send-super :create-item button-item "draw links" self :show-2d-links)

     (send self :create-2D-part-menu-buttons "select body" :select-part-button
	   (user::kxr-scan-all-bodies))
     (send self :create-2D-part-menu-buttons "select bodyset" :select-part-button
	   (user::kxr-scan-all-bodysets))
     (send self :create-2D-part-menu-buttons "select link" :select-part-button
	   (user::kxr-scan-all-links))
     (send self :create-2D-robot-menu-buttons "select robot" :select-config-button)
     
     (setq configs (user::kxr-all-configs))
     (setq build-buttons nil)
     (send-super :create-item button-item "kxr build" self :kxr-build-button :border-width 2)     
     (setq i 1)
     (dolist (c configs)
       (push (send-super :create-item choice-item
			 (format nil " (~A) ~A " i (car c))
			 self (car c)
			 ;;:button-size 10
			 :border-width 1
			 :choices
			 (mapcar #'(lambda (x) (format nil " ~A " x))
				 (cons nil (cdr c))))
	     build-buttons)
       (setq i (1+ i)))
     (setq build-buttons (reverse build-buttons))
     (send self :select-config-by-name "kxrl2w2l5a4h2")
     self))
  (:create-2D-part-menu-buttons
   (label method configs &rest args &key (height 30) (width 700) (color *maroon*) (rows 20)
	  (border-width 2) (font (font-id "*-fixed-bold-r-normal-*-18-*")) &allow-other-keys)
   (let* ((bar (send self :create-menubar :height height :width width))
	  ;;(instance* menubar-panel :create :font font :map nil :parent self args))
	  (len (length configs))
	  (cols (ceiling (/ len (float rows))))
	  (menus (instantiate vector cols))
	  )
     (send self :locate-item bar)
     (dotimes (j cols)
       (setf (elt menus j) 
	     (instance menu-panel :create :font font :color color))
       (dotimes (i rows)
	 (when (< (+ i (* rows j)) (length configs))
	   (send (elt menus j) :create-item button-item
		 (format nil " (~A) ~50A " (+ i (* rows j))
			 (elt configs (+ i (* rows j))))
		 self (list method (elt configs (+ (* rows j) i)))
		 :font font)))
       (send bar :create-item menu-button-item
	     (format nil " ~A ~A- " label (* rows j))
	     self nil :menu (elt menus j) :border-width border-width)
       )
     bar)
   )
  (:create-2D-robot-menu-buttons
   (label method
	  &optional (rows 20)
	  (configs user::*kxr-body-config-alist*)
	  &rest args &key (height 30) (width 1100) (color *maroon*)
	  (border-width 2)
	  (font (font-id "*-fixed-bold-r-normal-*-18-*")) &allow-other-keys)
   (let* ((bar (send self :create-menubar :height height :width width))
	  ;;(instance* menubar-panel :create :font font :map nil :parent self args))
	  (len (length configs))
	  (cols (ceiling (/ len (float rows))))
	  (menus (instantiate vector cols))
	  )
     (send self :locate-item bar)
     (dotimes (j cols)
       (setf (elt menus j) 
	     (instance menu-panel :create :font font :color color))
       (dotimes (i rows)
	 (when (< (+ i (* rows j)) (length configs))
	   (send (elt menus j) :create-item button-item
		 (format nil " (~A) ~60A " (+ i (* rows j))
			 (car (elt configs (+ i (* rows j)))))
		 self (list method (elt configs (+ (* rows j) i)))
		 :font font)))
       (send bar :create-item menu-button-item
	     (format nil " ~A ~A- " label (* rows j))
	     self nil :menu (elt menus j) :border-width border-width)
       )
     bar)
   )
  (:kxr-build-button (button) (send self :kxr-build))
  (:kxr-build
   ()
   (let* ((choices build-buttons)
	  (funcname 'user::kxr-robot)
	  (funcarg
	   (mapcan #'(lambda (c)
		       (let* ((s (make-string-input-stream (send c :name)))
			      (num (read s)) ;; (number)
			      (key (read s))
			      (value
			       (read-from-string
				(elt (mapcar #'car (c . choice-list))
				     (send c :value)))))
			 (if value (list key value)
			     ;;(list key nil)
			     )))
		   choices))
	  (config-name (user::kxr-config-name funcarg))
	  cpanel
	  vwer)
     ;;(format t ";; funcarg=~A, config-name=~A~%" funcarg config-name)
     (when robot
       (if (send robot :ri)
	   (send robot :delete-ri))
       (if (setq cpanel (send robot :control-panel))
	   (send cpanel :quit))
       (setq vwer  (send robot :viewer)))
     ;;
     (setq robot (apply funcname funcarg))
     (setf (get robot :config) funcarg)
     (send robot :name (send robot :config-name))
     (unless (derivedp vwer x::irtviewer) (send robot :create-viewer))
     (send robot :viewer :change-background (float-vector 0 0.9 0.7))
     ;;(send robot :viewer :draw-objects)
     (send robot :draw-collision)
     )
   )
  (:make-kxr-robot ;; textitem's method
   (&rest args)
   (let ((value (read-from-string (send textitem :value)))
	 nm config)
     (if (consp value) (setq value (car value)))
     (setq nm (string-downcase (string value)))
     ;;
     (setq robot (user::kxr-make-robot nm))
     ;;
     (setq config  (user::kxr-body-config nm))
     (send self :select-config config)
     (setf (get robot :config) config)
     (send robot :viewer :objects (list robot))
     ;;(send robot :viewer :draw-objects)
     (send robot :draw-collision)
     ))
  (:set-config-to-choice-items
   (config) ;; (:type :l2 ....)
   (let* ((choice-items build-buttons)
	  (clist (user::plist-to-alist config))
	  )
     (dolist (ci choice-items)
       (let ((st (make-string-input-stream (send ci :name)))
	     i il k v)
	 (setq il (read st)) ;; (index)
	 (setq k (read st))
	 (cond
	   ((setq v (assoc k clist))
	    (setq v (cadr v))
	    (setq i (position v (ci . choice-list)
			      :key #'(lambda (x) (read-from-string (car x)))
			      :test #'equal))
	    (send ci :value i))
	   (t (send ci :value 0)))))
     )
   )
  (:choice-item-index-old
   (key value choice-items)
   (dolist (ci choice-items)
     (let ((st (make-string-input-stream (send ci :name)))
	   i il k v)
       (setq il (read st)) ;; (index)
       (when
	   (equal key (setq k (read st)))
	 (setq i (position value (ci . choice-list)
			   :key #'(lambda (x) (read-from-string (car x)))
			   :test #'equal))
	 (send ci :value i))))
   )
  (:copy-to-robot
   (value &optional obj)
   (setq user::*robot* robot))
  (:listup-bodies
   (value &optional obj)
   (pprint (send robot :listup-function-name :bodies)))
  (:listup-links
   (value &optional obj)
   (pprint (send robot :listup-function-name :links)))
  (:create-ri  ;; kxr-model-panel
   (value &optional obj)
   (send robot :create-ri)
   (send robot :create-control-panel)
   ;;(send robot :viewer :draw-objects)
   (send robot :draw-collision)
   )
  (:select-part-button ;; 2d-menu-buttons method
   (value &optional obj)
   (let* ((nm (car value)) part)
     (unless part-viewer
       (setq part-viewer (user::make-irtviewer :width 400 :height 400)))
     ;;
     (send part-viewer :title (format nil "~A" nm))
     (setq part (apply nm nil))
     (format t ";; part name=~A~%" (send part :name))
     (user::objects+ (list part) :viewer part-viewer)
     ;;(send part-viewer :objects (list part))
     ;;(send part-viewer :look-all)
     )
   )
  (:show-2d-links
   (value &optional obj)
   (let* ((lks (send robot :listup-function-name :links))
	  (ls (mapcar #'(lambda (x) (cons (caar x) (cdr x))) lks))
	  parts)
     (unless part-viewer (setq part-viewer (user::make-irtviewer :width 400 :height 400)))
     ;;
     (send part-viewer :title "links")
     (dolist (l ls)
       (dotimes (i (cdr l))
	 (push (apply (car l) nil) parts)))
     ;;(setq parts (reverse parts))
     ;;(setq parts (mapcar #'(lambda (x) (apply x nil)) ls))
     (user::show-2d-arrange parts :n 5 :viewer part-viewer
			    :base nil :des nil :prop nil :xs 200 :ys 200)
     ;;(send part-viewer :objects (list part))
     ;;(send part-viewer :look-all)
     )
   )
  (:select-config-button ;; 2d-menu-buttons method -> require robot-config
   (value &optional obj)
   (send self :select-config (car value))
   )
  (:select-config-by-name
   (nm)
   (send self :select-config (user::kxr-body-config nm)))
  (:select-config
   (robot-config)
   (let* ((nm (car robot-config))
	  (config (cadr robot-config))
	  (servos (caddr robot-config)))
     (send textitem :value (format nil "~A" nm))
     (if (consp nm) (setq nm (car nm)))
     ;;(user::make-kxr-robot nm)
     (send self :set-config-to-choice-items config)
     (send self :kxr-build)
     )
   )
  )

(in-package "USER")

(format t "; (kxr-remocon-view) ; remocon button to :emulate-motion-code in project-file~%")

(provide :kxrviewer)

