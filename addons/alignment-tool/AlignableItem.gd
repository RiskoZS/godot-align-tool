## Represents an item that can be aligned by this plugin. Provides dimension-agnostic methods to
## calculate the item's AABB and to position it.
@tool
@abstract extends RefCounted

## Return the [class AABB] of this node, in the node's coordinate space. For 2D
## nodes, return an AABB with the Z size and position set to 0.
@abstract func get_aabb() -> AABB

## Return the global position of this node when the item was created. For 2D
## nodes, return a vector with the Z component set to 0.
@abstract func get_orig_global_transform() -> Transform3D

## Return the current global position of this node. For 2D nodes, return a
## vector with the Z component set to 0.
@abstract func get_global_transform() -> Transform3D

## Set the global position of this node to the given new value, performing the
## corresponding bookkeeping with the given [class EditorUndoRedoManager]. For
## 2D nodes, ignore the Z component of the target position.
@abstract func reposition_to(pos: Vector3, undoRedoManager: EditorUndoRedoManager) -> void
