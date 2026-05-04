extends RigidBody3D

## Local X is treated as sideways slide; multiply by this each physics step (0.1 ~= 90% reduction).
@export var sideways_velocity_retention: float = 0.1
## While grabbed: yaw cart so local -Z matches camera look on the ground (outward from camera).
@export var front_yaw_strength: float = 48.0
@export var front_yaw_max_impulse: float = 11.0

var _handle_zone: Area3D
var _interaction_area: Area3D
var _physics_dt: float = 1.0 / 60.0

func _ready() -> void:
	add_to_group("carts")
	_handle_zone = Area3D.new()
	_handle_zone.name = "HandleZone"
	_handle_zone.monitoring = true
	_handle_zone.monitorable = false
	_handle_zone.collision_layer = 0
	_handle_zone.collision_mask = 0
	var hz_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.85, 1.5, 0.45)
	hz_shape.shape = box
	_handle_zone.add_child(hz_shape)
	add_child(_handle_zone)
	# Toward +Z local: side where a pusher behind the cart (world +Z) naturally stands.
	_handle_zone.position = Vector3(0, 0, 0.75)

	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionArea"
	_interaction_area.monitoring = true
	_interaction_area.monitorable = false
	_interaction_area.collision_layer = 0
	_interaction_area.collision_mask = 0
	var ia_shape := CollisionShape3D.new()
	var ia_box := BoxShape3D.new()
	ia_box.size = Vector3(2.4, 2.0, 2.6)
	ia_shape.shape = ia_box
	_interaction_area.add_child(ia_shape)
	add_child(_interaction_area)
	# Default local +Z (toward player spawn when cart is at z=-5); world.gd may override after add_child.
	_interaction_area.position = Vector3(0, 0, 0.75)
	# Procedural world: use .connect() in code (not editor) for signals.
	_interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	_interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	call_deferred("_sync_area_masks_to_player_layer")

func _physics_process(delta: float) -> void:
	_physics_dt = delta

func _sync_area_masks_to_player_layer() -> void:
	var w := get_parent()
	if w == null:
		return
	var player := w.get_node_or_null("Player") as CharacterBody3D
	var mask := 1
	if player != null and player.collision_layer != 0:
		mask = player.collision_layer
	_handle_zone.collision_mask = mask
	_interaction_area.collision_mask = mask

func _hud_interaction_label() -> Label:
	var w := get_parent()
	if w == null:
		return null
	return w.get_node_or_null("HUD/InteractionLabel") as Label

func _on_interaction_area_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D or body.name != &"Player":
		return
	body.can_interact = true
	var lbl := _hud_interaction_label()
	if lbl:
		lbl.visible = true

func _on_interaction_area_body_exited(body: Node3D) -> void:
	if not body is CharacterBody3D or body.name != &"Player":
		return
	body.can_interact = false
	var lbl := _hud_interaction_label()
	if lbl:
		lbl.visible = false

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var local_v: Vector3 = state.transform.basis.inverse() * state.linear_velocity
	local_v.x *= sideways_velocity_retention
	state.linear_velocity = state.transform.basis * local_v
	_steer_cart_front_to_camera_look(state)

func _steer_cart_front_to_camera_look(state: PhysicsDirectBodyState3D) -> void:
	var w := get_parent()
	if w == null:
		return
	var player := w.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return
	if not player.is_pushing or player.current_cart != self:
		return
	var cam: Camera3D = null
	for c in player.get_children():
		if c is Camera3D:
			cam = c
			break
	if cam == null:
		return
	var want := -cam.global_transform.basis.z
	want.y = 0.0
	if want.length_squared() < 1e-5:
		return
	want = want.normalized()
	var fwd := -state.transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 1e-5:
		return
	fwd = fwd.normalized()
	var angle := fwd.signed_angle_to(want, Vector3.UP)
	if absf(angle) < 0.02:
		return
	var impulse := clampf(angle * front_yaw_strength * _physics_dt, -front_yaw_max_impulse, front_yaw_max_impulse)
	state.apply_torque_impulse(Vector3.UP * impulse)

func is_player_in_handle_zone(player: CharacterBody3D) -> bool:
	if _handle_zone == null:
		return false
	return _handle_zone.get_overlapping_bodies().has(player)

func is_player_in_grab_range(player: CharacterBody3D) -> bool:
	if is_player_in_handle_zone(player):
		return true
	if _interaction_area == null:
		return false
	return _interaction_area.get_overlapping_bodies().has(player)
