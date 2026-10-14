# Coop Core Defense

2人で一つの拠点を守りながら、CPU の敵の波に立ち向かうローカル協力ゲームの骨組み。Godot 4.6 製。
敵 AI は自前のビヘイビアツリー（BT）で動く。将来 Steam に出す前提で、ローカル協力 → Remote Play Together → 本物のオンライン同期、の順に育てる。

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
docs/design.md           コンセプト・ロードマップ・Steam までの段取り
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
