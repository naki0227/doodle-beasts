# Doodle Beasts（らくがきビースト）

みんなで分担して描いた絵が一体の生き物になり、CPU の敵の波と戦う協力ゲーム。Godot 4.6 製。Steam 向け。
コンセプトと段階計画は `docs/design.md`、市場の調査は `docs/competitive-analysis.md` にある。

いまあるのは**試作**。左右の枠に 2 人で同時に描き、合体した生き物が敵と戦うところまで動く。

1. **描画フェーズ**（60 秒）: P1 が左の枠に「からだ」、P2 が右の枠に「ぶき」を描く。描いている最中に、形から決まるステータスと武器の判定（「これは… 槍？」）が表示される。両者が完了するか時間切れで合体。
2. **戦闘フェーズ**: 合体した生き物が拠点のそばに現れ、ビヘイビアツリー（BT）で敵を追って戦う。プレイヤー 2 人も拠点の周りで殴ったり修理したりできる。拠点が落ちたら R で描き直しへ戻る。

## 遊び方

Godot 4.6 でこのフォルダを開いて実行する（`godot --path .`）。

| | 移動 / カーソル | 攻撃 / 描く | 修理 / 戻す | 完了 |
|---|---|---|---|---|
| P1 | WASD（描画中はマウスも可） | J（左クリック） | K（右クリック） | L |
| P2 | 矢印 | . | / | Enter |
| ゲームパッド 0 / 1 | 左スティック | A | X | Y |

描画フェーズでは同じボタンが「カーソル移動・描く・一つ戻す・完了」になる。スティックは倒した量でカーソルの速さが変わる。
拠点の HP が 0 になるとゲームオーバー。R キーか Start で描き直しへ。波は無限に続き、敵は少しずつ増えて硬くなる。

## 絵がどう読まれるか

- **からだ**: インクの総量でステータス総量（上限 100 点）が決まり、形が配分を決める。角が多いと攻撃、横長だと速さ、左右対称で閉じていると守り、残りが HP。
- **ぶき**: 細長い → 剣（とても長い → 槍）、先に塊 → ハンマー、短い線がたくさん → 爪、大きな閉じた形 → 盾、弧に弦 → 弓、どれでもない → 謎の武器。
- 判定は `src/draw/shape_analyzer.gd` の純粋関数で、同じ線からは必ず同じ結果が出る。詳しい表は `docs/design.md`。

## 構成

```
project.godot            プロジェクト設定（1280x720、GL Compatibility）
src/bt/                  ビヘイビアツリー本体（ゲームに依存しない）
src/ai/                  このゲーム用の葉ノード（索敵・移動・攻撃など）
src/draw/                描画フェーズ: キャンバス、線の計算、形の解析
src/game/                拠点・プレイヤー・敵・描いた生き物・波・HUD・戦闘シーン
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

# 単体テスト（61件）
godot --headless --path . -s res://tests/run_tests.gd

# 30秒間ゲームを回し、見本の絵から作った生き物が敵と戦うところまで確認
godot --headless --path . -s res://tests/simulate.gd

# 一連の流れを自動再生して動画にする（Xvfb と ffmpeg が必要。out/demo.mp4 ができる）
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
  --rendering-driver opengl3 --audio-driver Dummy \
  --write-movie out/frame.png --fixed-fps 30 -s res://tests/demo.gd
ffmpeg -framerate 30 -i out/frame%08d.png -c:v libx264 -pix_fmt yuv420p out/demo.mp4
```

テストは外部アドオンなしで動く。`tests/test_case.gd` を継承し、`test_` で始まるメソッドを書けば `tests/run_tests.gd` の一覧に加えるだけで実行される。
