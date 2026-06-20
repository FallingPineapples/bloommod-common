extends Window

const hacks = preload("res://BLOOMmod/hacks/manager.gd")
const inpututils = preload("res://BLOOMmod/utils/inputs.gd")
const Timeline = preload("res://BLOOMmod/utils/timeline.gd")

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
	hack_ids.clear()
	hack_lookup.clear()
	for id in range(len(hacks.hacks)):
		if not hacks.hack_scheduled[id]:
			continue
		var hack = hacks.hacks[id]
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

func set_timeline(timeline: Timeline) -> void:
	main.set_timeline(timeline)
	if visible:
		redraw()

# TODO: seems hacky, probably needs refactoring
func record(from_frame, to_frame):
	for tab_id in range(len(actions)):
		var tab = actions[tab_id]
		for action in tab:
			var value
			if is_hacks_tab(tab_id):
				value = hacks.is_hack_enabled(hack_ids[action], from_frame, main.timeline, false)
				inpututils.set_actions(main.timeline.inputs, from_frame + 1, to_frame, action, value)
			else:
				value = Input.is_action_pressed(action)
				inpututils.set_actions(main.timeline.inputs, from_frame, to_frame - 1, action, value)
	if visible:
		redraw()
	main.timeline.invalidate(from_frame, to_frame)
