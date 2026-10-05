;;;
;;; eus2json.l : export an EusLisp (jskeus irtmodel) robot model to JSON
;;;              for the iPhone SceneKit viewer (eusview).
;;;
;;; Units: m, deg (linear joints: mm). Coordinates: EusLisp world (z up).
;;;
;;;  links[i]  : name, parent (index or -1), pos, rot (row-major 3x3) = link frame
;;;              relative to the parent link frame at all joint angles = 0,
;;;              meshes [{color [r g b a], vertices [x y z ...] (link frame, m), indices [...]}]
;;;  joints[k] : name, link (child link index), type "rotational"|"linear",
;;;              axis (child link frame), min, max
;;;     child_local = T(pos) R(rot) R(axis, angle)      (rotational, deg)
;;;     child_local = T(pos) R(rot) T(axis * mm / 1000) (linear, mm)
;;;  poses     : {"zero-pose": [...], "reset-pose": [...], ...} (joint order)
;;;  check     : {"pose", "angles", "link_world_pos": [[x y z] per link]}
;;;  motions   : optional [{"name", "fps", "frames": [[angles..]..], "root": [[x y z r00..r22]..]}]
;;;
;;; usage (see eusview/README.md):
;;;   (load "eusview/irtload.l") (load "eusview/eus2json.l")
;;;   (eus2json r "robots/foo.json" :name "foo" :source "...")
;;;

(defvar *eus2json-pose-methods*
  '(:reset-pose :reset-manip-pose :init-pose :sit-pose))

;;; ------------------------------------------------------------ number output
(defun json-num (x &optional (d 4))
  "print x rounded to d decimals, trailing zeros stripped"
  (let* ((m (expt 10 d))
         (r (round (* x m)))
         (neg (< r 0))
         (a (abs r))
         (ip (/ a m))
         (fp (mod a m))
         s)
    (cond
     ((= fp 0) (setq s (format nil "~d" ip)))
     (t
      (let ((fs (format nil "~d" (+ fp m)))) ;; "1xxxx" -> zero padded
        (setq fs (subseq fs 1))
        (while (and (> (length fs) 0) (eql (elt fs (1- (length fs))) #\0))
          (setq fs (subseq fs 0 (1- (length fs)))))
        (setq s (format nil "~d.~a" ip fs)))))
    (if (and neg (/= r 0)) (concatenate string "-" s) s)))

(defun e2j-join (strs &optional (sep ","))
  "concatenate strings with sep (EusLisp format has no ~{ ~})"
  (let ((st (make-string-output-stream 256)) (first t))
    (dolist (x strs)
      (unless first (princ sep st))
      (princ x st)
      (setq first nil))
    (get-output-stream-string st)))

(defun json-escape (str)
  (let ((st (make-string-output-stream 64)))
    (dotimes (i (length str))
      (let ((c (elt str i)))
        (if (or (eql c #\") (eql c #\\)) (write-byte #\\ st))
        (write-byte c st)))
    (get-output-stream-string st)))

(defun json-str (s &optional (downcase t))
  (let ((str (string s)))
    (format nil "\"~a\"" (json-escape (if downcase (string-downcase str) str)))))

(defun json-vec (v &optional (d 4) (scl 1.0))
  (let ((ss nil))
    (dotimes (i (length v)) (push (json-num (* scl (elt v i)) d) ss))
    (format nil "[~a]" (e2j-join (nreverse ss)))))

(defun json-rot (m)
  (let (ss)
    (dotimes (i 3) (dotimes (j 3) (push (json-num (aref m i j) 6) ss)))
    (format nil "[~a]" (e2j-join (nreverse ss)))))

;;; ------------------------------------------------------------ model helpers
(defun e2j-axis-vector (ax)
  (cond ((float-vector-p ax) (normalize-vector ax))
        (t (case ax
             (:x #f(1 0 0)) (:-x #f(-1 0 0))
             (:y #f(0 1 0)) (:-y #f(0 -1 0))
             (:z #f(0 0 1)) (:-z #f(0 0 -1))
             (t (error "unknown axis ~A" ax))))))

(defun e2j-joint-type (j)
  (cond ((derivedp j rotational-joint) "rotational")
        ((derivedp j linear-joint) "linear")
        (t nil)))

(defun e2j-link-parent (l links)
  "nearest ancestor (cascaded-coords parent chain) that is one of links"
  (let ((p (send l :parent)))
    (while (and p (not (memq p links)))
      (setq p (send p :parent)))
    p))

(defun e2j-sort-links (links)
  "parents before children"
  (let ((done nil) (rest (copy-list links)) (changed t))
    (while (and rest changed)
      (setq changed nil)
      (dolist (l rest)
        (let ((p (e2j-link-parent l links)))
          (when (or (null p) (memq p done))
            (setq done (append done (list l)))
            (setq rest (remove l rest))
            (setq changed t)))))
    (append done rest)))

(defun e2j-color (b)
  (let ((col (get b :face-color)) (alpha 1.0))
    (when (and col (not (vectorp col)))
      (setq col (gl::find-color col)))
    (when (derivedp col gl::colormaterial)
      (setq col (send col :diffuse)))
    (if (get b :transparency) (setq alpha (- 1.0 (get b :transparency))))
    (if (and col (>= (length col) 3))
        (float-vector (elt col 0) (elt col 1) (elt col 2)
                      (if (> (length col) 3) (elt col 3) alpha))
      (float-vector 0.6 0.6 0.6 alpha))))

;;; mesh accumulator: (verts-list-reversed nverts indices-reversed)
(defun e2j-face-vertices (f)
  (let ((vs (send f :vertices)))
    (if (and (cdr vs) (eq (car vs) (car (last vs)))) (butlast vs) vs)))

(defun e2j-convex-p (vs nrm)
  (let ((n (length vs)) (ok t))
    (dotimes (i n)
      (let* ((a (elt vs i)) (b (elt vs (mod (1+ i) n))) (c (elt vs (mod (+ i 2) n)))
             (cr (v* (v- b a) (v- c b))))
        (if (< (v. cr nrm) -1e-6) (setq ok nil))))
    ok))

(defun e2j-triangulate-face (f)
  "returns (vertices . triangles) ; triangles are index triples into vertices"
  (let* ((vs (e2j-face-vertices f))
         (n (length vs))
         (nrm (send f :normal))
         tris)
    (cond
     ((< n 3) nil)
     ((and (null (and (derivedp f face) (send f :holes))) (e2j-convex-p vs nrm))
      (dotimes (i (- n 2)) (push (list 0 (1+ i) (+ i 2)) tris))
      (cons vs (nreverse tris)))
     (t
      (let ((polys (geo::face-to-triangle-aux f))
            (vv (copy-list vs)))
        (if (null polys)
            (progn ;; fallback: fan
              (dotimes (i (- n 2)) (push (list 0 (1+ i) (+ i 2)) tris))
              (cons vs (nreverse tris)))
          (progn
            (dolist (p polys)
              (let ((pv (e2j-face-vertices p)) idx)
                (dolist (v (subseq pv 0 3))
                  (let ((k (position v vv :test #'(lambda (a b) (< (distance a b) 1e-6)))))
                    (unless k
                      (setq vv (append vv (list v)))
                      (setq k (1- (length vv))))
                    (push k idx)))
                (setq idx (nreverse idx))
                ;; keep the face orientation
                (let ((tn (v* (v- (elt vv (elt idx 1)) (elt vv (elt idx 0)))
                              (v- (elt vv (elt idx 2)) (elt vv (elt idx 0))))))
                  (if (< (v. tn nrm) 0) (setq idx (list (elt idx 0) (elt idx 2) (elt idx 1)))))
                (push idx tris)))
            (cons vv (nreverse tris)))))))))

(defun e2j-body-meshes-faces (b lcds)
  "one mesh per body; vertices are duplicated per face (flat shading)"
  (let ((verts nil) (inds nil) (nv 0)
        (flip (and (find-method b :volume) (< (send b :volume) 0)))) ;; inside-out body (e.g. mirrored)
    (send b :worldcoords)
    (dolist (f (send b :faces))
      (let ((r (e2j-triangulate-face f)))
        (when r
          (dolist (v (car r))
            (push (send lcds :inverse-transform-vector v) verts))
          (dolist (tri (cdr r))
            (if flip (setq tri (list (elt tri 0) (elt tri 2) (elt tri 1))))
            (dolist (i tri) (push (+ nv i) inds)))
          (incf nv (length (car r))))))
    (if inds
        (list (list (e2j-color b) (nreverse verts) (nreverse inds))))))

(defun e2j-glvertices-meshes (glv lcds &optional default-color)
  (let ((ret nil)
        (gcds (send glv :worldcoords)))
    (dolist (minfo (glv . gl::mesh-list))
      (let* ((mat (cadr (assoc :material minfo)))
             (dif (or (cadr (assoc :diffuse mat)) (cadr (assoc :ambient mat))))
             (vm (cadr (assoc :vertices minfo)))
             (idx (cadr (assoc :indices minfo)))
             (typ (cadr (assoc :type minfo)))
             (n (array-dimension vm 0))
             (col (cond (dif (float-vector (elt dif 0) (elt dif 1) (elt dif 2)
                                           (if (> (length dif) 3) (elt dif 3) 1.0)))
                        (default-color default-color)
                        (t (float-vector 0.6 0.6 0.6 1.0))))
             verts inds)
        (when (or (null typ) (eq typ :triangles))
          (dotimes (i n)
            (push (send lcds :inverse-transform-vector
                        (send gcds :transform-vector (matrix-row vm i))) verts))
          (if idx
              (dotimes (i (length idx)) (push (elt idx i) inds))
            (dotimes (i n) (push i inds)))
          (push (list col (nreverse verts) (nreverse inds)) ret))))
    (nreverse ret)))

(defun e2j-body-glvertices (b)
  (and (find-method b :glvertices)
       (b . gl::aglvertices)))

(defun e2j-link-meshes (l &key prefer-glvertices)
  (let ((lcds (send l :worldcoords)) (ret nil))
    (dolist (b (send l :bodies))
      (let ((glv (e2j-body-glvertices b)))
        (cond
         ((and glv (or prefer-glvertices (null (send b :faces))))
          (setq ret (append ret (e2j-glvertices-meshes glv lcds (e2j-color b)))))
         ((derivedp b gl::glvertices)
          (setq ret (append ret (e2j-glvertices-meshes b lcds))))
         ((find-method b :faces)
          (setq ret (append ret (e2j-body-meshes-faces b lcds)))))))
    ret))

;;; ------------------------------------------------------------ zero pose
(defun e2j-set-zero-pose (r)
  "put every child link at its default-coords (= joint angle 0), ignoring limits"
  (dolist (j (send r :joint-list))
    (send j :joint-angle 0)) ;; also sets the joint-angle slots (may clamp)
  (dolist (j (send r :joint-list))
    (when (e2j-joint-type j)
      (send (send j :child-link) :replace-coords (j . default-coords))))
  (send r :worldcoords))

(defun e2j-relative (parent-cds cds)
  (if parent-cds
      (send (send parent-cds :inverse-transformation) :transform cds)
    (send cds :copy-worldcoords)))

;;; ------------------------------------------------------------ FK check
(defun e2j-fk (links parents rels joints angles)
  "compute link world coords from the exported data (what the viewer does)"
  (let ((wc (make-list (length links))) (jl (make-list (length links))))
    (dotimes (k (length joints))
      (setf (elt jl (car (elt joints k))) (list (cdr (elt joints k)) (elt angles k))))
    (dotimes (i (length links))
      (let* ((c (send (elt rels i) :copy-worldcoords))
             (ja (elt jl i)))
        (when ja
          (let ((j (car (car ja))) (ax (cdr (car ja))) (a (cadr ja)))
            (if (derivedp j rotational-joint)
                (send c :rotate (deg2rad a) ax :local)
              (send c :translate (scale a ax) :local))))
        (setf (elt wc i)
              (if (>= (elt parents i) 0)
                  (send (send (elt wc (elt parents i)) :copy-worldcoords) :transform c)
                c))))
    wc))

;;; ------------------------------------------------------------ main
(defun eus2json (r fname &key (name (send r :name)) (source "") (poses *eus2json-pose-methods*)
                   (check-pose nil) motions prefer-glvertices (extra-poses nil) (extra nil) group)
  "export robot r to fname. motions: list of (name fps frames roots [check-json-string] [digits] [extra-json])
where frames are angle-vectors and roots are the world coordinates of the root link
(roots nil: no \"root\" key; digits: decimals of the angles, default 3;
extra-json: string of additional members, e.g. \"\\\"number\\\":3\").
extra: list of (key . json-string) added as top level members (e.g. (\"physics\" . \"{...}\")).
group: \"kxr\" | \"khr\" | \"jsk\" (app grouping; written after \"name\")."
  (let* ((av0 (send r :angle-vector))
         (root-cds (send r :copy-worldcoords))
         (links (e2j-sort-links (send r :links)))
         (jlist (remove-if-not #'e2j-joint-type (send r :joint-list)))
         (skipped (remove-if #'e2j-joint-type (send r :joint-list)))
         parents rels pose-alist joints check-angles linkpos
         (nv 0) (ntri 0))
    (when skipped (warning-message 1 ";; eus2json: skip non rotational/linear joints ~A~%" skipped))
    ;; robot at world origin
    (send r :newcoords (make-coords))
    (send r :worldcoords)
    ;; ---- poses (joint-list order)
    (push (cons "zero-pose" (instantiate float-vector (length jlist))) pose-alist)
    (dolist (pm poses)
      (when (find-method r pm)
        (send r :angle-vector (copy-seq av0))
        (send r pm)
        (push (cons (string-downcase (string pm))
                    (map float-vector #'(lambda (j) (send j :joint-angle)) jlist))
              pose-alist)))
    ;; test-pose: every joint at 30% of its range (finite limits, else 30 deg / 30 mm)
    (push (cons "test-pose"
                (map float-vector
                     #'(lambda (j)
                         (let ((mn (send j :min-angle)) (mx (send j :max-angle)))
                           (if (and (> mn -1e5) (< mx 1e5))
                               (+ mn (* 0.3 (- mx mn)))
                             30.0)))
                     jlist))
          pose-alist)
    (dolist (ep extra-poses) (push ep pose-alist))
    (setq pose-alist (nreverse pose-alist))
    (send r :newcoords (make-coords)) ;; pose methods may move the root
    ;; ---- zero pose geometry
    (e2j-set-zero-pose r)
    (dolist (l links)
      (let ((p (e2j-link-parent l links)))
        (push (if p (position p links) -1) parents)
        (push (e2j-relative (if p (send p :worldcoords)) (send l :worldcoords)) rels)))
    (setq parents (nreverse parents) rels (nreverse rels))
    (dolist (j jlist)
      (let ((ci (position (send j :child-link) links)))
        (unless ci (error "joint ~A child link not in links" (send j :name)))
        (push (cons ci (cons j (e2j-axis-vector (j . axis)))) joints)))
    (setq joints (nreverse joints))
    ;; ---- check pose
    (setq check-pose (or check-pose (if (assoc "reset-pose" pose-alist :test #'equal) "reset-pose" "test-pose")))
    (setq check-angles (cdr (assoc check-pose pose-alist :test #'equal)))
    (send r :angle-vector (copy-seq av0))
    (send r :newcoords (make-coords))
    (dotimes (k (length jlist)) (send (elt jlist k) :joint-angle (elt check-angles k)))
    (send r :worldcoords)
    (setq linkpos (mapcar #'(lambda (l) (copy-seq (send l :worldpos))) links))
    ;; self test: FK from the exported data vs EusLisp
    (let* ((wc (e2j-fk links parents rels joints (coerce check-angles cons)))
           (err 0.0) (rerr 0.0))
      (dotimes (i (length links))
        (setq err (max err (distance (send (elt wc i) :worldpos) (elt linkpos i))))
        (setq rerr (max rerr (norm (array-entity (m- (send (elt wc i) :worldrot)
                                                       (send (elt links i) :worldrot)))))))
      (format t ";; eus2json ~A: FK self-check (~A) max pos err ~a mm, rot err ~a~%"
              name check-pose (json-num err 6) (json-num rerr 6)))
    ;; ---- write
    (e2j-set-zero-pose r)
    (with-open-file
     (o fname :direction :output)
     (format o "{~%\"name\":~a,~%~a\"source\":~a,~%\"units\":{\"length\":\"m\",\"angle\":\"deg\",\"linear_joint\":\"mm\"},~%"
             (json-str name nil) (if group (format nil "\"group\":~a,~%" (json-str group nil)) "")
             (json-str source nil))
     (format o "\"links\":[~%")
     (dotimes (i (length links))
       (let* ((l (elt links i))
              (rc (elt rels i))
              (ms (e2j-link-meshes l :prefer-glvertices prefer-glvertices)))
         (format o "{\"name\":~a,\"parent\":~d,\"pos\":~a,\"rot\":~a,~%\"meshes\":["
                 (json-str (send l :name)) (elt parents i)
                 (json-vec (send rc :worldpos) 5 0.001) (json-rot (send rc :worldrot)))
         (dotimes (k (length ms))
           (let ((m (elt ms k)))
             (incf nv (length (elt m 1))) (incf ntri (/ (length (elt m 2)) 3))
             (format o "~a~%{\"color\":~a,\"vertices\":[" (if (> k 0) "," "") (json-vec (elt m 0) 3))
             (let ((first t))
               (dolist (v (elt m 1))
                 (format o "~a~a,~a,~a" (if first "" ",")
                         (json-num (* 0.001 (elt v 0)) 4) (json-num (* 0.001 (elt v 1)) 4)
                         (json-num (* 0.001 (elt v 2)) 4))
                 (setq first nil)))
             (format o "],~%\"indices\":[~a]}" (e2j-join (elt m 2)))))
         (format o "]}~a~%" (if (< i (1- (length links))) "," ""))))
     (format o "],~%\"joints\":[~%")
     (dotimes (k (length joints))
       (let* ((jj (elt joints k)) (j (cadr jj)) (lin (derivedp j linear-joint)))
         (format o "{\"name\":~a,\"link\":~d,\"type\":\"~a\",\"axis\":~a,\"min\":~a,\"max\":~a}~a~%"
                 (json-str (send j :name)) (car jj) (e2j-joint-type j)
                 (json-vec (cddr jj) 6)
                 (json-num (max -1e6 (send j :min-angle)) 3)
                 (json-num (min 1e6 (send j :max-angle)) 3)
                 (if (< k (1- (length joints))) "," ""))))
     (format o "],~%\"poses\":{~%")
     (dotimes (k (length pose-alist))
       (format o "~a:~a~a~%" (json-str (car (elt pose-alist k)))
               (json-vec (cdr (elt pose-alist k)) 3)
               (if (< k (1- (length pose-alist))) "," "")))
     (format o "},~%\"check\":{\"pose\":~a,\"angles\":~a,~%\"link_world_pos\":[~a]}"
             (json-str check-pose) (json-vec check-angles 3)
             (e2j-join (mapcar #'(lambda (p) (json-vec p 5 0.001)) linkpos)))
     (when motions
       (format o ",~%\"motions\":[")
       (dotimes (k (length motions))
         (let ((mo (elt motions k)))
           (format o "~a~%{\"name\":~a,\"fps\":~a,~a~%\"frames\":[~a]~a~a}"
                   (if (> k 0) "," "")
                   (json-str (elt mo 0) nil) (elt mo 1)
                   (if (nth 6 mo) (format nil "~a," (nth 6 mo)) "")
                   (e2j-join (mapcar #'(lambda (av) (json-vec av (or (nth 5 mo) 3))) (elt mo 2))
                             (format nil ",~%"))
                   (if (elt mo 3)
                       (format nil ",~%\"root\":[~a]"
                               (e2j-join
                                (mapcar #'(lambda (c)
                                            (let ((p (json-vec (send c :worldpos) 5 0.001))
                                                  (m (json-rot (send c :worldrot))))
                                              (format nil "[~a,~a]" (subseq p 1 (1- (length p)))
                                                      (subseq m 1 (1- (length m))))))
                                        (elt mo 3))
                                (format nil ",~%")))
                     "")
                   (if (nth 4 mo) (format nil ",~%\"check\":~a" (nth 4 mo)) ""))))
       (format o "]"))
     (dolist (ex extra)
       (format o ",~%~a:~a" (json-str (car ex) nil) (cdr ex)))
     (format o "~%}~%"))
    ;; restore
    (send r :angle-vector av0)
    (send r :newcoords root-cds)
    (send r :worldcoords)
    (format t ";; eus2json ~A -> ~A : ~d links, ~d joints, ~d vertices, ~d triangles, poses ~A~%"
            name fname (length links) (length joints) nv ntri (mapcar #'car pose-alist))
    fname))
