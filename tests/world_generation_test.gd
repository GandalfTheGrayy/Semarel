extends MainLoop

const TEST_SEED: int = 12_345
const GOLDEN_TERRAIN_FINGERPRINT_V2: int = 823_958_333
const GOLDEN_ELEVATION_FINGERPRINT_V2: int = 1_193_244_069
const GOLDEN_COMBINED_FINGERPRINT_V2: int = 3_136_019

var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	_test_seed_contract_and_fingerprints()
	_test_v2_golden_fingerprint()
	_test_coherent_height_field()
	_test_v2_terrain_elevation_relation()
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

	_expect_equal(WorldGenerator.GENERATOR_VERSION, 2, "coherent prototype uses generator version two")
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


func _test_v2_golden_fingerprint() -> void:
	var world := _generate_world(Vector2i(64, 64), 16, TEST_SEED)
	_expect_equal(
		WorldFingerprint.terrain(world),
		GOLDEN_TERRAIN_FINGERPRINT_V2,
		"version two golden terrain fingerprint",
	)
	_expect_equal(
		WorldFingerprint.elevation(world),
		GOLDEN_ELEVATION_FINGERPRINT_V2,
		"version two golden elevation fingerprint",
	)
	_expect_equal(
		WorldFingerprint.combined(world),
		GOLDEN_COMBINED_FINGERPRINT_V2,
		"version two golden combined fingerprint",
	)


func _test_coherent_height_field() -> void:
	var world_size := Vector2i(64, 64)
	var world := _generate_world(world_size, 16, TEST_SEED)
	var total_neighbor_difference: int = 0
	var neighbor_pair_count: int = 0
	var close_neighbor_count: int = 0
	var minimum_elevation := WorldChunkData.MAX_ELEVATION
	var maximum_elevation := WorldChunkData.MIN_ELEVATION
	for world_y in range(world_size.y):
		for world_x in range(world_size.x):
			var position := Vector2i(world_x, world_y)
			var elevation := world.get_elevation(position)
			minimum_elevation = mini(minimum_elevation, elevation)
			maximum_elevation = maxi(maximum_elevation, elevation)
			if world_x + 1 < world_size.x:
				var horizontal_difference := absi(elevation - world.get_elevation(position + Vector2i.RIGHT))
				total_neighbor_difference += horizontal_difference
				neighbor_pair_count += 1
				if horizontal_difference <= 12:
					close_neighbor_count += 1
			if world_y + 1 < world_size.y:
				var vertical_difference := absi(elevation - world.get_elevation(position + Vector2i.DOWN))
				total_neighbor_difference += vertical_difference
				neighbor_pair_count += 1
				if vertical_difference <= 12:
					close_neighbor_count += 1
	var average_difference := float(total_neighbor_difference) / neighbor_pair_count
	var close_neighbor_ratio := float(close_neighbor_count) / neighbor_pair_count
	_expect_true(average_difference < 8.0, "neighbor elevation differences are broadly smooth")
	_expect_true(close_neighbor_ratio > 0.9, "most neighboring elevations remain close")
	_expect_true(maximum_elevation - minimum_elevation > 80, "coherent field retains broad height variation")
	_expect_equal(world.get_terrain(Vector2i.ZERO), TerrainTypes.Id.WATER, "top-left edge falls to water")
	_expect_equal(world.get_terrain(Vector2i(63, 63)), TerrainTypes.Id.WATER, "bottom-right edge falls to water")
	var generator_source := FileAccess.get_file_as_string("res://scripts/generation/world_generator.gd")
	_expect_false(generator_source.contains("_PROTOTYPE_REGION_SIZE"), "version one hard-region dependency is removed")


func _test_v2_terrain_elevation_relation() -> void:
	var world_size := Vector2i(128, 128)
	var world := _generate_world(world_size, 16, TEST_SEED)
	var categories_seen := PackedByteArray()
	categories_seen.resize(TerrainTypes.Id.size())
	var relation_is_valid := true
	for world_y in range(world_size.y):
		for world_x in range(world_size.x):
			var position := Vector2i(world_x, world_y)
			var elevation := world.get_elevation(position)
			var terrain := world.get_terrain(position)
			categories_seen[terrain] = 1
			match terrain:
				TerrainTypes.Id.WATER:
					relation_is_valid = relation_is_valid and elevation <= WorldGenerator.V2_WATER_MAX_ELEVATION
				TerrainTypes.Id.SAND:
					relation_is_valid = (
						relation_is_valid
						and elevation > WorldGenerator.V2_WATER_MAX_ELEVATION
						and elevation <= WorldGenerator.V2_SAND_MAX_ELEVATION
					)
				TerrainTypes.Id.LAND:
					relation_is_valid = (
						relation_is_valid
						and elevation > WorldGenerator.V2_SAND_MAX_ELEVATION
						and elevation < WorldGenerator.V2_ROCK_MIN_ELEVATION
					)
				TerrainTypes.Id.ROCK:
					relation_is_valid = relation_is_valid and elevation >= WorldGenerator.V2_ROCK_MIN_ELEVATION
	_expect_true(relation_is_valid, "terrain categories follow the version two height contract")
	for terrain in range(TerrainTypes.Id.size()):
		_expect_equal(categories_seen[terrain], 1, "representative coherent world contains terrain %d" % terrain)


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
	var chunks_of_sixty_four := _generate_world(Vector2i(32, 32), 64, TEST_SEED)
	_expect_equal(WorldFingerprint.terrain(chunks_of_eight), WorldFingerprint.terrain(chunks_of_sixteen), "terrain ignores chunk partition")
	_expect_equal(WorldFingerprint.elevation(chunks_of_eight), WorldFingerprint.elevation(chunks_of_sixteen), "elevation ignores chunk partition")
	_expect_equal(WorldFingerprint.combined(chunks_of_eight), WorldFingerprint.combined(chunks_of_sixteen), "combined output ignores chunk partition")
	_expect_equal(WorldFingerprint.combined(chunks_of_eight), WorldFingerprint.combined(chunks_of_sixty_four), "chunk size sixty-four preserves logical output")
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
