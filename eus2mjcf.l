;;;
;;;	Generator mujoco xml file
;;;	2020.6.4 created
;;;	2020.6.14 using <mujocoinclude> for multi robots
;;;	TODO: update inertia matrix
;;;	TODO: tendon robot
;;;	TODO: flying furnitures
;;;

(provide :eus2mjcf)
(require :utils)
(require :tiny-xml)
;;(require :read-stl)
(require :rcb4robots)

(defun load-robot (name)
  (let ((fname (format nil "models/~A.l" (string-downcase name))))
    (if (probe-file fname)
	(load fname)
      (make-kxr-robot name))
    (setq *robot* (apply (read-from-string name) nil))))

(defun trim-vector (v)
  (string-trim "#f()" (format nil "~S" v)))
(defun trim-matrix (v)
  (string-trim "#2f(() ())" (format nil "~S" v)))

(defun simulate (name) (mujoco name "simulate"))
(defun basic (name) (mujoco name "basic"))
(defun mujoco (name app &aux fname)
  (load-robot name)
  (send *robot* :dump-mjcf)
  (unless (probe-file
	   (setq fname (format nil "~A/mujoco/bin/~A" (unix::getenv "HOME") app)))
    (setq fname (format nil "~A/mujoco/build/bin/~A" (unix::getenv "HOME") app)))
  (system-format "~A mjcfs/~A/~A.xml" fname (send *robot* :name)
		 (send *robot* :name)))

(format t ";; (basic \"kxrl4t\")~%")
(format t ";; (simulate \"kxrl6\")~%")


(defmethod bodyset-link
  (:mjcf-body
   (&optional name)
   (append
    (send self :mjcf :name name)
    (mapcar #'(lambda (x) (send x :mjcf-body name)) child-links)))
  #|
  (:mass ()
  (let ((m (* 0.001
  (reduce #'+ (send-all (send self :bodies) :weight)))))
  (if (<= m 0.0) (prog1 0.01 (format t ";; mass=~A <= 0.0: self=~A~%" m self))
  m)))
  (:mass ()
  (let ((bs (send self :bodies)) (sum 0) w)
	   (dolist (b bs)
	     (unless (setq w (send b :weight))
	       (setq w (* 1.2 (send b :volume))))
	     (setq sum (+ sum w)))
	   (* 0.001 sum)))
  |#
  (:mass () (* 0.001 (send self :weight)))
  (:rgba (col)
	 (float-vector (elt col 0) (elt col 1) (elt col 2) 1.0))
  (:quat () (let ((q (matrix2quaternion rot)))
	      (float-vector (elt q 0) (elt q 1) (elt q 2) (elt q 3))))
  (:diaginertia
   (&aux (im (send self :inertia-matrix-g self)))
   (trim-vector (scale 0.000000001 (float-vector (aref im 0 0) (aref im 1 1) (aref im 2 2)))))
  (:fullinertia
   (&aux (im (scale-matrix 1e-9 (send self :inertia-tensor))))
   (trim-vector (float-vector (aref im 0 0) (aref im 1 1) (aref im 2 2) (aref im 0 1) (aref im 0 2) (aref im 1 2))))
  (:mjcf-joint ;; bodyset-link
   (&rest args &key name (damping 0.2) &allow-other-keys)
   (let* (
	  (dpos (if parent
		    (scale 0.001 (v- (send self :worldpos) (send parent :worldpos)))
		  (scale 0.001 (v- (send self :worldpos)))))
	  (cpos (scale 0.001 (v- (send self :centroid) (send self :worldpos))))
	  )
     (append
      (list
       (list "body" (format nil "name=~S pos=~S"
			    (if name
				(format nil "~A/~A" name (send self :name))
			      (format nil "~A" (send self :name)))
			    (trim-vector dpos)
			    )))
      (list
       (list (list "inertial" (format nil "pos=~S mass=~S fullinertia=~S"
				      (trim-vector cpos)
				      (string (send self :mass))
				      (send self :fullinertia)
				      ))))
      (cond
       ((eq (send joint :joint-type) :wheel)
	(list
	 (list (list "joint" 
		     (format nil "name=~S pos=~S axis=~S"
			     (if name
				 (format nil "~A/~A" name (send self :name))
			       (format nil "~A" (send self :name)))
			     "0 0 0"
			     (trim-vector (send joint :axis)))))))
       ((eq (send joint :joint-type) :thrust)
	(list
	 (list (list "joint" 
		     (format nil "name=~S pos=~S axis=~S"
			     (if name
				 (format nil "~A/~A" name (send self :name))
			       (format nil "~A" (send self :name)))
			     "0 0 0"
			     (trim-vector (send joint :axis)))))
	 (list (list "site" 
		     (format nil "name=~S pos=~S quat=~S"
			     (if name
				 (format nil "~A/~A-motor" name (send self :name))
			       (format nil "~A-motor" (send self :name)))
			     "0. 0. 0."
			     (trim-vector (send self :quat)))))))
       ((derivedp joint linear-joint)
	(format t ";; joint=~A is linear-joint~%" joint)
	)
       (t
	(list
	 (list (list "joint" 
		     (let ((min (send joint :min-angle))
			   (max (send joint :max-angle)))
		       (if (= min max) (setq min (- min 0.01)))
		       (format nil "name=~S pos=~S axis=~S limited=~S range=~S damping=~S"
			       (if name
				   (format nil "~A/~A" name
					   (string-downcase (string (send joint :name))))
				 (format nil "~A"
					 (string-downcase (string (send joint :name)))))
			       "0 0 0"
			       (trim-vector (send joint :axis))
			       "true"
			       (format nil "~S ~S" (deg2rad min) (deg2rad max))
			       (string damping))))))))
      (send self :mjcf-geoms name)
      )
     ))
  (:mjcf ;; bodyset-link
   (&rest args &key name (damping 0.2) &allow-other-keys)
   (if joint (send* self :mjcf-joint args)
     (send* self :mjcf-torso args))
   )
  (:mjcf-geoms ;; bodyset-link
   (name)
   (let (ret bs col)
     (setq bs (send self :bodies))
     (dotimes (i (length bs))
       (push
	(list (list "geom" (format nil "pos=~S type=~S mesh=~S rgba=~S"
				   "0 0 0"
				   "mesh"
				   (format nil "~A_~A_~A_mesh" name (send self :name) i)
				   (trim-vector (send self :rgba
						      (if (setq col (get (elt bs i) :face-color))
							  col #f(0.5 0.5 0.5))))
				   )))
	ret))
     (reverse ret))
   )
  (:mjcf-torso ;; bodyset-link
   (&rest args &key (name (send self :name)) (pos (send self :worldpos)) &allow-other-keys)
   (let* ((dpos (scale 0.001 pos))
	  (cpos (scale 0.001 (v- (send self :centroid) (send self :worldpos)))))
     (append
      (list
       (list "body" (format nil "name=~S pos=~S"
			    (if name
				(format nil "~A/~A" name (send self :name))
			      (format nil "~A" (send self :name)))
			    (trim-vector dpos))))
      (list
       (list (list "inertial" (format nil "pos=~S quat=~S mass=~S diaginertia=~S"
				      (trim-vector cpos)
				      (trim-vector (send self :quat))
				      (string (send self :mass))
				      (send self :diaginertia)
				      ))))
      (list
       (list (list "joint" (format nil "name=~S type=~S"
				   (if name
				       (format nil "~A/root" name)
				     (format nil "root"))
				   "free"))))
      (send self :mjcf-geoms name)
      )))
  (:tree-links ;; bodyset-link
   ()
   (cons self (flatten (mapcar #'(lambda (l) (send l :tree-links)) (send self :child-links)))))
  )

(defun mjcf-dump-objects-old
    (&rest args &key (timestep 0.005) (iterations 50)
	   (objs (objects))
	   (fname "objects")
	   (tolerance 1e-10) (solver "Newton") (kp 10) (kv 0.01)
	   (angle "radian") (convexhull "false")
	   (jacobian "dense") (cone "pyramidal")
	   (nconmax 1000) (njmax 5000) (nstack 1000000) &allow-other-keys)
  (let* ((robos (remove-if-not
		 #'(lambda (x) (or (derivedp x cascaded-link)
				   (derivedp x scene-model)))
		 objs))
	 (names (send-all robos :name)))
    (send-all robos :weight)
    (send-all robos :dump-mjcf)
    (tiny-xml::dump (apply #'mjcf-world-xml :names names args)
		    (format nil "mjcfs/~A.xml" fname))))

(defun mjcf-dump-objects
    (&rest args &key (timestep 0.001) (iterations 50)
	   (objs (objects))
	   (fname "objects")
	   (tolerance 1e-10) (solver "Newton") (kp 30) (kv 0.01)
	   (angle "radian") (convexhull "false")
	   (jacobian "dense") (cone "pyramidal")
	   (nconmax 1000) (njmax 5000) (nstack 1000000)
           (frictionloss 0.2) (armature 0.011) &allow-other-keys)
  (let* ((robos (remove-if-not
		 #'(lambda (x) (or (derivedp x cascaded-link)
				   (derivedp x scene-model)))
		 objs))
	 names)
    (numbering-same-objects robos)
    (dolist (o robos)
      (if (derivedp o scene-model)
	  (numbering-same-objects (send o :objects))))
    (setq names (send-all robos :name))
    (send-all robos :weight)
    (send-all robos :dump-mjcf)
    (tiny-xml::dump (apply #'mjcf-world-xml :names names args)
		    (format nil "mjcfs/~A.xml" fname))))

(defun numbering-same-objects (objs)
  (let* ((names (send-all objs :name))
	 name-clist nc)
    (dolist (o objs)
      (setq nc (assoc (send o :name) name-clist))
      (cond
       ((null nc) (push (cons (send o :name) 1) name-clist))
       (t (send o :name (format nil "~A_~A" (send o :name) (cdr nc)))
	  (rplacd nc (1+ (cdr nc)))))
      )))

(defun mjcf-world-xml
    (&rest args &key (timestep 0.001) (iterations 50) names
	   (tolerance 1e-10) (solver "Newton") (kp 10) (kv 0.01)
	   (angle "radian") (convexhull "false")
	   (jacobian "dense") (cone "pyramidal")
	   (nconmax 1000) (njmax 5000) (nstack 1000000)
           (frictionloss 0.2) (armature 0.011) &allow-other-keys)
  (let (ret)
    (dolist (name names)
      (push 
       `(("include" ,(format nil "file=~S" (format nil "~A/~Ainc.xml" name name))))
       ret))
    (append
     `(
       ("mujoco"
	,(format nil "model=~S" (format nil "~A" names)))
       (("!--"
	 ,(format nil
		  "~%   This file is automatically created from ~S model by eus2mjcf.l.~%   --" 
		  names)))
       (("compiler"
	 ;; ,(format nil "angle=~S  convexhull=~S" angle convexhull)))
	 ,(format nil "angle=~S " angle)))
       (("option"
	 ,(format nil "timestep=~S iterations=~S tolerance=~S solver=~S jacobian=~S cone=~S"
		  (string timestep) (string iterations) (string tolerance)
		  solver jacobian cone)))
       ("default" (("geom" "condim=\"3\" solref=\"0.02 1.0\""))
        (("joint" ,(format nil "frictionloss=~S armature=~S" (string frictionloss) (string armature)))))
       (("size"
	 ,(format nil "nconmax=~S njmax=~S nstack=~S"
		  (string nconmax) (string njmax) (string nstack)))))
     (list
      `("worldbody"
	(("light"
	  ,(format nil "pos =~S dir=~S diffuse=~S specular=~S"
		   "2 2 2" "-1 -1 -1" "1 1 1" "0.1 0.1 0.1")))
	(("geom"
	  ,(format nil "name=~S pos=~S size=~S type=~S material=~S condim=~S"
		   "floor" "0 0 0" "3 3 1" "plane" "matplane" "3")))))
     (list
      `("asset"
	(("texture"
	  ,(format nil "name=~S type=~S builtin=~S rgb1=~S rgb2=~S width=~S height=~S mark=~S markrgb=~S"
		   "texplane" "2d" "checker" ".4 .6 .8" ".2 0.3 0.4" "512" "512" "cross" ".8 .8 .8")))
	(("material"
	  ,(format nil "name=~S reflectance=~S texture=~S texrepeat=~S texuniform=~S"
		   "matplane" "0.3" "texplane" "1 1" "true")))))
     (reverse ret))
    ))

(defmethod cascaded-link
  (:all-links () (send (car (send self :links)) :tree-links))
  (:dump-mjcf-meshes ;; cascaded-link
   (&rest args &key (fname (send self :name))
	  (dirname (format nil "mjcfs/~A" fname)) &allow-other-keys)
   (let* ((ls (send self :all-links)) stlname offsetv minp gs bs fs fss ll faces)
     (when (derivedp self robot-model)
       (send self :angle-vector (send self :neutral)))
     (setq minp (find-extream (send-all (send-all (send self :bodies) :box) :minpoint)
			      #'(lambda (x) (elt x 2)) #'<))
     (setq offsetv (v+ (send self :worldpos) (float-vector 0 0 (- (elt minp 2)))))
     (send self :locate offsetv :world)
     (send-all (send self :links) :worldcoords)
     (format t ";; fname=~A torso pos=~A~%" fname (send (car (send self :links)) :worldpos))
     (unless (probe-file "mjcfs") (unix::mkdir "mjcfs"))
     (unless (probe-file dirname) (unix::mkdir dirname))
     #|
     ;; rename link
     (dolist (limb (list :head :larm :rarm :lleg :rleg :torso))
       (setq ll (send self limb))
       (dotimes (i (length ll))
	 (send (elt ll i) :name (format nil "~A_LINK~A" (string limb) i))))
     ;; rename joint
     (dolist (limb (list :head :larm :rarm :lleg :rleg :torso))
       (setq ll (send self limb :joint-list))
       (dotimes (i (length ll))
	 (send (elt ll i) :name (format nil "~A_JOINT~A" (string limb) i))))
     |#
     ;; dump stl
     (dolist (l ls)
       (setq bs (send l :bodies))
       (setq bs (mapcar
		 #'(lambda (b)
		     (if (derivedp b gl::glbody) b
		       (let ((col (get b :face-color))
			     mat glvertices)
			 (if col
			     (setq mat (list (list :ambient (float-vector (elt col 0) (elt col 1) (elt col 2)))
					     (list :diffuse (float-vector (elt col 0) (elt col 1) (elt col 2)))))
			   (setq mat  (list (list :ambient (float-vector 0.5 0.5 0.5))
					    (list :diffuse (float-vector 0.5 0.5 0.5)))))
			 (setq glvertices (gl::make-glvertices-from-faceset b  :material mat))
			 (send glvertices :transform (send b :copy-worldcoords))
			 (setq b (instance kxr-body :init :replace-obj b :name (get b :name)))
			 (send b :put :face-color col)
			 (send glvertices :put :face-color col)
			 (send b :assoc glvertices)
			 (setq (b . gl::aglvertices) glvertices)
			 (send l :assoc b)
			 b)))
		 bs))
       (setq fss (mapcar #'(lambda (x) (send x :convert-to-faceset))
			 (send-all bs :glvertices)))
       (setq faces (flatten (mapcar #'(lambda (x) (send x :faces)) fss)))
       (dotimes (i (length fss))
	 ;;(setq fs (copy-object (elt fss i))) 2021.12.22 found by anzai
	 (setq fs (elt fss i))
	 ;;(send fs :locate (v+ offsetv (v- (send fs :worldpos) (send l :worldpos))) :world)
	 (send fs :locate (v- (send fs :worldpos) (send l :worldpos)) :world)
	 (setq stlname (format nil "~A/~A_~A_mesh.stl" dirname (send l :name) i))
	 (unless (probe-file stlname) (eus2stl stlname fs))
	 )
       #|
       (setq stlname (format nil "~A/~A_mesh.stl" dirname (send l :name)))
       (with-open-file
       (f stlname :direction :output)
       (write-stl-header f (length faces))
       (dolist (_faceset fss)
       (send _faceset :worldpos)
       (let ((faces (send _faceset :faces)))
       (dolist (_face faces)
       (write-stl-face f _face :scale scale))))
       )
       |#
       ))
   )
  (:dump-mjcf ;; cascaded-link
   (&rest args &key (fname (send self :name)) (name (send self :name)) (dirname (format nil "mjcfs/~A" fname)) &allow-other-keys)
   (send* self :dump-mjcf-meshes args)
   (tiny-xml::dump
    (send* self :mjcf-include-xml :name name args) (format nil "~A/~Ainc.xml" dirname fname))
   (unless (probe-file (format nil "~A/~A" dirname fname))
     (unix::system (format nil "cd ~A; ln -s ../~A ." dirname fname)))
   (tiny-xml::dump
    (apply #'mjcf-world-xml :names (list name) args) (format nil "mjcfs/~A/~A.xml" fname fname)))
  (:dump-mjcf-include ;; cascaded-link
   (&rest args &key (fname (send self :name))
	  (name (send self :name)) (dirname (format nil "mjcfs/~A" fname)) &allow-other-keys)
   (send* self :dump-mjcf-meshes args)
   (tiny-xml::dump
    (send* self :mjcf-include-xml :name name args) (format nil "~A/~Ainc.xml" dirname fname)))
  (:mjcf-include-xml ;; cascaded-link
   (&rest args &key (name (send self :name)) (asset t) &allow-other-keys)
   (append
    `(("mujocoinclude")
      (("!--"
	,(format nil "~%   This file is automatically created from ~S model by eus2mjcf.l.~%   --" 
		 (send self :name)))))
    (if asset (list (send self :mjcf-asset name)))
    (if (car (send self :links))
	`(("worldbody" ,(send (car (send self :links)) :mjcf-body name))))
    #|
    (list
     `("contact"
       (("exclude"
	 ,(format nil "body1=~S body2=~S"
		  (string-downcase (string (send self :larm-shoulder-p :name)))
		  (string-downcase (string (send self :larm-shoulder-r :name))))))
       (("exclude"
	 ,(format nil "body1=~S body2=~S"
		  (string-downcase (string (send self :rarm-shoulder-p :name)))
		  (string-downcase (string (send self :rarm-shoulder-r :name))))))
       ))
    |#
    (if (derivedp self robot-model)
	(list (send* self :mjcf-actuator args))
      nil))
   )
  (:mjcf-actuator
   (&rest args &key name (kp 10) (kv 0.02) (yaw 0.01) &allow-other-keys)
   (let (ret)
     (dolist (j (send self :joint-list))
       (let ((nm (if name (format nil "~A/~A" name
				  (string-downcase (string (send j :name))))
		   (string-downcase (string (send j :name))))))
	 (cond
	  ((eq (send j :joint-type) :wheel)
	   (push
	    (list (list "velocity"
			(format nil "name=~S kv=~S joint=~S" nm (string kv) nm)))
	    ret))
	  ((eq (send j :joint-type) :thrust)
	   (push
	    (list (list "velocity"
			(format nil "name=~S kv=~S joint=~S" nm (string kv) nm)))
	    ret)
	   (push (list (list "motor"
			     (format nil "name=~S ctrllimited=~S ctrlrange=~S gear=~S site=~S"
				     (format nil "~A-motor" nm)
				     "true" "0.0 20.0"
				     (format nil "0 0. 1. 0. 0. ~A"
					     (* yaw (elt (send j :axis) 2)))
				     (format nil "~A-motor" nm))))
		 ret))
	  (t (push (list (list "position"
			       (format nil "name=~S kp=~S joint=~S"
				       nm (string kp) nm)))
		   ret)))))
     (cons "actuator" (reverse ret))))
  (:mjcf-geoms-asset
   (name)
   (mapcan
    #'(lambda (l)
	(let* ((bs (send l :bodies)) ret mesh-name)
	  (dotimes (i (length bs))
	    (setq mesh-name (format nil "~A_~A_mesh" (send l :name) i))
	    (push
	     (list (list "mesh"
			 (format nil "name=~S file=~S"
				 (concatenate string name "_" mesh-name)
				 (concatenate string name "/" mesh-name ".stl"))))
	     ret))
	  (reverse ret)))
    (send self :all-links))
   )
  (:mjcf-asset
   (&optional (name (send self :name)))
   (cons "asset" (send self :mjcf-geoms-asset name)))
  )

(defmethod scene-model
  (:weight ()
	   (let ((w 0.0))
	     (dolist (o objs)
	       (if (derivedp o cascaded-link)
		   (setq w (+ w (send o :weight)))))
	     w))
  ;;
  (:dump-mjcf ;; scene-model
   (&rest args &key (fname (send self :name)) (name (send self :name)) (dirname (format nil "mjcfs/~A" fname)) &allow-other-keys)
   (dolist (o (send self :objects))
     (when (derivedp o cascaded-link)
       (send o :dump-mjcf-meshes)
       (send o :dump-mjcf-include)))
   (unless (probe-file dirname) (unix::mkdir dirname))
   (tiny-xml::dump (send self :mjcf-include-xml) (format nil "mjcfs/~A/~Ainc.xml" fname fname))
   (unless (probe-file (format nil "~A/~A" dirname fname))
     (unix::system (format nil "cd ~A; ln -s ../~A ." dirname fname)))
   (tiny-xml::dump (apply #'mjcf-world-xml :names (list name) args) (format nil "mjcfs/~A/~A.xml" fname fname)))
  (:mjcf-include-xml ;; scene-model
   (&rest args &key (name (send self :name)) (asset t) &allow-other-keys)
   (let (ret names)
     (dolist (o (send self :objects))
       (if (derivedp o cascaded-link)
	   (push (send o :name) names)))
     (dolist (name (reverse names))
       (push 
	`(("include" ,(format nil "file=~S" (format nil "~A/~Ainc.xml" name name))))
	ret))
     (append
      `(("mujocoinclude")
	(("!--"
	  ,(format nil "~%   This file is automatically created from ~S model by eus2mjcf.l.~%   --" 
		   (send self :name)))))
      (reverse ret))
     )
   )
  )

;;
;; (send *robot* :dump-mjcf)
;; -> mjcfs/robotname.xml
;; -> mjcfs/robotname/robotnameinc.xml
;; -> mjcfs/robotname/xxxx.stl
;;
;; (objects-kxr-robots  (list r1 .. rn)) and (mjcf-dump-objects) 
;;
;; (load "kxranimate.l")-> (objects-kxr-robots)-> (mjcf-dump-objects)
;;
