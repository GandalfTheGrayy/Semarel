class_name RemainsStateStore
extends RefCounted

const INVALID_DEATH_TICK: int = -1

var _entity_store: EntityStore
var _entity_ids: PackedInt64Array = PackedInt64Array()
var _death_ticks: PackedInt64Array = PackedInt64Array()
var _id_to_dense_index: Dictionary = {}


func _init(entity_store: EntityStore) -> void:
	assert(entity_store != null, "Remains state requires an EntityStore")
	_entity_store = entity_store


func add_remains_state(entity_id: int, death_tick: int) -> bool:
	if death_tick < 0 or not _entity_store.has_entity(entity_id) or has_remains_state(entity_id):
		return false
	_id_to_dense_index[entity_id] = _entity_ids.size()
	_entity_ids.append(entity_id)
	_death_ticks.append(death_tick)
	return true


func has_remains_state(entity_id: int) -> bool:
	return _id_to_dense_index.has(entity_id)


func get_death_tick(entity_id: int) -> int:
	if not has_remains_state(entity_id):
		return INVALID_DEATH_TICK
	var dense_index: int = _id_to_dense_index[entity_id]
	return _death_ticks[dense_index]


func remove_remains_state(entity_id: int) -> bool:
	if not has_remains_state(entity_id):
		return false
	var removed_index: int = _id_to_dense_index[entity_id]
	var last_index := _entity_ids.size() - 1
	if removed_index != last_index:
		var moved_entity_id := _entity_ids[last_index]
		_entity_ids[removed_index] = moved_entity_id
		_death_ticks[removed_index] = _death_ticks[last_index]
		_id_to_dense_index[moved_entity_id] = removed_index
	_id_to_dense_index.erase(entity_id)
	_entity_ids.resize(last_index)
	_death_ticks.resize(last_index)
	return true


func get_remains_count() -> int:
	return _entity_ids.size()


func get_dense_count() -> int:
	return _entity_ids.size()


func get_entity_id_at_dense_index(dense_index: int) -> int:
	if dense_index < 0 or dense_index >= _entity_ids.size():
		return EntityStore.INVALID_ENTITY_ID
	return _entity_ids[dense_index]


func is_bound_to(entity_store: EntityStore) -> bool:
	return _entity_store == entity_store
