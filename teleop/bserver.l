;;
;; Teleop system for PU-Toyama 2025.11.13 M.I
;;
(require :rcb4robots)
(require :iarm)

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
  (setq *ri0* (kxr-make-robot-interface "iarm0" :viewer t))
  (send *ri0* :viewer :change-background (float-vector 0.9 0.9 0.7))
  (send *ri0* :viewer :look-all)
  ;;
  (send *ri0* :com-init)
  (send *ri0* :timer-on)
  (send *ri0* :send-stretch 1) 
  )

(defun breceive-loop nil
  (while t
    (setq msg (unix::recvfrom *ssock*))
    (when (stringp msg)
      (setq sym (read-from-string msg))
      (when (float-vector-p sym)
	(setq *angle-vector* sym))
      )
    (unix::usleep (* 2 1000))
    ))

(defun bserver-init (&key (ips "192.168.1.18") (ipc "192.168.1.34")
			  (port 2000))
  (setq *saddr* (make-socket-address :domain af_inet
				     :host ips :port port))
  (setq *ssock* (make-dgram-socket *saddr*))
  (setq *caddr* (make-socket-address :domain af_inet
				     :host ipc :port port))
  (setq *csock* (unix::socket (send *caddr* :domain) 2 0))
  (unix::sleep 1)
  (need-thread 4)
  (sys::thread-no-wait #'breceive-loop)
  )

(defun bserver-loop nil
  (when (boundp '*angle-vector*)
    (do-until-key
     (send *ri0* :angle-vector *angle-vector* 1)
     (setq *real-vector* (send *ri0* :read-angle-vector))
     (unix::sendto *csock* *caddr* (format nil "~A" *real-vector*))
     (send *ri0* :robot :angle-vector *angle-vector*)
     (send *ri0* :viewer :draw-objects))
    )
  )

(format t "(robot-init)~%")
(format t "(bserver-init)~%")
(format t "(bserver-loop)~%")
