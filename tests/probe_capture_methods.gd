extends Node

func _ready() -> void:
	print("=== Capture methods probe ===")
	
	# Method 1: get_viewport().get_texture().get_image()
	var vp = get_viewport()
	var tex = vp.get_texture()
	print("Method 1 - get_viewport().get_texture():", tex)
	if tex:
		var img = tex.get_image()
		print("  .get_image():", img)
	
	# Method 2: RenderingServer.viewport_get_texture()
	var rt_id = RenderingServer.viewport_get_texture(vp.get_viewport_rid())
	print("Method 2 - RenderingServer.viewport_get_texture():", rt_id)
	
	# Method 3: Create a Image from the viewport directly
	var img2 = Image.create(vp.get_visible_rect().size.x, vp.get_visible_rect().size.y, false, Image.FORMAT_RGBA8)
	print("Method 3 - Image.create():", img2)
	if img2:
		var err = RenderingServer.viewport_get_texture(vp.get_viewport_rid())
		print("  viewport_get_texture result:", err)
	
	# Method 4: Get viewport RID and try capture
	print("Method 4 - viewport rid:", vp.get_viewport_rid())
	
	# Method 5: Check if we can use render_target_update_mode
	print("Method 5 - viewport update mode:", vp.get("update_mode"))
	print("  viewport render_target_update_mode:", vp.get("render_target_update_mode"))
	
	print("\nDone")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Try again after a few frames
	print("\nAfter 3 frames:")
	tex = vp.get_texture()
	print("  texture:", tex)
	if tex:
		var img3 = tex.get_image()
		print("  .get_image():", img3)
	
	get_tree().quit()
