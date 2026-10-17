extends Node
## Runtime smoke test. Runs as a real scene so project autoloads are registered.
##
## Run with:  godot --headless --path . res://tests/smoke_test.tscn
## Exits with code 0 on success, 1 on failure.

const WORLD_SCENE := "res://scenes/main_world.tscn"

var _failures: Array[String] = []
var _passes: int = 0


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	_finish()


func _pass(msg: String) -> void:
	_passes += 1
	print("  PASS  ", msg)


func _fail(msg: String) -> void:
	_failures.append(msg)
	print("  FAIL  ", msg)


func _run() -> void:
	print("=== Japan Open World smoke test ===")

	# --- autoloads ---------------------------------------------------------
	var gm := get_tree().root.get_node_or_null("GameManager")
	var sm := get_tree().root.get_node_or_null("SettingsManager")
	if gm != null:
		_pass("GameManager autoload present")
	else:
		_fail("GameManager autoload missing")

	if sm != null:
		_pass("SettingsManager autoload present")
		var dd: float = sm.get_draw_distance()
		if dd > 100.0:
			_pass("draw distance configured: %.0f m" % dd)
		else:
			_fail("draw distance suspiciously small: %.1f" % dd)
	else:
		_fail("SettingsManager autoload missing")

	# --- world instantiation ----------------------------------------------
	var packed := load(WORLD_SCENE)
	if not (packed is PackedScene):
		_fail("could not load main world scene")
		return

	var world: Node = (packed as PackedScene).instantiate()
	if world == null:
		_fail("could not instantiate main world scene")
		return
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame

	# --- terrain -----------------------------------------------------------
	var terrain = world.get_node_or_null("Terrain")
	if terrain == null:
		_fail("terrain node missing")
	else:
		_pass("terrain node exists")
		var chunks: int = terrain.get_loaded_chunk_count()
		if chunks > 0:
			_pass("terrain streamed %d chunks around the player" % chunks)
		else:
			_fail("no terrain chunks loaded")

		var bounds: Rect2 = terrain.get_world_bounds()
		if bounds.size.x > 1000.0 and bounds.size.y > 1000.0:
			_pass("terrain covers %.0f x %.0f m" % [bounds.size.x, bounds.size.y])
		else:
			_fail("terrain bounds too small: %s" % bounds.size)

		var h_center: float = terrain.get_height_at(0.0, 0.0)
		var h_offset: float = terrain.get_height_at(300.0, -200.0)
		if h_center > -100.0 and h_center < 1000.0 and not is_equal_approx(h_center, h_offset):
			_pass("elevation sampling works (centre %.1f m, offset %.1f m)" % [h_center, h_offset])
		else:
			_fail("elevation sampling looks wrong (%.1f / %.1f)" % [h_center, h_offset])

	# --- city --------------------------------------------------------------
	var city = world.get_node_or_null("City")
	if city == null:
		_fail("city node missing")
	else:
		var stats: Dictionary = city.get_stats()
		var bcount: int = int(stats.get("buildings", 0))
		var rcount: int = int(stats.get("roads", 0))
		if bcount > 1000:
			_pass("OSM buildings parsed: %d footprints" % bcount)
		else:
			_fail("too few building footprints: %d" % bcount)
		if rcount > 100:
			_pass("OSM roads parsed: %d ways" % rcount)
		else:
			_fail("too few roads: %d" % rcount)
		var city_chunks: int = city.get_loaded_chunk_count()
		if city_chunks > 0:
			_pass("city geometry streamed in %d chunks" % city_chunks)
		else:
			_fail("no city geometry streamed")

	# --- player ------------------------------------------------------------
	var player = world.get_node_or_null("Player")
	if player == null:
		_fail("player node missing")
	else:
		_pass("player spawned at %s" % str(player.position))
		if terrain != null:
			var ground: float = terrain.get_height_at(player.position.x, player.position.z)
			var above: float = float(player.position.y) - ground
			if above > -2.0 and above < 20.0:
				_pass("player is above terrain (%.2f m)" % above)
			else:
				_fail("player vertical placement looks wrong (%.2f m above ground)" % above)

	# --- objectives --------------------------------------------------------
	var lanterns := 0
	for child in world.get_children():
		if child.get_class() == "Area3D" and child.has_method("interact"):
			lanterns += 1
	if lanterns >= 1:
		_pass("%d lantern objectives placed" % lanterns)
	else:
		_fail("no lantern objectives were placed")

	if gm != null:
		if gm.objectives_total == lanterns:
			_pass("GameManager objective total matches placed lanterns (%d)" % lanterns)
		else:
			_fail("objective total mismatch: %d vs %d" % [gm.objectives_total, lanterns])

	# --- physics settle ----------------------------------------------------
	if player != null and terrain != null:
		await get_tree().physics_frame
		await get_tree().physics_frame
		var ground2: float = terrain.get_height_at(player.position.x, player.position.z)
		if float(player.position.y) > ground2 - 3.0:
			_pass("player did not fall through terrain after physics step")
		else:
			_fail("player fell through terrain (y=%.1f, ground=%.1f)" % [player.position.y, ground2])


func _finish() -> void:
	print("\n=== smoke summary ===")
	print("passed: %d   failures: %d" % [_passes, _failures.size()])
	if not _failures.is_empty():
		for f in _failures:
			print("  - ", f)
		print("RESULT: FAIL")
		get_tree().quit(1)
	else:
		print("RESULT: PASS")
		get_tree().quit(0)
