;; export kxreus robots (https://github.com/inabajsk/kxreus, ~/kxreus via ~/.eusrc)
;;   EUSVIEW_ROBOTS="kxrl2l6a6h2 kxrl4t" eusview/run-eus.sh eusview/export-kxr.l
(defvar *eusview-dir* (or (unix:getenv "EUSVIEW_DIR") (format nil "~A/eusview" (if (boundp '*rcb4eus-dir*) *rcb4eus-dir* (format nil "~A/kxreus" (unix:getenv "HOME"))))))  ;; set by run-eus.sh
(load (format nil "~A/irtload.l" *eusview-dir*))
(load (format nil "~A/eus2json.l" *eusview-dir*))
(setq *out* (format nil "~A/robots/" *eusview-dir*))
(load (format nil "~A/kxr-env.l" *eusview-dir*))
(defun robot-names-from-env ()
  (let ((s (unix:getenv "EUSVIEW_ROBOTS")) (ret nil))
    (when s
      (with-input-from-string (in s)
        (let (x) (while (setq x (read in nil nil)) (push (string-downcase (string x)) ret)))))
    (nreverse ret)))
(dolist (name (or (robot-names-from-env)
                  '("kxrl2l6a6h2" "kxrl2l2a6h2m" "kxrl4t" "kxrl6" "kxrmw4a6h2m")))
  (let ((r (kxr-make-robot name :viewer nil :model nil)))
    (cond
     (r
      (format t ";; ~A: ~A links, ~A bodies (links' bodies ~A)~%" name (length (send r :links))
              (length (send r :bodies))
              (length (apply #'append (send-all (send r :links) :bodies))))
      (eus2json r (eusview-kxr-json name) :name name :group (eusview-kxr-group name)
                :source (format nil "kxreus (kxr-make-robot ~S :model nil)" name)))
     (t (format t ";; ~A: could not make the robot~%" name)))))
(format t ";;EUSVIEW-DONE~%")
(exit)
