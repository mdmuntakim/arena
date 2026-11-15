extends SceneTree
## Automated engine-side tests for Ringfall.
## Run: godot --headless -s tests/run_tests.gd
## Exits 0 on success, 1 on failure. No rendering needed.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	await test_move_tables()
	await test_knockback()
	await test_hit_detection()
	await test_ko_and_stocks()
	await test_input_edges()
	await test_weapon_throw_and_pickup()
	await test_movement_basics()
	await test_ledge_and_dodge()
	await test_ai_runs()
	if failures.is_empty():
		print("ALL TESTS PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in failures:
			print("FAIL: " + f)
		print("%d checks, %d failures" % [checks, failures.size()])
		quit(1)


func check(cond: bool, label: String) -> void:
	checks += 1
	if not cond:
		failures.append(label)
		print("  fail: " + label)
	else:
		print("  ok: " + label)


func make_match(mode: String, diff := 1) -> Match:
	var m := Match.new()
	m.mode = mode
	m.difficulty = diff
	m.char_ids = ["sera", "bram"]
	m.stage_id = "sunspire"
	root.add_child(m)
	m.match_state = Match.SS.FIGHT
	m.countdown_t = 0.0
	return m


func frames(n: int) -> void:
	for i in n:
		await physics_frame


# -------------------------------------------------------------------- moves

func test_move_tables() -> void:
	print("move tables")
	for w in ["unarmed", "hammer", "gauntlets", "daggers", "bow", "spear", "sword", "orbstaff"]:
		for slot in Moves.SLOTS:
			var mv: Dictionary = Moves.get_move(w, slot)
			check(float(mv["dmg"]) > 0.0, "%s/%s has damage" % [w, slot])
			check(int(mv["st"]) > 0 and int(mv["ac"]) > 0 and int(mv["rc"]) > 0,
					"%s/%s has frame data" % [w, slot])
			check((mv["sz"] as Vector2).length() > 10.0, "%s/%s has hitbox size" % [w, slot])
	check(absf(float(Moves.get_move("hammer", "gh_n")["dmg"]) - 27.0) < 0.01, "hammer sig damage as defined")
	check(Moves.CHARGE_MAX > 1.0, "charge scales up")


# ---------------------------------------------------------------- knockback

func test_knockback() -> void:
	print("knockback scaling")
	var m := make_match("training")
	var a: Fighter = m.fighters[0]
	var b: Fighter = m.fighters[1]
	var mv: Dictionary = Moves.get_move("sword", "gl_s")
	# Same hit, victim at 0% vs 100% damage -> velocity must grow.
	b.damage = 0.0
	b.velocity = Vector2.ZERO
	b.apply_hit(a, mv, 1.0)
	var kb_low := b.velocity.length()
	b.damage = 0.0
	await frames(2)
	b.damage = 100.0
	b.velocity = Vector2.ZERO
	b.apply_hit(a, mv, 1.0)
	var kb_bram := b.velocity.length()
	check(kb_bram > kb_low * 1.3, "knockback scales with damage (%.0f -> %.0f)" % [kb_low, kb_bram])
	check(b.velocity.x * a.facing > 0.0, "knockback is directed away from the attacker")
	# A lighter character takes more knockback from the same hit.
	var def_bram: Dictionary = b.def
	b.def = Data.CHARACTERS["sera"]
	b.damage = 100.0
	b.velocity = Vector2.ZERO
	b.apply_hit(a, mv, 1.0)
	var kb_sera := b.velocity.length()
	b.def = def_bram
	check(kb_sera > kb_bram, "heavier character receives less knockback")
	check(absf(kb_sera / kb_bram - float(def_bram["weight"]) / float(Data.CHARACTERS["sera"]["weight"])) < 0.05,
			"weight divides knockback as designed")
	# Hitstun grows with knockback.
	check(b.hitstun_frames > 10, "hitstun assigned from knockback")
	m.queue_free()
	await frames(1)


# -------------------------------------------------------------- hit detect

func test_hit_detection() -> void:
	print("hit detection")
	var m := make_match("training")
	var a: Fighter = m.fighters[0]
	var b: Fighter = m.fighters[1]
	var stage_main: Rect2 = m.stage_ref.def["main"]
	a.global_position = Vector2(-100, stage_main.position.y)
	b.global_position = Vector2(-20, stage_main.position.y)
	a.set_weapon("sword")
	await frames(2)
	a.velocity = Vector2.ZERO
	b.velocity = Vector2.ZERO
	a.facing = 1
	a.damage = 0.0
	b.damage = 0.0
	a.pad.move = Vector2.ZERO
	a.pad.heavy_just = true  # grounded side sig within range
	var saw_hitstop := false
	for i in 30:
		await physics_frame
		if a.hitstop_frames > 0 or b.hitstop_frames > 0 or m.hitstop > 0:
			saw_hitstop = true
	check(b.damage > 20.0, "in-range attack lands (damage %.1f)" % b.damage)
	check(saw_hitstop, "hitstop applied on contact")
	# Out of range: must miss.
	var b2 := b.damage
	b2 = b.damage
	b.state = Fighter.S.IDLE
	a.state = Fighter.S.IDLE
	await frames(60)
	b.global_position = Vector2(600, stage_main.position.y)
	a.global_position = Vector2(-100, stage_main.position.y)
	a.pad.heavy_just = true
	await frames(30)
	check(absf(b.damage - b2) < 0.01, "out-of-range attack misses")
	# Invulnerability blocks hits.
	b.global_position = Vector2(-20, stage_main.position.y)
	b.invuln_frames = 30
	var d_before := b.damage
	a.state = Fighter.S.IDLE
	a.pad.heavy_just = true
	await frames(30)
	check(absf(b.damage - d_before) < 0.01, "invulnerable fighter cannot be hit")
	m.queue_free()
	await frames(1)


# ------------------------------------------------------------- ko / stocks

func test_ko_and_stocks() -> void:
	print("KO and stocks")
	var m := make_match("ai")
	var a: Fighter = m.fighters[0]
	var b: Fighter = m.fighters[1]
	await frames(2)
	check(m.match_state == Match.SS.FIGHT, "match reaches FIGHT")
	check(a.stocks == Data.STOCKS and b.stocks == Data.STOCKS, "3 stocks at start")
	# Ring out fighter 1.
	b.global_position = m.stage_ref.blast.position - Vector2(80, 0)
	await frames(4)
	check(b.state == Fighter.S.KO, "leaving the blast zone is a KO")
	check(a.stocks == Data.STOCKS and b.stocks == Data.STOCKS - 1, "KO costs one stock")
	# Stats recorded.
	check(m.stats["kos"][0] == 1, "KO counted for the opponent")
	# Drain remaining stocks -> match ends with a winner.
	for i in Data.STOCKS - 1:
		# Wait for the respawn beat, then ring out again.
		await frames(110)
		if b.state == Fighter.S.RESPAWN:
			b.state = Fighter.S.AIR
		b.global_position = m.stage_ref.blast.position - Vector2(80, 0)
		await frames(6)
	check(m.match_state == Match.SS.END, "last stock loss ends the match")
	check(m.winner == 0, "fighter 0 declared winner")
	m.queue_free()
	await frames(1)


# ------------------------------------------------------------------ inputs

func test_input_edges() -> void:
	print("input edge mapping")
	var m := make_match("local2")
	var glue := InputGlue.new()
	m.add_child(glue)
	glue.match_ref = m
	var pad: PadState = m.pads[0]
	pad.reset()
	glue._btn(pad, "jump", true)
	check(pad.jump_just and pad.jump_held, "gamepad press produces a just-press")
	glue._btn(pad, "jump", true)
	pad.clear_just()
	check(not pad.jump_just, "holding does not repeat the press")
	glue._btn(pad, "jump", false)
	check(not pad.jump_held, "release clears the hold")
	# Keyboard mapping feeds P1.
	var press := InputEventKey.new()
	press.physical_keycode = KEY_K
	press.pressed = true
	Input.parse_input_event(press)
	await frames(2)
	glue._poll_keyboard(pad)
	check(pad.jump_held, "keyboard K maps to jump")
	var rel := InputEventKey.new()
	rel.physical_keycode = KEY_K
	rel.pressed = false
	Input.parse_input_event(rel)
	await frames(2)
	glue._poll_keyboard(pad)
	check(not pad.jump_held, "keyboard release clears jump")
	# PadState just flags clear together.
	pad.light_just = true
	pad.clear_just()
	check(not pad.light_just, "clear_just clears all edges")
	glue.queue_free()
	m.queue_free()
	await frames(1)


# --------------------------------------------------------- weapon mechanics

func test_weapon_throw_and_pickup() -> void:
	print("weapon pickup / throw")
	var m := make_match("training")
	var a: Fighter = m.fighters[0]
	var b: Fighter = m.fighters[1]
	var stage_main: Rect2 = m.stage_ref.def["main"]
	a.global_position = Vector2(-100, stage_main.position.y)
	b.global_position = Vector2(-20, stage_main.position.y)
	await frames(2)
	# Throwing the held weapon launches a projectile.
	a.set_weapon("sword")
	m.weapon_action(a)
	check(a.weapon == "unarmed", "throwing leaves the fighter unarmed")
	check(m.projectiles.size() == 1, "throw spawns a projectile")
	var dmg_before := b.damage
	await frames(40)
	check(b.damage > dmg_before, "thrown weapon hits on the way through")
	# Stage weapon spawn picks a free point and creates a drop.
	var n_drops := m.drops.size()
	m._spawn_stage_weapon()
	check(m.drops.size() == n_drops + 1, "stage weapon spawned")
	var d: WeaponDrop = m.drops[m.drops.size() - 1]
	d.flying = false
	a.global_position = d.position + Vector2(30, 0)
	m.weapon_action(a)
	check(a.weapon == d.kind, "fighter picks up the nearest weapon")
	m.queue_free()
	await frames(1)


# ----------------------------------------------------------------- movement

func test_movement_basics() -> void:
	print("movement basics")
	var m := make_match("training")
	var a: Fighter = m.fighters[0]
	var main: Rect2 = m.stage_ref.def["main"]
	a.global_position = Vector2(0, main.position.y)
	await frames(4)
	check(a.is_on_floor(), "fighter stands on the stage")
	var y0 := a.global_position.y
	a.pad.jump_just = true
	await frames(10)
	check(a.state == Fighter.S.AIR, "jump leaves the ground")
	check(a.global_position.y < y0 - 40.0, "jump gains height")
	await frames(80)
	check(a.is_on_floor(), "gravity returns the fighter to the stage")
	# Run right.
	a.pad.move = Vector2(1.0, 0)
	await frames(30)
	check(a.velocity.x > 100.0 or a.global_position.x > 100.0, "run input moves the fighter")
	# Fast-fall is faster than a normal fall.
	var f2: Fighter = m.fighters[1]
	f2.global_position = Vector2(200, main.position.y - 300)
	f2.velocity = Vector2.ZERO
	await frames(2)
	var vy_slow := f2.velocity.y
	f2.pad.move = Vector2(0, 1.0)
	await frames(6)
	check(f2.velocity.y > vy_slow, "holding down accelerates the fall")
	m.queue_free()
	await frames(1)


# ------------------------------------------------------------ dodge / ledge

func test_ledge_and_dodge() -> void:
	print("dodge invulnerability and ledges")
	var m := make_match("training")
	var a: Fighter = m.fighters[0]
	var main: Rect2 = m.stage_ref.def["main"]
	a.global_position = Vector2(0, main.position.y)
	await frames(2)
	a.pad.dodge_just = true
	await frames(6)
	check(a.state == Fighter.S.DODGE, "dodge input enters the dodge state")
	check(a.invuln_frames > 0, "dodge grants invulnerability")
	await frames(30)
	check(a.state != Fighter.S.DODGE, "dodge ends after its duration")
	# Ledge grab: fall next to the left edge.
	var ledge: Vector2 = m.stage_ref.ledges[0]["point"]
	a.global_position = ledge + Vector2(-30, 20)
	a.velocity = Vector2(0, 200)
	a.state = Fighter.S.AIR
	await frames(3)
	check(a.state == Fighter.S.LEDGE, "falling fighter snaps to the ledge")
	var d0 := a.damage
	# Hit the hanging fighter after invuln expires.
	await frames(40)
	check(a.invuln_frames == 0, "ledge invulnerability expires")
	a.damage = 0
	m.queue_free()
	await frames(1)


# --------------------------------------------------------------------- AI

func test_ai_runs() -> void:
	print("AI levels")
	for diff in 3:
		var m := make_match("ai", diff)
		var b: Fighter = m.fighters[1]
		var y0 := b.global_position.y
		await frames(120)
		# The AI should act: either moved, jumped, attacked or picked something up.
		var acted := b.global_position.distance_to(Vector2(m.stage_center().x + 60, y0)) > 10.0 \
				or b.state in [Fighter.S.ATTACK, Fighter.S.DASH, Fighter.S.AIR, Fighter.S.DODGE]
		check(acted, "AI difficulty %d makes the fighter act" % diff)
		check(m.fighters[0].state != Fighter.S.KO, "AI difficulty %d: no illegal states" % diff)
		m.queue_free()
		await frames(1)
