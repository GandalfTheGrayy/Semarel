extends MainLoop

var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	_test_rasterization()
	_test_partial_edge_and_alignment()
	_test_overlay_lifecycle_and_authority()
	_test_category_specific_incremental_refresh()
	_test_fixture_and_inspector()
	if _failures == 0:
		print("ELEVATION_VISUALIZATION_TESTS_PASSED assertions=%d" % _assertions)
	else:
		printerr(
			"ELEVATION_VISUALIZATION_TESTS_FAILED failures=%d assertions=%d"
			% [_failures, _assertions],
		)
		assert(false, "Elevation visualization test suite failed")


func _process(_delta: float) -> bool:
	return true


func _test_rasterization() -> void:
	var snapshot := PackedByteArray([0, 128, 255, 64])
	var image := ElevationRasterizer.rasterize(snapshot, 2, Vector2i(2, 2))
	_expect_equal(image.get_size(), Vector2i(2, 2), "elevation image dimensions")
	_expect_color(image.get_pixel(0, 0), Color8(0, 0, 0), "zero elevation is black")
	_expect_color(image.get_pixel(1, 0), Color8(128, 128, 128), "middle elevation is deterministic gray")
	_expect_color(image.get_pixel(0, 1), Color8(255, 255, 255), "maximum elevation is white")
	_expect_color(image.get_pixel(1, 1), Color8(64, 64, 64), "second intermediate value is deterministic")


func _test_partial_edge_and_alignment() -> void:
	var grid := WorldGrid.new(Vector2i(65, 65), 64, TerrainTypes.Id.WATER)
	grid.set_elevation(Vector2i(64, 64), 255)
	grid.commit_changes()
	var terrain_renderer := TerrainRenderer.new()
	var elevation_renderer := ElevationOverlayRenderer.new()
	terrain_renderer.set_world_grid(grid)
	elevation_renderer.set_world_grid(grid)
	terrain_renderer.rebuild_all()
	elevation_renderer.rebuild_all()

	_expect_equal(terrain_renderer.get_chunk_visual_count(), 4, "partial terrain visual count")
	_expect_equal(elevation_renderer.get_chunk_visual_count(), 4, "partial elevation visual count")
	_expect_equal(elevation_renderer.get_child_count(), 4, "overlay node count follows chunks")
	_expect_equal(elevation_renderer.get_chunk_image(Vector2i(1, 0)).get_size(), Vector2i(1, 64), "right edge clipped")
	_expect_equal(elevation_renderer.get_chunk_image(Vector2i(0, 1)).get_size(), Vector2i(64, 1), "bottom edge clipped")
	_expect_equal(elevation_renderer.get_chunk_image(Vector2i.ONE).get_size(), Vector2i.ONE, "corner edge clipped")
	_expect_color(elevation_renderer.get_chunk_image(Vector2i.ONE).get_pixel(0, 0), Color8(255, 255, 255), "corner elevation pixel")

	var terrain_corner := terrain_renderer.get_node("Chunk_1_1") as Sprite2D
	var elevation_corner := elevation_renderer.get_node("Chunk_1_1") as Sprite2D
	_expect_equal(elevation_corner.position, terrain_corner.position, "overlay and terrain chunk positions align")
	_expect_equal(elevation_corner.scale, terrain_corner.scale, "overlay and terrain scales align")
	_expect_equal(elevation_corner.position, Vector2(128, 128), "partial corner uses shared display scale")
	_expect_true(elevation_renderer.z_index > terrain_renderer.z_index, "elevation overlay draws above terrain")
	_expect_equal(elevation_corner.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "overlay uses nearest filtering")

	var copied_snapshot := grid.get_chunk_elevation_copy(Vector2i.ONE)
	copied_snapshot[0] = 0
	_expect_equal(grid.get_elevation(Vector2i(64, 64)), 255, "copied snapshot cannot mutate elevation")
	terrain_renderer.free()
	elevation_renderer.free()


func _test_overlay_lifecycle_and_authority() -> void:
	var grid := WorldGrid.new(Vector2i(4, 4), 2, TerrainTypes.Id.LAND)
	grid.set_elevation(Vector2i(3, 3), 87)
	grid.commit_changes()
	var renderer := ElevationOverlayRenderer.new()
	renderer.set_world_grid(grid)
	_expect_false(renderer.is_overlay_visible(), "overlay starts hidden")
	_expect_true(
		is_equal_approx(renderer.modulate.a, WorldPresentationConfig.ELEVATION_OVERLAY_OPACITY),
		"overlay opacity is presentation configuration",
	)
	renderer.set_overlay_visible(true)
	_expect_true(renderer.is_overlay_visible(), "overlay can be shown")
	renderer.set_overlay_visible(false)
	_expect_false(renderer.is_overlay_visible(), "overlay can be hidden")

	renderer.rebuild_all()
	_expect_equal(renderer.get_chunk_visual_count(), 4, "overlay creates one visual per chunk")
	_expect_equal(renderer.get_child_count(), 4, "overlay creates no cell nodes")
	_expect_equal(grid.get_elevation(Vector2i(3, 3)), 87, "overlay build preserves authoritative elevation")
	renderer.clear_visuals()
	_expect_equal(renderer.get_chunk_visual_count(), 0, "overlay visuals can be destroyed")
	_expect_equal(grid.get_elevation(Vector2i(3, 3)), 87, "overlay destruction preserves authoritative elevation")
	renderer.rebuild_all()
	_expect_equal(renderer.get_chunk_visual_count(), 4, "overlay rebuilds from WorldGrid")
	_expect_color(renderer.get_chunk_image(Vector2i.ONE).get_pixel(1, 1), Color8(87, 87, 87), "rebuilt overlay matches world")
	_expect_equal(grid.get_elevation(Vector2i(3, 3)), 87, "overlay rebuild remains read-only")
	renderer.free()


func _test_category_specific_incremental_refresh() -> void:
	var grid := WorldGrid.new(Vector2i(4, 2), 2, TerrainTypes.Id.WATER)
	grid.set_terrain(Vector2i.ZERO, TerrainTypes.Id.LAND)
	grid.set_elevation(Vector2i.ZERO, 32)
	grid.set_elevation(Vector2i(2, 0), 96)
	grid.commit_changes()
	var terrain_renderer := TerrainRenderer.new()
	var elevation_renderer := ElevationOverlayRenderer.new()
	terrain_renderer.set_world_grid(grid)
	elevation_renderer.set_world_grid(grid)
	terrain_renderer.rebuild_all()
	elevation_renderer.rebuild_all()

	var terrain_left_before := terrain_renderer.get_chunk_image(Vector2i.ZERO).get_data()
	var elevation_right_before := elevation_renderer.get_chunk_image(Vector2i(1, 0)).get_data()
	grid.set_elevation(Vector2i.ZERO, 200)
	var elevation_only := grid.commit_changes()
	var elevation_chunks_before := elevation_only.get_elevation_chunks()
	terrain_renderer.apply_world_changes(elevation_only)
	elevation_renderer.apply_world_changes(elevation_only)
	_expect_equal(terrain_renderer.get_chunk_refresh_count(Vector2i.ZERO), 1, "elevation-only batch skips terrain refresh")
	_expect_equal(elevation_renderer.get_chunk_refresh_count(Vector2i.ZERO), 2, "elevation-only batch refreshes elevation chunk")
	_expect_equal(elevation_renderer.get_chunk_refresh_count(Vector2i(1, 0)), 1, "elevation-only batch leaves other overlay chunk")
	_expect_equal(terrain_renderer.get_chunk_image(Vector2i.ZERO).get_data(), terrain_left_before, "elevation-only batch preserves terrain image")
	_expect_color(elevation_renderer.get_chunk_image(Vector2i.ZERO).get_pixel(0, 0), Color8(200, 200, 200), "elevation-only image update")
	_expect_equal(elevation_only.get_elevation_chunks(), elevation_chunks_before, "two renderers do not consume elevation metadata")
	_expect_equal(elevation_only.get_terrain_chunk_count(), 0, "elevation-only terrain category stays empty")

	var elevation_left_before := elevation_renderer.get_chunk_image(Vector2i.ZERO).get_data()
	grid.set_terrain(Vector2i(2, 0), TerrainTypes.Id.ROCK)
	var terrain_only := grid.commit_changes()
	var terrain_chunks_before := terrain_only.get_terrain_chunks()
	terrain_renderer.apply_world_changes(terrain_only)
	elevation_renderer.apply_world_changes(terrain_only)
	_expect_equal(terrain_renderer.get_chunk_refresh_count(Vector2i(1, 0)), 2, "terrain-only batch refreshes terrain chunk")
	_expect_equal(elevation_renderer.get_chunk_refresh_count(Vector2i.ZERO), 2, "terrain-only batch skips elevation refresh")
	_expect_equal(elevation_renderer.get_chunk_image(Vector2i.ZERO).get_data(), elevation_left_before, "terrain-only batch preserves elevation image")
	_expect_color(
		terrain_renderer.get_chunk_image(Vector2i(1, 0)).get_pixel(0, 0),
		TerrainPalette.get_color(TerrainTypes.Id.ROCK),
		"terrain-only image update",
	)
	_expect_equal(terrain_only.get_terrain_chunks(), terrain_chunks_before, "two renderers do not consume terrain metadata")
	_expect_equal(terrain_only.get_elevation_chunk_count(), 0, "terrain-only elevation category stays empty")

	grid.set_terrain(Vector2i.ZERO, TerrainTypes.Id.ROCK)
	grid.set_elevation(Vector2i(2, 0), 255)
	var mixed := grid.commit_changes()
	var mixed_terrain_before := mixed.get_terrain_chunks()
	var mixed_elevation_before := mixed.get_elevation_chunks()
	terrain_renderer.apply_world_changes(mixed)
	elevation_renderer.apply_world_changes(mixed)
	_expect_equal(terrain_renderer.get_chunk_refresh_count(Vector2i.ZERO), 2, "mixed batch refreshes listed terrain chunk")
	_expect_equal(elevation_renderer.get_chunk_refresh_count(Vector2i(1, 0)), 2, "mixed batch refreshes listed elevation chunk")
	_expect_color(
		terrain_renderer.get_chunk_image(Vector2i.ZERO).get_pixel(0, 0),
		TerrainPalette.get_color(TerrainTypes.Id.ROCK),
		"mixed terrain result",
	)
	_expect_color(elevation_renderer.get_chunk_image(Vector2i(1, 0)).get_pixel(0, 0), Color8(255, 255, 255), "mixed elevation result")
	_expect_equal(mixed.get_terrain_chunks(), mixed_terrain_before, "mixed terrain metadata remains stable")
	_expect_equal(mixed.get_elevation_chunks(), mixed_elevation_before, "mixed elevation metadata remains stable")
	_expect_equal(terrain_renderer.get_last_applied_revision(), mixed.get_revision(), "terrain renderer observes mixed revision")
	_expect_equal(elevation_renderer.get_last_applied_revision(), mixed.get_revision(), "elevation renderer observes mixed revision")
	_expect_equal(elevation_renderer.get_chunk_image(Vector2i(1, 0)).get_data() == elevation_right_before, false, "changed elevation image differs from initial")
	terrain_renderer.free()
	elevation_renderer.free()


func _test_fixture_and_inspector() -> void:
	var grid := WorldGrid.new(Vector2i(8, 8), 4, TerrainTypes.Id.WATER)
	WorldPreviewFixture.apply_to(grid)
	_expect_equal(grid.get_elevation(Vector2i.ZERO), 0, "fixture gradient starts at zero")
	_expect_equal(grid.get_elevation(Vector2i(7, 7)), 255, "fixture gradient reaches byte maximum")
	var initial_change_set := grid.commit_changes()
	_expect_true(initial_change_set.get_terrain_chunk_count() > 0, "fixture initializes terrain")
	_expect_equal(initial_change_set.get_elevation_chunk_count(), 4, "fixture initializes all elevation chunks")
	_expect_false(initial_change_set.is_empty(), "fixture creates mixed initial change set")

	var inspection := WorldInspector.build_inspection_text(grid, Vector2i(7, 7))
	_expect_true(inspection.contains("terrain:"), "inspector retains terrain")
	_expect_true(inspection.contains("elevation: 255"), "inspector reports unitless elevation")
	_expect_false(inspection.contains("255 m"), "inspector adds no physical unit")
	_expect_true(
		WorldInspector.build_inspection_text(grid, Vector2i(-1, 0)).contains("outside world"),
		"inspector outside-world behavior remains",
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
