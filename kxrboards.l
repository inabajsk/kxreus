;;;
;;; KXR Electronic Circuit Board
;;;	2021.3.20 created
;;;	2021.4.24 csv CAD file reading
;;	CSV(Comma Separated Value) File handler generated from Altium
;;
;;	*footprint-list* for size or STL file to each Footprint name list
;;	(get-footprint-names) -> for *footprint-list*
;;
;;	(read-board-chips "Chips/board.csv")
;;	(show-board-chips "Chips/board.csv") -> show 3D model of the board
;;
;;	(show-kxrboard-imu) -> show 3D models
;;	(detect-new-footprint "Chips/Pick .... .csv")
;;
;;	STP(Standard for the Exchange of Product Data) File read
;;	(read-stp-file "fname)
;;
(require :utils)
;;(require :read-wrl)
;;(require :read-stl)

(defun split-line-old (str &optional (char #\,))
  (let ((i 0) (n (length str)) p ret (s str))
    (while (< i n)
      (cond
       ((= (elt s i) #\")
	(setq p (position #\" s :start (1+ i)))
	(if p (setq p (1+ p))))
       (t (setq p (position char s :start i))))
      (if (and p (<= p n))
	  (push (subseq s i p) ret)
	(push (subseq s i) ret))
      (if p (setq i (1+ p)) (setq i n)))
    (reverse ret)))

(defun split-line-old0 (str &optional (char #\,))
  (let ((i 0) (n (length str)) p ret (s str))
    (while (< i n)
      (cond
       ((= (elt s i) #\")
	(incf i)
	(setq p (position #\" s :start i))
	(if p (+ p 2) (setq p i)))
       (t (setq p (position char s :start i))))
      (if (and p (<= p n))
	  (push (subseq s i p) ret)
	(push (subseq s i) ret))
      (if p (setq i (1+ p)) (setq i n)))
    (reverse ret)))

(defun split-line (str &optional (char #\,))
  (let ((i 0) (d 0) (n (length str)) p ret (s str))
    (while (< i n)
      (cond
       ((= (elt s i) #\")
	(incf i)
	(setq p (position #\" s :start i))
	(setq d 2))
       (t (setq p (position char s :start i))
	  (setq d 1)))
      (if (and p (<= p n))
	  (push (subseq s i p) ret)
	(push (subseq s i) ret))
      (if p (setq i (+ p d))
	(setq i n)))
    (reverse ret)))

(defun read-csv-lines (fname &optional (char #\,))
  (mapcar #'split-line (read-lines fname)))

(defun find-2d-list-if (pred ll)
  (let ((i 0) j)
    (catch 'find-2d-list-if
      (dolist (l ll)
	(setq j 0)
	(dolist (c l)
	  (if (funcall pred c) 
	      (throw 'find-2d-list-if (list c i j)))
	  (incf j))
	(incf i))
      nil)
    ))

(defclass electronic-chip :super geo::bodyset
  :slots (comment layer footprint x y r description))

(defmethod electronic-chip
  (:init (l &optional (thickness 1) (offset #f(0 0 0)))
	 (print l)
	 (setq
	  name (elt l 0)
	  comment (elt l 1)
	  layer (elt l 2)
	  footprint (elt l 3)
	  x (read-from-string (elt l 4))
	  y (read-from-string (elt l 5))
	  r (read-from-string (elt l 6)))
	 (if (> (length l) 7)
	     (setq description (elt l 7)))
	 (send-super :init (make-cascoords)
		     :bodies (send (send self :create-bodyset) :bodies))
	 (dolist (b (send self :bodies)) (send self :assoc b))
	 (cond
	  ((substringp "Top" layer)
	   (send self :locate (v+ (float-vector x y 0) offset))
	   (send self :rotate (deg2rad (- r 180)) :z)
	   )
	  (t (send self :locate (v+ (float-vector x y (- thickness)) offset))
	     (send self :rotate pi :y)
	     ;;(send self :rotate (deg2rad r) :z)
	     (send self :rotate (deg2rad (- r)) :z)
	     ))
	 self)
  (:create-bodyset
   ()
   (let* ((size (cdr (assoc footprint *footprint-list* :test #'string=)))
	  x/2 y/2 z (*contact-threshold* 0.00001)
	  bs shape shape-)
     (when size
       (cond
	((consp size)
	 (setq x/2 (/ (elt size 0) 2.0) y/2 (/ (elt size 1) 2.0) z (elt size 2))
	 (setq shape
	       (make-prism (list (float-vector x/2 y/2 0) (float-vector x/2 (- y/2) 0)
				 (float-vector (- x/2) (- y/2) 0) (float-vector (- x/2) y/2 0))
			   z)))
	(t (setq bs (wrl2eus (format nil "~A/~A" *rcb4eus-dir* size)))))
       (cond
	(bs)
	((substringp "Capacitor" description) (send shape :set-color :yellow))
	((substringp "Resistor" description) (send shape :set-color :rosybrown))
	;;((substringp "SM03B" comment)
	;;(send shape :set-color :whitesmoke))
	;;((substringp "SM06" comment)
	;;(send shape :set-color :whitesmoke))
	;;((substringp "S3B" comment)
	;;(send shape :set-color :whitesmoke))
	;;((substringp "ICM" comment)
	;;(send shape :name "imu")
	;;(send shape :set-color :blue))
	;;((substringp "VCNL" comment)
	;;(send shape :set-color :gray30))
	;;((substringp "stm" comment)
	;;(send shape :set-color :red))
	)
       (if shape (setq bs (instance bodyset :init (make-cascoords)
				    :bodies (list shape))))
       bs)))
  )

(defun read-chip-table (&optional (fname "Chips/KJS-01/Pick_Place_for_JointBaseSensorboard.csv"))
  (let* ((ll (read-csv-lines fname))
	 (d-pos (find-2d-list-if #'(lambda (x) (substringp "Designator" x)) ll)))
    (nthcdr (1+ (elt d-pos 1)) ll)
    ))

(defun read-board-chips (&optional
			 (csv "Chips/KJS-01/Pick_Place_for_JointBaseSensorboard.csv")
			 (board "Chips/KJS-01/KJS01-Board.wrl")
			 (thickness 1)
			 (offset #f(0 0 0))
			 &aux new)
  (if (setq new (detect-new-footprints csv))
      (format t ";; you have to put new footprint ~S to *footprint-list*~%" new)
    (let (lst)
      (dolist (l (read-chip-table csv))
	(push (instance electronic-chip :init l thickness offset) lst))
      (push  (wrl2eus board 1.0) lst)
      (reverse lst))))

(defun read-kjs01-chips nil
  (read-board-chips "Chips/KJS-01/Pick_Place_for_JointBaseSensorboard.csv"
		    "Chips/Parts/KJS01-Board.wrl"))
(defun read-kjs02-chips nil
  (read-board-chips "Chips/KJS-02/Pick_Place_for_KJS-02.csv"
		    "Chips/Parts/KJS02-Board.wrl"))
(defun read-kjs03-chips nil
  (read-board-chips "Chips/KJS-03-revA/Pick_Place_for_KJS-03-revA.csv"
		    "Chips/KJS-03-revA/KJS03-Board.wrl" 1.6)) ;; #f(-3 -7 0)
(defun read-kjs03-extend-chips nil
  (read-board-chips "Chips/KJS-03-revAextend/Pick_Place_for_KJS-03-revAextend.csv"
		    "Chips/KJS-03-revAextend/KJS-03-revAextend-onlyboard.wrl" 1.6))
(defun read-armh7b-chips nil
  (read-board-chips "Chips/stm32h7_kondo/Pick_Place_for_stm32h7_kondo.csv"
		    "Chips/Parts/ARMH7-Board.wrl"))
(defun read-max10a-chips nil
  (read-board-chips "Chips/FPGA_kondo_original/Pick_Place_for_FPGA_kondo_original.csv"
		    "Chips/Parts/FPGA-Board.wrl"))
(defun read-max10b-chips nil
  (read-board-chips "Chips/FPGA_kondo/Pick_Place_for_FPGA_kondo.csv"
		    "Chips/Parts/FPGA-Board.wrl"))

(defun show-kjs01 nil (objects (read-kjs01-chips)))
(defun show-kjs02 nil (objects (read-kjs02-chips)))
(defun show-kjs03-revA nil (objects (read-kjs03-chips)))
(defun show-kjs03-revAextend nil (objects (read-kjs03-extend-chips)))
(defun show-armh7b nil (objects (read-armh7b-chips)))
(defun show-max10a nil (objects (read-max10a-chips)))
(defun show-max10b nil (objects (read-max10b-chips)))

(defun draw-kjs01 nil (objects (list (wrl2eus "Chips/KJS-01/JointBaseSensorboard.wrl"))))
(defun draw-kjs02 nil (objects (list (wrl2eus "Chips/KJS-02/KJS-02.wrl"))))
(defun draw-kjs03-revAextend nil (objects (list (wrl2eus "Chips/KJS-03-revAextend/KJS-03-revAextend.wrl"))))
(defun draw-kjs03-revA nil (objects (list (wrl2eus "Chips/KJS-03-revA/KJS-03-revA.wrl"))))
(defun draw-armh7b nil (objects (list (wrl2eus "Chips/stm32h7_kondo.wrl"))))
(defun draw-max10a nil (objects (list (wrl2eus "Chips/FPGA_kondo_original.wrl"))))
(defun draw-max10b nil (objects (list (wrl2eus "Chips/FPGA_kondo.wrl"))))

(defun find-csv-position (str ll &aux p l (i 0))
  (catch 'find-csv-position
    (dolist (l ll)
      (if (setq p (position str l :test #'substringp))
	  (throw 'find-csv-position (list i p l)))
      (incf i))))
(defun chip-names (ll) (mapcar #'car ll))
(defun get-footprint-names (&optional (fname "Chips/KJS-01/Pick_Place_for_JointBaseSensorboard.csv"))
  (let ((p (find-csv-position "Footprint" (read-csv-lines fname)))
	(col 3) (ll (read-chip-table fname)))
    (if p (setq col (elt p 1)))
    (remove-duplicates (mapcar #'(lambda (x) (elt x col)) ll) :test #'string-equal)))

(defun detect-new-footprints (&optional (fname "Chips/KJS-01/Pick_Place_for_JointBaseSensorboard.csv"))
  (let* ((l (get-footprint-names fname))
	 (fp (mapcar #'car *footprint-list*))
	 (all (remove-duplicates (append l fp) :test #'string-equal))
	 )
    (set-difference all fp :test #'string-equal)))

(setq *footprint-list*
      '(
	("induct4*4" . "Chips/Parts/Inductor4.wrl")	;; Inductor MAX10A
	("C1206" . "Chips/Parts/1N5819-C1206.wrl")	;; Diode MAX10A
	("SG-210STF" . "Chips/Parts/SG-210STF.wrl") ;; Xtal
	("10M16SAU169" . "Chips/Parts/MAX10-10M16SAU169C8G.wrl")
	("1005/0402IND" 1.0 0.5 0.4)
	("2012/0805CAP" 2.0 1.2 0.5)
	;;
	("SOP65P490X110-8N" . "Chips/Parts/SOP65P490X110-8N.wrl") ;; Amp 
	("UFQFPN32" . "Chips/Parts/STM32L422KBU6_UFQFPN32.wrl")
	("HSFPAR003" . "Chips/Parts/HSFPAR003.wrl") ;; Pressure Sensor
	("1125R-SMT-4P-EDA" . "Chips/Parts/GROVE-4PIN-ANGLE.wrl")  ;;
	("SMT-0540-T-9-R" . "Chips/Parts/Buzzer.wrl")	;; SMT-0540-T-9-R Buzzer
	("IRLML0030TRPbF" . "Chips/Parts/IRLML0030TRPBF.wrl")	;; IRLML0030TRPbF 3pin FET
	("DIOD-SOD323-2-A_V" . "Chips/Parts/DIOD-SOD323-2-A_V.wrl") ;; High Speed Diode
	("1006DIODE" . "Chips/Parts/1006DIODE.wrl")  ;; LED
	("VH3.96"  . "Chips/Parts/B2PS-VH3.96.wrl") ;; ARMH7 Power 2pin Connector
	("SEEED_110990030" . "Chips/Parts/GROVE-4PIN-VERT.wrl") ;; Vertical Grove
	;;
	("LQFP100_L" . "Chips/Parts/STM32H7-LQFP100_L.wrl")  ;; STM32H7
	("UFQFPN48" . "Chips/Parts/STM32F411CEU6_UFQFPN48.wrl") ;; STM32F4
	;;
	("SPM5020-LR" . "Chips/Parts/SPM5020-LR.wrl") ;; Inductor
	("L6983C50QTR" . "Chips/Parts/L6983C50QTR.wrl") ;; Switching Legulator
	("XTALSMD8" . "Chips/Parts/XTALSMD8.wrl")  ;; Xtal
	("TSWITCH" . "Chips/Parts/TSWITCH.wrl")	;; Switch
	("BM06B-SRSS-TB" . "Chips/Parts/BM06B-SRSS-TB.wrl") ;; SH 6pin ST-link Connector
	("3528/1411CAP_TANT" . "Chips/Parts/CAP_TANT.wrl")	;; Tantalum Capacitor
	("MPU-9250" . "Chips/Parts/MPU-9250.wrl") ;; IMU  ;;
	("LD39200PU33R" . "Chips/Parts/LD39200PU33R.wrl") ;; 3x3 Regulator,(3.3V 2A 9.95,4.15) (5V 2A 13.5,14.3)
	("1005/0402CAP" 1.0 0.5 0.5)
	("1005/0402_035" 1.0 0.5 0.5) ;; to be check
	("1005/0402_055" 1.0 0.5 0.5) ;; to be check
	("1005/0402RES" 1.0 0.5 0.4)
	("HTSOP-J8" . "Chips/Parts/BD50HC5WEFJ.wrl") ;; 3.9 4.9 1.0)  ;; BD50HC5WEFJ 1.5A Regulator
	("*PQFN50P250X300X97-14N" . "Chips/Parts/ICM-20600.wrl") ;; 3.0 2.5 0.91) ;; ICM-20600
	("VCNL4040M3OE" . "Chips/Parts/VCNL4040M30E.wrl") ;; 2.0 4.0 1.1  PS sensor
	("HVQFN24" . "Chips/Parts/PCA9547BS.wrl") ;; 4 4 0.85 315deg   multiplexer 
	("SOT25" . "Chips/Parts/AP7343DQ.wrl") ;; 2.8 2.9 1.3  1.1V LDO Regulator
	("UFQPN20" . "Chips/Parts/STML011f4u6tr.wrl") ;; 3.0 3.0 1.2  CPU STM32L0
	("SW-2PIN" . "Chips/Parts/SW-2PIN.wrl") ;;  6.1 3.7 2.5 Switch Button
	("1608/0603_050" 1.6 0.8 0.5) ;; to be check
	("1608/0603_035" 1.6 0.8 0.5) ;; to be check
	("1608/0603_045" 1.6 0.8 0.5)
	("1608/0603IND"  1.6 0.8 0.5)
	("1608/0603CAP" 1.6 0.8 0.5)
	("1608/0603LED"  . "Chips/Parts/1608LED.wrl") ;; 1.6 0.8 0.5 Chips/Parts/LED1608.wrl
	("1608/0603_08" 1.6 0.8 0.5)
	("1608/0603_09" 1.6 0.8 0.5)
	("B3B-ZR-SM4-TF" . "Chips/Parts/B3B-ZR-SM4-TF.wrl") ;; ZH 3pin Straight Connector
	("S3B-ZR-SM4A-TF" . "Chips/Parts/S3B-ZR-SM4A-TF.wrl")	 ;; 7.0 5.0 4.0 ZH 3pin RightAngle connector 
	("SM03B-NSHSS-TB" . "Chips/Parts/SM03B-NSHSS-TB.wrl")  ;; 5.0 6.0 4.5 NSH 3pin RightAngle connector
	("SM04B-SRSS-TB" . "Chips/Parts/SM04B-SRSS-TB.wrl")  ;; 8.0 4.0 3.0 SH 4pin RightAngle
	("SM05B-SRSS-TB" . "Chips/Parts/SM05B-SRSS-TB.wrl")  ;; 8.0 4.0 3.0 SH 5pin RightAngle
	("SM06B-SRSS-TB" . "Chips/Parts/SM06B-SRSS-TB.wrl")  ;; 8.0 4.0 3.0 SH 6pin RightAngle
	))

;;; STP file handler
(defun read-end-semicolon-file (fname &aux (char #\;))
  (let ((ll) (line "") ln (eof (cons nil nil)) p)
    (with-open-file
     (f fname)
     (while (not (eql (setq ln (read-line f nil eof)) eof))
       (cond
	((find char ln)
	 (push (concatenate string line ln) ll)
	 (setq line ""))
	(t (setq line (concatenate string line ln))))
       ))
    (nreverse ll)))

(defun read-stp-file (fname) (read-end-semicolon-file fname))

;;;
(defun cube-side-chamfer (c len)
  (let ((xyz (cdr (assoc :cube (send c :csg))))
	(l2r (/ len (sqrt 2)))
	x y z b-)
    (when xyz
      (setq x (/ (elt xyz 0) 2) y (/ (elt xyz 1) 2) z (/ (elt xyz 2) 2))
      (setq b- (make-cube l2r (* 3 len) (* 4 z)))
      (send b- :rotate (/ pi 4) :z :world)
      (send b- :locate (float-vector x y 0) :world)
      (setq c (body- c b-))
      (setq b- (make-cube l2r (* 3 len) (* 4 z)))
      (send b- :rotate (/ pi -4) :z :world)
      (send b- :locate (float-vector x (- y) 0) :world)
      (setq c (body- c b-))
      (setq b- (make-cube l2r (* 3 len) (* 4 z)))
      (send b- :rotate (/ pi -4) :z :world)
      (send b- :locate (float-vector (- x) y 0) :world)
      (setq c (body- c b-))
      (setq b- (make-cube l2r (* 3 len) (* 4 z)))
      (send b- :rotate (/ pi 4) :z :world)
      (send b- :locate (float-vector (- x) (- y) 0) :world)
      (setq c (body- c b-))
      c)))

(defun kxr-rcb4-size-board ()
  (let* ((b (make-cube 35 30 1.3))
	 (cyl (make-cylinder 1.3 10)))
    (send cyl :locate (float-vector  15 12.5 -4) :world)
    (setq b (body- b cyl))
    (send cyl :locate (float-vector  15 -12.5 -4) :world)
    (setq b (body- b cyl))
    (send cyl :locate (float-vector  -15 -12.5 -4) :world)
    (setq b (body- b cyl))
    (send cyl :locate (float-vector  -15 12.5 -4) :world)
    (setq b (body- b cyl))
    (send b :set-color :darkblue)
    b)
  )

(defun kxr-jointbase-size-board ()
  (let* ((b (make-fillet-cube 27 27 1.3 3.5))
	 (b1- (make-cube 16 10 10))
	 (b2- (make-cube 6.5 13 10))
	 (cyl (make-cylinder 1.3 10)))
    (send cyl :locate (float-vector  10.5 10.5 -4) :world)
    (setq b (body- b cyl))
    (send cyl :locate (float-vector  10.5 -10.5 -4) :world)
    (setq b (body- b cyl))
    (send cyl :locate (float-vector  -10.5 -10.5 -4) :world)
    (setq b (body- b cyl))
    (send cyl :locate (float-vector  -10.5 10.5 -4) :world)
    (setq b (body- b cyl))
    ;;
    (send b1- :locate (float-vector 0 -15 -4) :world)
    (setq b (body- b b1-))
    (send b1- :locate (float-vector 0 15 -4) :world)
    (setq b (body- b b1-))
    ;;
    (send b2- :locate (float-vector 0 -15 -4) :world)
    (setq b (body- b b2-))
    (send b2- :locate (float-vector 0 15 -4) :world)
    (setq b (body- b b2-))
    (send b :set-color :darkred)
    b)
  )

(defun kxr-power-connector ()
  (let ((b (make-cube 15 8 8))
	(b- (make-cube 10 10 8))
	)
    (send b- :locate (float-vector 6 0 -1.5))
    (setq b (body- b b-))
    (send b :set-color :whitesmoke)
    b))

(defun kxr-zh-connector (&optional (p #f(0 0 0)) (color :whitesmoke) rotate angle)
  (let ((b (make-cube 3.5 7.4 6))
	(b- (make-cube 2.5 6.4 5)))
    (send b- :locate #f(0 0 2) :world)
    (setq b (body- b b-))
    (if angle (send b :rotate pi/2 :-y :world))
    (if rotate (send b :rotate pi/2 :z :world))
    (send b :set-color color)
    (send b :locate p :world)
    b))

(defun kxr-sh-connector (&optional (p #f(0 0 0)) (color :whitesmoke) rotate angle)
  (let ((b (make-cube 3 8 6))
	(b- (make-cube 2 7 5)))
    (send b- :locate #f(0 0 2) :world)
    (setq b (body- b b-))
    (if angle (send b :rotate pi/2 :y :world))
    (if rotate (send b :rotate pi/2 :z :world))
    (send b :set-color color)
    (send b :locate p :world)
    b))

(defun kxr-nsh-connector (&optional (p #f(0 0 0)) (color :whitesmoke) rotate angle)
  (let ((b (make-cube 4 5 6))
	(b- (make-cube 3 4 5)))
    (send b- :locate #f(0 0 2) :world)
    (setq b (body- b b-))
    (if angle (send b :rotate angle :y :world))
    (if rotate (send b :rotate pi/2 :z :world))
    (send b :set-color color)
    (send b :locate p :world)
    b))

(defun kxr-rcb4-board-bodyset ()
  (let* ((b (kxr-rcb4-size-board))
	 (c (kxr-power-connector))
	 (lst (list c)))
    (send c :locate (float-vector 16 -5 4) :world)
    (push (kxr-zh-connector (float-vector -9 0 4)) lst)
    (push (kxr-zh-connector (float-vector -3 0 4)) lst)
    (push (kxr-zh-connector (float-vector 3 0 4)) lst)
    (push (kxr-zh-connector (float-vector -9 -10 4)) lst)
    (push (kxr-zh-connector (float-vector -3 -10 4)) lst)
    (push (kxr-zh-connector (float-vector 3 -10 4)) lst)
    (push (kxr-zh-connector (float-vector -9 10 4) :darkgreen) lst)
    (push (kxr-zh-connector (float-vector -3 10 4) :darkgreen) lst)
    (push (kxr-zh-connector (float-vector 3 10 4) :darkgreen) lst)
    (push (kxr-zh-connector (float-vector -15 -5 4) :darkgreen) lst)
    (push (kxr-zh-connector (float-vector -15  5 4) :darkgreen) lst)
    (push (kxr-zh-connector (float-vector 15 5 4) :blue) lst)
    (dolist (x lst) (send b :assoc x))
    (setq c (instance bodyset :init (make-cascoords) :bodies (cons b lst)))
    (send c :name "rcb4-board")
    c))

(defun kxr-armh7-board-bodyset ()
  (let* ((b (kxr-rcb4-size-board))
	 (c (kxr-power-connector))
	 (imu (make-cube 3 3 2 :name "imu"))
	 (lst (list imu c)))
    (send c :locate (float-vector 16 -5 4) :world)
    (push (kxr-zh-connector (float-vector -11 0 4)) lst)
    (push (kxr-zh-connector (float-vector -4 0 4)) lst)
    (push (kxr-zh-connector (float-vector 3 0 4)) lst)
    (push (kxr-zh-connector (float-vector -11 -10 4)) lst)
    (push (kxr-zh-connector (float-vector -4 -10 4)) lst)
    (push (kxr-zh-connector (float-vector 3 -10 4)) lst)
    (push (kxr-zh-connector (float-vector -13 7 4) :whitesmoke t) lst)
    (push (kxr-zh-connector (float-vector 15 5 4) :whitesmoke) lst)
    (push (kxr-sh-connector (float-vector -6 12 4) :whitesmoke t) lst)
    (send imu :rotate -pi/2 :z :world)
    (send imu :rotate pi :x :world)
    (send imu :locate (float-vector (- (- 17.5 7.7)) 3 -1) :world)
    (dolist (x lst) (send b :assoc x))
    (setq c (instance bodyset :init (make-cascoords) :bodies (cons b lst)))
    (send c :name "armh7-board")
    c))

(defun kxr-max10-board-bodyset ()
  (let* ((b (kxr-rcb4-size-board))
	 (c (kxr-power-connector))
	 (imu (make-cube 3 3 2 :name "imu"))
	 (lst (list imu c)))
    (send c :locate (float-vector 16 -5 4) :world)
    (push (kxr-zh-connector (float-vector -11 0 4)) lst)
    (push (kxr-zh-connector (float-vector -4 0 4)) lst)
    (push (kxr-zh-connector (float-vector 3 0 4)) lst)
    (push (kxr-zh-connector (float-vector -11 -10 4)) lst)
    (push (kxr-zh-connector (float-vector -4 -10 4)) lst)
    (push (kxr-zh-connector (float-vector 3 -10 4)) lst)
    (push (kxr-zh-connector (float-vector -13 7 4) :whitesmoke t) lst)
    (push (kxr-zh-connector (float-vector 15 5 4) :whitesmoke) lst)
    (push (kxr-sh-connector (float-vector -6 9.5 4) :whitesmoke) lst)
    (send imu :rotate -pi/2 :z :world)
    (send imu :rotate pi :x :world)
    (send imu :locate (float-vector -4.5 3 -1) :world)
    (dolist (x lst) (send b :assoc x))
    (setq c (instance bodyset :init (make-cascoords) :bodies (cons b lst)))
    (send c :name "max10-board")
    c))

(defun kxr-ps-body (&optional (pos (float-vector 0 0 0))
			      &rest args)
  (let* ((b (make-cube 4 2 1.5))
	 (c (make-cylinder 0.54 6))
	 (*contact-threshold* 0.0001)
	 ;;(*coplanar-threshold* 0.0001)	 
	 ;;(*epsilon* 0.0001)
	 )
    (send c :locate (float-vector 1 0 -2) :world)
    (setq b (body- b c))
    (send b :locate pos)
    (if args (send* b args))
    (send b :name "ps")
    b))

(defun kxr-jointbase-sensorboard-bodyset ()
  (let* ((b (kxr-jointbase-size-board))
	 (imu (make-cube 3 2.5 2 :name "imu"))
	 (lst (list imu)))
    (push (kxr-zh-connector (float-vector -11 4 2.5) :whitesmoke nil t) lst)
    (push (kxr-zh-connector (float-vector -11 -4 2.5) :whitesmoke nil t) lst)
    ;;
    (push (kxr-nsh-connector (float-vector 11 0 -2.5) :whitesmoke nil pi/2) lst)
    (push (kxr-nsh-connector (float-vector 11 6 -2.5) :whitesmoke nil pi/2) lst)
    (push (kxr-nsh-connector (float-vector 11 -6 -2.5) :whitesmoke nil pi/2) lst)
    (push (kxr-nsh-connector (float-vector -11 0 -2.5) :whitesmoke nil -pi/2) lst)
    (push (kxr-nsh-connector (float-vector -11 6 -2.5) :whitesmoke nil -pi/2) lst)
    (push (kxr-nsh-connector (float-vector -11 -6 -2.5) :whitesmoke nil -pi/2) lst)
    ;;
    (push (kxr-ps-body (float-vector 4.8 4.8 -1) :rotate -pi/2 :z) lst)
    (push (kxr-ps-body (float-vector 4.8 -4.8 -1) :rotate -pi/2 :z) lst)
    (push (kxr-ps-body (float-vector -4.8 4.8 -1) :rotate pi/2 :z) lst)
    (push (kxr-ps-body (float-vector -4.8 -4.8 -1) :rotate pi/2 :z) lst)
    ;;
    (push (kxr-sh-connector (float-vector 11 -3.5 2) :whitesmoke nil t) lst)
    (send imu :locate (float-vector 11.5 5 1) :world)
    (dolist (x lst) (send b :assoc x))
    (setq b (instance bodyset :init (make-cascoords) :bodies (cons b lst)))
    (send b :name "jointbase-sensorboard")
    b))

(defun kxr-board-bodyset (name &optional (lst (read-kjs01-chips)))
  (let (b bs)
    (dolist (l lst)
      (dolist (x (send l :bodies))
	(push x bs)))
    (setq b (car bs))
    (dolist (x (cdr bs)) (send b :assoc x))
    (setq b (instance bodyset :init (make-cascoords) :bodies bs))
    (send b :name name)
    b))

(defun kxr-kjs01-board-bodyset nil
  (kxr-board-bodyset "KJS01" (read-kjs01-chips)))
(defun kxr-kjs02-board-bodyset nil
  (kxr-board-bodyset "KJS02" (read-kjs02-chips)))
(defun kxr-kjs03-board-bodyset nil
  (kxr-board-bodyset "KJS03" (read-kjs03-chips)))
(defun kxr-armh7b-board-bodyset nil
  (kxr-board-bodyset "ARMH7B" (read-armh7b-chips)))
(defun kxr-max10a-board-bodyset nil
  (kxr-board-bodyset "MAX10B" (read-max10a-chips)))
(defun kxr-max10b-board-bodyset nil
  (kxr-board-bodyset "MAX10B" (read-max10b-chips)))

(defun show-top-bottom (&optional (b (kxr-max10b-board-bodyset))
				  &key
				  (whole-wrl "Chips/FPGA_kondo/FPGA_kondo.wrl")
				  (xoffset 50)
				  (yoffset 80))
  (let* ((a (wrl2eus whole-wrl))
	 (ac (copy-object a))
	 (bc (copy-object b)))
    (send ac :locate (float-vector 0 yoffset 0))
    (send ac :rotate pi :x)
    (send b :locate (float-vector xoffset 0 0))
    (send bc :locate (float-vector xoffset yoffset 0))
    (send bc :rotate pi :x)
    (objects (list a ac b bc))))

(defun show-tb-kjs01 nil
  (show-top-bottom (kxr-kjs01-board-bodyset)
		   :whole-wrl "Chips/KJS-01/JointBaseSensorboard.wrl"))
(defun show-tb-kjs02 nil
  (show-top-bottom (kxr-kjs02-board-bodyset)
		   :whole-wrl "Chips/KJS-02/KJS-02.wrl"))
(defun show-tb-armh7b nil
  (show-top-bottom (kxr-armh7b-board-bodyset)
		   :whole-wrl "Chips/stm32h7_kondo/stm32h7_kondo.wrl"))
(defun show-tb-max10a nil
  (show-top-bottom (kxr-max10a-board-bodyset)
		   :whole-wrl "Chips/FPGA_kondo_original/FPGA_kondo_original.wrl"))

(defun show-tb-max10b nil
  (show-top-bottom (kxr-max10b-board-bodyset)
		   :whole-wrl "Chips/FPGA_kondo/FPGA_kondo.wrl"))

(defun show-flip (str &key (xoffset 50) (yoffset 50))
  (let* ((a (wrl2eus str))
	 (ac (copy-object a)))
    (send ac :locate (float-vector 0 yoffset 0))
    (send ac :rotate pi :x)
    (objects (list a ac))))

(defun show-kjs02-asm ()
  (objects (wrl2eus "Chips/KJS-02/KJS-02-asm-KHR.WRL")))
(defun show-kjs02-top ()
  (objects (wrl2eus "Chips/KJS-02/KJS-02-top-KHR.WRL")))
(defun show-kjs02-bottom ()
  (objects (wrl2eus "Chips/KJS-02/kjs-02-bottom-khr-rev2.wrl")))
(defun show-kjs02-revA ()
  (objects (wrl2eus "Chips/KJS-02/KJS-02-revA.wrl")))
(defun show-kjs02-revB ()
  (objects (wrl2eus "Chips/KJS-02/KJS-02-revB.wrl")))
(defun show-kjs02-revB-extend ()
  (objects (wrl2eus "Chips/KJS-02/KJS-02-revB-extend.wrl")))

(defun show-kjs02-pcb5 ()
  (objects (wrl2eus "Chips/KJS-02/PCB5x2_extend.wrl"))
  )
(defun show-kjss ()
  (setq *kjs02s*
	(list 
	 (setq *kjs02-top* (wrl2eus "Chips/KJS-02/KJS-02-top-KHR.WRL"))
	 (setq *kjs02-bottom* (wrl2eus "Chips/KJS-02/kjs-02-bottom-khr-rev2.wrl"))
	 (setq *kjs02-asm* (wrl2eus "Chips/KJS-02/KJS-02-asm-KHR.WRL"))
	 ))
  (require :kxrviewer)
  (show-2d-arrange *kjs02s* :base nil :n 2)
  )
  
(defun show-kxrboard-imu (&aux c)
  (setq *kxr-boards*
	(list
	 (setq *rcb4* (kxr-rcb4-board-bodyset))
	 (setq *armh7* (kxr-armh7-board-bodyset))
	 (setq *jbs* (kxr-jointbase-sensorboard-bodyset))
	 (setq *kjs01* (kxr-kjs01-board-bodyset))
	 (setq *kjs02* (kxr-kjs02-board-bodyset))
	 (setq *armh7b* (kxr-armh7b-board-bodyset))
	 (setq *max10b* (kxr-max10b-board-bodyset))))
  (setq *tb-boards*
	(mapcan #'(lambda (b) (let ((c (copy-object b)))
				(send c :rotate pi :x)
				(list b c)))
		*kxr-boards*))
  
  (require :kxrviewer)
  (show-2d-arrange *tb-boards* :base nil :n 2)
  
  (dolist (b *kxr-boards*)
    (setq c (send b :find-named-body "imu"))
    (format t "board:~A~%	imu-rot:	~A~%	imu-worldrot:	~A~%	rpy:~A~%	wrpy:~A~%"
	    (send b :name)
	    (and c (send c :rot))
	    (and c (send c :worldrot))
	    (and c (send c :rpy-deg))
	    (and c (send (send c :worldcoords) :rpy-deg))
	    ))
  )

(provide :kxrboards)
