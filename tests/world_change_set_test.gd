extends MainLoop

class TestObserver:
	extends RefCounted

	var revision: int = -1
	var terrain_chunks: Array[Vector2i] = []


	func observe(change_set: WorldChangeSet) -> void:
		revision = change_set.get_revision()
		terrain_chunks = change_set.get_terrain_chunks()


var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	_test_empty_commit_and_false_changes()
	_test_batch_deduplication_and_deterministic_order()
	_test_change_set_immutability()
	_test_snapshot_stability_and_multiple_consumers()
	_test_renderer_change_set_consumer()
	if _failures == 0:
		print("WORLD_CHANGE_SET_TESTS_PASSED assertions=%d" % _assertions)
	else:
		printerr(
			"WORLD_CHANGE_SET_TESTS_FAILED failures=%d assertions=%d"
			% [_failures, _assertions],
		)
		assert(false, "World change-set test suite failed")


func _process(_delta: float) -> bool:
	return true


func _test_empty_commit_and_false_changes() -> void:
	var grid := WorldGrid.new(Vector2i(8, 8), 4, TerrainTypes.Id.WATER)
	_expect_equal(grid.get_revision(), 0, "initial world revision")
	_expect_equal(grid.get_pending_terrain_chunk_count(), 0, "initial pending state")

	var empty_change_set := grid.commit_changes()
	_expect_true(empty_change_set.is_empty(), "empty commit creates empty change set")
	_expect_equal(empty_change_set.get_revision(), 0, "empty commit retains revision")
	_expect_equal(grid.get_revision(), 0, "empty commit does not advance world revision")

	_expect_false(grid.set_terrain(Vector2i(-1, 0), TerrainTypes.Id.LAND), "invalid position rejected")
	_expect_false(grid.set_terrain(Vector2i.ZERO, 255), "invalid terrain rejected")
	_expect_true(grid.set_terrain(Vector2i.ZERO, TerrainTypes.Id.WATER), "same-value write accepted")
	_expect_equal(grid.get_pending_terrain_chunk_count(), 0, "invalid and same-value writes create no pending change")
	_expect_equal(grid.commit_changes().get_revision(), 0, "false changes do not advance revision")

	_expect_true(grid.set_terrain(Vector2i.ZERO, TerrainTypes.Id.LAND), "first real change accepted")
	var first_change_set := grid.commit_changes()
	_expect_equal(first_change_set.get_revision(), 1, "first non-empty commit revision")
	_expect_equal(grid.get_revision(), 1, "world revision follows first commit")
	_expect_equal(first_change_set.get_terrain_chunks(), [Vector2i.ZERO], "first commit chunk")
	_expect_equal(grid.get_pending_terrain_chunk_count(), 0, "non-empty commit clears pending state")
	_expect_equal(grid.commit_changes().get_revision(), 1, "later empty commit retains current revision")


func _test_batch_deduplication_and_deterministic_order() -> void:
	var grid := WorldGrid.new(Vector2i(64, 64), 16, TerrainTypes.Id.WATER)
	for cell_index in range(100):
		var local_position := Vector2i(cell_index % 10, cell_index / 10)
		grid.set_terrain(Vector2i(32, 32) + local_position, TerrainTypes.Id.LAND)
	_expect_equal(grid.get_pending_terrain_chunk_count(), 1, "100 cells in one chunk deduplicate")

	var unordered_world_positions: Array[Vector2i] = [
		Vector2i(48, 48),
		Vector2i(16, 32),
		Vector2i(48, 0),
		Vector2i(0, 32),
		Vector2i(16, 0),
	]
	for world_position in unordered_world_positions:
		grid.set_terrain(world_position, TerrainTypes.Id.ROCK)

	var change_set := grid.commit_changes()
	var expected_order: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(3, 0),
		Vector2i(0, 2),
		Vector2i(1, 2),
		Vector2i(2, 2),
		Vector2i(3, 3),
	]
	_expect_equal(change_set.get_terrain_chunks(), expected_order, "chunks sort by y then x")
	_expect_equal(change_set.get_terrain_chunk_count(), expected_order.size(), "batch contains each chunk once")


func _test_change_set_immutability() -> void:
	var source_chunks: Array[Vector2i] = [Vector2i(2, 1), Vector2i.ZERO, Vector2i(2, 1)]
	var change_set := WorldChangeSet.new(7, source_chunks)
	source_chunks.clear()
	_expect_equal(change_set.get_revision(), 7, "constructor stores revision")
	_expect_equal(
		change_set.get_terrain_chunks(),
		[Vector2i.ZERO, Vector2i(2, 1)],
		"constructor copies, deduplicates, and sorts input",
	)

	var consumer_copy := change_set.get_terrain_chunks()
	consumer_copy.clear()
	_expect_equal(change_set.get_terrain_chunk_count(), 2, "consumer cannot clear internal chunks")
	_expect_equal(
		change_set.get_terrain_chunks(),
		[Vector2i.ZERO, Vector2i(2, 1)],
		"later consumer sees unchanged collection",
	)


func _test_snapshot_stability_and_multiple_consumers() -> void:
	var grid := WorldGrid.new(Vector2i(8, 4), 4, TerrainTypes.Id.WATER)
	grid.set_terrain(Vector2i(1, 1), TerrainTypes.Id.LAND)
	var first_change_set := grid.commit_changes()

	var observer_a := TestObserver.new()
	var observer_b := TestObserver.new()
	observer_a.observe(first_change_set)
	observer_a.terrain_chunks.clear()
	observer_b.observe(first_change_set)
	_expect_equal(observer_a.revision, 1, "observer A sees first revision")
	_expect_equal(observer_b.revision, 1, "observer B sees first revision")
	_expect_equal(observer_b.terrain_chunks, [Vector2i.ZERO], "observer A cannot alter observer B result")

	grid.set_terrain(Vector2i(5, 1), TerrainTypes.Id.ROCK)
	var second_change_set := grid.commit_changes()
	_expect_equal(second_change_set.get_revision(), 2, "second non-empty commit revision")
	_expect_equal(second_change_set.get_terrain_chunks(), [Vector2i(1, 0)], "second change set contains chunk B")
	_expect_equal(first_change_set.get_revision(), 1, "old change set retains revision")
	_expect_equal(first_change_set.get_terrain_chunks(), [Vector2i.ZERO], "old change set retains chunk A")


func _test_renderer_change_set_consumer() -> void:
	var grid := WorldGrid.new(Vector2i(4, 2), 2, TerrainTypes.Id.WATER)
	var renderer := TerrainRenderer.new()
	renderer.set_world_grid(grid)
	renderer.rebuild_all()

	grid.set_terrain(Vector2i.ZERO, TerrainTypes.Id.LAND)
	var first_change_set := grid.commit_changes()
	grid.set_terrain(Vector2i(2, 0), TerrainTypes.Id.ROCK)
	_expect_equal(grid.get_revision(), 1, "pending mutation does not advance revision")
	_expect_equal(grid.get_terrain(Vector2i(2, 0)), TerrainTypes.Id.ROCK, "world changes before presentation")

	var observer_before := TestObserver.new()
	observer_before.observe(first_change_set)
	renderer.apply_world_changes(first_change_set)
	var observer_after := TestObserver.new()
	observer_after.observe(first_change_set)
	_expect_equal(observer_before.revision, observer_after.revision, "renderer does not change observed revision")
	_expect_equal(renderer.get_last_applied_revision(), observer_before.revision, "renderer and observers see same revision")
	_expect_equal(observer_before.terrain_chunks, observer_after.terrain_chunks, "renderer does not consume chunk metadata")
	_expect_equal(first_change_set.get_terrain_chunks(), [Vector2i.ZERO], "same change set remains reusable")
	_expect_color(
		renderer.get_chunk_image(Vector2i.ZERO).get_pixel(0, 0),
		TerrainPalette.get_color(TerrainTypes.Id.LAND),
		"renderer refreshes listed chunk",
	)
	_expect_color(
		renderer.get_chunk_image(Vector2i(1, 0)).get_pixel(0, 0),
		TerrainPalette.get_color(TerrainTypes.Id.WATER),
		"renderer leaves unlisted chunk unchanged",
	)
	_expect_equal(grid.get_terrain(Vector2i.ZERO), TerrainTypes.Id.LAND, "renderer preserves authoritative chunk A")
	_expect_equal(grid.get_terrain(Vector2i(2, 0)), TerrainTypes.Id.ROCK, "renderer preserves authoritative chunk B")

	var second_change_set := grid.commit_changes()
	renderer.apply_world_changes(second_change_set)
	_expect_equal(second_change_set.get_revision(), 2, "second renderer batch revision")
	_expect_equal(second_change_set.get_terrain_chunks(), [Vector2i(1, 0)], "second renderer batch chunk")
	_expect_color(
		renderer.get_chunk_image(Vector2i(1, 0)).get_pixel(0, 0),
		TerrainPalette.get_color(TerrainTypes.Id.ROCK),
		"second batch refreshes its listed chunk",
	)
	_expect_equal(first_change_set.get_terrain_chunks(), [Vector2i.ZERO], "second apply leaves old change set stable")
	renderer.free()


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


func _expect_color(actual: Color, expected: Color, label: String) -> void:
	_assertions += 1
	if not actual.is_equal_approx(expected):
		_failures += 1
		printerr("FAIL: %s | expected=%s actual=%s" % [label, expected, actual])
