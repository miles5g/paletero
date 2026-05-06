extends Node3D
class_name CelestialCycle

const FULL_ROTATION_DEGREES: float = 360.0
const REAL_SECONDS_PER_CYCLE: float = 1800.0
const ROTATION_DEGREES_PER_SECOND: float = FULL_ROTATION_DEGREES / REAL_SECONDS_PER_CYCLE
const WAIT_ROTATION_DEGREES_PER_SECOND: float = 15.0 # 1 game hour per second.
const ORBIT_RADIUS: float = 220.0
## Sun/moon glow is hidden when body center is below this world Y (street tops ~0).
const CELESTIAL_GLOW_MIN_WORLD_Y: float = 0.35

@export var debug_hud_enabled: bool = true

var _world_environment: WorldEnvironment = null
var _environment: Environment = null
var _pivot: Node3D = null
var _orbital_arm: Node3D = null
var _sun_orb: MeshInstance3D = null
var _sun_halo: MeshInstance3D = null
var _sun_light: DirectionalLight3D = null
var _moon_orb: MeshInstance3D = null
var _moon_halo: MeshInstance3D = null
var _moon_light: DirectionalLight3D = null
var _cycle_angle_deg: float = 90.0
var _debug_layer: CanvasLayer = null
var _backdrop: ColorRect = null
var _clock_canvas: Node2D = null
var _wait_cursor: Label = null
var _sun_marker: Label = null
var _clock_label: Label = null
var _hint_label: Label = null
var _target_marker: Label = null
var _clock_center: Vector2 = Vector2(90.0, 90.0)
var _clock_radius: float = 58.0
var _is_wait_selecting: bool = false
var _is_wait_advancing: bool = false
var _wait_target_angle_deg: float = 90.0
var _wait_slider_dragging: bool = false
var _pre_wait_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _enter_prev_down: bool = false
var _esc_prev_down: bool = false
var _t_prev_down: bool = false


func setup(world_environment: WorldEnvironment) -> void:
	_world_environment = world_environment
	_environment = world_environment.environment if world_environment != null else null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_build_orbital_rig()
	_build_debug_hud()
	_apply_cycle_visuals()


func _process(delta: float) -> void:
	_poll_wait_controls()
	_poll_wait_slider_keys(delta)
	if _is_wait_advancing:
		_advance_wait_cycle(delta)
	else:
		_cycle_angle_deg = fposmod(_cycle_angle_deg + ROTATION_DEGREES_PER_SECOND * delta, FULL_ROTATION_DEGREES)
	_apply_cycle_visuals()


func _input(event: InputEvent) -> void:
	if not debug_hud_enabled:
		return
	if not _is_wait_selecting:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_wait_slider_dragging = false
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_wait_slider_dragging = true
			_set_wait_target_from_mouse(mb.position)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_wait_target_angle_deg = fposmod(_wait_target_angle_deg - 5.0, FULL_ROTATION_DEGREES)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_wait_target_angle_deg = fposmod(_wait_target_angle_deg + 5.0, FULL_ROTATION_DEGREES)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _wait_slider_dragging:
			_set_wait_target_from_mouse(mm.position)
			get_viewport().set_input_as_handled()


func _poll_wait_controls() -> void:
	var enter_down := Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER)
	var esc_down := Input.is_key_pressed(KEY_ESCAPE)
	var t_down := Input.is_key_pressed(KEY_T)
	var enter_edge := enter_down and not _enter_prev_down
	var esc_edge := esc_down and not _esc_prev_down
	var t_edge := t_down and not _t_prev_down
	_enter_prev_down = enter_down
	_esc_prev_down = esc_down
	_t_prev_down = t_down
	if not (_is_wait_selecting or _is_wait_advancing):
		return
	if esc_edge or t_edge:
		_finish_wait()
		return
	if _is_wait_selecting and enter_edge:
		_begin_wait_advance()


func _handle_wait_toggle() -> void:
	if _is_wait_advancing:
		_finish_wait()
		return
	if _is_wait_selecting:
		_finish_wait()
		return
	if not _can_start_wait():
		return
	_begin_wait_select()


func request_wait_toggle() -> void:
	_handle_wait_toggle()


func _can_start_wait() -> bool:
	var world := get_parent()
	if world == null:
		return true
	var player := world.get_node_or_null("Player") as CharacterBody3D
	if player != null and bool(player.get("is_pushing")):
		return false
	var inv := world.get_node_or_null("HUD/InventoryMenu") as Control
	if inv != null and inv.visible:
		return false
	return true


func _build_orbital_rig() -> void:
	_pivot = Node3D.new()
	_pivot.name = "CelestialPivot"
	add_child(_pivot)

	_orbital_arm = Node3D.new()
	_orbital_arm.name = "OrbitalArm"
	_pivot.add_child(_orbital_arm)

	_sun_orb = MeshInstance3D.new()
	_sun_orb.name = "SunOrb"
	var sun_mesh := SphereMesh.new()
	sun_mesh.radius = 10.5
	sun_mesh.height = 21.0
	_sun_orb.mesh = sun_mesh
	_sun_orb.position = Vector3(0.0, 0.0, -ORBIT_RADIUS)
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color(1.0, 0.74, 0.26)
	orb_mat.emission_enabled = true
	orb_mat.emission = Color(1.0, 0.84, 0.3)
	orb_mat.emission_energy_multiplier = 6.0
	orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb_mat.disable_ambient_light = true
	orb_mat.disable_fog = true
	_sun_orb.material_override = orb_mat
	_orbital_arm.add_child(_sun_orb)

	# Add a larger transparent shell so the sun reads as radiating orange/yellow glow.
	_sun_halo = MeshInstance3D.new()
	_sun_halo.name = "SunHalo"
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 15.8
	halo_mesh.height = 31.6
	_sun_halo.mesh = halo_mesh
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = Color(1.0, 0.66, 0.12, 0.0)
	halo_mat.emission_enabled = true
	halo_mat.emission = Color(1.0, 0.74, 0.2)
	halo_mat.emission_energy_multiplier = 4.6
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.disable_fog = true
	halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sun_halo.material_override = halo_mat
	_sun_orb.add_child(_sun_halo)

	_sun_light = DirectionalLight3D.new()
	_sun_light.name = "SunLight"
	_sun_light.shadow_enabled = true
	_sun_light.shadow_opacity = 0.1
	_sun_light.light_energy = 0.8
	_sun_light.light_color = Color(1.0, 0.92, 0.74)
	_sun_orb.add_child(_sun_light)

	# Moon: same orbit ring, opposite side of the sun (+Z vs sun's -Z).
	_moon_orb = MeshInstance3D.new()
	_moon_orb.name = "MoonOrb"
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 7.2
	moon_mesh.height = 14.4
	_moon_orb.mesh = moon_mesh
	_moon_orb.position = Vector3(0.0, 0.0, ORBIT_RADIUS)
	var moon_mat := StandardMaterial3D.new()
	moon_mat.albedo_color = Color(0.72, 0.74, 0.78)
	moon_mat.emission_enabled = true
	moon_mat.emission = Color(0.82, 0.86, 0.95)
	moon_mat.emission_energy_multiplier = 2.4
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mat.disable_ambient_light = true
	moon_mat.disable_fog = true
	_moon_orb.material_override = moon_mat
	_orbital_arm.add_child(_moon_orb)

	_moon_halo = MeshInstance3D.new()
	_moon_halo.name = "MoonHalo"
	var moon_halo_mesh := SphereMesh.new()
	moon_halo_mesh.radius = 10.5
	moon_halo_mesh.height = 21.0
	_moon_halo.mesh = moon_halo_mesh
	var moon_halo_mat := StandardMaterial3D.new()
	moon_halo_mat.albedo_color = Color(0.65, 0.72, 0.92, 0.0)
	moon_halo_mat.emission_enabled = true
	moon_halo_mat.emission = Color(0.7, 0.78, 0.98)
	moon_halo_mat.emission_energy_multiplier = 2.0
	moon_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	moon_halo_mat.disable_fog = true
	moon_halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_moon_halo.material_override = moon_halo_mat
	_moon_orb.add_child(_moon_halo)

	_moon_light = DirectionalLight3D.new()
	_moon_light.name = "MoonLight"
	_moon_light.shadow_enabled = false
	_moon_light.light_energy = 0.38
	_moon_light.light_color = Color(0.68, 0.76, 0.98)
	_moon_light.light_specular = 0.48
	_moon_orb.add_child(_moon_light)


func _apply_cycle_visuals() -> void:
	if _pivot == null:
		return
	_pivot.rotation_degrees.x = _cycle_angle_deg
	var sun_to_origin := Vector3.ZERO - _sun_orb.global_position
	var sun_forward := sun_to_origin.normalized() if sun_to_origin.length_squared() > 1e-6 else Vector3.FORWARD
	var dot_up := absf(sun_forward.dot(Vector3.UP))
	var safe_up := Vector3.UP if dot_up < 0.995 else Vector3.FORWARD
	_sun_orb.look_at(Vector3.ZERO, safe_up)
	_sun_light.look_at(Vector3.ZERO, safe_up)

	var moon_to_origin := Vector3.ZERO - _moon_orb.global_position
	var moon_forward := moon_to_origin.normalized() if moon_to_origin.length_squared() > 1e-6 else Vector3.BACK
	var moon_dot_up := absf(moon_forward.dot(Vector3.UP))
	var moon_safe_up := Vector3.UP if moon_dot_up < 0.995 else Vector3.FORWARD
	_moon_orb.look_at(Vector3.ZERO, moon_safe_up)
	_moon_light.look_at(Vector3.ZERO, moon_safe_up)

	var sun_glow_ok: bool = _sun_orb.global_position.y > CELESTIAL_GLOW_MIN_WORLD_Y
	var moon_glow_ok: bool = _moon_orb.global_position.y > CELESTIAL_GLOW_MIN_WORLD_Y
	if _sun_halo:
		_sun_halo.visible = sun_glow_ok
	if _moon_halo:
		_moon_halo.visible = moon_glow_ok

	var altitude: float = sin(deg_to_rad(_cycle_angle_deg))
	var daylight: float = clampf(altitude, 0.0, 1.0)
	var night_depth: float = clampf(-altitude, 0.0, 1.0)
	var horizon_band: float = 1.0 - smoothstep(0.08, 0.42, absf(altitude))
	var day_energy: float = pow(daylight, 0.58)
	var twilight_glow: float = horizon_band * 0.14
	var midnight_cut: float = smoothstep(0.65, 1.0, night_depth)
	var sun_energy: float = maxf(day_energy * 2.35 + twilight_glow, 0.0) * (1.0 - midnight_cut)
	_sun_light.light_energy = sun_energy
	_sun_light.light_color = _sun_color_for_altitude(altitude)

	# Moonlight: strongest when the sun is down; cool blue-white, no daytime spill.
	var moon_up := smoothstep(0.08, 0.48, night_depth)
	var moon_energy: float = moon_up * pow(night_depth, 0.58) * 0.92
	moon_energy *= 1.0 - smoothstep(0.0, 0.35, daylight)
	_moon_light.light_energy = moon_energy
	_moon_light.light_color = _moon_light_color_for_night(night_depth, horizon_band)

	_update_clock_hud()

	var orb_material := _sun_orb.material_override as StandardMaterial3D
	if orb_material:
		var orb_glow := 1.8 + day_energy * 6.0 + horizon_band * 1.3
		if not sun_glow_ok:
			orb_glow = 0.0
		orb_material.emission_energy_multiplier = orb_glow
		var hot_orange := Color(1.0, 0.62, 0.18)
		var warm_yellow := Color(1.0, 0.9, 0.34)
		var core_t := clampf(day_energy * 0.85 + horizon_band * 0.35, 0.0, 1.0)
		if sun_glow_ok:
			orb_material.albedo_color = hot_orange.lerp(warm_yellow, core_t)
			orb_material.emission = hot_orange.lerp(warm_yellow, clampf(core_t + 0.12, 0.0, 1.0))
		else:
			orb_material.albedo_color = Color(0.12, 0.12, 0.13)
			orb_material.emission = Color.BLACK
	var halo_material := _sun_halo.material_override as StandardMaterial3D if _sun_halo != null else null
	if halo_material and sun_glow_ok:
		var hot_orange := Color(1.0, 0.62, 0.18)
		var warm_yellow := Color(1.0, 0.92, 0.36)
		var halo_t := clampf(day_energy * 0.9 + horizon_band * 0.4, 0.0, 1.0)
		var halo_alpha := clampf(0.12 + day_energy * 0.2 + horizon_band * 0.08, 0.06, 0.34)
		var halo_col := hot_orange.lerp(warm_yellow, halo_t)
		halo_material.albedo_color = Color(halo_col.r, halo_col.g, halo_col.b, halo_alpha)
		halo_material.emission = hot_orange.lerp(warm_yellow, clampf(halo_t + 0.14, 0.0, 1.0))
		halo_material.emission_energy_multiplier = 2.2 + day_energy * 4.0 + horizon_band * 1.2

	var moon_body := _moon_orb.material_override as StandardMaterial3D if _moon_orb != null else null
	var moon_halo_mat := _moon_halo.material_override as StandardMaterial3D if _moon_halo != null else null
	if moon_body:
		var silver := Color(0.62, 0.64, 0.68)
		var ice := Color(0.88, 0.91, 0.98)
		var moon_vis := clampf(night_depth * 1.15 + horizon_band * 0.08, 0.0, 1.0)
		if moon_glow_ok:
			moon_body.albedo_color = silver.lerp(ice, moon_vis * 0.45)
			moon_body.emission = Color(0.72, 0.78, 0.95).lerp(Color(0.9, 0.93, 1.0), moon_vis)
			moon_body.emission_energy_multiplier = 0.45 + moon_vis * 4.6
		else:
			moon_body.albedo_color = Color(0.12, 0.12, 0.14)
			moon_body.emission = Color.BLACK
			moon_body.emission_energy_multiplier = 0.0
	if moon_halo_mat and moon_glow_ok:
		var moon_vis_h := clampf(night_depth * 1.05 + horizon_band * 0.1, 0.0, 1.0)
		var halo_blue := Color(0.58, 0.68, 0.95)
		var halo_pale := Color(0.82, 0.88, 1.0)
		var hcol := halo_blue.lerp(halo_pale, moon_vis_h)
		var halpha := clampf(0.04 + moon_vis_h * 0.22, 0.02, 0.28)
		moon_halo_mat.albedo_color = Color(hcol.r, hcol.g, hcol.b, halpha)
		moon_halo_mat.emission = hcol
		moon_halo_mat.emission_energy_multiplier = 0.75 + moon_vis_h * 3.2

	if _environment == null:
		return
	var env_night: float = smoothstep(0.0, 1.0, night_depth)
	var env_horizon: float = horizon_band
	var sky_day := Color(0.66, 0.62, 0.56)
	var sky_dusk := Color(0.31, 0.22, 0.24)
	var sky_night := Color(0.055, 0.07, 0.11)
	var ambient_day := Color(0.45, 0.4, 0.34)
	var ambient_dusk := Color(0.26, 0.2, 0.24)
	var ambient_night := Color(0.12, 0.15, 0.24)
	var fog_day := Color(0.64, 0.59, 0.52)
	var fog_night := Color(0.11, 0.13, 0.2)

	var day_to_dusk := sky_day.lerp(sky_dusk, env_horizon)
	_environment.background_color = day_to_dusk.lerp(sky_night, env_night)
	var amb_day_to_dusk := ambient_day.lerp(ambient_dusk, env_horizon)
	_environment.ambient_light_color = amb_day_to_dusk.lerp(ambient_night, env_night)
	_environment.ambient_light_energy = lerpf(1.62, 0.34, env_night)
	_environment.fog_light_color = fog_day.lerp(fog_night, env_night)
	_environment.fog_density = lerpf(0.012, 0.078, env_night)
	_environment.glow_intensity = lerpf(0.82, 0.34, env_night)
	_environment.glow_strength = lerpf(1.2, 0.86, env_night)
	_environment.glow_hdr_threshold = lerpf(0.58, 0.76, env_night)


func _moon_light_color_for_night(night_depth: float, horizon_band: float) -> Color:
	var cool := Color(0.55, 0.62, 0.88)
	var silver_blue := Color(0.74, 0.8, 0.98)
	var t := clampf(night_depth * 0.9 + horizon_band * 0.15, 0.0, 1.0)
	return cool.lerp(silver_blue, t)


func _sun_color_for_altitude(altitude: float) -> Color:
	if altitude >= 0.0:
		var t := pow(clampf(altitude, 0.0, 1.0), 0.62)
		var horizon_color := Color(0.96, 0.44, 0.18)
		var high_color := Color(1.0, 0.95, 0.78)
		return horizon_color.lerp(high_color, t)
	var nt := pow(clampf(-altitude, 0.0, 1.0), 0.74)
	var low_blue := Color(0.42, 0.46, 0.62)
	var deep_blue := Color(0.23, 0.28, 0.42)
	return low_blue.lerp(deep_blue, nt)


func _build_debug_hud() -> void:
	if not debug_hud_enabled:
		return
	_debug_layer = CanvasLayer.new()
	_debug_layer.name = "CelestialClockHUD"
	_debug_layer.layer = 5
	add_child(_debug_layer)
	_backdrop = ColorRect.new()
	_backdrop.name = "WaitBackdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.01, 0.01, 0.02, 0.72)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.visible = false
	_debug_layer.add_child(_backdrop)

	_clock_canvas = Node2D.new()
	_clock_canvas.name = "ClockCanvas"
	_clock_canvas.position = Vector2(26.0, 24.0)
	_debug_layer.add_child(_clock_canvas)
	_build_clock_ring()

	_sun_marker = Label.new()
	_sun_marker.name = "SunMarker"
	_sun_marker.text = "●"
	_sun_marker.add_theme_font_size_override("font_size", 18)
	_sun_marker.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35, 1.0))
	_debug_layer.add_child(_sun_marker)

	_wait_cursor = Label.new()
	_wait_cursor.name = "WaitCursor"
	_wait_cursor.text = "+"
	_wait_cursor.add_theme_font_size_override("font_size", 18)
	_wait_cursor.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	_wait_cursor.visible = false
	_debug_layer.add_child(_wait_cursor)

	_clock_label = Label.new()
	_clock_label.name = "DigitalClock"
	_clock_label.size = Vector2(120.0, 28.0)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock_label.add_theme_font_size_override("font_size", 15)
	_clock_label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
	_debug_layer.add_child(_clock_label)

	_target_marker = Label.new()
	_target_marker.name = "TargetMarker"
	_target_marker.text = "◎"
	_target_marker.add_theme_font_size_override("font_size", 20)
	_target_marker.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0, 0.9))
	_target_marker.visible = false
	_debug_layer.add_child(_target_marker)

	_hint_label = Label.new()
	_hint_label.name = "WaitHint"
	_hint_label.size = Vector2(240.0, 42.0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.93, 0.94))
	_hint_label.text = "[T] Wait"
	_debug_layer.add_child(_hint_label)


func _build_clock_ring() -> void:
	if _clock_canvas == null:
		return
	var day_arc := Line2D.new()
	day_arc.name = "DayArc"
	day_arc.default_color = Color(0.96, 0.7, 0.34, 0.95)
	day_arc.width = 4.0
	day_arc.closed = false
	day_arc.points = _arc_points(_clock_center, _clock_radius, PI, TAU, 36)
	_clock_canvas.add_child(day_arc)

	var night_arc := Line2D.new()
	night_arc.name = "NightArc"
	night_arc.default_color = Color(0.26, 0.36, 0.7, 0.9)
	night_arc.width = 4.0
	night_arc.closed = false
	night_arc.points = _arc_points(_clock_center, _clock_radius, 0.0, PI, 36)
	_clock_canvas.add_child(night_arc)


func _arc_points(center: Vector2, radius: float, start_angle: float, end_angle: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var a := lerpf(start_angle, end_angle, t)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


func _update_clock_hud() -> void:
	if _debug_layer == null or _sun_marker == null or _clock_label == null:
		return
	# Map world cycle to 24h clock where top = 12PM and bottom = 12AM.
	var hours_float: float = fposmod(((_cycle_angle_deg - 90.0) / 360.0) * 24.0 + 12.0, 24.0)
	var hour24: int = int(floor(hours_float))
	var minute: int = int(floor((hours_float - float(hour24)) * 60.0))
	var is_pm: bool = hour24 >= 12
	var hour12: int = hour24 % 12
	if hour12 == 0:
		hour12 = 12
	_clock_label.text = "%02d:%02d %s" % [hour12, minute, "PM" if is_pm else "AM"]

	var marker_angle: float = deg_to_rad(_cycle_angle_deg - 180.0)
	var clock_center_screen := _clock_canvas.position + _clock_center * _clock_canvas.scale
	var marker_pos := clock_center_screen + Vector2(cos(marker_angle), sin(marker_angle)) * _clock_radius
	_sun_marker.position = marker_pos - Vector2(7.0, 11.0)
	_clock_label.position = clock_center_screen - _clock_label.size * 0.5
	_hint_label.position = clock_center_screen + Vector2(-120.0, 66.0 * _clock_canvas.scale.y)
	_hint_label.size = Vector2(280.0, 52.0)
	if _target_marker:
		_target_marker.visible = _is_wait_selecting or _is_wait_advancing
		var target_angle := deg_to_rad(_wait_target_angle_deg - 180.0)
		var target_pos := clock_center_screen + Vector2(cos(target_angle), sin(target_angle)) * _clock_radius
		_target_marker.position = target_pos - Vector2(8.0, 12.0)
		if _is_wait_selecting:
			_clock_label.text = "%s\nSET %s" % [_clock_label.text, _time_string_for_angle(_wait_target_angle_deg)]
			_hint_label.text = "[Enter] Confirm  [Esc/T] Cancel"
		elif _is_wait_advancing:
			_hint_label.text = "Waiting... [Esc/T] cancel"
		else:
			_hint_label.text = "[T] Wait"
			if not _can_start_wait():
				_hint_label.text = "[T] Wait (unavailable)"
	if _wait_cursor:
		_wait_cursor.visible = _is_wait_selecting
		if _is_wait_selecting:
			var mpos := get_viewport().get_mouse_position()
			_wait_cursor.position = mpos - Vector2(6.0, 10.0)


func _begin_wait_select() -> void:
	_is_wait_selecting = true
	_is_wait_advancing = false
	_wait_target_angle_deg = _cycle_angle_deg
	_wait_slider_dragging = false
	get_tree().paused = true
	_set_wait_overlay_active(true)


func _begin_wait_advance() -> void:
	_is_wait_selecting = false
	_is_wait_advancing = true


func _advance_wait_cycle(delta: float) -> void:
	var step := WAIT_ROTATION_DEGREES_PER_SECOND * delta
	var dist_forward := fposmod(_wait_target_angle_deg - _cycle_angle_deg, FULL_ROTATION_DEGREES)
	if dist_forward <= step:
		_cycle_angle_deg = _wait_target_angle_deg
		_finish_wait()
		return
	_cycle_angle_deg = fposmod(_cycle_angle_deg + step, FULL_ROTATION_DEGREES)


func _finish_wait() -> void:
	_is_wait_selecting = false
	_is_wait_advancing = false
	_wait_slider_dragging = false
	get_tree().paused = false
	_set_wait_overlay_active(false)


func _set_clock_scale(mult: float) -> void:
	if _clock_canvas:
		_clock_canvas.scale = Vector2.ONE * mult
	_clock_radius = 58.0 * mult


func _set_wait_overlay_active(active: bool) -> void:
	if _backdrop:
		_backdrop.visible = active
	if _clock_canvas == null:
		return
	if active:
		_pre_wait_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var vp := get_viewport().get_visible_rect().size
		_clock_canvas.position = vp * 0.5 - _clock_center * 3.2
		_set_clock_scale(3.2)
	else:
		Input.mouse_mode = _pre_wait_mouse_mode
		_clock_canvas.position = Vector2(26.0, 24.0)
		_set_clock_scale(1.0)
	if _wait_cursor:
		_wait_cursor.visible = active


func _time_string_for_angle(angle_deg: float) -> String:
	var hours_float: float = fposmod(((angle_deg - 90.0) / 360.0) * 24.0 + 12.0, 24.0)
	var hour24: int = int(floor(hours_float))
	var minute: int = int(floor((hours_float - float(hour24)) * 60.0))
	var is_pm: bool = hour24 >= 12
	var hour12: int = hour24 % 12
	if hour12 == 0:
		hour12 = 12
	return "%02d:%02d %s" % [hour12, minute, "PM" if is_pm else "AM"]


func _set_wait_target_from_mouse(mouse_pos: Vector2) -> void:
	if not _is_wait_selecting or _clock_canvas == null:
		return
	var center_screen := _clock_canvas.position + _clock_center * _clock_canvas.scale
	var v := mouse_pos - center_screen
	if v.length() < 12.0:
		return
	var marker_angle := atan2(v.y, v.x)
	_wait_target_angle_deg = fposmod(rad_to_deg(marker_angle) + 180.0, FULL_ROTATION_DEGREES)


func _poll_wait_slider_keys(delta: float) -> void:
	if not _is_wait_selecting:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_set_wait_target_from_mouse(get_viewport().get_mouse_position())
	var step := 120.0 * delta
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		_wait_target_angle_deg = fposmod(_wait_target_angle_deg - step, FULL_ROTATION_DEGREES)
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		_wait_target_angle_deg = fposmod(_wait_target_angle_deg + step, FULL_ROTATION_DEGREES)
