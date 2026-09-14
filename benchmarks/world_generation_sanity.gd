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
	print("WORLD_GENERATION_SANITY")
	print("world_size=%s chunk_size=%d seed=%d version=%d" % [world.get_world_size(), world.get_chunk_size(), SANITY_SEED, WorldGenerator.GENERATOR_VERSION])
	print("generation_ms=%.3f" % (generation_usec / 1000.0))
	print("terrain_fingerprint=%d" % WorldFingerprint.terrain(world))
	print("elevation_fingerprint=%d" % WorldFingerprint.elevation(world))
	print("combined_fingerprint=%d" % WorldFingerprint.combined(world))
	print("initial_revision=%d terrain_chunks=%d elevation_chunks=%d" % [initial_changes.get_revision(), initial_changes.get_terrain_chunk_count(), initial_changes.get_elevation_chunk_count()])


func _process(_delta: float) -> bool:
	return true
