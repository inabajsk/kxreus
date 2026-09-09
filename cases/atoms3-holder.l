(require :utils)

(defun atoms3-holder nil
  (setq *epssilon* 0.000001)
  (setq *coplanar-threshold* 0.000001)
  (setq *contact-threshold* 0.000001)
  (setq *parallel-threshold* 0.000001)
  ;;
  ;;   (setq wx 35 wy 26 wz 11.5 fr 3 seg 10) org
  (setq wx 35 wy 26 wz 13 fr 3 seg 10)
  (setq c0 (make-fillet-cube wx wy wz fr :segments seg))
  ;;
  ;; bottom 
  (setq c1- (make-cube 8 (+ wy 4) wz))
  (send c1- :locate (float-vector
		     (/ wx 2)
		     0
		     4) :world)
  (setq c0 (body- c0 c1-))  
  ;;
  ;; bottom cable hole
  (setq c2- (make-cube 14 11 100))
  (send c2- :locate (float-vector
		     (- (/ wx 2) 4)
		     0
		     0) :world)
  (setq c0 (body- c0 c2-))
  ;;
  ;;
  ;; atom hole
  (setq s3 (make-fillet-cube 24 24 6 2 :segments seg))
  (send s3 :locate (float-vector
		    (setq s3x (- (/ wx 2) 18 4))
		    0
		    (/ wz 2)) :world)
  (setq c0 (body- c0 s3))
  ;;
  ;; center hole
  (setq cyl- (make-cylinder 2 20))
  (send cyl- :rotate pi :x :world)
  (send cyl- :locate (float-vector
		      s3x
		      0
		      (- (/ wz 2) 5)) :world)
  (setq c0 (body- c0 cyl-))
  ;;
  ;; center screw
  (setq cyl- (make-cylinder 1.0 100))
  (send cyl- :locate (float-vector
		      s3x
		      0
		      (- (/ wz -2) 5)) :world)
  (setq c0 (body- c0 cyl-))
  ;;
  ;; bottom quad holes
  (setq cyl- (make-cylinder 0.7 10))
  (dolist (x (list 0 -21))
    (dolist (y (list -10.5 10.5))
      (send cyl- :locate (float-vector
			  (+ (- (/ wx 2) 2) x)
			  y
			  (- (/ wz -2) 5)) :world)
      (setq c0 (body- c0 cyl-))))
  ;; bottom quad holes
  (dolist (x (list (- s3x 10.5) (+ s3x 10.5)))
    (dolist (y (list -10.5 10.5))
      (send cyl- :locate (float-vector
			  x
			  y
			  (- (/ wz -2) 5)) :world)
      (setq c0 (body- c0 cyl-))))
  ;;
  ;; top cable hole
  (setq c2- (make-cube 6 11 10))
  (send c2- :locate (float-vector
		     (/ wx -2)
		     0 (/ wz 2)) :world)
  (setq c0 (body- c0 c2-))
  ;; side cable hole
  (setq c2- (make-cube (+ 7 (- s3x) 4) 6 10))
  (dolist (y (list (/ wy -2) (/ wy 2)))
    (send c2- :locate (float-vector
		       (/ (+ s3x -7 4) 2)
		       y (/ wz 2)) :world)
    (setq c0 (body- c0 c2-)))
  ;;
  ;; 4pin hole
  (setq p4x 12)
  (setq pin4- (make-cube p4x 2.6 100))
  (send pin4- :locate (float-vector
		       (- (/ wx 2) 4 6 2.6 (/ p4x 2))
		       -7.5
		       (- (/ wz -2) 5)) :world)
  (setq c0 (body- c0 pin4-))
  ;;
  ;; 5pin hole
  (setq p5x 14.5)
  (setq pin5- (make-cube p5x 2.6 100))
  (send pin5- :locate (float-vector
		       (- (/ wx 2) 4 6 2.6 (/ p5x 2))
		       7.5
		       (- (/ wz -2) 5)) :world)
  (setq c0 (body- c0 pin5-))
  ;;
  (objects (list c0))
  c0)

(defun save-holder (&optional (save t))
  (setq holder (atoms3-holder))
  (objects (list holder))
  (when save (eus2stl "atoms3-holder.stl" holder :scale 1)))

