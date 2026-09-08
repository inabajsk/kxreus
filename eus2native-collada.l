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

(defun dump-float (x strm)
  ;; EusLispのfloat-vector要素はsingle precision(C float)なので、
  ;; 9桁の有効数字があれば往復変換して情報が失われない
  ;; (実際に(format nil "~16,9E" ...) -> read-from-stringで往復確認済み)。
  (format strm "~16,9E" (float x)))

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
        (format strm "  (list~%")
        (format strm "   (list :type ")
        (dump-lisp-literal (send glv :get-meshinfo :type m) strm)
        (format strm ")~%")
        (format strm "   (list :material ")
        (dump-lisp-literal (send glv :get-meshinfo :material m) strm)
        (format strm ")~%")
        (format strm "   (list :indices ")
        (dump-lisp-literal (send glv :get-meshinfo :indices m) strm)
        (format strm ")~%")
        (format strm "   (list :vertices ")
        (dump-lisp-literal (send glv :get-meshinfo :vertices m) strm)
        (format strm ")~%")
        (format strm "   (list :normals ")
        (dump-lisp-literal (send glv :get-meshinfo :normals m) strm)
        (format strm "))~%"))))
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
