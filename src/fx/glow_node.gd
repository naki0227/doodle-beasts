class_name GlowNode
extends Node2D
## 加算合成で光を描く子ノード。持ち主の draw_glow_into(self) を呼んで中身を描いてもらう。


var owner_node: Node


func _ready() -> void:
	material = DoodleStyle.glow_material()
	z_index = 2


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if owner_node != null and is_instance_valid(owner_node) and owner_node.has_method("draw_glow_into"):
		owner_node.draw_glow_into(self)


static func attach(to: Node) -> GlowNode:
	var glow := GlowNode.new()
	glow.owner_node = to
	to.add_child(glow)
	return glow
