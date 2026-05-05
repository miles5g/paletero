extends RigidBody3D

## Local X is treated as sideways slide; multiply by this each physics step (0.1 ~= 90% reduction).
@export var sideways_velocity_retention: float = 0.1
## While grabbed: yaw cart so local -Z matches camera look on the ground (outward from camera).
@export var front_yaw_strength: float = 82.0
@export var front_yaw_max_impulse: float = 18.0
## Resist rapid yaw spin during camera flicks.
@export var yaw_angular_damping: float = 6.5
## Upward assist while grabbed (helps glide over curbs/small rocks instead of hard-stopping).
@export var bump_float_force: float = 28.0
## Reference forward speed for full float assist; higher = less lift at normal speeds.
@export var bump_float_speed_ref: float = 8.0
## Damp roll/pitch angular velocity so curb hits do not flip as aggressively.
@export var anti_flip_damping: float = 8.0
## Extra downward hold while grounded and grabbed (prevents hover on camera flicks).
@export var grounded_hold_force: float = 34.0
## Limits sudden yaw impulse jumps from fast camera snaps.
@export var max_yaw_impulse_step: float = 3.8

var _handle_zone: Area3D
var _interaction_area: Area3D
var _physics_dt: float = 1.0 / 60.0
var _last_yaw_impulse: float = 0.0

var inventory_list: Array[ItemResource] = []

func _ready() -> void:
	add_to_group("carts")
	_stock_initial_inventory()
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


func add_item_to_inventory(new_item_resource: ItemResource) -> void:
	if new_item_resource == null:
		return
	for existing in inventory_list:
		if existing.item_name == new_item_resource.item_name:
			existing.quantity += new_item_resource.quantity
			return
	inventory_list.append(new_item_resource.duplicate(true))


func _stock_initial_inventory() -> void:
	var lime := ItemResource.new()
	lime.item_name = "Lime Paleta"
	lime.quantity = 1
	lime.weight_lbs = 1.0
	lime.value_usd = 1.50
	lime.description = "Tart lime frozen fruit bar."
	lime.rarity = ItemResource.Rarity.GREEN
	add_item_to_inventory(lime)

	var ice := ItemResource.new()
	ice.item_name = "Dry Ice Pack"
	ice.quantity = 1
	ice.weight_lbs = 5.0
	ice.value_usd = 10.00
	ice.description = "Keeps the cart cold. Heavy but necessary."
	ice.rarity = ItemResource.Rarity.BLUE
	add_item_to_inventory(ice)

	var recipe := ItemResource.new()
	recipe.item_name = "Secret Recipe"
	recipe.quantity = 1
	recipe.weight_lbs = 0.1
	recipe.value_usd = 500.00
	recipe.description = "A handwritten note with the perfect flavor ratios. Priceless."
	recipe.rarity = ItemResource.Rarity.GOLD
	add_item_to_inventory(recipe)

	var cooler := ItemResource.new()
	cooler.item_name = "Industrial Cooler"
	cooler.quantity = 1
	cooler.weight_lbs = 25.0
	cooler.value_usd = 250.00
	cooler.description = "A heavy-duty compressor. Makes the cart significantly heavier."
	cooler.rarity = ItemResource.Rarity.GOLD
	add_item_to_inventory(cooler)


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

func _on_interaction_area_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D or body.name != &"Player":
		return
	if body.is_pushing:
		return
	body.can_interact = true
	var w := get_parent()
	if w != null and w.has_method("set_grab_prompts_visible"):
		w.set_grab_prompts_visible(true)

func _on_interaction_area_body_exited(body: Node3D) -> void:
	if not body is CharacterBody3D or body.name != &"Player":
		return
	body.can_interact = false
	var w := get_parent()
	if w != null and w.has_method("set_grab_prompts_visible"):
		w.set_grab_prompts_visible(false)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var local_v: Vector3 = state.transform.basis.inverse() * state.linear_velocity
	local_v.x *= sideways_velocity_retention
	state.linear_velocity = state.transform.basis * local_v
	_steer_cart_front_to_camera_look(state)
	_apply_bump_float_and_stability(state)

func _grabber_player() -> CharacterBody3D:
	var w := get_parent()
	if w == null:
		return null
	var player := w.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return null
	if not player.is_pushing or player.current_cart != self:
		return null
	return player

func _apply_bump_float_and_stability(state: PhysicsDirectBodyState3D) -> void:
	var player := _grabber_player()
	if player == null:
		return
	var fwd := -state.transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 1e-5:
		return
	fwd = fwd.normalized()
	# Only assist while actually contacting geometry; prevents camera-turn induced airtime.
	if state.get_contact_count() <= 0:
		return
	var forward_speed := maxf(0.0, state.linear_velocity.dot(fwd))
	var up_assist := bump_float_force * clampf(forward_speed / bump_float_speed_ref, 0.0, 1.0)
	# Don't keep boosting when already moving upward quickly.
	if state.linear_velocity.y > 0.7:
		up_assist *= 0.25
	state.apply_central_force(Vector3.UP * up_assist)
	# Keep contact with ground during fast turns; disabled when airborne so drops feel natural.
	var hold := grounded_hold_force
	if state.linear_velocity.y > 0.0:
		hold += state.linear_velocity.y * 18.0
	state.apply_central_force(Vector3.DOWN * hold)
	var av := state.angular_velocity
	# Counter roll/pitch spin from abrupt curb contacts while still allowing yaw steering.
	state.apply_torque(Vector3(-av.x, 0.0, -av.z) * anti_flip_damping)
	# Dampen pure yaw spin so camera flicks don't slingshot the cart sideways.
	state.apply_torque(Vector3.UP * (-av.y * yaw_angular_damping))

func _steer_cart_front_to_camera_look(state: PhysicsDirectBodyState3D) -> void:
	var player := _grabber_player()
	if player == null:
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
	# Extra snap when very misaligned (quick turns), keeps nose from washing out to the side.
	if absf(angle) > 0.65:
		impulse *= 1.22
	# Limit impulse change per tick so camera flicks don't inject abrupt physics pops.
	var lo := _last_yaw_impulse - max_yaw_impulse_step
	var hi := _last_yaw_impulse + max_yaw_impulse_step
	impulse = clampf(impulse, lo, hi)
	_last_yaw_impulse = impulse
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
