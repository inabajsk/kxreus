;; common setup for reading kxreus (https://github.com/inabajsk/kxreus, ~/kxreus via ~/.eusrc)
;; without writing into it. Loaded by export-kxr.l and export-motions.l (after irtload.l).
;; use the kxreus sources (not the Darwin/obj .so compiled elsewhere)
(defvar *eusview-dir* (or (unix:getenv "EUSVIEW_DIR") (format nil "~A/eusview" (if (boundp '*rcb4eus-dir*) *rcb4eus-dir* (format nil "~A/kxreus" (unix:getenv "HOME"))))))  ;; set by run-eus.sh
(setq *load-path* (remove-if #'(lambda (p) (substringp "/Darwin/" p)) *load-path*))
(unless (and (find-package "TINY-XML") (fboundp (intern "PARSE" "TINY-XML")))
  (load (format nil "~A/tiny-xml.l" *rcb4eus-dir*)))
;; never write into ~/kxreus: kxreus caches part shapes in (rcb4eus-mkdir "glbodies")
;; (kxrbody.l: *-func.bod, *.gv) and "glbodies/stlcache" (kxr-stl-cache.l: stl2eus meshes) when the
;; files are missing. rcb4eus-mkdir is redefined to eusview/cache/... (kxreus is only read).
(require :utils)
(defun rcb4eus-mkdir (dirname)
  ;; dirname: "glbodies" (*.bod, *.gv) or "glbodies/stlcache" (kxr-stl-cache.l: stl2eus results)
  (let ((d (format nil "~A/cache" *eusview-dir*)))
    (unless (probe-file d) (unix::mkdir d))
    (dolist (p (eusview-split-path dirname))
      (setq d (format nil "~A/~A" d p))
      (unless (probe-file d) (unix::mkdir d)))
    d))
(defun eusview-split-path (s)
  (let ((ret nil) (cur nil))
    (dolist (c (append (coerce s cons) (list #\/)))
      (if (= c #\/)
          (progn (if cur (push (coerce (nreverse cur) string) ret)) (setq cur nil))
        (push c cur)))
    (nreverse ret)))
;; the cache starts empty (made by the current kxreus). EUSVIEW_LINK_KXREUS_CACHE=1 links the
;; files of ~/kxreus/glbodies (read only; they may be older than the kxreus sources).
(when (unix:getenv "EUSVIEW_LINK_KXREUS_CACHE")
  (rcb4eus-mkdir "glbodies")
  (unix:system (format nil "cd ~A/cache/glbodies && for f in ~A/glbodies/*; do [ -e \"$(basename $f)\" ] || ln -s \"$f\" .; done" *eusview-dir* *rcb4eus-dir*)))
(require :rcb4robots)
;; kxreus utils.l triangulates faces (glvertices *.gv, pqp models) with GLU callbacks gl::eus_tess_*
;; (EusLisp opengl/src/util.c of inabajsk/EusLisp glu-tess-collector, built into ~/jskeus).
;; Without them (other jskeus builds) or with EUSVIEW_NO_GLU_TESS=1, kxreus-glu-triangulate-face
;; returns nil -> kxreus' own fallback geometry::face-to-triangle-aux (slower, same shapes).
(cond
 ((and (fboundp 'gl::eus_tess_begin_cb) (null (unix:getenv "EUSVIEW_NO_GLU_TESS")))
  (format t ";; GLU tessellation (gl::eus_tess_*) is used~%"))
 (t
  (format t ";; no GLU tessellation: kxreus-glu-triangulate-face -> nil (face-to-triangle-aux)~%")
  (defun kxreus-glu-triangulate-face (f) nil)))
;; EUSVIEW_STL_SUBST="missing.STL=other.STL ..." (opt-in): when kxreus asks stl2eus (jskeus
;; irtstl.l) for an STL file that is not in ~/kxreus/stls, use another file of the same directory
;; (e.g. M5Stickhead_3eye_mount_rev6.STL of the :m3deye head with :3eye-rev 6 is missing).
(defun eusview-stl-substitutes ()
  (let ((s (unix:getenv "EUSVIEW_STL_SUBST")) (ret nil))
    (when s
      (dolist (w (eusview-split-path (substitute #\/ #\space s)))
        (let ((k (position #\= w))) (if k (push (cons (subseq w 0 k) (subseq w (1+ k))) ret)))))
    ret))
(when (and (eusview-stl-substitutes) (fboundp 'stl2eus))
  (setf (symbol-function 'eusview-orig-stl2eus) (symbol-function 'stl2eus))
  (defun stl2eus (fname &rest args)
    (let* ((full (if (or (probe-file fname) (= (elt fname 0) #\/)) fname
                   (format nil "~A/~A" *rcb4eus-dir* fname)))
           (k (let ((i nil)) (dotimes (j (length full)) (if (= (elt full j) #\/) (setq i j))) i))
           (base (subseq full (1+ k)))
           (sub (cdr (assoc base (eusview-stl-substitutes) :test #'string=))))
      (when (and sub (not (probe-file full)))
        (format t ";; stl2eus: ~A is missing, use ~A instead (EUSVIEW_STL_SUBST)~%" base sub)
        (setq fname (concatenate string (subseq full 0 (1+ k)) sub)))
      (apply #'eusview-orig-stl2eus fname args))))
;; robots/<group>/<name>.json: "khr" for the KHR names, else "kxr"
(defun eusview-kxr-group (name)
  (if (and (>= (length name) 3) (string= (subseq name 0 3) "khr")) "khr" "kxr"))
(defun eusview-kxr-json (name)
  (let ((d (format nil "~A~A" *out* (eusview-kxr-group name))))
    (unless (probe-file d) (unix::mkdir d))
    (format nil "~A/~A.json" d name)))
