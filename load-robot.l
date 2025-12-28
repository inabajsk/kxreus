;;
;;
(provide :load-robot)

#|
(defun load-robot (name)
  (load (format nil "models/~A.l" (string-downcase name)))
  (setq *robot* (apply (read-from-string name) nil)))
(defun load-robot (name)
  (let ((fname (format nil "~A/models/~A.l" *rcb4eus-dir*
		       (string-downcase (string name)))))
    (unless (probe-file fname)
      (eus2collada-robot name))
    (load fname)
    (setq *robot* (apply (read-from-string (string name)) nil))
    *robot*))
|#

(defun robot-class-name (name-str)
  (read-from-string (string-upcase (format nil "~A-robot" name-str))))
(defun robot-model-file-name (name-str)
  (format nil "models/~a.l" (string-downcase (string name-str))))

(defun load-robot (name-str)
  (let* ((func (read-from-string (string-downcase (string name-str))))
	 (cls (robot-class-name name-str)))
    (unless (boundp cls)
      (load (robot-model-file-name name-str)))
    (if (and (fboundp func) (boundp cls))
	(setq *robot* (instance (eval cls) :init))
      (warn ";; ~A is not defined!!~%" func))
    ))
