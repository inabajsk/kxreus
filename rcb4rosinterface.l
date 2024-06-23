
(ros::load-ros-manifest "roseus")
(ros::load-ros-manifest "std_msgs")
(ros::load-ros-manifest "geometry_msgs")
(ros::load-ros-manifest "kxr_rosserial_msgs")

(require :rcb4robots)

(defclass rcb4-ros-interface :super propertied-object
  :slots ()
  )

(defmethod rcb4-ros-interface
  (:init
   ()
   self)
  (:send-lisp
   (sexp)
   (let ((command-req (instance kxr_rosserial_msgs::LispCommandRequest :init))
	 (strm (make-string-output-stream 128)))
     (print sexp strm)
     (send command-req :command (get-output-stream-string strm))
     (setq response (ros::service-call "lisp_command" command-req))
     (ros::spin-once)
     (read-from-string (send response :response))))
  (:neutral () (send self :send-lisp '(send *ri* :neutral)))
  (:free () (send self :send-lisp '(send *ri* :free)))
  (:hold () (send self :send-lisp '(send *ri* :hold)))
  (:robot-name () (send self :send-lisp '(send *ri* :robot :name)))
  (:angle-vector (&rest args)
		 (send self :send-lisp `(send *ri* :angle-vector ,@args)))
  (:read-angle-vector () (send self :send-lisp '(send *ri* :read-angle-vector)))
  )

(defun rcb4-ros-init ()
  (ros::roseus "rcb4_ros_interface" :anonymous nil)
  (setq *ri* (instance rcb4-ros-interface :init))
  (setq *robot* (kxr-make-robot (send *ri* :robot-name)))
  (objects (list *robot*))
  )
(format t ";; (rcb4-ros-init)~%")
