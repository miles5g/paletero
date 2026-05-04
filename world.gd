extends Node3D

func _ready() -> void:
	# 1. Create the Sun
	var sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.position = Vector3(0, 10, 0)
	sun.rotation_degrees = Vector3(-45, 45, 0)
	add_child(sun)

	# 2. Build the Ground
	var ground = StaticBody3D.new()
	var ground_mesh = MeshInstance3D.new()
	ground_mesh.mesh = PlaneMesh.new()
	ground_mesh.mesh.size = Vector2(50, 50)
	
	var ground_col = CollisionShape3D.new()
	ground_col.shape = BoxShape3D.new()
	ground_col.shape.size = Vector3(50, 1, 50)
	
	ground.add_child(ground_mesh)
	ground.add_child(ground_col)
	add_child(ground)

	# 3. Spawn the Cart (RigidBody3D)
	var cart = RigidBody3D.new()
	cart.name = "Cart"
	cart.mass = 30.0
	cart.linear_damp = 1.0
	cart.angular_damp = 2.0
	cart.position = Vector3(0, 1, -5) # 5 meters in front of center
	
	var cart_mesh = MeshInstance3D.new()
	cart_mesh.mesh = BoxMesh.new()
	cart_mesh.mesh.size = Vector3(1, 1, 1.5)
	
	var cart_col = CollisionShape3D.new()
	cart_col.shape = BoxShape3D.new()
	cart_col.shape.size = Vector3(1, 1, 1.5)
	
	cart.add_child(cart_mesh)
	cart.add_child(cart_col)
	add_child(cart)

	# 4. Spawn the Player
	_spawn_player()

func _spawn_player() -> void:
	var player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1, 0)
	
	# Give the player a script (we will create this file next)
	player.set_script(load("res://player.gd"))
	
	var p_mesh = MeshInstance3D.new()
	p_mesh.mesh = CapsuleMesh.new()
	
	var p_col = CollisionShape3D.new()
	p_col.shape = CapsuleShape3D.new()
	
	# Add a Camera that follows the player
	var cam = Camera3D.new()
	cam.position = Vector3(0, 2.5, 4) # Up and behind
	cam.rotation_degrees = Vector3(-20, 0, 0) # Tilted down
	
	player.add_child(p_mesh)
	player.add_child(p_col)
	player.add_child(cam)
	add_child(player)