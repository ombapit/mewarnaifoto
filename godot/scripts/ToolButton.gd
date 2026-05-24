extends KidButton
class_name ToolButton

@export var icon_text: String = "★"
@export var label_text: String = ""


func _ready() -> void:
	super._ready()
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)

	var ic := Label.new()
	ic.text = icon_text
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_theme_font_size_override("font_size", 58)
	ic.add_theme_color_override("font_color", Color.WHITE)

	var lb := Label.new()
	lb.text = label_text
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.add_theme_font_size_override("font_size", 32)
	lb.add_theme_color_override("font_color", Color.WHITE)

	vb.add_child(ic)
	vb.add_child(lb)
	add_child(vb)
