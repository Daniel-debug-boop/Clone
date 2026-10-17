extends CanvasLayer
class_name GameHUD
## In-game HUD: objective counter, interaction prompt, stats, pause menu and
## completion banner. Built in code so the scene file stays trivial and robust.

signal resume_requested
signal quit_requested
signal save_requested

var _objective_label: Label
var _stats_label: Label
var _prompt: PanelContainer
var _prompt_label: Label
var _banner: PanelContainer
var _banner_label: Label
var _pause_menu: Control
var _crosshair: ColorRect
var _hint: Label


func _ready() -> void:
	layer = 10
	_build()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Crosshair.
	_crosshair = ColorRect.new()
	_crosshair.color = Color(1, 1, 1, 0.65)
	_crosshair.size = Vector2(6, 6)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position -= Vector2(3, 3)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)

	# Objective counter (top-left).
	var obj_panel := PanelContainer.new()
	obj_panel.position = Vector2(24, 20)
	obj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var obj_style := StyleBoxFlat.new()
	obj_style.bg_color = Color(0.04, 0.06, 0.09, 0.72)
	obj_style.corner_radius_top_left = 6
	obj_style.corner_radius_top_right = 6
	obj_style.corner_radius_bottom_left = 6
	obj_style.corner_radius_bottom_right = 6
	obj_style.content_margin_left = 14
	obj_style.content_margin_right = 14
	obj_style.content_margin_top = 8
	obj_style.content_margin_bottom = 8
	obj_panel.add_theme_stylebox_override("panel", obj_style)
	root.add_child(obj_panel)

	_objective_label = Label.new()
	_objective_label.text = "Kyoto Lanterns  0 / 0"
	_objective_label.add_theme_font_size_override("font_size", 20)
	_objective_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.55))
	obj_panel.add_child(_objective_label)

	# Stats (top-right).
	_stats_label = Label.new()
	_stats_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_stats_label.position = Vector2(-260, 24)
	_stats_label.size = Vector2(236, 120)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats_label.add_theme_font_size_override("font_size", 14)
	_stats_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.85))
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stats_label)

	# Interaction prompt (bottom centre).
	_prompt = PanelContainer.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-190, -150)
	_prompt.custom_minimum_size = Vector2(380, 0)
	_prompt.visible = false
	var prompt_style := StyleBoxFlat.new()
	prompt_style.bg_color = Color(0.05, 0.07, 0.1, 0.82)
	prompt_style.set_corner_radius_all(8)
	prompt_style.set_content_margin_all(12)
	_prompt.add_theme_stylebox_override("panel", prompt_style)
	root.add_child(_prompt)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 17)
	_prompt.add_child(_prompt_label)

	# Controls hint.
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(24, -40)
	_hint.text = "WASD move   Shift sprint   Space jump   E interact   C camera   Esc pause"
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 0.6))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)

	# Completion banner.
	_banner = PanelContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-260, 120)
	_banner.custom_minimum_size = Vector2(520, 0)
	_banner.visible = false
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0.16, 0.1, 0.02, 0.9)
	banner_style.border_color = Color(1.0, 0.72, 0.32)
	banner_style.set_border_width_all(2)
	banner_style.set_corner_radius_all(10)
	banner_style.set_content_margin_all(16)
	_banner.add_theme_stylebox_override("panel", banner_style)
	root.add_child(_banner)

	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 22)
	_banner_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.6))
	_banner.add_child(_banner_label)

	_build_pause_menu(root)


func _build_pause_menu(root: Control) -> void:
	_pause_menu = ColorRect.new()
	(_pause_menu as ColorRect).color = Color(0.02, 0.03, 0.05, 0.86)
	_pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_menu.visible = false
	_pause_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_pause_menu)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-160, -170)
	center.custom_minimum_size = Vector2(320, 0)
	center.add_theme_constant_override("separation", 14)
	_pause_menu.add_child(center)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	center.add_child(title)

	center.add_child(_make_button("Resume", func() -> void: resume_requested.emit()))
	center.add_child(_make_button("Save Game", func() -> void: save_requested.emit()))
	center.add_child(_make_button("Save & Quit to Menu", func() -> void: quit_requested.emit()))

	# Required third-party attribution (OSM ODbL, USGS terrain data, Poly Haven CC0,
	# Godot MIT). Shown in the pause menu as a reasonable place for a desktop build.
	var attribution := Label.new()
	attribution.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	attribution.position = Vector2(0, -64)
	attribution.custom_minimum_size = Vector2(0, 52)
	attribution.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attribution.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attribution.add_theme_font_size_override("font_size", 11)
	attribution.add_theme_color_override("font_color", Color(0.72, 0.77, 0.84, 0.7))
	attribution.text = "Terrain: Mapzen / AWS Terrain Tiles (SRTM, USGS). Map data © OpenStreetMap contributors (ODbL 1.0). 3D buildings: 国土交通省 PLATEAU, 「実在空間3D都市モデル」を加工して作成 (https://www.mlit.go.jp/plateau/). Materials: Poly Haven (CC0 1.0). Engine: Godot (MIT)."
	_pause_menu.add_child(attribution)


func _make_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(callback)
	return b


func set_objectives(collected: int, total: int) -> void:
	_objective_label.text = "Kyoto Lanterns  %d / %d" % [collected, total]


func set_stats(fps: float, speed: float, draw_distance: float, chunks: int) -> void:
	_stats_label.text = "FPS %d\nSpeed %.1f m/s\nView %.0f m\nChunks %d" % [
		int(fps), speed, draw_distance, chunks
	]


func show_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt.visible = true


func hide_prompt() -> void:
	_prompt.visible = false


func show_banner(text: String) -> void:
	_banner_label.text = text
	_banner.visible = true


func hide_banner() -> void:
	_banner.visible = false


func set_paused(paused: bool) -> void:
	_pause_menu.visible = paused
	_crosshair.visible = not paused
	_hint.visible = not paused
	if paused:
		hide_prompt()
