extends Panel

var _item_list: VBoxContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_description: Label
var _detail_weight: Label
var _detail_value: Label
var _cart: RigidBody3D = null
var _entries: Array[ItemResource] = []


func _ready() -> void:
	_item_list = get_node("MarginContainer/HSplitContainer/ScrollContainer/ItemListVBox") as VBoxContainer
	_detail_icon = get_node("MarginContainer/HSplitContainer/DetailsColumn/DetailIcon") as TextureRect
	_detail_name = get_node("MarginContainer/HSplitContainer/DetailsColumn/DetailName") as Label
	_detail_description = get_node("MarginContainer/HSplitContainer/DetailsColumn/DetailDescription") as Label
	_detail_weight = get_node("MarginContainer/HSplitContainer/DetailsColumn/DetailWeight") as Label
	_detail_value = get_node("MarginContainer/HSplitContainer/DetailsColumn/DetailValue") as Label


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
		var btn := Button.new()
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = _format_row(entry)
		var idx := i
		btn.pressed.connect(func (): _select_index(idx))
		_item_list.add_child(btn)
		i += 1

	if _entries.size() > 0:
		_select_index(0)


func _select_index(idx: int) -> void:
	if idx < 0 or idx >= _entries.size():
		return
	var entry := _entries[idx]
	_detail_name.text = entry.item_name
	_detail_description.text = entry.description
	_detail_weight.text = "Weight: %.2f lb" % entry.weight_lbs
	_detail_value.text = "Value: $%.2f" % entry.value_usd
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
	_detail_description.text = ""
	_detail_weight.text = ""
	_detail_value.text = ""
	_detail_icon.texture = null
	_detail_icon.visible = false


func _format_row(entry: ItemResource) -> String:
	var rarity_short := _rarity_abbrev(entry.rarity)
	return "%s ×%d  [%s]" % [entry.item_name, entry.quantity, rarity_short]


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
