;;;
;;; vrml2eus.l
;;;
;;; OpenHRP3形式のVRML97(.wrl、Joint/Segment PROTOを使うロボット
;;; 記述、Kawasaki RHP9のvrml/RHP9main.wrl等)から、外部ツールを
;;; 一切使わずにeusmodels/*.l形式のEusLispファイルを生成する。
;;; urdf2eus.l/mujoco2eus.l/collada2eus.lと同じ設計方針。
;;;
;;; COLLADAと違い、この形式は1個のJoint/Segmentノードの中に位置
;;; (translation/rotation)・関節種別/軸/可動域(jointType/jointAxis/
;;; llimit/ulimit)・質量パラメータ(mass/centerOfMass/momentsOfInertia、
;;; フルの3x3テンソルがそのまま9値で書かれている)が直接埋め込まれて
;;; おり、COLLADAのkinematics_models/physics_models/articulated_systems
;;; のような別ライブラリ+ID相互参照の解決が不要(実機確認済み)。
;;; また実機確認済み: このファイル(18MB)の最長行はわずか191文字で、
;;; collada2eus.lで問題になった「1行が数十万文字」という事態は起きない
;;; (1頂点・1面ごとに改行されている)。そのためconcatenateのサイズ制限
;;; を心配する必要が無く、素直にトークン単位のパーサとして書ける。
;;;
;;; 使い方:
;;;   (require :vrml2eus)
;;;   (vrml-to-native-collada-file "path/to/robot.wrl")
;;;   ;; -> ~/kxreus/eusmodels/<Humanoidのname>.l
;;;
(require :kxrmodels)
(require :eus2native-collada) ;; dump-link-init-form等・rgba-color-materialを再利用
(require :urdf2eus) ;; m2mm/m2mm-vec/kg2g/kgm2-2-gmm2等の単位変換ヘルパーを再利用

(provide :vrml2eus)

;; ============================================================
;; トークナイザ
;; ============================================================
;;
;; VRML97は"{ } [ ] ,"が単独トークンになりうる以外は空白区切り。
;; #以降はコメントとして無視。文字列は"..."で囲まれる(中に空白を
;; 含みうる)。1行が最大でも数百文字程度なので、1行ぶんの結果を
;; リストに集めて最後にnreverseするだけの単純な方式で十分高速。
;; whitespace/区切り文字の判定リストをループ内で毎回consせず、定数として
;; 1回だけ作っておく(18MBのファイルを1文字ずつ処理するため、ループ内で
;; (list ...)を作るコストが無視できないほど積み上がる、実機確認済み)。
(defparameter *vrml-ws-chars* (list #\Space #\Tab #\Return))
(defparameter *vrml-bracket-chars* (list #\{ #\} #\[ #\] #\,))
(defparameter *vrml-delim-chars* (list #\Space #\Tab #\Return #\{ #\} #\[ #\] #\, #\#))

(defun vrml-tokenize-line (line toks)
  (let ((n (length line)) (i 0))
    (while (< i n)
      (let ((c (elt line i)))
        (cond
         ((eql c #\#) (setq i n)) ;; 行末までコメント
         ((member c *vrml-ws-chars*) (incf i))
         ((eql c #\") ;; 文字列リテラル
          (let ((j (1+ i)))
            (while (and (< j n) (not (eql (elt line j) #\"))) (incf j))
            (push (subseq line (1+ i) j) toks)
            (setq i (1+ j))))
         ((member c *vrml-bracket-chars*)
          ;; 実機確認済みのEusLisp仕様: (string c)は文字リテラルの10進
          ;; 文字コード文字列("91"等)を返してしまい、期待する1文字の
          ;; 文字列("["等)にならない((string #\Newline)が"10"を返す
          ;; のと同じ既知の仕様、このセッションで既発見)。
          ;; (coerce (list c) string)なら正しく1文字の文字列になる。
          (push (coerce (list c) string) toks)
          (incf i))
         (t
          (let ((j i))
            (while (and (< j n)
                        (not (member (elt line j) *vrml-delim-chars*)))
              (incf j))
            (push (subseq line i j) toks)
            (setq i j))))))
    toks))

(defun vrml-tokenize-file (path)
  (let (toks)
    (with-open-file (f path :direction :input)
      (let (line)
        (while (setq line (read-line f nil))
          (setq toks (vrml-tokenize-line line toks)))))
    (nreverse toks)))

;; ---- トークン列を消費しながら読むための簡易ストリーム ----
;; *vt*: 残りトークンのリスト(car側から1個ずつpopしていく)。
(defvar *vt* nil)
(defun vt-peek () (car *vt*))
(defun vt-next () (pop *vt*))
(defun vt-expect (tok)
  (let ((x (vt-next)))
    (unless (string= x tok) (error "vrml2eus: expected ~S but got ~S" tok x))))
;; 次のトークンが数値として読めるかどうかを判定して1個読む(MFFloat/
;; SFVec3f/SFRotation等の値はスペース区切りの数値の並びとして続く)。
(defun vt-number-p (s)
  (and s (> (length s) 0)
       (or (digit-char-p (elt s 0))
           (and (member (elt s 0) (list #\- #\+ #\.)) (> (length s) 1)))))
(defun vt-read-number () (read-from-string (vt-next)))
(defun vt-read-numbers-while ()
  (let (result)
    (while (vt-number-p (vt-peek)) (push (vt-read-number) result))
    (nreverse result)))

;; ============================================================
;; ジオメトリ(Shape/IndexedFaceSet)のparse
;; ============================================================
;;
;; 1個のSegmentの"children ["の中には、Transform{children[Shape{...}]}
;; が複数個並びうる(multi-mesh)。子Jointは無い(SegmentはJointを
;; 子に持たない、実機確認済み: 兄弟Jointは常に親Jointのchildrenの中で
;; Segmentと同階層)。
;;
;; 戻り値: (list faces-list rgba-or-nil) のリスト(Shape1個ぶんずつ)。
(defun parse-vrml-color (name)
  ;; "material Material {"を読んだ直後から呼ぶ。diffuseColorを拾う。
  (let (rgba)
    (vt-expect "{")
    (let ((depth 1))
      (while (> depth 0)
        (let ((tok (vt-next)))
          (cond
           ((string= tok "{") (incf depth))
           ((string= tok "}") (decf depth))
           ((string= tok "diffuseColor")
            (let ((vals (vt-read-numbers-while)))
              (setq rgba (float-vector (nth 0 vals) (nth 1 vals) (nth 2 vals) 1.0))))
           (t nil)))))
    rgba))

(defun parse-vrml-indexed-face-set ()
  ;; "geometry IndexedFaceSet {"の"{"を読んだ直後から呼ぶ。
  (let (points coord-index)
    (vt-expect "{")
    (let ((depth 1))
      (while (> depth 0)
        (let ((tok (vt-next)))
          (cond
           ((string= tok "{") (incf depth))
           ((string= tok "}") (decf depth))
           ((string= tok "[") nil)
           ((string= tok "]") nil)
           ((string= tok "point")
            ;; Coordinate { point [ x y z, x y z, ... ] } の
            ;; "Coordinate {"と"point ["をここでまとめて読み飛ばす。
            (vt-expect "[")
            (let (vals)
              (while (not (string= (vt-peek) "]"))
                (if (string= (vt-peek) ",") (vt-next) (push (vt-read-number) vals)))
              (vt-expect "]")
              (setq vals (nreverse vals))
              ;; (nth (* i 3) vals)をdotimes内で使うとO(n^2)になる
              ;; (頂点数が多いメッシュで致命的に遅い、実機確認済み)ので、
              ;; valsを1回だけ先頭から辿るpopで組み立てる。
              (let* ((n (/ (length vals) 3)) (arr (make-array n)) (rest vals))
                (dotimes (i n)
                  (let ((x (pop rest)) (y (pop rest)) (z (pop rest)))
                    ;; メッシュ頂点もtranslation等と同じくVRML上はメートル
                    ;; 単位なので、m2mm-vecでmmに変換する(実機確認済みの
                    ;; バグ: これを忘れると各パーツの当たり判定ボックスが
                    ;; ほぼ原点に潰れたサイズになる)。
                    (setf (aref arr i) (m2mm-vec (float-vector x y z)))))
                (setq points arr))))
           ((string= tok "coordIndex")
            (vt-expect "[")
            (let (vals)
              (while (not (string= (vt-peek) "]"))
                (if (string= (vt-peek) ",") (vt-next) (push (round (vt-read-number)) vals)))
              (vt-expect "]")
              (setq coord-index (nreverse vals))))
           (t nil)))))
    (values points coord-index)))

;; Shape{ appearance Appearance{material Material{...}} geometry
;; IndexedFaceSet{...} } の "{"を読んだ直後から呼ぶ。
(defun parse-vrml-shape ()
  (let (rgba points coord-index)
    (vt-expect "{")
    (let ((depth 1))
      (while (> depth 0)
        (let ((tok (vt-next)))
          (cond
           ((string= tok "{") (incf depth))
           ((string= tok "}") (decf depth))
           ((string= tok "material")
            (vt-next) ;; "Material"(ノード型名)を読み飛ばす
            (setq rgba (parse-vrml-color "material")))
           ((string= tok "IndexedFaceSet")
            ;; parse-vrml-indexed-face-set自身が"{"から対応する"}"まで
            ;; 内部で完結して消費するので、外側のdepthカウンタは変えない
            ;; (materialノードの扱いと同じ)。
            (multiple-value-bind (p ci) (parse-vrml-indexed-face-set)
              (setq points p) (setq coord-index ci)))
           (t nil)))))
    ;; coordIndexは"i1 i2 i3 -1"の4個区切り(三角形面、-1が区切り)。
    ;; RHP9main.wrlは全て三角形メッシュであることを実機確認済み。
    (let (faces)
      (when (and points coord-index)
        (do ((rest coord-index (cddddr rest)))
            ((null rest))
          (push (instance geometry::face :init :vertices
                          (list (aref points (nth 0 rest)) (aref points (nth 1 rest)) (aref points (nth 2 rest))))
                faces)))
      (list (nreverse faces) rgba))))

;; ---- 未知のノード(Sensor類等、質量・幾何とは無関係)を安全に
;; 読み飛ばす。次のトークンが"{"であることを期待し、対応する"}"までを
;; 消費する。 ----
(defun vrml-skip-braces ()
  (vt-expect "{")
  (let ((depth 1))
    (while (> depth 0)
      (let ((tok (vt-next)))
        (cond ((string= tok "{") (incf depth))
              ((string= tok "}") (decf depth))
              (t nil))))))

;; ============================================================
;; Segment 1個ぶんのparse(質量パラメータ+ジオメトリ)
;; ============================================================
;; 戻り値: (list name mass centerOfMass momentsOfInertia-9値 shapes)
;; nameはこのSegment自身の"DEF <name> Segment"の名前(=リンク名、
;; URDFの"..._LINK"相当)。shapesはparse-vrml-shapeの戻り値
;; (list faces rgba)のリスト。
(defun parse-vrml-segment (name)
  (let (mass com inertia shapes)
    (vt-expect "{")
    (let ((depth 1))
      (while (> depth 0)
        (let ((tok (vt-next)))
          (cond
           ((string= tok "{") (incf depth))
           ((string= tok "}") (decf depth))
           ((string= tok "[") nil)
           ((string= tok "]") nil)
           ((string= tok "mass") (setq mass (vt-read-number)))
           ((string= tok "centerOfMass") (setq com (apply #'float-vector (vt-read-numbers-while))))
           ((string= tok "momentsOfInertia")
            (vt-expect "[")
            (setq inertia (vt-read-numbers-while))
            (vt-expect "]"))
           ((string= tok "Shape") (push (parse-vrml-shape) shapes))
           (t nil)))))
    (list name (or mass 0.0) (or com #f(0 0 0)) inertia (nreverse shapes))))

;; ============================================================
;; jointAxis("X"/"Y"/"Z")を軸ベクトルに変換
;; ============================================================
(defun vrml-joint-axis-vector (s)
  (cond ((string= s "X") #f(1 0 0))
        ((string= s "Y") #f(0 1 0))
        ((string= s "Z") #f(0 0 1))
        (t #f(1 0 0))))

;; ============================================================
;; Joint 1個ぶんのparse(再帰、子Joint(=次のリンク)も辿る)
;; ============================================================
;;
;; 戻り値: (list name translation-mm rotation-matrix joint-type-keyword
;;               axis-vector min max segment-info child-joint-results)
;; joint-type-keyword: :fixed/:free/:rotate/:slideのいずれか。
;; segment-infoはparse-vrml-segmentの戻り値(そのJointの直下、最初に
;; 現れるSegment1個ぶん。実機確認済み: 1 JointにつきSegmentは常に1個)。
;; child-joint-resultsはこのJointの子として現れる、後続のJointの
;; parse-vrml-joint結果のリスト(兄弟としてSegmentの後に並ぶ)。
(defun parse-vrml-joint (name)
  (let (translation (rotation (unit-matrix 3)) (jtype :fixed) (axis #f(1 0 0))
        (llimit nil) (ulimit nil) segment (children nil))
    (vt-expect "{")
    (let ((depth 1))
      (while (> depth 0)
        (let ((tok (vt-next)))
          (cond
           ((string= tok "{") (incf depth))
           ((string= tok "}") (decf depth))
           ((string= tok "[") nil)
           ((string= tok "]") nil)
           ((string= tok "translation") (setq translation (m2mm-vec (apply #'float-vector (vt-read-numbers-while)))))
           ((string= tok "rotation")
            (let ((vals (vt-read-numbers-while)))
              (setq rotation
                    (if (< (abs (nth 3 vals)) 1e-9)
                        (unit-matrix 3)
                      (matrix-exponent (scale (nth 3 vals) (float-vector (nth 0 vals) (nth 1 vals) (nth 2 vals))))))))
           ((string= tok "jointType")
            ;; トークナイザが文字列リテラルの引用符自体は取り除いている
            ;; ので、比較は引用符無しの生の値に対して行う。
            (let ((v (vt-next)))
              (setq jtype (cond ((string= v "rotate") :rotate)
                                 ((string= v "slide") :slide)
                                 ((string= v "free") :free)
                                 (t :fixed)))))
           ((string= tok "jointAxis") (setq axis (vrml-joint-axis-vector (vt-next))))
           ((string= tok "llimit") (vt-expect "[") (setq llimit (vt-read-numbers-while)) (vt-expect "]"))
           ((string= tok "ulimit") (vt-expect "[") (setq ulimit (vt-read-numbers-while)) (vt-expect "]"))
           ((string= tok "DEF")
            (let* ((child-name (vt-next)) (child-type (vt-next)))
              (cond
               ((string= child-type "Segment") (setq segment (parse-vrml-segment child-name)))
               ((string= child-type "Joint") (push (parse-vrml-joint child-name) children))
               (t (vrml-skip-braces)))))
           (t nil)))))
    (list name (or translation #f(0 0 0)) rotation jtype axis
          (car llimit) (car ulimit) segment (nreverse children))))

;; ============================================================
;; parse結果の木からbodyset-link/joint実体を組み立てる(再帰)
;; ============================================================
;;
;; jr: parse-vrml-jointの戻り値1個ぶん。
;; links-box/joints-box: (list nil)を渡す副作用用の入れ物。linksは
;; (cons lk shapes)のリストとして集める(shapesは後でgeometry書き出しに
;; 使う、(list faces rgba)のリストのリスト)。
;; jointType "free"(floating base、VRMLのWAIST相当)はjointオブジェクト
;; を作らず、その直下のSegmentがそのままルートリンクになる(urdf2eus.l/
;; mujoco2eus.lのfree/floating-base扱いと同じ)。
(defun vrml-build-tree (jr parent-abs-coords parent-link links-box joints-box)
  (let* ((jname (nth 0 jr)) (translation (nth 1 jr)) (rotation (nth 2 jr))
         (jtype (nth 3 jr)) (axis (nth 4 jr)) (jmin (nth 5 jr)) (jmax (nth 6 jr))
         (segment (nth 7 jr)) (children (nth 8 jr))
         (local-coords (make-coords :pos translation :rot rotation))
         (abs-coords (send (send parent-abs-coords :copy-worldcoords) :transform local-coords :local))
         (link-name (if segment (nth 0 segment) jname))
         (lk (instance bodyset-link :init (make-cascoords)
                        :bodies (list (make-cube 10 10 10)) :name link-name)))
    (when segment
      (let ((mass (nth 1 segment)) (com (nth 2 segment)) (inertia-vals (nth 3 segment)))
        (send lk :weight (kg2g mass))
        (setq (lk . acentroid) (m2mm-vec com))
        (when (and inertia-vals (= (length inertia-vals) 9))
          (let ((mat (make-matrix 3 3)))
            (fvector-replace (array-entity mat) (apply #'float-vector (mapcar #'kgm2-2-gmm2 inertia-vals)))
            (setq (lk . inertia-tensor) mat)))))
    (send lk :transform abs-coords)
    (push (cons lk (and segment (nth 4 segment))) (car links-box))
    (unless (eq jtype :free)
      (let ((prismaticp (eq jtype :slide)))
        (push
         (if prismaticp
             (instance linear-joint :init :name jname :parent-link parent-link :child-link lk
                       :axis axis :min (if jmin (m2mm jmin) 0.0) :max (if jmax (m2mm jmax) 0.0)
                       :max-joint-velocity 1.0 :max-joint-torque 1.0)
           (instance rotational-joint :init :name jname :parent-link parent-link :child-link lk
                     :axis axis :min (if jmin (rad2deg jmin) 0.0) :max (if jmax (rad2deg jmax) 0.0)
                     :max-joint-velocity 1.0 :max-joint-torque 1.0))
         (car joints-box))))
    (dolist (child children)
      (vrml-build-tree child abs-coords lk links-box joints-box))))

;; ============================================================
;; メイン
;; ============================================================
;;
;; "humanoidBody ["を目印にその中身だけを見る(PROTO定義・joints[...]
;; /segments[...]という冗長なUSE参照の一覧は無視してよい、実機確認済み)。
;;
;; 注意: ファイル先頭の"PROTO Humanoid [ ... exposedField MFNode
;; humanoidBody [ ] ... exposedField SFString name \"\" ... ]"という
;; フィールド宣言部にも"humanoidBody"/"name"という生トークンが出現する
;; (実データの"DEF <ROBOT> Humanoid { name ... humanoidBody [ ... }"
;; より手前にある)。単純にトークン一致だけで探すとこのPROTO宣言側に
;; ヒットしてしまう(実機確認済みのバグ)ので、まず"DEF" <name> "Humanoid"
;; という実インスタンス化パターンまで読み飛ばしてから、その中で
;; "name"/"humanoidBody"を探す。
(defun vrml-to-native-collada-file (wrl-path &key (outfile nil))
  (setq *vt* (vrml-tokenize-file wrl-path))
  (let (name-str)
    (while (and *vt*
                (not (and (string= (vt-peek) "DEF")
                          (>= (length *vt*) 3)
                          (string= (caddr *vt*) "Humanoid"))))
      (vt-next))
    (vt-expect "DEF")
    (vt-next) ;; ロボット名(nameフィールドと重複するので捨てる)
    (vt-expect "Humanoid")
    (vt-expect "{")
    (while (and *vt* (not (string= (vt-peek) "humanoidBody")))
      (let ((tok (vt-next))) (when (string= tok "name") (setq name-str (vt-peek)))))
    (vt-expect "humanoidBody")
    (vt-expect "[")
    (vt-expect "DEF")
    (let* ((root-name (vt-next)))
      (vt-expect "Joint")
      (let* ((root-jr (parse-vrml-joint root-name))
             (links-box (list nil)) (joints-box (list nil)))
        (vrml-build-tree root-jr (make-coords) nil links-box joints-box)
        (let* ((link-shapes (nreverse (car links-box)))
               (link-objs (mapcar #'car link-shapes))
               (root-link (car link-objs))
               (joints (nreverse (car joints-box))))
          (unless outfile
            (rcb4eus-mkdir "eusmodels")
            (setq outfile (rcb4eus-file (format nil "eusmodels/~A.l" name-str))))
          (let ((classname (format nil "~A-robot" name-str)))
            (with-open-file (strm outfile :direction :output :if-exists :supersede)
              (format strm ";; auto-generated by vrml2eus.l from ~A.~%" wrl-path)
              (format strm ";; do not edit by hand; regenerate with~%")
              (format strm ";;   (vrml-to-native-collada-file ~S)~%~%" wrl-path)
              (format strm "(load ~S)~%~%" *euscollada-robot-lisp-file*)
              (format strm "(defun ~A () (instance ~A :init))~%~%" name-str classname)
              (format strm "(defclass ~A~%" classname)
              (format strm "  :super euscollada-robot~%")
              (format strm "  :slots (")
              (dolist (l link-objs) (format strm "~A_lk " (eus-name-string l)))
              (dolist (j joints) (format strm "~A_jt " (eus-name-string j)))
              (format strm "))~%~%")
              (format strm "(defmethod ~A~%" classname)
              (format strm "  (:init~%")
              (format strm "   (&rest args)~%")
              (format strm "   (send-super* :init args)~%")
              (dolist (l link-objs) (dump-link-init-form strm l (make-coords)))
              (dump-link-assoc-forms strm joints root-link)
              (dolist (j joints) (dump-joint-init-form strm j))
              (format strm "     (setq links (list ")
              (dolist (l link-objs) (format strm "~A_lk " (eus-name-string l)))
              (format strm "))~%")
              (format strm "     (setq joint-list (list ")
              (dolist (j joints) (format strm "~A_jt " (eus-name-string j)))
              (format strm "))~%")
              (format strm "     (send self :init-ending)~%")
              (format strm "     self)~%")
              (dolist (j joints)
                (format strm "  (:~A (&rest args) (forward-message-to ~A_jt args))~%"
                        (eus-name-string j) (eus-name-string j)))
              (dolist (l link-objs)
                (format strm "  (:~A_lk (&rest args) (forward-message-to ~A_lk args))~%"
                        (eus-name-string l) (eus-name-string l)))
              (dump-generic-limb-accessors strm joints)
              (dump-pose-methods strm joints)
              (format strm "  )~%~%")
              (format strm "(defmethod ~A~%" classname)
              (dolist (ls link-shapes)
                (let* ((l (car ls)) (shapes (cdr ls))
                       (lname (eus-name-string l))
                       (faces (apply #'append (mapcar #'car shapes)))
                       (glv (if faces
                                (gl::make-glvertices-from-faces faces)
                              (gl::make-glvertices-from-faceset (make-cube 10 10 10))))
                       ;; 各shapesエントリは(faces-list rgba)という2要素の
                       ;; listなので、rgba本体を取り出すにはcdrではなく
                       ;; cadrが必要(cdrだと(rgba)という1要素listのままに
                       ;; なり、rgba-color-material内のeltでインデックス
                       ;; 範囲外エラーになる、実機確認済み)。
                       (rgba (cadr (find-if #'cadr shapes)))
                       (material (and rgba (rgba-color-material rgba))))
                  (let ((bbox (send glv :calc-bounding-box)))
                    (dump-glvertices-geom-method strm lname (send bbox :center) (send bbox :diagonal) (list glv) material))))
              (format strm "  )~%"))
            (format t ";; vrml-to-native-collada-file: wrote ~A (~A links, ~A joints)~%"
                    outfile (length link-objs) (length joints))
            outfile))))))
