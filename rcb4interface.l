;;;
;;;	Serial interface program for rcb4 board
;;;	classes: rcb4-interface
;;;
;;;	2017.1.9 start from khreus.l with rcb4.c
;;;	2017.6.27 met Mr. Kondo and knew KXR products
;;;	2017.7.6  build l2l6l6 model with VRML
;;;	2017.7.20 kxreus.l rename rcb4interface.l to adapt kxr 
;;;	2017.7.31 for kxrl2l6a4 with 1250000 BAUD 33 DOF
;;;	2017.8.10 rcb4.h play_motion number 0 start as same as project-file
;;;	2017.8.18 set *rcb4-dof* 35 for kxrl2l6a6
;;;	2017.8.29 add :draw-real-body
;;;	2017.8.31 ROS talker listener rcb4-arm-free 
;;;	2017.9.1  rcb4-servo-vector waits finishing motion, :walk-demo, :animate-demo
;;;	2017.9.9 add (rcb4-read-servo-offset short-offset)
;;;	2017.9.9 add (rcb4-read-servo-error) through get_servos_three
;;;	2017.9.13 remove chest links from Model and lighter vrml
;;;	2017.9.15 add rcb4$init-angle-vector for read/send-angle-vector, read-error-vector
;;;	2017.9.16 add ri :timer-on, :timer-off in make-rcb4-robot
;;;	2018.1.28 :read-motion-lst motion-table-index
;;;	2018.2.1  :write-motion-lst motion-list motion-table-index
;;;	2018.2.11 (rcb4-convert-lst from-motion-i to-motion-i)
;;;	2018.2.13 reduced eusrcb4.c by rcb4-read rcb4-write
;;;	2018.2.14 use only ftdi.l : no need anymore rcb4.c rcb4_util.c eusrcb4.c and make
;;;	2018.2.15 adpt khr3 for two acc sensors and different sysreg default, using rcb4-set-sysreg-bit
;;;	2018.2.18 (rcb4-write-convert-motion from-i to-i) ;; writes from-i-motion to to-i
;;;	2018.2.20 (rcb4-check-button): read decode wireless remote-controller(KRR-5FH)
;;;	2018.2.20 (rcb4-read-ram-jump-vectors) (rcb4-read-rom-jump-vectors) returns button mapping
;;;	2018.2.24 (rcb4-sysreg) uses *rcb4-sysreg-bits*
;;;	2018.2.26 :emulate-motion-code for :draw-rom-table, :draw-project-file to emulate codes
;;;	2018.2.27 emulate :call instruction  in :emulate-motion-code 
;;;	2018.3.3  add (rcb4-servo-state i) to show servo states on RAM
;;;	2018.3.4  add :write-jump-vector
;;;                     '((:jump-vector 10) (:button :rforward) (:motiontable 20 0 |L#XAB80|))
;;;	2018.3.10 classify, add (rcb4-send-cmd cmd read-size)
;;;	2018.3.11 com-port into rcb4-interface,  add methods to use multiple usb serials
;;;	2018.3.12 update :read to get the first byte of str for no blocking in reading com.
;;;	2018.8.1  add free-vector(size:angle-vector) to rcb4-interface to show free(#x8000)/hold(#xf777)
;;;
;;;	2018.3.20 MAX10 and ARMH7 boards created by Chen
;;;	2018.5.16 Max10 firmware by Shirai 2018.12 balance control by Kimura
;;;	2019.6.13 ARMh7 firmware reading and balancing 2019.6.25
;;;	2019.9.15 ARMh7 flash ROM handling :armh7-rom-to-flash :armh7-flash-to-rom
;;;	2019.12.27 jointbase_sensorboard handling
;;;	2020.1.25 ARMH7 receive 8 bytes after interpolation based sysreg to hand shake
;;;	2020.7.2  kxrextentions for kxrl2l6anzaifly
;;;	2020.10.24 rosrcb4.l teleop through ROS
;;;	2021.1.13 :memory-cstruct from kondoh7.elf
;;;	2021.11.16 :find-stereo-tags with dual m5stickv connected to ARMH7 I2C
;;;	2022.5.2 :serial argument to ftdi-open allows bilateral operations
;;;	2022.5.20 create uart.l for both tty-dev and ftdi :com-init :devname "ttyUSB0"
;;;
;;;	add /etc/udev/rules.d/99-my-khr.rules by
;;;	 sudo bash -c 'echo SUBSYSTEMS==\"usb\", ATTRS{idVendor}==\"165c\", 
;;;            ATTRS{idProduct}==\"0008\", MODE=\"0666\" > /etc/udev/rules.d/99-my-khr.rules'
;;;
;;;	irteusgl rcb4interface.l
;;;
(require :utils)
(require :rcb4asm)
(require :rcb4machine)
(require :tiny-xml)
(require :kxrbody)

(in-package "USER")
(require :uart)

(provide :rcb4interface)

(defclass kxr-rosserial-interface :super propertied-object
  :slots (name
	  ri
	  m5stack-model
	  face-model
          response
          )
  )

;;
;;(unless (boundp '*eusrcb4*)
;;  (setq *eusrcb4* (load-library
;;	(format nil "~A/librcb4eus" (unix:getenv "ARCHDIR")) '("eusrcb4"))))
;;

(defun rcb4-jump-vector-cond (num &aux v res)
  (dotimes (i 8)
    (if (logbitp i num)
	(push (elt #(:z :c :ze :ce :lit :word :jump :eof) i) res)))
  res)

(defun rcb4-encode-jump-vector (lst) ;; lst = (num (:button ....) (mi title))
  (let ((pat #x35) ;; :size :lit :z :z=
	(ram (rcb4-address :button))
	(button-code (rcb4-encode-button-code (assoc :button lst)))
	(addr (rcb4-address (list :motiontable (car (elt lst 2)) 0))) ;; (assoc :motiontable lst)))
	(str (instantiate string 8)))
    (setf (elt str 0) pat)
    (setf (elt str 1) (logand #xff ram))
    (setf (elt str 2) (logand #xff (ash ram -8)))
    (setf (elt str 3) (ash button-code -8))
    (setf (elt str 4) (logand #xff button-code))
    (dotimes (i 3)
      (setf (elt str (+ 5 i)) (logand #xff (ash addr (* -8 i)))))
    (coerce str cons))
  )
(defun rcb4-decode-jump-vector (jvi str)
  (let* ((lst (coerce str cons)) dest v2 adr res v
	 (cond (rcb4-jump-vector-cond (pop lst))))
    (if (member :eof cond)
	(return-from rcb4-decode-jump-vector (list cond)))
    ;;(push (list :jump-vector jvi) res)
    (push jvi res)
    (setq dest (numseq-to-num lst 2))
    (push (if (logbitp 15 dest)
	      (list :ics :no (logand #x7f (cadr lst)) :offset (car lst) )
	    (if (setq v2 (rcb4-symbol dest :ram)) v2
	      (list :ram (format nil "#x~X" dest)))) res)
    (pop lst) (pop lst)
    (cond
     ((member :lit cond)
      (cond
       ((equal (car res) :button)
	(push (cons (pop res)
		    (rcb4-decode-button-code (list (car lst)
						   (cadr lst)))) res))
       (t (push cond res) (push (list :lit (car lst) (cadr lst)) res))))
     (t (setq v (numseq-to-num lst 2))
	(push (if (logbitp 7 v)
		  (list :ics :no (cadr lst) :offset (car lst) )
		(list :ram (format nil "#x~X" v))) res)))
    (pop lst) (pop lst)    
    ;;(push (rcb4-symbol (numseq-to-num lst 3) :rom) res)  ;; (:motiontable ...)
    (push (cdr (rcb4-symbol (numseq-to-num lst 3) :rom)) res)
    (reverse res)))

;;;;; handlers for remote controller button
(defun rcb4-encode-button-code (lst)
  (if (numberp lst) (setq lst (rcb4-decode-button-code lst)))
  (let ((d0 0) (d1 0) v)
    (cond
     ((and (= (length lst) 2) (every #'numberp lst))
      (setq d0 (elt lst 0) d1 (elt lst 1)))
     (t
      (dolist (l lst)
	(if (setq v (position l #(:r-left :l-shift-u  :l-shift-d :r-shift-u :r-shift-d)))
	    (setq d0 (logior d0 (ash 1 v)))))
      (dolist (l lst)
	(if (setq v (position l #(:l-fore :l-back :l-right :l-left :r-fore :r-back :r-right)))
	    (setq d1 (logior d1 (ash 1 v)))))))
    (+ (ash d0 8) d1)))

(defun rcb4-decode-button-code (seq)
  (let (d0 d1 res v)
    (cond
     ((numberp seq)
      (setq d0 (ash seq -8) d1 (logand seq #xff)))
     ((and (>= (length seq) 2) (every #'numberp seq))
      (setq d0 (elt seq 0) d1 (elt seq 1))))
    (dotimes (i 5)
      (if (logbitp i d0)
	  (push (elt #(:r-left :l-shift-u  :l-shift-d :r-shift-u :r-shift-d) i) res)))
    (dotimes (i 7)
      (if (logbitp i d1)
	  (push
	   (elt #(:l-fore :l-back :l-right :l-left :r-fore :r-back :r-right) i)
	   res)))
    (cons (+ (ash d0 8) d1) (cons (list d0 d1) (reverse res)))))

(defun rcb4-command-lst (rom-str)
  (let* ((len (length rom-str)) (i 0) (j len) buf name (in t) code clen cs)
    (while (and in (< i len))
      (cond
       ((= (elt rom-str i) #xff)
	;; reading name string: code ... #xff name #xff format
	(while (and in (< (setq i (1+ i)) len))	
	  (if (= (elt rom-str i) #xff)
	      (setq in nil)
	    (push (elt rom-str i) name)))
	(setq name (coerce (reverse name) string))
	(setq in nil))
       (t
	(setq code (subseq rom-str i (setq j (+ i (elt rom-str i)))))
	(setq clen (length code))
	(setq cs (rcb4-checksum code (1- clen)))
	(when (not (= (elt code (1- clen)) cs))
	  (format t ";; wrong checksum, i=~A, j=~A, codelen=~A, checksum=~A, to be ~A.~%"
		  i j clen (elt code (1- clen)) cs)
	  )
	(push (coerce code cons) buf)))
      (setq i j))
    ;; (reverse (cons (concatenate string (car buf) "ff") (cdr buf)))
    (when (> i len)
      (format t ";; too long, i=~A, len=~A, name=~A, buf=~A~%" i len name (reverse buf)))
    (list (reverse buf) name)))

(defun ri-viewer-update nil
  (if (boundp '*ri*)
      (send *ri* :viewer-update)
    (if (boundp '*robot*) (send (send *robot* :ri) :viewer-update)))
  (x::window-main-one)
  )

(defun ri-update (ri)
  (let (robot vwer)
    ;;(send *irtviewer* :draw-objects :flush t)
    (setq robot (send ri :robot))
    (send ri :set-sysreg-bits '((:rom-on . 0) (:response-on . 0)))
    (send ri :robot :angle-vector (send ri :read-angle-vector))
    (send ri :real-orientation)
    (when (send ri :viewer)
      (setq vwer (send ri :viewer :viewer))
      (send vwer :draw-objects :flush nil)
      #|    
      (send vwer :viewsurface :line-width width)
      (send vwer :viewsurface :color color)
      (send vwer :draw-circle
      (make-coords :pos (send j :child-link :worldpos) :rot rot)
      :radius (* size (abs rtorque)) :arrow t :arc (deg2rad 330))
      |#
      (send robot :draw-torque vwer
	    :torque-vector (send ri :read-torque-vector)
	    :flush nil :size 1.0)
      
      (send ri :set-sysreg-bits '((:rom-on . 1)))
      (send ri :viewer :flush)
      ))
  )

(defun ri-balance-update nil
  (let* ((ri (send *robot* :ri))
	 (vwer ((send ri :viewer) . x::viewer))
	 (robot (send ri :robot))
	 r p-r)
    
    (send *irtviewer* :draw-objects :flush t)
    ;;
    (send ri :set-sysreg-bits '((:rom-on . 0) (:response-on . 0)))
    (send robot :angle-vector (send ri :read-angle-vector))
    (send ri :real-orientation)
    ;;(setq p-r (send ri :gravity-p-r))
    ;;(send ri :real-orientation p-r)
    ;;(send robot :legs :ankle-p :joint-angle (rad2deg (elt p-r 0)))
    ;;(send robot :legs :ankle-r :joint-angle (rad2deg (elt p-r 1)))
    (setq r (robot . rot))
    (setq p-r (car (rpy-angle r)))
    (send robot :legs :ankle-p :joint-angle (rad2deg (elt p-r 0)))
    (send robot :legs :ankle-r :joint-angle (rad2deg (elt p-r 1)))
    (send robot :legs :ankle-w :joint-angle 0)
    (send robot :send-to-ri 20)

    (send ri :set-sysreg-bits '((:rom-on . 1)))
    (send ri :viewer :draw-objects :flush t)
    (send robot :draw-torque (send ri :viewer :viewer)
	  :torque-vector (send ri :read-torque-vector)
	  :flush nil :size 1.0)
    (send ri :viewer :flush)
    ))

(defun rcb4-cmd-operator (op)
  (assocdr op '((:sub . -) (:add . +) (:mul . *) (:div . /)
		(:and . logand) (:or . logior) (:xor . logxor))))

(defclass rcb4-interface :super propertied-object
  :slots (name 
	  (robot :forward (:head :larm :rarm :arms :lleg :rleg :legs :joint-list :links))
	  (com-port :forward (:spin-on :spin-off :m5stack-model :face-model :enable-face-detection))
	  analog-neutral
	  servo-config-list  ;; servo config list of (servo-id method scale offset)
	  rcb4-dof
	  sv-length  ;; length of servo-vector = rcb4-dof
	  av-length  ;; length of angle-vector
	  angle-vector  ;; size = (length joint-list) -- depends to robot
	  free-vector ;; size = (length angle-vector)
	  torque-vector ;; size = (length angle-vector)
	  servo-vector  ;; 36
	  servo-joint-vector  ;; 36 : vector of rotational-joint
	  wheel-sids ;;
	  rotate-sids ;;
	  rotate-config-list ;; list of rotate servo config
	  sensor-board-list ;; list of senser boards
	  trim-vector   ;; 36 real-servo value= servo-vector + trim-vector for non RCBboards
	  servo-sorted-ids  ;; size = (length angle-vector)
	  angle-to-servo-index ;; #(servo-index1 ....) -- angle-vector-size
	  servo-to-angle-index ;; #(angle-index1 ....) -- servo-vector-size
	  actuator-to-joint-matrix  ;; matrix av-length (length servo-sorted-ids)
	  joint-to-actuator-matrix  ;; matrix av-length (length servo-sorted-ids)
	  servo-ary   ;; 36 x 3 words
	  project-file
	  motion-files
	  gravity-method
	  rcb4machine
	  logging-time 
	  codes		;; buffered codes for motion-table
	  control-board ;; :rcb4, :armh7, :max10
	  )
  )

;;(require :armh7interface)

(defun decimal-to-nbyte-binary-string (decimal &key (n 1))
  (let ((buf ""))
    (dotimes (i (* n 8))
      (if (logbitp (- (* n 8) (+ i 1)) decimal)
          (setq buf (concatenate string buf "1"))
        (setq buf (concatenate string buf "0"))
        )
      )
    decimal))

(defun reinterpret-as-nbyte-signed-int (unsigned-int &key (n 1))
  (if (logbitp (- (* n 8) 1) unsigned-int)
      ;; when MSB is 1 <=> unsigned-int < 0
      (* -1 (- (ash 1 (* n 8)) unsigned-int))
    ;; when MSB is 0
    unsigned-int
    ))

(defun button-table nil
  (mapc #'(lambda (x) (print x *error-output*)) (send *ri* :read-jump-vectors))) 
(defun erase-motion-button (mi)
  (mapc #'print (send *ri* :erase-motion-button mi)))
(defun set-motion-button (mi &rest buttons)
  (mapc #'print (send *ri* :set-motion-button mi buttons)))
(defun ram-button-table nil
  (mapc #'print (send *ri* :read-jump-vectors-region :ram)))
(defun rom-button-table nil
  (mapc #'print (send *ri* :read-jump-vectors-region :rom)))
(defun save-button-table nil
  (send *ri* :write-jump-vectors)
  (button-table))
(defun reset-button-table nil
  (send *ri* :write-project-to-rom-table)
  (button-table))

(defconstant deg-to-servovector (/ 4000.0 135))

(defmethod rcb4-interface
  (:generate-motion-files
   (&optional (dir "motions"))
   (dolist (mc (send self :project-file :mcodes))
     (send self :generate-motion-file mc :dir dir)))
  (:generate-motion-file
   (mc &key (fname (send robot :name)) (dir "motions"))
   (let* ((mi (send mc :number))
	  (mfile-name (format nil "~A/~A-~A.motion" dir fname mi)))
     (mkdir-unless dir)
     (with-open-file
      (mf mfile-name :direction :output)
      (write-motion-file-head-line mf robot)
      (send rcb4machine :emulate-motion-code self mc :loopmax 100 :motion-file mf))))
  (:joint-angle-servo-index
   ()
   (mapcar #'(lambda (j) (list (cons (send j :name) (send j :joint-angle))
			       (cons :servo-index (send j :servo-index))))
	   (send robot :joint-list)))
  (:board nil control-board)
  (:setup-cboard
   (&optional board)  ;; bd : :rcb4, :armh7
   (if (and board (member board '(:armh7 :max10 :rcb4 :rcb4-acc-reverse)))
       (setq control-board board))
   (when (find-method robot :setup-cboard)
     (unless (send robot :imu-sensors)
       (send robot :setup-cboard :board control-board))
     ))
  (:read-sensors nil nil)
  (:draw-torque
   (&key (flush t) (size 1.0))
   (send robot :draw-torque (send self :viewer :viewer)
	 :torque-vector (send self :read-torque-vector)
	 :flush flush :size size)
   )
  (:viewer-update
   nil
   ;;(send *irtviewer* :draw-objects :flush t)
   (when
       com-port
     (send self :set-sysreg-bits '((:rom-on . 0) (:response-on . 0)))
     (send self :real-orientation)
     (send self :read-sensors)
     (send robot :angle-vector (send self :read-angle-vector))
     (send self :set-sysreg-bits '((:rom-on . 1)))
     )
   (when (send self :viewer)
     (send self :viewer :viewer :draw-objects :flush nil)
     #|    
     (setq vwer ((send self :viewer) . x::viewer))
     (send vwer :draw-objects :flush nil)
     (send vwer :viewsurface :line-width width)
     (send vwer :viewsurface :color color)
     (send vwer :draw-circle
     (make-coords :pos (send j :child-link :worldpos) :rot rot)
     :radius (* size (abs rtorque)) :arrow t :arc (deg2rad 330))
     |#
     (send self :draw-torque :flush nil :size 1.0)
     (send self :draw-sensors :flush nil)
     (send self :draw-end-coords :flush nil)
     (send self :draw-zmp-coords :flush nil)
     (send self :viewer :viewer :flush)
     ;;(unix::usleep 100000)
     )
   )
  (:draw-sensors (&rest args) nil)
  (:draw-end-coords
   (&key (flush t))
   (send robot :draw-end-coords :viewer (send self :viewer :viewer) :flush flush))
  (:draw-zmp-coords
   (&key (flush t))
   (when
       (and (send self :rleg) (send self :lleg)
	    (send robot :rleg :end-coords)
	    (send robot :lleg :end-coords))
     (let ((rzmp (make-coords :pos (send self :rfoot-zmp)))
	   (re (send robot :rleg :end-coords :copy-worldcoords))
	   (lzmp (make-coords :pos (send self :lfoot-zmp)))
	   (le (send robot :lleg :end-coords :copy-worldcoords)))
       (send (send re :transform rzmp) :draw-on 
	     :viewer (send self :viewer :viewer)
	     :flush nil :size 40 :color #f(1 1 0) :width 2)
       (send (send le :transform lzmp) :draw-on 
	     :viewer (send self :viewer :viewer)
	     :flush nil :size 40 :color #f(1 1 0) :width 2)
       ;;(send self :viewer :viewer :draw-axis (send re :transform rzmp) 50)
       ;;(send self :viewer :viewer :draw-axis (send le :transform lzmp) 50)
       (if flush (send self :viewer :viewer :flush))))
   )
  (:rfoot-zmp () (float-vector 0 0 0))
  (:lfoot-zmp () (float-vector 0 0 0))
  (:sensors-update
   ()
   (when (send self :viewer)
     (send self :viewer :draw-objects :flush nil)
     (send self :read-sensors)
     (send self :draw-sensors :flush nil)
     (send self :viewer :flush))
   )
  ;;
  (:read-button nil (rcb4-decode-button-code (send self :read-str :button :ram 2)))
  (:find-button
   (bnum &optional (jvs (send self :read-jump-vectors))
	 &aux dat mc nm mi)
   (dotimes (i (length jvs))
     (when (eq (car (assocdr :button (elt jvs i))) bnum)
       ;;(setq mi (car (elt (elt jvs i) 2)))
       ;;(setq nm (send project-file :mcodes mi :name))
       (return-from :find-button (elt jvs i)))))
  (:check-button
   nil
   ;;(unless com-port (send self :com-init))
   (send self :jump-vector-off)
   (let* ((jvs (send self :read-jump-vectors)) ;; (pvs (send self :project-jump-vectors))
	  dat jv)
     (do-until-key
      (setq dat (send self :read-button))
      (unix::usleep (* 100 1000))
      (when
	  (> (car dat) 0)
	(if (setq jv (send self :find-button (car dat) jvs))
	    (format t "~A~%" jv)
	  (format t "~A~%" dat))))
     (send self :jump-vector-on)
     ))
  ;;
  (:motion-button
   (mi)
   (dolist (jv (send rcb4machine :list-jump-vectors))
     (let* ((mt (elt jv 2))
	    (bt (assoc :button jv)))
       (if (and jv mt (equal (car mt) mi) bt)
	   (return-from :motion-button (cadr bt)))))
   0)
  (:erase-motion-button
   (mi &optional flash)
   (send rcb4machine :erase-motion-button mi)
   (send self :write-jump-vectors flash)
   )
  (:set-motion-button
   (mi buttons &optional flash)
   (send rcb4machine :set-motion-button mi buttons)
   (send self :write-jump-vectors flash)
   )
;;;
  (:jump-vector-flag (&optional (flag 0))
		     (if (eq flag t) (send self :jump-vector-on)
		       (if (eq flag nil) (send self :jump-vector-off)))
		     (= 1 (assocdr :vector-jump-on (send self :sysreg))))
  (:jump-vector-on nil ;;(unless com-port (send self :com-init))
		   (send self :set-sysreg-bits '((:vector-jump-on . 1))))
  (:jump-vector-off nil ;; (unless com-port (send self :com-init))
		    (send self :set-sysreg-bits '((:vector-jump-on . 0))))
;;;
  (:project-jump-vectors () (send self :list-jump-vectors (send project-file :jump-vectors)))
  (:list-jump-vectors
   (jvs)
   (let (v ret mt nm)
     (dotimes (i (length jvs))
       (when (setq v (elt jvs i))
	 (setq mt (elt v 2))
	 (if (consp (setq nm (send project-file :mcodes (car mt) :name)))
	     (setq nm (cadr nm)))
	 (push (list (car v) (cadr v) (list (car mt) nm)) ret)))
     (reverse ret)))
  (:read-jump-vectors
   ()
   ;;(unless com-port (send self :com-init))
   (send rcb4machine :setup-jump-vectors (send self :read-jump-vectors-region :ram))
   (send rcb4machine :scan-jump-vectors))
  (:read-jump-vector
   (jvi region)
   (let* ((adr 
	   (if (eq region :rom)
	       (+ (rcb4-address :JumpVectorDataRom) (* 8 jvi))
	     (+ (rcb4-address :jump-vector) (* 8 jvi))))
	  (str (send self :read-str adr region 8)))
     ;;(format t "jump-vector ~A=~A~%" jvi (coerce str cons))
     (rcb4-decode-jump-vector jvi str)))
  (:read-jump-vectors-region
   (region) ;; retion= :rom/:ram
   (let ((i 0) res v)
     (setq v (send self :read-jump-vector i region))
     (while (and (< i 32) (not (member :eof (car v))))
       (push v res)
       (setq i (1+ i))
       (setq v (send self :read-jump-vector i region)))
     (reverse res)))
  (:read-ram-jump-vectors nil (send self :list-jump-vectors (send self :read-jump-vectors-region :ram)))
  (:read-rom-jump-vectors nil (send self :list-jump-vectors (send self :read-jump-vectors-region :rom)))
  (:copy-jump-vectors-from-rom-to-ram
   (&optional (flash t))
   (let ((romv (send self :read-jump-vectors-region :rom)) (i 0))
     (dolist (v romv)
       (send self :write-jump-vector-region v :ram)
       (setq i (1+ i)))
     (send self :write-eof-jump-vector-region i :ram)))
  (:copy-jump-vectors-from-ram-to-rom
   (&optional (flash t))
   (let ((romv (send self :read-jump-vectors-region :ram)) (i 0))
     (dolist (v romv)
       (send self :write-jump-vector-region v :rom)
       (setq i (1+ i)))
     (send self :write-eof-jump-vector-region i :rom)))
;;;
  (:write-jump-vector-region
   (lst region)
   (let* ((jvi (car lst)) ;; (cadr (assoc :jump-vector lst)))
	  (adr
	   (if (eq region :rom)
	       (+ (rcb4-address :JumpVectorDataRom) (* 8 jvi))
	     (+ (rcb4-address :jump-vector) (* 8 jvi)))))
     (setq lst (rcb4-encode-jump-vector lst))
     (send self :send-cmd (list :move (cons :lit lst) (list region adr)) 1)))
  (:write-jump-vector
   (lst)
   (send self :write-jump-vector-region lst :rom)
   (send self :write-jump-vector-region lst :ram))
  (:write-jump-vectors-region
   (jvls region)
   (let (jv b mc)
     (dotimes (ji (length jvls))
       (setq jv (elt jvls ji))
       (when (and jv
		  (numberp (car jv)) ;; (assoc :jump-vector jv)
		  (assoc :button jv))
	 (send self :write-jump-vector-region jv region)
	 ))))
  ;;
  (:write-to-flash nil nil)
  (:write-jump-vectors
   (&optional (flash t) (jvls (send rcb4machine :scan-jump-vectors)))
   ;;(unless com-port (send self :com-init))
   (when com-port
     (let ((ji (length jvls)))
       (send self :write-jump-vectors-region jvls :ram)
       (if (> ji 31) (setq ji 31))
       (send self :write-eof-jump-vector-region ji :ram)
       (send self :write-jump-vectors-region jvls :rom)
       (send self :write-eof-jump-vector-region ji :rom)
       (when flash (send self :write-to-flash))
       (send self :read-jump-vectors))))
  ;;
  (:write-eof-jump-vector-region
   (jvi region)
   (let* ((adr
	   (if (eq region :rom)
	       (+ (rcb4-address :JumpVectorDataRom) (* 8 jvi))
	     (+ (rcb4-address :jump-vector) (* 8 jvi))))
	  lst (str (instantiate string 8)))
     (setf (elt str 0) #x80)
     (setq lst (coerce str cons))
     (send self :send-cmd (list :move (cons :lit lst) (list region adr)) 1)))
  (:write-eof-jump-vector
   (jvi)
   (send self :write-eof-jump-vector-region jvi :rom)
   (send self :write-eof-jump-vector-region jvi :ram))
;;;
  (:read-address
   (addr region &optional (size 2))
   (numseq-to-num (send self :read-str addr region size) size))
  ;; #x357=(:read-address #x8c :ram 2)
  ;; #x357=(:read-address #x919 :rom 2)
;;;
  (:call-motion
   (num)
   ;;(unless com-port (send self :com-init))
   (send self :set-sysreg-bits '((:rom-on . 0) (:response-on . 0)))
   (send self :send-cmd `(:call nil (:motiontable ,num)) 1)
   (send self :set-sysreg-bits '((:rom-on . 1) (:response-on . 0))))
  (:call-motion-no-wait
   (num)
   (send self :send-cmd-no-wait `(:call nil (:motiontable ,num)) 1))
  (:jump-motion
   (num)
   ;;(unless com-port (send self :com-init))
   (send self :set-sysreg-bits '((:rom-on . 0) (:response-on . 0)))
   (send self :send-cmd `(:jump nil (:motiontable ,num)) 1)
   (send self :set-sysreg-bits '((:rom-on . 1) (:response-on . 0))))
  (:non-block
   (&optional flag)
   (case flag ((t :on) (setf (get self :non-block) t))
	 (:off (setf (get self :non-block) nil)))
   (get self :non-block))
  (:send-servo-vector-com
   (sv vel &optional (ids servo-sorted-ids))
   (when com-port
     (if logging-time (push (list :servo ids logging-time (copy-seq sv)) codes))
     (unless (send self :non-block)
       (send self :set-sysreg-bits '((:rom-on . 0) (:response-on . 1))))
     ;;(format t ";; send-servo-vector-com ids= ~A, vel=~A, sv=~A~%" ids vel sv)
     (send self :send-cmd `(:servo ,ids ,vel ,sv) 1)
     (unless (send self :non-block)
       (send com-port :read-data)
       (send self :set-sysreg-bits '((:rom-on . 1) (:response-on . 0))))))
  (:send-single-servo
   (sid val vel)
   (send self :set-sysreg-bits '((:rom-on . 0) (:response-on . 1)))
   (send self :send-cmd (list :servo sid vel val) 1)
   (send com-port :read-data)
   (send self :set-sysreg-bits '((:rom-on . 1) (:response-on . 0))))
  (:rom-table (&rest args)
	      ;;(if (null (send (elt (send rcb4machine :rom-table) 0) :bcodes)) 2023.1.21
	      ;;(send self :read-rom-table))
	      (apply #'send rcb4machine (cons :rom-table args)))
  ;;
  (:read-servos-three  ;; inaba
   ()
   (let* (ram (size 126) (offset 2) (len (/ size 2)) (vi 0)
	      i2 i10 str (seg (instantiate float-vector len)))
     (dotimes (j (/ rcb4-dof 7))
       (setq ram (+ #x90 (* 20 (* j 7)) offset))
       (setq str (send self :send-cmd
		       (list :move (list :ram ram size) (list :com)) size))
       (cond
	((= (length str) size)
	 (dotimes (i len)
	   (setq i2 (* 2 i))
	   (setf (elt seg i)
		 (logand #xffff
			 (logior (ash (elt str (1+ i2)) 8)
				 (elt str i2)))))
	 (dotimes (i 7)
	   (setq i10 (* i 10))
	   (setf (elt servo-ary vi) (elt seg i10)) (setq vi (1+ vi))
	   (setf (elt servo-ary vi) (elt seg (1+ i10))) (setq vi (1+ vi))
	   (setf (elt servo-ary vi) (elt seg (+ 2 i10))) (setq vi (1+ vi))
	   ))
	(t (warn "in :read-servos-three, str.len=~A, size=~A, str=<~S>~%" (length str) size str))))
     servo-ary))
  (:read-servo-table
   (idx) ;; idx=0 .. 35
   (let* (ram (size 126) (offset 2) (len (/ size 2)) (vi 0)
	      i2 i10 str (seg (instantiate float-vector len)))
     (dotimes (j (/ rcb4-dof 7))
       (setq ram (+ #x90 (* 20 (* j 7)) offset))
       (setq str (send self :send-cmd
		       (list :move (list :ram ram size) (list :com)) size))
       (cond
	((= (length str) size)
	 (dotimes (i len)
	   (setq i2 (* 2 i))
	   (setf (elt seg i)
		 (logand #xffff
			 (logior (ash (elt str (1+ i2)) 8)
				 (elt str i2)))))
	 (dotimes (i 7)
	   (setq i10 (* i 10))
	   (setf (elt servo-ary vi) (elt seg i10)) (setq vi (1+ vi))
	   (setf (elt servo-ary vi) (elt seg (1+ i10))) (setq vi (1+ vi))
	   (setf (elt servo-ary vi) (elt seg (+ 2 i10))) (setq vi (1+ vi))
	   ))
	(t (warn "in :read-servos-three, str.len=~A, size=~A, str=<~S>~%" (length str) size str))))
     servo-ary))
  (:read-servo-vector
   nil
   (let ((index 1) v)
     (setq servo-vector (make-sequence float-vector sv-length :initial-element 7500))
     (send self :read-servos-three)
     (dotimes (i sv-length) 
       (setq v (elt servo-ary index))
       (when (> v 0.0)
	 (setf (elt servo-vector i) v))
       (setq index (+ index 3))))
   servo-vector)
  (:servo-trim-vector-name
   (&optional (sv servo-vector) (tv trim-vector)
	      &aux res (nmlist (send robot :joint-list :name))
	      avi av)
   (setq av (send self :servo-vector-to-angle-vector sv))
   (dotimes (i sv-length)
     (setq avi (car (elt servo-to-angle-index i)))
     (when avi
       (push
	(list :servo-i i
	      :servo (round (elt sv i))
	      :trim (round (elt tv i))
	      (elt nmlist avi)
	      (round (elt av avi)))
	res)))
   (reverse res))
  (:read-servo-trim-vector-name
   ()
   (send self :servo-trim-vector-name
	 (send self :read-servo-vector)
	 (send self :read-trim-vector)))
  (:read-trim-vector-aux
   (&optional (index 0) (initial 7500)
	      &aux (sv (make-sequence float-vector sv-length :initial-element initial)) v)
   (send self :read-servos-three)
   (dotimes (i sv-length)
     (if (numberp (setq v (elt servo-ary index)))
	 (cond
	   ((= (logand v #x8000) #x8000)  ;; free value
	    ;;(format t ";; 0x8000 bit on in v=~A ~%" v)
	    (setf (elt sv i) (- v #x10000)))
	   (t
	    (setf (elt sv i) (elt servo-ary index)))))
     (setq index (+ index 3)))
   sv)
  (:read-trim-vector nil (send self :trim-vector (send self :read-trim-vector-aux 0 0)))
  (:read-ref-servo-vector nil (send self :read-trim-vector-aux 2))
  (:read-current-servo-vector nil (send self :read-trim-vector-aux 1))
  (:read-servo-connected2 nil (send self :read-trim-vector-aux 1 0))
  (:read-servo-connected
   (&aux (index 1) (initial 0) v ret)
   (send self :read-servos-three)
   (dotimes (i sv-length)
     (if (numberp (setq v (elt servo-ary index)))
	 (if (> v 0)
	     (push i ret)))
     (setq index (+ index 3)))
   (reverse ret))
  (:read-servo-error
   nil
   (let (i3 (sv (instantiate integer-vector rcb4-dof)))
     (send self :read-servos-three)
     (dotimes (i rcb4-dof)
       (setq i3 (* i 3))
       (setf (elt sv i)
	     (if (and (numberp (elt servo-ary (1+ i3)))
		      (numberp (elt servo-ary (+ 2 i3))))
		 (- (elt servo-ary (+ 2 i3)) (elt servo-ary (1+ i3)))
	       0)))
     sv))
;;;
  (:stop-motion () (send self :set-sysreg #x80 #x19))
  (:servo-state
   (sid &optional (region :ram))
   (let ((str (send self :read-str (+ (rcb4-address :servo) (* 20 sid)) region 20))) ;; #x90
     (list :servo (elt str 0) :id (elt str 1) :base (numseq-to-num str 2 2)
	   :real (numseq-to-num str 2 4) :ref  (numseq-to-num str 2 6)
	   :interp-vel (elt str 8) :interp-endpos (numseq-to-num str 2 9)
	   :interp-steps (elt str 11) :interp-width (numseq-to-num str 2 12)
	   :mix1-base (numseq-to-num str 2 14) :mix1-calc (elt str 16)
	   :mix2-base (numseq-to-num str 2 17) :mix1-calc (elt str 19)
	   ))
   )
  (:servo-mixing
   (sid &optional (region :ram))
   (let ((str (send self :read-str (+ (rcb4-address :servo) (* 20 sid)) region 20)))  ;; #x90
     (list :base (numseq-to-num str 2 2)
	   :real (numseq-to-num str 2 4) :ref  (numseq-to-num str 2 6)
	   :mix1-base (numseq-to-num str 2 14) :mix1-calc (elt str 16)
	   :mix2-base (numseq-to-num str 2 17) :mix1-calc (elt str 19)
	   ))
   )
  #|
  (:mixing-states
  nil
  (let (str buf)
  (dolist (sid servo-sorted-ids)
  (setq str (send self :read-str (+ #x90 (* 20 sid)) :ram 20))
  (push
  (list 
  (elt servo-vector-joint sid)
  :id (elt str 1) :base (numseq-to-num str 2 2)
  :real (numseq-to-num str 2 4) :ref  (numseq-to-num str 2 6)
  :mix1-base (numseq-to-num str 2 14) :mix1-calc (elt str 16)
  :mix2-base (numseq-to-num str 2 17) :mix1-calc (elt str 19)
  )
  buf)
  )
  buf)
  )
  |#
  (:read-project-name () (send self :read-str (rcb4-address :projecttitlerom) :rom 32)) ;; #xA1B 
  (:read-mainloop-motion ;; i: 0 or 1
   (&optional (i 0) &aux (base (rcb4-address :mainloop)) (size 9))
   (let ((lst (rcb4-command-lst (send self :read-str (+ base (* i size)) :rom size))))
     (when (car lst) (rcb4-disassemble (car lst)))
     ))
  (:read-priority-motion
   (&optional (i 0) &aux (base (rcb4-address :prioritymotion))) ;; #x45D
   (let ((lst 
	  (rcb4-command-lst (send self :read-str (+ (* i 25) base) :rom 25))))
     (when (car lst)
       (rcb4-disassemble (car lst)))
     ))
  (:read-priority-motions
   ()
   (let ((i 0) m lst)
     (while (setq m (send self :read-priority-motion i))
       (push m lst)
       (setq i (1+ i)))
     (reverse lst)))
  (:read-analog-old
   (&optional (ram (rcb4-address :adref)) (len 11)) ;; #x0c
   (let* ((size (* 4 len))
	  i2 str (ary (instantiate integer-vector len)))
     (setq str (send self :send-cmd `(:move (:ram ,ram ,size) (:com)) size))
     (dotimes (i len) (setq i2 (* 2 i))
	      (setf (elt ary i)
		    (logand #xffff
			    (+
			     (logior (ash (elt str (1+ i2)) 8)
				     (elt str i2))
			     (logior (ash (elt str (+ 23 i2)) 8)
				     (elt str (+ 22 i2)))))))
     ary))
  (:read-analog-old2
   (&optional (ram (rcb4-address :ad)) (len 11)) ;; #x0c
   (let* ((size (* 2 len))
	  i2 str (ary (instantiate integer-vector len)))
     (setq str (send self :send-cmd `(:move (:ram ,ram ,size) (:com)) size))
     (dotimes (i len) (setq i2 (* 2 i))
	      (setf (elt ary i)
		    (logand #xffff
			    (logior (ash (elt str (1+ i2)) 8)
				    (elt str i2)))))
     ary))
  (:read-analog-old1
   (&optional (ram #xc) (len 11))
   (let* ((size (* 4 len))
	  i2 str (ary (instantiate integer-vector len)))
     (setq str (send self :send-cmd `(:move (:ram ,ram ,size) (:com)) size))
     (when (> (length str) 0)
       (dotimes (i len) (setq i2 (+ (* len 2) (* 2 i)))
		(setf (elt ary i) (get-int str i2 2))))
     ary))
  (:read-analog
   (&key (len 11) (ram (+ #xc (* 2 len))))
   (let* ((size (* 2 len))
	  i2 str (ary (instantiate integer-vector len)))
     (setq str (send self :send-cmd `(:move (:ram ,ram ,size) (:com)) size))
     (when (> (length str) 0)
       (dotimes (i len) (setq i2 (* 2 i))
		(setf (elt ary i) (get-int str i2 2))))
     ary))
  (:read-acc (&aux (a (send self :read-analog)))
	     (float-vector (elt a 2) (elt a 3) (elt a 4)))
  (:read-gyro (&aux (a (send self :read-analog)))
	      (float-vector (elt a 5) (elt a 6) (elt a 7)))
  (:init-analog
   nil
   (setq analog-neutral (send self :read-analog))
   (case
    control-board
    (:armh7
     (setq gravity-method :read-gravity))
    (t
     (if (< (elt analog-neutral 5) 4)
	 (setq gravity-method :read-gravity2)
       (setq gravity-method :read-gravity)))))
;;  (:read-gravity nil (send self gravity-method))
  (:read-gravity2
   nil
   (let ((a (send self :read-analog)))
     (float-vector 
      (- (elt analog-neutral 3) (elt a 3)) ;; front-back
      (- (elt analog-neutral 4) (elt a 4)) ;; left-right
      -150)))
  (:battery-voltage
   nil
   (/ (* (elt (send self :read-analog) 0) 25) 1024.0))
  (:read-gravity-old
   nil
   (let ((a (send self :read-analog)) v)
     (cond
      ((or (eq (send robot :type) :l2) (null (send robot :imu-sensor "gsensor")))
       ;;(float-vector (elt a 3) (elt a 4) (elt a 5))
       ;; (elt a 3) y-axis+
       ;; (elt a 4) z-axis-
       ;; (elt a 5) x-axis-
       (setq v (float-vector (- (elt analog-neutral 5) (elt a 5)) ;; 325
			     (- (elt a 3) (elt analog-neutral 3));; 325
			     ;;(- (elt a 4) 375))
			     (- 375 (elt a 4)))
	     ))
      (t ;; :l4 or :l6
       ;;(float-vector (elt a 3) (elt a 4) (elt a 5))
       ;; (elt a 3) y-axis+
       ;; (elt a 4) x-axis-
       ;; (elt a 5) z-axis-
       (setq v (float-vector (- (elt analog-neutral 4) (elt a 4))
			     (- (elt analog-neutral 3) (elt a 3));; 325
			     (- (elt a 5) 375) ;; 325
			     ))))
     v))
  (:read-gravity
   nil
   (let* ((a (send self :read-analog))
	  (c (make-cascoords))
	  v)
     (case
      (send robot :type)
      (:l2
       (cond
	((substringp "makabe" (send robot :name))
	 (setq v (float-vector   (- (elt analog-neutral 3) (elt a 3))
				 (- 375 (elt a 4))
				 (- (elt a 5) (elt analog-neutral 5))))
	 (send c :rotate pi/2 :y)
	 (send c :rotate (- pi/2) :x))
	((eq control-board :rcb4-acc-reverse)
	 (setq v (float-vector (- (elt a 3) (elt analog-neutral 3))
			       (- (elt a 4) 375)
			       (- (elt a 5) (elt analog-neutral 5))))
	 (send c :rotate (- pi/2) :y)
	 (send c :rotate pi/2 :z)
	 (send c :rotate pi :x))
	(t
	 (setq v (float-vector (- (elt a 3) (elt analog-neutral 3))
			       (- (elt a 4) 375)
			       (- (elt a 5) (elt analog-neutral 5))))
	 (send c :rotate (- pi/2) :y)
	 (send c :rotate pi/2 :z))))
      (:l4
       (setq v (float-vector (- (elt a 4) (elt analog-neutral 4))
			     (- (elt analog-neutral 3) (elt a 3)) 
			     (- (elt a 5) 375)))
       ;;(send c :rotate pi :z)
       )
      (:l6
       (setq v (float-vector (- (elt a 4) (elt analog-neutral 4))
			     (- (elt analog-neutral 3) (elt a 3))  
			     (- (elt a 5) 375)))
       (send c :rotate pi :z)
       )
      )
     (send c :rotate-vector v)))
  (:av-length nil av-length)
  (:sv-length nil sv-length)
  ;;
  (:reload-project-file
   (&optional (name-str (send robot :config-name)))
   (send self :set-project-file name-str))
  (:setup
   (&optional create-viewer)
   (let* ((name-str (send robot :config-name))
	  (pdir (rcb4-robot-project-dir name-str))
	  (conf (kxr-body-config name-str))
	  (board (assoc :board (plist-to-alist (cadr conf)))))
     (send self :setup-vectors robot create-viewer)
     (send self :config conf)
     (send self :set-device-config)
     (send self :set-project-file)
     (send self :init-trim-vector)
     (send robot :set-ri self)
     (send self :set-motion-files pdir)
     (if board (setq control-board (cadr board))
       (setq control-board :armh7))
     (send self :setup-cboard control-board)
     self))
  (:setup-vectors
   (robo &optional create-viewer)
   (setq robot robo)
   (setq name (send robot :config-name))
   (if (null name) (error ";; robot name becomes nil, robot=~A~%" robot))
   (unless rcb4machine (setq rcb4machine (instance rcb4-machine :init)))
   (send rcb4machine :set-robot robot)
   (if (send rcb4machine :viewer)
       (send rcb4machine :create-viewer :viewer (send rcb4machine :viewer))
     (if create-viewer (send rcb4machine :create-viewer)))
   (setq av-length (length (send robot :angle-vector)))
   (setq free-vector (make-sequence vector av-length :initial-element t))
   (setq servo-vector 
	 (make-array sv-length :element-type float-vector :initial-element 7500))
   (setq servo-joint-vector (instantiate vector sv-length))
   (setq trim-vector (make-array sv-length :element-type float-vector
				 :initial-element 0))
   (setq angle-vector (instantiate float-vector av-length))
   (setq torque-vector (instantiate float-vector sv-length))
   
   (setq joint-to-actuator-matrix (make-matrix (1+ sv-length) (1+ av-length)))
   (dotimes (i sv-length)
     (setf (aref joint-to-actuator-matrix i av-length) 7500.0))
   (setf (aref joint-to-actuator-matrix sv-length av-length) 1.0)
   (setq actuator-to-joint-matrix (make-matrix (1+ av-length) (1+ sv-length)))
   
   (dotimes (i av-length)
     (setf (aref actuator-to-joint-matrix i sv-length) -250.0))
   (setf (aref actuator-to-joint-matrix av-length sv-length) 1.0)
   
   (setq angle-to-servo-index (instantiate vector av-length))
   (setq servo-to-angle-index (instantiate vector sv-length))
   ;;
   (setq servo-ary (instantiate integer-vector (* 3 rcb4-dof)))
   )
  ;; rcb4-interface
  (:init (&optional robo-or-str &key (create-viewer (xwindow-ready?)) (sv-len *rcb4-dof*) (model t) head)
	 (setq rcb4-dof *rcb4-dof*)
	 (setq sv-length sv-len)
	 (when robo-or-str
	   (send self :create-robot robo-or-str :create-viewer create-viewer :model model
		 :head head))
	 self)
  ;;
  (:create-robot
   (robo-or-str &key (create-viewer (xwindow-ready?)) (model t) head)
   (if (derivedp robo-or-str robot-model)
       (setq robot robo-or-str)
     (setq robot (kxr-create-robot robo-or-str :model model :head head)))
   (when robot (send self :setup create-viewer))
   #|
   (when (and create-viewer
	      (boundp '*irtviewer*) (send *irtviewer* :objects)
	      (setq robo-or-str (kxr-create-robot robo-or-str :model model :head head)))
     (send *irtviewer* :objects (list robo-or-str))
     (send *irtviewer* :draw-objects))
   |#
   )
  (:create-viewer (&rest args)
		  (send* rcb4machine :create-viewer args))
  (:viewer (&rest args) (forward-message-to (send rcb4machine :viewer) args))
  ;;
  (:robot (&rest args) (forward-message-to robot args))
  (:set-robot (r) (setq robot r))
  (:angle-alist
   (al &optional (msec 1000) controller)
   (send robot :angle-alist al)
   (send self :angle-vector (send robot :angle-vector) msec controller))
  (:angle-vector
   (&optional av (msec 1000) controller)
   (when av
     (setq angle-vector av)
     ;;(send self :angle-vector-to-servo-vector angle-vector nil servo-vector)
     ;;(setq servo-vector (send self :angle-vector-to-servo-vector angle-vector nil servo-vector))
     (setq servo-vector (send self :angle-vector-to-servo-vector angle-vector))
     (setq msec (round (/ msec 10)))
     (let ((sids (send self :limbs-sorted-sids controller)))
       (dolist (wheel-sid wheel-sids)
         (setq sids (remove wheel-sid sids)))
       (dolist (rotate-sid rotate-sids)
         (setq sids (remove rotate-sid sids)))
       (cond ((not (send self :rotate-config-list))
	      (setq angle-vector (send self :send-servo-vector (if (>= msec 255) 255 msec) sids)))
	     (t
	      (setq angle-vector (send self :rotate-angle-vector av (if (>= msec 255) 255 msec) t))
	      )
	     )
       )
     angle-vector))
  (:wheel-sids nil wheel-sids)
  (:rotate-sids nil rotate-sids)
  (:wheel-angle-vector
   (&optional av (msec 1000) controller)
   (when av
     (setq angle-vector av)
     ;;(send self :angle-vector-to-servo-vector angle-vector nil servo-vector)
     ;;(setq servo-vector (send self :angle-vector-to-servo-vector angle-vector nil servo-vector))
     (setq servo-vector (send self :angle-vector-to-servo-vector angle-vector))
     (setq msec (round (/ msec 10)))
     (send self :send-servo-vector (if (>= msec 255) 255 msec)
	         wheel-sids)
     angle-vector))
  (:wheel-stop
   (&optional (time 100) (sv (make-sequence integer-vector 36 :initial-element 7500)))
   (send self :send-servo-vector-com sv time wheel-sids)   
   )
  (:wheel-stop-old
   (&optional (time 100))
   (when (send robot :rleg-ankle-w :servo-index)
     (send self :move-joint :rleg-ankle-w 0 time)
     (unix::usleep 100000)
     (send self :move-joint :lleg-ankle-w 0 time))
   (unix::usleep 100000)
   (when (send robot :rleg-crotch-w :servo-index)
     (send self :move-joint :rleg-crotch-w 0 time)
     (unix::usleep 100000)
     (send self :move-joint :lleg-crotch-w 0 time))
   )
  (:send-rotate-sids
   (&optional av (frame 100) (normal nil) controller)
   (when av
     (setq angle-vector av)
     (setq servo-vector (send self :angle-vector-to-servo-vector angle-vector))
     (cond (normal
	    (let ((sids (send self :limbs-sorted-sids controller)))
	      (dolist (wheel-sid wheel-sids)
		(setq sids (remove wheel-sid sids)))
	      (send self :send-servo-vector (if (>= frame 255) 255 frame) sids)
	      ))
	   (t (send self :send-servo-vector (if (>= frame 255) 255 frame) rotate-sids)))
     angle-vector))
  (:rotate-angle-vector
   (&optional av (msec 1000) (normal nil) (debug nil) (timeout 10000) (thleshold 30) controller)
   (let ((rotate-config-lst (send self :rotate-config-list))
	 (config-num)
	 (count 0)
	 (config-lst)
	 (deg)
	 (joint)
	 (th)
	 (start-time)
	 (count-time)
	 (angle-vector)
	 (initial-angle-vector)
	 (servo-vector)
	 (sign)
	 (offset)
	 )
     (when av
       (when (numberp thleshold) (setq th thleshold))
       (setq initial-angle-vector (send self :robot :angle-vector))
       (send self :robot :angle-vector av)
       (when rotate-config-lst
	 (setq config-num (length rotate-config-lst))
	 (while (< count config-num)
	   (setq config-lst (elt rotate-config-lst count))
	   (setq joint (elt config-lst 1))
	   (setq sign (elt config-lst 2))
	   (setq offset (elt config-lst 3))
	   (setq deg (* (+ (send self :robot joint :joint-angle) offset) sign))
	   (when debug
	     (format t "before sending~%")
	     (format t "move_state:~A ~%" (assocdr 'move_state (send self :cls-alist wormmodule-vector-cstruct count)))
	     (format t "count:~A, deg:~A, th:~A, joint:~A~%" count deg th joint)
	     )
	   (send self :send-worm-angle-and-thleshold :worm-idx count :angle deg :thleshold th :print debug)
	   (send self :robot joint :joint-angle 135)
	   (when debug
	     (format t "after sending~%")
	     (format t "move_state:~A ~%" (assocdr 'move_state (send self :cls-alist wormmodule-vector-cstruct count)))
	     )
	   (inc count)
	   )

	 (when normal
	   (send self :non-block :on)
	   )
	 (send self :send-rotate-sids (send self :robot :angle-vector) msec normal)
	 
	 (setq count 0)
	 (when debug
	   (while (< count config-num)
	     (format t "before while loop~%")
	     (setq move_state (assocdr 'move_state (send self :cls-alist wormmodule-vector-cstruct count)))
	     (format t "move_state:~A ~%" move_state)
	     (format t "thleshold:~A~%" (assocdr 'thleshold (send self :cls-alist wormmodule-vector-cstruct count)))
	     (inc count)
	     )
	   )
	 (setq start-time (unix:localtime))
	 (setq count-time (calc-sec start-time (unix:localtime)))
	 (setq move_state (assocdr 'move_state (send self :cls-alist wormmodule-vector-cstruct count)))
	 (while (and (not (= move_state 2)) (< count-time (round (/ timeout 1000))));;todo: add timeout function for multiple servos
	   (setq count-time (calc-sec start-time (unix:localtime)))
	   (setq count 0)
	   (setq move_state (assocdr 'move_state (send self :cls-alist wormmodule-vector-cstruct count)))
	   (when debug
	     (while (< count config-num)
	       (format t "move_state:~A ~%" move_state)
	       (format t "magenc_error:~A ~%" (assocdr 'magenc_error (send self :cls-alist wormmodule-vector-cstruct count)))
	       (inc count)
	       )
	     )
	   )
	 (when normal
	   (send self :non-block :off)
	   )
	 )
       (send self :robot :angle-vector initial-angle-vector)
       (when debug
	 (format t "initial-angle-vector:~A~%" initial-angle-vector)
	 )
       initial-angle-vector)
     )
   )
  (:angle-plist
   (&optional plist (msec 1000))
   (send* robot :angle-plist plist)
   (send self :angle-vector (send robot :angle-vector) msec)
   )
  (:pose-methods
   (methods &optional (msec 1000))
   (send self :read-angle-vector)
   (dolist (m methods) (send* robot m))
   (send self :angle-vector (send robot :angle-vector) msec))
  (:angle-vector1 (&optional (av angle-vector)
			     &aux (av1 (make-sequence float-vector (1+ av-length)
						      :initial-element 1.0)))
		  (replace av1 av) av1)
  (:servo-vector (&optional sv) (if sv (setq servo-vector sv)) servo-vector)
  (:servo-vector1 (&optional (sv servo-vector)
			     &aux (sv1 (make-sequence float-vector (1+ sv-length)
						      :initial-element 1.0)))
		  (replace sv1 sv)
		  sv1)
  (:trim-vector (&optional sv) (if sv (setq trim-vector sv)) trim-vector)
  (:pop-servo-command () (pop codes))
  (:logging-time nil logging-time)
  (:start-logging (&optional (tm 10)) (setq logging-time tm) (send self :flush-codes))
  (:stop-logging () (setq logging-time nil))
  (:write-logging (mi &optional exec) (when codes (send self :write-codes-to-motion-table mi))
		  (when exec (send self :call-motion mi)))
  (:push-servo-command
   (&optional (av (send robot :angle-vector)) (time 100) (ids servo-sorted-ids) &aux sv fm)
   (setq angle-vector av)
   ;;(setq sv (send self :angle-vector-to-servo-vector av nil sv))
   (setq sv (copy-seq (send self :angle-vector-to-servo-vector av)))
   (setq fm (round (/ time 10)))
   (if (> 255 fm) 255 fm)
   (push (list :servo ids fm sv) codes))
  (:push-angle-plist-codes
   (&optional (plist (send robot :angle-plist)) (time 100) limbs)   
   (send* robot :angle-plist plist)
   (send self :push-angle-vector-codes (send robot :angle-vector) time limbs)
   )
  (:angle-plist-sorted-sids
   (plist)
   (if (eq (car plist) :angle-plist) (pop plist))
   (sort (remove-duplicates
	  (flatten (mapcar #'(lambda (j) (send robot j :servo-index))
			   (remove-if-not #'keywordp plist))))
	 #'<))
  (:push-angle-vector-codes
   (&optional (av (send robot :angle-vector)) (time 100) limbs)
   (send self :push-servo-command av time (send self :limbs-sorted-sids limbs)))
  (:write-codes-to-motion-table
   (mi &key (flush t) recover (name (format nil "(Generated ~A)" mi)))
   (if recover
       (push `(:call nil (:motiontable ,recover)) codes))
   (push '(:return) codes)
   ;;(print (reverse codes))
   (prog1 (send self :write-motion-lst (rcb4-assemble (reverse codes) mi) mi name)
     (send self :flush-codes flush))
   )
  (:flush-codes (&optional (flush t)) (if flush (setq codes nil)))
  (:write-return-motion
   (i)
   (send self :write-motion-lst
	 (rcb4-assemble '((:return)) i)
	 i
	 (format nil "(ROM ~A)" (string i))))
  (:reset-rom-table
   nil
   (dotimes (i 120) (send self :write-return-motion i)))
  (:write-motion-lst-old ;; bug over 128
   (lst motion-i &optional name)
   ;;(unless com-port (send self :com-init))
   (if (null name) (setq name (format nil "(ROM ~A)" motion-i)))
   (let ((base (rcb4-address (list :motiontable motion-i 0)))
	 (addr 0) res (i 0) cmd)
     (dolist (l lst)
       (setq cmd (list :move (cons :lit l) (list :rom (+ addr base))))
       (format t ";;~A: addr=~A :write-motion-lst l=~%~A~%" i (+ base addr)
	       (rcb4-assemble-one cmd))
       (send self :send-cmd cmd 1)
       ;;(print (list addr l))
       (unless (= (length l) (elt l 0))
	 (format t ";; wrong (length l) =~A , (elt l 0)=~A~%" (length l) (elt l 0)))
       (setq res (send self :read-lst (+ base addr) (length l)))
       (unless (equal l res)
	 (format t ";;~A: addr=~A :write-motion-lst l=~%~A res =~%~A~%" i addr l res))
       (setq i (1+ i))
       (setq addr (+ addr (elt l 0))))
     (send self :send-cmd
	   (list :move
		 (append '(:lit #xFF) (coerce (string name) cons) '(#xFF))
		 (list :rom addr)) 1)
     ))
  (:write-motion-lst
   (lst motion-i &optional name)
   ;;(unless com-port (send self :com-init))
   (if (null name) (setq name (format nil "(ROM ~A)" motion-i)))
   (let* ((base (rcb4-address (list :motiontable motion-i 0)))
	  (addr base) res (i 0) cmd n a7 l)
     (dolist (l lst)
       (setq n (length l))
       (setq a7 (logand addr #x7f))
       (cond
	((> (+ a7 n) 128 a7)
	 (setq cmd (list :move (cons :lit (subseq l 0 (- 128 a7))) (list :rom addr)))
	 (send self :send-cmd cmd 1)
	 ;;(format t ";;cmd1 = ~A~%" (rcb4-assemble-one cmd))
	 (setq cmd (list :move (cons :lit (subseq l (- 128 a7)))
			 (list :rom (+ addr (- 128 a7)))))
	 ;;(format t ";;cmd2 = ~A~%" (rcb4-assemble-one cmd))
	 (send self :send-cmd cmd 1))
	(t
	 (setq cmd (list :move (cons :lit l) (list :rom addr)))
	 (send self :send-cmd cmd 1)))
       (unless (= (length l) (elt l 0))
	 (format t ";; wrong (length l) =~A , (elt l 0)=~A~%" (length l) (elt l 0)))
       (setq res (send self :read-lst addr (length l)))
       (unless (equal l res)
	 (format t ";;~A: addr=~A :write-motion-lst l=~%~A res =~%~A~%" i addr l res))
       (setq i (1+ i))
       (setq addr (+ addr n)))
     ;;
     (setq a7 (logand addr #x7f))
     (setq n (+ 2 (length (string name))))
     (setq l (append '(#xFF) (coerce (string name) cons) '(#xFF)))
     (cond
      ((> (+ a7 n) 128 a7)
       (setq cmd (list :move (cons :lit (subseq l 0 (- 128 a7))) (list :rom addr)))
       (send self :send-cmd cmd 1)
       ;;(format t ";;cmd1 = ~A~%" (rcb4-assemble-one cmd))
       (setq cmd (list :move (cons :lit (subseq l (- 128 a7)))
		       (list :rom (+ addr (- 128 a7)))))
       ;;(format t ";;cmd2 = ~A~%" (rcb4-assemble-one cmd))
       (send self :send-cmd cmd 1))
      (t
       (setq cmd (list :move (cons :lit l) (list :rom addr)))
       (send self :send-cmd cmd 1)))
     ;; 2020.2.13
     (send self :read-rom-table motion-i)
     ))
  (:convert-lst
   (from-i to-i &key limbs (time-scale 1.0))
   (let ((lst-name (send self :read-motion-lst from-i))
	 (si-list  (send self :limbs-sorted-sids limbs)))
     (list (rcb4-assemble (rcb4-disassemble (car lst-name) from-i) to-i si-list time-scale)
	   (cadr lst-name))))
  (:write-convert-motion
   (from-i to-i &key limbs (time-scale 1.0))
   (let ((lst-name (send self :convert-lst from-i to-i :limbs limbs :time-scale time-scale)))
     (send self :write-motion-lst (car lst-name) to-i (format nil "(~A ~A :time- ~A from ~A)" to-i limbs time-scale (cadr lst-name)))))
  ;;
  (:generate-formed-acodes
   (mc &optional servo-mapping) ;; servo-mapping=((sid_0 sid_i) .. (sid_n sdi_j))
   (let* ((b (mc . bcodes))
	  (acodes (rcb4-disassemble b (mc . number)))
	  sids vel sv ret)
     (dolist (ac acodes)
       (cond
	((atom ac) (push ac ret))
	((memq (car ac) '(:stretch :speed))
	 (cond
	  ((set-difference (cadr ac) servo-sorted-ids)
	   ;; (format t ";; generate-formed-mc num=~A ~A sids=~A~%" (mc . number) (car ac) (cadr ac))
	   (push (cons (car ac) (cons (sort (intersection (cadr ac) servo-sorted-ids) #'<) (cddr ac))) ret))
	  (t (push ac ret))))
	((memq (car ac) '(:servo :s-s :m-s-cv :m-s-mv :m-ss))
	 (cond
	  (servo-mapping
	   (let* ((sids (elt ac 1))
		  (frames (elt ac 2))
		  (vals (elt ac 3))
		  v ss
		  (iv (make-sequence integer-vector (length vals) :initial-element 7500)))
	     (dotimes (i (length sids))
	       (cond
		((setq v (assoc (elt sids i) servo-mapping))
		 (setf (elt iv (cadr v)) (elt vals (elt sids i)))
		 (push (cadr v) ss))
		(t
		 (setf (elt iv (elt sids i)) (elt vals (elt sids i)))
		 (push (elt sids i) ss))))
	     (setq ss (sort ss #'<))
	     (setq ac (list (car ac) ss frames iv))
	     (format t ";; num=~A ss=~A servo-mapping=~A~% vals=~A~% ac=~A~%" (mc . number) ss servo-mapping vals ac)
	     (push ac ret)
	     ))
	  ((not (equal (cadr ac) servo-sorted-ids))
	   (format t ";; generate-formed-mc num=~A ~A sids=~A (cddr ac)=~A~%" (mc . number) (car ac) (cadr ac) (cddr ac))
	   ;;(push (cons (car ac) (cons servo-sorted-ids (cddr ac))) ret)
	   (push (cons (car ac) (cons (cadr ac) (cddr ac))) ret)
	   )
	  (t
	   (push (cons (car ac) (cons (cadr ac) (cddr ac))) ret)
	   ;;(push ac ret)
	   )))
	((memq (car ac) '(:jump :call))
	 (cond
	  ((atom (caddr ac))) ;; address should be a label
	  ((eq (car (caddr ac)) :motiontable)
	   (unless (= (elt (caddr ac) 2) 0) ;; not head of motion code
	     ;;(format t ";; generate-formed-mc num=~A addr=~A~%" (mc . number) (caddr ac))
	     )
	   ))
	 (push ac ret))
	(t (push ac ret))))
     (reverse ret)))
  (:write-motion-code
   (mc to-i &optional servo-mapping)
   (let ((acodes (send self :generate-formed-acodes mc servo-mapping))
	 (nm (mc . name)))
     (send self :write-motion-lst
	   (rcb4-assemble acodes to-i) to-i
	   (cond
	    ((stringp nm) nm)
	    ((and (consp nm) (cadr nm) (stringp (cadr nm)))
	     (cadr nm))))))
  (:write-project-to-rom-table
   (&optional (flash t) servo-mapping)
   ;;(unless com-port (send self :com-init))
   (dolist (mc (send project-file :mcodes))
     (format t "~A " (mc . number)) (finish-output t)
     (send rcb4machine :set-rom-table (send mc :number) mc)
     (send rcb4machine :scan-jump-vectors)
     (send self :write-motion-code mc (mc . number) servo-mapping)
     )
   (send self :write-jump-vectors flash))
  (:generate-formed-motion-code
   (mc &optional (to-i (mc . number)) servo-mapping)
   (instance rcb4-motion-code :init
	     (mc . name)
	     (rcb4-assemble (send self :generate-formed-acodes mc servo-mapping) to-i)
	     to-i (car (mc . buttondata))))
  (:servo-sorted-ids () servo-sorted-ids)
  ;;(:servo-vector-method nil servo-vector-method)
  (:init-trim-vector
   nil
   (if project-file
       (setq trim-vector (send project-file :trim-vector))
     (setq trim-vector (make-array sv-length :element-type float-vector :initial-element 0)))
   (send self :set-device-config)
   )
  (:reload-config
   ()
   (let ((*rcb4robotconfig-debug-message* nil))
     (load "rcb4robotconfig.l"))
   (send self :config (kxr-find-config-by-name (send robot :name)))
   (send self :set-project-file)
   (send self :set-device-config)
   t)
  (:config (&optional conf)
	   (if conf (setf (get self :config) conf))
	   (get self :config))
  (:device-config-list
   nil
   (let* ((config (send self :config))
	  (model-params (cadr config))
	  (alist (plist-to-alist model-params))
	  (roboset (assoc :robotset alist))
	  rset nameset devlist)
     (cond
      (roboset
       (setq rset (cadr roboset))
       (push (pop rset) nameset)
       (dolist (nm rset) (setq nameset (append (cdr nm) nameset)))
       (setq devlist
	     (apply #'append
		    (mapcar #'(lambda (nm)
				(let ((conf (kxr-find-config-by-name nm)))
				  (if conf (cddr conf) nil)))
			    nameset))))
      (t (cddr (send self :config))))))
  (:set-device-config
   (&optional (cf (send self :device-config-list)))
   ";; cf: list of (ICS-id-number :joint-name/:board-name scale offset)"
   (let (res m slen)
     (send self :set-angle-vector-joint)
     (setq servo-config-list nil)
     (mapc #'(lambda (ls)
	       (let* ((l ls)
		      (no (pop l)) (joint-name (pop l)) ;; joint-name ("larm" "palm" "gripper-"))
		      (flag (pop l)) (offset (pop l)) (servo-type (pop l))
		      (kjs-idx (pop l)) (magenc-offset (pop l)) (upper-limit (pop l)))
		 (when joint-name
		   (cond
		    ((< no rcb4-dof)
		     (push ls servo-config-list)
		     (send self :set-servo-vector-joint no joint-name flag offset servo-type kjs-idx magenc-offset upper-limit))
		    (t (send self :set-sensor-board-list no joint-name)))))) ;; was (/ no 2) 2023.2.11
	   cf)
     (setq servo-sorted-ids
	   (sort (remove-duplicates (mapcar #'car servo-config-list)) #'<))
     ;;
     (setf (aref joint-to-actuator-matrix sv-length av-length) 1.0)
     ;;
     (setq actuator-to-joint-matrix (pseudo-inverse joint-to-actuator-matrix))
     (if (send self :rotate-config-list) (setq rotate-config-list (reverse rotate-config-list)))
     trim-vector))
  (:servo-config-list () servo-config-list)
  (:sensor-board-list () sensor-board-list)
  (:check-body-tree ;; to check sensor-board-list
   (&optional (limb :larm))
   (mapcar #'(lambda (bs)
	       (mapcar #'(lambda (b) (cons (send b :name) (send (send b :parent) :name)))
		       bs))
	   (send-all (send robot limb :links) :bodies)))
  (:kjs-sensors
   nil
   (let ((kjss (send robot :kjs-sensors)) b bb)
     (when (not (derivedp (car kjss) body))
       (dolist (kjs kjss)
	 (cond
	   ((substringp "KJS-01" (send kjs :name))
	    (setq b (kxr-sensor-joint-base-a)))
	   ((substringp "KJS-02" (send kjs :name))
	    (setq b (kxr-sensor-joint-base-b)))
	   ((substringp "KJS-03" (send kjs :name))
	    (setq b (kxr-sensor-joint-base-c))))
	 (send b :name (send kjs :name))
	 ;;(format t ";; kjs=~A~%" kjs)
	 (send b :move-to kjs (send kjs :parent))
	 (send (send kjs :parent) :assoc b)
	 ;;(format t ";; b=~A~%" b)
	 (push b bb)
	 )
       (setq kjss (reverse bb))
       (setf (get robot :kjs-sensors) kjss)
       )
     kjss))
  (:set-sensor-board-list
   (id nm)
   (let* ((kjss (send self :kjs-sensors))
	  kjs b)
     (cond
       ((atom nm)
	(setq kjs (find-if 
		   #'(lambda (x)
		       (equal (read-from-string (send x :name)) nm))
		   kjss))
	(unless
	    (derivedp kjs body)
	  (format t ";; kjs=~A is not body kjss=~A~%" kjs kjss)
	  (return-from :set-sensor-board-list)
	  )
	(push (cons id kjs) sensor-board-list)
	(setf (get kjs :sensor-board-id) id)
	(send kjs :set-color :blue)
	)
       (t
	(let* ((bb (send robot :bodies)))
	  (dolist (b bb)
	    (let ((n (send b :name))
		  (pn (string (send (send b :parent) :name)))
		  (ppn (string (send (send (send b :parent) :parent) :name))))
	      (when
		  (every #'(lambda (x) (or
					(substringp x n)
					(substringp x pn)
					(substringp x ppn)
					))
			 nm)
		(send b :set-color :blue)
		(push (cons id b) sensor-board-list)
		(setf (get b :sensor-board-id) id)
		)
	      ))
	  ))
       )))
  (:joint-method-names nil (send robot :joint-list :joint-method-name))
  ;;
  (:trim (jname)
	 (let* ((sis (send robot jname :servo-index))
		(tv (send self :read-trim-vector)))
	   (elt tv (car sis))))
  (:diff-trim
   (jname)
   (let* ((sis (send robot jname :servo-index))
	  (cv (send self :read-servo-vector)))
     (round (- (elt cv (car sis)) 7500))))
  (:new-trim
   (jname)
   (round (+ (send self :trim jname) (send self :diff-trim jname))))
  (:all-new-trim
   ()
   (mapcar #'(lambda (j) (list j (send self :new-trim j))) (send self :joint-method-names)))
  (:diff-trim-vector
   nil
   (let* ((cv (coerce (send self :read-servo-vector) float-vector))
	  (v0 (make-sequence float-vector (length cv) :initial-element 7500)))
     (v- cv v0)))
  (:new-trim-vector
   nil
   (coerce
    (v+ (coerce (send self :read-trim-vector) float-vector)
	(send self :diff-trim-vector))
    integer-vector))
  (:make-joint-zero-offset-from-trim-vector
   (&optional (tvector trim-vector))
   (let (res v)
     (dotimes (si sv-length)
       (if (setq v (assoc si servo-config-list))
	   (push (list (cadr v) (/ (elt tvector si) deg-to-servovector)) res)))
     (reverse res)))
  (:set-angle-vector-joint
   ()
   (let ((jl (send robot :joint-list)))
     (mapc #'(lambda (j)
	       (push (position j jl) (get j :angle-index)))
	   jl)))
  (:set-servo-vector-joint
   (sv-index joint-method-name &optional (sign 1) offset servo-type pair-kjs-idx magenc-offset upper-limit)
   (unless (find-method robot joint-method-name)
     (warn "!! ~A has no method ~A in :set-servo-vector-joint~%" robot joint-method-name)
     (return-from :set-servo-vector-joint nil))
   (let* ((j (send robot joint-method-name))
	  (jl (send robot :joint-list))
	  (av-index (position j jl))
	  (rotate-config-lst nil))
     ;; (format t "joint-method-name:~A~%" joint-method-name)
     ;; (format t "sign:~A, offset:~A, servo-type:~A, kjs-idx:~A, magenc-offset:~A~%" sign offset servo-type pair-kjs-idx magenc-offset)
     (unless j
       (warn " Alarm!! joint-name ~A is not usable in ~A !!!~%" joint-method-name self))
     (when
	 (and j (numberp sv-index))
       (when
	   (numberp offset)
	 (setf (aref trim-vector sv-index) (- (aref trim-vector sv-index) (* deg-to-servovector sign offset)))
	 (format t ";; offset=~A, trim-vector(~A)=~A~%" offset sv-index (elt trim-vector sv-index))
	 )
       ;;(format *error-output* ":set-servo-vector-joint j:~A sv-index:~A joint-method-name:~A~%"
       ;;j sv-index joint-method-name)
       (send robot joint-method-name :max-joint-torque
	     (case
		 servo-type
	       ((s1 s3301) (* 6.0 9.8 0.01))
	       ((s2 s3302) (* 6.7 9.8 0.01))
	       ((s4 s3304) (* 13.9 9.8 0.01))
	       (sr (* 40 1.25 9.8 0.01))
	       (t (* 6.7 9.8 0.01))) 
	     )
       (send j :put :gear-ratio 
	     (case
		 servo-type
	       ((s1 s3301) 262.92)
	       ((s2 s3302) 262.92)
	       ((s4 s3304) 289.22)
	       (sr (* 289.22 20))
	       (t 262.92)))
       (send j :put :climit 4)
       (send j :put :torque-Const 
	     (/ (send j :max-joint-torque)
		(get j :gear-ratio)
		(get j :climit)))
       (case servo-type
	     (sr
	      (when (and (numberp pair-kjs-idx) (numberp magenc-offset))
		(format t "rotate servo config~%")
		(format t "servo-idx:~A, pair-kjs-idx:~A, magenc-offset:~A, ~%" sv-index pair-kjs-idx magenc-offset)
		(setq rotate-config-lst '())
		(push upper-limit rotate-config-lst)
		(push magenc-offset rotate-config-lst)
		(push pair-kjs-idx rotate-config-lst)
		(push offset rotate-config-lst)
		(push sign rotate-config-lst)
		(push joint-method-name rotate-config-lst)
		(push sv-index rotate-config-lst)
		(pushnew rotate-config-lst rotate-config-list);;(sv-idx joint-name kjs-idx magenc-offset upper-limit)
		)
	      )
	     )
       (setf (aref joint-to-actuator-matrix sv-index av-index)
	     (* deg-to-servovector sign))
       ;;
       (setf (aref servo-joint-vector sv-index) j)
       (if (equal :wheel (send j :joint-type)) (push sv-index wheel-sids))
       ;;(setf (aref actuator-to-joint-matrix av-index sv-index) (/ sign 30.0))
       ;;
       (unless (member sv-index (elt angle-to-servo-index av-index))
	 (push sv-index (elt angle-to-servo-index av-index))
	 (push sv-index (get j :servo-index))
	 (push sign (get j :servo-sign))
	 (push av-index (elt servo-to-angle-index sv-index)))
       )
     jl)
   )
  (:get-max-joint-torque
   (joint-name)
   (send robot joint-name :max-joint-torque)
   )
  (:rotate-config-list nil rotate-config-list)
  (:angle-index-to-servo-index
   (ai) (aref angle-to-servo-index ai))
  (:servo-index-to-angle-index
   (si) (aref servo-to-angle-index si))
  (:angle-vector-to-servo-vector-old
   (av &optional fv
       (sv (make-array sv-length :element-type integer-vector :initial-element 7500))
       &aux si trm)
   ;;(format t ";;call :joint-vector-to-servo-vector ~A~%" av)
   (setq sv (send self :joint-vector-to-servo-vector av))
   sv)
  (:angle-vector-to-servo-vector (av) (send self :joint-vector-to-servo-vector av))
  (:send-servo-vector
   (&optional (vel 50) (sids servo-sorted-ids))
   (dotimes (i av-length)
     (when (elt free-vector i)
       (dolist (si (aref angle-to-servo-index i))
	 (setq sids (remove si sids)))))
   (send self :send-servo-vector-com servo-vector vel sids)
   )
  ;;
  ;; send *ri* :send-joint-param param value {:larm :rarm :lleg :rleg or :larm-shoulder-p .. like}
  (:send-joint-param
   (param value &rest args &aux js sids (stv (make-sequence integer-vector sv-length :initial-element value)))
   (if (null args) (setq js (send robot :joint-list))
     (dolist (a args) 
       (if (keywordp a) (push (send robot a :joint-list) js)
	 (if (derivedp a joint) (push a js)))))
   (setq js (flatten js))
   (setq sids (sort (remove-duplicates (flatten (send-all js :servo-index)))
		    #'<))
   (send self :send-cmd (list param sids stv))
   )
  ;;
  (:send-stretch (&optional (value 127) &rest args)
		 (send* self :send-joint-param :stretch value args))
  (:send-speed (&optional (value 127) &rest args)
	       (send* self :send-joint-param :speed value args))
  ;;
  (:reset-angle-zero-offset
   nil
   ;;(dotimes (i av-length) (setf (aref actuator-to-joint-zero-offset i sv-length) 7500))
   (setq actuator-to-joint-matrix (pseudo-inverse joint-to-actuator-matrix))
   )
  (:servo-vector-to-joint-vector
   (&optional (sv servo-vector))
   (subseq (transform actuator-to-joint-matrix (send self :servo-vector1 sv)) 0 av-length))
  (:joint-vector-to-servo-vector
   (&optional (av angle-vector))
   (subseq (transform joint-to-actuator-matrix (send self :angle-vector1 av)) 0 sv-length))
  (:servo-vector-to-angle-vector
   (sv)
   (send self :servo-vector-to-joint-vector sv))
  (:servo-to-angle-index nil servo-to-angle-index)
  (:angle-to-servo-index nil angle-to-servo-index)
  (:draw-motion-files
   (&optional (str ""))
   (let ((mm (send self :motion-files str :mcode)))
     (if (xwindow-ready?)
	 (do-until-key
	  (if (null mm) (return-from :draw-motion-files nil))
	  (send self :emulate-motion-code (pop mm)))
       (format t ";; no xwindow~%"))))
  (:draw-project-file
   (&optional (str "") (wait 0))
   (let ((mm (send self :project-file :mcodes str)))
     (if (xwindow-ready?)
	 (if
	     (consp mm)
	     (do-until-key
	      (if (null mm) (return-from :draw-project-file nil))
	      (send self :emulate-motion-code (pop mm) :wait wait))
	   (send self :emulate-motion-code mm :wait wait))
       (format t ";; no xwindow~%"))))
  (:load-motion-file 
   (&optional (fname ""))
   (if (probe-file fname)
       (instance rcb4-motion-file :init self fname)
       (error ";; no file:~A~%" fname)))
  (:draw-motion-file
   (mf)
   (if (stringp mf) (setq mf (send self :load-motion-file)))
   (send self :emulate-motion-code (send mf :mcode)))
  (:run-project-file
   (&optional (str ""))
   (let ((mm (send self :project-file :mcodes str)))
     (if (consp mm)
	 (do-until-key
	  (if (null mm) (return-from :run-project-file nil))
	  (send self :emulate-motion-code (pop mm) :send-to-ri t))
       (send self :emulate-motion-code mm :send-to-ri t))))
  (:run-rom-table
   (&optional n &key (loopmax 200))
   (let ((mm (send self :rom-table n)))
     (if (consp mm)
	 (do-until-key
	  (if (null mm) (return-from :run-rom-table nil))
	  (send self :emulate-motion-code (pop mm) :send-to-ri t))
       (send self :emulate-motion-code mm :send-to-ri t))))
  (:emulate-motion-code-old
   (mc &key (loopmax 100) copy-viewer send-to-ri)
   (send rcb4machine :emulate-motion-code self mc
	 :loopmax loopmax :copy-viewer copy-viewer :send-to-ri send-to-ri))
  (:emulate-motion-code
   (mc &rest args &key (loopmax 100) copy-viewer send-to-ri &allow-other-keys)
   (send* rcb4machine :emulate-motion-code self mc args))
  (:emulate-button-motion
   (button &key (project t) (loopmax 100) copy-viewer send-to-ri)
   )
  (:draw-rom-table
   (&optional n &key (loopmax 200))
   (send rcb4machine :draw-rom-table self n :loopmax loopmax))
  (:rcb4machine (&rest args) (forward-message-to rcb4machine args))
  (:timer-on-old
   (&optional (func 'ri-viewer-update))
   (setq *top-selector-interval* 0.1)
   (when com-port (pushnew func *timer-job*))
   )
  (:timer-on
   (&optional (func :viewer-update))
   (setq *top-selector-interval* 0.1)
   (unless com-port (send self :com-init))
   (when com-port
     (when (keywordp func)
       (unless (get 'ri-viewer-update :original-function)
	 (setf (get 'ri-viewer-update :original-function)
	       (symbol-function 'ri-viewer-update)))
       (setf (symbol-function 'ri-viewer-update) 
	     `(lambda () (send ,self ,func))))
     (pushnew 'ri-viewer-update *timer-job*))
   )
  (:timer-off (&optional (func 'ri-viewer-update))
	      (setq *timer-job* (remove func *timer-job*)))
  (:balance-on nil (send self :timer-on 'ri-balance-update))
  (:balance-off nil (send self :timer-off 'ri-balance-update))
  (:read-gyro (&aux (a (send self :read-analog)))
	      (float-vector (elt a 1) (elt a 2)))  ;; 1: roll, 2: pitch
  (:power-voltage nil (elt (send self :read-analog) 0))
  (:real-orientation
   (&optional v)
   ;;(unless com-port (send self :com-init))
   (when com-port
     (let ((g (send self gravity-method)) (m (make-coords))
	   (s (send robot :worldcoords)))
       ;; (send robot :imu-sensor "gsensor") if modeled in gravity-method
       (orient-coords-to-axis m #f(0 0 -1) (normalize-vector g))
       (send robot :move-coords m s)
       (if (and v (float-vector-p v))
	   (send robot :rotate-vector v)
	   (send robot :worldcoords)))))
  (:real-orientation-new
   ()
   (let* ((g (send self gravity-method))
	  (m (make-cascoords))
	  (c (orient-coords-to-axis m #f(0 0 -1) (normalize-vector g)))
	  (s (send robot :worldcoords))
	  (b (send robot :imu-sensor "gsensor")) ;; if modeled in gravity-method
	  )
     ;;(orient-coords-to-axis m #f(0 0 -1) (normalize-vector g))
     (if b 
	 (send robot :move-coords 
	       (make-coords :rot (send c :worldrot) :pose (send b :worldpos))
	       b)
       (send robot :move-coords m s))))
  (:read-angle-vector
   nil
   (when (send self :read-servo-vector)
     (setq angle-vector (send self :servo-vector-to-angle-vector servo-vector))))
  (:read-angle-alist
   nil
   (send robot :angle-vector (send self :read-angle-vector))
   (send robot :angle-alist))
  (:read-ref-angle-vector
   nil
   (send self :servo-vector-to-angle-vector (send self :read-ref-servo-vector)))
  (:stop-vibration
   nil
   (send self :free :arms)
   (send self :free :head)
   (send self :set-free-vector))
  ;;
  (:generate-pose-form
   (&optional (method-name (gentemp "POSE" :keyword)) (read t))
   (if read (send self :read-angle-vector))
   (let ((jlst (send robot :joint-list :name))
	 (vlst (send robot :joint-list :joint-angle))
	 )
     (list 'defmethod 'robot-model
	   (cons method-name
		 (mapcar #'(lambda (n v)
			     `(send self ,n :joint-angle ,v))
			 jlst vlst))
	   )))
  (:stop-wheels nil
		(send self :read-angle-vector)
		(dolist (j (send robot :joint-list))
		  (if (eq (send j :joint-type) :wheel) (send j :joint-angle 0)))
		)
  (:free-vector nil free-vector)
  (:torque-vector nil torque-vector)
  (:read-torque-vector
   (&optional (scale 0.033))
   (let* ((eav (instantiate float-vector av-length))
	  (esv (send self :read-servo-error))
	  (jlist (send-all (send robot :joint-list) :name))
	  s)
     (dotimes (i av-length)
       (unless (elt free-vector i)
	 (setq s (string (elt jlist i)))
	 (unless (eq (elt s (1- (length s))) #\W)  ;; wheel joint
	   (dolist (si (aref angle-to-servo-index i))
	     (setf (elt eav i)
		   (* (elt esv si)
		      (aref joint-to-actuator-matrix si i)
		      scale))))))
     (setq torque-vector eav)
     eav
     )
   )
  (:read-torque-alist
   (&optional (scale 0.033))
   (let* ((esv (coerce (send self :read-torque-vector) cons))
	  (jlist (send robot :joint-list))
	  s)
     (mapcar
      #'(lambda (j v)
	  (cons (send j :method-name)
		v))
      ;;(reduce #'+ (mapcar #'(lambda (i) (elt esv i)) (send j :servo-index)))))
      jlist esv)))
  (:read-torque-vector-estimate
   (&optional (k 0.38789));;;;todo 3302/3304 [Nm]
   (let* ((eav (instantiate float-vector av-length))
	  (esv (send self :read-servo-error))
	  (jlist (send-all (send robot :joint-list) :name))
	  s)
     (dotimes (i av-length)
       (unless (elt free-vector i)
	 (setq s (string (elt jlist i)))
	 (unless (eq (elt s (1- (length s))) #\W)  ;; wheel joint
	   (dolist (si (aref angle-to-servo-index i))
	     (setf (elt eav i)
		   (* (elt esv si)
		      (/ 1 (aref joint-to-actuator-matrix si i))
		      k
		      ));;torque_estimation = error_angle([sv]) / (8000 / 270)([sv/deg]) * k([Nm/deg])
	     ))))
     (setq torque-vector eav)
     eav
     )
   )
  (:reset-pose (&optional (time 1000) controller)
	       (send robot :reset-pose) (send self :send-body time controller))
  (:sit-pose (&optional (time 1000) controller)
	     (send robot :sit-pose) (send self :send-body time controller)
	     (send self :free :legs))
  (:send-body (&optional (time 1000) controller)
	      (send self :angle-vector (send robot :angle-vector) time controller))	      
  (:move-joint (jo val &optional (time 1000))
	       (send robot jo :joint-angle val)
	       (send self :send-body time))
  ;;
  ;;
  (:servo-neutral (&optional (vel 500)) (send self :servo-all 7500 vel))
  (:neutral (&optional (time 1000) controller)
	    (send robot :neutral) (send self :send-body time controller))
  (:free-arms nil (send self :free :arms))
  (:free-grippers nil (send self :free
			    :larm-gripper-r :rarm-gripper-r))
  (:hold-arms nil (send self :free :arms))
  (:hold-grippers nil (send self :hold
			    :larm-gripper-r :rarm-gripper-r))
  (:free-all () (dotimes (i av-length) (setf (elt free-vector i) t))
	     (send self :servo-all #x8000 1))
  (:hold-all ()
	     (dotimes (i av-length) (setf (elt free-vector i) nil))
	     (send self :servo-all #x7fff 1))
  (:servo-all (&optional (v 7500) (vel 1000)) (send self :send-same-value v servo-sorted-ids vel))
  (:limbs-jlist (&optional limbs) (send robot :limbs-jlist limbs))
  (:jlist-sorted-sids (jlist) (send robot :jlist-sorted-sids jlist :servo-index))
  (:limbs-sorted-sids (&optional limbs) (send robot :limbs-sorted-sids limbs :servo-index))
  (:free (&rest args &aux js (jlist (send robot :joint-list)) sids)
	 ;;(unless com-port (send self :com-init))
	 (when com-port
	   (send self :read-angle-vector)
	   (setq js (send self :limbs-jlist args))
	   (dolist (j js) (setf (elt free-vector (position j jlist)) t))
	   (send self :send-same-value #x8000 (send self :jlist-sorted-sids js) 1)))
  (:hold (&rest args &aux js (jlist (send robot :joint-list)) sids)
	 ;;(unless com-port (send self :com-init))
	 (when com-port
	   (send self :read-angle-vector)
	   (setq js (send self :limbs-jlist args))
	   (dolist (j js) (setf (elt free-vector (position j jlist)) nil))
	   (send self :send-same-value #x7fff (send self :jlist-sorted-sids js) 1)))
  (:release
   (&rest args &aux js (jlist (send robot :joint-list)) sids)
   (when com-port
     (let ((tm  (find-if #'numberp args)))
       (if tm (setq args (remove tm args)) (setq tm 20))
       (send* self :free args)
       (unix::usleep (* tm 1000))
       (send* self :hold args))))
  (:free-joint-list
   (&optional (v (send self :free-vector)) &aux (jlist (send robot :joint-list :name)) res)
   (dotimes (i (length v))
     (if (elt v i) (push (elt jlist i) res)))
   res)
  (:hold-joint-list
   (&optional (v (send self :free-vector)) &aux (jlist (send robot :joint-list :name)) res)
   (dotimes (i (length v))
     (unless (elt v i) (push (elt jlist i) res)))
   res)
  (:set-free-vector
   (&optional (v (send self :free-vector))
	      &aux (fl (send self :free-joint-list)) (hl (send self :hold-joint-list)))
   (send* self :free fl)
   (send* self :hold hl))
  (:send-same-value
   (val &optional
	(sids servo-sorted-ids)
	(vel 100)
	(sv (copy-object servo-vector)))
   (dotimes (i rcb4-dof) (setf (elt sv i) val))
   (setq sids (sort (remove-duplicates sids) #'<))
   (if (or (= val #x8000) (= val #x7fff))
       (dolist (si wheel-sids) (setq sids (remove si sids))))
   (send self :send-servo-vector-com sv vel sids)
   #|
   (let ((flag (send self :non-block)))
     (send self :non-block :on)
     (send self :send-servo-vector-com sv vel sids)
     (if (null flag) (send self :non-block :off))
     )
   |#
   val)
  ;;
  (:head-free () (send self :free :head))
  (:head-hold () (send self :hold :head))
  (:larm-free () (send self :free :larm))
  (:rarm-free () (send self :free :rarm))
  (:lmarm-free () (send self :free :lmarm))
  (:rmarm-free () (send self :free :rmarm))
  (:arm-free () (send self :free :arms))
  (:marm-free () (send self :free :marms))
  (:leg-free () (send self :free :legs))
  (:lleg-free () (send self :free :lleg))
  (:rleg-free () (send self :free :rleg))
  (:lleg-hold () (send self :hold :lleg))
  (:rleg-hold () (send self :hold :rleg))
  (:leg-hold () (send self :hold :legs))
  (:torso-free () (send self :free :torso))
  (:torso-hold () (send self :hold :torso))
  (:lhand-free () (send self :send-same-value #x8000
			(send-all (last (send robot :larm :joint-list)) :servo-index)))
  (:rhand-free () (send self :send-same-value #x8000
			(send-all (last (send robot :rarm :joint-list)) :servo-index)))
  (:hand-free () (send self :send-same-value #x8000
		       (send-all (mapcan #'last (send self :arms :joint-list)) :servo-index)))
  (:larm-hold () (send self :hold :larm))
  (:rarm-hold () (send self :hold :rarm))
  (:arm-hold () (send self :hold :arms))
  (:marm-hold () (send self :hold :marms))
  ;;
  (:set-project-file
   (&optional (name-str (send robot :config-name)))
   (let ((name (kxr-project-file-name name-str)))
     (when (and name-str name (probe-file name))
       (setq project-file (instance rcb4-project-file :init self name))
       (dolist (mc (send project-file :mcodes))
	 (send rcb4machine :set-rom-table (send mc :number) mc))
       (send rcb4machine :scan-jump-vectors)
       (send self :trim-vector (send project-file :trim-vector))
       project-file)))
  (:project-file (&rest args) (forward-message-to project-file args))
  ;; check servo index
  (:check-motion-table
   (mt)
   (let ((svids servo-sorted-ids)
	 mc offset adr0  adr adr-list)
     (dotimes (i 120)
       (when (setq mc (elt mt i))
	 (setq adr (rcb4-address (list :motiontable i)))
	 (setq adr-list (list adr))
	 (dolist (a (mc . acodes))
	   (when (consp a)
	     (setq adr (+ adr (length (rcb4-assemble-one a i))))
	     (push adr adr-list)))
	 (dolist (a (mc . acodes))
	   (when (consp a)
	     ;; check if servo-ids of :servo command is inside servo-sorted-ids
	     (when (memq (car a) '(:servo :s-s :m-s-cv :m-s-mv :m-ss :stretch :speed))
	       (when (set-difference (cadr a) svids)
		 (format t ";; :check mt-i:~A, ~A svids-len=~A should be ~A~%"
			 i (car a) (length (cadr a)) (length svids))))
	     ;; check if jump/call address is the bounder of eatch commands
	     (when (memq (car a) '(:call :jump))
	       (setq adr (rcb4-address (caddr a)))
	       (unless (or (memq adr adr-list)
			   (zerop (mod (- adr (rcb4-address '(:motiontable 0 0))) #x800)))
		 (format t ";; :check mt-i:~A, wrong addr=~A adr-list=~A~%" i a adr-list)))
	     ))))
     ))
  (:check-project-file nil (send self :check-motion-table (send self :project-file :motion-table)))
  (:check-rom-table nil (send self :check-motion-table (send self :rom-table)))
  ;;
  (:convert-motion-table
   (from-mt from-ri to-mt to-ri)
   (let* (mc mc2 from-ccodes to-ccodes)
     ;;(assert (derivedp from-mt rcb4-motion-table) ";; not motion-table from-mt=~A~%" from-mt)
     ;;(assert (derivedp to-mt rcb4-motion-table) ";; not motion-table to-mt=~A~%" to-mt)
     (when (derivedp from-mt rcb4-motion-table)
       (dotimes (i 120)
	 (when (setq mc (elt from-mt i))
	   (send mc :deconversion from-ri) ;; acodes -> ccodes
	   (setq mc2 (copy-object mc))
	   (setq from-ccodes (copy-object (mc . ccodes)))
	   (setq to-ccodes nil)
	   (dolist (c from-ccodes)
	     (if (and (consp c)
		      (eq (car c) :angle-vector))
		 (push (convert-angle-vector-code c from-ri to-ri) to-ccodes)
	       (push c to-ccodes)))
	   (setq (mc2 . ccodes) (reverse to-ccodes))
	   (send mc2 :conversion to-ri nil) ;; ccodes -> ac -> bc
	   ;;(format t ";; conversion i:~A mc2:~A~%" i mc2)
	   (setq (mc2 . acodes) (copy-object (mc2 . ac)))
	   (setq (mc2 . bcodes) (copy-object (mc2 . bc)))
	   (setf (elt to-mt i) mc2)))
       )))
  (:reform-motion-code
   (mc &optional servo-mapping)
   (when mc
     (setq (mc . acodes) (send self :generate-formed-acodes mc servo-mapping))
     (setq (mc . ac) (send self :generate-formed-acodes mc servo-mapping))
     (setq (mc . bcodes) (rcb4-assemble (mc . acodes) (mc . number)))
     (setq (mc . bc) (rcb4-assemble (mc . acodes) (mc . number)))
     ;;(send mc :deconversion self)
     ;;(send mc :conversion self)
     mc))
  (:reform-motion-table
   (mt &optional servo-mapping)
   (dotimes (i 120) (send self :reform-motion-code (elt mt i) servo-mapping)))
  (:reform-servo-confs
   (sf &optional servo-mapping)
   (let (sc ret to from)
     (dolist (s sf)
       (setq sc (instance rcb4-servo-config :init
			  (if (evenp (s . devicenumber))
			      (format nil "R~A" (s . id))
			    (format nil "L~A" (s . id)))
			  (s . devicenumber)
			  "None" ;; (s . mode)
			  (s . port)
			  (s . id)
			  0  ;; (s . trim)
			  (s . position)
			  '(0 0) ;; location
			  ))
       (push sc ret))
     (setq ret (reverse ret))
     (dolist (sm servo-mapping)
       (setq from (find-if #'(lambda (x) (= (x . devicenumber) (car sm))) sf))
       (setq to (find-if #'(lambda (x) (= (x . devicenumber) (cadr sm))) ret))
       (when (and from to)
;;	 (setq (to . name) (from . name))
	 (setq (to . mode) "Normal")
	 (setq (to . trim) (from . trim))
	 (setq (to . position) (from . position))
	 (setq (to . location) (from . location)))
       )
     ret))
  ;;
  (:reform-project-file
   (&optional servo-mapping)
   (let* ((pf (send self :project-file))
	  (mt (send pf :motion-table))
	  (sf (send pf :sconfs))
	  sf2)
     (send self :reform-motion-table mt servo-mapping)
     (send self :replace-mt-project-file-xml mt project-file)
     (setq sf2 (send self :reform-servo-confs sf servo-mapping))
     (send self :replace-sf-project-file-xml sf2 project-file)     
     project-file))
  (:replace-mt-project-file-xml
   (mt &optional (pf project-file))
   (dotimes (i 120) 
     (if (elt mt i) (setq ((elt mt i) . bcodes) ((elt mt i) . bc))))
   (setq (pf . motion-table) mt)
   (xml-replace-motion-table (pf . xml) mt))
  (:replace-sf-project-file-xml
   (sf &optional (pf project-file))
   (setq (pf . sconfs) sf)
   (xml-replace-servo-confs (pf . xml) sf))
  ;;
  (:reform-rom-table
   ()
   (let ((mt (send self :rom-table)))
     (send self :reform-motion-table mt)
     mt))
  ;;
  (:reform-project-file-old
   (&optional (from-ri self))
   (let* ((from-mt (send from-ri :project-file :motion-table))
	  (to-mt (send self :project-file :motion-table))
	  (to-ri self) mc mc2 from-ccodes to-ccodes)
     (dotimes (i 120)
       (when (setq mc (elt from-mt i))
	 (send mc :deconversion from-ri) ;; acodes -> ccodes
	 (setq mc2 (copy-object mc))
	 (setq from-ccodes (copy-object (mc . ccodes)))
	 (setq to-ccodes nil)
	 (dolist (c from-ccodes)
	   (if (and (consp c)
		    (eq (car c) :angle-vector))
	       (push (convert-angle-vector-code c from-ri to-ri) to-ccodes)
	     (push c to-ccodes)))
	 (setq (mc2 . ccodes) (reverse to-ccodes))
	 (send mc2 :conversion to-ri nil) ;; ccodes -> ac -> bc
	 ;;(format t ";; conversion i:~A mc2:~A~%" i mc2)
	 (setq (mc2 . acodes) (copy-object (mc2 . ac)))
	 (setq (mc2 . bcodes) (copy-object (mc2 . bc)))
	 (setf (elt to-mt i) mc2)))
     (send self :replace-mt-project-file-xml to-mt project-file)
     project-file))
  ;;
  (:save-project-file
   (&optional (fname (send robot :name)))
   (tiny-xml::dump (project-file . xml) (format nil "~A.h4p" fname)))
  ;;
  (:set-motion-files
   (&optional (name-str (send robot :config-name)))
   (let ((pdir (rcb4-robot-project-dir name-str)))
     (when (probe-file pdir)
       (if (null motion-files)
	   (setq motion-files
		 (mapcar #'(lambda (x) (instance rcb4-motion-file :init self x))
			 (find-files :dir pdir :ext "xml"))))
       motion-files)))
  (:motion-files
   (&rest args)
   (mapcar
    #'(lambda (x) (forward-message-to x (cdr args)))
    (remove-if-not
     #'(lambda (x)
	 (cond ((numberp (car args))
		(equal (car args) (send x :motion-number)))
	       ((stringp (car args))
		(substringp (car args) (send x :name)))
	       (t t)))
     motion-files)))
  ;;
  (:rom-jump-vectors
   (&optional num key)
   (let ((rom-jump-vectors (send rcb4machine :jump-vectors)))
     (if num (if key (assoc key (elt rom-jump-vectors num))
	       (elt rom-jump-vectors num))
       rom-jump-vectors)))
  (:read-rom-table
   (&optional i nam &aux v)
   (when com-port
     (cond
       ((null i) 
	(dotimes (i 120) (format t "~A " i) (finish-output t)
		 (send self :read-rom-table i))
	(send self :read-jump-vectors)
	(send self :rom-table))
       (t
	(let* ((lst-name (send self :read-motion-lst i)) (code (car lst-name))
	       (rtab (send rcb4machine :rom-table))
	       (mc (elt rtab i))
	       (name (cadr lst-name)) (pc (send self :project-file :mcode i)))
	  (if (equal name "") (setq name (format nil "(ROM ~A)" i)))
	  (if nam (setq name nam))
	  (send mc :name name)
	  (unless (= (send mc :number) i)
	    (format t ";; error!! (mc . number):~A is not ~A~%" (send mc :number) i))
	  (send mc :set-bcodes code)
	  (send mc :set-buttondata (send self :motion-button i))
	  (if (and pc (equal (send mc :bcodes) (send pc :bcodes)))
	      (setq name (send pc :name)))
	  (send mc :name name)
	  (send mc :disassemble)
	  (send mc :deconversion self)
	  (send mc :conversion self)
	  (send rcb4machine :set-rom-table i mc)
	  mc)))))
;;; system 
  (:set-sysreg (low high)
	       (send self :send-cmd `(:move (:lit ,low ,high) (:ram #x0)) 1))
  (:gen-sysreg-word-old ;; inaba
   (lst &optional (opt (send self :get-options ":gen-sysreg-word")))
   (let* ((num (numseq-to-num opt 2)) i v (mask 0))
     (dolist (l lst)
       (when (and (symbolp (car l)) (numberp (cdr l)))
	 (setq i (position (car l) *rcb4-sysreg-bits*))
	 (setq v (not (zerop (cdr l)))))
       (if i (setq mask (logand #xffff
				(if v (ash 1 i) (lognot (ash 1 i))))))
       (setq num (if v (logior num mask) (logand num mask))))
     (list (logand num #xff) (logand (ash num -8) #xff))))
  (:get-options-old (&optional (msg ""))
		    (send self :send-cmd '(:move (:ram 0 2) (:com)) 2))
  (:sysreg-old
   (&optional (opt (send self :get-options "sysreg")))
   (let* ((num (numseq-to-num opt 2)) v res)
     (dotimes (i 16)
       (if (logbitp i num)
	   (push (cons (elt *rcb4-sysreg-bits* i) 1) res)
	 (push (cons (elt *rcb4-sysreg-bits* i) 0) res)))
     (if (= (assocdr :frame-b0 res) 1)
	 (if (= (assocdr :frame-b1 res) 1) (push '(:frame 25ms) res) (push '(:frame 15ms) res))
       (if (= (assocdr :frame-b1 res) 1) (push '(:frame 20ms) res) (push '(:frame 10ms) res)))
     (if (= (assocdr :com-b0 res) 1)
	 (if (= (assocdr :com-b1 res) 1) (push '(:com 115.2kbps) res) (push '(:com 625kbps) res))
       (if (= (assocdr :com-b1 res) 1) (push '(:com 1.25mbps) res) (push '(:com 115.2kbps) res)))
     (if (= (assocdr :ics-b0 res) 1)
	 (if (= (assocdr :ics-b1 res) 1) (push '(:ics 115.2kbps) res) (push '(:ics 625kbps) res))
       (if (= (assocdr :ics-b1 res) 1) (push '(:ics 1.25mbps) res) (push '(:ics 115.2kbps) res)))
     #|
     (remove-if
     #'(lambda (x) (member (car x) '(:com-0 :com-1 :frame-0 :frame-1 :ics-0 :ics-1)))
     res)
     |#
     res
     ))
  (:get-options (&optional (msg ""))
		(numseq-to-num (send self :send-cmd '(:move (:ram 0 2) (:com)) 2)
			       2))
  (:gen-sysreg-word ;; inaba
   (lst &optional (num (send self :get-options ":gen-sysreg-word")))
   (let* (i v (mask 0))
     (dolist (l lst)
       (when (and (symbolp (car l)) (numberp (cdr l)))
	 (setq i (position (car l) *rcb4-sysreg-bits*))
	 (setq v (not (zerop (cdr l)))))
       (if i (setq mask (logand #xffff
				(if v (ash 1 i) (lognot (ash 1 i))))))
       (setq num (if v (logior num mask) (logand num mask))))
     (list (logand num #xff) (logand (ash num -8) #xff))))
  (:set-sysreg-bits
   (lst)
   (send self :send-cmd
	 (list :move (cons :lit (send self :gen-sysreg-word lst)) '(:ram #x0)) 1))
  (:sysreg
   (&optional (num (send self :get-options "sysreg")))
   (let* (v res)
     (dotimes (i 16)
       (if (logbitp i num)
	   (push (cons (elt *rcb4-sysreg-bits* i) 1) res)
	 (push (cons (elt *rcb4-sysreg-bits* i) 0) res)))
     (if (= (assocdr :frame-b0 res) 1)
	 (if (= (assocdr :frame-b1 res) 1) (push '(:frame 25ms) res) (push '(:frame 15ms) res))
       (if (= (assocdr :frame-b1 res) 1) (push '(:frame 20ms) res) (push '(:frame 10ms) res)))
     (if (= (assocdr :com-b0 res) 1)
	 (if (= (assocdr :com-b1 res) 1) (push '(:com 115.2kbps) res) (push '(:com 625kbps) res))
       (if (= (assocdr :com-b1 res) 1) (push '(:com 1.25mbps) res) (push '(:com 115.2kbps) res)))
     (if (= (assocdr :ics-b0 res) 1)
	 (if (= (assocdr :ics-b1 res) 1) (push '(:ics 115.2kbps) res) (push '(:ics 625kbps) res))
       (if (= (assocdr :ics-b1 res) 1) (push '(:ics 1.25mbps) res) (push '(:ics 115.2kbps) res)))
     #|
     (remove-if
     #'(lambda (x) (member (car x) '(:com-0 :com-1 :frame-0 :frame-1 :ics-0 :ics-1)))
     res)
     |#
     res
     ))
  (:version nil (coerce (send self :send-cmd '(:version) 32) string))
  (:ack-old nil
	    ;;(unless com-port (send self :com-init))
	    (= (elt (send self :send-cmd '(:ack) 1) 0) 6))
  (:ack
   (&optional (tm-msec 1000) &aux ret (flag t))
   (send self :write (rcb4-assemble-one '(:ack)))
   ;; (format t ";; :ack  write :ack time-out=~A~%" tm-msec)
   (cond
     ((derivedp (com-port . strm) io-stream)
      (cond
	((send com-port :ready? tm-msec)
	 (format t ";; read-msg for :ack, after select-stream=~A~%" ret)
	 (setq ret (send com-port :read-all tm-msec))
	 (format t ";; :read-all ret=~A~%" (coerce ret cons))
	 (return-from :ack (if ret ret nil)))
	(t (return-from :ack nil))))
     (t 
      (= (elt (send self :send-cmd '(:ack) 1) 0) 6))))
  (:wait-ack
   (&optional (timeout-msec 1000) msg)
   (while (null (send self :ack timeout-msec))
     (if msg (format t ";; :wait-ack timeout-msec=~A~%" timeout-msec))))
  ;;
  (:com-close nil (setq com-port nil))
  (:com-stop nil (setf (get self :com-port) com-port))
  (:com-restart nil (setq com-port (get self :com-port)))
  ;;
  (:com-open ;; bottom
   (&rest args &key (index 0) slow (baud 1250000) (vid #x165c) (pid #x0008) (interface 0)
	  (stop 0) (parity 2) (serial 0) (latency 1) &allow-other-keys)
   (setq com-port (send* (instantiate uart-interface) :init args)))
  (:rcb4-open
   (&rest args &key exec &allow-other-keys)
   (when (or (null com-port) exec) (send* self :com-open args))
   (when com-port
     (unless control-board (setq control-board :rcb4))
     (send self :get-options ":com-init")
     (setq free-vector (make-sequence vector av-length :initial-element nil))
     (send self :init-analog)
     (list 
      (send self :sysreg)
      ;;(send self :read-project-title)
      )
     )
   )
  (:com2-init
   (&rest args &key (index 0) slow (baud 1250000) (vid #x0403) (pid #x6001) (interface 0)
	  (bits 8) (exec t) (stop 0) (parity 2) (latency 1)
	  &allow-other-keys)
   ;; stop: stop_BIT_1=0,stop_BIT_15=1, stop_BIT_2=2
   ;; parity: NONE=0, ODD=1, EVEN=2, MARK=3, SPACE=4
   ;; bits: BITS_7=7, BITS_8=8
   ;;
   (send self :rcb4-open :exec exec :index index :slow slow :baud baud :vid vid :pid pid :interface interface
	 :stop stop :parity parity :latency latency))
  (:com-init 
   (&rest args &key (index 0) slow (baud 1250000) (vid #x165c) (pid #x0008) (interface 0)
	  (stop 0) (parity 2) (latency 1) &allow-other-keys)
   (let (mp)
     (if
	 (and robot (setq mp (assoc :com-init-method (plist-to-alist (send robot :model-params)))))
	 (if (eq (car (cadr mp)) :com-init)
	     (send* self :com-open (cdr (cadr mp)))
	   (send* self (cadr mp)))
       (send self :rcb4-open :slow slow :baud baud :vid vid :pid pid :index index :interface interface
	     :stop stop :parity parity :latency latency))))
  (:write ;; 
   (msg)
   (when com-port
     (send com-port :write-data (coerce msg string))
     (length msg)))
  ;;
  (:send-cmd
   (cmd &optional (read-size 1))
   (send self :write (rcb4-assemble-one cmd))
   (send self :read-msg :start 1))
  (:send-cmd-no-wait
   (cmd &optional (read-size 1))
   (send self :write (rcb4-assemble-one cmd)))
  (:write-msg
   (lst &optional (mesg ""))
   (send self :write lst)
   (send self :read-msg))
  ;;
  (:write-msg-no-rom-return
   (lst &optional (mesg ""))
   (send self :write lst))
  ;;
  (:read-msg
   (&key (start 0))
   (when com-port
     (let* ((str (send com-port :read-data))
	    (n (length str)))
       (cond
	 ((> n start)
	  (subseq str start (- n 1)))
	 (t
	  (format t ";; (:read-msg :start ~A) str=~S str.len=~A" start str n)
	  str)))))
  ;;
  (:asm-from-rom
   (adr &optional (read-size 100) (region :rom))
   (rcb4-disassemble-one (send self :read-str adr region read-size)))
  (:asm-to-rom
   (lst addr &optional (region :rom))
   (send self :send-cmd (list :move (cons :lit lst) (list region addr)) 1))
  (:read-lst (addr &optional (size 2) (region :rom))
	     (coerce (send self :read-str addr region size) cons))
  (:read-str (addr region &optional (size 2))
	     (send self :send-cmd
		   (list :move (list region (rcb4-address addr) size) '(:com))
		   size))
  (:read-project-title
   nil
   (let ((str (send self :read-str :projecttitlerom :rom 32))
	 res)
     (dotimes (i 32)
       (when (member (elt str i) '(32 255))
	 (return-from :read-project-title (coerce (reverse res) string)))
       (push (elt str i) res))))
  (:read-motion-asm
   (motion-i)
   (rcb4-disassemble (car (send self :read-motion-lst motion-i)) motion-i))
  (:read-motion-lst
   (motion-i)
   (send self :read-command-lst (rcb4-address (list :motiontable motion-i 0 0)) 2048))
  (:read-command-lst
   (base size)
   (let (res (adr base))
     (while (> size 128)
       (push (send self :read-str adr :rom 128) res)
       (setq size (- size 128))
       (setq adr (+ adr 128)))
     (push (send self :read-str adr :rom size) res)
     (rcb4-command-lst (apply #'concatenate (cons string (reverse res))))))
  (:set-com-port (&optional c) (if c (setq com-port c)) com-port)
  (:com-port (&rest args) (forward-message-to com-port args))
  (:send-lisp (sexp) (send com-port :send-lisp sexp))
  (:com-swap (ri)
	     (let ((c (send ri :com-port)))
	       (send ri :set-com-port com-port)
	       (send self :set-com-port c)))
  (:read-rom-all
   (&optional exec)
   (when (and (null com-port) exec) (send self :com-init))
   (send self :read-rom-table)
   t)
  ;;
  (:reset-rom-names
   (&rest lst)
   (let (mc lst-name)
     (if (null lst)
	 (dotimes (i 120) (push i lst)))
     (dolist (i lst)
       (when
	   (and (numberp i) (< i 120))
	 (setq mc (send rcb4machine :rom-table i))
	 (setq lst-name (send self :read-motion-lst i))
	 (send mc :name (format nil "(ROM ~A)" i))
	 (send self :write-motion-lst (car lst-name) i (send mc :name))))))
  (:write-project-to-rom
   (&optional over-write)
   (let ((mcs (send project-file :mcodes))
	 name i bcodes rr rcodes)
     (dolist (mc mcs)
       (setq i (send mc :number))
       (setq name (format nil "~A" (send mc :name)))
       (setq bcodes (send mc :bcodes))
       (setq rr (send self :read-motion-lst i))
       (cond
	((equal bcodes (car rr))
	 (cond
	  ((equal (cadr rr) name)
	   (format t ";; ~A: already same name=~A. not overwrite~%" i name))
	  (t
	   (format t ";; ~A: code same. name=~A overwrite~%" i name)
	   (send self :write-motion-lst bcodes i name))))
	(t
	 (format t ";; ~A:project=~A,rom=~A~%" i bcodes (car rr))
	 (when over-write
	   (format t ";; ~A: overwrite name=~A~%" i name)
	   (send self :write-motion-lst bcodes i name)))
	))
     ))
  )

(defmethod rcb4-interface
    (:servo-id-list
     ()
     (mapcan #'(lambda (j)
		 (if (get j :active)
		     (list (cons (send j :name)
				 (car (mapcar #'(lambda (x) (/ x 2)) (get j :servo-index)))))
		     nil))
	     (send robot :joint-list)))
  (:standing-p (&optional (angle 60))
	       (> (elt (send self :real-orientation #f(0 0 1)) 2)
		  (sin (deg2rad angle))))
  (:fall-down-p (&optional (angle 30))
		(< (abs (elt (send self :real-orientation #f(0 0 1)) 2))
		   (sin (deg2rad angle))))
  (:face-down-p (&optional (angle -60))
		(< (elt (send self :real-orientation #f(1 0 0)) 2)
		   (sin (deg2rad angle))))
  (:face-up-p (&optional (angle 60))
	      (> (elt (send self :real-orientation #f(1 0 0)) 2)
		 (sin (deg2rad angle))))
  )



