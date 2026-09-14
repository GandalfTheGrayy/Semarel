class_name ElevationOverlayRenderer
extends Node2D

var _world_grid: WorldGrid
var _chunk_sprites: Dictionary = {}
var _chunk_images: Dictionary = {}
var _chunk_refresh_counts: Dictionary = {}
var _last_applied_revision: int = 0


func _init() -> void:
	z_index = 1
	modulate.a = WorldPresentationConfig.ELEVATION_OVERLAY_OPACITY
	visible = false


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


func apply_world_changes(change_set: WorldChangeSet) -> void:
	_refresh_chunks(change_set.get_elevation_chunks())
	_last_applied_revision = change_set.get_revision()


func clear_visuals() -> void:
	for sprite_value: Variant in _chunk_sprites.values():
		var sprite := sprite_value as Sprite2D
		if sprite != null:
			sprite.free()
	_chunk_sprites.clear()
	_chunk_images.clear()
	_chunk_refresh_counts.clear()


func set_overlay_visible(overlay_visible: bool) -> void:
	visible = overlay_visible


func is_overlay_visible() -> bool:
	return visible


func get_chunk_visual_count() -> int:
	return _chunk_sprites.size()


func get_last_applied_revision() -> int:
	return _last_applied_revision


func get_chunk_refresh_count(chunk_position: Vector2i) -> int:
	return int(_chunk_refresh_counts.get(chunk_position, 0))


func get_chunk_image(chunk_position: Vector2i) -> Image:
	var image := _chunk_images.get(chunk_position) as Image
	if image == null:
		return null
	return image.duplicate()


func _refresh_chunks(changed_chunks: Array[Vector2i]) -> void:
	if _world_grid == null:
		return
	for chunk_position: Vector2i in changed_chunks:
		if _world_grid.is_valid_chunk_position(chunk_position):
			_refresh_chunk(chunk_position)


func _refresh_chunk(chunk_position: Vector2i) -> void:
	var world_rect := _world_grid.get_chunk_world_rect(chunk_position)
	var elevation_snapshot := _world_grid.get_chunk_elevation_copy(chunk_position)
	var image := ElevationRasterizer.rasterize(
		elevation_snapshot,
		_world_grid.get_chunk_size(),
		world_rect.size,
	)
	_chunk_images[chunk_position] = image
	_chunk_refresh_counts[chunk_position] = get_chunk_refresh_count(chunk_position) + 1

	var sprite := _chunk_sprites.get(chunk_position) as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Chunk_%d_%d" % [chunk_position.x, chunk_position.y]
		sprite.centered = false
		sprite.position = Vector2(world_rect.position) * WorldPresentationConfig.CELL_DISPLAY_SCALE
		sprite.scale = Vector2.ONE * WorldPresentationConfig.CELL_DISPLAY_SCALE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		_chunk_sprites[chunk_position] = sprite

	var texture := sprite.texture as ImageTexture
	if texture != null and texture.get_width() == image.get_width() and texture.get_height() == image.get_height():
		texture.update(image)
	else:
		sprite.texture = ImageTexture.create_from_image(image)
