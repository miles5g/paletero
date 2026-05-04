extends CharacterBody3D

const BASE_SPEED: float = 4.0
const SPRINT_SPEED: float = BASE_SPEED * 1.6
const CROUCH_SPEED: float = BASE_SPEED * 0.5
const JUMP_VELOCITY: float = 4.5
const PUSH_MOVE_SPEED_CAP: float = 2.0

@export var push_force: float = 2.0
@export var mouse_sensitivity: float = 0.0025
## Virtual hitch: pulls cart toward the anchor relative to the player (works with CharacterBody3D + Jolt).
@export var hitch_spring: float = 2200.0
@export var hitch_damping: float = 95.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var is_pushing: bool = false
var current_cart: RigidBody3D = null
## Cart center relative to player in player-local axes (XZ follow, Y keeps height relationship).
var _hitch_cart_local: Vector3 = Vector3.ZERO
var can_interact: bool = false

var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D
var _capsule_mesh: CapsuleMesh
var _capsule_shape: CapsuleShape3D
var _stand_mesh_height: float
var _stand_shape_height: float
var _camera: Camera3D

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
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _camera:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_camera.rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)
		var pitch := _camera.rotation_degrees.x
		_camera.rotation_degrees.x = clampf(pitch, -80.0, 80.0)

func _physics_process(delta: float) -> void:
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
		_apply_hitch_forces()

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
	add_collision_exception_with(cart)
	_hitch_cart_local = global_transform.basis.inverse() * (cart.global_position - global_position)
	cart.freeze = false
	cart.sleeping = false
	cart.can_sleep = false

func _apply_hitch_forces() -> void:
	if current_cart == null or not is_instance_valid(current_cart):
		return
	var desired := global_position + global_transform.basis * _hitch_cart_local
	var err: Vector3 = desired - current_cart.global_position
	var v := current_cart.linear_velocity
	var damp := Vector3(v.x, 0.0, v.z) * hitch_damping
	current_cart.apply_central_force(err * hitch_spring - damp)

func _detach_from_cart() -> void:
	var cart := current_cart
	if cart != null:
		cart.can_sleep = true
		remove_collision_exception_with(cart)
	is_pushing = false
	current_cart = null

func _exit_tree() -> void:
	_detach_from_cart()

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
