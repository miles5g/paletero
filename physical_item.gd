extends RigidBody3D
class_name PhysicalItem

@export var item_resource: ItemResource


func _ready() -> void:
	add_to_group("physical_items")
	_apply_item_visual()
	apply_item_physics()


func set_item_resource(item: ItemResource) -> void:
	if item == null:
		item_resource = null
	else:
		item_resource = item.duplicate(true)
	_apply_item_visual()
	apply_item_physics()


func take_item_resource() -> ItemResource:
	var out := item_resource
	item_resource = null
	return out


func display_name() -> String:
	if item_resource == null:
		return "Item"
	return item_resource.item_name


func apply_item_physics() -> void:
	if item_resource == null:
		mass = 0.2
		return
	var total_w := maxf(0.1, item_resource.weight_lbs * float(item_resource.quantity))
	mass = total_w


func _apply_item_visual() -> void:
	var old_vis := get_node_or_null("Visual")
	if old_vis != null:
		old_vis.queue_free()
	var new_vis := _build_visual_for_item()
	new_vis.name = "Visual"
	add_child(new_vis)
	move_child(new_vis, 0)


func _build_visual_for_item() -> Node3D:
	var model := ItemResource.HandModel.CUBE
	var rarity := ItemResource.Rarity.GREEN
	if item_resource != null:
		model = item_resource.hand_model
		rarity = item_resource.rarity
		if model == ItemResource.HandModel.AUTO:
			model = _default_model_for_category(item_resource.category)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _mesh_for_model(model)
	mesh_inst.material_override = _material_for_rarity(rarity)
	# Same silhouette language as booth, but scaled down to world pickup size.
	mesh_inst.scale = Vector3.ONE * 0.42
	return mesh_inst


func _default_model_for_category(category: ItemResource.Category) -> ItemResource.HandModel:
	match category:
		ItemResource.Category.FOOD:
			return ItemResource.HandModel.SPHERE
		ItemResource.Category.WEAPON:
			return ItemResource.HandModel.CAPSULE
		ItemResource.Category.CLOTHING:
			return ItemResource.HandModel.CYLINDER
		_:
			return ItemResource.HandModel.CUBE


func _mesh_for_model(model: ItemResource.HandModel) -> Mesh:
	match model:
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
			var m_cube := BoxMesh.new()
			m_cube.size = Vector3(0.72, 0.72, 0.72)
			return m_cube


func _material_for_rarity(r: ItemResource.Rarity) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.58
	mat.metallic = 0.0
	mat.albedo_color = _rarity_color(r)
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
