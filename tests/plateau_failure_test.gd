extends Node
## Proves that missing / unreadable PLATEAU tiles degrade gracefully.
##
## Run via tests/run_tests.sh, which temporarily moves one .pmesh away before
## invoking this scene and restores it afterwards. The loader must:
##   * skip the missing tile,
##   * count it as failed,
##   * still load the remaining tiles,
##   * never crash or spam an unbounded number of warnings.

var _failures: Array[String] = []
var _passes := 0


func _pass(msg: String) -> void:
	_passes += 1
	print("  PASS  ", msg)


func _fail(msg: String) -> void:
	_failures.append(msg)
	print("  FAIL  ", msg)


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("\n=== plateau failure summary ===")
	print("passed: %d   failures: %d" % [_passes, _failures.size()])
	if _failures.is_empty():
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			print("  - ", f)
		print("RESULT: FAIL")
		get_tree().quit(1)


func _run() -> void:
	print("=== PLATEAU graceful degradation test ===")

	var index_path := "res://assets/plateau/index.json"
	if not FileAccess.file_exists(index_path):
		print("  SKIP  no PLATEAU index present")
		return

	var city := PlateauCity.new()
	city.name = "Plateau"
	add_child(city)
	city.setup(null)
	if not city.available:
		_fail("PlateauCity did not become available despite an index being present")
		return
	_pass("PlateauCity initialised (%d tiles indexed)" % city.get_available_tile_count())

	var anchor := Node3D.new()
	add_child(anchor)
	anchor.global_position = Vector3.ZERO
	city.set_player(anchor)

	for _i in range(40):
		await get_tree().process_frame

	var stats: Dictionary = city.get_stats()
	var failed := int(stats.get("failed", 0))
	var loaded := int(stats.get("loaded", 0))

	if failed >= 1:
		_pass("missing tile detected and skipped (failed=%d)" % failed)
	else:
		_fail("expected at least one failed tile; run via tests/run_tests.sh")

	if loaded > 0:
		_pass("remaining tiles still loaded (%d)" % loaded)
	else:
		_fail("no tiles loaded at all after a missing tile")

	# Ensure the failure set is bounded: the loader must not retry forever.
	var before := failed
	for _i in range(10):
		await get_tree().process_frame
	var after := int(city.get_stats().get("failed", 0))
	if after == before:
		_pass("failed tiles are not retried every frame")
	else:
		_fail("failed counter grew from %d to %d (retry loop)" % [before, after])

	# Stop streaming first, otherwise _process immediately reloads what we release.
	city.set_process(false)
	city.clear_all()
	await get_tree().process_frame
	await get_tree().process_frame
	if city.get_loaded_tile_count() == 0:
		_pass("clear_all() releases every loaded tile")
	else:
		_fail("tiles remain loaded after clear_all() (%d)" % city.get_loaded_tile_count())
