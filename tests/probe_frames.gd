extends SceneTree

var _draws := 0

func _initialize() -> void:
	RenderingServer.frame_post_draw.connect(func(): _draws += 1)
	var timer := create_timer(3.0)
	timer.timeout.connect(func():
		print("PROBE adapter: ", RenderingServer.get_video_adapter_name())
		print("PROBE driver: ", RenderingServer.get_current_rendering_driver_name())
		print("PROBE frame_post_draw emissions in 3s: ", _draws)
		quit(0))
