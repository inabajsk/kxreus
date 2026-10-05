;; export kxreus robots with the motions of their Heart-to-Heart 4 project (RCB4 emulation)
;; and the physical parameters for ODE (eus2physics.l)
;;   eusview/run-eus.sh eusview/export-motions.l                       (default projects)
;;   EUSVIEW_PROJECTS="kxrl4r kxrl6" eusview/run-eus.sh eusview/export-motions.l
;;   EUSVIEW_PROJECTS="kxra6g:kxrl2l2a6h2m" ...   project:robot (robot whose motions to use)
;;   EUSVIEW_PROJECTS="~/prog/rcb4eus/projects/Hello_khr3:khr20h2" ...   project directory (or .h4p) : robot
;;   EUSVIEW_ROBOTS="kxrl2l2a6h2m kxrl4t" ...   robots; project = their :project-file
;; -> robots/<robot>.json (eus2json + "motions" + "physics")
;;
;; How the motions are made (kxreus rcb4machine.l):
;;   ri = (instance rcb4-interface :init robot :create-viewer nil)  ; :setup -> :set-project-file
;;        reads projects/Hello_<project>/*.h4p (rcb4-project-file, motion codes disassembled)
;;   (send ri :emulate-motion-code mc :loopmax N) runs the RCB4 code of the motion
;;   (jumps, calls, servo commands). For every servo command (:servo ids frames servo-vector)
;;   it sets the robot's angle-vector (:servo-vector-to-angle-vector) and, when the robot
;;   has (get robot :ode-ci), calls (send robot :send-ode (* frames 10)) [msec] -- the hook
;;   used by kxrdyna.l. Here :send-ode records the key frame (angle-vector, msec).
;;   unix:usleep is disabled while emulating (the emulator sleeps in real time).
;;   RCB4 moves the servos linearly from the previous to the new position in <frames> x 10 ms,
;;   so the key frames are interpolated linearly and sampled at *em-fps*.
;;   Servos not in the ids of a command keep their position (the disassembler fills them
;;   with 7500 = 0 deg, so the codes are patched to "keep" before emulating); positions
;;   >= #x7fff (free / hold) also keep the position.
(defvar *eusview-dir* (or (unix:getenv "EUSVIEW_DIR") (format nil "~A/eusview" (if (boundp '*rcb4eus-dir*) *rcb4eus-dir* (format nil "~A/kxreus" (unix:getenv "HOME"))))))  ;; set by run-eus.sh
(load (format nil "~A/irtload.l" *eusview-dir*))
(load (format nil "~A/eus2json.l" *eusview-dir*))
(load (format nil "~A/eus2physics.l" *eusview-dir*))
(setq *out* (format nil "~A/robots/" *eusview-dir*))
(load (format nil "~A/kxr-env.l" *eusview-dir*))

(defvar *em-fps* 50)
(defvar *em-max-sec* 30.0)     ;; cut motions that loop (jumps that wait for buttons)
(defvar *em-keys* nil)          ;; ((msec . angle-vector) ...) reversed
(defvar *em-time* 0)            ;; msec
(defvar *em-slept* 0)           ;; usec requested by unix:usleep while emulating
(defvar *em-expected* 0)
(defvar *em-cur-sv* nil)        ;; current servo vector (RCB4 state)
(defvar *em-active* nil)
(defvar *em-truncated* nil)
(defconstant +em-keep+ -1)
(defvar *em-patched* nil)

(setq *em-orig-usleep* (symbol-function 'unix:usleep))
(defun em-usleep-on () (setf (symbol-function 'unix:usleep) *em-orig-usleep*))
(defun em-usleep-off ()
  (setf (symbol-function 'unix:usleep) #'(lambda (us) (setq *em-slept* (+ *em-slept* us)) 0)))

;; key frame hook (kxrdyna.l defines this method to drive the ODE robot)
(defmethod robot-model
  (:send-ode
   (&optional (itime 100) ode)
   (when *em-active*
     ;; timer waits (:mov ... (:timer ..)) between servo commands = hold
     (let ((extra (- *em-slept* *em-expected* (* 1000 itime))))
       (when (> extra 1000)
         (push (cons *em-time* (cdr (car *em-keys*))) *em-keys*)
         (setq *em-time* (+ *em-time* (round (/ extra 1000.0))))
         (push (cons *em-time* (cdr (car *em-keys*))) *em-keys*)))
     (setq *em-time* (+ *em-time* itime))
     (push (cons *em-time* (copy-seq (send self :angle-vector))) *em-keys*)
     (setq *em-expected* (+ *em-slept* (* 1000 itime)))
     (when (> *em-time* (* 1000 *em-max-sec*))
       (setq *em-truncated* t)
       (throw :em-stop nil)))
   t))

;; servo vector -> angle vector with "keep" entries (see header)
(defun em-define-ri-class (cls)
  (let ((sub (intern (format nil "EM-~A" (send cls :name)))))
    (unless (boundp sub)
      (eval `(defclass ,sub :super ,(send cls :name)))
      (eval `(defmethod ,sub
               (:servo-vector-to-angle-vector
                (sv)
                (if (and *em-active* *em-cur-sv*)
                    (let ((m (copy-seq *em-cur-sv*)))
                      (dotimes (i (min (length sv) (length m)))
                        (let ((v (elt sv i)))
                          (unless (or (= v +em-keep+) (>= v #x7fff)) (setf (elt m i) v))))
                      (setq *em-cur-sv* m)
                      (setq servo-vector (copy-seq m)) ;; for single servo commands
                      (send-super :servo-vector-to-angle-vector m))
                  (send-super :servo-vector-to-angle-vector sv))))))
    (symbol-value sub)))

(defun em-patch-codes (mc)
  "servo commands: entries of servos not in the id list -> keep; velocity vectors -> max"
  (unless (memq mc *em-patched*)
    (dolist (a (send mc :acodes))
      (when (and (consp a) (eq (car a) :servo) (listp (elt a 1)) (>= (length a) 4))
        (let* ((ids (elt a 1)) (sv (copy-seq (elt a 3))))
          (dotimes (i (length sv))
            (unless (member i ids) (setf (elt sv i) +em-keep+)))
          (setf (elt a 3) sv)
          (unless (numberp (elt a 2))
            (setf (elt a 2) (let ((mx 0)) (dolist (i ids) (setq mx (max mx (elt (elt a 2) i)))) mx))))))
    ;; timer wait loops "(:sub (:lit 0 128) (:ram (:timer ..)) t) (:jump .. back)": the emulator
    ;; does not count the timer down (it sleeps when the timer is set), so the loop would
    ;; never end -> drop the jump (the wait is recorded as a hold, see :send-ode)
    (let ((prev nil))
      (dolist (a (send mc :acodes))
        (when (consp a)
          (when (and (eq (car a) :jump) prev (eq (car prev) :sub)
                     (consp (elt prev 2)) (eq (car (elt prev 2)) :ram)
                     (consp (cadr (elt prev 2))) (eq (car (cadr (elt prev 2))) :timer))
            (setf (elt a 0) :em-nop))
          (setq prev a))))
    (push mc *em-patched*)))

(defun em-emulate (ri mc start-sv &key (loopmax 3000))
  "key frames ((msec . angle-vector) ...) of motion mc starting from servo vector start-sv"
  (let ((r (send ri :robot)))
    (dolist (m (send ri :project-file :mcodes)) (em-patch-codes m))
    (setq *em-keys* nil *em-time* 0 *em-slept* 0 *em-expected* 0 *em-truncated* nil)
    (setq *em-cur-sv* (copy-seq start-sv))
    (setq *em-active* t)
    (send r :angle-vector (send ri :servo-vector-to-angle-vector (copy-seq start-sv)))
    (push (cons 0 (copy-seq (send r :angle-vector))) *em-keys*)
    (setq *em-expected* 0)
    (setf (get r :ode-ci) t)
    (em-usleep-off)
    (unwind-protect
        (catch :em-stop
          (send ri :emulate-motion-code mc :loopmax loopmax))
      (em-usleep-on)
      (setq *em-active* nil)
      (setf (get r :ode-ci) nil))
    (reverse *em-keys*)))

(defun em-sample (keys fps)
  "linear interpolation of the key frames at fps"
  (let* ((tend (car (car (last keys)))) (n (1+ (ceiling (* tend fps 0.001))))
         (frames nil) (k keys))
    (dotimes (i n)
      (let ((tm (min tend (/ (* 1000.0 i) fps))))
        (while (and (cdr k) (<= (car (cadr k)) tm)) (setq k (cdr k)))
        (cond
         ((null (cdr k)) (push (copy-seq (cdr (car k))) frames))
         (t
          (let* ((t0 (car (car k))) (t1 (car (cadr k)))
                 (a (if (> t1 t0) (/ (- tm t0) (float (- t1 t0))) 1.0)))
            (push (midpoint a (cdr (car k)) (cdr (cadr k))) frames))))))
    (nreverse frames)))

(defun em-json-order (r frames)
  "angle-vector (joint-list order) -> eus2json joints order"
  (let* ((jl (send r :joint-list))
         (idx (mapcar #'(lambda (j) (position j jl)) (remove-if-not #'e2j-joint-type jl))))
    (mapcar #'(lambda (av) (map float-vector #'(lambda (i) (elt av i)) idx)) frames)))

(defun em-mc-name (mc)
  (let ((n (send mc :name))) (if (consp n) (cadr n) (format nil "~A" n))))

(defun em-home-sv (ri)
  "servo vector of the home position motion (else all 7500 = 0 deg)"
  (let* ((sv0 (make-array (send ri :sv-length) :element-type integer-vector :initial-element 7500))
         (home (find-if #'(lambda (mc) (substringp "ホームポジション" (em-mc-name mc)))
                        (send ri :project-file :mcodes))))
    (cond
     (home (em-emulate ri home sv0) (format t ";; home position: ~A~%" (em-mc-name home))
           (coerce *em-cur-sv* integer-vector))
     (t sv0))))

(defun em-project-file (proj)
  "proj: project name (projects/Hello_<proj> of kxreus) or a directory / .h4p path (with a /),
e.g. ~/prog/rcb4eus/projects/Hello_khr3 (read only) for the KHR projects missing in kxreus"
  (cond
   ((and (find #\/ proj) (substringp ".h4p" proj)) proj)
   ((find #\/ proj)
    (let ((f (car (find-files :dir proj :ext "h4p")))) (if (and f (probe-file f)) f)))
   (t (kxr-project-file-name proj (rcb4-robot-project-dir proj)))))

(defun em-short-fname (fn)
  (let ((home (unix:getenv "HOME")))
    (cond
     ((and (> (length fn) (length *rcb4eus-dir*)) (string= *rcb4eus-dir* (subseq fn 0 (length *rcb4eus-dir*))))
      (subseq fn (length *rcb4eus-dir*)))
     ((and home (> (length fn) (length home)) (string= home (subseq fn 0 (length home))))
      (concatenate string "~" (subseq fn (length home))))
     (t fn))))

(defun em-project-robot (proj)
  "robot name for project dir Hello_<proj>: <proj> if it is a robot, else the first robot
whose :project-file is <proj>"
  (cond
   ((kxr-body-config proj) proj)
   (t
    (let ((c (find-if #'(lambda (x) (equal (cadr (assoc :project-file (plist-to-alist (cadr x))))
                                           proj))
                      *kxr-body-config-alist*)))
      (when c (if (atom (car c)) (car c) (car (car c))))))))

(defun em-max-abs (frames jl)
  (let ((mx (instantiate float-vector (length jl))))
    (dolist (f frames) (dotimes (i (length mx)) (setf (elt mx i) (max (elt mx i) (abs (elt f i))))))
    mx))

(defun em-export (robot-name &key proj)
  (let* ((r (kxr-make-robot robot-name :viewer nil :model nil))
         ri pf motions (nf 0) home jl fname)
    (unless r (format t ";; ~A: could not make the robot~%" robot-name) (return-from em-export nil))
    (setq ri (instance (em-define-ri-class (kxr-ri-class robot-name)) :init r :create-viewer nil))
    (when proj ;; load projects/Hello_<proj>/*.h4p (cf. rcb4-interface :set-project-file)
      (let ((fn (em-project-file proj)) p rm)
        (unless (equal fn (and (send ri :project-file) (send ri :project-file :fname)))
          (setq p (instance rcb4-project-file :init ri fn))
          (setq rm (ri . rcb4machine))
          (dolist (mc (send p :mcodes)) (send rm :set-rom-table (send mc :number) mc))
          (send rm :scan-jump-vectors)
          (setq (ri . project-file) p)
          (send ri :trim-vector (send p :trim-vector)))))
    (setq pf (send ri :project-file))
    (unless pf (format t ";; ~A: no project file~%" robot-name) (return-from em-export nil))
    (format t ";; ~A: project ~A, ~A motions~%" robot-name (send pf :fname) (length (send pf :mcodes)))
    (setq jl (remove-if-not #'e2j-joint-type (send r :joint-list)))
    (setq home (em-home-sv ri))
    (dolist (mc (send pf :mcodes))
      (let* ((keys (em-emulate ri mc home)) frames mx big)
        (cond
         ((< (length keys) 2)
          (format t ";;  skip ~A ~A (no servo command)~%" (send mc :number) (em-mc-name mc)))
         (t
          (setq frames (em-json-order r (em-sample keys *em-fps*)))
          (setq mx (em-max-abs frames jl))
          (setq big nil)
          (dotimes (i (length mx))
            (if (> (elt mx i) 20) (push (format nil "~A:~A" (send (elt jl i) :name) (round (elt mx i))) big)))
          (format t ";;  motion ~A ~A: ~A keys, ~A s, ~A frames~A max|deg|>20: ~A~%"
                  (send mc :number) (em-mc-name mc) (length keys) (/ (car (car (last keys))) 1000.0)
                  (length frames) (if *em-truncated* " (truncated)" "") (reverse big))
          (incf nf (length frames))
          (push (list (em-mc-name mc) *em-fps* frames nil nil 1
                      (format nil "\"number\":~a,\"keyframes\":~a~a"
                              (send mc :number) (length keys)
                              (if *em-truncated* ",\"truncated\":true" "")))
                motions)))))
    (setq motions (nreverse motions))
    (send r :angle-vector (send ri :servo-vector-to-angle-vector (copy-seq home)))
    (setq fname (eusview-kxr-json robot-name))
    (eus2json r fname :name robot-name :group (eusview-kxr-group robot-name)
              :source (format nil "kxreus (kxr-make-robot ~S :model nil), motions: RCB4 emulation of ~A"
                              robot-name (em-short-fname (send pf :fname)))
              :motions motions
              :extra-poses (list (cons "home-position" (map float-vector #'(lambda (j) (send j :joint-angle)) jl)))
              :extra (list (cons "physics"
                                 (eus2physics r :rotation-joints (em-rotation-joints ri)))))
    (format t ";; ~A: ~A motions, ~A frames -> ~A~%" robot-name (length motions) nf fname)
    t))

(defun em-rotation-joints (ri)
  "joints of the servos in rotation (wheel) mode"
  (let ((jl (send ri :robot :joint-list)) ret)
    (dolist (sid (append (send ri :wheel-sids) (send ri :rotate-sids)))
      (dolist (ai (send ri :servo-index-to-angle-index sid))
        (if (and (numberp ai) (< ai (length jl))) (pushnew (elt jl ai) ret))))
    (when ret (format t ";; rotation (wheel) joints: ~A~%" (send-all ret :name)))
    ret))

(defun em-names-from-env (var)
  "split $var at spaces; names are downcased, paths (with /) are kept, ~ = $HOME"
  (let ((s (unix:getenv var)) (ret nil) (cur nil))
    (when s
      (dolist (c (append (coerce s cons) (list #\space)))
        (cond
         ((member c '(#\space #\tab #\newline))
          (when cur
            (let ((w (coerce (nreverse cur) string)))
              (if (find #\/ w)
                  (if (= (elt w 0) #\~) (setq w (concatenate string (unix:getenv "HOME") (subseq w 1))))
                (setq w (string-downcase w)))
              (push w ret))
            (setq cur nil)))
         (t (push c cur)))))
    (nreverse ret)))

(let ((robots (em-names-from-env "EUSVIEW_ROBOTS"))
      (projs (or (em-names-from-env "EUSVIEW_PROJECTS")
                 (unless (em-names-from-env "EUSVIEW_ROBOTS")
                   '("kxrl2l2a6h2g" "kxrl2l6a6h2" "kxrl4r" "kxrl4d")))))
  (dolist (rn robots) (em-export rn))
  (dolist (p projs)
    (let* ((c (let ((k nil)) (dotimes (i (length p)) (if (= (elt p i) #\:) (setq k i))) k)) ;; last :
           (proj (if c (subseq p 0 c) p))
           (rn (if c (subseq p (1+ c)) (em-project-robot proj))))
      (format t ";; project ~A -> robot ~A~%" proj rn)
      (if rn (em-export rn :proj proj)
        (format t ";; ~A: no robot for the project~%" proj)))))
(format t ";;EUSVIEW-DONE~%")
(exit)
