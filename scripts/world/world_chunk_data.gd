class_name WorldChunkData
extends RefCounted

const INVALID_ELEVATION: int = -1
const MIN_ELEVATION: int = 0
const MAX_ELEVATION: int = 255
const DEFAULT_ELEVATION: int = 0

var _chunk_size: int
var _terrain: PackedByteArray
var _elevation: PackedByteArray


func _init(chunk_size: int, initial_terrain: int = TerrainTypes.Id.WATER) -> void:
	assert(chunk_size > 0, "Chunk size must be positive")
	assert(TerrainTypes.is_valid(initial_terrain), "Initial terrain ID must be valid")
	_chunk_size = chunk_size
	_terrain = PackedByteArray()
	_terrain.resize(_chunk_size * _chunk_size)
	_terrain.fill(initial_terrain)
	_elevation = PackedByteArray()
	_elevation.resize(_chunk_size * _chunk_size)
	_elevation.fill(DEFAULT_ELEVATION)


func get_chunk_size() -> int:
	return _chunk_size


func get_cell_count() -> int:
	return _terrain.size()


func get_terrain_copy() -> PackedByteArray:
	return _terrain.duplicate()


func get_elevation_copy() -> PackedByteArray:
	return _elevation.duplicate()


func is_valid_local_position(local_position: Vector2i) -> bool:
	return (
		local_position.x >= 0
		and local_position.y >= 0
		and local_position.x < _chunk_size
		and local_position.y < _chunk_size
	)


func get_terrain(local_position: Vector2i) -> int:
	if not is_valid_local_position(local_position):
		return TerrainTypes.INVALID
	return _terrain[_to_index(local_position)]


func set_terrain(local_position: Vector2i, terrain: int) -> bool:
	if not is_valid_local_position(local_position) or not TerrainTypes.is_valid(terrain):
		return false
	_terrain[_to_index(local_position)] = terrain
	return true


func get_elevation(local_position: Vector2i) -> int:
	if not is_valid_local_position(local_position):
		return INVALID_ELEVATION
	return _elevation[_to_index(local_position)]


func set_elevation(local_position: Vector2i, elevation: int) -> bool:
	if not is_valid_local_position(local_position) or not is_valid_elevation(elevation):
		return false
	_elevation[_to_index(local_position)] = elevation
	return true


func fill(terrain: int) -> bool:
	if not TerrainTypes.is_valid(terrain):
		return false
	_terrain.fill(terrain)
	return true


func fill_elevation(elevation: int) -> bool:
	if not is_valid_elevation(elevation):
		return false
	_elevation.fill(elevation)
	return true


static func is_valid_elevation(elevation: int) -> bool:
	return elevation >= MIN_ELEVATION and elevation <= MAX_ELEVATION


func _to_index(local_position: Vector2i) -> int:
	return local_position.y * _chunk_size + local_position.x
