extends MainLoop

var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	_test_palette_contract()
	_test_rasterizer_pixels_and_fallback()
	_test_partial_edge_rasterization()
	_test_renderer_rebuild_and_incremental_refresh()
	_test_inspector_text()
	if _failures == 0:
		print("TERRAIN_VISUALIZATION_TESTS_PASSED assertions=%d" % _assertions)
	else:
		printerr(
			"TERRAIN_VISUALIZATION_TESTS_FAILED failures=%d assertions=%d"
			% [_failures, _assertions],
		)
		assert(false, "Terrain visualization test suite failed")


func _process(_delta: float) -> bool:
	return true


func _test_palette_contract() -> void:
	for terrain in range(TerrainTypes.Id.size()):
		_expect_true(TerrainPalette.has_color(terrain), "palette entry exists for terrain %d" % terrain)
		_expect_false(
			TerrainPalette.get_color(terrain).is_equal_approx(TerrainPalette.INVALID_COLOR),
			"valid terrain does not use fallback color %d" % terrain,
		)
	_expect_false(TerrainPalette.has_color(255), "invalid terrain has no palette entry")
	_expect_color(TerrainPalette.get_color(255), TerrainPalette.INVALID_COLOR, "invalid terrain fallback color")
	_expect_equal(TerrainPalette.get_terrain_name(255), "INVALID", "invalid terrain fallback name")


func _test_rasterizer_pixels_and_fallback() -> void:
	var snapshot := PackedByteArray([
		TerrainTypes.Id.WATER,
		TerrainTypes.Id.LAND,
		TerrainTypes.Id.SAND,
		TerrainTypes.Id.ROCK,
	])
	var image := TerrainRasterizer.rasterize(snapshot, 2, Vector2i(2, 2))
	_expect_equal(image.get_size(), Vector2i(2, 2), "rasterized image size")
	_expect_color(image.get_pixel(0, 0), TerrainPalette.get_color(TerrainTypes.Id.WATER), "water pixel")
	_expect_color(image.get_pixel(1, 0), TerrainPalette.get_color(TerrainTypes.Id.LAND), "land pixel")
	_expect_color(image.get_pixel(0, 1), TerrainPalette.get_color(TerrainTypes.Id.SAND), "sand pixel")
	_expect_color(image.get_pixel(1, 1), TerrainPalette.get_color(TerrainTypes.Id.ROCK), "rock pixel")

	var invalid_image := TerrainRasterizer.rasterize(PackedByteArray([255]), 1, Vector2i.ONE)
	_expect_color(invalid_image.get_pixel(0, 0), TerrainPalette.INVALID_COLOR, "invalid ID raster fallback")


func _test_partial_edge_rasterization() -> void:
	var grid := WorldGrid.new(Vector2i(65, 65), 64, TerrainTypes.Id.WATER)
	grid.set_terrain(Vector2i(64, 64), TerrainTypes.Id.ROCK)
	var corner_chunk := Vector2i.ONE
	var world_rect := grid.get_chunk_world_rect(corner_chunk)
	var snapshot := grid.get_chunk_terrain_copy(corner_chunk)
	var image := TerrainRasterizer.rasterize(snapshot, grid.get_chunk_size(), world_rect.size)
	_expect_equal(world_rect, Rect2i(Vector2i(64, 64), Vector2i.ONE), "partial corner world rect")
	_expect_equal(image.get_size(), Vector2i.ONE, "partial corner image excludes padded cells")
	_expect_color(image.get_pixel(0, 0), TerrainPalette.get_color(TerrainTypes.Id.ROCK), "partial corner pixel")

	snapshot[0] = TerrainTypes.Id.SAND
	_expect_equal(grid.get_terrain(Vector2i(64, 64)), TerrainTypes.Id.ROCK, "raster snapshot cannot mutate world")


func _test_renderer_rebuild_and_incremental_refresh() -> void:
	var grid := WorldGrid.new(Vector2i(3, 3), 2, TerrainTypes.Id.WATER)
	grid.set_terrain(Vector2i.ZERO, TerrainTypes.Id.LAND)
	grid.commit_changes()
	var renderer := TerrainRenderer.new()
	renderer.set_world_grid(grid)
	renderer.rebuild_all()

	_expect_equal(renderer.get_chunk_visual_count(), 4, "visual count follows chunk count")
	_expect_equal(renderer.get_child_count(), 4, "renderer creates no cell-level nodes")
	_expect_equal(renderer.get_chunk_image(Vector2i.ONE).get_size(), Vector2i.ONE, "partial renderer image size")
	_expect_equal(renderer.display_to_world_cell(Vector2(4.0, 2.0)), Vector2i(2, 1), "display scale mapping")
	_expect_equal(renderer.display_to_world_cell(Vector2(-0.1, 0.0)), Vector2i(-1, 0), "negative display mapping")
	_expect_color(
		renderer.get_chunk_image(Vector2i.ZERO).get_pixel(0, 0),
		TerrainPalette.get_color(TerrainTypes.Id.LAND),
		"renderer reads authoritative terrain",
	)
	_expect_equal(grid.get_terrain(Vector2i.ZERO), TerrainTypes.Id.LAND, "full rebuild does not mutate world")

	renderer.clear_visuals()
	_expect_equal(renderer.get_chunk_visual_count(), 0, "presentation can be destroyed")
	_expect_equal(grid.get_terrain(Vector2i.ZERO), TerrainTypes.Id.LAND, "destroying presentation preserves world")
	renderer.rebuild_all()
	_expect_equal(renderer.get_chunk_visual_count(), 4, "presentation rebuilds from world")
	_expect_color(
		renderer.get_chunk_image(Vector2i.ZERO).get_pixel(0, 0),
		TerrainPalette.get_color(TerrainTypes.Id.LAND),
		"rebuilt presentation matches authoritative terrain",
	)

	grid.set_terrain(Vector2i(2, 0), TerrainTypes.Id.ROCK)
	var refreshed_sprite := renderer.get_node("Chunk_1_0") as Sprite2D
	var texture_instance_id := refreshed_sprite.texture.get_instance_id()
	var change_set := grid.commit_changes()
	renderer.apply_world_changes(change_set)
	_expect_equal(
		refreshed_sprite.texture.get_instance_id(),
		texture_instance_id,
		"same-size incremental refresh reuses texture",
	)
	_expect_equal(change_set.get_terrain_chunk_count(), 1, "renderer leaves change-set metadata intact")
	_expect_equal(change_set.get_terrain_chunks(), [Vector2i(1, 0)], "renderer does not consume change set")
	_expect_color(
		renderer.get_chunk_image(Vector2i(1, 0)).get_pixel(0, 0),
		TerrainPalette.get_color(TerrainTypes.Id.ROCK),
		"incremental refresh updates selected chunk",
	)
	renderer.free()


func _test_inspector_text() -> void:
	var grid := WorldGrid.new(Vector2i(4, 4), 2, TerrainTypes.Id.LAND)
	var inside_text := WorldInspector.build_inspection_text(grid, Vector2i(3, 2))
	_expect_true(inside_text.contains("world cell: (3, 2)"), "inspector world coordinate")
	_expect_true(inside_text.contains("chunk: (1, 1)"), "inspector chunk coordinate")
	_expect_true(inside_text.contains("local: (1, 0)"), "inspector local coordinate")
	_expect_true(inside_text.contains("terrain: LAND"), "inspector terrain name")
	_expect_true(inside_text.contains("terrain id: 1"), "inspector terrain ID")
	_expect_true(
		WorldInspector.build_inspection_text(grid, Vector2i(-1, 0)).contains("outside world"),
		"inspector outside-world state",
	)


func _expect_true(value: bool, label: String) -> void:
	_assertions += 1
	if not value:
		_failures += 1
		printerr("FAIL: %s" % label)


func _expect_false(value: bool, label: String) -> void:
	_expect_true(not value, label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures += 1
		printerr("FAIL: %s | expected=%s actual=%s" % [label, expected, actual])


func _expect_color(actual: Color, expected: Color, label: String) -> void:
	_assertions += 1
	if not actual.is_equal_approx(expected):
		_failures += 1
		printerr("FAIL: %s | expected=%s actual=%s" % [label, expected, actual])
