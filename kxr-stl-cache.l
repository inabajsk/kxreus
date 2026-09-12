;;;
;;; disk cache for stl2eus, keyed by the full call (filename + args).
;;;
;;; stl2eus (jskeus core, irtstl.l) parses an STL triangle mesh in two
;;; conceptual steps: (1) read the file's raw triangles (fast: ~0.5s for
;;; ~11000 triangles, measured), then (2) deduplicate vertices and build
;;; the shared edge structure via hash-table lookups (SLOW: ~46-90s for
;;; the same ~11000 triangles, measured -- this step dominates, not the
;;; file I/O). For STL files with many thousands of faces -- e.g. the
;;; M5Stickhead 3eye head parts used by m5stickhead-mount-bodyset (base
;;; ~11300 faces, front ~4500, cover ~3800) -- this made :setup-head the
;;; single largest phase of a robot's construction (~130s out of ~190s
;;; for kxrl2makabelcw).
;;;
;;; A first attempt at caching the parsed body via the generic
;;; dump-structure/read round-trip (the same technique kxrbody.l's
;;; *kxr-body-functions* file-memoization uses for CSG-built parts)
;;; crashed/hung on read-back for these STL-derived meshes -- CSG parts
;;; have at most a few hundred faces, but a raw STL import has orders
;;; of magnitude more, and the deeply cross-referenced face/edge object
;;; graph (edges reference faces, faces reference edges, vertices are
;;; shared by eq identity) does not round-trip through the generic
;;; mechanism at that scale.
;;;
;;; This file instead serializes only the plain numeric data needed to
;;; rebuild the object graph explicitly (vertex positions, per-face
;;; vertex/edge index triples + normal/distance, per-edge vertex/face
;;; indices + flags -- angle is NOT stored since stl2eus itself never
;;; computes it, :set-angle is never called on these edges), using the
;;; same efficient "make-matrix + fvector-replace" / #i(...) literal
;;; idiom already proven fast and safe by eus2native-collada.l's
;;; model-file generation. Reconstruction rebuilds vertices, then faces
;;; (with their own throwaway per-triangle edges, same as stl2eus
;;; itself), then the shared/deduplicated edges, then overwrites each
;;; face's :edges slot with its correct shared edges in original order
;;; -- mirroring exactly what stl2eus's own dedup pass does, just from
;;; cached indices instead of a fresh hash-table search.
;;;
;;; Verified byte-for-byte-equivalent-in-outcome against plain stl2eus
;;; on both a 3830-face and an 11322-face real STL (this repo's
;;; M5Stickhead 3eye head parts): all face normals/distances, all edge
;;; pvert/nvert/pface/nface, and the bounding box match exactly, and
;;; gl::make-glvertices-from-faceset runs cleanly on the result.
;;; Measured speedup on the 11322-face file: ~98s (stl2eus) -> ~9s
;;; (cache read), after a one-time ~8s cache-write cost.
;;;
;;; Known harmless quirk: reconstructing the final body via
;;; (instance body :init :faces ... :edges ... :vertices ...
;;; :primitive (list :cube 100 100 100)) -- the same :primitive value
;;; stl2eus itself always passes, though no :init method anywhere in
;;; geo/*.l actually consumes that key -- prints one
;;; "vector dimension mismatch" error per cached file loaded. This
;;; comes from inside a compiled (non-Lisp-visible) frame, so its exact
;;; cause wasn't pinned down; it does not affect the returned body in
;;; any way we could detect (all correctness checks above still pass
;;; with it printing), and dropping :primitive avoids it but trades it
;;; for a different, less-well-understood "float vector expected"
;;; error instead -- so :primitive is kept and this message is left as
;;; a cosmetic wart rather than chased further.
;;;

(require :utils)

(defun kxr-stl-cache-dump-int-vector (v strm)
  (format strm "#i(")
  (dotimes (i (length v)) (format strm " ~D" (elt v i)))
  (format strm ")"))

(defun kxr-stl-cache-dump-float-vector (v strm)
  (format strm "#f(")
  (dotimes (i (length v)) (format strm " ~16,9E" (float (elt v i))))
  (format strm ")"))

(defun kxr-stl-cache-dump-float-matrix (mat strm)
  (format strm "(let ((mat (make-matrix ~D ~D))) (fvector-replace (array-entity mat) "
          (array-dimension mat 0) (array-dimension mat 1))
  (kxr-stl-cache-dump-float-vector (array-entity mat) strm)
  (format strm ") mat)"))

;; bod: a body/faceset as returned by stl2eus (:return-type :faceset or :body)
(defun kxr-stl-cache-write (bod cache-file)
  (let* ((verts (send bod :vertices))
         (faces (send bod :faces))
         (edges (send bod :edges))
         (nv (length verts)) (nf (length faces)) (ne (length edges))
         (vindex (make-hash-table :test #'eq))
         (findex (make-hash-table :test #'eq))
         (eindex (make-hash-table :test #'eq))
         (vmat (make-matrix nv 3))
         (fv0 (instantiate integer-vector nf)) (fv1 (instantiate integer-vector nf))
         (fv2 (instantiate integer-vector nf))
         (fe0 (instantiate integer-vector nf)) (fe1 (instantiate integer-vector nf))
         (fe2 (instantiate integer-vector nf))
         (fnormal (make-matrix nf 3)) (fdist (instantiate float-vector nf))
         (epv (instantiate integer-vector ne)) (env (instantiate integer-vector ne))
         (epf (instantiate integer-vector ne)) (enf (instantiate integer-vector ne))
         (eflags (instantiate integer-vector ne))
         (i 0))
    (dolist (v verts) (sethash v vindex i) (set-matrix-row vmat i v) (incf i))
    (setq i 0) (dolist (f faces) (sethash f findex i) (incf i))
    (setq i 0) (dolist (e edges) (sethash e eindex i) (incf i))
    (setq i 0)
    (dolist (f faces)
      (let ((vs (send f :vertices)) (es (send f :edges)))
        (setf (elt fv0 i) (gethash (elt vs 0) vindex))
        (setf (elt fv1 i) (gethash (elt vs 1) vindex))
        (setf (elt fv2 i) (gethash (elt vs 2) vindex))
        (setf (elt fe0 i) (gethash (elt es 0) eindex))
        (setf (elt fe1 i) (gethash (elt es 1) eindex))
        (setf (elt fe2 i) (gethash (elt es 2) eindex))
        (set-matrix-row fnormal i (f . normal))
        (setf (elt fdist i) (f . distance)))
      (incf i))
    (setq i 0)
    (dolist (e edges)
      (setf (elt epv i) (gethash (e . pvert) vindex))
      (setf (elt env i) (gethash (e . nvert) vindex))
      (setf (elt epf i) (if (e . pface) (gethash (e . pface) findex) -1))
      (setf (elt enf i) (if (e . nface) (gethash (e . nface) findex) -1))
      (setf (elt eflags i) (e . flags))
      (incf i))
    (let ((tmp (format nil "~A.tmp~A" cache-file (unix::getpid))))
      (with-open-file
          (strm tmp :direction :output :if-exists :supersede)
        (format strm "(setq *kxr-stl-cache-tmp* (list~%")
        (kxr-stl-cache-dump-float-matrix vmat strm) (format strm "~%")
        (kxr-stl-cache-dump-int-vector fv0 strm) (format strm "~%")
        (kxr-stl-cache-dump-int-vector fv1 strm) (format strm "~%")
        (kxr-stl-cache-dump-int-vector fv2 strm) (format strm "~%")
        (kxr-stl-cache-dump-int-vector fe0 strm) (format strm "~%")
        (kxr-stl-cache-dump-int-vector fe1 strm) (format strm "~%")
        (kxr-stl-cache-dump-int-vector fe2 strm) (format strm "~%")
        (kxr-stl-cache-dump-float-matrix fnormal strm) (format strm "~%")
        (kxr-stl-cache-dump-float-vector fdist strm) (format strm "~%")
        (kxr-stl-cache-dump-int-vector epv strm) (format strm "~%")
        (kxr-stl-cache-dump-int-vector env strm) (format strm "~%")
        (kxr-stl-cache-dump-int-vector epf strm) (format strm "~%")
        (kxr-stl-cache-dump-int-vector enf strm) (format strm "~%")
        (kxr-stl-cache-dump-int-vector eflags strm) (format strm "~%")
        (format strm "~S" (if (derivedp bod body) :body :faceset)) (format strm "~%")
        (format strm "))~%"))
      ;; atomic: readers only ever see a complete old or new file, never
      ;; a half-written one -- needed for parallel robot generation.
      (unix:rename tmp cache-file))))

(defun kxr-stl-cache-read (cache-file)
  (load cache-file)
  (let* ((data *kxr-stl-cache-tmp*)
         (vmat (nth 0 data))
         (fv0 (nth 1 data)) (fv1 (nth 2 data)) (fv2 (nth 3 data))
         (fe0 (nth 4 data)) (fe1 (nth 5 data)) (fe2 (nth 6 data))
         (fnormal (nth 7 data)) (fdist (nth 8 data))
         (epv (nth 9 data)) (env (nth 10 data))
         (epf (nth 11 data)) (enf (nth 12 data))
         (eflags (nth 13 data))
         (bod-class (or (nth 14 data) :faceset))
         (nv (array-dimension vmat 0)) (nf (length fdist)) (ne (length eflags))
         (verts (instantiate vector nv))
         (facevec (instantiate vector nf))
         (edgevec (instantiate vector ne))
         bod)
    (setq *kxr-stl-cache-tmp* nil)
    (dotimes (i nv) (setf (elt verts i) (matrix-row vmat i)))
    (dotimes (i nf)
      (setf (elt facevec i)
            (instance face :init
                      :vertices (list (elt verts (elt fv0 i))
                                       (elt verts (elt fv1 i))
                                       (elt verts (elt fv2 i)))
                      :normal (matrix-row fnormal i)
                      :distance (elt fdist i))))
    (dotimes (i ne)
      (let ((pf (elt epf i)) (nf2 (elt enf i)))
        (setf (elt edgevec i)
              (instance edge :init
                        :pvertex (elt verts (elt epv i))
                        :nvertex (elt verts (elt env i))
                        :pface (if (>= pf 0) (elt facevec pf))
                        :nface (if (>= nf2 0) (elt facevec nf2))
                        :flags (elt eflags i)))))
    (dotimes (i nf)
      (let ((fc (elt facevec i)))
        (setq (fc . edges)
              (list (elt edgevec (elt fe0 i))
                    (elt edgevec (elt fe1 i))
                    (elt edgevec (elt fe2 i))))))
    (setq bod (instance (if (eq bod-class :body) body faceset) :init
                         :faces (coerce facevec cons)
                         :edges (coerce edgevec cons)
                         :vertices (coerce verts cons)
                         :primitive (list :cube 100 100 100)))
    ;; replicate stl2eus's default (use-normal nil) per-vertex normal
    ;; hashtable, used by gl::make-glvertices-from-faceset for smooth
    ;; shading -- see the "(unless use-normal ...)" block in stl2eus.
    (let ((ht-norms (make-hash-table :test #'equal)))
      (dolist (f (send bod :faces))
        (let ((vs (cdr (send f :vertices))))
          (dolist (v vs) (sethash (list v vs) ht-norms (f . model-normal)))))
      (setf (get bod :gl-normal) ht-norms))
    bod))

(defun kxr-stl2eus-cached (fname &rest args &key (color #f(0.8 0.8 0.8)) (name "stlobject") &allow-other-keys)
  (let* ((dir (rcb4eus-mkdir "glbodies/stlcache"))
         (key (sxhash (format nil "~S" (cons fname args))))
         (cache-file (format nil "~A/stl2eus-~A.l" dir key))
         bod)
    (cond
      ((probe-file cache-file)
       (setq bod (kxr-stl-cache-read cache-file)))
      (t (setq bod (apply #'stl2eus fname args))
         (kxr-stl-cache-write bod cache-file)))
    (send bod :name (format nil "~A" name))
    (setf (get bod :face-color) color)
    bod))

(provide :kxr-stl-cache)
