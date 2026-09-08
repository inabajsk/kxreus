;;;
;;; eus2mujoco.l
;;;
;;; kxreusのネイティブbody-basedロボットモデル(make-kxr-robot :model nil)
;;; から、外部ツールを一切使わず、直接MuJoCo XML(MJCF)ファイル+STL
;;; メッシュを生成する。mujoco2eus.l(逆方向)と対になる。
;;;
;;; 注意: 既存の~/kxreus/eus2mjcf.l(cascaded-linkに:dump-mjcfを追加する
;;; 汎用ツール)は意図的に使わず、新規に書き直している(ユーザ指示)。
;;; メッシュ(STL)書き出しはeus2urdf.lのlink-local-faces/write-stl-*と
;;; 完全に同じ処理(フォーマットに依存しない)なので、それをrequireして
;;; 再利用する。
;;;
;;; MJCFはURDFと同じくm/kg/radがSI単位なので、単位変換はeus2urdf.lと
;;; 全く同じ(mm2m/g2kg/gmm2-2-kgm2/deg2rad)。慣性テンソルはURDFの
;;; ixx/ixy/.../izzではなく、MuJoCoのfullinertia(ixx iyy izz ixy ixz iyz
;;; の順)属性でそのまま指定できる(主軸分解して:quatで向きを別途書く
;;; 必要が無く、実装がシンプルになる)。
;;;
;;; MJCFはURDFと違い<body>を親子関係のまま入れ子にするツリー構造なので、
;;; ジョイントの親子関係からリンクの木を作り、ルートから再帰的に書き出す。
;;; <body>の位置(pos)・向き(quat)は「親リンク自身の座標系から見た
;;; 相対位置」(eus2urdf.lの<joint><origin>と同じ規約)。
;;;
;;; 使い方:
;;;   (require :eus2mujoco)
;;;   (native-robot-to-mujoco-file "kxrl2l2a6h2")
;;;   ;; -> ~/kxreus/eusmjcf/kxrl2l2a6h2.xml
;;;   ;; -> ~/kxreus/eusmjcf/meshes/kxrl2l2a6h2/<link>.stl (各リンク1個)
;;;
(require :kxrmodels)
(require :eus2urdf) ;; link-local-faces/dump-link-mesh-stlを再利用するため

(provide :eus2mujoco)

;; ---- ツリー構造の構築 ----

(defun mjcf-children-alist (joints)
  ;; ((parent-name . (joint1 joint2 ...)) ...) 、親リンク名で子jointを
  ;; グループ化。
  (let (alist)
    (dolist (j joints)
      (let* ((pname (eus-name-string (send j :parent-link)))
             (cell (assoc pname alist :test #'string=)))
        (if cell
            (setf (cdr cell) (append (cdr cell) (list j)))
          (push (cons pname (list j)) alist))))
    (nreverse alist)))

(defun mjcf-joint-type (joint)
  (cond ((derivedp joint rotational-joint) "hinge")
        ((derivedp joint linear-joint) "slide")
        (t (error "eus2mujoco: unsupported joint class ~A" (class joint)))))

;; ---- <body>1個ぶん(再帰) ----

(defun make-indent-string (n)
  ;; make-stringの:initial-elementがEusLispでは正しく動かない
  ;; (実機確認済み)ため、自前でスペースを積む。
  (let ((s ""))
    (dotimes (i n) (setq s (concatenate string s " ")))
    s))

(defun dump-mjcf-body (strm link incoming-joint children-alist indent mesh-relpath)
  (let* ((lname (eus-name-string link))
         (pad (make-indent-string indent)))
    (format strm "~A<body name=\"~A\"" pad lname)
    (if incoming-joint
        (let* ((rel (send (send (send incoming-joint :parent-link) :worldcoords)
                          :transformation (send link :worldcoords)))
               (pos (mm2m-vec (send rel :worldpos)))
               (q (matrix2quaternion (send rel :worldrot))))
          (format strm " pos=\"~A ~A ~A\"" (fmt-f (elt pos 0)) (fmt-f (elt pos 1)) (fmt-f (elt pos 2)))
          (unless (and (< (abs (- (elt q 0) 1.0)) 1e-6))
            (format strm " quat=\"~A ~A ~A ~A\"" (fmt-f (elt q 0)) (fmt-f (elt q 1)) (fmt-f (elt q 2)) (fmt-f (elt q 3)))))
      (format strm " pos=\"0 0 0\""))
    (format strm ">~%")
    ;; inertial
    (let ((c (mm2m-vec (link . acentroid))) (i (link . inertia-tensor)))
      (format strm "~A  <inertial pos=\"~A ~A ~A\" mass=\"~A\"~%"
              pad (fmt-f (elt c 0)) (fmt-f (elt c 1)) (fmt-f (elt c 2)) (fmt-f (g2kg (send link :weight))))
      (format strm "~A    fullinertia=\"~A ~A ~A ~A ~A ~A\"/>~%"
              pad (fmt-e (gmm2-2-kgm2 (aref i 0 0))) (fmt-e (gmm2-2-kgm2 (aref i 1 1))) (fmt-e (gmm2-2-kgm2 (aref i 2 2)))
              (fmt-e (gmm2-2-kgm2 (aref i 0 1))) (fmt-e (gmm2-2-kgm2 (aref i 0 2))) (fmt-e (gmm2-2-kgm2 (aref i 1 2)))))
    ;; joint
    (if incoming-joint
        (let ((rotationalp (derivedp incoming-joint rotational-joint)))
          (format strm "~A  <joint name=\"~A\" type=\"~A\" pos=\"0 0 0\" axis=\"~A ~A ~A\"~%"
                  pad (eus-name-string incoming-joint) (mjcf-joint-type incoming-joint)
                  (fmt-f (elt (incoming-joint . axis) 0)) (fmt-f (elt (incoming-joint . axis) 1)) (fmt-f (elt (incoming-joint . axis) 2)))
          (format strm "~A    limited=\"true\" range=\"~A ~A\" damping=\"0.2\"/>~%"
                  pad
                  (fmt-f (if rotationalp (deg2rad (send incoming-joint :min-angle)) (mm2m (send incoming-joint :min-angle))))
                  (fmt-f (if rotationalp (deg2rad (send incoming-joint :max-angle)) (mm2m (send incoming-joint :max-angle))))))
      (format strm "~A  <freejoint/>~%" pad))
    ;; geom(メッシュ)
    (format strm "~A  <geom type=\"mesh\" mesh=\"~A_mesh\"/>~%" pad lname)
    ;; 子リンク(再帰)
    (dolist (j (cdr (assoc lname children-alist :test #'string=)))
      (dump-mjcf-body strm (send j :child-link) j children-alist (+ indent 2) mesh-relpath))
    (format strm "~A</body>~%" pad)))

;; ---- メイン ----

(defun native-robot-to-mujoco-file
    (name-str &key (robot nil) (outfile nil) (mesh-dir nil))
  (unless robot
    (setq robot (make-kxr-robot name-str :model nil :viewer nil :ri nil)))
  (when (find-method robot :neutral) (send robot :neutral))
  (unless outfile
    ;; "eusmjcf"は今回のネイティブ生成専用の出力先。既存の"mjcfs"
    ;; (eus2mjcf.l由来)とは別ディレクトリにする。
    (rcb4eus-mkdir "eusmjcf")
    (setq outfile (rcb4eus-file (format nil "eusmjcf/~A.xml" name-str))))
  (unless mesh-dir
    (rcb4eus-mkdir "eusmjcf/meshes")
    (rcb4eus-mkdir (format nil "eusmjcf/meshes/~A" name-str))
    (setq mesh-dir (rcb4eus-file (format nil "eusmjcf/meshes/~A" name-str))))
  (let* ((links (send robot :links))
         (joints (send robot :joint-list))
         (root-link (car links))
         (children-alist (mjcf-children-alist joints)))
    (dolist (l links) (dump-link-mesh-stl l mesh-dir))
    (with-open-file (strm outfile :direction :output :if-exists :supersede)
      (format strm "<mujoco model=\"~A\">~%" name-str)
      (format strm "  <!-- auto-generated by eus2mujoco.l from a native robot-model. -->~%")
      (format strm "  <!-- do not edit by hand; regenerate with (native-robot-to-mujoco-file ~S) -->~%" name-str)
      (format strm "  <compiler angle=\"radian\"/>~%")
      (format strm "  <default>~%")
      (format strm "    <joint frictionloss=\"0.2\" armature=\"0.011\"/>~%")
      (format strm "    <geom rgba=\"0.7 0.7 0.7 1\"/>~%")
      (format strm "  </default>~%")
      (format strm "  <asset>~%")
      (dolist (l links)
        (format strm "    <mesh name=\"~A_mesh\" file=\"meshes/~A/~A.stl\"/>~%"
                (eus-name-string l) name-str (eus-name-string l)))
      (format strm "  </asset>~%")
      (format strm "  <worldbody>~%")
      (dump-mjcf-body strm root-link nil children-alist 4 (format nil "meshes/~A" name-str))
      (format strm "  </worldbody>~%")
      (format strm "</mujoco>~%"))
    (format t ";; native-robot-to-mujoco-file: wrote ~A (~A links, ~A joints)~%"
            outfile (length links) (length joints))
    outfile))
