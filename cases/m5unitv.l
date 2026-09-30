;;
(require :utils)
(defun m5unitv-holder (&optional reverse)
  (setq *epssilon* 0.000001)
  (setq *coplanar-threshold* 0.000001)
  (setq *contact-threshold* 0.000001)
  (setq *parallel-threshold* 0.000001)
  ;;
  (setq ww 2)
  (setq wx0 40 wy0 24)
  (setq wx (+ wx0 ww ww) wy (+ wy0 ww ww)
	wz 10 fr 2 seg 10)
  ;;
  (setq c0 (make-fillet-cube wx wy wz fr :segments seg))
  ;;
  (setq c0- (make-fillet-cube (- wx ww ww) (- wy ww ww) wz fr :segments seg))
  (send c0- :locate (float-vector
		     0
		     0
		     2) :world)
  (setq c0 (body- c0 c0-))  
  ;;
  ;; sd card
  (setq c1- (make-cube 20 14 8))
  (send c1- :locate (float-vector
		     (/ wx (if reverse -2 2))
		     1
		     2) :world)
  (setq c0 (body- c0 c1-))
  ;;
  ;; usbC
  (setq c1- (make-cube 5 12 100))
  (send c1- :locate (float-vector
		     (/ wx (if reverse 2 -2))
		     0
		     0) :world)
  (setq c0 (body- c0 c1-))
  ;;
  ;; side switch
  (setq c2- (make-cube 7 20 7))
  (send c2- :locate (float-vector
		     (if reverse (+ (/ wx 2) -7)
		       (+ (/ wx -2) 7))
		     (/ wy 2)
		     2) :world)
  (setq c0 (body- c0 c2-))  
  (send c2- :locate (float-vector
		     (if reverse (+ (/ wx 2) -7)
		       (+ (/ wx -2) 7))
		     (/ wy -2)
		     2) :world)
  (setq c0 (body- c0 c2-))  
  ;;
  ;; hole
  (setq cyl- (make-cylinder 1 100))
  (send cyl- :locate (float-vector
		      (+ (/ wx -2) 14)
		      0
		      -10) :world)
  (setq c0 (body- c0 cyl-))
  ;;
  ;; base
  (setq c0+ (make-cube 25 23 7))
  ;;
  (setq cyl- (make-cylinder 0.7 100))
  (dolist (x (list -4 4))
    (dolist (y (list -4 4))
      (send cyl- :locate (float-vector x y -20) :world)
      (setq c0+ (body- c0+ cyl-))))
  ;;
  (setq cyl- (make-cylinder 3 7))
  (send cyl- :locate (float-vector
		      0
		      (if reverse
			  (+ (/ 23 -2) 3.5)
			(- (/ 23 2) 3.5))
		      (/ wz -2)) :world)  
  (setq c0+ (body- c0+ cyl-))
  (setq cyl- (make-cylinder 1.3 100))
  (send cyl- :locate (float-vector
		      0
		      (if reverse
			  (+ (/ 23 -2) 3.5)
			(- (/ 23 2) 3.5))
		      -20) :world)  
  (setq c0+ (body- c0+ cyl-))
  ;;
  #|
  (setq cyl- (make-cylinder 2.5 100))
  (send cyl- :locate (float-vector
		      0
		      (+ (/ 23 -2) 8.5)
		      -20) :world)  
  (setq c0+ (body- c0+ cyl-))
  |#
  ;;
  (if reverse
      (send c0+ :rotate (- pi/2) :x :world)
    (send c0+ :rotate pi/2 :x :world))
  (send c0+ :locate (float-vector
		     0
		     (if reverse
			 (+ (/ wy 2) 2.5)
		       (- (/ wy -2) 2.5))
		     (+ (/ wz -2) 0.6 (/ 23 2))) :world)
  (setq c0 (body+ c0 c0+))
  ;;(objects (list c0 c0+))
  ;;
  (objects (list c0))
  c0)


(defun m5unitv-kxrl4d-head (&optional reverse)
  (setq *epssilon* 0.000001)
  (setq *coplanar-threshold* 0.000001)
  (setq *contact-threshold* 0.000001)
  (setq *parallel-threshold* 0.000001)
  ;;
  (setq ww 2)
  (setq wx0 40 wy0 24)
  (setq wx (+ wx0 ww ww) wy (+ wy0 ww ww)
	wz 10 fr 2 seg 10)
  ;;
  (setq c0 (make-fillet-cube wx wy wz fr :segments seg))
  ;;
  (setq c0- (make-fillet-cube (- wx ww ww) (- wy ww ww) wz fr :segments seg))
  (send c0- :locate (float-vector
		     0
		     0
		     2) :world)
  (setq c0 (body- c0 c0-))  
  ;;
  ;; sd card
  (setq c1- (make-cube 20 14 8))
  (send c1- :locate (float-vector
		     (/ wx (if reverse -2 2))
		     1
		     2) :world)
  (setq c0 (body- c0 c1-))
  ;;
  ;; usbC
  (setq c1- (make-cube 5 12 100))
  (send c1- :locate (float-vector
		     (/ wx (if reverse 2 -2))
		     0
		     0) :world)
  (setq c0 (body- c0 c1-))
  ;;
  ;; side switch
  (setq c2- (make-cube 7 20 7))
  (send c2- :locate (float-vector
		     (if reverse (+ (/ wx 2) -7)
		       (+ (/ wx -2) 7))
		     (/ wy 2)
		     2) :world)
  (setq c0 (body- c0 c2-))  
  (send c2- :locate (float-vector
		     (if reverse (+ (/ wx 2) -7)
		       (+ (/ wx -2) 7))
		     (/ wy -2)
		     2) :world)
  (setq c0 (body- c0 c2-))  
  ;;
  ;; hole
  (setq cyl- (make-cylinder 1 100))
  (send cyl- :locate (float-vector
		      (+ (/ wx -2) 14)
		      0
		      -10) :world)
  (setq c0 (body- c0 cyl-))
  ;;
  ;; base
  (setq c0+ (make-cube 25 23 20))

  (setq c0- (make-cube 30 23 20))
  (send c0- :locate (float-vector
		     0
		     -5
		     -6) :world)
  (setq c0+ (body- c0+ c0-))
  ;;
  (setq c0- (make-cube 18 20 25))
  (send c0- :locate (float-vector
		     0
		     16
		     10) :world)
  (setq c0+ (body- c0+ c0-))
  ;;
  (setq cyl- (make-cylinder 0.7 20))
  (dolist (x (list -4 4))
    (dolist (y (list -4 4))
      (send cyl- :locate (float-vector x y 0) :world)
      (setq c0+ (body- c0+ cyl-))))
  ;;
  (setq cyl- (make-cylinder 3 20))
  (send cyl- :locate (float-vector
		      0
		      0
		      -13) :world)  
  (setq c0+ (body- c0+ cyl-))
  ;;
  (setq cyl- (make-cylinder 1.3 100))
  (send cyl- :locate (float-vector
		      0
		      0
		      -20) :world)  
  (setq c0+ (body- c0+ cyl-))
  ;;
  (send c0+ :rotate pi/2 :x :world)
  (send c0+ :locate (float-vector
		     0
		     (- (/ wy -2) 10)
		     (- (/ wz -2) 0.6 (/ 23 2) -8)) :world)
  (setq c0 (body+ c0 c0+))
  (objects (list c0))
  c0)


(defun show-holder (&optional reverse)
  (setq holder (m5unitv-holder reverse)))

(defun show-head ()
  (setq head (m5unitv-kxrl4d-head)))

(defun save-holder (&optional (save t))
  (setq holder (m5unitv-holder))
  (setq rholder (m5unitv-holder t))
  (setq head (m5unitv-kxrl4d-head))
  (objects (list head holder))
  (when save
    (eus2stl "m5unitv-holder.stl" holder :scale 1)
    (eus2stl "m5unitv-kxrl4d-head.stl" head :scale 1)
    ;;(eus2stl "m5unitv-rholder.stl" rholder :scale 1)
    ))

