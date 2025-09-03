extends Node

var Hacks = preload("res://BLOOMmod/hacks/manager.gd")

var target_frame = 0
var bookmarks = []
var inputs = []
var rendered_state = -1

var frame_progress = 0.0
var current_speed = 1.0
var paused = true
var reverse = false

var recording = false
var last_recorded_frame = 0

var encoding = false
var ENCODE_TMP_PATH = "user://encode_tas.txt"

var state_frames = []
var state_trees = []
var state_queued_hacks = []

var requested_targets = []
var _FRAME_SIGNAL_FMT = "_frame_%d"

var _states_locked = false
var _queued_invalidation = -1

signal toast

func _ready():
	PhysicsServer2D.set_active(false)
	get_tree().root.set_embedding_subwindows(false)
	RenderingServer.viewport_set_update_mode(get_tree().root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_DISABLED)
	RenderingServer.viewport_attach_to_screen(get_tree().root.get_viewport_rid(), Rect2(), DisplayServer.INVALID_WINDOW_ID)
	encoding = OS.has_feature('movie')
	if not encoding:
		$input_editor.window_input.connect(_input)
		bookmarks.resize(35)
		bookmarks.fill(0)
	Hacks.bloom = self
	Hacks.load_internal_scripts()
	Hacks.load_script('autoexec.gd')
	if encoding:
		_start_encode()

func _input(event):
	if encoding:
		set_process_input(false)
		return
	var k = event as InputEventKey
	if k:
		if k.pressed and paused:
			match k.physical_keycode:
				KEY_V:
					if k.shift_pressed:
						target_frame += 10
					else:
						target_frame += 1
					expand_end()
				KEY_C:
					stop_recording()
					if k.shift_pressed:
						target_frame -= 10
					else:
						target_frame -= 1
					clamp_start()
		if k.pressed and !k.echo:
			match k.physical_keycode:
				KEY_P:
					if !paused and (reverse == k.shift_pressed):
						paused = true
						reverse = false
					else:
						paused = false
						reverse = k.shift_pressed
						if reverse:
							stop_recording()
					frame_progress = 0.0
				KEY_MINUS, KEY_UNDERSCORE:
					current_speed /= 2
				KEY_PLUS, KEY_EQUAL:
					current_speed *= 2
				_ when k.keycode >= KEY_F1 and k.keycode <= KEY_F35:
					var i = k.keycode - KEY_F1
					if k.shift_pressed:
						bookmarks[i] = target_frame
						toast.emit("Saved %d" % (i + 1))
					else:
						stop_recording()
						target_frame = bookmarks[i]
						toast.emit("Loaded %d" % (i + 1))
				KEY_APOSTROPHE, KEY_QUOTEDBL:
					toggle_recording()
					if recording and reverse:
						stop_and_reset() # TODO: does this make sense?
				KEY_QUOTELEFT, KEY_ASCIITILDE:
					if k.shift_pressed:
						show_window($hack_menu)
					else:
						show_window($input_editor)
						update_input_editor(true)
		if k.pressed and !k.echo and k.is_command_or_control_pressed():
			match k.physical_keycode:
				KEY_S:
					$dialogs/save.popup_centered()
				KEY_O:
					if len(inputs) == 0:
						$dialogs/load.popup_centered()
					else:
						pass # TODO: notify user?
				KEY_E:
					$dialogs/encode.popup_centered()
	Hacks.call_hook_enabled_at('input', target_frame, [event])

# TODO: warn when closing without saving

func show_window(window):
	window.show()
	if $/root.has_focus():
		window.grab_focus()

func _process(delta):
	if encoding:
		set_process(false)
		return
	update_frame(delta)
	update_recording()
	balance_distribution(10000)
	update_rendering()
	Hacks.call_hook_enabled('process')

func update_frame(delta):
	if paused:
		return
	var progress = current_speed * 60 * delta
	if reverse:
		frame_progress -= progress
	else:
		frame_progress += progress
	var frames = roundi(frame_progress)
	frame_progress -= frames
	target_frame += frames
	clamp_start()
	if recording: # TODO: is this intuitive?
		expand_end()
	else:
		clamp_end()

func update_recording():
	if not recording:
		return
	if last_recorded_frame > target_frame:
		toggle_recording()
		return
	if last_recorded_frame == target_frame:
		return
	$input_editor.record(last_recorded_frame, target_frame)
	last_recorded_frame = target_frame

func toggle_recording():
	if recording:
		stop_recording()
	else:
		start_recording()

func start_recording():
	if recording:
		return
	recording = true
	last_recorded_frame = target_frame
	toast.emit("Started recording")

func stop_recording():
	if not recording:
		return
	if last_recorded_frame < target_frame:
		update_recording()
	recording = false
	last_recorded_frame = target_frame
	toast.emit("Stopped recording")

func stop_and_reset():
	paused = true
	reverse = false
	frame_progress = 0.0

func clamp_start():
	if target_frame < 0:
		target_frame = 0
		stop_and_reset()

func clamp_end():
	if target_frame >= len(inputs):
		target_frame = len(inputs) - 1
		if target_frame < 0:
			target_frame = 0
		stop_and_reset()

func expand_end():
	if target_frame < len(inputs):
		return
	while target_frame >= len(inputs):
		inputs.append([])
	update_input_editor()

func update_input_editor(full=false):
	if $input_editor.visible:
		if full:
			$input_editor.update()
		else:
			$input_editor.redraw()

func get_input_events(frame):
	if frame >= len(inputs):
		return []
	return convert_input_events(inputs[frame])

func convert_input_events(input_events):
	var out = []
	for input in input_events:
		if input is InputEventAction:
			out.append_array(convert_action(input))
			continue
		out.append(input)
	return out

func convert_action(input):
	var events = InputMap.action_get_events(input.action)
	if len(events) <= 0:
		return []
	var event = events[0].duplicate()
	if event.device == -1:
		event.device = 0
	if event is InputEventKey:
		event.pressed = input.pressed
		var keycode = 0
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

func invalidate_after(frame):
	if _states_locked:
		if _queued_invalidation == -1:
			_queued_invalidation = frame
		else:
			_queued_invalidation = min(_queued_invalidation, frame)
	else:
		_invalidate_after(frame)
	Hacks.invalidate_after(frame)
	update_hack_menu()

func _invalidate_after(frame):
	var i = 0
	while i < len(state_frames):
		if state_frames[i] > frame:
			Hacks.call_hook_enabled('tree_delete', [state_trees[i]])
			state_frames.remove_at(i)
			state_trees.pop_at(i).free()
			state_queued_hacks.remove_at(i)
			if rendered_state == i:
				rendered_state = -1
			elif rendered_state > i:
				rendered_state -= 1
		else:
			i += 1

func _set_hack_enabled(tree, hack_id, value):
		var data = tree.get_meta(&'hacks_enabled')
		while len(data) <= hack_id:
			data.append(false)
		data[hack_id] = value

func _get_hack_enabled(tree, hack_id):
		var data = tree.get_meta(&'hacks_enabled')
		if len(data) <= hack_id:
			return false
		return data[hack_id]

func on_hack_enabled(hack_id):
	for state in len(state_frames):
		state_queued_hacks[state].append(hack_id)
		_set_hack_enabled(state_trees[state], hack_id, true)

func on_hack_disabled(hack_id):
	for state in len(state_frames):
		var i = state_queued_hacks[state].find(hack_id)
		if i == -1:
			Hacks.call_hook('tree_disable', hack_id, [state_trees[state]], state_frames[state])
		else:
			state_queued_hacks[state].remove_at(i)
		_set_hack_enabled(state_trees[state], hack_id, false)

func on_hack_event(tree, frame, event):
	if event[1] is bool:
		if _get_hack_enabled(tree, event[0]) == event[1]:
			return
		_set_hack_enabled(tree, event[0], event[1])
	elif not _get_hack_enabled(tree, event[0]):
		return
	Hacks.on_hack_event(tree, frame, event)

func add_current_hack_event(userdata, frame):
	Hacks.add_current_hack_event(userdata, frame)

func get_current_frame():
	return Hacks.current_frame

func update_hack_menu():
	$hack_menu.update()

func new_tree():
	var tree = SceneTree.new()
	tree.setup(ProjectSettings.get_setting("application/run/main_scene"))
	RenderingServer.viewport_set_update_mode(tree.root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_DISABLED)
	tree.set_meta(&'hacks_enabled', [])
	Hacks.call_hook_enabled('tree_create', [tree])
	return tree

func new_state():
	var tree = new_tree()
	state_trees.append(tree)
	state_frames.append(0)
	state_queued_hacks.append(Hacks.enabled_hacks.duplicate())

func clone_tree(from):
	var tree = from.duplicate()
	RenderingServer.viewport_set_update_mode(tree.root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_DISABLED)
	tree.set_meta(&'hacks_enabled', from.get_meta(&'hacks_enabled').duplicate())
	Hacks.call_hook_enabled('tree_clone', [tree])
	return tree

func clone_state(state):
	var tree = clone_tree(state_trees[state])
	state_trees.append(tree)
	state_frames.append(state_frames[state])
	state_queued_hacks.append(state_queued_hacks[state].duplicate())

func advance_state(state):
	flush_hack_queue(state)
	var tree = state_trees[state]
	var frame = state_frames[state]
	var input_events = get_input_events(frame)
	advance_tree(tree, input_events, frame)
	state_frames[state] += 1

func advance_tree(tree, input_events, frame=-1):
	var input_object = tree.get_input_object()
	for event in input_events:
		if event is InputEvent:
			input_object.parse_input_event(event)
		else:
			on_hack_event(tree, frame, event)
	Hacks.call_hook_filtered('tree_before_tick', tree.get_meta(&'hacks_enabled'), [tree], frame)
	tree.frame()
	Hacks.call_hook_filtered('tree_after_tick', tree.get_meta(&'hacks_enabled'), [tree], frame)

func flush_hack_queue(state):
	var tree = state_trees[state]
	var frame = state_frames[state]
	for hack_id in state_queued_hacks[state]:
		Hacks.call_hook('tree_enable', hack_id, [tree], frame)
	state_queued_hacks[state] = []

func request_state_at(frame):
	var sig_name = StringName(_FRAME_SIGNAL_FMT % frame)
	if not has_user_signal(sig_name):
		add_user_signal(sig_name, [{'name':"tree",'type':TYPE_OBJECT}])
	if not requested_targets.has(frame):
		requested_targets.append(frame)
	return Signal(self, sig_name)

func check_all_requested_targets():
	for target in requested_targets:
		if state_frames.has(target):
			check_requested_targets(state_frames.find(target))

func check_requested_targets(state):
	var frame = state_frames[state]
	if requested_targets.has(frame):
		requested_targets.erase(frame)
		emit_signal(_FRAME_SIGNAL_FMT % frame, state_trees[state])

func get_hotspots():
	var hotspots = []
	if paused or reverse:
		# when possible, omit moving hotspots for smoothness
		hotspots.append(target_frame)
	hotspots.append_array(bookmarks)
	return hotspots

func get_targets():
	# target_frame needs to be rendered, so it is added unconditionally
	var targets = [target_frame]
	targets.append_array(requested_targets)
	for hotspot in get_hotspots():
		for target_rate in [1, 23, 47, 89, 409, 1499, 4013, 14503]:
			var target = floori(hotspot / target_rate) * target_rate
			if target >= 0 and target not in targets:
				targets.append(target)
	return targets

func balance_distribution(max_usec):
	if _states_locked:
		push_warning("balance_distribution recursion")
		return
	_states_locked = true
	_balance_distribution(max_usec)
	_states_locked = false
	if _queued_invalidation != -1:
		_invalidate_after(_queued_invalidation)
	_queued_invalidation = -1

# TODO: trim the ton of states after the target
func _balance_distribution(max_usec):
	check_all_requested_targets()
	var end_usec = Time.get_ticks_usec() + max_usec
	var targets = get_targets()
	var states_used = []
	states_used.resize(len(state_frames))
	states_used.fill(false)
	for target in targets:
		var state = state_frames.find(target)
		if state != -1:
			states_used[state] = true
	for target in targets:
		if Time.get_ticks_usec() > end_usec:
			return
		if target in state_frames:
			continue
		var fastest_state = -1
		var fastest_cost = target + 20
		for state in len(state_frames):
			var frame = state_frames[state]
			if frame > target:
				continue
			if _queued_invalidation != -1:
				if frame > _queued_invalidation:
					continue
			# TODO: remember expensive frames?
			var cost = target - frame
			if states_used[state]:
				cost += 100
			if cost < fastest_cost:
				fastest_state = state
				fastest_cost = cost
		if fastest_state == -1:
			new_state()
			if Time.get_ticks_usec() > end_usec:
				return
			states_used.append(false)
			fastest_state = len(state_frames) - 1
		if states_used[fastest_state]:
			clone_state(fastest_state)
			if Time.get_ticks_usec() > end_usec:
				return
			states_used.append(false)
			fastest_state = len(state_frames) - 1
		# TODO: this frequently skips over other targets
		while state_frames[fastest_state] != target:
			if _queued_invalidation != -1:
				if state_frames[fastest_state] >= _queued_invalidation:
					break
			advance_state(fastest_state)
			if Time.get_ticks_usec() > end_usec:
				return
		check_requested_targets(fastest_state)
		states_used[fastest_state] = true

func update_rendering():
	if rendered_state != -1:
		RenderingServer.viewport_set_update_mode(state_trees[rendered_state].root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_DISABLED)
	rendered_state = -1
	for state in len(state_frames):
		if state_frames[state] == target_frame:
			RenderingServer.viewport_set_update_mode(state_trees[state].root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_WHEN_VISIBLE)
			rendered_state = state
			flush_hack_queue(state)
			Hacks.call_hook_enabled('tree_render', [state_trees[state]])
			update_hack_menu()
			break

func save_tas(path):
	var f = FileAccess.open(path, FileAccess.WRITE)
	var count = 0
	for frame in inputs:
		if len(frame) != 0 and count != 0:
			f.store_line(str(count))
			count = 0
		for input in frame:
			if input is InputEvent:
				if input is InputEventAction:
					var prefix = '+' if input.pressed else '-'
					f.store_line(prefix + input.action)
				else:
					push_warning("Could not save unsupported InputEvent type: %s" % input.get_class()) # TODO
			elif input is Array:
				if input[1] is Object or input[1] is Signal or input[1] is Callable:
					push_warning("Could not save hack data; unsupported data type: %s" % input.get_class())
				else:
					var data = Marshalls.variant_to_base64(input[1], false)
					f.store_line(':' + Hacks.hacks[input[0]] + ':' + data)
			else:
				push_warning("Could not save unknown input type: %s" % input.get_class())
		count += 1
	if count != 0:
		f.store_line(str(count))
	f.close()

func load_tas(path):
	var f = FileAccess.open(path, FileAccess.READ)
	if !f:
		push_error("Error code %d opening '%s'" % [FileAccess.get_open_error(), path])
		return
	inputs = [[]]
	invalidate_after(0)
	while not f.eof_reached():
		var line = f.get_line()
		if line == "":
			continue
		if line.left(1) in ['+', '-']:
			var action = line.right(-1)
			if not InputMap.has_action(action):
				push_warning("Unknown action '%s'" % action)
				continue
			var event = InputEventAction.new()
			event.action = action
			event.pressed = line.left(1) == '+'
			inputs[-1].append(event)
		elif line.left(1) == ':':
			var event_data = line.right(-1).split(':', true, 1)
			if len(event_data) != 2:
				push_warning("Could not decode '%s' (no separator)" % line)
				continue
			var hack_id = Hacks.hacks.find(event_data[0])
			if hack_id == -1:
				push_warning("Hack '%s' does not exist (script not loaded?)" % event_data[0])
				continue
			var data = Marshalls.base64_to_variant(event_data[1], false)
			var event = [hack_id, data]
			inputs[-1].append(event)
		elif line.is_valid_int():
			var count = int(line)
			var err = inputs.resize(len(inputs) + count)
			if err:
				push_error("Error code %d extending by '%s'" % [err, line])
				break
			for i in count:
				inputs[i - count] = []
		else:
			push_warning("Could not decode '%s'" % line)
	if len(inputs[-1]) == 0:
		inputs.pop_back()
	else:
		push_warning("No final frame count")
	f.close()
	update_input_editor()
	update_hack_menu()

func encode_tas(path):
	save_tas(ENCODE_TMP_PATH)
	var args = []
	if OS.has_feature('editor'):
		args.append_array(["--main-pack", "game_pack_path.pck"])
	args.append_array(["--write-movie", path])
	OS.create_process(OS.get_executable_path(), args)

func _start_encode():
	load_tas(ENCODE_TMP_PATH)
	new_state()
	paused = false

func _physics_process(_delta):
	if not encoding:
		return
	if paused:
		return
	target_frame = state_frames[0] + 1
	if target_frame >= len(inputs):
		get_tree().quit()
		return
	advance_state(0)
	update_rendering()
