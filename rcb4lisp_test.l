
(require :rcb4lisp)

(defparameter *error-count* 0)

(defun assert-true (v msg)
  (unless v (progn
              (format t "Error: ~a." msg)
              (terpri)
              (setq *error-count* (1+ *error-count*)))))

(defun assert-eq (v1 v2 msg)
  (unless (eq v1 v2)
    (progn (format t "Error: ~a. (eq ~a ~a)" (if (null msg) "" msg) v1 v2)
           (terpri)
           (setq *error-count* (1+ *error-count*)))))

(defun assert-equal (v1 v2 &optional msg)
  (if (my-equal v1 v2) nil
    (progn (format t "Error: ~a" (if (null msg) "" msg))
           (terpri)
           (print v1)
           (format t "---")(terpri)
           (print v2)
           (format t "---")(terpri)
           (setq *error-count* (1+ *error-count*))
           t)))

(defun my-equal (e1 e2)
  (cond ((eq e1 e2) t)
        ((and (symbolp e1) (symbolp e2))
         (equal (symbol-name e1) (symbol-name e2)))
        ((and (listp e1) (listp e2))
         (and (my-equal (car e1) (car e2))
              (my-equal (cdr e1) (cdr e2))))
        ((and (vectorp e1) (vectorp e2))
         (equal e1 e2))
        (t nil)))

(defun assert-eval (e1 e2 &optional (msg nil))
  (setq rcb4lisp::*label-number* 0)
  (let ((env (rcb4lisp::make-base-env nil)))
    (send env :clear-stack nil)
    (send env :add-var 'a) (setf (cadr (send env :get-var 'a)) '(:user 20))
    (send env :add-var 'i) (setf (cadr (send env :get-var 'i)) '(:user 18))
    (send env :add-var 'x) (setf (cadr (send env :get-var 'x)) '(:user 16))

    (let* ((code (rcb4lisp::eval-expr e2 env))
           (tmpvars (send (send env :stack) :array))
           (loc (send env :max-child-vars)))
      (dotimes (i (send tmpvars :size))
        (let ((v (send tmpvars :get i)))
          (unless (null v)
            (progn (setf (cadr (cadr v)) loc)
                   (setf loc (+ loc rcb4lisp::*int-value-size*))))))
      (if (assert-equal e1 code msg)
          (progn (print e2) (terpri))))))

(defun assert-compile (e1 e2)
  (setq rcb4lisp::*label-number* 0)
  (assert-equal e1 (rcb4lisp::compile e2)))


(setq al (rcb4lisp::make-array-list 0))
(send al :set 0 'a)
; (print (send al :to_vec))
(assert-true (= (send al :size) 1) "array-list :size 1")
(assert-true (eq (send al :get 0) 'a) "array-list :get 0")
(send al :set 1 'b)
(assert-true (eq (send al :get 1) 'b) "array-list :get 1")
; (print (send al :to_vec))
(dotimes (i 9) (send al :set i i))
(assert-true (eq (send al :size) 9) "array-list :size 9")
(assert-true (eq (send al :get 8) 8) "array-list :get 8")
(dotimes (i 9) (send al :set (+ i 8) (+ i 8)))
; (print (send al :to_vec))
(dotimes (i 17)
  (assert-true (eq (send al :get i) i) "array-list :get i"))

(setq sv (rcb4lisp::make-stack-variables))
(send sv :set-base '(var0 (:user 0)))
(assert-eq (car (send sv :top)) 'var0 "stack-var :top 'var0 (first)")
(send sv :push)
(assert-eq (cadr (cadr (send sv :top))) nil "stack-var :top 0")
(send sv :pop)
(assert-eq (car (send sv :top)) 'var0 "stack-var :top 'var0")
(send sv :push)
(send sv :push)
(assert-eq (send sv :size) 3 "stack-var :size 3")
; (print (send (send sv :array) :to_vec))

(assert-eval nil '3)
(assert-eval nil nil)
(assert-eval nil 'a)
(assert-eval '((:move (:lit 1 0) (:ram (:user 0)))
               (:not 2 (:ram (:user 0)) t))
             '(not 1))
(assert-eval '((:move (:ram (:user 18) 2) (:ram (:user 20)))
               (:not 2 (:ram (:user 20))))
             '(setq a (not i)))
(assert-eval '((:move (:ram (:user 18) 2) (:ram (:user 16)))  ; x = i
               (:not 2 (:ram (:user 16)))                     ; x = !x
               (:move (:ram (:user 16) 2) (:ram (:user 20)))) ; a = x
              '(setq x (setq a (not i))))
(assert-eval '((:sub (:lit 1 0) (:ram (:user 18)) t))
             '(- i 1))
(assert-eval '((:move (:lit 3 0) (:ram (:user 0)))
               (:mul (:lit 4 0) (:ram (:user 0)))
               (:add (:ram (:user 16) 2) (:ram (:user 0)) t))
              '(+ (* 3 4) x))
(assert-eval '((:move (:lit 3 0) (:ram (:user 16)))
               (:mul (:lit 4 0) (:ram (:user 16))))
              '(setq x (* 3 4)))

(assert-eval '((:move (:lit 1 0) (:ram (:user 16)))
               (:move (:lit 2 0) (:ram (:user 20))))
              '(progn (setq x 1) (setq a 2)))

(assert-eval '((:move (:ram (:user 16) 2) (:ram (:user 20)))
               (:shift 255 2 (:ram (:user 20)))
               (:move (:ram (:user 16) 2) (:ram (:user 0)))
               (:shift 2 2 (:ram (:user 0)))
               (:add (:ram (:user 0) 2) (:ram (:user 20))))
              '(setq a (+ (<< x 1) (>> x 2))))

(assert-eval '((:jump nil |l2|)
               |l1|
               (:add (:lit 1 0) (:ram (:user 16)))
               |l2|
               (:sub (:lit 1 0) (:ram (:user 16)) t)
               (:jump (:c :c=) |l1|))
             '(while (< x 1) (setq x (+ x 1))))

(assert-eval '((:sub (:lit 1 0) (:ram (:user 16)) t)
               (:jump (:c :c<>) |l1|)
               (:add (:lit 1 0) (:ram (:user 16)) t)
               |l1|)
             '(if (< x 1) (+ x 1)))

(assert-eval '((:sub (:lit 1 0) (:ram (:user 16)) t)
               (:jump (:c :c<>) |l1|)
               (:add (:lit 1 0) (:ram (:user 16)) t)
               (:jump nil |l2|)
               |l1|
               (:sub (:lit 1 0) (:ram (:user 16)) t)
               |l2|)
              '(if (< x 1) (+ x 1) (- x 1)))

(assert-eval '((:sub (:lit 1 0) (:ram (:user 16)) t)
               (:jump (:z :z<>) |l1|)
               (:add (:lit 1 0) (:ram (:user 16)) t)
               (:jump nil |l2|)
               |l1|
               (:sub (:lit 1 0) (:ram (:user 16)) t)
               |l2|)
              '(if (= x 1) (+ x 1) (- x 1)))

(assert-eval '((:move (:lit 0 0) (:ram (:user 2)))
               (:move (:ram (:user 16) 2) (:ram (:user 0)))
               (:add (:lit 1 0) (:ram (:user 0)))
               (:add (:ram (:user 0) 2) (:ram (:user 2)) t))
             '(let ((i 0) (j (+ x 1))) (+ i j)))

(assert-eval '((:move (:ram (:user 18) 2) (:ram (:user 0)))  ; tmp = i
               (:move (:ram (:user 16) 2) (:ram (:user 2)))  ; tmp2 = x
               (:move (:ram (:user 16) 2) (:ram (:user 4)))  ; tmp3 = x
               (:mul (:lit 2 0) (:ram (:user 4)))            ; tmp3 *= 2
               (:add (:ram (:user 4) 2) (:ram (:user 2)))    ; tmp2 += tmp3
               (:add (:ram (:user 2) 2) (:ram (:user 0)))    ; tmp += tmp2
               (:move (:ram (:user 0) 2) (:ram (:user 16)))) ; x = tmp
             '(setq x (+ i (+ x (* x 2)))))

(assert-eval '((:move (:lit 0 0) (:ram (:user 12)))          ; i12 = 0
               (:move (:lit 7 0) (:ram (:user 10)))          ; j10 = 7
               (:move (:ram (:user 12) 2) (:ram (:user 6)))  ; tmp6 = i12
               (:move (:ram (:user 12) 2) (:ram (:user 8)))  ; tmp8 = i12
               (:mul (:ram (:user 10) 2) (:ram (:user 8)))   ; tmp8 *= j10
               (:add (:ram (:user 8) 2) (:ram (:user 6)))    ; tmp6 += tmp8
               (:move (:ram (:user 6) 2) (:ram (:user 12)))  ; i12 = tmp6
               (:move (:ram (:user 12) 2) (:ram (:user 4)))  ; x4 = i12
               (:move (:ram (:user 10) 2) (:ram (:user 2)))  ; y2 = j10
               (:move (:ram (:user 10) 2) (:ram (:user 4)))  ; x4 = j10
               (:move (:ram (:user 12) 2) (:ram (:user 0)))  ; tmp0 = i12
               (:mul (:ram (:user 10) 2) (:ram (:user 0)))   ; tmp0 *= j10
               (:add (:ram (:user 0) 2) (:ram (:user 4))))   ; x4 += tmp0
             '(let ((i 0) (j 7))
                (setq i (+ i (* i j)))
                (let ((x i) (y j))
                  (setq x (+ j (* i j))))))


;(print (rcb4lisp::eval-expr '(defun foo (x) (+ x 1)) env))
;(print (rcb4lisp::eval-expr '(foo 3 (+ x 1)) env))

;(setq code1
;      '((defun foo (x) (+ x 1))
;        (defun bar (x) (foo x))
;        (defun baz (x) (bar x))))

(assert-compile '((:move (:lit 0 0) (:ram (:user 0)))
                  (:servo (10) 30 #f(7500))
                  (:speed (10) #f(100))
                  (:stretch (10) #f(99)) 
                  (:return))
                '(let ((x 0))
                   (servo (10) 30 #f(7500))
                   (speed (10) #f(100))
                   (stretch (10) #f(99))))

(assert-compile '((:move (:lit 5 0) (:ram (:user 2)))
                  (:jump nil |l2|)
                  |l1|
                  (:sub (:lit 1 0) (:ram (:user 2)))
                  |l2|
                  (:move (:lit 0 0) (:ram (:user 0)))
                  (:sub (:ram (:user 2) 2) (:ram (:user 0)) t) ; 0 - i
                  (:jump (:c :c=) |l1|)                        ; < 0
                  (:return))
                '(let ((i 5))
                   (while (> i 0)  ; i - 0 > 0
                     (setq i (- i 1)))))

(assert-compile '((:move (:lit 5 0) (:ram (:user 2)))
                  (:jump nil |l2|)
                  |l1| (:sub (:lit 1 0) (:ram (:user 2)))
                  |l2| (:move (:lit 0 0) (:ram (:user 0)))
                  (:sub (:ram (:user 2) 2) (:ram (:user 0)) t) ; 0 - i
                  (:jump (:c :c=) |l1|)
                  (:return))
                '(let ((i 5))
                   (while (< 0 i )
                     (setq i (- i 1)))))

(assert-compile '((:move (:lit 5 0) (:ram (:user 2)))
                  (:jump nil |l2|)
                  |l1| (:sub (:lit 1 0) (:ram (:user 2)))
                  |l2| (:move (:lit 0 0) (:ram (:user 0)))
                  (:sub (:ram (:user 2) 2) (:ram (:user 0)) t) ; 0 - i
                  (:jump (:c :z :c= :z=) |l1|)
                  (:return))
                '(let ((i 5))
                   (while (<= 0 i )
                     (setq i (- i 1)))))

(assert-compile '((:move (:lit 5 0) (:ram (:user 2)))
                  (:jump nil |l2|)
                  |l1| (:sub (:lit 1 0) (:ram (:user 2)))
                  |l2| (:move (:lit 3 0) (:ram (:user 0)))
                  (:sub (:ram (:user 2) 2) (:ram (:user 0)) t) ; 0 - i
                  (:jump (:c :z :c= :z=) |l1|)
                  (:return))
                '(let ((i 5))
                   (while (<= 3 i )
                     (setq i (- i 1)))))

(assert-compile '(
		  (:move (:lit 5 0) (:ram (:user 2)))
		  (:jump nil |l2|)
		  |l1|
		  (:sub (:lit 1 0) (:ram (:user 2)))
		  |l2|
		  (:move (:lit 3 0) (:ram (:user 0)))
		  (:sub (:ram (:user 2) 2) (:ram (:user 0)) t)
		  (:jump (:c :c=) |l1|)
		  (:return))
		'(let ((i 5))
		  (while (< 3 i )
		    (setq i (- i 1)))))

(assert-compile '((:sub (:lit 1 0) (:ram (:user 0)) t)
                  (:jump (:c :c<>) |l1|)
                  (:add (:lit 1 0) (:ram (:user 0)) t)
                  |l1|
                  (:return))
                '(let (x) (if (< x 1) (+ x 1))))

(assert-compile '((:move (:ram (:ad 2) 2) (:ram (:user 0))) (:return))
                '(let ((x (read-ad 2))) x))


(if (> *error-count* 0)
    (format t "** Failure: ~a errors **" *error-count*)
  (princ "** Test OK **"))
(terpri)

(setq hello-code
      '(let ((count 10))
         (servo (2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19) 30
                #f(7500.0 7500.0 8700.0 6300.0 8000.0 8000.0 10500.0
                   10500.0 7500.0 9400.0 8700.0 8700.0 11300.0 11300.0
                   6300.0 8700.0 8000.0 8000.0 10500.0 10500.0 7500.0
                   7500.0 7500.0 7500.0 7500.0 7500.0 7500.0 7500.0 7500.0
                   7500.0 7500.0 7500.0 7500.0 7500.0 7500.0 7500.0))
         (servo (2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19) 30
                #f(7500.0 7500.0 8700.0 6300.0 8000.0 8000.0 10500.0 10500.0
                   7500.0 9400.0 7500.0 7500.0 11300.0 11300.0 6300.0 8700.0
                   8000.0 8000.0 10500.0 10500.0 7500.0 7500.0 7500.0 7500.0
                   7500.0 7500.0 7500.0 7500.0 7500.0 7500.0 7500.0 7500.0
                   7500.0 7500.0 7500.0 7500.0))
         (servo (2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19) 30
                #f(7500.0 7500.0 8700.0 7500.0 5300.0 10000.0 9160.0 10700.0
                   7500.0 9400.0 6800.0 5000.0 11300.0 8300.0 6300.0 8700.0
                   9300.0 7720.0 11300.0 11300.0 7500.0 7500.0 7500.0 7500.0
                   7500.0 7500.0 7500.0 7500.0 7500.0 7500.0 7500.0 7500.0
                   7500.0 7500.0 7500.0 7500.0))
         (while (< 0 count)
           (setq count (- count 1))
           (servo (2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19) 20
                  #f(7500.0 7500.0 8700.0 5700.0 5300.0 10000.0 9160.0
                     10700.0 7500.0 9400.0 6800.0 5000.0 11300.0 8300.0
                     6300.0 8700.0 9300.0 7720.0 11300.0 11300.0 7500.0
                     7500.0 7500.0 7500.0 7500.0 7500.0 7500.0 7500.0
                     7500.0 7500.0 7500.0 7500.0 7500.0 7500.0 7500.0 7500.0))
           (servo (2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19) 20
                  #f(7500.0 7500.0 8700.0 7500.0 5300.0 10000.0 9160.0
                     10700.0 7500.0 9400.0 6800.0 5000.0 11300.0 8300.0
                     6300.0 8700.0 9300.0 7720.0 11300.0 11300.0 7500.0
                     7500.0 7500.0 7500.0 7500.0 7500.0 7500.0 7500.0
                     7500.0 7500.0 7500.0 7500.0 7500.0 7500.0 7500.0 7500.0)))
         (servo (2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19) 30
                #f(7500.0 7500.0 8700.0 6300.0 8000.0 8000.0 10500.0
                   10500.0 7500.0 7500.0 8000.0 8000.0 10500.0 10500.0
                   6300.0 8700.0 8000.0 8000.0 10500.0 10500.0 7500.0
                   7500.0 7500.0 7500.0 7500.0 7500.0 7500.0 7500.0 7500.0
                   7500.0 7500.0 7500.0 7500.0 7500.0 7500.0 7500.0)))
