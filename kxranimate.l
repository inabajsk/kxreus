;;;
;;;	bvh animation M.I.
;;;	2017.9.1  created as :animate-demo
;;;	2025.11.2 kxr-robots
;;;	2025.11.3 khr-robots
;;;
(require :rcb4robots)
(require :eus2wrl)
(require :eus2mjcf)

(defun load-robot (name)
  (let ((fname (format nil "~A/models/~A.l" *rcb4eus-dir*
		       (string-downcase (string name)))))
    (unless (probe-file fname)
      (eus2collada-robot name))
    (load fname)
    (setq *robot* (apply (read-from-string (string name)) nil))
    *robot*))

(defun bvh-load nil
  (load (format nil "~A/bvh/sfu-demo.l" *rcb4eus-dir*)))

(bvh-load)

(format t "; (objects-kxr-robots)~%; (animate)~%")
(format t "; (objects-kxr-robots :sample 1) ;; for all~%")
(format t "; (kxr-robots)~%")
(format t "; (khr-robots)~%")
(format t "; (all-robots)~%")

(defun kxr-operation ()
  (let* ((s (kxr-operation-stand :offset 0))
	 (j (get s :joint-coord))
	 (r (kxr-robot :torso :y-p :shoulder :cross :wrist :y-p-y :gripper t))
	 (b (send r :body-link :get :bottom))
	 )
    (send r :move-coords j b)
    (objects (list s r))))

(defun n-sample (seq &optional (scale 1.0))
  (let* ((len (length seq))
	 (n len) cof lst)
    (if (> scale 1.0)
	(if (< scale len) (setq n (round scale)))
      (setq n (round (* len scale))))
    (setq cof (/ len (float n)))
    (dotimes (i n)
      (push (elt seq (round (* i cof))) lst))
    (reverse lst)))

(defun kxr-sample-names (&optional count)
  (setq *kxr-sample-names*
	(n-sample *kxr-all-robot-names* count)))

(setq *kxr-all-robot-names*
      (list 
       "kxrl6"	 "kxrl4t"	 "kxrl4c2"	;;	 "kxrl4l3a3"
       "kxrl4l3a3" 	"kxrl4c3"  "kxrl4d"		;;"kxrl4b3"
       "kxrl4b4"	"kxrl4c"
       "kxrl4b2sn" 	 "kxrl4b1" 	 ;; "kxrl4b2"
       "kxrl4r"	      "kxrl4ct2a7h2"
       "kxrl4r2a3" 	"kxrl4r2a3gl" 	"kxrl4r2l3"
       "kxrdw4a6h2m"	 "kxrow4a6h2m"	 "kxrmw4a7h2m"	 
       "kxrl2semi2022s"	 "kxrl2l2a6h2m"	 "kxrl2g"
       "kxrl2l5a4h2g"	 "kxrl2w2l5a4h2"	 "kxrl2w2l6a5h2"	 "kxrl2w2l6a6h2"
       "kxrl2w2l6a7h2w"	 "kxrl2l6a6h2m"	 "kxrl2l6a7h2"	 "kxrl2t2l6a7h2yprb"
       "kxrl2t2l6a7h2d405"	 "kxrl2l7a7w"	 "kxrkamakiri"	 "kxrl2makabe"
       "kxrl2makabels" "kxrl2makabelc"	 "kxrl2makabelcw"
       ;;"kxrl2l6anzaifly"
       ))

(setq *kxr-robot-names* *kxr-all-robot-names*)
(setq *khr-robot-names*
      '(
	"khr3" "khranzaifly" "khranzaifly5" "khrh2ganzaiflys"
	"khrl5a3h2" "khrl5a3h2g" "khrl5a3h2wg" "khrl5a4h2g" "khrl5a4h2wg"
	"khrl6a3h2" "khrl6a3h2g" "khrl6a3h2wg" "khrl6a4h2" "khrl6a4h2g"
	"khrl6a4h2wg" "khrt1l5a3h2g" "khrt1l5a3h2wg" "khrt1l5a4h2g" "khrt1l5a4h2wg"
	"khrt1l6a3h2" "khrt1l6a3h2g" "khrt1l6a3h2m" "khrt1l6a3h2wg" "khrt1l6a4h2g"
	"khrt1l6a4h2wg"
	))

(setq *ros-distro* (unix::getenv "ROS_DISTRO"))
(setq *ros-distro-null* (or (null *ros-distro*) (equal *ros-distro* "")))
(defun make-robot (name) (funcall (read-from-string name)))
(defvar *kxr-sample-robots*)
(defun kxr-sample-robots (&key (model (if *ros-distro-null* nil 0))
			       generate
			       (sample 1.0) &aux r)
  (setq *kxr-sample-robot-names* (n-sample *kxr-all-robot-names* sample))
  (setq *kxr-sample-robots* nil)
  (dolist (name *kxr-sample-robot-names*)
    (cond
     ((setq r (find name *robots-made* :key #'(lambda (x) (send x :name)) :test #'equal))
      (push r *kxr-sample-robots*))
     (t
      (warn " kxr-sample-robots ~A~%" name)
      (push (kxr-make-robot name :model model :generate generate :viewer nil)
	    *kxr-sample-robots*))))
  (reverse *kxr-sample-robots*))

(defun objects-kxr-robots (&rest args
				 &key
				 (sample 0.3)
				 (robots (reverse (kxr-sample-robots :sample sample)))
				 (n 6) (xs 600) (ys xs)
				 (spos #f(0 -600 0))
				 base coords (color (float-vector 0.7 1.0 1.0))
				 &allow-other-keys)
  (apply #'show-2d-arrange robots :n n :xs xs :ys ys :spos spos :coords coords
	 :base base args)
  (send *irtviewer* :change-background color)
  (send *irtviewer* :draw-objects)
  )

(defun axis-vector (v)
  (if (vectorp v) v
    (case v
	  (:x #f(1 0 0))
	  (:-x #f(-1 0 0))
	  (:y #f(0 1 0))
	  (:-y #f(0 -1 0))
	  (:z #f(0 0 1))
	  (:-z #f(0 0 -1)))))
     
(defmethod joint
  (:axis (&optional v) (if v (setq axis (axis-vector v))
			 (axis-vector axis)))
  (:reverse-axis nil (send self :axis (scale -1 (send self :axis))))
  (:sign (&optional v) (if v (setf (get self :sign) v)) (get self :sign))
  )
(defun x0 (xwidth)
  (- (send x::*root* :width) xwidth 100))

(defun create-robot-models (robots &aux name rr)
  (dolist (r robots)
    (setq name (string-downcase (string r)))
    (unless (probe-file (format nil "~A/models/~A.l" *rcb4eus-dir* name))
      ;;(format t ";; (create-robot-models) generate ~A~%" name)
      (eus2collada-robot name)
      )
    (setq rr (load-robot name))
    (unless (probe-file (format nil "~A/mjcfs/~A" *rcb4eus-dir* name))
      (send rr :dump-mjcf))
    ))

(defun khr-robots (&rest args &key (robots *khr-robot-names*)
			 (xcount 10)
                         (ylines (1+ (/ (length robots) xcount)))
                         (titley 60)
                         (height (- (/ (- (send x::*root* :height) 300 titley) ylines) titley))
                         (width height)
			 ;;(xcount (round (+ 0.5 (/ (length robots) (float ylines)))))
			 (rs 5) (msec 1)
			 ;;(xcount (* (/ xcount0 rs) rs))
			 (x0 (x0 (* xcount (+ width)))) (y0 50)
                         &allow-other-keys)
  (create-robot-models robots)
  (apply #'create-piped-robots :robots robots :rs rs :x0 x0 :y0 y0 :width width :height height :xcount xcount :msec msec args))

(defun kxr-robots (&rest args &key (robots *kxr-robot-names*)
                         (xcount 12) (rs 4)
                         (ylines (1+ (/ (length robots) xcount)))
                         (titley 60)
                         (height (- (/ (- (send x::*root* :height) 200 titley) ylines) titley))
                         (width height) (msec 1)
			 (x0 (x0 (* xcount (+ width)))) (y0 50)
                         &allow-other-keys)
  (create-robot-models robots)
  (apply #'create-piped-robots :robots robots :rs rs :x0 x0 :y0 y0 :width width :height height :xcount xcount :msec msec args))

(defun all-robots (&rest
		   args
		   &key (robots (append *kxr-robot-names* *khr-robot-names*))
		   (xcount 14) (rs 7)
		   &allow-other-keys)
  (apply #'kxr-robots :robots robots :xcount xcount :rs rs args))

(defun all-robots2 nil
  (khr-robots :robots (append *kxr-robot-names* *khr-robot-names*)))

(defun create-piped-robots (&key (robots *kxr-robot-names*)
                                 (width 280) (height 280)
                                 (xskip 10)  (yskip 50) (xcount 10)
				 ;;(rs (if (> (length robots) 28) 2 1))
				 (rs xcount) (msec 10)
				 (x0 (x0 (* xcount (+ width)))) (y0 50)
				 &allow-other-keys)
  (let ((len (/ (length robots) rs)) name (x x0) (y y0) strm)
    (setq *piped-streams* nil)
    (dotimes (i len)
      (setq n nil)
      (dotimes (j rs) (push (pop robots) n))
      (setq strm (piped-robot (reverse n)
			      :x x :y y :wx width :wy height :msec msec))
      (push strm *piped-streams*)
      (dotimes (j rs)
	(if
	    (= (1- xcount) (mod (+ j (* i rs)) xcount))
	    (setq x x0 y (+ y height yskip))
	  (setq x (+ x width xskip))))
      )
    (when robots
      (setq strm (piped-robot robots :x x :y y :wx width :wy height))
      (push strm *piped-streams*)
      (dotimes (j (length robots))
	(setq x (+ x width xskip)))
      ))
  )

(defun piped-robot (nlist &key (x 50) (y 50) (wx 200) (wy 200) (msec 10))
  (piped-fork
   (format
    nil
    "irteusgl kxranimate.l '(robot-non-itimer (quote ~A) :x0 ~A :y0 ~A :width ~A :height ~A :xcount ~A :msec ~A)' 2> /dev/null"
    nlist x y wx wy (length nlist) msec))
  )

(defun irteus-pids (&optional (str "irt"))
  (let* ((strm (piped-fork (format nil "ps a | grep ~A" str)))
	 l ret)
    (while (setq l (read-line strm nil nil))
      (push (psline-pid l) ret))
    (reverse ret)))
(defun psline-pid (l) (read-from-string l))

(setq *start-pids* (irteus-pids))
(defun kill-pids (pids &aux s)
  ;;(print (list 'pids= pids))
  (dolist (pid pids)
    (unix::kill pid 9)
    ;;(setq s (format nil "sudo kill -9 ~A > /dev/null" pid))
    ;;(print s)
    ;;(unix::system s)
    ))

(setq *piped-streams* nil)
(defun kill-subs (&optional (str "irt"))
  (dolist (strm *piped-streams*)
    (format strm "(exit)~%")
    (unix:kill (get strm :pid) 9)
    (unix:usleep (* 100 1000))
    (close strm))
  (setq *piped-streams* nil)
  (kill-pids (set-difference (irteus-pids str) *start-pids*))
  nil)
(defun kill-start () (kill-pids *start-pids*))
(defun kill-all (&optional (str "irt"))
  (kill-subs str)
  (kill-start)
  )

(defun kxr-defun-form (robot)
  (let* ((name-string (read-from-string (send robot :name)))
	 (bod (cdr (kxr-define-lambda-form name-string (send robot :config)))))
    `(defun ,name-string ,@bod)))

(defun kxr-define-robot (name &optional options)
  (setf (symbol-function name) (kxr-define-lambda-form name options)))

(defun kxr-define-lambda-form (name &optional options)
  (let* ((sname (string-downcase (string name)))
	 (fname (format nil "dumped-robots/~A.l" sname))
	 (gvar (robot-gvar name))
	 (cls-name 'kxr-robot)
	 ;;(cls (symbol-value cls-name))
	 cls
	 (args options))
    (cond
      ((boundp cls-name)
       (setq cls (symbol-value cls-name)))
      (t (error "name=~A sname=~A cls-name=~A~%" name sname cls-name)))
    `(lambda (&optional (eval t))
       (let* ((fp (probe-file ,fname)))
	 (cond
	  ((or eval (null fp))
	   (setq ,gvar (instance ,(metaclass-name cls) :init :name ,sname ,@args)))
	  (t (format t ";; loading ~A~%" ,fname) (load ,fname)))
	 ;;(unless fp
	 ;;(format t ";; dumping ~A to ~A~%" ',gvar ,fname)
	 ;;(dump-kxr-model (symbol-value ',gvar) :fglvertices t))
	 ,gvar)))
  )

(defun robot-non-itimer (names &key
			       (msec 10)
			       (width 200) (height 200) (xcount 11)
			       (x0 (x0 (* xcount (+ width)))) (y0 50)
			       ) 
  (let* ((len (length names))
	 (robots (instantiate vector len))
	 name (x x0) (y y0) (xskip 10)  (yskip 55))
    (bvh-load)
    (dotimes (i len)
      (setf (elt robots i) (load-robot (elt names i)))
      (send (elt robots i)
	    :show-self :x x :y y :width width :height height)
      (if
	  (= (1- xcount) (mod i xcount))
	  (setq x x0 y (+ y height yskip))
	(setq x (+ x width xskip))))
    (do-until-key
     (dotimes (i len)
       (when (derivedp (elt robots i) robot-model)
	 (send (elt robots i) :mcd-tick))
       (x::window-main-one)
       (unix::usleep (* msec 1000))
       )))
  )

(defmethod robot-model
  (:animate-list nil (get self :animate-list))
  (:draw-animate
   (&optional (number 1) (vel 300) (al (get self :animate-list)))
   (if (null al)
       (animate :number number)
     (do-until-key
      (if (null al) (return-from :draw-animate))
      (send *robot* :angle-vector (pop al))
      (send *irtviewer* :draw-objects))))
  (:run-animate
   (&optional (number 1) (vel 300))
   (if (null (get self :animate-list)) (animate :number number))
   (dolist (av (get self :animate-list))
     (send (get self :ri) :angle-vector av vel))
   (send self :reset-pose)
   (send self :send-to-ri))
  )

(defmethod robot-model
  (:animate-files
   (&optional (names *bvh-files*) (file "bvh/sfu-demo.l"))
   (load file)
   (setf (get self :animate-files) names)
   (get self :animate-files))
  (:sfu-files
   (&optional (file "bvh/sfu-demo.l"))
   (send self :animate-files *bvh-files* file))
  (:pop-mcd nil (pop (get self :animate-files)))
  (:mcd-file nil (car (send self :animate-files)))
  (:mcd-index
   nil
   (when (null (get self :mcd-index))
     (setf (get self :mcd-index) 0))
   (get self :mcd-index))
  (:mcd
   (&optional (scale 10.0))
   (when (null (get self :mcd))
     (setf (get self :mcd)
	   (load-mcd (send self :mcd-file)
		     :scale scale
		     :bvh-robot-model-class sfu-bvh-robot-model)))
   (get self :mcd))
  (:mcd-index
   nil
   (when (null (get self :mcd-index)) (setf (get self :mcd-index) 0))
   (when (>= (get self :mcd-index) (send (send self :mcd) :frame-length))
     (send self :pop-mcd)
     (setf (get self :mcd-index) 0))
   (get self :mcd-index))
  (:mcd-state-load
   (&optional (step 1) (stay t))
   (send (send self :mcd) :frame (send self :mcd-index))
   (send (send (send self :mcd) :model) :copy-state-to self stay)
   (incf (get self :mcd-index) step)
   (when (>= (send self :mcd-index) (send (send self :mcd) :frame-length))
     (send self :pop-mcd))
   )
  (:show-self
   (&key x y (width 200) (height 200))
   (send self :create-viewer :x x :y y :width width :height height)
   (send (get self :viewer) :draw-objects)
   ;;(send (get self :viewer) :string 50 (- (send (get self :viewer) :height) 10)
   ;;(format nil "~3A" (send self :mcd-index)))
   )
  (:mcd-tick nil
	     (send self :mcd-state-load)
	     (send self :show-self :width (send (get self :viewer) :width)
		   :height (send (get self :viewer) :height))
	     )
  (:create-viewer
   (&key x y (width 200) (height 200))
   (unless (get self :viewer)
     ;;(format t "; :create-viewer width=~A height=~A x=~A y=~A~%" width height x y)
     (setf (get self :viewer)
	   (make-irtviewer :width width :height height))
     (send (get self :viewer) :objects (list self))
     (send (get self :viewer) :title (send self :name))
     (send (get self :viewer) :look-all)
     )
   (when (and x y) (send (get self :viewer) :move x y))
   (send (get self :viewer) :draw-objects)
   ))

(defun show-2d-arrange (&optional (objs (objects))
				  &key
				  ;;(n (if (< (length objs) 40) 5 (round (sqrt (length objs)))))
				  coords
				  (base t)
				  (des coords)
				  (prop t)
				  n
				  (xs 100)
				  (ys 100)
				  spos
				  ((:viewer vwer))
				  &allow-other-keys)
  (if (null n) (setq n (round (sqrt (/ (length objs) 1.4)))))
  (if (null spos) (setq spos (float-vector 0 (- (* ys (/ n 2))) 0)))
  (let ((res objs) (len (length objs)) (x 0) obj)
    (while res
      (dotimes (y n)
	(if (setq obj (pop res))
	    (send obj :locate (v+ spos (float-vector (* xs x) (* ys y) 0)) :world))
	)
      (setq x (1+ x))
      )
    (objects+ objs :coords coords :base base :des des :prop prop :viewer vwer)))

(defun kxr-dump-body-views  (&rest args)
  (apply #'kxr-draw-views `(:funcs ,(kxr-scan-all-bodies) :dir "body-views" ,@args)))
(defun kxr-dump-bodyset-views (&rest args)
  (apply #'kxr-draw-views `(:funcs ,(kxr-scan-all-bodysets) :dir "bodyset-views" ,@args)))
(defun kxr-dump-link-views  (&rest args)
  (apply #'kxr-draw-views `(:funcs ,(kxr-scan-all-links) :dir "link-views" ,@args)))
(defun kxr-dump-kxrl2l5-views (&rest args &key (options *kxr-l2l5all-options*) (func 'kxr-l2))
  (let ((forms (mapcar #'(lambda (x) (cons func (append (cdr x) (list :name (string (car x)))))) options)))
    (kxr-draw-views :funcs forms :dir "kxrl2l5-views")))
(defun kxr-dump-kxrl2l6-views (&rest args &key (options *kxr-l2l6all-options*) (func 'kxr-l2))
  (let ((forms (mapcar #'(lambda (x) (cons func (append (cdr x) (list :name (string (car x)))))) options)))
    (kxr-draw-views :funcs forms :dir "kxrl2l6-views")))
(defun kxr-dump-kxrl4-views (&rest args &key (options *kxr-l4all-options*) (func 'kxr-l4))
  (let ((forms (mapcar #'(lambda (x) (cons func (append (cdr x) (list :name (string (car x)))))) options)))
    (kxr-draw-views :funcs forms :dir "kxrl4-views")))

(defun kxr-draw-bodies (&rest args) (apply #'kxr-draw-views `(:funcs ,*kxr-body-functions* ,@args)))
(defun kxr-draw-bodysets (&rest args) (apply #'kxr-draw-views `(:funcs ,(kxr-scan-all-bodysets) ,@args)))
(defun kxr-draw-links (&rest args) (apply #'kxr-draw-views `(:funcs ,(kxr-scan-all-links) ,@args)))
(defun kxr-draw-robots (&rest args &key (func 'kxr-l2) (options *kxr-l2s-options*))
  (let ((forms (mapcar #'(lambda (x) (cons func (append (cdr x) (list :name (string (car x)))))) options)))
    (kxr-draw-views :funcs forms)))
(defun kxr-draw-all-robots (&rest args) (kxr-draw-views :funcs (kxr-all-string-names) :dir "all-robots"))
(defun kxr-draw-views (&rest args &key
				    (funcs *kxr-body-functions*)
				    dir (delay 40) (loop t) noname
				    &allow-other-keys)
  (let (objs img img-noname form fname str images gifname gifname-noname
	     obj (gifnames " ") (gifnames-noname " ") (counter 0))
    (when dir
      (unless (probe-file dir) (unix::mkdir dir))
      (unless (probe-file (format nil "~A/nonames" dir))
	(unix::mkdir (format nil "~A/nonames" dir))))
    (dolist (func funcs)
      (cond
	((stringp func)
	 (objects+ (list (setq obj (kxr-create-robot func))))
	 (setq form (list (read-from-string func))))
	((symbolp func)
	 (if (symbolp func) (setq form (list func))
	     (setq form func))
	 (objects+ (list (setq obj (eval form))))))
      (setq str (format nil "~A" form))
      (setq img-noname (send *irtviewer* :viewer :viewsurface :getglimage))
      (unless noname
	(send *irtviewer* :string 8 20 (format nil "~A:~A" counter str))
	(send *irtviewer* :string 8 (- (send *irtviewer* :height) 8)
	      (format nil "name:~A" (send obj :name))))
      (when dir
	(if (symbolp func)
	    (apply #'objects+ (list (setq obj (apply func nil))) `(:des t ,@args))
	    (if (stringp func)
		(objects+ (list (setq obj (kxr-create-robot func))))
		(objects+ (list (setq obj (eval form))))))
	(send *irtviewer* :string 8 20 (format nil "~A:~A" counter str))
	(send *irtviewer* :string 8 (- (send *irtviewer* :height) 8)
	      (format nil "name:~A" (send obj :name)))
	(setq img (send *irtviewer* :viewer :viewsurface :getglimage))
	(setq fname (format nil "~A/~A.pnm" dir (car form)))
	(setq fname-noname (format nil "~A/nonames/~A-noname.pnm" dir (car form)))
	(image::write-image-file fname img)
	(image::write-image-file fname-noname img-noname)
	(setq gifname (format nil "~A/tmp~A.gif" dir counter))
	(setq gifname-noname (format nil "~A/tmp-noname~A.gif" dir counter))
	(setq gifnames (concatenate string gifnames " " gifname))
	(setq gifnames-noname (concatenate string gifnames-noname " " gifname-noname))
	(unix:system (format nil "convert ~A ~A" fname gifname))
	(unix:system (format nil "convert ~A ~A" fname-noname gifname-noname))
	)
      (unless noname (send *irtviewer* :string 8 20 (make-string (length str))))
      (incf counter))
    (when dir
      (unix:system
       (format nil
	       "gifsicle -O2 -D2 -w --delay=~A -t#000000 ~A --colors 256 ~A > ~A/~A-t.gif"
	       delay (if loop "--loop" "") gifnames dir dir))
      (unix:system
       (format nil
	       "gifsicle -O2 -D2 -w --delay=~A ~A --colors 256 ~A > ~A/~A.gif"
	       delay (if loop "--loop" "") gifnames dir dir))
      (unix:system
       (format nil
	       "gifsicle -O2 -D2 -w --delay=~A -t#000000 ~A --colors 256 ~A > ~A/~A-t-noname.gif"
	       delay (if loop "--loop" "") gifnames-noname dir dir))
      (unix:system
       (format nil
	       "gifsicle -O2 -D2 -w --delay=~A ~A --colors 256 ~A > ~A/~A-noname.gif"
	       delay (if loop "--loop" "") gifnames-noname dir dir))
      (unix:system  (format nil "rm ~A ~A" gifnames gifnames-noname)))
    ))


(defun kxr-draw-face (f &aux fr (b (objects)))
  (setq fr (instance geo::faceset :init :faces (list f)))
  (send fr :set-color :red)
  (print f)
  (objects (cons fr b)))

(defun kxr-draw-faces (b &aux fr)
  (dolist (f (send b :faces))
    (kxr-draw-face f)
    (do-until-key (x::window-main-one))))
      
(defun kxr-dump-views-gif (images &key (name "file") transparent (loop t))
  (make-animgif-from-images name images :transparent transparent :loop loop :delay 1))

(defun make-animgif-from-images
  (giffile images
	   &key (delete t)
	   transparent
	   (loop t)
	   (delay 10))
  (let* ((counter 0) (basename (pathname-name giffile))
	 gif-filename ppm-filename (gif-filenames " ") cmd)
    (if (string= ".gif" (subseq basename (- (length basename) 4)))
	(setq basename (subseq basename 0 (- (length basename) 4))))
    (setq gif-filename (format nil "~A.gif" basename))

    (dolist (pm images)
      (setq ppm-filename (format nil "/tmp/~A~A.ppm" basename counter))
      (setq gif-filename (format nil "./tmp~A.gif" counter))
      (setq gif-filenames (concatenate string gif-filenames " " gif-filename))
      (image::write-pnm-file ppm-filename pm)
      ;;(format t ";writing ~A...~%" ppm-filename)      
      (unix:system (format nil "convert ~A ~A" ppm-filename gif-filename))
      (if delete (unix:system (format nil "rm ~A " ppm-filename)))
      (incf counter))
    
    (setq cmd 
	  (format
	   nil
	   "gifsicle -O2 -D2 -w --delay=~A ~A ~A --colors 256 ~A > ~A.gif"
	   delay
	   (if transparent "-t#000000" "")
	   (if loop "--loop" "")
	   gif-filenames basename))
    (if *debug* (warn cmd))
    (unix:system cmd)
    (if delete (unix:system  (format nil "rm ~A " gif-filenames)))
    ))

(defun kxr-all-bodies0 (&optional eval)
  (when
      (or eval (not (boundp '*kxr-all-bodies*)))
    (setq *kxr-all-bodies*
	  (list
	   ;;(kxr-remocon)
	   (kxr-servo-s3300)
	   (kxr-back-pack)
	   (kxr-battery-box)
	   (kxr-battery-leg-plate)
	   (kxr-body-plate)
	   (kxr-body-plate-spacer)
	   (kxr-joint-base)
	   (kxr-bottom-spacer)
	   (kxr-flat-frame)
	   (kxr-angle-bracket)
	   (kxr-finger-a)
	   (kxr-finger-b)
	   (kxr-upper-arm20)
	   (kxr-bottom-arm20)
	   (kxr-upper-arm26)
	   (kxr-bottom-arm26)
	   (kxr-upper-arm38)
	   (kxr-bottom-arm38)
	   (kxr-arm-supporter-a)
	   (kxr-arm-supporter-b)
	   (kxr-sole)
	   (kxr-cross-servo-frame-a)
	   (kxr-cross-servo-frame-b)
	   (kxr-lock-ring-cap)
	   (kxr-lock-ring)
	   (kxr-joint-frame-a)
	   (kxr-euclid-head)
	   (kxr-wheel)
	   (kxr-joint-frame-b-a)
	   (kxr-joint-frame-b-b)
	   ))
    )
  *kxr-all-bodies*
  )

(defun kxr-all-bodies (&optional eval)
  (when
      (or eval (not (boundp '*kxr-all-bodies*)))
    (setq *kxr-all-bodies*
	  (mapcar #'(lambda (x) (funcall x))
		  *kxr-body-functions*)))
  *kxr-all-bodies*)

(defun kxr-all-screws nil
  (list (kxr-screw-m2x4) (kxr-screw-m2x6)
	(kxr-screw-m2x8)
	(kxr-screw-m2x10)
	(kxr-screw-m2x12)
	(kxr-screw-m2.6x4)
	(kxr-screw-m2.6x10)
	(kxr-screw-m3x6)
	(kxr-screw-m3x8)))

(defun kxr-show-all-screws (&key coords base des eval (prop t))
  (show-2d-arrange (kxr-all-screws)
		   :xs 15 :ys 15 :base (or coords base) :des (or coords des) :prop prop))

(defun kxr-show-all-bodies (&key coords base des eval (prop t))
  (show-2d-arrange (kxr-all-bodies eval)
		   :base (or coords base) :des (or coords des) :prop prop))

(defun kxr-all-bodysets nil
  (unless
      (boundp '*kxr-all-bodysets*)
    (setq *kxr-all-bodysets*
	  (list
	   (kxr-l2-body-bodyset)
	   (kxr-battery-torso-bodyset)
	   (kxr-l4d-bodyset)
	   (kxr-l4tr-bodyset)
	   (kxr-l6-bodyset)

	   (kxr-angle-bracket-arms-bodyset)
	   (kxr-angle-arm-bodyset)
	   (kxr-arm-base-bodyset)
	   (kxr-arm-chain-base-bodyset)
	   (kxr-l6-foot-bodyset)

	   (kxr-double-servo-flat-frames-bodyset)
	   (kxr-cross-servo-bodyset)
	   (kxr-cross-servo-for-torso-bodyset)
	   (kxr-wheel-servo-spacer-bodyset)
	   (kxr-wheel-servo-spacer-bodyset :base-a t)

	   (kxr-servo-half-arm-supporter-a-bodyset)
	   (kxr-servo-double-arm-supporter-a-bodyset)
	   (kxr-l4d-crotch-p-bodyset)
	   (kxr-l4tr-crotch-p-bodyset)

	   (kxr-servo-supporter-bodyset)
	   (kxr-servo-bottom-supporter-bodyset)
	   (kxr-servo-bottom-supporter-bodyset :align t)
	   (kxr-gripper-servo-bodyset)
	   (kxr-joint-base-a-servo-bodyset) ;; base -> servo :l2-neck-base-a

	   (kxr-servo-frame-base-a-bodyset) ;; servo -> base :elbow-p, wrist-y, elbow-gripper 
	   (kxr-joint-frame-base-a-bodyset)
	   (kxr-joint-frame-base-b-bodyset)
	   (kxr-servo-joint-base-b-bodyset)

	   (kxr-finger-bodyset)
	   (kxr-chest-center-bodyset)
	   (kxr-passive-wheel-bodyset)
	   )))
  *kxr-all-bodysets*
  )

(defun kxr-show-all-bodysets (&key coords (base t) des (prop t))
  (show-2d-arrange (kxr-all-bodysets)
		   :n 5 :xs 200 :ys 200
		   :base (or coords base) :des (or coords des)
		   :prop prop))

(defun kxr-scan-all-bodies () (kxr-scan-all-funcs "kxrbody.l" " " kxr-body))
(defun kxr-scan-all-bodysets (&optional cls) (kxr-scan-all-funcs "kxrbodyset.l" "-bodyset" cls))
(defun kxr-scan-all-links (&optional cls) (kxr-scan-all-funcs "kxrlinks.l" "-link" cls))

(defun kxr-scan-all-funcs (&optional (fname "kxrlinks.l") (name "-link") result-cls)
  (let (res flist sym arg str-len (eof (cons nil nil)) str (name-len (length name)))
    (setq name (string-upcase name))
    (with-open-file (f fname :direction :input)
      (while (not (eq eof (setq sym (read f nil eof))))
	(cond
	  ((atom sym))
	  ((eq 'defun (car sym))
	   (setq arg (caddr sym))
	   (setq sym (cadr sym))
	   (setq str (string sym))
	   (setq str-len (length str))
	   (cond
	     ((and result-cls (or (null arg) (member (car arg) '(&rest &key &optional))))
	      (setq res (apply sym nil))
	      ;;(print (list sym res))
	      (when (eq (class res) result-cls)
		;;(print (list sym arg))
		(push sym flist)))
	     ((string-equal name (subseq str (max (- str-len name-len) 0))) 
	      ;;(print (list str str-len))
	      (push sym flist)))
	   ))))
    (reverse flist)))

(defun kxr-all-links0 ()
  (unless
      (boundp '*kxr-all-links*)
    (setq
     *kxr-all-links*
     (list
      ;; 1
      (kxr-l2l5-body-link)
      (kxr-l2l6-body-link)
      (kxr-l4d-body-link)
      (kxr-l4tr-body-link)
      (kxr-l6-body-link)
      ;; 2
      (kxr-l2-head-link)
      (kxr-l4d-neck-link)
      (kxr-l4r-crotch-link)
      (kxr-l6-knee-link)
      (kxr-l4d-ankle-link)
      ;; 3
      (kxr-wrist-gripper-link)
      (kxr-servo-frame-base-a-link)
      (kxr-arm-base-link)
      (kxr-double-arm-base-link)
      (kxr-shoulder-cross-r-link)
      ;; 4    
      (kxr-shoulder-cross-y-link)
      (kxr-l4t-crotch-link)
      (kxr-l6-foot-link)
      (kxr-wrist-cross-r-link)
      (kxr-wrist-y-link)
      ;; 5
      (kxr-wrist-r-gripper-link)
      (kxr-wrist-p-gripper-link)
      (kxr-y-wrist-r-link)
      (kxr-y-wrist-p-link)
      (kxr-shoulder-r-link)
      ;; 6    
      (kxr-elbow-p-gripper-link)
      (kxr-servo-wrist-y-link)
      (kxr-servo-wrist-r-link)
      (kxr-cross-servo-link)
      (kxr-crotch-cross-wheel-link)
      ;; 7
      (kxr-ankle-cross-wheel-link)
      (kxr-angle-arm-link)
      (kxr-finger1-link)
      (kxr-finger2-link)
      (kxr-foot-link)
      ;; 8
      (kxr-wheel-link)
      )))
  *kxr-all-links*
  )
(defun kxr-all-links ()
  (mapcar #'(lambda (f) (print (list 'func f)) (apply f nil)) (kxr-scan-all-links)))

(defun kxr-show-all-links (&key coords (base t) des (prop t))
  (show-2d-arrange
   (kxr-all-links) :n 8 :xs 200 :ys 200
   :base (or coords base) :des (or coords des) :prop prop))

(defun kxr-show-all-parts (&key coords base des (prop t))
  (show-2d-arrange
   (append (kxr-all-bodies) (kxr-all-bodysets))
   :n 5 :xs 200 :ys 200
   ))

;;;
;;; create options
;;;
;;;	*kxr-forearm-options*   7
;;;	*kxr-arm-options* 	63(7 x 3 x 3(gripper,wheel))
;;;	*kxr-head-options* 	4
;;;	*kxr-armhead-options* 	252(4 x 7 x 3 x 3)
;;;
;;;	*kxr-l2l5all-options* 	1008(4 x 252)
;;;	*kxr-l2l6all-options* 	1008(4 x 252)
;;;	*kxr-l2nl6all-options*	1008(4 x 252)
;;;	*kxr-l2wl6all-options*	1008(4 x 252)
;;;	*kxr-l4all-options*	9
;;;	*kxr-l6all-options*	3
;;;
;;;	*kxr-all-options*	4044 = (+ 1008 1008 1008 1008 9 3)
;;;	*kxr-all-names*	 	list of function names
;;;

(setq *kxr-forearm-options* ;; default 3(pitch,roll,pitch)
      '(
	(a3)
	(a4y   :wrist :y)
	(a4r   :wrist :r)
	(a5yr  :wrist :y-r)
	(a5yp  :wrist :y-p)
	(a5c   :wrist :cross)
	(a6cy  :wrist :cross-y)
	))
(defun kxr-arm-merge-name (nam str)
  (let* ((nam-str (copy-seq (symbol-name nam))))
    (setf (elt nam-str 1) (1+ (elt nam-str 1))) ;; (1+ degree)
    (read-from-string
     (concatenate string (subseq nam-str 0 2) str (subseq nam-str 2)))))

(setq *kxr-arm-options*
      (mapcan
       #'(lambda (x)
	   (list  x
		  (cons (kxr-arm-merge-name (car x) "y")
			(append '(:shoulder :y) (cdr x)))
		  (cons (kxr-arm-merge-name (car x) "c")
			(append '(:shoulder :cross) (cdr x)))
		  ))
       *kxr-forearm-options*))

(setq *kxr-head-options*
      '((h2)
	(h2e   :head :e)
	(h2b   :neck :b)
	(h2be  :neck :b :head :e)))

(setq *kxr-armhead-options*
      (mapcan
       #'(lambda (h)
	   (mapcan 
	    #'(lambda (a)
		(list
		 (cons (read-from-string (format nil "~Ag~A" (car a) (car h)))
		       (append '(:gripper t) (cdr a) (cdr h)))
		 (cons (read-from-string (format nil "~Aw~A" (car a) (car h)))
		       (append '(:gripper :wheel) (cdr a) (cdr h)))
		 (cons (read-from-string (format nil "~A~A" (car a) (car h)))
		       (append (cdr a) (cdr h)))))
	    *kxr-arm-options*))
       *kxr-head-options*))

(defun kxr-l2-define-options (&optional (head 'kxrl2l5) leg-options)
  (let ((ovars-sym (read-from-string (format nil "*~A-options*" head))))
    (set ovars-sym
	 (mapcar
	  #'(lambda (x)
	      (cons (read-from-string (format nil "~A~A" head (car x)))
		    (append (cdr x) leg-options)))
	  *kxr-armhead-options*))
    (set (read-from-string (format nil "*~A-names*" head))
	 (mapcar #'car (symbol-value ovars-sym)))
    (symbol-value ovars-sym))
  )

(setq *kxr-l2l5all-options* ;; 4
      (append
       (kxr-l2-define-options 'kxrl2l5)
       (kxr-l2-define-options 'kxrl2al5  '(:ankle :w))
       (kxr-l2-define-options 'kxrl2cl5  '(:crotch :w))
       (kxr-l2-define-options 'kxrl24l5  '(:ankle :w :crotch :w))
       ))

(setq *kxr-l2l6all-options* ;; 4
      (append
       (kxr-l2-define-options 'kxrl2l6   '(:l6 t))
       (kxr-l2-define-options 'kxrl2al6  '(:l6 t :ankle :w))
       (kxr-l2-define-options 'kxrl2cl6  '(:l6 t :crotch :w))
       (kxr-l2-define-options 'kxrl24l6  '(:l6 t :ankle :w :crotch :w))))

(setq *kxr-l2nl6all-options* ;; 4
      (append
       (kxr-l2-define-options 'kxrl2nl6   '(:l6 :rotate))
       (kxr-l2-define-options 'kxrl2nal6  '(:l6 :rotate :ankle :w))
       (kxr-l2-define-options 'kxrl2ncl6  '(:l6 :rotate :crotch :w))
       (kxr-l2-define-options 'kxrl2n4l6  '(:l6 :rotate :ankle :w :crotch :w))
       ))

(setq *kxr-l2wl6all-options* ;; 4
      (append
       (kxr-l2-define-options 'kxrl2wl6   '(:l6 :wide ))
       (kxr-l2-define-options 'kxrl2wal6  '(:l6 :wide :ankle :w))
       (kxr-l2-define-options 'kxrl2wcl6  '(:l6 :wide :crotch :w))
       (kxr-l2-define-options 'kxrl2w4l6  '(:l6 :wide :ankle :w :crotch :w))
       ))

(setq *kxr-l4all-options*
      '(
	(kxrl4t   :leg :j2)
	(kxrl4th  :leg :j2 :head :e)
	(kxrl4n   :leg :j2 :head :d)
	(kxrl4na3lw  :arm :j3 :leg :j1w :head :d)
	(kxrl4na2lw  :arm :j2 :leg :j1w :head :d)
	(kxrl4r  :leg :j1w)
	(kxrl4rh :leg :j1w :head :e)
	(kxrl4rd :leg :j1w :head :d)
	(kxrl4d  :leg :j4 :head :d)
	(kxrl4de :leg :j4 :head :e)
	))

(setq *kxr-l6all-options*
      '(
	;;(kxrl6)
	;;(kxrl6e :head :e)
	;;(kxrl6d :head :d)
	))

(setq *kxr-l2s-options*
      '(
	(kxrl2 :gripper t :head :e :neck :b)
	(kxrl2l5a3 :gripper t :head :e :neck :b)
	(kxrl2w2l5a3 :ankle :w :gripper :wheel :neck :b)
	(kxrl2w2l5a3h2 :ankle :w :gripper :wheel :neck :b :head :e)

	(kxrl2l5a4 :shoulder :y :gripper t :head :e :neck :b)
	(kxrl2l6a3 :l6 t :gripper t :head :e :neck :b)
	(kxrl2l6a4 :l6 t :shoulder :y :gripper t :head :e :neck :b)
	(kxrl2l6a4h2 :l6 t :shoulder :y :gripper t :head :e :neck :b)
	(kxrl2l6a5 :l6 t :shoulder :y :gripper t :head :e :neck :b)
	(kxrl2l6a5h2 :l6 t :shoulder :y :gripper t :head :e :neck :b)

	(kxrl2w2l6a4h2 :l6 t :shoulder :y :gripper t :head :e :neck :b)
	(kxrl2w2l6a5h2 :l6 t :ankle :w :shoulder :y :gripper t :head :e :neck :b)
	
	(kxrl2l6a6  :l6 t :shoulder :y :wrist :cross :gripper t :neck :b)
	(kxrl2l6a6h2 :l6 t :shoulder :y :wrist :cross :gripper t :head :e :neck :b)
	(kxrl2l6a6h2n :l6 t :shoulder :cross :wrist :y-p :gripper t :head :e :neck :b)
	(kxrl2w2l6a6h2 :l6 t :shoulder :y :wrist :cross :gripper t :head :e :neck :b
		       :ankle :w)

	(kxrl2w2l6a6h2n :l6 t :shoulder :cross :wrist :y-p :gripper t :head :e :neck :b	:ankle :w)
	
	(kxrl2l6a7 :l6 t :shoulder :cross :wrist :cross-y :gripper t :neck :b)
	(kxrl2l6a7h2 :l6 t :shoulder :cross :wrist :cross-y :gripper t :neck :b)
	(kxrl2l6a7h2n :l6 :rotate :shoulder :cross :wrist :cross-y :gripper t :head :e :neck :b)
	(kxrl2l6a7h2w :l6 :wide :shoulder :cross :wrist :cross-y :gripper t :head :e :neck :b)
	(kxrl2w2l6a7h2 :l6 t :shoulder :cross :wrist :cross-y :gripper :wheel :head :e :neck :b :ankle :w)
	(kxrl2w2l6a7h2w :l6 :wide :shoulder :cross :wrist :cross-y :gripper :wheel :head :e :neck :b :ankle :w)

	(kxrl2t2l6a7h2 :torso :y-p :shoulder :cross :wrist :y-cross :gripper t :neck :a)
	(kxrl2t2l6a7h2ypy :torso :y-p :shoulder :cross :wrist :y-p-y :gripper t :neck :a)
	(kxrl2t3l6a7h2ypy :torso :y-r-p :shoulder :cross :wrist :y-p-y :gripper t :neck :a)
	))

(setq *kxr-all-options*
      (append
       *kxr-l2s-options*
       *kxr-l2l5all-options*
       *kxr-l2l6all-options*
       *kxr-l2nl6all-options*
       *kxr-l2wl6all-options*
       *kxr-l4all-options*
       *kxr-l6all-options*
       ))

(setq *kxr-all-names* (mapcar #'car *kxr-all-options*))
(setq *kxr-l2s-names* (mapcar #'car *kxr-l2s-options*))
(setq *kxr-l2l5all-names* (mapcar #'car *kxr-l2l5all-options*))
(setq *kxr-l2l6all-names* (mapcar #'car *kxr-l2l6all-options*))
(setq *kxr-l2nl6all-names* (mapcar #'car *kxr-l2nl6all-options*))
(setq *kxr-l2wl6all-names* (mapcar #'car *kxr-l2wl6all-options*))
(setq *kxr-l4all-names* (mapcar #'car *kxr-l4all-options*))
(setq *kxr-l6all-names* (mapcar #'car *kxr-l6all-options*))

(mapc #'(lambda (x) (kxr-define-robot (car x) (cdr x))) *kxr-all-options*)

(defun show-wheeled-robots (&optional (names (kxr-wheeled-robots))
			    &key (width 500) (n 8))
  (show-robots-by-names names :width width :n n))

(defun show-robots-by-names (names &key (width 500) (n 8))
  (when (or (not (boundp '*shown-robots*))
	    (not (equal *shown-robot-names* names)))
    (setq *shown-robot-names* names)
    (setq *shown-robots*
	  (mapcar #'(lambda (nm) (print nm) (kxr-create-robot nm)) *shown-robot-names*)))
  (show-2d-arrange *shown-robots* :xs width :ys width :n n)
  )

(defun kxrl4-robots (&key eval)
  (setq *kxrl4-robots*
	(kxr-all-robot-models *kxr-l4all-options* :eval eval)))

(defun show-kxrl4-robots (&key eval n (xs 500) (ys 500))
  (show-2d-arrange (kxrl4-robots :eval eval) :n n :xs xs :ys ys))

(defun kxrl2l5-robots (&key eval)
  (setq *kxr-l2l5all-robots*
	(kxr-all-robot-models *kxr-l2l5all-options* :eval eval)))
(defun show-kxrl2l5-robots (&key eval n (xs 500) (ys 500))
  (show-2d-arrange (kxrl2l5-robots :eval eval) :n n :xs xs :ys ys))

(defun kxrl2l6-robots (&key eval n (xs 500) (ys 500))
  (setq *kxr-l2l6all-robots*
	(kxr-all-robot-models *kxr-l2l6all-options* :eval eval)))
(defun show-kxrl2l6-robots (&key eval n (xs 500) (ys 500))
  (show-2d-arrange (kxrl2l6-robots :eval eval) :n n :xs xs :ys ys))

(defun kxrl2wl6-robots (&key eval n (xs 500) (ys 500))
  (setq *kxr-l2wl6all-robots*
	(kxr-all-robot-models *kxr-l2wl6all-options* :eval eval)))
(defun show-kxrl2wl6-robots (&key eval n (xs 500) (ys 500))
  (show-2d-arrange (kxrl2wl6-robots :eval eval) :n n :xs xs :ys ys))

(defun kxr-all-robot-models (&optional (names *kxr-all-names*) &key eval)
  (mapcar #'(lambda (x)
	      (if (consp x) (setq x (car x)))
	      (if (and (null eval) (boundp (robot-gvar x)))
		  (symbol-value (robot-gvar x))
		(funcall x eval)))
	  names))

(defun load-kxr-models (&optional (dir "fine-models") endcoords)
  (dolist (f *kxr-all-robot-names*) (load (format nil "~A/~A.l" dir f)))
  (kxr-show-all-robot-models endcoords))

(defun load-kxr-fine-models (&optional endcoords)
  (load-kxr-models "fine-models" endcoords))
(defun load-kxr-simple-models (&optional endcoords)
  (load-kxr-models "simple-models" endcoords))

(defparameter *kxr-l2s-robots* nil)
(defun kxr-l2s-robots (&optional eval)
  (when (or eval (null *kxr-l2s-robots*))
    (setq *kxr-l2s-robots*
	  (kxr-all-robot-models *kxr-l2s-options* :eval eval)))
  *kxr-l2s-robots*)

(defun kxr-show-all-robots (&key (robots (kxr-l2s-robots))
			      coords endcoords base des)
  (show-2d-arrange robots :xs 500 :ys 500 :base base :des des :coords coords)
  (if endcoords (kxr-show-all-robot-endcoords robots)))

(defun kxr-show-robot-endcoords (r)
  (let (ec res (methods '(:rarm-end-coords	:larm-end-coords
			  :lmarm-end-coords	:rmarm-end-coords
			  :rleg-end-coords	:lleg-end-coords
			  :head-end-coords)))
    (dolist (m methods)
      (if (and (find-method r m) (setq ec (send r m)))
	  (push ec res)))
    (objects (append (objects) res))))

(defun kxr-show-all-robot-endcoords (&optional (robots (kxr-all-robot-models)))
  (dolist (r robots) (kxr-show-robot-endcoords r)))


(defun kxr-animate-transform (robot lst)
  (let (res)
    (objects (list robot))
    (dolist (l lst)
      (cond
	((and (keywordp (car l)) (<= 2 (length l) 3))
	 (push (send* robot (append (butlast l) :joint-angle (last l))) res)
	 )
	(t ))
      )))

(defmethod robot-model
  (:start-image-save
   nil
   (unless (probe-file "gifs") (unix::mkdir "gifs"))
   (send *irtviewer* :change-background #f(0 0 0))
   (send self :put :image-save t)
   (send self :put :save-image-files nil))
  (:end-image-save
   (&key
    (fname (format nil "gifs/~A-~A" (send self :name) (gentemp)))
    (delay 10)
    (transparent t)
    (loop t)
    )
   (send self :put :image-save nil)
   (when (get self :save-image-files)
     (unix:system
      (format nil
	      "gifsicle -O2 -D2 -w --delay=~A ~A ~A --colors 256 ~A > ~A"
	      delay
	      (if transparent "-t#000000" "")
	      (if loop "--loop" "")
	      (get self :save-image-files)
	      (format nil "~A-~A-~A~A.gif"
		      fname delay (if transparent "t" "") (if loop "-loop" "")))
      ;;(send self :put :save-image-files nil)
      )))
  (:draw-interpolation-linear
   (&key
    (interpolation-list
     (send self :get :interpolation-list))
    (rc-list
     (mapcar #'(lambda (x) (elt x 0)) interpolation-list))
    (av-list
     (mapcar #'(lambda (x) (elt x 1)) interpolation-list))
    (divide-num 10)
    (collision-check t)
    &aux
    fname)
   (dotimes (k (1- (length av-list)))
     (dotimes (i divide-num)
       (send *robot* :move-coords
             (midcoords (/ (float i) (1- divide-num)) (elt rc-list k) (elt rc-list (1+ k)))
             (send (car (send *robot* :links)) :worldcoords))
       (send *robot* :angle-vector
             (midpoint (/ (float i) (1- divide-num)) (elt av-list k) (elt av-list (1+ k))))
       (send *irtviewer* :draw-objects :flush nil)
       (x::window-main-one)
       (when collision-check
	 (send self :draw-collision-pair)
	 (when (send *robot* :self-collision-check)
	   (print "collision!!")
	   ;;(read-line)
	   ))
       (send *irtviewer* :viewer :flush)
       (when 
	   (get self :image-save)
	 (setq fname (format nil "gifs/t~A" (+ (* k divide-num) i)))
	 (image::write-image-file
	  (format nil "~A.pnm" fname)
	  (send *irtviewer* :viewer :viewsurface :getglimage))
	 (unix:system (format nil "convert ~A.pnm ~A.gif" fname fname))
	 (unix:system (format nil "rm ~A.pnm" fname))
	 (if (null (get self :save-image-files))
	     (setf (get self :save-image-files) ""))
	 (setf (get self :save-image-files)
	       (concatenate string
			    (get self :save-image-files) " "
			    (format nil "~A.gif" fname)))
	 )
       ))
   )
  ;; root coordinate is not supported :draw-interpolation-minjerk
  ;; (:draw-interpolation-minjerk
  ;;  (&key
  ;;   (av-list (send self :get :interpolation-list))
  ;;   (divide-num 100)
  ;;   &aux
  ;;   (int (instance minjerk-interpolator :init))
  ;;   )
  ;;  (send int :reset
  ;;        :position-list av-list
  ;;        :time-list
  ;;        (let (ret) (dotimes (i (1- (length av-list))) (push (1+ i) ret)) (reverse ret))
  ;;        )
  ;;  (send int :start-interpolation)
  ;;  (while (send int :interpolatingp)
  ;;    (send *robot* :angle-vector
  ;;          (send int :pass-time (/ 1.0 divide-num)))
  ;;    (send *irtviewer* :draw-objects :flush nil)
  ;;    (send self :draw-collision-pair)
  ;;    (send *irtviewer* :viewer :flush)
  ;;    )
  ;;  )
  (:draw-collision-pair
   ()
   (let (pair color)
     (dotimes (i (length (send *robot* :self-collision-check)))
       (setq pair (elt (send *robot* :self-collision-check) i))
       (setq color (map float-vector #'(lambda (x) (/ x 255.0)) (color-category10 i)))
       ;;(format t ";collision: ~a ~a~%" (send (car pair) :name) (send (cdr pair) :name))
       (send (car pair) :draw-on :flush nil :color color :width 2)
       (send (cdr pair) :draw-on :flush nil :color color :width 2)
       )))
  )

(provide :kxranimate)
