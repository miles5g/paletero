extends Node3D

## PS2-era floor read: tiny albedo so pixels fight the mesh, not crisp HD tiling.
const FLOOR_ALBEDO_TEXTURE_RES: int = 256
const _PHOTO_BOOTH_SCRIPT: Script = preload("res://item_photo_booth.gd")
const _PHOTO_BOOTH_VISUAL_LAYER: int = 2
const _PHYSICAL_ITEM_SCENE: PackedScene = preload("res://PhysicalItem.tscn")
const _CELESTIAL_CYCLE_SCRIPT: Script = preload("res://celestial_cycle.gd")

var _scanline_overlay: ColorRect = null


func _slot_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color.WHITE
	return sb


func _make_dim_slot_placeholder() -> Texture2D:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.2, 0.22, 0.2))
	for i in range(24):
		img.set_pixel(i, 0, Color(0.8, 0.8, 0.86, 0.22))
		img.set_pixel(i, 23, Color(0.8, 0.8, 0.86, 0.22))
		img.set_pixel(0, i, Color(0.8, 0.8, 0.86, 0.22))
		img.set_pixel(23, i, Color(0.8, 0.8, 0.86, 0.22))
	var tex := ImageTexture.new()
	tex.set_image(img)
	return tex


func _make_hand_slot(
	slot_name: String,
	hand_mark: String,
	mark_on_left: bool,
	font: Font
) -> Panel:
	var slot := Panel.new()
	slot.name = slot_name
	slot.custom_minimum_size = Vector2(72, 72)
	slot.size = Vector2(72, 72)
	slot.clip_contents = true
	slot.z_index = 20
	slot.add_theme_stylebox_override("panel", _slot_stylebox())
	var booth := _PHOTO_BOOTH_SCRIPT.new() as SubViewportContainer
	booth.name = "Booth"
	booth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	booth.z_index = 21
	booth.anchor_left = 0.0
	booth.anchor_top = 0.0
	booth.anchor_right = 1.0
	booth.anchor_bottom = 1.0
	# Inner frame: centered and fully contained inside white border.
	booth.offset_left = 8.0
	booth.offset_top = 14.0
	booth.offset_right = -8.0
	booth.offset_bottom = -8.0
	booth.modulate = Color(1.0, 1.0, 1.0, 0.92)
	var empty_mark := Label.new()
	empty_mark.name = "EmptyMark"
	empty_mark.text = "EMPTY"
	empty_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty_mark.add_theme_font_override("font", font)
	empty_mark.add_theme_font_size_override("font_size", 9)
	empty_mark.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.24))
	empty_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_mark.anchor_left = 0.0
	empty_mark.anchor_top = 0.0
	empty_mark.anchor_right = 1.0
	empty_mark.anchor_bottom = 1.0
	empty_mark.offset_left = 8.0
	empty_mark.offset_top = 20.0
	empty_mark.offset_right = -8.0
	empty_mark.offset_bottom = -8.0
	var mark := Label.new()
	mark.name = "HandMark"
	mark.text = hand_mark
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_theme_font_override("font", font)
	mark.add_theme_font_size_override("font_size", 12)
	mark.add_theme_color_override("font_color", Color.WHITE)
	mark.anchor_left = 0.0
	mark.anchor_top = 0.0
	mark.anchor_right = 0.0
	mark.anchor_bottom = 0.0
	mark.size = Vector2(12.0, 12.0)
	mark.offset_top = 3.0
	if mark_on_left:
		mark.offset_left = 7.0
	else:
		mark.offset_left = 53.0
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	slot.add_child(booth)
	slot.add_child(empty_mark)
	slot.add_child(mark)
	return slot


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
	return m


func _make_dark_concrete_material(albedo_tex: Texture2D, uv_scale: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.28, 0.28, 0.29)
	_apply_floor_texture_rules(m, albedo_tex, uv_scale)
	m.roughness = 0.92
	m.metallic = 0.0
	return m


func _make_curb_material(albedo_tex: Texture2D, uv_scale: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.24, 0.24, 0.26)
	_apply_floor_texture_rules(m, albedo_tex, uv_scale)
	m.roughness = 0.88
	m.metallic = 0.0
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


func _add_street_ramp(
	parent: Node3D,
	p_name: String,
	size: Vector3,
	center_pos: Vector3,
	rot_deg: Vector3,
	mat: Material
) -> void:
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
	body.rotation_degrees = rot_deg
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
	# Gentle kick ramp in-lane, close to player spawn so it’s easy to see and hit.
	_add_street_ramp(
		street_root,
		"KickRamp",
		Vector3(3.6, 0.6, 5.0),
		Vector3(0.0, 0.0, -14.0),
		Vector3(-18.0, 180.0, 0.0),
		asphalt
	)


func _make_terminal_font() -> Font:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Consolas", "Courier New", "Courier", "monospace"])
	sys.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var fv := FontVariation.new()
	fv.base_font = sys
	return fv


func _apply_terminal_theme_to_node(node: Node, font: Font, font_size: int) -> void:
	if node is Label:
		var lab := node as Label
		lab.add_theme_font_override("font", font)
		lab.add_theme_font_size_override("font_size", font_size)
		lab.add_theme_color_override("font_color", Color.WHITE)
	elif node is RichTextLabel:
		var rt := node as RichTextLabel
		rt.add_theme_font_override("normal_font", font)
		rt.add_theme_font_override("bold_font", font)
		rt.add_theme_font_size_override("normal_font_size", font_size)
		rt.add_theme_font_size_override("bold_font_size", font_size)
		rt.add_theme_color_override("default_color", Color.WHITE)
	elif node is Button:
		var b := node as Button
		b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", font_size)
		b.add_theme_color_override("font_color", Color.WHITE)
	for c in node.get_children():
		_apply_terminal_theme_to_node(c, font, font_size)


func _update_scanline_display_height() -> void:
	if _scanline_overlay == null:
		return
	var sm := _scanline_overlay.material as ShaderMaterial
	if sm:
		sm.set_shader_parameter("display_height", get_viewport().get_visible_rect().size.y)


func set_grab_prompts_visible(v: bool) -> void:
	var box := get_node_or_null("HUD/InteractionPrompts") as Control
	if box == null:
		return
	box.visible = v
	for c in box.get_children():
		if c is Control:
			(c as Control).visible = v


func set_interaction_prompt_text(msg: String) -> void:
	var lab := get_node_or_null("HUD/InteractionPrompts/InteractionLabel") as Label
	if lab == null:
		return
	lab.text = msg


func _ready() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"

	var prompt_box := VBoxContainer.new()
	prompt_box.name = "InteractionPrompts"
	prompt_box.visible = false
	prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_box.anchor_left = 0.0
	prompt_box.anchor_right = 1.0
	prompt_box.anchor_top = 1.0
	prompt_box.anchor_bottom = 1.0
	prompt_box.offset_top = -72.0
	prompt_box.offset_bottom = -12.0
	prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER

	var inventory_prompt := Label.new()
	inventory_prompt.name = "InventoryPromptLabel"
	inventory_prompt.text = "[Tab] Inventory"
	inventory_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var interaction_label := Label.new()
	interaction_label.name = "InteractionLabel"
	interaction_label.text = "[E] Grab Cart"
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	prompt_box.add_child(inventory_prompt)
	prompt_box.add_child(interaction_label)
	hud.add_child(prompt_box)

	var hand_slots := Control.new()
	hand_slots.name = "HandSlots"
	hand_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_slots.z_index = 40
	hand_slots.anchor_left = 0.0
	hand_slots.anchor_right = 0.0
	hand_slots.anchor_top = 1.0
	hand_slots.anchor_bottom = 1.0
	hand_slots.offset_left = 24.0
	hand_slots.offset_top = -138.0
	hand_slots.offset_right = 210.0
	hand_slots.offset_bottom = -18.0
	var term_hand_font := _make_terminal_font()
	var left_slot := _make_hand_slot("LeftHandSlot", "L", false, term_hand_font)
	var right_slot := _make_hand_slot("RightHandSlot", "R", true, term_hand_font)
	# Keep a clear gap so 2px borders never touch/overlap.
	left_slot.position = Vector2(8.0, 16.0)
	right_slot.position = Vector2(88.0, 16.0)
	hand_slots.add_child(left_slot)
	hand_slots.add_child(right_slot)
	hud.add_child(hand_slots)

	var inv_menu: Node = load("res://MasterHUD.tscn").instantiate()
	hud.add_child(inv_menu)
	var term_inv_font := _make_terminal_font()
	_apply_terminal_theme_to_node(inv_menu, term_inv_font, 13)

	var scan := ColorRect.new()
	scan.name = "ScanlineOverlay"
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scan.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://hud_scanlines.gdshader")
	sm.set_shader_parameter("line_spacing", 4.0)
	sm.set_shader_parameter("line_opacity", 0.1)
	scan.material = sm
	hud.add_child(scan)
	_scanline_overlay = scan
	call_deferred("_update_scanline_display_height")
	if not get_viewport().size_changed.is_connected(_update_scanline_display_height):
		get_viewport().size_changed.connect(_update_scanline_display_height)

	var term_ui_font := _make_terminal_font()
	_apply_terminal_theme_to_node(prompt_box, term_ui_font, 14)

	add_child(hud)

	# Base world environment values; celestial controller animates these over time.
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.19, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.25, 0.24)
	env.ambient_light_energy = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.36, 0.33, 0.31)
	env.fog_density = 0.052
	env.fog_sky_affect = 1.0
	env.fog_aerial_perspective = 0.6
	# Faint bloom so bright UI / spec hits read PS2-era against the dark grade.
	env.glow_enabled = true
	env.glow_intensity = 0.38
	env.glow_strength = 0.92
	env.glow_bloom = 0.2
	env.glow_hdr_threshold = 0.72
	env.glow_hdr_scale = 0.88
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	world_env.environment = env
	add_child(world_env)
	# 1. Create celestial world-clock: 30 min full orbit, synced sun + environment gradient.
	var celestial_cycle: CelestialCycle = _CELESTIAL_CYCLE_SCRIPT.new() as CelestialCycle
	celestial_cycle.name = "CelestialCycle"
	add_child(celestial_cycle)
	celestial_cycle.setup(world_env)

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

	var inv_panel := get_node_or_null("HUD/InventoryMenu") as Panel
	if inv_panel != null and inv_panel.has_method("bind_cart"):
		inv_panel.bind_cart(cart)

	# 4. Spawn the Player
	var player := _spawn_player()
	_spawn_initial_floor_items(player)

func _spawn_player() -> CharacterBody3D:
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
	# Visual firewall: gameplay camera ignores booth-only layer.
	cam.cull_mask = cam.cull_mask & ~(1 << (_PHOTO_BOOTH_VISUAL_LAYER - 1))
	
	player.add_child(p_mesh)
	player.add_child(p_col)
	player.add_child(cam)
	add_child(player)
	return player


func _spawn_initial_floor_items(player: CharacterBody3D) -> void:
	if player == null:
		return
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 1e-6:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var right := player.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 1e-6:
		right = Vector3.RIGHT
	right = right.normalized()

	var item_a := ItemResource.new()
	item_a.item_name = "Lime Paleta"
	item_a.quantity = 1
	item_a.weight_lbs = 1.0
	item_a.value_usd = 1.50
	item_a.description = "Tart lime frozen fruit bar."
	item_a.rarity = ItemResource.Rarity.GREEN
	item_a.category = ItemResource.Category.FOOD
	item_a.hand_model = ItemResource.HandModel.SPHERE

	var item_b := ItemResource.new()
	item_b.item_name = "Secret Recipe"
	item_b.quantity = 1
	item_b.weight_lbs = 0.1
	item_b.value_usd = 500.00
	item_b.description = "A handwritten note with the perfect flavor ratios. Priceless."
	item_b.rarity = ItemResource.Rarity.GOLD
	item_b.category = ItemResource.Category.UTILITY
	item_b.hand_model = ItemResource.HandModel.SCROLL

	var spawn_a := _PHYSICAL_ITEM_SCENE.instantiate() as PhysicalItem
	var spawn_b := _PHYSICAL_ITEM_SCENE.instantiate() as PhysicalItem
	if spawn_a == null or spawn_b == null:
		return
	spawn_a.set_item_resource(item_a)
	spawn_b.set_item_resource(item_b)
	add_child(spawn_a)
	add_child(spawn_b)
	# Place two pickups on floor in front of player.
	var base := player.global_position + fwd * 2.1 + Vector3.UP * 0.24
	spawn_a.global_position = base + right * -0.28
	spawn_b.global_position = base + right * 0.28