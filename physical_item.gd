extends RigidBody3D
class_name PhysicalItem

@export var item_resource: ItemResource


func _ready() -> void:
	add_to_group("physical_items")
	apply_item_physics()


func set_item_resource(item: ItemResource) -> void:
	if item == null:
		item_resource = null
	else:
		item_resource = item.duplicate(true)
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
