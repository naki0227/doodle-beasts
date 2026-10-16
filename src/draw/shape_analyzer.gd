class_name ShapeAnalyzer
extends RefCounted
## 描いた線からステータス・性格（戦い方）・目の数・武器を決める。画像認識は使わず、形の量だけで決める。
## 決定的なので、同じ線からは必ず同じ結果が出る（非同期対戦の公平性と、サーバーでの再計算のため）。
## 戦闘は自動で進み、獣は性格と武器に応じて動く（src/game/behavior_builder.gd）。

## ステータスの総量。インクをどれだけ使っても、この上限は超えない。形は「配分」だけを決める。
const STAT_POINTS := 100.0

enum Weapon { NONE, SWORD, SPEAR, HAMMER, CLAWS, SHIELD, BOW, UNKNOWN }

const WEAPON_LABELS := {
	Weapon.NONE: "素手",
	Weapon.SWORD: "剣",
	Weapon.SPEAR: "槍",
	Weapon.HAMMER: "ハンマー",
	Weapon.CLAWS: "爪",
	Weapon.SHIELD: "盾",
	Weapon.BOW: "弓",
	Weapon.UNKNOWN: "謎の武器",
}

## 体の形から決まる性格。獣の戦い方（ビヘイビアツリーの組み方）を決める。
const NATURES := {
	"assault": {"label": "突撃", "description": "いちばん近い霜の獣へ、まっすぐ飛びかかる"},
	"skirmish": {"label": "遊撃", "description": "駒に近い敵を先回りして叩き、一撃ごとに身を引く"},
	"guard": {"label": "守護", "description": "駒のそばを離れず、近づいた敵だけを打つ"},
	"bulwark": {"label": "盾", "description": "駒と敵のあいだに立ちはだかり、敵を引きつける"},
	"none": {"label": "ぼんやり", "description": "まだ何をすればいいかわからない"},
}

## 目の数ごとに広がる、見える範囲。目がなくても少しは見える。
const VISION_BASE := 230.0
const VISION_PER_EYE := 110.0
const MAX_EYES := 6

## 武器ごとの性能。damage_mul は攻撃力の倍率、range は届く距離、interval_mul は攻撃間隔の倍率、
## defense_bonus は被ダメージ軽減の加算。behavior は戦い方への影響（なければ空）。
const WEAPON_PROFILES := {
	Weapon.NONE: {"damage_mul": 0.6, "range": 44.0, "interval_mul": 0.8, "defense_bonus": 0.0, "hint": "何も持っていない", "behavior": ""},
	Weapon.SWORD: {"damage_mul": 1.2, "range": 56.0, "interval_mul": 1.0, "defense_bonus": 0.0, "hint": "細長い。バランス型", "behavior": ""},
	Weapon.SPEAR: {"damage_mul": 1.0, "range": 84.0, "interval_mul": 1.1, "defense_bonus": 0.0, "hint": "とても長い。射程が長い", "behavior": ""},
	Weapon.HAMMER: {"damage_mul": 1.9, "range": 52.0, "interval_mul": 1.7, "defense_bonus": 0.0, "hint": "先が重い。一撃が重く遅い", "behavior": "まわりの敵もまとめて叩く"},
	Weapon.CLAWS: {"damage_mul": 0.55, "range": 46.0, "interval_mul": 0.4, "defense_bonus": 0.0, "hint": "短い線がたくさん。手数で攻める", "behavior": ""},
	Weapon.SHIELD: {"damage_mul": 0.7, "range": 44.0, "interval_mul": 1.0, "defense_bonus": 0.3, "hint": "大きな面。守りが上がる", "behavior": "そばにいると、駒の受ける傷が減る"},
	Weapon.BOW: {"damage_mul": 0.8, "range": 200.0, "interval_mul": 1.3, "defense_bonus": 0.0, "hint": "弧に弦。遠くから撃てる", "behavior": "近づかれたら下がって、距離をとって射る"},
	Weapon.UNKNOWN: {"damage_mul": 1.0, "range": 60.0, "interval_mul": 1.0, "defense_bonus": 0.1, "hint": "何かはわからないが、そこそこ強い", "behavior": "ときどき気まぐれに歩きまわる"},
}


## 体の線からステータスと性格を出す。
## 戻り値: ink, spiky, wide, symmetry, closed, total_points, points{hp,attack,speed,defense}, hp, attack, speed, defense,
##   trait（説明の文字列）, nature（NATURES のキー）, eyes（目の数）, vision（見える範囲）
static func analyze_body(strokes: Array[PackedVector2Array], ink_budget: float) -> Dictionary:
	var ink := StrokeTools.total_length(strokes)
	var result := {
		"ink": ink, "spiky": 0.0, "wide": 0.0, "symmetry": 0.0, "closed": 0.0,
		"total_points": 0.0, "points": {"hp": 0.0, "attack": 0.0, "speed": 0.0, "defense": 0.0},
		"hp": 40.0, "attack": 3.0, "speed": 50.0, "defense": 0.0, "trait": "まだ何も描いていない",
		"nature": "none", "eyes": 0, "vision": VISION_BASE,
	}
	if ink < 1.0 or strokes.is_empty():
		return result

	var corners := 0
	var closed_ink := 0.0
	for stroke in strokes:
		corners += StrokeTools.corner_count(stroke)
		if StrokeTools.is_closed(stroke):
			closed_ink += StrokeTools.length(stroke)
	var rect := StrokeTools.bounds(strokes)
	var aspect := rect.size.x / maxf(1.0, rect.size.y)

	var spiky := clampf(corners / maxf(1.0, ink / 80.0), 0.0, 1.0)
	var wide := clampf((aspect - 0.5) / 1.5, 0.0, 1.0)
	var symmetry := StrokeTools.horizontal_symmetry(strokes)
	var closed := closed_ink / ink

	var total_points := STAT_POINTS * clampf(ink / maxf(1.0, ink_budget), 0.25, 1.0)
	var weights := {
		"hp": 0.8,
		"attack": 0.4 + spiky * 1.2,
		"speed": 0.4 + wide * 1.2,
		"defense": 0.4 + (symmetry + closed) * 0.6,
	}
	var weight_sum := 0.0
	for key in weights:
		weight_sum += weights[key]
	var points := {}
	for key in weights:
		points[key] = total_points * weights[key] / weight_sum

	result["spiky"] = spiky
	result["wide"] = wide
	result["symmetry"] = symmetry
	result["closed"] = closed
	result["total_points"] = total_points
	result["points"] = points
	result["hp"] = 40.0 + points["hp"] * 4.0
	result["attack"] = 3.0 + points["attack"] * 0.5
	result["speed"] = 50.0 + points["speed"] * 3.5
	result["defense"] = clampf(points["defense"] * 0.012, 0.0, 0.6)
	result["trait"] = _trait(spiky, wide, symmetry, closed)
	result["nature"] = _nature(spiky, wide, symmetry, closed)
	var eyes := count_eyes(strokes)
	result["eyes"] = eyes
	result["vision"] = VISION_BASE + VISION_PER_EYE * eyes
	return result


## 目の数。ほかの閉じた形の内側にある、小さな閉じた形（または点）を目とみなす。
static func count_eyes(strokes: Array[PackedVector2Array]) -> int:
	var outlines: Array[PackedVector2Array] = []
	for stroke in strokes:
		if StrokeTools.is_closed(stroke):
			outlines.append(stroke)
	var eyes := 0
	for candidate in strokes:
		var size := StrokeTools.bounds([candidate] as Array[PackedVector2Array]).size
		var small := maxf(size.x, size.y) <= 70.0
		var is_eye_shape := StrokeTools.is_closed(candidate) or StrokeTools.length(candidate) < 6.0
		if not (small and is_eye_shape):
			continue
		var center := StrokeTools.bounds([candidate] as Array[PackedVector2Array]).get_center()
		for outline in outlines:
			if outline != candidate and StrokeTools.length(outline) > StrokeTools.length(candidate) * 2.0 \
					and Geometry2D.is_point_in_polygon(center, outline):
				eyes += 1
				break
	return mini(eyes, MAX_EYES)


static func _nature(spiky: float, wide: float, symmetry: float, closed: float) -> String:
	var guard := (symmetry + closed) * 0.5
	var best := maxf(spiky, maxf(wide, guard))
	if best < 0.25:
		return "bulwark"
	if best == spiky:
		return "assault"
	if best == wide:
		return "skirmish"
	return "guard"


static func nature_label(nature: String) -> String:
	return NATURES.get(nature, NATURES["none"])["label"]


static func nature_description(nature: String) -> String:
	return NATURES.get(nature, NATURES["none"])["description"]


## 目の数を言葉にする。
static func eyes_text(eyes: int) -> String:
	if eyes <= 0:
		return "目がない — 近くしか見えない"
	if eyes == 1:
		return "目がひとつ — ふつうに見える"
	if eyes == 2:
		return "目がふたつ — よく見える"
	return "目が%dつ — 遠くまで見わたす" % eyes


static func _trait(spiky: float, wide: float, symmetry: float, closed: float) -> String:
	match _nature(spiky, wide, symmetry, closed):
		"bulwark":
			return "もっちり → 体力型"
		"assault":
			return "トゲトゲ → 攻撃型"
		"skirmish":
			return "横長 → 俊足型"
		_:
			return "まとまり → 守り型"


## 武器の線から種類を決める。
static func classify_weapon(strokes: Array[PackedVector2Array]) -> Weapon:
	var ink := StrokeTools.total_length(strokes)
	if strokes.is_empty() or ink < 20.0:
		return Weapon.NONE
	var rect := StrokeTools.bounds(strokes)
	var diagonal := maxf(1.0, rect.size.length())
	var longer := maxf(rect.size.x, rect.size.y)
	var shorter := maxf(1.0, minf(rect.size.x, rect.size.y))
	var elongation := longer / shorter

	if _looks_like_bow(strokes, diagonal):
		return Weapon.BOW

	# 片方の端にインクが集まっていて、少しでも細長ければハンマー（柄 + 頭）。
	if elongation >= 1.4 and _ink_concentrated_at_one_end(strokes, rect) >= 0.5:
		return Weapon.HAMMER

	var closed_ink := 0.0
	for stroke in strokes:
		if StrokeTools.is_closed(stroke):
			closed_ink += StrokeTools.length(stroke)
	var closed_ratio := closed_ink / ink
	if closed_ratio >= 0.5 and elongation < 1.8 and _hull_fill(strokes, rect) > 0.45:
		return Weapon.SHIELD

	var average_length := ink / strokes.size()
	if strokes.size() >= 4 and average_length < diagonal * 0.45 and closed_ratio < 0.3 and elongation < 3.0:
		return Weapon.CLAWS

	if elongation >= 2.0:
		return Weapon.SPEAR if elongation >= 4.0 else Weapon.SWORD

	return Weapon.UNKNOWN


static func weapon_label(kind: Weapon) -> String:
	return WEAPON_LABELS[kind]


static func weapon_profile(kind: Weapon) -> Dictionary:
	return WEAPON_PROFILES[kind]


## 弓: 弧（戻ってくる線）と、その両端を結ぶ真っ直ぐな線。
static func _looks_like_bow(strokes: Array[PackedVector2Array], diagonal: float) -> bool:
	if strokes.size() < 2:
		return false
	var near := diagonal * 0.25
	for arc in strokes:
		var arc_ratio := StrokeTools.chord_ratio(arc)
		if arc_ratio < 0.45 or arc_ratio > 0.9 or StrokeTools.length(arc) < diagonal * 0.3:
			continue
		var a0 := arc[0]
		var a1 := arc[arc.size() - 1]
		for string in strokes:
			if string == arc or StrokeTools.chord_ratio(string) < 0.93 or string.size() < 2:
				continue
			var s0 := string[0]
			var s1 := string[string.size() - 1]
			var straight := (s0.distance_to(a0) < near and s1.distance_to(a1) < near)
			var reversed := (s0.distance_to(a1) < near and s1.distance_to(a0) < near)
			if straight or reversed:
				return true
	return false


## 凸包の面積 ÷ 外接矩形の面積。丸や四角は大きく、線は小さい。
static func _hull_fill(strokes: Array[PackedVector2Array], rect: Rect2) -> float:
	var points := StrokeTools.all_points(strokes)
	if points.size() < 3:
		return 0.0
	var hull := Geometry2D.convex_hull(points)
	var area := 0.0
	for i in range(hull.size()):
		var a := hull[i]
		var b := hull[(i + 1) % hull.size()]
		area += a.x * b.y - b.x * a.y
	area = absf(area) * 0.5
	return area / maxf(1.0, rect.get_area())


## 長い方向に沿って見たとき、どちらかの端 35% にインクがどれだけ集まっているか（0〜1）。
## 均一な線なら 0.35 前後。0.5 を超えると「片端に頭がある」とみなす。
static func _ink_concentrated_at_one_end(strokes: Array[PackedVector2Array], rect: Rect2) -> float:
	var horizontal := rect.size.x >= rect.size.y
	var start := rect.position.x if horizontal else rect.position.y
	var span := maxf(1.0, rect.size.x if horizontal else rect.size.y)
	var head := 0
	var tail := 0
	var total := 0
	for point in StrokeTools.sample(strokes, 3.0):
		var t := ((point.x if horizontal else point.y) - start) / span
		total += 1
		if t < 0.35:
			head += 1
		elif t > 0.65:
			tail += 1
	if total == 0:
		return 0.0
	return float(maxi(head, tail)) / total
