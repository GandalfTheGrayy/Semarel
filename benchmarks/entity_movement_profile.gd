extends SceneTree

const ENTITY_COUNT: int = 10_000
const TICK_COUNT: int = 100
const WORLD_SIZE: Vector2i = Vector2i(256, 256)
const _HASH_MASK: int = 0x7fffffff


func _init() -> void:
	var world := WorldGrid.new(WORLD_SIZE, WorldGrid.DEFAULT_CHUNK_SIZE, TerrainTypes.Id.LAND)
	var store := _create_store()
	var representative_positions: Array[Vector2i] = []
	var alternate_positions: Array[Vector2i] = []
	representative_positions.resize(ENTITY_COUNT)
	alternate_positions.resize(ENTITY_COUNT)
	for dense_index in range(ENTITY_COUNT):
		var flat_index := (dense_index * 97) % (WORLD_SIZE.x * WORLD_SIZE.y)
		var position := Vector2i(flat_index % WORLD_SIZE.x, flat_index / WORLD_SIZE.x)
		representative_positions[dense_index] = position
		alternate_positions[dense_index] = Vector2i((position.x + 1) % WORLD_SIZE.x, position.y)

	var hash_checksum: int = 0
	var hash_started := Time.get_ticks_usec()
	for tick_index in range(1, TICK_COUNT + 1):
		for dense_index in range(store.get_dense_count()):
			var entity_id := store.get_entity_id_at_dense_index(dense_index)
			var direction_start := _direction_start(entity_id, tick_index)
			hash_checksum = (hash_checksum + entity_id * 31 + direction_start) & _HASH_MASK
	var hash_usec := Time.get_ticks_usec() - hash_started

	var position_read_checksum: int = 0
	var position_read_started := Time.get_ticks_usec()
	for tick_index in range(1, TICK_COUNT + 1):
		for dense_index in range(store.get_dense_count()):
			var position := store.get_cell_position_at_dense_index(dense_index)
			position_read_checksum = (
				position_read_checksum + position.x * 7 + position.y + tick_index
			) & _HASH_MASK
	var position_read_usec := Time.get_ticks_usec() - position_read_started

	var terrain_read_checksum: int = 0
	var terrain_read_started := Time.get_ticks_usec()
	for tick_index in range(1, TICK_COUNT + 1):
		for dense_index in range(representative_positions.size()):
			var terrain := world.get_terrain(representative_positions[dense_index])
			terrain_read_checksum = (terrain_read_checksum + terrain + tick_index) & _HASH_MASK
	var terrain_read_usec := Time.get_ticks_usec() - terrain_read_started

	var position_write_started := Time.get_ticks_usec()
	for tick_index in range(1, TICK_COUNT + 1):
		var target_positions := alternate_positions if tick_index % 2 == 1 else representative_positions
		for dense_index in range(store.get_dense_count()):
			store.set_cell_position_at_dense_index(dense_index, target_positions[dense_index])
	var position_write_usec := Time.get_ticks_usec() - position_write_started
	var position_write_checksum := _position_checksum(store)

	var movement_store := _create_store()
	var movement := PrototypeEntityMovement.new()
	var total_moved_count: int = 0
	var movement_started := Time.get_ticks_usec()
	for tick_index in range(1, TICK_COUNT + 1):
		total_moved_count += movement.step(world, movement_store, tick_index)
	var movement_usec := Time.get_ticks_usec() - movement_started
	var movement_checksum := _movement_checksum(movement_store)

	print("ENTITY_MOVEMENT_PROFILE")
	print(
		"entities=%d ticks=%d operations_per_component=%d"
		% [ENTITY_COUNT, TICK_COUNT, ENTITY_COUNT * TICK_COUNT],
	)
	print("dense_hash_ms=%.3f checksum=%d" % [hash_usec / 1000.0, hash_checksum])
	print(
		"dense_position_reads_ms=%.3f checksum=%d"
		% [position_read_usec / 1000.0, position_read_checksum],
	)
	print(
		"world_terrain_reads_ms=%.3f checksum=%d"
		% [terrain_read_usec / 1000.0, terrain_read_checksum],
	)
	print(
		"position_writes_ms=%.3f checksum=%d"
		% [position_write_usec / 1000.0, position_write_checksum],
	)
	print(
		"full_movement_ms=%.3f moved=%d final_checksum=%d"
		% [movement_usec / 1000.0, total_moved_count, movement_checksum],
	)
	print("world_revision=%d" % world.get_revision())
	quit()


func _create_store() -> EntityStore:
	var store := EntityStore.new(WORLD_SIZE)
	for index in range(ENTITY_COUNT):
		store.create_entity(Vector2i(index % WORLD_SIZE.x, floori(float(index) / WORLD_SIZE.x)))
	return store


# Mirrors the production movement decision so this benchmark measures the same work
# without adding a diagnostic-only method to the production API.
static func _direction_start(entity_id: int, tick_index: int) -> int:
	var mixed := (entity_id * 73_856_093 + tick_index * 19_349_663) & _HASH_MASK
	mixed = ((mixed ^ (mixed >> 13)) * 1_274_126_177) & _HASH_MASK
	return (mixed ^ (mixed >> 16)) & 3


static func _position_checksum(store: EntityStore) -> int:
	var checksum: int = 0
	for dense_index in range(store.get_dense_count()):
		var position := store.get_cell_position_at_dense_index(dense_index)
		checksum = (checksum + position.x * 7 + position.y) & _HASH_MASK
	return checksum


static func _movement_checksum(store: EntityStore) -> int:
	var checksum: int = 0
	for dense_index in range(store.get_dense_count()):
		var entity_id := store.get_entity_id_at_dense_index(dense_index)
		var position := store.get_cell_position_at_dense_index(dense_index)
		checksum = (checksum + entity_id * 31 + position.x * 7 + position.y) & _HASH_MASK
	return checksum
