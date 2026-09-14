extends Node

@onready var _terrain_renderer: TerrainRenderer = $World/TerrainRenderer
@onready var _world_inspector: WorldInspector = $DebugUI/WorldInspector

var _world_grid: WorldGrid


func _ready() -> void:
	_world_grid = WorldGrid.new(
		WorldGrid.DEFAULT_WORLD_SIZE,
		WorldGrid.DEFAULT_CHUNK_SIZE,
		TerrainTypes.Id.WATER,
	)
	WorldPreviewFixture.apply_to(_world_grid)
	_terrain_renderer.set_world_grid(_world_grid)
	_terrain_renderer.rebuild_all()
	_world_grid.clear_dirty_chunks()
	_world_inspector.configure(_world_grid, _terrain_renderer)
	print(
		"Semarel terrain preview ready: %d chunk visuals"
		% _terrain_renderer.get_chunk_visual_count(),
	)
