static var INTERNAL_HACKS = ['framework']
static var bloom

static func enable_framework():
	if not bloom.encoding:
		AudioServer.set_bus_mute(0, true)

static func tree_enable_framework(tree):
	var hack_layer = CanvasLayer.new()
	hack_layer.name = &'HackLayer'
	hack_layer.layer = 512
	tree.root.add_child(hack_layer)
