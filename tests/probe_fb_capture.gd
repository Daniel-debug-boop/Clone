extends Node

func _ready() -> void:
	print("=== Framebuffer capture probe ===")
	
	var vp = get_viewport()
	
	# Wait a few frames for rendering to happen
	for i in range(5):
		await get_tree().process_frame
	
	# Try using RenderingDevice to capture
	var rd = RenderingServer.get_rendering_device()
	if rd:
		print("RenderingDevice available:", rd)
		var img = Image.create(640, 360, false, Image.FORMAT_RGBA8)
		var status = rd.image_get_status(img.get_rid())
		print("image status:", status)
	else:
		print("No RenderingDevice")
	
	# Try get_viewport_rect approach
	print("\nViewport rect:", vp.get_visible_rect())
	
	# Try creating an Image and copying from the viewport texture
	var tex = vp.get_texture()
	if tex:
		print("tex is ViewportTexture:", tex is ViewportTexture)
		print("tex has get_image:", tex.has_method("get_image"))
		print("tex has get_size:", tex.has_method("get_size"))
		print("tex has get_format:", tex.has_method("get_format"))
		var img = Image.create(vp.get_visible_rect().size.x, vp.get_visible_rect().size.y, false, Image.FORMAT_RGBA8)
		print("created image:", img, "size:", img.get_size())
		print("image has save_png:", img.has_method("save_png"))
	
	print("\nDone")
	get_tree().quit()
