;; sample-robot + walk motion (irteus/demo/walk-motion.l test2, without the viewer)
;;   eusview/run-eus.sh eusview/export-walk.l  -> robots/jsk/sample-robot-walk.json
;; motions[].root[i] = world coords of links[0] (the root link) at frame i:
;;   [x y z (m), r00 r01 r02 r10 r11 r12 r20 r21 r22]; it replaces links[0].pos/rot.
(defvar *eusview-dir* (or (unix:getenv "EUSVIEW_DIR") (format nil "~A/eusview" (if (boundp '*rcb4eus-dir*) *rcb4eus-dir* (format nil "~A/kxreus" (unix:getenv "HOME"))))))  ;; set by run-eus.sh
(load (format nil "~A/irtload.l" *eusview-dir*))
(load (format nil "~A/eus2json.l" *eusview-dir*))
(load "irteus/demo/sample-robot-model.l")
(setq *fps* 30)
(setq r (instance sample-robot :init))
(defun walk-pattern (robot x y th)
  (send robot :reset-pose)
  (send robot :fix-leg-to-coords (make-coords))
  (send robot :calc-walk-pattern-from-footstep-list
        (send robot :go-pos-params->footstep-list x y th)
        :debug-view nil :default-step-height 50 :dt (/ 1.0 *fps*)))
(setq pat (walk-pattern r 500 150 45))
(format t ";; walk pattern: ~A frames~%" (length pat))
;; root-coords from the pattern vs. the root link after the last frame
(format t ";; last root-coords ~A root link ~A~%" (cadr (memq :root-coords (car (last pat))))
        (send (car (send r :links)) :worldcoords))
(setq frames (mapcar #'(lambda (p) (cadr (memq :angle-vector p))) pat))
(setq roots (mapcar #'(lambda (p) (cadr (memq :root-coords p))) pat))
;; check: put frame k on the robot and record link positions (for the viewer test)
(setq k (/ (length pat) 2))
(send r :angle-vector (elt frames k))
(send r :move-coords (elt roots k) (car (send r :links)))
(send r :worldcoords)
(setq check
  (format nil "{\"frame\":~d,\"link_world_pos\":[~a]}" k
          (e2j-join (mapcar #'(lambda (l) (json-vec (send l :worldpos) 5 0.001))
                            (e2j-sort-links (send r :links))))))
(send r :newcoords (make-coords))
(send r :reset-pose)
(eus2json r (format nil "~A/robots/jsk/sample-robot-walk.json" *eusview-dir*) :name "sample-robot" :group "jsk"
          :source "irteus/demo/sample-robot-model.l + walk-motion.l (go-pos 500 150 45)"
          :motions (list (list "walk-go-pos-500-150-45" *fps* frames roots check)))
(format t ";;EUSVIEW-DONE~%")
(exit)
