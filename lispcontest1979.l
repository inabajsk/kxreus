;;
;; 1978 Lisp Contest by I. Takeuchi
;;	1978.8.21 Symbol Processing 
;;	Results of LISP Processor Contest
;;
;; (lisp-contest) shows
;;

;;
;; (bita '(a b c d e f g))
;;
(defun mapappend (x fn)
  (cond ((null x) nil)
	(t (nconc (funcall fn (car x)) (mapappend (cdr x) fn)))))

(defun bita (a)
  (cond ((null (cdr a)) a)
	((null (cddr a))
	 (list (cons (car a) (cons '$ (cdr a)))))
	(t (bitl (cdr a) (list (car a))))))

(defun bitl (x j)
  (cond ((null x) nil)
	(t (nconc
	    (mapappend
	     (bita x)
	     #'(lambda (k)
		 (mapcar
		  #'(lambda (l) (list l '$ k))
		  (bita j)
		  )))))))
;;;
(defun test (a)
  (flet ((test1 nil
		(prog1
		    (print (list 'test1 (list a)))
		  (setq a (1+ a))))
	 (test2 (b)
		(print (list 'test2 (list a b)))))
	(list (test1) (test2 a))))

;;
;; (bitb '(a b c d e f g h))
;;
(defun bitbb (a)
  (flet
   ((bit nil
	 (cond ((null a) nil)
	       ((null (cdr a)) a)
	       (t 
		(let ((cdra (cdr a)))
		  (setq a (list (car a) '$ (cadr a)))
		  (mapcon
		   #'(lambda (b)
		       (g (car b)))
		   (bitb cdra))))))
    (g (b)
       (cond ((atom b) (list a))
	     (t (cons
		 (list (car a) '$ b)
		 (mapcar
		  #'(lambda (x) (cons x (cdr b)))
		  (g (car b))))))))
   (bit)))

(defun bitb (a)
  (cond ((null a) nil)
	((null (cdr a)) a)
	(t 
	 (mapcon
	  #'(lambda (b)
	      (g (car b) (list (car a) '$ (cadr a))))
	  (bitb (cdr a))))))
(defun g (b a)
  (cond ((atom b) (list a))
	(t (cons
	    (list (car a) '$ b)
	    (mapcar
	     #'(lambda (x) (cons x (cdr b)))
	     (g (car b) a))))))
;;
;; Sequence or Sort
;; (seqsort
;;
(defun seqsort (l)
  (prog (u v w)
	(setq u l)
	(setq v (minm l))
	(setq w nil)
	a
	(cond ((null u) (return w)))
	(setq v (minm u))
	(setq u (difflist v u))
	(setq w (append w (list v)))
	(go a)))

;;
(setq d100
  '(29 9 41 18 34 43 0 13 26 38 42 10 24 1 38 16 47 38 5 36 13
    5 13 26 41 9 29 44 0 5 23 45 9 49 14 35 46 49 19 21 0 10 9
    9 20 39 1 5 15 42 15 16 3 24 20 47 3 43 33 5 34 5 24 46 14
    15 11 27 13 31 14 4 49 7 0 32 41 2 40 19 7 20 0 20 17 18 1
    42 39 8 11 41 42 30 49 23 45 6 33 45))
;;
;; (seqsort d100)
;;
(defun difflist (a x)
  (cond ((null x) nil)
	((equal a (car x)) (difflist a (cdr x)))
	(t (cons (car x) (difflist a (cdr x))))))
(defun minm (l)
  (cond ((null l) nil)
	((null (cdr l)) (car l))
	(t (smaller (car l) (minm (cdr l))))))
(defun smaller (x y)
  (cond ((> y x) x) (t y)))

;;;
;;; (tarai 2n n 0)
;;;

(defun tarai (x y z)
  (cond
   ((> x y)
    (tarai (tarai (1- x) y z)
	   (tarai (1- y) z x)
	   (tarai (1- z) x y)))
   (t y)))

;;
;; tpu
;;
#|
(setf (get 'xlist 'value) '(x1 x2 x3 x4 x5 x6 x7))
(setf (get 'ylist 'value) '(y1 y2 y3 y4 y5 y6 y7))
(setf (get 'zlist 'value) '(zz1 zz2 zz3 zz4 zz5 zz6 zz7))
|#

(setq xlist '(x1 x2 x3 x4 x5 x6 x7))
(setq ylist '(y1 y2 y3 y4 y5 y6 y7))
(setq zlist '(zz1 zz2 zz3 zz4 zz5 zz6 zz7))

(defun rename (c xy)
  (prog (var z)
	(setq z zlist)
	(setq var (cadr c))
	b1
	(cond ((null var) (go b2)))
	(setq c (subst (car z) (car var) c))
	(setq z (cdr z))
	(setq var (cdr var))
	(go b1)
	b2
	(setq z xy)
	(setq var (cadr c))
	b3
	(cond ((null var) (return c)))
	(setq c (subst (car z) (car var) c))
	(setq z (cdr z))
	(setq var (cdr var))
	(go b3)))
(defun inside (a e)
  (cond ((atom e) (eq a e))
	((inside a (car e)) t)
	(t (inside a (cdr e)))))
(defun disagree (e1 e2)
  (cond ((null e1) nil)
	((or (atom e1) (atom e2))
	 (cond ((equal e1 e2) nil) (t (list e1 e2))))
	((equal (car e1) (car e2)) (disagree (cdr e1) (cdr e2)))
	((or (atom (car e1)) (atom (car e2)))
	 (list (car e1) (car e2)))
	(t (disagree (car e1) (car e2)))))
(defun unification (e1 e2)
  (prog (d u d1 d2)
	(cond
	 ((not (equal (length e1) (length e2)))
	  (return 'no)))
	b1
	(setq d (disagree e1 e2))
	(cond ((null d) (return (reverse u))))
	(setq d1 (car d))
	(setq d2 (cadr d))
	(cond ((or (member d1 xlist) (member d1 ylist)) (go b3)))
	(cond ((or (member d2 xlist) (member d2 ylist)) (go b4)))
	b2
	(return 'no)
	b3
	(cond ((inside d1 d2) (go b2)))
	(setq u (cons d u))
	(setq e1 (subst d2 d1 e1))
	(setq e2 (subst d2 d1 e2))
	(go b1)
	b4
	(cond ((inside d2 d1) (go b2)))
	(setq u (cons (reverse d) u))
	(setq e1 (subst d1 d2 e1))
	(setq e2 (subst d1 d2 e2))
	(go b1)))

(defun deletev (x y var)
  (prog (var1 tx tx1 x1)
	(setq x (append x y))
	b1
	(cond ((null var) (return x)))
	(setq var1 (car var))
	(setq tx x)
	(setq x1 nil)
	b2
	(cond ((null tx) (go b4)))
	(setq tx1 (car tx))
	(cond ((eq tx1 var1) (go b3)))
	(setq x1 (cons tx1 x1))
	(setq tx (cdr tx))
	(go b2)
	b3
	(setq x (append x1 (cdr tx)))
	b4
	(setq var (cdr var))
	(go b1)))
(defun uresolve (c1 c2 n)
  (prog (l1 l2 vc1 vc2 x y sign unif r res var v1 v2 h hist tc2)
	(setq c1 (rename c1 xlist))
	(setq c2 (rename c2 ylist))
	(setq l1 (car c1))
	(setq l2 (car c2))
	(setq vc1 (cadr c1))
	(setq vc2 (cadr c2))
	(setq c2 (caddr c2))
	(setq x (car (caddr c1)))
	(setq sign -1)
	(cond ((eq (car x) 'not) (go b7)))
	(setq sign 1)
	b1
	(cond
	 ((null c2) (return (list (reverse res) (reverse hist) n))))
	(setq y (car c2))
	(cond ((eq (car y) 'not) (go b2)))
	(go b6)
	b2
	(setq unif (unification x (cdr y)))
	b3
	(cond ((equal unif 'no) (go b6)))
	(setq r (append (reverse tc2) (cdr c2)))
	(cond ((null r) (return (list 'contradiction l1 l2))))
	(setq var nil)
	b4
	(cond ((null unif) (go b5)))
	(setq v1 (caar unif))
	(setq v2 (cadar unif))
	(setq var (cons v1 var))
	(setq r (subst v2 v1 r))
	(setq unif (cdr unif))
	(go b4)
	b5
	(setq n (1+ n))
	(setq h (list n l1 l2 (1+ (length tc2))))
	(setq r (list n (deletev vc1 vc2 var) r))
	(setq res (cons r res))
	(setq hist (cons h hist))
	b6
	(setq tc2 (cons y tc2))
	(setq c2 (cdr c2))
	(cond ((equal sign 1) (go b1)))
	b7
	(cond
	 ((null c2)
	  (return (list (reverse res) (reverse hist) n))))
	(setq y (car c2))
	(cond ((eq (car y) 'not) (go b6)))
	(setq unif (unification (cdr x) y))
	(go b3)))

(defun gunit (s1 s2 w c n)
  (prog (l s3 ss3 w1 v u res hist m x)
	(cond ((null w) (return (list res hist n))))
	(setq l (length (caddr c)))
	(setq s3 (list (list 10000 c)))
	(setq ss3 s3)
	b1
	(cond ((null w) (go b7)))
	(setq w1 (car w))
	b2
	(cond ((null ss3) (go b4)))
	(setq v (car ss3))
	(cond ((> (car w1) (car v)) (go b3)))
	(setq u (uresolve w1 (cadr v) n))
	(cond ((null (car u)) (go b3)))
	(setq res (append res (car u)))
	(setq hist (append hist (cadr u)))
	(setq n (caddr u))
	b3
	(setq ss3 (cdr ss3))
	(go b2)
	b4
	(cond ((equal (1- l) 1) (go b6)))
	(setq m (car w1))
	b5
	(cond ((null res) (go b6)))
	(setq x (cons (list m (car res)) x))
	(setq res (cdr res))
	(go b5)
	b6
	(setq w (cdr w))
	(setq ss3 s3)
	(go b1)
	b7
	(setq l (1- l))
	(cond ((equal l 1) (return (list res hist n))))
	(setq s3 x)
	(setq ss3 s3)
	(setq x nil)
	(setq w (append s1 s2))
	(go b1)))

(defun pnsort (res)
  (prog (c pos neg)
	b1
	(cond ((null res)
	       (return (list (reverse pos) (reverse neg)))))
	(setq c (caar (cddar res)))
	(cond ((equal (car c) 'not) (go b3)))
	(setq pos (cons (car res) pos))
	b2
	(setq res (cdr res))
	(go b1)
	b3
	(setq neg (cons (car res) neg))
	(go b2)))

(defun fdepth (c)
  (prog (n u)
	(setq c (car (caddr c)))
	(cond ((equal (car c) 'not) (go b1)))
	(setq c (cdr c))
	(go b2)
	b1
	(setq c (cddr c))
	b2
	(setq n 0)
	b3
	(cond ((null c) (go b5)))
	(cond ((atom (car c)) (go b4)))
	(setq u (append (cdar c) u))
	b4
	(setq c (cdr c))
	(go b3)
	b5
	(cond ((null u) (return n)))
	(setq n (1+ n))
	(setq c u)
	(setq u nil)
	(go b3)))

(defun ftest (res n4)
  (prog (c u)
	b1
	(cond ((null res) (return (reverse u))))
	(setq c (car res))
	(cond ((> (fdepth c) n4) (go b2)))
	(setq u (cons c u))
	b2
	(setq res (cdr res))
	(go b1)))
(defun subsume (c1 c2)
  (prog (z var u)
	(setq c1 (rename c1 xlist))
	(setq c1 (car (caddr c1)))
	(setq z zlist)
	(setq var (cadr c2))
	(setq c2 (car (caddr c2)))
	b1
	(cond ((null var) (go b2)))
	(setq c2 (subst (car z) (car var) c2))
	(setq var (cdr var))
	(go b1)
	b2
	(setq u (unification c1 c2))
	(cond ((equal u 'no) (return nil)))
	(return t)))
(defun stest (u res)
  (prog (r v w x1 y z)
	b1
	(cond ((null res) (go b5)))
	(setq r (car res))
	(setq z (append u v))
	b2
	(cond ((null z) (go b3)))
	(cond ((subsume (car z) r) (go b4)))
	(setq z (cdr z))
	(go b2)
	b3
	(setq v (cons r v))
	b4
	(setq res (cdr res))
	(go b1)
	b5
	(cond ((null v) (return w)))
	(setq x1 (car v))
	(setq z (cdr v))
	b6
	(cond ((null z) (go b8)))
	(cond ((subsume x1 (car z)) (go b7)))
	(setq y (cons (car z) y))
	b7
	(setq z (cdr z))
	(go b6)
	b8
	(setq w (cons x1 w))
	(setq v (reverse y))
	(setq y nil)
	(go b5)))

(defun contradict (u v)
  (prog (x1 y res)
	b1
	(cond ((or (null u) (null v)) (return nil)))
	(setq x1 (car u))
	(setq y v)
	b2
	(cond ((null y) (go b3)))
	(setq res (uresolve x1 (car y) -1))
	(cond ((equal (car res) 'contradiction) (return res)))
	(setq y (cdr y))
	(go b2)
	b3
	(setq u (cdr u))
	(go b1)))
(defun dtree (z hist n1)
  (prog (x tx x1 h m1 m2 m n)
	(setq hist (reverse hist))
	(setq x (cdr z))
	(setq z (list z))
	(cond ((> (car x) (cadr x)) (go b0)))
	(setq x (reverse x))
	b0
	(cond ((> (cadr x) n1) (go b1)))
	(setq x (list (car x)))
	b1
	(cond ((null x) (return z)))
	(setq x1 (car x))
	b2
	(cond ((equal x1 (caar hist)) (go b3)))
	(setq hist (cdr hist))
	(go b2)
	b3
	(setq x (cdr x))
	(setq h (car hist))
	(setq z (cons h z))
	(setq hist (cdr hist))
	(setq m1 (cadr h))
	(setq m2 (caddr h))
	(cond ((> m1 n1) (go b5)))
	b4
	(cond ((> m2 n1) (go b6)))
	(go b1)
	b5
	(setq n 1)
	(setq m m1)
	(go b7)
	b6
	(setq n 2)
	(setq m m2)
	b7
	(cond ((null x) (go b8)))
	(setq x1 (car x))
	(cond ((equal x1 m) (go b10)))
	(cond ((> x1 m) (go b9)))
	b8
	(setq x (append (reverse tx) (cons m x)))
	(go b11)
	b9
	(setq tx (cons x1 tx))
	(setq x (cdr x))
	(go b7)
	b10
	(setq x (append (reverse tx) x))
	b11
	(setq tx nil)
	(cond ((equal n 2) (go b1)))
	(go b4)))

(defun tpu (s1 s2 s3 w n1 n2 n3 n4)
  (prog (s w1 ts u1 u n k ck wck v pos neg hist y x1 x)
	(setq s (append s1 s2))
	(setq s (reverse s))
	b1
	(cond ((null w) (go b6)))
	(setq w1 (car w))
	b2
	(setq ts s)
	(cond ((null w1) (go b5)))
	b3
	(cond ((eq (car w1) (caar ts)) (go b4)))
	(setq ts (cdr ts))
	(go b3)
	b4
	(setq u1 (cons (car ts) u1))
	(setq w1 (cdr w1))
	(go b2)
	b5
	(setq u (cons u1 u))
	(setq w (cdr w))
	(setq u1 nil)
	(go b1)
	b6
	(setq w (reverse u))
	(setq n n1)
	(setq u (contradict s1 s2))
	(cond ((not (null u)) (return u)))
	(setq k 1)
	b7
	(cond ((> k n2) (return '(s is not proved))))
	(setq ck (car s3))
	(setq wck (car w))
	(setq v (gunit s1 s2 wck ck n))
	(cond ((null (car v)) (go b12)))
	(setq n (caddr v))
	(setq hist (append hist (cadr v)))
	(setq v (car v))
	(cond ((< k n3) (go b8)))
	(setq v (ftest v n4))
	b8
	(setq v (pnsort v))
	(setq pos (stest s1 (car v)))
	(setq neg (stest s2 (cadr v)))
	(cond ((null (append pos neg)) (go b12)))
	(setq u (contradict s1 neg))
	(cond ((not (null u)) (return (dtree u hist n1))))
	(setq u (contradict pos s2))
	(cond ((not (null u)) (return (dtree u hist n1))))
	(setq s1 (append s1 pos))
	(setq s2 (append s2 neg))
	(setq w (cdr w))
	(setq y (append pos neg))
	b9
	(cond ((null w) (go b10)))
	(setq x1 (append y (car w)))
	(setq x (cons x1 x))
	(setq w (cdr w))
	(go b9)
	b10
	(setq w (append (reverse x) (list y)))
	(setq x nil)
	b11
	(setq s3 (append (cdr s3) (list ck)))
	(setq k (1+ k))
	(go b7)
	b12
	(setq w (append (cdr w) (list nil)))
	(go b11)))

;;tpu-1
(defun tpu-1 nil
  (tpu '((1 (x y) ((p (g x y) x y))) (2 (x y) ((p x (h x y) y))))
       '((3 (x) ((not p (k x) x (k x)))))
       '((4 (x y z u v w)
	    ((not p x y u) (not p y z v) (not p x v w) (p u z w)))
	 (5 (x y z u v w)
	    ((not p x y u) (not p y z v) (not p u z w) (p x v w))))
       '((3) nil)
       5 2 3 0))
(defun tpu-2 nil
  (tpu '((1 (x) ((p e x x)))
	 (2 (x) ((p x e x)))
	 (3 (x) ((p x x e)))
	 (4 nil ((p a b c))))
       '((5 nil ((not p b a c))))
       '((6
	  (x y z u v w)
	  ((not p x y u) (not p y z v) (not p x v w) (p u z w)))
	 (7 (x y z u v w)
	    ((not p x y u) (not p y z v) (not p u z w) (p x v w))))
       '((4) nil)
       7 4 5 0))
(defun tpu-3 nil
  (tpu '((1 (x) ((p e x x))) (2 (x) ((p (i x) x e))))
       '((3 nil ((not p a e a))))
       '((4
	  (x y z u v w)
	  ((not p x y u) (not p y z v) (not p x v w) (p u z w)))
	 (5 (x y z u v w)
	    ((not p x y u) (not p y z v) (not p u z w) (p x v w))))
       '((3) (3))
       5 4 5 0))
(defun tpu-4 nil
  (tpu '((1 (x) ((p e x x))) (2 (x) ((p (i x) x e))))
       '((3 (x) ((not p a x e))))
       '((4
	  (x y z u v w)
	  ((not p x y u) (not p y z v) (not p x v w) (p u z w)))
	 (5 (x y z u v w)
	    ((not p x y u) (not p y z v) (not p u z w) (p x v w))))
       '((3) (3))
       5 4 5 0))
(defun tpu-5 nil
  (tpu '((1 (x) ((p e x x)))
	 (2 (x) ((p x w x)))
	 (3 (x) ((p x (i x) e)))
	 (5 (x) ((p (i x) x 3)))
	 (5 nil ((s a))))
       '((6 nil ((not s e))))
       '((7 (x y z) ((not s x) (not s y) (not p x (i y) z) (s z)))
	 (8 (x y z u v w)
	    ((not p x y u) (not p y z v) (not p x v w) (p u z w)))
	 (9 (x y z u v w)
	    ((not p x y u) (not p y z v) (not p u z w) (p x v w))))
       '((6) nil nil)
       9 4 5 0))
(defun tpu-6 nil
  (tpu '((1 (x) ((p e x x)))
	 (2 (x) ((p x e x)))
	 (3 (x) ((p x (i x) e)))
	 (5 (x) ((p (i x) x e)))
	 (5 nil ((s b))))
       '((6 nil ((not s (i b)))))
       '((7 (x y z) ((not s x) (not s y) (not p x (i y) z) (s z)))
	 (8 (x y z u v w)
	    ((not p x y u) (not p y z v) (not p x v w) (p u z w)))
	 (9 (x y z u v w)
	    ((not p x y u) (not p y z v) (not p u z w) (p x v w))))
       '((5 6) nil nil)
       9 4 5 0))

(defun tpu-7 nil
  (tpu '((1 nil ((p a)))
	 (2 nil ((m a (s c) (s b))))
	 (3 (x) ((m x x (s x)))))
       '((4 nil ((not d a b))))
       '((5 (x y z) ((not m x y z) (m y x z)))
	 (6 (x y z) ((not m x y z) (d x z)))
	 (7 (x y z u)
	    ((not p x) (not m y z u) (not d x u) (d x y) (d x z))))
       '((1 2 3 4) (1 2 3 4) (1 2 3 4))
       7 4 5 0))
(defun tpu-8 nil
  (tpu '((1 nil ((l 1 a))) (2 (x) ((d x x))))
       nil
       '((3 (x) ((p x) (d (g x) x)))
	 (4 (x) ((p x) (l 1 (g x))))
	 (5 (x) ((p x) (l (g x) x)))
	 (6 (x) ((not p x) (not d x a)))
	 (7 (x y z) ((not d x y) (not d y z) (d x z)))
	 (8 (x) ((not l 1 x) (not l x a) (p (f x))))
	 (9 (x) ((not l 1 x) (not l x a) (d (f x) x))))
       '((1 2) (1 2) (1 2) (1 2) (1 2) (1 2) (1 2))
       9 20 21 0))
(defun tpu-9 nil
  (tpu '((1 (x) ((l x (f x)))))
       '((2 (x) ((not l x x))))
       '((3 (x y) ((not l x y) (not l y x)))
	 (4 (x y) ((not d x (f y)) (l y x)))
	 (5 (x) ((p x) (d (h x) x)))
	 (6 (x) ((p x) (p (h x))))
	 (7 (x) ((p x) (l (h x) x)))
	 (8 (x) ((not p x) (not l a x) (l (f a) x))))
       '((1 2) (1 2) (1 2) (1 2) (1 2) (1 2))
       8 20 21 0))

;;
(defun tpu-all nil
  (pprint (list 'tpu-1 (tpu-1)))
  (pprint (list 'tpu-2 (tpu-2)))
  (pprint (list 'tpu-3 (tpu-3)))
  (pprint (list 'tpu-4 (tpu-4)))
  (pprint (list 'tpu-5 (tpu-5)))
  (pprint (list 'tpu-6 (tpu-6)))
  (pprint (list 'tpu-7 (tpu-7)))
  (pprint (list 'tpu-8 (tpu-8)))
  (pprint (list 'tpu-9 (tpu-9)))
  )

;; 
(defun bita-7 nil
  (bita '(a b c d e f g)))

(defun bitb-8 nil
  (bitb '(a b c d e f g h)))

(defun sort-100 nil
  (seqsort d100))

(defun tarai-5 nil
  (tarai 10 5 0))

(defun lisp-contest nil
  (mapc
   #'(lambda (f cnt)
       (format t "(timing ~A	(~A))	" cnt f)
       (timing cnt (apply f nil)))
   '(bita-7 bitb-8 sort-100 tarai-5 tpu-2 tpu-6)
   '(10000 4000 2000 100 100 100))
  )

(format t ";; (lisp-contest)~%")
