extends MainLoop

var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	_test_empty_attach_and_invalid_contracts()
	_test_removal_swap_remove_and_core_ownership()
	_test_transition_preserves_core_identity_and_position()
	_test_transition_failure_is_non_mutating()
	_test_three_heterogeneous_states()
	_test_movement_stops_through_membership_removal()
	_test_data_only_compact_boundary()
	if _failures == 0:
		print("REMAINS_STATE_STORE_TESTS_PASSED assertions=%d" % _assertions)
	else:
		printerr(
			"REMAINS_STATE_STORE_TESTS_FAILED failures=%d assertions=%d"
			% [_failures, _assertions],
		)
		assert(false, "Remains state store test suite failed")


func _process(_delta: float) -> bool:
	return true


func _test_empty_attach_and_invalid_contracts() -> void:
	var entities := EntityStore.new(Vector2i(8, 8))
	var remains := RemainsStateStore.new(entities)
	_expect_equal(remains.get_remains_count(), 0, "remains store begins empty")
	_expect_equal(remains.get_dense_count(), 0, "empty dense count")
	_expect_true(remains.is_bound_to(entities), "remains store retains its core entity owner")
	_expect_false(remains.add_remains_state(99, 0), "unknown core ID attach rejected")
	_expect_false(
		remains.add_remains_state(EntityStore.INVALID_ENTITY_ID, 0),
		"invalid core ID sentinel attach rejected",
	)
	_expect_equal(remains.get_death_tick(99), RemainsStateStore.INVALID_DEATH_TICK, "missing death sentinel")
	_expect_equal(
		remains.get_entity_id_at_dense_index(-1),
		EntityStore.INVALID_ENTITY_ID,
		"negative dense read returns sentinel",
	)
	_expect_equal(
		remains.get_entity_id_at_dense_index(0),
		EntityStore.INVALID_ENTITY_ID,
		"past-edge dense read returns sentinel",
	)

	var entity_id := entities.create_entity(Vector2i(2, 3))
	_expect_false(remains.add_remains_state(entity_id, -1), "negative death tick rejected")
	_expect_true(remains.add_remains_state(entity_id, 12), "valid remains state attached")
	_expect_false(remains.add_remains_state(entity_id, 13), "duplicate remains state rejected")
	_expect_true(remains.has_remains_state(entity_id), "attached remains state is present")
	_expect_equal(remains.get_death_tick(entity_id), 12, "death tick retained")
	_expect_equal(remains.get_remains_count(), 1, "valid attach increments remains count")
	_expect_equal(remains.get_entity_id_at_dense_index(0), entity_id, "dense row exposes stable core ID")

	var stale_id := entities.create_entity(Vector2i.ONE)
	_expect_true(entities.remove_entity(stale_id), "core entity made stale for attach validation")
	_expect_false(remains.add_remains_state(stale_id, 0), "stale core entity attach rejected")


func _test_removal_swap_remove_and_core_ownership() -> void:
	var entities := EntityStore.new(Vector2i(8, 8))
	var remains := RemainsStateStore.new(entities)
	for index in range(4):
		var entity_id := entities.create_entity(Vector2i(index, index))
		remains.add_remains_state(entity_id, (index + 1) * 10)

	_expect_true(remains.remove_remains_state(2), "middle remains row removes")
	_expect_equal(remains.get_entity_id_at_dense_index(1), 4, "last remains row fills removed slot")
	_expect_equal(remains.get_death_tick(4), 40, "moved row death tick mapping repaired")
	_expect_equal(remains.get_death_tick(3), 30, "unmoved row death tick remains valid")
	_expect_false(remains.has_remains_state(2), "removed remains row is absent")
	_expect_true(entities.has_entity(2), "remains removal does not delete core entity")
	_expect_equal(entities.get_cell_position(2), Vector2i(1, 1), "remains removal preserves core position")
	_expect_false(remains.remove_remains_state(2), "duplicate removal is safe")
	_expect_true(remains.remove_remains_state(4), "moved row remains removable by stable ID")
	_expect_true(remains.remove_remains_state(3), "last row removal succeeds")
	_expect_equal(remains.get_remains_count(), 1, "removal shrinks dense packed rows")
	_expect_equal(remains.get_death_tick(1), 10, "surviving row remains addressable")


func _test_transition_preserves_core_identity_and_position() -> void:
	var entities := EntityStore.new(Vector2i(16, 16))
	var living := LivingStateStore.new(entities)
	var remains := RemainsStateStore.new(entities)
	var entity_id := entities.create_entity(Vector2i(7, 9))
	var identity_before := entity_id
	var position_before := entities.get_cell_position(entity_id)
	_expect_true(living.add_living_state(entity_id, 4), "living state attached before transition")

	_expect_true(
		PrototypeLifecycleTransition.new().transition_to_remains(
			entity_id,
			23,
			entities,
			living,
			remains,
		),
		"valid living-to-remains transition succeeds",
	)
	_expect_true(entities.has_entity(entity_id), "transition preserves core entity")
	_expect_equal(entity_id, identity_before, "same stable entity ID exists after transition")
	_expect_equal(entities.get_entity_count(), 1, "transition creates no replacement core entity")
	_expect_equal(entities.get_entity_id_at_dense_index(0), identity_before, "core dense row retains stable ID")
	_expect_equal(entities.get_cell_position(entity_id), position_before, "transition preserves core position")
	_expect_false(living.has_living_state(entity_id), "transition removes living state")
	_expect_true(remains.has_remains_state(entity_id), "transition attaches remains state")
	_expect_equal(remains.get_death_tick(entity_id), 23, "transition records simulation death tick")
	_expect_equal(living.get_birth_tick(entity_id), LivingStateStore.INVALID_BIRTH_TICK, "birth tick is no longer readable")
	_expect_equal(living.get_age_ticks(entity_id, 30), LivingStateStore.INVALID_AGE_TICKS, "age is invalid after living removal")


func _test_transition_failure_is_non_mutating() -> void:
	var transition := PrototypeLifecycleTransition.new()
	var entities := EntityStore.new(Vector2i(8, 8))
	var living := LivingStateStore.new(entities)
	var remains := RemainsStateStore.new(entities)
	var living_id := entities.create_entity(Vector2i(2, 2))
	var generic_id := entities.create_entity(Vector2i(3, 3))
	living.add_living_state(living_id, 5)

	_expect_false(
		transition.transition_to_remains(generic_id, 10, entities, living, remains),
		"generic non-living entity cannot use living-to-remains transition",
	)
	_expect_false(remains.has_remains_state(generic_id), "non-living rejection attaches no remains row")
	_expect_false(
		transition.transition_to_remains(999, 10, entities, living, remains),
		"invalid core entity transition rejected",
	)
	_expect_false(
		transition.transition_to_remains(living_id, -1, entities, living, remains),
		"negative death tick transition rejected",
	)
	_expect_true(living.has_living_state(living_id), "negative tick failure preserves living state")
	_expect_false(remains.has_remains_state(living_id), "negative tick failure attaches no remains state")

	var other_entities := EntityStore.new(Vector2i(8, 8))
	var other_living := LivingStateStore.new(other_entities)
	var other_remains := RemainsStateStore.new(other_entities)
	_expect_false(
		transition.transition_to_remains(living_id, 10, entities, other_living, remains),
		"mismatched living-store binding rejected",
	)
	_expect_false(
		transition.transition_to_remains(living_id, 10, entities, living, other_remains),
		"mismatched remains-store binding rejected",
	)
	_expect_true(living.has_living_state(living_id), "binding failures preserve living row")
	_expect_false(remains.has_remains_state(living_id), "binding failures attach no remains row")

	_expect_true(remains.add_remains_state(living_id, 9), "invalid overlap arranged to test precondition")
	_expect_false(
		transition.transition_to_remains(living_id, 10, entities, living, remains),
		"already-remains transition rejected",
	)
	_expect_true(living.has_living_state(living_id), "already-remains failure does not remove living row")
	_expect_equal(remains.get_death_tick(living_id), 9, "already-remains failure does not overwrite death tick")


func _test_three_heterogeneous_states() -> void:
	var entities := EntityStore.new(Vector2i(8, 8))
	var living := LivingStateStore.new(entities)
	var remains := RemainsStateStore.new(entities)
	var living_id := entities.create_entity(Vector2i(1, 1))
	var remains_id := entities.create_entity(Vector2i(2, 2))
	var generic_id := entities.create_entity(Vector2i(3, 3))
	_expect_true(living.add_living_state(living_id, 0), "A receives living state")
	_expect_true(remains.add_remains_state(remains_id, 7), "B receives remains state")
	_expect_equal(entities.get_entity_count(), 3, "A B C share one three-entity core store")
	_expect_equal(living.get_living_count(), 1, "only A is living")
	_expect_equal(remains.get_remains_count(), 1, "only B is remains")
	_expect_false(living.has_living_state(generic_id), "C has no living row")
	_expect_false(remains.has_remains_state(generic_id), "C has no remains row")
	_expect_true(entities.has_entity(generic_id), "C remains a valid generic-only entity")


func _test_movement_stops_through_membership_removal() -> void:
	var world := WorldGrid.new(Vector2i(16, 16), 8, TerrainTypes.Id.LAND)
	var entities := EntityStore.new(Vector2i(16, 16))
	var living := LivingStateStore.new(entities)
	var remains := RemainsStateStore.new(entities)
	var entity_id := entities.create_entity(Vector2i(8, 8))
	living.add_living_state(entity_id, 0)
	var movement := PrototypeEntityMovement.new()
	var position_before_movement := entities.get_cell_position(entity_id)
	for tick_index in range(1, 4):
		movement.step(world, entities, living, tick_index)
	_expect_true(
		entities.get_cell_position(entity_id) != position_before_movement,
		"living entity moves before transition",
	)
	_expect_true(
		PrototypeLifecycleTransition.new().transition_to_remains(
			entity_id,
			4,
			entities,
			living,
			remains,
		),
		"movement fixture transitions to remains",
	)
	var death_position := entities.get_cell_position(entity_id)
	for tick_index in range(5, 11):
		_expect_equal(
			movement.step(world, entities, living, tick_index),
			0,
			"no living member moves after transition tick %d" % tick_index,
		)
		_expect_equal(
			entities.get_cell_position(entity_id),
			death_position,
			"remains position stays fixed after movement tick %d" % tick_index,
		)


func _test_data_only_compact_boundary() -> void:
	var entities := EntityStore.new(Vector2i(2, 2))
	var remains := RemainsStateStore.new(entities)
	var transition := PrototypeLifecycleTransition.new()
	_expect_true(remains is RefCounted, "remains store is data-only RefCounted")
	_expect_true(transition is RefCounted, "transition is data-only RefCounted")
	_expect_false(remains.has_method("get_tree"), "remains store has no scene-tree API")
	_expect_false(transition.has_method("get_tree"), "transition has no scene-tree API")
	var remains_source := FileAccess.get_file_as_string("res://scripts/entities/remains_state_store.gd")
	var transition_source := FileAccess.get_file_as_string(
		"res://scripts/simulation/prototype_lifecycle_transition.gd"
	)
	var movement_source := FileAccess.get_file_as_string(
		"res://scripts/simulation/prototype_entity_movement.gd"
	)
	_expect_true(remains_source.count("PackedInt64Array") >= 4, "IDs and death ticks use packed storage")
	_expect_false(remains_source.contains("extends Node"), "remains store has no Node dependency")
	_expect_false(remains_source.contains("Vector2i"), "remains store owns no position")
	_expect_false(remains_source.contains("TerrainTypes"), "remains store knows no terrain")
	_expect_false(remains_source.contains("birth_tick"), "remains store does not duplicate birth tick")
	_expect_false(transition_source.contains("enum EntityType"), "transition adds no global entity type enum")
	_expect_false(transition_source.contains("component_mask"), "transition adds no component mask")
	_expect_false(movement_source.contains("RemainsState"), "movement contains no remains-specific branch")


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
