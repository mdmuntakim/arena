class_name AiController
extends Node
## Drives a fighter's PadState. Three difficulty levels with different
## reaction time, aggression, dodge chance and mistake rate.

# difficulty: 0 easy, 1 medium, 2 hard
var difficulty := 1
var fighter: Fighter = null
var match_ref: Node = null
var pad: PadState = null

var think_timer := 0.0
var plan := "approach"          # approach, retreat, attack, recover, weapon
var plan_timer := 0.0
var react_cooldown := 0.0
var passive := false            # training dummy: never acts

const CFG := [
	{"react": 0.42, "aggr": 0.5, "dodge": 0.12, "mistake": 0.35, "air": 0.25},
	{"react": 0.24, "aggr": 0.8, "dodge": 0.38, "mistake": 0.16, "air": 0.5},
	{"react": 0.10, "aggr": 1.0, "dodge": 0.68, "mistake": 0.05, "air": 0.75},
]


func setup(f: Fighter, match_node: Node, diff: int) -> void:
	fighter = f
	match_ref = match_node
	difficulty = clampi(diff, 0, 2)
	pad = f.pad
	fighter.weapon_changed.connect(_on_weapon_changed)


func _on_weapon_changed(_f: Fighter) -> void:
	pass


func _process(dt: float) -> void:
	if fighter == null or match_ref == null:
		return
	if passive:
		pad.reset()
		return
	if match_ref.match_state != match_ref.SS.FIGHT:
		pad.reset()
		return
	var cfg: Dictionary = CFG[difficulty]
	think_timer -= dt
	react_cooldown -= dt
	plan_timer -= dt
	_opponent_dead_check()

	if think_timer <= 0.0:
		think_timer = float(cfg["react"]) * randf_range(0.8, 1.3)
		_decide(cfg)
	_execute(dt, cfg)


func _opponent_dead_check() -> void:
	pass


func opponent() -> Fighter:
	for f in match_ref.fighters:
		if f != fighter and f.state != Fighter.S.KO:
			return f
	return null


func _decide(cfg: Dictionary) -> void:
	var opp := opponent()
	if opp == null:
		plan = "idle"
		return
	var to_opp := opp.global_position - fighter.global_position
	var dist := to_opp.length()
	var offstage: bool = not match_ref.stage_ref.inside_stage_margin(fighter.global_position)

	# Recovery first: never DKO ourselves.
	if offstage:
		plan = "recover"
		plan_timer = 1.2
		return

	# Pick up a weapon when close and unarmed.
	if fighter.weapon == "unarmed":
		var drop: WeaponDrop = match_ref.nearest_drop(fighter.global_position)
		if drop != null and fighter.global_position.distance_to(drop.position) < 420.0:
			plan = "weapon"
			plan_timer = 0.9
			return

	# Dodge a nearby attacking opponent sometimes.
	if dist < 260.0 and opp.state == Fighter.S.ATTACK and react_cooldown <= 0.0:
		if randf() < float(cfg["dodge"]):
			react_cooldown = 0.8
			plan = "dodge"
			plan_timer = 0.35
			return

	if dist < _attack_range() and react_cooldown <= 0.0 and randf() < float(cfg["aggr"]):
		plan = "attack"
		plan_timer = 0.25
		react_cooldown = float(cfg["react"])
		return

	plan = "approach" if randf() > float(cfg["mistake"]) * 0.4 else "retreat"
	plan_timer = randf_range(0.4, 1.0)


func _attack_range() -> float:
	var reach: float = 150.0 * float(Data.WEAPONS.get(fighter.weapon, {"reach": 0.9})["reach"])
	return reach + 60.0


func _execute(dt: float, cfg: Dictionary) -> void:
	pad.clear_just()
	var opp := opponent()
	match plan:
		"idle":
			pad.move = Vector2.ZERO
		"approach":
			if opp == null:
				pad.move = Vector2.ZERO
				return
			var to_opp := opp.global_position - fighter.global_position
			pad.move = Vector2(signf(to_opp.x) * 0.9, 0.0)
			# Jump when the opponent is clearly above or a gap is close.
			if to_opp.y < -160.0 and randf() < float(cfg["air"]) * dt * 6.0:
				pad.jump_just = true
			if to_opp.y > 160.0:
				pad.move.y = 0.8
		"retreat":
			if opp != null:
				pad.move = Vector2(signf(fighter.global_position.x - opp.global_position.x) * 0.8, 0.0)
		"attack":
			_plan_attack(opp)
			plan_timer -= dt
			if plan_timer <= 0.0:
				plan = "approach"
		"dodge":
			if randf() < 0.5:
				pad.move = Vector2(0, 0)
			pad.dodge_just = true
			plan = "approach"
		"weapon":
			_plan_weapon(opp)
			if plan_timer <= 0.0:
				plan = "approach"
		"recover":
			_plan_recover()


func _plan_attack(opp: Fighter) -> void:
	if opp == null:
		return
	var to_opp := opp.global_position - fighter.global_position
	pad.move = Vector2(signf(to_opp.x), 0.0)
	fighter.facing = 1 if to_opp.x > 0 else -1
	var dist := absf(to_opp.x)
	var aerial := opp.global_position.y < fighter.global_position.y - 110.0 or not fighter.is_on_floor()
	if dist > 420.0 and fighter.weapon == "bow":
		# Zoning: fire arrows.
		pad.move = Vector2(signf(to_opp.x), -0.2 if absf(to_opp.y) > 130 else 0.0)
		pad.light_just = true
		return
	# Charge a heavy when the opponent is at high damage.
	if opp.damage > 90.0 and dist < 260.0 and randf() < 0.65:
		pad.move = Vector2(signf(to_opp.x) * 0.6, 0.0)
		pad.heavy_just = true
		return
	if aerial:
		if to_opp.y < -110.0 and fighter.is_on_floor():
			pad.jump_just = true
			return
		pad.move = Vector2(signf(to_opp.x), 0.4 if to_opp.y > 40 else 0.0)
		if dist < 190.0:
			pad.light_just = true
	else:
		if to_opp.y < -70.0 and dist < 160.0:
			pad.move = Vector2(0.2 * signf(to_opp.x), -0.9)
		elif to_opp.y > 60.0:
			pad.move = Vector2(0.2 * signf(to_opp.x), 0.9)
		elif dist < 130.0:
			pad.move = Vector2.ZERO
		pad.light_just = true


func _plan_weapon(opp: Fighter) -> void:
	var drop: WeaponDrop = match_ref.nearest_drop(fighter.global_position)
	if drop == null:
		plan = "approach"
		return
	var to_drop: Vector2 = drop.position - fighter.global_position
	pad.move = Vector2(signf(to_drop.x) * 0.9, 0.0)
	if absf(to_drop.x) < 40.0 and to_drop.y > 60.0:
		pad.move.y = 0.9
	if absf(to_drop.x) < 70.0 and absf(to_drop.y) < 100.0:
		pad.pickup_just = true
		plan = "approach"


func _plan_recover() -> void:
	var stage_c: Vector2 = match_ref.stage_center()
	var to_c := stage_c - fighter.global_position
	pad.move = Vector2(signf(to_c.x) * 0.95, 0.0)
	if fighter.is_on_floor():
		plan = "approach"
		return
	if to_c.y < 0 and fighter.velocity.y > 0:
		# Falling offstage: burn jump / wall jump / air dodge toward stage.
		if fighter.jumps_left > 0 or fighter.wall_jumps <= 2:
			pad.jump_just = true
		elif not fighter.air_dodge_used:
			pad.dodge_just = true
			pad.move = Vector2(signf(to_c.x) * 0.9, -0.4)
	elif fighter.velocity.y > 400.0:
		pad.jump_just = true
