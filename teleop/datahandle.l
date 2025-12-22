;;
;; Data store/plot/animate 2025.11.14 M.I
;;
(provide :datahandle)
(require :teleop)

(defun store-loop (&key fname show send (robot "iarm0"))
  (let ((mt (instance mtimer :init))
	ad addata av avdata tmdata tm0 tm1 xyz xyzdata)
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
     (push av avdata)
     (push ad addata)
     (push (send mt :stop) tmdata)
     (if send (unix::sendto *csock* *caddr* (format nil "~A" av)))
     )
    (setq tm1 (list (unix::localtime) (unix:gettimeofday)))
    (setq *robot-name* (send *ri* :robot :name))
    (setq *start-end-time* (list tm0 tm1))
    (setq *av-data* (reverse avdata))
    (setq *ad-data* (reverse addata))
    (setq *time-data* (reverse tmdata))
    (dump-loadable-structure fname *robot-name*
			     *start-end-time* *av-data* *ad-data* *time-data*)
    (joint-plot)
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
		      *robot-name*
		      (if fname fname
			(subseq stimestr 0 (1- (length stimestr)))))
       ))
    ))

(defun analog-plot (&key fname (yrange '(0 1000))
			 (idxs '(0 1 2 3 4 5 6 7 8 9 10)))
  (if (and fname (probe-file fname)) (load fname))
  (when
      (boundp '*ad-data*)
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
       :yrange yrange
       :graph-instance (setq *gp* (gnuplot))
       :title (format nil "~A Joints  ~A"
		      *robot-name*
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
		      *robot-name*
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
		      *robot-name*
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
