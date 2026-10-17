extends SceneTree

func _initialize() -> void:
	print("PROBE adapter: ", RenderingServer.get_video_adapter_name())
	print("PROBE driver: ", RenderingServer.get_current_rendering_driver_name())
	quit(0)
