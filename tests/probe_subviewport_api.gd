extends Node

func _ready() -> void:
	print("=== SubViewport API probe ===")
	var sv = SubViewport.new()
	print("SubViewport class:", sv)
	
	print("\nProperties on SubViewport:")
	var props = ["usage", "update_mode", "render_target_update_mode", "clear_on_background", "size"]
	for i in range(props.size()):
		var p = props[i]
		var val = sv.get(p)
		print("  %s = %s (type: %s)" % [p, str(val), typeof(val)])
	
	print("\nConstants on SubViewport:")
	var names = ["VIEWPORT_USAGE_RENDER_TARGET", "VIEWPORT_USAGE_2D", "VIEWPORT_USAGE_3D", "VIEWPORT_USAGE_3D_NO_ENVIRONMENT", "UPDATE_ALWAYS", "UPDATE_WHEN_FIXED", "UPDATE_DISABLED", "RENDER_TARGET_UPDATE_ALWAYS", "RENDER_TARGET_UPDATE_WHEN_FIXED", "RENDER_TARGET_UPDATE_ONCE"]
	for i in range(names.size()):
		var name = names[i]
		var val = sv.get(name)
		print("  %s = %s" % [name, str(val)])
	
	print("\nTrying to set usage with int values:")
	for v in [0, 1, 2, 3]:
		sv.set("usage", v)
		print("  set usage=%d -> got %s" % [v, sv.get("usage")])
	
	print("\nTexture after creation:")
	var tex = sv.get_texture()
	print("  texture:", tex)
	if tex != null:
		print("  texture type:", typeof(tex))
		print("  texture has get_image:", tex.has_method("get_image"))
		var img = tex.get_image()
		print("  image:", img)
	
	print("\nDone")
	get_tree().quit()
