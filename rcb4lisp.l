;; A mini language for RCB4.
;; written by Shigeru Chiba in 2019.5.2
;;

#|
(rcb4lisp::compile <program>) compiles <program> into the assembly code
for RCB-4.  <program> is written in a Lisp-like mini language.
For example,

(rcb4lisp::compile '(let ((i 5))
                      (while (> i 0)
                        (setq i (- i 1)))))

generates the following assembly code:

  ((:move (:lit 5 0) (:ram (:user 2)))
   (:jump nil |l2|)
   |l1|
   (:sub (:lit 1 0) (:ram (:user 2)))
   |l2|
   (:move (:lit 0 0) (:ram (:user 0)))
   (:sub (:ram (:user 2) 2) (:ram (:user 0)) t)
   (:jump (:c :c=) |l1|)
   (:return))

The language supports let, if, while, progn, return, setq,
+, -, *, /, mod, and, or, xor, <<, >>, not, servo, speed, stretch,
and read-ad.
The number literals are also available.

* Binary expressions such as +, -, ...
  The arithmetic operators take only two operands.
  (+ x y z) is invalid.  Write (+ x (+ y z)).

* (let ((<variable> <expression>) ...) <expression> ...)
  declares a local variable.  Since LET evaluates to void,
  it cannot be an operand of arithmetic operations such as + and -.

* (setq <variable> <expression>)
  sets <variable> to the value of <expression>.
  It reports an error when <variable> is an unbound variable.
  <variable> must be declared by let before setq.
  SETQ evaluates to the value of <expression>.
  So (setq x (setq y (+ i 1))) is valid.

* (if <condition> <then-expression>) or
  (if <condition> <then-expression> <else-expression>)
  <condition> must be a binary expression <, >, <=, >=, = (or ==), or !=.
  <condition> cannot contain logical AND or OR expressions.
  IF evaluates to void.  it cannot be an operand of arithmetic
  operations such as + and -.

* (return)
  ends the execution.  It is implicitly added to the end of the
  program.

* (servo (ids) time #f(values))
  sends the VALUES to the motors with IDS at TIME.
  IDS, TIMES, and VALUES must be literals.  They have to be
  compile-time constants.

;; (servo xxx) extension: 2020.11
* (servo symbol-name (methods) time)
  symbol-name is a global variable of robot model or robot interface
  in the USER package. methods are methods to the value of the symbol.

* (servo ri (methods) time)
  ri is a rcb4-interface for robot interface with robot model
  methods are methods to ri.

* (servo robo (methods) time)
  robo is an instance of robot-model with robot-interface
  methods are methods for robo
;;

* (speed (ids) #f(values))
* (stretch (ids) #f(values))
  sends the VALUES to the motors with IDS.
  IDS and VALUES must be literals.

* (read-ad <offset>)  ;; offset: 0 .. 10
  reads the 16bit A/D port (:ram (:ad <offset>)).

* (read-button)
  reads the 16bit code of received remocon button (:ram :button 2).

* (read-servo idx offset)
  reads the 16bit code of servo state in each 20 bytes servo registers
  (:ram (:servo id offset) 2).
  idx = 0 .. 35, offset = 0 .. 19. described in RCB-4HV firmware reference.
  offset 2(W) : trim value, 4 : current value, 6 : reference value
  offset 8(B) : interpolation time (velocity)

* (read-servo-trim idx)
  reads the 16bit code of the current servo position (:ram (:servo idx 2) 2).

* (read-servo-pos idx)
  reads the 16bit code of the current servo position (:ram (:servo idx 4) 2).

* (read-servo-ref idx)
  reads the 16bit code of the current servo position (:ram (:servo idx 6) 2).

* (write-servo-ref idx val)
  writes val, a 16bit value, to the idx servo reference position (:ram (:servo id 6) 2).


Note that the values available in this language are 16bit natural numbers
(and zero) only.  The language assumes RCB-4 is a 16bit machine and
adopts little-endian.

|#

(provide :rcb4lisp)

(eval-when (eval load)
	   (unless (find-package "RCB4LISP") (make-package "RCB4LISP"))
	   (in-package  "RCB4LISP"))

(defparameter *compile-error-count* 0)
(defparameter *label-number* 0)

(defvar *int-value-size* 2)    ; 2 bytes
(defvar *num-of-variables* 22) ; the maximum number of user variable.

;
; helper classes
;

(defclass array-list :super object
  :slots (vec size))

(defmethod array-list
  (:init (vec_size)
         (setq size vec_size)
         (setq vec (make-array vec_size)))
  (:set (idx val)
        (if (< idx size)
            (setf (svref vec idx) val)
          (if (< idx (length vec))
              (progn (setq size (1+ idx))
                     (setf (svref vec idx) val))
            (let* ((size2 (+ (logand (lognot 7) idx) 8))
                   (vec2 (make-array size2)))
              (dotimes (i size)
                (setf (svref vec2 i) (svref vec i)))
              (setf (svref vec2 idx) val)
              (setq size (1+ idx))
              (setq vec vec2)))))
  (:get (idx) (svref vec idx))
  (:size () size)
  (:to_vec () vec))

(defun make-array-list (size) (instance array-list :init size))

(defclass stack-variables :super object
  :slots (array sp))

(defmethod stack-variables
  (:init ()
         (setq array (make-array-list 1))
         (send self :set-base nil))
  (:set-base (var)   ; (name (:user index)) or nil
             (send array :set 0 var)
             (setq sp 1))
  (:push ()
         (if (>= sp (send array :size))
             (send array :set sp (list :tmp (list :user nil))))
         (let ((var (send array :get sp)))
           (setq sp (1+ sp))
           var))
  (:pop ()
        (setq sp (1- sp))
        (send array :get sp))
  (:top () (send array :get (1- sp)))
  (:size () (send array :size))

  ; for debugging
  (:sp () sp)
  (:array () array)
)

(defun make-stack-variables () (instance stack-variables :init))

(defclass eval-env :super object
  :slots (parent vars stack child-vars-count funcs))

(defmethod eval-env
  (:init (parent-env func-list)
   (setq parent parent-env)
   (setq vars (list))
   (setq stack (make-stack-variables))
   ;;(setq vars-count 0)
   (setq child-vars-count 0)
   (setq funcs func-list))
  (:make-child () (instance eval-env :init self funcs))
  (:funcs () funcs)    ; function list
  (:vars  () vars)
  (:stack () stack)

  (:get-func (name) (assoc name funcs))
  (:add-var (name) (setq vars (cons (list name (list :user nil)) vars)))
  (:get-var (name)
            (let ((found (assoc name vars)))
              (if (null found)
                  (if (null parent) nil
                    (send parent :get-var name))
                found)))
  (:push () (send stack :push))
  (:clear-stack (var)  ; (name (:user index)) or nil
                (send stack :set-base var))
  (:pop () (send stack :pop))
  (:top () (send stack :top))

  (:max-child-vars () child-vars-count) ; # of the variables used
                                       ; in the children.
  (:set-max-child-vars (n)
                       (if (> n child-vars-count)
                           (setq child-vars-count n)))

  ; debug
  (:stack-elements () (send (send stack :array) :to_vec)))

(defun make-base-env (exprs)
  (instance eval-env :init nil (read-defuns exprs)))

(defun read-defuns (exprs)
  (if (null exprs) nil
    (let* ((funcs (read-defuns (cdr exprs)))
           (expr (car exprs)))
      (if (eq (car expr) 'defun)
          (let ((name (cadr expr)))
            (if (null (assoc name funcs))
                (cons (list name expr nil) funcs)
              (progn (print-error "duplicated defun" name)
                     funcs)))
        funcs))))

;
; end of helper classes
;

; Compiles an expression.  The generated code ends with :return.
(defun compile (expr)
  (setq *compile-input* expr)
  (let* ((env  (make-base-env nil))
         (code (nconc (eval-expr expr env) '((:return))))
         (loc  (give-loc-to-vars env (send env :max-child-vars))))
    (if (> loc *num-of-variables*)
        (print-error "too many user variables" expr))
    (setq *compile-output* code)
    code))

; Evaluate an expression
; When (send env :top) is nil, the resulting value will be discarded.
; Otherwise, the resulting value has to be stored in the variable
; given by (send env :top).
(defun eval-expr (expr env)
  (cond
   ((null expr) (eval-number '0 env))
   ((listp expr)
    (let ((name (symbol-name (car expr))))
      (cond ((equal name "DEFUN") (eval-defun expr env))
            ((equal name "LET") (eval-let expr env))
            ((equal name "IF") (eval-if expr env))
            ((equal name "WHILE") (eval-while expr env))
            ((equal name "PROGN") (eval-progn expr env))
            ((equal name "RETURN") (eval-return expr env))
            ((equal name "SETQ") (eval-setq expr env))
	    ((equal name "WRITE-SERVO-REF")
	     (eval-call-to-write-servo-REF expr env))
            ((member name '("+" "-" "*" "/" "MOD") :test #'equal)
             (eval-binary expr env))
            ((member name '("AND" "OR" "XOR") :test #'equal)
             (eval-logical expr env))
            ((member name '("<<" ">>") :test #'equal)
             (eval-shift expr env))
            ((equal name "NOT") (eval-not expr env))
            (t (eval-call expr env)))))
   ((numberp expr) (eval-number expr env))
   ((is-variable expr) (eval-var expr env))
   (t (progn (print-error "unknown expression" expr)
             nil))))

; true if expr is a variable.
(defun is-variable (expr) (symbolp expr))

; true if the 2nd operand in expr contains a (self-recursive)
; reference to var.
; This is used to find a self recursive reference such as v
; in (setq v (+ a v)).  (eval-expr '(setq v (+ a v)) env) calls
; (includes-self-in-right 'v '(+ a v)).
(defun includes-self-in-right (var expr)
  (if (and (listp expr)
           (member (symbol-name (car expr))
                   '("+" "-" "*" "/" "MOD" "<<" ">>") :test #'equal)
           (is-variable (cadr expr)))
      (includes-var var (caddr expr))
    (includes-var var expr)))

; true if expr contains a (self-recursive) reference to var.
(defun includes-var (var expr)
  (cond
   ((null expr) nil)
   ((listp expr)
    (let ((name (symbol-name (car expr))))
      (cond ((member name '("+" "-" "*" "/" "MOD" "<<" ">>" "SETQ"
			    "WRITE-SERVO-REF")
                     :test #'equal) ; operators available in r-values
             (or (includes-var var (cadr expr))
                 (includes-var var (caddr expr))))
            ((member name '("NOT" "READ-AD" "READ-BUTTON" "READ-RAM"
			    "READ-SERVO" "READ-SERVO-REF" "READ-SERVO-POS"
			    "READ-SERVO-TRIM")
		     :test #'equal)
             (includes-var var (cadr expr)))
            (t (progn (print-error "bad r-value" expr) nil)))))
   (t (eq expr var))))

; not implemented yet
(defun eval-defun (expr env)
  (let ((name (cadr expr))
        (params (caddr expr))
        (body (cdddr expr)))
    (print-error "not implemented yet" expr)
    nil))

(defun eval-let (expr env)
  (let ((bindings (cadr expr))
        (body (cddr expr))
        (code (list nil))
        (let-env (send env :make-child)))
    (mapc #'(lambda (b)
              (send let-env :add-var
                    (if (listp b) (car b) b))) bindings)
    (mapc #'(lambda (b)
              (if (listp b)
                  (let ((var (car b))
                        (val (cadr b)))
                    (nconc code (eval-binding var val env let-env)))))
          bindings)
    (mapc #'(lambda (e) (nconc code (eval-expr e let-env))) body)
    (let ((loc (give-loc-to-vars let-env (send let-env :max-child-vars))))
      (send env :set-max-child-vars loc)
      (if (> loc *num-of-variables*)
          (print-error "too many user variables" expr)))
    (cdr code)))

(defun eval-binding (var expr env let-env)
  (if (null (send env :top))
      (progn (send env :clear-stack (send let-env :get-var var))
             (let ((code (eval-expr expr env)))
               (send env :clear-stack nil)
               code))
    (progn (print-error "badly nested let? " expr) nil)))

; give a memory location to variables
(defun give-loc-to-vars (env loc)
  (let ((tmpvars (send (send env :stack) :array))
        (vars  (send env :vars)))
    (dotimes (i (send tmpvars :size))
      (let ((v (send tmpvars :get i)))
        (unless (null v)
          (progn (setf (cadr (cadr v)) loc)
                 (setf loc (+ loc *int-value-size*))))))
    (mapc #'(lambda (b)
              (setf (cadr (cadr b)) loc)
              (setf loc (+ loc *int-value-size*)))
          vars)
    loc))

(defun eval-if (expr env)
  (eval-if-else (cadr expr) (caddr expr)
                (if (= (length expr) 3) nil (cadddr expr))
                env))

(defun eval-if-else (condition then-part else-part env)
  (let* ((else-label (generate-label))
         (end-label (generate-label))
         (code (jump-if condition else-label t env)))
    (if (null else-part)
        (nconc code
               (eval-expr then-part env)
               `(,else-label))
      (nconc code
             (eval-expr then-part env)
             `((:jump nil ,end-label))
             `(,else-label)
             (eval-expr else-part env)
             `(,end-label)))
    code))

(defun eval-while (expr env)
  (let ((condition (cadr expr))
        (body     (cddr expr))
        (loop-begin (generate-label))
        (loop-end (generate-label)))
    (let ((code `((:jump nil ,loop-end)
                  ,loop-begin)))
      (mapc #'(lambda (e) (nconc code (eval-expr e env))) body)
      (nconc code
             `(,loop-end)
             (jump-if condition loop-begin nil env))
      code)))

(defun generate-label ()
  (setq *label-number* (1+ *label-number*))
  (make-symbol (format nil "l~a" *label-number*)))

; The condition is not a normal expression.
; (and (> 0 i) (< i n)) is not supported.
;
(defun jump-if (expr jump-label is-unless env)
  (let ((code (list nil)))
    (let ((condition
           (if (is-comparison expr)
               (let ((flags (if-condition (car expr) is-unless)))
                 (if (symbolp flags)
                     (progn
                       (nconc code (eval-binary
                                    ; exchange the operands
                                    `(- ,(caddr expr) ,(cadr expr)) env))
                       (if-condition flags is-unless))
                   (progn
                     (nconc code (eval-binary
                                  `(- ,(cadr expr) ,(caddr expr)) env))
                     flags)))
             (progn
               (nconc code (eval-binary `((- ,expr 0)) env))
               (if-condition '!= is-unless)))))
      (nconc code `((:jump ,condition ,jump-label)))
      (cdr code))))

(defun is-comparison (expr)
  (if (listp expr)
      (member (symbol-name (car expr))
              '("<" ">" "<=" ">=" "==" "=" "!=") :test #'equal)
    nil))

(defun if-condition (op-name is-unless)
  (let ((name (symbol-name op-name)))
    (cond ((equal name "<")
           (if is-unless '(:c :c<>) '(:c :c=)))
          ((equal name "<=")
           (if is-unless '>= '(:c :z :c= :z=))) ; Carry or Zero
          ((equal name ">")
           (if is-unless '(:c :z :c= :z=) '<)) ; !C and !Z
          ((equal name ">=")
           (if is-unless '(:c :c=) '(:c :c<>)))
          ((or (equal name "=") (equal name "=="))
           (if is-unless '(:z :z<>) '(:z :z=)))
          ((equal name "!=")
           (if is-unless '(:z :z=) '(:z :z<>)))
          (t (progn (print-error "bad operator" op-name)
                    nil)))))

(defun eval-progn (expr env)
  (let ((code (list nil)))
    (dolist (e (cdr expr))
      (nconc code (eval-expr e env)))
    (cdr code)))

(defun eval-return (expr env)
  '((:return)))

(defun eval-setq (expr env)
  (let* ((var-name (cadr expr))
         (val (caddr expr))
         (var (send env :get-var var-name)))
    (if (null var)
        (progn (print-error "undefined variable for setq" expr) nil)
      (if (null (send env :top))
          (if (includes-self-in-right (car var) val)
              (progn (send env :push)
                     (let* ((code (eval-expr val env))
                            (result (send env :pop)))
                       (nconc code (move-code result var))))
            (progn (send env :clear-stack var)
                   (let ((code (eval-expr val env)))
                     (send env :clear-stack nil)
                     code)))
        (let* ((code (eval-expr val env))
               (result (send env :top)))
          (nconc code (move-code result var)))))))

; (write-servo-ref index val)
(defun eval-call-to-write-servo-ref (expr env)
  (let ((si (cadr expr))
	(val (caddr expr))
	(dest (send env :top))
	(code (list nil)))
    (if (= (length expr) 3)
	(progn
	  (send env :push)
	  (let* ((opd (eval-expr val env))
		 (dest (send env :top)))
	    (send env :pop)
	    (nconc code opd)
	    (nconc code
		   (move-code dest
			      `(:ram (:servo ,si 6))))
	    (cdr code)))
      (progn (print-error "bad arguments" expr) nil))))

(defun move-code (src dest)
  `((:move ,(ram-addr-or-lit src :size) ,(ram-addr dest))))

(defun ram-addr-or-lit (binding    ; (name (:user <loc>))
                        &optional (with-size nil))
  (if (listp binding)  ; binding is not a number but a list
      (ram-addr binding with-size)
    (let ((high (logand (ash binding -8) #xff))
          (low  (logand binding #xff)))
      `(:lit ,low ,high)))) ; little endian

(defun ram-addr (binding &optional (with-size nil))   ; (name (:user <loc>))
  `(:ram ,(cadr binding)
         ,@(if with-size (list *int-value-size*) nil)))

(defun eval-binary (expr env)
  (if (> (length expr) 3)
      (print-error "too many operands" expr))
  (let ((dest (send env :top))
        (operator (operator-name (car expr)))
        (left (cadr expr))
        (right (caddr expr))
        (code (list nil)))
    (let* ((left-operand (expr-to-operand left env dest code))
           (right-operand
            (if (numberp right) right
              (expr-to-operand right env nil code))))
      (nconc code
             `((,operator ,(ram-addr-or-lit right-operand :size)
                          ,(ram-addr left-operand)
                          ,@(if (null dest) (list t) nil))))
      (cdr code))))

(defun expr-to-operand (expr env dest code)
  (if (null dest)
      (if (is-variable expr)
          (var-to-operand expr env)
        (progn
          (send env :push)
          (nconc code (eval-expr expr env))
          (send env :pop)))
    (progn (nconc code (eval-expr expr env))
           dest)))

(defun operator-name (op)
  (let ((name (symbol-name op)))
    (cond ((equal name "+") :add)
          ((equal name "-") :sub)
          ((equal name "*") :mul)
          ((equal name "/") :div)
          ((equal name "MOD") :mod)
          ((equal name "AND") :and)
          ((equal name "OR") :or)
          ((equal name "XOR") :xor)
          (t (progn (print-error "unknown operator" op) op)))))

(defun eval-shift (expr env)
  (let ((dest (send env :top))
        (operator (car expr))
        (value (cadr expr))
        (shift-count (caddr expr))
        (code (list nil)))
    (unless (numberp shift-count)
      (print-error "non-number shift count" expr))
    (let ((operand (expr-to-operand value env dest code))
          (count (if (equal (symbol-name operator) ">>") shift-count
                   (mod (- 256 shift-count) 256))))
      (nconc code
             `((:shift ,count ,*int-value-size*
                       ,(ram-addr operand)
                       ,@(if (null dest) (list t) nil))))
      (cdr code))))

(defun eval-not (expr env)
  (let ((dest (send env :top))
        (value (cadr expr))
        (code (list nil)))
    (let ((operand (expr-to-operand value env dest code)))
      (nconc code
             `((:not ,*int-value-size* ,(ram-addr operand)
                     ,@(if (null dest) (list t) nil))))
      (cdr code))))

(defun eval-number (expr env)
  (let ((dest (send env :top)))
    (if (null dest) nil
      `((:move ,(ram-addr-or-lit expr :size)
               ,(ram-addr dest))))))

(defun eval-var (expr env)
  (let ((dest (send env :top))
        (src (var-to-operand expr env)))
    (if (null src) nil
      (if (or (null dest) (eq src dest)) nil
        (move-code src dest)))))

; translate expr into an operand
(defun var-to-operand (expr env)
  (let ((var (send env :get-var expr)))
    (if (null var)
        (progn (print-error "undefined variable" (list expr env)) nil)
      var)))

; not implemented yet
(defun eval-call (expr env)
  (let ((name (car expr))
        (args (cdr expr)))
    (if (symbolp name)
        (let ((name (symbol-name name)))
          (cond ((equal name "SERVO")
                 (eval-call-to-servo expr env))
                ((equal name "CALL")
                 (eval-call-to-call expr env))
                ((equal name "SPEED")
                 (eval-call-to-speed expr env))
                ((equal name "STRETCH")
                 (eval-call-to-stretch expr env))
                ((equal name "READ-RAM")
                 (eval-call-to-read-ram expr env))
                ((equal name "READ-BUTTON")
                 (eval-call-to-read-button expr env))
                ((equal name "READ-SERVO")
                 (eval-call-to-read-servo expr env))
                ((equal name "READ-SERVO-REF")
                 (eval-call-to-read-servo-ref expr env))
                ((equal name "READ-SERVO-POS")
                 (eval-call-to-read-servo-pos expr env))
                ((equal name "READ-SERVO-TRIM")
                 (eval-call-to-read-servo-trim expr env))
                ((equal name "READ-AD")
                 (eval-call-to-read-ad expr env))
                (t
                 (progn (print-error "undefined function" expr) nil))))
      (print-error "the function name must be a symbol" expr))))

; (servo ids times servo-vector)
(defun eval-call-to-servo-org (expr env)
  (if (= (length expr) 4)
      (list (cons :servo (cdr expr)))
    (progn (print-error "bad arguments" expr) nil)))

(defun eval-call-to-servo (expr env) ;; expr=(servo ri/robot methods tm)
  (if
      (= (length expr) 4)
      (let ((elm (cadr expr)))
	(when (symbolp elm)
	  (setq elm (symbol-value (find-symbol (symbol-name elm) (find-package "USER")))))
	(cond
	 ((derivedp elm user::rcb4-interface)
	  (let* ((ri elm)
		 (methods (caddr expr)) ;; 
		 (tm (elt expr 3))
		 (svids (send ri :servo-sorted-ids))
		 (robo (send ri :robot))
		 sv)
	    (cond
	      ((listp (car methods))
	       (mapc #'(lambda (method) (send* robo method)) methods))
	      ((eq :angle-plist (car methods))
	       (send* robo methods)
	       (setq svids (send ri :angle-plist-sorted-sids (cdr methods))))
	      (t (send* robo methods)))
	    (dolist (j (send robo :joint-list))
	      (if (eq (send j :joint-type) :wheel) (send j :joint-angle 0)))
	    (setq sv (copy-seq (send ri :angle-vector-to-servo-vector
				     (send robo :angle-vector))))
	    (list (list :servo svids tm sv))))
	 ((derivedp elm user::robot-model)
	  (let* ((robo elm)
		 (ri (get robo :ri))
		 (methods (caddr expr))
		 (tm (elt expr 3))
		 (svids (send ri :servo-sorted-ids))
		 sv)
	    (if ri (setq robo (send ri :robot)))
	    (if
	     (listp (car methods))
	     (mapc #'(lambda (method) (send* robo method)) methods)
	     (send* robo methods))
	    (dolist (j (send robo :joint-list))
	      (if (eq (send j :joint-type) :wheel) (send j :joint-angle 0)))
	    (setq sv (copy-seq (send ri :angle-vector-to-servo-vector
				     (send robo :angle-vector))))
	    (list (list :servo svids tm sv))))
	 (t (list (cons :servo (cdr expr))))))
      (progn (print-error "bad arguments" expr) nil))
  )

; (servo ids times servo-vector)
(defun eval-call-to-call (expr env)
  ;;(print (list `expr= expr))
  (if (= (length expr) 2)
      (list (list :call nil (list :motiontable (cadr expr) 0)))
    (progn (print-error "bad arguments" expr) nil)))

; (speed ids times servo-vector)
(defun eval-call-to-speed (expr env)
  (if (= (length expr) 3)
      (list (cons :speed (cdr expr)))
    (progn (print-error "bad arguments" expr) nil)))

; (stretch ids times servo-vector)
(defun eval-call-to-stretch (expr env)
  (if (= (length expr) 3)
      (list (cons :stretch (cdr expr)))
    (progn (print-error "bad arguments" expr) nil)))

; (read-ad offset)
(defun eval-call-to-read-ad (expr env)
  (let ((dest (send env :top)))
    (if (null dest) nil
      (move-code `(tmp (:ad ,(cadr expr)))
		 dest))))
; (read-button)
(defun eval-call-to-read-button (expr env)
  (let ((dest (send env :top)))
    (if (null dest) nil
      (move-code `(tmp :button)
		 dest))))

; (read-ram address size)
(defun eval-call-to-read-ram (expr env)
  (let ((dest (send env :top)))
    (if (null dest) nil
      (move-code `(tmp (:ram ,(cadr expr) ,(caddr expr)))
		 dest))))

; (read-servo index offset)
(defun eval-call-to-read-servo (expr env)
  (let ((dest (send env :top)))
    (if (null dest) nil
      (move-code `(tmp (:servo ,(cadr expr) ,(caddr expr)))
		 dest))))

; (read-servo-ref index)
(defun eval-call-to-read-servo-ref (expr env)
  (let ((dest (send env :top)))
    (if (null dest) nil
      (move-code `(tmp (:servo ,(cadr expr) 6))
		 dest))))

; (read-servo-pos index)
(defun eval-call-to-read-servo-pos (expr env)
  (let ((dest (send env :top)))
    (if (null dest) nil
      (move-code `(tmp (:servo ,(cadr expr) 4))
		 dest))))

; (read-servo-trim index)
(defun eval-call-to-read-servo-trim (expr env)
  (let ((dest (send env :top)))
    (if (null dest) nil
      (move-code `(tmp (:servo ,(cadr expr) 2))
		 dest))))

(defun print-error (msg expr)
  (format t "Error: ~a. ~a" msg expr)
  (terpri)
  (setq *compile-error-count* (1+ *compile-error-count*)))

(defun print-code (code)
  (mapc #'(lambda (c) (print c)) code)
  nil)

(in-package "USER")
