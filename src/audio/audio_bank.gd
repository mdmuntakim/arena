class_name AudioBank
extends Node
## All streams are original generated assets from assets/audio/.
## Music loops by hand (imports do not set loop metadata reliably).

var music: AudioStreamPlayer = null
var _sfx := {}
var _music_tracks := {}
var current_track := ""


func _ready() -> void:
	for k in ["hit_light", "hit_heavy", "whiff", "ko_blast", "jump", "dash",
			"dodge", "pickup", "throw", "shoot", "ui_click", "ui_go",
			"countdown", "victory", "spawn", "taunt"]:
		_sfx[k] = _load_sfx("res://assets/audio/%s.wav" % k)
	for k in ["music_stage1", "music_stage2", "music_stage3", "music_menu"]:
		_music_tracks[k] = _load_sfx("res://assets/audio/%s.wav" % k, true)


func _load_sfx(path: String, _loop := false) -> AudioStream:
	var s := load(path)
	if s == null:
		push_warning("Audio missing: " + path)
	return s


func play_sfx(k: String, vol := 0.0, pitch := 1.0) -> void:
	var s: AudioStream = _sfx.get(k)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = vol
	p.pitch_scale = pitch
	p.bus = "Master"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# ------------------------------------------------------------------ music

func play_music(track: String) -> void:
	if track == current_track and music != null and music.playing:
		return
	current_track = track
	if music != null:
		music.queue_free()
		music = null
	var s: AudioStream = _music_tracks.get(track)
	if s == null:
		return
	music = AudioStreamPlayer.new()
	music.stream = s
	music.volume_db = -9.0
	music.bus = "Master"
	add_child(music)
	music.finished.connect(func() -> void: music.play())
	music.play()


func stop_music() -> void:
	current_track = ""
	if music != null:
		music.queue_free()
		music = null


# ----------------------------------------------------------------- game sfx

func hit_play(dealt: float, heavy: bool) -> void:
	if heavy or dealt >= 16.0:
		play_sfx("hit_heavy", -2.0, randf_range(0.9, 1.05))
	else:
		play_sfx("hit_light", -4.0, randf_range(0.92, 1.12))

func whiff_play() -> void:
	play_sfx("whiff", -10.0, randf_range(0.95, 1.05))

func ko_play() -> void:
	play_sfx("ko_blast", 1.0)

func jump_play() -> void:
	play_sfx("jump", -12.0, randf_range(0.95, 1.1))

func dash_play() -> void:
	play_sfx("dash", -10.0)

func dodge_play() -> void:
	play_sfx("dodge", -8.0)

func pickup_play() -> void:
	play_sfx("pickup", -6.0)

func throw_play() -> void:
	play_sfx("throw", -6.0)

func shoot_play() -> void:
	play_sfx("shoot", -7.0)

func spawn_play() -> void:
	play_sfx("spawn", -10.0)

func taunt_play() -> void:
	play_sfx("taunt", -6.0)

func ui_click() -> void:
	play_sfx("ui_click", -6.0)

func ui_go() -> void:
	play_sfx("ui_go", -2.0)

func countdown_tick(n: int) -> void:
	play_sfx("countdown", -4.0, 1.0 + float(3 - n) * 0.12)

func victory_play() -> void:
	play_sfx("victory", -2.0)
