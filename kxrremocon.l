;;;
;;; KXR remote controller emulator 2018.11.7
;;;

(require :rcb4robots)
(require :kxrbody)

(in-package "USER")

(provide :kxrremocon)

(defun kxr-remocon-view nil
  (setq *kxr-remocon* (kxr-remocon))
  (setq *remocon-viewer* (instance kxrviewer :create :name "Remocon" :width 600 :height 300))
  (send *remocon-viewer* :objects (list *kxr-remocon*))
  (send *remocon-viewer* :change-background (float-vector 1 0 0.7))
  (send *remocon-viewer* :look-all)
  (send *remocon-viewer* :title "KXR Remocon")
  (send *remocon-viewer* :name "KXR Remocon")
  (setq (*remocon-viewer* . x::left-right-angle) 0)
  (setq (*remocon-viewer* . x::up-down-angle) 110)
  (setq (*remocon-viewer* . x::viewtarget) #f(0 0 -30))
  (send *remocon-viewer* :look1)
  (send *remocon-viewer* :resize 600 300)
  )

(defclass kxrviewer :super x::irtviewer)

(defmethod kxrviewer
  (:draw-event
   (event &aux ff fs buttonstr buttoncmd im (x 20) strs)
    (when (boundp 'user::*kxr-remocon*)
     (send self :objects (list user::*kxr-remocon*))
     (send self :draw-objects)
     (setq ff (user::kxr-pick-face
	       (float-vector (elt x::previous-cursor-pos 0)
			     (elt x::previous-cursor-pos 1) 0)
	       self))
     (setq buttonstr "        " buttoncmd nil)
     (dolist (h (get user::*kxr-remocon* :holes))
       (when
	   (and (elt h 4) (car ff)
		(user::face-equal (car ff) (elt h 4)))
	 (setq buttoncmd (car h))
	 (setq buttonstr (format nil "Button:~A" buttoncmd))))
     (cond
       (ff
	(setq fs (instance geo::faceset :init :faces (list (car ff))))
	(send fs :set-color :red)
	(send self :objects (list fs user::*kxr-remocon*))
	(send self :draw-objects)
	(setq strs (list 
		    (format nil "Face:~A" (car ff))
		    (format nil "Pos:~A" (cadr ff))))
	)
       (t
	(send self :objects (list user::*kxr-remocon*))
	(send self :draw-objects :clear nil :flush t)
	))
     (send self :strings
	   `(,(format nil "Event: draw-event ~A" x::previous-cursor-pos)
	      ,@strs
	      ,buttonstr))
     (send self :draw-objects :clear nil :flush t)
     (send self :flush)
     (when (and (boundp 'user::*ri*) buttoncmd)
       (catch :loop
	 (dolist (mc (send user::*ri* :project-file :mcodes))
	   (when (user::set-equal buttoncmd (send mc :buttoncmd))
	     (send user::*ri* :emulate-motion-code mc :loopmax 200)
	     (throw :loop nil))
	   )))
     (x::window-main-one)
     ))
  )

(defun set-equal (a b &key (test #'eq))
  (and (null (set-difference a b :test test))
       (null (set-difference b a :test test))))

(defun face-equal (a b)
  (set-equal (cdr (send a :vertices))
	     (cdr (send b :vertices))
	     :test #'equal))

(defun kxr-pick-face
    (spos &optional (vwer *remocon-viewer*))
  (let*
      ((eye (send vwer :viewer :viewing))
       (vp (send vwer :viewer :viewport :screen-point-to-ndc spos)))
    (bodies-vector-limit-face-pos (send vwer :objects)
				  (send eye :viewpoint)
				  (send eye :view-orient vp)
				  #'<))
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
		    (list '(:shift1) #f(-30 -60 7) :-x shiftbutton nil)
		    (list '(:shift2) #f(-30 -60 -7) :-x shiftbutton nil)
		    (list '(:shift3) #f(-30  60 7) :-x shiftbutton nil)
		    (list '(:shift4) #f(-30  60 -7) :-x shiftbutton nil)
		    
		    (list '(:lforward :lback :lright :lleft) #f(0 -15 10) :z psbutton nil)
		    (list '(:rforward :rback :rright :rleft) #f(0  15 10) :z psbutton nil)
		    
		    (list '(:lforward) #f(-8  -50 10) :z fbbutton nil)
		    (list '(:lback   ) #f( 8  -50 10) :z fbbutton nil)
		    (list '(:lright  ) #f( 0  -42 10) :z lrbutton nil)
		    (list '(:lleft   ) #f( 0  -58 10) :z lrbutton nil)
		    
		    (list '(:rforward) #f(-8   50 10) :z fbbutton nil)
		    (list '(:rback   ) #f( 8   50 10) :z fbbutton nil)
		    (list '(:rright  ) #f( 0   58 10) :z lrbutton nil)
		    (list '(:rleft   ) #f( 0   42 10) :z lrbutton nil)
		    ))
	 (buttons2
	  (list
	   (list '(:lforward :lleft)
		 (float-vector (* 22.5 (sin (deg2rad -135)))
			       (- (* 22.5 (cos (deg2rad -135))) 50) 0)
		 :z nil nil)
	   (list '(:lforward :lright)
		 (float-vector (* 22.5 (sin (deg2rad -45)))
			       (- (* 22.5 (cos (deg2rad -45))) 50) 0)
		 :z nil nil)
	   (list '(:lback :lleft)
		 (float-vector (* 22.5 (sin (deg2rad 135)))
			       (- (* 22.5 (cos (deg2rad 135))) 50) 0)
		 :z nil nil)
	   (list '(:lback :lright)
		 (float-vector (* 22.5 (sin (deg2rad 45)))
			       (- (* 22.5 (cos (deg2rad 45))) 50) 0)
		 :z nil nil)
	   ;;;
	   (list '(:rforward :rleft) 
		 (float-vector (* 22.5 (sin (deg2rad -135)))
			       (+ (* 22.5 (cos (deg2rad -135))) 50) 0)
		 :z nil nil)
	   (list '(:rforward :rright)
		 (float-vector (* 22.5 (sin (deg2rad -45)))
			       (+ (* 22.5 (cos (deg2rad -45))) 50) 0)
		 :z nil nil)
	   (list '(:rback :rleft)
		 (float-vector (* 22.5 (sin (deg2rad 135)))
			       (+ (* 22.5 (cos (deg2rad 135))) 50) 0)
		 :z nil nil)
	   (list '(:rback :rright)
		 (float-vector (* 22.5 (sin (deg2rad 45)))
			       (+ (* 22.5 (cos (deg2rad 45))) 50)  0)
		 :z nil nil))
	  )
	 cyl)
    
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

    (dolist (b (append buttons1 buttons2))
      (let ((bbody (elt b 3)) fp)
	(when bbody
	  (send bbody :locate (cadr b) :world)
	  (setq bod (body+ bod bbody)))
	(setq fp
	      (bodies-vector-limit-face-pos (list bod) (cadr b)
					    (axis2vector (caddr b)) ;; :-x, :z
					    ))
	(setf (cadr b) (cadr fp))
	(setf (elt b 4) (car fp))
	))
    (send bod :name "remocon")
    (kxr-assoc-holes bod (append buttons1 buttons2))
    bod))

(format t "; (kxr-remocon-view) ; remocon button to :emulate-motion-code in project-file~%")



