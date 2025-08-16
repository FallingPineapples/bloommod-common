extends Control

var main

func _process(_delta):
	position.x = -$%Main.get_parent().scroll_horizontal

func _draw():
	main.draw_grid(self, 0, 1)
	main.draw_data(self, Vector2i(0, 0), "Frame")
	for column in range(len(main.current_actions)):
		main.draw_data(self, Vector2i(column + 1, 0), main.current_actions[column])
