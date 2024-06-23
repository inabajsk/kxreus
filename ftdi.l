;;;
;;; 2017.11.7 FTDI libftdi handling M.I
;;;
(provide :ftdi)

#-:arm
(when (probe-file "/usr/lib/x86_64-linux-gnu/libftdi.so.1")
  (setq *ftdi-mod* (load-foreign "/usr/lib/x86_64-linux-gnu/libftdi.so.1")))
#+(and :arm :word-size=64)
(when (probe-file "/usr/lib/aarch64-linux-gnu/libftdi.so.1")
  (setq *ftdi-mod* (load-foreign "/usr/lib/aarch64-linux-gnu/libftdi.so.1")))
#+(and :arm :word-size=32)
(when (probe-file "/usr/lib/arm-linux-gnueabihf/libftdi.so.1")
  (setq *ftdi-mod* (load-foreign "/usr/lib/arm-linux-gnueabihf/libftdi.so.1")))
#+(and :arm :word-size=32)
(when (probe-file "/home/m5stack/lib/libftdi.so.1")
  (setq *ftdi-mod* (load-foreign "/home/m5stack/lib/libftdi.so.1")))

(defcstruct ftdi_context
  (usb_dev_handle :long)
  (usb_read_timeout :integer)
  (usb_write_timeout :integer)
  (ftdi_chip_type :integer)
  (baudrate :integer)
  (bitbang_enabled :byte)
  (readbuffer :long)
  (readbuffer_offset :integer)
  (readbuffer_remaining :integer)
  (readbuffer_chunksize :integer)
  (writebuffer_chunksize :integer)
  (max_packet_size :integer)
  (interface :integer)
  (index :integer)
  (in_ep :integer)
  (out_ep :integer)
  (bitbang_mode :byte)
  (eeprom_size :integer)
  (error_str :long)
  (async_usb_buffer :long)
  (async_usb_buffer_size :integer)
  (module_detach_mode :integer)
  )

(when (boundp '*ftdi-mod*)
(defforeign ftdi_init *ftdi-mod* "ftdi_init" () :integer) ;;
)
(defun ftdi-init (&key (index 0) (vendor #x165c)
		       (product #x0008) (description 0) (serial 0))
  (let ((fcon (instantiate ftdi_context)))
    (ftdi_init fcon)
    (ftdi_usb_open_desc_index fcon vendor product description serial index)
    fcon))

(defun ftdi-com-init0 (&key (baud 1250000)
			 (vid #x165c) (pid #x0008)
			 (index 0) (interface 0)
			 (description 0) (serial 0))
  (let ((fcon (instantiate ftdi_context)))
    (ftdi_init fcon)
    (ftdi_set_interface fcon interface)
    (ftdi_usb_open_desc_index fcon vid pid description serial index)
    (unless (numberp baud)
      (if (or (null baud) (equal baud :low)) (setq baud 115200)
        (setq baud 1250000)))
    (ftdi_set_baudrate fcon baud)
    (ftdi_set_line_property fcon 8 0 2) ;; BITS_8, STOP_BIT_1, EVEN                 
    fcon))
;;
(defun rcb4-com-init0 (&key slow (baud 1250000) (vid #x165c) (pid #x0008) (index 0) (interface 0)
			    (description 0) (serial 0))
  (let ((fcon (instantiate ftdi_context)))
    (ftdi_init fcon)
    (ftdi_set_interface fcon interface)
    (ftdi_usb_open_desc_index fcon vid pid description serial index)
    (if slow (setq baud :slow))
    (unless (numberp baud)
      (if (or (null baud) (member baud '(:low :slow))) (setq baud 115200)
	(setq baud 1250000)))
    (ftdi_set_baudrate fcon baud)
    (ftdi_set_line_property fcon 8 0 2) ;; BITS_8, STOP_BIT_1, EVEN
    (ftdi_set_latency_timer fcon 1)
    fcon))

(defun rcb4-open (&aux (vid #x165c))
  (when (check-lsusb vid)
    (ftdi-com-init :vid vid :pid #x0008 :baud 1250000 :parity 2)))

(defun arm2-open (&aux (vid #x0403))
  (when (check-lsusb vid)
    (ftdi-com-init :vid vid :pid #x6001 :baud 921600 :parity 0)))

(when (boundp '*ftdi-mod*)
(defforeign ftdi_set_interface *ftdi-mod* "ftdi_set_interface" () :integer);; ftdi_context *ftdi, enum ftdi_interface interface);
(defforeign ftdi_deinit *ftdi-mod* "ftdi_deinit" () :integer) ;; struct ftdi_context *ftdi);
(defforeign ftdi_free *ftdi-mod* "ftdi_free" () :integer) ;; struct ftdi_context *ftdi);
(defforeign ftdi_set_usbdev *ftdi-mod* "ftdi_set_usbdev" () :integer) ;; struct ftdi_context *ftdi, usb_dev_handle *usbdev);
(defforeign ftdi_usb_find_all *ftdi-mod* "ftdi_usb_find_all" () :integer) ;; ftdi_context *ftdi, ftdi_device_list **devlist, int vendor, int product);
(defforeign ftdi_list_free *ftdi-mod* "ftdi_list_free" () :integer) ;; ftdi_device_list **devlist);
(defforeign ftdi_list_free2 *ftdi-mod* "ftdi_list_free2" () :integer) ;; ftdi_device_list *devlist);
(defforeign ftdi_usb_get_strings *ftdi-mod* "ftdi_usb_get_strings" () :integer) ;; ftdi_context *ftdi, usb_device *dev, char * manufacturer, int mnf_len, char * description, int desc_len, char * serial, int serial_len);

(defforeign ftdi_usb_open *ftdi-mod* "ftdi_usb_open" () :integer) ;; ftdi_context *ftdi, int vendor, int product);
(defforeign ftdi_usb_open_desc *ftdi-mod* "ftdi_usb_open_desc" () :integer) ;; ftdi_context *ftdi, int vendor, int product, const char* description, const char* serial);
(defforeign ftdi_usb_open_desc_index *ftdi-mod* "ftdi_usb_open_desc_index" () :integer) ;; ftdi_context *ftdi, int vendor, int product, const char* description, const char* serial, unsigned int index);
(defforeign ftdi_usb_open_dev *ftdi-mod* "ftdi_usb_open_dev" () :integer) ;; ftdi_context *ftdi, usb_device *dev);
(defforeign ftdi_usb_open_string *ftdi-mod* "ftdi_usb_open_string" () :integer) ;; ftdi_context *ftdi, const char* description);

(defforeign ftdi_usb_close *ftdi-mod* "ftdi_usb_close" () :integer) ;; ftdi_context *ftdi);
(defforeign ftdi_usb_reset *ftdi-mod* "ftdi_usb_reset" () :integer) ;; ftdi_context *ftdi);
(defforeign ftdi_usb_purge_rx_buffer *ftdi-mod* "ftdi_usb_purge_rx_buffer" () :integer) ;; ftdi_context *ftdi);
(defforeign ftdi_usb_purge_tx_buffer *ftdi-mod* "ftdi_usb_purge_tx_buffer" () :integer) ;; ftdi_context *ftdi);
(defforeign ftdi_usb_purge_buffers *ftdi-mod* "ftdi_usb_purge_buffers" () :integer) ;; ftdi_context *ftdi);

(defforeign ftdi_set_baudrate *ftdi-mod* "ftdi_set_baudrate" () :integer) ;; ftdi_context *ftdi, int baudrate);
(defforeign ftdi_set_line_property *ftdi-mod* "ftdi_set_line_property" () :integer)
;; ftdi_context *ftdi, enum ftdi_bits_type bits, ftdi_stopbits_type sbit, enum ftdi_parity_type parity);
(defforeign ftdi_set_line_property2 *ftdi-mod* "ftdi_set_line_property2" () :integer)
;; ftdi_context *ftdi, enum ftdi_bits_type bits, sbit, parity, break_type);

;; read from ftdi chip with n byte buffer (!= read n byte)
(defforeign ftdi_read_data *ftdi-mod* "ftdi_read_data" () :integer) ;; ftdi_context *ftdi, unsigned char *buf, int size);
)

;; read n byte
(defun ftdi-read-timeout (fcon n &key (timeout 1000) (limit 2000)
			  &aux (buf "")
			    (original-timeout (send fcon :get 'usb_read_timeout))
			    (sub-buf (instantiate string n))
			    (rest-n n) i cnt)
  (send fcon :set timeout 'usb_read_timeout)
  (while (not (= rest-n 0))
    (setq cnt 0)
    (while (= 0 (setq i (ftdi_read_data fcon sub-buf rest-n)))
      (setq cnt (1+ cnt))
      (if (> cnt limit) (return-from ftdi-read-timeout nil))
      )
    (cond
     ((<= i 0)
      (format t ";; ftdi_read_data=~A sub-buf=~A rest-n=~A~%" i sub-buf rest-n)
      )
     (t
      (setq buf (concatenate cons buf (subseq sub-buf 0 i)))
      (setq rest-n (- rest-n i)))))
  (send fcon :set original-timeout 'usb_read_timeout)
  buf)

(defun ftdi-read-data (fcon n &key (timeout 1000)
			    &aux (buf "")
			    (original-timeout (send fcon :get 'usb_read_timeout))
			    (sub-buf (instantiate string n))
			    (rest-n n) i)
  (send fcon :set timeout 'usb_read_timeout)
  (while (not (= rest-n 0))
    (while (= 0 (setq i (ftdi_read_data fcon sub-buf rest-n))))
    (cond
     ((< i 0)
      (format t ";; ftdi_read_data=~A sub-buf=~A rest-n=~A~%" i sub-buf rest-n)
      )
     (t
      (setq buf (concatenate cons buf (subseq sub-buf 0 i)))
      (setq rest-n (- rest-n i)))))
  (send fcon :set original-timeout 'usb_read_timeout)
  buf)

(when (boundp '*ftdi-mod*)
(defforeign ftdi_read_data_set_chunksize *ftdi-mod* "ftdi_read_data_set_chunksize" () :integer) ;; ftdi_context *ftdi, unsigned int chunksize);
(defforeign ftdi_read_data_get_chunksize *ftdi-mod* "ftdi_read_data_get_chunksize" () :integer) ;; ftdi_context *ftdi, unsigned int *chunksize);

(defforeign ftdi_write_data *ftdi-mod* "ftdi_write_data" () :integer) ;; ftdi_context *ftdi, unsigned char *buf, int size);
)

(defun ftdi-write-data (fcon str)
  (ftdi_write_data fcon str (length str)))

(when (boundp '*ftdi-mod*)
(defforeign ftdi_write_data_set_chunksize *ftdi-mod* "ftdi_write_data_set_chunksize" () :integer) ;; ftdi_context *ftdi, unsigned int chunksize);
(defforeign ftdi_write_data_get_chunksize *ftdi-mod* "ftdi_write_data_get_chunksize" () :integer) ;; ftdi_context *ftdi, unsigned int *chunksize);

(defforeign ftdi_write_data_async *ftdi-mod* "ftdi_write_data_async" () :integer) ;; ftdi_context *ftdi, unsigned char *buf, int size);
(defforeign ftdi_async_complete *ftdi-mod* "ftdi_async_complete" () :integer) ;; ftdi_context *ftdi, int wait_for_more);

(defforeign ftdi_enable_bitbang *ftdi-mod* "ftdi_enable_bitbang" () :integer) ;; ftdi_context *ftdi, unsigned char bitmask));
(defforeign ftdi_disable_bitbang *ftdi-mod* "ftdi_disable_bitbang" () :integer) ;; ftdi_context *ftdi);
(defforeign ftdi_set_bitmode *ftdi-mod* "ftdi_set_bitmode" () :integer) ;; ftdi_context *ftdi, unsigned char bitmask, unsigned char mode);
(defforeign ftdi_read_pins *ftdi-mod* "ftdi_read_pins" () :integer) ;; ftdi_context *ftdi, unsigned char *pins);

(defforeign ftdi_set_latency_timer *ftdi-mod* "ftdi_set_latency_timer" () :integer) ;; ftdi_context *ftdi, unsigned char latency);
(defforeign ftdi_get_latency_timer *ftdi-mod* "ftdi_get_latency_timer" () :integer) ;; ftdi_context *ftdi, unsigned char *latency);

(defforeign ftdi_poll_modem_status *ftdi-mod* "ftdi_poll_modem_status" () :integer) ;; ftdi_context *ftdi, unsigned short *status);

(defforeign ftdi_setflowctrl *ftdi-mod* "ftdi_setflowctrl" () :integer) ;; ftdi_context *ftdi, int flowctrl);
(defforeign ftdi_setdtr_rts *ftdi-mod* "ftdi_setdtr_rts" () :integer) ;; ftdi_context *ftdi, int dtr, int rts);
(defforeign ftdi_setdtr *ftdi-mod* "ftdi_setdtr" () :integer) ;; ftdi_context *ftdi, int state);
(defforeign ftdi_setrts *ftdi-mod* "ftdi_setrts" () :integer) ;; ftdi_context *ftdi, int state);

(defforeign ftdi_set_event_char *ftdi-mod* "ftdi_set_event_char" () :integer) ;; ftdi_context *ftdi, unsigned char eventch, unsigned char enable);
(defforeign ftdi_set_error_char *ftdi-mod* "ftdi_set_error_char" () :integer) ;; ftdi_context *ftdi, unsigned char errorch, unsigned char enable);

(defforeign ftdi_eeprom_setsize *ftdi-mod* "ftdi_eeprom_setsize" () :integer) ;; ftdi_context *ftdi, ftdi_eeprom *eeprom, int size);

(defforeign ftdi_eeprom_initdefaults *ftdi-mod* "ftdi_eeprom_initdefaults" () :integer) ;; ftdi_eeprom *eeprom);
(defforeign ftdi_eeprom_free *ftdi-mod* "ftdi_eeprom_free" () :integer) ;; ftdi_eeprom *eeprom);
(defforeign ftdi_eeprom_build *ftdi-mod* "ftdi_eeprom_build" () :integer) ;; ftdi_eeprom *eeprom, unsigned char *output);
(defforeign ftdi_eeprom_decode *ftdi-mod* "ftdi_eeprom_decode" () :integer) ;; ftdi_eeprom *eeprom, unsigned char *output, int size);

(defforeign ftdi_read_eeprom *ftdi-mod* "ftdi_read_eeprom" () :integer) ;; ftdi_context *ftdi, unsigned char *eeprom);
(defforeign ftdi_read_chipid *ftdi-mod* "ftdi_read_chipid" () :integer) ;; ftdi_context *ftdi, unsigned int *chipid);
(defforeign ftdi_read_eeprom_getsize *ftdi-mod* "ftdi_read_eeprom_getsize" () :integer) ;; ftdi_context *ftdi, unsigned char *eeprom, int maxsize);

)

(defun ftdi-read-eeprom (fcon &optional (len 128))
  (let ((str (make-string len)))
    (ftdi_read_eeprom_getsize fcon str len)
    str))

(defun ftdi-read-device-number (fcon)
  (let ((str (make-string 128)))
    (ftdi_read_eeprom_getsize fcon str 128)
    (+
     (* 100 (- (aref str 102) #\0))
     (* 10 (- (aref str 104) #\0))
     (- (aref str 106) #\0))))

(defun ftdi-set-device-number (fcon num)
  (let ((str (ftdi-read-eeprom fcon)))
    (setf (aref str 102) (+ #\0 (mod (/ num 100) 10)))
    (setf (aref str 104) (+ #\0  (mod (/ num 10) 10)))
    (setf (aref str 106) (+ #\0  (mod num 10)))
    (ftdi_write_eeprom fcon str)
    (ftdi-read-device-number fcon))
  )

(when (boundp '*ftdi-mod*)
(defforeign ftdi_write_eeprom *ftdi-mod* "ftdi_write_eeprom" () :integer) ;; ftdi_context *ftdi, unsigned char *eeprom);
(defforeign ftdi_erase_eeprom *ftdi-mod* "ftdi_erase_eeprom" () :integer) ;; ftdi_context *ftdi);

(defforeign ftdi_read_eeprom_location *ftdi-mod* "ftdi_read_eeprom_location" () :integer) ;; ftdi_context *ftdi, int eeprom_addr, unsigned short *eeprom_val);
(defforeign ftdi_write_eeprom_location *ftdi-mod* "ftdi_write_eeprom_location" () :integer) ;; ftdi_context *ftdi, int eeprom_addr, unsigned short eeprom_val);

(defforeign ftdi_get_error_string *ftdi-mod* "ftdi_get_error_string" () :integer) ;; ftdi_context *ftdi);

) ;; (when (boundp '*ftdi-mod*))

(defun ftdi-com-init (&rest
		      args
		      &key (baud 1250000)
		      slow 
		      (vid #x165c)
		      (pid #x0008)
		      (index 0)
		      (interface 0)
		      (bits 8) 	;; 7:7bits, 8:8bits
		      (parity 2);; 0:none, 1:odd, 2:even, 3:mark, 4:space
		      (stop 0)	;; 0:bit_1, 1:Bit_1.5, 2:bit_2
		      (description 0)
		      (serial 0)
		      (latency 1) ;;  1msec latency, default 16
		      &allow-other-keys)
  ;;(print (list 'ftdi-com-init-args args))
  (let ((fcon (instantiate ftdi_context)) v)
    (format t "; ftdi-open:baud:~A vid:~X pid:~X parity:~A bits:~A stop:~A latency:~A~%"
	    baud vid pid parity bits stop latency)
    (setq v (ftdi_init fcon))
    (unless (zerop v) (format t "; ftdi_init fcon:~A =~A~%" fcon v))
    ;;
    (setq v (ftdi_set_interface fcon interface))
    (unless (zerop v) (format t "; ftdi_set_interface fcon:~A =~A~%" fcon v))
    ;;
    (setq v (ftdi_usb_open_desc_index fcon vid pid description serial index))
    (unless (zerop v) (format t "; ftdi_usb_open_desk_index=~A~%" v))
    ;;
    (unless (numberp baud)
      (if (or slow (null baud) (equal baud :low)) (setq baud 115200)
	(setq baud 1250000)))
    (setq v (ftdi_set_baudrate fcon baud))
    (unless (zerop v) (format t "; ftdi_set_baudrate=~A~%" v))
    ;;
    (setq v (ftdi_set_line_property fcon BITS stop parity))
    ;; BITS_8, STOP_BIT_1, EVEN
    (unless (zerop v) (format t "; ftdi_set_line_property=~A~%" v))
    ;;
    (setq v (ftdi_set_latency_timer fcon latency))
    (unless (zerop v) (format t "; ftdi_set_latency_timer fcon 1=~A~%" v))
    fcon)
  )

(defun lsusb-readlines ()
  (let ((strm (piped-fork "lsusb"))
	ret v)
    (while (setq v (read-line strm nil nil))
      (push v ret))
    (reverse ret)))

(defun check-lsusb (vid)
  (let ((lines (lsusb-readlines))
	(str (format nil "~X" vid))
	v)
    (catch :check-lsusb
      (while (setq v (pop lines))
	(when (substringp str v)
	  (throw :check-lsusb t)))
      nil)))

(defclass ftdi-interface :super propertied-object
  :slots (com-port))

(defmethod ftdi-interface
    (:create nil self)
  (:ftdi-open  ;; pid: #x6015 Akizuki USB-serial , #x6001 DSDTECH, #x0008 RCB4
   ;; vid: #x165c RCB4,  #x403 Akizuki, DSDTECH
   ;; parity: 2 RCB4, 0 ARMH7
   ;; baud: 1250000 RCB4, 921600 Akizuki, DSDTECH
   (&rest args &key (index 0) slow (baud 921600) (vid #x403) (pid #x6001) (interface 0)
	  (stop 0) (parity 0) &allow-other-keys)
   (when (check-lsusb vid)
     (setq com-port (ftdi-com-init :slow slow :baud baud :vid vid :pid pid :index index
				   :interface interface :stop stop :parity parity))))
  )
