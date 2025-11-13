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
  )

(defun server-init (&key (ip "192.168.1.18") (port 2000))
  (setq *saddr* (make-socket-address :domain af_inet
				     :host ip :port port))
  (setq *sport* (make-socket-port *saddr*))
  (setq *sstrm* (make-server-socket-stream *sport*))
  )
(defun server-loop nil
  (do-until-key
   ;;(when (select-stream (list *sstrm*) 0.001)
   (setq a (read *sstrm* nil nil))
   ;;(print a)
   (send *ri0* :angle-vector a 1)
   (send *ri0* :robot :angle-vector a)
   (print (send *ri0* :read-angle-vector) *sstrm*)
   (send *ri0* :viewer :draw-objects))
  )

(defun read-all nil
  (do-until-key
   (when (select-stream (list *sstrm*) 0.1)
     (print (read *sstrm* nil nil))))
  )

(format t "(robot-init)~%")
(format t "(server-init)~%")
(format t "(server-loop)~%")
