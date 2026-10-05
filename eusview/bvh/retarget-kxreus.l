;;;
;;; retarget-kxreus.l : write the kxreus EusView retargeting (~/kxreus/eusview-retarget.l,
;;;   eusview-bvh-export-retarget) for the app check (eusview/ios/tools/retargettest kxreus)
;;;   EUS_TIMEOUT=1800 eusview/run-eus.sh eusview/bvh/retarget-kxreus.l
;;;   -> ~/.cache/eusview/retarget-<robot>-<kind>-<name>-<method>.json
;;;
(defvar *eusview-dir* (or (unix:getenv "EUSVIEW_DIR") (format nil "~A/eusview" (if (boundp '*rcb4eus-dir*) *rcb4eus-dir* (format nil "~A/kxreus" (unix:getenv "HOME"))))))  ;; set by run-eus.sh
(load (format nil "~A/irtload.l" *eusview-dir*))
(load (format nil "~A/kxr-env.l" *eusview-dir*))   ;; caches under eusview/cache (kxreus is only read)
(load (format nil "~A/eusview.l" *rcb4eus-dir*))
;; (file start end step): sfu is 120 fps in the BVH (the app has every 4th frame)
(defvar *rk-files*
  '(("mocopi/greeting1.bvh" 0 940 40) ("mocopi/factory_1.bvh" 0 2000 80)
    ("rikiya/rbvh_a/A01.bvh" 0 130 10) ("rikiya/rbvh_e/E01.bvh" 0 300 12)
    ("sfu/0005_Jogging001.bvh" 0 1380 60) ("sfu/0012_SpeedVault001.bvh" 0 1000 40)
    ("lafan1/walk1_subject1.bvh" 0 7800 600) ("tum-kitchen/0-0/poses.bvh" 0 1200 100)))
(defvar *rk-robots* '("kxrl2l6a6h2" "khr20h2" "sample-robot"))
(dolist (f *rk-files*)
  (dolist (r *rk-robots*)
    (dolist (m '(:names :gmr))
      (unless (and (eq m :names) (substringp "tum-kitchen" (car f)))
        (eusview-bvh-export-retarget (elt f 0) r m (elt f 1) (elt f 2) (elt f 3))))))
(format t ";;EUSVIEW-DONE~%")
(exit)
