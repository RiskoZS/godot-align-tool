@tool
extends "AlignableItem.gd"

var _node: CanvasItem
var _orig_global_transform: Transform3D

func _init(node: CanvasItem) -> void:
	_node = node
	_orig_global_transform = get_global_transform()

func get_aabb() -> AABB:
	var rect = _node.find_children("*", "CanvasItem") \
		.map(_get_transformed_rect) \
		.reduce(func(a, b): return a.merge(b), _get_transformed_rect(_node))

	return AABB(Vector3(rect.position.x, rect.position.y, 0), Vector3(rect.size.x, rect.size.y, 0))

func get_orig_global_transform() -> Transform3D:
	return _orig_global_transform

func get_global_transform() -> Transform3D:
	var transform := _node.get_global_transform()
	return Transform3D(
		Vector3(transform.x.x, transform.x.y, 0),
		Vector3(transform.y.x, transform.y.y, 0),
		Vector3(0, 0, 1),
		Vector3(transform.origin.x, transform.origin.y, 0),
	)

func reposition_to(pos: Vector3, undoRedoManager: EditorUndoRedoManager) -> void:
	undoRedoManager.add_undo_property(_node, "global_position", _node.global_position)
	undoRedoManager.add_do_property(_node, "global_position", Vector2(pos.x, pos.y))

func _to_string() -> String:
	return "<Alignable2D:%s>" % _node


func _get_transformed_rect(incoming_node: CanvasItem) -> Rect2:
	return (_node.get_global_transform().affine_inverse() * incoming_node.get_global_transform()) * _get_node_rect(incoming_node)

static func _get_node_rect(node: CanvasItem) -> Rect2:
	# Unlike in 3D, 2D nodes generally do not have a standardized function to return a local-space
	# bounding rect. We can use the internal _edit_get_rect() function, but that doesn't entirely
	# work because it e.g. treats a Marker2D's gizmos as part of its bounding rect. So, we need to
	# handle this on a case-by-case basis.

	if node is Marker2D:
		return Rect2()

	elif node.has_method("_edit_get_rect"):
		return node._edit_get_rect()

	elif node.has_method("get_rect"):
		return node.get_rect()

	return Rect2()
