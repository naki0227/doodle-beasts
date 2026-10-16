extends Node
## 1 回の遊び（ラン）の状態を、描画フェーズと戦闘フェーズのあいだで受け渡す自動読み込みノード。
## 線のデータ（点の列）が正であり、ステータスも見た目も行動もここから毎回導出する。
##
## 流れ: 記録帳に描く → 波を守る → 記録帳に戻って描き直す（インクが増える）→ 次の波 → … → 金の駒が凍ったら終わり。

const BASE_INK := 3000.0
## 波を一つ守るごとに増えるインク。
const INK_PER_WAVE := 400.0
const FIRST_DRAW_SECONDS := 60.0
const REDRAW_SECONDS := 40.0

var body_strokes: Array[PackedVector2Array] = []
var weapon_strokes: Array[PackedVector2Array] = []
var ink_budget: float = BASE_INK
## 次に挑む波。
var next_wave: int = 1
## 波をまたいで持ち越す金の駒の HP。負なら満タンから。
var core_hp: float = -1.0
## 記録帳を開いた回数（1 回目は時間が長い）。
var drawings: int = 0


func has_beast() -> bool:
	return not body_strokes.is_empty()


func store(body: Array[PackedVector2Array], weapon: Array[PackedVector2Array], budget: float) -> void:
	body_strokes = body.duplicate(true)
	weapon_strokes = weapon.duplicate(true)
	ink_budget = budget


func clear() -> void:
	body_strokes = []
	weapon_strokes = []


## 新しいランを始める（タイトルやゲームオーバーから）。
func reset_run() -> void:
	clear()
	ink_budget = BASE_INK
	next_wave = 1
	core_hp = -1.0
	drawings = 0


## 波を守った。次の波と、駒の HP と、増えたインクを覚える。
func wave_cleared(wave: int, remaining_core_hp: float) -> void:
	next_wave = wave + 1
	core_hp = remaining_core_hp
	ink_budget += INK_PER_WAVE


func is_redraw() -> bool:
	return drawings > 0


func draw_seconds() -> float:
	return REDRAW_SECONDS if is_redraw() else FIRST_DRAW_SECONDS
