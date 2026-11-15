class_name InputGlue
extends Node
## Feeds the same PadStates as the touch controller:
##  - Keyboard fallback for desktop testing (WASD + J/K/L etc.)
##  - Physical Xbox-layout gamepads: device 0 drives P1, device 1 drives P2.
## Edge detection keeps "just pressed" semantics identical to touch.

var match_ref: Match = null
var key_held := {}

# Xbox button ids in Godot: A=0 B=1 X=2 Y=3 BACK=4 START=6 LB=9 RB=10
const JOY := {"jump": 0, "dodge": 1, "light": 2, "heavy": 3, "back": 4,
		"start": 6, "pickup": 9, "dash": 10}


func _physics_process(_dt: float) -> void:
	if match_ref == null:
		return
	# Assign gamepads to players: first pad -> P1, second -> P2.
	var pads_in_use := Input.get_connected_joypads()
	for i in 2:
		var dev := -1
		if pads_in_use.size() > i:
			dev = pads_in_use[i]
		_poll_gamepad(dev, match_ref.pads[i])
	_poll_keyboard(match_ref.pads[0])
	# Back / T: hitbox overlay in training, legend otherwise.
	if _pressed("back") or _key_edge(KEY_T):
		if match_ref.mode == "training":
			match_ref.debug_hitboxes = not match_ref.debug_hitboxes
	if _pressed("start") or _key_edge(KEY_ENTER) or _key_edge(KEY_ESCAPE):
		if match_ref.match_state in [Match.SS.FIGHT, Match.SS.PAUSED]:
			match_ref.toggle_pause()
	_key_clear()


func _poll_gamepad(dev: int, pad: PadState) -> void:
	if dev < 0:
		return
	_axes_to_move(pad, Input.get_joy_axis(dev, JOY_AXIS_LEFT_X), Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
	# D-pad as movement fallback.
	var dpad := Vector2.ZERO
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT):
		dpad.x -= 1
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT):
		dpad.x += 1
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP):
		dpad.y -= 1
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN):
		dpad.y += 1
	if dpad != Vector2.ZERO:
		pad.move = dpad.normalized()
	_btn(pad, "jump", Input.is_joy_button_pressed(dev, 0))
	_btn(pad, "dodge", Input.is_joy_button_pressed(dev, 1))
	_btn(pad, "light", Input.is_joy_button_pressed(dev, 2))
	_btn(pad, "heavy", Input.is_joy_button_pressed(dev, 3))
	_btn(pad, "pickup", Input.is_joy_button_pressed(dev, 9))
	_btn(pad, "dash", Input.is_joy_button_pressed(dev, 10))
	var taunt: bool = Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > 0.5 \
			or Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER) \
			or Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER)
	_btn(pad, "taunt", taunt)
	# START pauses.
	var start := Input.is_joy_button_pressed(dev, 6)
	if start and not key_held.get("gp%d_start" % dev, false):
		if match_ref.match_state in [Match.SS.FIGHT, Match.SS.PAUSED]:
			match_ref.toggle_pause()
	key_held["gp%d_start" % dev] = start
	var back := Input.is_joy_button_pressed(dev, 4)
	if back and not key_held.get("gp%d_back" % dev, false):
		if match_ref.mode == "training":
			match_ref.debug_hitboxes = not match_ref.debug_hitboxes
	key_held["gp%d_back" % dev] = back


func _axes_to_move(pad: PadState, ax: float, ay: float) -> void:
	var v := Vector2(ax, ay)
	var dead := 0.22
	if v.length() < dead:
		pad.move = Vector2.ZERO
	else:
		pad.move = (v - v.normalized() * dead) / (1.0 - dead)
		pad.move.y = clampf(pad.move.y, -1.0, 1.0)


func _btn(pad: PadState, action: String, held: bool) -> void:
	var key := "gp_" + action
	var prev: bool = key_held.get(key, false)
	match action:
		"jump":
			pad.jump_held = held
			if held and not prev:
				pad.jump_just = true
		"dodge":
			pad.dodge_held = held
			if held and not prev:
				pad.dodge_just = true
		"light":
			pad.light_held = held
			if held and not prev:
				pad.light_just = true
		"heavy":
			pad.heavy_held = held
			if held and not prev:
				pad.heavy_just = true
		"pickup":
			pad.pickup_held = held
			if held and not prev:
				pad.pickup_just = true
		"dash":
			pad.dash_held = held
			if held and not prev:
				pad.dash_just = true
		"taunt":
			pad.taunt_held = held
			if held and not prev:
				pad.taunt_just = true
	key_held[key] = held


func _poll_keyboard(pad: PadState) -> void:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		v.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		v.x += 1
	if Input.is_physical_key_pressed(KEY_W):
		v.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		v.y += 1
	pad.move = v.normalized() if v.length() > 1.0 else v
	_btn(pad, "jump", Input.is_physical_key_pressed(KEY_K))
	_btn(pad, "light", Input.is_physical_key_pressed(KEY_J))
	_btn(pad, "heavy", Input.is_physical_key_pressed(KEY_L))
	_btn(pad, "dodge", Input.is_physical_key_pressed(KEY_SPACE))
	_btn(pad, "dash", Input.is_physical_key_pressed(KEY_SHIFT))
	_btn(pad, "pickup", Input.is_physical_key_pressed(KEY_U))
	_btn(pad, "taunt", Input.is_physical_key_pressed(KEY_I))


func _pressed(action: String) -> bool:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return false
	var id: int = JOY[action]
	var held := Input.is_joy_button_pressed(pads[0], id)
	var prev: bool = key_held.get("edge_" + action, false)
	key_held["edge_" + action] = held
	return held and not prev


func _key_edge(code: int) -> bool:
	var held := Input.is_physical_key_pressed(code)
	var prev: bool = key_held.get("k%d" % code, false)
	key_held["k%d" % code] = held
	return held and not prev


func _key_clear() -> void:
	# Nothing to do: edges are consumed inline each frame.
	pass
