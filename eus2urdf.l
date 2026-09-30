;;;
;;; eus2urdf.l
;;;
;;; kxreusのネイティブbody-basedロボットモデル(make-kxr-robot :model nil)
;;; から、外部ツール(ROSのcollada_urdfパッケージ、rosrun collada_urdf
;;; collada_to_urdf等)を一切使わず、直接URDFファイル+STLメッシュを
;;; 生成する。eus2native-collada.l(EusLispモデルの直接生成)と対になる、
;;; URDF版。
;;;
;;; 単位系の変換(実機確認済み、torsoリンクの既存urdf/kxrl2l2a6h2.urdfの
;;; 値と厳密一致することを確認):
;;;   長さ: kxreus内部はmm、URDFはm  -> 1/1000
;;;   質量: kxreus内部はg、URDFはkg  -> 1/1000
;;;   慣性テンソル: kxreus内部はg*mm^2、URDFはkg*m^2 -> 1/1000 * 1/1000^2 = 1e-9
;;;   角度: kxreus内部は度、URDFはラジアン -> deg2rad
;;;
;;; 使い方:
;;;   (require :eus2urdf)
;;;   (native-robot-to-urdf-file "kxrl2l2a6h2")
;;;   ;; -> ~/kxreus/urdf/kxrl2l2a6h2.urdf
;;;   ;; -> ~/kxreus/urdf/meshes/kxrl2l2a6h2/<link>.stl (各リンク1個)
;;;
(require :kxrmodels)
;; write-stl-header/write-stl-faceはGEOMETRYパッケージにありexportされて
;; いない(exportされているのはstl2eus/eus2stlのみ)。irtstl.l自体は
;; 標準起動時に既にロード済み(実機確認)なので明示的なrequireは不要。

(provide :eus2urdf)

;; ---- 数値のXML属性値としての書式 ----
;;
;; EusLispのformatは~Fや~Eに幅指定が無いと直値("8F"等)をそのまま出力
;; してしまう(実機確認済みバグ)ため、必ず幅を指定した上で前後の
;; パディング空白を取り除く。
(defun fmt-f (x) (string-trim " " (format nil "~16,8F" (float x))))
(defun fmt-e (x) (string-trim " " (format nil "~16,8E" (float x))))

;; ---- 単位変換 ----

(defun mm2m (x) (* x 0.001))
(defun mm2m-vec (v) (scale 0.001 v))
(defun g2kg (x) (* x 0.001))
(defun gmm2-2-kgm2 (x) (* x 1e-9))

;; 回転行列 -> URDF roll-pitch-yaw(ラジアン、R = Rz(yaw)*Ry(pitch)*Rx(roll)、
;; ROS/URDFの標準的な外因性zyx規約)。matrix2rpyという名前の逆変換関数が
;; jskeus本体には見当たらなかった(rpy-matrixというRPY->行列の順方向のみ
;; 存在)ため、標準的な公式で自前実装する。
(defun matrix2rpy (mat)
  (let* ((r20 (aref mat 2 0))
         (pitch (asin (max -1.0 (min 1.0 (- r20))))))
    (if (< (abs (cos pitch)) 1e-6)
        ;; ジンバルロック(pitch = +-90度)。rollを0に固定してyawだけで表現。
        (list 0.0 pitch (atan2 (- (aref mat 0 1)) (aref mat 1 1)))
      (list (atan2 (aref mat 2 1) (aref mat 2 2))
            pitch
            (atan2 (aref mat 1 0) (aref mat 0 0))))))

;; kxrの一部ロボット構成(平行リンク機構等)では、別々のlink/joint
;; オブジェクトが同じ:nameを持つことがある(実機確認済み:
;; lleg6構成でlleg-crotch-rという名前のリンクが2個ある)。そのまま
;; defclassの:slotsに使うと同名シンボルが重複しmake-classがセグ
;; フォルトする。オブジェクトの同一性でメモ化し、名前が衝突した
;; 2個目以降には"_2"等の連番を付けて一意化する(同じオブジェクトに
;; 対する呼び出しは常に同じ名前を返す)。生成対象ロボットが変わる
;; 度に(reset-eus-name-string-table)でこの状態をリセットすること。
(defvar *eus-name-string-table* (make-hash-table :test #'eq))
(defvar *eus-name-string-used* nil)

(defun reset-eus-name-string-table ()
  (setq *eus-name-string-table* (make-hash-table :test #'eq))
  (setq *eus-name-string-used* nil))

(defun eus-name-string (obj)
  (or (gethash obj *eus-name-string-table*)
      (let* ((base (string-downcase (string (send obj :name))))
             (name base) (i 2))
        (while (member name *eus-name-string-used* :test #'string=)
          (setq name (format nil "~A_~A" base i))
          (incf i))
        (push name *eus-name-string-used*)
        (setf (gethash obj *eus-name-string-table*) name)
        name)))

;; ---- リンク1個ぶんのメッシュ(STL)書き出し ----
;;
;; eus2native-collada.lと同じ理由・同じ方式で、各kxr-bodyの詳細形状
;; (:glverticesがあればそれを優先、ネジ穴等の細部を含む)を集め、
;; リンク自身の絶対worldcoordsの逆変換で「リンク自身のローカル座標系」
;; に焼き直してから1個のfacesetにまとめてSTL出力する。URDFの<visual>/
;; <collision>の<origin>は恒等変換(0,0,0)のままで正しく表示できる
;; (メッシュ側に位置が焼き込み済みのため)。
(defun link-local-faces (link)
  (let ((link-inv (send (send link :worldcoords) :inverse-transformation))
        faces)
    (dolist (body (send link :bodies))
      (let* ((fine (and (find-method body :glvertices) (send body :glvertices)))
             (glv (if fine
                      (gl::make-glvertices-from-faces
                       (send fine :faces)
                       :material (send fine :get-meshinfo :material 0))
                    (gl::make-glvertices-from-faceset body))))
        (send glv :set-offset link-inv)
        (setq faces (append faces (send glv :faces)))))
    faces))

(defun dump-link-mesh-stl (link mesh-dir)
  (let* ((lname (eus-name-string link))
         (fname (format nil "~A/~A.stl" mesh-dir lname))
         (faces (link-local-faces link)))
    (with-open-file (f fname :direction :output :if-exists :supersede)
      (geometry::write-stl-header f (length faces))
      (dolist (face faces) (geometry::write-stl-face f face :scale 0.001)))
    fname))

;; ---- リンク1個ぶんの色(<material><color rgba=.../></material>)----
;;
;; ネイティブモデルのglverticesの:material(urdf2eus.l/mujoco2eus.lが
;; URDF/MJCFの色情報から設定したもの、あるいはkxreus独自モデルで元々
;; 設定されているもの)からdiffuse色を読み取る。STLメッシュ自体は色を
;; 持てないので、URDF側では別途<material>タグとして書き出す必要がある。
(defun link-material-rgba (link)
  ;; 実機確認済み: メッシュを持たないリンク(センサー取り付け点等)は
  ;; gl::make-glvertices-from-faceset (make-cube 10 10 10)のフォール
  ;; バックになり、jskeus自身が持つmake-cubeの既定マテリアルはalpha無し
  ;; の3要素(#f(0.65 0.65 0.65))になっている。4要素前提でalpha成分に
  ;; アクセスすると範囲外エラーになるため、無ければ1.0を補う。
  (let* ((body (car (send link :bodies)))
         (fine (and body (find-method body :glvertices) (send body :glvertices)))
         (material (and fine (send fine :get-meshinfo :material 0)))
         (diffuse (and material (cadr (assoc :diffuse material)))))
    (and diffuse
         (if (>= (length diffuse) 4)
             diffuse
           (float-vector (elt diffuse 0) (elt diffuse 1) (elt diffuse 2) 1.0)))))

;; ---- リンク1個ぶんの<link>要素 ----

(defun dump-urdf-link (strm link mesh-relpath)
  (let ((lname (eus-name-string link))
        (rgba (link-material-rgba link)))
    (format strm "  <link name=\"~A\">~%" lname)
    (format strm "    <visual>~%")
    (format strm "      <origin xyz=\"0 0 0\" rpy=\"0 0 0\"/>~%")
    (format strm "      <geometry><mesh filename=\"~A/~A.stl\" scale=\"1 1 1\"/></geometry>~%"
            mesh-relpath lname)
    (when rgba
      (format strm "      <material name=\"~A_material\"><color rgba=\"~A ~A ~A ~A\"/></material>~%"
              lname (fmt-f (elt rgba 0)) (fmt-f (elt rgba 1)) (fmt-f (elt rgba 2)) (fmt-f (elt rgba 3))))
    (format strm "    </visual>~%")
    (format strm "    <collision>~%")
    (format strm "      <origin xyz=\"0 0 0\" rpy=\"0 0 0\"/>~%")
    (format strm "      <geometry><mesh filename=\"~A/~A.stl\" scale=\"1 1 1\"/></geometry>~%"
            mesh-relpath lname)
    (format strm "    </collision>~%")
    (let* ((c (mm2m-vec (link . acentroid)))
           (i (link . inertia-tensor)))
      (format strm "    <inertial>~%")
      (format strm "      <mass value=\"~A\"/>~%" (fmt-f (g2kg (send link :weight))))
      (format strm "      <origin xyz=\"~A ~A ~A\" rpy=\"0 0 0\"/>~%"
              (fmt-f (elt c 0)) (fmt-f (elt c 1)) (fmt-f (elt c 2)))
      (format strm "      <inertia ixx=\"~A\" ixy=\"~A\" ixz=\"~A\" iyy=\"~A\" iyz=\"~A\" izz=\"~A\"/>~%"
              (fmt-e (gmm2-2-kgm2 (aref i 0 0))) (fmt-e (gmm2-2-kgm2 (aref i 0 1))) (fmt-e (gmm2-2-kgm2 (aref i 0 2)))
              (fmt-e (gmm2-2-kgm2 (aref i 1 1))) (fmt-e (gmm2-2-kgm2 (aref i 1 2))) (fmt-e (gmm2-2-kgm2 (aref i 2 2))))
      (format strm "    </inertial>~%"))
    (format strm "  </link>~%")))

;; ---- ジョイント1個ぶんの<joint>要素 ----
;;
;; URDFのjointの<origin>は「親リンク自身の座標系から見た子リンクの
;; 座標系への相対変換」(eus2native-collada.lのルート相対とは異なる
;; 規約)。ここだけ改めてparent_worldcoords^-1 * child_worldcoordsを
;; 計算する。
(defun urdf-joint-type (joint)
  (cond ((derivedp joint rotational-joint) "revolute")
        ((derivedp joint linear-joint) "prismatic")
        (t (error "eus2urdf: unsupported joint class ~A" (class joint)))))

(defun dump-urdf-joint (strm joint)
  (let* ((jname (eus-name-string joint))
         (pname (eus-name-string (send joint :parent-link)))
         (cname (eus-name-string (send joint :child-link)))
         (rel (send (send (send joint :parent-link) :worldcoords)
                    :transformation (send (send joint :child-link) :worldcoords)))
         (pos (mm2m-vec (send rel :worldpos)))
         (rpy (matrix2rpy (send rel :worldrot)))
         (axis (joint . axis))
         (rotationalp (derivedp joint rotational-joint)))
    (format strm "  <joint name=\"~A\" type=\"~A\">~%" jname (urdf-joint-type joint))
    (format strm "    <parent link=\"~A\"/>~%" pname)
    (format strm "    <child link=\"~A\"/>~%" cname)
    (format strm "    <origin xyz=\"~A ~A ~A\" rpy=\"~A ~A ~A\"/>~%"
            (fmt-f (elt pos 0)) (fmt-f (elt pos 1)) (fmt-f (elt pos 2))
            (fmt-f (elt rpy 0)) (fmt-f (elt rpy 1)) (fmt-f (elt rpy 2)))
    (format strm "    <axis xyz=\"~A ~A ~A\"/>~%" (fmt-f (elt axis 0)) (fmt-f (elt axis 1)) (fmt-f (elt axis 2)))
    ;; :min-angle/:max-angleは度なのでdeg2rad変換が必要(既存urdf/*.urdfの
    ;; 値と一致することを実機確認済み)。一方:max-joint-velocityは実機
    ;; 確認の結果、既にURDFがそのまま使える単位(rad/s相当)で入っており、
    ;; 変換すると既存urdf/*.urdfの値と食い違う。:max-joint-torqueは
    ;; 既存urdf/*.urdfの値と単位が一致しない(kgf*cm等の可能性があるが
    ;; 未特定)ため、eus2native-collada.lの他の値と同様、変換せずそのまま
    ;; 書き出す(TODO: 正しい単位・換算係数が判明したら直す)。
    (format strm "    <limit lower=\"~A\" upper=\"~A\" effort=\"~A\" velocity=\"~A\"/>~%"
            (fmt-f (if rotationalp (deg2rad (send joint :min-angle)) (mm2m (send joint :min-angle))))
            (fmt-f (if rotationalp (deg2rad (send joint :max-angle)) (mm2m (send joint :max-angle))))
            (fmt-f (send joint :max-joint-torque))
            (fmt-f (send joint :max-joint-velocity)))
    (format strm "  </joint>~%")))

;; ---- メイン ----

(defun native-robot-to-urdf-file
    (name-str &key (robot nil) (outfile nil) (mesh-dir nil))
  (reset-eus-name-string-table)
  (unless robot
    (setq robot (make-kxr-robot name-str :model nil :viewer nil :ri nil)))
  (when (find-method robot :neutral) (send robot :neutral))
  (unless outfile
    ;; "eusurdf"は今回のネイティブ(外部ツール不要)生成専用の出力先。
    ;; 既存の"urdf"(collada_urdf経由の外部ツール生成、参照用として
    ;; 温存)とは別ディレクトリにして上書きしないようにする。
    (rcb4eus-mkdir "eusurdf")
    (setq outfile (rcb4eus-file (format nil "eusurdf/~A.urdf" name-str))))
  (unless mesh-dir
    ;; rcb4eus-mkdirは非再帰(mkdir -p相当ではない)なので、各階層を
    ;; 順に作る。
    (rcb4eus-mkdir "eusurdf/meshes")
    (rcb4eus-mkdir (format nil "eusurdf/meshes/~A" name-str))
    (setq mesh-dir (rcb4eus-file (format nil "eusurdf/meshes/~A" name-str))))
  (let* ((links (send robot :links))
         (joints (send robot :joint-list)))
    (dolist (l links) (dump-link-mesh-stl l mesh-dir))
    (with-open-file (strm outfile :direction :output :if-exists :supersede)
      (format strm "<?xml version=\"1.0\"?>~%")
      (format strm "<!-- auto-generated by eus2urdf.l from a native robot-model. -->~%")
      (format strm "<!-- do not edit by hand; regenerate with (native-robot-to-urdf-file ~S) -->~%" name-str)
      (format strm "<robot name=\"~A\">~%" name-str)
      (dolist (l links) (dump-urdf-link strm l (format nil "meshes/~A" name-str)))
      (dolist (j joints) (dump-urdf-joint strm j))
      (format strm "</robot>~%"))
    (format t ";; native-robot-to-urdf-file: wrote ~A (~A links, ~A joints)~%"
            outfile (length links) (length joints))
    outfile))
