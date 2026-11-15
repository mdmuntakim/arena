class_name Fighter
extends CharacterBody2D
## A platform-fighter body: movement, attacks, dodges, knockback, ledge play.
## Pure logic + physics; all rendering lives in the attached Rig.

signal hit_connected(attacker: Fighter, defender: Fighter, move: Dictionary)
signal hit_received(defender: Fighter, move: Dictionary)
signal ko_fighter(fighter: Fighter)
signal weapon_changed(fighter: Fighter)

enum S { IDLE, RUN, DASH, AIR, ATTACK, DODGE, HITSTUN, LEDGE, RESPAWN, TAUNT, KO }

const HARD_FLOOR_LAYER := 1      # bit 0
const SOFT_PLATFORM_LAYER := 2   # bit 1
const WALL_LAYER := 4            # bit 2

# Body metrics (origin at the feet, y grows down).
const BODY_W := 64.0
const BODY_H := 118.0
const HANG_Y := -46.0            # feet offset while hanging on a ledge

var index := 0
var char_id := "bram"
var def: Dictionary
var match_ref: Node = null       # Match
var pad: PadState                # filled by touch pad / AI / keyboard
var is_ai := false
var rig: Node2D = null           # Rig

# --- combat state
var damage := 0.0
var stocks := Data.STOCKS
var weapon := "unarmed"
var state := S.IDLE
var state_frames := 0
var facing := 1
var jumps_left := 2
var wall_jumps := 0
var air_dodge_used := false
var air_dodge_cooldown := 0.0
var gc_frames := 0               # gravity-cancel window after an air dodge
var invuln_frames := 0
var ledge_cooldown := 0
var hitstun_frames := 0
var hitstop_frames := 0
var attack: Dictionary = {}
var charge_frames := 0
var attack_hits := {}            # victim -> true, one hit per attack
var dash_attack := false
var last_hit_damage := 0.0
var ledge_point := Vector2.ZERO  # set while hanging
var ledge_from := 0              # -1 left ledge, 1 right ledge
var spawn_point := Vector2.ZERO
var drop_through_timer := 0

# movement constants (scaled per character)
var walk_speed := 230.0
var run_speed := 380.0
var dash_speed := 640.0
var air_max := 320.0
var air_accel := 1500.0
var gravity := 2400.0
var fall_cap := 940.0
var fastfall_cap := 1500.0
var jump_vel := 950.0
var dj_vel := 830.0


static func create(index_: int, char_id_: String, match_ref_: Node, pad_: PadState) -> Fighter:
	var f := Fighter.new()
	f.index = index_
	f.char_id = char_id_
	f.match_ref = match_ref_
	f.pad = pad_
	f.def = Data.CHARACTERS[char_id_]
	return f


func _ready() -> void:
	name = "Fighter%d" % index
	collision_layer = 8
	collision_mask = HARD_FLOOR_LAYER | SOFT_PLATFORM_LAYER | WALL_LAYER
	floor_snap_length = 12.0
	safe_margin = 0.8
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(BODY_W, BODY_H)
	shape.shape = rect
	shape.position = Vector2(0, -BODY_H * 0.5)
	add_child(shape)
	_apply_stats()
	rig = Rig.new()
	rig.fighter = self
	add_child(rig)


func _apply_stats() -> void:
	var sp: float = def["speed"]
	walk_speed = 230.0 * sp
	run_speed = 380.0 * sp
	dash_speed = 640.0 * sp
	air_max = 320.0 * sp
	air_accel = 1500.0 * sp
	gravity = 2400.0
	jump_vel = 950.0 * float(def["jump"])
	dj_vel = 830.0 * float(def["jump"])


# ------------------------------------------------------------------ helpers

func grounded() -> bool:
	return state != S.AIR and is_on_floor()

func alive() -> bool:
	return state != S.KO

func combat_locked() -> bool:
	return state in [S.ATTACK, S.DODGE, S.HITSTUN, S.LEDGE, S.RESPAWN, S.TAUNT]

func hurtbox() -> Rect2:
	return Rect2(global_position.x - BODY_W * 0.5, global_position.y - BODY_H,
			BODY_W, BODY_H)

func attack_hitbox() -> Rect2:
	var off: Vector2 = attack["off"]
	var sz: Vector2 = attack["sz"]
	var center := global_position + Vector2(off.x * float(facing), off.y - BODY_H * 0.5)
	return Rect2(center - sz * 0.5, sz)

func set_weapon(w: String) -> void:
	weapon = w
	weapon_changed.emit(self)

# ------------------------------------------------------------------- tick

func _physics_process(_delta: float) -> void:
	if match_ref == null or state == S.KO:
		return
	if hitstop_frames > 0:
		hitstop_frames -= 1
		return
	if match_ref.match_state == match_ref.SS.END:
		if is_on_floor() and state in [S.IDLE, S.RUN, S.AIR]:
			state = S.IDLE
		velocity.x = move_toward(velocity.x, 0, 2000 * _delta)
		velocity.y = minf(velocity.y + gravity * _delta, fall_cap)
		move_and_slide()
		return

	match state:
		S.RESPAWN:
			_tick_respawn()
		S.LEDGE:
			_tick_ledge()
		S.ATTACK:
			_tick_attack()
		S.DODGE:
			_tick_dodge()
		S.HITSTUN:
			_tick_hitstun()
		S.TAUNT:
			state_frames += 1
			velocity.x = move_toward(velocity.x, 0, 2000 * _delta)
			if state_frames > 66:
				state = S.IDLE
				state_frames = 0
			_common_physics()
		_:
			_free_state()

# ------------------------------------------------------------- free movement

func _free_state() -> void:
	if match_ref.fighters_can_act():
		_read_actions()
	_common_physics()

func _read_actions() -> void:
	var on_floor := is_on_floor()
	var mx := pad.move.x
	var my := pad.move.y

	if on_floor:
		air_dodge_used = false
		wall_jumps = 0

	# Drop-through soft platform: down + jump.
	if on_floor and my > 0.6 and pad.jump_just and _on_soft_floor():
		pad.jump_just = false
		_drop_through()
		return

	# Jump / double jump / wall jump.
	if pad.jump_just:
		pad.jump_just = false
		if on_floor:
			_do_jump(jump_vel)
			return
		elif _at_wall():
			_do_wall_jump()
			return
		elif jumps_left > 0:
			jumps_left -= 1
			_do_jump(dj_vel)
			return

	# Dash (RB): grounded burst of speed, cancellable into attacks.
	if pad.dash_just and on_floor:
		pad.dash_just = false
		_start_dash(1 if (mx > 0.2 or (mx == 0 and facing > 0)) else -1)
		return

	# Dodge (B): spot dodge, roll or air dodge.
	if pad.dodge_just:
		pad.dodge_just = false
		if not on_floor:
			if not air_dodge_used and air_dodge_cooldown <= 0.0:
				_start_air_dodge()
				return
		elif absf(mx) > 0.35 or absf(my) > 0.35:
			_start_dodge(true)
			return
		else:
			_start_dodge(false)
			return

	# Attacks.
	if pad.light_just:
		pad.light_just = false
		_start_attack(_pick_attack(false, false))
		return
	if pad.heavy_just:
		pad.heavy_just = false
		_start_attack(_pick_attack(false, true))
		return

	# Weapon: LB picks up a nearby weapon, or throws the held one.
	if pad.pickup_just:
		pad.pickup_just = false
		match_ref.weapon_action(self)
		return

	if pad.taunt_just:
		pad.taunt_just = false
		if on_floor:
			state = S.TAUNT
			state_frames = 0
			velocity.x = 0
			return

	_update_facing()

func _update_facing() -> void:
	if absf(pad.move.x) > 0.25:
		facing = 1 if pad.move.x > 0 else -1

func _do_jump(v: float) -> void:
	velocity.y = -v
	if absf(pad.move.x) > 0.2:
		velocity.x = pad.move.x * run_speed
	state = S.AIR
	state_frames = 0
	rig.dust_fx()

func _do_wall_jump() -> void:
	var n := get_wall_normal()
	velocity = Vector2(n.x * 640.0, -jump_vel * 0.95)
	facing = 1 if n.x > 0 else -1
	wall_jumps += 1
	jumps_left = 1
	rig.dust_fx()

func _start_dash(dir: int) -> void:
	state = S.DASH
	state_frames = 0
	facing = dir
	velocity = Vector2(dash_speed * dir, 0)
	rig.dash_fx()

func _start_dodge(rolling: bool) -> void:
	state = S.DODGE
	state_frames = 0
	if rolling:
		var dir := Vector2(pad.move.x, 0).normalized()
		facing = 1 if dir.x >= 0 else -1
		velocity = dir * 560.0
		attack = {"n": "roll"}
	else:
		velocity.x = 0
		attack = {"n": "spot_dodge"}
	rig.dodge_fx()

func _start_air_dodge() -> void:
	state = S.DODGE
	state_frames = 0
	air_dodge_used = true
	air_dodge_cooldown = Data.AIR_DODGE_COOLDOWN
	var dir := Vector2(pad.move.x, clampf(pad.move.y, -0.4, 0.6) * 0.5)
	velocity = dir * 380.0
	attack = {"n": "air_dodge"}
	gc_frames = 20

func _drop_through() -> void:
	collision_mask &= ~SOFT_PLATFORM_LAYER
	velocity.y = 260.0
	state = S.AIR
	state_frames = 0
	drop_through_timer = 14
	rig.dust_fx()

func _pick_attack(air: bool, heavy: bool) -> String:
	var mx := pad.move.x
	var my := pad.move.y
	# Dash-cancel attack: attacking during a ground dash reads full forward.
	if state == S.DASH:
		mx = float(facing)
		dash_attack = not air
	var dir := "n"
	if absf(mx) > 0.35:
		dir = "s"
	elif my < -0.4:
		dir = "u"
	elif my > 0.4:
		dir = "d"
	var pre := "a" if air else "g"
	var kind := "l" if not heavy else "h"
	return "%s%s_%s" % [pre, kind, dir]

# ------------------------------------------------------------------- attack

func _start_attack(id: String) -> void:
	attack = Moves.get_move(weapon, id)
	attack["id"] = id
	state_frames = 0
	charge_frames = 0
	attack_hits = {}
	dash_attack = state == S.DASH
	if state == S.DASH:
		velocity.x = dash_speed * 0.75 * facing
	elif id.begins_with("g") and is_on_floor():
		velocity.x = 0
	elif id.begins_with("a"):
		# Gravity cancel: attacking right after an air dodge cancels momentum.
		if gc_frames > 0:
			velocity = Vector2.ZERO
	state = S.ATTACK
	rig.update_swing_hint(attack)

func _tick_attack() -> void:
	state_frames += 1
	var st: int = attack["st"]
	var ac: int = attack["ac"]
	var rc: int = attack["rc"]
	var id: String = attack["id"]
	var dt := get_physics_process_delta_time()
	var chargeable: bool = bool(attack.get("ch", false))

	# Charging heavies: hold in startup while the heavy button is held.
	if chargeable and state_frames > st and pad.heavy_held \
			and charge_frames < Moves.CHARGE_FRAMES:
		charge_frames += 1
		state_frames = st

	if state_frames <= st:
		# Startup: slight aerial drift, grounded attacks stay put.
		if id.begins_with("a"):
			velocity.x = move_toward(velocity.x, pad.move.x * air_max * 0.6, air_accel * 0.4 * dt)
		else:
			velocity.x = move_toward(velocity.x, 0, 3000 * dt)
		_common_physics()
		return

	# Active frames.
	if state_frames <= st + ac:
		if bool(attack.get("pr", false)):
			if state_frames == st + 1:
				match_ref.spawn_projectile(self, attack, charge_scale())
		else:
			match_ref.try_hit(self, charge_scale())
		_common_physics()
		return

	# Recovery.
	if state_frames <= st + ac + rc:
		if id.begins_with("a"):
			velocity.x = move_toward(velocity.x, pad.move.x * air_max * 0.6, air_accel * 0.4 * dt)
		else:
			velocity.x = move_toward(velocity.x, 0, 2400 * dt)
		_common_physics()
		return

	# Done.
	dash_attack = false
	state = S.AIR if not is_on_floor() else S.IDLE
	state_frames = 0

func charge_scale() -> float:
	if charge_frames <= 0:
		return 1.0
	return lerpf(1.0, Moves.CHARGE_MAX, float(charge_frames) / float(Moves.CHARGE_FRAMES))

# -------------------------------------------------------------------- dodge

func _tick_dodge() -> void:
	state_frames += 1
	var f := state_frames
	var kind: String = attack.get("n", "spot_dodge")
	var dur := 22
	var inv_to := 16
	if kind == "air_dodge":
		dur = 20
		inv_to = 14
	elif kind == "roll":
		dur = 20
		inv_to = 14
	if f >= 2 and f <= inv_to:
		invuln_frames = inv_to - f + 2  # stays > 0 across the window, decays after
	var dt := get_physics_process_delta_time()
	if kind == "air_dodge":
		velocity = velocity.move_toward(Vector2.ZERO, 700 * dt)
	elif kind != "roll":
		velocity.x = move_toward(velocity.x, 0, 2600 * dt)
	_common_physics()
	if f >= dur:
		state = S.AIR if not is_on_floor() else S.IDLE
		state_frames = 0

func _tick_hitstun() -> void:
	state_frames += 1
	_common_physics()
	if state_frames >= hitstun_frames:
		state = S.AIR if not is_on_floor() else S.IDLE
		state_frames = 0

# -------------------------------------------------------------------- ledge

func try_grab_ledge(point: Vector2, from: int) -> bool:
	# from: -1 -> grabbing the left edge (hangs left of it), 1 -> right edge.
	if state != S.AIR or velocity.y < 40.0:
		return false
	if combat_locked() or ledge_cooldown > 0 or wall_jumps > 2:
		return false
	var hang := point + Vector2(from * -26.0, HANG_Y)
	if (global_position - hang).length() > 92.0:
		return false
	global_position = hang
	velocity = Vector2.ZERO
	state = S.LEDGE
	state_frames = 0
	ledge_point = point
	ledge_from = from
	invuln_frames = maxi(invuln_frames, 26)
	jumps_left = 1
	air_dodge_used = false
	return true

func _tick_ledge() -> void:
	state_frames += 1
	global_position = ledge_point + Vector2(ledge_from * -26.0, HANG_Y)
	velocity = Vector2.ZERO
	if state_frames > 20:
		invuln_frames = 0
	invuln_frames = maxi(invuln_frames, 1) if state_frames <= 26 else invuln_frames
	var f := state_frames
	var climb := pad.jump_just or pad.move.y < -0.5 or (pad.move.x * -ledge_from > 0.4)
	var drop := pad.move.y > 0.55
	pad.jump_just = false
	if pad.light_just:
		pad.light_just = false
		_leave_ledge(Vector2(-ledge_from * 180.0, -jump_vel * 0.72))
		_start_attack("gl_s")
		return
	if drop and f > 8:
		_leave_ledge(Vector2(0, 100))
		return
	if climb and f > 8:
		_leave_ledge(Vector2(-ledge_from * 300.0, -jump_vel * 0.9))
		return
	if f > 240:
		_leave_ledge(Vector2(0, 100))

func _leave_ledge(v: Vector2) -> void:
	state = S.AIR
	state_frames = 0
	velocity = v
	ledge_cooldown = 22
	invuln_frames = 0

# ------------------------------------------------------------------ respawn

func respawn(at: Vector2) -> void:
	global_position = at + Vector2(0, -160)
	velocity = Vector2.ZERO
	damage = 0.0
	state = S.RESPAWN
	state_frames = 0
	invuln_frames = int(Data.RESPAWN_INVULN * 60.0)
	jumps_left = 2
	air_dodge_used = false
	set_weapon("unarmed")
	rig.respawned()

func _tick_respawn() -> void:
	state_frames += 1
	velocity = Vector2.ZERO
	invuln_frames = maxi(invuln_frames, 1)
	var act := pad.move != Vector2.ZERO or pad.jump_just or pad.light_just \
			or pad.heavy_just or pad.dodge_just
	pad.jump_just = false
	var f := state_frames
	if f > 24 and act:
		invuln_frames = maxi(int(Data.RESPAWN_INVULN * 60.0) - f, 20)
		state = S.AIR
		state_frames = 0
	elif f > 190:
		state = S.AIR
		state_frames = 0

# ------------------------------------------------------------------ physics

func _common_physics() -> void:
	var dt := get_physics_process_delta_time()
	if drop_through_timer > 0:
		drop_through_timer -= 1
		if drop_through_timer == 0:
			collision_mask |= SOFT_PLATFORM_LAYER

	var was_on_floor := is_on_floor()

	match state:
		S.IDLE, S.RUN:
			if is_on_floor():
				var mx := pad.move.x
				if absf(mx) > 0.2:
					var target := run_speed if absf(mx) > 0.62 else walk_speed
					velocity.x = move_toward(velocity.x, mx * target, 4200 * dt)
					state = S.RUN if absf(velocity.x) > walk_speed * 1.05 else S.IDLE
				else:
					velocity.x = move_toward(velocity.x, 0, 3400 * dt)
					if absf(velocity.x) < 20:
						state = S.IDLE
			else:
				state = S.AIR
		S.AIR:
			var mx := pad.move.x
			if absf(mx) > 0.15:
				velocity.x = move_toward(velocity.x, mx * air_max, air_accel * dt)
			else:
				velocity.x = move_toward(velocity.x, 0, 260 * dt)
		S.DASH:
			state_frames += 1
			var t := float(state_frames) / 14.0
			velocity.x = dash_speed * facing * (1.0 - 0.55 * t)
			if state_frames > 14 or not is_on_floor():
				state = S.IDLE if is_on_floor() else S.AIR
				state_frames = 0
		_:
			pass  # ATTACK / DODGE / HITSTUN manage their own velocities

	# Gravity.
	if not is_on_floor() and state != S.RESPAWN:
		var g := gravity
		var falling := velocity.y > 0.0
		if falling and pad.move.y > 0.6:
			g *= 1.8
		var cap := fastfall_cap if (falling and pad.move.y > 0.6) else fall_cap
		velocity.y = minf(velocity.y + g * dt, cap)

	move_and_slide()

	# Landing bookkeeping.
	if is_on_floor() and not was_on_floor:
		rig.dust_fx()
		jumps_left = 2
		wall_jumps = 0
		air_dodge_used = false
		if state in [S.AIR, S.RUN]:
			state = S.IDLE
			state_frames = 0
	if not is_on_floor() and state in [S.IDLE, S.RUN]:
		state = S.AIR

	# Timers.
	invuln_frames = maxi(0, invuln_frames - 1)
	if ledge_cooldown > 0:
		ledge_cooldown -= 1
	if air_dodge_cooldown > 0.0:
		air_dodge_cooldown = maxf(0.0, air_dodge_cooldown - dt)
	if gc_frames > 0:
		gc_frames -= 1

func _on_soft_floor() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if col is Node2D and (col as Node2D).get_meta("soft", false):
			return true
	return false

func _at_wall() -> bool:
	return is_on_wall()

# --------------------------------------------------------------------- hits

func apply_hit(attacker: Fighter, move: Dictionary, charge: float) -> void:
	if state == S.KO or invuln_frames > 0:
		return
	var dmg: float = float(move["dmg"]) * float(attacker.def["power"]) / float(def["defense"]) * charge
	damage = minf(damage + dmg, Data.MAX_DAMAGE)
	last_hit_damage = dmg
	# Velocity scale: base and per-percent terms are in "hand units"; the
	# factor converts them to px/s and weight divides the result.
	var kb: float = (float(move["kb"]) + damage * float(move["ks"])) * 100.0 * charge / float(def["weight"])
	var ang := deg_to_rad(float(move["ang"]))
	var dirx := float(attacker.facing)
	velocity = Vector2(cos(ang) * kb * dirx, -sin(ang) * kb)
	if state == S.LEDGE:
		_leave_ledge(Vector2.ZERO)
	hitstun_frames = int(clampf(kb * 0.024, 6.0, 46.0))
	state = S.HITSTUN
	state_frames = 0
	hitstop_frames = maxi(hitstop_frames, int(move["hs"]))
	facing = 1 if dirx < 0 else -1  # face the attacker
	# Weapon drop on solid hits.
	if weapon != "unarmed" and dmg >= 14.0:
		match_ref.drop_weapon(self)
	pad.clear_just()
	rig.hit_fx()
	hit_received.emit(self, move)
	attacker.hit_connected.emit(attacker, self, move)

func register_hit(victim: Fighter) -> bool:
	if attack_hits.has(victim.get_instance_id()):
		return false
	attack_hits[victim.get_instance_id()] = true
	return true
