extends MainLoop

const TEST_CHUNK_SIZE: int = 64
const TEST_WORLD_SIZE: Vector2i = Vector2i(256, 256)

var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	_test_chunk_storage_and_access()
	_test_world_coordinates_and_bounds()
	_test_chunk_read_api()
	_test_world_terrain_access()
	_test_world_terrain_read_regression()
	_test_pending_chunk_tracking()
	_test_data_only_types()
	if _failures == 0:
		print("WORLD_DATA_TESTS_PASSED assertions=%d" % _assertions)
	else:
		printerr("WORLD_DATA_TESTS_FAILED failures=%d assertions=%d" % [_failures, _assertions])
		assert(false, "World data test suite failed")


func _process(_delta: float) -> bool:
	return true


func _test_chunk_storage_and_access() -> void:
	var chunk := WorldChunkData.new(TEST_CHUNK_SIZE, TerrainTypes.Id.LAND)
	_expect_equal(chunk.get_cell_count(), TEST_CHUNK_SIZE * TEST_CHUNK_SIZE, "chunk storage size")
	_expect_true(chunk.is_valid_local_position(Vector2i.ZERO), "chunk first position is valid")
	_expect_true(
		chunk.is_valid_local_position(Vector2i(TEST_CHUNK_SIZE - 1, TEST_CHUNK_SIZE - 1)),
		"chunk last position is valid",
	)
	_expect_false(chunk.is_valid_local_position(Vector2i(-1, 0)), "negative local position is invalid")
	_expect_false(chunk.is_valid_local_position(Vector2i(TEST_CHUNK_SIZE, 0)), "past-edge local position is invalid")
	_expect_equal(chunk.get_terrain(Vector2i.ZERO), TerrainTypes.Id.LAND, "chunk fill reaches first cell")
	_expect_equal(
		chunk.get_terrain(Vector2i(TEST_CHUNK_SIZE - 1, TEST_CHUNK_SIZE - 1)),
		TerrainTypes.Id.LAND,
		"chunk fill reaches last cell",
	)
	_expect_true(chunk.set_terrain(Vector2i.ZERO, TerrainTypes.Id.SAND), "set first chunk cell")
	_expect_true(
		chunk.set_terrain(Vector2i(TEST_CHUNK_SIZE - 1, TEST_CHUNK_SIZE - 1), TerrainTypes.Id.ROCK),
		"set last chunk cell",
	)
	_expect_equal(chunk.get_terrain(Vector2i.ZERO), TerrainTypes.Id.SAND, "get first chunk cell")
	_expect_equal(
		chunk.get_terrain(Vector2i(TEST_CHUNK_SIZE - 1, TEST_CHUNK_SIZE - 1)),
		TerrainTypes.Id.ROCK,
		"get last chunk cell",
	)
	_expect_equal(chunk.get_terrain(Vector2i(-1, 0)), TerrainTypes.INVALID, "invalid chunk get sentinel")
	_expect_false(chunk.set_terrain(Vector2i(-1, 0), TerrainTypes.Id.WATER), "invalid chunk set rejected")
	_expect_true(chunk.fill(TerrainTypes.Id.WATER), "chunk refill accepted")
	_expect_equal(chunk.get_terrain(Vector2i.ZERO), TerrainTypes.Id.WATER, "chunk refill updates storage")


func _test_world_coordinates_and_bounds() -> void:
	var grid := WorldGrid.new(TEST_WORLD_SIZE, TEST_CHUNK_SIZE, TerrainTypes.Id.LAND)
	_expect_equal(grid.get_chunk_count(), Vector2i(4, 4), "test world chunk count")
	var partial_grid := WorldGrid.new(Vector2i(TEST_CHUNK_SIZE + 1, TEST_CHUNK_SIZE + 1), TEST_CHUNK_SIZE)
	_expect_equal(partial_grid.get_chunk_count(), Vector2i(2, 2), "partial edge chunks are allocated")
	_expect_true(partial_grid.is_inside_world(Vector2i(TEST_CHUNK_SIZE, TEST_CHUNK_SIZE)), "partial edge cell is inside")
	_expect_true(grid.is_inside_world(Vector2i.ZERO), "world origin is inside")
	_expect_true(grid.is_inside_world(TEST_WORLD_SIZE - Vector2i.ONE), "world max minus one is inside")
	_expect_false(grid.is_inside_world(Vector2i(-1, 0)), "negative x is outside")
	_expect_false(grid.is_inside_world(Vector2i(0, -1)), "negative y is outside")
	_expect_false(grid.is_inside_world(Vector2i(TEST_WORLD_SIZE.x, 0)), "world max x is outside")
	_expect_false(grid.is_inside_world(Vector2i(0, TEST_WORLD_SIZE.y)), "world max y is outside")
	_expect_equal(grid.world_to_chunk(Vector2i.ZERO), Vector2i.ZERO, "origin chunk coordinate")
	_expect_equal(grid.world_to_local(Vector2i.ZERO), Vector2i.ZERO, "origin local coordinate")
	_expect_equal(grid.world_to_chunk(Vector2i(-1, -1)), Vector2i(-1, -1), "negative coordinate uses floor chunk")
	_expect_equal(
		grid.world_to_local(Vector2i(-1, -1)),
		Vector2i(TEST_CHUNK_SIZE - 1, TEST_CHUNK_SIZE - 1),
		"negative coordinate has normalized local position",
	)
	_expect_equal(
		grid.world_to_chunk(Vector2i(TEST_CHUNK_SIZE - 1, TEST_CHUNK_SIZE - 1)),
		Vector2i.ZERO,
		"boundary minus one chunk coordinate",
	)
	_expect_equal(
		grid.world_to_local(Vector2i(TEST_CHUNK_SIZE - 1, TEST_CHUNK_SIZE - 1)),
		Vector2i(TEST_CHUNK_SIZE - 1, TEST_CHUNK_SIZE - 1),
		"boundary minus one local coordinate",
	)
	_expect_equal(grid.world_to_chunk(Vector2i(TEST_CHUNK_SIZE, 0)), Vector2i(1, 0), "boundary chunk coordinate")
	_expect_equal(grid.world_to_local(Vector2i(TEST_CHUNK_SIZE, 0)), Vector2i.ZERO, "boundary local coordinate")
	_expect_equal(
		grid.world_to_chunk(TEST_WORLD_SIZE - Vector2i.ONE),
		Vector2i(3, 3),
		"world max minus one chunk coordinate",
	)
	_expect_equal(
		grid.world_to_local(TEST_WORLD_SIZE - Vector2i.ONE),
		Vector2i(TEST_CHUNK_SIZE - 1, TEST_CHUNK_SIZE - 1),
		"world max minus one local coordinate",
	)


func _test_world_terrain_access() -> void:
	var grid := WorldGrid.new(TEST_WORLD_SIZE, TEST_CHUNK_SIZE, TerrainTypes.Id.LAND)
	var positions := [
		Vector2i.ZERO,
		Vector2i(TEST_CHUNK_SIZE - 1, TEST_CHUNK_SIZE - 1),
		Vector2i(TEST_CHUNK_SIZE, 0),
		TEST_WORLD_SIZE - Vector2i.ONE,
	]
	var terrains := [
		TerrainTypes.Id.SAND,
		TerrainTypes.Id.ROCK,
		TerrainTypes.Id.WATER,
		TerrainTypes.Id.ROCK,
	]
	for index in range(positions.size()):
		_expect_true(grid.set_terrain(positions[index], terrains[index]), "world terrain set %d" % index)
		_expect_equal(grid.get_terrain(positions[index]), terrains[index], "world terrain get %d" % index)
	_expect_equal(grid.get_terrain(Vector2i(-1, 0)), TerrainTypes.INVALID, "negative world get sentinel")
	_expect_equal(grid.get_terrain(TEST_WORLD_SIZE), TerrainTypes.INVALID, "past-edge world get sentinel")
	grid.commit_changes()
	_expect_false(grid.set_terrain(Vector2i(-1, 0), TerrainTypes.Id.LAND), "negative world set rejected")
	_expect_false(grid.set_terrain(TEST_WORLD_SIZE, TerrainTypes.Id.LAND), "past-edge world set rejected")
	_expect_false(grid.set_terrain(Vector2i.ZERO, TerrainTypes.Id.size()), "invalid terrain ID rejected")
	_expect_equal(grid.get_pending_terrain_chunk_count(), 0, "invalid writes do not create pending chunks")


func _test_world_terrain_read_regression() -> void:
	for chunk_size in [3, 8, 64]:
		var world_size := Vector2i(chunk_size * 2 + 1, chunk_size + 2)
		var grid := WorldGrid.new(world_size, chunk_size, TerrainTypes.Id.LAND)
		var positions: Array[Vector2i] = [
			Vector2i.ZERO,
			Vector2i(chunk_size - 1, chunk_size - 1),
			Vector2i(chunk_size, 0),
			world_size - Vector2i.ONE,
		]
		var terrains: Array[int] = [
			TerrainTypes.Id.SAND,
			TerrainTypes.Id.ROCK,
			TerrainTypes.Id.WATER,
			TerrainTypes.Id.SAND,
		]
		for index in range(positions.size()):
			_expect_true(
				grid.set_terrain(positions[index], terrains[index]),
				"terrain regression set chunk size %d index %d" % [chunk_size, index],
			)
			_expect_equal(
				grid.get_terrain(positions[index]),
				terrains[index],
				"terrain regression get chunk size %d index %d" % [chunk_size, index],
			)
		_expect_equal(
			grid.get_terrain(Vector2i(-1, 0)),
			TerrainTypes.INVALID,
			"terrain regression rejects negative for chunk size %d" % chunk_size,
		)
		_expect_equal(
			grid.get_terrain(world_size),
			TerrainTypes.INVALID,
			"terrain regression rejects outside for chunk size %d" % chunk_size,
		)


func _test_chunk_read_api() -> void:
	var grid := WorldGrid.new(Vector2i(TEST_CHUNK_SIZE + 1, TEST_CHUNK_SIZE + 1), TEST_CHUNK_SIZE)
	_expect_true(grid.is_valid_chunk_position(Vector2i.ZERO), "first chunk position is valid")
	_expect_true(grid.is_valid_chunk_position(Vector2i.ONE), "partial edge chunk position is valid")
	_expect_false(grid.is_valid_chunk_position(Vector2i(-1, 0)), "negative chunk position is invalid")
	_expect_false(grid.is_valid_chunk_position(Vector2i(2, 0)), "past-edge chunk position is invalid")
	_expect_equal(grid.chunk_to_world_origin(Vector2i.ONE), Vector2i(TEST_CHUNK_SIZE, TEST_CHUNK_SIZE), "chunk origin")
	_expect_equal(
		grid.get_chunk_world_rect(Vector2i.ZERO),
		Rect2i(Vector2i.ZERO, Vector2i(TEST_CHUNK_SIZE, TEST_CHUNK_SIZE)),
		"full chunk world rect",
	)
	_expect_equal(
		grid.get_chunk_world_rect(Vector2i(1, 0)),
		Rect2i(Vector2i(TEST_CHUNK_SIZE, 0), Vector2i(1, TEST_CHUNK_SIZE)),
		"right partial chunk world rect",
	)
	_expect_equal(
		grid.get_chunk_world_rect(Vector2i.ONE),
		Rect2i(Vector2i(TEST_CHUNK_SIZE, TEST_CHUNK_SIZE), Vector2i.ONE),
		"corner partial chunk world rect",
	)
	_expect_equal(grid.get_chunk_world_rect(Vector2i(2, 0)), Rect2i(), "invalid chunk world rect")

	var snapshot := grid.get_chunk_terrain_copy(Vector2i.ZERO)
	_expect_equal(snapshot.size(), TEST_CHUNK_SIZE * TEST_CHUNK_SIZE, "terrain snapshot contains padded chunk storage")
	snapshot[0] = TerrainTypes.Id.ROCK
	_expect_equal(grid.get_terrain(Vector2i.ZERO), TerrainTypes.Id.WATER, "snapshot cannot mutate authoritative terrain")
	_expect_equal(grid.get_chunk_terrain_copy(Vector2i(2, 0)).size(), 0, "invalid chunk snapshot is empty")


func _test_pending_chunk_tracking() -> void:
	var grid := WorldGrid.new(TEST_WORLD_SIZE, TEST_CHUNK_SIZE, TerrainTypes.Id.LAND)
	_expect_true(grid.set_terrain(Vector2i(1, 1), TerrainTypes.Id.SAND), "first pending write")
	_expect_true(grid.set_terrain(Vector2i(2, 2), TerrainTypes.Id.ROCK), "second write in same chunk")
	_expect_equal(grid.get_pending_terrain_chunk_count(), 1, "same-chunk writes produce one pending chunk")
	_expect_true(grid.set_terrain(Vector2i(2, 2), TerrainTypes.Id.ROCK), "same-value write accepted")
	_expect_equal(grid.get_pending_terrain_chunk_count(), 1, "same-value write adds no pending entry")

	var first_change_set := grid.commit_changes()
	_expect_equal(first_change_set.get_terrain_chunks(), [Vector2i.ZERO], "commit returns pending origin chunk")
	_expect_equal(grid.get_pending_terrain_chunk_count(), 0, "commit clears pending chunks")
	_expect_true(
		grid.set_terrain(Vector2i(TEST_CHUNK_SIZE - 1, 0), TerrainTypes.Id.SAND),
		"write before chunk boundary",
	)
	_expect_true(grid.set_terrain(Vector2i(TEST_CHUNK_SIZE, 0), TerrainTypes.Id.ROCK), "write at chunk boundary")
	_expect_equal(grid.get_pending_terrain_chunk_count(), 2, "boundary writes create two pending chunks")
	var boundary_change_set := grid.commit_changes()
	_expect_equal(
		boundary_change_set.get_terrain_chunks(),
		[Vector2i.ZERO, Vector2i(1, 0)],
		"boundary commit contains both chunks",
	)


func _test_data_only_types() -> void:
	var chunk := WorldChunkData.new(2)
	var grid := WorldGrid.new(Vector2i(2, 2), 2)
	_expect_true(chunk is RefCounted, "chunk is RefCounted data")
	_expect_true(grid is RefCounted, "grid is RefCounted data")
	_expect_false(chunk.has_method("get_tree"), "chunk has no scene-tree API")
	_expect_false(grid.has_method("get_tree"), "grid has no scene-tree API")


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
