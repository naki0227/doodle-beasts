extends Node2D
## ふわっと出て消える文字。擬音とダメージ数字に使う。

var text: String = ""
var color: Color = DoodleStyle.CREAM
var font_size: int = 30
var rotation_deg: float = 0.0
var rise: float = 26.0
var lifetime: float = 0.7
var use_hand_font: bool = true

var _t := 0.0


func _ready() -> void:
	z_index = 30
	rotation = deg_to_rad(rotation_deg)


func _process(delta: float) -> void:
	_t += delta
	if _t >= lifetime:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / lifetime, 0.0, 1.0)
	var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - k * 6.0) - 0.2 * k
	var alpha := 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
	draw_set_transform(Vector2(0.0, -rise * (1.0 - pow(1.0 - k, 2.0))), 0.0, Vector2(pop, pop))
	var font: Font = DoodleStyle.HAND_FONT if use_hand_font else DoodleStyle.UI_FONT
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(-width * 0.5, font_size * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(DoodleStyle.NIGHT, alpha * 0.9))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, alpha))
