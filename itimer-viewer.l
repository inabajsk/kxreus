;;
;; 2025.12.21 M.I
;;
(provide :itimer-viewer)
;;
(defun irtviewer-update nil
  (when (boundp '*irtviewer*)
    (send *irtviewer* :draw-objects)
    (when (boundp '*robot*)
      (when (send *robot* :viewer)
	(send *robot* :viewer :draw-objects)))
    (when (boundp '*ri*)
      (when (send *ri* :robot :viewer)
	(send *ri* :robot :viewer :draw-objects)))
    (x::window-main-one)
    )
  )

(defun push-itimer-irtviewer-update nil
  (setq *top-selector-interval* 0.01)
  (pushnew 'irtviewer-update *timer-job*)
  (format t ";; push-itimer-irtviewer-update *timer-job*=~A~%" *timer-job*)
  )
;;
(defun pop-itimer-irtviewer-update nil
  (remove 'irtviewer-update *timer-job*))

(push-itimer-irtviewer-update)

