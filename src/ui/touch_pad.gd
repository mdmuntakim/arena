class_name TouchPad
extends CanvasLayer
## Xbox-style on-screen controller:
##   Left thumb  - analogue stick (floating, deadzone, no button overlap)
##   Right thumb - ABXY diamond: A=jump, B=dodge/dash, X=light, Y=heavy
##   LB=weapon pickup/throw, RB=dash, LT/RT=taunt, Start=pause, Back=overlay
## True multi-touch: every finger tracked independently in _input().
## Size, opacity, spacing and handedness are adjustable and saved.
## One instance per player; side 0 = normal, 1 = mirrored for local 2P.

signal back_pressed

var side := 0                     # 0: stick left / buttons right, 1: mirrored
var match_ref: Match = null
var player_index := 0
var enabled := true
var legend_visible := false

var joy_active := false
var joy_index := -1
var joy_base := Vector2.ZERO
var joy_vector := Vector2.ZERO
var finger_button := {}           # touch index -> button id
var finger_stick := -1

var _draw_ctl: Control = null
var _last_countdown_hint := ""

# Layout relative to viewport (1920x1080 canvas). Offsets from the cluster
# anchor, scaled by button_scale and spacing.
const CLUSTER := Vector2(1650, 800)
const STICK_HOME := Vector2(260, 820)
const BUTTONS := {
	"A": {"off": Vector2(0, 100), "r": 54.0, "label": "JUMP", "col": Color(0.35, 0.85, 0.3)},
	"B": {"off": Vector2(112, 0), "r": 54.0, "label": "DODGE", "col": Color(0.95, 0.25, 0.2)},
	"X": {"off": Vector2(-112, 0), "r": 54.0, "label": "LIGHT", "col": Color(0.25, 0.55, 0.95)},
	"Y": {"off": Vector2(0, -100), "r": 54.0, "label": "HEAVY", "col": Color(0.95, 0.8, 0.15)},
	"RB": {"off": Vector2(150, -210), "r": 42.0, "label": "DASH", "col": Color(0.8, 0.8, 0.85)},
	"LB": {"off": Vector2(-150, -210), "r": 42.0, "label": "WEAPON", "col": Color(0.8, 0.8, 0.85)},
	"RT": {"off": Vector2(150, 210), "r": 34.0, "label": "TAUNT", "col": Color(0.6, 0.6, 0.68)},
	"LT": {"off": Vector2(-150, 210), "r": 34.0, "label": "EMOTE", "col": Color(0.6, 0.6, 0.68)},
}
const SMALL := {
	"START": {"pos": Vector2(1830, 70), "r": 30.0, "label": "START"},
	"BACK": {"pos": Vector2(90, 70), "r": 30.0, "label": "BACK"},
}


static func attach(parent: Node, match_ref_: Match, side_: int, player_index_: int) -> TouchPad:
	var t := TouchPad.new()
	t.name = "TouchPad%d" % player_index_
	t.side = side_
	t.match_ref = match_ref_
	t.player_index = player_index_
	t.layer = 20
	parent.add_child(t)
	var ctl := Control.new()
	ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctl.draw.connect(t._draw_ui)
	t._draw_ctl = ctl
	t.add_child(ctl)
	return t


func _pad() -> PadState:
	return match_ref.pads[player_index]


func _vp() -> Vector2:
	return _draw_ctl.get_viewport_rect().size if _draw_ctl != null else Vector2(1920, 1080)


func scale_f() -> float:
	return UiSettings.button_scale


func opacity_f() -> float:
	return UiSettings.opacity


func _button_pos(id: String) -> Vector2:
	var vp := _vp()
	var k := vp.x / 1920.0
	var def: Dictionary = BUTTONS[id]
	var off: Vector2 = def["off"]
	var spacing := UiSettings.spacing
	var pos := CLUSTER * k + Vector2(off.x * spacing, off.y) * scale_f() * k
	if side == 1 or UiSettings.left_handed:
		pos.x = vp.x - pos.x
	return pos


func _small_pos(id: String) -> Vector2:
	var vp := _vp()
	var k := vp.x / 1920.0
	var def: Dictionary = SMALL[id]
	var pos: Vector2 = def["pos"] * k
	if side == 1 or UiSettings.left_handed:
		pos.x = vp.x - pos.x
	return pos


func _stick_home() -> Vector2:
	var vp := _vp()
	var home := STICK_HOME * (vp.x / 1920.0)
	if side == 1 or UiSettings.left_handed:
		home.x = vp.x - home.x
	return home


func _stick_zone(pos: Vector2) -> bool:
	# Stick owns its half of the screen; never overlaps the button cluster.
	var vp := _vp()
	var is_left_half := pos.x < vp.x * 0.5
	var want_left := not (side == 1 or UiSettings.left_handed)
	return is_left_half == want_left and _button_at(pos) == ""


func _button_at(pos: Vector2) -> String:
	for id in BUTTONS:
		var c := _button_pos(id)
		var r: float = (BUTTONS[id]["r"] as float) * scale_f() * 1.12
		if pos.distance_to(c) <= r:
			return id
	for id in SMALL:
		var c := _small_pos(id)
		if pos.distance_to(c) <= (SMALL[id]["r"] as float) * 1.3:
			return id
	return ""


# ------------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not enabled or match_ref == null:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_press(t.index, t.position)
		else:
			_release(t.index, t.position)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == finger_stick and joy_active:
			_stick_to(d.position)
		elif finger_button.has(d.index):
			var bid: String = finger_button[d.index]
			# Slide off a button = release.
			if _button_pos(bid).distance_to(d.position) > (BUTTONS.get(bid, SMALL.get(bid, {})).get("r", 40.0) as float) * 1.6:
				_release(d.index, d.position)


func _press(index: int, pos: Vector2) -> void:
	var bid := _button_at(pos)
	if bid != "":
		finger_button[index] = bid
		_button_down(bid)
		_redraw()
		return
	if _stick_zone(pos) and finger_stick == -1:
		finger_stick = index
		joy_active = true
		joy_base = pos
		joy_vector = Vector2.ZERO
		_redraw()


func _release(index: int, _pos: Vector2) -> void:
	if finger_button.has(index):
		var bid: String = finger_button[index]
		finger_button.erase(index)
		_button_up(bid)
		_redraw()
		return
	if index == finger_stick:
		finger_stick = -1
		joy_active = false
		joy_vector = Vector2.ZERO
		_pad().move = Vector2.ZERO
		_redraw()


func _stick_to(pos: Vector2) -> void:
	var v := pos - joy_base
	var max_r := 82.0 * scale_f()
	if v.length() > max_r:
		joy_base += v.normalized() * (v.length() - max_r)
		v = v.normalized() * max_r
	joy_vector = v / max_r
	var dead := 0.18
	var p := _pad()
	if v.length() < dead:
		p.move = Vector2.ZERO
	else:
		p.move = (v - v.normalized() * dead) / (1.0 - dead)


func _button_down(bid: String) -> void:
	var p := _pad()
	if UiSettings.haptics:
		Input.vibrate_handheld(12)
	match bid:
		"A":
			p.jump_held = true
			p.jump_just = true
		"B":
			p.dodge_held = true
			p.dodge_just = true
		"X":
			p.light_held = true
			p.light_just = true
		"Y":
			p.heavy_held = true
			p.heavy_just = true
		"RB":
			p.dash_held = true
			p.dash_just = true
		"LB":
			p.pickup_held = true
			p.pickup_just = true
		"RT", "LT":
			p.taunt_held = true
			p.taunt_just = true
		"START":
			if match_ref != null:
				match_ref.toggle_pause()
		"BACK":
			if match_ref.mode == "training":
				match_ref.debug_hitboxes = not match_ref.debug_hitboxes
			legend_visible = not legend_visible
			back_pressed.emit()
	_redraw()


func _button_up(bid: String) -> void:
	var p := _pad()
	match bid:
		"A":
			p.jump_held = false
		"B":
			p.dodge_held = false
		"X":
			p.light_held = false
		"Y":
			p.heavy_held = false
		"RB":
			p.dash_held = false
		"LB":
			p.pickup_held = false
		"RT", "LT":
			p.taunt_held = false
	_redraw()


func _redraw() -> void:
	if _draw_ctl != null:
		_draw_ctl.queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw_ui() -> void:
	if _draw_ctl == null:
		return
	var f := ThemeDB.fallback_font
	var op := opacity_f()
	# Stick.
	var home := _stick_home()
	var base := joy_base if joy_active else home
	_draw_circle(base, 86.0 * scale_f(), Color(1, 1, 1, op * 0.16), 3.0, op)
	if joy_active:
		var knob := base + joy_vector * 70.0 * scale_f()
		_draw_circle(knob, 34.0 * scale_f(), Color(1, 1, 1, op * 0.8), 0.0, op)
	else:
		_draw_circle(base + Vector2(0, 0), 30.0 * scale_f(), Color(1, 1, 1, op * 0.3), 0.0, op)
	# ABXY + shoulders + triggers.
	var fighter_: Fighter = match_ref.fighters[player_index] if player_index < match_ref.fighters.size() else null
	for id in BUTTONS:
		var c := _button_pos(id)
		var r: float = (BUTTONS[id]["r"] as float) * scale_f()
		var col: Color = BUTTONS[id]["col"]
		var pressed: bool = finger_button.values().has(id)
		_draw_circle(c, r, Color(col.r, col.g, col.b, op * (0.75 if pressed else 0.38)), 3.0, op)
		_draw_glyph(c, id, col, op)
		var label: String = BUTTONS[id]["label"]
		# Contextual hint under B: dodge names change with the situation.
		if id == "B" and fighter_ != null:
			label = _b_hint(fighter_)
		if id == "Y" and fighter_ != null and fighter_.state == Fighter.S.ATTACK and fighter_.charge_frames > 0:
			label = "CHARGE"
			var g := float(fighter_.charge_frames) / float(Moves.CHARGE_FRAMES)
			_draw_ctl.draw_arc(c, r + 9.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(g, 0.0, 1.0), 32,
					Color(1, 0.9, 0.4, op), 5.0, true)
		var fs := int(15.0 * scale_f())
		var m := f.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		_draw_ctl.draw_string(f, c + Vector2(-m.x * 0.5, r + 4.0 + fs), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, op * 0.85))
	for id in SMALL:
		var c := _small_pos(id)
		var r: float = (SMALL[id]["r"] as float) * scale_f()
		var pressed: bool = finger_button.values().has(id)
		_draw_circle(c, r, Color(0.9, 0.9, 0.95, op * (0.6 if pressed else 0.3)), 2.0, op)
		var fs := int(13.0 * scale_f())
		var m := f.get_string_size(id, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		_draw_ctl.draw_string(f, c + Vector2(-m.x * 0.5, fs * 0.36), id,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, op))
	# Controls legend overlay.
	if legend_visible:
		_draw_legend(f, op)


func _b_hint(f: Fighter) -> String:
	if not f.is_on_floor():
		return "AIR DODGE" if not f.air_dodge_used else "USED"
	if f.state == Fighter.S.DASH:
		return "DASH ATK"
	return "ROLL" if absf(_pad().move.x) > 0.35 else "DODGE"


func _draw_circle(center: Vector2, radius: float, col: Color, ring: float, op: float) -> void:
	if ring > 0.0:
		_draw_ctl.draw_circle(center, radius, Color(col.r, col.g, col.b, col.a * 0.3))
		_draw_ctl.draw_arc(center, radius, 0, TAU, 40, Color(1, 1, 1, op * 0.55), ring, true)
	else:
		_draw_ctl.draw_circle(center, radius, col)


func _draw_glyph(c: Vector2, id: String, col: Color, op: float) -> void:
	var f := ThemeDB.fallback_font
	var fs := int(30.0 * scale_f())
	var ch := ""
	match id:
		"A", "B", "X", "Y":
			ch = id
		_:
			ch = id
	var m := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	_draw_ctl.draw_string(f, c + Vector2(-m.x * 0.5, fs * 0.36), ch,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, op))


func _draw_legend(f: Font, op: float) -> void:
	var vp := _vp()
	var lines := [
		"A  jump / double jump / wall jump      X  light attack (stick aims it)",
		"B  dodge (spot / roll / air dodge)     Y  heavy + signature (hold to charge)",
		"RB dash     LB pickup / throw weapon   LT/RT taunt   START pause",
		"stick: move & aim    down+jump: drop through platforms    stick into ledge: grab",
	]
	var y := vp.y - 40.0 - float(lines.size()) * 30.0
	_draw_ctl.draw_rect(Rect2(vp.x * 0.16, y - 34.0, vp.x * 0.68, lines.size() * 30.0 + 44.0),
			Color(0.03, 0.04, 0.1, 0.6))
	for l in lines:
		var m := f.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
		_draw_ctl.draw_string(f, Vector2(vp.x * 0.5 - m.x * 0.5, y), l,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, op * 0.9))
		y += 30.0
