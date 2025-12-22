;;; =========================================================
;;; Fuzzy system comparison: Sugeno (zero-order) vs Mamdani (centroid)
;;; EusLisp implementation created by M.I with CoPilot, 2025.12.22
;;; from
;;; 永原克起: マスタスレーブロボットにおける操作意図を推定するための制御系設計
;;; (Control System Design to Estimate Operating Intention on Master-Slave Robot)
;;; 富山県立大学工学部知能デザイン工学科卒業論文,2018.2.指導教員 小柳健一准教授
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
    (format t "~%[Input] Fx=~A Fy=~A Fz=~A StL=~A Dist=~A RV=~A"
            Fx Fy Fz StL Dist RV)
    (format t "~%Sugeno : degmov=~6,3F degarm=~6,3F degrisk=~6,3F intent=~A"
            (getf s :degmov) (getf s :degarm) (getf s :degrisk) (getf s :intent))
    (format t "~%Mamdani: degmov=~6,3F degarm=~6,3F degrisk=~6,3F intent=~A~%"
            (getf m :degmov) (getf m :degarm) (getf m :degrisk) (getf m :intent))
    (list :sugeno s :mamdani m)))
 
;;
;;; ---------- サンプル ----------
(defun compare-demo ()
  ;; サンプル入力（必要に応じて変更）
  (compare-fuzzy 8.0 -2.0 3.0 250.0 450.0 80.0))
(defun compare-demo1 ()
  (format t "~%(1) 移 動 操 作 を 想 定 し た 検 証
周囲に障害物がない環境で移動操作を行う場合．操作意図は「移動する」．移
動を 行うので入力は歩幅は大きく，力センサには進みたい方向に力が加わる．
また，近くには障害物がないため 相対距離が遠く，相対速度が遅い．")
  ;;[Input] Fx=12.0 Fy=-6.0 Fz=-6.0 StL=250.0 Dist=220.0 RV=40.0
  (compare-fuzzy 12.0 -6.0 -6.0 250.0 220.0 40.0))
(defun compare-demo2 ()
  (format t "~%(2) 回 避 操 作 を 想 定 し た 検 証
進行方向遠くから障害物が向かってきた場合．操作意図は「 回避する (移動
時)」移動をしているため，入力は歩幅は大きく，力センサには進みたい方向
に力が加わる．遠くから障害物が向かってきていることから相対距離が遠く，
相対速度は速い．")
  ;;[Input] Fx=6.0 Fy=13.0 Fz=-5.0 StL=230.0 Dist=230.0 RV=110.0
  (compare-fuzzy 6.0 13.0 -5.0 230.0 230.0 110.0))
(defun compare-demo3 ()
  (format t "~%(3) 移 動 操 作 中 の 誤 操 作 を 想 定 し た 検 証
移動操作として右旋回を行っている際に，誤って下向きに力を加えてしまった
場 合．操作意図は「 移動する 」．移動を行うので入力は歩幅は大きく，ま
た右旋回を行うので力センサにはyの正方向に力が加わる．")
  ;;[Input] Fx=6.0 Fy=12.0 Fz=-11.0 StL=250.0 Dist=210.0 RV=40.0
  (compare-fuzzy 6.0 12.0 -11.0 250.0 210.0 40.0))
(defun compare-demo4 ()
  (format t "~%(4) ア ー ム 操 作 を 想 定 し た 検 証
アームを上げる操作を行っている場合．操作意図は「 アームを動かす」．アー
ムの操作を行っているため，歩幅は小さく，力センサにはzの正方向に力が加
わる．物を持ち上げようとしていることから物体との相対距離は近く，移動は
行っていないため相対速度は0である．")
  ;;[Input] Fx=6.0 Fy=4.0 Fz=12.0 StL=120.0 Dist=50.0 RV=0.0
  (compare-fuzzy 6.0 4.0 12.0 120.0 50.0 0.0))
(defun compare-demo5 ()
  (format t "~%(5) ア ー ム 操 作 中 の 誤 操 作 を 想 定 し た 検 証
アームを上げる操作を行っている際に足を動かしてしまった場合．操作意図は
「アームを動かす」．アームの操作を行っているため，入力は力センサにはz
の正方向に力が加わる．物を持ち上げようとしていることから物体との相対距
離は近く，移動は行っていないため相対速度は0である．また，足を動かして
しまったことから歩幅は大きい．")
  ;;[Input] Fx=6.0 Fy=4.0 Fz=12.0 StL=220.0 Dist=60.0 RV=0.0
  (compare-fuzzy 6.0 4.0 12.0 220.0 60.0 0.0))

(format t "(demo) ;; examples~%")
(defun demo nil
  (compare-demo)
  (compare-demo1)  
  (compare-demo2)
  (compare-demo3)  
  (compare-demo4)
  (compare-demo5)
  )
#|
1.irteusgl$ demo

[Input] Fx=8.0 Fy=-2.0 Fz=3.0 StL=250.0 Dist=450.0 RV=80.0
Sugeno : degmov= 0.114 degarm=-0.516 degrisk=-0.250 intent=移動
Mamdani: degmov= 0.065 degarm=-0.255 degrisk=-0.250 intent=移動

(1) 移 動 操 作 を 想 定 し た 検 証
周囲に障害物がない環境で移動操作を行う場合．操作意図は「移動する」．移
動を 行うので入力は歩幅は大きく，力センサには進みたい方向に力が加わる．
また，近くには障害物がないため 相対距離が遠く，相対速度が遅い．
[Input] Fx=12.0 Fy=-6.0 Fz=-6.0 StL=250.0 Dist=220.0 RV=40.0
Sugeno : degmov= 0.457 degarm=-0.516 degrisk=-0.139 intent=移動
Mamdani: degmov= 0.213 degarm=-0.255 degrisk=-0.095 intent=移動

(2) 回 避 操 作 を 想 定 し た 検 証
進行方向遠くから障害物が向かってきた場合．操作意図は「 回避する (移動
時)」移動をしているため，入力は歩幅は大きく，力センサには進みたい方向
に力が加わる．遠くから障害物が向かってきていることから相対距離が遠く，
相対速度は速い．
[Input] Fx=6.0 Fy=13.0 Fz=-5.0 StL=230.0 Dist=230.0 RV=110.0
Sugeno : degmov= 0.370 degarm=-0.566 degrisk= 0.833 intent=停止
Mamdani: degmov= 0.161 degarm=-0.277 degrisk= 0.650 intent=停止

(3) 移 動 操 作 中 の 誤 操 作 を 想 定 し た 検 証
移動操作として右旋回を行っている際に，誤って下向きに力を加えてしまった
場 合．操作意図は「 移動する 」．移動を行うので入力は歩幅は大きく，ま
た右旋回を行うので力センサにはyの正方向に力が加わる．
[Input] Fx=6.0 Fy=12.0 Fz=-11.0 StL=250.0 Dist=210.0 RV=40.0
Sugeno : degmov= 0.457 degarm=-0.464 degrisk=-0.152 intent=移動
Mamdani: degmov= 0.213 degarm=-0.236 degrisk=-0.105 intent=移動

(4) ア ー ム 操 作 を 想 定 し た 検 証
アームを上げる操作を行っている場合．操作意図は「 アームを動かす」．アー
ムの操作を行っているため，歩幅は小さく，力センサにはzの正方向に力が加
わる．物を持ち上げようとしていることから物体との相対距離は近く，移動は
行っていないため相対速度は0である．
[Input] Fx=6.0 Fy=4.0 Fz=12.0 StL=120.0 Dist=50.0 RV=0.0
Sugeno : degmov=-0.717 degarm= 0.530 degrisk=-0.500 intent=アーム
Mamdani: degmov=-0.374 degarm= 0.257 degrisk=-0.500 intent=アーム

(5) ア ー ム 操 作 中 の 誤 操 作 を 想 定 し た 検 証
アームを上げる操作を行っている際に足を動かしてしまった場合．操作意図は
「アームを動かす」．アームの操作を行っているため，入力は力センサにはz
の正方向に力が加わる．物を持ち上げようとしていることから物体との相対距
離は近く，移動は行っていないため相対速度は0である．また，足を動かして
しまったことから歩幅は大きい．
[Input] Fx=6.0 Fy=4.0 Fz=12.0 StL=220.0 Dist=60.0 RV=0.0
Sugeno : degmov=-0.212 degarm=-0.256 degrisk=-0.500 intent=停止
Mamdani: degmov=-0.120 degarm=-0.105 degrisk=-0.500 intent=停止
|#
