extends SceneTree

const ENTITY_COUNT: int = 10_000
const TICK_COUNT: int = 100
const WORLD_SIZE: Vector2i = Vector2i(256, 256)


func _init() -> void:
	var world := WorldGrid.new(WORLD_SIZE, WorldGrid.DEFAULT_CHUNK_SIZE, TerrainTypes.Id.LAND)
	var store := EntityStore.new(WORLD_SIZE)
	for index in range(ENTITY_COUNT):
		store.create_entity(Vector2i(index % WORLD_SIZE.x, floori(float(index) / WORLD_SIZE.x)))
	var movement := PrototypeEntityMovement.new()
	var total_moved_count: int = 0
	var movement_started := Time.get_ticks_usec()
	for tick_index in range(1, TICK_COUNT + 1):
		total_moved_count += movement.step(world, store, tick_index)
	var movement_usec := Time.get_ticks_usec() - movement_started

	var checksum: int = 0
	for dense_index in range(store.get_dense_count()):
		var entity_id := store.get_entity_id_at_dense_index(dense_index)
		var position := store.get_cell_position_at_dense_index(dense_index)
		checksum = (checksum + entity_id * 31 + position.x * 7 + position.y) & 0x7fffffff

	print("ENTITY_MOVEMENT_SANITY")
	print("entities=%d ticks=%d" % [store.get_entity_count(), TICK_COUNT])
	print(
		"total_ms=%.3f average_ms_per_tick=%.3f"
		% [movement_usec / 1000.0, movement_usec / 1000.0 / TICK_COUNT],
	)
	print("total_moved=%d final_checksum=%d" % [total_moved_count, checksum])
	print("world_revision=%d" % world.get_revision())
	quit()
