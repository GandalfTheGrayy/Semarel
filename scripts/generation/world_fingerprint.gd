class_name WorldFingerprint
extends RefCounted

const _HASH_MASK: int = 0x7fffffff
const _HASH_PRIME: int = 16_777_619
const _HASH_OFFSET: int = 2_166_136_261


static func terrain(world_grid: WorldGrid) -> int:
	var fingerprint := _start(world_grid)
	var world_size := world_grid.get_world_size()
	for world_y in range(world_size.y):
		for world_x in range(world_size.x):
			fingerprint = _append(fingerprint, world_grid.get_terrain(Vector2i(world_x, world_y)))
	return fingerprint


static func elevation(world_grid: WorldGrid) -> int:
	var fingerprint := _start(world_grid)
	var world_size := world_grid.get_world_size()
	for world_y in range(world_size.y):
		for world_x in range(world_size.x):
			fingerprint = _append(fingerprint, world_grid.get_elevation(Vector2i(world_x, world_y)))
	return fingerprint


static func combined(world_grid: WorldGrid) -> int:
	var fingerprint := _start(world_grid)
	var world_size := world_grid.get_world_size()
	for world_y in range(world_size.y):
		for world_x in range(world_size.x):
			var world_position := Vector2i(world_x, world_y)
			fingerprint = _append(fingerprint, world_grid.get_terrain(world_position))
			fingerprint = _append(fingerprint, world_grid.get_elevation(world_position))
	return fingerprint


static func _start(world_grid: WorldGrid) -> int:
	var world_size := world_grid.get_world_size()
	var fingerprint := _HASH_OFFSET & _HASH_MASK
	fingerprint = _append(fingerprint, world_size.x)
	return _append(fingerprint, world_size.y)


static func _append(fingerprint: int, value: int) -> int:
	return ((fingerprint ^ value) * _HASH_PRIME) & _HASH_MASK
