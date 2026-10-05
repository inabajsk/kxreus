;; export the jskeus irteus/demo robots
;;   eusview/run-eus.sh eusview/export-demo.l
(defvar *eusview-dir* (or (unix:getenv "EUSVIEW_DIR") (format nil "~A/eusview" (if (boundp '*rcb4eus-dir*) *rcb4eus-dir* (format nil "~A/kxreus" (unix:getenv "HOME"))))))  ;; set by run-eus.sh
(load (format nil "~A/irtload.l" *eusview-dir*))
(load (format nil "~A/eus2json.l" *eusview-dir*))
(setq *out* (format nil "~A/robots/jsk/" *eusview-dir*))
(load "irteus/demo/sample-robot-model.l")
(load "irteus/demo/sample-arm-model.l")
(load "irteus/demo/sample-hand-model.l")
(load "irteus/demo/sample-multidof-arm-model.l")
(dolist (e (list
            (list "sample-robot" "irteus/demo/sample-robot-model.l" #'(lambda () (instance sample-robot :init)))
            (list "sample-arm" "irteus/demo/sample-arm-model.l" #'(lambda () (instance sarmclass :init)))
            (list "sample-hand" "irteus/demo/sample-hand-model.l" #'(lambda () (instance sample-hand :init)))
            (list "sample-multidof-arm" "irteus/demo/sample-multidof-arm-model.l"
                  #'(lambda () (instance sample-multidof-arm-robot :init)))))
  (let ((r (funcall (elt e 2))))
    (eus2json r (format nil "~A~A.json" *out* (elt e 0)) :name (elt e 0) :source (elt e 1) :group "jsk")))
(format t ";;EUSVIEW-DONE~%")
(exit)
