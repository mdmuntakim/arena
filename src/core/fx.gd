class_name Fx
extends Object
## One-shot particle/flash effects. Every helper spawns self-freeing nodes.

static func dust(parent: Node, pos: Vector2, col := Color(0.72, 0.66, 0.55)) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 7
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.4
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, 320)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 150.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color = Color(col.r, col.g, col.b, 0.7)
	parent.add_child(p)
	p.emitting = true
	_autofree(p, 1.0)


static func sparks(parent: Node, pos: Vector2, col: Color, heavy: bool) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 14 if heavy else 8
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.32 if heavy else 0.22
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 700)
	p.initial_velocity_min = 240.0
	p.initial_velocity_max = 560.0 if heavy else 380.0
	p.scale_amount_min = 2.2
	p.scale_amount_max = 4.6 if heavy else 3.4
	p.color = Color(col.r, col.g, col.b, 0.95)
	parent.add_child(p)
	p.emitting = true
	_autofree(p, 0.9)
	_flash_ring(parent, pos, 26.0 if heavy else 16.0, col)


static func dash_line(parent: Node, pos: Vector2, facing: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos + Vector2(0, -60)
	p.amount = 10
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.3
	p.direction = Vector2(-facing, -0.1)
	p.spread = 24.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.scale_amount_min = 1.6
	p.scale_amount_max = 3.2
	p.color = Color(1, 1, 1, 0.55)
	parent.add_child(p)
	p.emitting = true
	_autofree(p, 0.8)


static func dodge_glow(parent: Node, pos: Vector2, col: Color) -> void:
	_flash_ring(parent, pos + Vector2(0, -58), 34.0, col, 0.45)


static func ko_blast(parent: Node, pos: Vector2, col: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 60
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.9
	p.spread = 180.0
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = 300.0
	p.initial_velocity_max = 1200.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 8.0
	p.color = col
	parent.add_child(p)
	p.emitting = true
	_autofree(p, 1.4)
	_flash_ring(parent, pos, 150.0, col, 0.8)
	_flash_ring(parent, pos, 90.0, Color(1, 1, 1), 0.9)


static func spawn_ring(parent: Node, pos: Vector2, col: Color) -> void:
	_flash_ring(parent, pos, 60.0, col, 0.7)


static func _flash_ring(parent: Node, pos: Vector2, radius: float, col: Color, dur := 0.35) -> void:
	var r := RingFlash.new()
	r.position = pos
	r.radius = radius
	r.col = col
	r.dur = dur
	parent.add_child(r)


static func _autofree(node: Node, sec: float) -> void:
	var t := node.get_tree().create_timer(sec)
	t.timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free())


class RingFlash:
	extends Node2D
	var radius := 30.0
	var col := Color(1, 1, 1)
	var dur := 0.35
	var t := 0.0

	func _process(dt: float) -> void:
		t += dt
		if t >= dur:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / dur
		draw_arc(Vector2.ZERO, radius * (0.3 + 0.9 * k), 0, TAU, 40,
				Color(col.r, col.g, col.b, (1.0 - k) * 0.8), 6.0 * (1.0 - k) + 1.0)
