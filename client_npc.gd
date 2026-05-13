extends StaticBody3D
class_name ClientNPC

## Shown on the HUD terminal and dialogue speaker line (unique per spawned NPC).
@export var display_name: String = "Cliente"

## Interaction radius where the player can transact with this client.
@export var interaction_radius: float = 1.85

var _range_area: Area3D = null


func _ready() -> void:
	add_to_group("clients")
	if _range_area == null:
		_range_area = Area3D.new()
		_range_area.name = "RangeArea"
		_range_area.monitoring = true
		_range_area.monitorable = false
		_range_area.collision_layer = 0
		_range_area.collision_mask = 1
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = interaction_radius
		shape.shape = sphere
		_range_area.add_child(shape)
		add_child(_range_area)


func is_player_in_range(player: CharacterBody3D) -> bool:
	if player == null or _range_area == null:
		return false
	return _range_area.get_overlapping_bodies().has(player)
