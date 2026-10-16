class_name Sound
extends RefCounted
## 音を鳴らす窓口。Sound.play("shatter") のように、どこからでも呼べる。
## 実体は自動読み込みの SoundBus。見つからない場面（自動読み込みのない環境）では何もしない。


static func _bus() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("SoundBus")


static func play(sound_name: String, volume_db: float = 0.0, pitch_spread: float = 0.06) -> void:
	var bus := _bus()
	if bus != null:
		bus.play(sound_name, volume_db, pitch_spread)


static func music(music_name: String, fade: float = 1.5) -> void:
	var bus := _bus()
	if bus != null:
		bus.play_music(music_name, fade)


static func stop_music(fade: float = 1.5) -> void:
	var bus := _bus()
	if bus != null:
		bus.stop_music(fade)


static func loop_player(parent: Node, sound_name: String) -> AudioStreamPlayer:
	var bus := _bus()
	if bus == null:
		var silent := AudioStreamPlayer.new()
		parent.add_child(silent)
		return silent
	return bus.make_loop_player(parent, sound_name)
