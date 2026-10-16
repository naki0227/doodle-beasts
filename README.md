# はかり野 — よみがえりの大地

みんなで分担して記録帳に描いたかたちが一体の獣としてよみがえり、霜の獣の波から金の駒を守る協力ゲーム。Godot 4.6 製。Steam 向け。
（リポジトリ名とプロジェクトの内部名は Doodle Beasts のまま）

**戦闘は自動で進む。** プレイヤーの操作は記録帳に描くことだけ。描いたかたちから獣の性格（戦い方）・目の数（見える範囲）・武器が決まり、獣はそのとおりに動く。
波を一つ守るたびに記録帳へ戻り、増えたインクで描き直して次の波に挑む。
コンセプトと段階計画は `docs/design.md`、市場の調査は `docs/competitive-analysis.md` にある。

いまあるのは**試作**。タイトル → 記録帳の左右のページに 2 人で同時に描く → 合体 → 自動の戦闘 → 波を守ったら記録帳で描き直し → 次の波、まで動く。
見た目は「神々の世界が終わったあとの、巨人の骨の大地」で統一している。夕暮れの遠景、ピクセルアート風の後処理、ランタンを持つ旅人、金継ぎの線が光る石の獣。効果音と BGM は手続きで合成している。詳しくは `docs/design.md`。

## 遊び方

Godot 4.6 でこのフォルダを開いて実行する（`godot --path .`）。

記録帳での操作（戦闘中は操作しない）:

| | カーソル | 描く | 一つ消す | 封をする（完成） |
|---|---|---|---|---|
| 旅人 1（左のページ「からだ」） | WASD・マウス | J・左クリック | K・右クリック | L |
| 旅人 2（右のページ「ぶき」） | 矢印 | . | / | Enter |
| ゲームパッド 0 / 1 | 左スティック | A | X | Y |

スティックは倒した量でカーソルの速さが変わる。二人とも封をするか、ろうそくが燃え尽きると合体して戦いが始まる。
金の駒の HP が 0 になるとゲームオーバー。R キーか Start で、はじめから。

## 絵がどう読まれるか

- **からだ → 性格**: インクの総量でステータス総量（上限 100 点）が決まり、形が配分と性格を決める。
  - トゲトゲ（角が多い）→ **突撃**: いちばん近い霜の獣へ飛びかかる。力が高い
  - 横長 → **遊撃**: 駒に近い敵を先回りして叩き、一撃ごとに身を引く。速い
  - 左右対称で閉じた形 → **守護**: 駒のそばを離れず、近づいた敵だけを打つ。守りが高い
  - どれでもない丸っこい形 → **盾**: 駒と敵のあいだに立ちはだかり、敵を引きつける。体力が高い
- **目**: からだの輪郭の内側に描いた小さな閉じた形を目とみなす。目が多いほど遠くの敵に気づく。
- **ぶき**: 細長い → 剣（とても長い → 槍）、先に塊 → ハンマー（まわりの敵もまとめて叩く）、短い線がたくさん → 爪、大きな閉じた形 → 盾（そばにいると駒の傷が減る）、弧に弦 → 弓（距離をとって射る）、どれでもない → 謎の武器（ときどき気まぐれに歩きまわる）。
- 判定は `src/draw/shape_analyzer.gd` の純粋関数で、同じ線からは必ず同じ結果が出る。性格と武器からビヘイビアツリーを組むのは `src/game/behavior_builder.gd`。

## 構成

```
project.godot            プロジェクト設定（1280x720、GL Compatibility）
assets/audio/            効果音と BGM（tools/audio/gen_audio.py で合成）
assets/fonts/            Zen Old Mincho（SIL OFL、ライセンス同梱）
assets/shaders/          空・草地・霧・ピクセル化の後処理・羊皮紙・机・石の質感
src/fx/                  色とフォント（DoodleStyle）、遠景（Backdrop）、光（GlowNode）、演出（Fx）、音（Sound / SoundBus）
src/title/               タイトル画面
src/bt/                  ビヘイビアツリー本体（ゲームに依存しない）
src/ai/                  このゲーム用の葉ノード（標的選び・割り込み・距離とり・身を引く・修理など）
src/draw/                描画フェーズ: キャンバス、線の計算、形の解析
src/game/                金の駒・旅人・霜の獣・よみがえりの獣・行動の組み立て・波・HUD・戦闘シーン
tools/audio/             効果音と BGM の合成スクリプト（numpy + ffmpeg）
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

# 単体テスト（84件）
godot --headless --path . -s res://tests/run_tests.gd

# 全スクリプトとシーンが読み込めるか（構文エラーの検出）
godot --headless --path . -s res://tests/check_scripts.gd

# 30秒間ゲームを回し、見本の絵から作った生き物が敵と戦うところまで確認
godot --headless --path . -s res://tests/simulate.gd

# 各画面を短く表示して見た目を確かめる（Xvfb が必要）
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
  --rendering-driver opengl3 --audio-driver Dummy \
  --write-movie out/still.png --fixed-fps 10 -s res://tests/stills.gd

# 効果音と BGM を作り直す
python3 -I tools/audio/gen_audio.py assets/audio

# 一連の流れを自動再生して動画にする（Xvfb と ffmpeg が必要。out/demo.mp4 ができる）
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
  --rendering-driver opengl3 --audio-driver Dummy \
  --write-movie out/frame.png --fixed-fps 30 -s res://tests/demo.gd
ffmpeg -framerate 30 -i out/frame%08d.png -i out/frame.wav -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest out/demo.mp4
```

テストは外部アドオンなしで動く。`tests/test_case.gd` を継承し、`test_` で始まるメソッドを書けば `tests/run_tests.gd` の一覧に加えるだけで実行される。
