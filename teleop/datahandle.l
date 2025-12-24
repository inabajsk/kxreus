;;
;; Data store/plot/animate 2025.11.14 M.I
;;
(provide :datahandle)

(defun store-loop (&key fname show send (robot "iarm0"))
  (let ((mt (instance mtimer :init))
	rvdata ad addata av avdata tmdata tm0 tm1 xyz xyzdata)
    (setq *av-data* nil)
    (setq *rv-data* nil)
    (setq *ad-data* nil)
    (setq *time-data* nil)
    (unless (boundp '*ri*)
      (setq *ri* (kxr-make-robot-interface robot :viewer t))
      (send *ri* :com-init :baud *baudrate*)
      (send *ri* :free-all)
      )
    (unless fname
      (setq fname (format nil "~A ~A.dat"
			  (send *ri* :robot :name)
			  (car (unix::gettimeofday)))))
    (setq tm0 (list (unix::localtime) (unix:gettimeofday)))
    (send mt :start)
    (do-until-key
     (setq av (send *ri* :read-angle-vector))
     (setq ad (send *ri* :read-analog))
     (if send (unix::sendto *csock* *caddr* (format nil "~A" av)))
     (when show
       (send *ri* :robot :angle-vector av)
       (send *ri* :robot :viewer :draw-objects)
       )
     (when (boundp '*real-vector*)
       (push *real-vector* rvdata))
     (push av avdata)
     (push ad addata)
     (push (send mt :stop) tmdata)
     (if send (unix::sendto *csock* *caddr* (format nil "~A" av)))
     )
    (setq tm1 (list (unix::localtime) (unix:gettimeofday)))
    (setq *robot-name* (send *ri* :robot :name))
    (setq *start-end-time* (list tm0 tm1))
    (setq *av-data* (reverse avdata))
    (setq *rv-data* (reverse rvdata))
    (setq *ad-data* (reverse addata))
    (setq *time-data* (reverse tmdata))
    (if *rv-data*
	(dump-loadable-structure fname *robot-name* *rv-data*
				 *start-end-time* *av-data* *ad-data* *time-data*)
      (dump-loadable-structure fname *robot-name*
			       *start-end-time* *av-data* *ad-data* *time-data*))
    (joint-plot)
    (analog-plot)
    (xyz-2dplot)
    (xyz-3dplot)
    (animate-data)
    ))

(defun store-loop2 (&key fname show send (robot "iarm0"))
  (let ((mt (instance mtimer :init))
	radata rvdata av avdata tmdata tm0 tm1 xyz xyzdata)
    (setq *av-data* nil)
    (setq *rv-data* nil)
    (setq *ra-data* nil)
    (setq *time-data* nil)
    (follower3-init)
    (unless fname
      (setq fname (format nil "~A ~A.dat"
			  (send *ri* :robot :name)
			  (car (unix::gettimeofday)))))
    (setq tm0 (list (unix::localtime) (unix:gettimeofday)))
    (send mt :start)
    (do-until-key
     (setq av (send *ri* :read-angle-vector))
     (if send (unix::sendto *csock* *caddr* (format nil "~A" av)))
     (when show
       (send *ri* :robot :angle-vector av)
       (send *ri* :robot :viewer :draw-objects)
       )
     (when (boundp '*real-vector*) (push *real-vector* rvdata))
     (when (boundp '*real-analog*) (push *real-analog* radata))
     (push av avdata)
     (push (send mt :stop) tmdata)
     (if send (unix::sendto *csock* *caddr* (format nil "~A" av)))
     )
    (setq tm1 (list (unix::localtime) (unix:gettimeofday)))
    (setq *robot-name* (send *ri* :robot :name))
    (setq *start-end-time* (list tm0 tm1))
    (setq *av-data* (reverse avdata))
    (setq *rv-data* (reverse rvdata))
    (setq *ra-data* (reverse radata))
    (setq *time-data* (reverse tmdata))
    (if *rv-data*
	(dump-loadable-structure fname *robot-name* *rv-data* *ra-data*
				 *start-end-time* *av-data* *time-data*)
      (dump-loadable-structure fname *robot-name*
			       *start-end-time* *av-data* *time-data*))
    (joint-plot)
    (analog-plot)
    (xyz-2dplot)
    (xyz-3dplot)
    (animate-data)
    ))

(defun joint-plot (&key fname (yrange '(-90 90)))
  (if (and fname (probe-file fname)) (load fname))
  (when
      (boundp '*av-data*)
    (let (data (stimestr (unix::asctime (caar *start-end-time*))))
      (dotimes (i 4)
	(push (mapcar #'(lambda (fv) (elt fv i)) *av-data*) data))
      (graph-view
       (reverse data)
       *time-data*
       :keylist '("joint0" "joint1" "joint2" "joint3")
       :xrange (list (round (apply #'min *time-data*))
		     (round (apply #'max *time-data*)))
       :yrange yrange
       :graph-instance (setq *gp* (gnuplot))
       :title (format nil "~A Joints  ~A"
		      "leader"
		      (if fname fname
			(subseq stimestr 0 (1- (length stimestr)))))
       ))
    ))

(defun joint-plot2 (&key fname (yrange '(-90 90)))
  (if (and fname (probe-file fname)) (load fname))
  (unless (boundp '*ri*) (robot-model-init))
  (when
      (and (boundp '*av-data*) (boundp '*rv-data*) *rv-data*)
    (let (data (stimestr (unix::asctime (caar *start-end-time*))))
      (dotimes (i 4)
	(push (mapcar #'(lambda (fv) (elt fv i)) *av-data*) data))
      (dotimes (i 4)
	(push (mapcar #'(lambda (fv) (elt fv i)) *rv-data*) data))
      (graph-view
       (reverse data)
       *time-data*
       :keylist
       '("leader-joint0" "leader-joint1" "leader-joint2" "leader-joint3"
	 "follower-joint0" "follower-joint1" "follower-joint2" "follower-joint3")
       :xrange (list (round (apply #'min *time-data*))
		     (round (apply #'max *time-data*)))
       :yrange (list
		(apply #'min (flatten data))
		(apply #'max (flatten data))
		)
       :graph-instance (setq *gp* (gnuplot))
       :title (format nil "~A Joints  ~A"
		      "leader and follower"
		      (if fname fname
			(subseq stimestr 0 (1- (length stimestr)))))
       ))
    ))

(defun analog-plot (&key fname (yrange '(0 1000))
			 (idxs (if (boundp '*sensor-idxs*)
				   *sensor-idxs*
				 '(0 1 2 3 4 5 6 7 8 9 10))))
  (if (and fname (probe-file fname)) (load fname))
  (unless (boundp '*ad-data*)
    (when (boundp '*ra-data*) (setq *ad-data* *ra-data*)))
  (when (boundp '*ad-data*)
    (let (data (stimestr (unix::asctime (caar *start-end-time*))))
      (dolist (i idxs)
	(push (mapcar #'(lambda (fv) (elt fv i)) *ad-data*) data))
      (graph-view
       (reverse data)
       *time-data*
       :keylist
       (mapcar #'(lambda (i) (format nil "ad~A" i)) idxs)
       :xrange (list (round (apply #'min *time-data*))
		     (round (apply #'max *time-data*)))
       :yrange (list (round (apply #'min (car data)))
		     (round (apply #'max (car data))))
       :graph-instance (setq *gp* (gnuplot))
       :title (format nil "~A Analog  ~A"
		      "leader or follower"
		      (if fname fname
			(subseq stimestr 0 (1- (length stimestr)))))
       ))
    ))


(defun analog-plot2 (&key fname (yrange '(0 1000))
			  (idxs (if (boundp '*sensor-idxs*)
				    *sensor-idxs*
				  '(0 1 2 3 4 5 6 7 8 9 10))))
  (if (and fname (probe-file fname)) (load fname))
  (when
      (boundp '*ra-data*)
    (let (data (stimestr (unix::asctime (caar *start-end-time*))))
      (dolist (i idxs)
	(push (mapcar #'(lambda (fv) (elt fv i)) *ra-data*) data))
      (graph-view
       (reverse data)
       *time-data*
       :keylist
       (mapcar #'(lambda (i) (format nil "follower ad~A" i)) idxs)
       :xrange (list (round (apply #'min *time-data*))
		     (round (apply #'max *time-data*)))
       :yrange (list (round (apply #'min (car data)))
		     (round (apply #'max (car data))))
       :graph-instance (setq *gp* (gnuplot))
       :title (format nil "~A Analog  ~A"
		      "follower"
		      (if fname fname
			(subseq stimestr 0 (1- (length stimestr)))))
       ))
    ))

(defun xyz-2dplot (&key fname)
  (if (and fname (probe-file fname)) (load fname))
  (unless (boundp '*ri*) (robot-model-init))
  (when
      (boundp '*av-data*)
    (let (data (stimestr (unix::asctime (caar *start-end-time*)))
	       xyz xyzdata)
      (dolist (av *av-data*)
	(when (boundp '*ri*)
	  (send *ri* :robot :angle-vector av)
	  (setq xyz (copy-object (send *ri* :robot :end-coords :worldpos)))
	  )
	(push xyz xyzdata))
      (setq *xyz-data* (reverse xyzdata))
      (dotimes (i 3)
	(push (mapcar #'(lambda (fv) (elt fv i)) *xyz-data*) data))
      (graph-view
       (reverse data)
       *time-data*
       :keylist '("end-coords X" "end-coords Y" "end-coords Z")
       :xrange (list (round (apply #'min *time-data*))
		     (round (apply #'max *time-data*)))
       :yrange (list (apply #'min (mapcar #'(lambda (x) (apply #'min x)) data))
		     (apply #'max (mapcar #'(lambda (x) (apply #'max x)) data)))
       :graph-instance (setq *gp* (gnuplot))
       :title (format nil "~A end-pos  ~A"
		      "leader"
		      (if fname fname
			(subseq stimestr 0 (1- (length stimestr)))))
       ))
    ))

(defun xyz-2dplot2 (&key fname &aux xyz xyz2)
  (if (and fname (probe-file fname)) (load fname))
  (unless (boundp '*ri*) (robot-model-init))
  (when
      (and (boundp '*av-data*)
	   (boundp '*rv-data*) *rv-data*)
    (let (data (stimestr (unix::asctime (caar *start-end-time*)))
	       xyz xyzdata)
      (dotimes (i (length *av-data*))
	(send *ri* :robot :angle-vector (elt *av-data* i))
	(setq xyz (copy-object (send *ri* :robot :end-coords :worldpos)))
	(send *robot* :angle-vector (elt *rv-data* i))
	(setq xyz2 (copy-object (send *robot* :end-coords :worldpos)))
	(setq xyz (concatenate float-vector xyz xyz2))
	(push xyz xyzdata))
      (setq *xyz-data* (reverse xyzdata))
      (dotimes (i 6)
	(push (mapcar #'(lambda (fv) (elt fv i)) *xyz-data*)
	      data))
      (graph-view
       (reverse data)
       *time-data*
       :keylist
       (if (and (boundp '*rv-data*) *rv-data*)
	   '("leader X" "leader Y" "leader Z"
	     "follower X" "follower Y" "follower Z")
	 '("end-coords X" "end-coords Y" "end-coords Z"))
       :xrange (list (round (apply #'min *time-data*))
		     (round (apply #'max *time-data*)))
       :yrange (list (apply #'min (mapcar #'(lambda (x) (apply #'min x)) data))
		     (apply #'max (mapcar #'(lambda (x) (apply #'max x)) data)))
       :graph-instance (setq *gp* (gnuplot))
       :title (format nil "~A end-pos  ~A"
		      "leader follower"
		      (if fname fname
			(subseq stimestr 0 (1- (length stimestr)))))
       ))
    ))

(defun xyz-3dplot (&key fname)
  (if (and fname (probe-file fname)) (load fname))
  (unless (boundp '*ri*) (robot-model-init))
  (when
      (boundp '*av-data*)
    (let (data (stimestr (unix::asctime (caar *start-end-time*)))
	       xyz xydata zdata)
      (dolist (av *av-data*)
	(send *ri* :robot :angle-vector av)
	(setq xyz (copy-object (send *ri* :robot :end-coords :worldpos)))
	(push (elt xyz 2) zdata)
	(push (list (elt xyz 0) (elt xyz 1)) xydata))
      (setq *xy-data* (reverse xydata))
      (setq *z-data* (reverse zdata))
      (graph-view
       (list *z-data*)
       *xy-data*
       :xrange (list (round (apply #'min (mapcar #'car *xy-data*)))
		     (round (apply #'max (mapcar #'car *xy-data*))))
       :yrange (list (round (apply #'min (mapcar #'cadr *xy-data*)))
		     (round (apply #'max (mapcar #'cadr *xy-data*))))
       :zrange (list (round (apply #'min *z-data*))
		     (round (apply #'max *z-data*)))
       :graph-instance (setq *gp* (gnuplot))
       :title (format nil "~A end-pos  ~A"
		      "leader"
		      (if fname fname
			(subseq stimestr 0 (1- (length stimestr)))))
       ))
    ))

(defun xyz-3dplot2 (&key fname)
  (if (and fname (probe-file fname)) (load fname))
  (unless (boundp '*ri*) (robot-model-init))
  (when
      (and (boundp '*av-data*) (boundp '*rv-data*) *rv-data*)
    (let (data (stimestr (unix::asctime (caar *start-end-time*)))
	       xyz xyz2 xydata zdata xydata2 zdata2)
      (dotimes (i (length *av-data*))
	(send *ri* :robot :angle-vector (elt *av-data* i))
	(send *ri* :robot :viewer :draw-objects)
	(setq xyz (copy-object (send *ri* :robot :end-coords :worldpos)))
	(push (list (elt xyz 0) (elt xyz 1)) xydata)
	(push (elt xyz 2) zdata)
	(send *robot* :angle-vector (elt *rv-data* i))
	(send *robot* :viewer :draw-objects)
	(setq xyz2 (copy-object (send *robot* :end-coords :worldpos)))
	(push (elt xyz2 2) zdata2)
	(push (list (elt xyz2 0) (elt xyz2 1)) xydata2)
	)
      (setq *z-data* (list (reverse zdata) (reverse zdata2)))
      (setq *xy-data* (reverse xydata))
      (graph-view
       *z-data*
       *xy-data*
       :xrange (list (round (apply #'min (mapcar #'car *xy-data*)))
		     (round (apply #'max (mapcar #'car *xy-data*))))
       :yrange (list (round (apply #'min (mapcar #'cadr *xy-data*)))
		     (round (apply #'max (mapcar #'cadr *xy-data*))))
       :zrange (list (round (apply #'min (car *z-data*)))
		     (round (apply #'max (car *z-data*))))
       :graph-instance (setq *gp* (gnuplot))
       :title (format nil "~A end-pos  ~A"
		      "leader follower"
		      (if fname fname
			(subseq stimestr 0 (1- (length stimestr)))))
       ))
    ))

(defun xyz-3dplot3 (&key fname) ;; 3D *rv-data*
  (if (and fname (probe-file fname)) (load fname))
  (unless (boundp '*ri*) (robot-model-init))
  (when
      (and (boundp '*rv-data*) *rv-data*)
    (let (data (stimestr (unix::asctime (caar *start-end-time*)))
	       xyz xyz2 xydata zdata xydata2 zdata2)
      (dotimes (i (length *rv-data*))
	(send *ri* :robot :angle-vector (elt *rv-data* i))
	(send *ri* :robot :viewer :draw-objects)
	(setq xyz (copy-object (send *ri* :robot :end-coords :worldpos)))
	(push (list (elt xyz 0) (elt xyz 1)) xydata)
	(push (elt xyz 2) zdata)
	(send *robot* :angle-vector (elt *rv-data* i))
	(send *robot* :viewer :draw-objects)
	)
      (setq *z-data* (list (reverse zdata)))
      (setq *xy-data* (reverse xydata))
      (graph-view
       *z-data*
       *xy-data*
       :xrange (list (round (apply #'min (mapcar #'car *xy-data*)))
		     (round (apply #'max (mapcar #'car *xy-data*))))
       :yrange (list (round (apply #'min (mapcar #'cadr *xy-data*)))
		     (round (apply #'max (mapcar #'cadr *xy-data*))))
       :zrange (list (round (apply #'min (car *z-data*)))
		     (round (apply #'max (car *z-data*))))
       :graph-instance (setq *gp* (gnuplot))
       :title (format nil "~A end-pos  ~A"
		      "follower"
		      (if fname fname
			(subseq stimestr 0 (1- (length stimestr)))))
       ))
    ))

(defun animate-data (&key fname (name "iarm0") send)
  (if (and fname (probe-file fname)) (load fname))
  (unless (boundp '*ri*) (robot-model-init name))
  (when (boundp '*av-data*)
    (let ((pre (car *time-data*)) now)
      (dotimes (i (length *av-data*))
	(if (and send (boundp '*csock*))
	    (unix::sendto *csock* *caddr*
			  (format nil "~A" (elt *av-data* i))))
	(send *ri* :robot :angle-vector (elt *av-data* i))
	(send *ri* :robot :viewer :draw-objects)
	(unix:usleep (round (* 1000000
			       (- (setq now (elt *time-data* i)) pre))))
	(setq pre now)))
    ))

(format t "(data-plot)~%")
(defun data-plot nil
  (unless (boundp '*ri*) (robot-model-init))
  (joint-plot)
  (analog-plot)
  (xyz-2dplot)
  (xyz-3dplot)
  (animate-data)
  )

(format t "(data-plot2)~%")
(defun data-plot2 nil
  (unless (boundp '*ri*) (robot-model-init))
  (joint-plot2)
  (analog-plot2)
  (xyz-2dplot2)
  (xyz-3dplot)
  (xyz-3dplot2)
  (xyz-3dplot3)
  (animate-data)
  )

(format t "(store-loop)~%")
(format t "(joint-plot)~%")
(format t "(analog-plot)~%")
(format t "(xyz-2dplot)~%")
(format t "(xyz-3dplot)~%")
;;
(format t "(store-loop :fname \"test.dat\")~%")
(format t "(store-loop :fname \"test.dat\" :send t :show t)~%")
;;
(format t "(joint-plot :fname \"test.dat\")~%")
(format t "(analog-plot :fname \"test.dat\")~%")
(format t "(xyz-2dplot :fname \"test.dat\")~%")
(format t "(xyz-3dplot :fname \"test.dat\")~%")
;;
(format t "(animate-data)~%")
(format t "(animate-data :fname \"test.dat\")~%")
(format t "(animate-data :fname \"test.dat\" :send t})~%")

