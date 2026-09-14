class_name WorldInspector
extends PanelContainer

var _world_grid: WorldGrid
var _terrain_renderer: TerrainRenderer

@onready var _label: Label = $Info


func configure(world_grid: WorldGrid, terrain_renderer: TerrainRenderer) -> void:
	_world_grid = world_grid
	_terrain_renderer = terrain_renderer


func _process(_delta: float) -> void:
	if _world_grid == null or _terrain_renderer == null:
		return
	var display_position := _terrain_renderer.to_local(get_viewport().get_mouse_position())
	var world_cell := _terrain_renderer.display_to_world_cell(display_position)
	inspect_world_cell(world_cell)


func inspect_world_cell(world_cell: Vector2i) -> void:
	if _world_grid == null:
		return
	_label.text = build_inspection_text(_world_grid, world_cell)


static func build_inspection_text(world_grid: WorldGrid, world_cell: Vector2i) -> String:
	if not world_grid.is_inside_world(world_cell):
		return "World Inspector\n\noutside world"
	var terrain := world_grid.get_terrain(world_cell)
	var chunk_position := world_grid.world_to_chunk(world_cell)
	var local_position := world_grid.world_to_local(world_cell)
	return (
		"World Inspector\n\n"
		+ "world cell: (%d, %d)\n" % [world_cell.x, world_cell.y]
		+ "chunk: (%d, %d)\n" % [chunk_position.x, chunk_position.y]
		+ "local: (%d, %d)\n" % [local_position.x, local_position.y]
		+ "terrain: %s\n" % TerrainPalette.get_terrain_name(terrain)
		+ "terrain id: %d" % terrain
	)
