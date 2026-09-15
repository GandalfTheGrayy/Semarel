extends MainLoop

var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	_test_empty_set_update_and_clear()
	_test_invalid_and_stale_set_contracts()
	_test_stale_target_preserves_raw_id_without_retarget()
	_test_dense_swap_remove_and_stable_target_id()
	_test_explicit_source_cleanup()
	_test_living_and_remains_composability()
	_test_lifecycle_transition_preserves_reference()
	_test_data_only_compact_boundary()
	if _failures == 0:
		print("PROTOTYPE_OWNER_REFERENCE_STORE_TESTS_PASSED assertions=%d" % _assertions)
	else:
		printerr(
			"PROTOTYPE_OWNER_REFERENCE_STORE_TESTS_FAILED failures=%d assertions=%d"
			% [_failures, _assertions],
		)
		assert(false, "Prototype owner reference store test suite failed")


func _process(_delta: float) -> bool:
	return true


func _test_empty_set_update_and_clear() -> void:
	var entities := EntityStore.new(Vector2i(8, 8))
	var owners := PrototypeOwnerReferenceStore.new(entities)
	_expect_equal(owners.get_owner_reference_count(), 0, "owner reference store begins empty")
	_expect_equal(owners.get_dense_count(), 0, "empty dense count")
	_expect_true(owners.is_bound_to(entities), "reference store retains its core entity owner")
	_expect_false(owners.has_owner_reference(99), "unknown subject has no reference")
	_expect_equal(
		owners.get_owner_entity_id(99),
		PrototypeOwnerReferenceStore.INVALID_OWNER_ENTITY_ID,
		"missing reference returns invalid owner sentinel",
	)
	_expect_false(owners.is_owner_resolved(99), "missing reference is unresolved")
	_expect_false(owners.clear_owner(99), "missing reference clear is safe")
	_expect_equal(
		owners.get_entity_id_at_dense_index(-1),
		EntityStore.INVALID_ENTITY_ID,
		"negative dense read returns sentinel",
	)
	_expect_equal(
		owners.get_entity_id_at_dense_index(0),
		EntityStore.INVALID_ENTITY_ID,
		"past-edge dense read returns sentinel",
	)

	var subject_id := entities.create_entity(Vector2i(1, 1))
	var first_owner_id := entities.create_entity(Vector2i(2, 2))
	var second_owner_id := entities.create_entity(Vector2i(3, 3))
	_expect_true(owners.set_owner(subject_id, first_owner_id), "valid owner reference attaches")
	_expect_true(owners.has_owner_reference(subject_id), "attached reference is present")
	_expect_equal(owners.get_owner_entity_id(subject_id), first_owner_id, "stored target ID is readable")
	_expect_true(owners.is_owner_resolved(subject_id), "existing target resolves")
	_expect_equal(owners.get_owner_reference_count(), 1, "attach adds one dense row")
	_expect_false(owners.set_owner(subject_id, 999), "invalid update target is rejected")
	_expect_equal(owners.get_owner_reference_count(), 1, "invalid update does not change row count")
	_expect_equal(owners.get_owner_entity_id(subject_id), first_owner_id, "invalid update preserves old target")
	_expect_true(owners.set_owner(subject_id, second_owner_id), "existing owner reference updates")
	_expect_equal(owners.get_owner_reference_count(), 1, "update does not duplicate subject row")
	_expect_equal(owners.get_owner_entity_id(subject_id), second_owner_id, "update stores new target ID")
	_expect_true(owners.is_owner_resolved(subject_id), "updated target resolves")
	_expect_true(owners.set_owner(subject_id, subject_id), "storage permits stable self-reference")
	_expect_equal(owners.get_owner_entity_id(subject_id), subject_id, "self-reference retains subject stable ID")
	_expect_true(owners.clear_owner(subject_id), "owner reference clears")
	_expect_false(owners.has_owner_reference(subject_id), "cleared reference is absent")
	_expect_equal(owners.get_owner_reference_count(), 0, "clear removes only relation row")
	_expect_true(entities.has_entity(subject_id), "clear preserves subject core entity")
	_expect_true(entities.has_entity(first_owner_id), "clear preserves first target core entity")
	_expect_true(entities.has_entity(second_owner_id), "clear preserves second target core entity")


func _test_invalid_and_stale_set_contracts() -> void:
	var entities := EntityStore.new(Vector2i(8, 8))
	var owners := PrototypeOwnerReferenceStore.new(entities)
	var subject_id := entities.create_entity(Vector2i.ONE)
	var target_id := entities.create_entity(Vector2i(2, 2))
	_expect_false(owners.set_owner(99, target_id), "invalid subject rejected")
	_expect_false(owners.set_owner(subject_id, 99), "invalid target rejected")
	_expect_false(
		owners.set_owner(EntityStore.INVALID_ENTITY_ID, target_id),
		"invalid subject sentinel rejected",
	)
	_expect_false(
		owners.set_owner(subject_id, EntityStore.INVALID_ENTITY_ID),
		"invalid target sentinel rejected",
	)
	_expect_equal(owners.get_owner_reference_count(), 0, "invalid sets add no row")

	_expect_true(entities.remove_entity(target_id), "target becomes stale")
	_expect_false(owners.set_owner(subject_id, target_id), "new reference to stale target rejected")
	_expect_equal(owners.get_owner_reference_count(), 0, "stale target rejection remains non-mutating")

	var other_entities := EntityStore.new(Vector2i(8, 8))
	_expect_false(owners.is_bound_to(other_entities), "reference store rejects a different core-store binding")
	var foreign_id := EntityStore.INVALID_ENTITY_ID
	for index in range(4):
		foreign_id = other_entities.create_entity(Vector2i(index, 0))
	_expect_false(entities.has_entity(foreign_id), "foreign test ID is absent from bound core store")
	_expect_false(owners.set_owner(subject_id, foreign_id), "foreign-store-only target ID rejected")
	_expect_equal(owners.get_owner_reference_count(), 0, "foreign target rejection adds no row")


func _test_stale_target_preserves_raw_id_without_retarget() -> void:
	var entities := EntityStore.new(Vector2i(8, 8))
	var living := LivingStateStore.new(entities)
	var owners := PrototypeOwnerReferenceStore.new(entities)
	var subject_id := entities.create_entity(Vector2i(1, 1))
	var old_owner_id := entities.create_entity(Vector2i(2, 2))
	living.add_living_state(subject_id, 0)
	_expect_true(owners.set_owner(subject_id, old_owner_id), "A references B")
	_expect_true(owners.is_owner_resolved(subject_id), "B initially resolves")
	_expect_true(entities.remove_entity(old_owner_id), "B core entity is removed")
	_expect_true(entities.has_entity(subject_id), "target deletion does not cascade to subject")
	_expect_true(living.has_living_state(subject_id), "target deletion does not change subject Living state")
	_expect_true(owners.has_owner_reference(subject_id), "target deletion preserves reference row")
	_expect_equal(owners.get_owner_entity_id(subject_id), old_owner_id, "raw deleted target ID is preserved")
	_expect_false(owners.is_owner_resolved(subject_id), "deleted target makes reference unresolved")

	var new_entity_id := entities.create_entity(Vector2i(3, 3))
	_expect_true(new_entity_id > old_owner_id, "new entity receives a later monotonic ID")
	_expect_true(new_entity_id != old_owner_id, "deleted target ID is not reused")
	_expect_equal(owners.get_owner_entity_id(subject_id), old_owner_id, "new entity cannot replace stored target ID")
	_expect_false(owners.is_owner_resolved(subject_id), "new entity cannot hijack stale resolution")
	_expect_true(owners.set_owner(subject_id, new_entity_id), "stale reference can update to valid target")
	_expect_equal(owners.get_owner_reference_count(), 1, "stale-target update reuses same row")
	_expect_equal(owners.get_owner_entity_id(subject_id), new_entity_id, "update replaces raw target explicitly")
	_expect_true(owners.is_owner_resolved(subject_id), "explicitly updated target resolves")


func _test_dense_swap_remove_and_stable_target_id() -> void:
	var entities := EntityStore.new(Vector2i(16, 16))
	var owners := PrototypeOwnerReferenceStore.new(entities)
	var ids: Array[int] = []
	for index in range(6):
		ids.append(entities.create_entity(Vector2i(index, index)))
	owners.set_owner(ids[0], ids[3])
	owners.set_owner(ids[1], ids[4])
	owners.set_owner(ids[2], ids[5])
	_expect_equal(owners.get_owner_reference_count(), 3, "three reference rows attached")
	_expect_true(owners.clear_owner(ids[1]), "middle dense row clears")
	_expect_equal(owners.get_entity_id_at_dense_index(1), ids[2], "last subject row fills removed slot")
	_expect_equal(owners.get_owner_entity_id(ids[2]), ids[5], "moved row target mapping remains valid")
	_expect_equal(owners.get_owner_entity_id(ids[0]), ids[3], "unmoved row target mapping remains valid")
	_expect_true(owners.is_owner_resolved(ids[2]), "moved row still resolves")
	_expect_true(owners.clear_owner(ids[2]), "moved row remains clearable by stable subject ID")
	_expect_equal(owners.get_owner_reference_count(), 1, "swap-removes shrink dense layout")

	var target_dense_index := 3
	_expect_true(ids[3] != target_dense_index, "stable target ID differs from its initial dense index")
	_expect_equal(owners.get_owner_entity_id(ids[0]), ids[3], "reference stores target stable ID, not dense index")


func _test_explicit_source_cleanup() -> void:
	var entities := EntityStore.new(Vector2i(8, 8))
	var owners := PrototypeOwnerReferenceStore.new(entities)
	var subject_id := entities.create_entity(Vector2i.ONE)
	var target_id := entities.create_entity(Vector2i(2, 2))
	owners.set_owner(subject_id, target_id)
	_expect_true(owners.clear_owner(subject_id), "orchestrator clears source optional reference first")
	_expect_true(entities.remove_entity(subject_id), "orchestrator removes source core second")
	_expect_false(entities.has_entity(subject_id), "source core is gone after explicit cleanup")
	_expect_false(owners.has_owner_reference(subject_id), "source leaves no optional reference row")
	_expect_true(entities.has_entity(target_id), "source cleanup does not delete target")


func _test_living_and_remains_composability() -> void:
	var entities := EntityStore.new(Vector2i(8, 8))
	var living := LivingStateStore.new(entities)
	var remains := RemainsStateStore.new(entities)
	var owners := PrototypeOwnerReferenceStore.new(entities)
	var subject_id := entities.create_entity(Vector2i.ONE)
	var first_target_id := entities.create_entity(Vector2i(2, 2))
	var second_target_id := entities.create_entity(Vector2i(3, 3))
	living.add_living_state(subject_id, 4)
	remains.add_remains_state(second_target_id, 7)
	_expect_true(owners.set_owner(subject_id, first_target_id), "living subject gains owner reference")
	_expect_true(living.has_living_state(subject_id), "owner attach preserves Living state")
	_expect_true(remains.has_remains_state(second_target_id), "owner attach preserves unrelated Remains state")
	_expect_true(owners.set_owner(subject_id, second_target_id), "owner can update to core carrying Remains state")
	_expect_true(living.has_living_state(subject_id), "owner update preserves Living state")
	_expect_true(remains.has_remains_state(second_target_id), "owner update preserves target Remains state")
	_expect_true(owners.clear_owner(subject_id), "owner reference clears independently")
	_expect_true(living.has_living_state(subject_id), "owner clear preserves Living state")
	_expect_true(remains.has_remains_state(second_target_id), "owner clear preserves Remains state")
	_expect_true(entities.has_entity(subject_id), "owner mutation preserves subject core")
	_expect_true(entities.has_entity(first_target_id), "owner mutation preserves old target core")
	_expect_true(entities.has_entity(second_target_id), "owner mutation preserves new target core")


func _test_lifecycle_transition_preserves_reference() -> void:
	var entities := EntityStore.new(Vector2i(8, 8))
	var living := LivingStateStore.new(entities)
	var remains := RemainsStateStore.new(entities)
	var owners := PrototypeOwnerReferenceStore.new(entities)
	var subject_id := entities.create_entity(Vector2i(1, 1))
	var target_id := entities.create_entity(Vector2i(2, 2))
	living.add_living_state(subject_id, 2)
	owners.set_owner(subject_id, target_id)
	_expect_true(
		PrototypeLifecycleTransition.new().transition_to_remains(
			subject_id,
			11,
			entities,
			living,
			remains,
		),
		"living subject transitions to remains",
	)
	_expect_false(living.has_living_state(subject_id), "transition removes only Living state")
	_expect_true(remains.has_remains_state(subject_id), "transition attaches Remains state")
	_expect_true(owners.has_owner_reference(subject_id), "independent owner reference survives transition")
	_expect_equal(owners.get_owner_entity_id(subject_id), target_id, "transition preserves raw target ID")
	_expect_true(owners.is_owner_resolved(subject_id), "transition preserves target resolution")
	_expect_true(entities.has_entity(subject_id), "transition preserves subject core")
	_expect_true(entities.has_entity(target_id), "transition preserves target core")


func _test_data_only_compact_boundary() -> void:
	var entities := EntityStore.new(Vector2i(2, 2))
	var owners := PrototypeOwnerReferenceStore.new(entities)
	_expect_true(owners is RefCounted, "reference store is data-only RefCounted")
	_expect_false(owners.has_method("get_tree"), "reference store has no scene-tree API")
	var source := FileAccess.get_file_as_string(
		"res://scripts/entities/prototype_owner_reference_store.gd"
	)
	_expect_true(source.count("PackedInt64Array") >= 4, "subject and target IDs use packed int64 storage")
	_expect_true(source.contains("_owner_entity_ids"), "target stable IDs have an explicit packed column")
	_expect_false(source.contains("extends Node"), "reference store has no Node dependency")
	_expect_false(source.contains("NodePath"), "reference targets are not NodePath values")
	_expect_false(source.contains("WeakRef"), "reference targets are not object weak references")
	_expect_false(source.contains("get_cell_position"), "target storage does not use position or dense index")
	_expect_false(source.contains("reverse"), "reference store adds no reverse index")
	_expect_false(source.contains("RelationshipType"), "reference store adds no relation type registry")
	_expect_false(source.contains("GraphSystem"), "reference store adds no graph framework")


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
