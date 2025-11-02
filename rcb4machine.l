;;;
;;;	Emulator
;;;
(defmethod vector
    (:length () (length self))
  (:elt (&rest args) (forward-message-to (elt self (car args)) (cdr args)))
  (:position (v &key (key #'cr) (test #'equal))
	     (position v self :key key :test test))
  (:find (v &key (key #'cr) (test #'equal))
	 (find v self :key key :test test))
  )

(defclass rcb4-motion-table :super vector)

(defmethod rcb4-motion-table
  (:setup-motion-table
   (mcodes &aux n)
   (dolist (m mcodes)
     (if (setq n (send m :number))
	 (when (< n 120)
	   (setf (elt self n) m))))
   self)
  (:erase-button
   (button-num)
   (if (listp button-num) (setq button-num (rcb4-encode-button-code button-num)))
   (dotimes (i 120)
     (if (elt self i)
	 (if (= button-num (car (send (elt self i) :buttondata)))
	     (send (elt self i) :buttondata (list 0 (list 0 0))))))
   )
  (:erase-motion-button
   (mi)
   (if (elt self mi)
       (when (send (elt self mi) :buttondata)
	 (send (elt self mi) :buttondata (list 0 (list 0 0))))))
  (:set-motion-button ;; rcb4-motion-table
   (motion-id buttons) ;; 513 0 ((:button 513 (2 1) :lshiftu :lforward) (:motiontable 0 0 |L#XB80|))
   (let ((mc (elt self motion-id)))
     (if (and buttons (atom buttons)) (setq buttons (list buttons)))
     (setq buttons (rcb4-encode-button-code buttons))
     (when mc
       ;;(format t ";; :set-motion-button motion-id:~A buttons:~A~%" motion-id buttons)
       (send self :erase-button buttons)
       (send mc :buttondata (rcb4-decode-button-code buttons))
       mc)))
  (:button-mc
   (button &aux x)
   (if (listp button) (setq button (rcb4-encode-button-code button)))
   (dotimes (i 120)
     (setq x (elt self i))
     (if (and x (> (car (send x :buttondata)) 0))
	 (if (= button (car (send x :buttondata)))
	     (return-from :button-mc x)))))
  (:mcode (ith) (elt self ith))
  )

(defclass rcb4-jump-vectors :super vector)

(defmethod rcb4-jump-vectors
    (:set-jump-vector (i jv)
     (setf (elt self i) jv))
  (:button-mi
   (button)
   (if (listp button) (setq button (rcb4-encode-button-code button)))
   (send self :find button :key #'cadr)
   )
  (:setup-jump-vectors
   (mtab jvlist &aux mi mc jv (ji 0) btns) ;; mtab: motion-table
   (dolist (jv jvlist)
     (setq mi (car (elt jv 2)))
     (setq mc (elt mtab mi))
     (setq btns (assocdr :button jv))
     (send (elt mtab mi) :buttondata btns)
     (setq ji (car jv))
     (setf (elt self ji) jv))
   (send self :scan-jump-vectors mtab)
   )
  (:scan-jump-vectors
   (mtab &aux jv (ji 0) btns) ;; mtab: motion-table   
   (dotimes (i 120)
     (when (elt mtab i)
       (setq jv (send (elt mtab i) :buttondata))
       (when (> (car jv) 0)
	 (cond
	  ((member (car jv) btns)
	   (send (elt mtab i) :buttondata (list 0 (list 0 0))))
	  (t (push (car jv) btns)
	     (when (< ji 31)
	       (setf (elt self ji)
		     (list ji
			   (cons :button jv)
			   (list i 0)))
	       (setq ji (1+ ji))))))))
   (while (< ji 32)
     (setf (elt self ji) nil)
     (setq ji (1+ ji)))
   self)
  )
(defun write-motion-file-head-line (mfstrm robo)
  (format mfstrm "#WEBOTS_MOTION,V1.0")
  (dolist (j (send robo :joint-list))
    (let ((nm (send j :name)))
      (format mfstrm ",~A" (string-downcase (if (symbolp nm) (symbol-name nm) nm)))))
  (format mfstrm "~%"))
(defun webots-time-format (time-sec cnt)
  (let* ((min (floor (/ time-sec 60)))
	 (sec (floor (mod time-sec 60)))
	 (msec (floor (mod (* 1000 time-sec) 1000)))
	 (str (format nil "~2d:~2d:~3d,Pose~A" min sec msec cnt)))
    (dotimes (i (length str))
      (if (= (elt str i) #\ ) (setf (elt str i) #\0)))
    str))
(defun write-motion-file-angle-vector (mfstrm av time-sec cnt)
  (format mfstrm "~A" (webots-time-format time-sec cnt))
  (dotimes (i (length av)) (format mfstrm ",~A" (deg2rad (elt av i))))
  (format mfstrm "~%"))

(defclass rcb4-machine
  :slots (robot machine-ram machine-rom vwer rom-table user-vars rom-jump-vectors)
  )

(defmethod rcb4-machine
    (:set-robot (&optional r) (if r (setq robot r)) robot)
  (:robot (&rest args) (forward-message-to robot args))
  (:init
   ()
   (setq machine-ram (instantiate string #x490))
   (setq machine-rom (instantiate string #x3cbbb))
   (setq rom-table (instantiate rcb4-motion-table 120))
   (dotimes (i 120)
     (setf (elt rom-table i)
	   (instance rcb4-motion-code :init
		     (format nil "motion ~A" i) nil i 0)))
   (setq rom-jump-vectors (instantiate rcb4-jump-vectors 32))
   (setq user-vars (instantiate vector 20)) ;; used flag
   self)
  (:set-robot (robo) (setq robot robo))
  (:create-viewer
   (&key ((:viewer vw)) (width 400) (height 400) (background (float-vector 0.6 0.4 0.99)))
   (if (derivedp vw x::irtviewer)
       (setq vwer vw)
     (if (xwindow-ready?)
	 (setq vwer (instance x::irtviewer :create :width width :height height))
       (setq vwer nil)))
   (setf (get robot :viewer) vwer)
   (when vwer
     (send vwer :change-background (float-vector 0.6 0.4 0.99))
     (send vwer :objects (list robot))
     (send vwer :look-all)
     (send vwer :title (send robot :name))
     (send vwer :name (send robot :name))
     vwer))
  (:viewer (&rest args) (forward-message-to vwer args))
  ;;
  (:motion-table (&rest args) (forward-message-to rom-table args))
  (:jump-vectors (&rest args) (forward-message-to rom-jump-vectors args))
  (:list-jump-vectors
   (&optional (jvs rom-jump-vectors))
   (let (v ret mt nm)
     (dotimes (i (length jvs))
       (when (setq v (elt rom-jump-vectors i))
	 (setq mt (elt v 2))
	 (setq nm (send (elt rom-table (car mt)) :name))
	 (if (consp nm) (setq nm (cdr nm)))
	 (push (list (car v) (cadr v) (list (car mt) nm)) ret)))
     (reverse ret)))
  (:scan-jump-vectors
   nil
   (send rom-jump-vectors :scan-jump-vectors rom-table)
   (send self :list-jump-vectors))
  (:erase-motion-button
   (mi)
   (send rom-table :erase-motion-button mi)
   (send self :scan-jump-vectors))
  (:set-motion-button
   (motion-id buttons) ;; button : number | (list :r-back .... :l-back)
   (send rom-table :set-motion-button motion-id buttons)
   (send self :scan-jump-vectors))
  (:setup-jump-vectors
   (ramv)
   (let (v1 v2)
     (dotimes (i (length ramv))
       (setq v1 (elt ramv i))
       ;;(unless (equal v1 v2) (warn ";:read-jump-vectors diff ram[~A]=~A,rom[~A]=~A~%" i v1 i v2))
       (when v1
	 (send self :set-motion-button
	       (car (elt v1 2))
	       (cadr (assoc :button v1))
	       )))
     (send rom-jump-vectors :setup-jump-vectors rom-table ramv)))
  (:set-rom-table (i v)
		  (setf (elt rom-table i) v)
		  v)
  (:rom-table (&rest args) 
	      (cond
		((numberp (car args))
		 (forward-message-to (elt rom-table (car args)) (cdr args)))
		((keywordp (car args))
		 (forward-message-to rom-table args))
		(t rom-table)))
  (:machine-ram (addr) (elt machine-ram (rcb4-address addr)))
  (:machine-rom (addr) (elt machine-rom (rcb4-address addr)))
  (:exec nil nil)
  (:compare-i
   (i)
   (let* ((mc (elt rom-table i))
	  (a0 (mc . acodes)) (b0 (mc . bcodes))
	  (a1 (mc . ac)) (b1 (mc . bc)))
     (dolist (a a0)
       (unless (equal a (car a1))
	 (format t ";; compare:~A~%~A~%~A~%" (mc . name) (cadr a) (cadr (car a1)))
	 (if (equal (cadr a) (cadr (car a1)))
	     (format t "~A~%~A~%" (cadddr a) (cadddr (car a1))))
	 )
       (pop a1))))
  (:compare (&aux (i 0))
	    (do-until-key
	     (if (>= i 120) (return-from :compare nil))
	     (send self :compare-i i)
	     (incf i)))
  (:alloc-user-var
   (&optional (v t))
   (let ((index (position-if #'null user-vars)))
     (cond
      (index
       (setf (elt user-vars index) v)
       index)
      (t (error "no more user-vars: ~A~%" user-vars)))))
  (:draw-rom-table
   (ri &optional n &key (loopmax 200))
   (let (mm m)
     (cond
      ((numberp n)
       (if (null (elt rom-table n)) (send self :read-rom-table n))
       (setq m (elt rom-table n))
       (if m (send ri :emulate-motion-code (elt rom-table n) :loopmax loopmax)))
      (t
       (if (null (elt rom-table 0)) (send ri :read-rom-all))
       (setq mm (coerce rom-table cons))
       (do-until-key
	   (if (null mm) (return-from :draw-rom-table nil))
	 (setq m (pop mm))
	 (if m (send ri :emulate-motion-code m :loopmax loopmax)))))))
  (:emulate-motion-code
   (ri mc &key (loopmax 100) copy-viewer send-to-ri (wait 0) ode-ci motion-file)
   (let* ((acodes (if (listp mc) mc (send mc :acodes)))
	  (alen (length acodes))
	  (num (if (listp mc) 0 (send mc :number)))
	  scodes slen (pc 0) a labels zflag cflag
	  inst i op src dest flag addr len data cond
	  (time-sec 0) (av-cnt 0)
	  (loop 0) labaddr sft size)
     
     (if (atom mc)
	 (format t "~S~%" (send mc :name)))
     (dolist (a acodes)
       (cond ((symbolp a) (push (cons a pc) labels))
	     (t (push a scodes)	(setq pc (1+ pc)))))
     (setq slen pc  scodes (coerce (reverse scodes) vector))
     ;;(format t ";labels=~A~%" labels)
     (setq pc 0) ;; (format t ";~A~%; labels=~A~%" mc labels)
     (while (< pc slen)
       (setq inst (elt scodes pc))
       (setq a inst op (pop a))
       (when (> (setq loop (1+ loop)) loopmax)
	 (format t "; loop ~A: ~A~%" loop mc) (setq pc slen))
       ;;(format t ";;;pc=~A inst=~A~%" pc (car inst))
       (case op
	 (:return (setq pc slen))
	 (:jump
	  (setq cond (pop a)) (setq addr (pop a))
	  (cond
	   ((and (symbolp addr) (assoc addr labels))
	    (setq addr (assocdr addr labels)))
	   ((consp addr)
	    (cond
	     ((= (cadr addr) num) ;; inside
	      (format t ";(jump cond=~A addr=~A(pc=~A)) zflag=~A cflag=~A~%" 
		      cond addr (assocdr (car (last addr)) labels) zflag cflag)
	      (setq addr (assocdr (car (last addr)) labels))
	      )
	     (t
	      (when (or (null cond) 
			(and zflag (member :z cond) (member :z= cond))
			(and cflag (member :c= cond) (member :c cond)))
		;; (format t ";outside pc=~A cond=~A mc=~A -> mc=~A addr=~A , zflag=~A, cflag=~A~%"
		;; pc cond mc (elt rom-table (cadr addr)) addr zflag cflag)
		(cond
		 ((elt rom-table (cadr addr))
		  (return-from :emulate-motion-code
		    (send ri :emulate-motion-code (elt rom-table (cadr addr)))))
		 (t 
		  ;;(format t "(rom-table ~A)=nil, mc=~A~%" (cadr addr) mc)
		  (return-from :emulate-motion-code nil)
		  )))))))
	  (cond
	    ((numberp addr)
	     (if (or (null cond)
		     (and (member :z cond)
			  (if (member :z= cond) zflag (not zflag)))
		     (and (member :c cond)
			  (if (member :c= cond) cflag (not cflag))))
		 (setq pc addr)
		 (setq pc (1+ pc))))
	    (t (setq pc (1+ pc))))
	  ;;(format t "; after jump pc=~A : ~A~%" pc mc)
	  )
	 (:shift
	  (setq sft (pop a)) (setq size (pop a))
	  (setq dest (pop a)) (setq flag (if a (car a)))
	  (case (car dest)
	    (:ram
	     (setq addr (rcb4-address (cadr dest)))
	     (if (= size 2)
		 (let* ((value (+ (elt machine-ram addr)
				  (ash (elt machine-ram (1+ addr)) 8)))
			(dvalue (ash value (if (< sft 128) (- sft)
					       (- 256 sft)))))
		   (unless flag
		     (setf (elt machine-ram addr) dvalue)
		     (setf (elt machine-ram (1+ addr)) (ash dvalue -8)))
		   (setq zflag (zerop dvalue))
		   (setq cflag (minusp dvalue))
		   (format t
	   ";;shift sft=~A size=~A value=~A dvalue=~A flag=~A zflag=~A cflag=~A~%"
	   sft size value dvalue flag zflag cflag)
		   ))))
	  (setq pc (1+ pc)))
	 ((:mov :move :sub :add :mul :div :mod :and :or :xor)
	  (setq src (pop a)) (setq dest (pop a)) (setq flag (if a (car a)))
	  (case (pop src)
	    (:lit (setq data src))
	    (:ram (setq addr (rcb4-address (car src)))
		  (setq data nil)
		  (dotimes (i (cadr src))
		    (push (elt machine-ram (+ addr i)) data))
		  (setq data (reverse data)))
	    (:rom (setq addr (rcb4-address (car src)))
		  (setq data nil)
		  (dotimes (i (cadr src))
		    (push (elt machine-rom (+ addr i)) data))
		  (setq data (reverse data)))
	    (:ics ))
	  (case (car dest)
	    (:com )
	    (:ram (setq addr (rcb4-address (cadr dest)))
		  ;;(format t ";; op=~A, machine-ram[#x~X]=#x~X(~A), data=~A~%"
		  ;;op addr (elt machine-ram addr) (elt machine-ram addr) data)
		  (if (and (= (length data) 2) (not (eq op :move)))
		      (let* ((src (+ (car data) (ash (cadr data) 8)))
			     (dest (+ (elt machine-ram addr)
				      (ash (elt machine-ram (1+ addr)) 8)))
			     (value (funcall (rcb4-cmd-operator op) dest src)))
			(unless flag
			  (setf (elt machine-ram addr) value)
			  (setf (elt machine-ram (1+ addr)) (ash value -8)))
			(setq zflag (zerop value))
			(setq cflag (minusp value)))
		    (dolist (d data)
		      (let ((value
			     (if (eq op :move) d
			       (funcall (rcb4-cmd-operator op)
					(elt machine-ram addr) d))))
			(unless flag
			  (setf (elt machine-ram addr) value))
			(setq zflag (zerop value))
			(setq cflag (minusp value))
			(setq addr (1+ addr)))))
		  (when (and (consp (cadr dest)) (eq (car (cadr dest)) :timer))
		    (format t ";; :timer op:~A ~A, data=~A usleep (* 1000 ~A)~%"
			    op (cadr dest) data (numseq-to-num data 2))
		    (cond
		      ((memq op '(:mov :move))
		       (setq data (list (car data) (logand #x7f (cadr data))))
		       (unix:usleep (* 1000 (numseq-to-num data 2)))
		       (unless flag
			 (setf (elt machine-ram addr) 0)
			 (setf (elt machine-ram (1+ addr)) 0))
		       ))
		    )
		  )
	    (:rom  )
	    (:ics ))
	  (setq pc (1+ pc)))
	 (:call
	  (setq cond (car a)) (setq addr (cadr a))
	  (cond
	   ((and (null cond) (symbolp addr))
	    (setq addr (cadr (rcb4-symbol
			      (read-from-string (subseq (symbol-string (cadr a)) 1))
			      :rom)))
	    (format t ";call mc=~A pc=~A cond=~A, addr=~A(#x~X)~%" mc pc cond a addr addr)
	    (if (elt rom-table addr)
		(send ri :emulate-motion-code (elt rom-table addr)
		      :loopmax loopmax :send-to-ri send-to-ri)
		(send ri :emulate-motion-code (send ri :project-file :mcode addr)
		      :loopmax loopmax :send-to-ri send-to-ri))
	    (format t "; end-call~%"))
	   ((and (null cond) (consp addr))
	    (format t ";call mc=~A pc=~A cond=~A, addr=~A~%" mc pc cond addr)
	    (if (elt rom-table (cadr addr))
		(send ri :emulate-motion-code (elt rom-table (cadr addr))
		      :loopmax loopmax :send-to-ri send-to-ri)
		(send ri :emulate-motion-code (send ri :project-file :mcodes (cadr addr))
		      :loopmax loopmax :send-to-ri send-to-ri))
	    (format t "; end-call~%"))
	   )
	  (setq pc (1+ pc)))
	 (:servo
	  (let ((vel (elt a 1)))
	    (incf time-sec (/ (* vel 10) 1000.0))
	    (incf av-cnt)
	    (setq i 0)
	    (mapc
	     #'(lambda (x)
		 (when (derivedp x robot-model)
		   (when a
		     (cond
		       ((numberp (elt a 2))
			(let ((svv (send ri :servo-vector))
			      (ii (elt a 0)))
			  (setf (elt svv ii) (elt a 2))
			  (send x :angle-vector
				(send ri :servo-vector-to-angle-vector
				      svv
				      ;;(list mc (incf i) a)
				      ))
			  ))
		       (t
			(send x :angle-vector
			      (send ri :servo-vector-to-angle-vector
				    (elt a 2)
				    ;;(list mc (incf i))
				    )))))
		   ;;(format t ";; :servo wait vel=~A~%" vel)
		   (if send-to-ri
		       (send ri :angle-vector (send x :angle-vector) vel)
		     (unix:usleep (* 1000 vel 10)))
		   (when 
		       (or ode-ci (get robot :ode-ci))
		     ;;(format t ";; send-ode in emulate-motion-code x=~A~%" x)
		     (send robot :angle-vector (send x :angle-vector))
		     (send robot :send-ode (* vel 10)))
		   (when 
		       motion-file
		     ;;(format t ";; write to motion-file in emulate-motion-code x=~A~%" x)
		     (write-motion-file-angle-vector
		      motion-file (send x :angle-vector) time-sec av-cnt)
		     )
		   ))
	     (or (and vwer (send vwer :objects)) (list robot)))
	    (when vwer
	      (send vwer :draw-objects)
	      (when copy-viewer
		(send copy-viewer :viewer :viewsurface :putimage
		      (send (send vwer :viewer :viewsurface :getglimage) :halve)
		      :depth 24)
		))
	    (if (numberp (elt a 1))
		(unix:usleep (* 10000 (elt a 1)))
	      (unix:usleep (* 10000 (elt (car a) 1))))
	    (setq pc (1+ pc))))
	 (t (setq pc (1+ pc))))
       (when vwer
	 (send vwer :draw-objects)
	 ;;(send vwer :string 10 (- (send vwer :height) 10)
	 ;;(format nil "~A: PC:~A OP: ~A" num pc op))
	 ;;(send vwer :string 10 15
	 ;;(format nil "~A" (if (listp mc) "asm" (send mc :name))))
	 (send vwer :strings
	       (list 
		(format nil "Name:~A" (if (listp mc) "asm" (send mc :name)))
		(format nil "No:~A PC:~A OP: ~A" num pc op)))
	 (when copy-viewer
	   (send copy-viewer :viewer :viewsurface :putimage
		 (send (send vwer :viewer :viewsurface :getglimage) :halve)
		 :depth 24))
	 (unix:usleep (* wait 1000))
	 (x::window-main-one))
       )))
  )

(provide :rcb4machine)
