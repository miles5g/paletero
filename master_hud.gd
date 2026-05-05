extends Panel

## Matches HeaderRow column widths in MasterHUD.tscn
const COL_QTY_WIDTH: int = 44
const COL_WT_WIDTH: int = 72
const HEADER_GREY := Color(0.42, 0.46, 0.52)
const HEADER_FONT_SZ := 11
const ROW_HOVER_MODULATE := Color(1.38, 1.38, 1.38)

var _item_list: VBoxContainer
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
	# Runs after world applies terminal theme so list headers stay grey/small.
	_style_list_headers()
	if _detail_name:
		_detail_name.add_theme_font_size_override("font_size", 17)


func _style_list_headers() -> void:
	for path in [
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrName",
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrQty",
		"OuterMargin/MainContainer/CenterPanel/CenterColumn/HeaderRow/HdrWt",
	]:
		var lab := get_node_or_null(path) as Label
		if lab:
			lab.add_theme_font_size_override("font_size", HEADER_FONT_SZ)
			lab.add_theme_color_override("font_color", HEADER_GREY)


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

	if _cart == null:
		return

	var inv: Variant = _cart.get("inventory_list")
	if inv == null:
		return

	for it in inv:
		if it is ItemResource:
			_entries.append(it)

	var i := 0
	for entry in _entries:
		var row := _make_inventory_row(entry, i)
		_item_list.add_child(row)
		i += 1

	if _entries.size() > 0:
		_select_index(0)


func _make_inventory_row(entry: ItemResource, row_idx: int) -> Control:
	var rc := _rarity_color(entry.rarity)
	var shell := Control.new()
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.custom_minimum_size.y = 26

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 4.0
	h.offset_top = 2.0
	h.offset_right = -4.0
	h.offset_bottom = -2.0

	var name_lbl := Label.new()
	name_lbl.text = entry.item_name
	name_lbl.clip_text = true
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", rc)

	var qty_lbl := Label.new()
	qty_lbl.text = str(entry.quantity)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty_lbl.custom_minimum_size = Vector2(COL_QTY_WIDTH, 0)
	qty_lbl.add_theme_color_override("font_color", Color.WHITE)

	var wt_lbl := Label.new()
	wt_lbl.text = "%.2f" % entry.weight_lbs
	wt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wt_lbl.custom_minimum_size = Vector2(COL_WT_WIDTH, 0)
	wt_lbl.add_theme_color_override("font_color", Color.WHITE)

	h.add_child(name_lbl)
	h.add_child(qty_lbl)
	h.add_child(wt_lbl)
	shell.add_child(h)

	var row_idx_captured := row_idx
	shell.gui_input.connect(func (ev: InputEvent): _handle_row_click(ev, row_idx_captured))
	shell.mouse_entered.connect(func (): _on_row_hover(shell, true))
	shell.mouse_exited.connect(func (): _on_row_hover(shell, false))

	return shell


func _on_row_hover(shell: Control, hover: bool) -> void:
	if not is_instance_valid(shell):
		return
	var tw: Tween = _row_hover_tweens.get(shell, null)
	if tw != null and tw.is_valid():
		tw.kill()
	tw = create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	var target := ROW_HOVER_MODULATE if hover else Color.WHITE
	tw.tween_property(shell, "modulate", target, 0.1)
	_row_hover_tweens[shell] = tw


func _handle_row_click(ev: InputEvent, row_idx: int) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_select_index(row_idx)


func _select_index(idx: int) -> void:
	if idx < 0 or idx >= _entries.size():
		return
	var entry := _entries[idx]
	var rc := _rarity_color(entry.rarity)

	_detail_name.text = entry.item_name
	_detail_name.add_theme_color_override("font_color", rc)

	_detail_rarity.text = (
		"[color=%s][b]%s[/b][/color]" % [rc.to_html(false), _rarity_display_string(entry.rarity)]
	)

	_detail_weight.text = "WT: %.2f lb" % entry.weight_lbs
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
