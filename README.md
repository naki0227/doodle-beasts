# Doodle Beasts（仮題: はかり野 — よみがえりの大地）

みんなで分担して記録帳に描いたかたちが一体の獣としてよみがえり、霜の獣の波から金の駒を守る協力ゲーム。Godot 4.6 製。Steam 向け。
コンセプトと段階計画は `docs/design.md`、市場の調査は `docs/competitive-analysis.md` にある。

いまあるのは**試作**。タイトル → 記録帳の左右のページに 2 人で同時に描く → 合体 → よみがえった獣が霜の獣と戦う、まで動く。
見た目は「神々の世界が終わったあとの、巨人の骨の大地」で統一している。夕暮れの遠景、ピクセルアート風の後処理、ランタンを持つ旅人、金継ぎの線が光る石の獣。詳しくは `docs/design.md` のアートディレクションと `docs/moodboard/`。

1. **描画フェーズ**（60 秒）: P1 が左の枠に「からだ」、P2 が右の枠に「ぶき」を描く。描いている最中に、形から決まるステータスと武器の判定（「これは… 槍？」）が表示される。両者が完了するか時間切れで合体。
2. **戦闘フェーズ**: 合体した生き物が拠点のそばに現れ、ビヘイビアツリー（BT）で敵を追って戦う。プレイヤー 2 人も拠点の周りで殴ったり修理したりできる。拠点が落ちたら R で描き直しへ戻る。

## 遊び方

Godot 4.6 でこのフォルダを開いて実行する（`godot --path .`）。

| | 移動 / カーソル | 杖で打つ / 描く | 駒を直す / 一つ消す | 封をする（完成） |
|---|---|---|---|---|
| P1 | WASD（描画中はマウスも可） | J（左クリック） | K（右クリック） | L |
| P2 | 矢印 | . | / | Enter |
| ゲームパッド 0 / 1 | 左スティック | A | X | Y |

描画フェーズでは同じボタンが「カーソル移動・描く・一つ戻す・完了」になる。スティックは倒した量でカーソルの速さが変わる。
金の駒の HP が 0 になるとゲームオーバー。R キーか Start で描き直しへ。波は無限に続き、霜の獣は少しずつ増えて硬くなる。

## 絵がどう読まれるか

- **からだ**: インクの総量でステータス総量（上限 100 点）が決まり、形が配分を決める。角が多いと力、横長だと速さ、左右対称で閉じていると守り、残りが体力。
- **ぶき**: 細長い → 剣（とても長い → 槍）、先に塊 → ハンマー、短い線がたくさん → 爪、大きな閉じた形 → 盾、弧に弦 → 弓、どれでもない → 謎の武器。
- 判定は `src/draw/shape_analyzer.gd` の純粋関数で、同じ線からは必ず同じ結果が出る。詳しい表は `docs/design.md`。

## 構成

```
project.godot            プロジェクト設定（1280x720、GL Compatibility）
assets/fonts/            Zen Old Mincho（SIL OFL、ライセンス同梱）
assets/shaders/          空・草地・霧・ピクセル化の後処理・羊皮紙・机・石の質感
src/fx/                  色とフォント（DoodleStyle）、遠景（Backdrop）、光（GlowNode）、演出（Fx: 揺れ・ヒットストップ・擬音・飛び散り）
src/title/               タイトル画面
src/bt/                  ビヘイビアツリー本体（ゲームに依存しない）
src/ai/                  このゲーム用の葉ノード（索敵・移動・攻撃など）
src/draw/                描画フェーズ: キャンバス、線の計算、形の解析
src/game/                拠点・プレイヤー・敵・描いた生き物・波・HUD・戦闘シーン
tests/                   ヘッドレスのテストとシミュレーション
docs/design.md           コンセプト・段階計画・Steam までの段取り
docs/competitive-analysis.md  競合と市場の調査（2026-10）
docs/moodboard/          目指す雰囲気の参考画像（ゲームには同梱しない）
docs/behavior-tree.md    BT の使い方とノード一覧
.github/workflows/ci.yml push ごとにインポート・テスト・起動確認
```

## 開発

```sh
# 初回 / スクリプト追加後
godot --headless --path . --import

# 単体テスト（62件）
godot --headless --path . -s res://tests/run_tests.gd

# 全スクリプトとシーンが読み込めるか（構文エラーの検出）
godot --headless --path . -s res://tests/check_scripts.gd

# 30秒間ゲームを回し、見本の絵から作った生き物が敵と戦うところまで確認
godot --headless --path . -s res://tests/simulate.gd

# 各画面を短く表示して見た目を確かめる（Xvfb が必要）
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
  --rendering-driver opengl3 --audio-driver Dummy \
  --write-movie out/still.png --fixed-fps 10 -s res://tests/stills.gd

# 一連の流れを自動再生して動画にする（Xvfb と ffmpeg が必要。out/demo.mp4 ができる）
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
  --rendering-driver opengl3 --audio-driver Dummy \
  --write-movie out/frame.png --fixed-fps 30 -s res://tests/demo.gd
ffmpeg -framerate 30 -i out/frame%08d.png -c:v libx264 -pix_fmt yuv420p out/demo.mp4
```

テストは外部アドオンなしで動く。`tests/test_case.gd` を継承し、`test_` で始まるメソッドを書けば `tests/run_tests.gd` の一覧に加えるだけで実行される。
