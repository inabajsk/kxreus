;;;
;;;	Software Tools for RCB4, RCB4-mini M.I
;;;	RCB-4 (Robot Control Board 4): produced by Kondo Kagaku
;;;	assembler, disassembler, project file, motion file reader
;;;
;;;	2017.7.15 Assembler for Kondo machine on RCB4, RCB4-mini 
;;;	2017.7.17 Disassemble from Kondo files
;;;	2017.7.31 change rcb4-dof 33
;;;	2017.8.3  :draw-motion, add robot in rcb4-file, all-strings including < >
;;;	2017.8.9  add :draw-project-file
;;;	2017.8.10 add Number to name of motion-code of project-file 
;;;	2017.8.18 set *rcb4-dof* 35 for kxrl2l6a6
;;;	2018.2.2  (rcb4-disassemble "hexstr" | ("hexstr" ...))
;;;	2018.2.4  (rcb4-assemble ((:m-s-cv ...) ... ))
;;;	2018.2.4  :servo, :stretch, :speed instruction formats
;;;	2018.2.11 acodes generated by rcb4-disassemble includes hex-address string
;;;	2018.2.17 (rcb4-assemble acodes motion-i) accepts symbol labels
;;;     2018.2.17 (rcb4-disassemble hexstr motion-i) 
;;;	2018.2.26 (rcb4-assemble acodes motion-i) -> numlist, (rcb4-disassemble numlst motion-i)
;;;	2018.2.26 :ram address uses *rcb4-ram-address* symbols in rcb4-address
;;;	2018.3.4  :rom address uses *rcb4-rom-address* symbols in rcb4-address
;;;	2018.3.10 uppdates rcb4-address, rcb4-symbol from (sym addr size count) tables
;;;	2021.1.11 add :current-limit, :temperature-limit not supported in RCB4 but supported ICS

(require :utils)

(defvar *rcb4-dof* 36)
(defvar *rcb4asm-debug*)

(defvar *rcb4-instructions*
  '((:move . #x0)
    (:mov . #x0)
    (:and . #x1)
    (:or  . #x2)
    (:xor . #x3)
    (:not . #x4)
    (:shift . #x5)
    (:add . #x6)
    (:sub . #x7)
    (:mul . #x8)
    (:div . #x9)
    (:mod . #x0A)
    (:jump . #x0B)
    (:call . #x0C)
    (:return . #x0D)
    (:ics . #x0E)
    (:s-s . #x0F)	;; single servo
    (:m-s-cv . #x10)	;; multi servo send angles with single velocity
    (:m-s-mv . #x11)	;; multi servo send angles with multi velocity
    (:servo . #x10)	;; covers :s-s :m-s-cv :m-s-mv
    (:m-ss . #x12)	;; multi servo send speed or stretch
    (:stretch . #x12)	;; multi servo send stretch
    (:speed . #x12)	;; multi servo send speed
    (:current-limit . #x12)	;; multi servo send current limit, not RCB4
    (:temperature-limit . #x12);; multi servo send temperature limit, not RCB4
    (:version . #xFD)   
    (:ack . #xFE)
    ))

(defvar *rcb4-rom-address*
  '(
    (:Config  #x0 9 1)  ;; 9 bytes  mov(2)
    (:PioConfig  #x09 9 1)  ;; 9 bytes  mov(2)
    (:PioCmd  #x12 9 1)  ;; 9 bytes  mov(2)
    (:AdrCmdRom #x1B 11 1) ;; 11 bytes mov(3)
    (:Servocmd  #x26 11 35) ;; 11 bytes x 35
    (:ServoCmdRam  #x1A7 11 1) ;; 11bytes
    (:KRI3CmdRom  #x1B2 11 1) ;; 11bytes
    (:KRI3CmdRam  #x1BD 11 1) ;; 11bytes
    (:VectorJumpCmdRom  #x1C8 11 32) ;; 11 x 32
    (:VectorJumpCmdRam  #x328 11 1) ;; 11 bytes
    (:ConfigCmdExecute  #x333 11 1) ;; 11 bytes
    (:ServoCmdFree  #x33E 79 1) ;; 79bytes (:servo all #f(#x8000 ... #x8000))
    (:TimerWaitCmd  #x38D 25 1) ;; 25bytes 3cmd(:move(:lit 16 0)(:ram (:timer 0)))
    			    ;; (:sub (:lit 0 128) (:ram (:timer 0)) t)
    			    ;; (:jump (:nc :c<> :z :z<>) |L#X349|)
    (:ServoCmdHold  #x3A6 79 1) ;; 79bytes (:servo all #f(#x8000 ... #x7fff))
    (:ServoCmdHome  #x3F5 79 1) ;; 79bytes (:servo all #f(#x8000 ... 7500))
    (:StartupCmdRom #x444 7 1) ;; 7 bytes (:call (:nc :c<> :nz :z<>) |L#X13B80|) motion 39
    (:Mainloop #x44B 9 1) ;; Move(2)
    (:PioDirToInput #x454 9 1) ;; 9 bytes
    (:PriorityMotion #x45D 25 13) ;; 25 x 13
    (:PioDirToOutput  #x5A2 9 1) ;; 9bytes
    (:JmpToMainLoop  #x5AB 7 1) ;; 7bytes until #x5b1
                                ;; 42bytes
    (:ConfigDataRom #x5DC 2 1) ;; 2bytes
    (:ServoDataRam  #x5DE 72 1) ;; 72bytes
    (:ServoDataRom  #x626 20 36) ;; 20 x 36
    (:ADRDataRom  #x8F6 2 11) ;; 2 x 11 22 bytes
    (:KRI3DataRam #x90C 2 1) ;; 2 bytes
    (:KRI3DataRom #x90E 11 1) ;; 11 bytes
    (:JumpVectorDataRam #x919 2 1) ;; 2 bytes
    (:JumpVectorDataRom #x91B 8 32) ;; 8 x 32
    (:ProjectTitleRom #xA1B 32 1) ;; 32bytes
    (:PriorityMotionCall #xA3B 25 13) ;; 19 x 13 ;; 25 x 13?
    (:MotionTable  #x0B80 2048 120)  ;; 2048 x 120
    (:DefaultStartup #x3cb80 3 1) ;; 3bytes for :return
    (:RomEnd #x3cb83 2 1) ;;
    )
  )

(defvar *rcb4-ram-address*
  '(
    (:sysreg #x00 2 1) ;; system register
    (:pc  #x02 3 1) ;; 3 bytes
    (:sp  #x05 2 1)
    (:rom-flag  #x07 1 5)
    (:adref #x0c 2 11)   ;; 2 bytes x 11 until #x021
    (:ad  #x022 2 11)   ;; 2 bytes x 11 until #x037
    (:pio-dir  #x038 2 1)   ;; 2 bytes 
    (:pio-port #x03A 2 1)   ;; 2 bytes 
    (:timer   #x03c 2 4) ;; 2 bytes x 4 until #x043
    (:ics-data #x044 2 36) ;; 2 bytes x 36
    (:jump-vector-address #x08c 2 2) ;; address #x357
    (:servo  #x090 20 35) ;; 20 bytes x 35 until #x034B
    (:kri3  #x034c 1 1)  ;; 
    (:kri3-id  #x034d 1 1)  ;; 
    (:kri3-rd  #x034e 1 2)  ;; 0, 7 fix 
    (:button  #x0350 2 1)  ;; 2byte 
    (:kri3-ad  #x0352 1 4)  ;; 1byte x 4
    (:kri3-sum  #x0356 1 1)  ;; 1byte 
    (:jump-vector  #x0357 8 32) ;; 8 bytes x 32 vector until 0x0456
    (:counter  #x0457 1 11) ;; 1 byte x 11 until #x0461
    (:user  #x0462 2 22) ;;  2 byte x 22 until #x048d
    (:ramend  #x048e 2 1) ;;  2 byte x 22 until #x048d
    ))

(defvar *rcb4-sysreg-bits*
  #(:ics-on :rom-on :response-on :vector-jump-on
    :frame-b0 :frame-b1 :com-b0 :com-b1
    :zero-flag :carry-flag :prog-error nil
    nil :ics-b0 :ics-b1 :led))

;;;;;; basic functions

(defun hexstr-to-num (str &optional (len (length str)) (sum 0))
  (dotimes (i len)
    (setq sum (+ (ash sum 4)
		 (if (<= (elt str i) #\9)
		     (- (elt str i) #\0)
		   (- (char-upcase (elt str i)) #\A -10)))))
  sum)
(defun hexstr-to-numlist (str)
  (let (res (i 0))
    (while (< i (length str))
      (push (hexstr-to-num (subseq str i (+ i 2)) 2) res)
      (setq i (+ i 2)))
    (reverse res)))

(defun prhex (num &optional (palen t))
  (cond
    ((null num))
    ((numberp num) (format t "~X" num))
    ((atom num) (format t "~A" num))
    (t (if palen (format t "#x:(") (format t " "))
       (prhex (car num) t) 
       (prhex (cdr num) nil) (if palen (format t ")~%")))))

(defun rcb4-addr-numlist (addr size)
  (num-to-numlist (rcb4-address addr) size))

;;;; memory address 

(defun rcb4-mem-address-symbol (adr alist)
  (let ((a0 (car alist)) v0 v m)
    (dolist (a (cdr alist))
      (setq v0 (cadr a0))
      (when (and (<= v0 adr) (< adr (cadr a)))
	(if (and (= v0 adr) (= (elt a0 3) 1))
	    (return-from rcb4-mem-address-symbol (car a0)))
	(setq v (- adr v0) m (caddr a0))
	(return-from rcb4-mem-address-symbol 
	  (list (car a0) (/ v m) (mod v m))))
      (setq a0 a))
    adr)
  )
(defun rcb4-symbol (adr region &aux v)
  (if (eq region :ram)
      (setq v (rcb4-mem-address-symbol adr *rcb4-ram-address*)))
  (if (eq region :rom)
      (setq v (rcb4-mem-address-symbol adr *rcb4-rom-address*)))
  (if (and (consp v) (eq :motiontable (car v)))
      (append v (list (intern (string-upcase (format nil "L#x~X" adr)))))
    v))
(defun rcb4-address (addr &optional labels &aux l)
  (cond
   ((stringp addr) (read-from-string addr))
   ((numberp addr) addr)
   ((symbolp addr)
    (cond
     ((setq l (assoc addr labels)) (cdr l))
     ((setq l (find addr *rcb4-ram-address* :key #'car)) (cadr l))
     ((setq l (find addr *rcb4-rom-address* :key #'car)) (cadr l))
     ((setq l (read-from-string (subseq (symbol-string addr) 1)))
      (if (numberp l) l	-1))))
   ((symbolp (car addr))
    (let ((sym (car addr)) (i (cadr addr)) (v (caddr addr))
	  dat)
      (if (null v) (setq v 0))
      (cond
       ((setq dat (assoc sym *rcb4-ram-address*))
	(+ (cadr dat) (* i (caddr dat)) v))
       ((setq dat (assoc sym *rcb4-rom-address*))
	(+ (cadr dat) (* i (caddr dat)) v))
       (t (warn "wrong address ~A~%" addr)))))
   (t (warn "wrong address ~A~%" addr))))


;;;;;; disassembler

(defun rcb4-disassemble-old (a &optional (motion-i 0))
  (let ((addr (rcb4-address (list :motiontable motion-i 0))))
    (if
	(stringp a)
	(list (intern (string-upcase (format nil "L#x~X" addr)))
	      (rcb4-disassemble-one a motion-i))
      (mapcan
       #'(lambda (strcode)
	   (prog1 (list (intern (string-upcase (format nil "L#x~X" addr)))
			(rcb4-disassemble-one strcode motion-i))
	     (setq addr (+ addr (length strcode)))))
       a))))

(defun rcb4-disassemble (alst &optional (motion-i 0))
  (let* ((addr0 (rcb4-address (list :motiontable motion-i 0)))
	 (cnt 0) addr-list (addr addr0))
    (dolist (a alst) (push (cons addr cnt) addr-list)
	    (setq addr (+ addr (car a)))
	    (incf cnt))
    (setq addr addr0)
    (mapcan
     #'(lambda (strcode)
	 (prog1 (list (intern (string-upcase (format nil "L#x~X" addr)))
		      (rcb4-disassemble-one strcode motion-i addr-list))
	   (setq addr (+ addr (length strcode)))))
     alst)))

(defun rcb4-disassemble-one (a &optional (motion-i 0) addr-list)
  (let* ((codelist (if (stringp a) (coerce a cons) a))
	 (comsize (pop codelist))
	 (code (pop codelist))
	 (inst (car (find code *rcb4-instructions* :key #'cdr)))
	 kind dest src ret strs size)
    (when (and
	   (not (= (- comsize 2) (length codelist)))
	   (not (eq #xff (car (last codelist)))))
      (warn ";; size=~A inst=~A code-size=~A codelist~A~%"
	    comsize inst (length codelist) codelist))
    (case inst
      ((:move :mov :and :or :xor :add :sub :mul :div :mod :not :shift)
       (setq strs codelist)
       (setq kind (pop codelist))
       (setq dest
	     (case (rcb4-inst-dest kind)
	       (:ram (list :ram (rcb4-symbol
				 (numseq-to-num codelist 2) :ram)))
	       (:ics (list :ics (cons :id (cadr codelist))
			   (cons :offset (car codelist))))
	       (:com (list :com))
	       (:rom (list :rom (numseq-to-num codelist 3)))))
       (dotimes (i 3) (pop codelist))
       (setq src
	     (case (rcb4-inst-src kind)
	       (:ram (list :ram (rcb4-symbol
				 (numseq-to-num codelist 2) :ram)
			   (elt codelist 2)))
	       (:ics (list :ics 
			   (cons :offset (pop codelist))
			   (cons :id (pop codelist))
			   (cons :size (pop codelist))))
	       (:lit (cons :lit (butlast codelist)))
	       (:rom (list :rom  (numseq-to-num codelist 3)
			   (elt codelist 3)) ;; size
		     )))
       (if (= #x80 (logand kind #x80)) (list inst src dest t)
	 (list inst src dest)))
      ((:jump :call)
       (let ((cl codelist) (addr 0) buf con lab)
	 (dotimes (i 3) (push (pop codelist) buf))
	 (dolist (b buf) (setq addr (+ (ash addr 8) b)))
	 (setq con (rcb4-jump-conditional (pop codelist)))
	 (cond
	  ((and (<= (rcb4-address (list :motiontable motion-i 0)) addr)
		(< addr (rcb4-address (list :motiontable (1+ motion-i) 0))))
	   (unless (assoc addr addr-list) (warn ";;-- warn -- disassemble-one inst=~A con=~A addr=~A, addr-list=~A~%"
						inst con addr addr-list))
	   (list inst con (intern (string-upcase (format nil "L#x~X" addr)))))
	  (t (list inst con (rcb4-symbol addr :rom))))))
      (:return (list inst)) ;; (cons inst (cdr codelist)))
      (:ics (cons inst (list (pop codelist) ;; ics-no
			     (pop codelist) ;; size
			     (numseq-to-num codelist 2)
			     (numseq-to-num (cddr codelist) 2))))
      (:s-s (setq strs codelist)
	    (list :servo (pop codelist) (pop codelist) (numseq-to-num codelist 2)))
      (:m-s-cv
       (let (servos ids vel (id 0) b
		    (servo-vector
		     (make-array *rcb4-dof* :element-type integer-vector :initial-element 7500)))
	 ;;(setq servo-vector (instantiate float-vector *rcb4-dof*))
	 ;;(dotimes (i *rcb4-dof*) (setf (aref servo-vector i) 7500))
	 (setq ids (rcb4-servo-ids-from-5bytes codelist))
	 (dotimes (i 5) (push (pop codelist) servos))
	 (setq servos (reverse servos))
	 (setq vel (pop codelist))
	 (if (not (= (length ids) (/ (1- (length codelist)) 2)))
	     (warn ":m-s-cv bad length servos(length=~A):~A~% code(length=~A):~A~%"
		   (length ids) servos (/ (length codelist) 2) codelist))
	 (dolist (id ids)
	   (setf (aref servo-vector id) (numseq-to-num codelist 2))
	   (pop codelist) (pop codelist))
	 (list :servo ids vel servo-vector)
	 ))
      (:m-s-mv
       (let (servos ids b velocity-vector
		    (servo-vector
		     (make-array *rcb4-dof* :element-type integer-vector
				 :initial-element 7500)))
	 ;;(setq servo-vector (instantiate float-vector *rcb4-dof*))
	 ;;(dotimes (i *rcb4-dof*) (setf (aref servo-vector i) 7500))
	 (setq ids (rcb4-servo-ids-from-5bytes codelist))
	 (dotimes (i 5) (push (pop codelist) servos))
	 (setq servos (reverse servos))
	 (if (not (= (length ids)
		     (/ (1- (length codelist)) 3)))
	     (warn ":m-s-mv bad length servos(length=~A):~A~% code(length=~A):~A~%"
		   (length ids) servos (/ (length codelist) 3) codelist))
	 (dolist (id ids)
	   (setf (aref velocity-vector id) (pop codelist))
	   (setf (aref servo-vector id) (numseq-to-num codelist))
	   (pop codelist) (pop codelist))
	 (list :servo ids velocity-vector servo-vector)))
      ((:m-ss :stretch :speed :current-limit :temperature-limit)
       (let (servos ids subcom b s-vector)
	 (setq s-vector (instantiate integer-vector *rcb4-dof*))
	 (setq ids (rcb4-servo-ids-from-5bytes codelist))
	 (dotimes (i 5) (push (pop codelist) servos))
	 (setq servos (reverse servos))
	 (setq subcom (pop codelist))
	 (if (not (= (length ids) (1- (length codelist))))
	     (warn ":m-ss bad length servos(length=~A):~A~% code(length=~A):~A~%"
		   (length ids) servos (length codelist) codelist))
	 (dolist (id ids)
	   (setf (aref s-vector id) (pop codelist)))
	 (case
	  subcom
	  (1 (setq inst :stretch))
	  (2 (setq inst :speed))
	  (3 (setq inst :current-limit))
	  (4 (setq inst :temperature-limit)))
	 (list inst ids s-vector)))
      ((:version :ack) (cons inst codelist))
      ))
  )

(defun rcb4-inst-src (num)
  (elt #(:ram :ics :lit :rom) (logand num #x3)))

(defun rcb4-inst-dest (num)
  (elt #(:ram :ics :com :rom) (logand (ash num -4) #x3)))

(defun rcb4-servo-ids-from-5bytes
  (codelist &aux b ids c (id 0))  ;; servo-id: 0-35 same as ICS number
  (dotimes (i 5)
    (setq b (pop codelist))
    (dotimes (j 8)
      (if (and (= (logand b 1) 1) (< id 36)) (push id ids))
      (setq b (ash b -1))
      (incf id)))
  (reverse ids))

(defun rcb4-jump-conditional (num &aux ret)
  (dotimes (i 4)
    (if (logbitp i num)
	(push (elt #(:z= :c<> :z :c) i) ret)
	(push (elt #(:z<> :c= :nz :nc) i) ret)))
  ret)

;;;;;; assembler

(defun rcb4-assemble (lst &optional (motion-table-i 0) si-list (time-scale 1.0))
  (let (codes labels code straddr
	      (addr (rcb4-address (list :motiontable motion-table-i 0)))
	      offset loffset)
    (setq labels (rcb4-assemble-labels lst motion-table-i si-list)) ;; (lab . address)
    (dolist (p lst)
      (cond
       ((listp p)
	(setq code (rcb4-assemble-one p labels motion-table-i si-list time-scale))
	(setq addr (+ addr (length code)))
	(push code codes))
       ((stringp p)
	(setq straddr (read-from-string p))
	(setq offset (- straddr addr))
	(when (and offset loffset
		   (not (= offset loffset)))
	  (format t ";; offset difference ~A ~A at addr(~A) straddr(~A)~%"
		  offset loffset addr straddr))
	(setq loffset offset))))
    (reverse codes)))

(defun rcb4-assemble-labels (lst &optional (motion-table-i 0) si-list (time-scale 1.0))
  (let (labels code (addr (rcb4-address (list :motiontable motion-table-i 0))))
    (dolist (p lst)
      (cond ((listp p)
	     (setq code (rcb4-assemble-one p labels motion-table-i si-list time-scale))
	     (setq addr (+ addr (length code))))
	    ((symbolp p) (push (cons p addr) labels))))
    labels))

(defun rcb4-velocity (v)
  (if (> v 255) 255 (round v)))
(defun rcb4-assemble-one (code &optional labels table-i si-list (time-scale 1.0))
  (let* ((op (car code)) (opds (cdr code)) bytes)
    (setq
     bytes
     (case op
       ((:version :ack) (list (rcb4-op-code op)))
       (:return (list (rcb4-op-code op)))
       ((:move :mov)
	(rcb4-two-operand op (car opds) (cadr opds) nil))
       ((:and :or :xor :add :sub :mul :div :mod) ;; (op value dest flag)
	(rcb4-two-operand op (car opds) (cadr opds) (caddr opds)))
       (:not ;; (:not size dest flag)
	(rcb4-two-operand op (list :ram "#x0" (car opds)) ;; size
			  (cadr opds) (caddr opds)))
       (:shift ;; right (:shift shift size dest flag)
	(rcb4-two-operand
	 op
	 (list :ram (ash (logand (car opds) #xff) 8) (cadr opds))
	 (caddr opds) (cadddr opds)))
       ((:jump :call)
	(rcb4-jc-code op (rcb4-address (cadr opds) labels) (car opds)))
       (:ics ;; (:ics ics-no size src-address dest-address)
	(let ((ics-no (car opds)) (size (cadr opds))
	      (saddr (caddr opds)) (daddr (cadddr opds)))
	  (list (rcb4-op-code op) ics-no size
		(logand saddr #xff) (logand (ash saddr -8) #xff)
		(logand daddr #xff) (logand (ash daddr -8) #xff))))
       ((:servo :s-s :m-s-cv :m-s-mv)
	(let* ((no (if si-list si-list (car opds)))
	       (velocity (cadr opds)) (position (caddr opds)))
	  (if
	      (numberp no)
	      (list (rcb4-op-code :s-s)
		    no (rcb4-velocity (* time-scale velocity))  ;; single servo (:s-s no velocity position)
		    (logand position #xff) (ash position -8))
	    (if
		(numberp velocity) ;; multi-servo-(single constant)-velocity
		`(,(rcb4-op-code :m-s-cv) ,@(rcb4-servo-ids-to-5bytes no)
		  ,(rcb4-velocity (* time-scale velocity))
		  ,@(rcb4-servo-positions no position))
	      `(,(rcb4-op-code :m-s-mv)  ;; multi-servo-multi velocities
		,@(rcb4-servo-ids-to-5bytes no)
		,@(rcb4-servo-vels-poss no (mapcar #'(lambda (v) (rcb4-velocity (* time-scale v)))
						   velocity)
					position))))))
       ((:m-ss :stretch :speed :current-limit :temperature-limit)
	(let* ((subcom (case op (:stretch #x01)
			     (:speed #x02)
			     (:current-limit #x03)
			     (:temperature-limit #x04)
			     (:m-ss  (pop opds))))
	       (nos (if si-list si-list (car opds)))
	       (vals (rcb4-servo-svector nos (cadr opds))))
	  `(,(rcb4-op-code :m-ss) ,@(rcb4-servo-ids-to-5bytes nos) ,subcom ,@vals)))
       ))
    (push (+ 2 (length bytes)) bytes)
    `(,@bytes ,(rcb4-checksum bytes))))

(defun rcb4-checksum (bytes &optional (n (length bytes)) &aux (ret 0))
  (dotimes (i n) (setq ret (+ ret (logand (elt bytes i) #xff))))
  (logand ret #xff))

(defun rcb4-src-lit-bytes (src)
  (cond
   ((numberp src) (num-to-bytelist src))
   ((stringp src) (coerce src cons))
   ((vectorp src)
    (apply #'append
	   (map cons #'(lambda (x) (num-to-numlist x 2))
		(coerce src integer-vector))))
   ((consp src)
    (append
     (rcb4-src-lit-bytes (car src))
     (rcb4-src-lit-bytes (cdr src))))
   ((atom src) nil)))

(defun rcb4-src-bytes (src)
  (case (pop src)
    (:ram (append (rcb4-addr-numlist (car src) 2)  ;; (:ram addr size)
		  (list  (cadr src))))
    (:ics (list (assocdr :offset src) ;; 00h - FFh (ics offset ics-id size)
		(assocdr :id src) ;; 0 - 35
		(assocdr :size src)))  ;; 1 - 128
    (:lit (rcb4-src-lit-bytes src))
    (:rom (append (rcb4-addr-numlist (car src) 3)
		  (list  (cadr src))))))  ;; size

(defun rcb4-dest-bytes (dest)
  (case (pop dest)
    (:ram (rcb4-addr-numlist (car dest) 3))
    (:ics (list (assocdr :id dest) (assocdr :offset dest) 0))
    (:com (list 0 0 0))
    (:rom (rcb4-addr-numlist (car dest) 3))))

(defun rcb4-op-code (op)
  (cdr (assoc op *rcb4-instructions*)))

(defun rcb4-cond-code (cond-list &aux (sum 0))
  (dolist (c cond-list)
    (setq sum
	  (logior
	   sum
	   (case c (:z= #x01) (:c<> #x02) (:z #x04) (:c #x08)
		 (t 0)))))
  sum)

(defun rcb4-jc-code (op addr cond)
  (cons (rcb4-op-code op)
	(append (list (logand addr #xff)
		      (logand (ash addr -8) #xff)
		      (logand (ash addr -16) #xff))
		(list (rcb4-cond-code cond)))))

(defun rcb4-two-operand
  (op src dest &optional flag)
  (cons (rcb4-op-code op)
	(cons (rcb4-port-byte src dest flag)
	      (append (rcb4-dest-bytes dest)
		      (rcb4-src-bytes src)))))

(defun rcb4-servo-positions (ids fvector &aux id buf d)
  (let* ((flen (length fvector))
	 (fv (instantiate vector flen)))
    (setq ids (coerce ids cons))
    (dolist (id ids)
      (if (numberp id)
	  (setf (elt fv id) (round (elt fvector id)))))
    (dotimes (i flen)
      (when (setq d (elt fv i))
	(push (logand d #xff) buf)
	(push (logand (ash d -8) #xff) buf)))
    (reverse buf)))

(defun rcb4-servo-vels-poss (ids vvector pvector &aux p buf)
  (dolist (id ids)
    (push (logand (round (elt vvector id)) #xff) buf)
    (setq p (round (elt pvector id)))
    (push (logand p #xff) buf)
    (push (logand (ash p -8) #xff) buf))
  (reverse buf))

(defun rcb4-servo-svector (ids svector &aux buf)
  (dolist (id ids)
    (push (logand (round (elt svector id)) #xff) buf))
  (reverse buf))

(defun rcb4-servo-ids-to-5bytes (seq &aux (ids (list 0 0 0 0 0)) c)
  ;; servo-id: 0-35 as ICS number
  (setq seq (coerce seq cons))
  (dolist (c seq)
    (when (numberp c)
      (setf (elt ids (/ c 8))
	    (logior (elt ids (/ c 8)) (ash 1 (mod c 8))))))
  ids)

(defun rcb4-port-byte (src dest &optional flag)
  (let ((v (if flag #x80 #x0)))
    (logior v (logior (ash (rcb4-port-2bit dest) 4)
		      (rcb4-port-2bit src)))))

(defun rcb4-port-2bit (src/dest)
  (cond
   ((numberp src/dest) 0) ;; same as ram
   ((atom src/dest) 2) ;; com
   (t
    (case (car src/dest)
      (:ram 0) ;; RAM data
      (:ics 1) ;; ICS data
      (:lit 2) ;; literal
      (:com 2) ;; com port output
      (:rom 3) ;; ROM data
      (t (warn "bad instruction port") 0))))
  )

(defun rcb4-jump-labels (acodes)
  (let (jump-labels)
    (dolist (a acodes)
      (when (and (listp a)
		 (or (eq :jump (car a))
		     (eq :call (car a))))
	(push (elt a 2) jump-labels)))
    jump-labels))


(defun rcb4-deconversion (acodes ri &optional (jump-labels (rcb4-jump-labels acodes)))
  " acodes -> ccodes "
  (let (res svids tm sv av avids (conf (cddr (send ri :config))) v
	    hold exception (i 0) (jml (send ri :robot :joint-list :method-name))
	    plist)
    (dolist (a acodes)
      (cond
       ((listp a)
	(case
	 (car a)
	 (:servo
	  (setq svids (cadr a) tm (caddr a) sv (elt a 3))
	  (cond
	   ((listp svids)
	    (setq sv (copy-seq sv))
	    (setq av (copy-seq (send ri :servo-vector-to-angle-vector sv)))
	    (setq plist nil)
	    (dolist (id svids)
	      (if (>= (elt sv id) #x7fff)
		  (dolist (ai (send ri :servo-index-to-angle-index id))
		    (format t ";; rcb4-deconversion sid:~A value:~A~%" id (elt sv id)))
		(dolist (ai (send ri :servo-index-to-angle-index id))
		  (setq plist (cons (elt jml ai) (cons (elt av ai) plist)))
		  )))
	    (push (list :angle-time-plist tm (copy-seq plist)) res)
	    )
	   (t (push a res))))
	 (:stretch
	  (setq svids (cadr a) sv (caddr a))
	  (cond
	   ((listp svids)
	    (setq plist nil)
	    (dolist (id svids)
	      (dolist (ai (send ri :servo-index-to-angle-index id))
		(setq plist (cons (elt jml ai) (cons (elt sv id) plist)))))
	    (push (list :stretch-plist (copy-seq plist)) res)
	    )
	   (t (push a res))))
	 (t (push a res)))) ;; end of case
       ((member a jump-labels) ;; label
	(when *rcb4asm-debug* (format t ";; deconversion i:(~A) label a=~A is left~%" i a))
	(push a res))
       (t 
	;;(push a res)
	))
      (incf i)
      )
    (reverse res))
  )

(defun rcb4-conversion (ccodes ri number &optional limbs)
  " ccodes -> acodes "
  (let (res (addr (rcb4-address (list :motiontable number 0)))
	    (sjlist (send ri :servo-config-list))
	    a lab labels)
    (dolist (c ccodes)
      (cond
       ((listp c)
	(case
	 (car c)
	 (:angle-time-plist
	  (let* (svids si
		       (conf (send ri :servo-config-list))
		       (robo (send ri :robot))
		       (sorted-svids (send robo :limbs-sorted-sids limbs))
		       (jml (send ri :robot :joint-list :method-name))
		       (tm (elt c 1)) (plist (elt c 2))
		       (alist (plist-to-alist plist))
		       sv v)
	    (dolist (al alist)
	      (when (send (send robo (car al)) :joint-angle-range-over (cadr al))
		(format t ";;mi=~A range-over al=~A~%" number al)))
	    (send robo :angle-alist alist)
	    (setq sv (send ri :angle-vector-to-servo-vector (send robo :angle-vector)))
	    (setq svids nil)
	    (dolist (al alist)
	      (setq si (send ri :robot (car al) :servo-index))
	      (setq svids (append si svids)))
	    (setq svids (sort svids #'<))
	    (if (set-difference svids sorted-svids)
		(format t "; svids(len:~A) <> sorted-svids(len:~A)~%" (length svids) (length sorted-svids))
	      (setq svids (intersection svids sorted-svids)))
	    (setq c (list :servo svids tm (copy-seq sv)))
	    ))
	 (:stretch-plist
	  (let* (svids si
		       (conf (send ri :servo-config-list))
		       (robo (send ri :robot))
		       (sorted-svids (send robo :limbs-sorted-sids limbs))
		       (jml (send ri :robot :joint-list :method-name))
		       (plist (elt c 1))
		       (alist (plist-to-alist plist))
		       (svector (make-sequence integer-vector (ri . sv-length) :initial-element 0))
		       svid-slist)
	    (setq svid-slist nil)
	    (dolist (al alist)
	      (setq svid-slist
		    (append
		     (mapcar #'(lambda (si) (list si (cadr al))) (send ri :robot (car al) :servo-index))
		     svid-slist)))
	    (dolist (ss svid-slist)
	      (pushnew (car ss) svids)
	      (setf (elt svector (car ss)) (cadr ss)))
	    (if (set-difference svids sorted-svids)
		(format t "; svids(len:~A) <> sorted-svids(len:~A)~%" (length svids) (length sorted-svids)))
	    (setq c (list :stretch (sort svids #'<) svector))
	    ))
	 )
	(setq lab (intern (string-upcase (format nil "L#x~X" addr))))
	(push (cons lab addr) labels)
	(push lab res)
	(push c res)
	(setq addr (+ addr (length (rcb4-assemble-one c labels number)))))
       (t
	(unless (eq c (intern (string-upcase (format nil "L#x~X" addr))))
	  (if *rcb4asm-debug* (format t ";; :conversion mi=~A c=~A, addr=~X~%" number c addr))))))
    (reverse res))
  )

;; old
;; generate :angle-vector
;;
(defun rcb4-deconversion-avector (acodes ri &optional (jump-labels (rcb4-jump-labels acodes)))
  " acodes -> ccodes "
  (let (res svids tm sv av avids (conf (cddr (send ri :config))) v
	    free hold exception (i 0))
    (dolist (a acodes)
      (cond
       ((listp a)
	(case
	 (car a)
	 (:servo
	  (setq svids (cadr a) tm (caddr a) sv (elt a 3))
	  (setq free (make-sequence vector (send ri :av-length)))
	  (cond
	   ((listp svids)
	    (dolist (id svids)
	      (if (setq v (find id conf :key #'car))
		  (dolist (ai (send ri :servo-index-to-angle-index id))
		    (setf (elt free ai) t))
		  (if *rcb4asm-debug*
		      (format t ";;deconversion acodes[~A] servo id: ~A svids:~A~%" i id svids))))
	    ;;
	    (setq av (copy-seq (send ri :servo-vector-to-angle-vector (copy-seq sv))))
	    (setq sv (copy-seq sv))
	    (dolist (id svids)
	      (if (>= (elt sv id) #x7fff)
		  (dolist (ai (send ri :servo-index-to-angle-index id))
		    (setf (elt free ai) (elt sv id)))
		(dolist (ai (send ri :servo-index-to-angle-index id))
		  (setf (elt free ai) t))))
	    ;;
	    (when free
	      (setq exception nil)
	      (dotimes (i (send ri :av-length))
		(if (or (numberp (elt free i)) (null (elt free i)))
		    (push i exception))))
	    ;;(push (list :angle-vector av tm (reverse avids) (copy-seq (send ri :free-vector))) res)
	    #|		(if exception
	    (push (list :angle-vector av tm (copy-seq free)) res)
	    (push (list :angle-vector av tm) res)) |#
	    (push (list :angle-vector av tm (copy-seq free)) res)
	    )
	   (t (push a res))))
	 (t (push a res)))) ;; end of case
       ((member a jump-labels) ;; label
	(when *rcb4asm-debug* (format t ";; deconversion i:(~A) label a=~A is left~%" i a))
	(push a res))
       (t 
	;;(push a res)
	))
      (incf i)
      )
    (reverse res))
  )

(defun rcb4-conversion-avector (ccodes ri number &optional limbs)
  " ccodes -> acodes "
  (let (res (addr (rcb4-address (list :motiontable number 0)))
	    a lab labels)
    (dolist (c ccodes)
      (cond
       ((listp c)
	 (when
	     (eq (car c) :angle-vector) ;; av tm exception
	   (let (svids free si (sorted-svids (send ri :robot :limbs-sorted-sids limbs))
		       (av (elt c 1)) (tm (elt c 2)) (exception (elt c 3))
		       sv v (conf (send ri :servo-config-list)))
	     (when exception
	       ;;(format t ";; exept=~A~%;; free =~A~%" exception free)
	       (setq free (copy-seq exception))
	       )
	     ;;(setq sv (coerce (send ri :angle-vector-to-servo-vector av free) float-vector))
	     ;;(setq sv (coerce (copy-seq (send ri :angle-vector-to-servo-vector av free)) integer-vector))
	     (setq sv (coerce (send ri :angle-vector-to-servo-vector av) integer-vector))
	     ;;(setq svids (send ri :servo-sorted-ids))
	     #|
	     (dolist (id avids)
	     (setq v (find id conf :key #'cadr))
	     (if v
	     (push (car v) svids)
	     (format t "; conversion no angle id: ~A conf=~A~%" id conf)))
	     |#
	     (setq svids nil)
	     (unless free (setq free (instantiate vector (send ri :av-length))))
	     (dolist (si sorted-svids)
	       (dolist (ai (send ri :servo-index-to-angle-index si))
		 (when (elt free ai)
		   (setq v (find si conf :key #'car))
		   (if v
		       (pushnew si svids)
		     (format t "; conversion no angle v: ~A conf=~A~%" v conf))))
	       )
	     (setq svids (reverse svids))
	     (when (set-difference svids sorted-svids)
	       (format t "; svids(len:~A) <> sorted-svids(len:~A)~%" (length svids) (length sorted-svids)))
	     (setq c (list :servo svids tm (copy-seq sv)))
	     ))
	 (setq lab (intern (string-upcase (format nil "L#x~X" addr))))
	 (push (cons lab addr) labels)
	 (push lab res)
	 (push c res)
	 (setq addr (+ addr (length (rcb4-assemble-one c labels number)))))
	(t
	 (unless (eq c (intern (string-upcase (format nil "L#x~X" addr))))
	   (if *rcb4asm-debug* (format t ";; :conversion mi=~A c=~A, addr=~X~%" number c addr))))))
    (reverse res))
  )

(provide :rcb4asm)
