extends CharacterBody3D
class_name PlayerController
## Third-person character controller with orbit camera, sprint, jump and interaction.

signal interacted(target: Node)
signal landed(impact_speed: float)

const WALK_SPEED := 4.2
const SPRINT_SPEED := 8.0
const CROUCH_SPEED := 1.8
const JUMP_VELOCITY := 6.2
const ACCELERATION := 14.0
const AIR_ACCELERATION := 3.0
const FRICTION := 12.0
const MOUSE_CLAMP := deg_to_rad(85.0)
const INTERACT_RANGE := 3.5

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var visual: Node3D = $Visual

var _pitch := 0.0
var _yaw := 0.0
var _was_on_floor := true
var _interact_ray: RayCast3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_interact_ray = RayCast3D.new()
	_interact_ray.target_position = Vector3(0, 0, -INTERACT_RANGE)
	_interact_ray.collision_mask = 1 | 8
	_interact_ray.collide_with_areas = true
	camera.add_child(_interact_ray)
	_setup_visuals()
	camera_pivot.top_level = false


func _setup_visuals() -> void:
	# The character is represented by a clean capsule/silhouette proxy. No rigged
	# humanoid asset ships with this repository; see ASSET_MANIFEST.md.
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.16, 0.24, 0.42)
	body_mat.roughness = 0.6

	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.32
	body_mesh.height = 1.1
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.position.y = 0.15
	body.material_override = body_mat
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	body_shape.shape = capsule
	body_shape.position.y = 0.45
	add_child(body_shape)
	visual.add_child(body)

	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.86, 0.70, 0.58)
	head_mat.roughness = 0.7
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.19
	head_mesh.height = 0.38
	var head := MeshInstance3D.new()
	head.mesh = head_mesh
	head.position.y = 0.95
	head.material_override = head_mat
	visual.add_child(head)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = SettingsManager.get_mouse_sensitivity()
		var invert := -1.0 if SettingsManager.get_value("input/invert_y", false) else 1.0
		_yaw -= event.relative.x * sens
		_pitch -= event.relative.y * sens * invert
		_pitch = clampf(_pitch, -MOUSE_CLAMP, MOUSE_CLAMP)
		_apply_camera_rotation()
	elif event.is_action_pressed("toggle_camera"):
		# Toggle first-person / third-person distance.
		spring_arm.spring_length = 0.0 if spring_arm.spring_length > 1.0 else 3.2
	elif event.is_action_pressed("interact"):
		_try_interact()


func _apply_camera_rotation() -> void:
	camera_pivot.rotation = Vector3(_pitch, _yaw, 0.0)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * delta * 1.6

	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprinting := Input.is_action_pressed("sprint")
	var target_speed := SPRINT_SPEED if sprinting else WALK_SPEED
	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var yaw_basis := Basis.from_euler(Vector3(0.0, _yaw, 0.0))
	var direction := (yaw_basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
	var accel := ACCELERATION if is_on_floor() else AIR_ACCELERATION
	var horizontal := Vector2(velocity.x, velocity.z)
	var target := Vector2(direction.x, direction.z) * target_speed

	if direction.length() > 0.05:
		horizontal = horizontal.lerp(target, clampf(accel * delta, 0.0, 1.0))
	else:
		horizontal = horizontal.lerp(Vector2.ZERO, clampf(FRICTION * delta, 0.0, 1.0))

	velocity.x = horizontal.x
	velocity.z = horizontal.y

	var was_falling := velocity.y
	move_and_slide()

	if not _was_on_floor and is_on_floor():
		landed.emit(absf(was_falling))
	_was_on_floor = is_on_floor()

	# Face movement direction smoothly.
	if direction.length() > 0.1:
		var target_yaw := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, clampf(10.0 * delta, 0.0, 1.0))


func _try_interact() -> void:
	if _interact_ray == null:
		return
	_interact_ray.force_raycast_update()
	if _interact_ray.is_colliding():
		var collider := _interact_ray.get_collider()
		if collider and collider.has_method("interact"):
			collider.interact(self)
			interacted.emit(collider)


func get_current_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func get_yaw() -> float:
	return _yaw


func set_yaw(value: float) -> void:
	_yaw = value
	_apply_camera_rotation()


func get_interact_target() -> Node:
	if _interact_ray == null:
		return null
	_interact_ray.force_raycast_update()
	if _interact_ray.is_colliding():
		return _interact_ray.get_collider()
	return null
