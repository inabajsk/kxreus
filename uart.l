;;;
;;; 2022.5.14
;;;
;;#-:arm
;;(setq *libc-mod* (load-foreign "/usr/lib/x86_64-linux-gnu/libc.a"))
;;#+(and :arm :word-size=64)
;;(setq *libc-mod* (load-foreign "/usr/lib/aarch64-linux-gnu/libc.so"))
;;#+(and :arm :word-size=32)
;;(setq *libc-mod* (load-foreign "/usr/lib/arm-linux-gnueabihf/libc.so"))
(require :ftdi)
;;(defforeign unix_open *libc-mod* "__open" () :integer)
;;(defforeign unix_read *libc-mod* "__read" () :integer)
;;(defforeign unix_write *libc-mod* "__write" () :integer)

(defcstruct termios
  (c_iflag :integer)
  (c_oflag :integer)
  (c_cflag :integer)
  (c_lflag :integer)
  (c_line :byte)
  (c_cc :byte 32)
  (c_ispeed :integer)
  (c_ospeed :integer)
  )

(defcstruct termios-long
  (c_iflag :long)
  (c_oflag :long)
  (c_cflag :long)
  (c_lflag :long)
  (c_line :byte)
  (c_cc :byte 32)
  (c_ispeed :long)
  (c_ospeed :long)
  )

(defun udev-rule-line (strm &key (subsystem "usb")
			    (idvendor "0403")
			    (idproduct "6001")
			    (symlink "ftdi-$attr{serial}")
			    (mode "0666")
			    )
  (format strm
	  "SUBSYSTEMS==~S, ATTRS{idVendor}==~S, ATTRS{idProduct}==~S, SYMLINK+=~S, MODE=~S~%"
	  subsystem idvendor idproduct symlink mode)
  )

(defun udev-readlines (&optional (name "ftdi"))
  (let ((strm (piped-fork (format nil "ls -l /dev/~A*" name)))
	ret v)
    (while (setq v (read-line strm nil nil))
      (push v ret))
    (reverse ret)))

(defun udev-trigger (&optional (name "ftdi") (substr "tty"))
  (unless
      (every #'(lambda (x) (substringp substr x)) (udev-readlines name))
    (unix::system "sudo udevadm trigger")
    ))

(defun init-udev (&key (file "98-my-ftdi.rules"))
  ;; SUBSYSTEMS=="usb", ATTRS{idVendor}=="165c", ATTRS{idProduct}=="0008", SYMLINK+="rcb4-$attr{serial}", MODE="0666"
  ;;#SUBSYSTEMS=="usb", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="AG0JNIBH", SYMLINK+="$attr{serial}", MODE="0666"
  (unless
      (probe-file (format nil "/etc/udev/rules.d/~A" file))
    (with-open-file
     (f "98-my-ftdi.rules" :direction :output)
     (udev-rule-line f)
     (udev-rule-line f :idproduct "6015" :symlink "aki-$attr{serial}")
     (udev-rule-line f :idvendor "165c" :idproduct "0008" :symlink "rcb4")
     )
    (unix::system (format nil "sudo cp ~A /etc/udev/rules.d/" file))
    (unix::system "sudo udevadm control --reload-rules"))
  (udev-trigger "ftdi" "tty")
  ;;(udev-trigger "aki" "tty")
  )

(defun init-tcset (&optional fdio)
  (let ((tios (instantiate termios)))
    (unix::tcgets fdio tios)
    (send tios :set #x1cb7 'c_cflag)
    (send tios :set #x8a20 'c_lflag)
    (send tios :set #x100 'c_iflag)
    (send tios :set #x4   'c_oflag)
    ;;
    (send tios :set #x1007 'c_ispeed) ;; B921600
    (send tios :set #x1007 'c_ospeed) ;; B921600
    #|
    (progn
    (send tios :set #x66fce8bc 'c_cflag)
    (send tios :set #x8a20 'c_lflag)
    (send tios :set #x76f5a134 'c_iflag)
    (send tios :set #x76f5b754 'c_oflag)
    (send tios :set #x1007 'c_ispeed) ;; B921600
    (send tios :set #x1007 'c_ospeed) ;; B921600
    ;;
    (send tios :set #xcbd 'c_cflag)
    (send tios :set #x8a20 'c_lflag)
    (send tios :set #x100 'c_iflag)
    (send tios :set #x4   'c_oflag)
    (send tios :set #x1007 'c_ispeed) ;; B921600
    (send tios :set #x1007 'c_ospeed) ;; B921600
    )
    |#
    (unix::tcsets fdio tios))
  )

(defun uart-com-init (file
		      &rest args
		      &key
		      (baud 1250000)
		      slow 
		      (vid #x165c)
		      (pid #x0008)
		      (index 0)
		      (interface 0)
		      (bits 8)
		      (parity 2)
		      (stop 0)
		      (description 0)
		      (serial 0)
		      &allow-other-keys)
  (let (fdio)
    (setq fdio (open (format nil "/dev/~A" file) :direction :io))
    (init-tcset fdio)
    ;; SUBSYSTEMS=="usb", ATTRS{idVendor}=="165c", ATTRS{idProduct}=="0008", SYMLINK+="rcb4-$attr{serial}", MODE="0666"
    ;;#SUBSYSTEMS=="usb", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="AG0JNIBH", SYMLINK+="$attr{serial}", MODE="0666"
    ((fdio . instream) . fd)
    ))

(defun uart-read1 (fd)
  (let ((buf (instantiate string 1)) ret)
    (while (<= (setq ret (unix::uread fd buf 1)) 0))
    (elt buf 0)))
(defun uart-read1-wip (fd)
  (let ((buf (instantiate string 1)) ret)
    (while (<= (setq ret (unix::select-read-fd fd 1.0)) 0)) ;; 1.0 sec
    (elt buf 0)))

(defun uart-read-data (fd &optional n &key (timeout 1000)
			  &aux buf (i 0))
  (cond
   (n
    (setq buf (instantiate string n))
    (while (< i n)
      (setf (elt buf i) (uart-read1 fd))
      (incf i)))
   (t (setq buf (uart-read-rcb4format fd))))
  buf)

(defun uart-write-data (fd str)
  (unix::write fd str (length str)))

(defun uart-read-rcb4format (fd)
  (let* ((len (uart-read1 fd)))
    (if (<= len 0) (format t "len=~A~%" len)
      (uart-read-data fd (1- len)))))

(defun uart-write-seq (fd &optional (codes (list 3 253 0)))
  (let ((ret (uart-write-data fd (coerce codes string))))
    (when (<= ret 0) (format t "write ret=~A~%" ret))
    codes))

(defun rcb4-version (fd)
  (uart-write-seq fd (list 3 253 0))
  (uart-read-data fd))

(defclass uart-interface :super propertied-object
  :slots (strm fd buf1))

(defmethod uart-interface
  (:init
   (&rest args &key devname udev &allow-other-keys)
		 (cond
		   ((null devname) 
		    ;;(print (list 'uart-interface-init-args args))
		    (setq strm (apply #'ftdi-com-init args))
		    )
		   ((stringp devname)
		    (let ((name (format nil "/dev/~A" devname)))
		      (setq strm (open name :direction :io))
		      (init-tcset strm)
		      ;;(unix::system (format nil "stty -F ~A raw cbreak -onlcr -iexten time 100 extproc" name))
		      (unix::system (format nil "stty -F ~A raw cbreak -onlcr -iexten" name))
		      (setq fd ((strm . instream) . fd))
		      ))
		   )
		 (setq buf1 (instantiate string 1))
		 ;;(setq buf (instantiate string 127))
		 (when udev (init-udev))
		 self)
  (:ready?
   (&optional (timeout-msec 100))
   (if
    (derivedp strm io-stream)
    (select-stream (list strm) (/ timeout-msec 1000.0))
    t)
   )
  (:read1-timeout
   (&optional (timeout-msec 1000))
   (while t
     (if (send self :ready? timeout-msec)
	 (return-from :read1-timeout (send self :read1 timeout-msec))
	 (return-from :read1-timeout nil))))
  (:read-all
   (&optional (timeout-msec 1000) &aux v ret)
   (while (setq v (send self :read1-timeout timeout-msec))
     (push v ret))
   (reverse ret))
  (:read1
   (&aux ret)
   (if
       (derivedp strm io-stream)
       (while (<= (setq ret (unix::uread fd buf1 1)) 0))
       (while (<= (setq ret (ftdi_read_data strm buf1 1)) 0)))
   (elt buf1 0))
  (:read-data
   (&aux n (i 0) buf)
   (setq n (1- (send self :read1)))
   (setq buf (instantiate string n))
   (while (< i n)
     (setf (elt buf i) (send self :read1))
     (incf i))
   buf)
  (:write-data
   (byte-array &optional (len (length byte-array)))
   (if (derivedp strm io-stream)
       (unix::write fd byte-array len)
     (let ((n len) i)
       (setq i (ftdi_write_data strm (coerce byte-array string) n))
       (unless (= n i)
	 (format t ";; (:write ~S ~S) -> ~A~%" n byte-array i))
       i)))
  )

(defun uart-init (&optional (name "ftdi-AO007VJN") &key udev)
  (when udev (init-udev))
  (setq *fd* (uart-com-init name))
  )

(defun uart-test (&key ack (name "ftdi-AO007VJN") udev)
  (unless (boundp '*fd*) (uart-init name :udev udev))
  (if ack
      (uart-write-seq *fd* (list 3 254 1))
    (uart-write-seq *fd* (list 3 253 0)))
  (uart-read-data *fd*))

(defun uart-in (&optional (name "/dev/ftdi-AO007VJN") &aux ret)
  (with-open-file
   (f name :direction :input)
   (while
       (setq ret (read-line f nil nil))
     (print ret))))

(defun uart-out (&optional (name "/dev/serial0") &aux ret)
  (with-open-file
   (f name :direction :output)
   (while (setq ret (read-line))
     (print ret f))))

(provide :uart)  
  
