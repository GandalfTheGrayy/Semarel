class_name TerrainRenderer
extends Node2D

const CELL_DISPLAY_SCALE: float = 2.0

var _world_grid: WorldGrid
var _chunk_sprites: Dictionary = {}
var _chunk_images: Dictionary = {}


func set_world_grid(world_grid: WorldGrid) -> void:
	_world_grid = world_grid


func rebuild_all() -> void:
	clear_visuals()
	if _world_grid == null:
		return
	var chunk_count := _world_grid.get_chunk_count()
	for chunk_y in range(chunk_count.y):
		for chunk_x in range(chunk_count.x):
			_refresh_chunk(Vector2i(chunk_x, chunk_y))


func refresh_chunks(changed_chunks: Array[Vector2i]) -> void:
	if _world_grid == null:
		return
	for chunk_position in changed_chunks:
		if _world_grid.is_valid_chunk_position(chunk_position):
			_refresh_chunk(chunk_position)


func clear_visuals() -> void:
	for sprite_value: Variant in _chunk_sprites.values():
		var sprite := sprite_value as Sprite2D
		if sprite != null:
			sprite.free()
	_chunk_sprites.clear()
	_chunk_images.clear()


func get_chunk_visual_count() -> int:
	return _chunk_sprites.size()


func get_chunk_image(chunk_position: Vector2i) -> Image:
	var image := _chunk_images.get(chunk_position) as Image
	if image == null:
		return null
	return image.duplicate()


func display_to_world_cell(local_display_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(local_display_position.x / CELL_DISPLAY_SCALE),
		floori(local_display_position.y / CELL_DISPLAY_SCALE),
	)


func _refresh_chunk(chunk_position: Vector2i) -> void:
	var world_rect := _world_grid.get_chunk_world_rect(chunk_position)
	var terrain_snapshot := _world_grid.get_chunk_terrain_copy(chunk_position)
	var image := TerrainRasterizer.rasterize(
		terrain_snapshot,
		_world_grid.get_chunk_size(),
		world_rect.size,
	)
	_chunk_images[chunk_position] = image

	var sprite := _chunk_sprites.get(chunk_position) as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Chunk_%d_%d" % [chunk_position.x, chunk_position.y]
		sprite.centered = false
		sprite.position = Vector2(world_rect.position) * CELL_DISPLAY_SCALE
		sprite.scale = Vector2.ONE * CELL_DISPLAY_SCALE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		_chunk_sprites[chunk_position] = sprite

	var texture := sprite.texture as ImageTexture
	if texture != null and texture.get_width() == image.get_width() and texture.get_height() == image.get_height():
		texture.update(image)
	else:
		sprite.texture = ImageTexture.create_from_image(image)
