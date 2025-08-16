extends Window

# https://www.youtube.com/watch?v=4Na0Jk2WeVw

var frame_width = 100
var main_actions = []
var main_widths = []

var hack_tab_id = 1
var hack_actions = []
var hack_widths = []
var hack_ids = {}
var hack_lookup = {}

var tab_names = []
var actions = []
var widths = []

var current_actions
var current_widths
var current_positions

var font = get_theme_default_font()
var font_size = 18
var row_height = 20

@onready var tabbar = $%TabBar
@onready var header = $%Header
@onready var main = $%Main
@onready var bloommod = $/root/main

func _ready():
	header.main = self
	main.main = self
	calculate_tabs()

func update():
	update_hacks()
	update_columns()
	redraw()

func calculate_tabs():
	tab_names = []
	actions = []
	widths = []
	
	tab_names.append("Main")
	actions.append(main_actions)
	widths.append(main_widths)
	
	hack_tab_id = len(tab_names)
	tab_names.append("Hacks")
	# aliasing intentional
	actions.append(hack_actions)
	widths.append(hack_widths)
	
	# indirectly calls update()
	tabbar.clear_tabs()
	for tab in tab_names:
		tabbar.add_tab(tab)

func update_hacks():
	hack_actions.clear()
	hack_widths.clear()
	hack_ids = {}
	var Hacks = bloommod.Hacks
	for id in range(len(Hacks.hacks)):
		if not Hacks.hack_scheduled[id]:
			continue
		var hack = Hacks.hacks[id]
		hack_lookup[id] = len(hack_actions)
		hack_ids[hack] = id
		hack_actions.append(hack)
		var string_size = font.get_string_size(hack, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		hack_widths.append(string_size.x + 20)

func is_hacks_tab(tab_id=-1):
	if tab_id == -1:
		tab_id = tabbar.current_tab
	return tab_id == hack_tab_id

func update_columns():
	current_actions = actions[tabbar.current_tab]
	current_widths = [frame_width] + widths[tabbar.current_tab]
	calculate_column_positions()

func calculate_column_positions():
	var count = len(current_widths)
	current_positions = [0]
	current_positions.resize(count + 1)
	for i in range(count):
		current_positions[i + 1] = current_positions[i] + current_widths[i]
	redraw()

func redraw():
	main.update_size()
	header.queue_redraw()
	main.queue_redraw()

func draw_grid(canvas, row_start, row_end):
	var row_count = (row_end - row_start)
	var column_count = len(current_widths)
	var points = PackedVector2Array()
	if points.resize((row_count + column_count) * 2 + 4):
		return
	for i in range(row_count + 1):
		points[i * 2] = Vector2(0.5, i * row_height + 0.5)
		points[i * 2 + 1] = Vector2(current_positions[-1] + 0.5, i * row_height + 0.5)
	for i in range(column_count + 1):
		points[(row_count + i) * 2 + 2] = Vector2(current_positions[i] + 0.5, 0.5)
		points[(row_count + i) * 2 + 3] = Vector2(current_positions[i] + 0.5, row_count * row_height + 0.5)
	# why are these black I don't understand
	# canvas.draw_multiline(points, Color.WHITE)
	canvas.draw_multiline(points, Color.WHITE, 1)

func draw_data(canvas, position, text):
	var ascent = font.get_ascent(font_size)
	var descent = font.get_descent(font_size)
	# TODO: these can break on resize, can that be fixed
	# See https://github.com/godotengine/godot/issues/76450 maybe
	canvas.draw_string(font, Vector2(current_positions[position.x],
			(position.y + 0.5) * row_height - (descent - ascent) / 2),
		text, HORIZONTAL_ALIGNMENT_CENTER, current_widths[position.x], font_size)

func get_action(frame, action, tab_id=-1):
	if tab_id == -1:
		tab_id = tabbar.current_tab
	var hack_id
	if is_hacks_tab(tab_id):
		hack_id = hack_ids[action]
	for f in range(frame, -1, -1):
		var data = bloommod.inputs[f]
		for i in range(len(data) - 1, -1, -1):
			var event = data[i]
			if is_hacks_tab(tab_id):
				if not event is Array:
					continue
				if event[1] is bool and hack_id == event[0]:
					return event[1]
			else:
				if not event is InputEventAction:
					continue
				if action == event.action:
					return event.pressed
	return false

func toggle_action(frame, action, tab_id=-1):
	var value = not get_action(frame, action, tab_id)
	_update_edge(frame, action, value, false, tab_id)
	_update_edge(frame, action, value, true, tab_id)
	_invalidate_after(frame)
	return value

func set_actions(frame_from, frame_to, action, value, tab_id=-1):
	if tab_id == -1:
		tab_id = tabbar.current_tab
	var hack_id
	if is_hacks_tab(tab_id):
		hack_id = hack_ids[action]
	if frame_from > frame_to:
		var tmp = frame_from
		frame_from = frame_to
		frame_to = tmp
	var old_from = get_action(frame_from, action, tab_id)
	var old_to = get_action(frame_to, action, tab_id)
	if value != old_from:
		_update_edge(frame_from, action, value, false, tab_id)
	for frame in range(frame_from + 1, frame_to + 1):
		if is_hacks_tab(tab_id):
			bloommod.inputs[frame] = bloommod.inputs[frame].filter(func(event):
				return (not event is Array) or (not event[1] is bool) or (event[0] != hack_id)
			)
		else:
			bloommod.inputs[frame] = bloommod.inputs[frame].filter(func(event):
				return (not event is InputEventAction) or (event.action != action)
			)
	if value != old_to:
		_update_edge(frame_to, action, value, true, tab_id)
	_invalidate_after(frame_from)

func get_swift_action(frame, action, tab_id=-1):
	if tab_id == -1:
		tab_id = tabbar.current_tab
	var hack_id
	if is_hacks_tab(tab_id):
		hack_id = hack_ids[action]
	var count = 0
	var data = bloommod.inputs[frame]
	for i in range(len(data) - 1, -1, -1):
		var event = data[i]
		if is_hacks_tab(tab_id):
			if not event is Array:
				continue
			if event[1] is bool and hack_id == event[0]:
				count += 1
		else:
			if not event is InputEventAction:
				continue
			if action == event.action:
				count += 1
	return (count >= 2)

func _add_swift_action(frame, action, tab_id=-1):
	if tab_id == -1:
		tab_id = tabbar.current_tab
	var hack_id
	if is_hacks_tab(tab_id):
		hack_id = hack_ids[action]
	var end_value = get_action(frame, action, tab_id)
	for i in range(2):
		var value = (end_value == bool(i))
		var event
		if is_hacks_tab(tab_id):
			event = [hack_id, value]
		else:
			event = InputEventAction.new()
			event.action = action
			event.pressed = (value)
		bloommod.inputs[frame].append(event)
	_invalidate_after(frame)

func _remove_swift_action(frame, action, tab_id=-1):
	if tab_id == -1:
		tab_id = tabbar.current_tab
	var count = {&'v': 0} # box for lambda capture by reference
	if is_hacks_tab(tab_id):
		var hack_id = hack_ids[action]
		bloommod.inputs[frame] = bloommod.inputs[frame].filter(func(event):
			if (count.v >= 2) or (not event is Array) or (not event[1] is bool) or (event[0] != hack_id):
				return true
			count.v += 1
			return false
		)
	else:
		bloommod.inputs[frame] = bloommod.inputs[frame].filter(func(event):
			if (count.v >= 2) or (not event is InputEventAction) or (event.action != action):
				return true
			count.v += 1
			return false
		)
	_invalidate_after(frame)

func set_swift_action(frame, action, value, tab_id=-1):
	var old_value = get_swift_action(frame, action, tab_id)
	if old_value != value:
		if value:
			_add_swift_action(frame, action, tab_id)
		else:
			_remove_swift_action(frame, action, tab_id)

func toggle_swift_action(frame, action, tab_id=-1):
	if get_swift_action(frame, action, tab_id):
		_remove_swift_action(frame, action, tab_id)
		return false
	else:
		_add_swift_action(frame, action, tab_id)
		return true

func _update_edge(frame, action, value, trailing, tab_id=-1):
	if tab_id == -1:
		tab_id = tabbar.current_tab
	var hack_id
	if is_hacks_tab(tab_id):
		hack_id = hack_ids[action]
	if frame + int(trailing) >= len(bloommod.inputs):
		return
	var data = bloommod.inputs[frame + int(trailing)]
	var order = range(len(data)) if trailing else range(len(data)-1, -1, -1)
	for i in order:
		if is_hacks_tab(tab_id):
			var event = data[i]
			if not event is Array:
				continue
			if not event[1] is bool:
				continue
			if event[0] != hack_id:
				continue
			data.pop_at(i)
			return
		else:
			var event = data[i]
			if not event is InputEventAction:
				continue
			if event.action != action:
				continue
			data.pop_at(i)
			return
	var event
	if is_hacks_tab(tab_id):
		event = [hack_id, value != trailing]
	else:
		event = InputEventAction.new()
		event.action = action
		event.pressed = (value != trailing)
	if trailing:
		data.insert(0, event)
	else:
		data.append(event)

func _invalidate_after(frame):
	main.queue_redraw()
	bloommod.invalidate_after(frame)

# TODO: seems hacky, probably needs refactoring
func record(from_frame, to_frame):
	for tab_id in range(len(actions)):
		var tab = actions[tab_id]
		for action in tab:
			var value
			if is_hacks_tab(tab_id):
				value = bloommod.Hacks.is_hack_enabled(hack_ids[action], from_frame, false)
				set_actions(from_frame + 1, to_frame, action, value, tab_id)
			else:
				value = Input.is_action_pressed(action)
				set_actions(from_frame, to_frame - 1, action, value, tab_id)
	if visible:
		redraw()
