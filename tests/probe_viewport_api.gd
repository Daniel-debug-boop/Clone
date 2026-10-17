extends Node

func _ready() -> void:
	print("Viewport is a class:", Viewport is GDScriptNativeClass)
	print("Viewport has new:", Viewport.has_method("new"))
	var v := Viewport.new()
	print("created viewport:", v)
	v.size = Vector2i(640, 360)
	print("size:", v.size)
	print("update_mode enum values:")
	for name in ["ALWAYS", "WHEN_FIXED", "ONCE", "DISABLED"]:
		var val = v.get("update_mode")
		# Try to set
		v.set("update_mode", name)
		print("  set UPDATE_%s -> got %s" % [name, v.get("update_mode")])
	print("render_target_update_mode:")
	for name in ["ALWAYS", "WHEN_FIXED", "ONCE", "DISABLED"]:
		v.set("render_target_update_mode", name)
		print("  set RENDER_TARGET_UPDATE_%s -> got %s" % [name, v.get("render_target_update_mode")])
	print("render_target_v_fmt:")
	for name in ["VFORMAT_RGBA8", "VFORMAT_RGB8", "VFORMAT_RGBA16", "VFORMAT_NONE"]:
		var val = RenderingServer.get(name)
		if val != null:
			v.set("render_target_v_fmt", val)
			print("  set %s -> got %s" % [name, v.get("render_target_v_fmt")])
	print("clear_on_background:", v.get("clear_on_background"))
	v.set("clear_on_background", true)
	print("  set true ->", v.get("clear_on_background"))
	print("has get_texture:", v.has_method("get_texture"))
	var t := v.get_texture()
	print("texture:", t)
	print("texture is Texture2D:", t is Texture2D)
	if t != null:
		print("texture get_image:", t.has_method("get_image"))
		var img := t.get_image()
		print("image:", img)
		if img != null:
			print("image size:", img.get_size())
	print("done")
	get_tree().quit()
