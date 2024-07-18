# kxreus

How to install:
1) install ROS noetic or melodic
2) sudo apt get install ros-noetic-roseus or ros-melodic-roseus
3) sudo reboot
4) cd kxreus
5) make libs
    ;; setup usb drivers
6) make
7) make gen
    ;; generate typical robot models into kxreus/models directory
8) connect USB dual adapter to PC
9) lsusb ;; to show names of USB devices. check the name Kondo Kagaku...

How to use:
1) cd kxreus
2) roseus semi2024
3) (semi-init)  ;; demo program new UI setup
4) Drag the green viewer of robot kxrl2l2a6h2m to show.
    ;; check new mouse operation(:new-ui to *irtviewer*)
    ;;  left-button: changes view angle.
    ;;  Shift + left-button: slide view
    ;;  Ctrl + left-button: scale view
5) (pf semi-init)
6) (send *robot* :walk-motion :x 200 :y 200 :angle 10)
    ;; walk forward ported from irteus/demo/walk-motion.l
7) (load "kxranimate.l")
8) (objects-kxr-robots)
    ;; show typical robot models in a viewer.

<img src="./images/all-robots.png" height=400px>

How to move real robot ex. kxrl2g:
1) connect USB dual adapter with serial LED from PC to a robot
2) roseus semi2024
3) (make-kxr-robot "kxrl2g") ;; generates *robot*, *ri*, two viewers
     ;; other robots "kxrl4t", "kxrl4d", "kxrl6" etc. in kxreus/models
     ;; green viewer for *robot*, purple viewer for *ri*
4) (send *ri* :timer-on) ;; call :com-init, and start itimer to update *ri* viewer
5) (send *ri* :free :larm :rarm :head) ;; servo off uppder body joints
     ;; you can move upper body of kxrl2g. 
     ;; (send *ri* :free) to servo off all the joints
6) (setq a (send *ri* :read-angle-vector)) ;; store current pose to variable a
7) (send *ri* :hold) ;; servo on all joints
8) (send *ri* :angle-vector a 2000) ;; move to a posture in 2000[msec]
9) (send *ri* :call-motion 22) ;; call No. 22 motion in 0-119 motion table in ROM
10) (send *ri* :timer-off) ;; stop continuous viewer update
11) (send *ri* :draw-project-file) ;; show animation of motion-table
12) (reset) ;; when get error in roseus
13) Ctrl-C ;; in case hang up in :timer-on continuous viewer update
14) (exit) ;; exit from roseus

 ;; details are in kxr-document.txt

 ;; Rubik cube demo
  https://www.youtube.com/watch?v=CVYYmKJGDNQ
  described in https://github.com/fkanehiro/kxr_cube_solver
  the robot is named kxrl2l2a6h2m in rcb4robotconfig.l
  It has 2 2DOF legs, 6DOF arm, 2DOF head, magnet modular robot.

Robot-model generation:
  No requirements of real robot connections.
1) roseus semi2024
2) (make-kxr-robot "kxrl2l6a6h2m" :generate t)
    ;; when already models/kxrl2l6a6h2m.l exists, :generate key generates again.
3) (make-kxr-robot "kxrkamakiri")
    ;; when no models/kxrkamakiri.l, generates it.
4) (make-kxr-robot "kxrkamakiri" :model nil)
    ;; generates *robot* as an instance of kxr-robot model not models/kxrkamakiri.l
    ;; that is an instance of euscollada-robot model

    ;; you can find the robot config of kxr-robot models in a global variable
    ;; *kxr-body-config-alist* in rcb4robotconfig.l.
    ;; Each config has robot-name, model-param, servo-id and joint-name params.
    ;; You can specify a robot name in this alist to generate model.
    ;; model-param specifications are :setup-xxxx arguments in kxrmodels.l.
    ;; When you want to generate new robot, you define it with a body
    ;; in kxrbody.l, a bodyset in kxrbodyset.l, a robot-link in kxrlinks.l,
    ;; extends the definition of :setup-xxxx in kxreus.


Other robot model generation software:
    https://github.com/agent-system/robot_assembler


Rcb4lisp sample:
   Connect real kxrl2g robot to PC.
1) roseus semi2024.l
2) (make-kxr-robot "kxrl2g")
3) (send *ri* :com-init)
4) (semi-comp-jswing) ;; define comp-jswing for :head-neck-y swing motion
5) (comp-jswing) ;; execute comp-jswing :head-neck-y joint swing
6) (semi-comp-remocon) ;; define a motion for a robot with 2DOF neck joints
7) (comp-remocon) ;; execute the motion defined by semi-comp-remocon
   ;; remocon <shift-3 (:r-shift-u)> button for :head-neck-y joint
   ;; remocon <shift-1 (:l-shift-u)> button for :head-neck-p joint
   ;; remocon <r-forward> button to exit from comp-remocon motion
8) (semi-comp-squat) ;; for kxrl2g with 5DOF leg example defined
9) (comp-squat) ;; execute comp-squat motion defined by semi-comp-squat
      ;; remocon <shift-3> button to execute squat motion
      ;; remocon <r-forward> button to exit this motion loop
10) (semi-comp-iksquat) ;; for kxrl2g inverse-kinematics squat motion
11) (comp-iksquat) ;; execute the IK squat motion defined by semi-comp-iksquat
      ;; remocon <shift-3> button to execute squat motion
      ;; remocon <r-forward> button to exit this motion loop


Roseus basics:
   Roseus is an extention of a subset of CommonLisp: Euslisp
   https://github.com/euslisp/euslisp.
   UTokyo JSK provides extentions jskeus
   https://github.com/euslisp/jskeus
   with robot programming,
   and roseus with ROS extentions.
   https://github.com/jsk-ros-pkg/jsk_roseus
   euslisp < jskeus < roseus.
   see slide for euslisp:
      https://www.slideshare.net/slideshow/euslisp/53487698

1) roseus
2) (load "irteus/demo/demo.l") ;; show sample programs
3) (particle)   ;; interval timer sample used in :timer-on
4) (hand-grasp) ;; Object distances with :inverse-kinematics-loop
5) (hanoi-arm)  ;; Hanoi tower task :inverse-kinematics
6) (dual-arm-ik) ;; Bloom manipulation with :inverse-kinematics
7) (crank-motion) ;; Humanoid crank rotation with :fullbody-inverse-kinematics
8) (head-look-at-ik) ;; Humanoid head motion with :fullbody-inverse-kinematics
9) (walk-motion-for-sample-robot) ;; walk motion sample robot
10) (walk-motion-for-robots) ;; walk motion for H7, H6, Kaz3, Darwin
