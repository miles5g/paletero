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

	# Gritty world mood: dark overcast sky + dense fog.
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	# Slightly lifted from true black so distant silhouettes read against “overcast void.”
	env.background_color = Color(0.065, 0.07, 0.088)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Faint deep blue-grey fill: enough to read floor grit in shadow, still hostile.
	env.ambient_light_color = Color(0.14, 0.15, 0.22)
	env.ambient_light_energy = 1.22
	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.23, 0.28)
	# Claustrophobic visibility: most scene detail fades by ~15–20m; slightly softer near camera.
	env.fog_density = 0.058
	env.fog_sky_affect = 1.0
	env.fog_aerial_perspective = 0.6
	world_env.environment = env
	add_child(world_env)

	# 1. Create the Sun
	var sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = 0.62
	sun.light_color = Color(0.58, 0.62, 0.72)
	sun.position = Vector3(0, 10, 0)
	sun.rotation_degrees = Vector3(-45, 45, 0)
	add_child(sun)

	# 2. Build the Ground
	var ground = StaticBody3D.new()
	var ground_mesh = MeshInstance3D.new()
	ground_mesh.mesh = PlaneMesh.new()
	ground_mesh.mesh.size = Vector2(50, 50)
	var wet_asphalt := StandardMaterial3D.new()
	# Tiny lift so ambient + spec catch “wet” read instead of pure ink.
	wet_asphalt.albedo_color = Color(0.075, 0.078, 0.095)
	wet_asphalt.roughness = 0.1
	wet_asphalt.metallic = 0.0
	wet_asphalt.specular = 1.0
	ground_mesh.material_override = wet_asphalt
	
	var ground_col = CollisionShape3D.new()
	ground_col.shape = BoxShape3D.new()
	ground_col.shape.size = Vector3(50, 1, 50)
	
	ground.add_child(ground_mesh)
	ground.add_child(ground_col)
	add_child(ground)

	# 3. Spawn the Cart (RigidBody3D)
	var cart = RigidBody3D.new()
	cart.name = "Cart"
	cart.mass = 12.0
	cart.linear_damp = 0.45
	cart.gravity_scale = 0.82
	# Lighter cart: less angular drag so it feels a bit floatier while still settling.
	cart.angular_damp = 3.8
	cart.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	# Box is 1m tall centered at origin: put mass well below center, slightly toward the rear wheels.
	cart.center_of_mass = Vector3(0.0, -0.44, -0.18)
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