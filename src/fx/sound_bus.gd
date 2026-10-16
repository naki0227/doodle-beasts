extends Node
## 音を鳴らす自動読み込みノード（SoundBus）。効果音の再生器をいくつか使い回し、BGM は 2 つの再生器でクロスフェードする。
## 直接呼ばず、静的クラス Sound を通して使う（-s で起動するテスト用スクリプトが自動読み込みより先にコンパイルされるため）。
## ゲームオーバーで一時停止しても鳴るように、process_mode は Always。

const AUDIO_DIR := "res://assets/audio/"
const SFX_VOICES := 14
## 効果音ごとの基準の音量（dB）。
const SFX_LEVELS := {
	"pen": -14.0, "seal": -4.0, "merge": -2.0, "land": 0.0,
	"hit_blade": -6.0, "hit_heavy": -3.0, "hit_light": -9.0, "bow": -6.0,
	"shatter": -7.0, "frost_spawn": -16.0, "seed_hit": -8.0, "repair": -12.0,
	"horn": -5.0, "tick": -10.0, "ui": -8.0, "wave_clear": -4.0, "gameover": -2.0,
	"enemy_attack": -15.0,
}
const MUSIC_DB := -9.0
## 同じ効果音を続けて鳴らせる最短の間隔（秒）。重なりすぎて割れるのを防ぐ。
const MIN_GAP := 0.045

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name := ""
var _clock := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(SFX_VOICES):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_voices.append(player)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	add_child(_music_a)
	add_child(_music_b)


func _process(delta: float) -> void:
	_clock += delta


func stream(sound_name: String) -> AudioStream:
	if _streams.has(sound_name):
		return _streams[sound_name]
	var path := AUDIO_DIR + sound_name + ".ogg"
	var loaded: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[sound_name] = loaded
	return loaded


func play(sound_name: String, volume_db: float = 0.0, pitch_spread: float = 0.06) -> void:
	var s := stream("sfx_" + sound_name)
	if s == null:
		return
	if _clock - float(_last_played.get(sound_name, -1.0)) < MIN_GAP:
		return
	_last_played[sound_name] = _clock
	var player := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	player.stream = s
	player.volume_db = float(SFX_LEVELS.get(sound_name, -6.0)) + volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	player.play()


func play_music(music_name: String, fade: float = 1.5) -> void:
	if music_name == _music_name:
		return
	_music_name = music_name
	var s := stream(music_name) as AudioStreamOggVorbis
	if s == null:
		return
	s.loop = true
	var incoming := _music_b if _music_a.playing else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	incoming.stream = s
	incoming.volume_db = -60.0
	incoming.play()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(incoming, "volume_db", MUSIC_DB, fade)
	if outgoing.playing:
		tween.tween_property(outgoing, "volume_db", -60.0, fade)
		tween.chain().tween_callback(outgoing.stop)


func stop_music(fade: float = 1.5) -> void:
	_music_name = ""
	var tween := create_tween().set_parallel(true)
	for player in [_music_a, _music_b]:
		if player.playing:
			tween.tween_property(player, "volume_db", -60.0, fade)
	tween.chain().tween_callback(func() -> void:
		_music_a.stop()
		_music_b.stop())


## 書く音のように、鳴らしっぱなしにして音量で出し入れする再生器を作る。
func make_loop_player(parent: Node, sound_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var s := stream("sfx_" + sound_name) as AudioStreamOggVorbis
	if s != null:
		var copy := s.duplicate() as AudioStreamOggVorbis
		copy.loop = true
		player.stream = copy
	player.volume_db = -60.0
	parent.add_child(player)
	return player
