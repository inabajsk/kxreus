# kxreus

How to install:
1) install ROS noetic or melodic
2) sudo apt get install ros-noetic-roseus or ros-melodic-roseus
3) sudo reboot
4) cd kxreus
5) make libs
6) make
7) connect USB dual adapter to PC
8) lsusb ;; to show names of USB devices. check the name Kondo Kagaku...

How to use:
1) connect USB dual adapter with serial LED from PC to a robot (kxrl2g)
2) cd kxreus
3) roseus rcb4robots
4) (make-kxr-robot "kxrl2g") ;; generates *robot*, *ri*, two viewers
     ;; other robots "kxrl4t", "kxrl4d", "kxrl6" etc. in kxreus/models
     ;; green viewer for *robot*, purple viewer for *ri*
5) (send *ri* :timer-on) ;; call :com-init, and start itimer to update *ri* viewer
6) (send *ri* :free :larm :rarm :head) ;; servo off uppder body joints
     ;; you can move upper body of kxrl2g. 
     ;; (send *ri* :free) to servo off all the joints
7) (setq a (send *ri* :read-angle-vector)) ;; store current pose to variable a
8) (send *ri* :hold) ;; servo on all joints
9) (send *ri* :angle-vector a 2000) ;; move to a posture in 2000[msec]
10) (send *ri* :call-motion 22) ;; call No. 22 motion in 0-119 motion table in ROM
11) (send *ri* :timer-off) ;; stop continuous viewer update
12) (send *ri* :draw-project-file) ;; show animation of motion-table
13) (reset) ;; when get error in roseus
14) Ctrl-C ;; in case hang up in :timer-on continuous viewer update
15) (exit) ;; exit from roseus

 ;; details are in kxr-document.txt

Rcb4lisp sample:
1) roseus semi2024.l
2) (semi-comp-jswing) ;; define comp-jswing for :head-neck-y swing motion
3) (comp-jswing) ;; execute comp-jswing :head-neck-y joint swing
4) (semi-comp-remocon) ;; define a motion for a robot with 2DOF neck joints
5) (comp-remocon) ;; execute the motion defined by semi-comp-remocon
   ;; remocon <shift-3 (:r-shift-u)> button for :head-neck-y joint
   ;; remocon <shift-1 (:l-shift-u)> button for :head-neck-p joint
   ;; remocon <r-forward> button to exit from comp-remocon motion
6) (semi-comp-squat) ;; for kxrl2g with 5DOF leg example defined
7) (comp-squat) ;; execute comp-squat motion defined by semi-comp-squat
      ;; remocon <shift-3> button to execute squat motion
      ;; remocon <r-forward> button to exit this motion loop
8) (semi-comp-iksquat) ;; for kxrl2g inverse-kinematics squat motion
9) (comp-iksquat) ;; execute the IK squat motion defined by semi-comp-iksquat
      ;; remocon <shift-3> button to execute squat motion
      ;; remocon <r-forward> button to exit this motion loop

Real robot example:
  Rubik cube demo
  https://www.youtube.com/watch?v=CVYYmKJGDNQ
  described in https://github.com/fkanehiro/kxr_cube_solver
  the robot is named kxrl2l2a6h2m in rcb4robotconfig.l
  It has 2 2DOF legs, 6DOF arm, 2DOF head, magnet modular robot.

Robot-model generation:
1) roseus semi2024.l
2) (make-kxr-robot "kxrl2l2a6h2m") ;; when if no kxreus/models/kxrl2l2a6h2m.l
    ;; it generates the model file through installing several ros packages
3) (make-kxr-robot "kxrl2l2a6h2m" :generate t) ;; overwrite models/kxrl2l2a6h2m.l
    ;; you can find the robot config of kxrl2l2a6h2m in a global variable
    ;; *kxr-body-config-alist* in rcb4robotconfig.l.
    ;; Each config has robot-name, model-param, servo-id and joint-name params.
    ;; You can specify a robot name in this alist to generate model.
    ;; model-param specifications are :setup-xxxx arguments in kxrmodels.l.
    ;; When you want to generate new robot, you define it with a body
    ;; in kxrbody.l, a bodyset in kxrbodyset.l, a robot-link in kxrlinks.l,
    ;; extends the definition of :setup-xxxx in kxreus.
4) (make-kxr-robot "kxrl2l6a6h2m") ;; generate 6DOF biped, 6DOF arms, 2DOF head
5) (send *robot* :walk-motion) ;; walk forward ported from irteus/demo/walk-motion.l
6) (send *robot* :walk-motion2) ;; another walk sample ported from irteus/demo/walk-motion.l


Other robot model generation software:
    https://github.com/agent-system/robot_assembler

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
