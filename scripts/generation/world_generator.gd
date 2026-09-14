class_name WorldGenerator
extends RefCounted

const GENERATOR_VERSION: int = 1
const _PROTOTYPE_REGION_SIZE: int = 12


func generate_into(world_grid: WorldGrid, seed: int) -> void:
	assert(world_grid != null, "WorldGenerator requires a WorldGrid target")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var terrain_salt := rng.randi()
	var elevation_salt := rng.randi()
	var world_size := world_grid.get_world_size()

	for world_y in range(world_size.y):
		for world_x in range(world_size.x):
			var world_position := Vector2i(world_x, world_y)
			world_grid.set_terrain(
				world_position,
				_generate_terrain(world_position, terrain_salt),
			)
			world_grid.set_elevation(
				world_position,
				_generate_elevation(world_position, elevation_salt),
			)


func _generate_terrain(world_position: Vector2i, salt: int) -> int:
	var region_position := Vector2i(
		world_position.x / _PROTOTYPE_REGION_SIZE,
		world_position.y / _PROTOTYPE_REGION_SIZE,
	)
	var selector := _coordinate_value(region_position, salt) % 100
	if selector < 30:
		return TerrainTypes.Id.WATER
	if selector < 70:
		return TerrainTypes.Id.LAND
	if selector < 86:
		return TerrainTypes.Id.SAND
	return TerrainTypes.Id.ROCK


func _generate_elevation(world_position: Vector2i, salt: int) -> int:
	var variation := _coordinate_value(world_position, salt)
	return (variation + world_position.x * 3 + world_position.y * 5) & 0xff


func _coordinate_value(position: Vector2i, salt: int) -> int:
	var value := (
		position.x * 374_761_393
		+ position.y * 668_265_263
		+ salt * 69_069
		+ GENERATOR_VERSION * 362_437
	) & 0x7fffffff
	value = ((value ^ (value >> 13)) * 1_274_126_177) & 0x7fffffff
	return value ^ (value >> 16)
