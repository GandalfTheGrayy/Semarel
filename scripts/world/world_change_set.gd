class_name WorldChangeSet
extends RefCounted

var _revision: int
var _terrain_chunks: Array[Vector2i]


func _init(revision: int, terrain_chunks: Array[Vector2i]) -> void:
	assert(revision >= 0, "World change revision cannot be negative")
	_revision = revision
	var unique_chunks: Dictionary = {}
	for chunk_position: Vector2i in terrain_chunks:
		unique_chunks[chunk_position] = true
	_terrain_chunks = []
	for chunk_position: Vector2i in unique_chunks:
		_terrain_chunks.append(chunk_position)
	_terrain_chunks.sort_custom(_chunk_position_less)


func get_revision() -> int:
	return _revision


func is_empty() -> bool:
	return _terrain_chunks.is_empty()


func get_terrain_chunk_count() -> int:
	return _terrain_chunks.size()


func get_terrain_chunks() -> Array[Vector2i]:
	return _terrain_chunks.duplicate()


static func _chunk_position_less(left: Vector2i, right: Vector2i) -> bool:
	if left.y == right.y:
		return left.x < right.x
	return left.y < right.y
