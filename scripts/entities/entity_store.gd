class_name EntityStore
extends RefCounted

const INVALID_ENTITY_ID: int = 0
const INVALID_CELL_POSITION: Vector2i = Vector2i(-1, -1)

var _world_size: Vector2i
var _next_entity_id: int = 1
var _entity_ids: PackedInt64Array = PackedInt64Array()
var _cell_x: PackedInt32Array = PackedInt32Array()
var _cell_y: PackedInt32Array = PackedInt32Array()
var _id_to_dense_index: Dictionary = {}


func _init(world_size: Vector2i) -> void:
	assert(world_size.x > 0 and world_size.y > 0, "EntityStore world dimensions must be positive")
	_world_size = world_size


func create_entity(cell_position: Vector2i) -> int:
	if not is_inside_world(cell_position):
		return INVALID_ENTITY_ID
	var entity_id := _next_entity_id
	_next_entity_id += 1
	_id_to_dense_index[entity_id] = _entity_ids.size()
	_entity_ids.append(entity_id)
	_cell_x.append(cell_position.x)
	_cell_y.append(cell_position.y)
	return entity_id


func has_entity(entity_id: int) -> bool:
	return _id_to_dense_index.has(entity_id)


func get_cell_position(entity_id: int) -> Vector2i:
	if not has_entity(entity_id):
		return INVALID_CELL_POSITION
	var dense_index: int = _id_to_dense_index[entity_id]
	return Vector2i(_cell_x[dense_index], _cell_y[dense_index])


func set_cell_position(entity_id: int, cell_position: Vector2i) -> bool:
	if not has_entity(entity_id) or not is_inside_world(cell_position):
		return false
	var dense_index: int = _id_to_dense_index[entity_id]
	_cell_x[dense_index] = cell_position.x
	_cell_y[dense_index] = cell_position.y
	return true


func remove_entity(entity_id: int) -> bool:
	if not has_entity(entity_id):
		return false
	var removed_index: int = _id_to_dense_index[entity_id]
	var last_index := _entity_ids.size() - 1
	if removed_index != last_index:
		var moved_entity_id := _entity_ids[last_index]
		_entity_ids[removed_index] = moved_entity_id
		_cell_x[removed_index] = _cell_x[last_index]
		_cell_y[removed_index] = _cell_y[last_index]
		_id_to_dense_index[moved_entity_id] = removed_index
	_id_to_dense_index.erase(entity_id)
	_entity_ids.resize(last_index)
	_cell_x.resize(last_index)
	_cell_y.resize(last_index)
	return true


func get_entity_count() -> int:
	return _entity_ids.size()


func get_world_size() -> Vector2i:
	return _world_size


func is_inside_world(cell_position: Vector2i) -> bool:
	return (
		cell_position.x >= 0
		and cell_position.y >= 0
		and cell_position.x < _world_size.x
		and cell_position.y < _world_size.y
	)


func get_entity_ids_copy() -> PackedInt64Array:
	return _entity_ids.duplicate()


func get_cell_positions_copy() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	positions.resize(_entity_ids.size())
	for dense_index in range(_entity_ids.size()):
		positions[dense_index] = Vector2i(_cell_x[dense_index], _cell_y[dense_index])
	return positions
