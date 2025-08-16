extends Window

var Hacks = preload("res://BLOOMmod/hacks/manager.gd")

@export_multiline var add_script_text = "Load script..."

func clear():
	$Tabs/Hacks.clear()
	$Tabs/Scripts.clear()

func update():
	if !visible:
		clear()
		return
	update_hacks_tab()
	update_scripts_tab()

func update_hacks_tab():
	if _blocked > 0:
		return
	var tree = $Tabs/Hacks
	tree.clear()
	if !tree.visible:
		return
	var show_internal = $ShowInternal.button_pressed
	var root = tree.create_item()
	for id in range(len(Hacks.hacks)):
		var internal = Hacks.hack_internal[id]
		if internal and not show_internal:
			continue
		var item = root.create_child()
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_checked(0, Hacks.is_hack_enabled(id))
		item.set_text(0, Hacks.hacks[id])
		item.set_editable(0, not internal)
		item.set_meta(&'hack_id', id)

func update_scripts_tab():
	var tree = $Tabs/Scripts
	tree.clear()
	if !tree.visible:
		return
	var show_internal = $ShowInternal.button_pressed
	var root = tree.create_item()
	for id in range(len(Hacks.scripts)):
		var internal = Hacks.script_internal[id]
		if internal and not show_internal:
			continue
		var item = root.create_child()
		item.set_text(0, Hacks.scripts[id].get_file())
	var add_item = root.create_child()
	add_item.set_cell_mode(0, TreeItem.CELL_MODE_CUSTOM)
	add_item.set_editable(0, true)
	add_item.set_text(0, add_script_text)

var _blocked = 0
func _on_hacks_item_edited():
	_blocked += 1
	var item = $Tabs/Hacks.get_selected()
	var id = item.get_meta(&'hack_id')
	Hacks.set_hack_enabled(id, item.is_checked(0))
	_blocked -= 1

func _on_scripts_custom_popup_edited(arrow_clicked):
	if arrow_clicked:
		return
	$LoadScript.popup_centered()

func _on_load_script_file_selected(path):
	Hacks.load_script(path)
	update()
