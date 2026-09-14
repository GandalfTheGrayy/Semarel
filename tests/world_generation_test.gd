extends MainLoop

const TEST_SEED: int = 12_345

var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	_test_seed_contract_and_fingerprints()
	_test_local_rng_isolation()
	_test_repeated_generation_stability()
	_test_values_and_bounds()
	_test_partial_edge_world()
	_test_chunk_partition_independence()
	_test_initial_commit_contract()
	_test_data_only_boundaries()
	if _failures == 0:
		print("WORLD_GENERATION_TESTS_PASSED assertions=%d" % _assertions)
	else:
		printerr(
			"WORLD_GENERATION_TESTS_FAILED failures=%d assertions=%d"
			% [_failures, _assertions],
		)
		assert(false, "World generation test suite failed")


func _process(_delta: float) -> bool:
	return true


func _test_seed_contract_and_fingerprints() -> void:
	var first := _generate_world(Vector2i(64, 64), 16, TEST_SEED)
	var second := _generate_world(Vector2i(64, 64), 16, TEST_SEED)
	var different := _generate_world(Vector2i(64, 64), 16, TEST_SEED + 1)

	_expect_equal(WorldGenerator.GENERATOR_VERSION, 1, "generator version starts at one")
	_expect_equal(WorldFingerprint.terrain(first), WorldFingerprint.terrain(second), "same seed terrain fingerprint")
	_expect_equal(WorldFingerprint.elevation(first), WorldFingerprint.elevation(second), "same seed elevation fingerprint")
	_expect_equal(WorldFingerprint.combined(first), WorldFingerprint.combined(second), "same seed combined fingerprint")
	for position in [Vector2i.ZERO, Vector2i(31, 17), Vector2i(63, 63)]:
		_expect_equal(first.get_terrain(position), second.get_terrain(position), "same seed representative terrain %s" % position)
		_expect_equal(first.get_elevation(position), second.get_elevation(position), "same seed representative elevation %s" % position)
	_expect_true(
		WorldFingerprint.combined(first) != WorldFingerprint.combined(different),
		"different seed changes meaningful output",
	)
	_expect_true(
		WorldFingerprint.terrain(first) != WorldFingerprint.terrain(different)
		or WorldFingerprint.elevation(first) != WorldFingerprint.elevation(different),
		"different seed changes at least one layer fingerprint",
	)


func _test_local_rng_isolation() -> void:
	seed(77)
	for index in range(40):
		randi()
	var first := _generate_world(Vector2i(32, 32), 8, TEST_SEED)
	seed(901)
	for index in range(91):
		randf()
	var second := _generate_world(Vector2i(32, 32), 8, TEST_SEED)
	_expect_equal(
		WorldFingerprint.combined(first),
		WorldFingerprint.combined(second),
		"global RNG activity does not affect generation",
	)


func _test_repeated_generation_stability() -> void:
	var generator := WorldGenerator.new()
	var first := WorldGrid.new(Vector2i(32, 24), 8, TerrainTypes.Id.WATER)
	var second := WorldGrid.new(Vector2i(32, 24), 8, TerrainTypes.Id.WATER)
	var third := WorldGrid.new(Vector2i(32, 24), 8, TerrainTypes.Id.WATER)
	generator.generate_into(first, -804)
	generator.generate_into(second, -804)
	WorldGenerator.new().generate_into(third, -804)
	_expect_equal(WorldFingerprint.combined(first), WorldFingerprint.combined(second), "same instance keeps no generation state")
	_expect_equal(WorldFingerprint.combined(first), WorldFingerprint.combined(third), "separate instances produce same output")


func _test_values_and_bounds() -> void:
	var world := _generate_world(Vector2i(64, 64), 16, TEST_SEED)
	var terrain_valid := true
	var elevation_valid := true
	for world_y in range(64):
		for world_x in range(64):
			var position := Vector2i(world_x, world_y)
			terrain_valid = terrain_valid and TerrainTypes.is_valid(world.get_terrain(position))
			elevation_valid = elevation_valid and WorldChunkData.is_valid_elevation(world.get_elevation(position))
	_expect_true(terrain_valid, "all generated terrain IDs are valid")
	_expect_true(elevation_valid, "all generated elevation values are valid")
	_expect_equal(world.get_terrain(Vector2i(-1, 0)), TerrainTypes.INVALID, "negative terrain remains outside")
	_expect_equal(world.get_elevation(Vector2i(64, 0)), WorldChunkData.INVALID_ELEVATION, "past-edge elevation remains outside")


func _test_partial_edge_world() -> void:
	var world := _generate_world(Vector2i(65, 65), 64, TEST_SEED)
	_expect_equal(world.get_chunk_count(), Vector2i(2, 2), "partial world creates edge chunks")
	_expect_true(TerrainTypes.is_valid(world.get_terrain(Vector2i(64, 64))), "partial corner terrain generated")
	_expect_true(WorldChunkData.is_valid_elevation(world.get_elevation(Vector2i(64, 64))), "partial corner elevation generated")
	_expect_equal(world.get_terrain(Vector2i(65, 64)), TerrainTypes.INVALID, "partial padded terrain inaccessible")
	_expect_equal(world.get_elevation(Vector2i(64, 65)), WorldChunkData.INVALID_ELEVATION, "partial padded elevation inaccessible")
	_expect_equal(world.get_chunk_world_rect(Vector2i.ONE), Rect2i(Vector2i(64, 64), Vector2i.ONE), "partial corner rect remains clipped")


func _test_chunk_partition_independence() -> void:
	var chunks_of_eight := _generate_world(Vector2i(32, 32), 8, TEST_SEED)
	var chunks_of_sixteen := _generate_world(Vector2i(32, 32), 16, TEST_SEED)
	_expect_equal(WorldFingerprint.terrain(chunks_of_eight), WorldFingerprint.terrain(chunks_of_sixteen), "terrain ignores chunk partition")
	_expect_equal(WorldFingerprint.elevation(chunks_of_eight), WorldFingerprint.elevation(chunks_of_sixteen), "elevation ignores chunk partition")
	_expect_equal(WorldFingerprint.combined(chunks_of_eight), WorldFingerprint.combined(chunks_of_sixteen), "combined output ignores chunk partition")
	for position in [Vector2i(7, 7), Vector2i(8, 8), Vector2i(15, 15), Vector2i(16, 16)]:
		_expect_equal(chunks_of_eight.get_terrain(position), chunks_of_sixteen.get_terrain(position), "terrain has no chunk seam dependency %s" % position)
		_expect_equal(chunks_of_eight.get_elevation(position), chunks_of_sixteen.get_elevation(position), "elevation has no chunk seam dependency %s" % position)


func _test_initial_commit_contract() -> void:
	var world := WorldGrid.new(Vector2i(65, 65), 64, TerrainTypes.Id.WATER)
	WorldGenerator.new().generate_into(world, TEST_SEED)
	_expect_equal(world.get_revision(), 0, "generation does not commit or own revision")
	_expect_true(world.get_pending_terrain_chunk_count() > 0, "generation accumulates terrain invalidations")
	_expect_true(world.get_pending_elevation_chunk_count() > 0, "generation accumulates elevation invalidations")
	var initial_changes := world.commit_changes()
	_expect_equal(initial_changes.get_revision(), 1, "initial non-empty batch advances one revision")
	_expect_true(initial_changes.get_terrain_chunk_count() > 0, "initial batch carries terrain chunks")
	_expect_true(initial_changes.get_elevation_chunk_count() > 0, "initial batch carries elevation chunks")
	_expect_equal(world.get_revision(), 1, "WorldGrid owns committed revision")
	var empty_changes := world.commit_changes()
	_expect_true(empty_changes.is_empty(), "second commit is empty")
	_expect_equal(empty_changes.get_revision(), 1, "empty commit retains initial revision")


func _test_data_only_boundaries() -> void:
	var generator := WorldGenerator.new()
	_expect_true(generator is RefCounted, "generator is data-only RefCounted")
	var generator_source := FileAccess.get_file_as_string("res://scripts/generation/world_generator.gd")
	var fingerprint_source := FileAccess.get_file_as_string("res://scripts/generation/world_fingerprint.gd")
	_expect_true(generator_source.contains("extends RefCounted"), "generator source uses data-only base class")
	_expect_false(generator_source.contains("extends Node"), "generator does not require scene tree")
	_expect_false(generator_source.contains("res://scripts/presentation"), "generator has no presentation resource dependency")
	_expect_false(generator_source.contains("TerrainRenderer"), "generator does not know terrain renderer")
	_expect_false(generator_source.contains("Image"), "generator does not produce images")
	_expect_false(generator_source.contains("Color"), "generator does not produce colors")
	_expect_false(fingerprint_source.contains("res://scripts/presentation"), "fingerprint has no presentation resource dependency")


func _generate_world(world_size: Vector2i, chunk_size: int, generation_seed: int) -> WorldGrid:
	var world := WorldGrid.new(world_size, chunk_size, TerrainTypes.Id.WATER)
	WorldGenerator.new().generate_into(world, generation_seed)
	return world


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
