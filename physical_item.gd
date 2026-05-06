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
	if item_resource != null:
		model = item_resource.hand_model
		if model == ItemResource.HandModel.AUTO:
			model = _default_model_for_category(item_resource.category)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.82, 0.84)
	mat.roughness = 0.58
	mat.emission_enabled = true
	mat.emission = mat.albedo_color * 0.12
	match model:
		ItemResource.HandModel.SPHERE:
			var s := CSGSphere3D.new()
			s.radius = 0.16
			s.material = mat
			return s
		ItemResource.HandModel.CAPSULE:
			var cap := CSGCylinder3D.new()
			cap.radius = 0.11
			cap.height = 0.38
			cap.material = mat
			cap.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			return cap
		ItemResource.HandModel.CYLINDER:
			var cyl := CSGCylinder3D.new()
			cyl.radius = 0.12
			cyl.height = 0.32
			cyl.material = mat
			return cyl
		ItemResource.HandModel.SCROLL:
			var scroll := CSGCylinder3D.new()
			scroll.radius = 0.08
			scroll.height = 0.42
			scroll.material = mat
			scroll.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			return scroll
		_:
			var box := CSGBox3D.new()
			box.size = Vector3(0.3, 0.3, 0.3)
			box.material = mat
			return box


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
