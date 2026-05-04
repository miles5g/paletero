extends Node3D

func _ready() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	var interaction_label := Label.new()
	interaction_label.name = "InteractionLabel"
	interaction_label.text = "[E] Grab Cart"
	interaction_label.visible = false
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_child(interaction_label)
	interaction_label.anchor_left = 0.0
	interaction_label.anchor_right = 1.0
	interaction_label.anchor_top = 1.0
	interaction_label.anchor_bottom = 1.0
	interaction_label.offset_top = -52.0
	interaction_label.offset_bottom = -12.0
	add_child(hud)

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
	cart.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	cart.center_of_mass = Vector3(0, 0, -0.5)
	cart.set_script(load("res://cart.gd"))
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
	# InteractionArea lives on cart script; place on +Z local side facing player spawn (0,*,0) vs cart at z=-5.
	var interaction_area := cart.get_node_or_null("InteractionArea") as Area3D
	if interaction_area:
		interaction_area.position = Vector3(0, 0, 0.75)

	# 4. Spawn the Player
	_spawn_player()

func _spawn_player() -> void:
	var player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1, 0)
	player.collision_layer = 1
	player.collision_mask = 1
	
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