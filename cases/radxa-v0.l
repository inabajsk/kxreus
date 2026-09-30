(require :utils)

(defun radxa-cover-io-extention nil
  "for radxa I/O extension board"
  (setq *epssilon* 0.000001)
  (setq *coplanar-threshold* 0.000001)
  (setq *contact-threshold* 0.000001)
  (setq *parallel-threshold* 0.000001)
  ;;
  (setq wx 72 wy 37 wz 24 wzc 22 fr 2 seg 7)
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
  ;; i2c connector
  (setq cc-x 24 cc-y 13 cc-z 16)
  (setq cc- (make-cube cc-x cc-y cc-z))
  (send cc- :locate (float-vector
		     (/ wx 2)
		     0
		     (/ wzc 2)) :world)
  (setq cover (body- cover cc-))
  (send cc- :locate (float-vector
		     (/ wx -2)
		     0
		     (/ wzc 2)) :world)
  (setq cover (body- cover cc-))
  ;;
  ;; sd card
  (setq uw 15)
  (setq usb- (make-cube wx uw 10))
  (send usb- :locate (float-vector
		      -10
		      0
		      (/ wzc -2)) :world)
  (setq cover (body- cover usb-))

  ;; side low
  (setq cc-x 55 cc-z 18)
  (setq cc- (make-cube cc-x 10 cc-z))
  (send cc- :locate (float-vector
		     (- (/ wx 2) 8 (/ cc-x 2))
		     (/ wy 2)
		     (/ wzc -2)) :world)
  (setq cover (body- cover cc-))
  ;;
  ;; atom hole
  (setq ahw 24.5)
  (setq cc- (make-fillet-cube ahw ahw 20 2 :segments 10))
  (send cc- :locate (float-vector 0 0 (/ wzc 2)) :world)
  (setq cover (body- cover cc-)) 
  ;; atom cable
  (setq cc- (make-cube 12 30 16))
  (send cc- :locate (float-vector 0 (/ wy -2) (/ wzc 2)) :world)
  (setq cover (body- cover cc-))
  ;;
  (setq ucxw 55)
  (setq usbc- (make-cube ucxw wy 7))
  (send usbc- :locate (float-vector
		       0
		       (/ wy 2)
		       (+ (/ wz -2) 4 12.5)) :world)
  (setq cover (body- cover usbc-))
  ;;
  (objects (list cover))
  cover)



(defun radxa-base nil
  (setq *epssilon* 0.000001)
  (setq *coplanar-threshold* 0.000001)
  (setq *contact-threshold* 0.000001)
  (setq *parallel-threshold* 0.000001)
  ;;
  ;;
  (setq wx 72 wy 37 wz 24 fr 2 seg 14)
  ;;
  (setq c0 (make-fillet-cube wx wy wz fr :segments seg))
  (setq c- (make-fillet-cube (- wx 4) (- wy 6) wz fr :segments seg))  
  (send c- :locate (float-vector 0 0 4) :world)
  (setq c1 (body- c0 c-))
  (setq c-- (make-fillet-cube (- wx 2) (- wy 3) wz fr :segments seg))  
  (send c-- :locate (float-vector 0 0 (- wz 4)) :world)
  (setq c2 (body- c1 c--))
  ;;
  (setq uw 15)
  (setq usb- (make-cube wx uw 16))
  (send usb- :locate (float-vector
		      -10
		      0
		      (/ wz 2)) :world)
  (setq c3 (body- c2 usb-))
  ;;
  (setq ucxw 55)
  (setq usbc- (make-cube ucxw wy 22))
  (send usbc- :locate (float-vector
		       (- (/ wx 2) 8 (/ ucxw 2))
		       10
		       (/ wz 2)) :world)
  (setq c5 (body- c3 usbc-))
  (objects (list c5))
  ;;
  (setq dx 5)
  (setq cyl- (make-cylinder 0.8 120))
  (send cyl- :rotate (deg2rad -90) :x :world)
  (send cyl- :locate (float-vector
		      (- (/ wx 2) dx)
		      (- -10 (/ wy 2))
		      (- (/ wz 2) 2)) :world)
  (setq base (body- c5 cyl-))
  (send cyl- :locate (float-vector
		      (+ (/ wx -2) dx)
		      (- -10 (/ wy 2))
		      (- (/ wz 2) 2)) :world)
  (setq base (body- base cyl-))
  ;;

  (setq xb 0 yb -6.2)
  (setq bw 28 bz 3)
  (setq b- (make-fillet-cube bw bw bz 2 :segments seg))
  (send b- :locate (float-vector xb yb (/ wz -2)) :world)
  (setq base (body- base b-))
  ;;
  (setq cyl- (make-cylinder 0.8 10))
  (dolist (x (list (+ xb 10.5) (- xb 10.5)))
    (dolist (y (list (+ yb -10.5) (+ yb 10.5)))
      (send cyl- :locate (float-vector x y (- (/ wz -2) 5)) :world)
      (setq base (body- base cyl-))
      ))
  ;;
  (objects (list base))
  base
  )

(defun radxa-hub-cover nil
  "for Square USB Hub"
  (setq *epssilon* 0.000001)
  (setq *coplanar-threshold* 0.000001)
  (setq *contact-threshold* 0.000001)
  (setq *parallel-threshold* 0.000001)
  ;;
  (setq wx 72 wy 37 wzc 18 fr 2 seg 7)
  (setq cover (make-fillet-cube wx wy wzc fr :segments seg))
  ;;
  (setq cover- (make-fillet-cube (- wx 4) (- wy 6) wzc fr :segments seg))
  (send cover- :locate (float-vector 0 0 -5) :world)
  (setq cover (body- cover cover-))
  ;;
  (setq cover+ (make-fillet-cube (+ wx 2) (+ wy 3) wzc fr :segments seg))
  (setq cover-- (make-fillet-cube (- wx 2) (- wy 3) wzc fr :segments seg))
  (send cover-- :locate (float-vector 0 0 2) :world)
  (setq cover+ (body- cover+ cover--))
  (send cover+ :locate (float-vector 0 0 (+ (- wzc) 4)) :world)
  (setq cover (body- cover cover+))
  ;;
  ;; sd card
  (setq uw 15)
  (setq usb- (make-cube wx uw 10))
  (send usb- :locate (float-vector
		      -10
		      0
		      (/ wzc -2)) :world)
  (setq cover (body- cover usb-))

  ;; side low
  (setq cc-x 55 cc-z 18)
  (setq cc- (make-cube cc-x 10 cc-z))
  (send cc- :locate (float-vector
		     (- (/ wx 2) 8 (/ cc-x 2))
		     (/ wy 2)
		     (/ wzc -2)) :world)
  (setq cover (body- cover cc-))
  ;;
  ;; square USB HUB hole
  (setq uhw 45.5 uwz 10)
  (setq cc- (make-cube uhw (+ uhw 10) uwz))
  (send cc- :locate (float-vector 0 0 (/ wzc 2)) :world)
  (setq cover (body- cover cc-)) 
  ;; Hub outside
  ;; (setq wx 72 wy 37 wzc 17 fr 2 seg 7)
  (setq cc-x (- wx uhw 3)
	cc-y uhw cc-z 8)
  (setq cc- (make-cube cc-x cc-y cc-z))
  (send cc- :locate (float-vector
		     (/ wx 2)
		     0
		     (/ wzc 2)) :world)
  (setq cover (body- cover cc-))
  (send cc- :locate (float-vector
		     (/ wx -2)
		     0
		     (/ wzc 2)) :world)
  (setq cover (body- cover cc-))
  ;;
  ;; hub holder
  (setq cyl- (make-cylinder 1.0 200))
  (send cyl- :rotate pi/2 :y :world)
  (send cyl- :locate (float-vector -100 0 (- (/ wzc 2) 2)) :world)
  (setq cover (body- cover cyl-))
  ;;
  (objects (list cover))
  cover)




(defun show-all nil
  (setq base (radxa-hub-base))
  (setq cover (radxa-hub-cover))
  (send cover :locate (float-vector 0 0
				    (+ (/ wz 2) (/ wzc 2) -4 )) :world)
  ;;
  (objects (list base cover)))

(defun save-base (&optional (save t))
  (setq base (radxa-base))
  (objects (list base))
  (when save (eus2stl "radxa-base.stl" base :scale 1)))

(defun save-hub-cover (&optional (save t))
  (setq cover (radxa-hub-cover))
  (objects (list cover))  
  (when save (eus2stl "radxa-hub-cover.stl" cover :scale 1)))

(defun save-all nil
  (save-base) (save-hub-cover))
