;;
;; Teleop system for PU-Toyama 2025.11.13 M.I
;;
(require :rcb4robots)
(require :iarm)

(defparameter *leader-ip* "192.168.1.34")
(defparameter *follower-ip* "192.168.1.18")
(defparameter *port-number* 2000)

(push
 '("iarm0"
   (:file "iarm.l" :form (instance iarmclass :init))
   (2 :joint0 1)
   (4 :joint1 1)
   (6 :joint2 1)
   (8 :joint3 1)
   )
 *kxr-body-config-alist*)
(push
 '("iarm1"
   (:file "iarm.l" :form (instance iarmclass :init))
   (2 :joint0 1)
   (4 :joint1 1)
   (6 :joint2 1)
   (8 :joint3 1)
   )
 *kxr-body-config-alist*)

(defun robot-init (&optional (name "iarm0") &key (stretch 1))
  (make-kxr-robot name :viewer t)
  (send *ri* :com-init) (send *ri* :timer-on)
  (send *ri* :hold) (send *ri* :send-stretch stretch))

(defun follower-recv nil
  (while (setq msg (unix::recvfrom *ssock*))
    (when (stringp msg)
      (setq sym (read-from-string msg))
      (when (float-vector-p sym) (setq *angle-vector* sym)))
    (unix::usleep (* 1 1000))
    ))

(defun follower-init (&key (ips *follower-ip*) (ipc *leader-ip*) (port *port-number*))
  (robot-init "iarm1")
  (setq *ssock* (make-dgram-socket
		 (make-socket-address :domain af_inet :host ips :port port)))
  (setq *csock* (unix::socket (send
			       (setq *caddr* (make-socket-address
					      :domain af_inet :host ipc :port port)) :domain) 2 0))
  (unix::sleep 1) (need-thread 4)
  (sys::thread-no-wait #'follower-recv))

(defun leader-recv nil
  (while (setq msg (unix::recvfrom *ssock*))
    (when (stringp msg) (setq sym (read-from-string msg))
	  (when (float-vector-p sym) (setq *real-vector* sym)))
    (unix::usleep (* 1 1000))))

(defun leader-init (&key (ips *follower-ip*) (ipc *leader-ip*) (port *port-number*))
  (robot-init "iarm0")
  (setq *csock* (unix::socket
		 (send (setq *caddr* (make-socket-address
				      :domain af_inet :host ips :port port)) :domain) 2 0))
  (setq *ssock* (make-dgram-socket
		 (make-socket-address :domain af_inet :host ipc :port port)))
  (unix::sleep 1) (need-thread 4)
  (sys::thread-no-wait #'leader-recv))

(defun follower-loop nil
  (when (boundp '*angle-vector*)
    (do-until-key
     (send *ri* :angle-vector *angle-vector* 1)
     (setq *real-vector* (send *ri* :read-angle-vector))
     (unix::sendto *csock* *caddr* (format nil "~A" *real-vector*))
     (send *ri* :robot :angle-vector *angle-vector*)
     (send *ri* :viewer :draw-objects))
    )
  )

(defun leader-loop nil
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

(format t "(leader-init)~%")
(format t "(leader-loop)~%")

(format t "(follower-init)~%")
(format t "(follower-loop)~%")
