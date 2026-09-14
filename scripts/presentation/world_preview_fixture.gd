class_name WorldPreviewFixture
extends RefCounted


static func apply_to(world_grid: WorldGrid) -> void:
	var world_size := world_grid.get_world_size()
	var center := Vector2(world_size) * 0.5
	var island_radius := Vector2(world_size) * Vector2(0.42, 0.4)
	var rock_radius := maxf(3.0, minf(world_size.x, world_size.y) * 0.055)
	var rock_centers: Array[Vector2] = [
		Vector2(world_size) * Vector2(0.38, 0.43),
		Vector2(world_size) * Vector2(0.62, 0.58),
	]

	for y in range(world_size.y):
		for x in range(world_size.x):
			var world_position := Vector2i(x, y)
			var normalized := Vector2(
				(float(x) - center.x) / island_radius.x,
				(float(y) - center.y) / island_radius.y,
			)
			var distance_squared := normalized.length_squared()
			if distance_squared <= 1.0:
				world_grid.set_terrain(world_position, TerrainTypes.Id.SAND)
			if distance_squared <= 0.82:
				world_grid.set_terrain(world_position, TerrainTypes.Id.LAND)
			if distance_squared <= 0.72 and _is_inside_rock_patch(Vector2(world_position), rock_centers, rock_radius):
				world_grid.set_terrain(world_position, TerrainTypes.Id.ROCK)


static func _is_inside_rock_patch(position: Vector2, centers: Array[Vector2], radius: float) -> bool:
	var radius_squared := radius * radius
	for center: Vector2 in centers:
		if position.distance_squared_to(center) <= radius_squared:
			return true
	return false
