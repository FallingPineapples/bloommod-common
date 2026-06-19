static func get_input(inputs: Array[Array], frame: int) -> Array:
	if frame >= len(inputs):
		return []
	return inputs[frame]

static func get_action(inputs: Array[Array], frame: int, action) -> bool:
	for f in range(frame, -1, -1):
		var data = inputs[f]
		for i in range(len(data) - 1, -1, -1):
			var event = data[i]
			if event_matches(event, action):
				return event_pressed(event)
	return false

static func toggle_action(inputs: Array[Array], frame: int, action) -> bool:
	var value = not get_action(inputs, frame, action)
	_update_edge(inputs, frame, action, value, false)
	_update_edge(inputs, frame, action, value, true)
	return value

static func set_actions(inputs: Array[Array], frame_from: int, frame_to: int, action, value: bool) -> void:
	if frame_from > frame_to:
		var tmp = frame_from
		frame_from = frame_to
		frame_to = tmp
	var old_from = get_action(inputs, frame_from, action)
	var old_to = get_action(inputs, frame_to, action)
	if value != old_from:
		_update_edge(inputs, frame_from, action, value, false)
	for frame in range(frame_from + 1, frame_to + 1):
		inputs[frame] = inputs[frame].filter(func(event):
			return not event_matches(event, action)
		)
	if value != old_to:
		_update_edge(inputs, frame_to, action, value, true)

static func get_swift_action(inputs: Array[Array], frame: int, action) -> bool:
	var count = 0
	var data = inputs[frame]
	for i in range(len(data) - 1, -1, -1):
		if event_matches(data[i], action):
			count += 1
	return (count >= 2)

static func _add_swift_action(inputs: Array[Array], frame: int, action) -> void:
	var end_value = get_action(inputs, frame, action)
	for i in range(2):
		var event = make_event(action, end_value == bool(i))
		inputs[frame].append(event)

static func _remove_swift_action(inputs: Array[Array], frame: int, action) -> void:
	var count = {&'v': 0} # box for lambda capture by reference
	inputs[frame] = inputs[frame].filter(func(event):
		if (count.v >= 2) or (not event_matches(event, action)):
			return true
		count.v += 1
		return false
	)

static func set_swift_action(inputs: Array[Array], frame: int, action, value: bool) -> void:
	var old_value = get_swift_action(inputs, frame, action)
	if old_value != value:
		if value:
			_add_swift_action(inputs, frame, action)
		else:
			_remove_swift_action(inputs, frame, action)

static func toggle_swift_action(inputs: Array[Array], frame: int, action) -> bool:
	if get_swift_action(inputs, frame, action):
		_remove_swift_action(inputs, frame, action)
		return false
	else:
		_add_swift_action(inputs, frame, action)
		return true

# TODO: make this not remove swift presses as often?
static func _update_edge(inputs: Array[Array], frame: int, action, value: bool, trailing: bool) -> void:
	if frame + int(trailing) >= len(inputs):
		return
	var data = inputs[frame + int(trailing)]
	var order = range(len(data)) if trailing else range(len(data)-1, -1, -1)
	for i in order:
		if event_matches(data[i], action):
			data.pop_at(i)
			return
	var event = make_event(action, value != trailing)
	if trailing:
		data.insert(0, event)
	else:
		data.append(event)

static func make_event(action, pressed: bool):
	if action is int:
		return [action, pressed]
	else:
		var event = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		return event

static func event_action(event):
	if event is Array:
		return event[0]
	else:
		return event.action

# Assumes the event is already known to match an action
static func event_pressed(event) -> bool:
	if event is Array:
		if event[1] is bool:
			return event[1]
		push_error('cannot get pressed state of custom hack event')
		return true
	else:
		return event.pressed

static func event_matches(event, action) -> bool:
	if action is int:
		if not event is Array:
			return false
		if not event[1] is bool:
			return false
		return event[0] == action
	else:
		if not event is InputEventAction:
			return false
		return event.action == action
