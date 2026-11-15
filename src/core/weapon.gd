class_name WeaponDrop
extends Node2D
## A weapon lying on (or flying through) the stage. Fighters pick it up with
## LB; a held weapon thrown with LB becomes one of these again.

var kind := "sword"
var vel := Vector2.ZERO
var flying := true
var spin := 0.0
var stage_ref: Node = null   # StageNode
var live := true


static func spawn(parent: Node, kind_: String, pos: Vector2, vel_: Vector2, stage_ref_: Node) -> WeaponDrop:
	var d := WeaponDrop.new()
	d.kind = kind_
	d.position = pos
	d.vel = vel_
	d.stage_ref = stage_ref_
	parent.add_child(d)
	return d


func _process(dt: float) -> void:
	spin += dt * 9.0 if flying else dt * 0.5
	if flying:
		vel.y += 2000.0 * dt
		position += vel * dt
		var ground := _ground_below()
		if position.y >= ground and vel.y > 0.0:
			position.y = ground
			flying = false
			vel = Vector2.ZERO
		if stage_ref != null and stage_ref.outside_blast(position):
			live = false
			queue_free()
	queue_redraw()


func _ground_below() -> float:
	if stage_ref == null:
		return 400.0
	return stage_ref.floor_y_at(position.x, position.y)


func nearby(pos: Vector2, radius := 92.0) -> bool:
	return not flying and position.distance_to(pos) <= radius


func _draw() -> void:
	var col: Color = Data.WEAPONS.get(kind, {"color": Color.GRAY})["color"]
	var t := Vector2(0, -8)  # drawn small, held at an angle while flying
	var ang := -0.7 if not flying else sin(spin) * 0.8
	var fwd := Vector2(sin(ang), cos(ang))
	var perp := Vector2(cos(ang), -sin(ang))
	var reach := 34.0
	var tip := t + fwd * reach
	draw_colored_polygon(PackedVector2Array([
		t + perp * 3.4, tip + perp * 2.4, tip - perp * 2.4, t - perp * 3.4,
	]), col.darkened(0.15))
	match kind:
		"hammer":
			var head := PackedVector2Array([
				tip + perp * 10, tip + fwd * 10 - perp * 10,
				tip - fwd * 10 - perp * 10, tip - perp * 10,
			])
			draw_colored_polygon(head, col)
		"spear":
			var th := fwd
			draw_colored_polygon(PackedVector2Array([tip + th * 10, tip - th * 12 + perp * 4, tip - th * 12 - perp * 4]),
					Color(0.92, 0.94, 1.0))
		"sword":
			var guard := t + fwd * 8
			draw_line(guard + perp * 7, guard - perp * 7, Color(0.85, 0.7, 0.3), 2.6)
		"orbstaff":
			draw_circle(tip, 5.0 + 1.2 * sin(spin * 3.0), Color(0.8, 0.65, 1.0))
		"gauntlets":
			draw_circle(t, 7.0, col)
		"bow":
			var pts := PackedVector2Array()
			for i in 10:
				var a: float = lerpf(-1.3, 1.3, float(i) / 9.0)
				pts.append(t + Vector2(sin(a) * 26.0, cos(a) * 26.0).rotated(ang))
			draw_polyline(pts, col, 3.0)
		"daggers":
			draw_colored_polygon(PackedVector2Array([tip, tip - fwd * 14 + perp * 3.4, tip - fwd * 14 - perp * 3.4]),
					Color(0.92, 0.96, 1.0))
	# Pickup hint ring when settled.
	if not flying:
		draw_arc(Vector2(0, -8), 16.0, 0, TAU, 24, Color(1, 1, 1, 0.25 + 0.12 * sin(spin * 2.0)), 2.0)


class Projectile:
	extends Node2D
	## A thrown weapon or an arrow. Rect-based hit checks happen in Match.
	var vel := Vector2.ZERO
	var move: Dictionary = {}   # the move data that launched it
	var owner_index := 0
	var charge := 1.0
	var kind := "sword"
	var arrow := false
	var stage_ref: Node = null
	var live := true
	var life := 2.0

	static func spawn(parent: Node, kind_: String, pos: Vector2, vel_: Vector2,
			move_: Dictionary, owner_index_: int, stage_ref_: Node, is_arrow: bool, charge_: float) -> Projectile:
		var p := Projectile.new()
		p.kind = kind_
		p.position = pos
		p.vel = vel_
		p.move = move_
		p.owner_index = owner_index_
		p.stage_ref = stage_ref_
		p.arrow = is_arrow
		p.charge = charge_
		parent.add_child(p)
		return p

	func _process(dt: float) -> void:
		if not live:
			return
		position += vel * dt
		life -= dt
		if life <= 0.0 or (stage_ref != null and stage_ref.outside_blast(position)):
			queue_free()
			return
		if stage_ref != null:
			var gy: float = stage_ref.floor_y_at(position.x, position.y)
			if position.y >= gy:
				live = false
				Fx.dust(get_parent(), position, Color(0.8, 0.75, 0.6))
				queue_free()
		queue_redraw()

	func rect() -> Rect2:
		var s := Vector2(46, 16)
		return Rect2(position - s * 0.5, s)

	func _draw() -> void:
		var dir := vel.normalized()
		var col: Color = Data.WEAPONS.get(kind, {"color": Color.GRAY})["color"]
		if arrow:
			draw_line(Vector2.ZERO - dir * 20.0, dir * 20.0, Color(0.85, 0.72, 0.5), 3.0)
			draw_colored_polygon(PackedVector2Array([
				dir * 26.0, dir * 12.0 + dir.orthogonal() * 4.0, dir * 12.0 - dir.orthogonal() * 4.0,
			]), Color(0.95, 0.95, 1.0))
		else:
			draw_line(-dir * 18.0, dir * 18.0, col, 5.0)
			draw_circle(dir * 18.0, 6.0, col)
		# speed streak
		draw_line(-dir * 34.0, -dir * 20.0, Color(1, 1, 1, 0.35), 2.0)
