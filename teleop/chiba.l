;;
;;
;;
(require :teleop)

(defparameter *leader-ip* "192.168.1.34")
(defparameter *follower-ip* "192.168.1.18")
(defparameter *leader-ip* "192.168.88.137")
(defparameter *follower-ip* "192.168.88.137")

(defparameter *port-number* 2000)
(defparameter *baudrate* 1250000)

(defparameter *sensor-idxs* (list 4 5)) ;; force sensor index of :read-analog

(defmethod rcb4-interface
  (:force-sense nil (elt (send self :read-analog) *sensor-idx*))
  )

(push
 '("iarm0"  ;; leader
   (:file "iarm.l" :form (instance iarmclass :init))
   (2 :joint0 -1)
   (4 :joint1 1)
   (6 :joint2 -1)
   (8 :joint3 -1)
   )
 *kxr-body-config-alist*)

(push
 '("iarm1"  ;; follower
   (:file "iarm.l" :form (instance iarmclass :init))
   (2 :joint0 -1)
   (4 :joint1 1)
   (6 :joint2 -1)
   (8 :joint3 -1)
   )
 *kxr-body-config-alist*)

(push
 '("iarm"  ;; leader
   (:file "iarm.l" :form (instance iarmclass :init))
   (11 :joint0 -1)
   (13 :joint1 -1)
   (17 :joint2 -1)
   (21 :joint3 1)
   ;;   (18 :joint4 -1)
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
  (send *robot* :reset-pose)
  (send *ri* :robot :angle-vector (send *ri* :read-angle-vector))
  (send *ri* :angle-vector (send *robot* :angle-vector))
  (send *robot* :read-from-ri)
  (send *robot* :push 10)
  (send *robot* :send-to-ri)
  (send *robot* :read-from-ri)
  (send *robot* :push -10)
  (send *robot* :send-to-ri)
  (send *ri* :force-sense)
  )
