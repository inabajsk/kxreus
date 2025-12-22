
;;; =========================================================
;;; Fuzzy system (Sugeno zero-order) in EusLisp
;;; =========================================================
 
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
        ((<= value x1) (/ (- value x0) (- x1 x0)))  ; rising edge
        ((<= value x2) 1.0)                         ; top
        (t (/ (- x3 value) (- x3 x2)))))            ; falling edge
 
;;; ---------- ファジィ演算子 ----------
(defun f-or (a b) (max a b))
(defun f-and (a b) (min a b))
(defun f-not (a) (- 1.0 a))
 
(defun min* (&rest args) (apply #'min args))
(defun max* (&rest args) (apply #'max args))
 
;;; ---------- 非ファジィ化 ----------
(defun degrisk (r) ; r = (vlow low med high vhigh)
  (let* ((a (nth 0 r)) (b (nth 1 r)) (c (nth 2 r)) (d (nth 3 r)) (e (nth 4 r))
         (num (+ (* -1.0 a) (* -0.5 b) (* 0.0 c) (* 0.5 d) (* 1.0 e)))
         (den (+ a b c d e)))
    (if (<= den 1e-9) 0.0 (/ num den))))
 
(defun degmov (m) ; m = (low med high)  -> weights (-1,0,1)
  (let* ((a (nth 0 m)) (b (nth 1 m)) (c (nth 2 m))
         (num (+ (* -1.0 a) (* 0.0 b) (* 1.0 c)))
         (den (+ a b c)))
    (if (<= den 1e-9) 0.0 (/ num den))))
 
(defun degarm (a) ; a = (low med high) -> weights (-1,0,1)
  (let* ((x (nth 0 a)) (y (nth 1 a)) (z (nth 2 a))
         (num (+ (* -1.0 x) (* 0.0 y) (* 1.0 z)))
         (den (+ x y z)))
    (if (<= den 1e-9) 0.0 (/ num den))))
 
;;; ---------- ルール評価（添付コード準拠） ----------
(defun fuzzy-evaluate (Fx Fy Fz StL Dist RV)
  "入力: 力Fx,Fy,Fz [任意単位]、歩幅StL[mm]、相対距離Dist[mm]、相対速度RV[mm/s]
   出力: (degmov degarm degrisk intent intent2) を返す。
   intent2 は履歴フィルタなし版の簡易判定。"
  (let* (;; 前件（力）
         (NB-x (reverse-grade Fx -15.0 -5.0))
         (ZO-x (trapezoid Fx -15.0 -5.0 5.0 15.0))
         (PB-x (grade        Fx  5.0  15.0))
         (NB-y (reverse-grade Fy -15.0 -5.0))
         (ZO-y (trapezoid Fy -15.0 -5.0 5.0 15.0))
         (PB-y (grade        Fy  5.0  15.0))
         (NB-z (reverse-grade Fz -15.0 -5.0))
         (ZO-z (trapezoid Fz -15.0 -5.0 5.0 15.0))
         (PB-z (grade        Fz  5.0  15.0))
         ;; 歩幅
         (Small (reverse-grade StL 100.0 280.0))
         (Big   (grade        StL 100.0 280.0))
         ;; 距離
         (VNear-d (reverse-grade Dist 200.0 300.0))
         (Near-d  (triangle     Dist 200.0 300.0 400.0))
         (Medium-d (triangle    Dist 300.0 400.0 500.0))
         (Far-d    (triangle    Dist 400.0 500.0 600.0))
         (VFar-d   (grade       Dist 500.0 600.0))
         ;; 相対速度
         (VSlow-v (reverse-grade RV 30.0 60.0))
         (Slow-v  (triangle     RV 30.0 60.0 90.0))
         (Medium-v (triangle    RV 60.0 90.0 120.0))
         (Fast-v   (triangle    RV 90.0 120.0 150.0))
         (VFast-v  (grade       RV 120.0 150.0))
 
         ;; --- 移動度 m（Low, Medium, High） ---
         (Low-m
          (max* (min* Small NB-x NB-y)
                (min* Small NB-x ZO-y)
                (min* Small NB-x PB-y)
                (min* Small ZO-x NB-y)
                (min* Small ZO-x ZO-y)
                (min* Small ZO-x PB-y)
                (min* Small PB-x NB-y)
                (min* Small PB-x ZO-y)
                (min* Small PB-x PB-y)))
         (Medium-m (min* Big ZO-x ZO-y))
         (High-m
          (max* (min* Big NB-x NB-y)
                (min* Big NB-x ZO-y)
                (min* Big NB-x PB-y)
                (min* Big ZO-x NB-y)
                (min* Big ZO-x PB-y)
                (min* Big PB-x NB-y)
                (min* Big PB-x ZO-y)
                (min* Big PB-x PB-y)))
         (m-list (list Low-m Medium-m High-m))
 
         ;; --- アーム操作度 a（Low, Medium, High） ---
         (Low-a
          (max* (min* Big NB-x NB-z)
                (min* Big NB-x ZO-z)
                (min* Big NB-x PB-z)
                (min* Big ZO-x NB-z)
                (min* Big ZO-x ZO-z)
                (min* Big ZO-x PB-z)
                (min* Big PB-x NB-z)
                (min* Big PB-x ZO-z)
                (min* Big PB-x PB-z)))
         (Medium-a (min* Small ZO-x ZO-z))
         (High-a
          (max* (min* Small NB-x NB-z)
                (min* Small NB-x ZO-z)
                (min* Small NB-x PB-z)
                (min* Small ZO-x NB-z)
                (min* Small ZO-x PB-z)
                (min* Small PB-x NB-z)
                (min* Small PB-x ZO-z)
                (min* Small PB-x PB-z)))
         (a-list (list Low-a Medium-a High-a))
 
         ;; --- 危険度 r（VLow, Low, Med, High, VHigh） ---
         (VLow-r (max* (min* VFar-d VSlow-v)
                       (min* VFar-d Slow-v)
                       (min* Far-d  VSlow-v)))
         (Low-r  (max* (min* VFar-d Medium-v)
                       (min* VFar-d Fast-v)
                       (min* Far-d  Slow-v)
                       (min* Far-d  Medium-v)
                       (min* Medium-d VSlow-v)
                       (min* Medium-d Slow-v)
                       (min* Near-d   VSlow-v)
                       (min* VNear-d  VSlow-v)))
         (Med-r  (max* (min* Far-d    Fast-v)
                       (min* Medium-d Medium-v)
                       (min* Near-d   Slow-v)))
         (High-r (max* (min* VFar-d   VFast-v)
                       (min* Far-d    VFast-v)
                       (min* Medium-d Fast-v)
                       (min* Medium-d VFast-v)
                       (min* Near-d   Medium-v)
                       (min* Near-d   Fast-v)
                       (min* VNear-d  Slow-v)
                       (min* VNear-d  Medium-v)))
         (VHigh-r (max* (min* Near-d  VFast-v)
                        (min* VNear-d Fast-v)
                        (min* VNear-d VFast-v)))
         (r-list (list VLow-r Low-r Med-r High-r VHigh-r))
 
         ;; --- 非ファジィ化 ---
         (deg-m (degmov m-list))
         (deg-a (degarm a-list))
         (deg-r (degrisk r-list))
 
         ;; --- 意図判定（添付コードのロジックに準拠した簡易版） ---
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
                   (t "停止")))))
         ;; 履歴なしの意図（参考）
         (intent2 intent)) ; ここでは同じにしているが、必要なら履歴平均を入れる
    (list deg-m deg-a deg-r intent intent2)))
 
;;; ---------- サンプル実行 ----------
(defun demo-fuzzy ()
  (let* (;; サンプル入力（適宜変更してください）
         (Fx 8.0)    ; 前後方向力
         (Fy -2.0)   ; 左右方向力
         (Fz 3.0)    ; 上下方向力
         (StL 250.0) ; 歩幅[mm]
         (Dist 450.0); 相対距離[mm]
         (RV 80.0)   ; 相対速度[mm/s]
         (out (fuzzy-evaluate Fx Fy Fz StL Dist RV)))
    (format t "~%[Input] Fx=~A Fy=~A Fz=~A StL=~A Dist=~A RV=~A~%"
            Fx Fy Fz StL Dist RV)
    (format t "[Output] degmov=~A degarm=~A degrisk=~A intent=~A~%"
            (nth 0 out) (nth 1 out) (nth 2 out) (nth 3 out))
    out))
 
(format t ";; (demo-fuzzy)~%")
;;; 実行例:
;;; (demo-fuzzy)
;;; => [Output] degmov=... degarm=... degrisk=... intent="回避(移動)" など
#|
(demo-fuzzy)
[Input] Fx=8.0 Fy=-2.0 Fz=3.0 StL=250.0 Dist=450.0 RV=80.0
[Output] degmov=0.114286 degarm=-0.516129 degrisk=-0.25 intent=移動
(0.114286 -0.516129 -0.25 "移動" "移動")
|#
