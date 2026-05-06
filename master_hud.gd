extends Panel

enum SortColumn { NAME, CAT, QTY, WT, VAL }
enum Section { MANIFEST, STATS, MAP }

## Matches HeaderRow column widths in MasterHUD.tscn (pixel-aligned with rows)
const COL_QTY_WIDTH: int = 44
const COL_CAT_WIDTH: int = 30
const COL_H_SEP: int = 6
const COL_WT_WIDTH: int = 72
const COL_VAL_WIDTH: int = 52
const SORT_BTN_WIDTH: int = 10
const SORT_HDR_INNER_SEP: int = 0
const SORT_NAME_BTN_SEP: int = 0
const NAME_COL_LEFT_INSET: int = 0
const COL_QTY_CELL_WIDTH: int = COL_QTY_WIDTH + SORT_HDR_INNER_SEP + SORT_BTN_WIDTH
const COL_CAT_CELL_WIDTH: int = COL_CAT_WIDTH + SORT_HDR_INNER_SEP + SORT_BTN_WIDTH
const COL_WT_CELL_WIDTH: int = COL_WT_WIDTH + SORT_HDR_INNER_SEP + SORT_BTN_WIDTH
const COL_VAL_CELL_WIDTH: int = COL_VAL_WIDTH + SORT_HDR_INNER_SEP + SORT_BTN_WIDTH
const NAME_COL_STRETCH: float = 4.0
const META_COL_STRETCH: float = 1.0
const META_LABEL_MIN_WIDTH: int = 8
const HEADER_GREY := Color(0.42, 0.46, 0.52)
const HEADER_FONT_SZ := 9
const SORT_BTN_FONT_SZ := 8
const ROW_META_FONT_SZ := 9
const ROW_HOVER_PULSE_SEC := 0.5
const ROW_HOVER_GOLD := Color(1.0, 0.72, 0.18)
const ROW_HOVER_ALPHA_HI := 0.42
const ROW_HOVER_ALPHA_LO := 0.12
const ROW_SELECTED_COLOR := Color(1.0, 0.98, 0.82)
const ROW_SELECTED_ALPHA := 0.62
const ROW_SELECTED_ALPHA_LO := 0.28
const _PHYSICAL_ITEM_SCENE: PackedScene = preload("res://PhysicalItem.tscn")
const _PHOTO_BOOTH_SCRIPT: Script = preload("res://item_photo_booth.gd")
const MAP_VIEWPORT_SIZE: Vector2i = Vector2i(256, 256)
const MAP_CAMERA_DEFAULT_SIZE: float = 120.0
const MAP_CAMERA_MIN_SIZE: float = 48.0
const MAP_CAMERA_MAX_SIZE: float = 220.0
const MAP_CAMERA_ZOOM_STEP: float = 12.0
const MAP_WORLD_MIN_X: float = -14.0
const MAP_WORLD_MAX_X: float = 14.0
const MAP_WORLD_MIN_Z: float = -55.0
const MAP_WORLD_MAX_Z: float = 55.0
const MAP_ACTOR_LAYER: int = 3
const MAP_STRUCTURAL_LAYER: int = 1
const MAP_STREET_LEN: float = 100.0
const MAP_STREET_HALF_W: float = 4.0
const MAP_CURB_W: float = 0.22
const MAP_CURB_H: float = 0.16
const MAP_SIDEWALK_W: float = 6.0
const MAP_SLAB_H: float = 0.2

var _sort_column: SortColumn = SortColumn.NAME
var _sort_ascending: bool = true
var _selected_row_index: int = -1

var _item_list: VBoxContainer
var _total_money_label: Label
var _total_weight_label: Label
var _detail_icon: TextureRect
var _detail_booth: Node = null
var _detail_name: Label
var _detail_rarity: RichTextLabel
var _detail_category: Label
var _detail_weight: Label
var _detail_value: Label
var _detail_description: Label
var _action_list: VBoxContainer
var _drop_button: Button
var _trash_button: Button
var _eat_button: Button
var _transfer_button: Button = null
var _btn_manifest: Button
var _btn_stats: Button
var _btn_map: Button
var _right_panel: Control
var _manifest_page: Control
var _stats_page: Control
var _map_page: Control
var _active_section: Section = Section.MANIFEST

var _inventory_owner: Node = null
var _player_owner: CharacterBody3D = null
var _cart_owner: RigidBody3D = null
var _map_view: SubViewportContainer = null
var _map_viewport: SubViewport = null
var _map_camera: Camera3D = null
var _map_overlay: Control = null
var _map_player_marker: Polygon2D = null
var _map_cart_marker: Label = null
var _map_rose_root: Control = null
var _map_legend_label: Label = null
var _entries: Array[ItemResource] = []
var _placeholder_preview_tex: Texture2D = null

var _row_hover_tweens: Dictionary = {}
var _row_pulse_targets: Dictionary = {}


func _ready() -> void:
	set_process(true)
	visibility_changed.connect(_on_inventory_visibility_changed)
	_apply_panel_borders()
	_item_list = get_node(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/CenterList/ItemListVBox"
	) as VBoxContainer
	_total_money_label = get_node(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/WeightFooter/FooterTotalsHBox/TotalMoneyLabel"
	) as Label
	_total_weight_label = get_node(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/WeightFooter/FooterTotalsHBox/TotalManifestWeightLabel"
	) as Label
	_detail_icon = get_node(
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/ItemPreviewWindow/ItemPreviewImage"
	) as TextureRect
	var detail_preview_window := get_node_or_null(
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/ItemPreviewWindow"
	) as Control
	if detail_preview_window != null:
		_detail_booth = _PHOTO_BOOTH_SCRIPT.new()
		if _detail_booth is Control:
			var booth_ctrl := _detail_booth as Control
			booth_ctrl.name = "ItemPhotoBooth"
			booth_ctrl.anchor_left = 0.0
			booth_ctrl.anchor_top = 0.0
			booth_ctrl.anchor_right = 1.0
			booth_ctrl.anchor_bottom = 1.0
			booth_ctrl.offset_left = 3.0
			booth_ctrl.offset_top = 3.0
			booth_ctrl.offset_right = -3.0
			booth_ctrl.offset_bottom = -3.0
			detail_preview_window.add_child(booth_ctrl)
	if _detail_icon != null:
		_detail_icon.texture = null
		_detail_icon.visible = false
	_detail_name = get_node("OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/NameLabel") as Label
	_detail_rarity = get_node("OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/RarityLabel") as RichTextLabel
	_detail_category = get_node(
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/CategoryLabel"
	) as Label
	_detail_weight = get_node(
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/StatsHBox/WeightLabel"
	) as Label
	_detail_value = get_node(
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/StatsHBox/ValueLabel"
	) as Label
	_detail_description = get_node(
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/DescriptionLabel"
	) as Label
	_action_list = get_node(
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/ActionList"
	) as VBoxContainer
	_drop_button = get_node(
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/ActionList/DropButton"
	) as Button
	_trash_button = get_node(
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/ActionList/TrashButton"
	) as Button
	_eat_button = get_node(
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/ActionList/EatButton"
	) as Button
	_transfer_button = _action_list.get_node_or_null("TransferButton") as Button
	if _transfer_button == null and _action_list != null:
		_transfer_button = Button.new()
		_transfer_button.name = "TransferButton"
		_transfer_button.text = "[ TRANSFER ]"
		_action_list.add_child(_transfer_button)
	_btn_manifest = get_node("OuterMargin/MainContainer/LeftRailPanel/LeftRail/BtnManifest") as Button
	_btn_stats = get_node("OuterMargin/MainContainer/LeftRailPanel/LeftRail/BtnStats") as Button
	_btn_map = get_node("OuterMargin/MainContainer/LeftRailPanel/LeftRail/BtnMap") as Button
	_right_panel = get_node_or_null("OuterMargin/MainContainer/RightPanel") as Control
	_manifest_page = get_node("OuterMargin/MainContainer/CenterPanel/CenterColumn") as Control
	_ensure_section_pages()
	if _detail_icon and _detail_icon.texture == null:
		_detail_icon.texture = _get_placeholder_preview_texture()
		_detail_icon.visible = true
	_set_action_list_visible(false)
	call_deferred("_deferred_after_world_theme")


func _deferred_after_world_theme() -> void:
	_style_list_headers()
	_style_sort_buttons()
	_style_left_rail_buttons()
	_connect_sort_buttons()
	_connect_action_buttons()
	_connect_nav_buttons()
	_apply_selectable_golden_hover()
	_style_action_buttons_bw()
	_update_sort_button_icons()
	_show_section(_active_section)
	if _detail_name:
		_detail_name.add_theme_font_size_override("font_size", 17)
	if _total_money_label:
		_total_money_label.add_theme_font_size_override("font_size", 12)
	if _total_weight_label:
		_total_weight_label.add_theme_font_size_override("font_size", 12)
		_total_weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _style_left_rail_buttons() -> void:
	for b in [_btn_manifest, _btn_stats, _btn_map]:
		if b == null:
			continue
		# Keep long labels like "PLAYER INVENTORY" inside narrow rail bounds.
		b.add_theme_font_size_override("font_size", 10)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER


func _style_list_headers() -> void:
	var hdr_row := get_node_or_null("OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow") as HBoxContainer
	if hdr_row:
		hdr_row.add_theme_constant_override("separation", COL_H_SEP)
	var hdr_lead := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrRowLead"
	) as Control
	if hdr_lead:
		hdr_lead.custom_minimum_size.x = float(NAME_COL_LEFT_INSET)
	var name_cell := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrNameCell"
	) as HBoxContainer
	var qty_cell := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrQtyCell"
	) as HBoxContainer
	var cat_cell := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrCatCell"
	) as HBoxContainer
	var wt_cell := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrWtCell"
	) as HBoxContainer
	var val_cell := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrValCell"
	) as HBoxContainer
	if name_cell:
		name_cell.add_theme_constant_override("separation", SORT_NAME_BTN_SEP)
		name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_cell.size_flags_stretch_ratio = NAME_COL_STRETCH
	if cat_cell:
		cat_cell.add_theme_constant_override("separation", SORT_HDR_INNER_SEP)
		cat_cell.custom_minimum_size = Vector2(0, 0)
		cat_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cat_cell.size_flags_stretch_ratio = META_COL_STRETCH
	if qty_cell:
		qty_cell.add_theme_constant_override("separation", SORT_HDR_INNER_SEP)
		qty_cell.custom_minimum_size = Vector2(0, 0)
		qty_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qty_cell.size_flags_stretch_ratio = META_COL_STRETCH
	if wt_cell:
		wt_cell.add_theme_constant_override("separation", SORT_HDR_INNER_SEP)
		wt_cell.custom_minimum_size = Vector2(0, 0)
		wt_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wt_cell.size_flags_stretch_ratio = META_COL_STRETCH
	if val_cell:
		val_cell.add_theme_constant_override("separation", SORT_HDR_INNER_SEP)
		val_cell.custom_minimum_size = Vector2(0, 0)
		val_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_cell.size_flags_stretch_ratio = META_COL_STRETCH
	var hdr_name := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrNameCell/HdrName"
	) as Label
	var hdr_cat := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrCatCell/HdrCat"
	) as Label
	var hdr_qty := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrQtyCell/HdrQty"
	) as Label
	var hdr_wt := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrWtCell/HdrWt"
	) as Label
	var hdr_val := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrValCell/HdrVal"
	) as Label
	for lab in [hdr_name, hdr_cat, hdr_qty, hdr_wt, hdr_val]:
		if lab:
			lab.add_theme_font_size_override("font_size", HEADER_FONT_SZ)
			lab.add_theme_color_override("font_color", HEADER_GREY)
	if hdr_name:
		hdr_name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		hdr_name.mouse_filter = Control.MOUSE_FILTER_STOP
		hdr_name.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if hdr_cat:
		hdr_cat.custom_minimum_size = Vector2(META_LABEL_MIN_WIDTH, 0)
		hdr_cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr_cat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hdr_cat.mouse_filter = Control.MOUSE_FILTER_STOP
		hdr_cat.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if hdr_qty:
		hdr_qty.custom_minimum_size = Vector2(META_LABEL_MIN_WIDTH, 0)
		hdr_qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr_qty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hdr_qty.mouse_filter = Control.MOUSE_FILTER_STOP
		hdr_qty.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if hdr_wt:
		hdr_wt.custom_minimum_size = Vector2(META_LABEL_MIN_WIDTH, 0)
		hdr_wt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr_wt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hdr_wt.mouse_filter = Control.MOUSE_FILTER_STOP
		hdr_wt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if hdr_val:
		hdr_val.custom_minimum_size = Vector2(META_LABEL_MIN_WIDTH, 0)
		hdr_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hdr_val.mouse_filter = Control.MOUSE_FILTER_STOP
		hdr_val.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _transparent_stylebox() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	return s


func _golden_hover_stylebox(alpha: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(ROW_HOVER_GOLD.r, ROW_HOVER_GOLD.g, ROW_HOVER_GOLD.b, alpha)
	s.set_corner_radius_all(2)
	s.set_border_width_all(0)
	return s


func _apply_selectable_golden_hover() -> void:
	var transparent := _transparent_stylebox()
	var hover_sb := _golden_hover_stylebox(0.5)
	var pressed_sb := _golden_hover_stylebox(0.65)
	var paths := [
		"OuterMargin/MainContainer/LeftRailPanel/LeftRail/BtnManifest",
		"OuterMargin/MainContainer/LeftRailPanel/LeftRail/BtnStats",
		"OuterMargin/MainContainer/LeftRailPanel/LeftRail/BtnMap",
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrNameCell/SortNameBtn",
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrCatCell/SortCatBtn",
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrQtyCell/SortQtyBtn",
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrWtCell/SortWtBtn",
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrValCell/SortValBtn",
	]
	for p in paths:
		var b := get_node_or_null(p) as Button
		if b == null:
			continue
		b.flat = false
		b.add_theme_stylebox_override("normal", transparent.duplicate())
		b.add_theme_stylebox_override("hover", hover_sb.duplicate())
		b.add_theme_stylebox_override("pressed", pressed_sb.duplicate())
		b.add_theme_stylebox_override("focus", transparent.duplicate())
	_update_nav_button_highlight()


func _make_empty_section_page(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8.0
	box.offset_top = 8.0
	box.offset_right = -8.0
	box.offset_bottom = -8.0
	box.visible = false
	box.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", HEADER_GREY)
	box.add_child(label)
	return box


func _ensure_section_pages() -> void:
	var center_panel := get_node_or_null("OuterMargin/MainContainer/CenterPanel") as Panel
	if center_panel == null:
		return
	_stats_page = center_panel.get_node_or_null("StatsPage") as Control
	if _stats_page == null:
		var stats_box := _make_empty_section_page("STATS (EMPTY)")
		stats_box.name = "StatsPage"
		center_panel.add_child(stats_box)
		_stats_page = stats_box
	_map_page = center_panel.get_node_or_null("MapPage") as Control
	if _map_page == null:
		var map_panel := Panel.new()
		map_panel.name = "MapPage"
		map_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		map_panel.offset_left = 8.0
		map_panel.offset_top = 8.0
		map_panel.offset_right = -8.0
		map_panel.offset_bottom = -8.0
		map_panel.visible = false
		center_panel.add_child(map_panel)
		_map_page = map_panel
		_build_map_view(map_panel)


func _build_map_view(map_root: Control) -> void:
	if map_root == null:
		return
	_map_view = SubViewportContainer.new()
	_map_view.name = "MapViewportContainer"
	_map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_view.offset_left = 6.0
	_map_view.offset_top = 6.0
	_map_view.offset_right = -6.0
	_map_view.offset_bottom = -6.0
	_map_view.stretch = true
	_map_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_view.material = _map_terminal_material()
	map_root.add_child(_map_view)

	_map_viewport = SubViewport.new()
	_map_viewport.name = "MapViewport"
	_map_viewport.size = MAP_VIEWPORT_SIZE
	_map_viewport.disable_3d = false
	_map_viewport.transparent_bg = false
	# Isolated 3D world so day/night cycle lighting never touches map render.
	_map_viewport.own_world_3d = true
	_map_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_map_view.add_child(_map_viewport)
	if not _map_view.gui_input.is_connected(_on_map_view_gui_input):
		_map_view.gui_input.connect(_on_map_view_gui_input)

	var map_world_root := Node3D.new()
	map_world_root.name = "MapWorldRoot"
	_map_viewport.add_child(map_world_root)
	_build_map_proxy_geometry(map_world_root)

	_map_camera = Camera3D.new()
	_map_camera.name = "MapTopCamera"
	_map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_map_camera.size = MAP_CAMERA_DEFAULT_SIZE
	_map_camera.near = 0.1
	_map_camera.far = 500.0
	_map_camera.position = Vector3(0.0, 140.0, 0.0)
	_map_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	# Structural-only pass: render only designated structure layer.
	_map_camera.cull_mask = 1 << (MAP_STRUCTURAL_LAYER - 1)
	_map_camera.current = true
	map_world_root.add_child(_map_camera)

	var map_light := DirectionalLight3D.new()
	map_light.name = "MapLight"
	map_light.light_energy = 2.0
	map_light.light_color = Color(0.9, 1.0, 0.9)
	map_light.shadow_enabled = false
	map_light.rotation_degrees = Vector3(-78.0, 38.0, 0.0)
	map_light.light_cull_mask = 1 << (MAP_STRUCTURAL_LAYER - 1)
	map_world_root.add_child(map_light)

	_map_overlay = Control.new()
	_map_overlay.name = "MapOverlay"
	_map_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_root.add_child(_map_overlay)

	_map_player_marker = Polygon2D.new()
	_map_player_marker.name = "PlayerMarker"
	# Clear directional arrow: sharp nose + short tail.
	_map_player_marker.polygon = PackedVector2Array([
		Vector2(0.0, -12.0),
		Vector2(8.0, 8.0),
		Vector2(2.5, 5.0),
		Vector2(0.0, 12.0),
		Vector2(-2.5, 5.0),
		Vector2(-8.0, 8.0),
	])
	_map_player_marker.color = Color.WHITE
	_map_overlay.add_child(_map_player_marker)

	_map_cart_marker = Label.new()
	_map_cart_marker.name = "CartMarker"
	_map_cart_marker.text = "■"
	_map_cart_marker.add_theme_font_size_override("font_size", 13)
	_map_cart_marker.add_theme_color_override("font_color", Color.WHITE)
	_map_cart_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_overlay.add_child(_map_cart_marker)

	_map_rose_root = Control.new()
	_map_rose_root.name = "MapRose"
	_map_rose_root.anchor_left = 0.0
	_map_rose_root.anchor_top = 0.0
	_map_rose_root.anchor_right = 0.0
	_map_rose_root.anchor_bottom = 0.0
	_map_rose_root.offset_left = 14.0
	_map_rose_root.offset_top = 8.0
	_map_rose_root.offset_right = 126.0
	_map_rose_root.offset_bottom = 70.0
	map_root.add_child(_map_rose_root)

	var rose_color := Color(0.82, 1.0, 0.82, 0.95)
	var rose_center := Vector2(56.0, 28.0)
	var rose_font_size := 12
	for entry in [
		{"txt": "N", "pos": Vector2(rose_center.x - 8.0, rose_center.y - 20.0)},
		{"txt": "E", "pos": Vector2(rose_center.x + 14.0, rose_center.y - 4.0)},
		{"txt": "S", "pos": Vector2(rose_center.x - 8.0, rose_center.y + 12.0)},
		{"txt": "W", "pos": Vector2(rose_center.x - 30.0, rose_center.y - 4.0)},
		{"txt": "✦", "pos": Vector2(rose_center.x - 8.0, rose_center.y - 4.0)},
	]:
		var rose_label := Label.new()
		rose_label.text = entry["txt"]
		rose_label.position = entry["pos"]
		rose_label.size = Vector2(16.0, 16.0)
		rose_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rose_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rose_label.add_theme_font_size_override("font_size", rose_font_size)
		rose_label.add_theme_color_override("font_color", rose_color)
		_map_rose_root.add_child(rose_label)

	_map_legend_label = Label.new()
	_map_legend_label.name = "MapLegendKey"
	_map_legend_label.anchor_left = 0.0
	_map_legend_label.anchor_top = 0.0
	_map_legend_label.anchor_right = 0.0
	_map_legend_label.anchor_bottom = 0.0
	_map_legend_label.offset_left = 24.0
	_map_legend_label.offset_top = 64.0
	_map_legend_label.offset_right = 104.0
	_map_legend_label.offset_bottom = 114.0
	_map_legend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_legend_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_map_legend_label.add_theme_font_size_override("font_size", 10)
	_map_legend_label.add_theme_color_override("font_color", Color(0.82, 1.0, 0.82, 0.95))
	_map_legend_label.text = "▲ Player\n■ Cart"
	map_root.add_child(_map_legend_label)


func _process(_delta: float) -> void:
	if _map_page == null or not _map_page.visible:
		return
	_resolve_known_owners()
	_update_map_markers()


func _on_map_view_gui_input(event: InputEvent) -> void:
	if _active_section != Section.MAP or not visible or _map_camera == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_map_camera.size = clampf(
				_map_camera.size - MAP_CAMERA_ZOOM_STEP,
				MAP_CAMERA_MIN_SIZE,
				MAP_CAMERA_MAX_SIZE
			)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_map_camera.size = clampf(
				_map_camera.size + MAP_CAMERA_ZOOM_STEP,
				MAP_CAMERA_MIN_SIZE,
				MAP_CAMERA_MAX_SIZE
			)
			accept_event()


func _on_inventory_visibility_changed() -> void:
	_reset_map_zoom()


func _reset_map_zoom() -> void:
	if _map_camera == null:
		return
	_map_camera.size = MAP_CAMERA_DEFAULT_SIZE


func _update_map_markers() -> void:
	if _map_overlay == null or _map_player_marker == null or _map_cart_marker == null:
		return
	var map_size := _map_overlay.size
	if map_size.x <= 1.0 or map_size.y <= 1.0:
		return
	var bounds := _map_visible_bounds()
	var min_x: float = bounds["min_x"]
	var max_x: float = bounds["max_x"]
	var min_z: float = bounds["min_z"]
	var max_z: float = bounds["max_z"]
	if _player_owner != null and is_instance_valid(_player_owner):
		var p2 := _world_to_map(_player_owner.global_position, map_size, min_x, max_x, min_z, max_z)
		_map_player_marker.position = p2
		var fwd := _player_compass_forward(_player_owner)
		_map_player_marker.rotation = _map_heading_rotation(fwd)
		_map_player_marker.visible = true
	else:
		_map_player_marker.visible = false
	if _cart_owner != null and is_instance_valid(_cart_owner):
		var c2 := _world_to_map(_cart_owner.global_position, map_size, min_x, max_x, min_z, max_z)
		_map_cart_marker.position = c2 - Vector2(6.0, 8.0)
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
	# North-up map: 0 rad points to -Z (up on map), positive rotates clockwise.
	return atan2(fwd.x, -fwd.z)




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
	var side_mat := StandardMaterial3D.new()
	side_mat.albedo_color = Color(0.62, 0.62, 0.62)
	side_mat.roughness = 0.94
	var curb_mat := StandardMaterial3D.new()
	curb_mat.albedo_color = Color(0.9, 0.9, 0.9)
	curb_mat.roughness = 0.85
	var slab_y := -MAP_SLAB_H * 0.5
	_add_map_box(root, Vector3(MAP_STREET_HALF_W * 2.0, MAP_SLAB_H, MAP_STREET_LEN), Vector3(0.0, slab_y, 0.0), road_mat)
	var inner := MAP_STREET_HALF_W + MAP_CURB_W * 0.5
	_add_map_box(root, Vector3(MAP_CURB_W, MAP_CURB_H, MAP_STREET_LEN), Vector3(-inner, MAP_CURB_H * 0.5 - 0.02, 0.0), curb_mat)
	_add_map_box(root, Vector3(MAP_CURB_W, MAP_CURB_H, MAP_STREET_LEN), Vector3(inner, MAP_CURB_H * 0.5 - 0.02, 0.0), curb_mat)
	var walk_center_x := inner + MAP_CURB_W * 0.5 + MAP_SIDEWALK_W * 0.5
	_add_map_box(root, Vector3(MAP_SIDEWALK_W, MAP_SLAB_H, MAP_STREET_LEN), Vector3(-walk_center_x, slab_y, 0.0), side_mat)
	_add_map_box(root, Vector3(MAP_SIDEWALK_W, MAP_SLAB_H, MAP_STREET_LEN), Vector3(walk_center_x, slab_y, 0.0), side_mat)
	# Proxy ramp so map topology matches gameplay lane.
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


func _connect_nav_buttons() -> void:
	if _btn_manifest and not _btn_manifest.pressed.is_connected(_on_manifest_pressed):
		_btn_manifest.pressed.connect(_on_manifest_pressed)
		_btn_manifest.mouse_entered.connect(_on_nav_button_hover.bind(_btn_manifest, true))
		_btn_manifest.mouse_exited.connect(_on_nav_button_hover.bind(_btn_manifest, false))
	if _btn_stats and not _btn_stats.pressed.is_connected(_on_stats_pressed):
		_btn_stats.pressed.connect(_on_stats_pressed)
		_btn_stats.mouse_entered.connect(_on_nav_button_hover.bind(_btn_stats, true))
		_btn_stats.mouse_exited.connect(_on_nav_button_hover.bind(_btn_stats, false))
	if _btn_map and not _btn_map.pressed.is_connected(_on_map_pressed):
		_btn_map.pressed.connect(_on_map_pressed)
		_btn_map.mouse_entered.connect(_on_nav_button_hover.bind(_btn_map, true))
		_btn_map.mouse_exited.connect(_on_nav_button_hover.bind(_btn_map, false))


func _on_manifest_pressed() -> void:
	if _active_section == Section.MANIFEST:
		_try_toggle_inventory_owner()
	_show_section(Section.MANIFEST)


func _on_stats_pressed() -> void:
	_show_section(Section.STATS)


func _on_map_pressed() -> void:
	_show_section(Section.MAP)


func _show_section(section: Section) -> void:
	_active_section = section
	if _manifest_page:
		_manifest_page.visible = section == Section.MANIFEST
	if _stats_page:
		_stats_page.visible = section == Section.STATS
	if _map_page:
		_map_page.visible = section == Section.MAP
	if _right_panel:
		_right_panel.visible = section == Section.MANIFEST
	_update_nav_button_highlight()


func _update_nav_button_highlight() -> void:
	var transparent := _transparent_stylebox()
	var active := _golden_hover_stylebox(0.45)
	var buttons := [_btn_manifest, _btn_stats, _btn_map]
	for b in buttons:
		if b == null:
			continue
		var sec: Section = Section.MANIFEST
		if b == _btn_stats:
			sec = Section.STATS
		elif b == _btn_map:
			sec = Section.MAP
		b.add_theme_stylebox_override("normal", (active if _active_section == sec else transparent).duplicate())


func _on_nav_button_hover(btn: Button, hover: bool) -> void:
	if btn == null:
		return
	var sec: Section = Section.MANIFEST
	if btn == _btn_stats:
		sec = Section.STATS
	elif btn == _btn_map:
		sec = Section.MAP
	if sec == _active_section:
		# Active tab remains persistently highlighted.
		btn.add_theme_stylebox_override("normal", _golden_hover_stylebox(0.45))
		return
	if hover:
		btn.add_theme_stylebox_override("normal", _golden_hover_stylebox(0.26))
	else:
		btn.add_theme_stylebox_override("normal", _transparent_stylebox())


func _style_sort_buttons() -> void:
	var paths := [
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrNameCell/SortNameBtn",
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrCatCell/SortCatBtn",
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrQtyCell/SortQtyBtn",
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrWtCell/SortWtBtn",
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrValCell/SortValBtn",
	]
	for p in paths:
		var b := get_node_or_null(p) as Button
		if b:
			b.custom_minimum_size.x = SORT_BTN_WIDTH
			b.custom_minimum_size.y = 14
			b.add_theme_font_size_override("font_size", SORT_BTN_FONT_SZ)
			b.add_theme_color_override("font_color", HEADER_GREY)


func _style_action_buttons_bw() -> void:
	var paths := [
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/ActionList/DropButton",
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/ActionList/TrashButton",
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/ActionList/EatButton",
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/ActionList/TransferButton",
	]
	for p in paths:
		var b := get_node_or_null(p) as Button
		if b == null:
			continue
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color.BLACK
		normal.border_color = Color.WHITE
		normal.set_border_width_all(1)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.1, 0.1, 0.1, 1.0)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("pressed", normal.duplicate())
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("focus", normal.duplicate())
		b.add_theme_color_override("font_color", Color.WHITE)
		b.flat = false


func _connect_sort_buttons() -> void:
	var bn := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrNameCell/SortNameBtn"
	) as Button
	var bq := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrQtyCell/SortQtyBtn"
	) as Button
	var bc := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrCatCell/SortCatBtn"
	) as Button
	var bw := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrWtCell/SortWtBtn"
	) as Button
	var bv := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrValCell/SortValBtn"
	) as Button
	var hdr_name_lab := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrNameCell/HdrName"
	) as Label
	var hdr_qty_lab := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrQtyCell/HdrQty"
	) as Label
	var hdr_cat_lab := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrCatCell/HdrCat"
	) as Label
	var hdr_wt_lab := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrWtCell/HdrWt"
	) as Label
	var hdr_val_lab := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrValCell/HdrVal"
	) as Label
	if bn:
		bn.pressed.connect(_on_sort_toggle.bind(SortColumn.NAME))
	if bc:
		bc.pressed.connect(_on_sort_toggle.bind(SortColumn.CAT))
	if bq:
		bq.pressed.connect(_on_sort_toggle.bind(SortColumn.QTY))
	if bw:
		bw.pressed.connect(_on_sort_toggle.bind(SortColumn.WT))
	if bv:
		bv.pressed.connect(_on_sort_toggle.bind(SortColumn.VAL))
	if hdr_name_lab:
		hdr_name_lab.gui_input.connect(_on_header_sort_gui_input.bind(SortColumn.NAME))
	if hdr_cat_lab:
		hdr_cat_lab.gui_input.connect(_on_header_sort_gui_input.bind(SortColumn.CAT))
	if hdr_qty_lab:
		hdr_qty_lab.gui_input.connect(_on_header_sort_gui_input.bind(SortColumn.QTY))
	if hdr_wt_lab:
		hdr_wt_lab.gui_input.connect(_on_header_sort_gui_input.bind(SortColumn.WT))
	if hdr_val_lab:
		hdr_val_lab.gui_input.connect(_on_header_sort_gui_input.bind(SortColumn.VAL))


func _connect_action_buttons() -> void:
	if _drop_button and not _drop_button.pressed.is_connected(_on_drop_pressed):
		_drop_button.pressed.connect(_on_drop_pressed)
	if _trash_button and not _trash_button.pressed.is_connected(_on_trash_pressed):
		_trash_button.pressed.connect(_on_trash_pressed)
	if _eat_button and not _eat_button.pressed.is_connected(_on_eat_pressed):
		_eat_button.pressed.connect(_on_eat_pressed)
	if _transfer_button and not _transfer_button.pressed.is_connected(_on_transfer_pressed):
		_transfer_button.pressed.connect(_on_transfer_pressed)


func _on_header_sort_gui_input(ev: InputEvent, which: SortColumn) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_sort_toggle(which)


func _update_sort_button_icons() -> void:
	var bn := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrNameCell/SortNameBtn"
	) as Button
	var bq := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrQtyCell/SortQtyBtn"
	) as Button
	var bc := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrCatCell/SortCatBtn"
	) as Button
	var bw := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrWtCell/SortWtBtn"
	) as Button
	var bv := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrValCell/SortValBtn"
	) as Button
	for pair in [[bn, SortColumn.NAME], [bc, SortColumn.CAT], [bq, SortColumn.QTY], [bw, SortColumn.WT], [bv, SortColumn.VAL]]:
		var b: Button = pair[0]
		var col: SortColumn = pair[1]
		if b == null:
			continue
		if _sort_column == col:
			b.text = "▲" if _sort_ascending else "▼"
		else:
			b.text = "▲"


func _format_weight_smart(w: float) -> String:
	var r := snappedf(w, 0.01)
	if absf(r - roundf(r)) < 1e-5:
		return str(int(roundf(r)))
	var out := "%.2f" % r
	while out.ends_with("0") and out.contains("."):
		out = out.substr(0, out.length() - 1)
	if out.ends_with("."):
		out = out.substr(0, out.length() - 1)
	return out


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.BLACK
	sb.set_border_width_all(2)
	sb.border_color = Color.WHITE
	return sb


func _apply_panel_borders() -> void:
	var sb := _panel_style()
	add_theme_stylebox_override("panel", sb)
	for path in [
		"OuterMargin/MainContainer/LeftRailPanel",
		"OuterMargin/MainContainer/CenterPanel",
		"OuterMargin/MainContainer/RightPanel",
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/WeightFooter",
	]:
		var p := get_node_or_null(path) as Panel
		if p:
			p.add_theme_stylebox_override("panel", sb.duplicate())
	var scroll_center := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/CenterList"
	) as ScrollContainer
	if scroll_center:
		var sbs := sb.duplicate()
		scroll_center.add_theme_stylebox_override("panel", sbs)
	var scroll_bottom := get_node_or_null("OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf") as ScrollContainer
	if scroll_bottom:
		var sbb := sb.duplicate()
		scroll_bottom.add_theme_stylebox_override("panel", sbb)


func bind_cart(cart: RigidBody3D) -> void:
	_inventory_owner = cart
	_resolve_known_owners()
	_update_manifest_title()
	update_total_manifest_weight()


func bind_inventory_owner(inventory_owner_node: Node) -> void:
	_inventory_owner = inventory_owner_node
	_resolve_known_owners()
	_update_manifest_title()
	update_total_manifest_weight()


func update_total_manifest_weight() -> void:
	if _total_money_label == null and _total_weight_label == null:
		return
	var total_w := 0.0
	var total_money := 0.0
	if _inventory_owner != null:
		var inv: Variant = _inventory_owner.get("inventory_list")
		if inv != null:
			for it in inv:
				if it is ItemResource:
					var q := float(it.quantity)
					total_w += it.weight_lbs * q
					total_money += it.value_usd * q
	if _total_money_label:
		_total_money_label.text = "Total money: $%.2f" % total_money
	if _total_weight_label:
		_total_weight_label.text = "Total weight: %s lbs" % _format_weight_smart(total_w)


func _apply_sort_to_entries() -> void:
	if _entries.size() <= 1:
		return
	var asc := _sort_ascending
	match _sort_column:
		SortColumn.NAME:
			_entries.sort_custom(
				func(a: ItemResource, b: ItemResource) -> bool:
					var c := a.item_name.nocasecmp_to(b.item_name)
					if c != 0:
						return c < 0 if asc else c > 0
					return false
			)
		SortColumn.CAT:
			_entries.sort_custom(
				func(a: ItemResource, b: ItemResource) -> bool:
					if a.category != b.category:
						return a.category < b.category if asc else a.category > b.category
					return a.item_name.nocasecmp_to(b.item_name) < 0
			)
		SortColumn.QTY:
			_entries.sort_custom(
				func(a: ItemResource, b: ItemResource) -> bool:
					if a.quantity != b.quantity:
						return a.quantity < b.quantity if asc else a.quantity > b.quantity
					return a.item_name.nocasecmp_to(b.item_name) < 0
			)
		SortColumn.WT:
			_entries.sort_custom(
				func(a: ItemResource, b: ItemResource) -> bool:
					if not is_equal_approx(a.weight_lbs, b.weight_lbs):
						return a.weight_lbs < b.weight_lbs if asc else a.weight_lbs > b.weight_lbs
					return a.item_name.nocasecmp_to(b.item_name) < 0
			)
		SortColumn.VAL:
			_entries.sort_custom(
				func(a: ItemResource, b: ItemResource) -> bool:
					if not is_equal_approx(a.value_usd, b.value_usd):
						return a.value_usd < b.value_usd if asc else a.value_usd > b.value_usd
					return a.item_name.nocasecmp_to(b.item_name) < 0
			)


func _fill_item_list_rows() -> void:
	for tw in _row_hover_tweens.values():
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
	_row_hover_tweens.clear()
	_row_pulse_targets.clear()
	for c in _item_list.get_children():
		c.queue_free()
	var i := 0
	for entry in _entries:
		_item_list.add_child(_make_inventory_row(entry, i))
		i += 1
	_refresh_selected_row_highlight()


func _set_action_list_visible(v: bool) -> void:
	if _action_list:
		_action_list.visible = v
	_update_transfer_button_state()


func _selected_entry() -> ItemResource:
	if _selected_row_index < 0 or _selected_row_index >= _entries.size():
		return null
	return _entries[_selected_row_index]


func _remove_selected_item_from_cart() -> ItemResource:
	if _inventory_owner == null:
		return null
	var entry := _selected_entry()
	if entry == null:
		return null
	var inv: Variant = _inventory_owner.get("inventory_list")
	if inv == null:
		return null
	var list := inv as Array
	var idx := list.find(entry)
	if idx >= 0:
		list.remove_at(idx)
	if _inventory_owner.has_method("calculate_total_weight"):
		_inventory_owner.calculate_total_weight()
	if _inventory_owner.has_method("update_mass"):
		_inventory_owner.update_mass()
	return entry


func _spawn_dropped_item(item_name: String, item: ItemResource) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := scene.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return
	var body: PhysicalItem = _PHYSICAL_ITEM_SCENE.instantiate() as PhysicalItem
	if body == null:
		return
	body.name = "Dropped_%s" % item_name.replace(" ", "_")
	if item != null:
		body.set_item_resource(item)
	scene.add_child(body)
	var up := player.global_transform.basis.y.normalized()
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
	var half_capsule_height := 0.9
	var shape_node := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		var shape := shape_node.shape as CapsuleShape3D
		half_capsule_height = shape.height * 0.5
	var head_top := player.global_position + up * (half_capsule_height + 0.25)
	if shape_node != null:
		head_top = shape_node.global_position + up * (half_capsule_height + 0.25)
	var side_sign := -1.0 if randf() < 0.5 else 1.0
	var lateral := (right * side_sign + fwd * randf_range(0.35, 0.75)).normalized()
	var side_offset := right * side_sign * randf_range(0.44, 0.72)
	var forward_offset := fwd * randf_range(0.72, 1.02)
	var vertical_offset := up * randf_range(0.35, 0.52)
	body.global_position = head_top + side_offset + forward_offset + vertical_offset
	var tilt_x := deg_to_rad(randf_range(25.0, 40.0))
	var tilt_z := deg_to_rad(randf_range(16.0, 30.0) * side_sign)
	body.global_basis = Basis.from_euler(Vector3(tilt_x, 0.0, tilt_z))
	body.add_collision_exception_with(player)
	var release_timer := get_tree().create_timer(0.32)
	release_timer.timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.remove_collision_exception_with(player)
	)
	body.apply_central_impulse(lateral * randf_range(1.35, 2.0) + up * 0.08)
	body.apply_torque_impulse(Vector3(randf_range(0.85, 1.5), 0.0, randf_range(-1.5, -0.85) * side_sign))


func _on_trash_pressed() -> void:
	var removed := _remove_selected_item_from_cart()
	if removed == null:
		return
	refresh()


func _on_eat_pressed() -> void:
	var removed := _remove_selected_item_from_cart()
	if removed == null:
		return
	print("Consumed %s" % removed.item_name)
	refresh()


func _on_drop_pressed() -> void:
	var removed := _remove_selected_item_from_cart()
	if removed == null:
		return
	_spawn_dropped_item(removed.item_name, removed)
	refresh()


func _on_transfer_pressed() -> void:
	var entry := _selected_entry()
	if entry == null:
		return
	var from_owner := _inventory_owner
	var to_owner := _transfer_target_owner()
	if from_owner == null or to_owner == null:
		return
	var inv: Variant = from_owner.get("inventory_list")
	if inv == null:
		return
	var from_list := inv as Array
	var idx := from_list.find(entry)
	if idx < 0:
		return
	from_list.remove_at(idx)
	if to_owner.has_method("add_item_to_inventory"):
		to_owner.add_item_to_inventory(entry)
	else:
		var to_inv: Variant = to_owner.get("inventory_list")
		if to_inv is Array:
			(to_inv as Array).append(entry.duplicate(true))
	if from_owner.has_method("calculate_total_weight"):
		from_owner.calculate_total_weight()
	if from_owner.has_method("update_mass"):
		from_owner.update_mass()
	if to_owner.has_method("calculate_total_weight"):
		to_owner.calculate_total_weight()
	if to_owner.has_method("update_mass"):
		to_owner.update_mass()
	refresh()


func _on_sort_toggle(which: SortColumn) -> void:
	if _sort_column == which:
		_sort_ascending = not _sort_ascending
	else:
		_sort_column = which
		_sort_ascending = true
	_update_sort_button_icons()
	var sel_name := ""
	if _selected_row_index >= 0 and _selected_row_index < _entries.size():
		sel_name = _entries[_selected_row_index].item_name
	_apply_sort_to_entries()
	_fill_item_list_rows()
	var new_idx := 0
	if sel_name != "":
		for j in range(_entries.size()):
			if _entries[j].item_name == sel_name:
				new_idx = j
				break
	if _entries.size() > 0:
		_select_index(new_idx)
	else:
		_selected_row_index = -1


func refresh() -> void:
	if _item_list == null:
		return
	for tw in _row_hover_tweens.values():
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
	_row_hover_tweens.clear()
	for c in _item_list.get_children():
		c.queue_free()
	_entries.clear()
	_clear_detail_panel()
	_selected_row_index = -1
	_resolve_known_owners()
	_update_manifest_title()

	if _inventory_owner == null:
		update_total_manifest_weight()
		_update_sort_button_icons()
		return

	var inv: Variant = _inventory_owner.get("inventory_list")
	if inv == null:
		update_total_manifest_weight()
		_update_sort_button_icons()
		return

	for it in inv:
		if it is ItemResource:
			_entries.append(it)

	_apply_sort_to_entries()
	_fill_item_list_rows()

	update_total_manifest_weight()
	_update_sort_button_icons()
	if _entries.size() > 0:
		_select_index(0)
	else:
		_set_action_list_visible(false)


func _resolve_known_owners() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if _player_owner == null or not is_instance_valid(_player_owner):
		_player_owner = scene.get_node_or_null("Player") as CharacterBody3D
	if _cart_owner == null or not is_instance_valid(_cart_owner):
		_cart_owner = scene.get_node_or_null("Cart") as RigidBody3D


func _update_manifest_title() -> void:
	if _btn_manifest == null:
		return
	if _inventory_owner != null and _player_owner != null and _inventory_owner == _player_owner:
		_btn_manifest.text = "PLAYER INVENTORY"
	else:
		_btn_manifest.text = "CART INVENTORY"


func _transfer_target_owner() -> Node:
	_resolve_known_owners()
	if not _is_player_near_cart():
		return null
	if _inventory_owner == null:
		return null
	if _player_owner != null and _inventory_owner == _player_owner:
		return _cart_owner
	if _cart_owner != null and _inventory_owner == _cart_owner:
		return _player_owner
	return null


func _update_transfer_button_state() -> void:
	if _transfer_button == null:
		return
	if _action_list == null or not _action_list.visible:
		_transfer_button.visible = false
		return
	var target := _transfer_target_owner()
	var can_transfer := _selected_entry() != null and target != null and is_instance_valid(target)
	_transfer_button.visible = can_transfer
	if not can_transfer:
		return
	if _player_owner != null and target == _player_owner:
		_transfer_button.text = "[ TRANSFER TO PLAYER ]"
	else:
		_transfer_button.text = "[ TRANSFER TO CART ]"


func _is_player_near_cart() -> bool:
	if _player_owner == null or _cart_owner == null:
		return false
	if bool(_player_owner.get("is_pushing")):
		return true
	if _cart_owner.has_method("is_player_in_grab_range"):
		return bool(_cart_owner.call("is_player_in_grab_range", _player_owner))
	return false


func _try_toggle_inventory_owner() -> void:
	_resolve_known_owners()
	if _player_owner == null or _cart_owner == null:
		return
	if not _is_player_near_cart():
		return
	if _inventory_owner == _cart_owner:
		_inventory_owner = _player_owner
	else:
		_inventory_owner = _cart_owner
	_update_manifest_title()
	refresh()


func _make_inventory_row(entry: ItemResource, row_idx: int) -> Control:
	var rc := _rarity_color(entry.rarity)
	var shell := Control.new()
	shell.name = "Row_%d" % row_idx
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.custom_minimum_size.y = 34

	var highlight := ColorRect.new()
	highlight.name = "HighlightBar"
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.z_index = 10
	highlight.visible = false
	highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	highlight.offset_left = 0.0
	highlight.offset_top = 0.0
	highlight.offset_right = 0.0
	highlight.offset_bottom = 0.0
	highlight.color = Color(ROW_HOVER_GOLD.r, ROW_HOVER_GOLD.g, ROW_HOVER_GOLD.b, 0.0)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", COL_H_SEP)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.z_index = 20
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 0.0
	h.offset_top = 0.0
	h.offset_right = 0.0
	h.offset_bottom = 0.0

	var row_lead := Control.new()
	row_lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_lead.custom_minimum_size = Vector2(NAME_COL_LEFT_INSET, 0)

	var name_lbl := Label.new()
	name_lbl.text = entry.item_name
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.clip_text = false
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", _name_row_font_size(entry.item_name))
	name_lbl.add_theme_color_override("font_color", rc)

	var cat_lbl := Label.new()
	cat_lbl.text = _category_symbol(entry.category)
	cat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_lbl.custom_minimum_size = Vector2(META_LABEL_MIN_WIDTH, 0)
	cat_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_lbl.add_theme_font_size_override("font_size", ROW_META_FONT_SZ)
	cat_lbl.add_theme_color_override("font_color", Color.WHITE)
	var cat_pad := Control.new()
	cat_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cat_pad.custom_minimum_size = Vector2(SORT_BTN_WIDTH, 0)

	var cat_cell := HBoxContainer.new()
	cat_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cat_cell.add_theme_constant_override("separation", SORT_HDR_INNER_SEP)
	cat_cell.custom_minimum_size = Vector2(0, 0)
	cat_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_cell.size_flags_stretch_ratio = META_COL_STRETCH
	cat_cell.add_child(cat_lbl)
	cat_cell.add_child(cat_pad)

	var qty_lbl := Label.new()
	qty_lbl.text = str(entry.quantity).lpad(3, " ")
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_lbl.custom_minimum_size = Vector2(META_LABEL_MIN_WIDTH, 0)
	qty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qty_lbl.add_theme_font_size_override("font_size", ROW_META_FONT_SZ)
	qty_lbl.add_theme_color_override("font_color", Color.WHITE)
	var qty_pad := Control.new()
	qty_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qty_pad.custom_minimum_size = Vector2(SORT_BTN_WIDTH, 0)

	var qty_cell := HBoxContainer.new()
	qty_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qty_cell.add_theme_constant_override("separation", SORT_HDR_INNER_SEP)
	qty_cell.custom_minimum_size = Vector2(0, 0)
	qty_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qty_cell.size_flags_stretch_ratio = META_COL_STRETCH
	qty_cell.add_child(qty_lbl)
	qty_cell.add_child(qty_pad)

	var wt_lbl := Label.new()
	wt_lbl.text = _format_weight_smart(entry.weight_lbs).lpad(6, " ")
	wt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wt_lbl.custom_minimum_size = Vector2(META_LABEL_MIN_WIDTH, 0)
	wt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wt_lbl.add_theme_font_size_override("font_size", ROW_META_FONT_SZ)
	wt_lbl.add_theme_color_override("font_color", Color.WHITE)
	var wt_pad := Control.new()
	wt_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wt_pad.custom_minimum_size = Vector2(SORT_BTN_WIDTH, 0)

	var wt_cell := HBoxContainer.new()
	wt_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wt_cell.add_theme_constant_override("separation", SORT_HDR_INNER_SEP)
	wt_cell.custom_minimum_size = Vector2(0, 0)
	wt_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wt_cell.size_flags_stretch_ratio = META_COL_STRETCH
	wt_cell.add_child(wt_lbl)
	wt_cell.add_child(wt_pad)

	var val_lbl := Label.new()
	val_lbl.text = ("%.2f" % entry.value_usd).lpad(7, " ")
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.custom_minimum_size = Vector2(META_LABEL_MIN_WIDTH, 0)
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_lbl.add_theme_font_size_override("font_size", ROW_META_FONT_SZ)
	val_lbl.add_theme_color_override("font_color", Color.WHITE)
	var val_pad := Control.new()
	val_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	val_pad.custom_minimum_size = Vector2(SORT_BTN_WIDTH, 0)

	var val_cell := HBoxContainer.new()
	val_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	val_cell.add_theme_constant_override("separation", SORT_HDR_INNER_SEP)
	val_cell.custom_minimum_size = Vector2(0, 0)
	val_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_cell.size_flags_stretch_ratio = META_COL_STRETCH
	val_cell.add_child(val_lbl)
	val_cell.add_child(val_pad)

	h.add_child(row_lead)
	name_lbl.size_flags_stretch_ratio = NAME_COL_STRETCH
	h.add_child(name_lbl)
	h.add_child(cat_cell)
	h.add_child(qty_cell)
	h.add_child(wt_cell)
	h.add_child(val_cell)

	shell.add_child(highlight)
	shell.add_child(h)

	var row_idx_captured := row_idx
	shell.gui_input.connect(func (ev: InputEvent): _handle_row_click(ev, row_idx_captured))
	shell.mouse_entered.connect(func (): _on_row_highlight_hover(highlight, row_idx_captured, true))
	shell.mouse_exited.connect(func (): _on_row_highlight_hover(highlight, row_idx_captured, false))

	return shell


func _start_row_pulse(highlight: ColorRect, col_hi: Color, col_lo: Color) -> void:
	_row_pulse_targets[highlight] = [col_hi, col_lo]
	_run_row_pulse_once(highlight, col_hi, col_lo)


func _run_row_pulse_once(highlight: ColorRect, col_hi: Color, col_lo: Color) -> void:
	if not is_instance_valid(highlight):
		return
	highlight.visible = true
	highlight.color = col_lo
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(highlight, "color", col_hi, ROW_HOVER_PULSE_SEC)
	tw.tween_property(highlight, "color", col_lo, ROW_HOVER_PULSE_SEC)
	tw.finished.connect(_on_row_pulse_finished.bind(highlight.get_instance_id()))
	_row_hover_tweens[highlight] = tw


func _on_row_pulse_finished(highlight_id: int) -> void:
	var obj := instance_from_id(highlight_id)
	var highlight := obj as ColorRect
	if highlight == null or not is_instance_valid(highlight):
		return
	if not _row_pulse_targets.has(highlight):
		_row_hover_tweens.erase(highlight)
		return
	var colors: Array = _row_pulse_targets[highlight]
	if colors.size() < 2:
		_row_pulse_targets.erase(highlight)
		_row_hover_tweens.erase(highlight)
		return
	var hi: Color = colors[0]
	var lo: Color = colors[1]
	_run_row_pulse_once(highlight, hi, lo)


func _set_row_selected_highlight(highlight: ColorRect, selected: bool) -> void:
	if not is_instance_valid(highlight):
		return
	var prev: Tween = _row_hover_tweens.get(highlight, null)
	if prev is Tween and (prev as Tween).is_valid():
		(prev as Tween).kill()
	if selected:
		var sel_hi := Color(ROW_SELECTED_COLOR.r, ROW_SELECTED_COLOR.g, ROW_SELECTED_COLOR.b, ROW_SELECTED_ALPHA)
		var sel_lo := Color(ROW_SELECTED_COLOR.r, ROW_SELECTED_COLOR.g, ROW_SELECTED_COLOR.b, ROW_SELECTED_ALPHA_LO)
		_start_row_pulse(highlight, sel_hi, sel_lo)
	else:
		_row_pulse_targets.erase(highlight)
		highlight.visible = false
		highlight.color = Color(ROW_HOVER_GOLD.r, ROW_HOVER_GOLD.g, ROW_HOVER_GOLD.b, 0.0)


func _refresh_selected_row_highlight() -> void:
	if _item_list == null:
		return
	for i in range(_item_list.get_child_count()):
		var row := _item_list.get_child(i) as Control
		if row == null:
			continue
		var h := row.get_node_or_null("HighlightBar") as ColorRect
		if h == null:
			continue
		_set_row_selected_highlight(h, i == _selected_row_index)


func _on_row_highlight_hover(highlight: ColorRect, row_idx: int, hover: bool) -> void:
	if not is_instance_valid(highlight):
		return
	var prev: Tween = _row_hover_tweens.get(highlight, null)
	if prev is Tween and (prev as Tween).is_valid():
		(prev as Tween).kill()

	var gold_hi := Color(ROW_HOVER_GOLD.r, ROW_HOVER_GOLD.g, ROW_HOVER_GOLD.b, ROW_HOVER_ALPHA_HI)
	var gold_lo := Color(ROW_HOVER_GOLD.r, ROW_HOVER_GOLD.g, ROW_HOVER_GOLD.b, ROW_HOVER_ALPHA_LO)
	var sel_hi := Color(ROW_SELECTED_COLOR.r, ROW_SELECTED_COLOR.g, ROW_SELECTED_COLOR.b, ROW_SELECTED_ALPHA)
	var sel_lo := Color(ROW_SELECTED_COLOR.r, ROW_SELECTED_COLOR.g, ROW_SELECTED_COLOR.b, ROW_SELECTED_ALPHA_LO)

	if hover:
		if row_idx == _selected_row_index:
			_start_row_pulse(highlight, sel_hi, sel_lo)
		else:
			_start_row_pulse(highlight, gold_hi, gold_lo)
	else:
		if row_idx == _selected_row_index:
			_set_row_selected_highlight(highlight, true)
			return
		_row_pulse_targets.erase(highlight)
		var tw2 := create_tween()
		tw2.set_trans(Tween.TRANS_QUAD)
		tw2.set_ease(Tween.EASE_IN)
		var cend := Color(ROW_HOVER_GOLD.r, ROW_HOVER_GOLD.g, ROW_HOVER_GOLD.b, 0.0)
		tw2.tween_property(highlight, "color", cend, 0.14)
		tw2.finished.connect(func (): _hide_highlight_if_done(highlight))
		_row_hover_tweens[highlight] = tw2


func _hide_highlight_if_done(highlight: ColorRect) -> void:
	if not is_instance_valid(highlight):
		return
	if highlight.color.a <= 0.02:
		highlight.visible = false
		highlight.color = Color(ROW_HOVER_GOLD.r, ROW_HOVER_GOLD.g, ROW_HOVER_GOLD.b, 0.0)


func _handle_row_click(ev: InputEvent, row_idx: int) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_select_index(row_idx)


func _select_index(idx: int) -> void:
	if idx < 0 or idx >= _entries.size():
		return
	_set_action_list_visible(false)
	_selected_row_index = idx
	var entry := _entries[idx]
	var rc := _rarity_color(entry.rarity)

	_detail_name.text = entry.item_name
	_detail_name.add_theme_color_override("font_color", rc)

	_detail_rarity.text = (
		"[color=%s][b]%s[/b][/color]" % [rc.to_html(false), _rarity_display_string(entry.rarity)]
	)
	_detail_category.text = "Category: %s" % _category_display_string(entry.category)
	_detail_category.add_theme_color_override("font_color", Color.WHITE)

	_detail_weight.text = "WT: %s lb" % _format_weight_smart(entry.weight_lbs)
	_detail_weight.add_theme_color_override("font_color", Color.WHITE)
	_detail_value.text = "$%.2f" % entry.value_usd
	_detail_value.add_theme_color_override("font_color", Color.WHITE)

	_detail_description.text = entry.description
	_detail_description.add_theme_color_override("font_color", Color.WHITE)

	if _detail_booth != null and _detail_booth.has_method("set_item_resource"):
		_detail_booth.call("set_item_resource", entry)
		if _detail_icon != null:
			_detail_icon.visible = false
	elif entry.icon != null:
		_detail_icon.texture = entry.icon
		_detail_icon.visible = true
	else:
		_detail_icon.texture = _get_placeholder_preview_texture()
		_detail_icon.visible = true
	_set_action_list_visible(true)
	_refresh_selected_row_highlight()


func _clear_detail_panel() -> void:
	if _detail_name == null:
		return
	_detail_name.text = ""
	_detail_name.add_theme_color_override("font_color", Color.WHITE)
	_detail_rarity.text = ""
	_detail_rarity.add_theme_color_override("default_color", Color.WHITE)
	_detail_category.text = ""
	_detail_category.add_theme_color_override("font_color", Color.WHITE)
	_detail_weight.text = ""
	_detail_weight.add_theme_color_override("font_color", Color.WHITE)
	_detail_value.text = ""
	_detail_value.add_theme_color_override("font_color", Color.WHITE)
	_detail_description.text = ""
	_detail_description.add_theme_color_override("font_color", Color.WHITE)
	if _detail_booth != null and _detail_booth.has_method("set_item_resource"):
		_detail_booth.call("set_item_resource", null)
		if _detail_icon != null:
			_detail_icon.visible = false
	else:
		_detail_icon.texture = _get_placeholder_preview_texture()
		_detail_icon.visible = true
	_set_action_list_visible(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_set_action_list_visible(false)


func _make_temp_item_preview_texture() -> Texture2D:
	var w := 96
	var h := 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.1, 0.1, 1.0))
	for y in range(h):
		for x in range(w):
			var border := x < 2 or y < 2 or x >= w - 2 or y >= h - 2
			if border:
				img.set_pixel(x, y, Color.WHITE)
			elif (x + y) % 10 == 0:
				img.set_pixel(x, y, Color(0.7, 0.7, 0.7, 1.0))
	var tex := ImageTexture.create_from_image(img)
	return tex


func _get_placeholder_preview_texture() -> Texture2D:
	if _placeholder_preview_tex == null:
		_placeholder_preview_tex = _make_temp_item_preview_texture()
	return _placeholder_preview_tex


func _rarity_display_string(r: ItemResource.Rarity) -> String:
	match r:
		ItemResource.Rarity.GREEN:
			return "GREEN"
		ItemResource.Rarity.BLUE:
			return "BLUE"
		ItemResource.Rarity.PURPLE:
			return "PURPLE"
		ItemResource.Rarity.GOLD:
			return "GOLD"
	return "UNKNOWN"


func _category_display_string(c: ItemResource.Category) -> String:
	match c:
		ItemResource.Category.FOOD:
			return "Food"
		ItemResource.Category.UTILITY:
			return "Utility"
		ItemResource.Category.WEAPON:
			return "Weapon"
		ItemResource.Category.CLOTHING:
			return "Clothing"
	return "Unknown"


func _category_symbol(c: ItemResource.Category) -> String:
	match c:
		ItemResource.Category.FOOD:
			return "■"
		ItemResource.Category.UTILITY:
			return "▲"
		ItemResource.Category.WEAPON:
			return "●"
		ItemResource.Category.CLOTHING:
			return "■"
	return "?"


func _name_row_font_size(item_name: String) -> int:
	var n := item_name.length()
	if n > 20:
		return 9
	if n > 14:
		return 10
	return 11


func _rarity_color(r: ItemResource.Rarity) -> Color:
	match r:
		ItemResource.Rarity.GREEN:
			return Color(0.2, 1.0, 0.45)
		ItemResource.Rarity.BLUE:
			return Color(0.4, 0.75, 1.0)
		ItemResource.Rarity.PURPLE:
			return Color(0.86, 0.45, 1.0)
		ItemResource.Rarity.GOLD:
			return Color(1.0, 0.86, 0.22)
	return Color.WHITE
