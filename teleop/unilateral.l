;;
;; Teleop system for PU-Toyama 2025.11.13 M.I
;;
(require :rcb4robots)
(require :iarm)

(defparameter *leader-ip* "192.168.1.34")
(defparameter *follower-ip* "192.168.1.18")
(defparameter *port-number* 2000)
;;(defparameter *baudrate* 115200)
(defparameter *baudrate* 1250000)

(push
 '("iarm0"  ;; leader
   (:file "iarm.l" :form (instance iarmclass :init))
   (0 :joint0 -1)
   (2 :joint1 1)
   (4 :joint2 -1)
   (8 :joint3 -1)
   )
 *kxr-body-config-alist*)

(push
 '("iarm1"  ;; follower
   (:file "iarm.l" :form (instance iarmclass :init))
   (0 :joint0 -1)
   (2 :joint1 1)
   (4 :joint2 -1)
   (8 :joint3 -1)
   )
 *kxr-body-config-alist*)

(defun robot-model-init (&optional (name "iarm0"))
  (setq *ri* (kxr-make-robot-interface name :viewer t))
  (send *ri* :viewer :change-background (float-vector 0.9 0.9 0.7))
  (send *ri* :viewer :look-all)
  )

(defun robot-init (&optional (name "iarm0") &key free stretch)
  (robot-model-init name)
  (send *ri* :com-init :baud *baudrate*)
  (if free (send *ri* :free))
  (if stretch (send *ri* :send-stretch stretch))
  ;;(send *ri* :timer-on)
  )

(defun follower-recv (&aux msg sym)
  (while (setq msg (unix::recvfrom *ssock*))
    (when (stringp msg)
      (setq sym (read-from-string msg))
      (when (float-vector-p sym) (setq *angle-vector* sym)))
    (unix::usleep (* 1 1000))
    ))

(defun follower-init (&key (name "iarm1") (ip *follower-ip*) (port 2000) stretch)
  (robot-init name :stretch stretch)
  (setq *saddr* (make-socket-address :domain af_inet :host ip :port port))
  (setq *ssock* (make-dgram-socket *saddr*))
  (unix::sleep 1)
  (need-thread 4)
  (sys::thread-no-wait #'follower-recv)
  )

(defun follower-loop nil
  (when (boundp '*angle-vector*)
    (do-until-key
     (send *ri* :angle-vector *angle-vector* 1)
     (send *ri* :robot :angle-vector *angle-vector*)
     (send *ri* :viewer :draw-objects))
    )
  )

(format t "(follower-init)~%")
(format t "(follower-loop)~%")

(defun leader-init (&key (name "iarm0")
			 (ip *follower-ip*) (port 2000) (free t))
  (robot-init name :free free)
  (setq *caddr* (make-socket-address :domain af_inet :host ip :port port))
  (setq *csock* (unix::socket (send *caddr* :domain) 2 0))
  )

(defun leader-loop nil
  (do-until-key
   (setq a (send *ri* :read-angle-vector))
   (unix::sendto *csock* *caddr* (format nil "~A" a))
   (send *ri* :robot :angle-vector a)
   (send *ri* :viewer :draw-objects)
   )
  )

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

(defun animate-data (&key fname (name "iarm0") send)
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

(format t "(leader-init)~%")
(format t "(leader-loop)~%")
(format t "(store-loop \"test.dat\")~%")
(format t "(store-loop \"test.dat\" :send nil :show nil)~%")
(format t "(graph-plot)~%")
(format t "(graph-plot \"test.dat\")~%")
(format t "(animate-data)~%")
(format t "(animate-data \"test.dat\")~%")
(format t "(animate-data \"test.dat\" :send t})~%")
