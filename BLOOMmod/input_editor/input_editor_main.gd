extends Control

var main
@onready var bloommod = $/root/main

var mouse_down_cell = Vector2i()
var mouse_down_value = false
var mouse_down_swift = false

func update_size():
	custom_minimum_size.x = main.current_positions[-1] + 1
	custom_minimum_size.y = len(bloommod.inputs) * main.row_height + 1

func _gui_input(event):
	if event is InputEventMouseButton:
		var cell = _find_cell(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if cell.x == 0:
				if event.pressed:
					bloommod.target_frame = cell.y
			else:
				if event.pressed:
					mouse_down_cell = cell
					mouse_down_swift = event.shift_pressed
					if mouse_down_swift:
						mouse_down_value = toggle_cell_swift(cell)
					else:
						mouse_down_value = toggle_cell(cell)
				elif cell.x == mouse_down_cell.x:
					if mouse_down_swift:
						set_cells_swift(mouse_down_cell, cell, mouse_down_value)
					else:
						set_cells(mouse_down_cell, cell, mouse_down_value)

func _find_cell(position):
	var frame = clamp(floor(position.y/main.row_height), 0, len(bloommod.inputs) - 1)
	var min = 0
	var max = len(main.current_positions) - 2
	while min < max:
		var mid = ceil((min + max) / 2.0)
		if position.x < main.current_positions[mid]:
			max = mid - 1
		else:
			min = mid
	return Vector2i(min, frame)

func get_cell(cell):
	var action = main.current_actions[cell.x - 1]
	return main.get_action(cell.y, action)

func toggle_cell(cell):
	var action = main.current_actions[cell.x - 1]
	return main.toggle_action(cell.y, action)

func set_cells(cell_from, cell_to, value):
	var action = main.current_actions[cell_from.x - 1]
	main.set_actions(cell_from.y, cell_to.y, action, value)

func toggle_cell_swift(cell):
	var action = main.current_actions[cell.x - 1]
	return main.toggle_swift_action(cell.y, action)

func set_cells_swift(cell_from, cell_to, value):
	var action = main.current_actions[cell_from.x - 1]
	if cell_from.y > cell_to.y:
		var tmp = cell_from
		cell_from = cell_to
		cell_to = tmp
	for y in range(cell_from.y, cell_to.y + 1):
		main.set_swift_action(y, action, value)

# TODO: mitigate lag for long tases
# TODO: unknown input combinations
func _draw():
	var length = len(bloommod.inputs)
	main.draw_grid(self, 0, length)
	var current_data = []
	current_data.resize(len(main.current_actions))
	current_data.fill(false)
	var counts = []
	counts.resize(len(main.current_actions))
	for frame in range(0, length):
		counts.fill(0)
		for event in bloommod.inputs[frame]:
			if main.is_hacks_tab():
				if not event is Array:
					continue
				if not event[1] is bool:
					continue
				var column = main.hack_lookup[event[0]]
				if column == -1:
					continue
				current_data[column] = event[1]
				counts[column] += 1
			else:
				if not event is InputEventAction:
					continue
				var column = main.current_actions.find(event.action)
				if column == -1:
					continue
				current_data[column] = event.pressed
				counts[column] += 1
		main.draw_data(self, Vector2i(0, frame), str(frame))
		for column in range(len(main.current_actions)):
			var text = ''
			if counts[column] > 1:
				text = main.current_actions[column]
				if current_data[column]:
					text = "-+" + text
				else:
					text = "+-" + text
			elif current_data[column]:
				text = main.current_actions[column]
			if text != '':
				main.draw_data(self, Vector2i(column + 1, frame), text)

func _process(_delta):
	$Panel.size = Vector2(main.current_positions[-1], main.row_height)
	$Panel.position = Vector2(main.current_positions[0], main.row_height * bloommod.target_frame)
	# $Panel.visible = bloommod.tasing
