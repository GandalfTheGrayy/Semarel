extends MainLoop

const ENTITY_COUNT: int = 10_000
const TICK_COUNT: int = 250
const WORLD_SIZE: Vector2i = Vector2i(256, 256)


func _initialize() -> void:
	var world := WorldGrid.new(WORLD_SIZE, WorldGrid.DEFAULT_CHUNK_SIZE, TerrainTypes.Id.LAND)
	var entities := EntityStore.new(WORLD_SIZE)
	var living := LivingStateStore.new(entities)
	var remains := RemainsStateStore.new(entities)
	for index in range(ENTITY_COUNT):
		var cell_position := Vector2i(index % WORLD_SIZE.x, (index / WORLD_SIZE.x) % WORLD_SIZE.y)
		var entity_id := entities.create_entity(cell_position)
		living.add_living_state(entity_id, 0)

	var aging := PrototypeAgingSystem.new()
	var transition := PrototypeLifecycleTransition.new()
	var movement := PrototypeEntityMovement.new()
	var total_moved := 0
	var total_dead := 0
	var started_usec := Time.get_ticks_usec()
	for tick_index in range(1, TICK_COUNT + 1):
		total_dead += aging.step(tick_index, entities, living, remains, transition)
		total_moved += movement.step(world, entities, living, tick_index)
	var elapsed_ms := (Time.get_ticks_usec() - started_usec) / 1000.0

	var checksum: int = 0
	for dense_index in range(entities.get_dense_count()):
		var entity_id := entities.get_entity_id_at_dense_index(dense_index)
		var position := entities.get_cell_position_at_dense_index(dense_index)
		checksum = (checksum * 31 + entity_id + position.x * 17 + position.y * 37) & 0x7fffffff
		if remains.has_remains_state(entity_id):
			checksum = (checksum * 31 + remains.get_death_tick(entity_id)) & 0x7fffffff

	print("LIFECYCLE_SIMULATION_SANITY")
	print("entities=%d ticks=%d" % [ENTITY_COUNT, TICK_COUNT])
	print("total_ms=%.3f avg_ms_per_tick=%.3f" % [elapsed_ms, elapsed_ms / TICK_COUNT])
	print("total_moved=%d total_dead=%d" % [total_moved, total_dead])
	print("final_living=%d final_remains=%d" % [living.get_living_count(), remains.get_remains_count()])
	print("checksum=%d world_revision=%d" % [checksum, world.get_revision()])


func _process(_delta: float) -> bool:
	return true
