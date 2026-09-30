;;
(require :utils)
(defun m5stickv-holder nil
  (setq *epssilon* 0.000001)
  (setq *coplanar-threshold* 0.000001)
  (setq *contact-threshold* 0.000001)
  (setq *parallel-threshold* 0.000001)
  ;;
  (setq ww 2)
  (setq wx0 47.6 wy0 23.6)
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
  (setq c1- (make-cube (- wx0 8) (- wy0 8) 100))
  (setq c0 (body- c0 c1-))
  ;;
  (setq c2- (make-cube (- wx 12) wy 20))
  (send c2- :locate (float-vector
		     0
		     10
		     (+ (/ wz -2) 6 10)))
  (setq c0 (body- c0 c2-))  
  ;;
  (setq cyl- (make-cylinder 1.5 100))
  (send cyl- :rotate pi/2 :y :world)
  (send cyl- :locate (float-vector
		      0
		      0
		      (+ (/ wz -2) 8)) :world)
  (setq c0 (body- c0 cyl-))    
  ;;
  (setq c0+ (make-cube 25 23 7))
  (setq cyl- (make-cylinder 0.7 100))
  (dolist (x (list -4 4))
    (dolist (y (list -4 4))
      (send cyl- :locate (float-vector x y -20) :world)
      (setq c0+ (body- c0+ cyl-))))
  ;;
  (setq cyl- (make-cylinder 3 7))
  (send cyl- :locate (float-vector
		      0
		      (- (/ 23 2) 3.5)
		      (/ wz -2)) :world)  
  (setq c0+ (body- c0+ cyl-))
  (setq cyl- (make-cylinder 1.3 100))
  (send cyl- :locate (float-vector
		      0
		      (- (/ 23 2) 3.5)
		      -20) :world)  
  (setq c0+ (body- c0+ cyl-))
  ;;
  (setq cyl- (make-cylinder 2.5 100))
  (send cyl- :locate (float-vector
		      0
		      (+ (/ 23 -2) 8.5)
		      -20) :world)  
  (setq c0+ (body- c0+ cyl-))
  ;;
  (send c0+ :rotate pi/2 :x :world)
  (send c0+ :locate (float-vector
		     0
		     (- (/ wy -2) 2.5)
		     (+ (/ wz -2) 0.5 (/ 23 2))) :world)
  (setq c0 (body+ c0 c0+))
  ;;
  (objects (list c0))
  c0)

(defun show-holder nil
  (setq holder (m5stickv-holder)))

(defun save-holder (&optional (save t))
  (setq holder (m5stickv-holder))
  (objects (list holder))
  (when save (eus2stl "m5stickv-holder.stl" holder :scale 1)))

