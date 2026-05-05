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

var _sort_column: SortColumn = SortColumn.NAME
var _sort_ascending: bool = true
var _selected_row_index: int = -1

var _item_list: VBoxContainer
var _total_money_label: Label
var _total_weight_label: Label
var _detail_icon: TextureRect
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
var _btn_manifest: Button
var _btn_stats: Button
var _btn_map: Button
var _right_panel: Control
var _manifest_page: Control
var _stats_page: Control
var _map_page: Control
var _active_section: Section = Section.MANIFEST

var _cart: RigidBody3D = null
var _entries: Array[ItemResource] = []

var _row_hover_tweens: Dictionary = {}


func _ready() -> void:
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
	_btn_manifest = get_node("OuterMargin/MainContainer/LeftRailPanel/LeftRail/BtnManifest") as Button
	_btn_stats = get_node("OuterMargin/MainContainer/LeftRailPanel/LeftRail/BtnStats") as Button
	_btn_map = get_node("OuterMargin/MainContainer/LeftRailPanel/LeftRail/BtnMap") as Button
	_right_panel = get_node_or_null("OuterMargin/MainContainer/RightPanel") as Control
	_manifest_page = get_node("OuterMargin/MainContainer/CenterPanel/CenterColumn") as Control
	_ensure_section_pages()
	if _detail_icon and _detail_icon.texture == null:
		_detail_icon.texture = _make_temp_item_preview_texture()
		_detail_icon.visible = true
	_set_action_list_visible(false)
	call_deferred("_deferred_after_world_theme")


func _deferred_after_world_theme() -> void:
	_style_list_headers()
	_style_sort_buttons()
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
		var map_box := _make_empty_section_page("MAP (EMPTY)")
		map_box.name = "MapPage"
		center_panel.add_child(map_box)
		_map_page = map_box


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
	var mapping := {
		_btn_manifest: Section.MANIFEST,
		_btn_stats: Section.STATS,
		_btn_map: Section.MAP,
	}
	for b in mapping.keys():
		if b == null:
			continue
		var sec: Section = mapping[b]
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
	_cart = cart
	update_total_manifest_weight()


func update_total_manifest_weight() -> void:
	if _total_money_label == null and _total_weight_label == null:
		return
	var total_w := 0.0
	var total_money := 0.0
	if _cart != null:
		var inv: Variant = _cart.get("inventory_list")
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


func _selected_entry() -> ItemResource:
	if _selected_row_index < 0 or _selected_row_index >= _entries.size():
		return null
	return _entries[_selected_row_index]


func _remove_selected_item_from_cart() -> ItemResource:
	if _cart == null:
		return null
	var entry := _selected_entry()
	if entry == null:
		return null
	var inv: Variant = _cart.get("inventory_list")
	if inv == null:
		return null
	var list := inv as Array
	var idx := list.find(entry)
	if idx >= 0:
		list.remove_at(idx)
	if _cart.has_method("calculate_total_weight"):
		_cart.calculate_total_weight()
	if _cart.has_method("update_mass"):
		_cart.update_mass()
	return entry


func _spawn_dropped_placeholder(item_name: String) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := scene.get_node_or_null("Player") as Node3D
	if player == null:
		return
	var box := CSGBox3D.new()
	box.name = "Dropped_%s" % item_name.replace(" ", "_")
	box.size = Vector3(0.35, 0.2, 0.35)
	box.global_position = player.global_position + Vector3(0, 0.6, 0)
	scene.add_child(box)


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
	_spawn_dropped_placeholder(removed.item_name)
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

	if _cart == null:
		update_total_manifest_weight()
		_update_sort_button_icons()
		return

	var inv: Variant = _cart.get("inventory_list")
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
	highlight.visible = true
	highlight.color = col_lo
	var tw := create_tween()
	tw.set_loops(-1)
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(highlight, "color", col_hi, ROW_HOVER_PULSE_SEC)
	tw.tween_property(highlight, "color", col_lo, ROW_HOVER_PULSE_SEC)
	_row_hover_tweens[highlight] = tw


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

	if entry.icon != null:
		_detail_icon.texture = entry.icon
		_detail_icon.visible = true
	else:
		_detail_icon.texture = _make_temp_item_preview_texture()
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
	_detail_icon.texture = _make_temp_item_preview_texture()
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
