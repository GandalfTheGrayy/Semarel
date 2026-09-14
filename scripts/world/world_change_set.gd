class_name WorldChangeSet
extends RefCounted

var _revision: int
var _terrain_chunks: Array[Vector2i]
var _elevation_chunks: Array[Vector2i]


func _init(
	revision: int,
	terrain_chunks: Array[Vector2i],
	elevation_chunks: Array[Vector2i] = [],
) -> void:
	assert(revision >= 0, "World change revision cannot be negative")
	_revision = revision
	_terrain_chunks = _copy_unique_sorted(terrain_chunks)
	_elevation_chunks = _copy_unique_sorted(elevation_chunks)


func get_revision() -> int:
	return _revision


func is_empty() -> bool:
	return _terrain_chunks.is_empty() and _elevation_chunks.is_empty()


func get_terrain_chunk_count() -> int:
	return _terrain_chunks.size()


func get_terrain_chunks() -> Array[Vector2i]:
	return _terrain_chunks.duplicate()


func get_elevation_chunk_count() -> int:
	return _elevation_chunks.size()


func get_elevation_chunks() -> Array[Vector2i]:
	return _elevation_chunks.duplicate()


static func _copy_unique_sorted(chunks: Array[Vector2i]) -> Array[Vector2i]:
	var unique_chunks: Dictionary = {}
	for chunk_position: Vector2i in chunks:
		unique_chunks[chunk_position] = true
	var result: Array[Vector2i] = []
	for chunk_position: Vector2i in unique_chunks:
		result.append(chunk_position)
	result.sort_custom(_chunk_position_less)
	return result


static func _chunk_position_less(left: Vector2i, right: Vector2i) -> bool:
	if left.y == right.y:
		return left.x < right.x
	return left.y < right.y
