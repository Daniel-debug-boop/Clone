extends Node

const WORLD_SCENE := "res://scenes/main_world.tscn"
const OUT_DIR := "user://screenshots"

var _world: Node3D
var _player: Node3D
var _saved: Array[String] = []

func _ready() -> void:
	print("=== Japan Open World screenshot capture ===")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_apply_capture_settings()
	await get_tree().process_frame
	_world = load(WORLD_SCENE).instantiate()
	get_tree().root.add_child(_world)
	_disable_shadows()
	var t0 := Time.get_ticks_msec()
	for i in range(20):
		await get_tree().process_frame
		if (i + 1) % 5 == 0:
			print("  warmup %d/20 frames, %.1fs" % [i + 1, (Time.get_ticks_msec() - t0) / 1000.0])
	_report_world()
	_player = _world.get_node_or_null("Player")
	await _shot_vista()
	await _shot_street_level()
	await _shot_character()
	await _shot_distant()
	await _shot_materials()
	print("=== captured %d screenshots in %.1fs ===" % [_saved.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	for s in _saved:
		print("  ", s)
	get_tree().quit(0 if _saved.size() >= 5 else 1)

func _apply_capture_settings() -> void:
	# Software rasterisation cannot sustain a full-detail city at the shipping
	# draw distance, so capture runs at the minimum supported distance. This
	# changes how much of the world streams in, not how it looks up close.
	SettingsManager.set_value("graphics/draw_distance", 400.0)
	print("  capture profile: draw distance %.0f m" % SettingsManager.get_draw_distance())

func _disable_shadows() -> void:
	var lights := get_tree().root.find_children("*", "DirectionalLight3D", true, false)
	for light in lights:
		(light as DirectionalLight3D).shadow_enabled = false
	print("  capture profile: shadows off on %d light(s)" % lights.size())

func _report_world() -> void:
	var plateau = _world.get_node_or_null("Plateau")
	var terrain = _world.get_node_or_null("Terrain")
	var city = _world.get_node_or_null("City")
	if plateau and plateau.has_method("get_loaded_tile_count"):
		print("  world: %d PLATEAU tiles resident" % plateau.get_loaded_tile_count())
	if terrain and terrain.has_method("get_loaded_chunk_count"):
		print("  world: %d terrain chunks resident" % terrain.get_loaded_chunk_count())
	if city and city.has_method("get_loaded_chunk_count"):
		print("  world: %d city chunks resident" % city.get_loaded_chunk_count())

func _place_player(x: float, z: float) -> void:
	if _player == null:
		return
	var terrain = _world.get_node_or_null("Terrain")
	var y: float = terrain.get_height_at(x, z) + 2.0 if terrain else 2.0
	_player.global_position = Vector3(x, y, z)
	for _i in range(3):
		await get_tree().process_frame

func _shot_vista() -> void:
	await _place_player(-300.0, -500.0)
	var from := Vector3(-620.0, 150.0, -980.0)
	var at := Vector3(200.0, 60.0, 200.0)
	for _i in range(3):
		await get_tree().process_frame
	await _save("01_kyoto_vista", from, at, 62.0)

func _shot_street_level() -> void:
	await _place_player(-120.0, -420.0)
	var terrain = _world.get_node_or_null("Terrain")
	var y: float = terrain.get_height_at(-60.0, -380.0) + 3.0 if terrain else 3.0
	var from := Vector3(-60.0, y, -380.0)
	var at := Vector3(120.0, y + 6.0, -250.0)
	for _i in range(3):
		await get_tree().process_frame
	await _save("02_street_level", from, at, 70.0)

func _shot_character() -> void:
	await _place_player(-200.0, -300.0)
	if _player:
		var p := _player.global_position
		var from := p + Vector3(4.5, 3.2, 6.0)
		var at := p + Vector3(0, 1.2, 0)
		for _i in range(3):
			await get_tree().process_frame
		await _save("03_character", from, at, 60.0)

func _shot_distant() -> void:
	await _place_player(-900.0, -900.0)
	var from := Vector3(-1500.0, 520.0, -1500.0)
	var at := Vector3(0.0, 40.0, 0.0)
	for _i in range(4):
		await get_tree().process_frame
	await _save("04_distant_lod", from, at, 55.0)

func _shot_materials() -> void:
	await _place_player(60.0, -260.0)
	var terrain = _world.get_node_or_null("Terrain")
	var y: float = terrain.get_height_at(60.0, -260.0) + 2.2 if terrain else 2.2
	var from := Vector3(60.0, y, -260.0)
	var at := Vector3(110.0, y + 1.0, -320.0)
	for _i in range(3):
		await get_tree().process_frame
	await _save("05_materials", from, at, 45.0)

func _save(name: String, from: Vector3, at: Vector3, fov: float) -> void:
	# Position the main camera at the shot's viewpoint before capturing.
	# Otherwise every screenshot records the same view.
	var cam := _world.get_viewport().get_camera_3d() if _world != null else null
	if cam == null:
		cam = get_viewport().get_camera_3d()
	if cam != null:
		cam.global_position = from
		cam.fov = fov
		cam.look_at(at, Vector3.UP)
		# Give the camera a couple of frames to settle.
		await get_tree().process_frame
		await get_tree().process_frame
	# Capture via the main viewport. In headless GL mode the viewport
	# texture may be non-readable; this is best-effort.
	var vp := get_viewport()
	var tex := vp.get_texture()
	if tex == null:
		push_error("capture: viewport texture is null for %s" % name)
		return
	var img: Image = tex.get_image()
	if img == null:
		push_error("capture: viewport texture image is null for %s" % name)
		return
	var path := "user://screenshots/%s.png" % name
	var err := img.save_png(path)
	if err == OK:
		var size := img.get_size()
		_saved.append("%s (%dx%d)" % [path, size.x, size.y])
		print("  saved %s (%dx%d)" % [path, size.x, size.y])
	else:
		push_error("failed to save %s (err %d)" % [path, err])
