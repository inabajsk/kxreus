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
(push
 '("iarm1"
   (:file "iarm.l" :form (instance iarmclass :init))
   (3 :joint0 1)
   (5 :joint1 1)
   (7 :joint2 1)
   (9 :joint3 1)
   )
 *kxr-body-config-alist*)

(defun setup nil
  (setq *ri0* (kxr-make-robot-interface "iarm0" :viewer t))
  (send *ri0* :viewer :change-background (float-vector 0.9 0.9 0.7))
  (send *ri0* :viewer :look-all)
  ;;
  (setq *ri1* (kxr-make-robot-interface "iarm1" :viewer t))
  (send *ri1* :viewer :change-background (float-vector 0 0.9 0.7))
  (send *ri1* :viewer :look-all)
  )
(defun init0 nil
  (send *ri0* :com-init)
  (send *ri0* :timer-on)
  )
(defun init1 nil
  (send *ri1* :com-init)
  )
#|
(format t ";; (make-kxr-robot \"iarm0\")~%")
(format t ";; (make-iarm)~%")
(defun make-iarm ()
  (setq *robot* (iarm))
  (objects (list *robot*))
  (send *irtviewer* :change-background (float-vector 0 0.9 0.7))
  (send *irtviewer* :look-all)
  (setq *ri* (instance rcb4-interface :init))
  (setq (*ri* . robot) (iarm))
  (setq *ri-viewer* (make-irtviewer))
  (send *ri-viewer* :objects (list (*ri* . robot)))
  (send *ri-viewer* :change-background (float-vector 0.6 0.4 0.99))
  (send *ri-viewer* :look-all)
  (setq (*ri* . av-length) (length (send (*ri* . robot) :angle-vector)))
  ;;(send *ri* :com-init)
  *robot*)
|#

