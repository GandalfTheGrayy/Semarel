class_name TerrainPalette
extends RefCounted

const INVALID_COLOR: Color = Color(1.0, 0.0, 1.0, 1.0)


static func has_color(terrain: int) -> bool:
	return TerrainTypes.is_valid(terrain)


static func get_color(terrain: int) -> Color:
	match terrain:
		TerrainTypes.Id.WATER:
			return Color8(45, 113, 179)
		TerrainTypes.Id.LAND:
			return Color8(79, 148, 87)
		TerrainTypes.Id.SAND:
			return Color8(224, 199, 123)
		TerrainTypes.Id.ROCK:
			return Color8(112, 118, 125)
		_:
			return INVALID_COLOR


static func get_terrain_name(terrain: int) -> String:
	match terrain:
		TerrainTypes.Id.WATER:
			return "WATER"
		TerrainTypes.Id.LAND:
			return "LAND"
		TerrainTypes.Id.SAND:
			return "SAND"
		TerrainTypes.Id.ROCK:
			return "ROCK"
		_:
			return "INVALID"
