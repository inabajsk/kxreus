;;;; ============================================
;;;; EusLisp ファジィ推論（Mamdani）サンプル
;;;; 入力: 温度誤差 e = setpoint - current_temp  [-10, 10]
;;;; 出力: ヒータ出力 power [0, 100]
;;;; ルール:
;;;;   R1: if e is NEG  then power is LOW
;;;;   R2: if e is ZERO then power is MED
;;;;   R3: if e is POS  then power is HIGH
;;;; ============================================
 
;;; --------------------------------------------
;;; 三角形／台形メンバーシップ関数
;;; --------------------------------------------
(defun tri (x a b c)
  "三角形メンバーシップ: 頂点b, 左端a, 右端c"
  (cond
    ((or (< x a) (> x c)) 0.0)
    ((= a b)               ; 左肩（垂直）
     (if (<= x b) 1.0 (max 0.0 (/ (- c x) (- c b)))))
    ((= b c)               ; 右肩（垂直）
     (if (>= x b) 1.0 (max 0.0 (/ (- x a) (- b a)))))
    ((<= x b) (max 0.0 (/ (- x a) (- b a))))
    (t         (max 0.0 (/ (- c x) (- c b))))))
 
(defun trap (x a b c d)
  "台形メンバーシップ: 平坦部[b, c], 左端a, 右端d"
  (cond
    ((or (< x a) (> x d)) 0.0)
    ((and (>= x b) (<= x c)) 1.0)
    ((< x b) (max 0.0 (/ (- x a) (- b a))))
    (t       (max 0.0 (/ (- d x) (- d c))))))
 
;;; --------------------------------------------
;;; ユニバース設定
;;; --------------------------------------------
(defparameter *e-min* -10.0)
(defparameter *e-max*  10.0)
(defparameter *p-min*   0.0)
(defparameter *p-max* 100.0)
 
;;; サンプリング刻み（脱ファジィ化の重心法で使用）
(defparameter *p-step* 1.0)  ; 1刻みで十分な滑らかさ
 
;;; --------------------------------------------
;;; 入力ファジィ集合（誤差 e）
;;; NEG: 左寄り, ZERO: 中央, POS: 右寄り（三角形）
;;; 例: NEG = tri(e, -10, -10, 0)  ; 左肩
;;;     ZERO = tri(e, -5, 0, 5)
;;;     POS = tri(e, 0, 10, 10)    ; 右肩
;;; --------------------------------------------
(defun mu-neg (e) (tri e -10.0 -10.0 0.0))
(defun mu-zero(e) (tri e  -5.0   0.0 5.0))
(defun mu-pos (e) (tri e   0.0  10.0 10.0))
 
;;; --------------------------------------------
;;; 出力ファジィ集合（ヒータ power）
;;; LOW, MED, HIGH を三角形で定義
;;; --------------------------------------------
(defun mu-low  (p) (tri p   0.0  0.0 40.0))  ; 左肩
(defun mu-med  (p) (tri p  20.0 50.0 80.0))
(defun mu-high (p) (tri p  60.0 100.0 100.0)) ; 右肩
 
;;; --------------------------------------------
;;; ルールベース（Mamdani: min で切り取り、max で合成）
;;; R1: e is NEG  -> power is LOW
;;; R2: e is ZERO -> power is MED
;;; R3: e is POS  -> power is HIGH
;;; --------------------------------------------
(defun rule-strengths (e)
  "各ルールの発火度（前件のメンバーシップ値）を返す"
  (list (mu-neg e)   ; R1 強度
        (mu-zero e)  ; R2 強度
        (mu-pos e))) ; R3 強度
 
(defun aggregate-output (e)
  "出力宇宙 *p-min*..*p-max* をサンプルし、合成されたメンバーシップ μ_agg(p) を返す
   μ_agg(p) = max( min(μ_R1, μ_LOW(p)), min(μ_R2, μ_MED(p)), min(μ_R3, μ_HIGH(p)) )"
  (let* ((rs (rule-strengths e))
         (r1 (elt rs 0))
         (r2 (elt rs 1))
         (r3 (elt rs 2))
         (n  (+ 1 (floor (/ (- *p-max* *p-min*) *p-step*))))
         (p-list nil)
         (mu-list nil))
    (dotimes (i n)
      (let* ((p (+ *p-min* (* i *p-step*)))
             (mu (max (min r1 (mu-low p))
                      (min r2 (mu-med p))
                      (min r3 (mu-high p)))))
        (push p p-list)
        (push mu mu-list)))
    (list (nreverse p-list) (nreverse mu-list))))
 
;;; --------------------------------------------
;;; 重心法（Centroid）による脱ファジィ化
;;; crisp = (Σ p * μ(p)) / (Σ μ(p))
;;; --------------------------------------------
(defun centroid (p-list mu-list)
  (let ((num 0.0)
        (den 0.0))
    (mapcar #'(lambda (p-mu)
                (let ((p (car p-mu))
                      (mu (cadr p-mu)))
                  (setq num (+ num (* p mu)))
                  (setq den (+ den mu))))
            (mapcar #'list p-list mu-list))
    (if (> den 0.0)
        (/ num den)
      ;; すべての μ が 0 の場合は中立値（MED の頂点）にフォールバック
      50.0)))
 
;;; --------------------------------------------
;;; メイン: 現在温度と目標温度から出力を計算
;;; --------------------------------------------
(defun fuzzy-heater (current-temp setpoint)
  "ファジィ推論によりヒータ出力を返す。戻り値: (power e strengths)"
  (let* ((e (- setpoint current-temp))
         (vals (aggregate-output e))
         (p-list (elt vals 0))
         (mu-list (elt vals 1))
         (power (centroid p-list mu-list))
         (strengths (rule-strengths e)))
    (list power e strengths)))
 
;;; --------------------------------------------
;;; 実行例
;;; --------------------------------------------
(defun demo ()
  (let* ((setpoint 22.0)
         (current 18.0)  ; e = 4.0 → POS が強め → HIGH 寄り
         (ret (fuzzy-heater current setpoint))
         (power (elt ret 0))
         (e     (elt ret 1))
         (rs    (elt ret 2)))
    (format t "~%[Demo] setpoint=~A, current=~A, error e=~A~%" setpoint current e)
    (format t "  Rule strengths: R1(NEG→LOW)=~5,2F  R2(ZERO→MED)=~5,2F  R3(POS→HIGH)=~5,2F~%"
            (elt rs 0) (elt rs 1) (elt rs 2))
    (format t "  => Defuzzified power (centroid) = ~5,2F~%" power)
    power))
 
(format t ";;(demo)~%")
#|
[Demo] setpoint=22.0, current=18.0, error e=4.0
  Rule strengths: R1(NEG→LOW)= 0.00  R2(ZERO→MED)= 0.20  R3(POS→HIGH)= 0.40
  => Defuzzified power (centroid) = 68.30
68.2987
|#
