extends MainLoop

const SANITY_SEED: int = 12_345


func _initialize() -> void:
	var started_at := Time.get_ticks_usec()
	var world := WorldGrid.new(
		WorldGrid.DEFAULT_WORLD_SIZE,
		WorldGrid.DEFAULT_CHUNK_SIZE,
		TerrainTypes.Id.WATER,
	)
	WorldGenerator.new().generate_into(world, SANITY_SEED)
	var generation_usec := Time.get_ticks_usec() - started_at
	var initial_changes := world.commit_changes()
	var terrain_counts := PackedInt32Array()
	terrain_counts.resize(TerrainTypes.Id.size())
	var world_size := world.get_world_size()
	for world_y in range(world_size.y):
		for world_x in range(world_size.x):
			terrain_counts[world.get_terrain(Vector2i(world_x, world_y))] += 1
	var cell_count := world_size.x * world_size.y
	print("WORLD_GENERATION_SANITY")
	print("world_size=%s chunk_size=%d seed=%d version=%d" % [world.get_world_size(), world.get_chunk_size(), SANITY_SEED, WorldGenerator.GENERATOR_VERSION])
	print("generation_ms=%.3f" % (generation_usec / 1000.0))
	print("terrain_fingerprint=%d" % WorldFingerprint.terrain(world))
	print("elevation_fingerprint=%d" % WorldFingerprint.elevation(world))
	print("combined_fingerprint=%d" % WorldFingerprint.combined(world))
	print(
		"terrain_distribution_percent water=%.3f sand=%.3f land=%.3f rock=%.3f"
		% [
			terrain_counts[TerrainTypes.Id.WATER] * 100.0 / cell_count,
			terrain_counts[TerrainTypes.Id.SAND] * 100.0 / cell_count,
			terrain_counts[TerrainTypes.Id.LAND] * 100.0 / cell_count,
			terrain_counts[TerrainTypes.Id.ROCK] * 100.0 / cell_count,
		],
	)
	print("initial_revision=%d terrain_chunks=%d elevation_chunks=%d" % [initial_changes.get_revision(), initial_changes.get_terrain_chunk_count(), initial_changes.get_elevation_chunk_count()])


func _process(_delta: float) -> bool:
	return true
