# ビヘイビアツリー（BT）の使い方

敵の「何をするか」を、シーンツリー上のノードの木として組む。コードを書かずにエディタで枝を並べ替えられるのが利点。

## 基本

- `BehaviorTree` ノードを敵の子に置く。`agent` を空にすると親（敵本体）が主体になる。
- その直下の最初の `BTNode` がルート。毎物理フレーム評価される（`tick_interval` で間引ける）。
- 各ノードは `SUCCESS` / `FAILURE` / `RUNNING` を返す。`RUNNING` は「まだ途中」。
- ノード間で引き継ぐ値（いまの狙いなど）は `Blackboard` に入れる。キーは `&"target"` のような StringName。

## ノード一覧

| ノード | 種類 | 役割 |
|---|---|---|
| `BTSequence` | 複合 | 子を順に評価。全部 SUCCESS で SUCCESS。途中で FAILURE なら FAILURE |
| `BTSelector` | 複合 | 子を順に評価。最初に SUCCESS / RUNNING になった子を採用 |
| `BTInverter` | 装飾 | 子の SUCCESS と FAILURE を反転 |
| `BTCooldown` | 装飾 | 子が SUCCESS を返したあと `cooldown_seconds` の間は FAILURE |
| `BTCondition` | 葉（基底） | `_check()` を上書きして真偽を返す。副作用なし |
| `BTAction` | 葉（基底） | `_tick()` を上書きして行動する |

ゲーム用の葉（`src/ai/`）:

| ノード | 返す値 |
|---|---|
| `BTFindNearestPlayer` | `radius` 内で一番近いプレイヤーを `target` に入れて SUCCESS。いなければ FAILURE。倒れたプレイヤー（`is_targetable()` が false）は無視 |
| `BTTargetGroup` | 指定グループ（既定 `core`）の最初のノードを `target` に入れて SUCCESS |
| `BTIsTargetInRange` | `target` が `range` 以内なら SUCCESS |
| `BTMoveToTarget` | `target` へ移動。`stop_distance` 以内で SUCCESS、移動中 RUNNING |
| `BTAttackTarget` | `agent.attack(target)` を呼ぶ。当たれば SUCCESS、クールダウン中は RUNNING |
| `BTIsHpBelow` | `agent.hp / max_hp` が `ratio` 未満なら SUCCESS |

## 複合ノードの「記憶」

`remember_running` が false（既定）のとき、複合ノードは毎回先頭の子から評価し直す。前に並べた枝が優先され、途中だった後ろの枝は捨てられる（`reset()` が呼ばれる）。敵が「拠点へ向かっている途中でプレイヤーが近づいたら、すぐ追いかける」のはこの仕組み。

true にすると RUNNING だった子から再開する。「扉を開ける → 入る → 閉める」のように、途中で割り込まれたくない手順に使う。

## いまの敵のツリー（`src/game/enemy.tscn`）

```
Root (Selector)
├─ ChasePlayer (Sequence)
│  ├─ FindNearestPlayer  radius=220
│  └─ EngageOrApproach (Selector)
│     ├─ Engage (Sequence)
│     │  ├─ IsTargetInRange  range=40
│     │  └─ AttackTarget
│     └─ MoveToTarget  stop_distance=34
└─ AssaultCore (Sequence)
   ├─ TargetCore  group=core
   └─ EngageOrApproach (Selector)
      ├─ Engage (Sequence)
      │  ├─ IsTargetInRange  range=70
      │  └─ AttackTarget
      └─ MoveToTarget  stop_distance=60
```

読み方: 「近くにプレイヤーがいれば、射程内なら殴る、遠ければ近づく。いなければ拠点に同じことをする」。

## 獣と旅人のツリー（コードで組み立てる）

よみがえりの獣のツリーは、描いた形から決まる性格・目・武器によって変わる。シーンには置かず、`src/game/behavior_builder.gd` が組み立てて差し替える。

```
Root (Selector)
├─ Whim (Sequence)         謎の武器だけ: Check(is_whimsical) → Announce → Wander
├─ Withdraw (Sequence)     遊撃だけ: Check(is_retreating) → Retreat
├─ Hunt (Sequence)
│  ├─ FindTarget           半径 = 見える範囲（目の数）。性格で選び方が変わる
│  ├─ Announce             「突撃！」「駒を守る！」など。切り替わったときだけ頭上に出る
│  └─ Engage (Selector)
│     ├─ Strike (Sequence): IsTargetInRange → (弓なら KeepDistance) → AttackTarget
│     └─ MoveToTarget      （盾の性格は Intercept: 駒と敵のあいだに立つ）
└─ Home (Sequence)         Announce「見張る」→ MoveToAnchor（駒のそばの持ち場）
```

| 性格 | FindTarget の設定 |
|---|---|
| 突撃 | 自分にいちばん近い敵 |
| 遊撃 | 駒にいちばん近い敵（nearest_to_anchor） |
| 守護 | 駒から 240 以内の敵だけ（anchor_radius） |
| 盾 | 駒にいちばん近い敵。Engage の移動が Intercept になる |

旅人（`build_wanderer`）: `Defend`（駒から 200 以内の敵を払う）→ `Repair`（Check(core_needs_repair) → RepairCore）→ 持ち場へ。

葉ノード（`src/ai/`）の追加分:

| ノード | 役割 |
|---|---|
| `BTFindTarget` | 標的選び。見える範囲、基準点（駒）からの距離の制限、基準点に近い順 |
| `BTMoveToAnchor` | 駒のそばの持ち場へ戻る |
| `BTIntercept` | 駒と標的のあいだ、駒から一定の距離に立つ |
| `BTKeepDistance` | 標的が近すぎれば下がる |
| `BTRetreat` | 標的から離れる方向へ下がる |
| `BTWander` | 駒のまわりを気ままに歩く |
| `BTAgentCheck` | agent の bool メソッドを条件にする |
| `BTAnnounce` | いまの行動を agent に知らせる |
| `BTRepairCore` | 駒のそばへ行って直す |

敵の `BTFindNearestPlayer` は、`taunting` が true の相手（盾の獣）を実際より近いとみなす。

## 敵本体（agent）との契約

葉ノードは物理を知らない。移動や攻撃の実体は agent 側のメソッドに任せる。

```gdscript
func move_toward_point(point: Vector2, delta: float) -> void
func stop_moving() -> void
func attack(target: Node) -> bool      # 当たれば true、クールダウン中は false
var hp: float
var max_hp: float
```

この契約さえ満たせば、`CharacterBody2D` でも `Node2D` のスタブでも同じツリーが動く。テスト（`tests/test_enemy_tree.gd`）は物理なしで実際の `enemy.tscn` のツリーを回している。

## 新しい葉ノードの作り方

1. `src/ai/` に `BTCondition` か `BTAction` を継承したスクリプトを作る。
2. 調整したい値は `@export` にする。エディタのインスペクタから敵ごとに変えられる。
3. `tests/test_ai_leaves.gd` に `BTTestStubs.FakeAgent` / `FakeTarget` を使ったテストを足す。

例: 低 HP で逃げる枝を足すなら、Root の先頭に
`Sequence [ IsHpBelow ratio=0.25, FleeFromTarget ]` を挿す。`FleeFromTarget` は `BTMoveToTarget` を参考に、狙いの反対方向へ `move_toward_point` を呼ぶだけでよい。

## 将来の置き換え

ツリーが複雑になってデバッガや可視化が欲しくなったら、Godot の BT アドオン **LimboAI**（GDExtension、専用エディタ付き）に移せる。ノードの概念（Sequence / Selector / Condition / Action / Blackboard）は同じなので、葉ノードの中身はほぼそのまま持っていける。
