;;
(load "lispcontest1979.l")
(compile-file "lispcontest1979.l")
(format t ";; interpreter~%")
(lisp-contest)
(load "lispcontest1979")
(format t ";; compiled~%")
(lisp-contest)
 

