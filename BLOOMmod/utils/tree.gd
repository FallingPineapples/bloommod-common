const hacks = preload("res://BLOOMmod/hacks/manager.gd")

static func new_tree() -> SceneTree:
	var tree = SceneTree.new()
	tree.setup(ProjectSettings.get_setting("application/run/main_scene"))
	RenderingServer.viewport_set_update_mode(tree.root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_DISABLED)
	tree.set_meta(&'hacks_enabled', Array([], TYPE_BOOL, &"", null))
	hacks.call_hook_enabled('tree_create', [tree])
	return tree

static func clone_tree(from: SceneTree) -> SceneTree:
	hacks.call_hook_enabled('tree_before_clone', [from])
	var tree = from.duplicate()
	RenderingServer.viewport_set_update_mode(tree.root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_DISABLED)
	tree.set_meta(&'hacks_enabled', from.get_meta(&'hacks_enabled').duplicate())
	hacks.call_hook_enabled('tree_after_clone', [tree, from])
	return tree

static func advance_tree(tree: SceneTree, input: Array, frame:=-1) -> void:
	var input_object := tree.get_input_object()
	var input_events := convert_input_events(input)
	for event in input_events:
		if event is InputEvent:
			input_object.parse_input_event(event)
		elif event is Array:
			on_hack_event(tree, frame, event)
		else:
			push_error('unknown input type')
	hacks.call_hook_filtered('tree_before_tick', tree.get_meta(&'hacks_enabled'), [tree], frame)
	tree.frame()
	hacks.call_hook_filtered('tree_after_tick', tree.get_meta(&'hacks_enabled'), [tree], frame)

static func convert_input_events(input: Array) -> Array:
	var input_events := []
	for event in input:
		if event is InputEventAction:
			input_events.append_array(convert_action(event))
			continue
		input_events.append(event)
	return input_events

static func convert_action(input: InputEventAction) -> Array[InputEvent]:
	var events := InputMap.action_get_events(input.action)
	if len(events) <= 0:
		return []
	var event: InputEvent = events[0].duplicate()
	if event.device == -1:
		event.device = 0
	if event is InputEventKey:
		event.pressed = input.pressed
		var keycode := 0
		if event.keycode != 0:
			keycode = event.keycode
		elif event.physical_keycode != 0:
			keycode = event.physical_keycode
		event.keycode = keycode
		event.physical_keycode = keycode
		event.key_label = keycode
		if (keycode >= 0x20 and keycode != 0x7f) and keycode < 0x10ffff and not (keycode >= 0xd800 and keycode <= 0xdfff):
			event.unicode = keycode # TODO: Do this more accurately
	if event is InputEventJoypadButton:
		event.pressed = input.pressed
	# TODO: more types of events
	return [event]

static func _set_hack_enabled(tree: SceneTree, hack_id: int, value: bool) -> void:
	var data: Array[bool] = tree.get_meta(&'hacks_enabled')
	while len(data) <= hack_id:
		data.append(false)
	data[hack_id] = value

static func _get_hack_enabled(tree: SceneTree, hack_id: int) -> bool:
	var data: Array[bool] = tree.get_meta(&'hacks_enabled')
	if len(data) <= hack_id:
		return false
	return data[hack_id]

static func on_hack_event(tree: SceneTree, frame: int, event: Array) -> void:
	if event[1] is bool:
		if _get_hack_enabled(tree, event[0]) == event[1]:
			return
		_set_hack_enabled(tree, event[0], event[1])
	elif not _get_hack_enabled(tree, event[0]):
		return
	hacks.on_hack_event(tree, frame, event)
