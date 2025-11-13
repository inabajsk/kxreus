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
  (send *ri0* :com-init)
  (send *ri0* :timer-on)
  )

(defun dclient-init (&key (ip "192.168.1.18") (port 2000))
  (setq *caddr* (make-socket-address :domain af_inet :host ip :port port))
  (setq *csock* (unix::socket (send *caddr* :domain) 2 0))
  )

(defun dclient-loop nil
  (do-until-key
   (setq a (send *ri0* :read-angle-vector))
   (unix::sendto *csock* *caddr* (format nil "~A" a))
   ;;(print a)
   (send *ri0* :robot :angle-vector a)
   (send *ri0* :viewer :draw-objects)
   )
  )

(format t "(robot-init)~%")
(format t "(dclient-init)~%")
(format t "(dclient-loop)~%")
