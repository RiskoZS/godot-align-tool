## A generic class that binds to a UI button and aligns items of a compatible
## type.
@tool
extends Node

const AlignableItem = preload("AlignableItem.gd")
const AlignToolButton = preload("AlignToolButton.gd")

var _plugin: EditorPlugin
var _selection: EditorSelection

var _button: AlignToolButton
var _selection_filter: Callable
var _alignable_factory: Callable

var _aligning_items: Array = []


## Creates a new Aligner.
##
## This Aligner will listen to the given [param button] for activation events. The given
## [param selection_filter] should be a callback that takes a [class Node] and returns whether this
## Aligner should try to align it, and [param alignable_factory] should be a callback that takes a
## [class Node] and returns the appropriate [class AlignableItem] implementation that this Aligner
## should use.
func _init(plugin: EditorPlugin, button: AlignToolButton, selection_filter: Callable, alignable_factory: Callable
		) -> void:

	_plugin = plugin
	_selection_filter = selection_filter
	_alignable_factory = alignable_factory

	_selection = _plugin.get_editor_interface().get_selection()
	_selection.selection_changed.connect(_selection_changed)

	_button = button
	_button.popup_toggled.connect(_popup_toggled)
	_button.align_button_pressed.connect(_align_button_pressed)


## Disconnect listeners
func _exit_tree():
	_selection.selection_changed.disconnect(_selection_changed)
	_button.popup_toggled.disconnect(_popup_toggled)
	_button.align_button_pressed.disconnect(_align_button_pressed)


## Update the state of the align menu button
func _selection_changed() -> void:
	_button.disabled = _get_relevant_selected_nodes().size() < 2


## Returns a list of all selected transformable nodes that may be aligned by this Aligner
func _get_relevant_selected_nodes() -> Array[Node]:
	# get_transformable_selected_nodes() is deprecated in favour of get_top_selected_nodes(), but we probably want to
	# support older Godot 4 versions...?
	return _selection.get_transformable_selected_nodes().filter(_selection_filter)


## When the popup is opened, create the [class AlignableItem]s, which saves their original transforms.
func _popup_toggled(is_visible: bool) -> void:
	if not is_visible:
		_aligning_items.clear()
		return

	_aligning_items = _get_relevant_selected_nodes().map(_alignable_factory)


## Perform the align/spacing operation; this is where the main business logic happens
func _align_button_pressed(axis: AlignToolButton.Axis, alignment: AlignToolButton.Alignment) -> void:
	if _aligning_items.is_empty():
		return

	var undoRedoManager := _plugin.get_undo_redo()

	var is_local := _button.get_is_in_local_space()
	var is_to_active := (_button.get_alignment_target() == AlignToolButton.Target.ACTIVE_NODE)

	var active_item: AlignableItem = _aligning_items.back()
	var origin := active_item.get_orig_global_transform() if is_local else Transform3D()
	var origin_inv := origin.affine_inverse()

	# For each item, pre-calculate its relative transforms and AABB
	var item_datas: Array = _aligning_items \
		.map(func(item: AlignableItem):
			var relative_orig_transform := origin_inv * item.get_orig_global_transform()
			return {
				item = item,
				relative_orig_transform = relative_orig_transform,
				relative_cur_transform = origin_inv * item.get_global_transform(),
				relative_aabb = relative_orig_transform * item.get_aabb()
			} \
		)

	# Merge into a total AABB (or take the active item's AABB) that will be used as the alignment bounds
	var total_aabb: AABB = item_datas.back().relative_aabb if is_to_active else item_datas \
		.map(func(item_data): return item_data.relative_aabb) \
		.reduce(func(a, b): return a.merge(b))

	_debug_draw_aabb_in_space(total_aabb, origin)

	# The aligning-axis-relative coordinate of the aligning plane
	var target_axis_pos := _get_aabb_align_point(total_aabb, alignment)[axis]

	# Align
	if alignment in [AlignToolButton.Alignment.MIN, AlignToolButton.Alignment.CENTER, AlignToolButton.Alignment.MAX]:
		undoRedoManager.create_action("Align Node(s)")

		# Perform the alignment; the goal is to align the 'AABB align point' of every item's AABB with the
		# 'AABB align point' of the total AABB.
		for item_data in item_datas:
			_debug_draw_aabb_in_space(item_data.relative_aabb, origin)

			_reposition_item(
				item_data,
				target_axis_pos, _get_aabb_align_point(item_data.relative_aabb, alignment), axis, origin,
				undoRedoManager
			)

		undoRedoManager.commit_action()
		return

	# Distribute or space out
	var sorted_item_datas: Array = item_datas.duplicate()
	sorted_item_datas.sort_custom(func(a, b): return a.relative_aabb.position[axis] < b.relative_aabb.position[axis])

	var total_len := total_aabb.size[axis]

	# Distribute items (equal distance between centers)
	if alignment == AlignToolButton.Alignment.DISTRIBUTE:
		undoRedoManager.create_action("Distribute Node(s) (Equal Center Distance)")

		var first_item_padding: float = sorted_item_datas.front().relative_aabb.size[axis] / 2
		var last_item_padding: float = sorted_item_datas.back().relative_aabb.size[axis] / 2

		var gap_size := (total_len - first_item_padding - last_item_padding) / (sorted_item_datas.size() - 1)

		for i in sorted_item_datas.size():
			var item_data = sorted_item_datas[i]

			_reposition_item(
				item_data,
				target_axis_pos + first_item_padding + (gap_size * i), item_data.relative_aabb.get_center(),
				axis, origin,
				undoRedoManager
			)

		undoRedoManager.commit_action()
		return

	# Space out items (equal gaps between items)
	undoRedoManager.create_action("Distribute Node(s) (Equal Spacing)")

	var total_item_len = item_datas.reduce(func(accum, data): return accum + data.relative_aabb.size[axis], 0)
	var gap_size = (total_len - total_item_len) / (sorted_item_datas.size() - 1)

	var num_space_placed := 0.0

	for item_data in sorted_item_datas:
		_reposition_item(
			item_data,
			target_axis_pos + num_space_placed, item_data.relative_aabb.position, axis, origin,
			undoRedoManager
		)
		num_space_placed += item_data.relative_aabb.size[axis] + gap_size

	undoRedoManager.commit_action()


static func _reposition_item(item_data, target_axis_pos: float, item_pos_to_align: Vector3, axis: AlignToolButton.Axis,
	origin: Transform3D, undoRedoManager: EditorUndoRedoManager) -> void:

	var rel_cur_item_pos: Vector3 = item_data.relative_cur_transform.origin
	var transform_offset: float = item_data.relative_orig_transform.origin[axis] - item_pos_to_align[axis]

	rel_cur_item_pos[axis] = target_axis_pos + transform_offset

	item_data.item.reposition_to(origin * rel_cur_item_pos, undoRedoManager)


## Returns the point on the given [param aabb] to align to. The correct axis of the returned point should then be
## queried.
##
## Put differently, the returned point is the intersection of all three axis-aligned aligning planes for the given
## [param alignment] type.
static func _get_aabb_align_point(aabb: AABB, alignment: AlignToolButton.Alignment) -> Vector3:
	match alignment:
		AlignToolButton.Alignment.MIN: return aabb.position
		AlignToolButton.Alignment.CENTER: return aabb.get_center()
		AlignToolButton.Alignment.MAX: return aabb.end
		AlignToolButton.Alignment.DISTRIBUTE: return aabb.position
		AlignToolButton.Alignment.SEPARATE: return aabb.position

	return Vector3.ZERO # Should never happen


## For debugging; requires DD3D installed
static func _debug_draw_aabb_in_space(aabb: AABB, origin: Transform3D) -> void:
	# DebugDraw3D.draw_box(
	# 	origin * aabb.get_center(),
	# 	origin.basis.get_rotation_quaternion(),
	# 	aabb.size * origin.basis.get_scale(),
	# 	Color(0, 0, 0, 0),
	# 	true,
	# 	3
	# )
	pass
