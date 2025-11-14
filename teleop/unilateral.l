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

(format t "(leader-init)~%")
(format t "(leader-loop)~%")

(defun leader nil
  (leader-init)
  (unix::sleep 1)
  (leader-loop)
  )
(format t "(leader)~%")

(defun follower nil
  (follower-init)
  (while (not (boundp '*angle-vector*)) (unix::sleep 1))
  (follower-loop)
  )
(format t "(follower)~%")

(require :datahandle)

