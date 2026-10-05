;; export the robot models of jskeus (~/jskeus/eus/models/*-robot.l, darwin.l) -> robots/jsk/<name>.json
;;   EUSVIEW_ROBOTS="h7 darwin" EUS_TIMEOUT=900 eusview/run-eus.sh eusview/export-jsk.l
;; Each file defines (defun <name> (&rest args) (instance* <name>-robot :init args)) (darwin.l: DARWIN).
;; Physics: the links' :weight is used when the robot has weights (total > 100 g); otherwise the
;; weights are estimated from the volumes of the bodies (*jsk-density* g/cm^3, "estimated": true).
;; The servos get the odedyna default force (fmax 500000, practically unlimited) instead of the
;; KXR servo values, since these robots are much larger.
(defvar *eusview-dir* (or (unix:getenv "EUSVIEW_DIR") (format nil "~A/eusview" (if (boundp '*rcb4eus-dir*) *rcb4eus-dir* (format nil "~A/kxreus" (unix:getenv "HOME"))))))  ;; set by run-eus.sh
(load (format nil "~A/irtload.l" *eusview-dir*))
(load (format nil "~A/eus2json.l" *eusview-dir*))
(load (format nil "~A/eus2physics.l" *eusview-dir*))
(setq *out* (format nil "~A/robots/jsk/" *eusview-dir*))
(unless (probe-file *out*) (unix::mkdir *out*))
(defvar *jsk-density* 1.0) ;; g/cm^3 (assumed; the models have no mass data)
(defvar *jsk-servo*
  (list (cons :fmax (e2p-cdr :fmax *e2p-odedyna-motor*)) (cons :vmax (/ (/ pi 3) 0.13))
        (cons :kp 10.0) (cons :damping 0.0)))
(defvar *jsk-names*
  '("akira" "akira2" "akira3" "ape" "ape3" "bishamon" "chibikaz" "darwin" "h3" "h3s" "h4" "h6" "h7"
    "hanzou" "hanzous" "human" "igoid" "igoid2" "igoid3" "ikuo-haru" "jrob1" "kaz" "kaz2" "kaz3"
    "kuma" "macket" "macra" "miharu" "millennium" "patra" "penguin" "saizo" "tama" "tamaii" "taro"
    "tot" "zero"))

(defun jsk-names-from-env ()
  (let ((s (unix:getenv "EUSVIEW_ROBOTS")) (ret nil))
    (when s
      (with-input-from-string (in s)
        (let (x) (while (setq x (read in nil nil)) (push (string-downcase (string x)) ret)))))
    (nreverse ret)))

(defun jsk-model-file (name)
  (format nil "~A/models/~A.l" (string-right-trim "/" *eusdir*)
          (if (string= name "darwin") "darwin" (format nil "~A-robot" name))))

(defun jsk-export (name)
  (let* ((file (jsk-model-file name)) r links wsum est fname)
    (unless (probe-file file) (format t ";; ~A: no file ~A~%" name file) (return-from jsk-export nil))
    (load file)
    (setq r (funcall (intern (string-upcase name) "USER")))
    (unless (derivedp r robot-model) (format t ";; ~A: not a robot-model: ~A~%" name r)
      (return-from jsk-export nil))
    (setq links (send r :links))
    (setq wsum (apply #'+ (mapcar #'(lambda (l) (let ((w (send l :weight))) (if (numberp w) w 0))) links)))
    (setq est (if (> wsum 100.0) nil *jsk-density*))
    (format t ";; ~A: ~A links, ~A joints, ~A bodies, links' :weight sum ~A g~A~%" name (length links)
            (length (send r :joint-list)) (length (send r :bodies)) wsum
            (if est (format nil " -> estimate from volumes (~A g/cm^3)" est) ""))
    (setq fname (format nil "~A~A.json" *out* name))
    (eus2json r fname :name name :group "jsk"
              :source (format nil "jskeus eus/models/~A (~A)" (pathname-name (pathname file))
                              (string-downcase name))
              :extra (list (cons "physics"
                                 (eus2physics r :servo *jsk-servo* :estimate-density est
                                              :pose (if (find-method r :reset-pose) :reset-pose :init-pose)))))
    t))

(dolist (name (or (jsk-names-from-env) *jsk-names*))
  (jsk-export name))
(format t ";;EUSVIEW-DONE~%")
(exit)
