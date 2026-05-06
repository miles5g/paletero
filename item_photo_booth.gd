extends SubViewportContainer
class_name ItemPhotoBooth

const ICON_SIZE: Vector2i = Vector2i(128, 128)
const ITEM_VISUAL_LAYER: int = 2
const BOOTH_VOID_POS: Vector3 = Vector3(12000.0, 4000.0, -12000.0)

var _viewport: SubViewport = null
var _scene_root: Node3D = null
var _anchor: Node3D = null
var _camera: Camera3D = null
var _current_item_mesh: MeshInstance3D = null
var _spin_y: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = false


	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_viewport_world()


func _process(delta: float) -> void:
	if _current_item_mesh == null or not is_instance_valid(_current_item_mesh):
		return
	_spin_y += delta * 0.85
	_current_item_mesh.rotation = Vector3(0.08, _spin_y, 0.0)


func set_item_resource(item: ItemResource) -> void:
	if _anchor == null:
		return
	if _current_item_mesh != null and is_instance_valid(_current_item_mesh):
		_current_item_mesh.queue_free()
		_current_item_mesh = null
	if item == null:
		return
	var mesh := MeshInstance3D.new()
	mesh.name = "PreviewMesh"
	mesh.mesh = _mesh_for_item(item)
	mesh.material_override = _material_for_item(item)
	mesh.layers = 1 << (ITEM_VISUAL_LAYER - 1)
	_anchor.add_child(mesh)
	_current_item_mesh = mesh
	_center_current_mesh()
	_spin_y = 0.0


func _center_current_mesh() -> void:
	if _current_item_mesh == null or not is_instance_valid(_current_item_mesh):
		return
	var aabb := _current_item_mesh.get_aabb()
	var center_local := aabb.position + aabb.size * 0.5
	# Normalize all mesh origins so the icon is centered in the booth.
	_current_item_mesh.position = -center_local


func _setup_viewport_world() -> void:
	_viewport = get_node_or_null("SubViewport") as SubViewport
	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.name = "SubViewport"
		add_child(_viewport)
	_viewport.size = ICON_SIZE
	_viewport.transparent_bg = true
	_viewport.disable_3d = false
	_viewport.own_world_3d = true
	# Keep booth settings API-safe across Godot 4 minor versions.
	_viewport.msaa_3d = Viewport.MSAA_DISABLED

	_scene_root = Node3D.new()
	_scene_root.name = "BoothWorld"
	_scene_root.position = BOOTH_VOID_POS
	_viewport.add_child(_scene_root)

	var booth_env := WorldEnvironment.new()
	booth_env.name = "BoothEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.74, 0.76, 0.86)
	env.ambient_light_energy = 1.45
	booth_env.environment = env
	_scene_root.add_child(booth_env)

	_anchor = Node3D.new()
	_anchor.name = "Anchor"
	_scene_root.add_child(_anchor)

	_camera = Camera3D.new()
	_camera.name = "BoothCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 1.35
	_camera.look_at_from_position(Vector3(0.0, 0.0, 2.7), Vector3.ZERO, Vector3.UP)
	_camera.cull_mask = 1 << (ITEM_VISUAL_LAYER - 1)
	_scene_root.add_child(_camera)

	# High-contrast booth lighting: one fill + one rim for hard industrial read.
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.72, 0.74, 0.86)
	fill.light_energy = 0.95
	fill.rotation_degrees = Vector3(-38.0, 30.0, 0.0)
	fill.shadow_enabled = false
	fill.light_cull_mask = 1 << (ITEM_VISUAL_LAYER - 1)
	_scene_root.add_child(fill)

	var rim := DirectionalLight3D.new()
	rim.name = "RimLight"
	rim.light_color = Color(0.95, 0.95, 1.0)
	rim.light_energy = 1.3
	rim.rotation_degrees = Vector3(26.0, -145.0, 0.0)
	rim.shadow_enabled = false
	rim.light_cull_mask = 1 << (ITEM_VISUAL_LAYER - 1)
	_scene_root.add_child(rim)

	var key := OmniLight3D.new()
	key.name = "KeyLight"
	key.position = Vector3(0.0, 0.28, 1.1)
	key.light_color = Color(1.0, 0.98, 0.9)
	key.light_energy = 0.85
	key.omni_range = 6.0
	key.shadow_enabled = false
	key.light_cull_mask = 1 << (ITEM_VISUAL_LAYER - 1)
	_scene_root.add_child(key)


func _mesh_for_item(item: ItemResource) -> Mesh:
	var hand_model := item.hand_model
	if hand_model == ItemResource.HandModel.AUTO:
		hand_model = _default_hand_model_for_category(item.category)
	match hand_model:
		ItemResource.HandModel.CUBE:
			var m_cube := BoxMesh.new()
			m_cube.size = Vector3(0.72, 0.72, 0.72)
			return m_cube
		ItemResource.HandModel.SPHERE:
			var m_sphere := SphereMesh.new()
			m_sphere.radius = 0.36
			m_sphere.height = 0.72
			return m_sphere
		ItemResource.HandModel.CAPSULE:
			var m_capsule := CapsuleMesh.new()
			m_capsule.radius = 0.2
			m_capsule.height = 0.9
			return m_capsule
		ItemResource.HandModel.CYLINDER:
			var m_cyl := CylinderMesh.new()
			m_cyl.top_radius = 0.28
			m_cyl.bottom_radius = 0.34
			m_cyl.height = 0.76
			return m_cyl
		ItemResource.HandModel.SCROLL:
			var m_scroll := CylinderMesh.new()
			m_scroll.top_radius = 0.16
			m_scroll.bottom_radius = 0.16
			m_scroll.height = 0.92
			return m_scroll
		_:
			var m_fallback := BoxMesh.new()
			m_fallback.size = Vector3(0.72, 0.72, 0.72)
			return m_fallback

func _default_hand_model_for_category(category: ItemResource.Category) -> ItemResource.HandModel:
	match category:
		ItemResource.Category.FOOD:
			return ItemResource.HandModel.SPHERE
		ItemResource.Category.WEAPON:
			return ItemResource.HandModel.CAPSULE
		ItemResource.Category.CLOTHING:
			return ItemResource.HandModel.CYLINDER
		_:
			return ItemResource.HandModel.CUBE


func _material_for_item(item: ItemResource) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.58
	mat.metallic = 0.0
	mat.albedo_color = _rarity_color(item.rarity)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color * 0.12
	return mat


func _rarity_color(r: ItemResource.Rarity) -> Color:
	match r:
		ItemResource.Rarity.GREEN:
			return Color(0.46, 0.84, 0.47)
		ItemResource.Rarity.BLUE:
			return Color(0.42, 0.58, 0.95)
		ItemResource.Rarity.PURPLE:
			return Color(0.7, 0.42, 0.95)
		ItemResource.Rarity.GOLD:
			return Color(0.98, 0.82, 0.3)
	return Color(0.72, 0.72, 0.72)
