;;;
;;; 2021.3.22 add make-chamfer-cube, make-fillet-cube
;;;
(provide :utils)

(defun string-underscored (str)
  (dotimes (i (length str))
    (if (= (elt str i) #\-) (setf (elt str i) #\_)))
  str)

(defun objects+ (blist &key base (des t) show-name
		       (coords t) (prop t) ((:viewer vwer)) &allow-other-keys)
  (let ((bs blist))
    (if (or coords base)
	(setq bs
	      (append bs
		      (mapcar #'(lambda (x)
				  (let ((c (make-cascoords :pos (send x :worldpos)
							   :rot (send x :worldrot))))
				    (send x :assoc c)
				    (send c :put :size 60)
				    (send c :put :color #f(1 0 0))
				    (send c :put :width 10)
				    c))
			      blist))))
    (if (or coords des)
	(setq bs
	      (append
	       bs
	       (mapcan #'(lambda (b)
			   (remove-if-not
			    #'(lambda (x) (memq (class x) (list cascaded-coords kxr-hole)))
			    (send b :descendants)))
		       blist))))
    (if prop
	(setq bs
	      (append
	       bs
	       (mapcan #'(lambda (b)
			   (mapcan
			    #'(lambda (x)
				(when (memq (class (cdr x)) (list cascaded-coords kxr-hole))
				  (list (cdr x))))
			    (send b :plist)))
		       blist))))
    (cond
     (vwer
      (send vwer :objects bs)
      (send vwer :look-all)
      (when show-name
	(dolist (b bs) 
	  (if (send b :name) (send vwer :format-at-3dpos (send b :worldpos) "~A" (send b :name)))))
      )
     (t (objects bs)
	(when show-name
	  (dolist (b bs) 
	    (if (send b :name)
		(send *irtviewer* :format-at-3dpos (send b :worldpos) "~A" (send b :name))))
	  )))
    ;; red: base
    ;; yellow: :joint-coord   #f(1 1 0) in bodyset in kxrbodyset.l, link in kxrlinks.l
    ;; purple: :origin-coord  #f(1 0 1)
    ;; white:  :prop :neck, :larm, :rarm
    ;; green:  holes
    ;; blue:   :joint-coord #f(0 0 1) in kxr-body, kxrbody.l
    ))

(defmethod robot-model
  (:walk-motion-single-support
   (&key (step-height 5) (scale 0.5)
	 (footstep-list
	  (list (make-coords :coords (send self :rleg :end-coords :copy-worldcoords) :name :rleg)
		(make-coords :coords (send (send self :lleg :end-coords :copy-worldcoords)
					   :translate (scale scale #f(0 0 0))) :name :lleg)
		(make-coords :coords (send (send self :rleg :end-coords :copy-worldcoords)
					   :translate (scale scale (float-vector 0 0 step-height))) :name :rleg)
		)))
   (send self :reset-pose)
   (send self :fix-leg-to-coords (make-coords))
   (send self :move-centroid-on-foot :rleg '(:rleg :lleg))
   (objects (list self))
   ;;(objects (append (list robot) footstep-list))
   ;; Start : COG is above the right foot.
   ;; End : COG is above the left foot.
   (send self :calc-walk-pattern-from-footstep-list
	 footstep-list :debug-view :no-message
	 :default-step-height step-height
	 :start-with-double-support nil
	 :end-with-double-support nil
	 :init-pose-function #'(lambda ()))
   )
  )

(defmethod bodyset-link
    (:detachable?
     (&aux (bs (send self :bodies)))
	(and
	 (find-if #'(lambda (b) (substringp "mag+" (send b :name))) bs)
	 (find-if #'(lambda (b) (substringp "mag-" (send b :name))) bs)))
  (:detach
   nil
   (when (detachable-link? self)
     (let* ((bs (send self :bodies))
	    (b0 (pop bs)) ret)
       (while bs
	 ;;(format t ";; b0:~A, (car bs):~A~%" b0 (car bs))
	 (when (and (substringp "mag+" (send b0 :name))
		    (substringp "mag-" (send (car bs) :name)))
	   (return-from :detach (kxr-link-create bs)))
	 (setq b0 (pop bs)))
       ))
   )
  )
(defun detachable-link? (arg)
  (and
   (derivedp arg bodyset-link)
   (send arg :detachable?)))

(defun detachable-links (arg)
  (cond
    ((null arg) nil)
    ((derivedp arg cascaded-link)
     (detachable-links (send arg :links)))
    ((detachable-link? arg) (list arg))
    ((consp arg)
     (append
      (detachable-links (car arg))
      (detachable-links (cdr arg))))))
(defmacro with-save-mp4 (fname &rest forms)
  `(let ()
     (send *irtviewer* :logging :clear)
     (send *irtviewer* :logging :start)
     ,@forms
     (send *irtviewer* :save-mpeg :fname ,fname :delay 1 :delete nil)
     (send *irtviewer* :logging :stop)
     (unix::system (format nil "convert ~A.mpg ~A.mp4" ,fname ,fname))
     ))

(defun calc-sec (a b) ;; a:from b:to
  (let (ans)
    (setq ans (+ (- (elt b 0) (elt a 0)) (+ (* 60 (- (elt b 1) (elt a 1))) (* 3600 (- (elt b 2) (elt a 2))))))
    )
  )

(defun rospack-find-roseus nil
  (unless (boundp '*roseus-dir*)
    #-:arm
    (setq *roseus-dir* (read-line (piped-fork "rospack find roseus") nil nil))
    #+:arm    
    (progn
      (setq *roseus-dir* (format nil "~A/roseus" *rcb4eus-dir*))
      (unless (probe-file *roseus-dir*)
	(setq *roseus-dir* (format nil "~A/ros_ws/src/jsk_roseus/roseus" (unix::getenv "HOME")))
	))
    )
  *roseus-dir*)
(defun roseus-dir (&optional (subdir ""))
  (format nil "~A/~A" (rospack-find-roseus) subdir))
(defun load-roseus nil
  (pushnew (roseus-dir "euslisp/") *load-path* :test #'equal)
  (load (roseus-dir "euslisp/roseus.l"))
  (load (roseus-dir "euslisp/eustf.l"))
  (load (roseus-dir "euslisp/actionlib.l"))
  (load (roseus-dir "euslisp/roseus-utils.l")))

(defun xwindow-ready? ()
  (and (member :xwindow *features*) (unix::getenv "DISPLAY")))
(defun find-named-coords (bod name &key (test #'substringp) (method :descendants))
  (cond
    ((null bod) nil)
    ((and (coordinates-p bod) (symbolp name) (coordinates-p (get bod name)) (get bod name)))
    ((derivedp bod cascaded-coords) (send bod :find-named-coords name :test test :method method))
    ((consp bod)
     (or (find-named-coords (car bod) name :test test :method method)
	 (find-named-coords (cdr body) name :test test :name method)))))
(defun make-chamfer-cube (xsize ysize zsize c &rest args)
  "MAKE-CHAMFER-CUBE x y z chamfer &key color name"
  (setq xsize (float xsize) ysize (float ysize) zsize (float zsize))
  (let* ((xsize/2 %(xsize / 2.0))
	 (x-c (- xsize/2 c))
	 (ysize/2 %(ysize / 2.0))
	 (y-c (- ysize/2 c))
	 (zsize/2 %(- zsize / 2.0))
	 (z-c (- zsize/2 c))
	 vlst b)
    (push (float-vector xsize/2 y-c zsize/2) vlst)
    (push (float-vector xsize/2 (- y-c) zsize/2) vlst)
    (push (float-vector x-c (- ysize/2) zsize/2) vlst)
    (push (float-vector (- x-c) (- ysize/2) zsize/2) vlst)
    (push (float-vector (- xsize/2) (- y-c) zsize/2) vlst)
    (push (float-vector (- xsize/2) y-c zsize/2) vlst)
    (push (float-vector (- x-c) ysize/2 zsize/2) vlst)
    (push (float-vector x-c ysize/2 zsize/2) vlst)
    (setq b (apply #'make-prism (reverse vlst) zsize
		   :primitive (list ':cube xsize ysize zsize)
		   args))
    (dolist (f (send b :get-face nil :side))
      (send f :id (append (send f :id) (list  (nth (nth 1 (send f :id))
						   '(:-x :-y :x :y))))))
    b))

(defun make-fillet-cube (xsize ysize zsize r &rest args
			 &key (segments 2) (corners (list 0 1 2 3))
			   &allow-other-keys)
  "MAKE-fillet-CUBE x y z fillet &key color name"
  (setq xsize (float xsize) ysize (float ysize) zsize (float zsize))
  (let* ((xsize/2 %(xsize / 2.0))
	 (x-c (- xsize/2 r))
	 (ysize/2 %(ysize / 2.0))
	 (y-c (- ysize/2 r))
	 (zsize/2 %(- zsize / 2.0))
	 (z-c (- zsize/2 r))
	 (theta (- (/ pi/2 segments)))
	 (rv (float-vector 0 r 0))
	 v vlst b)
    (setq segments (1+ segments))
    (cond
      ((member 0 corners)
       (setq v (float-vector x-c y-c zsize/2))
       (dotimes (i segments)
	 (push (v+ v (rotate-vector rv (* i theta) :z)) vlst)))
      (t (push (float-vector xsize/2 ysize/2 zsize/2) vlst)))
    ;;
    (cond
      ((member 1 corners)
       (setq rv (float-vector r 0 0))
       (setq v (float-vector x-c (- y-c) zsize/2))
       (dotimes (i segments)
	 (push (v+ v (rotate-vector rv (* i theta) :z)) vlst)))
      (t (push (float-vector xsize/2 (- ysize/2) zsize/2) vlst)))
    ;;
    (cond
      ((member 2 corners)
       (setq v (float-vector (- x-c) (- y-c) zsize/2))
       (setq rv (float-vector 0 (- r) 0))
       (dotimes (i segments)
	 (push (v+ v (rotate-vector rv (* i theta) :z)) vlst)))
      (t (push (float-vector (- xsize/2) (- ysize/2) zsize/2) vlst)))
    ;;
    (cond
      ((member 3 corners)
       (setq v (float-vector (- x-c) y-c zsize/2))
       (setq rv (float-vector (- r) 0 0))
       (dotimes (i segments)
	 (push (v+ v (rotate-vector rv (* i theta) :z)) vlst)))
      (t (push (float-vector (- xsize/2) ysize/2 zsize/2) vlst)))
    ;;
    (setq b (apply #'make-prism (reverse vlst) zsize
		   :primitive (list ':cube xsize ysize zsize)
		   args))
    (dolist (f (send b :get-face nil :side))
      (send f :id (append (send f :id) (list  (nth (nth 1 (send f :id))
						   '(:-x :-y :x :y))))))
    b))
#|
(defmethod object
    (:bodies
     ()
     (cond
       ((eq (class self) object) nil)
       ((consp self) (append (send (car self) :bodies) (send (cdr self) :bodies)))
       ((derivedp self body) (list self))
       ((send (class self) :method :bodies)
	(send self :bodies))
       (t nil)))
  )
|#
(defmethod cascaded-coords
    ;;(:all-descendants ()
    ;;(append descendants (send-all descendants :all-descendants)))
    (:all-descendants ()
     (append descendants (flatten (send-all descendants :all-descendants))))
  (:move-named-coords
   (from-name base name &optional angle axis
	      &aux fc)
   (cond
     ((setq fc (send self :find-named-coords from-name))
      (send self :move-coords
	    (send base :find-named-coords name)
	    fc)
      ;;(if angle (send self :rotate angle axis :local))
      (when angle
	(send self :dissoc fc)
	(send fc :assoc self)
	(send fc :rotate angle axis :local)
	(send fc :dissoc self)
	(send self :assoc fc))
      (send base :assoc self))
     (t (warn "self=~A :find-named-coords ~A is not found~%" self from-name)))
   self)
  (:find-named-objects
   (name &key (method :descendants) (test #'substringp))
   (remove-if-not #'(lambda (x) (funcall test name (string (send x :name))))
		  (send self method)))
  (:find-named-bodies (name) (send self :find-named-objects name :method :bodies))
  (:find-named-object
   (name &key (method :descendants) (test #'substringp))
   (find-if #'(lambda (x) (funcall test name (string (send x :name))))
	    (send self method)))
  (:find-named-coords (name &key (test #'substringp) (method :descendants))
		      (send self :find-named-object name :method method :test test))
  (:find-named-body (name) (send self :find-named-object name :method :bodies))
  (:find-body (name &rest args)
	      (forward-message-to (send self :find-named-body name) args))
  (:add-sensors
   (&rest args)
   (let* ((ladc 13)
	  (lps 5)
	  (hl 13.5)
	  (z 15)
	  (c (make-cascoords))
	  (imu (make-cascoords :name "imu" :pos (float-vector 4 1 (- 5 z)))) ;; to be updated
	  (ps (list (make-cascoords :name "ps0" :pos (float-vector  lps (- lps) 0))
		    (make-cascoords :name "ps1" :pos (float-vector (- lps) (- lps) 0))
		    (make-cascoords :name "ps2" :pos (float-vector (- lps) lps 0))
		    (make-cascoords :name "ps3" :pos (float-vector  lps lps 0))))
	  (adc (list (make-cascoords :name "adc0" :pos (float-vector ladc ladc 0))
		     (make-cascoords :name "adc1" :pos (float-vector ladc (- ladc) 0))
		     (make-cascoords :name "adc2" :pos (float-vector (- ladc) (- ladc) 0))
		     (make-cascoords :name "adc3" :pos (float-vector (- ladc) ladc 0))))
	  )
     (send c :assoc imu)
     (dolist (p ps) (send c :assoc p))
     (dolist (p adc) (send c :assoc p))
     (if args (send* c args))
     (send c :locate (send self :worldpos) :world)
     (dolist (a (send c :descendants))
       (send self :assoc a))
     ))
  )

(defun mkdir-unless (name) (unless (probe-file name) (unix::mkdir name)))
(defun system-format (&rest args)
  (apply #'format *error-output* args)
  (format *error-output* "~%")
  (unix::system (apply #'format nil args)))
(defun unlink-format (&rest args) (unix::unlink (apply #'format nil args)))

(defun rcb4eus-dir ()
  (if (boundp '*rcb4eus-dir*)  *rcb4eus-dir*
      (format nil "~A/prog/rcb4eus" (unix:getenv "HOME"))))

(defun rcb4eus-file (filename &key (dir (rcb4eus-dir)) (ext ""))
  (format nil "~A/~A~A" dir filename ext))

(defun rcb4eus-mkdir (dirname)
  (setq dirname (rcb4eus-file dirname))
  (unless (probe-file dirname) (unix::mkdir dirname))
  dirname)

(defun find-library (filename)
  (dolist (p (union *loader-current-directory* *load-path*
		    :test #'string=))
    (let ((path (concatenate-pathnames p filename)))
      (cond 
       ((probe-file (merge-pathnames ".so" path))
	(return-from find-library (merge-pathnames ".so" path)))
       ((probe-file (merge-pathnames ".l" path))
	(return-from find-library (merge-pathnames ".l" path))))
      nil)))

(defun assoc (item alist &key (key #'identity) (test #'equal))
  (cond
   ((null alist) nil)
   ((and (consp (car alist))
	 (funcall test item (funcall key (caar alist)))) (car alist))
   (t (assoc item (cdr alist) :key key :test test))))

(defun assocdr (k data &key (test #'equal) (key #'identity))
  (cdr (assoc k data :test test :key key)))

(defun classify-list (symlist &key (test #'equal) (key #'identity))
  (let (a ret)
    (dolist (s symlist)
      (if (setq a (assoc s ret :test test :key key))
	  (rplacd a (1+ (cdr a)))
	(push (cons s 1) ret)))
    ret))

(defun equivalent-classes (x &key (test #'equal) (key #'identity))
  (cond
   ((null x) nil)
   (t (equivalent-classes-aux
       (car x)
       (equivalent-classes (cdr x) :test test :key key)
       :test test :key key))))

(defun equivalent-classes-aux (a b &key (test #'equal) (key #'identity))
  (cond
   ((null b) (list a))
   ((intersection a (car b) :test test :key key)
    (equivalent-classes-aux (union a (car b) :test test :key key)
			    (cdr b) :test test :key key))
   (t (cons (car b)
	    (equivalent-classes-aux a (cdr b) :test test :key key)))))

(defun robot-gvar (name-str)
  (read-from-string (string-upcase (format nil "*~A*" name-str))))

(defmacro kxr-defun (fname args &rest fdef)
  `(progn
     (setq (',fname . function)
	   (cons
	    'lambda
	    (list
	     ',args
	     (list 'let (list (list 'rargs '',args)
			      (list 'return-value (cons 'progn ',fdef)))
		   (list 'when (list 'derivedp 'return-value 'propertied-object)
			 (list 'putprop 'return-value '',fname :create-function-name)
			 (list 'putprop 'return-value 'rargs :create-function-args))
		   'return-value))))
     (remprop ',fname 'builtin-function-entry)
     ',fname)
  )

(defun set-new-defun (&optional (func 'kxr-defun))
  (cond
   ((get 'defun :original-definition))
   (t
    (setf (get 'defun :original-definition) (symbol-function 'defun))
    (setf (symbol-function 'defun) (symbol-function func))
    )))

(defun reset-new-defun ()
  (when
      (get 'defun :original-definition)
    (setf (symbol-function 'defun) (get 'defun :original-definition))
    (setf (get 'defun :original-definition) nil)
    ))

(defun eq-memq (tag lst &key (test #'eq))
  (or (funcall test tag lst) (member tag lst :test test)))

(defun kxr-arm-limb? (l/r &optional (list '(:larm :rarm :lmarm :rmarm)))
  (eq-memq l/r list))
(defun kxr-leg-limb? (l/r &optional (list '(:lleg :rleg :lleg0 :rleg0 :lleg1 :rleg1 :lleg2 :rleg2)))
  (eq-memq l/r list))
(defun kxr-left-limb? (l/r &optional (list '(:larm :lleg :lmarm :lwing :lleg0 :lleg1 :lleg2)))
  (eq-memq l/r list))
(defun kxr-right-limb? (l/r &optional (list '(:rarm :rleg :rmarm :rwing :rleg0 :rleg1 :rleg2)))
  (eq-memq l/r list))

(defun set-equal (a b &key (test #'eq))
  (and (null (set-difference a b :test test))
       (null (set-difference b a :test test))))

(defun face-equal (a b)
  (set-equal (cdr (send a :vertices))
	     (cdr (send b :vertices))
	     :test #'equal))

(defun faceset-equal (fs1 fs2)
  (set-equal (send fs1 :faces) (send fs2 :faces) :test #'user::face-equal))

(defun plist-to-alist (plist)
  (cond
   ((null plist) nil)
   (t (cons (list (car plist) (cadr plist)) (plist-to-alist (cddr plist))))))

(defun replace-plist-key-value (plist key value)
  (let (res k v)
    (while plist
      (setq k (pop plist))
      (setq v (pop plist))      
      (cond
       ((eq k key)
	(push key res) (push value res))
       (t (push k res) (push v res))))
    (unless (member key plist)
      (push key res) (push value res))
    (reverse res)))
	
(defun alist-to-plist (alist) (apply #'append alist))

(defun alist-difference (a b &key (test #'eq))
  (cond
    ((null a) nil)
    ((equal (assoc (caar a) b :test test) (car a))
     (alist-difference (cdr a) b :test test))
    (t (cons (car a) (alist-difference (cdr a) b :test test)))))
(defun alist-equal (a b &key (test #'eq))
  (and a
       (null (alist-difference a b :test test))
       (null (alist-difference b a :test test))))

(defun config-check (tag value config)
  (catch :config-check
    (while config
      (if (and (eq-memq tag (car config))
	       (eq-memq value (cadr config)))
	  (throw :config-check t))
      (setq config (cddr config)))
    nil))

(in-package "X")
(defmethod irtviewer
  (:format-at-3dpos
   (3dpos &rest data)
   (let ((2dpos (send self :viewer :point-to-screen 3dpos)))
     (send self :string (round (elt 2dpos 0)) (round (elt 2dpos 1))
	   (apply #'format nil data))))
  )

(in-package "GL")
(defun find-color (color)
  (cond
   ((symbolp color)
    (find-if #'(lambda (o) (eq (send o :name) color))
	     *face-colors*))
   ((vectorp color)
    (let ((min-distance 1) min-color d)
      (mapcar #'(lambda (x) 
		  (if (< (setq d (distance (send x :diffuse) color))
			 min-distance)
		      (setq min-distance d min-color x)))
	      *face-colors*)
      min-color))
   (t color)
   ))

(in-package "USER")

(defmacro defpose (mname &optional (fname "poses-file.l"))
  (cond
   ((keywordp mname)
    `(progn (send *robot* :read-from-ri)
	    (send *robot* :defmethod-pose ,mname :fname ,fname)))
   ((symbolp mname)
    `(progn (send *robot* :read-from-ri)
	    (send *robot* :defun-pose ',mname :fname ,fname)))
   ))
(defun run-poses (poses &optional (tm 100) (fname "poses-file.l"))
  (dolist (pose (cons fname poses))
    (cond
     ((and (stringp pose) (probe-file pose)) (load pose))
     ((and (keywordp pose) (find-method *robot* pose))
      (send *robot* pose))
     ((functionp pose)
      (funcall pose *robot*))
     ((numberp pose) (setq tm pose))
     )
    (send *robot* :send-to-ri tm)))

(defun angle-alist-op (al1 al2 op)
  (let (v ret)
    (dolist (al al1)
      (setq v (assoc (car al) al2))
      (if v (push (cons (car al) (funcall op (cdr al) (cdr v))) ret)))
    ret))

(defun angle-alist- (al1 al2) (angle-alist-op al1 al2 #'-))
(defun angle-alist+ (al1 al2) (angle-alist-op al1 al2 #'+))
(defun angle-alist-scale (s al)
  (let (ret)
    (dolist (a al)
      (push (cons (car a) (* s (cdr a))) ret))
    ret))

(defmethod robot-model
    (:show-camera-cones
     nil
     (send self :viewer :objects (cons self (send self :camera-cones)))
     )
  (:stereo-min-distance
   nil
   (let ((cams (send self :cameras)))
     (when (and cams (> (length cams) 1))
       (let* ((lc (car cams)) (rc (cadr cams))
	      (lp (send lc :worldpos)) (rp (send rc :worldpos))
	      (width (norm (v- lp rp)))
	      (e (send self :head-end-coords :rotate-vector #f(0 0 1)))
	      (c (send lc :rotate-vector #f(1 0 0)))
	      (langle (/ (get lc :lens-angle) 2))
	      (cangle (rad2deg (acos (v. e c))))
	      (mangle (+ cangle langle)))
	 (/ width 2 (tan (deg2rad mangle)))))))
  (:stereo-base-width
   nil
   (let ((cams (send self :cameras)))
     (when (and cams (> (length cams) 1))
       (let* ((lc (car cams)) (rc (cadr cams))
	      (lp (send lc :worldpos)) (rp (send rc :worldpos)))
	 (norm (v- lp rp))))))
  (:stereo-center-distance
   nil
   (let ((cams (send self :cameras)))
     (when (and cams (> (length cams) 1))
       (let* ((lc (car cams)) (rc (cadr cams))
	      (lp (send lc :worldpos)) (rp (send rc :worldpos))
	      (width (norm (v- lp rp)))
	      (e (send self :head-end-coords :rotate-vector #f(0 0 1)))
	      (c (send lc :rotate-vector #f(1 0 0)))
	      (cangle (rad2deg (acos (v. e c)))))
	 (/ width 2 (tan (deg2rad cangle)))))))
  (:camera-cones
   (&key depth lens-angle)
   (let* ((cams (send self :cameras))
	  (depth 400) (lens-angle 65) (col :gray) (tra 0.4) cone cones)
     (dolist (cam cams)
       (if (get cam :lens-angle) (setq lens-angle (get cam :lens-angle)))
       (cond
	 ((substringp "stickv" (send cam :name))
	  (setq lens-angle lens-angle depth depth))
	 ((substringp "unitv2" (send cam :name))
	  (setq lens-angle lens-angle depth (/ depth 2)))
	 )
       (setq cone (camera-zcone lens-angle depth col tra))
       (send cone :transform (send cam :worldcoords))
       (send cone :rotate pi/2 :y)
       (send cone :rotate pi/2 :z)
       (send cam :assoc cone)
       (push cone cones))
     (reverse cones))
   )
  )

(defun camera-zcone (&optional (lens-deg 68) (depth 200) (col :gray) (tra 0.3))
  (let* ((y (* depth (tan (deg2rad (/ lens-deg 2.0)))))
	 (x (* y (/ 480 640.0)))
	 (vs (list (float-vector x y depth)
		   (float-vector (- x) y depth)
		   (float-vector (- x) (- y) depth)
		   (float-vector x (- y) depth)))
	 (co (make-cone (float-vector 0 0 0) vs))
	 (coi (make-cone (float-vector 0 0 0) (copy-object vs)))
	 )
    (send coi :translate (float-vector 0 0 10) :world)
    (setq co (body- co coi))
    (setf (get co :face-color) col)
    (gl::transparent co tra)
    co))

(defmethod robot-model
    (:pressure-sensor (sensor-name) (send self :get-sensor-method :pressure-sensor sensor-name))
  (:proximity-sensor (sensor-name) (send self :get-sensor-method :proximity-sensor sensor-name))
  (:button-sensor (sensor-name) (send self :get-sensor-method :button-sensor sensor-name))
  (:kjs-sensors
   nil
   (unless (get self :kjs-sensors)
     (setf (get self :kjs-sensors)
	   (remove-if-not #'(lambda (x) (substringp "KJS" (string (send x :name)))) (send self :imu-sensors))))
   (get self :kjs-sensors))
  (:pressure-sensors nil (get self :pressure-sensors))
  (:proximity-sensors nil (get self :proximity-sensors))
  (:button-sensors nil (get self :button-sensors))
  (:tail (&rest args)
	 (unless args (setq args (list nil))) (send* self :limb :tail args))
  (:in-model-params?
   (x prop)
   (eq-memq x (flatten (assocdr prop (plist-to-alist (send self :model-params))))))
  (:model-param
   (key)
   (let* ((mp (send self :model-params))
	  (al (plist-to-alist mp))
	  (p (assoc key al)))
     (if p (cadr p))))
  (:crotch-tread
   ()
   (let* ((b (send self :body-link))
	  (l0 (get b :lleg))
	  (r0 (get b :rleg))
	  dv)
     (when l0
       (setq dv (v- (send l0 :worldpos) (send r0 :worldpos)))
       (elt dv 1))))
  (:arm-treads
   ()
   (mapcar #'(lambda (l r) (send self :link-tread l r))
	   (send self :larm) (send self :rarm)))
  (:leg-treads
   ()
   (mapcar #'(lambda (l r) (send self :link-tread l r))
	   (send self :lleg) (send self :rleg)))
  (:link-tread
   (l0 r0)
   (let* ((n (string-upcase (string (send l0 :name))))
	  (dv (v- (send l0 :worldpos) (send r0 :worldpos)))
	  (a (subseq n (1- (length n)))))
     (when l0
       (list (intern n *keyword-package*) (elt dv 1)))))
  (:link-lengths
   (&optional links &aux (l0 (pop links)) ret)
   (dolist (l links)
     (push (list (send l0 :name) (send self :link-length l0 l)) ret)
     (setq l0 l))
   (reverse ret))
  (:link-length
   (l0 l1)
   (let* ((n (string-upcase (string (send l0 :name))))
	  (dv (v- (send l1 :worldpos) (send l0 :worldpos))))
     (norm dv)))
  (:bounding-box
   (&rest args)
   (user::forward-message-to
    (make-bounding-box (flatten (send-all (send self :bodies) :vertices)) 0.0) args))
  (:cal-size
   (&optional idx)
   (let ((av (send self :angle-vector)) s)
     (send self :neutral)
     (setq s (send self :bounding-box :diagonal))
     (send self :angle-vector av)
     (if idx (elt s idx) (coerce s cons))))
  (:size
   nil (or (get self :size) (send self :put :size (mapcar #'round (send self :cal-size)))))
  (:specs
   ()
   (let* ((mp (send self :model-params))
	  (al (plist-to-alist mp))
	  (ss
	   `((:name ,(send self :name))
	     (:body ,(send self :model-param :body))
	     (:head ,(send self :model-param :head))
	     (:weight ,(send self :weight))
	     (:size ,(send self :size))
	     (:treads ,@(send self :arm-treads)
		      ,@(send self :leg-treads))
	     (:link-lengths ,@(send self :link-lengths (send self :larm))
			    ,@(send self :link-lengths (send self :lleg))
			    ,@(send self :link-lengths (send self :head)))
	     )))
     ss)
   )
  (:angle-vector
   (&optional av method-list) ;; (send self :joint-list :joint-method-name)
   (cond
    ((null av) (send-super :angle-vector))
    ((consp method-list)
     (if
	 (= (length method-list) (length av))
	 (progn
	   (dotimes (i (length method-list))
	     (let ((meth (elt method-list i)))
	       (if (find-method self meth)
		   (send self meth :joint-angle (elt av i)))))
	   (send-super :angle-vector))
       (warn ";; wrong method-list length=~A with av length=~A~%" (length method-list) (length av))))
    (t (send-super :angle-vector av))))
  (:control-panel (&rest args) (user::forward-message-to (get self :control-panel) args))
  (:create-control-panel
   (&rest args &key (width 910))
   (unless (boundp 'x::robot-conrol-panel)
     (require :kxrviewer))
   (when (send self :control-panel) (send self :control-panel :quit))
   (let ((pan (instance* x::robot-control-panel :create self :title (send self :name)
			 :width width args)))
     (setf (get self :control-panel) pan)
     (send pan :redraw)
     (send pan :flush)
     pan))
  (:back-pack nil (send self :find-named-body "back-pack"))
  (:foot-stand
   nil
   (send self
	 :translate (v- (scale 0.5 (v+ (send (send self :lleg-end-coords) :worldpos)
				       (send (send self :rleg-end-coords) :worldpos))))
	 :world)
   )
  (:listup-function-name
   (&optional (method :bodies))
   (classify-list
    (mapcar #'(lambda (l)
		(list (get l :create-function-name)
		      (get l :create-function-args)))
	    (send self method)))
   )
  (:joint-list-angle nil
		     (mapcar #'(lambda (j) (list (send j :name) (send j :joint-angle))) 
			     (send self :joint-list)))
  (:active-joint-list
   nil
   (or (get self :active-joint-list)
       (send self :put :active-joint-list
	     (remove-if-not #'(lambda (j) (get j :active)) joint-list))))
  ;;
  (:limbs-jlist
   (&optional limbs)
   (let (js)
     (if (null limbs) (setq js (send self :joint-list))
	 (dolist (a (flatten limbs))
	   (if (keywordp a)
	       (push (send self a :joint-list) js)
	       (if (derivedp a joint) (push a js)))))
     (flatten js)))
  (:jlist-sorted-sids
   (jlist &optional (method :servo-index))
   (sort (remove-duplicates (flatten (send-all (flatten jlist) method))) #'<))
  (:limbs-sorted-sids
   (&optional limbs (method :servo-index))
   (send self :jlist-sorted-sids (send self :limbs-jlist limbs) method))
  ;;
  (:model-params nil (get self :model-params)) ;; the second element plist of robot's config in rcb4robotsconfig.l 
  (:type (&optional typ) nil (if typ typ (if (setq typ (member :type (get self :model-params))) (cadr typ))))
  (:config-check (tag value) (config-check tag value (get self :model-params)))
  (:config-name
   ()
   (let ((nm (send self :name)))
     (cond
      ((get self :config-name))
      ((kxr-find-config-by-name nm)
       (setf (get self :config-name) nm))
      (t (kxr-config-name (send self :model-params))))
     ))
  (:create-ri
   (&key ((:viewer create-viewer) (xwindow-ready?)) (model t) rcb4 head
	 (width 400) (height width))
   (when (get self :ri) (send self :delete-ri))
   (send self :set-ri
	 (make-kxr-robot-interface (send self :config-name) :viewer create-viewer :model model
				   :rcb4 rcb4 :head head :width width :height height))
   )
  (:delete-ri
   ()
   (when (xwindow-ready?) (send self :ri :robot :viewer :quit))
   (send self :set-ri nil)
   )
  ;;
  (:ri (&rest args) (forward-message-to (get self :ri) args))
  (:servo-vector
   nil
   (copy-seq (send (get self :ri) :angle-vector-to-servo-vector (send self :angle-vector))))
  (:neutral (&aux (a (send self :angle-vector)))
	    (dotimes (i (length a)) (setf (elt a i) 0.0))
	    (send self :angle-vector a))
  (:show-collisions
   (&optional (flush t))
   (let (pair color 
	      (collisions
	       (send self :self-collision-check)))
     (when (and collisions (get self :viewer))
       (send (get self :viewer) :draw-objects :flush flush)
       (dotimes (i (length collisions))
	 (setq pair (elt collisions i))
	 (setq color (map float-vector #'(lambda (x) (/ x 255.0)) (color-category10 i)))
	 ;;(format t "collision: ~a ~a~%" (send (car pair) :name) (send (cdr pair) :name))
	 (send (car pair) :draw-on :flush nil :color color :width 2)
	 (send (cdr pair) :draw-on :flush nil :color color :width 2)
	 )
       (send (get self :viewer) :viewer :flush)
       (x::window-main-one)
       (unix::usleep (* 500 1000))
       )
     collisions))
  (:read-from-ri
   nil
   (let* ((av (send self :ri :read-angle-vector))
	  ori)
     (when (and av (setq ori (send self :ri :real-orientation)))
       (send self :newcoords ori)
       ;;(send self :newcoords (send self :ri :backpack-orientation))
       (dotimes (i (length joint-list))
	 (if (eq (send (elt joint-list i) :joint-type) :wheel)
	     (setf (elt av i) 0)))
       (send self :angle-vector av)
       #-:arm
       (send self :show-collisions)
       ))
   )
  (:clear-wheels
   nil
   (dolist (j joint-list)
     (if (eq (send j :joint-type) :wheel) (send j :joint-angle 0)))
   )
  (:copy-from-ri
   nil
   (send self :read-from-ri)
   (send self :clear-wheels)
   )
  (:send-to-ri ;; robot-model
   (&optional (msec 1000) limbs &aux (ri (get self :ri)))
   (when (and ri (send ri :com-port))
     (send ri :robot :update-descendants)
     (send ri :robot :angle-vector (send self :angle-vector))
     (send ri :angle-vector (send self :angle-vector) msec limbs)
     #-:arm
     (if (find-method (send ri :robot) :show-collisions)
	 (send ri :robot :show-collisions))
     #-:arm
     (if (find-method (send ri :robot) :send-ode)
	 (send ri :robot :send-ode))
     ;;(send ri :robot :wait-ode)
     ))
  (:read-from-ri-leg
   (&aux (av (send self :ri :read-angle-vector)))
   (when av
     (send self :angle-vector av)
     (send self :fix-leg-to-coords (make-coords)))
   )    
  (:send-to-ri-fast ;; robot-model
   (&optional (msec 1000) limbs &aux (ri (get self :ri)))
   (when ri
     (send ri :robot :angle-vector (send self :angle-vector))
     (send ri :angle-vector (send self :angle-vector) msec limbs)
     ))
  (:set-ri (ri) (setf (get self :ri) ri))
  (:footstep-list
   (&key (x 100) (y 0) (theta 0) (ratio 0.7) (default-step-height 10)
	 &allow-other-keys)
   (send self :reset-pose)
   (send self :legs :move-end-pos #f(0 0 0))
   (send self :fix-leg-to-coords (make-coords))    
   (objects (list self))
   (send self :gen-footstep-parameter :ratio ratio)
   #|
   (default-half-offset (float-vector 0 16 0))
   (forward-offset-length 20)
   (outside-offset-length 20)
   (rotate-rad 0.3)
   (send self :put :footstep-parameter
   (list :default-half-offset default-half-offset
   :forward-offset-length forward-offset-length
   :outside-offset-length outside-offset-length
   :rotate-rad rotate-rad))
   |#
   (send self :go-pos-params->footstep-list x y theta))
  (:draw-walk
   (&rest args
	  &key (x 100) (y 0) (theta 0) (ratio 0.7) (default-step-height 10) mi real-body
	  (time 60) (time0 400) (time-scale 1.0)
	  (name (format nil "(walk ~A ~A ~A :time ~A)" x y theta time)) (flush t)
	  centroid-offset-func
	  (solve-angle-vector-args (if centroid-offset-func
				       (list :centroid-offset-func centroid-offset-func) nil))
	  (footstep-list (send* self :footstep-list args)) &allow-other-keys)
   (let ((al (send self :calc-walk-pattern-from-footstep-list
		   footstep-list
		   :solve-angle-vector-args solve-angle-vector-args
		   :debug-view :no-message
		   :default-step-height default-step-height)))
     (setq time (* time time-scale) time0 (* time0 time-scale))
     ;;(print (length footstep-list))
     (cond
      (mi
       (send self :ri :push-angle-vector-codes (elt (car al) 1) time0 (list :lleg :rleg))
       (dolist (a al)
	 (send self :ri :push-angle-vector-codes (elt a 1) time (list :lleg :rleg)))
       (send self :ri :write-codes-to-motion-table mi :name name :flush flush))
      (t al)))
   )
  (:run-real-walk
   (&optional (x 100) (y 0) (theta 0) (ratio 1.2) (msec 1000))
   (let ((al (send self :draw-walk :x x :y y :theta theta :ratio ratio)))
     (do ((i 0 (+ i 1))) ((>= i (length al)) nil)
	 (send (get self :ri) :angle-vector (cadr (elt al i)) msec)))
   )
  (:init-walk
   (&optional (len 80) (angle 10) (ratio 0.7) (default-step-height 5))
   (send self :reset-pose)
   (send self :fix-leg-to-coords (make-cascoords))
   (send self :gen-footstep-parameter :ratio ratio)
   (setf (get self :forward-walk) (send self :go-pos-params->footstep-list len 0 0))
   (setf (get self :turn-walk) (send self :go-pos-params->footstep-list 0 0 angle))
   (setf (get self :default-step-height) default-step-height)
   )
  (:walk-stay
   (&optional (ration 0.7))
   ;; (send self :walk-vel #f(0 0 0)) ;; x y theta
   )
  (:walk-motion
   (&key (x 100) (y 0) (angle 0) (height 5) (from-origin t))
   (let ((*viewer* (send *irtviewer* :viewer)))
     (send self :reset-pose)
     (send self :legs :move-end-pos #f(0 0 20))
     (when from-origin
       (send self :fix-leg-to-coords (make-coords)))
     (setf (get self :walk-motion)
	   (send self :go-pos-params->footstep-list x y angle))
     (unless (get self :default-step-height)
       (setf (get self :default-step-height) height))
     (setf (get self :walk-pattern-list)
	   (send self :calc-walk-pattern-from-footstep-list
		 (get self :walk-motion) :debug-view :no-message
		 :default-step-height (get self :default-step-height))))
   t)
  (:walk-fore
   (&optional (len 100))
   (send self :walk-motion :x len :y 0 :angle 0))
  (:walk-turn
   (&optional (angle 30))
   (send self :walk-motion :x 0 :y 0 :angle angle))
  (:joint-possible-methods
   nil
   (remove-if-not
    #'(lambda (x)
	(and
	 (some
	  #'(lambda (limb-string) (substringp limb-string (symbol-name x)))
	  '("LLEG-" "RLEG-" "LARM-" "LMARM-" "RARM-" "RMARM-"
	    "HEAD-" "TORSO-" "LWING-" "RWING-" "LTILT-" "RTILT-"
	    "LLEG0-" "LLEG1-" "LLEG2-" "RLEG0-" "RLEG1-" "RLEG2-"))
	 (some
	  #'(lambda (str)
	      (let ((xstr (string x)))
		(equal (subseq xstr (- (length xstr) 2)) str)))
	  '("-R" "-P" "-Y" "-W"))))
    (send self :methods)))
  (:joint-list-names nil (mapcar #'string (send self :joint-list :name)))
  (:joint-method-names nil (send self :joint-list :joint-method-name))
  (:joint-angles ()
		 (mapcar #'(lambda (a b) (list 'send '*robot* a :joint-angle b))
			 (send self :joint-list :joint-method-name)
			 (send self :joint-list :joint-angle)))
  (:save-definition
   (fname deflist)
   (when fname
     (let (data)
       (when (probe-file fname)
	 (do-file-form (f fname) (push f data)))
       (push deflist data)
       (with-open-file
	(f fname :direction :output)
	(dolist (d (reverse data))
	  (pprint d f)))))
   deflist)
  (:defun-pose
      (name &key fname)
      (send self :save-definition fname
	    `(defun ,name (&optional (*robot* *robot*))
	       ,@(mapcar #'(lambda (a b)
			     (list 'if (list 'find-method 'self a)
				   (list 'send 'self a :joint-angle b)))
			 (send self :joint-list :joint-method-name)
			 (send self :joint-list :joint-angle))
	       ;;,'(send *robot* :fix-leg-to-coords (make-coords))
	       ,'(send *robot* :angle-vector)
	       )))
  (:angle-alist  ;; 2023.9.10 not dotted pair to enable alist-to-plist, plist-to-alist
   (&optional alist) 
   (if alist
       (dolist (al alist) (if (find-method self (car al))
			      (send self (car al) :joint-angle (cadr al)))))
   (mapcar #'(lambda (j) (list (send j :joint-method-name) (send j :joint-angle))) joint-list))
  (:defmethod-plist-pose
      (name &rest args)
      (format t ";; :defmethod-plist-pose name=~A args=~A~%" name args)
      `(defmethod ,(send (class self) :name)
	   (,name (&optional (*robot* *robot*))
		     (send self :angle-plist ,@(send* *robot* :angle-plist args)))
	 ))
  (:save-plist-pose
   (name &rest args)
   (send self :save-definition (format nil "poses-~A.l" (send (class self) :name))
	 (send* self :defmethod-plist-pose name args)))
  (:angle-plist
   (&rest args)
   (let ((plist args) key value keys)
     (while plist
       (setq key (pop plist))
       (setq value (pop plist))
       (cond
	 ((member key '(:larm :rarm :lleg :rleg :head :torso :tail :arms :legs))
	  (setq keys (append (send-all (flatten (send self key)) :joint :method-name) keys)))
	 ((null value) (push key keys))
	 ((symbolp value) (push key keys) (push value plist))
	 ((numberp value)
	  (when (find-method self key)
	    (push key keys)
	    (send self key :joint-angle value)))
	 )
       )
     (if (null keys) (setq keys (send self :joint-list :method-name)))
     (mapcan #'(lambda (key)
		 (list key (send self key :joint-angle)))
	     keys)))
  (:torque-alist
   (&optional alist)
   (if alist
       (dolist (al alist) (if (find-method self (car al))
			      (send self (car al) :joint-angle (cadr al)))))
   (mapcar #'(lambda (j) (list (send j :joint-method-name) (send j :joint-angle))) joint-list))
  (:defmethod-pose
   (m-name &key ((:class cls-name) (send (class self) :name)) fname)
   (send self :save-definition fname
	 `(defmethod ,cls-name
	    (,m-name ()
		     ,@(mapcar #'(lambda (a b) (list 'send 'self a :joint-angle b))
			       (send self :joint-list :joint-method-name)
			       (send self :joint-list :joint-angle))
		     ;;,'(send self :fix-leg-to-coords (make-coords))
	     ,'(send self :angle-vector)
	     ))))
  (:deflimb-pose
      (limb m-name &key ((:class cls-name) (send (class self) :name)) fname)
      (send self :save-definition fname
	    `(defmethod ,cls-name
		 (,m-name ()
		  ,@(let ((jlist (flatten (send self limb :joint-list))))
		      (append
		       (mapcar #'(lambda (a b) (list 'send 'self a :joint-angle b))
			       (send-all jlist :joint-method-name)
			       (send-all jlist :joint-angle))
		       (list '(send self :angle-vector))))))
	    ))
  (:thigh-length
   nil
   (let* ((av (send self :angle-vector)) l)
     (send self :neutral)
     (setq l (elt (v- (send self :lleg-crotch-p :child-link :worldpos)
		      (send self :lleg-knee-p :child-link :worldpos)) 2))
     (send self :angle-vector av)
     l))
  (:shin-length
   nil
   (let* ((av (send self :angle-vector)) l)
     (send self :neutral)
     (setq l (elt (v- (send self :lleg-knee-p :child-link :worldpos)
		      (send self :lleg-ankle-p :child-link :worldpos)) 2))
     (send self :angle-vector av)
     l))
  (:setup-limb-length
   ()
   (let ((pose (send self :angle-vector)) dat len)
     (send self :neutral)
     (dolist (limb '(:larm :rarm :lleg :rleg))
       (setf len (elt (v- (send self limb :root-link :worldpos)
			  (send self limb :end-coords :worldpos))
		      2))
       (push (setf (get self limb) len) dat))
     (send self :angle-vector pose)
     ))
  #|
  (:limb-length
   (limb)
   (let* (dat
	  (pln
	   (make-plane :point (send self limb :root-link :worldpos)
		       :normal (transform (send self limb :root-link :worldrot) #f(0 1 0))))
	  (len 0))
     (dolist (lk (send self limb))
       (setq len (distance (send pln :foot (send self limb :root-link :worldpos))
			   (send pln :foot (send self limb :end-coords :worldpos))))
       (push (setf (get self limb) len) dat))
     ))
  |#
  ;;
  (:joint-access-names
   nil
   (or (get self :joint-access-names)
       (send self :setup-joint-method-names)))
  (:setup-joint-method-names
   nil
   (let* ((meths (send self :methods))
	  (pnames (send self :joint-possible-methods))
	  (jlist-names (send self :joint-list-names))
	  (av-len (length (send self :angle-vector)))
	  i j
	  (nlist (instantiate vector (length jlist-names))))
     (dolist (pj pnames)
       (when (find-method self pj)
	 (setq j (send self pj)) ;;  2022.12.17 dangerous side effect
	 (when (and (derivedp j joint)  ;; rotational and prismatic
		    (setq i (position (send j :name) jlist-names :test #'string-equal)))
	   (setf (elt nlist i) (symbol-name pj))
	   (setf (get j :joint-method-name) pj)
	   )))
     (dotimes (i (length (send self :angle-vector)))
       (setf (get (elt joint-list i) :angle-vector-index) i))
     (setf (get self :joint-access-names) (coerce nlist cons))
     ))
  )

(defun mirror-method (jname)
  (let ((sname (string jname)))
    (cond
      ((substringp "larm" sname)
       (intern (replace sname "RARM") *keyword-package*))
      ((substringp "rarm" sname)
       (intern (replace sname "LARM") *keyword-package*))
      ((substringp "lleg" sname)
       (intern (replace sname "RLEG") *keyword-package*))
      ((substringp "rleg" sname)
       (intern (replace sname "LLEG") *keyword-package*))
      (t nil)))
  )

(defun 4bit2num (lst v)
  (let ((sum 0))
    (dolist (i lst)
      (setq sum (ash sum 4))
      (setq sum (+ sum (logand #xf (elt v (1- i))))))
    sum))

(defun numseq-to-short (lst num &optional (start 0) &aux v)
  (if (logbitp 15 (setq v (numseq-to-num lst num start)))
      (- v #x10000) v))

(defun numseq-to-num (lst num &optional (start 0) &aux (sum 0) buf)
  (when (>= (length lst) num)
    (dotimes (i num) (push (elt lst (+ start i)) buf))
    (dolist (l buf) (setq sum (logior (ash sum 8) l))))
  sum)

(defun num-to-numlist (addr num &aux lst)
  (dotimes (i num)
    (push (logand addr #xff) lst)
    (setq addr (ash addr -8)))
  (reverse lst))

(defun num-to-bytelist (num)
  (let (res div mod)
    (while (> (setq mod (mod num 256) div (/ num 256)) 0)
      (push (mod num 256) res)
      (setq num (ash num -8)))
    (push mod res)
    (reverse res)))

(defun num-to-4bytes (num)
  (num-to-numlist (round num) 4))

(defun get-uint (str &optional (idx 0) (len 4) (v 0))
  (dotimes (i len)
    (setq v (ash v 8))
    (setq v (+ v (elt str (- (+ len idx -1) i)))))
  v)

(defun get-int (str &optional (idx 0) (len 4) (v 0) minus)
  (setq minus (if (= (logand #x80 (elt str (+ len idx -1))) #x80) t nil))
  (dotimes (i len)
    (setq v (ash v 8))
    (setq v (+ v (elt str (- (+ len idx -1) i)))))
  (if minus (- v (ash 1 (* 8 len))) v))

(defun send+ (&rest args)
  (send* args)
  (send *robot* :draw-collision)
  )

(defun draw-collision0 (&aux pair color)
  (send *robot* :push-interpolation-list)
  (when (xwindow-ready?)
    (send *irtviewer* :draw-objects :flush t)
    (dotimes (i (length (send *robot* :self-collision-check)))
      (setq pair (elt (send *robot* :self-collision-check) i))
      (setq color (map float-vector #'(lambda (x) (/ x 255.0)) (color-category10 i)))
      (format t "collision: ~a ~a~%" (send (car pair) :name) (send (cdr pair) :name))
      (send (car pair) :draw-on :flush nil :color color :width 2)
      (send (cdr pair) :draw-on :flush nil :color color :width 2)
      )
    (send *irtviewer* :viewer :flush)
    (x::window-main-one)
    (unix::usleep (* 500 1000))))

(defun draw-collision (&aux pair color)
  (send *robot* :draw-collision)
  )


(in-package "X")

;;(setq font-k12 (font-id "*-jis-fixed-medium-r-normal-*-12-*"))
#|
(defmethod glviewsurface
  (:write-to-ppm-file
   (file &key (x 0) (y 0)
	 (width x::width)
	 (height x::height))
   (let* ((glimg (send self :getglimage
		       :x x :y y :width (1- width) :height height)))
     (send glimg :write-to-ppm-file file)
     ))
  (:write-to-jpg-file
   (file &key (x 0) (y 0)
	 (width x::width)
	 (height x::height)
	 (quality))
   (let* ((glimg (send self :getglimage
		       :x x :y y :width (1- width) :height height)))
     (send glimg :write-to-jpg-file file quality)
     ))
  )

(defun font-id (font &aux (id font))	;fontstruct/fontname to font-id
   (cond ((integerp font) font)
	 ((stringp font)
	  ;;(setq freestr (make-string 256))
	  (setq kanjifont (createfontset *display* "-*-fixed-medium-r-normal--16-*-*-*"
					 0 0 0))
	  (setq id (LoadQueryFont *display* font))
	  (if (= id 0)
		  (prog1 0 (warn "can't load font ~S" font))
#-(or :alpha :irix6 :x86_64 :aarch64)
		  (sys:peek (+ id 4) :long)
#+(or :alpha :irix6 :x86_64 :aarch64)
		  (sys:peek (+ id 8) :long)
))))

|#

(defmethod Xdrawable
 (:string-mb
  (x y str &optional (start 0) (end (length str)) (gc gcon)
     (fontstr "-*-fixed-medium-r-normal--16-*-*-*"))
   (let ((missing_list (instantiate integer-vector 1))
	(missing_count (instantiate integer-vector 1))
	(def_string (instantiate integer-vector 1)) fs)
     ;;(format t ";; :string-mb~%")
     (etlocale 0 "")
     (setq fs (createfontset *display* fontstr missing_list missing_count def_string))
     (when (/= fs 0)
       (if (/= (elt missing_list 0) 0)
	   (FreeStringList missing_list))
       (mbDrawString *display* drawable fs (gcontext-gcid gc)
		     x y
		     (+ (sys:address str) (* lisp::sizeof-* 2)  start)
		     (- end start))
       (FreeFontSet *display* fs)
       )
     )
	     )
  )

(defmethod irtviewer
    (:string-core
     (x y str &optional (fid x::font-courb18))
		(gl::glxUseXfont fid 32 96 (+ 1000 32))
		(gl::glRasterPos2i (round x) (- (send self :height) (round y)))
		(gl::glListBase 1000)
		(gl::glCallLists (length str) gl::GL_UNSIGNED_BYTE str)
		)
  (:string (x y str &optional (fid x::font-courb18))
	   ;;(fid x::font-helvetica-bold-12))
	   ;;(fid x::font-courb18)
	   ;;(fid x::font-a14)
	   ;;(send-all x::subwindows :2d-mode)
	   ;;(send viewer :viewsurface :2d-mode)
	   (send viewer :viewsurface :2d-mode)
	   (if (fboundp 'etlocale)
	       (send self :string-mb x y str) ;; you need xforeign.c.c extension
	       (send self :string-core x y str fid))
	   ;;(send-all x::subwindows :3d-mode)
	   ;;(send viewer :viewsurface :3d-mode)
	   (send viewer :viewsurface :3d-mode)
	   (send self :flush)
	   )
  (:strings
   (strs &optional (x 20) (y 20) (h 15))
   ;;(send-all x::subwindows :2d-mode)
   (send viewer :viewsurface :2d-mode)
   (dolist (str strs)
     (send self :string-core x y str)
     (setq y (+ y h)))
   ;;(send-all x::subwindows :3d-mode)
   (send viewer :viewsurface :3d-mode)
   (send self :flush)
   )
  )

(in-package "USER")

(defun transpose-rows (img)
  (let* ((ow (send img :width))
	 (oh (send img :height))
	 (od (/ (send img :depth) 8))
	 (wd (* ow od))
	 (buf (make-string wd))
	 (ob (send img :entity)))
    (when (not (= od 3))
      (error "not supported depth"))
    (dotimes (y (/ oh 2))
      (dotimes (i wd)
	(setf (elt buf i) (elt ob (* wd (- oh y 1)))))
      (dotimes (i wd)
	(setf (elt ob (* wd (- oh y i))) (elt ob (* wd y))))
      (dotimes (i wd)
	(setf (elt ob (* wd y )) (elt buf i))))
    ;;(user::ctranspose-rows ow oh od ob)
    ;;(return-from transpose-rows (instance img:color-image24 :init ow oh ob))
    (return-from transpose-rows img)
    ))

(defmethod image::color-image24
    (:write-to-ppm-file (file) (image::write-pnm-file file self))
  ;;(:write-to-jpg-file (file &optional quality)
  ;;(image::write-jpg-file file self quality))
  )

(defun make-sphere (r &rest args &key name &allow-other-keys)
  (let (b)
    (setq b (make-gdome (make-icosahedron r)))
    (setf (get b :sphere) r)
    b))

(defun make-capsule (r h &key (segments 12))
  (let (pl (seg2 (ceiling (/ segments 4.0)))
	   (dth (/ 2pi segments))
	   (h/2 (* 0.5 h))
	   c)
    (dotimes (i seg2)
      (push (float-vector (* r (sin (* dth i)))
			  0
			  (+ h/2 (* r (cos (* dth i)))))
	    pl))
    (push (float-vector r 0 h/2) pl)
    (nreverse pl)
    (nconc
     pl
     (reverse 
      (mapcar #'(lambda (x) (float-vector (elt x 0) (elt x 1) (- (elt x 2))))
	      pl))
     )
    ;;    (setq c (make-torus pl :segments segments))
    (setq c (make-solid-of-revolution pl :segments segments))
    (setf (get c :capsule) (list r h))
    c))

(defmethod faceset
  (:volume (&optional (point #f(0 0 0)))
	   (apply #'+ (send-all faces :volume point)))
  )

(defun sub-directory (&optional (dir "."))
  (mapcan
   #'(lambda (d)
       (cond
	 ((equal d "..") nil)
	 ((equal d ".") nil) ;; (list (namestring (truename dir))))
	 ((lisp::directory-p (setq d (format nil "~A/~A" (namestring (truename dir)) d)))
	  (list d))
	 (t nil)))
   (directory dir)))

(defun sub-directories (&optional (dir "."))
  (let ((dirs (sub-directory dir)))
    (cond
      ((null dirs) nil)
      (t (cons (namestring (truename dir))
	       (mapcan
		#'(lambda (d) (sub-directories d))
		dirs))))))

(defun find-all-files (&key (dir ".") (subseq "") (ext "xml"))
  (mapcan
   #'(lambda (d)
       (find-files :dir d :subseq subseq :ext ext))
   (sub-directories dir)))

(defun find-files (&key (dir ".") (subseq "") (ext "xml"))
  (mapcan
   #'(lambda (x)
       (let ((pname (format nil "~A/~A" dir x)))
	 (if (and (string-equal ext (pathname-type pname))
		  (substringp subseq x))
	     (list pname)
	   nil)))
   (directory dir)))

(defun axis2vector (key)
  (case key
    (:x #f(1 0 0)) (:-x #f(-1 0 0))
    (:y #f(0 1 0)) (:-y #f(0 -1 0))
    (:z #f(0 0 1)) (:-z #f(0 0 -1))
    (t key)))

;;;
;;(defun nanp (v) (member *nan* (coerce v cons)))
(defun nanp (v) (some #'c-isnan (coerce v cons)))

(defun gl::make-glvertices-from-faceset (fs &key (material))
  "returns glvertices instance. fs is geomatry::faceset"
  (let (mat)
    (cond
      (material (setq mat material))
     ((get fs :face-color)
      (let ((col (get fs :face-color)))
        (unless (vectorp col)
          (setq col (gl::find-color col)))
        (setq mat
              (list (list :ambient (float-vector (elt col 0) (elt col 1) (elt col 2)))
                    (list :diffuse (float-vector (elt col 0) (elt col 1) (elt col 2)))))))
     (t ;; use default material
      (setq mat
            (list (list :ambient (float-vector 0.65 0.65 0.65))
                  (list :diffuse (float-vector 0.65 0.65 0.65))))))
    (gl::make-glvertices-from-faces (send fs :faces) :material mat)))

(defun gl::make-glvertices-from-faces (flst &key (material))
  "returns glvertices instance. flst is list of geomatry::face"
  (let ((flst1 (flatten (mapcar #'(lambda (f) (geometry::face-to-triangle-aux f))
				flst))))
    ;;(format t ";;make-glverticies-from-faces flst=~A, flst1=~A~%" (length flst) (length flst1))
    (setq flst (remove-if #'(lambda (x) (zerop (send x :area))) flst1))
    ;;(format t ";;make-glverticies-from-faces flst1=~A, flst=~A~%" (length flst1) (length flst))
    (unless (equal (length flst1) (length flst))
      (warn ";; zero area face (length flst1) -> (length flst)=~A~%"
	    (length flst1) (length flst)))
    (let ((mat (make-matrix (* 3 (length flst)) 3))
	  (nom (make-matrix (* 3 (length flst)) 3))
	  (idx (instantiate integer-vector (* 3 (length flst))))
	  (cntr 0))
      (dolist (f flst)
	(let* ((nm (normalize-vector (send f :normal)))
	       (vsl (send f :vertices)))
	  (if (or (nanp nm) (some #'nanp vsl))
	      (warn ";;nan nm=~A, f=~A~%" nm f)
	    (progn
	      ;;
	      (user::c-matrix-row mat cntr (car vsl) t)
	      (user::c-matrix-row nom cntr nm t)
	      (incf cntr)
	      ;;
	      (user::c-matrix-row mat cntr (cadr vsl) t)
	      (user::c-matrix-row nom cntr nm t)
	      (incf cntr)
	      ;;
	      (user::c-matrix-row mat cntr (caddr vsl) t)
	      (user::c-matrix-row nom cntr nm t)
	      (incf cntr)))
	  ))
      (setq idx (instantiate integer-vector cntr))
      (dotimes (i (length idx)) (setf (elt idx i) i))
      (let ((msh
	     (list (list :type :triangles)
		   (list :vertices mat)
		   (list :normals nom)
		   (list :indices idx))))
	(when material
	  (push (list :material material) msh))
	(instance gl::glvertices :init (list msh)))
      ))
  )
;;;
;;; using (find-extream list key test) of lisp/geo/primt.l
;;;
(defun bodies-vector-limit-face-pos (bb &optional (pos #f(0 0 -10000)) (v #f(0 0 1)) (test #'>))
  (find-extream
   (apply #'append
	  (send-all bb :faces-intersect-with-point-vector pos v))
   #'(lambda (x) (if x (v. (cadr x) v) 0.0))
   test))

(defun bodies-vector-limit (bb &optional (pos #f(0 0 -10000)) (v #f(0 0 1)) (test #'>))
  (let ((v2 (bodies-vector-limit-face-pos bb pos v test)))
    (if v2
	(v. (cadr v2) v)
	0.0)))

(defclass kxr-body  :super gl::glbody :slots ())

(defmethod joint
  (:axis nil axis)
  (:joint-type nil (get self :joint-type))
  (:method-name nil (get self :joint-method-name))
  (:servo-index () (get self :servo-index))
  (:servo-sign () (get self :servo-sign))
  (:angle-index () (get self :angle-index))
  (:joint-list () (list self))
  (:joint-method-name nil (get self :joint-method-name))
  (:joint-stretch
   (&optional v)
   (if v (setf (get self :joint-stretch) v))
   (get self :joint-stretch))
  (:joint-state (&optional (sid (get self :servo-index)) sts)
		(dolist (si sid)
		  (push (send *robot* :ri :servo-state si) sts))
		sts)
  (:joint-free-state nil (get self :joint-free-state))
  (:joint-free
   ()
   (cond ((get self :servo-index)
	  (dolist (si (get self :servo-index))
	    (send *robot* :ri :send-single-servo si #x8000 100))
	  (setf (get self :joint-free-state) t))
	 (t (warn "; joint free to ~A no servo-index~%"  self)))
   (get self :joint-free-state))
  (:joint-hold
   ()
   (cond ((get self :servo-index)
	  (dolist (si (get self :servo-index))
	    (send *robot* :ri :send-single-servo si #x7fff 100))
	  (setf (get self :joint-free-state) nil))
	 (t (warn "; joint-hold to ~A no servo-index~%"  self)))
   (get self :joint-free-state))
  (:id (&optional v)
       (if v (setf (get self :id) v))
       (get self :id))
  (:no (&optional (r (send self :robot)))
       (if r (position self (send r :joint-list))))
  (:robot
   nil
   (or
    (get self :robot)
    (let ((p self) r)
      (while (setq p (send p :parent-link)) (setq r p))
      (setf (get self :robot) (send r :parent)))))
  (:joint-angle-range-over
   (&optional v)
   (when v
     (when (and joint-min-max-table joint-min-max-target)
       (setq min-angle (send self :joint-min-max-table-min-angle)
	     max-angle (send self :joint-min-max-table-max-angle)))
     (or (> v max-angle) (< v min-angle))))
  )

(in-package "USER")

(defmethod robot-model
    (:neck (&rest args)
	      (unless args (setq args (list nil))) (send* self :limb :neck args))
  (:volume () (apply #'+ (send self :bodies :volume)))
  (:viewer (&rest args) (forward-message-to (get self :viewer) args))
  (:create-viewer
   (&optional vwer &key (width 400) (height 400))
   (when (xwindow-ready?)
     (if vwer (setf (get self :viewer) vwer)
       (setf (get self :viewer) (make-irtviewer :width width :height height)))
     (send self :viewer :objects (list self))
     (send self :viewer :look-all)
     (send self :viewer :title (send self :name))
     (send self :viewer :name (send self :name)))
   )
  (:clear-interpolation-list
   ()
   (send self :put :interpolation-list nil)
   )
  (:push-interpolation-list
   (&optional
    (rc (send (car (send self :links)) :copy-worldcoords))
    (av (send self :angle-vector))
    )
   (send self :put :interpolation-list
         (append (send self :get :interpolation-list)
                 (list (list rc av))))
   )
  (:draw-collision
   (&aux pair color (vw (send self :viewer)))
   (when (xwindow-ready?)
     (send self :push-interpolation-list)
     (unless vw (setq vw *irtviewer*))
     (send vw :draw-objects :flush t)
     (dotimes (i (length (send self :self-collision-check)))
       (setq pair (elt (send self :self-collision-check) i))
       (setq color (map float-vector #'(lambda (x) (/ x 255.0)) (color-category10 i)))
       (format t "collision: ~a ~a~%" (send (car pair) :name) (send (cdr pair) :name))
       (send (car pair) :draw-on :flush nil :color color :width 2)
       (send (cdr pair) :draw-on :flush nil :color color :width 2)
       )
     (send vw :viewer :flush)
     (x::window-main-one)
     (unix::usleep (* 500 1000))))
  (:draw-end-coords
   (&key ((:viewer vw) (send self :viewer :viewer)) (flush t) c)
   (when (xwindow-ready?)
     (when (setq c (send self :worldcoords))
       (send c :draw-on :viewer vw :flush nil :size 20 :color #f(1 1 0) :width 2))
     (when (setq c (send self :rarm-end-coords))
       (send c :draw-on :viewer vw :flush nil :size 20 :color #f(1 1 0) :width 2))
     (when (setq c (send self :larm-end-coords))
       (send c :draw-on :viewer vw :flush nil :size 20 :color #f(1 1 0) :width 2))
     (when (setq c (send self :rleg-end-coords))
       (send c :draw-on :viewer vw :flush nil :size 20 :color #f(1 1 0) :width 2))
     (when (setq c (send self :lleg-end-coords))
       (send c :draw-on :viewer vw :flush nil :size 20 :color #f(1 1 0) :width 2))
     (when (setq c (send self :head-end-coords))
       (send c :draw-on :viewer vw :flush nil :size 20 :color #f(1 1 0) :width 2))
     (dolist (c (send self :cameras))
       (send c :draw-on :viewer vw :flush nil :size 20 :color #f(1 1 0) :width 2))
     ;;(send self :viewer :viewer :draw-axis (send re :transform rzmp) 50)
     ;;(send self :viewer :viewer :draw-axis (send le :transform lzmp) 50)
     (if flush (send vw :flush))
     ))
  (:min-z-pos
   ()
   (send self :worldcoords)
   (find-extream
    (send-all (send self :links) :min-z-pos)
    #'(lambda (x) (elt x 2))
    #'<))
  (:move-on-ground
   (&optional (origin #f(0 0 0)))
   (send self :fix-leg-to-coords (make-coords))
   #|
   (send self :worldcoords)
   (send-all (send self :links) :worldcoords)
   (send self :translate (v- origin (send self :min-z-pos)) :world)
   (send self :worldcoords)
   (send-all (send self :links) :worldcoords)
   (send self :worldcoords)
   |#
   (send self :viewer :draw-objects :flush t)
   (send self :viewer :flush)
   (x::window-main-one)
   )
  )

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


(defun make-model-obb-cube
    (coords bodies &key (thr 0) (grow 0.0) (capsule nil))
  (let ((bs (remove
	     nil
	     (mapcar #'(lambda (x)
			 (if (member :volume (send x :methods))
			     (if (> (abs (send x :volume)) thr) x)))
		     bodies)))
	bb b min max whd)
    (unless bs (return-from make-model-obb-cube nil))
    (setq bb (make-bounding-box 
	      (mapcar #'(lambda (v) (send coords :inverse-transform-vector v))
		      (copy-list (flatten (send-all bs :vertices))))))
    (send bb :grow grow)
    (setq min (send bb :minpoint)
	  max (send bb :maxpoint)
	  whd (v- max min))
    (if capsule
	(setq b (make-capsule (max (elt whd 0) (elt whd 1)) (elt whd 2)))
      (setq b (make-cube (elt whd 0) (elt whd 1) (elt whd 2))))
    (send b :newcoords (send coords :copy-worldcoords))
    (send b :translate (vector-mean (list min max)))
    (send b :worldcoords)
    b))

#|
(defmethod cascaded-link
  (:weight
   (&optional update-mass-property)
   (if update-mass-property
       (let ((w 0.0))
	 (dolist (l (send self :links))
	   (send l :weight (* 1.2 0.001 (send l :volume)))
	   (setq w (+ w (send l :weight))))
	 (setf (get self :weight) w))
     (get self :weight)))
  )
|#
(defmethod cascaded-link
  (:cal-weight-old
   (&optional w)
   (cond
     (w (send self :put :weight w))
     (t (setq w 0.0)
	(dolist (l links)
	  (send l :cal-weight)
	  (if (numberp (send l :weight))
	      (setq w (+ w (send l :weight)))))
	(send self :put :weight w))))
  (:cal-weight
   ()
   (apply #'+ (send-all (send self :bodies) :weight)))
  (:height () (or (get self :height) (send self :cal-height)))
  (:cal-height
   nil
   (let* ((vs (flatten (send-all (send self :bodies) :vertices)))
	  (min (find-extream vs #'(lambda (x) (elt x 2)) #'<))
	  (max (find-extream vs #'(lambda (x) (elt x 2)) #'>)))
     (send self :put :height (- (elt max 2) (elt min 2)))))
  )

(defmethod bodyset
  (:centroid
   (&optional (point (float-vector 0 0 0)))
   (let* ((cents (send-all (send self :bodies) :centroid point))
	  (vols (send-all (send self :bodies) :volume))
	  (total-volume (apply #'+ vols))
	  (glist (mapcar #'(lambda (c v) (scale v c)) cents vols))
	  (centroid (float-vector 0 0 0)))
     (dolist (g glist)  (v+ g centroid centroid))
     (scale (/ 1.0 total-volume) centroid centroid)
     ;;	(setf (get self :centroid) centroid)
     centroid))
  )
(defmethod faceset
  (:centroid (&optional (point (float-vector 0 0 0)))
	     (let* ((cents (send-all faces :centroid point))
		    (total-area (apply #'+ (mapcar #'car cents)))
		    (glist (mapcar #'(lambda (c) (apply #'scale c)) cents))
		    (centroid (float-vector 0 0 0)))
	       (dolist (g glist)  (v+ g centroid centroid))
	       (scale (/ 1.0 total-area) centroid centroid)
	       ;;	(setf (get self :centroid) centroid)
	       centroid))
  (:world-centroid
   ()
   (send (send self :worldcoords) :transform-vector (get self :centroid)))
  (:weight
   (&optional w) 
   (cond
    (w (setf (get self :weight) w))
    ((get self :weight))
    (t 
     (setf (get self :weight) (* 1.2 (/ (send self :volume) 1000.0)))
     ;;(format t ";; faceset=~A is no weight. set to ~A~%" self (get self :weight))
     (get self :weight))))
  (:cal-inertia-matrix-g
   nil
   (let* ((g (send self :centroid))
	  (im (make-matrix 3 3))
	  (v (send self :volume)))
     (dolist (f faces)
       (let* ((vs (send f :vertices))
	      (c (vector-mean vs)) (s (make-matrix 3 3)))
	 (while (cddr vs)
	   (setq s (m+ s (tripyramid-im (v- (car vs) g)
					(v- (cadr vs) g)
					(v- (caddr vs) g))))
	   (pop vs) (pop vs))
	 (setq im (m+ im s))))
     ;;(setq (im . entity) (scale (/ 1 12.0 1000.0) (im . entity)))
     (setq (im . entity) (scale (/ 120.0) (im . entity)))
     (send self :put :inertia-matrix-g im)
     im))
  (:inertia-matrix-g
   nil
   (if (null (get self :inertia-matrix-g))
       (send self :cal-inertia-matrix-g))
   (get self :inertia-matrix-g))
  (:inertia-matrix
   (&optional (c (make-cascoords)))
   (if (null (get self :inertia-matrix))
       (send self :cal-inertia-matrix c))
   (get self :inertia-matrix))
  (:cal-inertia-matrix
   (&optional (c (make-cascoords)))
   (let ((g (v- (send self :centroid) (send c :worldpos)))
	 (img (copy-object (send self :inertia-matrix-g))))
     ;;(format t ":cal-inertia-matrix ~%")
     (setf (aref img 0 0) (+ (aref img 0 0) (* (elt g 1) (elt g 1))
			     (* (elt g 2) (elt g 2))))
     (setf (aref img 1 1) (+ (aref img 1 1) (* (elt g 0) (elt g 0))
			     (* (elt g 2) (elt g 2))))
     (setf (aref img 2 2) (+ (aref img 2 2) (* (elt g 1) (elt g 1))
			     (* (elt g 0) (elt g 0))))
     ;;(setq (img . entity) (scale (/ 1 1000000.0) (img . entity)))
     (send self :put :inertia-matrix img)
     img))
  (:faceset nil (instance faceset :init :faces faces))
  (:z-height (&optional (p #f(0 0 0)) (func #'max))
	     (apply func (mapcar
			  #'(lambda (v) (elt v 2))
			  (send-all faces :foot p))))
  )

(defun tripyramid-im0 (a b c &optional (im (make-matrix 3 3)))
  (labels ((v2 (v) (let ((v1 (copy-object v)) (n (length v)))
		     (dotimes (i n) (setf (elt v1 i) (* (elt v i) (elt v i))))
		     v1))
	   (v12 (v) (let ((v1 (copy-object v)) (n (length v)))
		      (setf (elt v1 0) (* (elt v 0) (elt v 1)))
		      (setf (elt v1 1) (* (elt v 1) (elt v 2)))
		      (setf (elt v1 2) (* (elt v 2) (elt v 0)))
		      v1)))
    (let* ((k (vplus (list a b c)))
	   (kk (vplus (list (v2 a) (v2 b) (v2 c))))
	   (kkk (vplus (list (v12 a) (v12 b) (v12 c))))
	   (v (v. (v* a b) c)))
      (setf (aref im 0 0) (+ (* (elt k 1) (elt k 1))
			     (elt kk 1)
			     (* (elt k 2) (elt k 2))
			     (elt kk 2)))
      (setf (aref im 1 1) (+ (* (elt k 0) (elt k 0))
			     (elt kk 0)
			     (* (elt k 2) (elt k 2))
			     (elt kk 2)))
      (setf (aref im 2 2) (+ (* (elt k 0) (elt k 0))
			     (elt kk 0)
			     (* (elt k 1) (elt k 1))
			     (elt kk 1)))
      (setf (aref im 0 1) (* -0.5 (+ (* (elt k 0) (elt k 1))
				     (elt kkk 0))))
      (setf (aref im 0 2) (* -0.5 (+ (* (elt k 0) (elt k 2))
				     (elt kkk 2))))
      (setf (aref im 1 2) (* -0.5 (+ (* (elt k 1) (elt k 2))
				     (elt kkk 1))))
      (setf (aref im 1 0) (aref im 0 1))
      (setf (aref im 2 0) (aref im 0 2))      
      (setf (aref im 2 1)  (aref im 1 2))
      (setq (im . entity) (scale (/ v 120.0) (im . entity)))
      im)
    )
  )

(defun tripyramid-im
  (a b c &optional (im (make-matrix 3 3)) (vtmp #F(0 0 0))
     (k0 (+ (aref a 0) (aref b 0) (aref c 0)))
     (k1 (+ (aref a 1) (aref b 1) (aref c 1)))
     (k2 (+ (aref a 2) (aref b 2) (aref c 2)))
     (k00 (+ (* (aref a 0) (aref a 0)) (* (aref b 0) (aref b 0)) (* (aref c 0) (aref c 0))))
     (k11 (+ (* (aref a 1) (aref a 1)) (* (aref b 1) (aref b 1)) (* (aref c 1) (aref c 1))))
     (k22 (+ (* (aref a 2) (aref a 2)) (* (aref b 2) (aref b 2)) (* (aref c 2) (aref c 2))))
     (k01 (+ (* (aref a 0) (aref a 1)) (* (aref b 0) (aref b 1)) (* (aref c 0) (aref c 1))))
     (k12 (+ (* (aref a 1) (aref a 2)) (* (aref b 1) (aref b 2)) (* (aref c 1) (aref c 2))))
     (k20 (+ (* (aref a 2) (aref a 0)) (* (aref b 2) (aref b 0)) (* (aref c 2) (aref c 0)))))
  (aset im 0 0 (+ (* k1 k1) k11 (* k2 k2) k22))
  (aset im 1 1 (+ (* k2 k2) k22 (* k0 k0) k00))
  (aset im 2 2 (+ (* k0 k0) k00 (* k1 k1) k11))
  (aset im 0 1 (* -0.5 (+ (* k0 k1) k01))) (aset im 1 0 (aref im 0 1))
  (aset im 0 2 (* -0.5 (+ (* k0 k2) k20))) (aset im 2 0 (aref im 0 2))
  (aset im 1 2 (* -0.5 (+ (* k1 k2) k12))) (aset im 2 1 (aref im 1 2))
  (scale-matrix (/ (v. a (v* b c vtmp)) 120.0) im im) im)

(defun find-named-body (name shapes &key (test #'equal))
  (find-if #'(lambda (x) (funcall test name (send x :name))) shapes))

(defmethod body
  (:min-z-all
   (&optional (bodies (list self)))
   (send self :worldcoords)
   (elt (find-extream (flatten (send-all bodies :vertices))  #'(lambda (x) (elt x 2)) #'<) 2))
  (:max-z-all
   (&optional (bodies (list self)))
   (send self :worldcoords)
   (elt (find-extream (flatten (send-all bodies :vertices)) #'(lambda (x) (elt x 2)) #'>) 2))
  (:min-z-pos
   (&optional (p (send self :worldpos)) &aux (minp (float-vector 0 0 -1000000)) (v #f(0 0 1)))
   (bodies-vector-limit (list self) (v+ p minp) v #'<))
  (:max-z-pos
   (&optional (p (send self :worldpos)) &aux (minp (float-vector 0 0 -1000000)) (v #f(0 0 1)))
   (bodies-vector-limit (list self) (v+ p minp) v #'>))
  (:min-z
   (&optional (p (send self :worldpos)) &aux (minp (float-vector 0 0 -1000000)) (v #f(0 0 1)))
   (send self :min-z-pos p))
  (:max-z
   (&optional (p (send self :worldpos)) &aux (minp (float-vector 0 0 -1000000)) (v #f(0 0 1)))
   (send self :max-z-pos p))
  (:bottom-on
   (b)
   (send self :bottom-to-z :z (send b :max-z)))
  (:bottom-to-z-pos
   (&optional (z 0) (p (send self :worldpos)))
   (send self :worldcoords)
   (send self :translate (float-vector 0 0 (- z (send self :min-z-pos p))) :world)
   (send self :worldcoords))
  (:top-to-z-pos
   (&optional (z 0) (p (send self :worldpos)))
   (send self :worldcoords)
   (send self :translate (float-vector 0 0 (- z (send self :max-z-pos p))) :world)
   (send self :worldcoords))
  (:bottom-to-z
   (&key (z 0) (bodies (list self)))
   (send self :worldcoords)
   (send self :translate (float-vector 0 0 (- z (send self :min-z-all bodies))) :world)
   (send self :worldcoords))
  (:top-to-z
   (&key (z 0) (bodies (list self)))
   (send self :worldcoords)
   (send self :translate (float-vector 0 0 (- z (send self :max-z-all bodies))) :world)
   (send self :worldcoords))
  (:puton (bset &optional (on #f(0 0 -10000)) (from #f(0 0 -10000)))
	  (send bset :translate (float-vector (elt on 0) (elt on 1)
					      (- (send self :z-height on)
						 (send bset :z-depth from)))
		:world))
  (:z-limit
   (&optional (p #f(0 0 -10000)) (v #f(0 0 1)))
   (bodies-vector-limit (list self) p v))
  (:z-height (&optional (p (float-vector 0 0 -10000)) (v (float-vector 0 0 1)))
	     (send self :z-limit p v))
  (:z-depth (&optional (p (float-vector 0 0 10000)) (v (float-vector 0 0 -1)))
	    (send self :z-limit p v))
  )

(defmethod bodyset
  (:min-z-all
   (&optional (bodies (send self :bodies)))
   (send self :worldcoords)
   (elt (find-extream (flatten (send-all bodies :vertices)) #'(lambda (x) (elt x 2)) #'<) 2))
  (:max-z-all
   (&optional (bodies (send self :bodies)))
   (send self :worldcoords)
   (elt (find-extream (flatten (send-all bodies :vertices)) #'(lambda (x) (elt x 2)) #'>) 2))
  (:min-z-pos
   ()
   (send self :worldcoords)
   (find-extream (flatten (send-all (send self :bodies) :vertices))
		 #'(lambda (x) (elt x 2)) #'<))
  (:max-z-pos
   ()
   (send self :worldcoords)
   (find-extream (flatten (send-all (send self :bodies) :vertices))
		 #'(lambda (x) (elt x 2)) #'>))
  (:min-z
   (&optional (p pos) &aux (minp (float-vector 0 0 -1000000)) (v #f(0 0 1)))
   (bodies-vector-limit (send-all (send-all (send self :bodies) :box) :body)
			(v+ p minp) v #'<))
  (:max-z
   (&optional (p pos) &aux (minp (float-vector 0 0 -1000000)) (v #f(0 0 1)))
   (bodies-vector-limit (send-all (send-all (send self :bodies) :box) :body)
			(v+ p minp) v #'>))
  (:bottom-on
   (b)
   (send self :bottom-to-z :z (send b :max-z)))
  (:bottom-to-z
   (&key (bodies (send self :bodies)) (z 0))
   (let (p)
     (send self :worldcoords)
     ;;(setq p (send self :min-z-pos))
     ;;(send self :translate (float-vector 0 0 (- z (elt p 2))) :world)
     (send self :translate (float-vector 0 0 (- z (send self :min-z-all bodies))) :world)
     (send self :worldcoords)))
  (:top-to-z
   (&key (bodies (send self :bodies)) (z 0))
   (let (p)
     (send self :worldcoords)
     ;;(setq p (send self :max-z-pos))
     ;;(send self :translate (float-vector 0 0 (- (elt p 2))) :world)
     (send self :translate (float-vector 0 0 (- z (send self :max-z-all bodies))) :world)
     (send self :worldcoords)))
  (:inertia-matrix
   (&optional (c (make-cascoords)))
   (let* ((bs (send self :bodies))
	  (im (copy-object (send (car bs) :inertia-matrix c))))
     (dolist (b (cdr bs))
       (m+ im (send b :inertia-matrix c) im))
     (send self :inertia-tensor im)))
  (:weight ()
	   (or (get self :weight)
	       (apply #'+ (send-all (send self :bodies) :weight))))
  (:puton (bset &optional (on #f(0 0 -10000)) (from #f(0 0 -10000)))
	  (send bset :translate (float-vector (elt on 0) (elt on 1)
					      (- (send self :z-height on)
						 (send bset :z-depth from)))
		:world))
  (:z-limit
   (&optional (p (float-vector 0 0 -10000)) (v #f(0 0 1)))
   (bodies-vector-limit (send-all (send-all (send self :bodies) :box) :body)
			p v))
  (:z-height (&optional (p (float 0 0 -10000)) (v #f(0 0 1)))
	     (send self :z-limit p v))
  (:z-depth (&optional (p (float 0 0 10000)) (v #f(0 0 -1)))
	    (send self :z-limit p v))
  (:volume nil (apply #'+ (send-all (send self :bodies) :volume)))
  )

(defmethod bodyset
    (:bounding-box
     (&rest args)
	(unless
	    (get self :bounding-box)
	  (setf (get self :bounding-box)
		(make-bounding-box (send self :world-vertices))))
	(forward-message-to (get self :bounding-box) args))
  (:bounding-body
   (&rest args)
   (let ((bb (send (send self :bounding-box) :body)))
     (send bb :newcoords (send self :copy-worldcoords))
     (forward-message-to bb args)))
  )

(defmethod bodyset
#|
  (:weight 
   (&optional w)
   (cond
    (w (setq weight w) (setf (get self :weight) w)))
   weight)
|#
  (:cal-weight
   (&aux (w 0.0))
   (dolist (b (send self :bodies))
     (if (numberp (send b :weight))
	 (setq w (+ w (send b :weight)))))
      (setf (get self :weight) w))
  (:inertia-matrix
   (&optional (c (make-cascoords)))
   (let* ((bs (send self :bodies))
	  (im (copy-object (send (car bs) :inertia-matrix c))))
     (dolist (b (cdr bs))
       (m+ im (send b :inertia-matrix c) im))
     (send self :inertia-tensor im)))
  (:inertia-matrix-g
   (&optional (c (make-cascoords :pos (send self :centroid))))
   (let* ((bs (send self :bodies))
	  (im (copy-object (send (car bs) :inertia-matrix c))))
     (dolist (b (cdr bs))
       (m+ im (send b :inertia-matrix c) im))
     (send self :inertia-tensor im)))
  (:vertices
   ()
   (flatten (send-all (send self :bodies) :vertices)))
  (:world-vertices
   ()
    (mapcar #'(lambda (v) (send self :inverse-transform-vector v))
	    (send self :vertices)))
  (:min-z-pos
   ()
   (send self :worldcoords)
   (find-extream
    (flatten (send-all (send self :bodies) :vertices))
    #'(lambda (x) (elt x 2)) #'<))
  )

(defun revolution2cylinder (b)
  (let* ((csg (b . csg))
	 (vv (mapcar #'(lambda (x) (send b :inverse-transform-vector x)) (cadr (assoc :revolution csg))))
	 (bbox (make-bounding-box vv))
	 (minp (send bbox :minpoint))
	 (maxp (send bbox :maxpoint))
	 (mean (vector-mean (list minp maxp)))
	 (dif (v- maxp minp))
	 cyl)
    (setq cyl (make-cylinder (elt maxp 0) (elt dif 2)))
    (send cyl :translate-vertices (float-vector 0 0 (elt minp 2)))
    (send cyl :worldcoords)
    ;;(send cyl :newcoords (make-coords :pos (float-vector 0 0 (elt minp 2))))
    (send cyl :newcoords (send b :copy-worldcoords))
    cyl))

(defmacro wait-key (form)
  `(do-until-key (print ,form) (unix::usleep (* 100 1000))
		 (if (xwindow-ready?) (x::window-main-one))
		 ))

(defun print-servo-id-vector ()
  (let* ((ids (send *ri* :servo-sorted-ids))
         (s (apply #'concatenate string (mapcar #'(lambda (x) (format nil "~d, " x)) ids))))
    (format t "~A~%" (concatenate string "{" (subseq s 0 (- (length s) 2)) "};"))))

(defun signed2unsigned (value bite-size)
  (cond ((or (> value 0) (eq value 0)) value)
	(t
	 (+ value (expt 2 (* 8 bite-size))))))


