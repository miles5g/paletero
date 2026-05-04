extends Node3D

## PS2-era floor read: tiny albedo so pixels fight the mesh, not crisp HD tiling.
const FLOOR_ALBEDO_TEXTURE_RES: int = 256


func _make_floor_grit_texture(noise_seed: int) -> ImageTexture:
	var img := Image.create(FLOOR_ALBEDO_TEXTURE_RES, FLOOR_ALBEDO_TEXTURE_RES, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.52
	noise.frequency = 0.055
	for y in range(FLOOR_ALBEDO_TEXTURE_RES):
		for x in range(FLOOR_ALBEDO_TEXTURE_RES):
			var xf := float(x)
			var yf := float(y)
			var n := noise.get_noise_2d(xf, yf)
			var n2 := noise.get_noise_2d(xf * 2.4 + 19.0, yf * 2.4 - 7.0)
			var n3 := noise.get_noise_2d(xf * 0.31 + 3.0, yf * 0.31 + 11.0)
			var v := 0.38 + n * 0.22 + n2 * 0.14 + n3 * 0.08
			v = clampf(v, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v * 1.02, 1.0))
	var tex := ImageTexture.new()
	tex.set_image(img)
	return tex


func _apply_floor_texture_rules(m: StandardMaterial3D, albedo_tex: Texture2D, uv_scale: Vector3) -> void:
	m.albedo_texture = albedo_tex
	m.uv1_scale = uv_scale
	# No mip sampling + chunky texels (Godot 4 has no texture_mipmap_mode on BaseMaterial3D).
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


func _make_wet_asphalt_material(albedo_tex: Texture2D, uv_scale: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.21, 0.26)
	_apply_floor_texture_rules(m, albedo_tex, uv_scale)
	m.roughness = 0.1
	m.metallic = 0.0
	m.specular = 1.0
	return m


func _make_dark_concrete_material(albedo_tex: Texture2D, uv_scale: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.28, 0.28, 0.29)
	_apply_floor_texture_rules(m, albedo_tex, uv_scale)
	m.roughness = 0.92
	m.metallic = 0.0
	m.specular = 0.32
	return m


func _make_curb_material(albedo_tex: Texture2D, uv_scale: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.24, 0.24, 0.26)
	_apply_floor_texture_rules(m, albedo_tex, uv_scale)
	m.roughness = 0.88
	m.metallic = 0.0
	m.specular = 0.28
	return m


func _add_street_box(parent: Node3D, p_name: String, size: Vector3, center_pos: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = p_name
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	body.add_child(mi)
	body.add_child(col)
	body.position = center_pos
	parent.add_child(body)


## Long strip along Z: sidewalks + curbs + wet asphalt lane (player/cart stay near center).
func _build_street_layout(root: Node3D) -> void:
	var street_root := Node3D.new()
	street_root.name = "Street"
	root.add_child(street_root)
	var tex_asphalt := _make_floor_grit_texture(0xA511A1)
	var tex_walk := _make_floor_grit_texture(0x51DEA1)
	var tex_curb := _make_floor_grit_texture(0xC0B4E)
	# Tile the 256² maps so long boxes still show chunky texels (nearest filter).
	var asphalt := _make_wet_asphalt_material(tex_asphalt, Vector3(52, 52, 52))
	var concrete := _make_dark_concrete_material(tex_walk, Vector3(34, 34, 34))
	var curb_mat := _make_curb_material(tex_curb, Vector3(10, 6, 120))
	var street_len := 100.0
	var street_half_w := 4.0
	var curb_w := 0.22
	var curb_h := 0.16
	var sidewalk_w := 6.0
	var slab_h := 0.2
	# Top of flat surfaces at y = 0 (same as old ground feel).
	var slab_y := -slab_h * 0.5
	var z0 := 0.0
	# Road
	_add_street_box(
		street_root,
		"StreetAsphalt",
		Vector3(street_half_w * 2.0, slab_h, street_len),
		Vector3(0.0, slab_y, z0),
		asphalt
	)
	var inner := street_half_w + curb_w * 0.5
	# Left curb (thin, long; slight lip above slab read).
	_add_street_box(
		street_root,
		"CurbLeft",
		Vector3(curb_w, curb_h, street_len),
		Vector3(-inner, curb_h * 0.5 - 0.02, z0),
		curb_mat
	)
	_add_street_box(
		street_root,
		"CurbRight",
		Vector3(curb_w, curb_h, street_len),
		Vector3(inner, curb_h * 0.5 - 0.02, z0),
		curb_mat
	)
	var walk_center_x := inner + curb_w * 0.5 + sidewalk_w * 0.5
	_add_street_box(
		street_root,
		"SidewalkLeft",
		Vector3(sidewalk_w, slab_h, street_len),
		Vector3(-walk_center_x, slab_y, z0),
		concrete
	)
	_add_street_box(
		street_root,
		"SidewalkRight",
		Vector3(sidewalk_w, slab_h, street_len),
		Vector3(walk_center_x, slab_y, z0),
		concrete
	)


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
	# Faint bloom so bright UI / spec hits read PS2-era against the dark grade.
	env.glow_enabled = true
	env.glow_intensity = 0.28
	env.glow_strength = 0.85
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.78
	env.glow_hdr_scale = 0.88
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
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

	# 2. Street layout: asphalt lane + curbs + sidewalk slabs (procedural StaticBodies).
	_build_street_layout(self)

	# 3. Spawn the Cart (RigidBody3D)
	var cart = RigidBody3D.new()
	cart.name = "Cart"
	cart.mass = 12.0
	cart.linear_damp = 0.3
	cart.gravity_scale = 0.72
	# Lighter cart: less angular drag so it feels a bit floatier while still settling.
	cart.angular_damp = 4.8
	cart.physics_material_override = PhysicsMaterial.new()
	cart.physics_material_override.friction = 0.18
	cart.physics_material_override.bounce = 0.08
	cart.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	# Box is 1m tall centered at origin: put mass well below center, slightly toward the rear wheels.
	cart.center_of_mass = Vector3(0.0, -0.44, -0.18)
	cart.set_script(load("res://cart.gd"))
	cart.position = Vector3(0, 1, -5) # 5 meters in front of center
	
	var cart_mesh = MeshInstance3D.new()
	cart_mesh.mesh = BoxMesh.new()
	cart_mesh.mesh.size = Vector3(1, 1, 1.5)
	cart_mesh.position.y = 0.16
	
	var cart_col = CollisionShape3D.new()
	cart_col.shape = BoxShape3D.new()
	# Smaller + raised hull = better curb/speed-bump clearance without changing visible cart size.
	cart_col.shape.size = Vector3(1, 0.72, 1.5)
	cart_col.position.y = 0.24
	# Front ramp collider: acts like chunky front tires for head-on curb climbing.
	var front_bump_col = CollisionShape3D.new()
	front_bump_col.shape = BoxShape3D.new()
	front_bump_col.shape.size = Vector3(0.86, 0.18, 0.34)
	front_bump_col.position = Vector3(0.0, 0.05, -0.74)
	front_bump_col.rotation.x = deg_to_rad(28.0)
	
	cart.add_child(cart_mesh)
	cart.add_child(cart_col)
	cart.add_child(front_bump_col)
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