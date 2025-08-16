static var HACKS = ['freecam']
static var bloom

static var freecam_pos = null
static var freecam_zoom_level = -4.0

static func input_freecam(e):
	if freecam_pos == null:
		return
	var event = e as InputEventFromWindow
	if !event or not event.window_id == DisplayServer.MAIN_WINDOW_ID:
		return
	var motion = event as InputEventMouseMotion
	if motion and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_move_freecam(motion.relative)
	var button = event as InputEventMouseButton
	if button and button.pressed:
		var factor = button.factor
		if factor == 0.0:
			factor = 1.0
		# funny poll i found: https://www.reddit.com/r/cad/comments/pebw8g/zooming_in_mouse_wheel_up_or_down/
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_freecam(factor, button.global_position)
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_freecam(-factor, button.global_position)
	var pan = event as InputEventPanGesture
	if pan:
		_zoom_freecam(pan.delta.y * 0.2, pan.position)

static func _move_freecam(motion):
	var zoom = pow(1.1, freecam_zoom_level)
	freecam_pos -= motion / zoom

static func _zoom_freecam(factor, pos):
	var old_zoom = pow(1.1, freecam_zoom_level)
	freecam_zoom_level += factor
	var new_zoom = pow(1.1, freecam_zoom_level)
	var delta = bloom.get_node(^'/root').get_visible_rect().get_center() - pos
	freecam_pos += delta * (1 / new_zoom - 1 / old_zoom)

static func tree_enable_freecam(tree):
	var camera = Camera2D.new()
	camera.name = &'freecam'
	tree.root.add_child(camera)

static func tree_render_freecam(tree):
	var camera = tree.root.get_node_or_null(^'freecam')
	if not camera:
		return
	if freecam_pos == null:
		var transform = tree.root.canvas_transform
		freecam_pos = transform.affine_inverse() * tree.root.get_visible_rect().get_center()
		freecam_zoom_level = log(transform.get_scale().x) / log(1.1)
	camera.position = freecam_pos
	var zoom = pow(1.1, freecam_zoom_level)
	camera.zoom = Vector2(zoom, zoom)
	camera.make_current()

static func tree_disable_freecam(tree):
	var camera = tree.root.get_node_or_null(^'freecam')
	if not camera:
		return
	camera.enabled = false
	tree.root.remove_child(camera)
	camera.queue_free()
	var default_camera = tree.root.get_camera_2d()
	if not default_camera:
		return
	# Force camera transform update
	default_camera.notification(Node.NOTIFICATION_INTERNAL_PROCESS)
