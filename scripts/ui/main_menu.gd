extends Control
## Main menu: new game, continue, settings, quit. Renders a real HDRI sky behind
## the UI so the menu reflects the game's actual lighting.

signal start_game

var _settings_panel: PanelContainer
var _menu_box: VBoxContainer
var _continue_button: Button
var _status_label: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_backdrop()
	_build_ui()


func _build_backdrop() -> void:
	var world := Node3D.new()
	world.name = "Backdrop"
	add_child(world)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	var hdri := "res://assets/hdri/kloofendal_48d_partly_cloudy_puresky_2k.hdr"
	var sky := Sky.new()
	if ResourceLoader.exists(hdri):
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load(hdri) as Texture2D
		sky.sky_material = pano
	else:
		sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.78, 0.9)
	env.fog_density = 0.004
	we.environment = env
	world.add_child(we)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 6, 12)
	cam.rotation_degrees = Vector3(-12, 0, 0)
	cam.far = 3000.0
	cam.current = true
	world.add_child(cam)

	# A distant plane keeps the horizon from being pure sky.
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	ground.mesh = plane
	ground.position.y = -2.0
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.22, 0.28, 0.24)
	gm.roughness = 1.0
	ground.material_override = gm
	world.add_child(ground)


func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.05, 0.42)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var title := Label.new()
	title.text = "JAPAN OPEN WORLD"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-420, 90)
	title.custom_minimum_size = Vector2(840, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.93, 0.84))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "京都  ·  Central Kyoto, built from real elevation and OpenStreetMap data"
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.position = Vector2(-420, 170)
	subtitle.custom_minimum_size = Vector2(840, 0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.86, 0.95, 0.85))
	add_child(subtitle)

	_menu_box = VBoxContainer.new()
	_menu_box.set_anchors_preset(Control.PRESET_CENTER)
	_menu_box.position = Vector2(-160, -20)
	_menu_box.custom_minimum_size = Vector2(320, 0)
	_menu_box.add_theme_constant_override("separation", 14)
	add_child(_menu_box)

	_menu_box.add_child(_make_button("New Game", _on_new_game))
	_continue_button = _make_button("Continue", _on_continue)
	_continue_button.disabled = not GameManager.has_save()
	_menu_box.add_child(_continue_button)
	_menu_box.add_child(_make_button("Settings", _on_settings))
	_menu_box.add_child(_make_button("Quit", _on_quit))

	_status_label = Label.new()
	_status_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status_label.position = Vector2(24, -44)
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.76, 0.84, 0.6))
	_status_label.text = "Godot 4.6  ·  Real Kyoto DEM  ·  OSM roads & buildings  ·  See BUILD.md"
	add_child(_status_label)

	_build_settings_panel()


func _build_settings_panel() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.position = Vector2(-260, -220)
	_settings_panel.custom_minimum_size = Vector2(520, 0)
	_settings_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.94)
	style.border_color = Color(0.4, 0.5, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(22)
	_settings_panel.add_theme_stylebox_override("panel", style)
	add_child(_settings_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_settings_panel.add_child(box)

	var heading := Label.new()
	heading.text = "Settings"
	heading.add_theme_font_size_override("font_size", 26)
	box.add_child(heading)

	# Resolution.
	var res_row := HBoxContainer.new()
	res_row.add_child(_label("Resolution"))
	var res_opt := OptionButton.new()
	var resolutions := ["1280 x 720", "1600 x 900", "1920 x 1080", "2560 x 1440", "3840 x 2160"]
	var current_res := "%d x %d" % [SettingsManager.get_value("display/resolution_x"), SettingsManager.get_value("display/resolution_y")]
	var res_idx := resolutions.find(current_res)
	res_opt.selected = maxi(0, res_idx)
	for r in resolutions:
		res_opt.add_item(r)
	res_opt.item_selected.connect(func(i: int) -> void:
		var dims: PackedStringArray = String(resolutions[i]).split(" x ")
		SettingsManager.set_value("display/resolution_x", int(dims[0]))
		SettingsManager.set_value("display/resolution_y", int(dims[1]))
	)
	res_row.add_child(res_opt)
	box.add_child(res_row)

	# Fullscreen.
	var fs_row := HBoxContainer.new()
	fs_row.add_child(_label("Fullscreen"))
	var fs_check := CheckButton.new()
	fs_check.button_pressed = bool(SettingsManager.get_value("display/fullscreen"))
	fs_check.toggled.connect(func(on: bool) -> void: SettingsManager.set_value("display/fullscreen", on))
	fs_row.add_child(fs_check)
	box.add_child(fs_row)

	# Quality.
	var q_row := HBoxContainer.new()
	q_row.add_child(_label("Quality preset"))
	var q_opt := OptionButton.new()
	for q in ["Low", "Medium", "High", "Ultra"]:
		q_opt.add_item(q)
	q_opt.selected = int(SettingsManager.get_value("graphics/quality"))
	q_opt.item_selected.connect(func(i: int) -> void: SettingsManager.set_value("graphics/quality", i))
	q_row.add_child(q_opt)
	box.add_child(q_row)

	# Render scale.
	box.add_child(_slider_row("Render scale", 0.5, 1.0, 0.05,
		float(SettingsManager.get_value("graphics/render_scale")),
		func(v: float) -> void: SettingsManager.set_value("graphics/render_scale", v)))

	# Mouse sensitivity.
	box.add_child(_slider_row("Mouse sensitivity", 0.0005, 0.012, 0.0002,
		float(SettingsManager.get_value("input/mouse_sensitivity")),
		func(v: float) -> void: SettingsManager.set_value("input/mouse_sensitivity", v)))

	# Draw distance.
	box.add_child(_slider_row("View distance (m)", 500.0, 2600.0, 50.0,
		float(SettingsManager.get_value("graphics/draw_distance")),
		func(v: float) -> void: SettingsManager.set_value("graphics/draw_distance", v)))

	box.add_child(_make_button("Back", func() -> void:
		_settings_panel.visible = false
		_menu_box.visible = true
	))


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(210, 0)
	l.add_theme_font_size_override("font_size", 16)
	return l


func _slider_row(title: String, min_v: float, max_v: float, step: float, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(_label(title))
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return row


func _make_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(callback)
	return b


func _on_new_game() -> void:
	GameManager.start_new_game()


func _on_continue() -> void:
	var data := GameManager.load_game()
	if not data.is_empty():
		GameManager.start_new_game()


func _on_settings() -> void:
	_menu_box.visible = false
	_settings_panel.visible = true


func _on_quit() -> void:
	get_tree().quit()
