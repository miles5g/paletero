extends Control
## Corner minimap: same technical map pipeline as inventory MAP (isolated viewport, proxy geometry, edge shader, markers).

const MAP_VIEWPORT_SIZE: Vector2i = Vector2i(160, 160)
const MAP_WORLD_MIN_X: float = -72.0
const MAP_WORLD_MAX_X: float = 72.0
const MAP_WORLD_MIN_Z: float = -72.0
const MAP_WORLD_MAX_Z: float = 72.0
const MAP_STRUCTURAL_LAYER: int = 1
const MAP_STREET_LEN: float = 132.0
const MAP_STREET_HALF_W: float = 6.5
const MAP_CURB_W: float = 0.22
const MAP_CURB_H: float = 0.16
const MAP_SIDEWALK_W: float = 11.0
const MAP_SLAB_H: float = 0.22

var _map_view: SubViewportContainer = null
var _map_viewport: SubViewport = null
var _map_camera: Camera3D = null
var _map_overlay: Control = null
var _map_player_marker: Polygon2D = null
var _map_cart_marker: Label = null


func _ready() -> void:
	name = "MinimapHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 38
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -172.0
	offset_top = 12.0
	offset_right = -12.0
	offset_bottom = 172.0
	custom_minimum_size = Vector2(160, 160)
	_build_minimap_view()
	set_process(true)


func _process(_delta: float) -> void:
	_update_map_markers()


func _update_map_markers() -> void:
	if _map_overlay == null or _map_player_marker == null or _map_cart_marker == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := scene.get_node_or_null("Player") as CharacterBody3D
	var cart := scene.get_node_or_null("Cart") as RigidBody3D
	var map_size := _map_overlay.size
	if map_size.x <= 1.0 or map_size.y <= 1.0:
		return
	var bounds := _map_visible_bounds()
	var min_x: float = bounds["min_x"]
	var max_x: float = bounds["max_x"]
	var min_z: float = bounds["min_z"]
	var max_z: float = bounds["max_z"]
	if player != null and is_instance_valid(player):
		var p2 := _world_to_map(player.global_position, map_size, min_x, max_x, min_z, max_z)
		_map_player_marker.position = p2
		var fwd := _player_compass_forward(player)
		_map_player_marker.rotation = _map_heading_rotation(fwd)
		_map_player_marker.visible = true
	else:
		_map_player_marker.visible = false
	if cart != null and is_instance_valid(cart):
		var c2 := _world_to_map(cart.global_position, map_size, min_x, max_x, min_z, max_z)
		_map_cart_marker.position = c2 - Vector2(5.0, 7.0)
		_map_cart_marker.visible = true
	else:
		_map_cart_marker.visible = false


func _map_visible_bounds() -> Dictionary:
	var min_x := MAP_WORLD_MIN_X
	var max_x := MAP_WORLD_MAX_X
	var min_z := MAP_WORLD_MIN_Z
	var max_z := MAP_WORLD_MAX_Z
	if _map_camera != null and _map_viewport != null:
		var half_h := _map_camera.size * 0.5
		var vp_size := _map_viewport.size
		var aspect := 1.0
		if vp_size.y > 0:
			aspect = float(vp_size.x) / float(vp_size.y)
		var half_w := half_h * aspect
		min_x = _map_camera.position.x - half_w
		max_x = _map_camera.position.x + half_w
		min_z = _map_camera.position.z - half_h
		max_z = _map_camera.position.z + half_h
	return {
		"min_x": min_x,
		"max_x": max_x,
		"min_z": min_z,
		"max_z": max_z,
	}


func _world_to_map(
	world_pos: Vector3,
	map_size: Vector2,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float
) -> Vector2:
	var nx := inverse_lerp(min_x, max_x, world_pos.x)
	var nz := inverse_lerp(min_z, max_z, world_pos.z)
	nx = clampf(nx, 0.0, 1.0)
	nz = clampf(nz, 0.0, 1.0)
	return Vector2(nx * map_size.x, nz * map_size.y)


func _player_compass_forward(player: CharacterBody3D) -> Vector3:
	if player == null:
		return Vector3(0.0, 0.0, -1.0)
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	var fwd := -player.global_transform.basis.z
	if cam != null:
		fwd = -cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 1e-6:
		return Vector3(0.0, 0.0, -1.0)
	return fwd.normalized()


func _map_heading_rotation(fwd_world: Vector3) -> float:
	var fwd := Vector3(fwd_world.x, 0.0, fwd_world.z)
	if fwd.length_squared() < 1e-6:
		return 0.0
	fwd = fwd.normalized()
	return atan2(fwd.x, -fwd.z)


func _build_minimap_view() -> void:
	_map_view = SubViewportContainer.new()
	_map_view.name = "MinimapViewportContainer"
	_map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_view.offset_left = 4.0
	_map_view.offset_top = 4.0
	_map_view.offset_right = -4.0
	_map_view.offset_bottom = -4.0
	_map_view.stretch = true
	_map_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_view.material = _map_terminal_material()
	add_child(_map_view)

	_map_viewport = SubViewport.new()
	_map_viewport.name = "MinimapViewport"
	_map_viewport.size = MAP_VIEWPORT_SIZE
	_map_viewport.disable_3d = false
	_map_viewport.transparent_bg = false
	_map_viewport.own_world_3d = true
	_map_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_map_view.add_child(_map_viewport)

	var map_world_root := Node3D.new()
	map_world_root.name = "MinimapWorldRoot"
	_map_viewport.add_child(map_world_root)
	_build_map_proxy_geometry(map_world_root)

	_map_camera = Camera3D.new()
	_map_camera.name = "MinimapTopCamera"
	_map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_map_camera.size = 120.0
	_map_camera.near = 0.1
	_map_camera.far = 500.0
	_map_camera.position = Vector3(0.0, 140.0, 0.0)
	_map_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_map_camera.cull_mask = 1 << (MAP_STRUCTURAL_LAYER - 1)
	_map_camera.current = true
	map_world_root.add_child(_map_camera)

	var map_light := DirectionalLight3D.new()
	map_light.name = "MinimapLight"
	map_light.light_energy = 2.0
	map_light.light_color = Color(0.9, 1.0, 0.9)
	map_light.shadow_enabled = false
	map_light.rotation_degrees = Vector3(-78.0, 38.0, 0.0)
	map_light.light_cull_mask = 1 << (MAP_STRUCTURAL_LAYER - 1)
	map_world_root.add_child(map_light)

	_map_overlay = Control.new()
	_map_overlay.name = "MinimapOverlay"
	_map_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map_overlay)

	_map_player_marker = Polygon2D.new()
	_map_player_marker.name = "MinimapPlayerMarker"
	_map_player_marker.polygon = PackedVector2Array([
		Vector2(0.0, -10.0),
		Vector2(7.0, 7.0),
		Vector2(2.0, 4.0),
		Vector2(0.0, 10.0),
		Vector2(-2.0, 4.0),
		Vector2(-7.0, 7.0),
	])
	_map_player_marker.color = Color.WHITE
	_map_overlay.add_child(_map_player_marker)

	_map_cart_marker = Label.new()
	_map_cart_marker.name = "MinimapCartMarker"
	_map_cart_marker.text = "■"
	_map_cart_marker.add_theme_font_size_override("font_size", 11)
	_map_cart_marker.add_theme_color_override("font_color", Color.WHITE)
	_map_cart_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_overlay.add_child(_map_cart_marker)


func _map_terminal_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\n\nuniform vec3 tint_color = vec3(0.1, 1.0, 0.45);\nuniform float edge_strength = 2.6;\nuniform float edge_threshold = 0.065;\nuniform float fill_strength = 0.08;\nuniform float glow_strength = 0.32;\n\nfloat luma(vec3 c) {\n\treturn dot(c, vec3(0.299, 0.587, 0.114));\n}\n\nvoid fragment() {\n\tvec2 texel = TEXTURE_PIXEL_SIZE;\n\tfloat tl = luma(texture(TEXTURE, UV + vec2(-texel.x, -texel.y)).rgb);\n\tfloat tc = luma(texture(TEXTURE, UV + vec2(0.0, -texel.y)).rgb);\n\tfloat tr = luma(texture(TEXTURE, UV + vec2(texel.x, -texel.y)).rgb);\n\tfloat ml = luma(texture(TEXTURE, UV + vec2(-texel.x, 0.0)).rgb);\n\tfloat mc = luma(texture(TEXTURE, UV).rgb);\n\tfloat mr = luma(texture(TEXTURE, UV + vec2(texel.x, 0.0)).rgb);\n\tfloat bl = luma(texture(TEXTURE, UV + vec2(-texel.x, texel.y)).rgb);\n\tfloat bc = luma(texture(TEXTURE, UV + vec2(0.0, texel.y)).rgb);\n\tfloat br = luma(texture(TEXTURE, UV + vec2(texel.x, texel.y)).rgb);\n\n\tfloat gx = -tl - 2.0 * ml - bl + tr + 2.0 * mr + br;\n\tfloat gy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;\n\tfloat sobel = length(vec2(gx, gy));\n\tfloat edge = smoothstep(edge_threshold, edge_threshold + 0.16, sobel * edge_strength);\n\n\tfloat fill = mc * fill_strength;\n\tfloat glow = smoothstep(0.0, 1.0, edge) * glow_strength;\n\tfloat intensity = clamp(fill + edge + glow, 0.0, 1.0);\n\tvec3 out_col = tint_color * intensity;\n\tCOLOR = vec4(out_col, 1.0);\n}\n"
	mat.shader = sh
	return mat


func _build_map_proxy_geometry(root: Node3D) -> void:
	if root == null:
		return
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.78, 0.78, 0.78)
	road_mat.roughness = 0.92
	road_mat.polygon_offset_factor = 2.0
	road_mat.polygon_offset_units = 2.0
	var plinth_mat := StandardMaterial3D.new()
	plinth_mat.albedo_color = Color(0.62, 0.62, 0.62)
	plinth_mat.roughness = 0.94
	var curb_mat := StandardMaterial3D.new()
	curb_mat.albedo_color = Color(0.9, 0.9, 0.9)
	curb_mat.roughness = 0.85
	var slab_y := -MAP_SLAB_H * 0.5
	var inner := MAP_STREET_HALF_W + MAP_CURB_W * 0.5
	var walk_c := inner + MAP_CURB_W * 0.5 + MAP_SIDEWALK_W * 0.5
	var corridor_h := walk_c + MAP_SIDEWALK_W * 0.5
	var plinth_half := corridor_h + 44.0 + 4.0
	_add_map_box(
		root,
		Vector3(plinth_half * 2.0, MAP_SLAB_H, plinth_half * 2.0),
		Vector3(0.0, slab_y - 0.004, 0.0),
		plinth_mat
	)
	var half_len := MAP_STREET_LEN * 0.5
	var lane_hw := MAP_STREET_HALF_W
	var lane_w := lane_hw * 2.0
	var arm := half_len - lane_hw
	var curb_y := MAP_CURB_H * 0.5 - 0.015
	_add_map_box(root, Vector3(lane_w, MAP_SLAB_H, lane_w), Vector3(0.0, slab_y, 0.0), road_mat)
	if arm > 0.05:
		var z_south := -(half_len + lane_hw) * 0.5
		var z_north := (half_len + lane_hw) * 0.5
		var x_west := -(half_len + lane_hw) * 0.5
		var x_east := (half_len + lane_hw) * 0.5
		_add_map_box(root, Vector3(lane_w, MAP_SLAB_H, arm), Vector3(0.0, slab_y, z_south), road_mat)
		_add_map_box(root, Vector3(lane_w, MAP_SLAB_H, arm), Vector3(0.0, slab_y, z_north), road_mat)
		_add_map_box(root, Vector3(arm, MAP_SLAB_H, lane_w), Vector3(x_west, slab_y, 0.0), road_mat)
		_add_map_box(root, Vector3(arm, MAP_SLAB_H, lane_w), Vector3(x_east, slab_y, 0.0), road_mat)
		_add_map_box(root, Vector3(MAP_CURB_W, MAP_CURB_H, arm), Vector3(-inner, curb_y, z_south), curb_mat)
		_add_map_box(root, Vector3(MAP_CURB_W, MAP_CURB_H, arm), Vector3(inner, curb_y, z_south), curb_mat)
		_add_map_box(root, Vector3(MAP_CURB_W, MAP_CURB_H, arm), Vector3(-inner, curb_y, z_north), curb_mat)
		_add_map_box(root, Vector3(MAP_CURB_W, MAP_CURB_H, arm), Vector3(inner, curb_y, z_north), curb_mat)
		_add_map_box(root, Vector3(arm, MAP_CURB_H, MAP_CURB_W), Vector3(x_west, curb_y, -inner), curb_mat)
		_add_map_box(root, Vector3(arm, MAP_CURB_H, MAP_CURB_W), Vector3(x_west, curb_y, inner), curb_mat)
		_add_map_box(root, Vector3(arm, MAP_CURB_H, MAP_CURB_W), Vector3(x_east, curb_y, -inner), curb_mat)
		_add_map_box(root, Vector3(arm, MAP_CURB_H, MAP_CURB_W), Vector3(x_east, curb_y, inner), curb_mat)
	var ramp := MeshInstance3D.new()
	var ramp_mesh := BoxMesh.new()
	ramp_mesh.size = Vector3(3.6, 0.6, 5.0)
	ramp.mesh = ramp_mesh
	ramp.material_override = road_mat
	ramp.layers = 1 << (MAP_STRUCTURAL_LAYER - 1)
	ramp.position = Vector3(0.0, 0.0, -14.0)
	ramp.rotation_degrees = Vector3(-18.0, 180.0, 0.0)
	root.add_child(ramp)


func _add_map_box(root: Node3D, box_size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	mi.mesh = bm
	mi.material_override = mat
	mi.layers = 1 << (MAP_STRUCTURAL_LAYER - 1)
	mi.position = pos
	root.add_child(mi)
