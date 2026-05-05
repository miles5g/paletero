extends Panel

var _item_list: VBoxContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_rarity: RichTextLabel
var _detail_weight: Label
var _detail_value: Label
var _detail_description: Label

var _cart: RigidBody3D = null
var _entries: Array[ItemResource] = []


func _ready() -> void:
	_apply_panel_borders()
	_item_list = get_node("OuterMargin/MainContainer/CenterPanel/CenterList/ItemListVBox") as VBoxContainer
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
	call_deferred("_deferred_typography")


func _deferred_typography() -> void:
	# Applied after world applies the global terminal font size so the title stays large.
	if _detail_name:
		_detail_name.add_theme_font_size_override("font_size", 17)


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
	var scroll_center := get_node_or_null("OuterMargin/MainContainer/CenterPanel/CenterList") as ScrollContainer
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
		var row := RichTextLabel.new()
		row.bbcode_enabled = true
		row.scroll_active = false
		row.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.fit_content = true
		row.custom_minimum_size = Vector2(0, 20)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.focus_mode = Control.FOCUS_NONE
		var name_hex := _rarity_hex(entry.rarity)
		row.text = (
			"[color=%s]%s[/color]  ×%d  [%s]"
			% [name_hex, entry.item_name, entry.quantity, _rarity_abbrev(entry.rarity)]
		)
		var row_idx := i
		row.gui_input.connect(func (ev: InputEvent): _handle_row_click(ev, row_idx))
		_item_list.add_child(row)
		i += 1

	if _entries.size() > 0:
		_select_index(0)


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


func _rarity_hex(r: ItemResource.Rarity) -> String:
	return _rarity_color(r).to_html(false)


func _rarity_abbrev(r: ItemResource.Rarity) -> String:
	match r:
		ItemResource.Rarity.GREEN:
			return "G"
		ItemResource.Rarity.BLUE:
			return "B"
		ItemResource.Rarity.PURPLE:
			return "P"
		ItemResource.Rarity.GOLD:
			return "Au"
		_:
			return "?"
