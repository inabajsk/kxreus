;;;
;;; eus2collada.l
;;;
;;; kxreusのネイティブロボットモデル(eusmodels/*.l)から、外部ツールを
;;; 一切使わずに単純な(ジオメトリ+材質+visual_sceneだけの、OpenHRP3の
;;; ロボティクスプロファイルまでは踏み込まない)COLLADA(.dae)ファイルを
;;; 生成する。collada2eus.lと対になる出力方向。MeshLab等の一般的な
;;; COLLADAビューアで表示確認できることを目的とする。
;;;
;;; 出力側はformatでストリームに直接書き込むだけなので、collada2eus.l
;;; 側で問題になった「巨大な1文字列をconcatenateで組み立てる」ような
;;; 危険な操作は一切発生しない(eus2urdf.l/eus2mujoco.lと同じ安全な
;;; パターン)。
;;;
;;; ノードの姿勢は<translate>/<rotate>の組ではなく<matrix>(4x4同次
;;; 変換行列、COLLADAの標準要素)を1個書くだけにする(回転行列から
;;; 軸角度表現へ変換する手間を避けるため)。
;;;
;;; 使い方:
;;;   (require :eus2collada)
;;;   (native-robot-to-collada-file "name" :robot r)
;;;   ;; -> eusdae/name.dae (:outfileで明示指定も可)
;;;
(require :kxrmodels)
(require :eus2urdf) ;; link-local-faces, link-material-rgba, eus-name-stringを再利用
(require :eus2mujoco) ;; mjcf-children-alist, make-indent-stringを再利用

(provide :eus2collada)

;; coordsは(呼び出し側で既に)書きたいノードの親相対変換に計算済みの
;; ものを渡す(:pos/:rotをそのまま使う。:worldpos/:worldrotは使わない
;; ―coordsがどこにも:assocされていないスタンドアロンな一時オブジェクト
;; である前提のため)。回転成分(rot)は無次元(そのまま)、平行移動成分
;; (pos)だけmm->mに変換する。
(defun dae-write-matrix (strm coords)
  (let ((pos (send coords :pos)) (rot (send coords :rot)))
    (format strm "<matrix>~A ~A ~A ~A ~A ~A ~A ~A ~A ~A ~A ~A 0 0 0 1</matrix>~%"
            (fmt-f (aref rot 0 0)) (fmt-f (aref rot 0 1)) (fmt-f (aref rot 0 2)) (fmt-f (mm2m (elt pos 0)))
            (fmt-f (aref rot 1 0)) (fmt-f (aref rot 1 1)) (fmt-f (aref rot 1 2)) (fmt-f (mm2m (elt pos 1)))
            (fmt-f (aref rot 2 0)) (fmt-f (aref rot 2 1)) (fmt-f (aref rot 2 2)) (fmt-f (mm2m (elt pos 2))))))

;; ---- 1リンクぶんのgeometry+material要素を書く ----
(defun dump-dae-link-geometry (strm link)
  (let* ((lname (eus-name-string link))
         (faces (link-local-faces link))
         (rgba (or (link-material-rgba link) #f(0.7 0.7 0.7 1.0))))
    ;; geometry(頂点は重複可、STL相当の単純な「各面3頂点」方式でよい
    ;; ―ファイルサイズ最適化はせず、表示確認用の単純さを優先する)
    (format strm "    <geometry id=\"~A_geom\">~%" lname)
    (format strm "      <mesh>~%")
    (format strm "        <source id=\"~A_positions\">~%" lname)
    (format strm "          <float_array id=\"~A_positions-array\" count=\"~A\">" lname (* (length faces) 9))
    (dolist (f faces)
      (dolist (v (send f :vertices))
        (format strm "~A ~A ~A " (fmt-f (mm2m (elt v 0))) (fmt-f (mm2m (elt v 1))) (fmt-f (mm2m (elt v 2))))))
    (format strm "</float_array>~%")
    (format strm "          <technique_common><accessor count=\"~A\" source=\"#~A_positions-array\" stride=\"3\">~%"
            (* (length faces) 3) lname)
    (format strm "            <param name=\"X\" type=\"float\"/><param name=\"Y\" type=\"float\"/><param name=\"Z\" type=\"float\"/>~%")
    (format strm "          </accessor></technique_common>~%")
    (format strm "        </source>~%")
    (format strm "        <vertices id=\"~A_vertices\"><input semantic=\"POSITION\" source=\"#~A_positions\"/></vertices>~%" lname lname)
    (format strm "        <triangles count=\"~A\" material=\"~A_mat\">~%" (length faces) lname)
    (format strm "          <input offset=\"0\" semantic=\"VERTEX\" source=\"#~A_vertices\"/>~%" lname)
    (format strm "          <p>")
    (dotimes (i (* (length faces) 3)) (format strm "~A " i))
    (format strm "</p>~%")
    (format strm "        </triangles>~%")
    (format strm "      </mesh>~%")
    (format strm "    </geometry>~%")
    rgba))

(defun dump-dae-effect (strm lname rgba)
  (format strm "    <effect id=\"~A_eff\"><profile_COMMON><technique sid=\"common\"><phong>~%" lname)
  (format strm "      <diffuse><color>~A ~A ~A ~A</color></diffuse>~%"
          (fmt-f (elt rgba 0)) (fmt-f (elt rgba 1)) (fmt-f (elt rgba 2)) (fmt-f (if (>= (length rgba) 4) (elt rgba 3) 1.0)))
  (format strm "    </phong></technique></profile_COMMON></effect>~%"))

(defun dump-dae-material (strm lname)
  (format strm "    <material id=\"~A_mat\"><instance_effect url=\"#~A_eff\"/></material>~%" lname lname))

;; ---- ノード木(joint親子関係)を辿ってvisual_sceneを再帰的に書く ----
;; eus2mujoco.lのmjcf-children-alist/dump-mjcf-bodyと同じ考え方: 各
;; jointの:parent-link/:child-linkからchildren-alistを作り、rootから
;; 再帰する。ノードの変換は親相対(parent_worldcoords^-1 * child_
;; worldcoords)で計算する。
(defun dump-dae-node (strm link incoming-joint children-alist indent)
  (let* ((lname (eus-name-string link))
         (pad (make-indent-string indent))
         (rel (if incoming-joint
                  (send (send (send incoming-joint :parent-link) :worldcoords)
                        :transformation (send link :worldcoords))
                (send link :worldcoords))))
    (format strm "~A<node id=\"~A\" name=\"~A\">~%" pad lname lname)
    (format strm "~A  " pad) (dae-write-matrix strm rel)
    (format strm "~A  <instance_geometry url=\"#~A_geom\">~%" pad lname)
    (format strm "~A    <bind_material><technique_common>~%" pad)
    (format strm "~A      <instance_material symbol=\"~A_mat\" target=\"#~A_mat\"/>~%" pad lname lname)
    (format strm "~A    </technique_common></bind_material>~%" pad)
    (format strm "~A  </instance_geometry>~%" pad)
    (dolist (j (cdr (assoc lname children-alist :test #'string=)))
      (dump-dae-node strm (send j :child-link) j children-alist (+ indent 2)))
    (format strm "~A</node>~%" pad)))

;; ---- メイン ----
(defun native-robot-to-collada-file (name-str &key (robot nil) (outfile nil))
  (reset-eus-name-string-table)
  (unless robot
    (setq robot (make-kxr-robot name-str :model nil :viewer nil :ri nil)))
  (when (find-method robot :neutral) (send robot :neutral))
  (unless outfile
    (rcb4eus-mkdir "eusdae")
    (setq outfile (rcb4eus-file (format nil "eusdae/~A.dae" name-str))))
  (let* ((links (send robot :links))
         (joints (send robot :joint-list))
         (root-link (car links))
         (children-alist (mjcf-children-alist joints))
         (link-rgba (mapcar #'(lambda (l) (cons l nil)) links)))
    (with-open-file (strm outfile :direction :output :if-exists :supersede)
      (format strm "<?xml version=\"1.0\" encoding=\"UTF-8\"?>~%")
      (format strm "<COLLADA xmlns=\"http://www.collada.org/2005/11/COLLADASchema\" version=\"1.4.1\">~%")
      (format strm "  <!-- auto-generated by eus2collada.l from a native robot-model. -->~%")
      (format strm "  <!-- do not edit by hand; regenerate with (native-robot-to-collada-file ~S) -->~%" name-str)
      (format strm "  <asset><up_axis>Z_UP</up_axis></asset>~%")
      (format strm "  <library_geometries>~%")
      (dolist (l links)
        (setf (cdr (assoc l link-rgba)) (dump-dae-link-geometry strm l)))
      (format strm "  </library_geometries>~%")
      (format strm "  <library_effects>~%")
      (dolist (l links) (dump-dae-effect strm (eus-name-string l) (cdr (assoc l link-rgba))))
      (format strm "  </library_effects>~%")
      (format strm "  <library_materials>~%")
      (dolist (l links) (dump-dae-material strm (eus-name-string l)))
      (format strm "  </library_materials>~%")
      (format strm "  <library_visual_scenes>~%")
      (format strm "    <visual_scene id=\"vscene\" name=\"~A\">~%" name-str)
      (dump-dae-node strm root-link nil children-alist 6)
      (format strm "    </visual_scene>~%")
      (format strm "  </library_visual_scenes>~%")
      (format strm "  <scene><instance_visual_scene url=\"#vscene\"/></scene>~%")
      (format strm "</COLLADA>~%"))
    (format t ";; native-robot-to-collada-file: wrote ~A (~A links, ~A joints)~%"
            outfile (length links) (length joints))
    outfile))
