extends RigidBody3D

## =============================================================================
## Cart physics (grabbed + free). All “feel” tuning lives in these exports.
## Player applies planar coupling in player.gd; this script only handles body
## integration extras: yaw toward camera, roll/pitch stability, light grounding.
## =============================================================================

## --- Yaw (camera vs cart heading) — torque only, no offset wheel forces ---
@export var yaw_align_strength: float = 42.0
@export var yaw_angular_damping: float = 6.0
@export var yaw_max_torque: float = 95.0
## Scale yaw correction when player is not pressing movement (look-only).
@export var yaw_align_idle_scale: float = 0.35

## --- Angular stability (curbs / impacts) ---
@export var roll_pitch_damping: float = 8.0

## --- Grounding when grabbed (contacts only; no forward-speed “boost”) ---
@export var grabbed_downward_bias: float = 220.0
## Below this vertical speed (m/s), treat as supported / not in free fall.
@export var falling_velocity_threshold: float = -3.2

var _handle_zone: Area3D
var _interaction_area: Area3D
## Snapshot from spawn (`world.gd`); physics mass stays fixed regardless of inventory.
var _base_mass: float = 1.0

var inventory_list: Array[ItemResource] = []


func _ready() -> void:
	add_to_group("carts")
	_base_mass = mass
	_stock_initial_inventory()
	update_mass()
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
	_interaction_area.position = Vector3(0, 0, 0.75)
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


func calculate_total_weight() -> float:
	var total := 0.0
	for it in inventory_list:
		if it is ItemResource:
			total += it.weight_lbs * float(it.quantity)
	return total


func update_mass() -> void:
	# Inventory is manifest-only for UI; do not change RigidBody mass.
	mass = maxf(0.01, _base_mass)


func _stock_initial_inventory() -> void:
	var lime := ItemResource.new()
	lime.item_name = "Lime Paleta"
	lime.quantity = 1
	lime.weight_lbs = 1.0
	lime.value_usd = 1.50
	lime.description = "Tart lime frozen fruit bar."
	lime.rarity = ItemResource.Rarity.GREEN
	lime.category = ItemResource.Category.FOOD
	lime.hand_model = ItemResource.HandModel.SPHERE
	add_item_to_inventory(lime)

	var ice := ItemResource.new()
	ice.item_name = "Dry Ice Pack"
	ice.quantity = 1
	ice.weight_lbs = 5.0
	ice.value_usd = 10.00
	ice.description = "Keeps the cart cold. Heavy but necessary."
	ice.rarity = ItemResource.Rarity.BLUE
	ice.category = ItemResource.Category.UTILITY
	ice.hand_model = ItemResource.HandModel.CUBE
	add_item_to_inventory(ice)

	var recipe := ItemResource.new()
	recipe.item_name = "Secret Recipe"
	recipe.quantity = 1
	recipe.weight_lbs = 0.1
	recipe.value_usd = 500.00
	recipe.description = "A handwritten note with the perfect flavor ratios. Priceless."
	recipe.rarity = ItemResource.Rarity.GOLD
	recipe.category = ItemResource.Category.UTILITY
	recipe.hand_model = ItemResource.HandModel.SCROLL
	add_item_to_inventory(recipe)

	var cooler := ItemResource.new()
	cooler.item_name = "Industrial Cooler"
	cooler.quantity = 1
	cooler.weight_lbs = 25.0
	cooler.value_usd = 250.00
	cooler.description = "A heavy-duty compressor. Makes the cart significantly heavier."
	cooler.rarity = ItemResource.Rarity.GOLD
	cooler.category = ItemResource.Category.UTILITY
	cooler.hand_model = ItemResource.HandModel.CUBE
	add_item_to_inventory(cooler)


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
	# Integration ownership:
	# - Player script applies translational coupling (XZ + mild Y) while pushing.
	# - Cart script applies rotational stabilization and heading assist.
	# Keeping these responsibilities split avoids duplicate/competing force stacks.
	var player := _grabber_player()
	var av := state.angular_velocity
	# Dampen roll/pitch first so curb hits do not cascade into wobble/flip loops.
	state.apply_torque(Vector3(-av.x, 0.0, -av.z) * roll_pitch_damping)
	# Continuous yaw damping keeps angular velocity bounded between heading updates.
	state.apply_torque(Vector3.UP * (-av.y * yaw_angular_damping))
	if player != null:
		_apply_yaw_toward_camera(state, player)
		_apply_grabbed_grounding(state)


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


func _apply_yaw_toward_camera(state: PhysicsDirectBodyState3D, player: CharacterBody3D) -> void:
	var cam: Camera3D = null
	for c in player.get_children():
		if c is Camera3D:
			cam = c
			break
	if cam == null:
		return
	var want := -cam.global_transform.basis.z
	want.y = 0.0
	if want.length_squared() < 1e-6:
		return
	want = want.normalized()
	var fwd := -state.transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 1e-6:
		return
	fwd = fwd.normalized()
	var angle := fwd.signed_angle_to(want, Vector3.UP)
	if absf(angle) < 0.004:
		return
	var intent := 1.0
	if player.has_method("get_cart_push_intent"):
		intent = player.get_cart_push_intent()
	# Look-only rotations should not steer as aggressively as active pushing input.
	var idle_w := lerpf(yaw_align_idle_scale, 1.0, intent)
	# P-controller on yaw error with hard torque clamp for deterministic tuning.
	var torque := clampf(angle * yaw_align_strength * idle_w, -yaw_max_torque, yaw_max_torque)
	state.apply_torque(Vector3.UP * torque)


func _apply_grabbed_grounding(state: PhysicsDirectBodyState3D) -> void:
	if state.get_contact_count() <= 0:
		return
	var vy := state.linear_velocity.y
	# Real falls: let gravity act unassisted.
	if vy < falling_velocity_threshold:
		return
	# Upward motion (jump, curb pop): do not add extra downward hold,
	# or we will immediately cancel loft and hide jump sync.
	if vy > 0.0:
		return
	# Downward bias is applied only when supported so real drops remain ballistic.
	state.apply_central_force(Vector3.DOWN * grabbed_downward_bias)


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
