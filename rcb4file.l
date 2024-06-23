;;;
;;;	File handlers for Project and motion produced by HeartToHeart4
;;;	
;;;	2017.7.13 KXR xml file reader for project and motion files
;;;	2017.8.2  :run-motion motion-file
;;;	2017.8.4  use tiny-xm.l to parse xml file
;;;	2017.8.8  create rcb4-motion-code class for project-file mcodes
;;;	2017.8.7  create kxrl2_vrml to test

(provide :rcb4file)

(require :tiny-xml)
(require :rcb4asm)
(require :rcb4machine)

(defvar *rcb4file-debug*)

(defun string-tag= (tag str)
  (and
   (stringp str)
   (or (string= tag str)
       (and (> (length str) (length tag))
	    (= #\  (char str (length tag)))))))

(defun tag-data-p (tag lst)
  (and
   (listp lst)
   (or (and (stringp (car lst))
	    (string-tag= tag (car lst)))
       (and (listp (car lst))
	    (stringp (caar lst))
	    (string-tag= tag (caar lst))))))

(defun get-tag-structure (tag lst)
  (cond
   ((atom lst) nil)
   ((equal tag (car lst)) (list lst))
   ((member tag (car lst) :test #'equal) (list lst))
   (t (let ((dat (mapcan #'(lambda (x) (get-tag-structure tag x))
			 (cdr lst))))
	(if dat (list (cons (car lst) dat)) nil)))))

(defun get-tag-contents (tag lst)
  (cond
   ((atom lst) nil)
   ((equal tag (car lst))
    (if (cdr lst) (list (cdr lst)) nil))
   ((member tag (car lst) :test #'equal)
    (if (cdr lst) (list (cdr lst)) nil))
   (t (mapcan #'(lambda (x) (get-tag-contents tag x))
	      (cdr lst)))))

(defun find-tag (tag lst)
  (cond
   ((atom lst) nil)
   ((equal tag (car lst)) lst)
   ;;((and (consp (car lst)) (equal tag (car (car lst)))) lst)
   ((find-tag tag (cdr lst)))
   ((find-tag tag (car lst)))))

(defun get-tag-data (tag lst)
  (cond
   ((atom lst) nil)
   ((equal tag (car lst)) 
    (if (cdr lst) (list lst) nil))
   ((member tag (car lst) :test #'equal)
    (if (cdr lst) (list lst) nil))
   (t (mapcan #'(lambda (x) (get-tag-data tag x))
	      (cdr lst)))))

(defun get-taglist-data (taglist lst)
  (let ((dat lst))
    (dolist (tag taglist)
      (setq dat (mapcan #'(lambda (x) (get-tag-data tag x)) dat)))
    dat))

(defun rcb4-project-xml-to-motion-codes
  (xml ri)
  (let ((codelst
	 (get-taglist-data
	  '("MotionDataCollection" "DictionaryEntry" "Value") xml)))
    (mapcan
     #'(lambda (x) 
	 (let* ((n (car (get-tag-data "Name" x)))
		(num (car (get-tag-data "Number" x)))
		(bd (car (get-tag-data "ButtonData" x)))
		(m (get-tag-data "MotionData" x))
		(b (mapcan
		    #'(lambda (c)
			(mapcar #'cadr
				(get-tag-data "anyType" c)))
		    m)))
	   (if b
	       (list (instance rcb4-motion-code :init
			       (list (cadr num) (cadr n))	;; motion-name
			       (mapcar				;; codes
				#'(lambda (x)
				    (hexstr-to-numlist
				     (remove-if #'(lambda (s) (equal s #\ )) x)))
				b)
			       (read-from-string (cadr num))	;; num
			       (read-from-string (cadr bd))	;; buttondat
			       ))
	     nil)))
     codelst))
  )

(defun rcb4-project-xml-to-servo-config
  (xml ri)
  (mapcan
   #'(lambda (x) 
       (let* ((n (car (get-tag-data "Name" x)))
	      (dev (car (get-tag-data "DeviceNumber" x)))
	      (mode (car (get-tag-data "Mode" x)))
	      (port (car (get-tag-data "Port" x)))
	      (id (car (get-tag-data "ID" x)))
	      (trim (car (get-tag-data "Trim" x)))
	      (pos (car (get-tag-data "Position" x)))
	      (location (car (get-tag-data "Location" x)))
	      )
	 (list (instance rcb4-servo-config :init
			 (cadr n)
			 (read-from-string (cadr dev))
			 (cadr mode)
			 (cadr port)
			 (read-from-string (cadr id))
			 (read-from-string (cadr trim))
			 (read-from-string (cadr pos))
			 (list (read-from-string (cadr (cadr location)))
			       (read-from-string (cadr (caddr location))))))))
   (get-taglist-data
    '("ServoConfigParams" "DictionaryEntry" "Value") xml))
  )

(defclass rcb4-jump-vectors :super vector)
(defclass rcb4-motion-table :super vector)

(defclass rcb4-file :super object
  :slots (fname name ri xml))

(defmethod rcb4-file
  (:prin1 (&optional (strm t) &rest more-args)
	  (send-super :prin1 strm
		      (format nil "~S~A"
			      name (if more-args more-args ""))))
  (:init (roboi f)
	 (setq ri roboi)
	 (cond
	  ((probe-file f)
	   (setq fname (namestring (truename (pathname f))))
	   (setq name (pathname-name (pathname fname)))
	   (send self :load))
	  (t (warn ";; no xml file ~A in :init rcb4-file~%" f)))
	 self)
  (:fname nil fname)
  (:name nil name)
  (:xml nil xml)
  (:load nil (setq xml (tiny-xml::parse fname)))
  (:find-tag (tag) (find-tag tag xml))
  (:dump-xml ()
	     (with-open-file
	      (f (format nil "~A/~A.l" (directory-namestring fname) name)
		 :direction :output)
	      (pprint xml f)))
  (:read-xml ()
	     (with-open-file
	      (f (format nil "~A/~A.l" (directory-namestring fname) name)
		 :direction :input) (read f)))
  (:load-xml () (setq xml (send self :read-xml)) t)
  (:ri (&rest args) (forward-message-to ri args))
  )

(defclass rcb4-project-file :super rcb4-file
  :slots (mcodes sconfs jump-vectors motion-table))

(defmethod rcb4-project-file
  (:init (roboi nam)
	 (send-super :init roboi nam)
	 (setq mcodes (rcb4-project-xml-to-motion-codes xml ri))
	 (setq sconfs (rcb4-project-xml-to-servo-config xml ri))
	 (setq motion-table (instantiate rcb4-motion-table 120))
	 (send motion-table :setup-motion-table mcodes)
	 (setq jump-vectors (instantiate rcb4-jump-vectors 32))
	 (send jump-vectors :setup-jump-vectors motion-table nil)
	 (send self :setup-ccodes)
	 self)
  (:setup-ccodes
   ()
   (dolist (mc mcodes)
     (send mc :deconversion ri)
     (send mc :conversion ri))
   )
  (:motion-table (&rest args) (forward-message-to motion-table args))
  (:jump-vectors (&rest args) (forward-message-to jump-vectors args))  
  (:trim-vector
   (&optional debug)
   (let ((sconfs (send self :sconfs))
	 (trim-vector (instantiate float-vector (ri . sv-length))))
     (dolist (s sconfs)
       (let ((id (send s :devicenumber)))
	 (setf (elt trim-vector id) (send s :trim))))
     trim-vector))
  (:find-mcodes
   (&optional str)
   (remove-if-not
    #'(lambda (x)
	(cond
	 ((numberp str) 
	  (equal str (send x :number)))
	 ((stringp str)
	  (member str (cdr (send x :name)) :test #'substringp))
	 (t t)))
    mcodes))
  (:mcodes (&rest args)
	   (cond
	    ((keywordp (car args))
	     (forward-message-to-all mcodes args))
	    ((numberp (car args))
	     (forward-message-to (car (send self :find-mcodes (car args)))
				 (cdr args)))
	    (t
	     (mapcar #'(lambda (x)
			 (forward-message-to x (cdr args)))
		     (send self :find-mcodes (car args))))))
  (:mcode (str &rest args)
	  (forward-message-to
	   (car (send self :find-mcodes str))
	   args))
  (:sconfs nil sconfs)
  )

(defclass rcb4-servo-config :super object
  :slots (name devicenumber mode port id trim position location))

(defmethod rcb4-servo-config
  (:prin1 (&optional (strm t) &rest more-args)
	  (send-super :prin1 strm
		      (format nil "~S ~S ~S ~S id:~S trim:~S pos:~S ~A ~A"
			      name devicenumber mode port id trim
			      position location
			      (if more-args more-args "")))
	  )
  (:init (nam devnum mod por i tri pos loc)
	 (setq name nam
	       devicenumber devnum
	       mode mod
	       port por
	       id i
	       trim tri
	       position pos
	       location loc)
	 self)
  (:trim nil trim)
  (:mode nil mode)
  (:position nil position)
  (:location nil location)
  (:port nil port)
  (:id nil id)
  (:name nil name)
  (:devicenumber nil devicenumber)
  )

(defclass rcb4-motion-file :super rcb4-file
  :slots (mcode))

(defmethod rcb4-motion-file
  (:init (robo f)
	 (send-super :init robo f)
	 (setq mcode
	       (instance
		rcb4-motion-code :init f
		(mapcan
		 #'(lambda (c)
		     (mapcar
		      #'(lambda (s)
			  (hexstr-to-numlist
			   (remove-if #'(lambda (x) (equal x #\ )) (cadr s))))
		      (get-tag-data "anyType" c)))
		 (get-tag-data "ProgramCode" xml))
		0 ;; motion-table number
		0))  ;; button-table number
	 self)
  (:mcode (&rest args) (forward-message-to mcode args))
  )

(defclass rcb4-motion-code :super object
  :slots (name number buttondata bcodes labels acodes ccodes ac bc 
	       jump-labels used-insts servo-vectors))

(defmethod rcb4-motion-code
  (:prin1 (&optional (strm t) &rest more-args)
	  (send-super :prin1 strm
		      (format nil "~A ~S~A"
			      number name (if more-args more-args "")))
	  )
  (:set-bcodes
   (codes)
   (setq bcodes nil)
   (dolist (c codes)
     (cond
      ((not (eq (car c) (length c)))
       (if (not (eq (car (last c)) #xff))
	   (format t ";; wrong length code (~S) in num=~A of motion=~A~%" c number name)
	 (push (butlast c) bcodes)))
      (t (push c bcodes))))
   (setq bcodes (reverse bcodes)))
  (:set-buttondata
   (buttondat)
   (setq buttondata 
	 (rcb4-decode-button-code (list (/ buttondat 256) (mod buttondat 256)))))
  (:init (motion-name codes num buttondat) ;; rcb4-motion-code
	 (setq name 
	       (if (stringp motion-name)
		   (pathname-name (pathname motion-name))
		 motion-name))
	 (setq number num)
	 (send self :set-buttondata buttondat)
	 ;;(setq *codes* codes)
	 (send self :set-bcodes codes)
	 (setq acodes (send self :disassemble))
	 (setq labels (send self :assemble-labels))
	 (setq used-insts (remove-duplicates (send self :insts)))
	 (setq servo-vectors   ;; used servo-id length
	       (mapcar
		#'(lambda (x) (let ((ids (cadr x)))
				(if (numberp ids) 1 (length ids))))
		(send self :get-insts '(:servo :stretch :speed))))

	 self)
  (:name (&optional n) (if n (setq name n)) name)
  (:labels (&optional ls) (if ls (setq labels ls)) labels)
  (:number () number)
  (:buttondata (&optional v) (if v (setq buttondata v)) buttondata)
  (:buttoncmd () (cddr buttondata))
  (:motion-number () number)
  (:acodes (&rest args)
	   (forward-message-to acodes args))
  (:ac (&rest args) (forward-message-to ac args))
  (:ccodes (&rest args)
	   (forward-message-to ccodes args))
  (:alists nil (remove-if #'symbolp acodes))
  (:bcodes (&rest args)
	   (cond
	    ((numberp (car args))
	     (forward-message-to (elt bcodes (car args)) (cdr args)))
	    ((keywordp (car args))
	     (mapcar #'(lambda (x) (forward-message-to x args))
		     bcodes))
	    (t bcodes)))
  (:bc (&rest args)
       (cond
	((numberp (car args))
	 (forward-message-to (elt bc (car args)) (cdr args)))
	((keywordp (car args))
	 (mapcar #'(lambda (x) (forward-message-to x args))
		 bc))
	(t bc)))
  (:used-insts nil used-insts)
  (:insts nil (mapcar #'car (send self :alists)))
  (:assemble (&optional (codes acodes)) (rcb4-assemble codes number))
  (:assemble-labels (&optional (codes acodes)) (rcb4-assemble-labels codes number))
  (:disassemble nil
		(let* ((acs (rcb4-disassemble bcodes number))
		       (bcs (rcb4-assemble acs number)))
		  (unless (every #'equal bcodes bcs)
		    (format t ";; disassemble->assemble error mc=~A~%" self))
		  (setq acodes acs)))
  (:deconversion
   (ri) ;;(format t ";; :deconversion called acodes=~A ~%" acodes)
   (setq jump-labels (rcb4-jump-labels acodes))
   (setq ccodes (rcb4-deconversion acodes ri jump-labels))
   )
  ;;
  (:conversion
   (ri &optional (check t))
   (setq ac (rcb4-conversion ccodes ri number))
   (setq bc (rcb4-assemble ac number))
   (when check
     (unless (equal ac acodes)
       ;;(if *rcb4file-debug* (format t "!!mi=~A name:~A~%ac!=acodes ac=~%~A~% acodes=~%~A~%" number
       ;;(send (send ri :project-file :mcodes number) :name) ac acodes))
       (if *rcb4file-debug* (format t "!!mi=~A name:~A ac!=acodes~%" number name))
       (dotimes (i (length ac))
	 (unless (equal (elt ac i) (elt acodes i))
	   (let ((ac1 (elt ac i)) (ac2 (elt acodes i)) sv v1 v2)
	     (cond
	      ((atom ac1)
	       (if *rcb4file-debug* (format t ";; mi=~A i(~A)-th ac1=~A and ac2=~A~%" number i ac1 ac2)))
	      ((eq (car ac1) :servo)
	       (dolist (j (cadr ac2))
		 (unless (equal (setq v1 (round (elt (elt ac1 3) j)))
				(setq v2 (round (elt (elt ac2 3) j))))
		   (if *rcb4file-debug*
		       (format t ";; mi=~A i(~A)-th inst:servo[~A]=~A(#x~X)=~A(deg) in ac and ~A(#x~X)=~A(deg) in acodes~%"
			       number i j v1 v1 (/ (- v1 7500) 30.0)  v2 v2 (/ (- v2 7500) 30.0))  )
		   ))
	       )
	      ((eq (car ac1) :stretch)
	       (dolist (j (cadr ac2))
		 (unless (equal (setq v1 (round (elt (elt ac1 2) j)))
				(setq v2 (round (elt (elt ac2 2) j))))
		   (if *rcb4file-debug*
		       (format t ";; mi=~A i(~A)-th inst:stretch[~A]=~A in ac and ~A in acodes~%"
			       number i j v1 v2)  )
		   ))
	       )
	      (t
	       (format t ";; mi:=~A (elt ac ~A)=~A~% (elt acodes ~A)=~A~%" number i (elt ac i) i (elt acodes i)))))))
       ))
   )
  ;;
  (:get-insts
   (insts)
   (remove-if-not #'(lambda (a) (memq (car a) insts)) (send self :alists)))
  (:servo-vectors nil servo-vectors)
  (:convert-to-i
   (to-i)
   (setq bcodes (rcb4-assemble (rcb4-disassemble bcodes) to-i))
   (setq number to-i))
  )

(defun digit-to-hexchar (num)
  (setq num (logand num #xf))
  (if (> num 9) (+ #\A (- num 10))
    (+ #\0 num)))

(defun num-to-hexstr (num &optional (size 2))
  (let ((str (instantiate string size)))
    (dotimes (i size)
      (setf (elt str (- size i 1)) (digit-to-hexchar (logand num #xf)))
      (setq num (ash num -4)))
    str))

(defun list-code-to-hex-str-code (lc)
  (let ((str "") c)
    (while (setq c (pop lc))
      (setq str (concatenate string str (num-to-hexstr c)))
      (if lc (setq str (concatenate string str " "))))
    str))

(defun xml-replace-motion-data (xmd bc &aux bcl num)
  (setq num (length (cdr xmd)))
  (unless (= num (length bc))
    (format t ";; before wrong bc length xml-size=~A, bc-size=~A~%" num (length bc)))
  (nconc (car (last bc)) (list #xff))
  (dolist (x (cdr xmd))
    (setq bcl (pop bc))
    (if bcl (rplacd x (list (list-code-to-hex-str-code bcl)))))
  (unless (= (length (cdr xmd)) num)
    (format t ";; after wrong bc length before-xml-size=~A after-xml-size=~A~%" num (length (cdr xmd))))
  )

(defun xml-replace-motion-table (xml mt)
  (let ((xmt-list
	 (get-taglist-data '("MotionDataCollection" "DictionaryEntry" "Value") xml))
	lc bc)
    (when (= 120 (length xmt-list))
      (dotimes (i 120)
	(when (and (elt xmt-list i) (elt mt i))
	  (setq lc (assoc "MotionData" (elt xmt-list i) :test #'string=))
	  (setq bc (copy-object ((elt mt i) . bc)))
	  (xml-replace-motion-data lc bc)
	  )
	))
    ))

(defun xml-replace-servo-confs (xml sconfs)
  (let ((xsf-list
	 (get-taglist-data
	  '("ServoConfigParams" "DictionaryEntry" "Value") xml))
	lc bc)
    (when (= (length sconfs) (length xsf-list))
      (dotimes (i (length xsf-list))
	(setq lc (assoc "Mode" (elt xsf-list i) :test #'string=))
	(rplacd lc (list ((elt sconfs i) . mode)))
	(setq lc (assoc "Name" (elt xsf-list i) :test #'string=))
	(rplacd lc (list ((elt sconfs i) . name)))
	))
    ))

(defun convert-angle-vector-code (code from-ri to-ri)
  (let* ((from-jl (send from-ri :joint-list))
	 (to-jl (send to-ri :joint-list))
	 (from-av (cadr code))
	 (to-av (instantiate float-vector (length to-jl)))
	 (to-free (instantiate vector (length to-jl)))
	 fi ti)
    (dotimes (fi (length from-jl))
      (setq ti (position (send (elt from-jl fi) :name) to-jl
			 :key #'(lambda (x) (send x :name))))
      (if ti (setf (elt to-av ti) (elt from-av fi)))
      )
    (dotimes (i (length to-jl))
      (setf (elt to-free i) (get (elt to-jl i) :active)))
    (list :angle-vector to-av (elt code 2) to-free))
  )

(defun convert-project-file (from-robot-name to-robot-name)
  (let* (mc mc2 from-ccodes to-ccodes
	    (from-ri (make-kxr-robot-interface from-robot-name))
	    (to-ri (make-kxr-robot-interface to-robot-name))
	    (from-pf (send from-ri :project-file))
	    (from-mt (send from-pf :motion-table))
	    (to-mt (instantiate rcb4-motion-table 120))
	    (to-pf (send to-ri :project-file)))
    (dotimes (i 120)
      (when (setq mc (elt from-mt i))
	(send mc :deconversion from-ri) ;; acodes -> ccodes
	(setq mc2 (copy-object mc))
	(setq from-ccodes (copy-object (mc . ccodes)))
	(setq to-ccodes nil)
	(dolist (c from-ccodes)
	  (if (and (consp c)
		   (eq (car c) :angle-vector))
	      (push (convert-angle-vector-code c from-ri to-ri) to-ccodes)
	    (push c to-ccodes)))
	(setq (mc2 . ccodes) (reverse to-ccodes))
	(send mc2 :conversion to-ri nil) ;; ccodes -> ac -> bc
	(format t ";; conversion i:~A mc2:~A~%" i mc2)
	(setq (mc2 . acodes) (copy-object (mc2 . ac)))
	(setq (mc2 . bcodes) (copy-object (mc2 . bc)))
	(setf (elt to-mt i) mc2)))
    (unless to-pf
      (setq to-pf (copy-object from-pf)))
    (xml-replace-motion-table (to-pf . xml) to-mt)
    (tiny-xml::dump (to-pf . xml) (format nil "~A.h4p" (send to-pf :name)))
    to-pf)
  )

(defun reform-project-file (rname)
  (convert-project-file rname rname))

;;(convert-project-file "kxrl2l5a3h2" "kxrl2l6anzai")
;;(reform-project-file "kxrl2l5a3")
;;(reform-project-file "kxrl2l6anzai")
;;(convert-project-file "kxrl2l5a3h2" "kxrl2l6anzai")


