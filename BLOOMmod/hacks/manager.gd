static var internal_scripts = [
	'framework',
	'overlay',
	'freecam',
]

static var scripts = []
static var hacks = []

static var hack_enabled = []
static var script_internal = []
static var hack_internal = []
static var hack_scheduled = []

static var enabled_hacks = []
static var _enabled_at_hacks_cache = []
static var _enabled_at_cache_frame = -1

static var script_objects = []
static var hack_owners = []

static var bloom = null

static var current_hack_id = -1
static var current_frame = -1

static func load_script(script, internal=false):
	var id = len(scripts)
	var object
	if script.begins_with("res://"):
		object = load(script)
		if not object is GDScript:
			return
	else:
		var code = FileAccess.get_file_as_string(script)
		if code == '':
			return # TODO: notify user
		object = GDScript.new()
		object.source_code = code
		var err = object.reload()
		if err:
			return # TODO: notify user
	scripts.append(script)
	script_internal.append(internal)
	if not (&'HACKS' in object or &'bloom' in object):
		var type = object.get_instance_base_type()
		var new_object = ClassDB.instantiate(type)
		new_object.script = object
		object = new_object
	script_objects.insert(id, object)
	object.set(&'bloom', bloom)
	if object.has_method(&'loaded'):
		object.call(&'loaded')
	for hack_var in [&'HACKS', &'INTERNAL_HACKS']:
		var new_hacks = object.get(hack_var)
		if not (new_hacks is Array or new_hacks is PackedStringArray):
			continue
		var internal_hack = hack_var == &'INTERNAL_HACKS'
		for hack in new_hacks:
			var hack_name = str(hack)
			if not hack_name.is_valid_identifier():
				push_warning("Invalid hack name '%s' (not an identifier)" % hack_name)
				continue
			var hack_id = add_hack(id, hack_name, internal_hack)
			if object.get('record_toggles_%s' % hack_name):
				hack_scheduled[hack_id] = true
			if internal_hack or object.get('default_enable_%s' % hack_name):
				enable_hack(hack_id)
	return id

static func load_internal_scripts():
	for script in internal_scripts:
		load_script('res://BLOOMmod/scripts/%s.gd' % script, true)

static func add_hack(script_id, hack_name, internal=false):
	var id = len(hacks)
	hacks.append(hack_name)
	hack_owners.append(script_id)
	hack_internal.append(internal)
	hack_enabled.append(false)
	hack_scheduled.append(false)
	_enabled_at_hacks_cache.append(false)
	return id

static func enable_hack(id):
	if hack_scheduled[id]:
		add_hack_event([id, true], bloom.target_frame)
	else:
		if hack_enabled[id]:
			return
		hack_enabled[id] = true
		enabled_hacks.insert(enabled_hacks.bsearch(id), id)
		call_hook('enable', id)
		bloom.on_hack_enabled(id)

static func disable_hack(id):
	if hack_internal[id]:
		return
	if hack_scheduled[id]:
		add_hack_event([id, false], bloom.target_frame)
	else:
		if not hack_enabled[id]:
			return
		hack_enabled[id] = false
		enabled_hacks.erase(id)
		call_hook('disable', id)
		bloom.on_hack_disabled(id)

static func set_hack_enabled(id, enable):
	if enable:
		enable_hack(id)
	else:
		disable_hack(id)

static func is_hack_enabled(id, frame=-1, update_cache=true):
	if hack_scheduled[id]:
		if frame == -1:
			frame = bloom.target_frame
		if frame != _enabled_at_cache_frame:
			if update_cache:
				update_enabled_at_cache(frame)
			else:
				return _is_hack_enabled(id, frame)
		return _enabled_at_hacks_cache[id]
	else:
		return hack_enabled[id]

static func update_enabled_at_cache(frame):
	for id in range(len(hacks)):
		_enabled_at_hacks_cache[id] = _is_hack_enabled(id, frame)
	_enabled_at_cache_frame = frame
	
static func _is_hack_enabled(id, frame):
	var start = -1
	if frame > _enabled_at_cache_frame:
		start = _enabled_at_cache_frame
	for f in range(frame, start, -1):
		if f >= len(bloom.inputs):
			continue
		var data = bloom.inputs[f]
		for i in range(len(data) - 1, -1, -1):
			if not data[i] is Array:
				continue
			var event = data[i]
			if event[1] is bool and id == event[0]:
				return event[1]
	if start == -1:
		return false
	else:
		return _enabled_at_hacks_cache[id]

static func invalidate_after(frame):
	if _enabled_at_cache_frame >= frame:
		_enabled_at_cache_frame = -1

static func call_hook(hook, id, args=[], frame=-1):
	var hack_name = hacks[id]
	var method = "%s_%s" % [hook, hack_name]
	var owner = script_objects[hack_owners[id]]
	if owner.has_method(method):
		var prev_hack_id = current_hack_id
		var prev_frame = current_frame
		current_hack_id = id
		current_frame = frame
		owner.callv(method, args)
		current_hack_id = prev_hack_id
		current_frame = prev_frame

static func call_hook_filtered(hook, filter, args=[], frame=-1):
	for id in range(len(filter)):
		if not filter[id]:
			continue
		call_hook(hook, id, args, frame)

static func call_hook_enabled(hook, args=[]):
	for id in enabled_hacks:
		call_hook(hook, id, args)

static func call_hook_enabled_at(hook, frame, args=[]):
	for id in range(len(hacks)):
		if not is_hack_enabled(id, frame):
			continue
		call_hook(hook, id, args)

static func add_current_hack_event(userdata, frame):
	if current_hack_id == -1:
		push_error("must be called in a hook")
		return
	add_hack_event([current_hack_id, userdata], frame)

static func add_hack_event(event, frame):
	while frame >= len(bloom.inputs):
		bloom.inputs.append([])
	bloom.inputs[frame].append(event)
	bloom.invalidate_after(frame)
	bloom.update_input_editor()

static func on_hack_event(tree, frame, event):
	if event[1] is bool:
		var hook = 'tree_enable' if event[1] else 'tree_disable'
		call_hook(hook, event[0], [tree], frame)
	else:
		call_hook('data_event', event[0], [tree, event[1]], frame)
