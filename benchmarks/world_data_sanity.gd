extends MainLoop

const WORLD_SIZE: Vector2i = Vector2i(256, 256)
const CHUNK_SIZE: int = 64
const OPERATION_COUNT: int = 100_000


func _initialize() -> void:
	var initialization_started := Time.get_ticks_usec()
	var grid := WorldGrid.new(WORLD_SIZE, CHUNK_SIZE, TerrainTypes.Id.LAND)
	var initialization_usec := Time.get_ticks_usec() - initialization_started

	var state: int = 0x5EED1234
	var checksum: int = 0
	var operations_started := Time.get_ticks_usec()
	for operation_index in range(OPERATION_COUNT):
		state = (state * 1_664_525 + 1_013_904_223) & 0xFFFFFFFF
		var x := state % WORLD_SIZE.x
		state = (state * 1_664_525 + 1_013_904_223) & 0xFFFFFFFF
		var y := state % WORLD_SIZE.y
		var terrain := TerrainTypes.Id.SAND if operation_index % 2 == 0 else TerrainTypes.Id.ROCK
		grid.set_terrain(Vector2i(x, y), terrain)
		checksum += grid.get_terrain(Vector2i(x, y))
	var operations_usec := Time.get_ticks_usec() - operations_started

	var report := {
		"world_size": [WORLD_SIZE.x, WORLD_SIZE.y],
		"chunk_size": CHUNK_SIZE,
		"chunk_count": [grid.get_chunk_count().x, grid.get_chunk_count().y],
		"cell_count": WORLD_SIZE.x * WORLD_SIZE.y,
		"set_operations": OPERATION_COUNT,
		"get_operations": OPERATION_COUNT,
		"initialization_ms": float(initialization_usec) / 1000.0,
		"operations_ms": float(operations_usec) / 1000.0,
		"checksum": checksum,
	}
	print("WORLD_DATA_SANITY %s" % JSON.stringify(report))


func _process(_delta: float) -> bool:
	return true
