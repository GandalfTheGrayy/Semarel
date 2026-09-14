extends Node

@onready var _terrain_renderer: TerrainRenderer = $World/TerrainRenderer
@onready var _world_inspector: WorldInspector = $DebugUI/WorldInspector
@onready var _change_summary: Label = $DebugUI/ChangeSummary

var _world_grid: WorldGrid
var _debug_probe_step: int = 0


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
	_world_inspector.configure(_world_grid, _terrain_renderer)
	_update_change_summary(initial_change_set)
	print(
		"Semarel terrain preview ready: %d chunk visuals"
		% _terrain_renderer.get_chunk_visual_count(),
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_apply_debug_world_change_probe()


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
	_terrain_renderer.apply_world_changes(change_set)
	_update_change_summary(change_set)
	_debug_probe_step += 1


func _update_change_summary(change_set: WorldChangeSet) -> void:
	_change_summary.text = (
		"SPACE: apply debug change batch\n"
		+ "world revision: %d\n" % _world_grid.get_revision()
		+ "last change-set revision: %d\n" % change_set.get_revision()
		+ "last changed terrain chunks: %d" % change_set.get_terrain_chunk_count()
	)
