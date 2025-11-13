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

(defun robot-init nil
  (make-kxr-robot "iarm0")
  (send *ri* :com-init)
  (send *ri* :timer-on)
  (send *ri* :hold)
  (send *ri* :send-stretch 1)
  )

(defun creceive-loop nil
  (while t
    (setq msg (unix::recvfrom *ssock*))
    (when (stringp msg)
      (setq sym (read-from-string msg))
      (when (float-vector-p sym)
	(setq *real-vector* sym))
      )
    (unix::usleep (* 2 1000))
    ))

(defun bclient-init (&key (ips *follower-ip*)
			  (ipc *client-ip*) (port *port-number*))
  (setq *caddr* (make-socket-address :domain af_inet :host ips :port port))
  (setq *csock* (unix::socket (send *caddr* :domain) 2 0))
  ;;
  (setq *saddr* (make-socket-address :domain af_inet
				     :host ipc :port port))
  (setq *ssock* (make-dgram-socket *saddr*))
  ;;
  (unix::sleep 1)
  (need-thread 4)
  (sys::thread-no-wait #'creceive-loop)
  )

(defun bclient-loop nil
  (do-until-key
   (setq *angle-vector* (send *ri* :read-angle-vector))
   (unix::sendto *csock* *caddr* (format nil "~A" *angle-vector*))
   ;;(print a)
   (send *ri* :robot :angle-vector *angle-vector*)
   (send *ri* :viewer :draw-objects)
   (when (boundp '*real-vector*)
     (send *robot* :angle-vector *real-vector*)
     (send *robot* :viewer :draw-objects)
     (send *ri* :angle-vector *real-vector* 1)
     ))
  )

(format t "(robot-init)~%")
(format t "(bclient-init)~%")
(format t "(bclient-loop)~%")
