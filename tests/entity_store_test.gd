extends MainLoop

var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	_test_creation_identity_and_bounds()
	_test_position_update_and_stale_ids()
	_test_swap_remove_first_middle_and_last()
	_test_snapshot_immutability_and_layout()
	_test_ephemeral_dense_iteration_api()
	if _failures == 0:
		print("ENTITY_STORE_TESTS_PASSED assertions=%d" % _assertions)
	else:
		printerr("ENTITY_STORE_TESTS_FAILED failures=%d assertions=%d" % [_failures, _assertions])
		assert(false, "Entity store test suite failed")


func _process(_delta: float) -> bool:
	return true


func _test_creation_identity_and_bounds() -> void:
	var store := EntityStore.new(Vector2i(8, 6))
	_expect_equal(store.get_entity_count(), 0, "store begins empty")
	_expect_equal(store.get_world_size(), Vector2i(8, 6), "store retains logical bounds")
	_expect_equal(store.create_entity(Vector2i(-1, 0)), EntityStore.INVALID_ENTITY_ID, "negative creation rejected")
	_expect_equal(store.create_entity(Vector2i(8, 0)), EntityStore.INVALID_ENTITY_ID, "past-edge creation rejected")
	var first := store.create_entity(Vector2i.ZERO)
	var second := store.create_entity(Vector2i(7, 5))
	_expect_equal(first, 1, "stable IDs begin at one")
	_expect_equal(second, 2, "stable IDs increase monotonically")
	_expect_true(store.has_entity(first), "first entity exists")
	_expect_true(store.has_entity(second), "second entity exists")
	_expect_false(store.has_entity(EntityStore.INVALID_ENTITY_ID), "invalid sentinel never exists")
	_expect_equal(store.get_entity_count(), 2, "valid creations increase count")
	_expect_equal(store.get_cell_position(first), Vector2i.ZERO, "origin position retained")
	_expect_equal(store.get_cell_position(second), Vector2i(7, 5), "world max minus one retained")
	_expect_true(store.remove_entity(first), "first ID can be removed")
	var third := store.create_entity(Vector2i.ONE)
	_expect_equal(third, 3, "removed stable ID is never reused")
	_expect_false(store.has_entity(first), "removed ID stays stale")


func _test_position_update_and_stale_ids() -> void:
	var store := EntityStore.new(Vector2i(4, 4))
	var entity_id := store.create_entity(Vector2i(1, 1))
	_expect_true(store.set_cell_position(entity_id, Vector2i(3, 3)), "valid position update accepted")
	_expect_equal(store.get_cell_position(entity_id), Vector2i(3, 3), "position update stored")
	_expect_false(store.set_cell_position(entity_id, Vector2i(-1, 0)), "negative update rejected")
	_expect_false(store.set_cell_position(entity_id, Vector2i(4, 0)), "outside update rejected")
	_expect_equal(store.get_cell_position(entity_id), Vector2i(3, 3), "invalid update preserves prior position")
	_expect_true(store.remove_entity(entity_id), "entity removal succeeds")
	_expect_false(store.remove_entity(entity_id), "stale removal is safe")
	_expect_false(store.set_cell_position(entity_id, Vector2i.ZERO), "stale update is safe")
	_expect_equal(store.get_cell_position(entity_id), EntityStore.INVALID_CELL_POSITION, "stale read returns explicit sentinel")


func _test_swap_remove_first_middle_and_last() -> void:
	var first_store := EntityStore.new(Vector2i(8, 8))
	var first_ids: Array[int] = []
	for index in range(3):
		first_ids.append(first_store.create_entity(Vector2i(index, index)))
	_expect_true(first_store.remove_entity(first_ids[0]), "swap-remove first entity")
	_expect_equal(first_store.get_entity_ids_copy(), PackedInt64Array([3, 2]), "last dense row fills removed first row")
	_expect_equal(first_store.get_cell_position(3), Vector2i(2, 2), "moved first-row mapping stays valid")
	_expect_equal(first_store.get_cell_position(2), Vector2i.ONE, "unmoved first-store mapping stays valid")

	var middle_store := EntityStore.new(Vector2i(8, 8))
	for index in range(4):
		middle_store.create_entity(Vector2i(index, 0))
	_expect_true(middle_store.remove_entity(2), "swap-remove middle entity")
	_expect_equal(middle_store.get_entity_ids_copy(), PackedInt64Array([1, 4, 3]), "last dense row fills removed middle row")
	_expect_equal(middle_store.get_cell_position(4), Vector2i(3, 0), "moved middle-row mapping stays valid")
	_expect_equal(middle_store.get_cell_position(3), Vector2i(2, 0), "other middle-store mapping stays valid")

	var last_store := EntityStore.new(Vector2i(8, 8))
	for index in range(3):
		last_store.create_entity(Vector2i(index, 1))
	_expect_true(last_store.remove_entity(3), "remove last dense entity")
	_expect_equal(last_store.get_entity_ids_copy(), PackedInt64Array([1, 2]), "last removal needs no swap")
	_expect_equal(last_store.get_cell_position(2), Vector2i(1, 1), "last removal preserves previous mapping")


func _test_snapshot_immutability_and_layout() -> void:
	var store := EntityStore.new(Vector2i(16, 16))
	var first := store.create_entity(Vector2i(2, 3))
	store.create_entity(Vector2i(4, 5))
	var ids := store.get_entity_ids_copy()
	var positions := store.get_cell_positions_copy()
	ids[0] = 999
	positions[0] = Vector2i(15, 15)
	_expect_true(store.has_entity(first), "ID snapshot cannot alter mapping")
	_expect_equal(store.get_cell_position(first), Vector2i(2, 3), "position snapshot cannot alter storage")
	_expect_equal(store.get_entity_ids_copy(), PackedInt64Array([1, 2]), "ID snapshot copy remains stable")
	_expect_equal(store.get_cell_positions_copy(), [Vector2i(2, 3), Vector2i(4, 5)], "position snapshot follows dense layout")
	_expect_true(store is RefCounted, "store is data-only RefCounted")
	_expect_false(store.has_method("get_tree"), "store has no scene-tree API")
	var source := FileAccess.get_file_as_string("res://scripts/entities/entity_store.gd")
	_expect_true(source.contains("PackedInt64Array"), "stable IDs use compact packed storage")
	_expect_true(source.contains("PackedInt32Array"), "logical positions use compact packed columns")
	_expect_false(source.contains("extends Node"), "entity store has no Node dependency")
	_expect_false(source.contains("TerrainTypes"), "entity store does not know terrain")


func _test_ephemeral_dense_iteration_api() -> void:
	var store := EntityStore.new(Vector2i(5, 5))
	var first := store.create_entity(Vector2i(1, 1))
	var second := store.create_entity(Vector2i(2, 2))
	_expect_equal(store.get_dense_count(), 2, "dense count follows active entity count")
	_expect_equal(store.get_entity_id_at_dense_index(0), first, "dense zero exposes stable ID")
	_expect_equal(store.get_entity_id_at_dense_index(1), second, "dense one exposes stable ID")
	_expect_equal(store.get_cell_position_at_dense_index(1), Vector2i(2, 2), "dense position read")
	_expect_true(store.set_cell_position_at_dense_index(1, Vector2i(4, 4)), "dense position write")
	_expect_equal(store.get_cell_position(second), Vector2i(4, 4), "dense write updates stable-ID view")
	_expect_false(store.set_cell_position_at_dense_index(1, Vector2i(5, 4)), "dense write enforces world bounds")
	_expect_equal(store.get_entity_id_at_dense_index(-1), EntityStore.INVALID_ENTITY_ID, "negative dense ID read sentinel")
	_expect_equal(store.get_entity_id_at_dense_index(2), EntityStore.INVALID_ENTITY_ID, "past-edge dense ID read sentinel")
	_expect_equal(
		store.get_cell_position_at_dense_index(2),
		EntityStore.INVALID_CELL_POSITION,
		"past-edge dense position sentinel",
	)
	_expect_false(store.set_cell_position_at_dense_index(2, Vector2i.ZERO), "past-edge dense write rejected")
	store.remove_entity(first)
	_expect_equal(store.get_entity_id_at_dense_index(0), second, "swap-remove changes ephemeral dense position")
	_expect_equal(store.get_cell_position_at_dense_index(0), Vector2i(4, 4), "moved dense row retains data")


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
