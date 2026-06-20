extends Window

var hacks = preload("res://BLOOMmod/hacks/manager.gd")

@export_multiline var add_script_text = "Load script..."
@export_multiline var save_embedded_text = "Save embedded script as..."

const ACTION_ADD_SCRIPT = 0
const ACTION_SAVE_EMBEDDED = 1

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
	for id in range(len(hacks.hacks)):
		var internal = hacks.hack_internal[id]
		if internal and not show_internal:
			continue
		var item = root.create_child()
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_checked(0, hacks.is_hack_enabled(id))
		item.set_text(0, hacks.hacks[id])
		item.set_editable(0, not internal)
		item.set_meta(&'hack_id', id)

func update_scripts_tab():
	var tree = $Tabs/Scripts
	tree.clear()
	if !tree.visible:
		return
	var show_internal = $ShowInternal.button_pressed
	var root = tree.create_item()
	for id in range(len(hacks.scripts)):
		var internal = hacks.script_internal[id]
		if internal and not show_internal:
			continue
		var item = root.create_child()
		item.set_text(0, hacks.scripts[id].get_file())
	var add_item = root.create_child()
	add_item.set_cell_mode(0, TreeItem.CELL_MODE_CUSTOM)
	add_item.set_editable(0, true)
	add_item.set_text(0, add_script_text)
	add_item.set_metadata(0, ACTION_ADD_SCRIPT)
	var save_item = root.create_child()
	save_item.set_cell_mode(0, TreeItem.CELL_MODE_CUSTOM)
	save_item.set_editable(0, true)
	save_item.set_text(0, save_embedded_text)
	save_item.set_metadata(0, ACTION_SAVE_EMBEDDED)

var _blocked = 0
func _on_hacks_item_edited():
	_blocked += 1
	var item = $Tabs/Hacks.get_selected()
	var id = item.get_meta(&'hack_id')
	hacks.set_hack_enabled(id, item.is_checked(0))
	_blocked -= 1

func _on_scripts_custom_popup_edited(arrow_clicked):
	if arrow_clicked:
		return
	match $Tabs/Scripts.get_edited().get_metadata(0):
		ACTION_ADD_SCRIPT:
			$Dialogs/LoadScript.popup_centered()
		ACTION_SAVE_EMBEDDED:
			$Dialogs/SelectEmbedded.set_current_path("res://BLOOMmod/scripts/")
			$Dialogs/SelectEmbedded.popup_centered()
		_: push_error("Unknown action in hack_menu")

func _on_load_script_file_selected(path):
	hacks.load_script(path)
	update()

var _paths
func _on_select_embedded_files_selected(paths):
	_paths = paths
	$Dialogs/SaveEmbedded.popup_centered()

func _on_save_embedded_dir_selected(dir):
	for path in _paths:
		var data = FileAccess.get_file_as_bytes(path)
		if !data:
			push_error("Error code '%s' opening '%s'" % [error_string(FileAccess.get_open_error()), path])
			continue
		var new_path = dir.path_join(path.get_file())
		var f = FileAccess.open(new_path, FileAccess.WRITE)
		if !f:
			push_error("Error code '%s' opening '%s'" % [error_string(FileAccess.get_open_error()), new_path])
			continue
		f.store_buffer(data)
		f.close()
