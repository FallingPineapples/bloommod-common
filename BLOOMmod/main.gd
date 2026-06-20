extends Node

const hacks = preload("res://BLOOMmod/hacks/manager.gd")
const treeutils = preload("res://BLOOMmod/utils/tree.gd")
const inpututils = preload("res://BLOOMmod/utils/inputs.gd")
const Timeline = preload("res://BLOOMmod/utils/timeline.gd")

var target_frame = 0
var bookmarks = []
var main_timeline: Timeline = null
var rendered_tree: WeakRef = weakref(null)

var frame_progress = 0.0
var current_speed = 1.0
var paused = true
var reverse = false

var recording = false
var last_recorded_frame = 0

var encoding = false
var ENCODE_TMP_PATH = "user://encode_tas.txt"

signal toast

func _ready():
	PhysicsServer2D.set_active(false)
	get_tree().root.set_embedding_subwindows(false)
	treeutils.set_tree_render(get_tree(), false)
	RenderingServer.viewport_attach_to_screen(get_tree().root.get_viewport_rid(), Rect2(), DisplayServer.INVALID_WINDOW_ID)
	$input_editor.main.bloom = self
	encoding = OS.has_feature('movie')
	if not encoding:
		$input_editor.window_input.connect(_input)
		bookmarks.resize(35)
		bookmarks.fill(0)
	hacks.bloom = self
	hacks.load_internal_scripts()
	hacks.load_script('autoexec.gd')
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
						update_input_editor()
		if k.pressed and !k.echo and k.is_command_or_control_pressed():
			match k.physical_keycode:
				KEY_S:
					if main_timeline:
						$dialogs/save.popup_centered()
					else:
						toast.emit("No tas loaded")
				KEY_O:
					if main_timeline == null:
						$dialogs/load.popup_centered()
					else:
						pass # TODO: notify user?
				KEY_E:
					if main_timeline:
						$dialogs/encode.popup_centered()
					else:
						toast.emit("No tas loaded")
	hacks.call_hook_enabled_at('input', target_frame, [event], main_timeline)

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
	if main_timeline:
		main_timeline.balance_distribution(10000) # TODO: should this do all timelines?
		update_rendering()
	hacks.call_hook_enabled('process')

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
	ensure_main_timeline()
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
	if target_frame >= main_timeline.len():
		target_frame = main_timeline.len() - 1
		if target_frame < 0:
			target_frame = 0
		stop_and_reset()

func expand_end():
	if target_frame < main_timeline.len():
		return
	while target_frame >= main_timeline.len():
		main_timeline.inputs.append([])
	main_timeline.invalidate_at(target_frame)

func update_input_editor():
	if $input_editor.visible:
		$input_editor.update()

func add_current_hack_event(userdata, frame):
	hacks.add_current_hack_event(userdata, frame)

func get_current_frame():
	return hacks.current_frame

func get_current_timeline():
	return hacks.current_timeline

func update_hack_menu():
	$hack_menu.update()

func update_rendering():
	var state = main_timeline.find_state_at(target_frame)
	if state == -1:
		if rendered_tree.get_ref() != null:
			treeutils.set_tree_render(rendered_tree.get_ref(), false)
			rendered_tree = weakref(null)
	else:
		var tree = main_timeline.get_tree(state)
		if rendered_tree.get_ref() != tree:
			if rendered_tree.get_ref() != null:
				treeutils.set_tree_render(rendered_tree.get_ref(), false)
		treeutils.set_tree_render(tree, true)
		rendered_tree = weakref(tree)
		main_timeline.flush_hack_queue(state)
		hacks.call_hook_enabled('tree_render', [tree], target_frame, main_timeline)
	update_hack_menu()

func save_tas(path):
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(main_timeline.serialized())
	f.close()

func load_tas(path):
	var data = FileAccess.get_file_as_bytes(path)
	if !data:
		push_error("Error code '%d' opening '%s'" % [error_string(FileAccess.get_open_error()), path])
		return
	set_main_timeline(Timeline.deserialized(data))

func encode_tas(path):
	save_tas(ENCODE_TMP_PATH)
	var args = []
	if OS.has_feature('editor'):
		args.append_array(["--main-pack", "game_pack_path.pck"])
	args.append_array(["--write-movie", path])
	OS.create_process(OS.get_executable_path(), args)

func _start_encode():
	load_tas(ENCODE_TMP_PATH)
	main_timeline.new_state()
	paused = false

func _physics_process(_delta):
	if not encoding:
		set_physics_process(false)
		return
	if paused:
		return
	target_frame = main_timeline.state_frames[0] + 1
	if target_frame >= main_timeline.len():
		get_tree().quit()
		return
	main_timeline.advance_state(0)
	update_rendering()

func set_main_timeline(timeline: Timeline) -> void:
	if main_timeline:
		main_timeline.remove_target_source(_get_target_frame_targets)
		main_timeline.remove_hotspot_source(_get_main_hotspots)
	main_timeline = timeline
	if main_timeline:
		main_timeline.add_target_source(_get_target_frame_targets, 0)
		main_timeline.add_hotspot_source(_get_main_hotspots)
	$input_editor.set_timeline(main_timeline)
	update_hack_menu()

func ensure_main_timeline() -> void:
	if main_timeline == null:
		set_main_timeline(Timeline.new())
		toast.emit("Blank TAS created")

# target_frame needs to be rendered, so it is added unconditionally
func _get_target_frame_targets() -> Array[int]:
	return [target_frame]

func _get_main_hotspots() -> Array[int]:
	var hotspots: Array[int] = []
	if paused or reverse:
		# when possible, omit moving hotspots for smoothness
		hotspots.append(target_frame)
	hotspots.append_array(bookmarks)
	return hotspots
