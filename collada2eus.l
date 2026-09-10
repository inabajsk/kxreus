;;;
;;; collada2eus.l
;;;
;;; COLLADA(.dae、OpenHRP3 Collada Writerがvrmlから書き出す
;;; ロボティクスプロファイル形式)から、外部ツールを一切使わずに
;;; eusmodels/*.l形式のEusLispファイルを生成する。urdf2eus.l/
;;; mujoco2eus.lと対になる3つめの入力方向。
;;;
;;; 実装上の最大の注意点(実機確認済みの重大な制約):
;;; このファイル形式は1個のメッシュのposition/normal float_arrayが
;;; 1行で数十万〜100万文字規模になることがある(Kawasaki RHP9の
;;; 実データで確認)。このEusLisp(irteusgl)のconcatenateは、呼び出し
;;; 回数ではなく結合対象の文字列サイズに比例した深さで内部的に
;;; 再帰しているらしく、メガバイト級の文字列を巻き込むconcatenateは
;;; 呼び出し回数が2引数だけでもスタックオーバーフローする(実機確認済み:
;;; tiny-xml.lを素直に使うとこれで落ちる。ulimit -s unlimitedでも解消
;;; しない=OSレベルのCスタックではなくEusLisp処理系内部のスタックが
;;; 限界に達している)。
;;;
;;; そのため、このファイルではtiny-xml.l(全文を1つの文字列にまとめて
;;; からタグを読む方式)を一切使わず、行単位で読み進める専用のパーサを
;;; 新規に書く。position/subseq/read(with-input-from-stringでの
;;; ストリーム読み)は同規模の1行に対して問題なく動作することを実機
;;; 確認済みなので、複数行を絶対にconcatenateで結合しないという制約の
;;; 下で、1行ずつ状態機械的に処理する。
;;;
;;; 使い方:
;;;   (require :collada2eus)
;;;   (collada-to-native-collada-file "path/to/robot.dae")
;;;   ;; -> ~/kxreus/eusmodels/<COLLADAのvisual_scene rootノード名>.l
;;;
(require :kxrmodels)
(require :eus2native-collada) ;; dump-link-init-form等・rgba-color-materialを再利用
(require :urdf2eus) ;; path-dirname, m2mm-vec等の単位変換ヘルパーを再利用

(provide :collada2eus)

;; ---- 1行だけを対象にした軽量ヘルパー(巨大な1行には使わない) ----
;;
;; float_array/<p>の中身のような巨大な1行に対しては、絶対にこれらを
;; 使わない(subseq/positionは安全、concatenateだけが危険なので、
;; これらの関数自体はconcatenateを呼ばない限り安全だが、念のため
;; float_arrayの中身抽出は専用の固定オフセット方式(dae-tag-content)
;; を使う)。
(defun dae-str-find (needle haystack &optional (start 0))
  (let* ((nlen (length needle)) (hlen (length haystack)))
    (do ((i start (1+ i))) ((> (+ i nlen) hlen) nil)
      (when (string= needle (subseq haystack i (+ i nlen))) (return-from dae-str-find i)))))

;; line中の attr="value" を取り出す(shortな行専用)。
(defun dae-line-attr (line key)
  (let ((p (dae-str-find (format nil "~A=\"" key) line)))
    (when p
      (let* ((vstart (+ p (length key) 2))
             (vend (position #\" line :start vstart)))
        (and vend (subseq line vstart vend))))))

;; 開始タグの名前(例: "  <joint name=..." -> "joint")。行頭の空白と
;; "<"を読み飛ばし、次の空白/">"までを取り出す。
(defun dae-tag-name-of-line (line)
  (let ((p (position #\< line)))
    (and p
         (let* ((s (1+ p))
                (e s))
           (while (and (< e (length line))
                       (not (member (elt line e) (list #\Space #\Tab #\> #\/))))
             (incf e))
           (subseq line s e)))))

;; <tagname ...>DATA</tagname> がまるごと1行に収まっている場合の
;; DATA部分だけを取り出す(closetagは既知の固定文字列を渡す)。
;; concatenateを一切使わず、position(1文字)とsubseqだけで完結する。
(defun dae-tag-content (line closetag)
  (let ((gt (position #\> line))
        (clen (length closetag)))
    (and gt (subseq line (1+ gt) (- (length line) clen)))))

;; DATA文字列(スペース区切りの数値の並び)からfloatのリストを読む。
;; with-input-from-stringのストリーム読みはconcatenateを使わないので
;; 巨大な文字列に対しても安全(実機確認済み)。
(defun dae-parse-floats (s)
  (with-input-from-string (in s)
    (let (result x)
      (while (not (eq (setq x (read in nil :eof)) :eof))
        (push (float x) result))
      (nreverse result))))

(defun dae-parse-ints (s)
  (with-input-from-string (in s)
    (let (result x)
      (while (not (eq (setq x (read in nil :eof)) :eof))
        (push x result))
      (nreverse result))))

;; ---- COLLADAの<rotate>要素(axis-x axis-y axis-z angle-deg)を
;; 回転行列に変換する(Rodrigues公式) ----
(defun dae-rotate-vals-to-matrix (vals)
  (let ((ax (nth 0 vals)) (ay (nth 1 vals)) (az (nth 2 vals)) (deg (nth 3 vals)))
    (if (< (abs deg) 1e-9)
        (unit-matrix 3)
      (rotation-matrix (deg2rad deg) (normalize-vector (float-vector ax ay az))))))

;; ============================================================
;; パスA: library_visual_scenes を読み、ノード木を組み立てる
;; ============================================================
;;
;; 各ノードは (name parent-name local-coords joint-index geom-refs) を
;; 持つ。geom-refsは(geometry-id . material-id)のリスト(1ノードに
;; 複数のinstance_geometryがありうる)。local-coordsは、ノードが持つ
;; 全translate/rotate要素を出現順に合成したもの(親から見た相対座標)。
;; joint-indexは、sid="node_jointN_axis0"のNをそのまま使う(1始まり、
;; kinematics_modelの関節リストの何番目に対応するかを示すインデックス
;; として実機確認済み)。ルート(親を持たない最初のノード)はjoint-index
;; nilのまま。

;; frame = (list name parent-name coords joint-index geom-refs-reversed)
;; スタックの先頭(car frame-stack)が「今読んでいる行が属する、最も
;; 内側のノード」。<translate>/<rotate>/<instance_geometry>/
;; <instance_material>は、この先頭フレームだけを書き換える。
;; </node>で先頭フレームをpopしてnodesに確定登録する(このとき次の
;; frame-stack先頭が自動的に親フレームに戻るので、親の続きの行(次の
;; 兄弟instance_geometryや兄弟node)はそのまま親フレームに対して正しく
;; 積み上がる)。
(defun parse-dae-visual-scene (path)
  (let (nodes (frame-stack nil))
    (with-open-file (f path :direction :input)
      (let (line (in-vscene nil))
        (while (setq line (read-line f nil))
         ;; library_visual_scenesの中身に巨大な1行は現れない(巨大な
         ;; float_array/<p>はlibrary_geometriesだけ)。dae-str-findは
         ;; ナイーブなO(n*m)探索なので、無関係な巨大行に対して毎回
         ;; 呼んでしまうと(該当section外でも)極端に遅くなる。長さで
         ;; 早期に弾く。
         (when (< (length line) 1000)
          (cond
           ((dae-str-find "<library_visual_scenes" line) (setq in-vscene t))
           ((dae-str-find "</library_visual_scenes" line) (setq in-vscene nil))
           ((not in-vscene) nil)
           ((dae-str-find "<node " line)
            (let* ((name (dae-line-attr line "name"))
                   (parent-name (and frame-stack (nth 0 (car frame-stack)))))
              (push (list name parent-name (make-coords) nil nil) frame-stack)))
           ((dae-str-find "</node>" line)
            (when frame-stack
              (let ((frame (pop frame-stack)))
                (setf (nth 4 frame) (reverse (nth 4 frame)))
                (push frame nodes))))
           ((and frame-stack (dae-str-find "<translate" line))
            (let* ((closetag "</translate>")
                   (content (if (dae-str-find closetag line)
                                (dae-tag-content line closetag)
                              (subseq line (1+ (position #\> line)))))
                   (vals (dae-parse-floats content))
                   (sid (dae-line-attr line "sid"))
                   (frame (car frame-stack)))
              (setf (nth 2 frame) (send (nth 2 frame) :transform
                                         (make-coords :pos (m2mm-vec (apply #'float-vector vals))) :local))
              (when sid
                (let ((n (dae-str-find "node_joint" sid)))
                  (when n
                    (setf (nth 3 frame)
                          (read-from-string (subseq sid (+ n 10) (dae-str-find "_axis0" sid)))))))))
           ((and frame-stack (dae-str-find "<rotate" line))
            (let* ((closetag "</rotate>")
                   (content (if (dae-str-find closetag line)
                                (dae-tag-content line closetag)
                              (subseq line (1+ (position #\> line)))))
                   (vals (dae-parse-floats content))
                   (sid (dae-line-attr line "sid"))
                   (frame (car frame-stack)))
              (setf (nth 2 frame) (send (nth 2 frame) :transform
                                         (make-coords :rot (dae-rotate-vals-to-matrix vals)) :local))
              (when sid
                (let ((n (dae-str-find "node_joint" sid)))
                  (when n
                    (setf (nth 3 frame)
                          (read-from-string (subseq sid (+ n 10) (dae-str-find "_axis0" sid)))))))))
           ((and frame-stack (dae-str-find "<instance_geometry" line))
            (let ((url (dae-line-attr line "url")) (frame (car frame-stack)))
              (setf (nth 4 frame) (cons (cons (subseq url 1) nil) (nth 4 frame))))) ;; url="#g1_0_geom0" -> "g1_0_geom0"
           ((and frame-stack (dae-str-find "<instance_material" line))
            (let ((target (dae-line-attr line "target")) (frame (car frame-stack)))
              (when (nth 4 frame)
                (setf (cdr (car (nth 4 frame))) (subseq target 1)))))
           (t nil))))))
    (nreverse nodes)))

;; ============================================================
;; パスB: library_geometries を読み、geometry-id -> 三角形頂点リスト
;; (mm単位、各要素は(list v0 v1 v2)の3頂点)のハッシュテーブルを作る
;; ============================================================
;;
;; 法線はCOLLADA側のものを使わず、gl::make-glvertices-from-facesに
;; 三角形の頂点順序から計算させる(STL由来のメッシュと同じ扱い)。
;; そのため<p>の中の法線インデックス(offset 1)は読み捨てる。
;;
;; 1行が数十万〜100万文字になりうるposition/normalのfloat_arrayと
;; <p>の中身は、dae-tag-content(position/subseqのみ、concatenateは
;; 一切使わない)で安全に取り出す。

(defun parse-dae-geometries (path needed-ids)
  (let ((result (make-hash-table :test #'equal)))
    (with-open-file (f path :direction :input)
      (let (line (in-lib nil) (cur-id nil) (want nil)
            (cur-positions nil) (vertex-offset 0) (triangles nil))
        (while (setq line (read-line f nil))
          ;; float_array/<p>の中身は巨大(数十万〜100万文字)になりうるが、
          ;; どの種類の行かは常に先頭付近(タグ名+属性)だけで判別できる。
          ;; dae-str-findで行全体を毎回スキャンすると、巨大な1行1本
          ;; あたりだけでもO(行長)がかさむ(該当73本ぶん積み重なる)ため、
          ;; 種別判定は先頭200文字だけの部分文字列(prefix)に対して行う。
          (let ((prefix (if (> (length line) 200) (subseq line 0 200) line)))
            (cond
             ((dae-str-find "<library_geometries" prefix) (setq in-lib t))
             ((dae-str-find "</library_geometries" prefix) (setq in-lib nil))
             ((not in-lib) nil)
             ((dae-str-find "<geometry id=" prefix)
              (setq cur-id (dae-line-attr line "id"))
              (setq want (and (gethash cur-id needed-ids) t))
              (setq cur-positions nil) (setq vertex-offset 0) (setq triangles nil))
             ((and want (dae-str-find "<float_array" prefix) (dae-str-find "_positions-array" prefix))
              ;; 実機確認済みの重大バグ: (nth (* i 3) vals)をdotimesで
              ;; 回すとリスト長に比例した時間がかかるnthをn回呼ぶことに
              ;; なりO(n^2)になる(17000頂点規模で実質終わらない)。
              ;; popでリストを1回だけ順に消費するO(n)の方式に直す。
              (let* ((content (dae-tag-content line "</float_array>"))
                     (vals (dae-parse-floats content))
                     (n (/ (length vals) 3))
                     (arr (make-array n))
                     (rest vals))
                (dotimes (i n)
                  (let ((x (pop rest)) (y (pop rest)) (z (pop rest)))
                    (setf (aref arr i) (m2mm-vec (float-vector x y z)))))
                (setq cur-positions arr)))
             ((and want (dae-str-find "<input" prefix) (dae-str-find "VERTEX" prefix))
              (setq vertex-offset (read-from-string (dae-line-attr line "offset"))))
             ((and want (dae-str-find "<p>" prefix))
              (let* ((content (dae-tag-content line "</p>"))
                     (idxs (dae-parse-ints content))
                     ;; NORMALのinputも1個あるのでstride=2固定(実機確認済み:
                     ;; このファイルはVERTEX+NORMALの2 inputのみ、TEXCOORD無し)
                     (stride 2)
                     (nverts (/ (length idxs) stride))
                     (verts (make-array nverts))
                     (rest idxs))
                (dotimes (i nverts)
                  (let ((v (pop rest)) (nrm (pop rest)))
                    (setf (aref verts i) (aref cur-positions (if (= vertex-offset 0) v nrm)))))
                (dotimes (tri (/ nverts 3))
                  (push (list (aref verts (* tri 3)) (aref verts (+ 1 (* tri 3))) (aref verts (+ 2 (* tri 3))))
                        triangles))))
             ((dae-str-find "</geometry>" prefix)
              (when want
                (setf (gethash cur-id result) (nreverse triangles)))
              (setq cur-id nil) (setq want nil))
             (t nil))))))
    result))

;; ============================================================
;; パスC: library_materials + library_effects -> id(material) -> rgba
;; ============================================================
(defun parse-dae-materials (path)
  (let ((mat-to-effect (make-hash-table :test #'equal))
        (effect-to-rgba (make-hash-table :test #'equal))
        (result (make-hash-table :test #'equal)))
    (with-open-file (f path :direction :input)
      (let (line (in-lib nil) (cur-effect nil) (in-diffuse nil))
        (while (setq line (read-line f nil))
         (when (< (length line) 1000)
          (cond
           ((dae-str-find "<library_effects" line) (setq in-lib :effects))
           ((dae-str-find "</library_effects" line) (setq in-lib nil))
           ((dae-str-find "<library_materials" line) (setq in-lib :materials))
           ((dae-str-find "</library_materials" line) (setq in-lib nil))
           ((not in-lib) nil)
           ((and (eq in-lib :effects) (dae-str-find "<effect id=" line))
            (setq cur-effect (dae-line-attr line "id")) (setq in-diffuse nil))
           ((and (eq in-lib :effects) (dae-str-find "<diffuse>" line)) (setq in-diffuse t))
           ((and (eq in-lib :effects) in-diffuse (dae-str-find "<color>" line))
            (let* ((content (dae-tag-content line "</color>"))
                   (vals (dae-parse-floats content)))
              (setf (gethash cur-effect effect-to-rgba) (apply #'float-vector vals)))
            (setq in-diffuse nil))
           ((and (eq in-lib :materials) (dae-str-find "<material id=" line))
            (setq cur-effect (dae-line-attr line "id")))
           ((and (eq in-lib :materials) (dae-str-find "<instance_effect" line))
            (let* ((url (dae-line-attr line "url")) (eff (subseq url 1)))
              (setf (gethash cur-effect mat-to-effect) eff)))
           (t nil))))))
    (maphash #'(lambda (matid effid)
                 (let ((rgba (gethash effid effect-to-rgba)))
                   (when rgba (setf (gethash matid result) rgba))))
             mat-to-effect)
    result))

;; ============================================================
;; パスD: library_kinematics_models -> jointのリスト(ファイル出現順、
;; visual_sceneのnode_jointN_axis0のNとそのまま対応することを実機確認済み)
;; ============================================================
;; 各要素: (list name type axis min max)  type=:revolute/:prismatic
(defun parse-dae-kinematics-joints (path)
  (let (joints (in-lib nil) (cur-name nil) (cur-type nil) (cur-axis nil) (cur-min nil) (cur-max nil))
    (with-open-file (f path :direction :input)
      (let (line)
        (while (setq line (read-line f nil))
         (when (< (length line) 1000)
          (cond
           ((dae-str-find "<library_kinematics_models" line) (setq in-lib t))
           ((dae-str-find "</library_kinematics_models" line) (setq in-lib nil))
           ((not in-lib) nil)
           ((dae-str-find "<joint name=" line)
            (setq cur-name (dae-line-attr line "name")) (setq cur-axis nil) (setq cur-min nil) (setq cur-max nil))
           ((dae-str-find "<revolute" line) (setq cur-type :revolute))
           ((dae-str-find "<prismatic" line) (setq cur-type :prismatic))
           ((dae-str-find "<axis>" line)
            (setq cur-axis (apply #'float-vector (dae-parse-floats (dae-tag-content line "</axis>")))))
           ((dae-str-find "<min>" line)
            (setq cur-min (car (dae-parse-floats (dae-tag-content line "</min>")))))
           ((dae-str-find "<max>" line)
            (setq cur-max (car (dae-parse-floats (dae-tag-content line "</max>")))))
           ((dae-str-find "</joint>" line)
            (push (list cur-name cur-type cur-axis cur-min cur-max) joints))
           (t nil))))))
    (nreverse joints)))

;; ============================================================
;; パスE: library_physics_models -> rigid_body名(=link名) -> (mass
;; local-com-coords principal-inertia-vals)
;; ============================================================
;; mass_frameは2組のtranslate/rotateを持つが、実機確認済み(RHP9の
;; CHEST_Y_LINKでURDFの既知の正しい値と一致確認): 2組目がリンク自身の
;; ローカル座標系におけるCOM位置+主軸回転で、1組目は木構造上位からの
;; 累積オフセット(ノード自身の親相対位置と重複)であり不要。
(defun parse-dae-physics (path)
  (let ((result (make-hash-table :test #'equal))
        (in-lib nil) (cur-name nil) (cur-mass nil) (tr-list nil) (in-mass-frame nil) (cur-inertia nil))
    (with-open-file (f path :direction :input)
      (let (line)
        (while (setq line (read-line f nil))
         (when (< (length line) 1000)
          (cond
           ((dae-str-find "<library_physics_models" line) (setq in-lib t))
           ((dae-str-find "</library_physics_models" line) (setq in-lib nil))
           ((not in-lib) nil)
           ((dae-str-find "<rigid_body " line)
            (setq cur-name (dae-line-attr line "name")) (setq cur-mass nil) (setq tr-list nil) (setq in-mass-frame nil))
           ((dae-str-find "<mass>" line)
            (setq cur-mass (car (dae-parse-floats (dae-tag-content line "</mass>")))))
           ((dae-str-find "<mass_frame>" line) (setq in-mass-frame t) (setq tr-list nil))
           ((dae-str-find "</mass_frame>" line) (setq in-mass-frame nil))
           ((and in-mass-frame (dae-str-find "<translate>" line))
            (push (cons :t (dae-parse-floats (dae-tag-content line "</translate>"))) tr-list))
           ((and in-mass-frame (dae-str-find "<rotate>" line))
            (push (cons :r (dae-parse-floats (dae-tag-content line "</rotate>"))) tr-list))
           ((dae-str-find "<inertia>" line)
            (setq cur-inertia (apply #'float-vector (dae-parse-floats (dae-tag-content line "</inertia>")))))
           ((dae-str-find "</rigid_body>" line)
            (let* ((pairs (reverse tr-list))
                   ;; 2組目(後半)のtranslate/rotateがリンクローカルのCOM
                   (local-t (cdr (nth 2 pairs))) (local-r (cdr (nth 3 pairs))))
              (when (and cur-name cur-mass local-t)
                (setf (gethash cur-name result)
                      (list cur-mass
                            (make-coords :pos (m2mm-vec (apply #'float-vector local-t))
                                         :rot (if local-r (dae-rotate-vals-to-matrix local-r) (unit-matrix 3)))
                            cur-inertia)))))
           (t nil))))))
    result))

;; ============================================================
;; メイン: パスA〜Eを組み合わせてeusmodels/*.lを書き出す
;; ============================================================
;;
;; visual_sceneの一番外側のノード(実リンクではない、シーン全体の
;; ダミー、親を持たない唯一のノード)を除外し、その名前をロボット名に
;; 使う。残りのノードは、親名(parse-dae-visual-scene時点で記録済み)を
;; 使って絶対座標を積み上げ、joint-index(1始まり)でkinematics_modelの
;; 関節リストを直接indexして関節定義を引く(実機確認済みの対応関係)。
(defun collada-to-native-collada-file (dae-path &key (outfile nil))
  (reset-eus-name-string-table)
  (let* ((all-nodes (parse-dae-visual-scene dae-path))
         (scene-root (find-if #'(lambda (n) (null (nth 1 n))) all-nodes))
         (name-str (nth 0 scene-root))
         (needed-ids (make-hash-table :test #'equal)))
    (dolist (n all-nodes)
      (dolist (gr (nth 4 n)) (setf (gethash (car gr) needed-ids) t)))
    (let* ((geom-hash (parse-dae-geometries dae-path needed-ids))
           (mat-hash (parse-dae-materials dae-path))
           (joint-defs (parse-dae-kinematics-joints dae-path))
           (phys-hash (parse-dae-physics dae-path))
           (abs-coords-alist (list (cons name-str (make-coords)))))
      ;; ルート以外の各ノードのabs-coordsを親から積み上げる。
      ;;
      ;; 実機確認済みの重大バグ: all-nodesはparse-dae-visual-sceneが
      ;; </node>を見た順(depth-first「後行(post-order)」順)で積んで
      ;; おり、子ノードの方が親ノードより先にリストへ入る(親の</node>
      ;; は子の</node>より後にしか来ないため)。「必ず子より先に親が
      ;; 確定している」という前提は誤りで、そのまま1パスで処理すると
      ;; 親がまだabs-coords-alistに無く(send nil :copy-worldcoords)と
      ;; いう形でクラッシュする。urdf2eus.lの木構築と同じ、親が解決済み
      ;; のノードだけを繰り返し処理する方式に直す。
      (let ((remaining (remove name-str (mapcar #'(lambda (n) (nth 0 n)) all-nodes) :test #'string=)))
        (while remaining
          (let ((progressed nil))
            (dolist (name (copy-list remaining))
              (let* ((n (find name all-nodes :key #'(lambda (x) (nth 0 x)) :test #'string=))
                     (parent-name (nth 1 n))
                     (parent-cell (assoc parent-name abs-coords-alist :test #'string=)))
                (when parent-cell
                  (push (cons name (send (send (cdr parent-cell) :copy-worldcoords) :transform (nth 2 n) :local))
                        abs-coords-alist)
                  (setq remaining (remove name remaining :test #'string=))
                  (setq progressed t))))
            (unless progressed
              (error "collada2eus: could not resolve node tree (missing parent or cycle) for ~A" remaining)))))
      ;; ルートも含めた全ノードぶんbodyset-linkを作る(ルートの親関節は
      ;; 無いが、他のリンクの:parent-linkとして必要になる)。
      (let* ((link-obj-alist
              (mapcar
               #'(lambda (n)
                   (let* ((name (nth 0 n))
                          (phys (gethash name phys-hash))
                          (lk (instance bodyset-link :init (make-cascoords)
                                        :bodies (list (make-cube 10 10 10)) :name name)))
                     (when phys
                       (send lk :weight (kg2g (nth 0 phys)))
                       (setq (lk . acentroid) (send (nth 1 phys) :worldpos))
                       (let* ((rot (send (nth 1 phys) :worldrot))
                              (diag (nth 2 phys))
                              (dmat (make-matrix 3 3)))
                         (fvector-replace (array-entity dmat)
                                          (float-vector (kgm2-2-gmm2 (elt diag 0)) 0.0 0.0
                                                        0.0 (kgm2-2-gmm2 (elt diag 1)) 0.0
                                                        0.0 0.0 (kgm2-2-gmm2 (elt diag 2))))
                         (setq (lk . inertia-tensor) (m* (m* rot dmat) (transpose rot)))))
                     (send lk :transform (cdr (assoc name abs-coords-alist :test #'string=)))
                     (cons name lk)))
               all-nodes))
             (link-objs (mapcar #'(lambda (n) (cdr (assoc (nth 0 n) link-obj-alist :test #'string=))) all-nodes))
             (root-link (cdr (assoc name-str link-obj-alist :test #'string=)))
             (joints
              (remove nil
                      (mapcar
                       #'(lambda (n)
                           (let* ((name (nth 0 n)) (parent-name (nth 1 n)) (jidx (nth 3 n)))
                             (when parent-name
                               (let* ((jdef (and jidx (nth (1- jidx) joint-defs)))
                                      (plink (cdr (assoc parent-name link-obj-alist :test #'string=)))
                                      (clink (cdr (assoc name link-obj-alist :test #'string=)))
                                      (prismaticp (and jdef (eq (nth 1 jdef) :prismatic))))
                                 (if prismaticp
                                     (instance linear-joint :init
                                               :name (if jdef (nth 0 jdef) (format nil "~A_fixed" name))
                                               :parent-link plink :child-link clink
                                               :axis (nth 2 jdef) :min (m2mm (nth 3 jdef)) :max (m2mm (nth 4 jdef))
                                               :max-joint-velocity 1.0 :max-joint-torque 1.0)
                                   (instance rotational-joint :init
                                             :name (if jdef (nth 0 jdef) (format nil "~A_fixed" name))
                                             :parent-link plink :child-link clink
                                             :axis (if jdef (nth 2 jdef) #f(1 0 0))
                                             :min (if jdef (nth 3 jdef) 0.0) :max (if jdef (nth 4 jdef) 0.0)
                                             :max-joint-velocity 1.0 :max-joint-torque 1.0))))))
                       all-nodes))))
        (unless outfile
          (rcb4eus-mkdir "eusmodels")
          (setq outfile (rcb4eus-file (format nil "eusmodels/~A.l" name-str))))
        (let ((classname (format nil "~A-robot" name-str)))
          (with-open-file (strm outfile :direction :output :if-exists :supersede)
            (format strm ";; auto-generated by collada2eus.l from ~A.~%" dae-path)
            (format strm ";; do not edit by hand; regenerate with~%")
            (format strm ";;   (collada-to-native-collada-file ~S)~%~%" dae-path)
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
            (dolist (n all-nodes)
              (let* ((lname (eus-name-string (cdr (assoc (nth 0 n) link-obj-alist :test #'string=))))
                     (faces (apply #'append
                                    (mapcar #'(lambda (gr)
                                                (let ((tris (gethash (car gr) geom-hash)))
                                                  (mapcar #'(lambda (tri) (instance geometry::face :init :vertices tri)) tris)))
                                            (nth 4 n))))
                     (glv (if faces
                              (gl::make-glvertices-from-faces faces)
                            (gl::make-glvertices-from-faceset (make-cube 10 10 10))))
                     (rgba (let ((mat-id (cdr (find-if #'cdr (nth 4 n)))))
                             (and mat-id (gethash mat-id mat-hash))))
                     (material (and rgba (rgba-color-material rgba))))
                (let ((bbox (send glv :calc-bounding-box)))
                  (dump-glvertices-geom-method strm lname (send bbox :center) (send bbox :diagonal) (list glv) material))
                (setq faces nil)))
            (format strm "  )~%"))
          (format t ";; collada-to-native-collada-file: wrote ~A (~A links, ~A joints)~%"
                  outfile (length link-objs) (length joints))
          outfile)))))
