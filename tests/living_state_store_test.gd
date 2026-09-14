extends MainLoop

var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	_test_empty_attach_and_invalid_contracts()
	_test_heterogeneous_entity_membership()
	_test_derived_age_without_mutation()
	_test_removal_ownership_and_explicit_coordination()
	_test_swap_remove_first_middle_and_last()
	_test_data_only_compact_boundary()
	if _failures == 0:
		print("LIVING_STATE_STORE_TESTS_PASSED assertions=%d" % _assertions)
	else:
		printerr(
			"LIVING_STATE_STORE_TESTS_FAILED failures=%d assertions=%d"
			% [_failures, _assertions],
		)
		assert(false, "Living state store test suite failed")


func _process(_delta: float) -> bool:
	return true


func _test_empty_attach_and_invalid_contracts() -> void:
	var entities := EntityStore.new(Vector2i(8, 8))
	var living := LivingStateStore.new(entities)
	_expect_equal(living.get_living_count(), 0, "living store begins empty")
	_expect_equal(living.get_dense_count(), 0, "empty dense count")
	_expect_true(living.is_bound_to(entities), "living store retains its core entity owner")
	_expect_false(living.add_living_state(99, 0), "unknown entity ID attach rejected")
	_expect_false(
		living.add_living_state(EntityStore.INVALID_ENTITY_ID, 0),
		"invalid entity sentinel attach rejected",
	)

	var entity_id := entities.create_entity(Vector2i(2, 3))
	_expect_false(living.add_living_state(entity_id, -1), "negative birth tick rejected")
	_expect_true(living.add_living_state(entity_id, 12), "valid living state attached")
	_expect_false(living.add_living_state(entity_id, 13), "duplicate living state rejected")
	_expect_true(living.has_living_state(entity_id), "attached state is present")
	_expect_equal(living.get_birth_tick(entity_id), 12, "birth tick retained")
	_expect_equal(living.get_living_count(), 1, "valid attach increments living count")
	_expect_equal(living.get_entity_id_at_dense_index(0), entity_id, "dense row exposes stable core ID")
	_expect_equal(
		living.get_entity_id_at_dense_index(-1),
		EntityStore.INVALID_ENTITY_ID,
		"negative dense read returns sentinel",
	)
	_expect_equal(
		living.get_entity_id_at_dense_index(1),
		EntityStore.INVALID_ENTITY_ID,
		"past-edge dense read returns sentinel",
	)
	_expect_equal(living.get_birth_tick(99), LivingStateStore.INVALID_BIRTH_TICK, "missing birth sentinel")
	_expect_equal(living.get_age_ticks(99, 20), LivingStateStore.INVALID_AGE_TICKS, "missing age sentinel")

	var stale_id := entities.create_entity(Vector2i.ONE)
	_expect_true(entities.remove_entity(stale_id), "core entity made stale for attach validation")
	_expect_false(living.add_living_state(stale_id, 0), "stale core entity attach rejected")


func _test_heterogeneous_entity_membership() -> void:
	var entities := EntityStore.new(Vector2i(8, 8))
	var living := LivingStateStore.new(entities)
	var first := entities.create_entity(Vector2i(1, 1))
	var second := entities.create_entity(Vector2i(2, 2))
	var third := entities.create_entity(Vector2i(3, 3))
	_expect_true(living.add_living_state(first, 4), "first generic entity gains optional living state")
	_expect_true(living.add_living_state(third, 9), "third generic entity gains optional living state")
	_expect_equal(entities.get_entity_count(), 3, "all heterogeneous entities remain generic entities")
	_expect_equal(living.get_living_count(), 2, "only two entities allocate living rows")
	_expect_true(entities.has_entity(first), "first generic entity exists")
	_expect_true(entities.has_entity(second), "non-living generic entity exists")
	_expect_true(entities.has_entity(third), "third generic entity exists")
	_expect_true(living.has_living_state(first), "first entity is living")
	_expect_false(living.has_living_state(second), "second entity carries no living state")
	_expect_true(living.has_living_state(third), "third entity is living")
	_expect_equal(entities.get_cell_position(second), Vector2i(2, 2), "non-living entity retains generic position")
	_expect_equal(
		living.get_birth_tick(second),
		LivingStateStore.INVALID_BIRTH_TICK,
		"non-living entity has no birth tick row",
	)


func _test_derived_age_without_mutation() -> void:
	var entities := EntityStore.new(Vector2i(4, 4))
	var living := LivingStateStore.new(entities)
	var entity_id := entities.create_entity(Vector2i.ONE)
	living.add_living_state(entity_id, 10)
	_expect_equal(living.get_age_ticks(entity_id, 9), LivingStateStore.INVALID_AGE_TICKS, "age before birth is invalid")
	_expect_equal(living.get_age_ticks(entity_id, 10), 0, "age is zero at birth tick")
	_expect_equal(living.get_age_ticks(entity_id, 20), 10, "age derives at tick twenty")
	_expect_equal(living.get_age_ticks(entity_id, 50), 40, "age derives at tick fifty")
	_expect_equal(living.get_birth_tick(entity_id), 10, "age queries never mutate birth tick")


func _test_removal_ownership_and_explicit_coordination() -> void:
	var entities := EntityStore.new(Vector2i(4, 4))
	var living := LivingStateStore.new(entities)
	var entity_id := entities.create_entity(Vector2i(2, 2))
	living.add_living_state(entity_id, 0)
	_expect_true(living.remove_living_state(entity_id), "living state removal succeeds")
	_expect_false(living.has_living_state(entity_id), "removed optional state is absent")
	_expect_true(entities.has_entity(entity_id), "living removal does not delete core entity")
	_expect_equal(entities.get_cell_position(entity_id), Vector2i(2, 2), "living removal preserves core position")
	_expect_false(living.remove_living_state(entity_id), "stale optional-state removal is safe")
	_expect_true(entities.remove_entity(entity_id), "orchestrator can remove core entity after optional cleanup")
	_expect_equal(entities.get_entity_count(), 0, "explicit cleanup leaves no core entity")
	_expect_equal(living.get_living_count(), 0, "explicit cleanup leaves no living row")


func _test_swap_remove_first_middle_and_last() -> void:
	var first_entities := EntityStore.new(Vector2i(8, 8))
	var first_living := LivingStateStore.new(first_entities)
	for index in range(3):
		var entity_id := first_entities.create_entity(Vector2i(index, index))
		first_living.add_living_state(entity_id, (index + 1) * 10)
	_expect_true(first_living.remove_living_state(1), "swap-remove first living row")
	_expect_equal(first_living.get_entity_id_at_dense_index(0), 3, "last living row fills removed first row")
	_expect_equal(first_living.get_entity_id_at_dense_index(1), 2, "unmoved living row remains addressable")
	_expect_equal(first_living.get_birth_tick(3), 30, "moved first-row birth mapping stays valid")
	_expect_equal(first_living.get_birth_tick(2), 20, "unmoved first-store birth mapping stays valid")
	_expect_true(first_entities.has_entity(1), "optional first-row removal preserves stable core ID")

	var middle_entities := EntityStore.new(Vector2i(8, 8))
	var middle_living := LivingStateStore.new(middle_entities)
	for index in range(4):
		var entity_id := middle_entities.create_entity(Vector2i(index, 0))
		middle_living.add_living_state(entity_id, index + 5)
	_expect_true(middle_living.remove_living_state(2), "swap-remove middle living row")
	_expect_equal(middle_living.get_entity_id_at_dense_index(1), 4, "last living row fills removed middle row")
	_expect_equal(middle_living.get_birth_tick(4), 8, "moved middle-row birth mapping stays valid")
	_expect_equal(middle_living.get_birth_tick(3), 7, "other middle birth mapping stays valid")
	_expect_true(middle_entities.has_entity(2), "optional middle-row removal preserves core entity")

	var last_entities := EntityStore.new(Vector2i(8, 8))
	var last_living := LivingStateStore.new(last_entities)
	for index in range(3):
		var entity_id := last_entities.create_entity(Vector2i(index, 1))
		last_living.add_living_state(entity_id, index)
	_expect_true(last_living.remove_living_state(3), "remove last living row")
	_expect_equal(last_living.get_dense_count(), 2, "last removal shrinks dense storage")
	_expect_equal(last_living.get_entity_id_at_dense_index(1), 2, "last removal preserves previous row")
	_expect_equal(last_living.get_birth_tick(2), 1, "last removal preserves previous birth tick")
	_expect_true(last_entities.has_entity(3), "optional last-row removal preserves core entity")


func _test_data_only_compact_boundary() -> void:
	var entities := EntityStore.new(Vector2i(2, 2))
	var living := LivingStateStore.new(entities)
	_expect_true(living is RefCounted, "living store is data-only RefCounted")
	_expect_false(living.has_method("get_tree"), "living store has no scene-tree API")
	var source := FileAccess.get_file_as_string("res://scripts/entities/living_state_store.gd")
	_expect_true(source.contains("PackedInt64Array"), "living IDs and birth ticks use packed storage")
	_expect_false(source.contains("extends Node"), "living store has no Node dependency")
	_expect_false(source.contains("Vector2i"), "living store owns no position")
	_expect_false(source.contains("TerrainTypes"), "living store knows no terrain")
	_expect_false(source.contains("age +="), "living age is never incremented per tick")
	_expect_false(source.contains("var _age_ticks"), "living store persists no derived age column")


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
