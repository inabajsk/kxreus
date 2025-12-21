;;
;; robot parameter
;; 
(require :teleop)

(defparameter *leader-ip* "192.168.11.20")
(defparameter *follower-ip* "192.168.11.26")
(defparameter *port-number* 2000)
(defparameter *baudrate* 115200)
;;(defparameter *baudrate* 1250000)

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

(defmethod rcb4-interface
  (:push
   (&optional (l 10) (tm 10))
   (send robot :angle-vector (send self :read-angle-vector))
   (send robot :push l)
   (send self :angle-vector (send robot :angle-vector) tm)
   )
  (:react
   (&optional (th 300))
   )
  )

(defun react (&optional (th 300))
  (send *ri* :hold-all)
  (send *ri* :reset-pose)
  (do-until-key
   (send *robot* :angle-vector (send *ri* :read-angle-vector))
   (setq v (send *ri* :force-sense))
   (format t "v=~A~%" v)
   (when (> v th)
     (send *robot* :push -5)
     (send *ri* :angle-vector (send *robot* :angle-vector) 50)
     )
   )
  )

(defun demo nil
  (make-kxr-robot "iarm")
  (send *ri* :com-init)
  (send *ri* :reset-pose)
  (send *robot* :read-from-ri)
  (send *robot* :push 10)
  (send *robot* :send-to-ri)
  (send *robot* :read-from-ri)
  (send *robot* :push -10)
  (send *robot* :send-to-ri)
  (send *ri* :force-sense)
  )
