class_name WorldGrid
extends RefCounted

const DEFAULT_CHUNK_SIZE: int = 64
const DEFAULT_WORLD_SIZE: Vector2i = Vector2i(256, 256)

var _world_size: Vector2i
var _chunk_size: int
var _chunk_count: Vector2i
var _chunks: Array[WorldChunkData] = []
var _dirty_chunks: Dictionary = {}


func _init(
	world_size: Vector2i = DEFAULT_WORLD_SIZE,
	chunk_size: int = DEFAULT_CHUNK_SIZE,
	initial_terrain: int = TerrainTypes.Id.WATER,
) -> void:
	assert(world_size.x > 0 and world_size.y > 0, "World dimensions must be positive")
	assert(chunk_size > 0, "Chunk size must be positive")
	assert(TerrainTypes.is_valid(initial_terrain), "Initial terrain ID must be valid")
	_world_size = world_size
	_chunk_size = chunk_size
	_chunk_count = Vector2i(
		ceili(float(_world_size.x) / _chunk_size),
		ceili(float(_world_size.y) / _chunk_size),
	)
	_chunks.resize(_chunk_count.x * _chunk_count.y)
	for chunk_y in range(_chunk_count.y):
		for chunk_x in range(_chunk_count.x):
			var chunk_position := Vector2i(chunk_x, chunk_y)
			_chunks[_chunk_to_index(chunk_position)] = WorldChunkData.new(_chunk_size, initial_terrain)


func get_world_size() -> Vector2i:
	return _world_size


func get_chunk_size() -> int:
	return _chunk_size


func get_chunk_count() -> Vector2i:
	return _chunk_count


func is_valid_chunk_position(chunk_position: Vector2i) -> bool:
	return (
		chunk_position.x >= 0
		and chunk_position.y >= 0
		and chunk_position.x < _chunk_count.x
		and chunk_position.y < _chunk_count.y
	)


func chunk_to_world_origin(chunk_position: Vector2i) -> Vector2i:
	return chunk_position * _chunk_size


func get_chunk_world_rect(chunk_position: Vector2i) -> Rect2i:
	if not is_valid_chunk_position(chunk_position):
		return Rect2i()
	var origin := chunk_to_world_origin(chunk_position)
	var remaining_size := _world_size - origin
	var actual_size := Vector2i(
		mini(_chunk_size, remaining_size.x),
		mini(_chunk_size, remaining_size.y),
	)
	return Rect2i(origin, actual_size)


func get_chunk_terrain_copy(chunk_position: Vector2i) -> PackedByteArray:
	if not is_valid_chunk_position(chunk_position):
		return PackedByteArray()
	return _get_chunk(chunk_position).get_terrain_copy()


func is_inside_world(world_position: Vector2i) -> bool:
	return (
		world_position.x >= 0
		and world_position.y >= 0
		and world_position.x < _world_size.x
		and world_position.y < _world_size.y
	)


func world_to_chunk(world_position: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(world_position.x) / _chunk_size),
		floori(float(world_position.y) / _chunk_size),
	)


func world_to_local(world_position: Vector2i) -> Vector2i:
	var chunk_position := world_to_chunk(world_position)
	return world_position - chunk_position * _chunk_size


func get_terrain(world_position: Vector2i) -> int:
	if not is_inside_world(world_position):
		return TerrainTypes.INVALID
	var chunk := _get_chunk(world_to_chunk(world_position))
	return chunk.get_terrain(world_to_local(world_position))


func set_terrain(world_position: Vector2i, terrain: int) -> bool:
	if not is_inside_world(world_position) or not TerrainTypes.is_valid(terrain):
		return false
	var chunk_position := world_to_chunk(world_position)
	var chunk := _get_chunk(chunk_position)
	var local_position := world_to_local(world_position)
	if chunk.get_terrain(local_position) == terrain:
		return true
	if not chunk.set_terrain(local_position, terrain):
		return false
	_dirty_chunks[chunk_position] = true
	return true


func is_chunk_dirty(chunk_position: Vector2i) -> bool:
	return _dirty_chunks.has(chunk_position)


func get_dirty_chunk_count() -> int:
	return _dirty_chunks.size()


func get_dirty_chunks() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for chunk_position: Vector2i in _dirty_chunks:
		result.append(chunk_position)
	return result


func consume_dirty_chunks() -> Array[Vector2i]:
	var result := get_dirty_chunks()
	_dirty_chunks.clear()
	return result


func clear_dirty_chunks() -> void:
	_dirty_chunks.clear()


func _get_chunk(chunk_position: Vector2i) -> WorldChunkData:
	return _chunks[_chunk_to_index(chunk_position)]


func _chunk_to_index(chunk_position: Vector2i) -> int:
	return chunk_position.y * _chunk_count.x + chunk_position.x
