class_name WorldGenerator
extends RefCounted

const GENERATOR_VERSION: int = 2
const V2_WATER_MAX_ELEVATION: int = 88
const V2_SAND_MAX_ELEVATION: int = 101
const V2_ROCK_MIN_ELEVATION: int = 176

const _BASE_FREQUENCY: float = 0.012
const _FRACTAL_OCTAVES: int = 3
const _EDGE_FALLOFF_START: float = 0.62
const _EDGE_FALLOFF_END: float = 1.02
const _EDGE_FALLOFF_STRENGTH: float = 0.52
const _CENTER_HEIGHT: float = 0.60
const _NOISE_STRENGTH: float = 0.34


func generate_into(world_grid: WorldGrid, seed: int) -> void:
	assert(world_grid != null, "WorldGenerator requires a WorldGrid target")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var height_noise := _create_height_noise(rng.randi_range(-2_147_483_647, 2_147_483_647))
	var world_size := world_grid.get_world_size()

	for world_y in range(world_size.y):
		for world_x in range(world_size.x):
			var world_position := Vector2i(world_x, world_y)
			var relative_height := _sample_base_height(world_position, world_size, height_noise)
			var elevation := roundi(relative_height * WorldChunkData.MAX_ELEVATION)
			world_grid.set_elevation(world_position, elevation)
			world_grid.set_terrain(world_position, _classify_terrain(elevation))


func _create_height_noise(noise_seed: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = _BASE_FREQUENCY
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = _FRACTAL_OCTAVES
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	return noise


func _sample_base_height(
	world_position: Vector2i,
	world_size: Vector2i,
	height_noise: FastNoiseLite,
) -> float:
	var noise_value := height_noise.get_noise_2d(world_position.x, world_position.y)
	var centered_position := (
		(Vector2(world_position) + Vector2(0.5, 0.5)) / Vector2(world_size) * 2.0
		- Vector2.ONE
	)
	var distance_from_center := centered_position.length()
	var edge_falloff := smoothstep(
		_EDGE_FALLOFF_START,
		_EDGE_FALLOFF_END,
		distance_from_center,
	)
	return clampf(
		_CENTER_HEIGHT + noise_value * _NOISE_STRENGTH - edge_falloff * _EDGE_FALLOFF_STRENGTH,
		0.0,
		1.0,
	)


func _classify_terrain(elevation: int) -> int:
	if elevation <= V2_WATER_MAX_ELEVATION:
		return TerrainTypes.Id.WATER
	if elevation <= V2_SAND_MAX_ELEVATION:
		return TerrainTypes.Id.SAND
	if elevation >= V2_ROCK_MIN_ELEVATION:
		return TerrainTypes.Id.ROCK
	return TerrainTypes.Id.LAND
