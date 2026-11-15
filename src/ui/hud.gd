class_name HUD
extends CanvasLayer
## In-fight UI: damage readouts, stocks, timer, combo popups, KO banner,
## countdown, training panel, pause overlay and results screen.

signal rematch_requested
signal charselect_requested
signal menu_requested

var match_ref: Match = null
var ctl: Control = null
var popups := []                # {text, t, pos}
var banner := ""
var banner_t := 0.0
var last_countdown := -1
var paused := false
var results_visible := false

var pause_box: Control = null
var results_box: Control = null
var results_label: Label = null


func _ready() -> void:
	layer = 15
	ctl = Control.new()
	ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctl.draw.connect(_draw_ui)
	add_child(ctl)
	_build_pause()
	_build_results()


func _font() -> Font:
	return ThemeDB.fallback_font


func _dmg_color(d: float) -> Color:
	if d < 60.0:
		return Color(0.95, 0.97, 1.0)
	if d < 120.0:
		return Color(1.0, 0.9, 0.4)
	if d < 180.0:
		return Color(1.0, 0.6, 0.25)
	return Color(1.0, 0.35, 0.3)


func _draw_ui() -> void:
	if match_ref == null:
		return
	var vp := ctl.get_viewport_rect().size
	var f := _font()
	# Timer.
	var t := int(match_ref.time_left)
	var tstr := "%d:%02d" % [t / 60, t % 60]
	_draw_center(f, Vector2(vp.x * 0.5, 44), tstr, 40, Color(1, 1, 1, 0.92))
	for i in 2:
		var fi: Fighter = match_ref.fighters[i]
		var anchor := Vector2(vp.x * 0.5 + (220 if i == 0 else -220), 50)
		_draw_player_panel(fi, i, anchor)
	# Countdown.
	if match_ref.match_state == Match.SS.COUNTDOWN:
		var ct: float = match_ref.countdown_t
		var text := "Ready"
		var n := 0
		if ct > 2.6:
			n = 3
		elif ct > 1.8:
			n = 2
		elif ct > 1.0:
			n = 1
		elif ct > 0.2:
			n = 0
		if n > 0:
			text = str(n)
			if n != last_countdown and n >= 1:
				last_countdown = n
				if match_ref.audio != null:
					match_ref.audio.countdown_tick(n)
		else:
			text = "FIGHT!"
		_draw_center(f, Vector2(vp.x * 0.5, vp.y * 0.4), text, 110, Color(1, 0.85, 0.3, 0.95))
	# Popups (combo damage).
	for p in popups.duplicate():
		var a: float = clampf(p["t"] / 0.9, 0.0, 1.0)
		_draw_center(f, p["pos"] + Vector2(0, -(0.9 - p["t"]) * 60.0), p["text"],
				30 + int(p["count"]) * 4, Color(1, 0.95, 0.5, a))
	# KO banner.
	if banner_t > 0.0:
		_draw_center(f, Vector2(vp.x * 0.5, vp.y * 0.32), banner, 84,
				Color(1, 0.3, 0.25, clampf(banner_t, 0.0, 1.0)))
	# Training panel.
	if match_ref.mode == "training":
		var dummy: Fighter = match_ref.fighters[1]
		var lines := [
			"TRAINING   dummy damage: %d%%" % int(dummy.damage),
			"dummy stocks: infinite",
			"[BACK button / T] hitbox display: %s" % ("ON" if match_ref.debug_hitboxes else "off"),
		]
		var y := vp.y - 30.0 - lines.size() * 26.0
		for l in lines:
			_draw_center(f, Vector2(vp.x * 0.5, y), l, 20, Color(1, 1, 1, 0.75))
			y += 26.0


func _draw_player_panel(f: Fighter, i: int, anchor: Vector2) -> void:
	var fnt := _font()
	var dir := 1 if i == 0 else -1
	# Readability chip behind the panel.
	var chip := Rect2(anchor.x - 108.0 if i == 0 else anchor.x - 152.0, anchor.y - 52.0, 260, 118)
	ctl.draw_rect(chip, Color(0.03, 0.04, 0.09, 0.5))
	ctl.draw_rect(chip, (f.def["primary"] as Color).lightened(0.3), false, 2.0)
	var name_col: Color = f.def["primary"].lightened(0.45)
	# Name.
	_draw_text_at(fnt, anchor + Vector2(-90 * dir, -12), f.def["name"], 20, name_col, i == 0)
	# Damage %.
	var pct := int(roundf(f.damage))
	_draw_text_at(fnt, anchor + Vector2(-90 * dir, 26), "%d%%" % pct, 42, _dmg_color(f.damage), i == 0)
	# Stocks.
	for s in Data.STOCKS:
		var on := s < f.stocks
		var pos := Vector2(anchor.x + dir * (96.0 + float(s) * 30.0), 56)
		if i == 1:
			pos = Vector2(anchor.x - dir * (96.0 + float(s) * 30.0), 56)
		ctl.draw_circle(pos, 9.0, Color(1, 0.85, 0.3, 0.95 if on else 0.18))
		ctl.draw_arc(pos, 9.0, 0, TAU, 16, Color(0.2, 0.15, 0.05, 0.8), 2.0)
	# Weapon.
	var wname: String = Data.WEAPONS[f.weapon]["name"]
	_draw_text_at(fnt, anchor + Vector2(-90 * dir, 84), wname, 18, Color(0.9, 0.92, 1.0, 0.85), i == 0)
	# Player tag.
	_draw_text_at(fnt, anchor + Vector2(-90 * dir, -38), "P%d%s" % [i + 1, "  (AI)" if f.is_ai else ""],
			16, Color(1, 1, 1, 0.6), i == 0)


func _draw_text_at(fnt: Font, pos: Vector2, text: String, size: int, col: Color, left_align: bool) -> void:
	var p := pos
	if not left_align:
		var m := fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		p.x -= m.x
	ctl.draw_string(fnt, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_center(fnt: Font, pos: Vector2, text: String, size: int, col: Color) -> void:
	var m := fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	ctl.draw_string(fnt, pos - Vector2(m.x * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _process(dt: float) -> void:
	for p in popups.duplicate():
		p["t"] -= dt
		if p["t"] <= 0.0:
			popups.erase(p)
	if banner_t > 0.0:
		banner_t -= dt


func queue_redraw() -> void:
	if ctl != null:
		ctl.queue_redraw()


func combo_popup(idx: int, count: int, dealt: float) -> void:
	var victim: Fighter = match_ref.fighters[1 - idx]
	var pos := victim.global_position + Vector2(0, -170)
	var cam := ctl.get_viewport().get_camera_2d() as Camera2D
	if cam != null:
		var half := Vector2(ctl.get_viewport_rect().size) * 0.5 / cam.zoom.x
		pos = (pos - cam.get_screen_center_position()) * cam.zoom.x + half
	popups.append({"text": "%d%%  x%d" % [int(roundf(dealt)), count], "t": 0.9, "pos": pos, "count": count})


func ko_banner(victim_idx: int) -> void:
	banner = "P%d KO'D!" % (victim_idx + 1)
	banner_t = 1.3


func pickup_toast(idx: int, kind: String) -> void:
	pass  # weapon name already shown on the panel


# ------------------------------------------------------------------ pause

func _build_pause() -> void:
	pause_box = _overlay_box("PAUSED", [
		["Resume", func() -> void: match_ref.toggle_pause()],
		["Exit to menu", func() -> void: menu_requested.emit()],
	])
	pause_box.visible = false


func _build_results() -> void:
	results_box = _overlay_box("", [
		["Rematch", func() -> void: rematch_requested.emit()],
		["Character select", func() -> void: charselect_requested.emit()],
		["Main menu", func() -> void: menu_requested.emit()],
	])
	results_box.visible = false
	results_label = results_box.get_meta("label")


func _overlay_box(title: String, buttons: Array) -> Control:
	var box := Control.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.08, 0.72)
	box.add_child(dim)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 72)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.offset_bottom = -240.0
	box.add_child(label)
	box.set_meta("label", label)
	var i := 0
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.add_theme_font_size_override("font_size", 30)
		btn.custom_minimum_size = Vector2(360, 64)
		btn.position = Vector2(-180, 130 + i * 84)
		btn.set_anchors_preset(Control.PRESET_CENTER)
		btn.offset_top = 130 + i * 84
		btn.offset_bottom = 194 + i * 84
		btn.offset_left = -180
		btn.offset_right = 180
		btn.pressed.connect(b[1])
		box.add_child(btn)
		i += 1
	return box


func set_paused(b: bool) -> void:
	paused = b
	pause_box.visible = b


func show_results(winner: int, stats: Dictionary) -> void:
	results_visible = true
	results_box.visible = true
	var title := "DRAW"
	if winner >= 0:
		var wname: String = match_ref.fighters[winner].def["name"]
		title = "P%d WINS\n%s" % [winner + 1, wname]
		if match_ref.audio != null:
			match_ref.audio.victory_play()
	results_label.text = title
	results_label.add_theme_font_size_override("font_size", 64)
	# Stat lines under the title.
	var st := "\nKOs  %d - %d    damage dealt  %d - %d    time  %s" % [
		stats["kos"][0], stats["kos"][1],
		int(stats["damage_dealt"][0]), int(stats["damage_dealt"][1]),
		"%d:%02d" % [int(stats["time"]) / 60, int(stats["time"]) % 60],
	]
	results_label.text += st
