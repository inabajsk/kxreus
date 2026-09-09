;;;
;;; urdf2eus.l
;;;
;;; URDFファイル(+STLメッシュ)から、外部ツール(ROSのurdfパーサ等)を
;;; 一切使わず、直接eusmodels/*.l形式(euscollada-robotサブクラス)の
;;; EusLispファイルを生成する。eus2urdf.l(逆方向)と対になる。
;;;
;;; 実装方針: URDFをパースして得たリンク/ジョイントの情報から、実際に
;;; bodyset-link/rotational-joint(linear-joint)インスタンスを構築し、
;;; eus2native-collada.l(ネイティブロボットモデル -> eusmodels/*.l)の
;;; 既存の書き出し関数(dump-link-init-form/dump-link-assoc-forms/
;;; dump-joint-init-form)をそのまま再利用する。これにより出力フォーマット
;;; が完全に一致し、:look-all/:change-visual/:neutral等が同じように
;;; 動くeusmodels/*.lファイルが得られる。
;;;
;;; 単位変換(eus2urdf.lと逆方向、実機確認済みの換算式をそのまま反転):
;;;   長さ: URDFはm、kxreus内部はmm  -> *1000
;;;   質量: URDFはkg、kxreus内部はg  -> *1000
;;;   慣性テンソル: URDFはkg*m^2、kxreus内部はg*mm^2 -> *1e9
;;;   角度: URDFはラジアン、kxreus内部は度 -> rad2deg
;;;
;;; 使い方:
;;;   (require :urdf2eus)
;;;   (urdf-to-native-collada-file "eusurdf/kxrl2l2a6h2.urdf")
;;;   ;; -> ~/kxreus/eusmodels/<name>.l (URDFのrobot name属性を使用)
;;;
(require :kxrmodels)
(require :eus2native-collada) ;; dump-link-init-form等を再利用するため
(require :tiny-xml)

(provide :urdf2eus)

;; ---- 単位変換(eus2urdf.lの逆) ----

(defun m2mm (x) (* x 1000.0))
(defun m2mm-vec (v) (scale 1000.0 v))
(defun kg2g (x) (* x 1000.0))
(defun kgm2-2-gmm2 (x) (* x 1e9))

;; ---- XML属性文字列("key1=\"val1\" key2=\"val2 with space\"")のparse ----
;;
;; SolidWorksのURDFエクスポータ等が出力する整形済みXMLでは、1個のタグの
;; 中で属性ごとに改行+インデントされていることがよくある(実機確認済み:
;; Booster K1のURDFがこの形式で、区切りを半角スペースだけと想定していた
;; 元の実装では改行が属性名の一部に混入し、attrのlookupが全て失敗して
;; いた)。空白文字全般(スペース・タブ・改行・CR)を区切りとして扱う。
(defun xml-attr-ws-p (c)
  (or (eql c #\Space) (eql c #\Tab) (eql c #\Newline) (eql c 13)))

(defun parse-xml-attrs (s)
  (let ((result nil) (i 0) (n (length s)))
    (while (< i n)
      (while (and (< i n) (xml-attr-ws-p (elt s i))) (incf i))
      (when (< i n)
        (let ((key-start i))
          (while (and (< i n) (not (eql (elt s i) #\=))) (incf i))
          (let ((key (string-trim (list #\Space #\Tab #\Newline 13) (subseq s key-start i))))
            (incf i) ;; skip '='
            (when (and (< i n) (eql (elt s i) #\"))
              (incf i) ;; skip opening quote
              (let ((val-start i))
                (while (and (< i n) (not (eql (elt s i) #\"))) (incf i))
                (let ((val (subseq s val-start i)))
                  (incf i) ;; skip closing quote
                  (push (cons key val) result))))))))
    (nreverse result)))

(defun xml-attr (attrs key &optional default)
  (let ((c (assoc key attrs :test #'string=)))
    (if c (cdr c) default)))

(defun parse-floats (s)
  (with-input-from-string (in s)
    (let (result x)
      (while (not (eq (setq x (read in nil :eof)) :eof))
        (push (float x) result))
      (nreverse result))))

;; ---- tiny-xmlのparse結果からタグ名・属性・子要素を取り出す ----
;;
;; tiny-xml::parseは各要素を(tagspec child1 child2 ...)という入れ子リス
;; トで返す。tagspecは文字列(属性無し)か(タグ名 "属性文字列")のリスト。
;; 子要素はさらに同じ形の入れ子リストか、テキストの文字列。

(defun xml-tag-name (elem)
  (let ((tagspec (car elem)))
    (if (consp tagspec) (car tagspec) tagspec)))

(defun xml-tag-attrs (elem)
  (let ((tagspec (car elem)))
    (if (consp tagspec) (parse-xml-attrs (cadr tagspec)) nil)))

(defun xml-children (elem) (cdr elem))

(defun xml-find-all (elem tag)
  (remove-if-not #'(lambda (c) (and (consp c) (string= (xml-tag-name c) tag)))
                  (xml-children elem)))

(defun xml-find (elem tag)
  (car (xml-find-all elem tag)))

;; ---- URDFの<link>1個ぶんの情報 ----

(defclass urdf-link-info :super propertied-object
  :slots (name mesh-file mass centroid inertia visual-origin color))

;; ---- URDFの色情報(<material>)のparse ----
;;
;; URDFの<material>は2通りありうる: (a) <robot>直下でname+<color rgba=
;; .../>を定義しておき、各リンクの<visual><material name="..."/>で
;; 名前だけ参照する形式(Unitree G1で確認済み)、(b) <visual><material>
;; の中に直接<color rgba=.../>を書く形式。前者のため、<robot>直下の
;; <material>群を先にname->rgbaのalistとして集めておく必要がある。
(defun parse-urdf-materials (robot-elem)
  (let (alist)
    (dolist (m (xml-find-all robot-elem "material"))
      (let* ((mname (xml-attr (xml-tag-attrs m) "name"))
             (color-elem (xml-find m "color")))
        (when (and mname color-elem)
          (push (cons mname
                      (apply #'float-vector (parse-floats (xml-attr (xml-tag-attrs color-elem) "rgba" "0.8 0.8 0.8 1"))))
                alist))))
    alist))

(defun parse-urdf-link (elem mesh-basedir &optional (materials-alist nil))
  (let* ((name (xml-attr (xml-tag-attrs elem) "name"))
         (visual (xml-find elem "visual"))
         (geom (and visual (xml-find visual "geometry")))
         (mesh (and geom (xml-find geom "mesh")))
         (mesh-file (and mesh (xml-attr (xml-tag-attrs mesh) "filename")))
         (material-elem (and visual (xml-find visual "material")))
         (material-color-elem (and material-elem (xml-find material-elem "color")))
         (color (cond (material-color-elem
                       (apply #'float-vector (parse-floats (xml-attr (xml-tag-attrs material-color-elem) "rgba" "0.8 0.8 0.8 1"))))
                      ((and material-elem materials-alist)
                       (cdr (assoc (xml-attr (xml-tag-attrs material-elem) "name") materials-alist :test #'string=)))
                      (t nil)))
         ;; <visual><origin>: メッシュファイル自身のローカル座標系と
         ;; リンク自身の原点がずれている場合に指定される(実機確認済み:
         ;; RHP9のURDFで前腕・大腿部等、複数のリンクがこれを使っており、
         ;; 恒等変換のまま無視すると、そのリンクの運動学的な位置は
         ;; 正しいのに、見た目のメッシュだけ全く別の場所にずれて表示
         ;; されてしまっていた)。
         (visual-origin-elem (and visual (xml-find visual "origin")))
         (visual-origin (if visual-origin-elem
                             (make-coords
                              :pos (m2mm-vec (apply #'float-vector
                                                     (parse-floats (xml-attr (xml-tag-attrs visual-origin-elem) "xyz" "0 0 0"))))
                              :rot (let ((rpy (parse-floats (xml-attr (xml-tag-attrs visual-origin-elem) "rpy" "0 0 0"))))
                                     (rpy-matrix (nth 2 rpy) (nth 1 rpy) (nth 0 rpy))))
                           (make-coords)))
         (inertial (xml-find elem "inertial"))
         (mass-elem (and inertial (xml-find inertial "mass")))
         (origin-elem (and inertial (xml-find inertial "origin")))
         (inertia-elem (and inertial (xml-find inertial "inertia")))
         (mass (if mass-elem (read-from-string (xml-attr (xml-tag-attrs mass-elem) "value" "0")) 0.0))
         (centroid (if origin-elem
                       (m2mm-vec (apply #'float-vector (parse-floats (xml-attr (xml-tag-attrs origin-elem) "xyz" "0 0 0"))))
                     #f(0 0 0)))
         (ivals (if inertia-elem
                    (mapcar #'(lambda (k) (read-from-string (xml-attr (xml-tag-attrs inertia-elem) k "0")))
                            (list "ixx" "ixy" "ixz" "iyy" "iyz" "izz"))
                  (list 0 0 0 0 0 0)))
         (i (make-matrix 3 3)))
    (fvector-replace (array-entity i)
                      (float-vector (kgm2-2-gmm2 (nth 0 ivals)) (kgm2-2-gmm2 (nth 1 ivals)) (kgm2-2-gmm2 (nth 2 ivals))
                                    (kgm2-2-gmm2 (nth 1 ivals)) (kgm2-2-gmm2 (nth 3 ivals)) (kgm2-2-gmm2 (nth 4 ivals))
                                    (kgm2-2-gmm2 (nth 2 ivals)) (kgm2-2-gmm2 (nth 4 ivals)) (kgm2-2-gmm2 (nth 5 ivals))))
    (let ((li (instance urdf-link-info)))
      (setq (li . name) name
            (li . mesh-file) (and mesh-file (resolve-mesh-path mesh-file mesh-basedir))
            (li . mass) (kg2g mass)
            (li . centroid) centroid
            (li . inertia) i
            (li . visual-origin) visual-origin
            (li . color) color)
      li)))

;; URDFのmesh filenameは"meshes/foo.stl"(URDF自身からの相対パス、
;; eus2urdf.lの出力形式)か、"package://パッケージ名/相対パス"
;; (ROSパッケージ相対、他ツール由来のURDFでよく使われる)のどちらか
;; がありうる。後者は、ROSパッケージ解決の複雑さには踏み込まず、
;; パッケージ名の部分を捨ててURDF自身のディレクトリからの相対パス
;; として扱うベストエフォートの実装とする。
(defun join-strings (lst sep)
  (if (null lst) ""
    (reduce #'(lambda (a b) (concatenate string a sep b)) lst)))

(defun resolve-mesh-path (mesh-file mesh-basedir)
  (let ((rel (if (and (>= (length mesh-file) 10) (string= (subseq mesh-file 0 10) "package://"))
                 (join-strings (cdr (string-to-list (subseq mesh-file 10) #\/)) "/")
               mesh-file)))
    (format nil "~A/~A" mesh-basedir rel)))

;; 文字列を区切り文字でリストに分割(URDFのmesh filename、
;; "package://pkg/meshes/foo.stl"や"meshes/foo.stl"からファイル名
;; だけ取り出すために使う)。
(defun string-to-list (s ch)
  (let (result (start 0))
    (dotimes (i (length s))
      (when (eql (elt s i) ch)
        (push (subseq s start i) result)
        (setq start (+ i 1))))
    (push (subseq s start) result)
    (nreverse result)))

;; ---- URDFの<joint>1個ぶんの情報 ----

(defclass urdf-joint-info :super propertied-object
  :slots (name type parent child xyz rpy axis lower upper effort velocity))

(defun parse-urdf-joint (elem)
  (let* ((attrs (xml-tag-attrs elem))
         (name (xml-attr attrs "name"))
         (type (xml-attr attrs "type"))
         (parent (xml-attr (xml-tag-attrs (xml-find elem "parent")) "link"))
         (child (xml-attr (xml-tag-attrs (xml-find elem "child")) "link"))
         (origin (xml-find elem "origin"))
         (xyz (if origin (apply #'float-vector (parse-floats (xml-attr (xml-tag-attrs origin) "xyz" "0 0 0"))) #f(0 0 0)))
         (rpy (if origin (parse-floats (xml-attr (xml-tag-attrs origin) "rpy" "0 0 0")) (list 0.0 0.0 0.0)))
         (axis-elem (xml-find elem "axis"))
         (axis (if axis-elem (apply #'float-vector (parse-floats (xml-attr (xml-tag-attrs axis-elem) "xyz" "1 0 0"))) #f(1 0 0)))
         (limit (xml-find elem "limit"))
         (lower (if limit (read-from-string (xml-attr (xml-tag-attrs limit) "lower" "0")) 0.0))
         (upper (if limit (read-from-string (xml-attr (xml-tag-attrs limit) "upper" "0")) 0.0))
         (effort (if limit (read-from-string (xml-attr (xml-tag-attrs limit) "effort" "1")) 1.0))
         (velocity (if limit (read-from-string (xml-attr (xml-tag-attrs limit) "velocity" "1")) 1.0)))
    (let ((ji (instance urdf-joint-info)))
      (setq (ji . name) name (ji . type) type (ji . parent) parent (ji . child) child
            (ji . xyz) xyz (ji . rpy) rpy (ji . axis) axis
            (ji . lower) lower (ji . upper) upper (ji . effort) effort (ji . velocity) velocity)
      ji)))

;; ---- ジョイントのorigin(xyz/rpy) -> coordsオブジェクト ----

(defun urdf-joint-origin-coords (ji)
  (make-coords :pos (m2mm-vec (ji . xyz))
               :rot (rpy-matrix (nth 2 (ji . rpy)) (nth 1 (ji . rpy)) (nth 0 (ji . rpy)))))

;; ---- ルートリンク名(どのjointの子にもなっていないリンク)を探す ----

(defun urdf-root-link-name (link-infos joint-infos)
  (let ((child-names (mapcar #'(lambda (j) (j . child)) joint-infos)))
    (dolist (li link-infos)
      (unless (member (li . name) child-names :test #'string=)
        (return-from urdf-root-link-name (li . name))))
    (error "urdf2eus: root link not found (every link appears as some joint's child)")))

;; ---- メッシュ(STL)読み込み ----
;;
;; STLファイル自体はURDFの<visual><origin>基準のローカル座標(通常は
;; identity、eus2urdf.lの出力はそう)。ここでvisual-origin-coordsだけを
;; 適用し、リンク自身のローカル座標系にとどめる(絶対worldcoordsへは
;; 変換しない)。
;;
;; 重要: 絶対worldcoords(abs-coords)まで変換してしまうと、後で
;; bodyset-link(このfacesetをbodiesに持つ)へ:transform abs-coordsを
;; 呼んだ時に、facesetが「生きた」cascaded-coords(:worldcoordsが
;; 変わるたびに:update->:reset-verticesで頂点を再計算する)であるため、
;; 既に絶対座標へ焼き込み済みの頂点にabs-coordsがもう一度適用されて
;; しまい、二重変換になる(実機確認済みの重大バグ、キネマティックチェーン
;; の深さに比例して誤差が増大する形で現れた)。頂点はリンク自身のローカル
;; 座標のまま渡し、bodyset-linkの:transformで初めて絶対位置になるように
;; する(eus2native-collada.lの:set-offsetによる焼き込みと同じ原理)。
(defun read-link-mesh-faces-local (li visual-origin-coords)
  (unless (li . mesh-file) (return-from read-link-mesh-faces-local nil))
  (unless (probe-file (li . mesh-file))
    (warning-message 1 "urdf2eus: mesh file not found: ~A (skipping)~%" (li . mesh-file))
    (return-from read-link-mesh-faces-local nil))
  (let ((local-faces (geometry::stl-make-faces (li . mesh-file) :scale 1000)))
    (mapcar
     #'(lambda (f)
         (instance geometry::face :init :vertices
                   (mapcar #'(lambda (v) (send visual-origin-coords :transform-vector v))
                           (send f :vertices))))
     local-faces)))

;; ---- XMLコメントの除去(tiny-xml::parseに渡す前の前処理) ----
;;
;; tiny-xml.l(xml-read2)のコメント処理は"<!--"で始まるタグを1個の
;; 葉ノードとして扱うだけで、"-->"までを正しく読み飛ばすわけではない
;; (実機確認済み)。そのため、コメントの中にタグらしき文字列(URDFでは
;; よく「mujoco変換時はここのコメントを外す」という参考コード片が
;; コメントとして書かれている、実際にUnitree G1のURDFで遭遇)が
;; 含まれていると、コメントの中身まで本物のタグとして誤ってparseされて
;; しまう。ここで"<!--"から最初の"-->"までを機械的に取り除いた一時
;; ファイルを作り、それをtiny-xml::parseに渡す。
(defun strip-xml-comments-to-tmpfile (path)
  ;; 1文字ずつstring concatenateすると(EusLispのstringはimmutableで
  ;; 毎回コピーが発生するため)O(n^2)になり数万文字のファイルで
  ;; 極端に遅くなる(実機確認済み、24KB程度のURDFで数分以上かかり
  ;; 実質ハング)。かわりに、非コメント部分を"チャンク"(部分文字列)の
  ;; リストとして集め、最後に一度だけ結合する(O(n))。
  ;; 注意: (string #\Newline)は使わないこと。このEusLispでは#\Newline
  ;; などの文字リテラルがcharacter型ではなく単なる整数として扱われて
  ;; おり、(string <整数>)はその10進表記の文字列("10")を返してしまう
  ;; (実機確認済み: このバグにより改行が全て文字列"10"に化けており、
  ;; SolidWorks製URDF(Booster K1)のようにタグの属性が複数行に渡る
  ;; ファイルで、"10"がタグの内側に紛れ込んでタグ名・属性名を破壊して
  ;; いた)。(coerce (list 10) string)は同じ改行コードを正しく1文字の
  ;; 文字列に変換できる(tiny-xml.lのxml-file::eofが使っているのと同じ
  ;; 手法)。
  (let* ((text (with-open-file (f path :direction :input)
                 (let ((lines nil) line)
                   (while (setq line (read-line f nil))
                     (push line lines) (push (coerce (list 10) string) lines))
                   (tiny-xml::concat-strings-safe (nreverse lines)))))
         (chunks nil) (i 0) (chunk-start 0) (n (length text)))
    (while (< i n)
      (if (and (<= (+ i 4) n) (string= (subseq text i (+ i 4)) "<!--"))
          (let ((e (+ i 4)) (found nil))
            (when (> i chunk-start) (push (subseq text chunk-start i) chunks))
            (while (and (not found) (<= (+ e 3) n))
              (if (string= (subseq text e (+ e 3)) "-->")
                  (progn (setq i (+ e 3)) (setq found t))
                (incf e)))
            (unless found (setq i n))
            (setq chunk-start i))
        (incf i)))
    (when (> n chunk-start) (push (subseq text chunk-start n) chunks))
    (let ((tmpfile (format nil "/tmp/urdf2eus-nocomment-~A.xml" (unix::getpid))))
      (with-open-file (f tmpfile :direction :output :if-exists :supersede)
        (princ (tiny-xml::concat-strings-safe (nreverse chunks)) f))
      tmpfile)))

;; ---- メイン ----

(defun path-dirname (path)
  ;; unix::dirnameに相当するものがEusLispに見当たらず、positionも
  ;; :from-endキーワードを受け付けない(実機確認済み)ため、自前で
  ;; 最後の"/"を探す。無ければカレントディレクトリ"."を返す。
  (let ((p nil))
    (dotimes (i (length path))
      (when (eql (elt path i) #\/) (setq p i)))
    (if p (subseq path 0 p) ".")))

(defun urdf-to-native-collada-file (urdf-path &key (outfile nil))
  (let* ((doc (tiny-xml::parse (strip-xml-comments-to-tmpfile urdf-path)))
         (robot-elem (if (string= (xml-tag-name doc) "robot") doc (xml-find doc "robot")))
         (name-str (xml-attr (xml-tag-attrs robot-elem) "name"))
         (mesh-basedir (path-dirname urdf-path))
         (link-elems (xml-find-all robot-elem "link"))
         (joint-elems (xml-find-all robot-elem "joint"))
         (materials-alist (parse-urdf-materials robot-elem))
         (link-infos (mapcar #'(lambda (e) (parse-urdf-link e mesh-basedir materials-alist)) link-elems))
         (joint-infos (mapcar #'parse-urdf-joint joint-elems))
         (root-name (urdf-root-link-name link-infos joint-infos))
         (abs-coords-alist (list (cons root-name (make-coords))))
         ;; 子->親joint の逆引き(1リンクにつき親は必ず1つ、URDFの木構造)
         (joint-of-child (mapcar #'(lambda (j) (cons (j . child) j)) joint-infos)))
    ;; 親から子へ順にたどれるよう、絶対coordsが未確定なリンクが無くなる
    ;; まで繰り返す(joint-elemsの記載順が親->子の順とは限らないため)。
    (let ((remaining (remove root-name (mapcar #'(lambda (li) (li . name)) link-infos) :test #'string=)))
      (while remaining
        (let ((progressed nil))
          (dolist (lname (copy-list remaining))
            (let* ((ji (cdr (assoc lname joint-of-child :test #'string=)))
                   (pcoords (and ji (cdr (assoc (ji . parent) abs-coords-alist :test #'string=)))))
              (when pcoords
                ;; :transformは破壊的(selfを直接書き換える)なので、
                ;; 親のabs-coordsを壊さないよう必ずcopy-worldcoordsして
                ;; から使う。
                (push (cons lname (send (send pcoords :copy-worldcoords)
                                         :transform (urdf-joint-origin-coords ji) :local))
                      abs-coords-alist)
                (setq remaining (remove lname remaining :test #'string=))
                (setq progressed t))))
          (unless progressed
            (error "urdf2eus: could not resolve link tree (missing parent or cycle) for ~A" remaining)))))
    ;; リンクごとにbodyset-linkインスタンスを構築(絶対=ルート相対coords
    ;; に直接:transformするので、実際の親子assocは不要。eus2native-
    ;; collada.lのdump-link-init-formはworldcoordsだけを見るため)。
    ;;
    ;; 注意: bodyset-linkの:bodiesには実メッシュのfaceset化(geometry::
    ;; faceset :init :faces ...)を使わない。faceset:initが
    ;; remove-duplicates(edges/vertices両方)を全faceの生データに対して
    ;; 行っており、これがO(n^2)(実質n^3に近い、apply #'append→
    ;; remove-duplicatesの組み合わせ)であるため、数万三角形規模の
    ;; メッシュ(市販ロボットの公式CADメッシュ等でよくある)で実質
    ;; ハングする(実機確認済み: 44658三角形のメッシュでfacesetの:init
    ;; だけで10分以上経っても終わらなかった)。:bodiesはbodyset-linkの
    ;; :init内の:assoc用に何か実体が要るだけなので安価なmake-cubeで
    ;; 済ませる。
    ;;
    ;; さらに、全リンクぶんのface生データを事前に(let*の束縛として)
    ;; 一括で保持するのも避ける。リンク数の多いロボット(20〜30リンク、
    ;; 各数万三角形)では全リンクぶんの生頂点データが同時にメモリ上に
    ;; 残り続け、GCが著しく遅くなることを実機確認済み(個々のメッシュは
    ;; 数十秒で終わるのに全体では数十分経っても完了しなかった)。かわりに
    ;; 最終出力ループ内でリンクごとにその場でfacesを読み、使い終わったら
    ;; (次のリンクに移る際にGC対象にできるよう)保持しない。
    (let* ((link-obj-alist
            (mapcar
             #'(lambda (li)
                 (let* ((abs-coords (cdr (assoc (li . name) abs-coords-alist :test #'string=)))
                        (lk (instance bodyset-link :init (make-cascoords)
                                      :bodies (list (make-cube 10 10 10)) :name (li . name))))
                   (send lk :weight (li . mass))
                   (setq (lk . acentroid) (li . centroid))
                   (setq (lk . inertia-tensor) (li . inertia))
                   (send lk :transform abs-coords)
                   (cons (li . name) lk)))
             link-infos))
           (links (mapcar #'(lambda (li) (cdr (assoc (li . name) link-obj-alist :test #'string=))) link-infos))
           (root-link (cdr (assoc root-name link-obj-alist :test #'string=)))
           (joints
            (mapcar
             #'(lambda (ji)
                 (let ((plink (cdr (assoc (ji . parent) link-obj-alist :test #'string=)))
                       (clink (cdr (assoc (ji . child) link-obj-alist :test #'string=)))
                       (prismaticp (string= (ji . type) "prismatic")))
                   ;; instanceはクラス名をマクロ展開時の文字通りのシンボル
                   ;; として要求する(変数に束縛したシンボルを渡しても
                   ;; 動かないことを実機確認済み)ため、型ごとに分岐する。
                   (if prismaticp
                       (instance linear-joint :init
                                 :name (ji . name) :parent-link plink :child-link clink
                                 :axis (ji . axis)
                                 :min (m2mm (ji . lower)) :max (m2mm (ji . upper))
                                 :max-joint-velocity (ji . velocity)
                                 :max-joint-torque (ji . effort))
                     (instance rotational-joint :init
                               :name (ji . name) :parent-link plink :child-link clink
                               :axis (ji . axis)
                               :min (rad2deg (ji . lower)) :max (rad2deg (ji . upper))
                               :max-joint-velocity (ji . velocity)
                               :max-joint-torque (ji . effort)))))
             joint-infos)))
      (unless outfile
        (rcb4eus-mkdir "eusmodels")
        (setq outfile (rcb4eus-file (format nil "eusmodels/~A.l" name-str))))
      (let ((classname (format nil "~A-robot" name-str)))
        (with-open-file
            (strm outfile :direction :output :if-exists :supersede)
          (format strm ";; auto-generated by urdf2eus.l from ~A.~%" urdf-path)
          (format strm ";; do not edit by hand; regenerate with~%")
          (format strm ";;   (urdf-to-native-collada-file ~S)~%~%" urdf-path)
          (format strm "(load ~S)~%~%" *euscollada-robot-lisp-file*)
          (format strm "(defun ~A () (instance ~A :init))~%~%" name-str classname)
          (format strm "(defclass ~A~%" classname)
          (format strm "  :super euscollada-robot~%")
          (format strm "  :slots (")
          (dolist (l links) (format strm "~A_lk " (eus-name-string l)))
          (dolist (j joints) (format strm "~A_jt " (eus-name-string j)))
          (format strm "))~%~%")
          (format strm "(defmethod ~A~%" classname)
          (format strm "  (:init~%")
          (format strm "   (&rest args)~%")
          (format strm "   (send-super* :init args)~%")
          (dolist (l links) (dump-link-init-form strm l (make-coords)))
          (dump-link-assoc-forms strm joints root-link)
          (dolist (j joints) (dump-joint-init-form strm j))
          (format strm "     (setq links (list ")
          (dolist (l links) (format strm "~A_lk " (eus-name-string l)))
          (format strm "))~%")
          (format strm "     (setq joint-list (list ")
          (dolist (j joints) (format strm "~A_jt " (eus-name-string j)))
          (format strm "))~%")
          (format strm "     (send self :init-ending)~%")
          (format strm "     self)~%")
          (dolist (j joints)
            (format strm "  (:~A (&rest args) (forward-message-to ~A_jt args))~%"
                    (eus-name-string j) (eus-name-string j)))
          (dolist (l links)
            (format strm "  (:~A_lk (&rest args) (forward-message-to ~A_lk args))~%"
                    (eus-name-string l) (eus-name-string l)))
          (dump-generic-limb-accessors strm joints)
          (dump-pose-methods strm joints)
          (format strm "  )~%~%")
          (format strm "(defmethod ~A~%" classname)
          (dolist (l links)
            (let* ((lname (eus-name-string l))
                   (li (find (send l :name) link-infos :key #'(lambda (x) (x . name)) :test #'string=))
                   ;; read-link-mesh-faces-localは既にリンク自身のローカル
                   ;; 座標系で焼き込み済み(visual-originのみ適用、絶対座標
                   ;; へは変換しない)なので、ここでさらに:set-offset
                   ;; link-invを掛けるのは二重変換になる(実機確認済みの
                   ;; バグ: head-neck-pの箱がZ=[-8,69](正しい、リンク相対)
                   ;; ではなくZ=[-126.5,-49.5](link-invが二重適用された
                   ;; 誤った位置)になっていた。サイズ(diagonal)は不変な
                   ;; ので個々のリンクの位置精度チェックでは検出できず、
                   ;; 集約bboxでのみ症状が出ていた)。
                   (faces (and li (read-link-mesh-faces-local li (li . visual-origin))))
                   (glv (if faces
                            (gl::make-glvertices-from-faces faces)
                          (gl::make-glvertices-from-faceset (make-cube 10 10 10)))))
              (let ((bbox (send glv :calc-bounding-box))
                    (material (and li (li . color) (rgba-color-material (li . color)))))
                (dump-glvertices-geom-method strm lname (send bbox :center) (send bbox :diagonal) (list glv) material))
              (setq faces nil)))
          (format strm "  )~%"))
        (format t ";; urdf-to-native-collada-file: wrote ~A (~A links, ~A joints)~%"
                outfile (length links) (length joints))
        outfile))))
