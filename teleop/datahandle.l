;;
;; Data store/plot/animate 2025.11.14 M.I
;;
(provide :datahandle)

(defun store-loop (&optional (fname (format nil "~A ~A.dat"
					    (send *ri* :robot :name)
					    (car (unix::gettimeofday))))
			     &key (show t) (send t))
  (let ((mt (instance mtimer :init))
	av avdata tmdata tm0 tm1)
    (setq tm0 (list (unix::localtime) (unix:gettimeofday)))
    (send mt :start)
    (do-until-key
     (setq av (send *ri* :read-angle-vector))
     (if send (unix::sendto *csock* *caddr* (format nil "~A" av)))
     (when show
       (send *ri* :robot :angle-vector av)
       (send *ri* :viewer :draw-objects))
     (push av avdata)
     (push (send mt :stop) tmdata)
     (unix::sendto *csock* *caddr* (format nil "~A" av))
     )
    (setq tm1 (list (unix::localtime) (unix:gettimeofday)))
    (setq *robot-name* (send *ri* :robot :name))
    (setq *start-end-time* (list tm0 tm1))
    (setq *av-data* (reverse avdata))
    (setq *time-data* (reverse tmdata))
    (dump-loadable-structure fname *robot-name*
			     *start-end-time* *av-data* *time-data*)
    (graph-plot)
    ))

(defun graph-plot (&key fname (yrange '(-90 90)))
  (if (and fname (probe-file fname)) (load fname))
  (when
      (boundp '*time-data*)
    (let (data (stimestr (unix::asctime (caar *start-end-time*))))
      (dotimes (i 4)
	(push (mapcar #'(lambda (fv) (elt fv i)) *av-data*) data))
      (graph-view
       (reverse data)
       *time-data*
       :xrange (list (round (car (find-extreams *time-data* :bigger #'<)))
		     (round (car (find-extreams *time-data* :bigger #'>))))
       :yrange yrange
       :title (format nil "~A Joints  ~A"
		      *robot-name*
		      (if fname fname
			(subseq stimestr 0 (1- (length stimestr)))))
       ))
    ))

(defun animate-data (&key fname (name "iarm0") (send t))
  (if (and fname (probe-file fname)) (load fname))
  (unless (boundp '*ri*) (robot-model-init name))
  (when (boundp '*av-data*)
    (let ((pre (car *time-data*)) now)
      (dotimes (i (length *av-data*))
	(if send (unix::sendto *csock* *caddr*
			       (format nil "~A" (elt *av-data* i))))
	(send *ri* :robot :angle-vector (elt *av-data* i))
	(send *ri* :viewer :draw-objects)
	(unix:usleep (round (* 1000000
			       (- (setq now (elt *time-data* i)) pre))))
	(setq pre now)))
    ))

(format t "(store-loop \"test.dat\")~%")
(format t "(store-loop \"test.dat\" :send nil :show nil)~%")
(format t "(graph-plot)~%")
(format t "(graph-plot \"test.dat\")~%")
(format t "(animate-data)~%")
(format t "(animate-data \"test.dat\")~%")
(format t "(animate-data \"test.dat\" :send t})~%")
