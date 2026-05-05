extends Panel

enum SortColumn { NAME, QTY, WT }

## Matches HeaderRow column widths in MasterHUD.tscn (pixel-aligned with rows)
const COL_QTY_WIDTH: int = 44
const COL_H_SEP: int = 6
const COL_WT_WIDTH: int = 72
const SORT_BTN_WIDTH: int = 22
const SORT_HDR_INNER_SEP: int = 2
const SORT_NAME_BTN_SEP: int = 0
const NAME_COL_LEFT_INSET: int = 6
const COL_QTY_CELL_WIDTH: int = COL_QTY_WIDTH + SORT_HDR_INNER_SEP + SORT_BTN_WIDTH
const COL_WT_CELL_WIDTH: int = COL_WT_WIDTH + SORT_HDR_INNER_SEP + SORT_BTN_WIDTH
const HEADER_GREY := Color(0.42, 0.46, 0.52)
const HEADER_FONT_SZ := 11
const SORT_BTN_FONT_SZ := 10
const ROW_HOVER_PULSE_SEC := 0.5

const _ROW_GLOW_SHADER: Shader = preload("res://inventory_row_glow.gdshader")

var _sort_column: SortColumn = SortColumn.NAME
var _sort_ascending: bool = true
var _selected_row_index: int = -1

var _item_list: VBoxContainer
var _total_money_label: Label
var _total_weight_label: Label
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_rarity: RichTextLabel
var _detail_weight: Label
var _detail_value: Label
var _detail_description: Label

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
	_detail_icon = get_node("OuterMargin/MainContainer/RightPanel/RightDetail/TopHalf") as TextureRect
	_detail_name = get_node("OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/NameLabel") as Label
	_detail_rarity = get_node("OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/RarityLabel") as RichTextLabel
	_detail_weight = get_node(
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/StatsHBox/WeightLabel"
	) as Label
	_detail_value = get_node(
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/StatsHBox/ValueLabel"
	) as Label
	_detail_description = get_node(
		"OuterMargin/MainContainer/RightPanel/RightDetail/BottomHalf/DetailVBox/DescriptionLabel"
	) as Label
	call_deferred("_deferred_after_world_theme")


func _deferred_after_world_theme() -> void:
	_style_list_headers()
	_style_sort_buttons()
	_connect_sort_buttons()
	_update_sort_button_icons()
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
	var wt_cell := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrWtCell"
	) as HBoxContainer
	if name_cell:
		name_cell.add_theme_constant_override("separation", SORT_NAME_BTN_SEP)
	if qty_cell:
		qty_cell.add_theme_constant_override("separation", SORT_HDR_INNER_SEP)
		qty_cell.custom_minimum_size = Vector2(COL_QTY_CELL_WIDTH, 0)
	if wt_cell:
		wt_cell.add_theme_constant_override("separation", SORT_HDR_INNER_SEP)
		wt_cell.custom_minimum_size = Vector2(COL_WT_CELL_WIDTH, 0)
	var hdr_name := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrNameCell/HdrName"
	) as Label
	var hdr_qty := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrQtyCell/HdrQty"
	) as Label
	var hdr_wt := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrWtCell/HdrWt"
	) as Label
	for lab in [hdr_name, hdr_qty, hdr_wt]:
		if lab:
			lab.add_theme_font_size_override("font_size", HEADER_FONT_SZ)
			lab.add_theme_color_override("font_color", HEADER_GREY)
	if hdr_name:
		hdr_name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		hdr_name.mouse_filter = Control.MOUSE_FILTER_STOP
		hdr_name.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if hdr_qty:
		hdr_qty.custom_minimum_size = Vector2(COL_QTY_WIDTH, 0)
		hdr_qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hdr_qty.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		hdr_qty.mouse_filter = Control.MOUSE_FILTER_STOP
		hdr_qty.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if hdr_wt:
		hdr_wt.custom_minimum_size = Vector2(COL_WT_WIDTH, 0)
		hdr_wt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hdr_wt.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		hdr_wt.mouse_filter = Control.MOUSE_FILTER_STOP
		hdr_wt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _style_sort_buttons() -> void:
	var paths := [
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrNameCell/SortNameBtn",
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrQtyCell/SortQtyBtn",
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrWtCell/SortWtBtn",
	]
	for p in paths:
		var b := get_node_or_null(p) as Button
		if b:
			b.custom_minimum_size.x = SORT_BTN_WIDTH
			b.add_theme_font_size_override("font_size", SORT_BTN_FONT_SZ)
			b.add_theme_color_override("font_color", HEADER_GREY)


func _connect_sort_buttons() -> void:
	var bn := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrNameCell/SortNameBtn"
	) as Button
	var bq := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrQtyCell/SortQtyBtn"
	) as Button
	var bw := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrWtCell/SortWtBtn"
	) as Button
	var hdr_name_lab := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrNameCell/HdrName"
	) as Label
	var hdr_qty_lab := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrQtyCell/HdrQty"
	) as Label
	var hdr_wt_lab := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrWtCell/HdrWt"
	) as Label
	if bn:
		bn.pressed.connect(_on_sort_toggle.bind(SortColumn.NAME))
	if bq:
		bq.pressed.connect(_on_sort_toggle.bind(SortColumn.QTY))
	if bw:
		bw.pressed.connect(_on_sort_toggle.bind(SortColumn.WT))
	if hdr_name_lab:
		hdr_name_lab.gui_input.connect(_on_header_sort_gui_input.bind(SortColumn.NAME))
	if hdr_qty_lab:
		hdr_qty_lab.gui_input.connect(_on_header_sort_gui_input.bind(SortColumn.QTY))
	if hdr_wt_lab:
		hdr_wt_lab.gui_input.connect(_on_header_sort_gui_input.bind(SortColumn.WT))


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
	var bw := get_node_or_null(
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrWtCell/SortWtBtn"
	) as Button
	for pair in [[bn, SortColumn.NAME], [bq, SortColumn.QTY], [bw, SortColumn.WT]]:
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


func _dim_highlight_color(rc: Color) -> Color:
	var d := rc.darkened(0.58)
	d.a = 0.72
	return d


func _make_inventory_row(entry: ItemResource, row_idx: int) -> Control:
	var rc := _rarity_color(entry.rarity)
	var shell := Control.new()
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.custom_minimum_size.y = 26

	var highlight := ColorRect.new()
	highlight.name = "HighlightBar"
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.z_index = -1
	highlight.visible = false
	highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	highlight.offset_left = 0.0
	highlight.offset_top = 0.0
	highlight.offset_right = 0.0
	highlight.offset_bottom = 0.0
	var sm := ShaderMaterial.new()
	sm.shader = _ROW_GLOW_SHADER
	sm.set_shader_parameter("base_color", _dim_highlight_color(rc))
	sm.set_shader_parameter("halo_boost", 1.05)
	highlight.material = sm

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", COL_H_SEP)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	name_lbl.clip_text = true
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", rc)

	var qty_lbl := Label.new()
	qty_lbl.text = str(entry.quantity)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty_lbl.custom_minimum_size = Vector2(COL_QTY_WIDTH, 0)
	qty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qty_lbl.add_theme_color_override("font_color", Color.WHITE)
	var qty_pad := Control.new()
	qty_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qty_pad.custom_minimum_size = Vector2(SORT_BTN_WIDTH, 0)

	var qty_cell := HBoxContainer.new()
	qty_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qty_cell.add_theme_constant_override("separation", SORT_HDR_INNER_SEP)
	qty_cell.custom_minimum_size = Vector2(COL_QTY_CELL_WIDTH, 0)
	qty_cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	qty_cell.add_child(qty_lbl)
	qty_cell.add_child(qty_pad)

	var wt_lbl := Label.new()
	wt_lbl.text = _format_weight_smart(entry.weight_lbs)
	wt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wt_lbl.custom_minimum_size = Vector2(COL_WT_WIDTH, 0)
	wt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wt_lbl.add_theme_color_override("font_color", Color.WHITE)
	var wt_pad := Control.new()
	wt_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wt_pad.custom_minimum_size = Vector2(SORT_BTN_WIDTH, 0)

	var wt_cell := HBoxContainer.new()
	wt_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wt_cell.add_theme_constant_override("separation", SORT_HDR_INNER_SEP)
	wt_cell.custom_minimum_size = Vector2(COL_WT_CELL_WIDTH, 0)
	wt_cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wt_cell.add_child(wt_lbl)
	wt_cell.add_child(wt_pad)

	h.add_child(row_lead)
	h.add_child(name_lbl)
	h.add_child(qty_cell)
	h.add_child(wt_cell)

	shell.add_child(highlight)
	shell.add_child(h)

	var row_idx_captured := row_idx
	shell.gui_input.connect(func (ev: InputEvent): _handle_row_click(ev, row_idx_captured))
	shell.mouse_entered.connect(func (): _on_row_highlight_hover(highlight, rc, true))
	shell.mouse_exited.connect(func (): _on_row_highlight_hover(highlight, rc, false))

	return shell


func _on_row_highlight_hover(highlight: ColorRect, rarity_color: Color, hover: bool) -> void:
	if not is_instance_valid(highlight):
		return
	var sm := highlight.material as ShaderMaterial
	if sm:
		sm.set_shader_parameter("base_color", _dim_highlight_color(rarity_color))
	var prev: Tween = _row_hover_tweens.get(highlight, null)
	if prev is Tween and (prev as Tween).is_valid():
		(prev as Tween).kill()

	if hover:
		highlight.visible = true
		highlight.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var tw := create_tween()
		tw.set_loops(-1)
		tw.set_trans(Tween.TRANS_SINE)
		tw.set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(highlight, "modulate:a", 1.0, ROW_HOVER_PULSE_SEC)
		tw.tween_property(highlight, "modulate:a", 0.0, ROW_HOVER_PULSE_SEC)
		_row_hover_tweens[highlight] = tw
	else:
		var tw2 := create_tween()
		tw2.set_trans(Tween.TRANS_QUAD)
		tw2.set_ease(Tween.EASE_IN)
		tw2.tween_property(highlight, "modulate:a", 0.0, 0.12)
		tw2.finished.connect(func (): _hide_highlight_if_done(highlight))
		_row_hover_tweens[highlight] = tw2


func _hide_highlight_if_done(highlight: ColorRect) -> void:
	if is_instance_valid(highlight) and highlight.modulate.a <= 0.01:
		highlight.visible = false
		highlight.modulate = Color.WHITE


func _handle_row_click(ev: InputEvent, row_idx: int) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_select_index(row_idx)


func _select_index(idx: int) -> void:
	if idx < 0 or idx >= _entries.size():
		return
	_selected_row_index = idx
	var entry := _entries[idx]
	var rc := _rarity_color(entry.rarity)

	_detail_name.text = entry.item_name
	_detail_name.add_theme_color_override("font_color", rc)

	_detail_rarity.text = (
		"[color=%s][b]%s[/b][/color]" % [rc.to_html(false), _rarity_display_string(entry.rarity)]
	)

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
		_detail_icon.texture = null
		_detail_icon.visible = false


func _clear_detail_panel() -> void:
	if _detail_name == null:
		return
	_detail_name.text = ""
	_detail_name.add_theme_color_override("font_color", Color.WHITE)
	_detail_rarity.text = ""
	_detail_rarity.add_theme_color_override("default_color", Color.WHITE)
	_detail_weight.text = ""
	_detail_weight.add_theme_color_override("font_color", Color.WHITE)
	_detail_value.text = ""
	_detail_value.add_theme_color_override("font_color", Color.WHITE)
	_detail_description.text = ""
	_detail_description.add_theme_color_override("font_color", Color.WHITE)
	_detail_icon.texture = null
	_detail_icon.visible = false


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
