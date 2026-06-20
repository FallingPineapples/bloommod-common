const hacks = preload("res://BLOOMmod/hacks/manager.gd")
const treeutils = preload("res://BLOOMmod/utils/tree.gd")
const inpututils = preload("res://BLOOMmod/utils/inputs.gd")
const Timeline = preload("res://BLOOMmod/utils/timeline.gd")

var inputs: Array[Array] = []

var state_frames: Array[int] = []
var state_trees: Array[SceneTree] = []
var state_queued_hacks: Array[Array] = []

var hotspot_sources: Array[Callable] = []
var target_sources: Array[Callable] = [_get_hotspot_targets, _get_requested_targets]

var requested_targets: Array[int] = []
const _FRAME_SIGNAL_FMT = "_frame_%d"

var _states_locked := false
var _queued_invalidation_from := -1
var _queued_invalidation_to := -1

signal invalidated

func len() -> int:
	return len(inputs)

func new_state() -> void:
	var tree = treeutils.new_tree()
	state_trees.append(tree)
	state_frames.append(0)
	state_queued_hacks.append(hacks.enabled_hacks.duplicate())

func clone_state(state: int) -> void:
	var tree = treeutils.clone_tree(state_trees[state])
	state_trees.append(tree)
	state_frames.append(state_frames[state])
	state_queued_hacks.append(state_queued_hacks[state].duplicate())

func advance_state(state: int) -> void:
	flush_hack_queue(state)
	var tree := state_trees[state]
	var frame := state_frames[state]
	var input := inpututils.get_input(inputs, frame)
	treeutils.advance_tree(tree, input, frame, self)
	state_frames[state] += 1

func flush_hack_queue(state: int) -> void:
	var tree := state_trees[state]
	var frame := state_frames[state]
	for hack_id in state_queued_hacks[state]:
		hacks.call_hook('tree_enable', hack_id, [tree], self, frame)
	state_queued_hacks[state] = []

func find_state_at(frame: int) -> int:
	return state_frames.find(frame)

func get_tree(state: int) -> SceneTree:
	return state_trees[state]

func request_state_at(frame: int) -> Signal:
	var sig_name := StringName(_FRAME_SIGNAL_FMT % frame)
	if not has_user_signal(sig_name):
		add_user_signal(sig_name, [{'name':"tree",'type':TYPE_OBJECT}])
	if not requested_targets.has(frame):
		requested_targets.append(frame)
	return Signal(self, sig_name)

func request_tree_at(frame: int) -> SceneTree:
	var state: int = await request_state_at(frame)
	return treeutils.clone_tree(get_tree(state))

func check_all_requested_targets() -> void:
	for target in requested_targets:
		if state_frames.has(target):
			check_requested_targets(state_frames.find(target))

func check_requested_targets(state: int) -> void:
	var frame := state_frames[state]
	if requested_targets.has(frame):
		requested_targets.erase(frame)
		emit_signal(_FRAME_SIGNAL_FMT % frame, state)

func get_hotspots() -> Array[int]:
	var hotspots: Array[int] = []
	for source in hotspot_sources:
		for hotspot in source.call():
			if hotspot not in hotspots:
				hotspots.append(hotspot)
	return hotspots

func add_hotspot_source(source: Callable, index:=-1) -> void:
	if index == -1:
		hotspot_sources.append(source)
	else:
		hotspot_sources.insert(index, source)

func remove_hotspot_source(source: Callable) -> void:
	hotspot_sources.erase(source)

func get_targets() -> Array[int]:
	var targets: Array[int] = []
	for source in target_sources:
		for target in source.call():
			if target not in targets:
				targets.append(target)
	return targets

func add_target_source(source: Callable, index:=-1) -> void:
	if index == -1:
		target_sources.append(source)
	else:
		target_sources.insert(index, source)

func remove_target_source(source: Callable) -> void:
	target_sources.erase(source)

func _get_hotspot_targets() -> Array[int]:
	var targets: Array[int] = []
	for hotspot in get_hotspots():
		for target_rate in [1, 23, 47, 89, 409, 1499, 4013, 14503]:
			var target = floori(hotspot / target_rate) * target_rate
			if target >= 0 and target not in targets:
				targets.append(target)
	return targets

func _get_requested_targets() -> Array[int]:
	return requested_targets

func balance_distribution(max_usec: int) -> void:
	if _states_locked:
		push_warning("balance_distribution recursion")
		return
	_states_locked = true
	_balance_distribution(max_usec)
	_states_locked = false
	if _queued_invalidation_from != -1:
		_invalidate(_queued_invalidation_from, _queued_invalidation_to)
	_queued_invalidation_from = -1
	_queued_invalidation_to = -1

# TODO: trim the ton of states after the target
func _balance_distribution(max_usec: int) -> void:
	check_all_requested_targets()
	var end_usec := Time.get_ticks_usec() + max_usec
	var targets := get_targets()
	var states_used: Array[bool] = []
	states_used.resize(len(state_frames))
	states_used.fill(false)
	for target in targets:
		var state := state_frames.find(target)
		if state != -1:
			states_used[state] = true
	for target in targets:
		if Time.get_ticks_usec() > end_usec:
			return
		if target in state_frames:
			continue
		var fastest_state := -1
		var fastest_cost := target + 20
		for state in len(state_frames):
			var frame := state_frames[state]
			if frame > target:
				continue
			if _queued_invalidation_from != -1:
				if frame > _queued_invalidation_from:
					continue
			# TODO: remember expensive frames?
			var cost := target - frame
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
			if _queued_invalidation_from != -1:
				if state_frames[fastest_state] >= _queued_invalidation_from:
					break
			advance_state(fastest_state)
			if Time.get_ticks_usec() > end_usec:
				return
		check_requested_targets(fastest_state)
		states_used[fastest_state] = true

func invalidate_at(frame: int) -> void:
	invalidate(frame, frame)

func invalidate(frame_from: int, frame_to: int) -> void:
	if _states_locked:
		if _queued_invalidation_from == -1:
			_queued_invalidation_from = frame_from
			_queued_invalidation_to = frame_to
		else:
			_queued_invalidation_from = min(_queued_invalidation_from, frame_from)
			_queued_invalidation_to = max(_queued_invalidation_to, frame_to)
	else:
		_invalidate(frame_from, frame_to)

func _invalidate(frame_from: int, frame_to: int) -> void:
	var i := 0
	while i < len(state_frames):
		if state_frames[i] > frame_from:
			hacks.call_hook_enabled('tree_delete', [state_trees[i]])
			state_frames.remove_at(i)
			state_trees.pop_at(i).free()
			state_queued_hacks.remove_at(i)
		else:
			i += 1
	invalidated.emit(frame_from, frame_to)

func _on_hack_enabled(hack_id: int):
	for state in len(state_frames):
		state_queued_hacks[state].append(hack_id)
		treeutils._set_hack_enabled(state_trees[state], hack_id, true)

func _on_hack_disabled(hack_id: int):
	for state in len(state_frames):
		var i := state_queued_hacks[state].find(hack_id)
		if i == -1:
			hacks.call_hook('tree_disable', hack_id, [state_trees[state]], self, state_frames[state])
		else:
			state_queued_hacks[state].remove_at(i)
		treeutils._set_hack_enabled(state_trees[state], hack_id, false)

func serialized() -> PackedByteArray:
	return inpututils.serialize(inputs)

static func deserialized(data: PackedByteArray) -> Timeline:
	var timeline := Timeline.new()
	timeline.inputs = inpututils.deserialize(data)
	return timeline
