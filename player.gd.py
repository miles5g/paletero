extends CharacterBody3D

@export var speed: float = 4.0
@export var push_force: float = 2.0 
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	# 1. Apply Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Handle Movement Input
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	# 3. Pushing Logic (The "Bones" of the Cart interaction)
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		
		# If the thing we walk into is a RigidBody (The Cart), give it a push
		if body is RigidBody3D:
			var force_dir = -collision.get_normal()
			body.apply_central_impulse(force_dir * velocity.length() * push_force)