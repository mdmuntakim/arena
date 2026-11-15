class_name Match
extends Node2D
## Runs one fight: stage, two fighters, camera, HUD, controls, audio.
## Modes: vs AI (3 difficulties), training, local 2-player.

signal match_ended(winner_index: int, stats: Dictionary)
signal request_pause

enum SS { COUNTDOWN, FIGHT, PAUSED, END }

var mode := "ai"              # ai | training | local2
var difficulty := 1
var char_ids := ["bram", "sera"]
var stage_id := "sunspire"

var stage_ref: StageNode = null
var fighters: Array = []      # [Fighter, Fighter]
var camera: FightCamera = null
var hud: Node = null          # HUD (CanvasLayer)
var audio: Node = null        # AudioBank
var pads: Array = []          # PadState per fighter
var ai_nodes: Array = []

var match_state := SS.COUNTDOWN
var countdown_t := 3.6
var time_left := Data.MATCH_TIME
var hitstop := 0
var winner := -1
var ended := false

# weapon drops / projectiles
var drops: Array = []
var projectiles: Array = []
var weapon_timer := 4.0

# stats
var stats := {"kos": [0, 0], "damage_dealt": [0.0, 0.0], "time": 0.0}
var combo := {}               # victim -> {count, timer}
var debug_hitboxes := false


func _ready() -> void:
	stage_ref = StageNode.build(self, stage_id)
	# Fighters.
	for i in 2:
		var pad := PadState.new()
		pads.append(pad)
		var f := Fighter.create(i, char_ids[i], self, pad)
		f.stocks = Data.STOCKS if mode != "training" else 1
		f.spawn_point = stage_ref.random_spawn(i)
		f.position = f.spawn_point + Vector2(0, -40)
		add_child(f)
		fighters.append(f)
	# Camera.
	camera = FightCamera.new()
	camera.targets = fighters
	camera.stage_bounds = stage_ref.bounds
	add_child(camera)
	camera.position = stage_ref.random_spawn(0) + Vector2(0, -200)
	# AI for fighter 1 in AI mode (passive dummy in training).
	if mode == "ai" or mode == "training":
		var ai := AiController.new()
		add_child(ai)
		ai.setup(fighters[1], self, difficulty)
		ai.passive = mode == "training"
		ai_nodes.append(ai)
	# HUD + controls + audio (built by main and attached).
	match_state = SS.COUNTDOWN


func attach_ui(hud_: Node, audio_: Node) -> void:
	hud = hud_
	audio = audio_


func fighters_can_act() -> bool:
	return match_state == SS.FIGHT


func stage_center() -> Vector2:
	var main: Rect2 = stage_ref.def["main"]
	return Vector2(main.get_center().x, main.position.y - 60.0)


func _physics_process(dt: float) -> void:
	if hitstop > 0:
		hitstop -= 1
		return
	match match_state:
		SS.COUNTDOWN:
			countdown_t -= dt
			if countdown_t <= 0.0:
				match_state = SS.FIGHT
				if audio != null:
					audio.ui_go()
		SS.FIGHT:
			time_left = maxf(0.0, time_left - dt)
			stats["time"] += dt
			_tick_combat(dt)
			if time_left <= 0.0:
				_end_by_time()
		SS.PAUSED, SS.END:
			pass
	if hud != null:
		hud.queue_redraw()
	if debug_hitboxes:
		queue_redraw()


func _tick_combat(dt: float) -> void:
	# Weapon spawner.
	weapon_timer -= dt
	if weapon_timer <= 0.0 and drops.size() < 4:
		weapon_timer = randf_range(9.0, 13.0)
		_spawn_stage_weapon()
	# Ring-out check.
	for f in fighters:
		if f.state != Fighter.S.KO and stage_ref.outside_blast(f.global_position):
			_ko(f)
	# Projectiles.
	for p in projectiles.duplicate():
		if not is_instance_valid(p) or not p.live:
			continue
		var prect: Rect2 = p.rect()
		for f in fighters:
			if f.index == p.owner_index or f.state == Fighter.S.KO or f.invuln_frames > 0:
				continue
			if prect.intersects(f.hurtbox()) and not p.get_meta("hit_%d" % f.index, false):
				p.set_meta("hit_%d" % f.index, true)
				_connect_hit_projectile(p, f)
	# Ledge grabbing.
	for f in fighters:
		if f.state != Fighter.S.KO and f.state != Fighter.S.LEDGE:
			for l in stage_ref.ledges:
				f.try_grab_ledge(l["point"], l["from"])
	# Combo bookkeeping.
	for f in fighters:
		var c: Dictionary = combo.get(f.get_instance_id(), {})
		if c.is_empty():
			continue
		if f.state == Fighter.S.HITSTUN:
			c["timer"] = 1.2
		else:
			c["timer"] = float(c["timer"]) - dt
			if float(c["timer"]) <= 0.0 or f.state == Fighter.S.KO:
				combo.erase(f.get_instance_id())
	if camera != null:
		camera.snap_update()


# ------------------------------------------------------------------ hits

func try_hit(attacker: Fighter, charge: float) -> void:
	var rect: Rect2 = attacker.attack_hitbox()
	var mv := attacker.attack
	for f in fighters:
		if f == attacker or f.state == Fighter.S.KO or f.invuln_frames > 0:
			continue
		if rect.intersects(f.hurtbox()) and attacker.register_hit(f):
			_connect_hit(attacker, f, mv, charge, rect.get_center())
			return


func _connect_hit(attacker: Fighter, victim: Fighter, mv: Dictionary, charge: float, at: Vector2) -> void:
	var dmg_before := victim.damage
	victim.apply_hit(attacker, mv, charge)
	var dealt: float = victim.damage - dmg_before
	stats["damage_dealt"][attacker.index] += dealt
	# Hitstop freezes both.
	var hs := int(mv["hs"])
	attacker.hitstop_frames = maxi(attacker.hitstop_frames, hs)
	victim.hitstop_frames = maxi(victim.hitstop_frames, hs)
	hitstop = hs
	# FX.
	var heavy: bool = float(mv["dmg"]) >= 18.0
	Fx.sparks(self, at, (attacker.def["aura"] as Color).lightened(0.3), heavy)
	camera.kick(0.5 if heavy else 0.22)
	if audio != null:
		audio.hit_play(dealt, heavy)
	# Combo counter.
	var c: Dictionary = combo.get(victim.get_instance_id(), {"count": 0, "timer": 0})
	c["count"] = int(c["count"]) + 1
	c["timer"] = 1.4
	combo[victim.get_instance_id()] = c
	if hud != null:
		hud.combo_popup(attacker.index, int(c["count"]), dealt)


func _connect_hit_projectile(p: WeaponDrop.Projectile, victim: Fighter) -> void:
	var owner_f: Fighter = null
	for f in fighters:
		if f.index == p.owner_index:
			owner_f = f
	if owner_f == null:
		return
	var at := p.position
	var mv: Dictionary = p.move.duplicate()
	# Launch away from the arrow direction.
	mv["ang"] = clampf(float(mv["ang"]), 5.0, 70.0)
	victim.apply_hit(owner_f, mv, p.charge)
	stats["damage_dealt"][owner_f.index] += victim.last_hit_damage
	var hs := int(mv["hs"])
	hitstop = hs
	camera.kick(0.3)
	Fx.sparks(self, at, (owner_f.def["aura"] as Color).lightened(0.3), false)
	if audio != null:
		audio.hit_play(victim.last_hit_damage, false)
	if hud != null:
		hud.combo_popup(owner_f.index, 1, victim.last_hit_damage)


# ------------------------------------------------------------------- KO

func _ko(f: Fighter) -> void:
	var pos := f.global_position
	var clamped := Vector2(
		clampf(pos.x, stage_ref.blast.position.x + 60.0, stage_ref.blast.end.x - 60.0),
		clampf(pos.y, stage_ref.blast.position.y + 60.0, stage_ref.blast.end.y - 60.0))
	f.state = Fighter.S.KO
	f.velocity = Vector2.ZERO
	Fx.ko_blast(self, clamped, f.def["aura"])
	camera.kick(1.2)
	if audio != null:
		audio.ko_play()
	stats["kos"][1 - f.index] += 1
	if hud != null:
		hud.ko_banner(f.index)
	if mode == "training":
		_training_reset(f)
		return
	f.stocks -= 1
	if f.stocks <= 0:
		winner = 1 - f.index
		_end_match()
	else:
		# Respawn after a short beat.
		var t := get_tree().create_timer(1.4)
		t.timeout.connect(func() -> void:
			if is_instance_valid(f) and f.state == Fighter.S.KO and match_state != SS.END:
				f.respawn(Vector2(stage_center().x + (60.0 if f.index == 0 else -60.0), stage_ref.def["main"].position.y - 420.0)))


func _training_reset(f: Fighter) -> void:
	var t := get_tree().create_timer(0.8)
	t.timeout.connect(func() -> void:
		if is_instance_valid(f):
			f.respawn(Vector2(stage_center().x + (60.0 if f.index == 0 else -60.0), stage_ref.def["main"].position.y - 420.0)))


func _end_match() -> void:
	match_state = SS.END
	ended = true
	if hud != null:
		hud.show_results(winner, stats)
	match_ended.emit(winner, stats)


func _end_by_time() -> void:
	var a: Fighter = fighters[0]
	var b: Fighter = fighters[1]
	if a.stocks != b.stocks:
		winner = 0 if a.stocks > b.stocks else 1
	elif a.damage != b.damage:
		winner = 0 if a.damage < b.damage else 1
	else:
		winner = -1
	_end_match()


# ---------------------------------------------------------------- weapons

func _spawn_stage_weapon() -> void:
	var points: Array = stage_ref.weapon_spawn_points()
	var shuffled := points.duplicate()
	shuffled.shuffle()
	for p in shuffled:
		if _drop_at(p) == null and _fighter_near(p, 170.0) == null:
			var kinds := ["sword", "hammer", "spear", "bow", "daggers", "gauntlets", "orbstaff"]
			drops.append(WeaponDrop.spawn(self, kinds[randi() % kinds.size()], p, Vector2(0, -260), stage_ref))
			if audio != null:
				audio.spawn_play()
			return


func _drop_at(pos: Vector2) -> WeaponDrop:
	for d in drops:
		if is_instance_valid(d) and d.position.distance_to(pos) < 120.0:
			return d
	return null


func _fighter_near(pos: Vector2, r: float) -> Fighter:
	for f in fighters:
		if is_instance_valid(f) and f.state != Fighter.S.KO and f.global_position.distance_to(pos) < r:
			return f
	return null


func nearest_drop(pos: Vector2) -> WeaponDrop:
	var best: WeaponDrop = null
	var best_d := 1e9
	for d in drops:
		if not is_instance_valid(d) or d.flying or not d.live:
			continue
		var dist: float = d.position.distance_to(pos)
		if dist < best_d:
			best_d = dist
			best = d
	return best


func weapon_action(f: Fighter) -> void:
	if f.weapon != "unarmed":
		# Throw the held weapon.
		var tp := Moves.throw_params(f.weapon)
		var vel := Vector2(float(f.facing) * float(tp["speed"]), -180.0)
		var mv := {
			"n": "throw", "dmg": float(tp["dmg"]), "kb": float(tp["kb"]),
			"ks": float(tp["ks"]), "ang": float(tp["ang"]), "hs": 5,
		}
		var p := WeaponDrop.Projectile.spawn(self, f.weapon,
				f.global_position + Vector2(f.facing * 30.0, -64.0), vel, mv, f.index, stage_ref, false, 1.0)
		projectiles.append(p)
		f.set_weapon("unarmed")
		if audio != null:
			audio.throw_play()
		return
	var d := nearest_drop(f.global_position)
	if d != null:
		d.live = false
		d.queue_free()
		f.set_weapon(d.kind)
		if audio != null:
			audio.pickup_play()
		if hud != null:
			hud.pickup_toast(f.index, d.kind)


func drop_weapon(f: Fighter) -> void:
	var kind := f.weapon
	f.set_weapon("unarmed")
	var d := WeaponDrop.spawn(self, kind, f.global_position + Vector2(0, -70),
			Vector2(-float(f.facing) * 260.0, -520.0), stage_ref)
	drops.append(d)


func spawn_projectile(attacker: Fighter, mv: Dictionary, charge: float) -> void:
	var w := attacker.weapon
	var ang := 0.0
	var id: String = mv.get("id", "gl_n")
	if id.ends_with("_u"):
		ang = -0.42
	elif id.ends_with("_d"):
		ang = 0.42
	var dir := Vector2(float(attacker.facing) * cos(ang), sin(ang)).normalized()
	var speed := 1300.0 * charge
	var p := WeaponDrop.Projectile.spawn(self, w,
			attacker.global_position + Vector2(attacker.facing * 40.0, -64.0),
			dir * speed, mv, attacker.index, stage_ref, w == "bow", charge)
	projectiles.append(p)
	if audio != null:
		audio.shoot_play()
	# Bow recoil.
	attacker.velocity.x -= float(attacker.facing) * 60.0


# ------------------------------------------------------------------- pause

func toggle_pause() -> void:
	if match_state == SS.FIGHT:
		match_state = SS.PAUSED
		if hud != null:
			hud.set_paused(true)
	elif match_state == SS.PAUSED:
		match_state = SS.FIGHT
		if hud != null:
			hud.set_paused(false)


# ---------------------------------------------------------------- fx hooks

func fx_dust(pos: Vector2) -> void:
	Fx.dust(self, pos)

func fx_dash(pos: Vector2, facing: int) -> void:
	Fx.dash_line(self, pos, facing)

func fx_dodge(pos: Vector2, col: Color) -> void:
	Fx.dodge_glow(self, pos, col)

func fx_flash(f: Fighter) -> void:
	if is_instance_valid(f.rig):
		var tw := f.rig.create_tween()
		f.rig.modulate = Color(3.2, 2.2, 2.2)
		tw.tween_property(f.rig, "modulate", Color(1, 1, 1), 0.18)

func fx_spawn(f: Fighter) -> void:
	Fx.spawn_ring(self, f.global_position + Vector2(0, -60), f.def["aura"])


# ------------------------------------------------------------------- debug

func _draw() -> void:
	if not debug_hitboxes:
		return
	for f in fighters:
		if not is_instance_valid(f) or f.state == Fighter.S.KO:
			continue
		var col := Color(0.3, 1.0, 0.4, 0.25) if f.invuln_frames > 0 else Color(1.0, 0.9, 0.2, 0.22)
		draw_rect(f.hurtbox(), col, true, -1.0)
		draw_rect(f.hurtbox(), Color(1.0, 0.9, 0.2, 0.7), false, 2.0)
		if f.state == Fighter.S.ATTACK and not bool(f.attack.get("pr", false)):
			var sf: int = f.state_frames
			var st: int = f.attack["st"]
			var ac: int = f.attack["ac"]
			if sf > st and sf <= st + ac:
				draw_rect(f.attack_hitbox(), Color(1.0, 0.25, 0.2, 0.4), true, -1.0)
				draw_rect(f.attack_hitbox(), Color(1.0, 0.25, 0.2, 0.9), false, 2.0)
