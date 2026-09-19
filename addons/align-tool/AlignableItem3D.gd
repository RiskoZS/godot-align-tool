@tool
extends "AlignableItem.gd"

var _node: Node3D
var _orig_global_transform: Transform3D

func _init(node: Node3D) -> void:
	_node = node
	_orig_global_transform = get_global_transform()

func get_aabb() -> AABB:
	return _node.find_children("*", "Node3D") \
		.map(_get_transformed_aabb) \
		.reduce(func(a, b): return a.merge(b), _get_transformed_aabb(_node))

func get_orig_global_transform() -> Transform3D:
	return _orig_global_transform

func get_global_transform() -> Transform3D:
	return _node.global_transform

func reposition_to(pos: Vector3, undoRedoManager: EditorUndoRedoManager) -> void:
	undoRedoManager.add_undo_property(_node, "global_position", _node.global_position)
	undoRedoManager.add_do_property(_node, "global_position", pos)

func _to_string() -> String:
	return "<Alignable3D:%s>" % _node


func _get_transformed_aabb(incoming_node: Node3D) -> AABB:
	return (_node.global_transform.affine_inverse() * incoming_node.global_transform) * _get_node_aabb(incoming_node)

static func _get_node_aabb(node: Node3D) -> AABB:
	if node is VisualInstance3D:
		return node.get_aabb()

	return AABB()
