class_name Menu
extends CanvasLayer
## Title screen -> character select -> stage select -> start a match.
## Also hosts the controller settings panel.

signal start_requested(cfg: Dictionary)

var state := "title"          # title, chars, stages, settings, credits
var mode := "ai"              # ai | training | local2
var difficulty := 1
var pick := [0, 1]            # selected character index per player
var picking := 0              # whose turn in local 2P
var stage_pick := 0

var ctl: Control = null
var screens := {}             # name -> Control


func _ready() -> void:
	layer = 12
	UiSettings.load_settings()
	ctl = Control.new()
	ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctl.draw.connect(_draw_bg)
	add_child(ctl)
	_build_title()
	_build_chars()
	_build_stages()
	_build_settings()
	_build_credits()
	_show("title")


func _font() -> Font:
	return ThemeDB.fallback_font


func _show(name_: String) -> void:
	state = name_
	for k in screens:
		screens[k].visible = k == name_
	if ctl != null:
		ctl.queue_redraw()


# ------------------------------------------------------------------- title

func _build_title() -> void:
	var s := _screen("title")
	_label(s, "RINGFALL", 130, Vector2(0, -250), Color(1, 0.87, 0.35))
	_label(s, "a platform fighter for two thumbs", 28, Vector2(0, -160), Color(1, 1, 1, 0.75))
	_btn(s, "VS AI", func() -> void:
		mode = "ai"
		_show("chars"))
	_btn(s, "TRAINING", func() -> void:
		mode = "training"
		_show("chars"))
	_btn(s, "LOCAL 2P", func() -> void:
		mode = "local2"
		picking = 0
		_show("chars"))
	_btn(s, "CONTROLS", func() -> void: _show("settings"))
	_btn(s, "ABOUT", func() -> void: _show("credits"))
	# Difficulty row for VS AI.
	_label(s, "AI difficulty:", 22, Vector2(0, 210), Color(1, 1, 1, 0.7))
	var diff_row := HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.set_anchors_preset(Control.PRESET_CENTER)
	diff_row.offset_top = 240
	diff_row.offset_left = -300
	diff_row.offset_right = 300
	for i in 3:
		var b := Button.new()
		b.text = ["Easy", "Normal", "Hard"][i]
		b.toggle_mode = true
		b.button_pressed = i == difficulty
		b.add_theme_font_size_override("font_size", 22)
		b.custom_minimum_size = Vector2(170, 50)
		b.pressed.connect(func() -> void:
			difficulty = i
			for c in diff_row.get_children():
				(c as Button).button_pressed = c == b)
		diff_row.add_child(b)
	s.add_child(diff_row)


# ------------------------------------------------------------ character pick

func _build_chars() -> void:
	var s := _screen("chars")
	_label(s, "CHOOSE YOUR FIGHTER", 52, Vector2(0, -380), Color(1, 0.87, 0.35))
	# Cards are drawn in _draw_bg; invisible buttons on top.
	for ci in Data.CHARACTER_IDS.size():
		var cx := _card_center(ci).x
		var cy := _card_center(ci).y
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(360, 480)
		b.position = Vector2(cx - 180, cy - 240)
		b.pressed.connect(func() -> void: _pick_char(ci))
		s.add_child(b)
	_btn(s, "BACK", func() -> void: _show("title"), Vector2(0, 470))
	var confirm := func() -> void:
		if mode == "local2" and picking == 0:
			picking = 1
		else:
			_show("stages")
	_btn(s, "CONFIRM", confirm, Vector2(0, 560))


func _card_center(i: int) -> Vector2:
	var vp := ctl.get_viewport_rect().size
	var k := vp.x / 1920.0
	return Vector2(vp.x * 0.5 + (float(i) - 1.5) * 420.0 * k, vp.y * 0.5 - 20.0 * k)


func _pick_char(ci: int) -> void:
	if mode == "local2" and picking == 1:
		pick[1] = ci
	else:
		pick[0] = ci
		if mode != "local2":
			pick[1] = (ci + 1) % Data.CHARACTER_IDS.size()  # AI takes the next


# ---------------------------------------------------------------- stage pick

func _build_stages() -> void:
	var s := _screen("stages")
	_label(s, "CHOOSE A STAGE", 52, Vector2(0, -330), Color(1, 0.87, 0.35))
	for si in Data.STAGE_IDS.size():
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(460, 420)
		var cx := _stage_center(si).x
		var cy := _stage_center(si).y
		b.position = Vector2(cx - 230, cy - 210)
		var sid: String = Data.STAGE_IDS[si]
		b.pressed.connect(func() -> void:
			stage_pick = si
			_start())
		s.add_child(b)
	_btn(s, "BACK", func() -> void: _show("chars"), Vector2(0, 470))


func _stage_center(i: int) -> Vector2:
	var vp := ctl.get_viewport_rect().size
	var k := vp.x / 1920.0
	return Vector2(vp.x * 0.5 + (float(i) - 1.0) * 520.0 * k, vp.y * 0.5 - 20.0 * k)


func _start() -> void:
	var cfg := {
		"mode": mode,
		"difficulty": difficulty,
		"chars": [Data.CHARACTER_IDS[pick[0]], Data.CHARACTER_IDS[pick[1]]],
		"stage": Data.STAGE_IDS[stage_pick],
	}
	start_requested.emit(cfg)


# ---------------------------------------------------------------- settings

func _build_settings() -> void:
	var s := _screen("settings")
	_label(s, "CONTROLS", 52, Vector2(0, -360), Color(1, 0.87, 0.35))
	_label(s, "On-screen controller settings (saved automatically)", 22, Vector2(0, -290), Color(1, 1, 1, 0.7))
	var rows := [
		["Button size", func(v: float) -> void: UiSettings.button_scale = v, 0.7, 1.6, UiSettings.button_scale],
		["Opacity", func(v: float) -> void: UiSettings.opacity = v, 0.2, 0.9, UiSettings.opacity],
		["Spacing", func(v: float) -> void: UiSettings.spacing = v, 0.8, 1.35, UiSettings.spacing],
	]
	var y := -200
	for row in rows:
		_label(s, row[0], 24, Vector2(0, y - 20), Color(1, 1, 1, 0.85))
		var sl := HSlider.new()
		sl.min_value = row[2]
		sl.max_value = row[3]
		sl.step = 0.01
		sl.value = row[4]
		sl.custom_minimum_size = Vector2(500, 40)
		sl.set_anchors_preset(Control.PRESET_CENTER)
		sl.position = Vector2(-250, float(y) + 10)
		sl.value_changed.connect(func(v: float) -> void:
			row[1].call(v)
			UiSettings.save_settings())
		s.add_child(sl)
		y += 90
	var lh := CheckButton.new()
	lh.text = "Left-handed layout (mirror)"
	lh.add_theme_font_size_override("font_size", 24)
	lh.set_anchors_preset(Control.PRESET_CENTER)
	lh.position = Vector2(-240, float(y) + 10)
	lh.size = Vector2(480, 50)
	lh.button_pressed = UiSettings.left_handed
	lh.toggled.connect(func(b: bool) -> void:
		UiSettings.left_handed = b
		UiSettings.save_settings())
	s.add_child(lh)
	var hp := CheckButton.new()
	hp.text = "Haptics on button press"
	hp.add_theme_font_size_override("font_size", 24)
	hp.set_anchors_preset(Control.PRESET_CENTER)
	hp.position = Vector2(-240, float(y) + 80)
	hp.size = Vector2(480, 50)
	hp.button_pressed = UiSettings.haptics
	hp.toggled.connect(func(b: bool) -> void:
		UiSettings.haptics = b
		UiSettings.save_settings())
	s.add_child(hp)
	_btn(s, "BACK", func() -> void: _show("title"), Vector2(0, 500))


# ------------------------------------------------------------------ credits

func _build_credits() -> void:
	var s := _screen("credits")
	_label(s, "ABOUT", 52, Vector2(0, -330), Color(1, 0.87, 0.35))
	var lines := [
		"Ringfall - an original platform fighter built with Godot 4.5.",
		"4 fighters, 8 weapon types, 3 stages, local AI and 2-player matches.",
		"",
		"Every asset is procedural and original: art, animation, audio.",
		"No content from Brawlhalla or any other game is used.",
		"",
		"Bluetooth Xbox pads use the same mapping as the on-screen buttons.",
	]
	var y := -240
	for l in lines:
		_label(s, l, 24, Vector2(0, y), Color(1, 1, 1, 0.85))
		y += 46
	_btn(s, "BACK", func() -> void: _show("title"), Vector2(0, 500))


# ------------------------------------------------------------- ui helpers

func _screen(name_: String) -> Control:
	var s := Control.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.visible = false
	add_child(s)
	screens[name_] = s
	return s


func _label(parent: Control, text: String, size: int, off: Vector2, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.position = off
	l.custom_minimum_size = Vector2(1200, size + 10)
	l.offset_left = -600
	l.offset_right = 600
	parent.add_child(l)


func _btn(parent: Control, text: String, action: Callable, center := Vector2(0, 0)) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 32)
	b.custom_minimum_size = Vector2(400, 66)
	b.set_anchors_preset(Control.PRESET_CENTER)
	b.position = center - Vector2(200, 33)
	b.offset_left = -200
	b.offset_right = 200
	b.offset_top = center.y - 33
	b.offset_bottom = center.y + 33
	b.pressed.connect(action)
	parent.add_child(b)


# ---------------------------------------------------------------- background

func _draw_bg() -> void:
	var vp := ctl.get_viewport_rect().size
	# Vertical arena sky.
	ctl.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.03, 0.08))
	var grad_steps := 8
	for i in grad_steps:
		var t := float(i) / float(grad_steps - 1)
		var col := Color(0.08, 0.1, 0.22).lerp(Color(0.16, 0.09, 0.24), t)
		ctl.draw_rect(Rect2(0, vp.y * t, vp.x, vp.y / float(grad_steps) + 1.0), col)
	# Arena ring motif behind content.
	var c := Vector2(vp.x * 0.5, vp.y * 0.5)
	ctl.draw_arc(c, vp.y * 0.42, 0, TAU, 64, Color(1, 0.75, 0.3, 0.12), 10.0, true)
	ctl.draw_arc(c, vp.y * 0.34, 0, TAU, 64, Color(1, 0.6, 0.25, 0.08), 4.0, true)
	# Fighters silhouette strip on title.
	if state == "title":
		ctl.draw_rect(Rect2(vp.x * 0.5 - 260, vp.y * 0.62, 520, 8), Color(1, 0.75, 0.3, 0.25))
	# Character cards.
	if state == "chars":
		for i in Data.CHARACTER_IDS.size():
			_draw_char_card(i)
	# Stage cards.
	if state == "stages":
		for i in Data.STAGE_IDS.size():
			_draw_stage_card(i)


func _draw_char_card(i: int) -> void:
	var fnt := _font()
	var id: String = Data.CHARACTER_IDS[i]
	var def: Dictionary = Data.CHARACTERS[id]
	var c := _card_center(i)
	var selected: bool = (mode == "local2" and picking == 1 and pick[1] == i) \
			or pick[0] == i and (mode != "local2" or picking == 0)
	var k := ctl.get_viewport_rect().size.x / 1920.0
	var card := Rect2(c - Vector2(180, 240) * k, Vector2(360, 480) * k)
	ctl.draw_rect(card, Color(0.06, 0.07, 0.14, 0.85))
	ctl.draw_rect(card, Color(1, 0.87, 0.35, 0.9) if selected else Color(1, 1, 1, 0.25), false, 3.0)
	# Bust: head + shoulders in the character palette.
	var head_c := c + Vector2(0, -150) * k
	ctl.draw_circle(head_c, 34 * k, def["skin"])
	ctl.draw_circle(head_c + Vector2(4 * k, -18 * k), 26 * k, def["hair"])
	ctl.draw_rect(Rect2(c - Vector2(70, 60) * k, Vector2(140, 110) * k), def["primary"])
	ctl.draw_rect(Rect2(c - Vector2(70, 60) * k, Vector2(140, 16) * k), def["secondary"])
	ctl.draw_circle(c + Vector2(-70, -5) * k, 14 * k, def["skin"])
	ctl.draw_circle(c + Vector2(70, -5) * k, 14 * k, def["skin"])
	# Eye glint.
	ctl.draw_circle(head_c + Vector2(12 * k, 2 * k), 4 * k, Color(0.1, 0.1, 0.12))
	# Name + weapons.
	ctl.draw_string(fnt, c + Vector2(-170 * k, 130 * k), def["name"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * k), Color(1, 1, 1))
	ctl.draw_string(fnt, c + Vector2(-170 * k, 160 * k), def["desc"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * k), Color(1, 1, 1, 0.7))
	var wn: String = Data.WEAPONS[def["weapons"][0]]["name"] + " / " + Data.WEAPONS[def["weapons"][1]]["name"]
	ctl.draw_string(fnt, c + Vector2(-170 * k, 190 * k), wn,
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * k), Color(0.85, 0.9, 1, 0.85))
	# Stat bars.
	var bars := [["SPEED", def["speed"]], ["POWER", def["power"]], ["WEIGHT", def["weight"]]]
	var by := 224 * k
	for b in bars:
		ctl.draw_string(fnt, c + Vector2(-170 * k, by), b[0],
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * k), Color(1, 1, 1, 0.6))
		var w := clampf(float(b[1]) / 1.3, 0.0, 1.0) * 130.0 * k
		ctl.draw_rect(Rect2(c + Vector2(-70 * k, by - 12 * k), Vector2(130 * k, 9 * k)), Color(1, 1, 1, 0.12))
		ctl.draw_rect(Rect2(c + Vector2(-70 * k, by - 12 * k), Vector2(w, 9 * k)), def["secondary"])
		by += 30 * k
	# Turn indicator in local 2P.
	if mode == "local2":
		var who := "P1 PICKS" if picking == 0 else "P2 PICKS"
		ctl.draw_string(fnt, c + Vector2(-60 * k, -260 * k), who,
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * k), Color(1, 0.87, 0.35, 0.8))


func _draw_stage_card(i: int) -> void:
	var fnt := _font()
	var id: String = Data.STAGE_IDS[i]
	var def: Dictionary = Data.STAGES[id]
	var c := _stage_center(i)
	var k := ctl.get_viewport_rect().size.x / 1920.0
	var card := Rect2(c - Vector2(230, 210) * k, Vector2(460, 420) * k)
	ctl.draw_rect(card, Color(0.06, 0.07, 0.14, 0.85))
	ctl.draw_rect(card, Color(1, 1, 1, 0.25), false, 3.0)
	# Sky gradient of the stage.
	for t in 6:
		var col := (def["sky"] as Color).lerp(def["sky_bottom"] as Color, float(t) / 5.0)
		ctl.draw_rect(Rect2(c + Vector2(-210, -190) * k + Vector2(0, float(t) * 30.0 * k),
				Vector2(420, 31.0 * k)), col)
	# Platform silhouette.
	ctl.draw_rect(Rect2(c + Vector2(-190, 20) * k, Vector2(380, 26) * k), def["ground"])
	ctl.draw_rect(Rect2(c + Vector2(-190, 20) * k, Vector2(380, 6) * k), def["accent"])
	ctl.draw_rect(Rect2(c + Vector2(-150, -60) * k, Vector2(140, 10) * k), def["accent"] * Color(1, 1, 1, 0.7))
	ctl.draw_rect(Rect2(c + Vector2(10, -60) * k, Vector2(140, 10) * k), def["accent"] * Color(1, 1, 1, 0.7))
	ctl.draw_string(fnt, c + Vector2(-210 * k, 100 * k), def["name"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(28 * k), Color(1, 1, 1))
	ctl.draw_string(fnt, c + Vector2(-210 * k, 132 * k), def["desc"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * k), Color(1, 1, 1, 0.7))
	ctl.draw_string(fnt, c + Vector2(-210 * k, 160 * k),
			("night lighting" if def["night"] else "day lighting"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * k), Color(1, 1, 1, 0.55))
