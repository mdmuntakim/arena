extends SceneTree
## Release screenshot + frame-time capture. Needs a real renderer:
##   xvfb-run -a godot --path . --rendering-method gl_compatibility \
##       --rendering-driver opengl3 --resolution 1920x1080 -s tools/screenshot.gd
## Saves PNGs into docs/screenshots/ and prints the measured frame time.
## The fight is fast-forwarded with Engine.time_scale between shots so match
## moments can be captured without rendering thousands of frames (a software
## rasteriser like Mesa llvmpipe needs a while per frame).

const OUT_DIR := "res://docs/screenshots"

var main: Node2D = null
var step := 0
var perf_ms := 0.0
var perf_n := 0
var perf_last := 0
var hit_shot_done := false


func _initialize() -> void:
	Engine.max_physics_steps_per_frame = 32
	process_frame.connect(_tick)


func _shoot(name_: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + "/" + name_ + ".png")
	img.save_png(path)
	print("shot: ", name_)


func _cfg(stage := "sunspire") -> Dictionary:
	return {"mode": "ai", "difficulty": 1, "chars": ["bram", "sera"], "stage": stage}


func _tick() -> void:
	var now := Time.get_ticks_msec()
	if perf_last > 0 and step > 60:
		perf_ms += float(now - perf_last) / 1000.0
		perf_n += 1
	perf_last = now
	step += 1
	match step:
		1:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
			var scene := load("res://src/main.tscn")
			main = scene.instantiate()
			root.add_child(main)
		14:
			_shoot("01_main_menu")
		15:
			main.menu._show("chars")
		24:
			_shoot("02_character_select")
		25:
			main.menu._show("stages")
		34:
			_shoot("03_stage_select")
		35:
			main.menu.visible = false
			main._start_match(_cfg())
			Engine.time_scale = 6.0
		70:
			Engine.time_scale = 1.0
			# Neutral: countdown just ending.
			main.match_node.countdown_t = 0.9
		78:
			_shoot("04_neutral_day")
		79:
			# Force a close-range sig so a hit confirm is on screen.
			var m: Match = main.match_node
			var a: Fighter = m.fighters[0]
			var b: Fighter = m.fighters[1]
			var main_rect: Rect2 = m.stage_ref.def["main"]
			a.global_position = Vector2(-160, main_rect.position.y)
			b.global_position = Vector2(-80, main_rect.position.y)
			a.velocity = Vector2.ZERO
			b.velocity = Vector2.ZERO
			a.facing = 1
			b.damage = 55.0
			a.pad.heavy_just = true
		95:
			if not hit_shot_done:
				hit_shot_done = true
				_shoot("05_hit_confirm")
				step = 100
		101:
			# Ring out fighter 1 for the KO blast.
			var m2: Match = main.match_node
			m2.fighters[1].global_position = m2.stage_ref.blast.position - Vector2(120, 0)
		104:
			_shoot("06_ko_blast")
		105:
			main._back_to_menu()
			main._start_match(_cfg("frostbridge"))
			Engine.time_scale = 5.0
		150:
			Engine.time_scale = 1.0
			main.match_node.countdown_t = 0.9
		158:
			_shoot("07_night_stage")
		159:
			main._back_to_menu()
			main._start_match(_cfg("emberhollow"))
			Engine.time_scale = 5.0
		200:
			Engine.time_scale = 1.0
			main.match_node.countdown_t = 0.9
		208:
			_shoot("08_dusk_stage")
		209:
			if perf_n > 0:
				print("PERF adapter=%s resolution=1920x1080 avg_frame_ms=%.1f samples=%d" % [
					RenderingServer.get_video_adapter_name(), perf_ms * 1000.0 / perf_n, perf_n])
			quit(0)
