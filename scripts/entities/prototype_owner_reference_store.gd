class_name PrototypeOwnerReferenceStore
extends RefCounted

const INVALID_OWNER_ENTITY_ID: int = EntityStore.INVALID_ENTITY_ID

var _entity_store: EntityStore
var _entity_ids: PackedInt64Array = PackedInt64Array()
var _owner_entity_ids: PackedInt64Array = PackedInt64Array()
var _id_to_dense_index: Dictionary = {}


func _init(entity_store: EntityStore) -> void:
	assert(entity_store != null, "Owner references require an EntityStore")
	_entity_store = entity_store


func set_owner(entity_id: int, owner_entity_id: int) -> bool:
	if not _entity_store.has_entity(entity_id) or not _entity_store.has_entity(owner_entity_id):
		return false
	if has_owner_reference(entity_id):
		var dense_index: int = _id_to_dense_index[entity_id]
		_owner_entity_ids[dense_index] = owner_entity_id
		return true
	_id_to_dense_index[entity_id] = _entity_ids.size()
	_entity_ids.append(entity_id)
	_owner_entity_ids.append(owner_entity_id)
	return true


func has_owner_reference(entity_id: int) -> bool:
	return _id_to_dense_index.has(entity_id)


func get_owner_entity_id(entity_id: int) -> int:
	if not has_owner_reference(entity_id):
		return INVALID_OWNER_ENTITY_ID
	var dense_index: int = _id_to_dense_index[entity_id]
	return _owner_entity_ids[dense_index]


func is_owner_resolved(entity_id: int) -> bool:
	var owner_entity_id := get_owner_entity_id(entity_id)
	return owner_entity_id != INVALID_OWNER_ENTITY_ID and _entity_store.has_entity(owner_entity_id)


func clear_owner(entity_id: int) -> bool:
	if not has_owner_reference(entity_id):
		return false
	var removed_index: int = _id_to_dense_index[entity_id]
	var last_index := _entity_ids.size() - 1
	if removed_index != last_index:
		var moved_entity_id := _entity_ids[last_index]
		_entity_ids[removed_index] = moved_entity_id
		_owner_entity_ids[removed_index] = _owner_entity_ids[last_index]
		_id_to_dense_index[moved_entity_id] = removed_index
	_id_to_dense_index.erase(entity_id)
	_entity_ids.resize(last_index)
	_owner_entity_ids.resize(last_index)
	return true


func get_owner_reference_count() -> int:
	return _entity_ids.size()


func get_dense_count() -> int:
	return _entity_ids.size()


func get_entity_id_at_dense_index(dense_index: int) -> int:
	if dense_index < 0 or dense_index >= _entity_ids.size():
		return EntityStore.INVALID_ENTITY_ID
	return _entity_ids[dense_index]


func is_bound_to(entity_store: EntityStore) -> bool:
	return _entity_store == entity_store
