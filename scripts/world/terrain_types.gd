class_name TerrainTypes
extends RefCounted

const INVALID: int = -1

enum Id {
	WATER,
	LAND,
	SAND,
	ROCK,
}


static func is_valid(terrain: int) -> bool:
	return terrain >= 0 and terrain < Id.size()
