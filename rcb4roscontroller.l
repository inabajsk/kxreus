#!/usr/bin/env roseus
;;;
;;;	ROS Controller for RCB4 Robots 2023.3.12
;;;
(require :rcb4robots)
;;(load "additional-settings.l")

(ros::load-ros-manifest "roseus")
(ros::load-ros-manifest "std_msgs")
(ros::load-ros-manifest "kxr_rosserial_msgs")

(defun joint-callback (msg)
  (let ((names (send msg :name))
	;;(nlist (send *ri* :robot :joint-access-names))
	(nlist (send *ri* :robot :joint-list :name))
	(av (send msg :position)))
    (dotimes (i (length names))
      (if (member (elt names i) nlist :test #'string-equal)
	  (send *ri* :robot
		(intern (elt names i) *keyword-package*)
		:joint-angle (rad2deg (elt av i)))))
    (send *ri* :angle-vector (send *ri* :robot :angle-vector) 10)
    )
  )

(defun joint-publish ()
  (let* ((transformation nil)
	 (board-crds)
	 (pv (send *ri* :angle-vector))
	 (av (send *ri* :read-angle-vector))
	 (ev (send *ri* :read-torque-vector))
	 )
    (when (ros::ok)
      (send *ri* :robot :angle-vector av);; to support robot model which has gsensor in link that is not base_link
      (send *ri* :real-orientation)
      (when (substringp "euscollada-robot" (string-downcase (send (send *ri* :robot :super) :name)))
	(setq c (make-coords :rot (send *ri* :robot :worldrot)))
	(send *tfbr* :send-transform c "map" "base_link" (ros::time-now)))
      (when (substringp "robot-model" (string-downcase (send (send *ri* :robot :super) :name)))
      	(setq c (make-coords :rot (send *ri* :robot :worldrot)))
      	(send *tfbr* :send-transform c "map" "torso" (ros::time-now)))
      (send *joint-msg* :name (send *ri* :robot :joint-list :name))
      (send *joint-msg* :position (scale (/ pi 180) av))
      (when pv
	(send *joint-msg* :velocity (scale (/ pi 180) (v- av pv)))
	)
      (send *joint-msg* :effort ev)
      ;;)
      (send *joint-msg* :header :stamp (ros::time-now))
      (ros::publish "joint_states" *joint-msg*)
      (ros::sleep))
    )
  )

(defun rcb4-server-callback (req)
  (let ((m (send req :command)))
    (format *error-output* "Rec rcb4 [~A]~%" (coerce m cons))
    (send (*ri* . com-port) :write-data m)
    (setq *ri-ret* (send (*ri* . com-port) :read-data))
    (format *error-output* "Returning [~A]~%" (coerce *ri-ret* cons))
    (send *rcb4-res* :response *ri-ret*)
    *rcb4-res*))

(defun lisp-server-callback (req)
  (let ((m (send req :command))
	(s (make-string-output-stream 128))
	(*print-object* t)
	(*print-circle* t)
	(*print-structure* t))
    (format *error-output* "Rec lisp [~A]~%" (coerce m cons))
    (print (eval (read-from-string m)) s)
    (setq *lisp-ret* (get-output-stream-string s))
    (format *error-output* "Returning [~A]~%" *lisp-ret*)
    (send *lisp-res* :response *lisp-ret*)
    *lisp-res*)
  )

(defun get-robot-name () (unix::getenv "ROBOT_NAME"))
(defun get-publish-state () (unix::getenv "PUBLISH_STATE"));;publish // publish_sensor

(defun demo-init (&optional (robo-name (get-robot-name)) (publish-state (get-publish-state)))
  (let ((sensor nil)
	(pcexec nil))
    (format t "publish-state:~A~%" publish-state)
    (setq sensor (substringp "sensor" publish-state))
    (setq pcexec (substringp "pcexec" publish-state))
    (setq *ri* (make-kxr-robot-interface robo-name :model t))
    (cond (pcexec
	   (format t ";; com-open on pc~%")
	   (send *ri* :com-init)
	   )
	  ((probe-file "/dev/ttyAML1")
	   (format t ";; before :com-open :devname ttyAML1~%")
	   (send *ri* :com-open :devname "ttyAML1")
	   (format t ";; :wait-ack 2000 loop~%")
	   (send *ri* :wait-ack 2000 t)
	   (format t ";; exit :wait-ack loop~%")
	   (send *ri* :com-init :devname "ttyAML1")
	   (format t ";; after :com-init :devname ttyAML1~%")
	   )
	  (t (send *ri* :com-init))
	  )

    (ros::roseus "rcb4roscontroller" :anonymous nil);;
    (ros::advertise "joint_states" sensor_msgs::jointstate 1);;
    (ros::subscribe "puppet_joint_states" sensor_msgs::jointstate #'joint-callback);;
    (ros::advertise-service "lisp_command" kxr_rosserial_msgs::LispCommand #'lisp-server-callback);;
    (ros::advertise-service "rcb4_command" kxr_rosserial_msgs::Rcb4Command #'rcb4-server-callback);;
    (setq *rcb4-res* (instance kxr_rosserial_msgs::Rcb4CommandResponse :init));;
    (setq *lisp-res* (instance kxr_rosserial_msgs::LispCommandResponse :init));;
    (setq *tfbr* (instance ros::transform-broadcaster :init));;
    ;; temporary
    (setq *magbr* (instance ros::transform-broadcaster :init));;tukaimawasi
    ;; end temporary
    (setq *joint-msg* (instance sensor_msgs::jointstate :init));;
    (unix::sleep 2)
    )
  )

(defun demo-loop (&key (run-manual nil) (print nil) &optional (publish-state (get-publish-state)))
  (let ((sensor nil)
	(pcexec nil))
    (format t "publish-state:~A~%" publish-state)
    (setq sensor (substringp "sensor" publish-state))
    (setq pcexec (substringp "pcexec" publish-state))
    (ros::rate 100)
    (format t "start joint-publish loop~%")
    (format t "publish-state:~A~%" (get-publish-state))
    (cond (pcexec
	   (do-until-key
	    (ros::spin-once)
	    (joint-publish)
	    )
	   )
	  (t
	   (while t
	     (ros::spin-once)
	     (joint-publish)
	     )))))


(demo-init)
(demo-loop)
