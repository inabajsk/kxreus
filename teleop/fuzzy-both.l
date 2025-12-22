;;; =========================================================
;;; Fuzzy system comparison: Sugeno (zero-order) vs Mamdani (centroid)
;;; EusLisp implementation
;;; =========================================================

(defun getf (plist key &optional default)
  (if (member key plist) (cadr (member key plist)) default))
;;
;;; ---------- 基本メンバーシップ関数 ----------
(defun grade (value x0 x1)
  (cond ((<= value x0) 0.0)
        ((<= value x1) (/ (- value x0) (- x1 x0)))
        (t 1.0)))
 
(defun reverse-grade (value x0 x1)
  (cond ((<= value x0) 1.0)
        ((<= value x1) (/ (- x1 value) (- x1 x0)))
        (t 0.0)))
 
(defun triangle (value x0 x1 x2)
  (cond ((or (<= value x0) (>= value x2)) 0.0)
        ((<= value x1) (/ (- value x0) (- x1 x0)))
        (t (/ (- x2 value) (- x2 x1)))))
 
(defun trapezoid (value x0 x1 x2 x3)
  (cond ((or (<= value x0) (>= value x3)) 0.0)
        ((<= value x1) (/ (- value x0) (- x1 x0)))  ; rising
        ((<= value x2) 1.0)                         ; top
        (t (/ (- x3 value) (- x3 x2)))))            ; falling
 
;;; ---------- ファジィ演算子 ----------
(defun f-or (a b) (max a b))
(defun f-and (a b) (min a b))
(defun f-not (a) (- 1.0 a))
(defun min* (&rest args) (apply #'min args))
(defun max* (&rest args) (apply #'max args))
 
;;; ---------- Sugeno: 非ファジィ化 ----------
(defun degrisk-sugeno (r) ; r = (vlow low med high vhigh)
  (let* ((a (nth 0 r)) (b (nth 1 r)) (c (nth 2 r)) (d (nth 3 r)) (e (nth 4 r))
         (num (+ (* -1.0 a) (* -0.5 b) (* 0.0 c) (* 0.5 d) (* 1.0 e)))
         (den (+ a b c d e)))
    (if (<= den 1e-9) 0.0 (/ num den))))
 
(defun degmov-sugeno (m) ; m = (low med high)
  (let* ((a (nth 0 m)) (b (nth 1 m)) (c (nth 2 m))
         (num (+ (* -1.0 a) (* 0.0 b) (* 1.0 c)))
         (den (+ a b c)))
    (if (<= den 1e-9) 0.0 (/ num den))))
 
(defun degarm-sugeno (a) ; a = (low med high)
  (let* ((x (nth 0 a)) (y (nth 1 a)) (z (nth 2 a))
         (num (+ (* -1.0 x) (* 0.0 y) (* 1.0 z)))
         (den (+ x y z)))
    (if (<= den 1e-9) 0.0 (/ num den))))
 
;;; ---------- Mamdani: 出力ファジィ集合（-1..+1 の範囲） ----------
;; 移動度/アーム操作度の出力集合
(defun mu-low-m (x)   (triangle x -1.00 -0.66 -0.33))
(defun mu-med-m (x)   (triangle x -0.50  0.00  0.50))
(defun mu-high-m (x)  (triangle x  0.33  0.66  1.00))
 
(defun mu-low-a (x)   (triangle x -1.00 -0.66 -0.33))
(defun mu-med-a (x)   (triangle x -0.50  0.00  0.50))
(defun mu-high-a (x)  (triangle x  0.33  0.66  1.00))
 
;; 危険度の出力集合（5カテゴリ）
(defun mu-vlow-r (x)  (triangle x -1.00 -0.80 -0.60))
(defun mu-low-r  (x)  (triangle x -0.80 -0.50 -0.20))
(defun mu-med-r  (x)  (triangle x -0.30  0.00  0.30))
(defun mu-high-r (x)  (triangle x  0.20  0.50  0.80))
(defun mu-vhigh-r(x)  (triangle x  0.60  0.80  1.00))
 
;;; ---------- Mamdani: 重心法のためのユーティリティ ----------
(defun range-list (start end step)
  (do ((x start (+ x step))
       (acc '()))
      ((> x end) (reverse acc))
    (setq acc (cons x acc))))
 
(defun centroid-aggregate (pairs domain-start domain-end step)
  "pairs: list of (alpha function) for Mamdani
   aggregated μ(x) = max_i min(alpha_i, μ_i(x))"
  (let ((num 0.0) (den 0.0))
    (dolist (x (range-list domain-start domain-end step))
      (let ((mu 0.0))
        (dolist (pr pairs)
          (let ((a (car pr)) (fn (cadr pr)))
            (setq mu (max mu (min a (funcall fn x))))))
        (setq num (+ num (* x mu)))
        (setq den (+ den mu))))
    (if (<= den 1e-9) 0.0 (/ num den))))
 
;;; ---------- 共通：前件（添付コード準拠） ----------
(defun antecedents (Fx Fy Fz StL Dist RV)
  (let ((NB-x (reverse-grade Fx -15.0 -5.0))
        (ZO-x (trapezoid Fx -15.0 -5.0 5.0 15.0))
        (PB-x (grade        Fx  5.0  15.0))
        (NB-y (reverse-grade Fy -15.0 -5.0))
        (ZO-y (trapezoid Fy -15.0 -5.0 5.0 15.0))
        (PB-y (grade        Fy  5.0  15.0))
        (NB-z (reverse-grade Fz -15.0 -5.0))
        (ZO-z (trapezoid Fz -15.0 -5.0 5.0 15.0))
        (PB-z (grade        Fz  5.0  15.0))
        (Small (reverse-grade StL 100.0 280.0))
        (Big   (grade        StL 100.0 280.0))
        (VNear-d (reverse-grade Dist 200.0 300.0))
        (Near-d  (triangle     Dist 200.0 300.0 400.0))
        (Medium-d (triangle    Dist 300.0 400.0 500.0))
        (Far-d    (triangle    Dist 400.0 500.0 600.0))
        (VFar-d   (grade       Dist 500.0 600.0))
        (VSlow-v (reverse-grade RV 30.0 60.0))
        (Slow-v  (triangle     RV 30.0 60.0 90.0))
        (Medium-v (triangle    RV 60.0 90.0 120.0))
        (Fast-v   (triangle    RV 90.0 120.0 150.0))
        (VFast-v  (grade       RV 120.0 150.0)))
    ;; 連想配列風に返す
    (list
     (list :NB-x NB-x :ZO-x ZO-x :PB-x PB-x)
     (list :NB-y NB-y :ZO-y ZO-y :PB-y PB-y)
     (list :NB-z NB-z :ZO-z ZO-z :PB-z PB-z)
     (list :Small Small :Big Big)
     (list :VNear-d VNear-d :Near-d Near-d :Medium-d Medium-d :Far-d Far-d :VFar-d VFar-d)
     (list :VSlow-v VSlow-v :Slow-v Slow-v :Medium-v Medium-v :Fast-v Fast-v :VFast-v VFast-v))))
 
;;; ---------- Sugeno 推論 ----------
(defun fuzzy-evaluate-sugeno (Fx Fy Fz StL Dist RV)
  (let* ((ant (antecedents Fx Fy Fz StL Dist RV))
         (NB-x (getf (car ant) :NB-x)) (ZO-x (getf (car ant) :ZO-x)) (PB-x (getf (car ant) :PB-x))
         (NB-y (getf (cadr ant) :NB-y)) (ZO-y (getf (cadr ant) :ZO-y)) (PB-y (getf (cadr ant) :PB-y))
         (NB-z (getf (caddr ant) :NB-z)) (ZO-z (getf (caddr ant) :ZO-z)) (PB-z (getf (caddr ant) :PB-z))
         (Small (getf (cadddr ant) :Small)) (Big (getf (cadddr ant) :Big))
         (VNear (getf (nth 4 ant) :VNear-d)) (Near (getf (nth 4 ant) :Near-d))
         (Medium-d (getf (nth 4 ant) :Medium-d)) (Far (getf (nth 4 ant) :Far-d)) (VFar (getf (nth 4 ant) :VFar-d))
         (VSlow (getf (nth 5 ant) :VSlow-v)) (Slow (getf (nth 5 ant) :Slow-v))
         (Medium-v (getf (nth 5 ant) :Medium-v)) (Fast (getf (nth 5 ant) :Fast-v)) (VFast (getf (nth 5 ant) :VFast-v))
 
         ;; --- 移動度 m ---
         (Low-m (max* (min* Small NB-x NB-y)
                      (min* Small NB-x ZO-y)
                      (min* Small NB-x PB-y)
                      (min* Small ZO-x NB-y)
                      (min* Small ZO-x ZO-y)
                      (min* Small ZO-x PB-y)
                      (min* Small PB-x NB-y)
                      (min* Small PB-x ZO-y)
                      (min* Small PB-x PB-y)))
         (Med-m (min* Big ZO-x ZO-y))
         (High-m (max* (min* Big NB-x NB-y)
                       (min* Big NB-x ZO-y)
                       (min* Big NB-x PB-y)
                       (min* Big ZO-x NB-y)
                       (min* Big ZO-x PB-y)
                       (min* Big PB-x NB-y)
                       (min* Big PB-x ZO-y)
                       (min* Big PB-x PB-y)))
         (m-list (list Low-m Med-m High-m))
 
         ;; --- アーム a ---
         (Low-a (max* (min* Big NB-x NB-z)
                      (min* Big NB-x ZO-z)
                      (min* Big NB-x PB-z)
                      (min* Big ZO-x NB-z)
                      (min* Big ZO-x ZO-z)
                      (min* Big ZO-x PB-z)
                      (min* Big PB-x NB-z)
                      (min* Big PB-x ZO-z)
                      (min* Big PB-x PB-z)))
         (Med-a (min* Small ZO-x ZO-z))
         (High-a (max* (min* Small NB-x NB-z)
                       (min* Small NB-x ZO-z)
                       (min* Small NB-x PB-z)
                       (min* Small ZO-x NB-z)
                       (min* Small ZO-x PB-z)
                       (min* Small PB-x NB-z)
                       (min* Small PB-x ZO-z)
                       (min* Small PB-x PB-z)))
         (a-list (list Low-a Med-a High-a))
 
         ;; --- 危険 r ---
         (VLow-r (max* (min* VFar VSlow)
                       (min* VFar Slow)
                       (min* Far  VSlow)))
         (Low-r  (max* (min* VFar Medium-v)
                       (min* VFar Fast)
                       (min* Far  Slow)
                       (min* Far  Medium-v)
                       (min* Medium-d VSlow)
                       (min* Medium-d Slow)
                       (min* Near VSlow)
                       (min* VNear VSlow)))
         (Med-r  (max* (min* Far    Fast)
                       (min* Medium-d Medium-v)
                       (min* Near   Slow)))
         (High-r (max* (min* VFar   VFast)
                       (min* Far    VFast)
                       (min* Medium-d Fast)
                       (min* Medium-d VFast)
                       (min* Near   Medium-v)
                       (min* Near   Fast)
                       (min* VNear  Slow)
                       (min* VNear  Medium-v)))
         (VHigh-r (max* (min* Near  VFast)
                        (min* VNear Fast)
                        (min* VNear VFast)))
         (r-list (list VLow-r Low-r Med-r High-r VHigh-r))
 
         (deg-m (degmov-sugeno m-list))
         (deg-a (degarm-sugeno a-list))
         (deg-r (degrisk-sugeno r-list))
 
         (intent
          (cond
            ((<= deg-r 0.0)
             (cond ((and (> deg-m 0.0) (<= deg-a 0.0)) "移動")
                   ((and (<= deg-m 0.0) (> deg-a 0.0))  "アーム")
                   (t "停止")))
            ((>= deg-r 0.5)
             (if (< Fx 0.0) "移動(後退)" "停止"))
            (t
             (cond ((and (> deg-m 0.0) (<= deg-a 0.0)) "回避(移動)")
                   ((and (<= deg-m 0.0) (> deg-a 0.0))  "回避(アーム)")
                   (t "停止"))))))
    (list :degmov deg-m :degarm deg-a :degrisk deg-r :intent intent)))
 
;;; ---------- Mamdani 推論 ----------
(defun fuzzy-evaluate-mamdani (Fx Fy Fz StL Dist RV &key (step 0.01))
  (let* ((ant (antecedents Fx Fy Fz StL Dist RV))
         (NB-x (getf (car ant) :NB-x)) (ZO-x (getf (car ant) :ZO-x)) (PB-x (getf (car ant) :PB-x))
         (NB-y (getf (cadr ant) :NB-y)) (ZO-y (getf (cadr ant) :ZO-y)) (PB-y (getf (cadr ant) :PB-y))
         (NB-z (getf (caddr ant) :NB-z)) (ZO-z (getf (caddr ant) :ZO-z)) (PB-z (getf (caddr ant) :PB-z))
         (Small (getf (cadddr ant) :Small)) (Big (getf (cadddr ant) :Big))
         (VNear (getf (nth 4 ant) :VNear-d)) (Near (getf (nth 4 ant) :Near-d))
         (Medium-d (getf (nth 4 ant) :Medium-d)) (Far (getf (nth 4 ant) :Far-d)) (VFar (getf (nth 4 ant) :VFar-d))
         (VSlow (getf (nth 5 ant) :VSlow-v)) (Slow (getf (nth 5 ant) :Slow-v))
         (Medium-v (getf (nth 5 ant) :Medium-v)) (Fast (getf (nth 5 ant) :Fast-v)) (VFast (getf (nth 5 ant) :VFast-v))
 
         ;; ルール強度（α）→ 出力集合（μ）への割り当て
         ;; 移動度 m
         (pairs-m
          (append
           (mapcar #'(lambda (a) (list a #'mu-low-m))
                   (list (min* Small NB-x NB-y)
                         (min* Small NB-x ZO-y)
                         (min* Small NB-x PB-y)
                         (min* Small ZO-x NB-y)
                         (min* Small ZO-x ZO-y)
                         (min* Small ZO-x PB-y)
                         (min* Small PB-x NB-y)
                         (min* Small PB-x ZO-y)
                         (min* Small PB-x PB-y)))
           (list (list (min* Big ZO-x ZO-y) #'mu-med-m))
           (mapcar #'(lambda (a) (list a #'mu-high-m))
                   (list (min* Big NB-x NB-y)
                         (min* Big NB-x ZO-y)
                         (min* Big NB-x PB-y)
                         (min* Big ZO-x NB-y)
                         (min* Big ZO-x PB-y)
                         (min* Big PB-x NB-y)
                         (min* Big PB-x ZO-y)
                         (min* Big PB-x PB-y)))))
 
         ;; アーム a
         (pairs-a
          (append
           (mapcar #'(lambda (a) (list a #'mu-low-a))
                   (list (min* Big NB-x NB-z)
                         (min* Big NB-x ZO-z)
                         (min* Big NB-x PB-z)
                         (min* Big ZO-x NB-z)
                         (min* Big ZO-x ZO-z)
                         (min* Big ZO-x PB-z)
                         (min* Big PB-x NB-z)
                         (min* Big PB-x ZO-z)
                         (min* Big PB-x PB-z)))
           (list (list (min* Small ZO-x ZO-z) #'mu-med-a))
           (mapcar #'(lambda (a) (list a #'mu-high-a))
                   (list (min* Small NB-x NB-z)
                         (min* Small NB-x ZO-z)
                         (min* Small NB-x PB-z)
                         (min* Small ZO-x NB-z)
                         (min* Small ZO-x PB-z)
                         (min* Small PB-x NB-z)
                         (min* Small PB-x ZO-z)
                         (min* Small PB-x PB-z)))))
 
         ;; 危険 r
         (pairs-r
          (append
           (mapcar #'(lambda (a) (list a #'mu-vlow-r))
                   (list (max* (min* VFar VSlow)
                               (min* VFar Slow)
                               (min* Far  VSlow))))
           (mapcar #'(lambda (a) (list a #'mu-low-r))
                   (list (max* (min* VFar Medium-v)
                               (min* VFar Fast)
                               (min* Far  Slow)
                               (min* Far  Medium-v)
                               (min* Medium-d VSlow)
                               (min* Medium-d Slow)
                               (min* Near VSlow)
                               (min* VNear VSlow))))
           (mapcar #'(lambda (a) (list a #'mu-med-r))
                   (list (max* (min* Far    Fast)
                               (min* Medium-d Medium-v)
                               (min* Near   Slow))))
           (mapcar #'(lambda (a) (list a #'mu-high-r))
                   (list (max* (min* VFar   VFast)
                               (min* Far    VFast)
                               (min* Medium-d Fast)
                               (min* Medium-d VFast)
                               (min* Near   Medium-v)
                               (min* Near   Fast)
                               (min* VNear  Slow)
                               (min* VNear  Medium-v))))
           (mapcar #'(lambda (a) (list a #'mu-vhigh-r))
                   (list (max* (min* Near  VFast)
                               (min* VNear Fast)
                               (min* VNear VFast))))))
 
         ;; 重心法（-1..+1）
         (deg-m (centroid-aggregate pairs-m -1.0 1.0 step))
         (deg-a (centroid-aggregate pairs-a -1.0 1.0 step))
         (deg-r (centroid-aggregate pairs-r -1.0 1.0 step))
 
         (intent
          (cond
            ((<= deg-r 0.0)
             (cond ((and (> deg-m 0.0) (<= deg-a 0.0)) "移動")
                   ((and (<= deg-m 0.0) (> deg-a 0.0))  "アーム")
                   (t "停止")))
            ((>= deg-r 0.5)
             (if (< Fx 0.0) "移動(後退)" "停止"))
            (t
             (cond ((and (> deg-m 0.0) (<= deg-a 0.0)) "回避(移動)")
                   ((and (<= deg-m 0.0) (> deg-a 0.0))  "回避(アーム)")
                   (t "停止"))))))
    (list :degmov deg-m :degarm deg-a :degrisk deg-r :intent intent)))
 
;;; ---------- 比較関数 ----------
(defun compare-fuzzy (Fx Fy Fz StL Dist RV)
  (let* ((s (fuzzy-evaluate-sugeno  Fx Fy Fz StL Dist RV))
         (m (fuzzy-evaluate-mamdani Fx Fy Fz StL Dist RV)))
    (format t "~%[Input] Fx=~A Fy=~A Fz=~A StL=~A Dist=~A RV=~A~%"
            Fx Fy Fz StL Dist RV)
    (format t "~%Sugeno : degmov=~6,3F degarm=~6,3F degrisk=~6,3F intent=~A"
            (getf s :degmov) (getf s :degarm) (getf s :degrisk) (getf s :intent))
    (format t "~%Mamdani: degmov=~6,3F degarm=~6,3F degrisk=~6,3F intent=~A~%"
            (getf m :degmov) (getf m :degarm) (getf m :degrisk) (getf m :intent))
    (list :sugeno s :mamdani m)))
 
;;
;;; ---------- サンプル ----------
(format t ";; (compare-demo)~%") 
(defun compare-demo ()
  ;; サンプル入力（必要に応じて変更）
  (compare-fuzzy 8.0 -2.0 3.0 250.0 450.0 80.0))
#|
compare-demo

[Input] Fx=8.0 Fy=-2.0 Fz=3.0 StL=250.0 Dist=450.0 RV=80.0

Sugeno : degmov= 0.114 degarm=-0.516 degrisk=-0.250 intent=移動
Mamdani: degmov= 0.065 degarm=-0.255 degrisk=-0.250 intent=移動
(:sugeno (:degmov 0.114286 :degarm -0.516129 :degrisk -0.25 :intent "移動")
 :mamdani (:degmov 0.065184 :degarm -0.255115 :degrisk -0.25 :intent "移動"))
2.irteusgl$ 
|#

