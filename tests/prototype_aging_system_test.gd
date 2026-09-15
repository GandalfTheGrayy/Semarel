extends MainLoop

const TEST_ENTITY_COUNT: int = 12

var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	_test_deterministic_lifespan_rule()
	_test_age_threshold_and_core_preservation()
	_test_death_then_no_movement()
	_test_swap_remove_does_not_skip_eligible_rows()
	_test_multiple_deaths_are_deterministic()
	_test_render_schedule_independence()
	_test_world_revision_and_owner_reference_independence()
	_test_data_only_hot_loop_contract()
	if _failures == 0:
		print("PROTOTYPE_AGING_SYSTEM_TESTS_PASSED assertions=%d" % _assertions)
	else:
		printerr(
			"PROTOTYPE_AGING_SYSTEM_TESTS_FAILED failures=%d assertions=%d"
			% [_failures, _assertions],
		)
		assert(false, "Prototype aging system test suite failed")


func _process(_delta: float) -> bool:
	return true


func _test_deterministic_lifespan_rule() -> void:
	var first_results := PackedInt32Array()
	var distinct_results: Dictionary = {}
	for entity_id in range(1, 65):
		var lifespan := PrototypeAgingSystem.get_prototype_lifespan_ticks(entity_id)
		first_results.append(lifespan)
		distinct_results[lifespan] = true
		_expect_true(
			lifespan >= PrototypeAgingSystem.BASE_LIFESPAN_TICKS,
			"lifespan lower bound for entity %d" % entity_id,
		)
		_expect_true(
			lifespan
			<= PrototypeAgingSystem.BASE_LIFESPAN_TICKS
			+ PrototypeAgingSystem.LIFESPAN_VARIATION_TICKS
			- 1,
			"lifespan upper bound for entity %d" % entity_id,
		)

	seed(81)
	for index in range(73):
		randi()
	var second_results := PackedInt32Array()
	for entity_id in range(1, 65):
		second_results.append(PrototypeAgingSystem.get_prototype_lifespan_ticks(entity_id))
	_expect_equal(first_results, second_results, "global RNG activity cannot change stable-ID lifespans")
	_expect_true(distinct_results.size() > 8, "representative stable IDs produce lifespan variation")
	_expect_equal(
		PrototypeAgingSystem.get_prototype_lifespan_ticks(EntityStore.INVALID_ENTITY_ID),
		PrototypeAgingSystem.INVALID_LIFESPAN_TICKS,
		"invalid stable ID has no prototype lifespan",
	)


func _test_age_threshold_and_core_preservation() -> void:
	var entities := EntityStore.new(Vector2i(8, 8))
	var entity_id := entities.create_entity(Vector2i(3, 4))
	var living := LivingStateStore.new(entities)
	var remains := RemainsStateStore.new(entities)
	living.add_living_state(entity_id, 10)
	var aging := PrototypeAgingSystem.new()
	var transition := PrototypeLifecycleTransition.new()
	var lifespan := PrototypeAgingSystem.get_prototype_lifespan_ticks(entity_id)
	var threshold_tick := 10 + lifespan

	_expect_equal(
		aging.step(threshold_tick - 1, entities, living, remains, transition),
		0,
		"entity remains living one tick before threshold",
	)
	_expect_true(living.has_living_state(entity_id), "living row exists before threshold")
	_expect_false(remains.has_remains_state(entity_id), "remains row absent before threshold")
	var position_before := entities.get_cell_position(entity_id)
	_expect_equal(
		aging.step(threshold_tick, entities, living, remains, transition),
		1,
		"entity transitions exactly at age threshold",
	)
	_expect_true(entities.has_entity(entity_id), "natural death preserves stable core ID")
	_expect_equal(entities.get_entity_count(), 1, "natural death preserves core count")
	_expect_equal(entities.get_cell_position(entity_id), position_before, "natural death preserves position")
	_expect_false(living.has_living_state(entity_id), "natural death removes Living row")
	_expect_true(remains.has_remains_state(entity_id), "natural death adds Remains row")
	_expect_equal(remains.get_death_tick(entity_id), threshold_tick, "death tick is current simulation tick")


func _test_death_then_no_movement() -> void:
	var world := WorldGrid.new(Vector2i(8, 8), 4, TerrainTypes.Id.LAND)
	var entities := EntityStore.new(Vector2i(8, 8))
	var entity_id := entities.create_entity(Vector2i(4, 4))
	var living := LivingStateStore.new(entities)
	var remains := RemainsStateStore.new(entities)
	living.add_living_state(entity_id, 0)
	var death_tick := PrototypeAgingSystem.get_prototype_lifespan_ticks(entity_id)
	var position_before := entities.get_cell_position(entity_id)
	_expect_equal(
		PrototypeAgingSystem.new().step(
			death_tick,
			entities,
			living,
			remains,
			PrototypeLifecycleTransition.new(),
		),
		1,
		"aging transitions entity before movement in the death tick",
	)
	_expect_equal(
		PrototypeEntityMovement.new().step(world, entities, living, death_tick),
		0,
		"movement sees no row after same-tick natural death",
	)
	_expect_equal(entities.get_cell_position(entity_id), position_before, "dead entity does not move on death tick")


func _test_swap_remove_does_not_skip_eligible_rows() -> void:
	var entities := EntityStore.new(Vector2i(16, 16))
	var living := LivingStateStore.new(entities)
	var remains := RemainsStateStore.new(entities)
	for index in range(10):
		var entity_id := entities.create_entity(Vector2i(index, index))
		var birth_tick := 0 if index < 6 else 200
		living.add_living_state(entity_id, birth_tick)

	var newly_dead := PrototypeAgingSystem.new().step(
		200,
		entities,
		living,
		remains,
		PrototypeLifecycleTransition.new(),
	)
	_expect_equal(newly_dead, 6, "all six eligible rows transition in one pass")
	_expect_equal(living.get_living_count(), 4, "four ineligible rows remain living")
	_expect_equal(remains.get_remains_count(), 6, "six eligible rows become remains")
	for entity_id in range(1, 7):
		_expect_false(living.has_living_state(entity_id), "eligible ID %d was not skipped" % entity_id)
		_expect_equal(remains.get_death_tick(entity_id), 200, "eligible ID %d records shared death tick" % entity_id)
	for entity_id in range(7, 11):
		_expect_true(living.has_living_state(entity_id), "ineligible ID %d remains living" % entity_id)
		_expect_false(remains.has_remains_state(entity_id), "ineligible ID %d has no remains row" % entity_id)


func _test_multiple_deaths_are_deterministic() -> void:
	var first := _run_tick_sequence(210)
	seed(771)
	for index in range(41):
		randf()
	var second := _run_tick_sequence(210)
	_expect_equal(first.living_ids, second.living_ids, "same ticks retain identical living membership")
	_expect_equal(first.remains_ids, second.remains_ids, "same ticks retain identical remains membership")
	_expect_equal(first.death_ticks, second.death_ticks, "same entities record identical death ticks")
	_expect_equal(first.positions, second.positions, "same lifecycle and movement sequence retains positions")
	_expect_equal(first.living_ids.size(), 0, "all representative entities die by tick 210")
	_expect_equal(first.remains_ids.size(), TEST_ENTITY_COUNT, "all representative entities become remains")


func _test_render_schedule_independence() -> void:
	var sixty_frames := _run_render_schedule(900, 1.0 / 60.0)
	var thirty_frames := _run_render_schedule(450, 1.0 / 30.0)
	var ten_frames := _run_render_schedule(150, 0.1)
	_expect_equal(sixty_frames.tick_index, 150, "sixty-frame schedule reaches tick 150")
	_expect_equal(thirty_frames.tick_index, 150, "thirty-frame schedule reaches tick 150")
	_expect_equal(ten_frames.tick_index, 150, "ten-frame schedule reaches tick 150")
	_expect_equal(sixty_frames.living_ids, thirty_frames.living_ids, "60 Hz and 30 Hz living membership match")
	_expect_equal(sixty_frames.living_ids, ten_frames.living_ids, "60 Hz and 10 Hz living membership match")
	_expect_equal(sixty_frames.remains_ids, thirty_frames.remains_ids, "60 Hz and 30 Hz remains membership match")
	_expect_equal(sixty_frames.remains_ids, ten_frames.remains_ids, "60 Hz and 10 Hz remains membership match")
	_expect_equal(sixty_frames.positions, thirty_frames.positions, "60 Hz and 30 Hz positions match")
	_expect_equal(sixty_frames.positions, ten_frames.positions, "60 Hz and 10 Hz positions match")
	_expect_true(sixty_frames.living_ids.size() > 0, "tick 150 retains some living entities")
	_expect_true(sixty_frames.remains_ids.size() > 0, "tick 150 has some natural deaths")


func _test_world_revision_and_owner_reference_independence() -> void:
	var world := WorldGrid.new(Vector2i(8, 8), 4, TerrainTypes.Id.WATER)
	world.set_terrain(Vector2i.ZERO, TerrainTypes.Id.LAND)
	world.commit_changes()
	var revision_before := world.get_revision()
	var entities := EntityStore.new(Vector2i(8, 8))
	var subject_id := entities.create_entity(Vector2i.ONE)
	var owner_id := entities.create_entity(Vector2i(2, 2))
	var living := LivingStateStore.new(entities)
	var remains := RemainsStateStore.new(entities)
	var owners := PrototypeOwnerReferenceStore.new(entities)
	living.add_living_state(subject_id, 0)
	owners.set_owner(subject_id, owner_id)
	var death_tick := PrototypeAgingSystem.get_prototype_lifespan_ticks(subject_id)
	_expect_equal(
		PrototypeAgingSystem.new().step(
			death_tick,
			entities,
			living,
			remains,
			PrototypeLifecycleTransition.new(),
		),
		1,
		"owner-reference subject dies naturally",
	)
	_expect_equal(world.get_revision(), revision_before, "aging and death do not advance world revision")
	_expect_true(owners.has_owner_reference(subject_id), "owner row survives natural death")
	_expect_equal(owners.get_owner_entity_id(subject_id), owner_id, "raw owner target survives natural death")
	_expect_true(owners.is_owner_resolved(subject_id), "owner resolution survives while target exists")


func _test_data_only_hot_loop_contract() -> void:
	var aging := PrototypeAgingSystem.new()
	_expect_true(aging is RefCounted, "aging system is data-only RefCounted")
	_expect_false(aging.has_method("get_tree"), "aging system has no scene-tree API")
	var source := FileAccess.get_file_as_string("res://scripts/simulation/prototype_aging_system.gd")
	_expect_true(source.contains("get_dense_count"), "aging uses dense living iteration")
	_expect_true(source.contains("get_entity_id_at_dense_index"), "aging reads stable IDs from dense rows")
	_expect_true(source.contains("PrototypeLifecycleTransition"), "aging reuses the existing transition")
	_expect_false(source.contains("get_entity_ids_copy"), "aging takes no full living-ID snapshot")
	_expect_false(source.contains("RandomNumberGenerator"), "aging allocates no per-entity RNG")
	_expect_false(source.contains("randi("), "aging ignores global integer RNG")
	_expect_false(source.contains("randf("), "aging ignores global float RNG")
	_expect_false(source.contains("SystemRegistry"), "aging adds no system registry")
	_expect_false(source.contains("Scheduler"), "aging adds no scheduler abstraction")
	_expect_false(source.contains("Renderer"), "aging has no presentation dependency")


func _run_tick_sequence(final_tick: int) -> Dictionary:
	var world := WorldGrid.new(Vector2i(32, 32), 8, TerrainTypes.Id.LAND)
	var entities := EntityStore.new(Vector2i(32, 32))
	var living := LivingStateStore.new(entities)
	var remains := RemainsStateStore.new(entities)
	for index in range(TEST_ENTITY_COUNT):
		var entity_id := entities.create_entity(Vector2i(index + 2, index + 3))
		living.add_living_state(entity_id, 0)
	var aging := PrototypeAgingSystem.new()
	var transition := PrototypeLifecycleTransition.new()
	var movement := PrototypeEntityMovement.new()
	for tick_index in range(1, final_tick + 1):
		aging.step(tick_index, entities, living, remains, transition)
		movement.step(world, entities, living, tick_index)
	return _capture_state(entities, living, remains)


func _run_render_schedule(frame_count: int, frame_delta: float) -> Dictionary:
	var world := WorldGrid.new(Vector2i(32, 32), 8, TerrainTypes.Id.LAND)
	var entities := EntityStore.new(Vector2i(32, 32))
	var living := LivingStateStore.new(entities)
	var remains := RemainsStateStore.new(entities)
	for index in range(TEST_ENTITY_COUNT):
		var entity_id := entities.create_entity(Vector2i(index + 2, index + 3))
		living.add_living_state(entity_id, 0)
	var clock := SimulationClock.new()
	var aging := PrototypeAgingSystem.new()
	var transition := PrototypeLifecycleTransition.new()
	var movement := PrototypeEntityMovement.new()
	for frame_index in range(frame_count):
		clock.add_time(frame_delta)
		while clock.consume_tick():
			var tick_index := clock.get_tick_index()
			aging.step(tick_index, entities, living, remains, transition)
			movement.step(world, entities, living, tick_index)
	var state := _capture_state(entities, living, remains)
	state["tick_index"] = clock.get_tick_index()
	return state


func _capture_state(
	entities: EntityStore,
	living: LivingStateStore,
	remains: RemainsStateStore,
) -> Dictionary:
	var living_ids := PackedInt64Array()
	for dense_index in range(living.get_dense_count()):
		living_ids.append(living.get_entity_id_at_dense_index(dense_index))
	var remains_ids := PackedInt64Array()
	var death_ticks := PackedInt64Array()
	for dense_index in range(remains.get_dense_count()):
		var entity_id := remains.get_entity_id_at_dense_index(dense_index)
		remains_ids.append(entity_id)
		death_ticks.append(remains.get_death_tick(entity_id))
	return {
		"living_ids": living_ids,
		"remains_ids": remains_ids,
		"death_ticks": death_ticks,
		"positions": entities.get_cell_positions_copy(),
	}


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
