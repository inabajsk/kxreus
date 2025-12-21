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
   (10 :joint0 -1)
   (12 :joint1 1)
   (16 :joint2 -1)
   (20 :joint3 -1)
;;   (18 :joint4 -1)
   )
 *kxr-body-config-alist*)

