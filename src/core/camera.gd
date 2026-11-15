class_name FightCamera
extends Camera2D
## Dynamic fight camera: follows the midpoint of the fighters, zooms with
## their separation, stays inside the stage bounds and shakes on big hits.

var targets: Array = []          # Fighter list (dead ones ignored)
var stage_bounds: Rect2
var shake := 0.0

const BASE := Vector2(1920, 1080)


func _ready() -> void:
	make_current()
	position_smoothing_enabled = true
	position_smoothing_speed = 7.0


func _process(dt: float) -> void:
	if shake > 0.0:
		shake = maxf(0.0, shake - dt * 3.2)
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 26.0
	else:
		offset = Vector2.ZERO


func snap_update() -> void:
	var live: Array = []
	for t in targets:
		if is_instance_valid(t) and t.state != Fighter.S.KO:
			live.append(t)
	if live.is_empty():
		return
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for f in live:
		var p: Vector2 = f.global_position + Vector2(0, -60)
		lo = lo.min(p)
		hi = hi.max(p)
	var mid := (lo + hi) * 0.5 - Vector2(0, 110)
	var spread := (hi - lo).length()
	var zoom_target := clampf(1150.0 / maxf(spread, 320.0), 0.78, 1.35)
	var z := zoom.x
	zoom = Vector2.ONE * lerpf(z, zoom_target, 0.06)
	# Keep the view inside the stage when the stage is bigger than the view.
	var half := Vector2(BASE.x, BASE.y) * 0.5 / zoom.x
	if stage_bounds.size.x > 0:
		if stage_bounds.size.x > half.x * 2.0:
			mid.x = clampf(mid.x, stage_bounds.position.x + half.x, stage_bounds.end.x - half.x)
		else:
			mid.x = stage_bounds.get_center().x
		if stage_bounds.size.y > half.y * 2.0:
			mid.y = clampf(mid.y, stage_bounds.position.y + half.y, stage_bounds.end.y - half.y)
		else:
			mid.y = stage_bounds.get_center().y
	position = mid


func kick(amount: float) -> void:
	shake = maxf(shake, amount)
