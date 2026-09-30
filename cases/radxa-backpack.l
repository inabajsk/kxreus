;;
(require :utils)
;;(load "read-stl.l")
(setq yh 18.5)
(setq yw 33)
(setq x0 (/ 58 2.0))
(setq y0 (/ 23 2.0))
;;
(defun backholder-dual nil (backholder 15.0 t))
(defun backholder (&optional (offset 0.0) dual)
  (let* ((cu0 (make-fillet-cube 71 yw yh 2))
	 (cu0- (make-fillet-cube 65.5 31 4 2))
	 (cy0 (make-cylinder 1.3 30))
	 (cy+ (make-cylinder 5 8 :segments 35))
	 (cy- (make-cylinder 2.8 20 :segments 35))
	 (cy-- (make-cylinder 1.5 40 :segments 11))
	 (cu1 (make-cube 66 17  40))
	 (cu2 (make-cube 51.5 25.5 60))
	 (cu3 (make-cube 65 40 yh))
	 (cu4 (make-cube 52.5 50 10))
	 (cu5 (make-cube 65 12 yh))
	 (cu6 (make-fillet-cube 56 5 60 2))
	 (*contact-threshold* 0.00001)
	 c)
    (send cy-- :locate (float-vector 0 0 -10) :world)
    (send cy- :assoc cy--)
    ;;
    (send cu0- :locate (float-vector 0 0 (/ yh 2)) :world)
    (setq cu0 (body- cu0 cu0-))
    ;;

    (send cy+ :locate (float-vector 36 offset (- -0.1 (/ yh 2))) :world)
    (setq cu0 (body+ cu0 cy+))
    (send cy+ :locate (float-vector -36 offset (- -0.1 (/ yh 2))) :world)
    (setq cu0 (body+ cu0 cy+))
    ;;
    (send cy- :locate (float-vector 36 offset (- 3 (/ yh 2))) :world)
    (setq cu0 (body- cu0 cy-))
    (setq cu0 (body- cu0 cy--))
    (send cy- :locate (float-vector -36 offset (- 3 (/ yh 2))) :world)
    (setq cu0 (body- cu0 cy-))
    (setq cu0 (body- cu0 cy--))

    (when dual
      (send cy+ :locate (float-vector 36 (- offset) (- -0.1 (/ yh 2))) :world)
      (setq cu0 (body+ cu0 cy+))
      (send cy+ :locate (float-vector -36 (- offset) (- -0.1 (/ yh 2))) :world)
      (setq cu0 (body+ cu0 cy+))
      ;;
      (send cy- :locate (float-vector 36 (- offset) (- 3 (/ yh 2))) :world)
      (setq cu0 (body- cu0 cy-))
      (setq cu0 (body- cu0 cy--))
      (send cy- :locate (float-vector -36 (- offset) (- 3 (/ yh 2))) :world)
      (setq cu0 (body- cu0 cy-))
      (setq cu0 (body- cu0 cy--))
      )
    ;;
    (send cu3 :locate (float-vector 0 0 (- 8)) :world)
    (setq c (body- cu0 cu3)) 
    ;;
    (send cu2 :locate (float-vector 0 2 0) :world)
    (setq c (body- c cu2))
    ;;
    (send cu4 :locate (float-vector 0 0 10) :world)
    (setq c (body- c cu4))
    ;;
    (send cu5 :locate (float-vector 15 0 2.0) :world)
    (setq c (body- c cu5))
    ;;
    (send cu6 :locate (float-vector 0 (- (+ (/ yw 2.0) 0)) 0) :world)
    (setq c (body- c cu6))
    ;;
    (setq c (body- c cu1))   ;; yw=17
    ;;
    (send cy0 :locate (float-vector x0 y0 -15) :world)
    (setq c (body- c cy0))
    (send cy0 :locate (float-vector (- x0) y0 -15) :world)
    (setq c (body- c cy0))
    (send cy0 :locate (float-vector x0 (- y0) -15) :world)
    (setq c (body- c cy0))
    (send cy0 :locate (float-vector (- x0) (- y0) -15) :world)
    (setq c (body- c cy0))    
    ;;(list c cu6)
    c
    ))

(defun backholder-short (&optional (offset 0.0))
  (let* ((yh 16) (yw 33)
	 (cu0 (make-fillet-cube 71 yw yh 2))
	 (cu0- (make-fillet-cube 65.5 31 4 2))
	 (cy0 (make-cylinder 1.3 30))
	 (cy+ (make-cylinder 5 8 :segments 35))
	 (cy- (make-cylinder 2.8 20 :segments 35))
	 (cy-- (make-cylinder 1.5 40 :segments 11))
	 (cu1 (make-cube 66 17  40))
	 (cu2 (make-cube 51.5 25.5 60))
	 (cu3 (make-cube 65 40 yh))
	 (cu4 (make-cube 52.5 50 10))
	 (cu5 (make-cube 65 12 yh))
	 (cu6 (make-fillet-cube 56 5 60 2))
	 (*contact-threshold* 0.00001)
	 c)
    (send cy-- :locate (float-vector 0 0 -10) :world)
    (send cy- :assoc cy--)
    ;;
    (send cu0- :locate (float-vector 0 0 (/ yh 2)) :world)
    (setq cu0 (body- cu0 cu0-))
    ;;
    (send cy+ :locate (float-vector 36 offset (- -0.1 (/ yh 2))) :world)
    (setq cu0 (body+ cu0 cy+))
    (send cy+ :locate (float-vector -36 offset (- -0.1 (/ yh 2))) :world)
    (setq cu0 (body+ cu0 cy+))
    ;;
    (send cy- :locate (float-vector 36 offset (- 3 (/ yh 2))) :world)
    (setq cu0 (body- cu0 cy-))
    (setq cu0 (body- cu0 cy--))
    (send cy- :locate (float-vector -36 offset (- 3 (/ yh 2))) :world)
    (setq cu0 (body- cu0 cy-))
    (setq cu0 (body- cu0 cy--))
    ;;
    (send cu3 :locate (float-vector 0 0 (- 8)) :world)
    (setq c (body- cu0 cu3)) 
    ;;
    (send cu2 :locate (float-vector 0 2 0) :world)
    (setq c (body- c cu2))
    ;;
    (send cu4 :locate (float-vector 0 0 10) :world)
    (setq c (body- c cu4))
    ;;
    (send cu5 :locate (float-vector 15 0 2.0) :world)
    (setq c (body- c cu5))
    ;;
    (send cu6 :locate (float-vector 0 (- (+ (/ yw 2.0) 0)) 0) :world)
    (setq c (body- c cu6))
    ;;
    (setq c (body- c cu1))   ;; yw=17
    ;;
    (send cy0 :locate (float-vector x0 y0 -15) :world)
    (setq c (body- c cy0))
    (send cy0 :locate (float-vector (- x0) y0 -15) :world)
    (setq c (body- c cy0))
    (send cy0 :locate (float-vector x0 (- y0) -15) :world)
    (setq c (body- c cy0))
    (send cy0 :locate (float-vector (- x0) (- y0) -15) :world)
    (setq c (body- c cy0))    
    ;;(list c cu6)
    c
    ))

(defun backholder-no-dig (&optional (offset 0.0))
  (let* ((yh 16) (yw 33)
	 (cu0 (make-fillet-cube 71 yw yh 2))
	 (cy0 (make-cylinder 1.3 30))
	 (cy+ (make-cylinder 5 8 :segments 35))
	 (cy- (make-cylinder 2.8 20 :segments 35))
	 (cy-- (make-cylinder 1.5 40 :segments 11))
	 (cu1 (make-cube 66 17  40))
	 (cu2 (make-cube 51.5 25.5 60))
	 (cu3 (make-cube 65 40 yh))
	 (cu4 (make-cube 52.5 50 10))
	 (cu5 (make-cube 65 12 yh))
	 (cu6 (make-fillet-cube 56 5 60 2))
	 (*contact-threshold* 0.00001)
	 )
    (send cy-- :locate (float-vector 0 0 -10) :world)
    (send cy- :assoc cy--)
    ;;
    (send cy+ :locate (float-vector 36 offset (- -0.1 (/ yh 2))) :world)
    (setq cu0 (body+ cu0 cy+))
    (send cy+ :locate (float-vector -36 offset (- -0.1 (/ yh 2))) :world)
    (setq cu0 (body+ cu0 cy+))
    ;;
    (send cy- :locate (float-vector 36 offset (- 3 (/ yh 2))) :world)
    (setq cu0 (body- cu0 cy-))
    (setq cu0 (body- cu0 cy--))
    (send cy- :locate (float-vector -36 offset (- 3 (/ yh 2))) :world)
    (setq cu0 (body- cu0 cy-))
    (setq cu0 (body- cu0 cy--))
    ;;
    (send cu3 :locate (float-vector 0 0 (- 6.5)) :world)
    (setq c (body- cu0 cu3)) 
    ;;
    (send cu2 :locate (float-vector 0 2 0) :world)
    (setq c (body- c cu2))
    ;;
    (send cu4 :locate (float-vector 0 0 10) :world)
    (setq c (body- c cu4))
    ;;
    (send cu5 :locate (float-vector 15 0 2.0) :world)
    (setq c (body- c cu5))
    ;;
    (send cu6 :locate (float-vector 0 (- (+ (/ yw 2.0) 0)) 0) :world)
    (setq c (body- c cu6))
    ;;
    (setq c (body- c cu1))   ;; yw=17
    ;;
    (send cy0 :locate (float-vector x0 y0 -15) :world)
    (setq c (body- c cy0))
    (send cy0 :locate (float-vector (- x0) y0 -15) :world)
    (setq c (body- c cy0))
    (send cy0 :locate (float-vector x0 (- y0) -15) :world)
    (setq c (body- c cy0))
    (send cy0 :locate (float-vector (- x0) (- y0) -15) :world)
    (setq c (body- c cy0))    
    ;;(list c cu6)
    c
    ))

(defun backcover (&key (left t) (right t) (center t) (yh 6) (hw 13) (hw-offset 0))
  (let* ((xw 71) (yw 33)
	 (cu0 (make-fillet-cube xw yw yh 2))
	 (cy0 (make-cylinder 1.5 30))
	 (cy1 (make-cylinder 3 yh))
	 (cu4 (make-cube 52 50 yh))
	 (cu5 (make-cube 24 hw 20))
	 (cu6 (make-fillet-cube 25 25 20 2))
	 (*contact-threshold* 0.00001)
	 c)
    ;;
    (send cu4 :locate (float-vector 0 0 -2) :world)
    (setq c (body- cu0 cu4))
    ;;
    (when left
      (send cu5 :locate (float-vector (/ xw 2.0) hw-offset -2.0) :world)
      (setq c (body- c cu5)))
    (when right
      (send cu5 :locate (float-vector (/ xw -2.0) hw-offset -2.0) :world)
      (setq c (body- c cu5)))
    ;;
    (send cy0 :locate (float-vector x0 y0 -15) :world)
    (send cy1 :locate (float-vector x0 y0 (- (/ yh 2.0) 1.8)) :world)    
    (setq c (body- c cy0))
    (setq c (body- c cy1))
    (send cy0 :locate (float-vector (- x0) y0 -15) :world)
    (send cy1 :locate (float-vector (- x0) y0 (- (/ yh 2.0) 1.8)) :world)
    (setq c (body- c cy0))
    (setq c (body- c cy1))
    (send cy0 :locate (float-vector x0 (- y0) -15) :world)
    (send cy1 :locate (float-vector x0 (- y0) (- (/ yh 2.0) 1.8)) :world)
    (setq c (body- c cy0))
    (setq c (body- c cy1))
    (send cy0 :locate (float-vector (- x0) (- y0) -15) :world)
    (send cy1 :locate (float-vector (- x0) (- y0) (- (/ yh 2.0) 1.8)) :world)
    (setq c (body- c cy0))    
    (setq c (body- c cy1))
    ;;
    (when center
      (send cu6 :locate (float-vector 0 0 0) :world)    
      (setq c (body- c cu6)))
    c
    ))

(setq c (backcover :left nil :center nil))
(eus2stl "backcover-right-only.stl" c :scale 1)

(setq c (backcover :center nil))
(eus2stl "backcover-left-right.stl" c :scale 1)

(setq c (backcover :left nil))
(eus2stl "backcover-right-center.stl" c :scale 1)

(setq c (backcover))
(eus2stl "backcover.stl" c :scale 1)
(send c :locate (float-vector 0 0 (+ (/ 18.5 2) (/ 6 2))) :world)

(setq c8 (backcover :yh 8))
(eus2stl "backcover8.stl" c8 :scale 1)

(setq c8-15 (backcover :yh 8 :hw 15))
(eus2stl "backcover8-15.stl" c8-15 :scale 1)

(setq c8-145-1 (backcover :yh 8 :hw 14.5 :hw-offset 1))
(eus2stl "backcover8-145-1.stl" c8-145-1 :scale 1)


(setq h-0 (backholder 0))
(eus2stl "backholder-offset0.stl" h-0 :scale 1)

(setq h-d (backholder-dual))
(eus2stl "backholder-dual.stl" h-d :scale 1)

(setq h-2.5 (backholder 2.5))
(send h-2.5 :locate #f(0 35 0))
(eus2stl "backholder-offset2.5.stl" h-2.5 :scale 1)

(setq h--2.5 (backholder -2.5))
(send h--2.5 :locate #f(0 -35 0))
(eus2stl "backholder-offset-2.5.stl" h--2.5 :scale 1)

(setq h-10 (backholder 10.0))
(send h-10 :locate #f(0 70 0))
(eus2stl "backholder-offset10.stl" h-10 :scale 1)

(setq h--10 (backholder -10.0))
(send h--10 :locate #f(0 -70 0))
(eus2stl "backholder-offset-10.stl" h--10 :scale 1)

(objects (list c h-0 h-2.5 h--2.5 h-10 h--10))

