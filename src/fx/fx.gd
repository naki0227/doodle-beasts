class_name Fx
extends RefCounted
## 演出をまとめて出す窓口。すべて静的関数なので、どこからでも Fx.burst(...) のように呼べる。
## 画面揺れ・ヒットストップ・飛び散り・擬音・ダメージ数字・矢・地面に残る跡。
## 演出を置く場所（fx_layer / fx_decals / shake_camera グループのノード）がない場面では何もしない。
## そのため、テストやシミュレーションからゲームの処理を呼んでも安全。
## 自動読み込みにしないのは、-s で起動するテスト用スクリプトが自動読み込みより先にコンパイルされるため。

const BURST_SCRIPT := preload("res://src/fx/burst_effect.gd")
const POP_SCRIPT := preload("res://src/fx/pop_text.gd")
const ARROW_SCRIPT := preload("res://src/fx/arrow_effect.gd")

## ヒットストップは戦闘シーンだけで有効にする。
static var hitstop_enabled := false
static var _hitstop_depth := 0


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func layer() -> Node2D:
	var tree := _tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"fx_layer") as Node2D


## 文字の演出を置く場所。ピクセル化の後処理より上にあり、文字がくっきり読める。なければ fx_layer。
static func text_layer() -> Node2D:
	var tree := _tree()
	if tree == null:
		return null
	var found := tree.get_first_node_in_group(&"fx_text_layer") as Node2D
	return found if found != null else layer()


static func shake(amount: float) -> void:
	var tree := _tree()
	if tree == null:
		return
	var camera := tree.get_first_node_in_group(&"shake_camera")
	if camera != null and camera.has_method("add_shake"):
		camera.add_shake(amount)


static func hitstop(seconds: float = 0.06) -> void:
	var tree := _tree()
	if not hitstop_enabled or tree == null or seconds <= 0.0:
		return
	_hitstop_depth += 1
	Engine.time_scale = 0.05
	tree.create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		Fx._hitstop_depth = maxi(0, Fx._hitstop_depth - 1)
		if Fx._hitstop_depth == 0:
			Engine.time_scale = 1.0)


## 放射状の線と飛び散る粒。
static func burst(at: Vector2, color: Color, size: float = 1.0, crumbs: int = 10) -> void:
	var target := layer()
	if target == null:
		return
	var effect := BURST_SCRIPT.new() as Node2D
	effect.position = at
	effect.set("color", color)
	effect.set("size", size)
	effect.set("crumb_count", crumbs)
	target.add_child(effect)


## 漫画の擬音（ドカッ、ザシュ など）。
static func pop_text(at: Vector2, text: String, color: Color, size: int = 30) -> void:
	var target := text_layer()
	if target == null:
		return
	var effect := POP_SCRIPT.new() as Node2D
	effect.position = at
	effect.set("text", text)
	effect.set("color", color)
	effect.set("font_size", size)
	effect.set("rotation_deg", randf_range(-14.0, 14.0))
	target.add_child(effect)


static func damage_number(at: Vector2, amount: float, color: Color = DoodleStyle.CREAM) -> void:
	var target := text_layer()
	if target == null:
		return
	var effect := POP_SCRIPT.new() as Node2D
	effect.position = at + Vector2(randf_range(-10.0, 10.0), 0.0)
	effect.set("text", str(maxi(1, roundi(amount))))
	effect.set("color", color)
	effect.set("font_size", 20)
	effect.set("rise", 46.0)
	effect.set("use_hand_font", false)
	target.add_child(effect)


static func arrow(from: Vector2, to: Vector2) -> void:
	var target := layer()
	if target == null:
		return
	var effect := ARROW_SCRIPT.new() as Node2D
	effect.set("from", from)
	effect.set("to", to)
	target.add_child(effect)


## 地面に残る跡（消しカスやインクの点）。
static func decal(at: Vector2, color: Color, count: int = 6, spread: float = 18.0) -> void:
	var tree := _tree()
	if tree == null:
		return
	var decals := tree.get_first_node_in_group(&"fx_decals")
	if decals != null and decals.has_method("add_marks"):
		decals.add_marks(at, color, count, spread)
