## The plugin entrypoint; sets up buttons and binds them to [class Aligner]s.
@tool
extends EditorPlugin

const Aligner = preload("Aligner.gd")
const AlignableItem2D = preload("AlignableItem2D.gd")
const AlignableItem3D = preload("AlignableItem3D.gd")
const AlignToolButton = preload("AlignToolButton.gd")

var _aligners: Array[Aligner] = []
var _buttons: Array = []

func _enter_tree():
	var button_2d: AlignToolButton = preload("AlignToolButton.tscn").instantiate()
	button_2d.setup_2d()
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, button_2d)
	_buttons.append([CONTAINER_CANVAS_EDITOR_MENU, button_2d])

	var button_3d: AlignToolButton = preload("AlignToolButton.tscn").instantiate()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, button_3d)
	_buttons.append([CONTAINER_SPATIAL_EDITOR_MENU, button_3d])

	_aligners = [
		Aligner.new(self, button_2d, func(node): return node is CanvasItem, AlignableItem2D.new),
		Aligner.new(self, button_3d, func(node): return node is Node3D,     AlignableItem3D.new),
	]

	for aligner in _aligners:
		add_child(aligner)

func _exit_tree():
	for aligner in _aligners:
		aligner.queue_free()

	for button_info in _buttons:
		remove_control_from_container(button_info[0], button_info[1])
		button_info[1].queue_free()

	_aligners.clear()
	_buttons.clear()
