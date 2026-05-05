extends CharacterBody3D

const BASE_SPEED: float = 4.0
const SPRINT_SPEED: float = BASE_SPEED * 1.6
const CROUCH_SPEED: float = BASE_SPEED * 0.5
const JUMP_VELOCITY: float = 4.5
## Max walk speed while hitched (higher than old cap so pushing feels brisk).
const PUSH_MOVE_SPEED_CAP: float = 6.2

@export var push_force: float = 2.0
@export var mouse_sensitivity: float = 0.0025
## Virtual hitch: pulls cart toward a point in front of the player (CharacterBody3D + Jolt).
@export var hitch_spring: float = 2650.0
@export var hitch_damping: float = 118.0
## Vertical pull vs horizontal (stiffer Y keeps the hitch from sagging visually).
@export var hitch_vertical_spring: float = 1100.0
## How fast the hitch “looks” direction catches your facing (higher = stiffer in front).
@export var hitch_forward_track: float = 14.0
## Sideways oscillation of the target (meters); 0 = rigid arms / fixed line.
@export var hitch_wobble_amplitude: float = 0.0
## World-space distance from player to hitch target on the ground (fixed while grabbed).
@export var hitch_nominal_distance: float = 2.05
## Extra XZ force toward player horizontal velocity (tighter “rope” when starting/stopping).
@export var hitch_velocity_match: float = 58.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var is_pushing: bool = false
var current_cart: RigidBody3D = null
var _hitch_distance: float = 2.0
## Smoothed horizontal forward used for “in front” target (lags body/camera yaw).
var _hitch_forward_smooth: Vector3 = Vector3.ZERO
## Cart Y offset from player at grab (preserves relative height).
var _hitch_dy: float = 0.0
var can_interact: bool = false

var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D
var _capsule_mesh: CapsuleMesh
var _capsule_shape: CapsuleShape3D
var _stand_mesh_height: float
var _stand_shape_height: float
var _camera: Camera3D
var _push_arm_l: MeshInstance3D = null
var _push_arm_r: MeshInstance3D = null
var _push_forearm_l: MeshInstance3D = null
var _push_forearm_r: MeshInstance3D = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for c in get_children():
		if c is MeshInstance3D:
			_mesh_instance = c
		elif c is CollisionShape3D:
			_collision_shape = c
		elif c is Camera3D:
			_camera = c
	if _mesh_instance and _mesh_instance.mesh is CapsuleMesh:
		_capsule_mesh = _mesh_instance.mesh
		_stand_mesh_height = _capsule_mesh.height
	if _collision_shape and _collision_shape.shape is CapsuleShape3D:
		_capsule_shape = _collision_shape.shape
		_stand_shape_height = _capsule_shape.height

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _camera and not _is_inventory_menu_open():
		rotate_y(-event.relative.x * mouse_sensitivity)
		_camera.rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)
		var pitch := _camera.rotation_degrees.x
		_camera.rotation_degrees.x = clampf(pitch, -80.0, 80.0)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_inventory") and _can_toggle_cart_inventory():
		_toggle_inventory_menu()
	if Input.is_action_just_pressed("interact"):
		_interact()

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var want_stand := not Input.is_action_pressed("crouch")
	var geometry_crouch := Input.is_action_pressed("crouch") or (want_stand and not _can_uncrouch_to_stand())

	var move_speed := BASE_SPEED
	if geometry_crouch:
		move_speed = CROUCH_SPEED
	elif Input.is_action_pressed("sprint"):
		move_speed = SPRINT_SPEED
	if is_pushing:
		move_speed = minf(move_speed, PUSH_MOVE_SPEED_CAP)

	_update_crouch_capsule(geometry_crouch)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()

	if is_pushing and current_cart != null:
		current_cart.sleeping = false
		_apply_hitch_forces(delta)
		_update_push_arms_visual()

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()

		if body is RigidBody3D and (not is_pushing or body != current_cart):
			var force_dir = -collision.get_normal()
			body.apply_central_impulse(force_dir * velocity.length() * push_force)

func _interact() -> void:
	if is_pushing:
		_detach_from_cart()
		return
	if not can_interact:
		return
	for cart in get_tree().get_nodes_in_group("carts"):
		if cart is RigidBody3D and cart.has_method("is_player_in_grab_range") and cart.is_player_in_grab_range(self):
			_attach_to_cart(cart)
			return

func _attach_to_cart(cart: RigidBody3D) -> void:
	if current_cart != null and current_cart != cart:
		remove_collision_exception_with(current_cart)
	current_cart = cart
	is_pushing = true
	can_interact = false
	add_collision_exception_with(cart)
	var w := get_parent()
	if w != null and w.has_method("set_grab_prompts_visible"):
		w.set_grab_prompts_visible(false)
	_hitch_distance = hitch_nominal_distance
	_hitch_dy = cart.global_position.y - global_position.y
	var face := -global_transform.basis.z
	face.y = 0.0
	if face.length_squared() < 1e-5:
		face = Vector3(0, 0, -1)
	_hitch_forward_smooth = face.normalized()
	cart.freeze = false
	cart.sleeping = false
	cart.can_sleep = false
	_create_push_arms()

func _new_push_arm_mesh(arm_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = arm_name
	var cyl := CylinderMesh.new()
	cyl.height = 1.0
	cyl.top_radius = 0.058
	cyl.bottom_radius = 0.058
	cyl.radial_segments = 10
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.52, 0.42)
	mat.roughness = 0.9
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi

func _create_push_arms() -> void:
	_destroy_push_arms()
	_push_arm_l = _new_push_arm_mesh("PushArmUpperL")
	_push_arm_r = _new_push_arm_mesh("PushArmUpperR")
	_push_forearm_l = _new_push_arm_mesh("PushArmLowerL")
	_push_forearm_r = _new_push_arm_mesh("PushArmLowerR")
	add_child(_push_arm_l)
	add_child(_push_arm_r)
	add_child(_push_forearm_l)
	add_child(_push_forearm_r)

func _destroy_push_arms() -> void:
	if _push_arm_l != null and is_instance_valid(_push_arm_l):
		_push_arm_l.queue_free()
	if _push_arm_r != null and is_instance_valid(_push_arm_r):
		_push_arm_r.queue_free()
	if _push_forearm_l != null and is_instance_valid(_push_forearm_l):
		_push_forearm_l.queue_free()
	if _push_forearm_r != null and is_instance_valid(_push_forearm_r):
		_push_forearm_r.queue_free()
	_push_arm_l = null
	_push_arm_r = null
	_push_forearm_l = null
	_push_forearm_r = null

func _stretch_arm_between(mi: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var dir := to - from
	var h := dir.length()
	var cyl := mi.mesh as CylinderMesh
	if h < 0.02:
		mi.visible = false
		return
	mi.visible = true
	cyl.height = h
	var y_axis := dir / h
	var x_axis := y_axis.cross(global_transform.basis.z)
	if x_axis.length_squared() < 1e-6:
		x_axis = y_axis.cross(global_transform.basis.x)
	if x_axis.length_squared() < 1e-6:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	x_axis = y_axis.cross(z_axis).normalized()
	mi.global_position = from + dir * 0.5
	mi.global_basis = Basis(x_axis, y_axis, z_axis)

func _clamp_arm_reach_target(shoulder: Vector3, desired_target: Vector3) -> Vector3:
	var local_target := global_transform.basis.inverse() * (desired_target - shoulder)
	# Keep arms in front hemisphere: z > 0 is behind the torso in this setup.
	# No side stiffening: arms can sweep naturally in front.
	if local_target.z > 0.0:
		local_target.z = 0.0
	return shoulder + global_transform.basis * local_target

func _arm_elbow_target(shoulder: Vector3, hand_target: Vector3, side_sign: float) -> Vector3:
	var dir := hand_target - shoulder
	var reach_len := dir.length()
	if reach_len < 0.05:
		return shoulder + global_transform.basis * Vector3(0.0, -0.12, -0.08)
	var mid := shoulder + dir * 0.5
	var b := global_transform.basis
	var bend_out := b.x * side_sign * 0.14
	var bend_down := -b.y * 0.11
	# Slight backward bow adds loose, organic bend while keeping hands attached.
	var bend_back := b.z * 0.08
	var bend_scale := clampf(reach_len / 2.0, 0.55, 1.0)
	return mid + (bend_out + bend_down + bend_back) * bend_scale

func _update_push_arms_visual() -> void:
	if current_cart == null or not is_instance_valid(current_cart):
		return
	if _push_arm_l == null or _push_arm_r == null or _push_forearm_l == null or _push_forearm_r == null:
		return
	var b := global_transform.basis
	var left_shoulder := global_position + b * Vector3(-0.42, 0.92, 0.08)
	var right_shoulder := global_position + b * Vector3(0.42, 0.92, 0.08)
	var handle_gp: Vector3
	var hz := current_cart.get_node_or_null("HandleZone") as Node3D
	if hz != null and hz.is_inside_tree():
		handle_gp = hz.global_position
	else:
		var cb := current_cart.global_transform.basis
		handle_gp = current_cart.global_position + cb * Vector3(0.0, 0.45, 0.75)
	var left_target := _clamp_arm_reach_target(left_shoulder, handle_gp)
	var right_target := _clamp_arm_reach_target(right_shoulder, handle_gp)
	var left_elbow := _arm_elbow_target(left_shoulder, left_target, -1.0)
	var right_elbow := _arm_elbow_target(right_shoulder, right_target, 1.0)
	_stretch_arm_between(_push_arm_l, left_shoulder, left_elbow)
	_stretch_arm_between(_push_forearm_l, left_elbow, left_target)
	_stretch_arm_between(_push_arm_r, right_shoulder, right_elbow)
	_stretch_arm_between(_push_forearm_r, right_elbow, right_target)

func _apply_hitch_forces(delta: float) -> void:
	if current_cart == null or not is_instance_valid(current_cart):
		return
	var face := -global_transform.basis.z
	face.y = 0.0
	if face.length_squared() < 1e-5:
		face = _hitch_forward_smooth
	face = face.normalized()
	var alpha := 1.0 - exp(-hitch_forward_track * delta)
	_hitch_forward_smooth = _hitch_forward_smooth.lerp(face, alpha)
	if _hitch_forward_smooth.length_squared() < 1e-5:
		_hitch_forward_smooth = face
	else:
		_hitch_forward_smooth = _hitch_forward_smooth.normalized()
	var right := Vector3(-_hitch_forward_smooth.z, 0.0, _hitch_forward_smooth.x).normalized()
	var wob := sin(Time.get_ticks_msec() * 0.0017) * hitch_wobble_amplitude
	var target_xz := global_position + _hitch_forward_smooth * _hitch_distance + right * wob
	var desired := Vector3(target_xz.x, global_position.y + _hitch_dy, target_xz.z)
	var err: Vector3 = desired - current_cart.global_position
	# Hard guard: if cart drifts behind, add strong forward pull to recover control quickly.
	var to_cart_xz := current_cart.global_position - global_position
	to_cart_xz.y = 0.0
	var behind_dist := maxf(0.0, -to_cart_xz.dot(_hitch_forward_smooth))
	var behind_correction := _hitch_forward_smooth * (behind_dist * hitch_spring * 0.9)
	var v := current_cart.linear_velocity
	var damp_h := Vector3(v.x, 0.0, v.z) * hitch_damping
	var damp_v := Vector3(0.0, v.y, 0.0) * hitch_damping * 0.42
	var v_cart_xz := Vector3(v.x, 0.0, v.z)
	var v_player_xz := Vector3(velocity.x, 0.0, velocity.z)
	var match_xz := (v_player_xz - v_cart_xz) * hitch_velocity_match
	current_cart.apply_central_force(
		Vector3(err.x, 0.0, err.z) * hitch_spring
		+ Vector3(0.0, err.y, 0.0) * hitch_vertical_spring
		+ Vector3(behind_correction.x, 0.0, behind_correction.z)
		+ Vector3(match_xz.x, 0.0, match_xz.z)
		- damp_h
		- damp_v
	)

func _detach_from_cart() -> void:
	_destroy_push_arms()
	var cart := current_cart
	if cart != null:
		cart.can_sleep = true
		remove_collision_exception_with(cart)
	is_pushing = false
	can_interact = cart != null and cart.has_method("is_player_in_grab_range") and cart.is_player_in_grab_range(self)
	var wp := get_parent()
	if wp != null and wp.has_method("set_grab_prompts_visible"):
		wp.set_grab_prompts_visible(can_interact)
	current_cart = null

func _exit_tree() -> void:
	_detach_from_cart()


func _inventory_menu_panel() -> Panel:
	var w := get_parent()
	if w == null:
		return null
	return w.get_node_or_null("HUD/InventoryMenu") as Panel


func _is_inventory_menu_open() -> bool:
	var panel := _inventory_menu_panel()
	return panel != null and panel.visible


func _can_toggle_cart_inventory() -> bool:
	if is_pushing:
		return true
	for c in get_tree().get_nodes_in_group("carts"):
		if c is RigidBody3D and c.has_method("is_player_in_grab_range") and c.is_player_in_grab_range(self):
			return true
	return false


func _resolve_cart_for_inventory() -> RigidBody3D:
	if is_pushing and current_cart != null and is_instance_valid(current_cart):
		return current_cart
	for c in get_tree().get_nodes_in_group("carts"):
		if c is RigidBody3D and c.has_method("is_player_in_grab_range") and c.is_player_in_grab_range(self):
			return c
	return null


func _toggle_inventory_menu() -> void:
	var panel := _inventory_menu_panel()
	if panel == null:
		return
	panel.visible = not panel.visible
	if panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var cart := _resolve_cart_for_inventory()
		if cart != null and panel.has_method("bind_cart"):
			panel.bind_cart(cart)
		if panel.has_method("refresh"):
			panel.refresh()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _can_uncrouch_to_stand() -> bool:
	if _collision_shape == null or _capsule_shape == null:
		return true
	if _capsule_shape.height >= _stand_shape_height - 0.01:
		return true
	var up := global_transform.basis.y.normalized()
	var half_curr := _capsule_shape.height * 0.5
	var half_stand := _stand_shape_height * 0.5
	var crouch_top := _collision_shape.global_position + up * half_curr
	var stand_top := global_position + up * half_stand
	var probe_len: float = (stand_top - crouch_top).dot(up)
	if probe_len <= 0.02:
		return true
	var space := get_world_3d().direct_space_state
	var from := crouch_top + up * 0.02
	var to := crouch_top + up * (probe_len + 0.02)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	q.collision_mask = collision_mask
	return space.intersect_ray(q).is_empty()

func _update_crouch_capsule(crouching: bool) -> void:
	if _capsule_mesh == null or _capsule_shape == null or _mesh_instance == null or _collision_shape == null:
		return
	if crouching:
		_capsule_mesh.height = _stand_mesh_height * 0.5
		_capsule_shape.height = _stand_shape_height * 0.5
		var dy := -_stand_shape_height * 0.25
		_mesh_instance.position.y = dy
		_collision_shape.position.y = dy
	else:
		_capsule_mesh.height = _stand_mesh_height
		_capsule_shape.height = _stand_shape_height
		_mesh_instance.position.y = 0.0
		_collision_shape.position.y = 0.0
