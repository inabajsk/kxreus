;;;
;;; eus2native-collada.l
;;;
;;; kxreus/models/<name>.l(euscollada-robotサブクラス)を、外部ツール
;;; (export-collada, collada2eus)を一切使わず、ネイティブの(:model nilで
;;; 作れる)robot-modelから直接生成する。
;;;
;;; ../eus2wrl.l の eus2collada-robot は
;;;   robot-model -> (eus2wrl)      -> .wrl
;;;               -> (export-collada, 外部バイナリ) -> .dae
;;;               -> (eus2yaml)     -> .yaml
;;;               -> (collada2eus, 外部バイナリ)     -> models/<name>.l
;;; という4段パイプラインを使うが、collada2eus.cpp(外部バイナリの実体)を
;;; 読むと、COLLADA XMLをパースしてそのままEusLispソースをfprintfして
;;; いるだけで特別な変換ロジックは無い。ネイティブのrobot-modelには
;;; 同じ情報(リンクのボディ形状・質量パラメータ・ジョイントの親子/軸/
;;; 可動域)が既に全て揃っているので、それを直接読み取って同じ形の
;;; EusLispソースを吐けば、wrl/dae/yaml/外部バイナリの4段はまるごと
;;; 不要になる。
;;;
;;; 使い方:
;;;   (require :eus2native-collada)
;;;   (native-robot-to-collada-file "kxrl2l2a6h2")
;;;   ;; -> ~/kxreus/models/kxrl2l2a6h2.l が生成される
;;;
(require :kxrmodels)

;; ROS環境(/opt/ros/*/share/euscollada/...)が無い環境でも動くよう、
;; euscollada-robot/collada-body等のクラス定義はkxreusリポジトリ内に
;; コピーしたeuscollada-robot-base.lを使う(ROSのeuscolladaパッケージは
;; 参照しない)。
(defparameter *euscollada-robot-lisp-file*
  (rcb4eus-file "euscollada-robot-base.l"))

(provide :eus2native-collada)

;; ---- 汎用EusLispリテラル書き出し ----
;; float-vector/integer-vector/matrix/keyword/list等を、そのまま読み込める
;; EusLispソース断片としてstrmへ書き出す。matrixだけは#m(...)のような
;; リテラル構文が無いため、models/*.l の既存生成ファイルと同じ
;; 「make-matrix + fvector-replace」のイディオムを使う。
;;
;; 注意: この関数群はすべて format(~%等のディレクティブを解釈する)を
;; 使うこと。princにformat文字列を渡すと"~%"がそのままの2文字として
;; 出力されてしまうバグを実機で確認済み(このファイルの最初の実装ミス)。

;; *dump-float-precision*が:shortの間は、メッシュの頂点・法線データ
;; だけ有効数字4桁(0.01mmオーダーの精度、見た目にも衝突判定にも
;; 十分)で書き出し、ファイルサイズを抑える。関節軸・:transform等の
;; 運動学的に重要な値は既定(:full, 9桁)のまま変えない。
(defvar *dump-float-precision* :full)

(defun dump-float (x strm)
  ;; EusLispのfloat-vector要素はsingle precision(C float)なので、
  ;; 9桁の有効数字があれば往復変換して情報が失われない
  ;; (実際に(format nil "~16,9E" ...) -> read-from-stringで往復確認済み)。
  (if (eq *dump-float-precision* :short)
      (format strm "~11,4E" (float x))
    (format strm "~16,9E" (float x))))

(defun eus-name-string (obj)
  ;; リンクの:nameは文字列、ジョイントの:nameはキーワード(大文字)を返す
  ;; ことを実機確認済み。どちらでも小文字の素の文字列に揃える。
  (string-downcase (string (send obj :name))))

(defun dump-lisp-literal (obj strm)
  (cond
   ((null obj) (format strm "nil"))
   ((eq obj t) (format strm "t"))
   ((keywordp obj) (format strm "~S" obj))
   ((integer-vector-p obj)
    (format strm "#i(")
    (dotimes (i (length obj)) (format strm " ~D" (elt obj i)))
    (format strm ")"))
   ((float-vector-p obj)
    (format strm "#f(")
    (dotimes (i (length obj)) (format strm " ") (dump-float (elt obj i) strm))
    (format strm ")"))
   ((matrixp obj)
    (format strm "(let ((mat (make-matrix ~D ~D))) (fvector-replace (array-entity mat) "
            (array-dimension obj 0) (array-dimension obj 1))
    (dump-lisp-literal (array-entity obj) strm)
    (format strm ") mat)"))
   ((stringp obj) (format strm "~S" obj))
   ((floatp obj) (dump-float obj strm))
   ((integerp obj) (format strm "~D" obj))
   ((numberp obj) (format strm "~A" obj))
   ((symbolp obj) (format strm "~S" obj))
   ((consp obj)
    (format strm "(list")
    (dolist (x obj) (format strm " ") (dump-lisp-literal x strm))
    (format strm ")"))
   (t (format strm "~S" obj))))

;; ---- リンク1個ぶんのcollision-proxy body(実体のあるfacesetボディ) ----
;;
;; models/*.l(collada2eus生成)は、各リンクのcollisionボディとして
;; qhull(凸包。faceの頂点を生成時にlocal-cds経由であらかじめ変換=焼き
;; 込み済み)をcollada-bodyで包んでいる。faceset/body(qhullやこの
;; boxの実クラス)の:verticesは:worldcoordsに応じて動的に再計算される
;; ことを実機確認済み(faceset:update -> :reset-vertices)。そのため
;; :look-all(全bodyの:vertices from draw-thingsでbboxを作る)が特別な
;; クラス変更なしに正しく動く。
;;
;; ここでは真の凸包計算(qhullアルゴリズム)は実装せず、同じ安全な原理
;; だけを再現する: リンク全bodyのbounding-box形状のfacesetを、頂点を
;; "生成時にあらかじめ計算した位置"で直接構築する(:locateで後から
;; 動かさない)。:locateを使うと、geomがまだ非identity座標のうちに
;; glvをassocすることになり、assocが「今の絶対位置を保つ」ように
;; glvへ補正オフセットを計算してしまい、後でgeomの祖先linkが
;; :transformで動いた時にその補正が破綻する
;; (過去に実機で確認した重大なバグ、meshが原点付近に潰れて見える
;; 症状だった。memory: feedback-eus2native-collada-regression参照)。
(defun box-corner (center half-dims sx sy sz)
  (float-vector (+ (elt center 0) (* sx (elt half-dims 0)))
                (+ (elt center 1) (* sy (elt half-dims 1)))
                (+ (elt center 2) (* sz (elt half-dims 2)))))

(defun dump-box-faceset-literal (strm bbox-center bbox-dims)
  (let* ((h (scale 0.5 bbox-dims))
         (c--- (box-corner bbox-center h -1 -1 -1))
         (c--+ (box-corner bbox-center h -1 -1  1))
         (c-+- (box-corner bbox-center h -1  1 -1))
         (c-++ (box-corner bbox-center h -1  1  1))
         (c+-- (box-corner bbox-center h  1 -1 -1))
         (c+-+ (box-corner bbox-center h  1 -1  1))
         (c++- (box-corner bbox-center h  1  1 -1))
         (c+++ (box-corner bbox-center h  1  1  1))
         (faces (list
                 (list c--- c--+ c-++ c-+-)   ;; -x
                 (list c+-- c++- c+++ c+-+)   ;; +x
                 (list c--- c+-- c+-+ c--+)   ;; -y
                 (list c-+- c-++ c+++ c++-)   ;; +y
                 (list c--- c-+- c++- c+--)   ;; -z
                 (list c--+ c+-+ c+++ c-++)))) ;; +z
    (format strm "(instance geometry::faceset :init :faces~%")
    (format strm "  (list~%")
    (dolist (f faces)
      (format strm "   (instance geometry::face :init :vertices (list")
      (dolist (v f) (format strm " ") (dump-lisp-literal v strm))
      (format strm "))~%"))
    (format strm "  ))~%")))

;; ---- 頂点の重複除去 ----
;;
;; gl::make-glvertices-from-faces(glvertices構築の共通経路、fine形状
;; からもbodyの自前faceからも常にこれを通る)は、三角形ごとに3頂点を
;; 独立して書き出すだけで、隣接三角形どうしの共有頂点をまとめる処理を
;; 一切しない(実装を読んで確認済み)。そのため:indicesは常に単純な
;; 0..3N-1の連番で、頂点・法線の行数は「ユニークな頂点数」ではなく
;; 「(三角形数)×3」になっている。実測(torsoのある1メッシュ)で
;; 3936行に対しユニークな頂点はわずか610個(6.45倍の重複)であり、
;; 生成ファイルサイズの大部分はここに由来する。頂点+法線のペアが完全に
;; 一致する行を1つにまとめ、:indicesをそのユニークな頂点を指す値に
;; 張り替えることで、見た目上のメッシュ(三角形数・形状)は一切変えず
;; ファイルサイズだけを大きく削減できる。
;; キーを(cons 頂点ベクタ 法線ベクタ)のまま:test #'equalのハッシュ
;; テーブルに渡すと、ベクタ(配列)内容に基づく適切なハッシュ値が得られず
;; (実機確認済み: 数万行規模の実在CADメッシュ(Unitree G1等)でハッシュが
;; ほぼ機能せず、事実上全エントリが同じバケツに落ちてremove-duplicates
;; 相当のO(n^2)スキャンになり、127296行のメッシュ1個で数分以上かかった)、
;; O(n^2)的に劣化する。文字列キー(formatでフォーマット)やsortベースの
;; 案も試したが、前者はformat呼び出し自体が遅く、後者はSTLの共有辺に
;; 由来する重複キーが大量にある実データでquicksortが劣化するらしく
;; (乱数の一意なデータでは速いのに、重複の多い実データでは同じ規模でも
;; 2分以上かかることを実機確認)、どちらも実用的な速度が出なかった。
;;
;; 最終的に、キーを「整数に丸めたリスト」(浮動小数点ベクタではなく、
;; 各要素をscale倍して丸めた整数のリスト)にすることで解決した。
;; EusLispの:test #'equalハッシュテーブルは、リスト(cons)キーに対しては
;; 内容ベースのハッシュが正しく機能する(実機確認済み: 127296行・
;; 重複あり実データ相当のテストで一瞬で完了)。整数への丸めは、STLの
;; 頂点が元々float32由来で有効数字が限られていること、かつ出力自体も
;; 短precision(~11,4E)でしか保存しないことを踏まえ、実用上十分な
;; 桁数(1e5倍)で行う。
;;
;; 注意: キーを組み立てる際、(concatenate list v nv)は使わないこと。
;; 中身は同じ6要素でも、user::c-matrix-rowが返すベクタに対して
;; concatenateを呼ぶと(elt個別アクセスは高速なのに)何らかの理由で
;; 極端に遅くなる(実機確認済み: 127296行のうち先頭2万行の処理だけで
;; 90秒以上かかり、事実上のボトルネックだった)。eltで1要素ずつ直接
;; 取り出してlistに組む方式なら同じ規模で1秒未満。
(defun mesh-dedupe-key (v nv)
  (list (round (* (elt v 0) 100000)) (round (* (elt v 1) 100000)) (round (* (elt v 2) 100000))
        (round (* (elt nv 0) 100000)) (round (* (elt nv 1) 100000)) (round (* (elt nv 2) 100000))))

(defun dedupe-mesh-arrays (verts-matrix norms-matrix)
  (let* ((n (array-dimension verts-matrix 0))
         (h (make-hash-table :test #'equal))
         (indices (instantiate integer-vector n))
         (vlist nil) (nlist nil) (cnt 0))
    (dotimes (i n)
      (let* ((v (user::c-matrix-row verts-matrix i))
             (nv (user::c-matrix-row norms-matrix i))
             (key (mesh-dedupe-key v nv))
             (existing (gethash key h)))
        (if existing
            (setf (elt indices i) existing)
          (progn
            (setf (gethash key h) cnt)
            (setf (elt indices i) cnt)
            (push v vlist) (push nv nlist)
            (incf cnt)))))
    (setq vlist (nreverse vlist) nlist (nreverse nlist))
    (let ((new-v (make-matrix cnt 3)) (new-n (make-matrix cnt 3)) (i 0))
      (dolist (v vlist) (user::c-matrix-row new-v i v t) (incf i))
      (setq i 0)
      (dolist (nv nlist) (user::c-matrix-row new-n i nv t) (incf i))
      (values new-v new-n indices))))

;; ---- リンク1個ぶんの、全bodyをまとめたglvertices(mesh-listを結合) ----
;;
;; models/*.lはリンクごとに1個の統合メッシュなので、それに合わせる。
;; kxr-bodyごとに材質(:material)が異なりうるので、1個のnative-
;; glverticesインスタンスの中にbodyの数だけmesh-list要素を持たせる形で
;; 結合し(材質は保持したまま)、オブジェクト数は1個にまとめる。
(defun dump-combined-glv-mesh-list-literal (strm glv-list)
  (format strm "(list~%")
  (dolist (glv glv-list)
    (let ((nmesh (length (send glv :get-meshinfo :type))))
      (dotimes (m nmesh)
        (multiple-value-bind (dedup-v dedup-n dedup-idx)
            (dedupe-mesh-arrays (send glv :get-meshinfo :vertices m)
                                 (send glv :get-meshinfo :normals m))
          (format strm "  (list~%")
          (format strm "   (list :type ")
          (dump-lisp-literal (send glv :get-meshinfo :type m) strm)
          (format strm ")~%")
          (format strm "   (list :material ")
          (dump-lisp-literal (send glv :get-meshinfo :material m) strm)
          (format strm ")~%")
          (format strm "   (list :indices ")
          (dump-lisp-literal dedup-idx strm)
          (format strm ")~%")
          (format strm "   (list :vertices ")
          (let ((*dump-float-precision* :short))
            (dump-lisp-literal dedup-v strm))
          (format strm ")~%")
          (format strm "   (list :normals ")
          (let ((*dump-float-precision* :short))
            (dump-lisp-literal dedup-n strm))
          (format strm "))~%")))))
  (format strm "  )~%"))

(defun dump-glvertices-geom-method (strm link-name bbox-center bbox-dims glv-list)
  (format strm "  (:_make_instance_~A_geom0 ()~%" link-name)
  (format strm "   (let* ((box ")
  (dump-box-faceset-literal strm bbox-center bbox-dims)
  (format strm "          )~%")
  (format strm "          (geom (instance collada-body :init :replace-obj box :name ~S))~%" link-name)
  (format strm "          (glv (instance native-glvertices :init~%")
  (format strm "               ")
  (dump-combined-glv-mesh-list-literal strm glv-list)
  (format strm "               )))~%")
  (format strm "     (setq (geom . gl::aglvertices) glv)~%")
  (format strm "     (send geom :assoc glv)~%")
  (format strm "     geom))~%"))

;; ---- リンク1個ぶんの:init本体(ジオメトリ生成 + bodyset-link + 質量
;; パラメータ + ワールド座標) ----

(defun dump-link-init-form (strm link root-coords)
  ;; euscollada-robot(既存のmodels/*.l)の慣習では、ルートリンクの位置を
  ;; 原点として、各リンクの:transformはルートからの相対座標で書く
  ;; (ネイティブrobot-modelの絶対worldcoordsをそのまま使うと、ルート
  ;; リンク自体が起立時の脚の高さぶんZにオフセットしており、実機確認の
  ;; 結果、既存ファイルとは全リンク一律にズレてしまうことが分かった)。
  (let* ((lname (eus-name-string link))
         (rel-coords (send root-coords :transformation (send link :worldcoords))))
    (format strm "     ;; link: ~A_lk~%" lname)
    (format strm "     (let ((geom-lst (list (send self :_make_instance_~A_geom0))))~%" lname)
    (format strm "       (setq ~A_lk (instance bodyset-link :init (make-cascoords)~%" lname)
    (format strm "                             :bodies geom-lst~%")
    (format strm "                             :name ~S))~%" lname)
    (format strm "       (send ~A_lk :weight " lname)
    (dump-lisp-literal (send link :weight) strm)
    (format strm ")~%")
    (format strm "       (setq (~A_lk . acentroid) " lname)
    (dump-lisp-literal (link . acentroid) strm)
    (format strm ")~%")
    (format strm "       (setq (~A_lk . inertia-tensor) " lname)
    (dump-lisp-literal (link . inertia-tensor) strm)
    (format strm ")~%")
    (format strm "       (send ~A_lk :transform " lname)
    (format strm "(make-coords :pos ")
    (dump-lisp-literal (send rel-coords :worldpos) strm)
    (format strm " :rot ")
    (dump-lisp-literal (send rel-coords :worldrot) strm)
    (format strm "))~%")
    (format strm "       )~%")))

;; ---- リンクの親子関係(cascaded-coordsのassoc) ----
;;
;; cascaded-link(robot-modelの親クラス)の:init-endingは、joint-listから
;; parent-link/child-linkの対応付け(:add-parent-link等)こそ行うが、これは
;; 単なる帳簿付けで、実際のcascaded-coordsの親子関係(:assoc)は一切張られ
;; ない(irtmodel.l確認済み)。そのため:assocを明示的に張らないと、各リンクは
;; 見かけ上正しい位置に静止表示されるだけの「バラバラな物体」のままで、
;; :angle-vectorで関節を動かしても子リンクが追従しない
;; (実機確認、kxrroboset1で発覚)。既存のcollada2eus生成ファイルは
;; joint-listのparent-link/child-linkの対に対して
;; (send parent_lk :assoc child_lk) を明示的に列挙しており、さらに最後に
;; (send self :assoc ルートリンク) でロボット自身にもルートリンクを
;; assocしている。この生成順序(全リンクの:transform確定 -> :assoc ->
;; joint生成)も既存ファイルに合わせる。joint :initが(send child-link
;; :copy-coords)でdefault-coords(ローカル座標)を記録するため、:assocで
;; 親が決まった後でjointを作らないとdefault-coordsが不正な値になる。
(defun dump-link-assoc-forms (strm joints root-link)
  (dolist (j joints)
    (format strm "     (send ~A_lk :assoc ~A_lk)~%"
            (eus-name-string (send j :parent-link))
            (eus-name-string (send j :child-link))))
  (format strm "     (send self :assoc ~A_lk)~%" (eus-name-string root-link)))

;; ---- リンク/腕/脚/頭ごとの姿勢リセットメソッド(:neutral等) ----
;;
;; 既存のcollada2eus生成ファイル(models/*.l)には:neutral/:reset-pose/
;; :reset-manip-poseがあり、いずれも同じ本体(:rarm/:larm/:rleg/:lleg/
;; :headの各関節を0にする)を持つ。実装は
;; `(send self limb :angle-vector (float-vector 0 ...))`という、
;; robot-model組み込みの汎用limb accessor(:rarm等、リンク名の
;; prefixから自動でlimbを構成する仕組み)を経由している。
;;
;; このrobot-model組み込みのlimb accessorを生成時にネイティブロボットへ
;; 試しに呼んでみたところ、:rarmは正しく高速に動くが:larmや:end-coords
;; など一部の呼び出しが数十秒単位でハングする現象を実機で確認した
;; (ネイティブのkxr-body構造がその探索アルゴリズムと相性が悪いと
;; 見られる。原因の完全な特定はしていない)。595体のロボットすべてを
;; バッチ生成する際にこれに依存するのは危険なので、生成時には一切
;; 使わない。代わりに、関節名のprefix("rarm-","larm-","rleg-",
;; "lleg-","head-")だけを見て生成時にlimbごとの関節リストを組み立て、
;; 生成される:neutral等の本体では各関節の:joint-angleを直接0にする
;; (:rarm等のlimb accessorには一切依存しない、実行時も安全)。
(defun limb-of-joint-name (name)
  (cond ((substringp "rarm-" name) :rarm)
        ((substringp "larm-" name) :larm)
        ((substringp "rleg-" name) :rleg)
        ((substringp "lleg-" name) :lleg)
        ((substringp "head-" name) :head)
        (t nil)))

(defun group-joints-by-limb (joints)
  ;; ((:rarm "rarm-shoulder-p" "rarm-shoulder-r" ...) (:larm ...) ...)
  ;; joint-listの元の順序を保ったまま、limbごとにまとめる。
  (let (alist)
    (dolist (j joints)
      (let* ((name (eus-name-string j))
             (limb (limb-of-joint-name name)))
        (when limb
          (let ((cell (assoc limb alist)))
            (if cell
                (setf (cdr cell) (append (cdr cell) (list name)))
              (push (list limb name) alist))))))
    (nreverse alist)))

(defun dump-pose-method (strm method-name docstring limb-groups)
  (format strm "  (:~A~%" method-name)
  (format strm "   (&optional (limbs '(")
  (dolist (g limb-groups) (format strm "~A " (car g)))
  (format strm ")))~%")
  (format strm "   ~S~%" docstring)
  (format strm "   (unless (listp limbs) (setq limbs (list limbs)))~%")
  (format strm "   (dolist (limb limbs)~%")
  (format strm "     (case limb~%")
  (dolist (g limb-groups)
    (format strm "       (~A " (car g))
    (dolist (jname (cdr g)) (format strm "(send self :~A :joint-angle 0) " jname))
    (format strm ")~%"))
  (format strm "       (t (format t \"Unknown limb is passed: ~~a~~%%\" limb))))~%")
  (format strm "   (send self :angle-vector))~%"))

(defun dump-pose-methods (strm joints)
  (let ((limb-groups (group-joints-by-limb joints)))
    (when limb-groups
      (dump-pose-method strm "reset-pose" "Predefined pose named reset-pose." limb-groups)
      (dump-pose-method strm "reset-manip-pose" "Predefined pose named reset-manip-pose." limb-groups)
      (dump-pose-method strm "neutral" "Predefined pose named neutral." limb-groups))))

;; ---- 汎用リムアクセサ(:larm-shoulder-p等)の自動生成 ----
;;
;; urdf2eus.l/mujoco2eus.lが読み込む実在ロボット(Unitree G1、Booster K1
;; 等)のjoint名は、そのロボット固有の英語表記("left_shoulder_pitch_
;; joint"等)であり、kxreus独自の"larm-shoulder-p"のような命名規則とは
;; 異なる。そのままでは:larm-shoulder-p等の呼び出しができないため、
;; 各jointの実際の名前に含まれるキーワード(shoulder/elbow/wrist/
;; hip/knee/ankle、left/right)と、そのjointの回転軸(x->roll、
;; y->pitch、z->yaw。Unitree G1・Booster K1の両方でこの対応を実データ
;; から確認済み)から、kxreus命名規則に沿ったエイリアスメソッドを機械的
;; に生成し、実体のjointへforward-message-toする。
(defun axis-dominant-rpy (axis)
  (let ((ax (abs (elt axis 0))) (ay (abs (elt axis 1))) (az (abs (elt axis 2))))
    (cond ((and (>= ax ay) (>= ax az)) "r")
          ((and (>= ay ax) (>= ay az)) "p")
          (t "y"))))

(defun limb-side-of-real-name (name)
  (cond ((substringp "left" name) "l")
        ((substringp "right" name) "r")
        (t nil)))

(defun limb-part-of-real-name (name)
  (cond ((substringp "shoulder" name) (cons "arm" "shoulder"))
        ((substringp "elbow" name) (cons "arm" "elbow"))
        ((substringp "wrist" name) (cons "arm" "wrist"))
        ((substringp "hip" name) (cons "leg" "crotch"))
        ((substringp "knee" name) (cons "leg" "knee"))
        ((substringp "ankle" name) (cons "leg" "ankle"))
        (t nil)))

(defun dump-generic-limb-accessors (strm joints)
  (let (seen)
    (dolist (j joints)
      (let* ((jname (eus-name-string j))
             (side (limb-side-of-real-name jname))
             (part (limb-part-of-real-name jname)))
        (when (and side part)
          (let ((method-name (format nil "~A~A-~A-~A" side (car part) (cdr part)
                                      (axis-dominant-rpy (j . axis)))))
            (if (member method-name seen :test #'string=)
                (warning-message 1 "eus2native-collada: duplicate generic accessor ~A (joint ~A), skipping~%"
                                  method-name jname)
              (progn
                (push method-name seen)
                (format strm "  (:~A (&rest args) (forward-message-to ~A_jt args))~%"
                        method-name jname)))))))))

;; ---- ジョイント1個ぶん ----

(defun joint-class-name (joint)
  (cond ((derivedp joint rotational-joint) "rotational-joint")
        ((derivedp joint linear-joint) "linear-joint")
        (t (error "eus2native-collada: unsupported joint class ~A" (class joint)))))

(defun dump-joint-init-form (strm joint)
  (let ((jname (eus-name-string joint)))
    (format strm "     ;; joint: ~A_jt~%" jname)
    (format strm "     (setq ~A_jt~%" jname)
    (format strm "           (instance ~A :init~%" (joint-class-name joint))
    (format strm "                     :name ~S~%" jname)
    (format strm "                     :parent-link ~A_lk :child-link ~A_lk~%"
            (eus-name-string (send joint :parent-link)) (eus-name-string (send joint :child-link)))
    (format strm "                     :axis ")
    (dump-lisp-literal (joint . axis) strm)
    (format strm "~%")
    (format strm "                     :min ")
    (dump-lisp-literal (send joint :min-angle) strm)
    (format strm " :max ")
    (dump-lisp-literal (send joint :max-angle) strm)
    (format strm "~%")
    (format strm "                     :max-joint-velocity ")
    (dump-lisp-literal (send joint :max-joint-velocity) strm)
    (format strm "~%")
    (format strm "                     :max-joint-torque ")
    (dump-lisp-literal (send joint :max-joint-torque) strm)
    (format strm "~%                     ))~%")))

;; ---- メイン ----

(defun native-robot-to-collada-file
    (name-str &key (robot nil) (outfile nil))
  (unless robot
    (setq robot (make-kxr-robot name-str :model nil :viewer nil :ri nil)))
  (unless outfile
    ;; "eusmodels"は今回のネイティブ生成専用の出力先(とりあえずの名前)。
    ;; 既存の外部ツール生成(collada2eus)が使う"models"とは別ディレクトリに
    ;; して、既存のmodels/*.lキャッシュを一切上書きしないようにする。
    (rcb4eus-mkdir "eusmodels")
    (setq outfile (rcb4eus-file (format nil "eusmodels/~A.l" name-str))))
  (let* ((links (send robot :links))
         (joints (send robot :joint-list))
         (root-coords (send (car links) :worldcoords))
         (classname (format nil "~A-robot" name-str)))
    (with-open-file
        (strm outfile :direction :output :if-exists :supersede)
      (format strm ";; auto-generated by eus2native-collada.l from a native robot-model.~%")
      (format strm ";; do not edit by hand; regenerate with~%")
      (format strm ";;   (native-robot-to-collada-file ~S)~%~%" name-str)
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
      (dolist (l links) (dump-link-init-form strm l root-coords))
      (dump-link-assoc-forms strm joints (car links))
      (dolist (j joints) (dump-joint-init-form strm j))
      (format strm "     (setq links (list ")
      (dolist (l links) (format strm "~A_lk " (eus-name-string l)))
      (format strm "))~%")
      (format strm "     (setq joint-list (list ")
      (dolist (j joints) (format strm "~A_jt " (eus-name-string j)))
      (format strm "))~%")
      (format strm "     (send self :init-ending)~%")
      (format strm "     self)~%")
      ;; 関節名アクセサ
      (dolist (j joints)
        (format strm "  (:~A (&rest args) (forward-message-to ~A_jt args))~%"
                (eus-name-string j) (eus-name-string j)))
      ;; リンク名アクセサ(models/*.lにあり、eusmodels/*.lに無かったもの)
      (dolist (l links)
        (format strm "  (:~A_lk (&rest args) (forward-message-to ~A_lk args))~%"
                (eus-name-string l) (eus-name-string l)))
      ;; :neutral/:reset-pose/:reset-manip-pose(models/*.lにあり、
      ;; eusmodels/*.lに無かったもの)
      (dump-pose-methods strm joints)
      (format strm "  )~%~%")
      ;; ジオメトリ生成メソッド本体
      ;;
      ;; models/*.l(collada2eus生成)と同じく、リンクごとに1個の
      ;; geom(collision-proxy bodyでラップ)にまとめる(以前はkxr-body
      ;; ごとに別々のnative-glverticesを作っていたが、models/*.lの構造
      ;; に合わせるようリクエストされ変更)。
      (format strm "(defmethod ~A~%" classname)
      (dolist (l links)
        (let* ((lname (eus-name-string l))
               (bodies (send l :bodies))
               ;; bodyの頂点はネイティブrobot-modelの絶対worldcoordsで
               ;; 焼き込まれている(gl::glverticesは「頂点データ」と
               ;; 「表示用coords」が別物で、:transformは頂点を動かさず
               ;; 見かけ上動かすだけ)。dump-link-init-formで:transformに
               ;; 与えるのはルート相対座標なので、そのままだと絶対座標+
               ;; ルート相対座標の二重適用になってリンクが飛び散る
               ;; (実機確認、kxrroboset1で発覚)。ここで頂点データ自体を
               ;; リンク相対(=リンクの絶対worldcoordsの逆変換)に焼き直す
               ;; ことで、後で:transformを掛けたときに正しい絶対位置に
               ;; 一致するようにする。
               (link-inv (send (send l :worldcoords) :inverse-transformation))
               (glv-list
                (mapcar
                 #'(lambda (body)
                     ;; kxr-bodyは、実際のCSG形状(:replace-obj)には
                     ;; *kxr-fine-body*に応じて簡略形状(sbod, ネジ穴等
                     ;; の細部を省いた高速衝突判定向け)か詳細形状(bod)
                     ;; のどちらかを使うが、描画用に:generate-
                     ;; glverticesで作るgl::aglvertices(:glverticesで
                     ;; アクセス可能)は常に詳細形状(bod、ネジ穴などの
                     ;; 細部を含む実機確認済み)から作られてキャッシュ
                     ;; されている(kxrbody.l)。bodyの自前形状(:faces)
                     ;; をそのまま使うと簡略形状になってしまう場合が
                     ;; あるため、詳細版があれば優先して使う。
                     (let* ((fine (and (find-method body :glvertices) (send body :glvertices)))
                            (glv (if fine
                                     (gl::make-glvertices-from-faces
                                      (send fine :faces)
                                      :material (send fine :get-meshinfo :material 0))
                                   (gl::make-glvertices-from-faceset body))))
                       (send glv :set-offset link-inv)
                       glv))
                 bodies))
               (all-points (flatten (mapcar #'(lambda (g) (send g :actual-vertices)) glv-list)))
               (bbox (geo::make-bounding-box all-points)))
          (dump-glvertices-geom-method
           strm lname (send bbox :center) (send bbox :diagonal) glv-list)))
      (format strm "  )~%"))
    (format t ";; native-robot-to-collada-file: wrote ~A (~A links, ~A joints)~%"
            outfile (length links) (length joints))
    outfile))
