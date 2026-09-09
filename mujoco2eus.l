;;;
;;; mujoco2eus.l
;;;
;;; MuJoCo XML(MJCF)ファイル(+STLメッシュ)から、外部ツールを一切
;;; 使わず、直接eusmodels/*.l形式(euscollada-robotサブクラス)の
;;; EusLispファイルを生成する。eus2mujoco.l(逆方向)と対になる。
;;;
;;; 実装方針はurdf2eus.lと全く同じ(そちらのコメント参照): 実際に
;;; bodyset-link/rotational-joint(linear-joint)インスタンスを構築し、
;;; eus2native-collada.lの既存の書き出し関数を再利用する。
;;;
;;; urdf2eus.lで発見した重大バグ(メッシュ頂点を絶対座標に焼き込んだ
;;; 後でbodyset-linkに:transformすると、geometry::facesetが「生きた」
;;; cascaded-coordsであるため二重変換になる)を踏まえ、ここでは最初から
;;; リンク自身のローカル座標のまま頂点を焼き込み、後から一切動かさない。
;;;
;;; MJCFはURDFと違い<body>がツリー状に入れ子になっている(親子関係が
;;; 木構造としてそのままXMLに現れる)ため、パースも木を再帰的にたどる
;;; 形になる(URDFのようにflatなlink/jointリストではない)。
;;;
;;; 使い方:
;;;   (require :mujoco2eus)
;;;   (mujoco-to-native-collada-file "eusmjcf/kxrl2l2a6h2.xml")
;;;   ;; -> ~/kxreus/eusmodels/<name>.l (MJCFのmodel属性を使用)
;;;
(require :kxrmodels)
(require :eus2native-collada) ;; dump-link-init-form等を再利用するため
(require :urdf2eus) ;; xml-tag-name/xml-find/parse-xml-attrs/parse-floats/
                     ;; path-dirname/join-strings/string-to-list等を再利用

(provide :mujoco2eus)

;; ---- <inertial>のfullinertia/diaginertia(+quat) -> 3x3行列 ----

(defun mjcf-inertia-matrix (attrs)
  (let ((full (xml-attr attrs "fullinertia"))
        (diag (xml-attr attrs "diaginertia"))
        (iquat (xml-attr attrs "quat" "1 0 0 0")))
    (cond
     (full
      (let* ((v (parse-floats full))
             (m (make-matrix 3 3)))
        (fvector-replace (array-entity m)
                          (float-vector (kgm2-2-gmm2 (nth 0 v)) (kgm2-2-gmm2 (nth 3 v)) (kgm2-2-gmm2 (nth 4 v))
                                        (kgm2-2-gmm2 (nth 3 v)) (kgm2-2-gmm2 (nth 1 v)) (kgm2-2-gmm2 (nth 5 v))
                                        (kgm2-2-gmm2 (nth 4 v)) (kgm2-2-gmm2 (nth 5 v)) (kgm2-2-gmm2 (nth 2 v))))
        m))
     (diag
      (let* ((v (parse-floats diag))
             (d (make-matrix 3 3))
             (q (apply #'float-vector (parse-floats iquat)))
             (r (quaternion2matrix q)))
        (fvector-replace (array-entity d)
                          (float-vector (kgm2-2-gmm2 (nth 0 v)) 0.0 0.0
                                        0.0 (kgm2-2-gmm2 (nth 1 v)) 0.0
                                        0.0 0.0 (kgm2-2-gmm2 (nth 2 v))))
        ;; I_world = R * D * R^T (主軸系->body系)
        (m* r (m* d (transpose r)))))
     (t (make-matrix 3 3)))))

;; ---- <asset>のmesh名->ファイルパスの対応 ----

(defun mjcf-file-basename-noext (path)
  ;; <mesh>にname属性が無い場合、MuJoCoの規約でfileのbasename
  ;; (拡張子抜き)がそのままmesh名になる。
  (let* ((parts (string-to-list path #\/))
         (fname (car (last parts)))
         (dotparts (string-to-list fname #\.)))
    (if (> (length dotparts) 1)
        (join-strings (butlast dotparts) ".")
      fname)))

;; ---- MJCFの色情報のparse ----
;;
;; <geom rgba="..."/>で直接指定される場合(Unitree G1/Booster K1の
;; ロボット本体のgeomはこの形式)と、<geom material="名前"/>で
;; <asset><material name="名前" rgba="..."/>を参照する場合の両方に
;; 対応する。
(defun mjcf-asset-material-alist (root-elem)
  (let ((asset (xml-find root-elem "asset")))
    (if asset
        (remove nil
                (mapcar #'(lambda (m)
                            (let* ((attrs (xml-tag-attrs m))
                                   (name (xml-attr attrs "name"))
                                   (rgba (xml-attr attrs "rgba")))
                              (and name rgba
                                   (cons name (apply #'float-vector (parse-floats rgba))))))
                        (xml-find-all asset "material")))
      nil)))

(defun mjcf-geom-color (geom material-alist)
  (and geom
       (let* ((attrs (xml-tag-attrs geom))
              (rgba (xml-attr attrs "rgba")))
         (cond (rgba (apply #'float-vector (parse-floats rgba)))
               ((xml-attr attrs "material")
                (cdr (assoc (xml-attr attrs "material") material-alist :test #'string=)))
               (t nil)))))

(defun mjcf-asset-mesh-alist (root-elem mesh-basedir)
  ;; <compiler meshdir="...">はmesh要素のfile属性の基準ディレクトリを
  ;; 変える(MuJoCoの規約)。URDFには無い概念なのでここだけ独自対応。
  (let* ((compiler (xml-find root-elem "compiler"))
         (meshdir (and compiler (xml-attr (xml-tag-attrs compiler) "meshdir")))
         (mesh-root (if meshdir (format nil "~A/~A" mesh-basedir meshdir) mesh-basedir))
         (asset (xml-find root-elem "asset")))
    (if asset
        (mapcar #'(lambda (m)
                    (let* ((attrs (xml-tag-attrs m))
                           (file (xml-attr attrs "file"))
                           (name (xml-attr attrs "name" (mjcf-file-basename-noext file))))
                      (cons name (resolve-mesh-path file mesh-root))))
                (xml-find-all asset "mesh"))
      nil)))

;; ---- <body>1個ぶんの情報 ----

(defclass mjcf-body-info :super propertied-object
  :slots (name pos-coords mass centroid inertia mesh-file geom-origin color
          joint-name joint-type joint-axis joint-lower joint-upper))

(defun mjcf-body-pos-coords (attrs)
  (let* ((pos (if (xml-attr attrs "pos")
                  (m2mm-vec (apply #'float-vector (parse-floats (xml-attr attrs "pos"))))
                #f(0 0 0)))
         (quat (xml-attr attrs "quat"))
         (euler (xml-attr attrs "euler"))
         (rot (cond (quat (quaternion2matrix (apply #'float-vector (parse-floats quat))))
                    (euler (let ((e (parse-floats euler)))
                             ;; MuJoCoの既定eulerseq="xyz"(内因性)を想定
                             (rpy-matrix (nth 2 e) (nth 1 e) (nth 0 e))))
                    (t (unit-matrix 3)))))
    (make-coords :pos pos :rot rot)))

;; ---- 木構造の再帰parse ----
;;
;; parent-abs-coords: 親body(無ければルート=identity)の絶対
;; (ルート相対)coords。返り値は (list body-info-list joint-info-list)
;; を子孫すべて含めてflattenしたもの。

(defun parse-mjcf-body (elem parent-abs-coords mesh-alist mesh-basedir &optional (material-alist nil))
  (let* ((attrs (xml-tag-attrs elem))
         (name (xml-attr attrs "name"))
         (rel-coords (mjcf-body-pos-coords attrs))
         (abs-coords (send (send parent-abs-coords :copy-worldcoords) :transform rel-coords :local))
         (inertial (xml-find elem "inertial"))
         (mass (if inertial (read-from-string (xml-attr (xml-tag-attrs inertial) "mass" "0")) 0.0))
         (centroid (if inertial
                       (m2mm-vec (apply #'float-vector (parse-floats (xml-attr (xml-tag-attrs inertial) "pos" "0 0 0"))))
                     #f(0 0 0)))
         (inertia (if inertial (mjcf-inertia-matrix (xml-tag-attrs inertial)) (make-matrix 3 3)))
         (geom (xml-find elem "geom"))
         (mesh-name (and geom (xml-attr (xml-tag-attrs geom) "mesh")))
         (mesh-file (and mesh-name (cdr (assoc mesh-name mesh-alist :test #'string=))))
         ;; <geom>自身のpos/quat: メッシュ自体がbodyフレームからずれて
         ;; 配置されている場合に指定される(urdf2eus.lの<visual><origin>
         ;; と同種。実機確認済みの同種バグ: これを無視すると、そのbody
         ;; の運動学的な位置は正しいのに、見た目のメッシュだけ別の場所に
         ;; ずれて表示される)。
         (geom-origin (if geom (mjcf-body-pos-coords (xml-tag-attrs geom)) (make-coords)))
         (color (mjcf-geom-color geom material-alist))
         (joint-elem0 (xml-find elem "joint"))
         (bi (instance mjcf-body-info))
         ;; type="free"(6dof浮遊ベース)はrotational-joint/linear-joint
         ;; どちらでも表現できないため、jointが無い(ルートと同様)扱いに
         ;; する。ベース自身の絶対位置は:transformで直接書き込むので
         ;; 情報は失われない。
         (joint-elem (and joint-elem0
                          (not (string= (xml-attr (xml-tag-attrs joint-elem0) "type" "hinge") "free"))
                          joint-elem0)))
    (setq (bi . name) name (bi . pos-coords) abs-coords
          (bi . mass) (kg2g mass) (bi . centroid) centroid (bi . inertia) inertia
          (bi . mesh-file) mesh-file (bi . geom-origin) geom-origin (bi . color) color)
    ;; linear-jointに相当する概念が無いため、そのリンクは(rootと同様)
    ;; joint無しのリンクとして扱う(free jointの担うベースの6dofは
    ;; そもそも:transformで直接絶対位置を書き込んでいるので情報は失われ
    ;; ない、可動関節としての表現だけを省略する)。
    (when joint-elem
      (let ((jattrs (xml-tag-attrs joint-elem)))
        (setq (bi . joint-name) (xml-attr jattrs "name")
              (bi . joint-type) (xml-attr jattrs "type" "hinge")
              (bi . joint-axis) (apply #'float-vector (parse-floats (xml-attr jattrs "axis" "1 0 0")))
              (bi . joint-lower) (nth 0 (parse-floats (xml-attr jattrs "range" "0 0")))
              (bi . joint-upper) (nth 1 (parse-floats (xml-attr jattrs "range" "0 0"))))))
    (let ((bodies (list bi)))
      (dolist (child (xml-find-all elem "body"))
        (setq bodies (append bodies (parse-mjcf-body child abs-coords mesh-alist mesh-basedir material-alist))))
      bodies)))

;; ---- メイン ----

(defun mujoco-to-native-collada-file (mjcf-path &key (outfile nil))
  (let* ((doc (tiny-xml::parse (strip-xml-comments-to-tmpfile mjcf-path)))
         (root-elem (if (string= (xml-tag-name doc) "mujoco") doc (xml-find doc "mujoco")))
         (name-str (xml-attr (xml-tag-attrs root-elem) "model"))
         (mesh-basedir (path-dirname mjcf-path))
         (mesh-alist (mjcf-asset-mesh-alist root-elem mesh-basedir))
         (material-alist (mjcf-asset-material-alist root-elem))
         (worldbody (xml-find root-elem "worldbody"))
         (root-body-elem (xml-find worldbody "body")))
    (let ((body-infos (parse-mjcf-body root-body-elem (make-coords) mesh-alist mesh-basedir material-alist)))
      ;; body-infosの先頭がルート。親子関係はXMLの入れ子構造そのものから
      ;; 再度たどる(parse-mjcf-bodyの戻り値だけでは親名の対応づけが
      ;; 複雑になるため、ここでは素直にelem木を再走査する)。
      (let* ((root-bi (car body-infos))
             (name-of-bi (mapcar #'(lambda (bi) (cons (bi . name) bi)) body-infos))
             ;; メッシュの実データ(faces)はbodyset-linkの:bodiesには
             ;; 入れない。geometry::faceset:initがedges/verticesの
             ;; remove-duplicatesを全faceの生データに対して行うため、
             ;; 数万三角形規模のメッシュで実質ハングする(urdf2eus.lで
             ;; 実機確認済み)。:bodiesは:assoc用の安価なmake-cubeで
             ;; 済ませる。また、全リンクぶんのfacesを事前に一括保持する
             ;; のも避ける(リンク数が多いロボットでGCが著しく遅くなる、
             ;; urdf2eus.lで実機確認済み)。最終出力ループでリンクごとに
             ;; その場でfacesを読む(name-of-bi経由でbi(mesh-fileを
             ;; 持つ)を引く)。
             (links (mapcar
                     #'(lambda (bi)
                         (let ((lk (instance bodyset-link :init (make-cascoords)
                                             :bodies (list (make-cube 10 10 10)) :name (bi . name))))
                           (send lk :weight (bi . mass))
                           (setq (lk . acentroid) (bi . centroid))
                           (setq (lk . inertia-tensor) (bi . inertia))
                           (send lk :transform (bi . pos-coords))
                           (cons (bi . name) lk)))
                     body-infos))
             (root-link (cdr (assoc (root-bi . name) links :test #'string=))))
        ;; ジョイントは、各body-infoが「自分を子とする関節情報」を
        ;; 持っている(MJCFの<joint>はbody要素の内側=そのbodyへの
        ;; incoming jointとして書かれる)ので、親はelem木の入れ子から
        ;; 直接たどる必要がある。ここではbody-infosの生成順(親が必ず
        ;; 子より先)を使い、各bi(ルート以外)についてXMLを再検索する
        ;; 代わりに、parse-mjcf-body時点でparent名を記録していないため
        ;; 単純化のため「1個上の要素」情報を別途集める。
        (let* ((joint-objs
                (remove nil
                        (mapcar
                         #'(lambda (bi)
                             (when (bi . joint-name)
                               (let* ((parent-name (find-mjcf-parent-name root-body-elem (bi . name)))
                                      (plink (cdr (assoc parent-name links :test #'string=)))
                                      (clink (cdr (assoc (bi . name) links :test #'string=)))
                                      (prismaticp (string= (bi . joint-type) "slide")))
                                 (if prismaticp
                                     (instance linear-joint :init
                                               :name (bi . joint-name) :parent-link plink :child-link clink
                                               :axis (bi . joint-axis)
                                               :min (m2mm (bi . joint-lower)) :max (m2mm (bi . joint-upper))
                                               :max-joint-velocity 1.0 :max-joint-torque 1.0)
                                   (instance rotational-joint :init
                                             :name (bi . joint-name) :parent-link plink :child-link clink
                                             :axis (bi . joint-axis)
                                             :min (rad2deg (bi . joint-lower)) :max (rad2deg (bi . joint-upper))
                                             :max-joint-velocity 1.0 :max-joint-torque 1.0))))
                             )
                         body-infos))))
          (unless outfile
            (rcb4eus-mkdir "eusmodels")
            (setq outfile (rcb4eus-file (format nil "eusmodels/~A.l" name-str))))
          (let ((classname (format nil "~A-robot" name-str))
                (all-links (mapcar #'cdr links)))
            (with-open-file
                (strm outfile :direction :output :if-exists :supersede)
              (format strm ";; auto-generated by mujoco2eus.l from ~A.~%" mjcf-path)
              (format strm ";; do not edit by hand; regenerate with~%")
              (format strm ";;   (mujoco-to-native-collada-file ~S)~%~%" mjcf-path)
              (format strm "(load ~S)~%~%" *euscollada-robot-lisp-file*)
              (format strm "(defun ~A () (instance ~A :init))~%~%" name-str classname)
              (format strm "(defclass ~A~%" classname)
              (format strm "  :super euscollada-robot~%")
              (format strm "  :slots (")
              (dolist (l all-links) (format strm "~A_lk " (eus-name-string l)))
              (dolist (j joint-objs) (format strm "~A_jt " (eus-name-string j)))
              (format strm "))~%~%")
              (format strm "(defmethod ~A~%" classname)
              (format strm "  (:init~%")
              (format strm "   (&rest args)~%")
              (format strm "   (send-super* :init args)~%")
              (dolist (l all-links) (dump-link-init-form strm l (make-coords)))
              (dump-link-assoc-forms strm joint-objs root-link)
              (dolist (j joint-objs) (dump-joint-init-form strm j))
              (format strm "     (setq links (list ")
              (dolist (l all-links) (format strm "~A_lk " (eus-name-string l)))
              (format strm "))~%")
              (format strm "     (setq joint-list (list ")
              (dolist (j joint-objs) (format strm "~A_jt " (eus-name-string j)))
              (format strm "))~%")
              (format strm "     (send self :init-ending)~%")
              (format strm "     self)~%")
              (dolist (j joint-objs)
                (format strm "  (:~A (&rest args) (forward-message-to ~A_jt args))~%"
                        (eus-name-string j) (eus-name-string j)))
              (dolist (l all-links)
                (format strm "  (:~A_lk (&rest args) (forward-message-to ~A_lk args))~%"
                        (eus-name-string l) (eus-name-string l)))
              (dump-generic-limb-accessors strm joint-objs)
              (dump-pose-methods strm joint-objs)
              (format strm "  )~%~%")
              (format strm "(defmethod ~A~%" classname)
              (dolist (l all-links)
                (let* ((lname (eus-name-string l))
                       (bi (cdr (assoc (send l :name) name-of-bi :test #'string=)))
                       (mesh-file (and bi (bi . mesh-file)))
                       (faces (and mesh-file (probe-file mesh-file)
                                   (read-link-mesh-faces-local
                                    (let ((li (instance urdf-link-info)))
                                      (setq (li . mesh-file) mesh-file) li)
                                    (if bi (bi . geom-origin) (make-coords)))))
                       ;; read-link-mesh-faces-localは既にリンク自身の
                       ;; ローカル座標系で焼き込み済みなので、ここでさらに
                       ;; :set-offset link-invを掛けるのは二重変換になる
                       ;; (urdf2eus.lで実機確認済みの同種バグ)。
                       (glv (if faces
                                (gl::make-glvertices-from-faces faces)
                              (gl::make-glvertices-from-faceset (make-cube 10 10 10)))))
                  (let ((bbox (send glv :calc-bounding-box))
                        (material (and bi (bi . color) (rgba-color-material (bi . color)))))
                    (dump-glvertices-geom-method strm lname (send bbox :center) (send bbox :diagonal) (list glv) material))
                  (setq faces nil)))
              (format strm "  )~%"))
            (format t ";; mujoco-to-native-collada-file: wrote ~A (~A links, ~A joints)~%"
                    outfile (length all-links) (length joint-objs))
            outfile))))))

;; body-nameを子として直接含む親<body>要素のname属性を返す(elem木を
;; 直接たどって探す。同名リンクが複数無い前提)。
(defun find-mjcf-parent-name (elem target-name &optional (parent-name nil))
  (dolist (child (xml-find-all elem "body"))
    (let ((cname (xml-attr (xml-tag-attrs child) "name")))
      (if (string= cname target-name)
          (return-from find-mjcf-parent-name (xml-attr (xml-tag-attrs elem) "name"))
        (let ((found (find-mjcf-parent-name child target-name)))
          (when found (return-from find-mjcf-parent-name found))))))
  nil)
