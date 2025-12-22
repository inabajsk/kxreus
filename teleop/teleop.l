;;
;; Teleop system for PU-Toyama 2025.11.14 M.I
;;
(require :rcb4robots)
(require :iarm)
(require :utils)
(provide :teleop)

(defun robot-model-init (&optional (name "iarm0"))
  (setq *ri* (kxr-make-robot-interface name :viewer t))
  (send *ri* :viewer :change-background (float-vector 0.9 0.9 0.7))
  (send *ri* :viewer :look-all)
  )

(defun robot1-init (&optional (name "iarm0") &key free stretch)
  (robot-model-init name)
  (send *ri* :com-init :baud *baudrate*)
  (if free (send *ri* :free))
  (if stretch (send *ri* :send-stretch stretch))
  ;;(send *ri* :timer-on)
  )

(defun follower1-recv (&aux msg sym)
  (while (setq msg (unix::recvfrom *ssock*))
    (when (stringp msg)
      (setq sym (read-from-string msg))
      (when (float-vector-p sym) (setq *angle-vector* sym)))
    (unix::usleep (* 1 1000))
    ))

(defun follower1-init (&key (name "iarm1") (ip *follower-ip*) (port 2000) stretch)
  (robot1-init name :stretch stretch)
  (setq *saddr* (make-socket-address :domain af_inet :host ip :port port))
  (setq *ssock* (make-dgram-socket *saddr*))
  (unix::sleep 1)
  (need-thread 4)
  (sys::thread-no-wait #'follower1-recv)
  )

(defun follower1-loop nil
  (when (boundp '*angle-vector*)
    (do-until-key
     (send *ri* :angle-vector *angle-vector* 1)
     (send *ri* :robot :angle-vector *angle-vector*)
     (send *ri* :viewer :draw-objects)
     (x::window-main-one))
    )
  )

(defun leader1-init (&key (name "iarm0")
			  (ip *follower-ip*) (port 2000) (free t))
  (robot1-init name :free free)
  (setq *caddr* (make-socket-address :domain af_inet :host ip :port port))
  (setq *csock* (unix::socket (send *caddr* :domain) 2 0))
  )

(defun leader1-loop nil
  (do-until-key
   (setq a (send *ri* :read-angle-vector))
   (unix::sendto *csock* *caddr* (format nil "~A" a))
   (send *ri* :robot :angle-vector a)
   (send *ri* :viewer :draw-objects)
   )
  )

(format t "(leader1)~%")
(defun leader1 nil
  (leader1-init)
  (unix::sleep 1)
  (leader1-loop)
  )
(format t "(follower1)~%")
(defun follower1 nil
  (follower1-init)
  (while (not (boundp '*angle-vector*)) (unix::sleep 1))
  (follower1-loop)
  )
;;
;; type 2 bilateral
;;
(defun robot2-init (&optional (name "iarm0") &key (stretch 1))
  (make-kxr-robot name :viewer t)
  (send *ri* :com-init :baud *baudrate*) (send *ri* :timer-on)
  (send *ri* :hold) (send *ri* :send-stretch stretch))

(defun follower2-recv nil
  (while (setq msg (unix::recvfrom *ssock*))
    (when (stringp msg)
      (setq sym (read-from-string msg))
      (when (float-vector-p sym) (setq *angle-vector* sym)))
    ;;(unix::usleep (* 1 1000))
    ))

(defun follower2-init (&key (name "iarm1") (ips *follower-ip*) (ipc *leader-ip*) (port *port-number*)
			   (stretch 1))
  (robot2-init name :stretch stretch)
  (setq *ssock* (make-dgram-socket
		 (make-socket-address :domain af_inet :host ips :port port)))
  (setq *csock* (unix::socket (send
			       (setq *caddr* (make-socket-address
					      :domain af_inet :host ipc :port port)) :domain) 2 0))
  (unix::sleep 1) (need-thread 4)
  (sys::thread-no-wait #'follower2-recv))

(defun follower2-loop nil
  (when (boundp '*angle-vector*)
    (do-until-key
     (send *ri* :angle-vector *angle-vector* 1)
     (setq *real-vector* (send *ri* :read-angle-vector))
     (unix::sendto *csock* *caddr* (format nil "~A" *real-vector*))
     (send *ri* :robot :angle-vector *angle-vector*)
     (send *ri* :viewer :draw-objects)
     (x::window-main-one))
    )
  )

(defun leader2-recv nil
  (while (setq msg (unix::recvfrom *ssock*))
    (when (stringp msg) (setq sym (read-from-string msg))
	  (when (float-vector-p sym) (setq *real-vector* sym)))
    ;;(unix::usleep (* 1 1000))
    ))

(defun leader2-init (&key (ips *follower-ip*) (ipc *leader-ip*) (port *port-number*))
  (robot2-init "iarm0")
  (setq *csock* (unix::socket
		 (send (setq *caddr* (make-socket-address
				      :domain af_inet :host ips :port port)) :domain) 2 0))
  (setq *ssock* (make-dgram-socket
		 (make-socket-address :domain af_inet :host ipc :port port)))
  (unix::sleep 1) (need-thread 4)
  (sys::thread-no-wait #'leader2-recv))

(defun leader2-loop nil
  (do-until-key
   (setq *angle-vector* (send *ri* :read-angle-vector))
   (unix::sendto *csock* *caddr* (format nil "~A" *angle-vector*))
   (send *ri* :robot :angle-vector *angle-vector*)
   (send *ri* :viewer :draw-objects)
   (when (boundp '*real-vector*)
     (send *robot* :angle-vector *real-vector*)
     (send *robot* :viewer :draw-objects)
     (send *ri* :angle-vector *real-vector* 1)
     ))
  )

(format t "(leader2-init)~%")
(format t "(leader2-loop)~%")
(format t "(follower2-init)~%")
(format t "(follower2-loop)~%")

(format t "(leader2)~%")
(defun leader2 nil
  (leader2-init)
  (unix::sleep 1)
  (leader2-loop)
  )

(format t "(follower2)~%")
(defun follower2 nil
  (follower2-init)
  (while (not (boundp '*angle-vector*)) (unix::sleep 1))
  (follower2-loop)
  )
;;
;; type 3 unilateral and receive follower states
;;
(defun robot3-init (&optional (name "iarm0") &key (stretch 1))
  (make-kxr-robot name :viewer t)
  (send *ri* :com-init :baud *baudrate*) (send *ri* :timer-on)
  (send *ri* :hold) (send *ri* :send-stretch stretch))

(defun follower3-recv nil
  (while (setq msg (unix::recvfrom *ssock*))
    (when (stringp msg)
      (setq sym (read-from-string msg))
      (when (float-vector-p sym) (setq *angle-vector* sym)))
    ;;(unix::usleep (* 1 1000))
    ))

(defun follower3-init (&key (name "iarm1") (ips *follower-ip*) (ipc *leader-ip*) (port *port-number*)
			   (stretch 1))
  (robot3-init name :stretch stretch)
  (setq *ssock* (make-dgram-socket
		 (make-socket-address :domain af_inet :host ips :port port)))
  (setq *csock* (unix::socket (send
			       (setq *caddr* (make-socket-address
					      :domain af_inet :host ipc :port port)) :domain) 3 0))
  (unix::sleep 1) (need-thread 4)
  (sys::thread-no-wait #'follower3-recv))

(defun follower3-loop nil
  (when (boundp '*angle-vector*)
    (do-until-key
     (send *ri* :angle-vector *angle-vector* 1)
     (setq *real-vector* (send *ri* :read-angle-vector))
     (unix::sendto *csock* *caddr* (format nil "~A" *real-vector*))
     (send *ri* :robot :angle-vector *angle-vector*)
     (send *ri* :viewer :draw-objects)
     (x::window-main-one))
    ))

(defun leader3-recv nil
  (while (setq msg (unix::recvfrom *ssock*))
    (when (stringp msg) (setq sym (read-from-string msg))
	  (when (float-vector-p sym) (setq *real-vector* sym)))
    ))

(defun leader3-init (&key (ips *follower-ip*) (ipc *leader-ip*) (port *port-number*))
  (robot3-init "iarm0")
  (setq *csock* (unix::socket
		 (send (setq *caddr* (make-socket-address
				      :domain af_inet :host ips :port port)) :domain) 3 0))
  (setq *ssock* (make-dgram-socket
		 (make-socket-address :domain af_inet :host ipc :port port)))
  (unix::sleep 1) (need-thread 4)
  (sys::thread-no-wait #'leader3-recv))

(defun leader3-loop nil
  (do-until-key
   (setq *angle-vector* (send *ri* :read-angle-vector))
   (unix::sendto *csock* *caddr* (format nil "~A" *angle-vector*))
   (send *ri* :robot :angle-vector *angle-vector*)
   (send *ri* :viewer :draw-objects)
   (when (boundp '*real-vector*)
     (send *robot* :angle-vector *real-vector*)
     (send *robot* :viewer :draw-objects)
     ))
  )

(format t "(leader3-init)~%")
(format t "(leader3-loop)~%")
(format t "(follower3-init)~%")
(format t "(follower3-loop)~%")

(format t "(leader3)~%")
(defun leader3 nil
  (leader3-init)
  (unix::sleep 1)
  (leader3-loop)
  )

(format t "(follower3)~%")
(defun follower3 nil
  (follower3-init)
  (while (not (boundp '*angle-vector*)) (unix::sleep 1))
  (follower3-loop)
  )



(require :datahandle)
