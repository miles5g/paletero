extends Control

## Centered terminal-style cluster for NPC interaction (below MasterHUD z_index).

signal cart_inventory_pressed
signal player_inventory_pressed
signal talk_pressed
signal close_requested


func _ready() -> void:
	visible = false
	# Let clicks pass through outside the panel (no fullscreen dim / modal blocker).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -172.0
	panel.offset_top = -132.0
	panel.offset_right = 172.0
	panel.offset_bottom = 132.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "> CLIENT TERMINAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Select inventory channel or dialogue."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 0.88))
	vbox.add_child(sub)

	vbox.add_child(_make_btn("[ CART INVENTORY ]", func() -> void: cart_inventory_pressed.emit()))
	vbox.add_child(_make_btn("[ PLAYER INVENTORY ]", func() -> void: player_inventory_pressed.emit()))
	vbox.add_child(_make_btn("[ TALK ]", func() -> void: talk_pressed.emit()))
	vbox.add_child(_make_btn("[ CLOSE ]", func() -> void: close_requested.emit()))

	add_child(panel)


func _make_btn(txt: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(on_press)
	return b


func open_terminal() -> void:
	visible = true


func close_terminal() -> void:
	visible = false
