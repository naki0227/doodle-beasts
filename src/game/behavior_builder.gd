class_name BehaviorBuilder
extends RefCounted
## 描いた形から決まった性格・目・武器をもとに、獣のビヘイビアツリーを組み立てる。旅人（自動で動くプレイヤー）のツリーもここで作る。
## 戦闘中に人は操作しない。描いた絵が、そのまま戦い方になる。
##
## 獣のツリー（Root は Selector。上の枝ほど優先）:
##   Whim      謎の武器だけ。気まぐれの間は歩きまわる
##   Withdraw  遊撃だけ。一撃のあと少し身を引く
##   Hunt      性格ごとの標的選び → 攻撃（盾は駒と敵のあいだに割り込む）
##   Home      見張り。駒のそばの持ち場へ戻る
## 目が多いほど見える範囲（標的を探す半径）が広い。弓は距離をとって射る。

const ANNOUNCE := {
	"assault": "突撃！", "skirmish": "先回り！", "guard": "駒を守る！", "bulwark": "立ちはだかる！", "none": "…？",
}


static func _seq(node_name: String, children: Array) -> BTSequence:
	var node := BTSequence.new()
	node.name = node_name
	for child in children:
		node.add_child(child)
	return node


static func _sel(node_name: String, children: Array) -> BTSelector:
	var node := BTSelector.new()
	node.name = node_name
	for child in children:
		node.add_child(child)
	return node


static func _named(node: Node, node_name: String) -> Node:
	node.name = node_name
	return node


static func _announce(text: String) -> BTAnnounce:
	var node := BTAnnounce.new()
	node.name = "Announce"
	node.text = text
	return node


static func _check(method: StringName) -> BTAgentCheck:
	var node := BTAgentCheck.new()
	node.name = "Check_%s" % method
	node.method = method
	return node


## 届けば打つ、届かなければ近づく。keep_distance > 0 なら、近すぎるときは下がってから打つ（弓）。
static func engage(reach: float, keep_distance: float = 0.0) -> BTSelector:
	var in_range := BTIsTargetInRange.new()
	in_range.name = "IsTargetInRange"
	in_range.range = reach
	var strike_children: Array = [in_range]
	if keep_distance > 0.0:
		var keep := BTKeepDistance.new()
		keep.name = "KeepDistance"
		keep.min_distance = keep_distance
		strike_children.append(keep)
	strike_children.append(_named(BTAttackTarget.new(), "AttackTarget"))
	var move := BTMoveToTarget.new()
	move.name = "MoveToTarget"
	move.stop_distance = maxf(10.0, reach - 14.0)
	return _sel("Engage", [_seq("Strike", strike_children), move])


static func build_beast(beast: Beast) -> BTNode:
	var nature: String = beast.nature
	var reach := beast.reach()
	var keep := reach * 0.55 if beast.weapon_kind == ShapeAnalyzer.Weapon.BOW else 0.0
	var branches: Array = []

	if beast.weapon_kind == ShapeAnalyzer.Weapon.UNKNOWN:
		var wander := BTWander.new()
		wander.name = "Wander"
		wander.radius = 260.0
		branches.append(_seq("Whim", [_check(&"is_whimsical"), _announce("きまぐれ…"), wander]))

	if nature == "skirmish":
		branches.append(_seq("Withdraw", [_check(&"is_retreating"), _named(BTRetreat.new(), "Retreat")]))

	var find := BTFindTarget.new()
	find.name = "FindTarget"
	find.group = &"enemies"
	find.radius = beast.vision
	match nature:
		"skirmish":
			find.anchor_group = &"core"
			find.nearest_to_anchor = true
		"guard":
			find.anchor_group = &"core"
			find.anchor_radius = 240.0
		"bulwark":
			find.anchor_group = &"core"
			find.nearest_to_anchor = true
		"none":
			find.radius = minf(beast.vision, 150.0)
	var hunt_tail: Node
	if nature == "bulwark":
		var block_in_range := BTIsTargetInRange.new()
		block_in_range.name = "IsTargetInRange"
		block_in_range.range = reach
		var intercept := BTIntercept.new()
		intercept.name = "Intercept"
		intercept.guard_distance = 130.0
		hunt_tail = _sel("Engage", [_seq("Strike", [block_in_range, _named(BTAttackTarget.new(), "AttackTarget")]), intercept])
	else:
		hunt_tail = engage(reach, keep)
	branches.append(_seq("Hunt", [find, _announce(ANNOUNCE.get(nature, "…？")), hunt_tail]))

	if nature == "none":
		var idle_wander := BTWander.new()
		idle_wander.name = "Wander"
		idle_wander.radius = 180.0
		branches.append(_seq("Home", [_announce("ぼんやり…"), idle_wander]))
	else:
		var home := BTMoveToAnchor.new()
		home.name = "MoveToAnchor"
		home.offset = Vector2(0.0, 120.0) if nature in ["guard", "bulwark"] else Vector2(190.0, 50.0)
		branches.append(_seq("Home", [_announce("見張る"), home]))
	return _sel("Root", branches)


## 旅人。駒に近づいた霜を杖で払い、駒が傷んでいれば直し、何もなければ持ち場で待つ。
static func build_wanderer(player: Node2D, slot: Vector2) -> BTNode:
	var find := BTFindTarget.new()
	find.name = "FindTarget"
	find.group = &"enemies"
	find.radius = 280.0
	find.anchor_group = &"core"
	find.anchor_radius = 200.0
	find.nearest_to_anchor = true
	var defend := _seq("Defend", [find, engage(player.attack_range)])
	var repair := _seq("Repair", [_check(&"core_needs_repair"), _named(BTRepairCore.new(), "RepairCore")])
	var home := BTMoveToAnchor.new()
	home.name = "MoveToAnchor"
	home.offset = slot
	return _sel("Root", [defend, repair, home])


## ツリーを BehaviorTree ノードの中身として差し替える。
static func install(tree_node: BehaviorTree, root: BTNode) -> void:
	for child in tree_node.get_children():
		tree_node.remove_child(child)
		child.queue_free()
	tree_node.add_child(root)
	tree_node.blackboard.clear()
