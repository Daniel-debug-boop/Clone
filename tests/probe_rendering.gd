extends Node

func _ready() -> void:
	print("PROBE adapter: ", RenderingServer.get_video_adapter_name())
	print("PROBE driver: ", RenderingServer.get_current_rendering_driver_name())
	get_tree().quit()
