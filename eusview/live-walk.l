;; live-walk.l : sample-robot の歩行を EusLisp で計算しながら iPhone の EusView に送る
;;   python3 eusview/live.py &      (中継)
;;   iPhone の EusView で sample-robot を開き「接続」→ ws://<Mac の IP>:8766/
;;   EUS_TIMEOUT=600 eusview/run-eus.sh eusview/live-walk.l
(defvar *eusview-dir* (or (unix:getenv "EUSVIEW_DIR") (format nil "~A/eusview" (if (boundp '*rcb4eus-dir*) *rcb4eus-dir* (format nil "~A/kxreus" (unix:getenv "HOME"))))))  ;; set by run-eus.sh
(load (format nil "~A/irtload.l" *eusview-dir*))
(load (format nil "~A/eus2json.l" *eusview-dir*))
(load (format nil "~A/eus2live.l" *eusview-dir*))
(load "irteus/demo/sample-robot-model.l")
(setq r (instance sample-robot :init))
(live-connect)
(setq *fps* 30)
(dotimes (k 3)
  (send r :newcoords (make-coords))
  (send r :reset-pose)
  (send r :fix-leg-to-coords (make-coords))
  (live-send r)
  (unix:usleep 500000)
  ;; 歩行パターンを 1 コマずつ計算して, そのつど送る
  (dolist (p (send r :calc-walk-pattern-from-footstep-list
                   (send r :go-pos-params->footstep-list (if (evenp k) 500 300) (if (evenp k) 150 -100) (if (evenp k) 45 -30))
                   :debug-view nil :default-step-height 50 :dt (/ 1.0 *fps*)))
    (send r :angle-vector (cadr (memq :angle-vector p)))
    (send r :move-coords (cadr (memq :root-coords p)) (car (send r :links)))
    (live-send r)
    (unix:usleep (round (/ 1e6 *fps*)))))
(live-pose "reset-pose")
(format t ";;EUSVIEW-DONE~%")
(exit)
