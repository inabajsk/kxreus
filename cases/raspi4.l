(require :utils)

(defun raspi4-base nil
  (setq *epssilon* 0.000001)
  (setq *coplanar-threshold* 0.000001)
  (setq *contact-threshold* 0.000001)
  (setq *parallel-threshold* 0.000001)
  ;;
  ;;
  (setq wx 92 wy 64 wz 24 fr 3 seg 14)
  ;;
  (setq c0 (make-fillet-cube wx wy wz fr :segments seg))
  (setq c- (make-fillet-cube (- wx 4) (- wy 6) wz fr :segments seg))  
  (send c- :locate (float-vector 0 0 4) :world)
  (setq c1 (body- c0 c-))
  (setq c-- (make-fillet-cube (- wx 2) (- wy 3) wz fr :segments seg))  
  (send c-- :locate (float-vector 0 0 (- wz 4)) :world)
  (setq c2 (body- c1 c--))
  ;;
  (setq uw 52)
  (setq usb- (make-cube wx uw 6))
  (send usb- :locate (float-vector
		      -10
		      (- (- (/ wy 2) 5.5 (/ uw 2)))
		      (/ wz 2)) :world)
  (setq c3 (body- c2 usb-))
  ;;
  (setq cable- (make-cube wx 6 20))
  (send cable- :locate (float-vector
			-10
			(- (/ wy 2) 5 (/ 13 2))
			(/ wz 2)) :world)
  (setq c3 (body- c3 cable-))
  (objects (list c3))
  ;;
  (setq cable-- (make-fillet-cube 6.5 11.3 50 2))
  (send cable-- :rotate pi/2 :y :world)
  (send cable-- :locate (float-vector
			 (/ wx -2)
			 (+ (/ wy -2) 8 (/ 11 2))
			 (- (/ wz 2) 10)
			 ) :world)
  (setq c4 (body- c3 cable--))
  (objects (list c4))
  ;;
  (setq ucxw 54)
  (setq usbc- (make-cube ucxw wy 22))
  (send usbc- :locate (float-vector
		       (- (/ wx 2) 8 (/ ucxw 2))
		       10
		       (/ wz 2)) :world)
  (setq c5 (body- c4 usbc-))
  (objects (list c5))
  ;;
  (setq sdw 15)
  (setq sd- (make-cube wx sdw 14))
  (send sd- :locate (float-vector 10 0 (/ wz 2)) :world)
  (setq c5 (body- c5 sd-))
  (objects (list c5))
  ;;
  (setq bw 27.0 bz 2)
  (setq b- (make-fillet-cube bw bw bz 2 :segments seg))
  (setq xb 21)
  (send b- :locate (float-vector (- xb) 0 (/ wz -2)) :world)
  (setq c6 (body- c5 b-))
  (send b- :locate (float-vector xb 0 (/ wz -2)) :world)
  (setq c6 (body- c6 b-))
  (setq cyl- (make-cylinder 0.8 10))
  ;;
  (setq yb (/ 51.5 2))
  (dolist (x (list (+ xb 10.5) (- xb 10.5)
		   (- (+ xb 10.5)) (- (- xb 10.5))))
    (dolist (y (list -10.5 10.5))
      (send cyl- :locate (float-vector x y (- (/ wz -2) 5)) :world)
      (setq c6 (body- c6 cyl-))
      ))
  ;;
  (setq dx 6)
  (setq cyl- (make-cylinder 0.8 120))
  (send cyl- :rotate (deg2rad -90) :x :world)
  (send cyl- :locate (float-vector
		      (- (/ wx 2) dx)
		      (- -10 (/ wy 2))
		      (- (/ wz 2) 2)) :world)
  (setq base (body- c6 cyl-))
  (send cyl- :locate (float-vector
		      (+ (/ wx -2) dx)
		      (- -10 (/ wy 2))
		      (- (/ wz 2) 2)) :world)
  (setq base (body- base cyl-))
  ;;
  (setq hc- (make-fillet-cube 10 10 34 3))
  (send hc- :locate (float-vector
		     (- (/ wx 2) 16)
		     (/ wy 2)
		     (/ wz -2)) :world)
  (setq base (body- base hc-))
  ;;(objects (list base hc-))
  (send hc- :locate (float-vector
		     (- (/ wx 2) 16)
		     (/ wy -2)
		     (/ wz -2)) :world)
  (setq base (body- base hc-))
  (objects (list base))
  base
  )

(defun raspi4-cover nil
  (setq *epssilon* 0.000001)
  (setq *coplanar-threshold* 0.000001)
  (setq *contact-threshold* 0.000001)
  (setq *parallel-threshold* 0.000001)
  ;;
  (setq wx 92 wy 64 wz 24 wzc 22 fr 3 seg 7)
  (setq cover (make-fillet-cube wx wy wzc fr :segments seg))
  (setq cover- (make-fillet-cube (- wx 4) (- wy 6) wzc fr :segments seg))
  (send cover- :locate (float-vector 0 0 -2) :world)
  (setq cover (body- cover cover-))
  ;;
  (setq cover+ (make-fillet-cube (+ wx 2) (+ wy 3) wzc fr :segments seg))
  (setq cover-- (make-fillet-cube (- wx 2) (- wy 3) wzc fr :segments seg))
  (send cover-- :locate (float-vector 0 0 2) :world)
  (setq cover+ (body- cover+ cover--))
  (send cover+ :locate (float-vector 0 0 (+ (- wzc) 4)) :world)
  (setq cover (body- cover cover+))
  ;;
  (setq ewx 10 ewy 53 ewz 36)
  (setq ceth- (make-cube ewx ewy ewz))
  (send ceth- :locate (float-vector
		       (/ wx -2)
		       0
		       (/ wzc -2)) :world)
  (setq cover (body- cover ceth-))
  ;;
  (setq cc-x 69 cc-y (- wy 8) -z 10)
  (setq cc- (make-cube cc-x cc-y cc-z))
  (send cc- :locate (float-vector
		     (+ (/ wx -2) 19 (/ cc-x 2))
		     0
		     (/ wzc 2)) :world)
  (setq cover (body- cover cc-))
  
  ;; side
  ;; base ucxw 54
  (setq cc-x 54 cc-z 18)
  (setq cc- (make-cube cc-x 10 cc-z))
  (send cc- :locate (float-vector
		     (- (/ wx 2) 8 (/ cc-x 2))
		     (/ wy 2)
		     (/ wzc -2)) :world)
  (setq cover (body- cover cc-))
  ;;
  (setq sdw 15)
  (setq sd- (make-cube wx sdw 6))
  (send sd- :locate (float-vector 10 0 (/ wzc -2)) :world)
  (setq cover (body- cover sd-))
  ;;
  (objects (list cover))
  cover)

(defun save-base (&optional (save t))
  (setq base (raspi4-base))
  (objects (list base))
  (when save (eus2stl "raspi4-base.stl" base :scale 1)))

(defun save-cover (&optional (save t))
  (setq cover (raspi4-cover))
  (send cover :rotate pi :x)
  (objects (list cover))  
  (when save (eus2stl "raspi4-cover.stl" cover :scale 1)))

