class_name PrototypeEntityMovement
extends RefCounted

const _HASH_MASK: int = 0x7fffffff
const _DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]


func step(world_grid: WorldGrid, entity_store: EntityStore, tick_index: int) -> int:
	assert(world_grid != null, "Prototype movement requires a WorldGrid")
	assert(entity_store != null, "Prototype movement requires an EntityStore")
	assert(world_grid.get_world_size() == entity_store.get_world_size(), "World and entity bounds must match")
	assert(tick_index >= 0, "Simulation tick index cannot be negative")

	var moved_entity_count := 0
	var dense_count := entity_store.get_dense_count()
	for dense_index in range(dense_count):
		var entity_id := entity_store.get_entity_id_at_dense_index(dense_index)
		var current_position := entity_store.get_cell_position_at_dense_index(dense_index)
		var direction_start := _direction_start(entity_id, tick_index)
		for direction_attempt in range(_DIRECTIONS.size()):
			var direction_index := (direction_start + direction_attempt) % _DIRECTIONS.size()
			var destination := current_position + _DIRECTIONS[direction_index]
			if not _is_valid_destination(world_grid, entity_store, destination):
				continue
			if entity_store.set_cell_position_at_dense_index(dense_index, destination):
				moved_entity_count += 1
			break
	return moved_entity_count


static func _direction_start(entity_id: int, tick_index: int) -> int:
	var mixed := (entity_id * 73_856_093 + tick_index * 19_349_663) & _HASH_MASK
	mixed = ((mixed ^ (mixed >> 13)) * 1_274_126_177) & _HASH_MASK
	return (mixed ^ (mixed >> 16)) & 3


static func _is_valid_destination(
	world_grid: WorldGrid,
	entity_store: EntityStore,
	destination: Vector2i,
) -> bool:
	if not entity_store.is_inside_world(destination) or not world_grid.is_inside_world(destination):
		return false
	var terrain := world_grid.get_terrain(destination)
	return TerrainTypes.is_valid(terrain) and terrain != TerrainTypes.Id.WATER
