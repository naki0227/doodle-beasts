# Doodle Beasts（らくがきビースト）

みんなで分担して描いた絵が一体の生き物になり、CPU の敵の波と戦う協力ゲーム。Godot 4.6 製。Steam 向け。
コンセプトと段階計画は `docs/design.md`、市場の調査は `docs/competitive-analysis.md` にある。

いまリポジトリにあるのは**戦闘の土台**で、描画と合体はまだ無い。拠点・ローカル 2 人・ビヘイビアツリー（BT）で動く敵・無限ウェーブ・HUD が動く状態。

## 遊び方

Godot 4.6 でこのフォルダを開いて実行する（`godot --path .`）。

| | 移動 | 攻撃 | 拠点修理 |
|---|---|---|---|
| P1 | WASD | J | K |
| P2 | 矢印 | . | / |
| ゲームパッド 0 / 1 | 左スティック | A | X |

拠点の HP が 0 になるとゲームオーバー。R キーか Start でやり直し。波は無限に続き、敵は少しずつ増えて硬くなる。

## 構成

```
project.godot            プロジェクト設定（1280x720、GL Compatibility）
src/bt/                  ビヘイビアツリー本体（ゲームに依存しない）
src/ai/                  このゲーム用の葉ノード（索敵・移動・攻撃など）
src/game/                拠点・プレイヤー・敵・波・HUD・メインシーン
tests/                   ヘッドレスのテストとシミュレーション
docs/design.md           コンセプト・段階計画・Steam までの段取り
docs/competitive-analysis.md  競合と市場の調査（2026-10）
docs/behavior-tree.md    BT の使い方とノード一覧
.github/workflows/ci.yml push ごとにインポート・テスト・起動確認
```

## 開発

```sh
# 初回 / スクリプト追加後
godot --headless --path . --import

# 単体テスト（36件）
godot --headless --path . -s res://tests/run_tests.gd

# 30秒間ゲームを回し、敵が拠点を攻撃するところまで確認
godot --headless --path . -s res://tests/simulate.gd
```

テストは外部アドオンなしで動く。`tests/test_case.gd` を継承し、`test_` で始まるメソッドを書けば `tests/run_tests.gd` の一覧に加えるだけで実行される。
