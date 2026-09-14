extends MainLoop

var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	_test_single_node_snapshot_renderer()
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


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures += 1
		printerr("FAIL: %s | expected=%s actual=%s" % [label, expected, actual])
