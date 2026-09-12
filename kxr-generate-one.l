;;;
;;; kxr-generate-one.l
;;;
;;; Small driver used by generate-parallel.sh to generate exactly one
;;; robot's models/<name>.l per process (or to just list robot names,
;;; for the shell wrapper to fan work out from), so many of these can
;;; run as separate OS processes in parallel -- each robot's
;;; construction is independent and only ever writes its own
;;; models/<name>.l, so this is safe to parallelize as long as the
;;; shared glbodies/ caches are written atomically (see
;;; rcb4eus-dump-structure-atomically in utils.l and kxr-stl-cache.l's
;;; own atomic write), which they are.
;;;
;;; Usage (see generate-parallel.sh):
;;;   ROBOT_NAME=kxrl6 irteusgl kxr-generate-one.l
;;;   KXR_LIST_NAMES=sample irteusgl kxr-generate-one.l   ;; prints *kxr-all-robot-names*
;;;   KXR_LIST_NAMES=all irteusgl kxr-generate-one.l      ;; prints all rcb4robotconfig.l names
;;;

(setq *rcb4eus-dir* (or (unix::getenv "RCB4EUS_DIR") (format nil "~A" (pwd))))
(load (format nil "~A/rcb4robots.l" *rcb4eus-dir*))
(require :kxranimate)

(let ((list-mode (unix::getenv "KXR_LIST_NAMES"))
      (name (unix::getenv "ROBOT_NAME")))
  (cond
    (list-mode
     (dolist (n (if (equal list-mode "all") (kxr-all-string-names) *kxr-all-robot-names*))
       (format t "~A~%" n)))
    (name
     (format t ";; kxr-generate-one: ~A~%" name)
     (kxr-make-robot name :model (if *ros-distro-null* nil 0) :viewer nil))
    (t
     (format t "usage: set ROBOT_NAME=<name>, or KXR_LIST_NAMES=sample|all~%"))))
(exit)
