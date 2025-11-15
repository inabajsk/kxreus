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
