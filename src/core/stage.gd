class_name StageNode
extends Node2D
## Builds one of the three stages: solid ground, one-way soft platforms,
## walls, parallax backdrop, night lighting, ledge points and blast bounds.

var id := "sunspire"
var def: Dictionary
var ledges: Array = []          # [{point: Vector2, from: int}]
var blast: Rect2
var bounds: Rect2
var night := false

var _solids: Array = []         # Rect2 list (drawn + collision)
var _softs: Array = []          # Rect2 list
var _wpos: Array = []           # weapon spawn points


static func build(parent: Node, id_: String) -> StageNode:
	var s := StageNode.new()
	s.id = id_
	s.def = Data.STAGES[id_]
	s.name = "Stage"
	parent.add_child(s)
	return s


func _ready() -> void:
	night = bool(def["night"])
	var main: Rect2 = def["main"]
	_solids = [main] + (def["edges"] as Array)
	_softs = def["soft"] as Array
	_wpos = def["weapon_spawns"] as Array

	# --- collision bodies
	for r in _solids:
		_add_static_rect(r, false)
	for r in _softs:
		_add_static_rect(r, true)

	# --- ledges at the main platform's top corners
	ledges = [
		{"point": Vector2(main.position.x, main.position.y), "from": -1},
		{"point": Vector2(main.end.x, main.position.y), "from": 1},
	]

	# --- blast zone and camera bounds
	var m := Data.BLAST_MARGIN
	var left := main.position.x - m.x
	var right := main.end.x + m.x
	var top := main.position.y - m.y - 240.0
	var bottom := main.end.y + m.y - 120.0
	blast = Rect2(left, top, right - left, bottom - top)
	bounds = Rect2(main.position.x - 620.0, main.position.y - 900.0,
			main.size.x + 1240.0, 1500.0)

	_build_parallax()
	_build_lights()


func _add_static_rect(r: Rect2, soft: bool) -> void:
	var body := StaticBody2D.new()
	body.position = r.position + r.size * 0.5
	body.collision_layer = 2 if soft else (1 | 4)
	body.set_meta("soft", soft)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	if soft:
		cs.one_way_collision = true
		cs.one_way_collision_margin = 26.0
	body.add_child(cs)
	add_child(body)
	# visual
	var poly := Polygon2D.new()
	var pts := PackedVector2Array([
		-r.size * 0.5, Vector2(r.size.x * 0.5, -r.size.y * 0.5),
		r.size * 0.5, Vector2(-r.size.x * 0.5, r.size.y * 0.5),
	])
	poly.polygon = pts
	var col: Color = def["ground"]
	poly.color = col
	body.add_child(poly)
	# top edge highlight
	var h := Polygon2D.new()
	var eh := 10.0
	var hw := r.size.x * 0.5
	var hh := r.size.y * 0.5
	h.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh),
		Vector2(hw, -hh + eh), Vector2(-hw, -hh + eh),
	])
	h.color = (def["accent"] as Color).lightened(0.15) if not soft else (def["accent"] as Color)
	body.add_child(h)
	if not soft:
		# vertical shading on tall blocks
		var sh := Polygon2D.new()
		sh.polygon = PackedVector2Array([
			r.size * 0.5 - Vector2(0, 0), r.size * 0.5,
			Vector2(-r.size.x * 0.5, r.size.y * 0.5),
			Vector2(-r.size.x * 0.5, r.size.y * 0.5) + Vector2(26, 0),
		])
		sh.color = Color(0, 0, 0, 0.18)
		body.add_child(sh)
		# brick / stone mortar lines
		var yy := -r.size.y * 0.5 + 26.0
		while yy < r.size.y * 0.5:
			var line := Polygon2D.new()
			line.polygon = PackedVector2Array([
				Vector2(-r.size.x * 0.5, yy), Vector2(r.size.x * 0.5, yy),
				Vector2(r.size.x * 0.5, yy + 3.0), Vector2(-r.size.x * 0.5, yy + 3.0),
			])
			line.color = Color(0, 0, 0, 0.10)
			body.add_child(line)
			yy += 44.0


# ------------------------------------------------------------------ queries

func floor_y_at(x: float, y: float) -> float:
	# Nearest surface at or below y under this x (solids and soft platforms).
	var best := 1e9
	for r in _solids:
		if x >= r.position.x - 4.0 and x <= r.end.x + 4.0 and r.position.y >= y - 8.0:
			best = minf(best, r.position.y)
	for r in _softs:
		if x >= r.position.x and x <= r.end.x and r.position.y >= y - 8.0:
			best = minf(best, r.position.y)
	return best if best < 1e8 else blast.end.y + 400.0


func outside_blast(p: Vector2) -> bool:
	return not blast.has_point(p)


func inside_stage_margin(p: Vector2) -> bool:
	# True while the fighter is over/near the main platform (used by the AI
	# to notice it is offstage and start recovering).
	var main: Rect2 = def["main"]
	return p.x > main.position.x - 140.0 and p.x < main.end.x + 140.0 \
			and p.y < main.position.y + 240.0


func weapon_spawn_points() -> Array:
	return _wpos


func random_spawn(idx: int) -> Vector2:
	var sp: Array = def["spawns"]
	return sp[idx % sp.size()]


# ------------------------------------------------------------------ visuals

func _build_parallax() -> void:
	var bg := ParallaxBackground.new()
	bg.name = "Parallax"
	add_child(bg)
	var vp := Vector2(1920, 1080)
	var tex_id: String = def.get("tex", "stage1")
	# Sky fills the screen, does not scroll.
	var sky := _layer("res://assets/textures/%s_sky.png" % tex_id, 0.0, Vector2.ZERO)
	if sky != null:
		sky.motion_mirroring = Vector2(0, 0)
	# Far silhouettes.
	var far := _layer("res://assets/textures/%s_far.png" % tex_id, 0.25, Vector2(0, -160), Vector2(1920, 0))
	# Mid silhouettes.
	var mid := _layer("res://assets/textures/%s_mid.png" % tex_id, 0.55, Vector2(0, 20), Vector2(1920, 0))
	for n in [far, mid]:
		if n != null:
			n.scale = Vector2(1.0, 1.0)


func _layer(path: String, motion: float, offset: Vector2, mirror := Vector2.ZERO) -> ParallaxLayer:
	var tex := load(path)
	if tex == null:
		return null
	var l := ParallaxLayer.new()
	l.motion_scale = Vector2(motion, motion)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.position = Vector2(-960, -540) + offset
	if mirror != Vector2.ZERO:
		l.motion_mirroring = mirror
	l.add_child(spr)
	var pb: ParallaxBackground = get_node("Parallax")
	pb.add_child(l)
	return l


func _build_lights() -> void:
	if night:
		var cm := CanvasModulate.new()
		cm.color = Color(0.52, 0.58, 0.78)
		add_child(cm)
	var tex := load("res://assets/textures/light_radial.png")
	if tex == null:
		return
	var spots: Array
	if night:
		spots = [Vector2(0, -160), (def["spawns"] as Array)[0], (def["spawns"] as Array)[1]]
	else:
		spots = [Vector2(0, -320)]
	for p in spots:
		var l := PointLight2D.new()
		l.texture = tex
		l.texture_scale = 3.4
		l.position = p
		l.energy = 1.15 if night else 0.55
		l.color = (def["accent"] as Color).lightened(0.4)
		add_child(l)
