;;
;; Teleop system for PU-Toyama 2025.11.13 M.I
;;
(require :rcb4robots)
(require :iarm)

(defparameter *follower-ip* "192.168.1.18")
(defparameter *port-number* 2000)

(push
 '("iarm0"  ;; leader
   (:file "iarm.l" :form (instance iarmclass :init))
   (2 :joint0 1)
   (4 :joint1 1)
   (6 :joint2 1)
   (8 :joint3 1)
   )
 *kxr-body-config-alist*)

(push
 '("iarm1"  ;; follower
   (:file "iarm.l" :form (instance iarmclass :init))
   (2 :joint0 1)
   (4 :joint1 1)
   (6 :joint2 1)
   (8 :joint3 1)
   )
 *kxr-body-config-alist*)

(defun robot-init (&optional (name "iarm0") free)
  (setq *ri* (kxr-make-robot-interface name :viewer t))
  (send *ri* :viewer :change-background (float-vector 0.9 0.9 0.7))
  (send *ri* :viewer :look-all)
  ;;
  (send *ri* :com-init)
  (if free (send *ri* :free))
  ;;(send *ri* :timer-on)
  )

(defun follower-recv (&aux msg sym)
  (while (setq msg (unix::recvfrom *ssock*))
    (when (stringp msg)
      (setq sym (read-from-string msg))
      (when (float-vector-p sym) (setq *angle-vector* sym)))
    (unix::usleep (* 1 1000))
    ))

(defun follower-init (&key (name "iarm1") (ip *follower-ip*) (port 2000))
  (robot-init name)
  (setq *saddr* (make-socket-address :domain af_inet
				     :host ip :port port))
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

(defun leader-init (&key (name "iarm0") (ip *follower-ip*) (port 2000) (free t))
  (robot-init name free)
  (setq *caddr* (make-socket-address :domain af_inet :host ip :port port))
  (setq *csock* (unix::socket (send *caddr* :domain) 2 0))
  )

(defun leader-loop nil
  (do-until-key
   (setq a (send *ri* :read-angle-vector))
   (unix::sendto *csock* *caddr* (format nil "~A" a))
   ;;(print a)
   (send *ri* :robot :angle-vector a)
   (send *ri* :viewer :draw-objects)
   )
  )

(format t "(leader-init)~%")
(format t "(leader-loop)~%")
