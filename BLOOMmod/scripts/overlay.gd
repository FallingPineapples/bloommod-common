static var HACKS = ['overlay']
static var default_enable_overlay = (not OS.has_feature('movie'))
static var bloom

# why godot. why.
static var _self = preload('res://BLOOMmod/scripts/overlay.gd')

static var overlay_toasts = []

static func loaded():
	bloom.toast.connect(_self._on_toast)

static func _on_toast(text):
	overlay_toasts.append(text)
	bloom.get_tree().create_timer(2.0).timeout.connect(_self._on_toast_timeout)

static func _on_toast_timeout():
	overlay_toasts.pop_front()

static func tree_enable_overlay(tree):
	var hack_layer = tree.root.get_node(^'HackLayer')
	var label = Label.new()
	label.name = &'overlay'
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.offset_left = 10.0
	label.offset_top = 10.0
	label.offset_right = 600.0
	label.offset_bottom = 700.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_override(&'font', preload('res://BLOOMmod/CourierPrime-Regular.ttf'))
	label.add_theme_font_size_override(&'font_size', 26)
	label.add_theme_constant_override(&'outline_size', 14)
	label.add_theme_color_override(&'font_outline_color', Color.BLACK)
	hack_layer.add_child(label)

static func tree_disable_overlay(tree):
	var hack_layer = tree.root.get_node(^'HackLayer')
	var label = hack_layer.get_node_or_null(^'overlay')
	if not label:
		return
	hack_layer.remove_child(label)
	label.queue_free()

static func tree_render_overlay(tree):
	var hack_layer = tree.root.get_node(^'HackLayer')
	var label = hack_layer.get_node_or_null(^'overlay')
	if not label:
		return
	var state = []
	state.append(str(bloom.target_frame))
	state.append("paused" if bloom.paused else "running")
	state.append("x" + str(bloom.current_speed * (-1 if bloom.reverse else 1)))
	if bloom.recording:
		state.append("recording")
	var data = [' '.join(state)] + overlay_toasts
	label.text = '\n'.join(data)
