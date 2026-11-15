class_name UiSettings
extends Object
## Shared adjustable settings for the on-screen controller (and menu).
## Saved to user://controls.cfg so the layout survives restarts.

static var button_scale := 1.0      # 0.7 .. 1.6
static var opacity := 0.55          # 0.2 .. 0.9
static var spacing := 1.0           # 0.8 .. 1.35 horizontal spread
static var left_handed := false
static var haptics := true

const SAVE_PATH := "user://controls.cfg"


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		button_scale = cfg.get_value("controls", "button_scale", 1.0)
		opacity = cfg.get_value("controls", "opacity", 0.55)
		spacing = cfg.get_value("controls", "spacing", 1.0)
		left_handed = cfg.get_value("controls", "left_handed", false)
		haptics = cfg.get_value("controls", "haptics", true)
	_clamp()


static func save_settings() -> void:
	_clamp()
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "button_scale", button_scale)
	cfg.set_value("controls", "opacity", opacity)
	cfg.set_value("controls", "spacing", spacing)
	cfg.set_value("controls", "left_handed", left_handed)
	cfg.set_value("controls", "haptics", haptics)
	cfg.save(SAVE_PATH)


static func _clamp() -> void:
	button_scale = clampf(button_scale, 0.7, 1.6)
	opacity = clampf(opacity, 0.2, 0.9)
	spacing = clampf(spacing, 0.8, 1.35)
