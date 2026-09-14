extends MainLoop

const CHUNK_SIZE: int = 64

var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	_test_chunk_storage_independence()
	_test_world_bounds_and_partial_edges()
	_test_elevation_pending_changes()
	_test_layered_change_sets()
	_test_renderer_ignores_elevation_changes()
	if _failures == 0:
		print("WORLD_LAYER_EXTENSIBILITY_TESTS_PASSED assertions=%d" % _assertions)
	else:
		printerr(
			"WORLD_LAYER_EXTENSIBILITY_TESTS_FAILED failures=%d assertions=%d"
			% [_failures, _assertions],
		)
		assert(false, "World layer extensibility test suite failed")


func _process(_delta: float) -> bool:
	return true


func _test_chunk_storage_independence() -> void:
	var chunk := WorldChunkData.new(4, TerrainTypes.Id.LAND)
	_expect_equal(chunk.get_terrain_copy().size(), 16, "terrain storage size")
	_expect_equal(chunk.get_elevation_copy().size(), 16, "elevation storage size")
	_expect_equal(chunk.get_elevation(Vector2i.ZERO), WorldChunkData.DEFAULT_ELEVATION, "default elevation")
	_expect_equal(chunk.get_elevation(Vector2i(3, 3)), WorldChunkData.DEFAULT_ELEVATION, "last default elevation")

	_expect_true(chunk.set_terrain(Vector2i.ZERO, TerrainTypes.Id.ROCK), "terrain write accepted")
	_expect_equal(chunk.get_elevation(Vector2i.ZERO), 0, "terrain write preserves elevation")
	_expect_true(chunk.set_elevation(Vector2i.ZERO, 87), "elevation write accepted")
	_expect_equal(chunk.get_terrain(Vector2i.ZERO), TerrainTypes.Id.ROCK, "elevation write preserves terrain")
	_expect_equal(chunk.get_elevation(Vector2i.ZERO), 87, "elevation write stored")

	_expect_false(chunk.set_elevation(Vector2i(-1, 0), 12), "negative local elevation write rejected")
	_expect_false(chunk.set_elevation(Vector2i(4, 0), 12), "past-edge local elevation write rejected")
	_expect_equal(
		chunk.get_elevation(Vector2i(-1, 0)),
		WorldChunkData.INVALID_ELEVATION,
		"invalid local elevation read sentinel",
	)
	_expect_false(chunk.set_elevation(Vector2i.ONE, -1), "negative elevation rejected")
	_expect_false(chunk.set_elevation(Vector2i.ONE, 256), "past-byte elevation rejected")
	_expect_true(chunk.fill_elevation(255), "maximum elevation fill accepted")
	_expect_equal(chunk.get_elevation(Vector2i.ZERO), 255, "elevation fill reaches first cell")
	_expect_equal(chunk.get_elevation(Vector2i(3, 3)), 255, "elevation fill reaches last cell")
	_expect_equal(chunk.get_terrain(Vector2i.ZERO), TerrainTypes.Id.ROCK, "elevation fill preserves terrain")
	_expect_false(chunk.fill_elevation(256), "invalid elevation fill rejected")

	var terrain_copy := chunk.get_terrain_copy()
	var elevation_copy := chunk.get_elevation_copy()
	terrain_copy[0] = TerrainTypes.Id.WATER
	elevation_copy[0] = 1
	_expect_equal(chunk.get_terrain(Vector2i.ZERO), TerrainTypes.Id.ROCK, "terrain copy cannot mutate terrain")
	_expect_equal(chunk.get_elevation(Vector2i.ZERO), 255, "elevation copy cannot mutate elevation")


func _test_world_bounds_and_partial_edges() -> void:
	var grid := WorldGrid.new(Vector2i(65, 65), CHUNK_SIZE, TerrainTypes.Id.WATER)
	var positions: Array[Vector2i] = [
		Vector2i.ZERO,
		Vector2i(CHUNK_SIZE - 1, CHUNK_SIZE - 1),
		Vector2i(CHUNK_SIZE, 0),
		Vector2i(CHUNK_SIZE, CHUNK_SIZE),
	]
	var values: Array[int] = [1, 63, 64, 255]
	for index in range(positions.size()):
		_expect_true(grid.set_elevation(positions[index], values[index]), "bounded elevation set %d" % index)
		_expect_equal(grid.get_elevation(positions[index]), values[index], "bounded elevation get %d" % index)

	_expect_equal(grid.world_to_chunk(Vector2i(CHUNK_SIZE - 1, 0)), Vector2i.ZERO, "boundary minus one chunk")
	_expect_equal(grid.world_to_chunk(Vector2i(CHUNK_SIZE, 0)), Vector2i(1, 0), "boundary chunk")
	_expect_equal(grid.get_elevation(Vector2i(-1, 0)), WorldChunkData.INVALID_ELEVATION, "negative world read sentinel")
	_expect_equal(grid.get_elevation(Vector2i(65, 64)), WorldChunkData.INVALID_ELEVATION, "outside world read sentinel")
	_expect_false(grid.set_elevation(Vector2i(-1, 0), 10), "negative world write rejected")
	_expect_false(grid.set_elevation(Vector2i(64, 65), 10), "outside world write rejected")
	_expect_false(grid.set_elevation(Vector2i.ZERO, -1), "invalid low world elevation rejected")
	_expect_false(grid.set_elevation(Vector2i.ZERO, 256), "invalid high world elevation rejected")

	var partial_snapshot := grid.get_chunk_elevation_copy(Vector2i.ONE)
	_expect_equal(partial_snapshot.size(), CHUNK_SIZE * CHUNK_SIZE, "partial chunk keeps padded elevation storage")
	_expect_equal(partial_snapshot[0], 255, "partial chunk snapshot contains world max cell")
	partial_snapshot[0] = 0
	_expect_equal(grid.get_elevation(Vector2i(64, 64)), 255, "elevation snapshot cannot mutate world")
	_expect_equal(grid.get_chunk_elevation_copy(Vector2i(2, 0)).size(), 0, "invalid chunk elevation snapshot empty")


func _test_elevation_pending_changes() -> void:
	var grid := WorldGrid.new(Vector2i(16, 16), 4, TerrainTypes.Id.LAND)
	_expect_true(grid.set_elevation(Vector2i.ZERO, 0), "same-value elevation write accepted")
	_expect_false(grid.set_elevation(Vector2i(-1, 0), 20), "invalid position creates no elevation change")
	_expect_false(grid.set_elevation(Vector2i.ZERO, 256), "invalid value creates no elevation change")
	_expect_equal(grid.get_pending_elevation_chunk_count(), 0, "same-value elevation creates no pending chunk")
	_expect_true(grid.commit_changes().is_empty(), "same-value elevation leaves empty commit")
	_expect_equal(grid.get_revision(), 0, "same-value elevation does not advance revision")

	for index in range(8):
		grid.set_elevation(Vector2i(index % 4, index / 4), index + 1)
	_expect_equal(grid.get_pending_elevation_chunk_count(), 1, "same-chunk elevations deduplicate")
	_expect_equal(grid.get_pending_terrain_chunk_count(), 0, "elevation writes do not create terrain changes")

	var unordered_positions: Array[Vector2i] = [
		Vector2i(12, 12),
		Vector2i(4, 8),
		Vector2i(12, 0),
		Vector2i(0, 8),
	]
	for index in range(unordered_positions.size()):
		grid.set_elevation(unordered_positions[index], 20 + index)
	var change_set := grid.commit_changes()
	_expect_equal(
		change_set.get_elevation_chunks(),
		[Vector2i.ZERO, Vector2i(3, 0), Vector2i(0, 2), Vector2i(1, 2), Vector2i(3, 3)],
		"elevation chunks sort by y then x",
	)
	_expect_equal(change_set.get_terrain_chunk_count(), 0, "elevation-only batch has no terrain chunks")
	_expect_equal(grid.get_pending_elevation_chunk_count(), 0, "commit clears pending elevation chunks")


func _test_layered_change_sets() -> void:
	var grid := WorldGrid.new(Vector2i(12, 8), 4, TerrainTypes.Id.WATER)
	grid.set_terrain(Vector2i(1, 1), TerrainTypes.Id.LAND)
	_expect_equal(grid.get_pending_terrain_chunk_count(), 1, "terrain marks terrain pending")
	_expect_equal(grid.get_pending_elevation_chunk_count(), 0, "terrain does not mark elevation pending")
	var first := grid.commit_changes()
	_expect_equal(first.get_revision(), 1, "terrain-only batch revision")
	_expect_equal(first.get_terrain_chunks(), [Vector2i.ZERO], "terrain-only category")
	_expect_equal(first.get_elevation_chunk_count(), 0, "terrain-only elevation category empty")

	grid.set_elevation(Vector2i(9, 1), 90)
	_expect_equal(grid.get_pending_terrain_chunk_count(), 0, "elevation does not mark terrain pending")
	_expect_equal(grid.get_pending_elevation_chunk_count(), 1, "elevation marks elevation pending")
	var second := grid.commit_changes()
	_expect_equal(second.get_revision(), 2, "elevation-only batch revision")
	_expect_false(second.is_empty(), "elevation-only batch is not empty")
	_expect_equal(second.get_terrain_chunk_count(), 0, "elevation-only terrain category empty")
	_expect_equal(second.get_elevation_chunks(), [Vector2i(2, 0)], "elevation-only category")

	grid.set_terrain(Vector2i(5, 5), TerrainTypes.Id.ROCK)
	grid.set_elevation(Vector2i(5, 5), 120)
	_expect_equal(grid.get_pending_terrain_chunk_count(), 1, "mixed batch has one terrain pending chunk")
	_expect_equal(grid.get_pending_elevation_chunk_count(), 1, "mixed batch has one elevation pending chunk")
	var third := grid.commit_changes()
	_expect_equal(third.get_revision(), 3, "mixed batch advances one revision")
	_expect_equal(grid.get_revision(), 3, "world has one revision per non-empty batch")
	_expect_equal(third.get_terrain_chunks(), [Vector2i(1, 1)], "mixed terrain category")
	_expect_equal(third.get_elevation_chunks(), [Vector2i(1, 1)], "mixed elevation category")
	_expect_equal(first.get_terrain_chunks(), [Vector2i.ZERO], "first snapshot remains stable")
	_expect_equal(first.get_elevation_chunk_count(), 0, "first elevation snapshot remains empty")
	_expect_equal(second.get_terrain_chunk_count(), 0, "second terrain snapshot remains empty")
	_expect_equal(second.get_elevation_chunks(), [Vector2i(2, 0)], "second elevation snapshot remains stable")

	var terrain_source: Array[Vector2i] = [Vector2i(2, 1)]
	var elevation_source: Array[Vector2i] = [Vector2i(1, 2), Vector2i.ZERO, Vector2i(1, 2)]
	var direct := WorldChangeSet.new(9, terrain_source, elevation_source)
	terrain_source.clear()
	elevation_source.clear()
	var terrain_copy := direct.get_terrain_chunks()
	var elevation_copy := direct.get_elevation_chunks()
	terrain_copy.clear()
	elevation_copy.clear()
	_expect_equal(direct.get_terrain_chunks(), [Vector2i(2, 1)], "terrain collection immutable by contract")
	_expect_equal(
		direct.get_elevation_chunks(),
		[Vector2i.ZERO, Vector2i(1, 2)],
		"elevation collection copied, deduplicated, sorted, and immutable",
	)
	_expect_true(grid.commit_changes().is_empty(), "empty layered commit")
	_expect_equal(grid.get_revision(), 3, "empty layered commit retains revision")


func _test_renderer_ignores_elevation_changes() -> void:
	var grid := WorldGrid.new(Vector2i(4, 2), 2, TerrainTypes.Id.WATER)
	grid.set_terrain(Vector2i.ZERO, TerrainTypes.Id.LAND)
	grid.commit_changes()
	var renderer := TerrainRenderer.new()
	renderer.set_world_grid(grid)
	renderer.rebuild_all()

	var left_before := renderer.get_chunk_image(Vector2i.ZERO)
	var right_before := renderer.get_chunk_image(Vector2i(1, 0))
	grid.set_elevation(Vector2i.ZERO, 200)
	var elevation_only := grid.commit_changes()
	renderer.apply_world_changes(elevation_only)
	_expect_equal(elevation_only.get_terrain_chunk_count(), 0, "renderer receives no terrain invalidation")
	_expect_equal(elevation_only.get_elevation_chunks(), [Vector2i.ZERO], "elevation invalidation remains available")
	_expect_equal(renderer.get_last_applied_revision(), elevation_only.get_revision(), "renderer observes batch revision")
	_expect_equal(renderer.get_chunk_image(Vector2i.ZERO).get_data(), left_before.get_data(), "elevation-only batch preserves left image")
	_expect_equal(renderer.get_chunk_image(Vector2i(1, 0)).get_data(), right_before.get_data(), "elevation-only batch preserves right image")

	grid.set_terrain(Vector2i(2, 0), TerrainTypes.Id.ROCK)
	var terrain_only := grid.commit_changes()
	renderer.apply_world_changes(terrain_only)
	_expect_equal(terrain_only.get_terrain_chunks(), [Vector2i(1, 0)], "terrain invalidation still routed")
	_expect_equal(terrain_only.get_elevation_chunk_count(), 0, "terrain-only batch has no elevation invalidation")
	_expect_color(
		renderer.get_chunk_image(Vector2i(1, 0)).get_pixel(0, 0),
		TerrainPalette.get_color(TerrainTypes.Id.ROCK),
		"terrain-only batch refreshes expected image",
	)
	_expect_equal(grid.get_elevation(Vector2i.ZERO), 200, "renderer preserves authoritative elevation")
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
