;;
(require :utils)
(defun m5stickc-base nil
  (let
      ()
      ;; ((*epssilon* 0.000001)
      ;;  (*coplanar-threshold* 0.000001)
      ;;  (*contact-threshold* 0.000001)
      ;;  (*parallel-threshold* 0.000001)
      ;;  ww wx0 wy0 wx wy wz fr seg kw cw bw
      ;;  c0 c0- c1- c2- c0 cyl-)
    (setq *epssilon* 0.000001)
    (setq *coplanar-threshold* 0.000001)
    (setq *contact-threshold* 0.000001)
    (setq *parallel-threshold* 0.000001)
    ;;
    ;; base
    (setq wx 50 wy 27 wz 8 wxh 8)
    (setq c0 (make-fillet-cube wx wy wz 2))
    (setq c0- (make-cube wx (+ wy 10) wz))
    (send c0- :locate (float-vector (- (/ wx 2) (- (/ wx 2) wxh))
				    0
				    (/ wz 2)) :world)
    (setq c0 (body- c0 c0-))
    ;;
    (setq c0- (make-cube 20 (+ wy -3) 3))
    (send c0- :locate (float-vector (/ wx -2)
				    0
				    1) :world)
    (setq c0 (body- c0 c0-))
    ;;
    (setq c0- (make-cube 7 (+ wy -4) 100))
    (send c0- :locate (float-vector
		       (+ (/ wx -2) (+ (- wx 41) (/ 7 2)))
		       0
		       0) :world)
    ;;
    (setq c0 (body- c0 c0-))
    ;;(objects (list c0 c0-))
    ;;
    (setq cyl- (make-cylinder 0.7 12))
    (setq xoffset 10.5)
    (dolist (x (list (+ -21 -10.5) -21 -10.5 0 10.5))
      (dolist (y (list -10.5 10.5))
	(send cyl- :locate
	      (float-vector
	       (+ x xoffset)
	       y
	       -10) :world)
	(setq c0 (body- c0 cyl-))))
    ;;
    ;; m5stickc holes
    (setq cyl- (make-cylinder 1 100))
    (send cyl- :locate (float-vector
			(- (/ wx 2) 3)
			-8
			-20) :world)
    (setq c0 (body- c0 cyl-))
    (send cyl- :locate (float-vector
			(- (/ wx 2) 3)
			8
			-20) :world)
    (setq c0 (body- c0 cyl-))
    c0)
  )

(defun show-base nil
  (objects (list (setq head (m5stickc-base)))))

(defun save-base (&optional (save t))
  (setq base (m5stickc-base))
  (objects (list base))
  (when save
    (eus2stl "m5stickc-base.stl" head :scale 1)
    ))

