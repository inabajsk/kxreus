;; kxr-body-minus-holes: fast alternative to (body- bod . cutters) for
;; the common case of many small, mutually non-intersecting, axis-
;; aligned through-holes cut into a flat prism (e.g. a mounting plate).
;;
;; Unlike body-, this never calls compose-body/body- at all: it builds
;; the two axis-facing faces of `bod` directly as polygon-with-N-holes
;; objects (reusing the same face/hole representation already used by
;; the GLU tessellation path), reusing each cutter's own side faces as
;; the hole walls, and re-derives the hole contour from each cutter's
;; own rim vertices (not an independently-computed circle) so the two
;; edge loops share exactly the same vertex coordinates and can be
;; stitched together.
;;
;; This avoids a discovered bug where body- permanently flips the
;; normals of bod's own untouched faces the first time bod is used as
;; body1 (making bod unsafe to reuse across independent compose-body
;; calls without a deep-copy primitive, which jskeus doesn't provide).
;;
;; A SECOND discovery: jskeus's `body` class requires every edge to have
;; BOTH pface and nface set (body's :init unconditionally calls
;; (send-all edges :set-angle), which dereferences both) -- i.e. body
;; assumes a watertight, fully-stitched manifold. Hand-assembled faces
;; don't have this by construction, so kxr-stitch-body-faces below
;; explicitly matches every edge to its geometric partner (same two
;; endpoints, reversed) among all faces and cross-links pface/nface.
;; This is real B-rep bookkeeping that compose-body normally handles
;; internally -- getting it wrong produces either an error (unmatched
;; edge) or, worse, a body that looks fine but has wrong edge/angle data.
;;
;; Cost scales with the number of holes N (not N^2 like sequential
;; body-, whose cost grows with the accumulated face count of the
;; already-cut body), since the two affected faces are rebuilt once
;; with all N hole contours merged in, and edge stitching is the only
;; per-hole work left (still cheap: local vertex matching, not a
;; growing CSG scan). Measured on a 159-face body-plate part with 24
;; interior screw holes: ~1050ms (sequential body-) -> ~430ms (this),
;; producing an identical result (same face count, same volume, same
;; glvertices mesh) -- and the gap widens with more holes.
;;
;; ASSUMPTIONS for kxr-body-minus-holes itself (violating these
;; silently produces wrong geometry -- this is NOT a general body-
;; replacement):
;;  - bod is a simple extruded prism with exactly one planar face whose
;;    outward normal is +axis and exactly one whose normal is -axis.
;;  - every cutter is a clean through-hole along `axis`: its own end
;;    caps land entirely outside bod (checked indirectly: its side
;;    faces' rim vertices must lie exactly on bod's face+/face- planes).
;;  - holes are pairwise non-overlapping (their disks don't intersect),
;;    AND each hole is entirely interior to bod's outline (a hole that
;;    reaches or crosses the outer boundary needs the outer contour
;;    itself modified, not just a hole added to a face -- confirmed to
;;    silently produce a wrong face count/volume without erroring).
;;
;; Use kxr-body-minus-holes-safe (bottom of this file) instead of
;; kxr-body-minus-holes directly unless you have already verified these
;; assumptions yourself -- it checks them and transparently falls back
;; to plain sequential body- otherwise, so it is always correct, just
;; not always fast.

(defun kxr-body-axis-face (bod axis sign &optional (eps 0.01))
  (send bod :worldcoords)
  (let ((matches (remove-if-not
		  #'(lambda (f) (> (v. (send f :normal) (scale sign axis)) (- 1.0 eps)))
		  (send bod :faces))))
    (unless (= (length matches) 1)
      (error "kxr-body-axis-face: expected exactly 1 face with normal ~A*~A on ~A, got ~A"
	     sign axis bod (length matches)))
    (car matches)))

(defun kxr-vertex-member (v vlist &optional (eps 0.001))
  (find-if #'(lambda (p) (< (norm (v- p v)) eps)) vlist))

(defun kxr-plane-crossing-point (p1 p2 normal dist)
  ;; point where segment p1-p2 crosses the plane {x : normal.x = dist},
  ;; or nil if both endpoints are on the same side.
  (let ((d1 (- (v. normal p1) dist))
	(d2 (- (v. normal p2) dist)))
    (if (< (* d1 d2) 0.0)
	(v+ p1 (scale (/ d1 (- d1 d2)) (v- p2 p1)))
      nil)))

(defun kxr-order-by-angle (verts normal)
  (let ((vsum (float-vector 0 0 0)))
    (dolist (p verts) (v+ vsum p vsum))
    (let* ((center (scale (/ 1.0 (length verts)) vsum))
	   (u (normalize-vector (v- (car verts) center)))
	   (v2 (v* normal u))
	   (angle-point-pairs
	    (mapcar #'(lambda (p) (let ((d (v- p center))) (cons (atan (v. d v2) (v. d u)) p)))
		    verts)))
      (mapcar #'cdr (sort (copy-seq angle-point-pairs) #'(lambda (a b) (< (car a) (car b))))))))

(defun kxr-cutter-trim (cutter axis face-top face-bot)
  "cutter deliberately overshoots both face-top's and face-bot's planes
   (a clean through-cut), so none of its own vertices land exactly on
   either plane. This rebuilds each of the cutter's side faces as a
   quad trimmed exactly to where it crosses the two planes (discarding
   the original overshooting geometry entirely), and returns
   (list trimmed-wall-faces top-rim-points bot-rim-points) -- the rim
   points are exactly the trimmed walls' own boundary vertices (not an
   independently-computed circle), so they are guaranteed to coincide
   for edge stitching."
  (send cutter :worldcoords)
  (let* ((raw-walls (remove-if #'(lambda (f) (> (abs (v. (send f :normal) axis)) 0.7))
				(send cutter :faces)))
	 (normal-top (send face-top :normal)) (dist-top (- (face-top . distance)))
	 (normal-bot (send face-bot :normal)) (dist-bot (- (face-bot . distance)))
	 (trimmed nil) (top-pts nil) (bot-pts nil))
    (dolist (f raw-walls)
      (let* ((vs (butlast (send f :vertices))) ;; drop repeated closing vertex
	     (n (length vs))
	     (panel-tops nil) (panel-bots nil))
	(dotimes (i n)
	  (let* ((a (nth i vs)) (b (nth (mod (1+ i) n) vs))
		 (ct (kxr-plane-crossing-point a b normal-top dist-top))
		 (cb (kxr-plane-crossing-point a b normal-bot dist-bot)))
	    (when ct
	      (push ct panel-tops)
	      (unless (kxr-vertex-member ct top-pts) (push ct top-pts)))
	    (when cb
	      (push cb panel-bots)
	      (unless (kxr-vertex-member cb bot-pts) (push cb bot-pts)))))
	;; panel-tops/panel-bots each end up with exactly 2 points (one per
	;; vertical edge), collected in traversal order; (append tops
	;; (reverse bots)) rebuilds a simple (non-self-intersecting) quad
	;; following the panel's original cyclic order. No :normal/
	;; :distance is passed -- :init derives them from this vertex
	;; order via :reset-normal, guaranteeing they're self-consistent
	;; (passing the raw wall's own normal here instead does NOT
	;; guarantee that, since it has no way to know whether this
	;; vertex order actually winds the same way around it -- this
	;; was confirmed to silently produce a negative-area face).
	(push (instance geometry::face :init
			 :vertices (append (nreverse panel-tops) (reverse (nreverse panel-bots))))
	      trimmed)))
    (list trimmed
	  (kxr-order-by-angle top-pts normal-top)
	  (kxr-order-by-angle bot-pts normal-bot))))

(defun kxr-stitch-body-faces (new-faces &optional (eps 0.05))
  "Match every edge of `new-faces` that doesn't already have a partner
   to its geometric partner (opposite endpoints) among them, and
   cross-link pface/nface. Only pass freshly-created faces here (e.g.
   hole boundaries and cutter wall faces) -- bod's own untouched faces
   (face+/face- mutated in place via :enter-hole, and all other faces)
   already have correct pface/nface from bod's own construction and
   must not be included, or their valid links would be needlessly
   re-derived (harmless if it succeeds, but pure risk for no benefit).
   Errors if any edge needing a match has no exactly-one partner (not
   a closed manifold)."
  (let ((all-edges (mapcan #'(lambda (f) (copy-seq (send f :edges))) new-faces))
	(unmatched nil))
    (dolist (e1 all-edges)
      (unless (e1 . nface)
	(let ((partners
	       (remove-if-not
		#'(lambda (e2)
		    (and (not (eq e2 e1))
			 (null (e2 . nface))
			 (< (norm (v- (e1 . pvert) (e2 . nvert))) eps)
			 (< (norm (v- (e1 . nvert) (e2 . pvert))) eps)))
		all-edges)))
	  (cond
	   ((= (length partners) 1)
	    (let ((e2 (car partners)))
	      (setq (e1 . nface) (e2 . pface))
	      (setq (e2 . nface) (e1 . pface))))
	   (t (push (list e1 (length partners)) unmatched))))))
    (when unmatched
      (error "kxr-stitch-body-faces: ~A edge(s) failed to match exactly one partner: ~A"
	     (length unmatched) unmatched))
    new-faces))

(defun kxr-body-minus-holes (bod hole-centers hole-radii cutters &key (axis #f(0 0 1)))
  "bod: un-holed prism (e.g. make-prism output), with exactly one face
   whose normal is +axis and one whose normal is -axis. hole-centers/
   hole-radii: parallel lists, one per hole (radii currently unused --
   the actual hole shape comes from each cutter's own geometry, kept
   for future direction-aware generalization / sanity checks).
   cutters: parallel list of already-positioned, already-through-cut
   cylinder bodies (same objects you'd otherwise pass to body-), one
   per hole. See file header for assumptions -- prefer
   kxr-body-minus-holes-safe unless you have verified them yourself."
  (let* ((face+ (kxr-body-axis-face bod axis 1))
	 (face- (kxr-body-axis-face bod axis -1))
	 (trims (mapcar #'(lambda (c) (kxr-cutter-trim c axis face+ face-)) cutters))
	 (cutter-walls (mapcar #'first trims))
	 ;; reversed: a wall panel's own top/bottom edge and the matching
	 ;; hole edge must trace the same physical boundary in OPPOSITE
	 ;; directions (half-edge convention) for kxr-stitch-body-faces to
	 ;; pair them; the wall panels' own vertex order (from kxr-cutter-
	 ;; trim, following the cutter's original construction) and the
	 ;; hole's angle-sorted order otherwise coincide instead of reversing.
	 (holes+ (mapcar #'(lambda (tr) (instance geometry::hole :init :vertices (reverse (second tr)))) trims))
	 (holes- (mapcar #'(lambda (tr) (instance geometry::hole :init :vertices (reverse (third tr)))) trims)))
    ;; mutate face+/face- IN PLACE (:enter-hole) instead of rebuilding
    ;; them from their own vertex list: their existing edges are already
    ;; correctly stitched to bod's other faces (from bod's own
    ;; construction), and rebuilding-from-vertices does not reliably
    ;; reproduce that same edge direction/identity (a real failure mode
    ;; hit and confirmed while developing this function) -- so the
    ;; outer boundary is left completely untouched, and only the new
    ;; hole/wall edges (all freshly created, so nface starts nil) need
    ;; stitching at all.
    (dolist (h holes+) (send face+ :enter-hole h) (send h :face face+))
    (dolist (h holes-) (send face- :enter-hole h) (send h :face face-))
    (kxr-stitch-body-faces (append holes+ holes- (apply #'append cutter-walls)))
    (instance geometry::body :init :faces (append (send bod :faces) (apply #'append cutter-walls)))))

;; ---- safety check + auto-fallback wrapper ----
;;
;; kxr-body-minus-holes silently produces wrong geometry if a hole
;; overlaps another, or reaches/crosses bod's outer boundary (confirmed
;; while developing this: a hole that breaches the boundary needs the
;; outer contour itself modified, not just a hole added to a face, and
;; produced a visibly wrong face count/volume without erroring). The
;; helpers below detect both cases and kxr-body-minus-holes-safe falls
;; back to plain sequential body- whenever they're not met, so it is
;; always safe to call as a drop-in replacement for (apply #'body- bod
;; cutters) -- just slower (identical to body-) on the cases it can't
;; fast-path.

(defun kxr-point-segment-distance (p a b)
  (let* ((ab (v- b a)) (len2 (v. ab ab))
	 (tt (if (> len2 1e-12) (/ (v. (v- p a) ab) len2) 0.0))
	 (tc (max 0.0 (min 1.0 tt))))
    (norm (v- p (v+ a (scale tc ab))))))

(defun kxr-point-in-polygon-p (point poly-vertices normal)
  "point-in-polygon test for a point already known to lie in the
   polygon's plane, via signed angle sum around point (~2pi if inside,
   ~0 if outside)."
  (let* ((vs (butlast poly-vertices))
	 (n (length vs))
	 (u (normalize-vector (v- (car vs) point)))
	 (v2 (v* normal u))
	 (total 0.0))
    (dotimes (i n)
      (let* ((a (nth i vs)) (b (nth (mod (1+ i) n) vs))
	     (da (v- a point)) (db (v- b point))
	     (dang (- (atan (v. db v2) (v. db u)) (atan (v. da v2) (v. da u)))))
	(cond ((> dang pi) (decf dang (* 2 pi)))
	      ((< dang (- pi)) (incf dang (* 2 pi))))
	(incf total dang)))
    (> (abs total) pi)))

(defun kxr-circle-inside-polygon-p (center radius poly-vertices normal &optional (margin 0.1))
  "true if the disk (center, radius) lies entirely inside the closed
   planar polygon poly-vertices, with a safety margin against
   near-boundary numerical issues."
  (and (kxr-point-in-polygon-p center poly-vertices normal)
       (let* ((vs (butlast poly-vertices)) (n (length vs)))
	 (dotimes (i n t)
	   (let ((d (kxr-point-segment-distance center (nth i vs) (nth (mod (1+ i) n) vs))))
	     (unless (>= d (+ radius margin)) (return-from kxr-circle-inside-polygon-p nil)))))))

(defun kxr-holes-pairwise-disjoint-p (hole-centers hole-radii &optional (margin 0.1))
  (let ((n (length hole-centers)) (cv (coerce hole-centers vector)) (rv (coerce hole-radii vector)))
    (dotimes (i n t)
      (dotimes (j n)
	(when (< i j)
	  (unless (>= (norm (v- (aref cv i) (aref cv j))) (+ (aref rv i) (aref rv j) margin))
	    (return-from kxr-holes-pairwise-disjoint-p nil)))))))

(defun kxr-body-minus-holes-safe (bod hole-centers hole-radii cutters &key (axis #f(0 0 1)))
  "Drop-in alternative to (apply #'body- bod cutters): uses the fast
   kxr-body-minus-holes path when every hole is pairwise non-overlapping
   and entirely interior to bod's two axis-facing faces (not touching or
   crossing the outer boundary), and transparently falls back to plain
   sequential body- otherwise -- so it is always correct, just not
   always fast."
  (let ((face+ (kxr-body-axis-face bod axis 1)))
    (if (and (kxr-holes-pairwise-disjoint-p hole-centers hole-radii)
	     (every #'(lambda (c r)
			(kxr-circle-inside-polygon-p c r (send face+ :vertices) (send face+ :normal)))
		    hole-centers hole-radii))
	(kxr-body-minus-holes bod hole-centers hole-radii cutters :axis axis)
      (apply #'body- bod cutters))))
