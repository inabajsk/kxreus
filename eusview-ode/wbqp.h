/*
 * wbqp.h : 全身の 2 次計画法 (QP) で, 移した動作 (GMR など) を自己衝突なし・関節の可動範囲の中・重心が足の裏の中に直す
 *          C の API (Swift はブリッジングヘッダ, Android は JNI, EusLisp は defforeign から呼ぶ. odesim.h と同じ書き方)
 *   考え方: AIST / CNRS の mc_rtc (Tasks) の QP 制御と同じ. 毎コマ, 変数 = ルートの 6 自由度 + 関節角の変化,
 *     目的 = 重み付き最小二乗 (関節角・手足・ルートの向きを参照に合わせる), 制約 = 関節の可動範囲・速さ, 自己衝突 (速度ダンパ),
 *     重心の床への投影が支持多角形の中, 床に着いている足を動かさない・床より下に行かない. 数回の逐次 QP (SQP).
 *   ソルバ: 自前の Goldfarb–Idnani 双対有効制約法 (密, 小さい問題向け. wbqp.cpp に書いた. 外部のライブラリは使わない)
 *   単位: m, rad, kg (直動関節は m). 座標は z が上, 床は z = 0. 姿勢 (pose) は 12 個の double: 位置 x y z, 回転 3x3 行優先
 *   使い方は eusview/bvh/QP.md
 *   ライセンス: このファイルと wbqp.cpp は EusView の一部 (自前のコード, 外部のコードを含まない)
 */
#ifndef WBQP_H
#define WBQP_H
#ifdef __cplusplus
extern "C" {
#endif

typedef struct WbQP WbQP;

/* 1 つのロボットの評価 (衝突・可動範囲・重心) */
typedef struct {
  double min_dist;      /* 自己衝突を調べるカプセルの組の最小の距離 (m, 負 = めり込み). 組がなければ 1e9 */
  int pair[2];          /* その組のリンクの番号 */
  int n_collide;        /* 距離 < 0 の組の数 */
  int n_limit;          /* 可動範囲の外 (limit_tol より外) の関節の数 */
  int n_at_limit;       /* 可動範囲の端 (端から at_limit_tol 以内か外) の関節の数 */
  double max_limit_excess; /* 可動範囲から出た量の最大 (rad, 0 = 中) */
  double com[3];        /* 重心 (m) */
  double com_margin;    /* 重心の床への投影と支持多角形の縁の距離 (m, 正 = 中). 支える足がないときは NAN */
  double foot_height[2];/* 左・右の足の裏のいちばん低い点の高さ (m) */
} WbqpEval;

typedef struct {
  WbqpEval before;      /* 参照 (QP の前) */
  WbqpEval after;       /* QP の答え */
  int contact;          /* 床に着いている (止める) 足: bit0 左, bit1 右 */
  int support;          /* 重心を中に入れる支持多角形に使う足 (contact の一部) */
  int status;           /* 0: 答えた, 1: 逐次 QP の回数の上限, -1: QP が解けない (前の答えか参照を返す) */
  int sqp_iters;        /* 逐次 QP の回数 */
  int qp_iters;         /* 有効制約法の反復の合計 */
  int n_constraints;    /* 最後の QP の不等式制約の数 */
  int n_collision_rows; /* そのうち自己衝突の制約の数 */
  double slack_max;     /* 緩めた量の最大 (衝突・重心の制約, m) */
  double time_ms;       /* 計算時間 (ms) */
} WbqpDiag;

/* ---- モデル (初めに 1 度) ---- */
WbQP *wbqp_create(void);
void wbqp_destroy(WbQP *h);
/* リンクを根元から順に加える (parent < 自分の番号. ルートは parent = -1). rest: 親から見た関節角 0 のときの姿勢 (12 個) */
int wbqp_add_link(WbQP *h, int parent, const double rest[12]);
/* リンクの形 (メッシュの頂点, リンクの座標, m). 衝突のカプセル・足の裏・質量の見積もりに使う. 何度でも足せる */
void wbqp_add_link_vertices(WbQP *h, int link, const float *xyz, int nv);
/* 質量と重心 (リンクの座標). 呼ばないリンクは頂点の外接箱から見積もる (400 kg/m^3, PhysicsSim と同じ) */
void wbqp_set_link_mass(WbQP *h, int link, double mass, const double com[3]);
/* 関節: link を親に対して動かす (link の姿勢 = 親 · rest · R(axis, q)). type 0 = 回転 (rad), 1 = 直動 (m).
   lo/hi: 可動範囲, vmax: 速さの上限 (rad/s か m/s, 0 以下なら既定値 vmax_default). 戻り値は関節の番号 (q の並び) */
int wbqp_add_joint(WbQP *h, int link, int type, const double axis[3], double lo, double hi, double vmax);
/* 衝突のカプセル (リンクの座標, 線分 p0-p1 と半径). 1 つも足さないリンクは頂点から自動で 1 つ作る. radius <= 0 でそのリンクは衝突なし */
int wbqp_add_capsule(WbQP *h, int link, const double p0[3], const double p1[3], double radius);
/* 手 (side 0 = 左, 1 = 右): 位置を合わせる点 (link の座標) */
void wbqp_set_hand(WbQP *h, int side, int link, const double offset[3]);
/* 足 (side 0 = 左, 1 = 右): 足の裏のリンク. 裏の多角形は関節角 0 の姿勢でそのリンクのいちばん低い頂点から作る */
void wbqp_set_foot(WbQP *h, int side, int link);
/* 衝突を調べない組を足す (カプセルの番号ではなくリンクの番号) */
void wbqp_exclude_pair(WbQP *h, int link_a, int link_b);
/* パラメータ (名前は QP.md). 戻り値 0 = 知らない名前 */
int wbqp_set_param(WbQP *h, const char *name, double value);
double wbqp_get_param(WbQP *h, const char *name);
/* モデルを仕上げる: カプセル・足の裏・質量・大きさ (scale = 脚の長さ) を求め, 衝突を調べる組を決める.
   poses: n 個の関節角の組 (例: 関節角 0, reset-pose). これらの姿勢で当たっている組 (と木で近いリンク) は調べない */
int wbqp_finalize(WbQP *h, const double *poses, int n);

/* ---- 情報 ---- */
int wbqp_num_links(WbQP *h);
int wbqp_num_joints(WbQP *h);
int wbqp_num_capsules(WbQP *h);
void wbqp_capsule(WbQP *h, int i, int *link, double p0[3], double p1[3], double *radius);
int wbqp_num_pairs(WbQP *h);
void wbqp_pair(WbQP *h, int i, int *link_a, int *link_b);
/* 足の裏の多角形 (リンクの座標, 3 個ずつ). 戻り値は頂点の数 */
int wbqp_sole(WbQP *h, int side, double *xyz, int max);
double wbqp_total_mass(WbQP *h);

/* ---- 評価 (状態を変えない, 別のスレッドから呼んでよい) ----
   q: 関節角, root: ルートのリンクのワールドの姿勢 (12 個). support: 支える足 (bit0 左, bit1 右, -1 = 床からの高さで決める).
   link_flags (リンクの数, NULL 可): bit0 = 衝突している (距離 < 0), bit1 = 関節が可動範囲の端か外, bit2 = 衝突の手前 (d_safe 未満)
   poly (NULL 可): 支持多角形の頂点 (x y を max 個まで, 縮める前). 戻り値は頂点の数 */
int wbqp_eval(WbQP *h, const double *q, const double root[12], int support, WbqpEval *ev,
              int *link_flags, double *poly, int max);
/* 順運動学: 全部のリンクのワールドの姿勢 (12 個ずつ) */
void wbqp_fk(WbQP *h, const double *q, const double root[12], double *poses);

/* ---- コマごとに解く ---- */
/* 前のコマの記憶 (答え・止めている足の位置) を消す (別の動作を始めるとき) */
void wbqp_reset(WbQP *h);
/* 参照 (q_ref, root_ref) を直す. contact / support: bit0 左, bit1 右 (-1 = 参照の足の高さで決める. support = -1 は contact と同じ).
   targets (NULL 可): 手と足の目標 4 x 12 (左手, 右手, 左足, 右足の姿勢. 手は位置だけ使う). NULL なら参照の順運動学.
   q_out, root_out: 答え. diag (NULL 可): 前後の評価など. 戻り値 = diag.status */
int wbqp_solve(WbQP *h, const double *q_ref, const double root_ref[12], int contact, int support,
               const double *targets, double *q_out, double root_out[12], WbqpDiag *diag);
/* 足が床に着いているか (参照の足の裏の高さ, ヒステリシスつき). prev: 前のコマの値 (初めは 0) */
int wbqp_contact_of(WbQP *h, const double *q_ref, const double root_ref[12], int prev);
/* 動作全体の contact と support を決める (support = この先 preview コマの間ずっと着いている足. 片足立ちの前に重心を移すため).
   q_ref: n x 関節の数, root_ref: n x 12 */
void wbqp_plan_contacts(WbQP *h, int n, const double *q_ref, const double *root_ref, int *contact, int *support);

#ifdef __cplusplus
}
#endif
#endif
