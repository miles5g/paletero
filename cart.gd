extends RigidBody3D

## =============================================================================
## Cart physics (grabbed + free). All “feel” tuning lives in these exports.
## Player applies planar coupling in player.gd; this script only handles body
## integration extras: yaw toward camera, roll/pitch stability, light grounding.
## =============================================================================

## --- Yaw (camera vs cart heading) — torque only, no offset wheel forces ---
@export var yaw_align_strength: float = 210.0
@export var yaw_angular_damping: float = 6.0
@export var yaw_max_torque: float = 460.0
## Scale yaw correction when player is not pressing movement (look-only).
@export var yaw_align_idle_scale: float = 0.35
## Debug: draw camera/cart steering sources and connecting rope (visual only).
@export var steer_debug_visible: bool = true
@export var steer_source_cart_forward: float = 0.78
@export var steer_source_cart_height: float = 0.16
## Maximum allowed distance from source A to source C.
@export var steer_source_c_max_dist: float = 10
## Hard-lock cart front anchor to source C while grabbed.
@export var steer_lock_front_to_c: bool = true
## Limit per-step planar lock correction to avoid violent grab snaps.
@export var steer_lock_max_step_m: float = 0.45
## Safety floor for cart center while lock is active.
@export var steer_lock_min_center_y: float = 0.45
## Show live yellow connector length text near rope midpoint.
@export var steer_rope_length_label_visible: bool = true

## --- Heavy impact feedback (simple layer-2 structural check) ---
@export var impact_layer_2_min_speed: float = 5.8
@export var impact_feedback_cooldown_sec: float = 0.18

var _handle_zone: Area3D
var _interaction_area: Area3D
## Snapshot from spawn (`world.gd`); physics mass stays fixed regardless of inventory.
var _base_mass: float = 1.0
var _steer_source_cart_debug: MeshInstance3D = null
var _steer_source_cart_front_debug: MeshInstance3D = null
var _steer_rope_debug: MeshInstance3D = null
var _steer_rope_length_label: Label3D = null
var _steer_rope_cb_debug: MeshInstance3D = null
var _steer_rope_cb_length_label: Label3D = null
var _impact_feedback_cd_t: float = 0.0

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

	# Debug: cart-local source point B (red) and rope AB (yellow) to camera source A.
	if steer_debug_visible:
		var src := MeshInstance3D.new()
		src.name = "CartSourceDebug"
		var s_mesh := SphereMesh.new()
		s_mesh.radius = 0.1
		s_mesh.height = 0.2
		src.mesh = s_mesh
		var s_mat := StandardMaterial3D.new()
		s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		s_mat.albedo_color = Color(1.0, 0.25, 0.25, 0.96)
		s_mat.emission_enabled = true
		s_mat.emission = s_mat.albedo_color * 0.7
		src.material_override = s_mat
		add_child(src)
		_steer_source_cart_debug = src

		var src_front := MeshInstance3D.new()
		src_front.name = "CartFrontCenterDebug"
		var sf_mesh := SphereMesh.new()
		sf_mesh.radius = 0.09
		sf_mesh.height = 0.18
		src_front.mesh = sf_mesh
		var sf_mat := StandardMaterial3D.new()
		sf_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sf_mat.albedo_color = Color(0.2, 1.0, 0.3, 0.96)
		sf_mat.emission_enabled = true
		sf_mat.emission = sf_mat.albedo_color * 0.65
		src_front.material_override = sf_mat
		add_child(src_front)
		_steer_source_cart_front_debug = src_front

		var rope := MeshInstance3D.new()
		rope.name = "CartRopeDebug"
		var r_mesh := CylinderMesh.new()
		r_mesh.top_radius = 0.04
		r_mesh.bottom_radius = 0.04
		r_mesh.height = 1.0
		rope.mesh = r_mesh
		var r_mat := StandardMaterial3D.new()
		r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		r_mat.albedo_color = Color(1.0, 0.92, 0.25, 0.96)
		r_mat.emission_enabled = true
		r_mat.emission = r_mat.albedo_color * 0.5
		rope.material_override = r_mat
		add_child(rope)
		_steer_rope_debug = rope

		var len_label := Label3D.new()
		len_label.name = "CartRopeLenDebug"
		len_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		len_label.no_depth_test = true
		len_label.font_size = 36
		len_label.modulate = Color(1.0, 0.92, 0.25, 0.98)
		len_label.outline_size = 6
		len_label.text = "0.00m"
		add_child(len_label)
		_steer_rope_length_label = len_label

		var rope_cb := MeshInstance3D.new()
		rope_cb.name = "CartRopeCBDebug"
		var cb_mesh := CylinderMesh.new()
		cb_mesh.top_radius = 0.03
		cb_mesh.bottom_radius = 0.03
		cb_mesh.height = 1.0
		rope_cb.mesh = cb_mesh
		var cb_mat := StandardMaterial3D.new()
		cb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cb_mat.albedo_color = Color(0.55, 1.0, 0.55, 0.96)
		cb_mat.emission_enabled = true
		cb_mat.emission = cb_mat.albedo_color * 0.5
		rope_cb.material_override = cb_mat
		add_child(rope_cb)
		_steer_rope_cb_debug = rope_cb

		var cb_len_label := Label3D.new()
		cb_len_label.name = "CartRopeCBLenDebug"
		cb_len_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cb_len_label.no_depth_test = true
		cb_len_label.font_size = 32
		cb_len_label.modulate = Color(0.55, 1.0, 0.55, 0.98)
		cb_len_label.outline_size = 6
		cb_len_label.text = "0.00m"
		add_child(cb_len_label)
		_steer_rope_cb_length_label = cb_len_label

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
	var push_intent := 1.0
	if player != null and player.has_method("get_cart_push_intent"):
		push_intent = player.get_cart_push_intent()
	if player != null and steer_lock_front_to_c and push_intent > 0.01:
		# Keep C-lock active only while movement is pressed; idle remains free/neutral.
		_enforce_cart_front_lock_to_c(state, player)
	# Continuous yaw damping keeps angular velocity bounded between heading updates.
	state.apply_torque(Vector3.UP * (-av.y * yaw_angular_damping))
	if _impact_feedback_cd_t > 0.0:
		_impact_feedback_cd_t = maxf(0.0, _impact_feedback_cd_t - state.step)
	_maybe_emit_heavy_impact_feedback(state, player)
	if player != null:
		_apply_yaw_toward_camera(state, player)
		_update_steer_debug_sources(state, player)
	elif steer_debug_visible:
		_update_steer_debug_sources(state, null)


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
	var intent := 1.0
	if player.has_method("get_cart_push_intent"):
		intent = player.get_cart_push_intent()
	# No movement key -> no yaw steering influence.
	if intent <= 0.01:
		return
	var cam: Camera3D = null
	for c in player.get_children():
		if c is Camera3D:
			cam = c
			break
	if cam == null:
		return
	# Steering target is the rope direction: cart source B pulled toward camera source A.
	var cart_front_world := state.transform.origin \
		+ (-state.transform.basis.z) * steer_source_cart_forward
	var src_a_valid := false
	var src_a := Vector3.ZERO
	var tip := cam.get_node_or_null("CameraSteerTipDebug") as MeshInstance3D
	if tip != null and is_instance_valid(tip):
		src_a = tip.global_position
		src_a_valid = true
	else:
		var cam_fwd := -cam.global_transform.basis.z
		if cam_fwd.length_squared() > 1e-6:
			cam_fwd = cam_fwd.normalized()
			src_a = cam.global_transform.origin + cam_fwd * 6.0
			src_a_valid = true
	if not src_a_valid:
		return
	var a_to_c := cart_front_world - src_a
	var c_max := maxf(0.2, steer_source_c_max_dist)
	if a_to_c.length() > c_max:
		cart_front_world = src_a + a_to_c.normalized() * c_max
	# Source B is constrained to be equidistant from A and C (the midpoint).
	var src_b := (src_a + cart_front_world) * 0.5
	var rope_dir := src_b - cart_front_world
	rope_dir.y = 0.0
	if rope_dir.length_squared() < 1e-6:
		return
	var want := rope_dir.normalized()
	var fwd := -state.transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 1e-6:
		return
	fwd = fwd.normalized()
	var angle := fwd.signed_angle_to(want, Vector3.UP)
	if absf(angle) < 0.004:
		return
	# Look-only rotations should not steer as aggressively as active pushing input.
	var idle_w := lerpf(yaw_align_idle_scale, 1.0, intent)
	# P-controller on yaw error with hard torque clamp for deterministic tuning.
	var torque := clampf(angle * yaw_align_strength * idle_w, -yaw_max_torque, yaw_max_torque)
	state.apply_torque(Vector3.UP * torque)


func _enforce_cart_front_lock_to_c(state: PhysicsDirectBodyState3D, player: CharacterBody3D) -> void:
	var cam: Camera3D = null
	for c in player.get_children():
		if c is Camera3D:
			cam = c
			break
	if cam == null:
		return
	var src_a_valid := false
	var src_a := Vector3.ZERO
	var tip := cam.get_node_or_null("CameraSteerTipDebug") as MeshInstance3D
	if tip != null and is_instance_valid(tip):
		src_a = tip.global_position
		src_a_valid = true
	else:
		var cam_fwd := -cam.global_transform.basis.z
		if cam_fwd.length_squared() > 1e-6:
			cam_fwd = cam_fwd.normalized()
			src_a = cam.global_transform.origin + cam_fwd * 6.0
			src_a_valid = true
	if not src_a_valid:
		return

	# Current cart front anchor (body-dependent), then clamp to source-C max distance from A.
	var front_now := state.transform.origin \
		+ (-state.transform.basis.z) * steer_source_cart_forward \
		+ Vector3.UP * steer_source_cart_height
	var a_to_c := front_now - src_a
	var c_max := maxf(0.2, steer_source_c_max_dist)
	var c_target := front_now
	if a_to_c.length() > c_max:
		c_target = src_a + a_to_c.normalized() * c_max

	# Absolute lock in XZ only (avoid downward snaps from camera pitch/height changes).
	var lock_delta := c_target - front_now
	lock_delta.y = 0.0
	var step_cap := maxf(0.05, steer_lock_max_step_m)
	if lock_delta.length() > step_cap:
		lock_delta = lock_delta.normalized() * step_cap
	if lock_delta.length_squared() < 1e-8:
		return
	var t := state.transform
	t.origin += lock_delta
	# Keep center above a minimum safety height so grab cannot pop underground.
	t.origin.y = maxf(t.origin.y, steer_lock_min_center_y)
	state.transform = t

	# Prevent immediate separation along the planar lock axis.
	var n := lock_delta.normalized()
	var v := state.linear_velocity
	var sep_speed := -v.dot(n)
	if sep_speed > 0.0:
		v += n * sep_speed
		state.linear_velocity = v


func _maybe_emit_heavy_impact_feedback(state: PhysicsDirectBodyState3D, player: CharacterBody3D) -> void:
	if _impact_feedback_cd_t > 0.0:
		return
	var speed := state.linear_velocity.length()
	if speed < impact_layer_2_min_speed:
		return
	var structural_layer_mask := 1 << (2 - 1) # Layer 2
	for i in range(state.get_contact_count()):
		var collider := state.get_contact_collider_object(i)
		if not collider is CollisionObject3D:
			continue
		var c := collider as CollisionObject3D
		if (c.collision_layer & structural_layer_mask) == 0:
			continue
		_impact_feedback_cd_t = impact_feedback_cooldown_sec
		var w := get_parent()
		if w != null and w.has_method("play_cart_impact_feedback"):
			w.call("play_cart_impact_feedback", speed)
		if player != null and player.has_method("on_cart_heavy_impact"):
			player.call("on_cart_heavy_impact", speed)
		return


func _update_steer_debug_sources(state: PhysicsDirectBodyState3D, player: CharacterBody3D) -> void:
	if not steer_debug_visible:
		if _steer_source_cart_debug != null:
			_steer_source_cart_debug.visible = false
		if _steer_rope_debug != null:
			_steer_rope_debug.visible = false
		if _steer_rope_cb_debug != null:
			_steer_rope_cb_debug.visible = false
		if _steer_source_cart_front_debug != null:
			_steer_source_cart_front_debug.visible = false
		if _steer_rope_length_label != null:
			_steer_rope_length_label.visible = false
		if _steer_rope_cb_length_label != null:
			_steer_rope_cb_length_label.visible = false
		return
	if _steer_source_cart_debug == null or _steer_rope_debug == null:
		return
	# Raw C point: always pinned to the cart's front plane.
	var cart_front_raw := state.transform.origin \
		+ (-state.transform.basis.z) * steer_source_cart_forward \
		+ Vector3.UP * steer_source_cart_height
	var cart_front_world := cart_front_raw
	if _steer_source_cart_front_debug != null:
		_steer_source_cart_front_debug.visible = true
		_steer_source_cart_front_debug.global_position = cart_front_raw

	# Source A: camera tip in front of the player's gaze, if available.
	var src_a_valid := false
	var src_a := Vector3.ZERO
	if player != null and is_instance_valid(player):
		for c in player.get_children():
			if c is Camera3D:
				var cam := c as Camera3D
				var tip := cam.get_node_or_null("CameraSteerTipDebug") as MeshInstance3D
				if tip != null and is_instance_valid(tip):
					src_a = tip.global_position
					src_a_valid = true
				else:
					var cam_fwd := -cam.global_transform.basis.z
					if cam_fwd.length_squared() > 1e-6:
						cam_fwd = cam_fwd.normalized()
						src_a = cam.global_transform.origin + cam_fwd * 6.0
						src_a_valid = true
				break

	if not src_a_valid:
		_steer_rope_debug.visible = false
		if _steer_rope_cb_debug != null:
			_steer_rope_cb_debug.visible = false
		if _steer_rope_length_label != null:
			_steer_rope_length_label.visible = false
		if _steer_rope_cb_length_label != null:
			_steer_rope_cb_length_label.visible = false
		if _steer_source_cart_debug != null:
			_steer_source_cart_debug.visible = false
		if _steer_source_cart_front_debug != null:
			_steer_source_cart_front_debug.visible = true
			_steer_source_cart_front_debug.global_position = cart_front_raw
		return

	var a_to_c := cart_front_world - src_a
	var c_max := maxf(0.2, steer_source_c_max_dist)
	if a_to_c.length() > c_max:
		cart_front_world = src_a + a_to_c.normalized() * c_max
	# B is equidistant from A and C by definition (midpoint of segment AC).
	var src_b := (src_a + cart_front_world) * 0.5

	_steer_source_cart_debug.visible = true
	_steer_source_cart_debug.global_position = src_b

	# Rope AB: exact A<->B connector, hard-locked length.
	var dir := src_b - src_a
	var h := dir.length()
	if h < 0.05:
		_steer_rope_debug.visible = false
		if _steer_rope_cb_debug != null:
			_steer_rope_cb_debug.visible = false
		if _steer_rope_length_label != null:
			_steer_rope_length_label.visible = false
		if _steer_rope_cb_length_label != null:
			_steer_rope_cb_length_label.visible = false
		return
	_steer_rope_debug.visible = true
	var y_axis := dir / h
	var x_axis := y_axis.cross(Vector3.FORWARD)
	if x_axis.length_squared() < 1e-6:
		x_axis = y_axis.cross(Vector3.RIGHT)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	x_axis = y_axis.cross(z_axis).normalized()
	_steer_rope_debug.global_position = src_a + dir * 0.5
	_steer_rope_debug.global_basis = Basis(x_axis, y_axis, z_axis)
	var cyl := _steer_rope_debug.mesh as CylinderMesh
	cyl.height = h
	if _steer_rope_length_label != null:
		_steer_rope_length_label.visible = steer_rope_length_label_visible
		if steer_rope_length_label_visible:
			_steer_rope_length_label.global_position = src_a + dir * 0.5 + Vector3.UP * 0.22
			_steer_rope_length_label.text = "%0.2fm" % h

	# Rope CB: visible string from raw cart-front C (green) to locked endpoint B, with distance.
	if _steer_rope_cb_debug != null:
		var dir_cb := src_b - cart_front_raw
		var h_cb := dir_cb.length()
		if h_cb < 0.05:
			_steer_rope_cb_debug.visible = false
			if _steer_rope_cb_length_label != null:
				_steer_rope_cb_length_label.visible = false
		else:
			_steer_rope_cb_debug.visible = true
			var y_cb := dir_cb / h_cb
			var x_cb := y_cb.cross(Vector3.FORWARD)
			if x_cb.length_squared() < 1e-6:
				x_cb = y_cb.cross(Vector3.RIGHT)
			x_cb = x_cb.normalized()
			var z_cb := x_cb.cross(y_cb).normalized()
			x_cb = y_cb.cross(z_cb).normalized()
			_steer_rope_cb_debug.global_position = cart_front_raw + dir_cb * 0.5
			_steer_rope_cb_debug.global_basis = Basis(x_cb, y_cb, z_cb)
			var cyl_cb := _steer_rope_cb_debug.mesh as CylinderMesh
			cyl_cb.height = h_cb
			if _steer_rope_cb_length_label != null:
				_steer_rope_cb_length_label.visible = steer_rope_length_label_visible
				if steer_rope_length_label_visible:
					_steer_rope_cb_length_label.global_position = cart_front_raw + dir_cb * 0.5 + Vector3.UP * 0.16
					_steer_rope_cb_length_label.text = "CB %0.2fm" % h_cb


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
