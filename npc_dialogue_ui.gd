extends Control

## Fallout: New Vegas–style bottom dialogue strip (speaker + body + numbered replies).

signal dialogue_closed

var _mono_font: Font = null
var _bar: Panel = null
var _speaker_label: Label = null
var _body_label: Label = null
var _choices_box: VBoxContainer = null

var _current_node_id: String = ""

const _CHOICE_ROW_H: float = 32.0
const _CHOICE_SEP: int = 6
## Vertical space for the choice list (three rows tall; a fourth option scrolls).
const _CHOICE_ROWS_SCROLL_VIEW: int = 3
const _BAR_HEIGHT_PX: float = 228.0
## Centered card width (clamped to viewport with side padding).
const _BAR_MAX_WIDTH_PX: float = 640.0
const _BAR_VIEWPORT_MARGIN_X: float = 48.0
## Minimal graph: id -> { "speaker": String, "text": String, "choices": [{ "label": String, "next": String }] }
const _GRAPH := {
	"start": {
		"speaker": "CLIENT",
		"text": "Hot day out here. You pushing paletas today, or just stretching your legs?",
		"choices": [
			{"label": "Yeah — I'm selling. Mango, lime, coconut on deck.", "next": "sell"},
			{"label": "Still stocking the cart. Give me a minute.", "next": "stock"},
			{"label": "Just passing through — maybe later.", "next": "pass"},
			{"label": "[Leave]", "next": "exit"}
		]
	},
	"sell": {
		"speaker": "CLIENT",
		"text": "Good, good. Ring me up when you've got ice on the glass — I'll take two.",
		"choices": [
			{"label": "Will do.", "next": "exit"}
		]
	},
	"stock": {
		"speaker": "CLIENT",
		"text": "Fair enough. I'll be on the sidewalk — don't make me melt out here.",
		"choices": [
			{"label": "Won't be long.", "next": "exit"}
		]
	},
	"pass": {
		"speaker": "CLIENT",
		"text": "Suit yourself. Sun doesn't wait.",
		"choices": [
			{"label": "Later.", "next": "exit"}
		]
	}
}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_root_layout()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_viewport_resized):
		vp.size_changed.connect(_on_viewport_resized)
	_mono_font = _make_mono_font()

	_bar = Panel.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = Color(0.07, 0.065, 0.055, 0.97)
	bar_sb.border_width_left = 2
	bar_sb.border_width_top = 2
	bar_sb.border_width_right = 2
	bar_sb.border_width_bottom = 2
	bar_sb.border_color = Color(0.42, 0.36, 0.18, 1.0)
	bar_sb.content_margin_left = 16
	bar_sb.content_margin_top = 10
	bar_sb.content_margin_right = 16
	bar_sb.content_margin_bottom = 10
	_bar.add_theme_stylebox_override("panel", bar_sb)
	add_child(_bar)

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 6)
	_bar.add_child(outer)

	_speaker_label = Label.new()
	_speaker_label.text = "CLIENT"
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker_label.add_theme_font_override("font", _mono_font)
	_speaker_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28, 1.0))
	_speaker_label.add_theme_font_size_override("font_size", 15)
	_speaker_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	outer.add_child(_speaker_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.text = ""
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.custom_minimum_size.y = 40.0
	_body_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_body_label.add_theme_font_override("font", _mono_font)
	_body_label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.84, 1.0))
	_body_label.add_theme_font_size_override("font_size", 14)
	outer.add_child(_body_label)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.35, 0.32, 0.26, 0.9))
	outer.add_child(sep)

	var scroll := ScrollContainer.new()
	var choices_area_h := (
		_CHOICE_ROW_H * float(_CHOICE_ROWS_SCROLL_VIEW)
		+ float(_CHOICE_SEP * maxi(0, _CHOICE_ROWS_SCROLL_VIEW - 1))
	)
	scroll.custom_minimum_size.y = choices_area_h
	# Take remaining height inside the bottom panel so the strip never collapses to zero.
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_choices_box = VBoxContainer.new()
	_choices_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_choices_box.add_theme_constant_override("separation", _CHOICE_SEP)
	scroll.add_child(_choices_box)

	_apply_bar_layout()


func open_dialogue(start_id: String = "start") -> void:
	_apply_root_layout()
	_apply_bar_layout()
	visible = true
	move_to_front()
	# One frame after becoming visible so anchors/viewport size apply before building buttons.
	call_deferred("_show_node", start_id)


func close_dialogue() -> void:
	if not visible:
		return
	visible = false
	_current_node_id = ""
	dialogue_closed.emit()


func _apply_root_layout() -> void:
	# set_anchors_preset alone keeps old offsets → Control stays tiny and draws top-left.
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT,
		Control.LayoutPresetMode.PRESET_MODE_MINSIZE,
		0
	)


func _apply_bar_layout() -> void:
	if _bar == null:
		return
	var vp := get_viewport()
	var vw: float = vp.get_visible_rect().size.x if vp != null else _BAR_MAX_WIDTH_PX
	var w: float = minf(_BAR_MAX_WIDTH_PX, vw - _BAR_VIEWPORT_MARGIN_X)
	w = maxf(w, 280.0)
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_left = -w * 0.5
	_bar.offset_right = w * 0.5
	_bar.offset_top = -_BAR_HEIGHT_PX
	_bar.offset_bottom = 0.0


func _on_viewport_resized() -> void:
	_apply_root_layout()
	_apply_bar_layout()


func _show_node(id: String) -> void:
	_current_node_id = id
	if id == "exit":
		close_dialogue()
		return
	var node: Variant = _GRAPH.get(id)
	if node == null:
		close_dialogue()
		return
	_speaker_label.text = str(node.get("speaker", "CLIENT"))
	_body_label.text = str(node.get("text", ""))
	while _choices_box.get_child_count() > 0:
		var c := _choices_box.get_child(0)
		_choices_box.remove_child(c)
		c.queue_free()
	var choices: Variant = node.get("choices", [])
	var i := 1
	for ch in choices:
		if ch is Dictionary:
			var btn := _make_choice_button(i, str(ch.get("label", "?")), str(ch.get("next", "exit")))
			_choices_box.add_child(btn)
			i += 1


func _make_choice_button(idx: int, label_text: String, next_id: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size.y = _CHOICE_ROW_H
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = "%d. %s" % [idx, label_text]
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.clip_text = true
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0.12, 0.11, 0.09, 0.95)
	flat.border_width_left = 1
	flat.border_width_top = 1
	flat.border_width_right = 1
	flat.border_width_bottom = 1
	flat.border_color = Color(0.28, 0.25, 0.2, 0.9)
	flat.content_margin_left = 10
	flat.content_margin_top = 6
	flat.content_margin_right = 10
	flat.content_margin_bottom = 6
	b.add_theme_stylebox_override("normal", flat)
	var hover := flat.duplicate()
	hover.bg_color = Color(0.18, 0.16, 0.12, 1.0)
	hover.border_color = Color(0.55, 0.48, 0.22, 1.0)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_font_override("font", _mono_font)
	b.add_theme_color_override("font_color", Color(0.82, 0.72, 0.42, 1.0))
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(func() -> void: _show_node(next_id))
	return b


func _make_mono_font() -> Font:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Consolas", "Courier New", "Courier", "monospace"])
	sys.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var fv := FontVariation.new()
	fv.base_font = sys
	return fv
