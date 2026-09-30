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

;;;
;;;    2026.8  rcb4lispでコンパイルされたプログラム -> HeartToHeart互換の
;;;    CanvasData XML (ActivityData/LineDataブロックのフローチャート)。
;;;    tools_gen_dispatch_xml.py から移植（生成されたXMLをWindows上の
;;;    実際のHeartToHeartで開き、動作検証済み）。
;;;    メモリ上の (rcb4lisp::compile prog) / (rcb4-assemble ... motion-i)
;;;    の出力結果を直接処理するため、（保存されたコンソールログを解析していた
;;;    Pythonの元版とは異なり）テキストログのパースは不要です。
;;;
;;;    注記（移植時に修正したバグについて）:
;;;    Pythonの元版では「同一モーション内のローカルジャンプかどうか」を判定する
;;;    アドレス範囲が、スロット0のウィンドウ（0x0B80..0x0B80+2048）にハードコード
;;;    されていました。これは motion-i=0 であったファイルでしか正しく機能しません。
;;;    他のスロットでは、ローカルジャンプのアドレスが FF FF FF に消去されなくなっていました。
;;;    本バージョンでは、rcb4-address を介して motion-i 自体からアドレス範囲を計算します。
;;;    また、ローカルの :jump だけでなく :call にも同様の処理を適用しており、
;;;    実際のHeartToHeartからエクスポートされたROMデータにおける
;;;    ローカルジャンプ/コール表現に一致させています。

(defun rcb4-canvas-label-p (item) (symbolp item))
(defun rcb4-canvas-jump-p (item) (and (consp item) (eq (car item) :jump)))
(defun rcb4-canvas-call-p (item) (and (consp item) (eq (car item) :call)))
(defun rcb4-canvas-jump-or-call-p (item) (or (rcb4-canvas-jump-p item) (rcb4-canvas-call-p item)))
(defun rcb4-canvas-return-p (item) (and (consp item) (eq (car item) :return)))

(defun rcb4-canvas-join (lst sep)
  (let ((s ""))
    (dolist (x lst)
      (setq s (if (string= s "") (format nil "~A" x) (format nil "~A~A~A" s sep x))))
    s))

(defun rcb4-canvas-random-hex (n)
  (let ((s ""))
    (dotimes (i n) (setq s (format nil "~A~X" s (random 16))))
    s))

(defun rcb4-canvas-gen-guid ()
  (format nil "~A-~A-~A-~A-~A"
          (rcb4-canvas-random-hex 8) (rcb4-canvas-random-hex 4)
          (rcb4-canvas-random-hex 4) (rcb4-canvas-random-hex 4)
          (rcb4-canvas-random-hex 12)))

;; items-vec: compiled program (labels + instruction forms) coerced to a vector.
;; returns (list blocks label-to-block); blocks is a list of (labels . idxs)
;; in program order, idxs are indices into items-vec for the real instructions
;; in that block. label-to-block is an alist (label . block-index).
(defun rcb4-canvas-build-blocks (items-vec)
  (let* ((n (length items-vec))
         (is-label (make-array n)) (is-jump (make-array n))
         (boundary (make-array n :initial-element nil))
         blocks cur-labels cur-idxs label-to-block)
    (dotimes (i n)
      (setf (aref is-label i) (rcb4-canvas-label-p (aref items-vec i)))
      (setf (aref is-jump i) (rcb4-canvas-jump-p (aref items-vec i))))
    (setf (aref boundary 0) t)
    (dotimes (i n)
      (when (and (aref is-jump i) (< (1+ i) n)) (setf (aref boundary (1+ i)) t))
      (when (aref is-label i) (setf (aref boundary i) t)))
    (dotimes (i n)
      (when (and (aref boundary i) cur-idxs)
        (push (cons (reverse cur-labels) (reverse cur-idxs)) blocks)
        (setq cur-labels nil cur-idxs nil))
      (if (aref is-label i)
          (push (aref items-vec i) cur-labels)
        (push i cur-idxs)))
    (when (or cur-idxs cur-labels)
      (push (cons (reverse cur-labels) (reverse cur-idxs)) blocks))
    (setq blocks (reverse blocks))
    (let ((bi 0))
      (dolist (b blocks)
        (dolist (lab (car b)) (push (cons lab bi) label-to-block))
        (incf bi)))
    (list blocks label-to-block)))

;; returns a list of (edge-type . target-block-index), edge-type one of
;; :true :false :normal
(defun rcb4-canvas-block-edges (bi blocks items-vec label-to-block)
  (let* ((idxs (cdr (nth bi blocks))))
    (if (null idxs)
        (if (< (1+ bi) (length blocks)) (list (cons :normal (1+ bi))) nil)
      (let* ((last-idx (car (last idxs)))
             (last-instr (aref items-vec last-idx)))
        (cond
         ((rcb4-canvas-jump-p last-instr)
          (let* ((cnd (cadr last-instr))
                 (target (caddr last-instr))
                 (tb (cdr (assoc target label-to-block))))
            (if (null cnd)
                (list (cons :normal tb))
              (let ((edges (list (cons :true tb))))
                (when (< (1+ bi) (length blocks))
                  (setq edges (append edges (list (cons :false (1+ bi))))))
                edges))))
         ((rcb4-canvas-return-p last-instr) nil)
         ((< (1+ bi) (length blocks)) (list (cons :normal (1+ bi))))
         (t nil))))))

(defun rcb4-canvas-describe-instr (instr)
  (if (not (consp instr))
      (format nil "~A" instr)
    (case (car instr)
      (:move "サーボ値読み取り")
      (:sub "比較")
      (:jump (if (null (cadr instr)) "ジャンプ(無条件)" "ジャンプ(条件分岐)"))
      (:call (let ((tgt (caddr instr)))
               (if (and (consp tgt) (eq (car tgt) :motiontable))
                   (format nil "モーション~A番を呼ぶ" (cadr tgt))
                 "コール")))
      (:return "終了")
      (:servo "サーボ駆動")
      (t (format nil "~A" (car instr))))))

(defun rcb4-canvas-hint-for-block (idxs items-vec)
  (rcb4-canvas-join
   (mapcar #'(lambda (i) (rcb4-canvas-describe-instr (aref items-vec i))) idxs)
   " / "))

(defun rcb4-canvas-basename-for-block (idxs items-vec)
  (let ((last-instr (aref items-vec (car (last idxs)))))
    (cond
     ((and (rcb4-canvas-jump-p last-instr) (cadr last-instr)) "CmpAD")
     ((find-if #'(lambda (i) (rcb4-canvas-call-p (aref items-vec i))) idxs) "MotionJump")
     (t "ServoParam"))))

;; a vector of 1-character STRINGS, not a string of characters --
;; (elt "0123456789ABCDEF" i) returns a raw char-code integer in this
;; EusLisp (no distinct character type), so indexing into a plain string
;; and printing with ~A prints the decimal char-code instead of the digit.
(defvar *rcb4-canvas-hexdigits* #("0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "A" "B" "C" "D" "E" "F"))

(defun rcb4-canvas-byte-to-hex2 (b)
  ;; manual 2-digit zero-padded uppercase hex -- ~2,'0X wasn't substituting
  ;; the value correctly in this EusLisp's format implementation.
  (let ((v (logand b 255)))
    (format nil "~A~A" (aref *rcb4-canvas-hexdigits* (ash v -4)) (aref *rcb4-canvas-hexdigits* (logand v 15)))))

(defun rcb4-canvas-bytes-to-hexstr (bytelist)
  (rcb4-canvas-join (mapcar #'rcb4-canvas-byte-to-hex2 (coerce bytelist cons)) " "))

;; blanks the address bytes of a LOCAL (same-motion-slot) :jump/:call to
;; FF FF FF and recomputes the checksum, matching real HeartToHeart export
;; behavior; leaves cross-slot (:motiontable N) targets fully resolved.
(defun rcb4-canvas-make-program-code (idxs items-vec byte-lines-vec motion-i)
  (let ((base (rcb4-address (list :motiontable motion-i 0)))
        (limit (rcb4-address (list :motiontable (1+ motion-i) 0)))
        chunks)
    (dolist (i idxs)
      (let* ((b (copy-seq (aref byte-lines-vec i)))
             (instr (aref items-vec i)))
        (when (rcb4-canvas-jump-or-call-p instr)
          (let ((addr (+ (elt b 2) (ash (elt b 3) 8) (ash (elt b 4) 16))))
            (when (and (>= addr base) (< addr limit))
              (setf (elt b 2) 255) (setf (elt b 3) 255) (setf (elt b 4) 255)
              (let ((sum 0))
                (dotimes (k 6) (incf sum (elt b k)))
                (setf (elt b 6) (logand sum 255))))))
        (push (rcb4-canvas-bytes-to-hexstr b) chunks)))
    (reverse chunks)))

;; assembled-code: output of (rcb4-assemble compiled-prog motion-i) --
;; one byte-chunk per NON-label item in compiled-prog, in order (labels
;; contribute nothing to rcb4-assemble's output). Re-aligns it against
;; items-vec (which still has the labels interspersed) so byte-lines-vec[i]
;; corresponds 1:1 with items-vec[i] (nil at label positions).
(defun rcb4-canvas-align-byte-lines (items-vec assembled-code)
  (let ((n (length items-vec)) (result (make-array (length items-vec))) (rest assembled-code))
    (dotimes (i n)
      (if (rcb4-canvas-label-p (aref items-vec i))
          (setf (aref result i) nil)
        (progn (setf (aref result i) (car rest)) (setq rest (cdr rest)))))
    result))

(defvar *rcb4-canvas-pos*)

(defun rcb4-canvas-layout-1 (bi col row edges-of)
  (let ((existing (assoc bi *rcb4-canvas-pos*)))
    (if existing
        row
      (progn
        (push (cons bi (cons col row)) *rcb4-canvas-pos*)
        (let ((cur-max row))
          (dolist (edge (funcall edges-of bi))
            (let ((etype (car edge)) (target (cdr edge)))
              (setq cur-max
                    (max cur-max
                         (cond
                          ((eq etype :true) (rcb4-canvas-layout-1 target col (1+ row) edges-of))
                          ((eq etype :false) (rcb4-canvas-layout-1 target (1+ col) row edges-of))
                          (t (rcb4-canvas-layout-1 target (1+ col) row edges-of)))))))
          cur-max)))))

;; returns an alist (block-index . (col . row))
(defun rcb4-canvas-layout-blocks (nblocks edges-of)
  (setq *rcb4-canvas-pos* nil)
  (rcb4-canvas-layout-1 0 0 0 edges-of)
  (dotimes (bi nblocks)
    (unless (assoc bi *rcb4-canvas-pos*)
      (let ((maxrow 0))
        (dolist (p *rcb4-canvas-pos*) (setq maxrow (max maxrow (cddr p))))
        (push (cons bi (cons 0 (1+ maxrow))) *rcb4-canvas-pos*))))
  (reverse *rcb4-canvas-pos*))

(defvar *rcb4-canvas-col-w* 96)
(defvar *rcb4-canvas-row-h* 72)
(defvar *rcb4-canvas-bw* 64)
(defvar *rcb4-canvas-bh* 48)

(defun rcb4-canvas-block-rect (bi pos-alist)
  (let* ((p (cdr (assoc bi pos-alist))) (col (car p)) (row (cdr p)))
    (list (+ (* col *rcb4-canvas-col-w*) 8) (+ (* row *rcb4-canvas-row-h*) 16)
          *rcb4-canvas-bw* *rcb4-canvas-bh*)))

;; compiled-prog: (rcb4lisp::compile prog) result (reset rcb4lisp::*label-number*
;; to 0 before compiling, as elsewhere in this codebase, so labels don't
;; collide across calls). motion-i: target ROM motion table slot number
;; (used both to assemble and to decide which jump/call targets are "local").
;; Returns the full CanvasData XML as a string.
(defun rcb4lisp-program-to-canvas-xml (compiled-prog motion-i &key (description "自動生成"))
  (let* ((items-vec (coerce compiled-prog vector))
         (assembled (rcb4-assemble compiled-prog motion-i))
         (byte-lines-vec (rcb4-canvas-align-byte-lines items-vec assembled))
         (bl (rcb4-canvas-build-blocks items-vec))
         (blocks (car bl)) (label-to-block (cadr bl))
         (nblocks (length blocks))
         (edges-of #'(lambda (bi) (rcb4-canvas-block-edges bi blocks items-vec label-to-block)))
         (pos-alist (rcb4-canvas-layout-blocks nblocks edges-of))
         (block-guid (make-array nblocks))
         (activity-outgoing (make-array nblocks :initial-element nil))
         (activity-incoming (make-array nblocks :initial-element nil))
         lines-xml activities-xml)
    (dotimes (bi nblocks) (setf (aref block-guid bi) (rcb4-canvas-gen-guid)))
    (dotimes (bi nblocks)
      (dolist (edge (rcb4-canvas-block-edges bi blocks items-vec label-to-block))
        (let* ((etype (car edge)) (target (cdr edge))
               (r1 (rcb4-canvas-block-rect bi pos-alist)) (r2 (rcb4-canvas-block-rect target pos-alist))
               (x1 (nth 0 r1)) (y1 (nth 1 r1)) (w1 (nth 2 r1)) (h1 (nth 3 r1))
               (x2 (nth 0 r2)) (y2 (nth 1 r2)) (w2 (nth 2 r2)) (h2 (nth 3 r2))
               (line-guid (rcb4-canvas-gen-guid))
               p1x p1y p2x p2y mode)
          (cond
           ((eq etype :true)
            (setq p1x (+ x1 (ash w1 -1)) p1y (+ y1 h1) p2x (+ x2 (ash w2 -1)) p2y y2 mode "True"))
           ((eq etype :false)
            (setq p1x (+ x1 w1) p1y (+ y1 (ash h1 -1)) p2x x2 p2y (+ y2 (ash h2 -1)) mode "False"))
           (t
            (setq p1x (+ x1 w1) p1y (+ y1 (ash h1 -1)) p2x x2 p2y (+ y2 (ash h2 -1)) mode "Normal")))
          (push (format nil "    <anyType xsi:type=\"LineData\">~%      <GUID>~A</GUID>~%      <Path>~%        <Point><X>~A</X><Y>~A</Y></Point>~%        <Point><X>~A</X><Y>~A</Y></Point>~%      </Path>~%      <ConnectMode>~A</ConnectMode>~%    </anyType>"
                          line-guid p1x p1y p2x p2y mode)
                lines-xml)
          (push line-guid (aref activity-outgoing bi))
          (push line-guid (aref activity-incoming target)))))
    (setq lines-xml (reverse lines-xml))
    (dotimes (bi nblocks)
      (let* ((idxs (cdr (nth bi blocks)))
             (r (rcb4-canvas-block-rect bi pos-alist))
             (x (nth 0 r)) (y (nth 1 r)) (w (nth 2 r)) (h (nth 3 r))
             (out-guids (reverse (aref activity-outgoing bi)))
             (in-guids (reverse (aref activity-incoming bi)))
             (guids (append out-guids in-guids))
             (types (append (make-list (length out-guids) :initial-element "BeginConnect")
                             (make-list (length in-guids) :initial-element "EndConnect")))
             (chunks (rcb4-canvas-make-program-code idxs items-vec byte-lines-vec motion-i))
             (code-xml (rcb4-canvas-join
                        (mapcar #'(lambda (c) (format nil "        <anyType xsi:type=\"xsd:string\">~A</anyType>" c)) chunks)
                        (format nil "~%")))
             (bn (rcb4-canvas-basename-for-block idxs items-vec))
             (hint (rcb4-canvas-hint-for-block idxs items-vec))
             (motion-flag (if (= bi 0) "Start" "None"))
             (group (cond ((string= bn "CmpAD") "Compare") ((string= bn "MotionJump") "Jump") (t "Set"))))
        (push (format nil "    <anyType xsi:type=\"ActivityData\">~%      <Name>~A~A</Name>~%      <GUID>~A</GUID>~%      <Location><X>~A</X><Y>~A</Y></Location>~%      <Size><Width>~A</Width><Height>~A</Height></Size>~%      <Text>~A~A</Text>~%      <BackColorText>WhiteSmoke</BackColorText>~%      <MotionFlag>~A</MotionFlag>~%      <BaseName>~A</BaseName>~%      <Description>~A</Description>~%      <Group>~A</Group>~%      <ConnectedGuids>~A</ConnectedGuids>~%      <ConnectTypes>~A</ConnectTypes>~%      <ProgramCode>~%~A~%      </ProgramCode>~%      <Hint>~A</Hint>~%    </anyType>"
                        bn bi (aref block-guid bi) x y w h bn bi motion-flag bn description group
                        (rcb4-canvas-join guids ",") (rcb4-canvas-join types ",") code-xml hint)
              activities-xml)))
    (setq activities-xml (reverse activities-xml))
    (let ((max-col 0) (max-row 0))
      (dolist (p pos-alist)
        (setq max-col (max max-col (car (cdr p))))
        (setq max-row (max max-row (cdr (cdr p)))))
      (format nil "<?xml version=\"1.0\"?>~%<CanvasData xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">~%  <Name>canvas</Name>~%  <Size><Width>~A</Width><Height>~A</Height></Size>~%  <GridSize>8</GridSize>~%  <Lines>~%~A~%  </Lines>~%  <Activities>~%~A~%  </Activities>~%  <BackColorText>buttonface</BackColorText>~%</CanvasData>~%"
              (* (+ max-col 2) *rcb4-canvas-col-w*) (* (+ max-row 2) *rcb4-canvas-row-h*)
              (rcb4-canvas-join lines-xml (format nil "~%")) (rcb4-canvas-join activities-xml (format nil "~%"))))))

;; convenience: compile+assemble+generate+write in one call.
;; prog: an rcb4lisp s-expression (e.g. (if (> (read-servo-pos N) 0) (call A) (call B)))
(defun rcb4lisp-program-to-canvas-xml-file (prog motion-i outpath &key (description "自動生成"))
  (setq rcb4lisp::*label-number* 0)
  (let* ((compiled (rcb4lisp::compile prog))
         (xml (rcb4lisp-program-to-canvas-xml compiled motion-i :description description)))
    (with-open-file (f outpath :direction :output :if-exists :supersede)
      (format f "~A" xml))
    outpath))

;;;
;;; 2026.8  acodes -> rcb4lisp ソース（「デコンパイラ」）。
;;; rcb4lisp 自身のコンパイラが出力する特定制御フロー形状の
;;; (if (COMPARISON) THEN [ELSE]) 連鎖（rcb4lisp.l 内の eval-if-else/jump-if を参照）
;;; を認識して再構築します。また、
;;; (:angle-time-plist tm plist) ブロック（rcb4-deconversion のモデル認識型ポーズ表現）
;;; を認識し、これを (servo *ri* (:angle-plist ...) tm) として再構築します。
;;; この形式は rcb4lisp::compile がすでに適切な :servo acode へ変換する方法を
;;; 知っているため（eval-call-to-servo を参照）、rcb4lisp コンパイラの拡張は不要で、
;;; すでに相互変換（ラウンドトリップ）が可能です。
;;;
;;; それ以外のもの（ポーズに逆変換できない生 :servo 命令、while 風の後方ジャンプなど）は、
;;; 推測で処理せず不透明な (:raw ...) 形式のまま残します。
;;;
;;; 自前用途として rcb4lisp が実際に吐き出す厳密な比較式である
;;; (> (read-servo-pos N) 0) のみがパターンマッチングされます。
;;; 他の比較演算子（<, <=, >=, =, !=）が必要になった場合は、
;;; それらの条件フラグのシグネチャを rcb4-decompile-condition-block に
;;; 追加する必要があります（完全な表は rcb4lisp.l 内の if-condition を参照）。


;; 末尾の無条件 (:jump nil target) を取り除きます。
;; これは then 節の後に続く eval-if-else の「goto end-of-if」マーカーに過ぎず、
;; 意味のあるソースコード内容ではありません。

(defun rcb4-decompile-strip-trailing-goto (idxs items-vec)
  (if (and idxs
           (let ((last-instr (aref items-vec (car (last idxs)))))
             (and (consp last-instr) (eq (car last-instr) :jump) (null (cadr last-instr)))))
      (butlast idxs)
    idxs))

;; recognizes: (:move (:ram (:servo N 4) 2) (:ram addr))
;;             (:sub (:lit 0 0) (:ram addr) t)
;;             (:jump (:c :z :c= :z=) target)
;; which is exactly what rcb4lisp compiles (> (read-servo-pos N) 0) to
;; (if-condition ">" t) = (:c :z :c= :z=), see rcb4lisp.l.
(defun rcb4-decompile-cond-set-eq-p (a b)
  (and (listp a) (listp b) (= (length a) (length b))
       (null (set-difference a b)) (null (set-difference b a))))

(defun rcb4-decompile-condition-block (idxs items-vec)
  (when (= (length idxs) 3)
    (let ((mov (aref items-vec (first idxs)))
          (sub (aref items-vec (second idxs)))
          (jmp (aref items-vec (third idxs))))
      (when (and (consp mov) (eq (car mov) :move)
                 (consp sub) (eq (car sub) :sub)
                 (consp jmp) (eq (car jmp) :jump))
        (let ((src (cadr mov)))
          (when (and (consp src) (eq (car src) :ram)
                     (consp (cadr src)) (eq (car (cadr src)) :servo)
                     (rcb4-decompile-cond-set-eq-p (cadr jmp) '(:c :z :c= :z=)))
            (list '> (list 'read-servo-pos (cadr (cadr src))) 0)))))))

;; a block whose (post-goto-stripped) content is exactly one :call to a
;; cross-slot (:motiontable N) target.
(defun rcb4-decompile-call-block (idxs items-vec)
  (when (= (length idxs) 1)
    (let ((instr (aref items-vec (car idxs))))
      (when (and (consp instr) (eq (car instr) :call))
        (let ((tgt (caddr instr)))
          (when (and (consp tgt) (eq (car tgt) :motiontable))
            (list 'call (cadr tgt))))))))

;; a block whose content is exactly one ccodes-level (:angle-time-plist tm
;; plist) entry (rcb4-deconversion's output for a deconvertible :servo
;; instruction) -- reconstructed as a form rcb4lisp::compile already
;; understands (eval-call-to-servo's :angle-plist branch).
(defun rcb4-decompile-pose-block (idxs items-vec)
  (when (= (length idxs) 1)
    (let ((instr (aref items-vec (car idxs))))
      (when (and (consp instr) (eq (car instr) :angle-time-plist))
        (let ((tm (cadr instr)) (plist (caddr instr)))
          `(servo *ri* (:angle-plist ,@plist) ,tm))))))

(defvar *rcb4-decompile-max-depth* 500)

(defun rcb4-decompile-node (bi blocks items-vec label-to-block &optional (depth 0))
  (if (> depth *rcb4-decompile-max-depth*)
      (list :raw-too-deep bi)
    (let* ((raw-idxs (cdr (nth bi blocks)))
           (idxs (rcb4-decompile-strip-trailing-goto raw-idxs items-vec)))
      (if (null idxs)
          nil
        (let ((cond-form (rcb4-decompile-condition-block idxs items-vec)))
          (cond
           (cond-form
            (let* ((edges (rcb4-canvas-block-edges bi blocks items-vec label-to-block))
                   (else-bi (cdr (assoc :true edges)))
                   (then-bi (cdr (assoc :false edges)))
                   (then-form (rcb4-decompile-node then-bi blocks items-vec label-to-block (1+ depth)))
                   (else-form (rcb4-decompile-node else-bi blocks items-vec label-to-block (1+ depth))))
              (if else-form
                  (list 'if cond-form then-form else-form)
                (list 'if cond-form then-form))))
           ((rcb4-decompile-call-block idxs items-vec))
           ((rcb4-decompile-pose-block idxs items-vec))
           (t (list :raw (mapcar #'(lambda (i) (aref items-vec i)) idxs)))))))))

;; acodes: e.g. (send motion-code :acodes). ri: a live rcb4-interface
;; instance with the matching robot model loaded (needed by
;; rcb4-deconversion to resolve servo-id <-> joint-name, same requirement
;; as :generate-formed-acodes elsewhere in this codebase).
(defun rcb4-acodes-to-rcb4lisp (acodes ri &optional (jump-labels (rcb4-jump-labels acodes)))
  (let* ((ccodes (rcb4-deconversion acodes ri jump-labels))
         (items-vec (coerce ccodes vector))
         (bl (rcb4-canvas-build-blocks items-vec))
         (blocks (car bl)) (label-to-block (cadr bl)))
    (rcb4-decompile-node 0 blocks items-vec label-to-block)))

(defun rcb4-motion-code-to-rcb4lisp (mc ri)
  (rcb4-acodes-to-rcb4lisp (send mc :acodes) ri))


