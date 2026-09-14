extends MainLoop

const TEST_POSITIONS: Array[Vector2i] = [
	Vector2i(2, 2),
	Vector2i(5, 3),
	Vector2i(9, 7),
	Vector2i(12, 11),
]

var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	_test_determinism_rng_isolation_and_first_tick()
	_test_render_schedule_independence()
	_test_prototype_terrain_rule_and_blocked_stay()
	_test_bounds_one_cell_and_identity_contract()
	_test_dense_order_independence()
	_test_living_dense_order_independence()
	_test_movement_only_living()
	_test_presentation_snapshot_and_catchup_refresh()
	_test_data_only_hot_path_contract()
	if _failures == 0:
		print("ENTITY_MOVEMENT_TESTS_PASSED assertions=%d" % _assertions)
	else:
		printerr("ENTITY_MOVEMENT_TESTS_FAILED failures=%d assertions=%d" % [_failures, _assertions])
		assert(false, "Entity movement test suite failed")


func _process(_delta: float) -> bool:
	return true


func _test_determinism_rng_isolation_and_first_tick() -> void:
	var world := WorldGrid.new(Vector2i(16, 16), 8, TerrainTypes.Id.LAND)
	var first := _create_store(Vector2i(16, 16), TEST_POSITIONS)
	var second := _create_store(Vector2i(16, 16), TEST_POSITIONS)
	var first_living := _create_living_store_for_all(first)
	var second_living := _create_living_store_for_all(second)
	seed(71)
	for index in range(37):
		randi()
	_run_ticks(world, first, first_living, 1, 20)
	seed(902)
	for index in range(83):
		randf()
	_run_ticks(world, second, second_living, 1, 20)
	_expect_equal(first.get_entity_ids_copy(), second.get_entity_ids_copy(), "deterministic runs retain identical IDs")
	_expect_equal(first.get_cell_positions_copy(), second.get_cell_positions_copy(), "same state and ticks ignore global RNG")

	var clock_store := _create_store(Vector2i(16, 16), TEST_POSITIONS)
	var direct_store := _create_store(Vector2i(16, 16), TEST_POSITIONS)
	var clock_living := _create_living_store_for_all(clock_store)
	var direct_living := _create_living_store_for_all(direct_store)
	var clock := SimulationClock.new()
	clock.add_time(0.1)
	_expect_true(clock.consume_tick(), "first fixed tick can be consumed")
	_expect_equal(clock.get_tick_index(), 1, "first consumed simulation tick is index one")
	PrototypeEntityMovement.new().step(world, clock_store, clock_living, clock.get_tick_index())
	PrototypeEntityMovement.new().step(world, direct_store, direct_living, 1)
	_expect_equal(clock_store.get_cell_positions_copy(), direct_store.get_cell_positions_copy(), "main tick index has no off-by-one shift")


func _test_render_schedule_independence() -> void:
	var sixty_frames := _run_render_schedule(60, 1.0 / 60.0)
	var thirty_frames := _run_render_schedule(30, 1.0 / 30.0)
	var ten_frames := _run_render_schedule(10, 0.1)
	_expect_equal(sixty_frames.tick_index, 10, "sixty frames reach ten ticks")
	_expect_equal(thirty_frames.tick_index, 10, "thirty frames reach ten ticks")
	_expect_equal(ten_frames.tick_index, 10, "ten frames reach ten ticks")
	_expect_equal(sixty_frames.positions, thirty_frames.positions, "60 Hz and 30 Hz render schedules match")
	_expect_equal(sixty_frames.positions, ten_frames.positions, "60 Hz and 10 Hz render schedules match")


func _test_prototype_terrain_rule_and_blocked_stay() -> void:
	for passable_terrain in [TerrainTypes.Id.LAND, TerrainTypes.Id.SAND, TerrainTypes.Id.ROCK]:
		var coast_world := WorldGrid.new(Vector2i(3, 3), 3, TerrainTypes.Id.WATER)
		coast_world.set_terrain(Vector2i(1, 1), TerrainTypes.Id.LAND)
		coast_world.set_terrain(Vector2i(2, 1), passable_terrain)
		coast_world.commit_changes()
		var coast_store := EntityStore.new(Vector2i(3, 3))
		var coast_id := coast_store.create_entity(Vector2i(1, 1))
		var coast_living := LivingStateStore.new(coast_store)
		coast_living.add_living_state(coast_id, 0)
		var moved := PrototypeEntityMovement.new().step(coast_world, coast_store, coast_living, 17)
		_expect_equal(moved, 1, "entity takes only valid terrain %d neighbor" % passable_terrain)
		_expect_equal(coast_store.get_cell_position(coast_id), Vector2i(2, 1), "prototype movement reaches terrain %d" % passable_terrain)
		_expect_equal(coast_world.get_terrain(coast_store.get_cell_position(coast_id)), passable_terrain, "destination retains terrain %d" % passable_terrain)

	var water_world := WorldGrid.new(Vector2i(3, 3), 3, TerrainTypes.Id.WATER)
	water_world.set_terrain(Vector2i(1, 1), TerrainTypes.Id.LAND)
	water_world.commit_changes()
	var water_store := EntityStore.new(Vector2i(3, 3))
	var water_blocked_id := water_store.create_entity(Vector2i(1, 1))
	var water_living := LivingStateStore.new(water_store)
	water_living.add_living_state(water_blocked_id, 0)
	_expect_equal(
		PrototypeEntityMovement.new().step(water_world, water_store, water_living, 17),
		0,
		"WATER blocks every cardinal destination",
	)
	_expect_equal(water_store.get_cell_position(water_blocked_id), Vector2i(1, 1), "WATER-blocked entity stays safely")

	var blocked_world := WorldGrid.new(Vector2i.ONE, 1, TerrainTypes.Id.LAND)
	var blocked_store := EntityStore.new(Vector2i.ONE)
	var blocked_id := blocked_store.create_entity(Vector2i.ZERO)
	var blocked_living := LivingStateStore.new(blocked_store)
	blocked_living.add_living_state(blocked_id, 0)
	_expect_equal(
		PrototypeEntityMovement.new().step(blocked_world, blocked_store, blocked_living, 1),
		0,
		"fully blocked entity reports no move",
	)
	_expect_equal(blocked_store.get_cell_position(blocked_id), Vector2i.ZERO, "fully blocked entity stays safely")


func _test_bounds_one_cell_and_identity_contract() -> void:
	var world := WorldGrid.new(Vector2i(4, 4), 2, TerrainTypes.Id.LAND)
	var store := _create_store(
		Vector2i(4, 4),
		[Vector2i.ZERO, Vector2i(3, 3), Vector2i(0, 3), Vector2i(3, 0)],
	)
	var ids_before := store.get_entity_ids_copy()
	var count_before := store.get_entity_count()
	var world_revision_before := world.get_revision()
	var living := _create_living_store_for_all(store)
	var movement := PrototypeEntityMovement.new()
	for tick_index in range(1, 21):
		var positions_before := store.get_cell_positions_copy()
		movement.step(world, store, living, tick_index)
		var positions_after := store.get_cell_positions_copy()
		for dense_index in range(store.get_dense_count()):
			var distance := _manhattan_distance(positions_before[dense_index], positions_after[dense_index])
			_expect_true(distance <= 1, "entity moves at most one cell on tick %d index %d" % [tick_index, dense_index])
			_expect_true(store.is_inside_world(positions_after[dense_index]), "entity remains in bounds on tick %d index %d" % [tick_index, dense_index])
	_expect_equal(store.get_entity_ids_copy(), ids_before, "movement preserves stable IDs")
	_expect_equal(store.get_entity_count(), count_before, "movement preserves entity count")
	_expect_equal(world.get_revision(), world_revision_before, "entity movement does not advance world revision")


func _test_dense_order_independence() -> void:
	var world := WorldGrid.new(Vector2i(12, 12), 4, TerrainTypes.Id.LAND)
	var first := EntityStore.new(Vector2i(12, 12))
	var second := EntityStore.new(Vector2i(12, 12))
	for entity_index in range(6):
		var position := Vector2i(entity_index + 2, entity_index + 1)
		first.create_entity(position)
		second.create_entity(position)
	first.remove_entity(2)
	first.remove_entity(3)
	second.remove_entity(3)
	second.remove_entity(2)
	_expect_true(first.get_entity_ids_copy() != second.get_entity_ids_copy(), "same surviving IDs can have different dense order")
	var first_living := _create_living_store_for_all(first)
	var second_living := _create_living_store_for_all(second)
	var movement := PrototypeEntityMovement.new()
	movement.step(world, first, first_living, 23)
	movement.step(world, second, second_living, 23)
	for entity_id in [1, 4, 5, 6]:
		_expect_equal(first.get_cell_position(entity_id), second.get_cell_position(entity_id), "stable ID drives movement for entity %d" % entity_id)


func _test_living_dense_order_independence() -> void:
	var world := WorldGrid.new(Vector2i(12, 12), 4, TerrainTypes.Id.LAND)
	var first := EntityStore.new(Vector2i(12, 12))
	var second := EntityStore.new(Vector2i(12, 12))
	for entity_index in range(6):
		var position := Vector2i(entity_index + 2, entity_index + 1)
		first.create_entity(position)
		second.create_entity(position)
	var first_living := _create_living_store_for_all(first)
	var second_living := _create_living_store_for_all(second)
	first_living.remove_living_state(2)
	first_living.remove_living_state(3)
	second_living.remove_living_state(3)
	second_living.remove_living_state(2)
	_expect_true(
		_first_living_ids(first_living) != _first_living_ids(second_living),
		"same living membership can have different dense order",
	)
	var movement := PrototypeEntityMovement.new()
	movement.step(world, first, first_living, 23)
	movement.step(world, second, second_living, 23)
	for entity_id in [1, 4, 5, 6]:
		_expect_equal(
			first.get_cell_position(entity_id),
			second.get_cell_position(entity_id),
			"living stable ID drives movement for entity %d" % entity_id,
		)


func _test_movement_only_living() -> void:
	var world := WorldGrid.new(Vector2i(8, 8), 4, TerrainTypes.Id.LAND)
	var store := EntityStore.new(Vector2i(8, 8))
	var living_id := store.create_entity(Vector2i(3, 3))
	var non_living_id := store.create_entity(Vector2i(3, 3))
	var living := LivingStateStore.new(store)
	living.add_living_state(living_id, 0)
	var non_living_position := store.get_cell_position(non_living_id)
	var living_moved := false
	var movement := PrototypeEntityMovement.new()
	for tick_index in range(1, 6):
		var before := store.get_cell_position(living_id)
		movement.step(world, store, living, tick_index)
		living_moved = living_moved or store.get_cell_position(living_id) != before
		_expect_equal(
			store.get_cell_position(non_living_id),
			non_living_position,
			"generic non-living entity stays fixed on tick %d" % tick_index,
		)
	_expect_true(living_moved, "living entity participates in prototype movement")
	_expect_equal(store.get_entity_count(), 2, "movement preserves heterogeneous generic entities")
	_expect_equal(living.get_living_count(), 1, "movement preserves optional living membership")


func _test_presentation_snapshot_and_catchup_refresh() -> void:
	var world := WorldGrid.new(Vector2i(32, 32), 8, TerrainTypes.Id.LAND)
	var store := EntityStore.new(Vector2i(32, 32))
	for index in range(100):
		store.create_entity(Vector2i(index % 32, floori(float(index) / 32.0)))
	var living := _create_living_store_for_all(store)
	var renderer := DebugEntityRenderer.new()
	renderer.set_entity_store(store)
	renderer.refresh_from_store()
	var cached_before := renderer.get_marker_positions_copy()
	var clock := SimulationClock.new()
	var movement := PrototypeEntityMovement.new()
	clock.add_time(0.5)
	var frame_moved_count := 0
	while clock.consume_tick():
		frame_moved_count += movement.step(world, store, living, clock.get_tick_index())
	_expect_equal(clock.get_tick_index(), 5, "catchup processes five authoritative ticks")
	_expect_true(frame_moved_count > 0, "catchup moves entities")
	_expect_equal(renderer.get_marker_positions_copy(), cached_before, "renderer snapshot stays stable before explicit refresh")
	if frame_moved_count > 0:
		renderer.refresh_from_store()
	_expect_equal(renderer.get_refresh_count(), 2, "five catchup ticks cause one frame-end refresh")
	_expect_equal(renderer.get_marker_positions_copy(), store.get_cell_positions_copy(), "explicit refresh shows authoritative final positions")
	_expect_equal(renderer.get_marker_count(), 100, "movement presentation retains all markers")
	_expect_equal(renderer.get_child_count(), 0, "movement presentation creates no entity child Nodes")
	renderer.free()


func _test_data_only_hot_path_contract() -> void:
	var movement := PrototypeEntityMovement.new()
	_expect_true(movement is RefCounted, "movement is data-only RefCounted")
	_expect_false(movement.has_method("get_tree"), "movement has no scene-tree API")
	var source := FileAccess.get_file_as_string("res://scripts/simulation/prototype_entity_movement.gd")
	_expect_true(source.contains("get_dense_count"), "movement uses dense iteration")
	_expect_true(source.contains("get_entity_id_at_dense_index"), "movement decisions read stable IDs")
	_expect_true(source.contains("LivingStateStore"), "movement requires explicit living membership")
	_expect_false(source.contains("get_entity_ids_copy"), "movement hot path creates no full ID snapshot")
	_expect_false(source.contains("get_cell_positions_copy"), "movement hot path creates no full position snapshot")
	_expect_false(source.contains("RandomNumberGenerator"), "movement allocates no per-entity RNG")
	_expect_false(source.contains("randi("), "movement ignores global integer RNG")
	_expect_false(source.contains("randf("), "movement ignores global float RNG")
	_expect_false(source.contains("create_entity"), "movement pass creates no entities")
	_expect_false(source.contains("remove_entity"), "movement pass removes no entities")
	_expect_false(source.contains("Renderer"), "movement has no presentation dependency")


func _run_render_schedule(frame_count: int, frame_delta: float) -> Dictionary:
	var world := WorldGrid.new(Vector2i(16, 16), 8, TerrainTypes.Id.LAND)
	var store := _create_store(Vector2i(16, 16), TEST_POSITIONS)
	var living := _create_living_store_for_all(store)
	var clock := SimulationClock.new()
	var movement := PrototypeEntityMovement.new()
	for frame_index in range(frame_count):
		clock.add_time(frame_delta)
		while clock.consume_tick():
			movement.step(world, store, living, clock.get_tick_index())
	return {
		"tick_index": clock.get_tick_index(),
		"positions": store.get_cell_positions_copy(),
	}


func _run_ticks(
	world: WorldGrid,
	store: EntityStore,
	living: LivingStateStore,
	first_tick: int,
	tick_count: int,
) -> void:
	var movement := PrototypeEntityMovement.new()
	for tick_offset in range(tick_count):
		movement.step(world, store, living, first_tick + tick_offset)


func _create_store(world_size: Vector2i, positions: Array[Vector2i]) -> EntityStore:
	var store := EntityStore.new(world_size)
	for position: Vector2i in positions:
		store.create_entity(position)
	return store


func _create_living_store_for_all(store: EntityStore) -> LivingStateStore:
	var living := LivingStateStore.new(store)
	for dense_index in range(store.get_dense_count()):
		living.add_living_state(store.get_entity_id_at_dense_index(dense_index), 0)
	return living


func _first_living_ids(living: LivingStateStore) -> PackedInt64Array:
	var ids := PackedInt64Array()
	for dense_index in range(living.get_dense_count()):
		ids.append(living.get_entity_id_at_dense_index(dense_index))
	return ids


func _manhattan_distance(first: Vector2i, second: Vector2i) -> int:
	return absi(first.x - second.x) + absi(first.y - second.y)


func _expect_true(value: bool, label: String) -> void:
	_assertions += 1
	if not value:
		_failures += 1
		printerr("FAIL: %s" % label)


func _expect_false(value: bool, label: String) -> void:
	_expect_true(not value, label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures += 1
		printerr("FAIL: %s | expected=%s actual=%s" % [label, expected, actual])
