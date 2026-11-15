class_name Rig
extends Node2D
## Procedural skeletal rig for a fighter. Body parts are polygon chains driven
## by a pose dictionary; poses are computed per state and blended every frame
## (smooth idle -> run -> attack -> hit transitions without animation assets).
## All drawing happens in "facing right" space and is mirrored on the x axis.

var fighter = null   # Fighter; untyped to avoid a cyclic class reference

# blended pose (all values radians / unit scalars)
var cur := {}
var t_global := 0.0
var swing_trail := []   # recent weapon tip angles for the attack trail

const P0 := Vector2(0, -58)        # hips
const TORSO := 44.0                # hip -> neck length
const UPPER_ARM := 24.0
const LOWER_ARM := 23.0
const UPPER_LEG := 30.0
const LOWER_LEG := 28.0


func _ready() -> void:
	z_index = 10
	cur = _neutral()


func _neutral() -> Dictionary:
	return {
		"lean": 0.0, "head": 0.0, "crouch": 0.0,
		"armF1": 0.35, "armF2": 0.35, "armB1": -0.3, "armB2": -0.25,
		"legF1": 0.12, "legF2": 0.06, "legB1": -0.12, "legB2": -0.06,
		"weapon": 0.0, "spin": 0.0, "squash": 1.0,
	}


func _physics_process(dt: float) -> void:
	if fighter == null:
		return
	t_global += dt
	var target := _pose()
	var rate := 14.0
	# Snap instantly on hard transitions (respawn, dodge spin).
	if cur.is_empty() or target.get("snap", false):
		cur = target.duplicate()
		cur.erase("snap")
	else:
		for k in target:
			if cur.has(k):
				cur[k] = lerpf(float(cur[k]), float(target[k]), clampf(rate * dt, 0.0, 1.0))
			else:
				cur[k] = target[k]
	# Attack swing trail decays.
	if not swing_trail.is_empty():
		swing_trail.pop_front()
	queue_redraw()


# --------------------------------------------------------------- poses

func _pose() -> Dictionary:
	var p := _neutral()
	var f = fighter
	var t := float(f.state_frames) / 60.0
	var speed := absf(f.velocity.x) / maxf(f.run_speed, 1.0)
	match f.state:
		fighter.S.IDLE:
			p["lean"] = 0.04 + 0.02 * sin(t_global * 3.0)
			p["armF1"] = 0.3 + 0.06 * sin(t_global * 3.0)
			p["armB1"] = -0.3 - 0.06 * sin(t_global * 3.0)
			p["legF1"] = 0.1
			p["legB1"] = -0.1
			p["crouch"] = 0.03 + 0.02 * sin(t_global * 3.0)
		fighter.S.RUN:
			var phase := t_global * (7.0 + 6.0 * clampf(speed, 0.0, 1.4))
			p["lean"] = 0.2
			p["legF1"] = sin(phase) * 0.85
			p["legF2"] = -maxf(0.0, -sin(phase - 0.7)) * 0.9
			p["legB1"] = sin(phase + PI) * 0.85
			p["legB2"] = -maxf(0.0, -sin(phase + PI - 0.7)) * 0.9
			p["armF1"] = sin(phase + PI) * 0.7
			p["armF2"] = 0.6
			p["armB1"] = sin(phase) * 0.7
			p["armB2"] = 0.6
			p["crouch"] = 0.08
		fighter.S.DASH:
			p["lean"] = 0.42
			p["legF1"] = 0.9
			p["legF2"] = -0.5
			p["legB1"] = -0.7
			p["legB2"] = -0.4
			p["armF1"] = -0.9
			p["armB1"] = 1.0
			p["crouch"] = 0.18
		fighter.S.AIR:
			if f.velocity.y < -60.0:
				p["legF1"] = 0.55
				p["legF2"] = -0.9
				p["legB1"] = -0.35
				p["legB2"] = -0.5
				p["armF1"] = -1.4
				p["armB1"] = 1.2
				p["lean"] = 0.05
			else:
				p["legF1"] = 0.35
				p["legF2"] = -0.35
				p["legB1"] = -0.5
				p["legB2"] = -0.2
				p["armF1"] = -2.1
				p["armF2"] = -0.3
				p["armB1"] = 1.8
				p["lean"] = -0.06
		fighter.S.ATTACK:
			_pose_attack(p)
		fighter.S.DODGE:
			if f.attack.get("n", "") == "roll":
				p["snap"] = true
				p["spin"] = clampf(t, 0.0, 1.0) * TAU
				p["crouch"] = 0.5
				p["legF1"] = 0.8
				p["legF2"] = -1.2
				p["legB1"] = 0.8
				p["legB2"] = -1.2
				p["armF1"] = 0.9
				p["armB1"] = 0.9
			else:
				p["crouch"] = 0.28
				p["lean"] = 0.1
				p["armF1"] = 0.8
				p["armF2"] = 0.7
				p["armB1"] = -0.8
		fighter.S.HITSTUN:
			var k := clampf(t * 3.0, 0.0, 1.0)
			p["lean"] = -0.5 * k
			p["armF1"] = -2.2 * k
			p["armB1"] = 2.2 * k
			p["legF1"] = 0.5 * k
			p["legB1"] = -0.6 * k
			p["head"] = -0.4 * k
		fighter.S.LEDGE:
			p["lean"] = 0.1
			p["armF1"] = -2.6
			p["armF2"] = -0.2
			p["armB1"] = -2.8
			p["armB2"] = -0.2
			p["legF1"] = 0.35
			p["legF2"] = -0.5
			p["legB1"] = -0.2
			p["legB2"] = -0.35
		fighter.S.RESPAWN:
			p["crouch"] = 0.25
			p["lean"] = 0.06
			p["armF1"] = 1.4
			p["armF2"] = 0.4
			p["armB1"] = -1.4
		fighter.S.TAUNT:
			p["lean"] = -0.08 + 0.05 * sin(t * 6.0)
			p["armF1"] = -2.6
			p["armB1"] = -2.6
			p["head"] = -0.15
	return p


func _pose_attack(p: Dictionary) -> void:
	var f = fighter
	var mv: Dictionary = f.attack
	var id: String = mv.get("id", "gl_n")
	var st: int = mv["st"]
	var ac: int = mv["ac"]
	var rc: int = mv["rc"]
	var arc: float = float(mv.get("arc", 1.3))
	# windup -> strike -> follow through
	var prog := 0.0
	if f.state_frames <= st:
		prog = -0.35 * (1.0 - float(f.state_frames) / maxf(float(st), 1.0))
	elif f.state_frames <= st + ac:
		prog = lerpf(0.0, 1.0, float(f.state_frames - st) / float(ac))
	else:
		prog = lerpf(1.0, 0.6, clampf(float(f.state_frames - st - ac) / float(rc), 0.0, 1.0))
	# Base swing angle per direction.
	var base_ang := 0.0
	var swing_from := -arc * 0.6
	if id.ends_with("_u"):
		base_ang = -PI * 0.55
		swing_from = -PI * 0.95
	elif id.ends_with("_d"):
		base_ang = PI * 0.5
		swing_from = -PI * 0.2
	var weapon_ang := base_ang + swing_from + prog * absf(arc)
	p["weapon"] = weapon_ang
	p["lean"] = 0.18 * (1.0 if not id.ends_with("_u") else -0.4)
	p["armF1"] = clampf(weapon_ang, -2.4, 2.4) * 0.55
	p["armF2"] = 0.15
	p["armB1"] = -0.5 - 0.4 * prog
	p["crouch"] = 0.12 if id.ends_with("_d") else 0.02
	p["legF1"] = 0.35
	p["legB1"] = -0.3
	# Daggers: off-hand blade mirrors the swing slightly.
	if f.weapon == "daggers":
		p["armB1"] = clampf(weapon_ang * 0.4, -1.8, 1.8)
	# Record the trail while active.
	if f.state_frames > st and f.state_frames <= st + ac + 2 and f.weapon not in ["bow"]:
		swing_trail.append(weapon_ang)
		if swing_trail.size() > 10:
			swing_trail.pop_front()


# --------------------------------------------------------------- geometry

func _rot_around(p: Vector2, c: Vector2, a: float) -> Vector2:
	var s := sin(a)
	var co := cos(a)
	var d := p - c
	return c + Vector2(d.x * co - d.y * s, d.x * s + d.y * co)


func _out(p: Vector2, spin_center := Vector2.ZERO, spin := 0.0) -> Vector2:
	# rotate (roll spin), then mirror on x for facing
	var q := p
	if spin != 0.0:
		q = _rot_around(p, spin_center, spin)
	return Vector2(q.x * float(fighter.facing), q.y)


func _chain(base: Vector2, a1: float, a2: float, l1: float, l2: float) -> Array:
	var j1 := base + Vector2(sin(a1), cos(a1)) * l1
	var j2 := j1 + Vector2(sin(a1 + a2), cos(a1 + a2)) * l2
	return [base, j1, j2]


func _limb_poly(chain: Array, w0: float, w1: float, w2: float) -> PackedVector2Array:
	var a: Vector2 = chain[0]
	var b: Vector2 = chain[1]
	var c: Vector2 = chain[2]
	var pts := PackedVector2Array()
	var d1 := (b - a).normalized().orthogonal()
	var d2 := (c - b).normalized().orthogonal()
	pts.append(a + d1 * w0)
	pts.append(b + (d1 * w1 + d2 * w1) * 0.5)
	pts.append(c + d2 * w2)
	pts.append(c - d2 * w2)
	pts.append(b - (d1 * w1 + d2 * w1) * 0.5)
	pts.append(a - d1 * w0)
	return pts


func _draw_part(pts: PackedVector2Array, spin_c: Vector2, spin: float, col: Color, outline: Color) -> void:
	var mapped := PackedVector2Array()
	for p in pts:
		mapped.append(_out(p, spin_c, spin))
	if outline.a > 0.0:
		draw_colored_polygon(_grow(mapped, 2.4), outline)
	draw_colored_polygon(mapped, col)


func _grow(pts: PackedVector2Array, amount: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p - c) * (1.0 + amount / maxf((p - c).length(), 1.0)))
	return out


# --------------------------------------------------------------- drawing

func _draw() -> void:
	if fighter == null:
		return
	var def: Dictionary = fighter.def
	var skin: Color = def["skin"]
	var primary: Color = def["primary"]
	var secondary: Color = def["secondary"]
	var hair: Color = def["hair"]
	var outline := primary.darkened(0.55)
	var skin_outline := skin.darkened(0.5)
	var p := cur
	var spin: float = p.get("spin", 0.0)
	var spin_c := Vector2(0, -60)
	var crouch: float = p.get("crouch", 0.0)
	var lean: float = p.get("lean", 0.0)
	var hip := Vector2(0, -58 + crouch * 26.0)
	var neck := hip + Vector2(sin(lean), -cos(lean)) * TORSO
	var head_c := neck + Vector2(sin(lean + p.get("head", 0.0)), -cos(lean + p.get("head", 0.0))) * 16.0

	# Ground shadow (soft ellipse at the feet).
	if absf(spin) < 0.6:
		draw_set_transform(Vector2(0, 1.0), 0.0, Vector2(1.7, 0.42))
		draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 1))

	# Charged heavy glow.
	if fighter.state == fighter.S.ATTACK and fighter.charge_frames > 0:
		var g := float(fighter.charge_frames) / float(Moves.CHARGE_FRAMES)
		var aura: Color = def["aura"]
		draw_circle(_out(hip, spin_c, spin), 42.0 + 16.0 * g,
				Color(aura.r, aura.g, aura.b, 0.10 + 0.16 * g + 0.05 * sin(t_global * 20.0)))

	# Back limbs first.
	var legB := _chain(hip, p["legB1"], p["legB2"], UPPER_LEG, LOWER_LEG)
	_draw_part(_limb_poly(legB, 11.0, 9.5, 7.5), spin_c, spin, primary.darkened(0.3), outline.darkened(0.2))
	var armB := _chain(neck, p["armB1"], p["armB2"], UPPER_ARM, LOWER_ARM)
	_draw_part(_limb_poly(armB, 10.0, 9.0, 7.5), spin_c, spin, primary.darkened(0.25), outline.darkened(0.2))

	# Off-hand weapon (daggers / bow).
	_draw_weapon(armB[2], p["armB1"] + p["armB2"], true, spin_c, spin, secondary)

	# Torso.
	var torso_pts := PackedVector2Array([
		hip + Vector2(-13, 4), hip + Vector2(13, 4),
		neck + Vector2(12, -2), neck + Vector2(-12, -2),
	])
	_draw_part(torso_pts, spin_c, spin, primary, outline)
	# Belt / trim.
	var trim := PackedVector2Array([hip + Vector2(-13, -2), hip + Vector2(13, -2),
			hip + Vector2(13, 4), hip + Vector2(-13, 4)])
	_draw_part(trim, spin_c, spin, secondary, Color(0, 0, 0, 0))

	# Front leg.
	var legF := _chain(hip, p["legF1"], p["legF2"], UPPER_LEG, LOWER_LEG)
	_draw_part(_limb_poly(legF, 11.5, 10.0, 8.0), spin_c, spin, primary, outline)
	# Boots.
	_draw_part(PackedVector2Array([legF[2] + Vector2(-6, -3), legF[2] + Vector2(9, -3),
			legF[2] + Vector2(11, 4), legF[2] + Vector2(-7, 4)]), spin_c, spin, secondary, outline.darkened(0.2))

	# Head.
	var hp := PackedVector2Array()
	var hc := _out(head_c, spin_c, spin)
	var hr := 15.0
	for i in 10:
		var a := TAU * float(i) / 10.0
		hp.append(hc + Vector2(cos(a) * hr, sin(a) * hr * 1.06))
	draw_colored_polygon(_grow(hp, 2.2), skin_outline)
	draw_colored_polygon(hp, skin)
	# Hair cap (mirrored circle slice).
	var hairp := PackedVector2Array()
	for i in 6:
		var a := PI + PI * float(i) / 5.0
		hairp.append(hc + Vector2(cos(a) * (hr + 1.5), sin(a) * (hr + 1.5) * 1.04))
	hairp.append(hc + Vector2(0, -3))
	draw_colored_polygon(hairp, hair)
	# Face: eye + brow (drawn only facing forward enough).
	if absf(spin) < 1.0:
		var ex := hc + Vector2(6.0 * float(fighter.facing), -1.0)
		draw_circle(ex, 2.6, Color(0.08, 0.08, 0.1))
		draw_line(ex + Vector2(-3.0 * fighter.facing, -5.5), ex + Vector2(2.4 * fighter.facing, -5.0),
				Color(0.08, 0.08, 0.1), 2.0)

	# Front arm + main weapon.
	var armF := _chain(neck, p["armF1"], p["armF2"], UPPER_ARM, LOWER_ARM)
	_draw_part(_limb_poly(armF, 10.5, 9.5, 8.0), spin_c, spin, primary, outline)
	_draw_weapon(armF[2], p["armF1"] + p["armF2"], false, spin_c, spin, secondary)
	# Fist.
	draw_circle(_out(armF[2], spin_c, spin), 6.4, skin)

	# Attack swing trail.
	if not swing_trail.is_empty() and fighter.weapon not in ["bow"]:
		var hand_out := _out(armF[2], spin_c, spin)
		var reach := _weapon_reach()
		var prev_ang: float = swing_trail[0]
		for ang in swing_trail:
			_draw_fan_slice(hand_out, prev_ang, ang, reach, def["aura"])
			prev_ang = ang


func _weapon_reach() -> float:
	var w: String = fighter.weapon
	return 70.0 * float(Data.WEAPONS.get(w, {"reach": 0.9})["reach"])


func _draw_fan_slice(center: Vector2, a0: float, a1: float, reach: float, col: Color) -> void:
	# angle 0 = pointing forward in facing space; mirror handled here
	var step := 0.22
	if absf(a1 - a0) < 0.01:
		return
	var n := maxi(2, int(absf(a1 - a0) / step))
	var pts := PackedVector2Array()
	pts.append(center)
	for i in n + 1:
		var a: float = lerpf(a0, a1, float(i) / float(n))
		pts.append(center + Vector2(cos(a) * reach * float(fighter.facing), sin(a) * reach))
	var c := Color(col.r, col.g, col.b, 0.10)
	draw_colored_polygon(pts, c)


func _draw_weapon(hand: Vector2, ang: float, offhand: bool, spin_c: Vector2, spin: float, trim: Color) -> void:
	var f = fighter
	var w: String = f.weapon
	var col: Color = Data.WEAPONS.get(w, {"color": Color.GRAY})["color"]
	var hl := hand + Vector2(sin(ang), cos(ang)) * 6.0
	var tip := hand + Vector2(sin(ang), cos(ang)) * _weapon_reach()
	var perp := Vector2(cos(ang), -sin(ang))
	var mp := func(pp: Vector2) -> Vector2: return _out(pp, spin_c, spin)

	match w:
		"sword", "orbstaff", "spear", "hammer":
			var is_hammer := w == "hammer"
			var shaft_w := 5.0 if not is_hammer else 6.5
			draw_colored_polygon(PackedVector2Array([
				mp.call(hl + perp * shaft_w), mp.call(tip + perp * shaft_w * 0.6),
				mp.call(tip + perp * -shaft_w * 0.6), mp.call(hl - perp * shaft_w),
			]), col)
			match w:
				"sword":
					var guard := hl + (tip - hl).normalized() * 10.0
					draw_line(mp.call(guard + perp * 9.0), mp.call(guard - perp * 9.0), trim, 3.4)
				"spear":
					var th := (tip - hl).normalized()
					var tri := PackedVector2Array([mp.call(tip), mp.call(tip - th * 16 + perp * 5), mp.call(tip - th * 16 - perp * 5)])
					draw_colored_polygon(tri, Color(0.92, 0.94, 1.0))
				"hammer":
					var hd := (tip - hl).normalized()
					var hh := tip - hd * 4.0
					var head_pts := PackedVector2Array([
						mp.call(hh + perp * 18 + hd * 12), mp.call(hh - perp * 18 + hd * 12),
						mp.call(hh - perp * 18 - hd * 12), mp.call(hh + perp * 18 - hd * 12),
					])
					draw_colored_polygon(_grow(head_pts, 2.0), col.darkened(0.35))
					draw_colored_polygon(head_pts, col)
				"orbstaff":
					var orb: Vector2 = tip - (tip - hl).normalized() * 9.0
					var orb_out: Vector2 = mp.call(orb)
					var pulse := 7.0 + 1.5 * sin(t_global * 6.0)
					draw_circle(orb_out, pulse + 4.0, Color(col.r, col.g, col.b, 0.25))
					draw_circle(orb_out, pulse, Color(0.8, 0.65, 1.0))
		"daggers":
			var th := (tip - hl).normalized()
			var tri := PackedVector2Array([mp.call(tip), mp.call(tip - th * 18 + perp * 4), mp.call(tip - th * 18 - perp * 4)])
			draw_colored_polygon(tri, col)
		"bow":
			# Bow arc in the off-hand.
			if offhand:
				var pts := PackedVector2Array()
				var base := hand
				var a0 := ang - 1.4
				for i in 12:
					var a: float = lerpf(a0, ang + 1.4, float(i) / 11.0)
					pts.append(_out(base + Vector2(sin(a), cos(a)) * 34.0, spin_c, spin))
				draw_polyline(pts, col, 3.4)
				var t0 := _out(base + Vector2(sin(a0), cos(a0)) * 34.0, spin_c, spin)
				var t1 := _out(base + Vector2(sin(ang + 1.4), cos(ang + 1.4)) * 34.0, spin_c, spin)
				draw_line(t0, t1, Color(0.95, 0.93, 0.85), 1.6)
		"gauntlets":
			draw_circle(mp.call(hand + Vector2(sin(ang), cos(ang)) * 5.0), 7.4, col)
			draw_circle(mp.call(hand + Vector2(sin(ang), cos(ang)) * 5.0), 4.6, col.lightened(0.3))
		_:
			pass  # unarmed: bare fists already drawn

# ------------------------------------------------------------------ fx hooks

func update_swing_hint(_attack: Dictionary) -> void:
	# The pose already reads the live attack state; kept for API symmetry.
	pass

func dust_fx() -> void:
	if fighter != null and fighter.match_ref != null:
		fighter.match_ref.fx_dust(fighter.global_position)

func dash_fx() -> void:
	if fighter != null and fighter.match_ref != null:
		fighter.match_ref.fx_dash(fighter.global_position, fighter.facing)

func dodge_fx() -> void:
	if fighter != null and fighter.match_ref != null:
		fighter.match_ref.fx_dodge(fighter.global_position, fighter.def["aura"])

func hit_fx() -> void:
	if fighter != null and fighter.match_ref != null:
		fighter.match_ref.fx_flash(fighter)

func respawned() -> void:
	if fighter != null and fighter.match_ref != null:
		fighter.match_ref.fx_spawn(fighter)
