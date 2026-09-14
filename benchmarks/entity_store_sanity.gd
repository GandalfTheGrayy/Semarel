extends SceneTree

const ENTITY_COUNT: int = 10_000
const ACCESS_COUNT: int = 100_000
const WORLD_SIZE: Vector2i = Vector2i(256, 256)


func _init() -> void:
	var store := EntityStore.new(WORLD_SIZE)
	var create_started := Time.get_ticks_usec()
	for index in range(ENTITY_COUNT):
		store.create_entity(Vector2i(index % WORLD_SIZE.x, floori(float(index) / WORLD_SIZE.x)))
	var create_usec := Time.get_ticks_usec() - create_started

	var ids := store.get_entity_ids_copy()
	var checksum: int = 0
	var access_started := Time.get_ticks_usec()
	for operation in range(ACCESS_COUNT):
		var entity_id := int(ids[(operation * 97) % ids.size()])
		var position := store.get_cell_position(entity_id)
		var updated_position := Vector2i((position.x + 1) % WORLD_SIZE.x, position.y)
		store.set_cell_position(entity_id, updated_position)
		checksum = (checksum + entity_id * 31 + updated_position.x * 7 + updated_position.y) & 0x7fffffff
	var access_usec := Time.get_ticks_usec() - access_started

	var remove_started := Time.get_ticks_usec()
	for index in range(0, ids.size(), 4):
		store.remove_entity(int(ids[index]))
	var remove_usec := Time.get_ticks_usec() - remove_started

	print("ENTITY_STORE_SANITY")
	print("created=%d create_ms=%.3f" % [ENTITY_COUNT, create_usec / 1000.0])
	print("read_updates=%d read_update_ms=%.3f" % [ACCESS_COUNT, access_usec / 1000.0])
	print("removed=%d remove_ms=%.3f" % [ENTITY_COUNT / 4, remove_usec / 1000.0])
	print("final_count=%d checksum=%d" % [store.get_entity_count(), checksum])
	quit()
