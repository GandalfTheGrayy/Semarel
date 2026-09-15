extends MainLoop

var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	_test_single_node_snapshot_renderer()
	_test_living_and_remains_snapshots()
	if _failures == 0:
		print("DEBUG_ENTITY_RENDERER_TESTS_PASSED assertions=%d" % _assertions)
	else:
		printerr("DEBUG_ENTITY_RENDERER_TESTS_FAILED failures=%d assertions=%d" % [_failures, _assertions])
		assert(false, "Debug entity renderer test suite failed")


func _process(_delta: float) -> bool:
	return true


func _test_single_node_snapshot_renderer() -> void:
	var store := EntityStore.new(Vector2i(32, 32))
	for index in range(100):
		store.create_entity(Vector2i(index % 32, floori(float(index) / 32.0)))
	var first_position := store.get_cell_position(1)
	var renderer := DebugEntityRenderer.new()
	renderer.set_entity_store(store)
	renderer.refresh_from_store()
	_expect_equal(renderer.get_marker_count(), 100, "one renderer snapshot represents one hundred entities")
	_expect_equal(renderer.get_child_count(), 0, "renderer creates no per-entity child Nodes")
	_expect_equal(renderer.get_refresh_count(), 1, "first explicit refresh counted once")
	_expect_equal(store.get_cell_position(1), first_position, "renderer refresh does not mutate entity store")

	store.create_entity(Vector2i(31, 31))
	_expect_equal(renderer.get_marker_count(), 100, "store mutation does not redraw implicitly each frame")
	renderer.refresh_from_store()
	_expect_equal(renderer.get_marker_count(), 101, "explicit refresh observes new entity snapshot")
	_expect_equal(renderer.get_refresh_count(), 2, "second explicit refresh counted once")
	_expect_equal(renderer.get_child_count(), 0, "updated renderer remains a single presentation object")
	renderer.free()
	_expect_equal(store.get_entity_count(), 101, "freeing presentation preserves authoritative entity data")
	_expect_equal(store.get_cell_position(1), first_position, "freeing presentation preserves entity positions")


func _test_living_and_remains_snapshots() -> void:
	var store := EntityStore.new(Vector2i(16, 16))
	var living := LivingStateStore.new(store)
	var remains := RemainsStateStore.new(store)
	for index in range(100):
		var entity_id := store.create_entity(Vector2i(index % 16, floori(float(index) / 16.0)))
		if index < 60:
			living.add_living_state(entity_id, 0)
		elif index < 90:
			remains.add_remains_state(entity_id, 20)
	var renderer := DebugEntityRenderer.new()
	renderer.set_entity_store(store)
	renderer.set_state_stores(living, remains)
	renderer.refresh_from_store()
	_expect_equal(renderer.get_marker_count(), 100, "state-aware renderer retains every core marker")
	_expect_equal(renderer.get_living_marker_count(), 60, "renderer snapshots living membership")
	_expect_equal(renderer.get_remains_marker_count(), 30, "renderer snapshots remains membership")
	_expect_equal(renderer.get_child_count(), 0, "mixed markers create no per-entity child Nodes")
	_expect_equal(living.get_living_count(), 60, "renderer does not mutate living authority")
	_expect_equal(remains.get_remains_count(), 30, "renderer does not mutate remains authority")
	_expect_true(
		DebugEntityRenderer.LIVING_MARKER_COLOR != DebugEntityRenderer.REMAINS_MARKER_COLOR,
		"living and remains use visibly distinct debug tones",
	)
	PrototypeLifecycleTransition.new().transition_to_remains(1, 21, store, living, remains)
	_expect_equal(renderer.get_living_marker_count(), 60, "membership changes wait for explicit refresh")
	_expect_equal(renderer.get_remains_marker_count(), 30, "remains changes wait for explicit refresh")
	renderer.refresh_from_store()
	_expect_equal(renderer.get_living_marker_count(), 59, "refresh observes transitioned living count")
	_expect_equal(renderer.get_remains_marker_count(), 31, "refresh observes transitioned remains count")
	_expect_equal(renderer.get_refresh_count(), 2, "transition causes only the requested refresh")
	_expect_equal(renderer.get_child_count(), 0, "refreshed mixed renderer remains one Node2D")
	renderer.free()


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures += 1
		printerr("FAIL: %s | expected=%s actual=%s" % [label, expected, actual])


func _expect_true(value: bool, label: String) -> void:
	_assertions += 1
	if not value:
		_failures += 1
		printerr("FAIL: %s" % label)
