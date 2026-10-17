extends Area3D
class_name LanternObjective
## A collectible shrine lantern placed at a real Kyoto landmark.
## Walk up to it and press E (interact) to restore it.

signal collected(name: String)

@export var landmark_name: String = "Shrine Lantern"
@export var landmark_name_ja: String = ""

var _collected := false
var _time := 0.0
var _base_y := 0.0
var _core: MeshInstance3D
var _light: OmniLight3D
var _ring: MeshInstance3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	shape.shape = sphere
	shape.position.y = 1.0
	add_child(shape)

	_base_y = position.y

	_core = MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.32
	core_mesh.height = 0.64
	_core.mesh = core_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.72, 0.32)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.15)
	mat.emission_energy_multiplier = 4.0
	mat.roughness = 0.3
	_core.material_override = mat
	_core.position.y = 1.0
	add_child(_core)

	_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.55
	ring_mesh.outer_radius = 0.62
	_ring.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.9, 0.85, 0.7)
	ring_mat.metallic = 0.7
	ring_mat.roughness = 0.25
	_ring.material_override = ring_mat
	_ring.position.y = 1.0
	_ring.rotation.x = deg_to_rad(90)
	add_child(_ring)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.66, 0.3)
	_light.light_energy = 2.2
	_light.omni_range = 7.0
	_light.position.y = 1.0
	_light.shadow_enabled = false
	add_child(_light)


func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta
	position.y = _base_y + sin(_time * 1.6) * 0.18
	_ring.rotation.y += delta * 0.9
	var pulse := 0.75 + sin(_time * 3.0) * 0.25
	_light.light_energy = 1.6 * pulse + 0.8


func interact(_by: Node) -> void:
	if _collected:
		return
	_collected = true
	set_deferred("monitoring", false)
	collected.emit(landmark_name)
	GameManager.register_objective()

	# Quick visual payoff: rise and fade out.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 3.0, 0.8)
	tween.tween_property(_core, "scale", Vector3(1.8, 1.8, 1.8), 0.8)
	tween.tween_property(_light, "light_energy", 0.0, 0.8)
	tween.chain().tween_callback(queue_free)


func get_label() -> String:
	if landmark_name_ja != "":
		return "%s / %s" % [landmark_name, landmark_name_ja]
	return landmark_name
