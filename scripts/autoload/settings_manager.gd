extends Node
## Persistent user settings (quality, resolution, input sensitivity).
##
## Stored as a ConfigFile in `user://settings.cfg`. All values are validated on
## load so a corrupted or hand-edited file can never break startup.

signal settings_changed

const CONFIG_PATH := "user://settings.cfg"

const DEFAULTS := {
	"display/resolution_x": 1920,
	"display/resolution_y": 1080,
	"display/fullscreen": true,
	"display/vsync": true,
	"graphics/quality": 2,          # 0 low, 1 medium, 2 high, 3 ultra
	"graphics/render_scale": 1.0,
	"graphics/shadows": true,
	"graphics/ssao": true,
	"graphics/taa": true,
	"graphics/draw_distance": 1400.0,
	"input/mouse_sensitivity": 0.0025,
	"input/gamepad_sensitivity": 2.0,
	"input/invert_y": false,
}

var _values: Dictionary = {}


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	_values = DEFAULTS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		apply_all()
		return

	for section in ["display", "graphics", "input"]:
		for key in cfg.get_section_keys(section):
			var full := "%s/%s" % [section, key]
			if _values.has(full):
				_values[full] = cfg.get_value(section, key)

	_sanitize()
	apply_all()


func _sanitize() -> void:
	_values["display/resolution_x"] = clampi(int(_values["display/resolution_x"]), 640, 7680)
	_values["display/resolution_y"] = clampi(int(_values["display/resolution_y"]), 480, 4320)
	_values["graphics/quality"] = clampi(int(_values["graphics/quality"]), 0, 3)
	_values["graphics/render_scale"] = clampf(float(_values["graphics/render_scale"]), 0.5, 1.0)
	_values["graphics/draw_distance"] = clampf(float(_values["graphics/draw_distance"]), 400.0, 3000.0)
	_values["input/mouse_sensitivity"] = clampf(float(_values["input/mouse_sensitivity"]), 0.0003, 0.02)
	_values["input/gamepad_sensitivity"] = clampf(float(_values["input/gamepad_sensitivity"]), 0.3, 10.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for full: String in _values:
		var parts := full.split("/", false, 1)
		if parts.size() == 2:
			cfg.set_value(parts[0], parts[1], _values[full])
	cfg.save(CONFIG_PATH)


func get_value(key: String, fallback: Variant = null) -> Variant:
	return _values.get(key, fallback)


func set_value(key: String, value: Variant) -> void:
	if not _values.has(key):
		return
	_values[key] = value
	_sanitize()
	apply_all()
	save_settings()
	settings_changed.emit()


func apply_all() -> void:
	_apply_display()
	_apply_graphics()


func _apply_display() -> void:
	var w: int = int(_values["display/resolution_x"])
	var h: int = int(_values["display/resolution_y"])
	if _values["display/fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(w, h))
	var vsync_mode := DisplayServer.VSYNC_ENABLED if _values["display/vsync"] else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)


func _apply_graphics() -> void:
	var quality: int = int(_values["graphics/quality"])
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = float(_values["graphics/render_scale"])
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.use_taa = bool(_values["graphics/taa"]) and quality >= 2
		vp.use_debanding = quality >= 1

	if RenderingServer.has_method("environment_set_ssao_quality"):
		var ssao_quality := RenderingServer.ENV_SSAO_QUALITY_HIGH if (bool(_values["graphics/ssao"]) and quality >= 2) else RenderingServer.ENV_SSAO_QUALITY_VERY_LOW
		# signature: quality, half_size, adaptive_target, blur_passes, fadeout_from, fadeout_to
		RenderingServer.environment_set_ssao_quality(ssao_quality, true, 2, 2, 50.0, 300.0)


func get_draw_distance() -> float:
	return float(_values["graphics/draw_distance"])


func get_mouse_sensitivity() -> float:
	return float(_values["input/mouse_sensitivity"])
