;; tiny-xml.l
;
; 2017.8.4 written by S. Chiba
; 2019.7.24 added xml-write, handling NL data, xml comment
; 2020.2.15 added xml-print to replace xml-write
;
; usage: (tiny-xml::parse "foo.xml")
; usage: (tiny-xml::xml-print "foo.xml" xml)
;
(provide :tiny-xml)
(eval-when (eval load)
	   (unless (find-package "TINY-XML") (make-package "TINY-XML"))
	   (in-package "TINY-XML"))

#|
(unless (find-package "TINY-XML") (make-package "TINY-XML"))
(in-package "TINY-XML")
|#

(export '(parse dump xml-print))

(defclass xml-file :super object
  :slots (file text len pos))

(defmethod xml-file
  (:init (data)
         (setq file data)
         (setq text "")
         (setq len 0)
         (setq pos 0))
  (:pos () pos)
  (:eof ()
        (if (< pos len)
            nil
          (let ((next-line (read-line file nil)))
            (if (null next-line)
                t
              (progn
                (setq text (concatenate string text next-line (coerce '(10) string)))
                (setq len (length text))
                nil)))))
  (:clear ()
          (setq text (subseq text pos))
          (setq len (length text))
          (setq pos 0))
  (:subseq (start end)
           (subseq text start end))
  (:unget ()
          (if (> pos 0)
              (setq pos (- pos 1))))
  (:get ()
        (if (send self :eof)
            nil
	    (when
		(> (length text) pos)
	      (let ((c (char text pos)))
		(setq pos (+ pos 1))
		c))))
  )

(defun read-whole-file (fname)
  (let ((fd (open fname :direction :input))
        (text nil)
        (buf nil))
    (while (setq buf (read-line fd nil))
      (setq text (cons buf text)))
    (close fd)
    (apply #'concatenate string (reverse text))))

(defun null-or-eq (v a)
  (or (null v) (= v a)))

(defun read-xml-tag (file)
  (until (null-or-eq (send file :get) #\<)
         nil)
  (let ((s (send file :pos)))
    (until (null-or-eq (send file :get) #\>)
           nil)
    (let ((e (- (send file :pos) 1)))
      (if (>= s e)
          nil
        (send file :subseq s e)))))

(defun read-xml-text (file)
  (let ((s (send file :pos)))
    (until (null-or-eq (send file :get) #\<)
           nil)
    (send file :unget)
    (let ((e (send file :pos) 1))
      (if (>= s e)
          nil
        (let ((text (send file :subseq s e)))
          (if (empty-str-p text)
              nil
            text))))))

(defun empty-str-p (str)
  (let ((p 0)
        (len (length str))
        (result t))
    (while (< p len)
      (if (> (char str p) #\ )
          (setq result nil))
      (setq p (+ p 1)))
    result))

(defun clean-reverse (lst result)
  (if (null lst)
      result
    (if (null (car lst))
        (clean-reverse (cdr lst) result)
      (clean-reverse (cdr lst) (cons (car lst) result)))))

(defun xml-read (file)
  (let ((stag (read-xml-tag file)))
    (xml-read2 file stag)))

(defun xml-read2 (file stag)
  (cond
    ((= #\/ (char stag (- (length stag) 1)))
     ; if stag is < ... />
     (list (to-open-tag (subseq stag 0 (- (length stag) 1)))))
    ((substringp "!--" stag)
     (list (to-open-tag stag)))
    (t (xml-read3 file (list (to-open-tag stag))))))

(defun to-open-tag (stag)
  (let* ((tag (string-trim '(#\ ) stag))
         (p (position #\ tag)))
    (if (null p)
        tag
      (list (subseq tag 0 p) (subseq tag (+ p 1))))))

(defun xml-read3 (file lst)
  (let* ((text (read-xml-text file))
         (etag (read-xml-tag file)))
    (send file :clear)
    (if (or (null etag) (eq (char etag 0) #\/))
        (clean-reverse (cons text lst) nil)
      (let ((nested (xml-read2 file etag)))
	        (xml-read3 file (cons nested (cons text lst)))))))

(defun parse (fname)
  (with-open-file (in fname :direction :input)
    (xml-read (instance xml-file :init in))))

;;; 2020.2.15

(defun xml-indent (col strm) (dotimes (i col) (format strm " ")))

(defun xml-print0 (x &optional (strm t))
  (cond
    ((null x))
    ((atom x) (format strm "~A" x))
    ((atom (car x)) ;; atom tag
     (format strm "<~A>" (car x))
     (if (listp (cadr x)) (format strm "~%"))
     (dolist (a (cdr x)) (xml-print0 a strm))
     (format strm "</~A>~%" (car x)))
    (t  ;; list tag
     (format strm "<") (dolist (a (butlast (car x))) (format strm "~A " a))
     (cond ((listp (cadr x)) (format strm "~A>~%" (car (last (car x)))))
	   (t (format strm "~A>" (car (last (car x))))))
     (dolist (a (cdr x)) (xml-print0 a strm))
     (format strm "</~A>~%" (car (car x)))
     )))

(defun xml-print1 (x &optional (strm t) (col 0))
  (cond
    ((null x))
    ((atom x) (format strm "~A" x))
    ((atom (car x)) ;; atom tag
     (xml-indent col strm)
     (cond
       ((null (cdr x))
	(format strm "<~A />~%" (car x)))
       ((null (cddr x))
	(cond
	  ((atom (cadr x))
	   (format strm "<~A>" (car x))
	   (xml-print1 (cadr x) strm)
	   (format strm "</~A>~%" (car x)))
	  (t
	   (format strm "<~A>~%" (car x))
	   (xml-print1 (cadr x) strm (+ col 2))
	   (xml-indent col strm) (format strm "</~A>~%" (car x)))))
       (t
	(format strm "<~A>~%" (car x))
	(dolist (a (cdr x)) (xml-print1 a strm (+ col 2)))
	(when (listp (cadr x)) (xml-indent col strm))
	(format strm "</~A>~%" (car x)))))
    (t  ;; list tag
     (xml-indent col strm)
     (format strm "<") (dolist (a (butlast (car x))) (format strm "~A " a))
     (format strm "~A>" (car (last (car x))))
     (when (listp (cadr x)) (format strm "~%"))
     (dolist (a (cdr x)) (xml-print1 a strm (if (cddr x) (+ col 2) col)))
     (when (listp (cadr x)) (xml-indent col strm))
     (when
	 (and (not (string-equal (caar x) "?xml"))
	      (not (string-equal (caar x) "!doctype"))
	      (not (string-equal (caar x) "!--")))
       (format strm "</~A>~%" (car (car x)))))
    ))

(defun xml-print (x &optional (strm t) (col 0))
  (cond
    ((null x))
    ((atom x) (format strm "~A" x))
    ((atom (car x)) ;; atom tag
     (xml-indent col strm)
     (cond
       ((null (cdr x))
	(format strm "<~A />~%" (car x)))
       (t
	(format strm "<~A>" (car x))
	(cond
	  ((atom (cadr x))
	   (dolist (a (cdr x)) (xml-print a strm)))
	  (t
	   (format strm "~%")
	   (dolist (a (cdr x)) (xml-print a strm (+ col 2)))
	   (xml-indent col strm)
	   ))
	(format strm "</~A>" (car x))
	(format strm "~%")
	)))
    (t  ;; (car x)= list tag
     (xml-indent col strm)
     (cond
      ((null (cdr x))
       (cond
	((string= (caar x) "!--")
	 (format strm "<") (dolist (a (butlast (car x))) (format strm "~A " a))
	 (format strm "~A>~%" (car (last (car x)))))
	(t 
	 (format strm "<") (dolist (a (butlast (car x))) (format strm "~A " a))
	 (format strm "~A/>~%" (car (last (car x)))))))
      (t
       (format strm "<") (dolist (a (butlast (car x))) (format strm "~A " a))
       (format strm "~A>" (car (last (car x))))
       (when (listp (cadr x)) (format strm "~%"))
       (dolist (a (cdr x)) (xml-print a strm (if (cddr x) (+ col 2) col)))
       (when (listp (cadr x)) (xml-indent col strm))
       (when
	   (and (not (string-equal (caar x) "?xml"))
		(not (string-equal (caar x) "!doctype")))
	 (format strm "</~A>" (caar x))
	 (unless (equal "span" (caar x)) (format strm "~%"))
	 )))
     ))
  )

(defun dump (xml fname &optional (func #'xml-print))
  (with-open-file (f fname :direction :output)
    (funcall func xml f)))

(defun file-check (fname1 fname2)
  (let ((s1 t) (s2 t) (i 0) (ret t))
    (with-open-file (f1 fname1)
      (with-open-file (f2 fname2)
	(while (and ret s1 s2)
	  (setq s1 (read-line f1 nil))
	  (setq s2 (read-line f2 nil))
	  (unless (string-equal s1 s2)
	    ;;(format t "i=~A~% ~15A=~S~% ~15A=~S~%" i fname1 s1 fname2 s2)
	    (setq ret nil))
	  (setq i (1+ i)))))
    (if (or s1 s2) (format t " s1=~A, s2=~A " s1 s2))
    ret))

(in-package "USER")

#|
(defun test (&optional (fname "test.h4p") (func 'tiny-xml::xml-print) &aux dname)
  (setq dname (format nil "~A-~A.~A" (pathname-name (pathname fname))
		      (string-downcase (symbol-name func))
		      (pathname-type (pathname fname))))
  (setq xml (tiny-xml::parse fname))
  (tiny-xml::dump xml dname (symbol-function func))
  (setq xml2 (tiny-xml::parse dname))
  (format t ";;func= ~18A " func)
  (format t "(equal xml xml2)= ~A " (equal xml xml2))
  (format t "(file-check ~S ~S)= ~A ~%" (pathname-name fname) dname (tiny-xml::file-check fname dname))
  )

(test "test.h4p")
(test "test.h4p" 'tiny-xml::xml-print0)
(test "test.h4p" 'tiny-xml::xml-print1)
(test "projects/Hello_kxrl2w2l5a4h2/Hello_KXR-l2w2l5a4h2.h4p")
(test "projects/Hello_kxrl2w2l5a4h2/Hello_KXR-l2w2l5a4h2.h4p" 'tiny-xml::xml-print0)
(test "projects/Hello_kxrl2w2l5a4h2/Hello_KXR-l2w2l5a4h2.h4p" 'tiny-xml::xml-print1)
(test "dom3.xml")
(test "dom3.xml" 'tiny-xml::xml-print0)
(test "dom3.xml"'tiny-xml::xml-print1)
(test "projects/Hello_kxrl2w2l5a4h2/XL2GH_59_turnRightxml.xml")
(test "projects/Hello_kxrl2w2l5a4h2/XL2GH_59_turnRightxml.xml" 'tiny-xml::xml-print0)
(test "projects/Hello_kxrl2w2l5a4h2/XL2GH_59_turnRightxml.xml" 'tiny-xml::xml-print1)
|#
