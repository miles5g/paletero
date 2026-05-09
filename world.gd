extends Node3D

## PS2-era floor read: tiny albedo so pixels fight the mesh, not crisp HD tiling.
const FLOOR_ALBEDO_TEXTURE_RES: int = 256
const _PHOTO_BOOTH_SCRIPT: Script = preload("res://item_photo_booth.gd")
const _PHOTO_BOOTH_VISUAL_LAYER: int = 2
const _MAP_STRUCTURAL_LAYER: int = 1
const _PHYSICAL_ITEM_SCENE: PackedScene = preload("res://PhysicalItem.tscn")
const _CELESTIAL_CYCLE_SCRIPT: Script = preload("res://celestial_cycle.gd")
const _CLIENT_NPC_SCRIPT: Script = preload("res://client_npc.gd")
const BUILDING_BASE_SCENE: PackedScene = preload("res://Building_Base.tscn")

var _compass_bar_label: Label = null
var _compass_waypoint_label: Label = null
var _compass_caret_label: Label = null
var _money_ching_player: AudioStreamPlayer = null
var _cart_impact_player: AudioStreamPlayer = null


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
	# Structural colliders live on both 1 (legacy/world) and 2 (impact routing).
	body.collision_layer = (1 << 0) | (1 << 1)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.layers = 1 << (_MAP_STRUCTURAL_LAYER - 1)
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
	body.collision_layer = (1 << 0) | (1 << 1)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.layers = 1 << (_MAP_STRUCTURAL_LAYER - 1)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	body.add_child(mi)
	body.add_child(col)
	body.position = center_pos
	body.rotation_degrees = rot_deg
	parent.add_child(body)


func _street_corridor_half(street_half_w: float, curb_w: float, sidewalk_w: float) -> Dictionary:
	var inner := street_half_w + curb_w * 0.5
	var walk_center := inner + curb_w * 0.5 + sidewalk_w * 0.5
	var corridor_half := walk_center + sidewalk_w * 0.5
	return {"inner": inner, "walk_center": walk_center, "corridor_half": corridor_half}


## One CSG slab (sidewalk + building pads) with a cross-shaped cutout; asphalt sits in the hole flush at y=0.
## Avoids hundreds of coplanar sidewalk tiles (Z-fight) and fixes tessellation gaps from strip builds.
func _build_town_square_plinth_and_roads(
	parent: Node3D,
	street_len: float,
	slab_h: float,
	curb_h: float,
	curb_w: float,
	inner: float,
	street_half_w: float,
	corridor_half: float,
	parcel_extent: float,
	asphalt: Material,
	curb_mat: Material,
	plinth_mat: Material
) -> void:
	var town_half := corridor_half + parcel_extent + 4.0
	var plinth_thick := 0.34
	var plinth_cy := -plinth_thick * 0.5
	var lane_hw := street_half_w
	var lane_w := lane_hw * 2.0
	var half_len := street_len * 0.5
	var arm_ns := half_len - lane_hw
	var road_cy := -slab_h * 0.5
	var curb_y := curb_h * 0.5 - 0.015

	var comb := CSGCombiner3D.new()
	comb.name = "TownSquarePlinth"
	comb.use_collision = true
	comb.collision_layer = (1 << 0) | (1 << 1)
	comb.layers = 1 << (_MAP_STRUCTURAL_LAYER - 1)
	comb.position = Vector3(0.0, plinth_cy, 0.0)
	var outer := CSGBox3D.new()
	outer.name = "PlinthOuter"
	outer.size = Vector3(town_half * 2.0, plinth_thick, town_half * 2.0)
	outer.material = plinth_mat
	var sub_ns := CSGBox3D.new()
	sub_ns.operation = CSGShape3D.OPERATION_SUBTRACTION
	sub_ns.size = Vector3(lane_w, plinth_thick + 1.2, street_len + 28.0)
	var sub_ew := CSGBox3D.new()
	sub_ew.operation = CSGShape3D.OPERATION_SUBTRACTION
	sub_ew.size = Vector3(street_len + 28.0, plinth_thick + 1.2, lane_w)
	comb.add_child(outer)
	comb.add_child(sub_ns)
	comb.add_child(sub_ew)
	parent.add_child(comb)

	_add_street_box(parent, "StreetAsphalt_IX", Vector3(lane_w, slab_h, lane_w), Vector3(0.0, road_cy, 0.0), asphalt)
	if arm_ns > 0.05:
		var z_south := -(half_len + lane_hw) * 0.5
		var z_north := (half_len + lane_hw) * 0.5
		var x_west := -(half_len + lane_hw) * 0.5
		var x_east := (half_len + lane_hw) * 0.5
		_add_street_box(parent, "StreetAsphalt_NS_S", Vector3(lane_w, slab_h, arm_ns), Vector3(0.0, road_cy, z_south), asphalt)
		_add_street_box(parent, "StreetAsphalt_NS_N", Vector3(lane_w, slab_h, arm_ns), Vector3(0.0, road_cy, z_north), asphalt)
		_add_street_box(parent, "StreetAsphalt_EW_W", Vector3(arm_ns, slab_h, lane_w), Vector3(x_west, road_cy, 0.0), asphalt)
		_add_street_box(parent, "StreetAsphalt_EW_E", Vector3(arm_ns, slab_h, lane_w), Vector3(x_east, road_cy, 0.0), asphalt)
		_add_street_box(parent, "CurbLeft_NS_S", Vector3(curb_w, curb_h, arm_ns), Vector3(-inner, curb_y, z_south), curb_mat)
		_add_street_box(parent, "CurbRight_NS_S", Vector3(curb_w, curb_h, arm_ns), Vector3(inner, curb_y, z_south), curb_mat)
		_add_street_box(parent, "CurbLeft_NS_N", Vector3(curb_w, curb_h, arm_ns), Vector3(-inner, curb_y, z_north), curb_mat)
		_add_street_box(parent, "CurbRight_NS_N", Vector3(curb_w, curb_h, arm_ns), Vector3(inner, curb_y, z_north), curb_mat)
		_add_street_box(parent, "CurbSouth_EW_W", Vector3(arm_ns, curb_h, curb_w), Vector3(x_west, curb_y, -inner), curb_mat)
		_add_street_box(parent, "CurbNorth_EW_W", Vector3(arm_ns, curb_h, curb_w), Vector3(x_west, curb_y, inner), curb_mat)
		_add_street_box(parent, "CurbSouth_EW_E", Vector3(arm_ns, curb_h, curb_w), Vector3(x_east, curb_y, -inner), curb_mat)
		_add_street_box(parent, "CurbNorth_EW_E", Vector3(arm_ns, curb_h, curb_w), Vector3(x_east, curb_y, inner), curb_mat)


func _place_building_mock(parent: Node3D, world_x: float, world_z: float, yaw_deg: float) -> void:
	var inst := BUILDING_BASE_SCENE.instantiate()
	if inst == null:
		return
	inst.name = "Building_%d_%d" % [int(world_x * 10.0), int(world_z * 10.0)]
	inst.position = Vector3(world_x, 0.0, world_z)
	inst.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	parent.add_child(inst)


## Roads first (+ intersection), then outward: sidewalk corridor, parcel slabs, bone-cube buildings.
func _build_street_layout(root: Node3D) -> void:
	var street_root := Node3D.new()
	street_root.name = "Street"
	root.add_child(street_root)
	var buildings_root := Node3D.new()
	buildings_root.name = "CityBlockBuildings"
	root.add_child(buildings_root)

	var tex_asphalt := _make_floor_grit_texture(0xA511A1)
	var tex_walk := _make_floor_grit_texture(0x51DEA1)
	var tex_curb := _make_floor_grit_texture(0xC0B4E)
	var asphalt := _make_wet_asphalt_material(tex_asphalt, Vector3(52, 52, 52))
	var concrete := _make_dark_concrete_material(tex_walk, Vector3(34, 34, 34))
	var curb_mat := _make_curb_material(tex_curb, Vector3(10, 6, 120))

	# Enlarged corridor vs original strip; arms span entire mock block.
	var street_half_w := 6.5
	var curb_w := 0.22
	var curb_h := 0.16
	var sidewalk_w := 11.0
	var slab_h := 0.22

	var co := _street_corridor_half(street_half_w, curb_w, sidewalk_w)
	var inner: float = co["inner"]
	var corridor_half: float = co["corridor_half"]

	var street_len := 132.0
	var parcel_extent := 44.0

	_build_town_square_plinth_and_roads(
		street_root,
		street_len,
		slab_h,
		curb_h,
		curb_w,
		inner,
		street_half_w,
		corridor_half,
		parcel_extent,
		asphalt,
		curb_mat,
		concrete
	)

	# Bone-block mock buildings (simple CSG cubes from Building_Base.tscn).
	var inset := 9.0
	var d1 := 7.0
	var d2 := 15.0
	_place_building_mock(buildings_root, corridor_half + inset, corridor_half + d1, 0.0)
	_place_building_mock(buildings_root, corridor_half + d2, corridor_half + inset, 90.0)
	_place_building_mock(buildings_root, -(corridor_half + inset), corridor_half + d1, 0.0)
	_place_building_mock(buildings_root, -(corridor_half + d2), corridor_half + inset, -90.0)
	_place_building_mock(buildings_root, corridor_half + d1, -(corridor_half + inset), 180.0)
	_place_building_mock(buildings_root, corridor_half + d2, -(corridor_half + inset), 90.0)
	_place_building_mock(buildings_root, -(corridor_half + d1), -(corridor_half + inset), 180.0)
	_place_building_mock(buildings_root, -(corridor_half + d2), -(corridor_half + inset), -90.0)

	_add_street_ramp(
		street_root,
		"KickRamp",
		Vector3(3.6, 0.6, 5.0),
		Vector3(0.0, 0.06, -14.0),
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


func _heading_degrees_from_player(player: CharacterBody3D) -> float:
	if player == null:
		return 0.0
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	var fwd := -player.global_transform.basis.z
	if cam != null:
		fwd = -cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 1e-6:
		return 0.0
	fwd = fwd.normalized()
	# 0 deg = North (-Z), clockwise positive.
	return fposmod(rad_to_deg(atan2(fwd.x, -fwd.z)), 360.0)


func _compass_bar_text(heading_deg: float) -> String:
	var width := 41
	var center := int(width / 2.0)
	var chars := PackedStringArray()
	for _i in range(width):
		chars.append(" ")
	# 90 degrees span across the bar; center is camera forward.
	for dir_idx in range(8):
		var dir_deg := float(dir_idx) * 45.0
		var rel := fposmod(dir_deg - heading_deg + 180.0, 360.0) - 180.0
		if absf(rel) > 95.0:
			continue
		var x := center + int(round((rel / 90.0) * float(center - 1)))
		var label: String = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][dir_idx]
		if label.length() == 1:
			if x >= 0 and x < width:
				chars[x] = label
		else:
			var left := x - 1
			if left >= 0 and left < width:
				chars[left] = label.substr(0, 1)
			if left + 1 >= 0 and left + 1 < width:
				chars[left + 1] = label.substr(1, 1)
	var line := ""
	for i in range(width):
		line += chars[i]
	return line


func _relative_waypoint_degrees(player: CharacterBody3D) -> Dictionary:
	var beam := get_node_or_null("MapWaypointBeam") as Node3D
	if player == null or beam == null:
		return {"has": false, "rel_deg": 0.0}
	var to_waypoint := beam.global_position - player.global_position
	to_waypoint.y = 0.0
	if to_waypoint.length_squared() < 1e-6:
		return {"has": false, "rel_deg": 0.0}
	to_waypoint = to_waypoint.normalized()
	var waypoint_heading := fposmod(rad_to_deg(atan2(to_waypoint.x, -to_waypoint.z)), 360.0)
	var player_heading := _heading_degrees_from_player(player)
	var rel := fposmod(waypoint_heading - player_heading + 180.0, 360.0) - 180.0
	return {"has": true, "rel_deg": rel}


func _compass_marker_line(width: int, rel_deg: float, marker: String) -> String:
	if width <= 0:
		return ""
	var out := ""
	for _i in range(width):
		out += " "
	var center := int(width / 2.0)
	var x := center + int(round((rel_deg / 90.0) * float(center - 1)))
	x = clampi(x, 0, width - 1)
	return out.substr(0, x) + marker + out.substr(x + 1)


func _update_compass_hud() -> void:
	if _compass_bar_label == null:
		return
	var player := get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return
	var heading_deg := _heading_degrees_from_player(player)
	if _compass_bar_label != null:
		var line := _compass_bar_text(heading_deg)
		var waypoint := _relative_waypoint_degrees(player)
		var waypoint_line := ""
		if bool(waypoint["has"]):
			var rel_deg: float = waypoint["rel_deg"]
			if absf(rel_deg) <= 95.0:
				waypoint_line = _compass_marker_line(line.length(), rel_deg, "X")
		_compass_bar_label.text = line
		if _compass_waypoint_label != null:
			_compass_waypoint_label.text = waypoint_line


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
	set_process(true)
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	# Keep gameplay/inventory UI above auxiliary overlays like the sun-dial wait HUD.
	hud.layer = 20

	var prompt_box := VBoxContainer.new()
	prompt_box.name = "InteractionPrompts"
	prompt_box.visible = false
	prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_box.anchor_left = 0.0
	prompt_box.anchor_right = 1.0
	prompt_box.anchor_top = 1.0
	prompt_box.anchor_bottom = 1.0
	# Keep interaction prompts above bottom compass strip.
	prompt_box.offset_top = -118.0
	prompt_box.offset_bottom = -58.0
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

	var minimap_hud := preload("res://minimap_hud.gd").new()
	hud.add_child(minimap_hud)

	var inv_menu: Node = load("res://MasterHUD.tscn").instantiate()
	if inv_menu is Control:
		var inv_ctrl := inv_menu as Control
		# Hand slots use z_index 40; keep inventory popup definitively above them.
		inv_ctrl.z_index = 120
	hud.add_child(inv_menu)
	var term_inv_font := _make_terminal_font()
	_apply_terminal_theme_to_node(inv_menu, term_inv_font, 13)

	var term_ui_font := _make_terminal_font()
	_apply_terminal_theme_to_node(prompt_box, term_ui_font, 14)

	var compass_bar := Label.new()
	compass_bar.name = "CompassBar"
	compass_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass_bar.anchor_left = 0.5
	compass_bar.anchor_right = 0.5
	compass_bar.anchor_top = 1.0
	compass_bar.anchor_bottom = 1.0
	compass_bar.offset_left = -170.0
	compass_bar.offset_top = -36.0
	compass_bar.offset_right = 170.0
	compass_bar.offset_bottom = -8.0
	compass_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass_bar.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	compass_bar.add_theme_font_override("font", term_ui_font)
	compass_bar.add_theme_font_size_override("font_size", 12)
	compass_bar.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	hud.add_child(compass_bar)
	_compass_bar_label = compass_bar

	var compass_waypoint := Label.new()
	compass_waypoint.name = "CompassWaypoint"
	compass_waypoint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass_waypoint.anchor_left = 0.5
	compass_waypoint.anchor_right = 0.5
	compass_waypoint.anchor_top = 1.0
	compass_waypoint.anchor_bottom = 1.0
	compass_waypoint.offset_left = -170.0
	compass_waypoint.offset_top = -36.0
	compass_waypoint.offset_right = 170.0
	compass_waypoint.offset_bottom = -8.0
	compass_waypoint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass_waypoint.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	compass_waypoint.add_theme_font_override("font", term_ui_font)
	compass_waypoint.add_theme_font_size_override("font_size", 12)
	compass_waypoint.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 0.95))
	hud.add_child(compass_waypoint)
	_compass_waypoint_label = compass_waypoint

	var compass_caret := Label.new()
	compass_caret.name = "CompassCaret"
	compass_caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass_caret.anchor_left = 0.5
	compass_caret.anchor_right = 0.5
	compass_caret.anchor_top = 1.0
	compass_caret.anchor_bottom = 1.0
	compass_caret.offset_left = -8.0
	compass_caret.offset_top = -24.0
	compass_caret.offset_right = 8.0
	compass_caret.offset_bottom = -6.0
	compass_caret.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass_caret.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	compass_caret.text = "^"
	compass_caret.add_theme_font_override("font", term_ui_font)
	compass_caret.add_theme_font_size_override("font_size", 12)
	compass_caret.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	hud.add_child(compass_caret)
	_compass_caret_label = compass_caret

	add_child(hud)
	_setup_money_ching_audio()
	_setup_cart_impact_audio()

	# Base world environment values; celestial controller animates these over time.
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.19, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.25, 0.24)
	env.ambient_light_energy = 1.1
	env.fog_enabled = false
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
	# Collide with both gameplay/default (1) and structural (2) layers.
	cart.collision_layer = 1
	cart.collision_mask = (1 << 0) | (1 << 1)
	cart.linear_damp = 2.6
	cart.gravity_scale = 1.0
	# Weighted-sled: heavy rotational resistance so it won't spin like a toy.
	cart.angular_damp = 9.5
	cart.physics_material_override = PhysicsMaterial.new()
	cart.physics_material_override.friction = 0.18
	cart.physics_material_override.bounce = 0.08
	cart.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	# Weighted-sled anchor: center of mass significantly below floor/axle zone.
	cart.center_of_mass = Vector3(0.0, -0.72, -0.2)
	cart.set_script(load("res://cart.gd"))
	cart.position = Vector3(0, 1, -5) # 5 meters in front of center
	
	var cart_mesh = MeshInstance3D.new()
	cart_mesh.mesh = BoxMesh.new()
	cart_mesh.mesh.size = Vector3(1, 1, 1.5)
	cart_mesh.position.y = 0.16
	# Map camera excludes actor layer; cart is represented by 2D marker overlay.
	cart_mesh.layers = 1 << (3 - 1)
	
	var cart_col = CollisionShape3D.new()
	cart_col.shape = BoxShape3D.new()
	# Smaller + raised hull = better curb/speed-bump clearance without changing visible cart size.
	cart_col.shape.size = Vector3(1, 0.72, 1.5)
	cart_col.position.y = 0.24
	# Front ramp collider: steeper and slightly taller to improve head-on curb climbing.
	# This acts like a broad caster assembly that converts forward impact into lift.
	var front_bump_col = CollisionShape3D.new()
	front_bump_col.shape = BoxShape3D.new()
	front_bump_col.shape.size = Vector3(0.9, 0.24, 0.4)
	front_bump_col.position = Vector3(0.0, 0.09, -0.78)
	front_bump_col.rotation.x = deg_to_rad(36.0)
	# Two rounded front contacts mimic left/right front wheel behavior for head-on obstacles.
	# Spheres reduce edge snagging versus a single flat face, especially at curb corners.
	var front_wheel_l = CollisionShape3D.new()
	front_wheel_l.shape = SphereShape3D.new()
	front_wheel_l.shape.radius = 0.175
	front_wheel_l.position = Vector3(-0.31, 0.1, -0.8)
	var front_wheel_r = CollisionShape3D.new()
	front_wheel_r.shape = SphereShape3D.new()
	front_wheel_r.shape.radius = 0.175
	front_wheel_r.position = Vector3(0.31, 0.1, -0.8)
	
	cart.add_child(cart_mesh)
	cart.add_child(cart_col)
	cart.add_child(front_bump_col)
	cart.add_child(front_wheel_l)
	cart.add_child(front_wheel_r)
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
	# 5. Spawn one customer for early transaction gameplay.
	_spawn_client_npc()
	_spawn_initial_floor_items(player)


func _process(_delta: float) -> void:
	_update_compass_hud()


func _setup_money_ching_audio() -> void:
	var ap := AudioStreamPlayer.new()
	ap.name = "MoneyChingPlayer"
	ap.stream = _build_money_ching_stream()
	ap.volume_db = -10.0
	ap.bus = &"Master"
	add_child(ap)
	_money_ching_player = ap


func _setup_cart_impact_audio() -> void:
	var ap := AudioStreamPlayer.new()
	ap.name = "CartImpactPlayer"
	ap.stream = _build_cart_impact_stream()
	ap.volume_db = -9.0
	ap.bus = &"Master"
	add_child(ap)
	_cart_impact_player = ap


func _build_cart_impact_stream() -> AudioStreamWAV:
	# Short heavy "thud": low-mid burst with fast decay.
	var rate := 22050
	var seconds := 0.18
	var n := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	var tau := PI * 2.0
	for i in range(n):
		var t := float(i) / float(rate)
		var env := exp(-t * 18.0)
		var s := (
			0.78 * sin(t * tau * 120.0)
			+ 0.26 * sin(t * tau * 210.0)
			+ 0.12 * sin(t * tau * 470.0)
		)
		var sample := int(clampf(s * env * 7000.0, -32767.0, 32767.0))
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


func play_cart_impact_feedback(speed: float) -> void:
	if _cart_impact_player == null or not is_instance_valid(_cart_impact_player):
		return
	var w := clampf((speed - 5.0) / 8.0, 0.0, 1.0)
	_cart_impact_player.pitch_scale = lerpf(0.86, 1.02, w)
	_cart_impact_player.volume_db = lerpf(-13.0, -6.0, w)
	_cart_impact_player.play()


func _build_money_ching_stream() -> AudioStreamWAV:
	# Short synthetic “register ding” — no external .wav needed (PS2-ish, bright partials + fast decay).
	var rate := 22050
	var seconds := 0.22
	var n := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	var tau := PI * 2.0
	for i in range(n):
		var t := float(i) / float(rate)
		var env := exp(-t * 12.0)
		var s := (
			0.42 * sin(t * tau * 2650.0)
			+ 0.38 * sin(t * tau * 3950.0)
			+ 0.12 * sin(t * tau * 880.0)
		)
		var sample := int(clampf(s * env * 2800.0, -32767.0, 32767.0))
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


func _play_money_ching(delta_usd: float) -> void:
	if _money_ching_player == null or not is_instance_valid(_money_ching_player):
		return
	if absf(delta_usd) < 0.0005:
		return
	if delta_usd >= 0.0:
		_money_ching_player.pitch_scale = 1.0
		_money_ching_player.volume_db = -10.0
	else:
		_money_ching_player.pitch_scale = 0.78
		_money_ching_player.volume_db = -14.0
	_money_ching_player.play()


func show_money_popup(delta_usd: float) -> void:
	_play_money_ching(delta_usd)
	var cycle := get_node_or_null("CelestialCycle") as Node
	if cycle != null and cycle.has_method("show_money_popup"):
		cycle.call("show_money_popup", delta_usd)

func _spawn_player() -> CharacterBody3D:
	var player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1, 0)
	player.collision_layer = 1
	# Include structural layer so sidewalks/roads still collide after Layer-2 move.
	player.collision_mask = (1 << 0) | (1 << 1)
	
	# Give the player a script (we will create this file next)
	player.set_script(load("res://player.gd"))
	
	var p_mesh = MeshInstance3D.new()
	p_mesh.mesh = CapsuleMesh.new()
	# Keep player hidden from structural top-down map render.
	p_mesh.layers = 1 << (3 - 1)
	
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


func _spawn_client_npc() -> void:
	var client := StaticBody3D.new()
	client.name = "ClientNPC"
	client.set_script(_CLIENT_NPC_SCRIPT)
	client.position = Vector3(5.5, 1.0, -3.4)
	var mesh := MeshInstance3D.new()
	mesh.mesh = CapsuleMesh.new()
	mesh.layers = 1 << (3 - 1)
	var col := CollisionShape3D.new()
	col.shape = CapsuleShape3D.new()
	(mesh.mesh as CapsuleMesh).radius = 0.42
	(mesh.mesh as CapsuleMesh).height = 1.15
	(col.shape as CapsuleShape3D).radius = 0.42
	(col.shape as CapsuleShape3D).height = 1.15
	client.add_child(mesh)
	client.add_child(col)
	add_child(client)


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