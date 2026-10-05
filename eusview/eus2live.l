;; eus2live.l : EusLisp から iPhone の EusView へ関節角を送る (eusview/live.py が中継)
;;   (live-connect)                    live.py (TCP 8767) につなぐ
;;   (live-send-angles robot)          関節角 {"angles": [...]} (度・mm, joint-list の順 = JSON の joints の順)
;;   (live-send-root robot)            ルートリンクのワールド座標 {"root": [x y z(m) r00..r22]}
;;   (live-send robot)                 両方
;;   (live-pose "reset-pose")          JSON の名前付き姿勢へ動かす
(defvar *live* nil)

(defun live-connect (&optional (host "localhost") (port 8767))
  (setq *live* (make-client-socket-stream (make-socket-address :domain af_inet :host host :port port)))
  (unless (streamp *live*) (warn ";; live.py につながりません (~A:~A)~%" host port) (setq *live* nil))
  *live*)

(defun live-write (str)
  (when *live* (format *live* "~A~%" str) (finish-output *live*)))

(defun live-num (x) (json-num x 4))  ; eus2json.l の数値の書き方 (format の ~,4f は EusLisp では使えない)

(defun live-send-angles (robot)
  ;; eus2json.l と同じ関節の順 (e2j の並べ方を使う)
  (live-write (format nil "{\"angles\":[~A]}"
                      (e2j-join (map cons #'live-num (send robot :angle-vector))))))

(defun live-send-root (robot)
  (let* ((root (car (e2j-sort-links (send robot :links)))) (c (send root :worldcoords))
         (p (scale 0.001 (send c :worldpos))) (r (send c :worldrot)))
    (live-write (format nil "{\"root\":[~A]}"
                        (e2j-join (mapcar #'live-num
                                          (append (coerce p cons)
                                                  (list (aref r 0 0) (aref r 0 1) (aref r 0 2)
                                                        (aref r 1 0) (aref r 1 1) (aref r 1 2)
                                                        (aref r 2 0) (aref r 2 1) (aref r 2 2)))))))))

(defun live-send (robot) (live-send-angles robot) (live-send-root robot))
(defun live-pose (name) (live-write (format nil "{\"pose\":\"~A\"}" name)))
