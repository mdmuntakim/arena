extends Node2D
## Ringfall - main scene wiring: menu -> match -> results -> menu.
## Everything is built in code; this root only orchestrates the flow.

var menu: Menu
var match_node: Match = null
var hud: HUD = null
var audio: AudioBank
var glue: InputGlue
var last_cfg := {}


func _ready() -> void:
	audio = AudioBank.new()
	audio.name = "AudioBank"
	add_child(audio)
	glue = InputGlue.new()
	glue.name = "InputGlue"
	add_child(glue)
	menu = Menu.new()
	menu.name = "Menu"
	add_child(menu)
	menu.start_requested.connect(_start_match)
	audio.play_music("music_menu")


func _start_match(cfg: Dictionary) -> void:
	last_cfg = cfg
	menu.visible = false
	menu.set_process(false)
	glue.match_ref = null
	if match_node != null:
		match_node.queue_free()
	match_node = Match.new()
	match_node.name = "Match"
	match_node.mode = cfg["mode"]
	match_node.difficulty = cfg["difficulty"]
	match_node.char_ids = cfg["chars"]
	match_node.stage_id = cfg["stage"]
	add_child(match_node)
	match_node.fighters[0].is_ai = cfg["mode"] == "ai"
	match_node.fighters[1].is_ai = cfg["mode"] == "ai"
	# UI on top of the fight.
	hud = HUD.new()
	hud.name = "HUD"
	match_node.add_child(hud)
	hud.match_ref = match_node
	match_node.attach_ui(hud, audio)
	# Touch pads: P1 always; P2 mirrored only in local 2P.
	var p1 := TouchPad.attach(self, match_node, 0, 0)
	var p2: TouchPad = null
	if cfg["mode"] == "local2":
		p2 = TouchPad.attach(self, match_node, 1, 1)
		p2.visible = true
	# Keyboard/gamepad glue.
	glue.match_ref = match_node
	audio.play_music(Data.STAGES[cfg["stage"]]["music"])
	# Menu comes back after the match ends.
	hud.menu_requested.connect(_back_to_menu)
	hud.rematch_requested.connect(_rematch)
	hud.charselect_requested.connect(func() -> void:
		_back_to_menu()
		menu._show("chars"))
	match_node.match_ended.connect(func(_w: int, _s: Dictionary) -> void:
		if p1 != null:
			p1.enabled = false
		if p2 != null and is_instance_valid(p2):
			p2.enabled = false)


func _rematch() -> void:
	_start_match(last_cfg)


func _back_to_menu() -> void:
	if match_node != null:
		match_node.queue_free()
		match_node = null
	if hud != null:
		hud.queue_free()
		hud = null
	glue.match_ref = null
	# Kill leftover touch pads.
	for c in get_children():
		if c is TouchPad:
			c.queue_free()
	menu.visible = true
	menu.set_process(true)
	menu._show("title")
	audio.play_music("music_menu")
