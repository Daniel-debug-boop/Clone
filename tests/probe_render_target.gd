extends Node

func _ready() -> void:
	print("=== Render target capture probe ===")
	
	# Create a SubViewport with usage set to render target
	var sv = SubViewport.new()
	sv.size = Vector2i(640, 360)
	print("SubViewport created:", sv)
	print("  size:", sv.size)
	
	# Check what usage values are valid
	print("\nTrying usage values:")
	for v in range(10):
		sv.set("usage", v)
		var tex = sv.get_texture()
		print("  usage=%d: tex=%s" % [v, tex])
		if tex:
			var img = tex.get_image()
			print("    get_image: %s" % img)
	
	# Try with UPDATE_ALWAYS
	print("\nWith UPDATE_ALWAYS (4):")
	sv.set("update_mode", 4)
	sv.set("usage", 2)  # Try value 2
	var tex2 = sv.get_texture()
	print("  tex:", tex2)
	if tex2:
		var img2 = tex2.get_image()
		print("  get_image: %s" % img2)
	
	# Add a camera and see if rendering happens
	var cam = Camera3D.new()
	cam.fov = 65.0
	cam.far = 6000.0
	cam.near = 0.15
	sv.add_child(cam)
	cam.current = true
	cam.look_at(Vector3(0, 0, -10), Vector3.UP)
	
	print("\nAfter adding camera, waiting 10 frames:")
	for i in range(10):
		await get_tree().process_frame
	
	tex2 = sv.get_texture()
	print("  tex after frames:", tex2)
	if tex2:
		var img2 = tex2.get_image()
		print("  get_image: %s" % img2)
		if img2:
			print("  image size:", img2.get_size())
	
	# Try creating a MeshInstance with a plane and render it
	print("\nTrying with a mesh:")
	var mesh = MeshDataTool.new()
	# Actually just try a simple approach - create a visual instance
	var plane = MeshInstance3D.new()
	plane.mesh = BoxMesh.new()
	sv.add_child(plane)
	plane.position = Vector3(0, 0, -5)
	
	for i in range(10):
		await get_tree().process_frame
	
	tex2 = sv.get_texture()
	print("  tex after mesh:", tex2)
	if tex2:
		var img2 = tex2.get_image()
		print("  get_image: %s" % img2)
	
	print("\nDone")
	get_tree().quit()
