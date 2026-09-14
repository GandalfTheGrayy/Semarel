extends Node

@onready var _terrain_renderer: TerrainRenderer = $World/TerrainRenderer
@onready var _elevation_overlay: ElevationOverlayRenderer = $World/ElevationOverlayRenderer
@onready var _world_inspector: WorldInspector = $DebugUI/WorldInspector
@onready var _change_summary: Label = $DebugUI/ChangeSummary

var _world_grid: WorldGrid
var _debug_probe_step: int = 0
var _last_change_set: WorldChangeSet


func _ready() -> void:
	_world_grid = WorldGrid.new(
		WorldGrid.DEFAULT_WORLD_SIZE,
		WorldGrid.DEFAULT_CHUNK_SIZE,
		TerrainTypes.Id.WATER,
	)
	WorldPreviewFixture.apply_to(_world_grid)
	var initial_change_set := _world_grid.commit_changes()
	_terrain_renderer.set_world_grid(_world_grid)
	_terrain_renderer.rebuild_all()
	_elevation_overlay.set_world_grid(_world_grid)
	_elevation_overlay.rebuild_all()
	_world_inspector.configure(_world_grid, _terrain_renderer)
	_last_change_set = initial_change_set
	_update_change_summary(initial_change_set)
	print(
		"Semarel preview ready: %d terrain + %d elevation chunk visuals"
		% [_terrain_renderer.get_chunk_visual_count(), _elevation_overlay.get_chunk_visual_count()],
	)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE:
			_apply_debug_world_change_probe()
		KEY_E:
			_elevation_overlay.set_overlay_visible(not _elevation_overlay.is_overlay_visible())
			_update_change_summary(_last_change_set)


func _apply_debug_world_change_probe() -> void:
	var terrain := TerrainTypes.Id.ROCK if _debug_probe_step % 2 == 0 else TerrainTypes.Id.SAND
	var boundary := _world_grid.get_chunk_size()
	var probe_cells: Array[Vector2i] = [
		Vector2i(boundary - 1, boundary - 1),
		Vector2i(boundary, boundary - 1),
		Vector2i(boundary - 1, boundary),
		Vector2i(boundary, boundary),
	]
	for world_cell in probe_cells:
		_world_grid.set_terrain(world_cell, terrain)

	var change_set := _world_grid.commit_changes()
	_dispatch_world_changes(change_set)
	_debug_probe_step += 1


func _dispatch_world_changes(change_set: WorldChangeSet) -> void:
	_terrain_renderer.apply_world_changes(change_set)
	_elevation_overlay.apply_world_changes(change_set)
	_last_change_set = change_set
	_update_change_summary(change_set)


func _update_change_summary(change_set: WorldChangeSet) -> void:
	var overlay_state := "on" if _elevation_overlay.is_overlay_visible() else "off"
	_change_summary.text = (
		"SPACE: apply debug change batch\n"
		+ "E: elevation overlay (%s)\n" % overlay_state
		+ "world revision: %d\n" % _world_grid.get_revision()
		+ "last change-set revision: %d\n" % change_set.get_revision()
		+ "last changed terrain chunks: %d\n" % change_set.get_terrain_chunk_count()
		+ "last changed elevation chunks: %d" % change_set.get_elevation_chunk_count()
	)
