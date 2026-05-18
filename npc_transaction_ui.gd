extends Control

## Centered terminal-style cluster for NPC interaction (below MasterHUD z_index).

signal cart_inventory_pressed
signal player_inventory_pressed
signal talk_pressed

var _title_label: Label = null
var _panel: Panel = null
var _content_vbox: VBoxContainer = null
var _panel_sb: StyleBoxFlat = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_sb = StyleBoxFlat.new()
	_panel_sb.bg_color = Color(0, 0, 0, 0)
	_panel_sb.border_width_left = 2
	_panel_sb.border_width_top = 2
	_panel_sb.border_width_right = 2
	_panel_sb.border_width_bottom = 2
	_panel_sb.border_color = Color(0.42, 0.36, 0.18, 1.0)
	_panel_sb.content_margin_left = 12
	_panel_sb.content_margin_top = 10
	_panel_sb.content_margin_right = 12
	_panel_sb.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", _panel_sb)
	center.add_child(_panel)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 6)
	_content_vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content_vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_panel.add_child(_content_vbox)

	_title_label = Label.new()
	_title_label.text = "> Cliente"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.custom_minimum_size.x = 200.0
	_content_vbox.add_child(_title_label)

	_content_vbox.add_child(_make_btn("[ CART INVENTORY ]", func() -> void: cart_inventory_pressed.emit()))
	_content_vbox.add_child(_make_btn("[ PLAYER INVENTORY ]", func() -> void: player_inventory_pressed.emit()))
	_content_vbox.add_child(_make_btn("[ TALK ]", func() -> void: talk_pressed.emit()))

	call_deferred("_fit_npc_terminal_panel_size")


func _fit_npc_terminal_panel_size() -> void:
	if _panel == null or _content_vbox == null or _panel_sb == null:
		return
	await get_tree().process_frame
	var ms: Vector2 = _content_vbox.get_combined_minimum_size()
	if ms.x < 2.0 or ms.y < 2.0:
		return
	_panel.custom_minimum_size = Vector2(
		ms.x + _panel_sb.content_margin_left + _panel_sb.content_margin_right,
		ms.y + _panel_sb.content_margin_top + _panel_sb.content_margin_bottom
	)


func _make_btn(txt: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(on_press)
	return b


func open_terminal(character_name: String = "") -> void:
	if _title_label != null:
		var n := character_name.strip_edges()
		if n.is_empty():
			n = "Cliente"
		_title_label.text = "> %s" % n
	visible = true
	call_deferred("_fit_npc_terminal_panel_size")


func close_terminal() -> void:
	visible = false
