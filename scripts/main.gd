extends Node

const DEBUG_WORLD_SEED: int = 12_345
const DEBUG_ENTITY_COUNT: int = 32
const DEBUG_ENTITY_PLACEMENT_STRIDE: int = 1_973

@onready var _terrain_renderer: TerrainRenderer = $World/TerrainRenderer
@onready var _elevation_overlay: ElevationOverlayRenderer = $World/ElevationOverlayRenderer
@onready var _debug_entity_renderer: DebugEntityRenderer = $World/DebugEntityRenderer
@onready var _world_inspector: WorldInspector = $DebugUI/WorldInspector
@onready var _change_summary: Label = $DebugUI/ChangeSummary

var _world_grid: WorldGrid
var _entity_store: EntityStore
var _living_state_store: LivingStateStore
var _simulation_clock: SimulationClock
var _entity_movement: PrototypeEntityMovement
var _debug_probe_step: int = 0
var _last_change_set: WorldChangeSet
var _last_movement_tick: int = 0
var _last_moved_entity_count: int = 0


func _ready() -> void:
	_world_grid = WorldGrid.new(
		WorldGrid.DEFAULT_WORLD_SIZE,
		WorldGrid.DEFAULT_CHUNK_SIZE,
		TerrainTypes.Id.WATER,
	)
	WorldGenerator.new().generate_into(_world_grid, DEBUG_WORLD_SEED)
	var initial_change_set := _world_grid.commit_changes()
	_terrain_renderer.set_world_grid(_world_grid)
	_terrain_renderer.rebuild_all()
	_elevation_overlay.set_world_grid(_world_grid)
	_elevation_overlay.rebuild_all()
	_entity_store = EntityStore.new(_world_grid.get_world_size())
	_living_state_store = LivingStateStore.new(_entity_store)
	_populate_debug_entities()
	_debug_entity_renderer.set_entity_store(_entity_store)
	_debug_entity_renderer.refresh_from_store()
	_simulation_clock = SimulationClock.new()
	_entity_movement = PrototypeEntityMovement.new()
	_world_inspector.configure(_world_grid, _terrain_renderer)
	_last_change_set = initial_change_set
	_update_change_summary(initial_change_set)
	print(
		"Semarel preview ready: %d terrain + %d elevation chunk visuals; %d entities; %d living"
		% [
			_terrain_renderer.get_chunk_visual_count(),
			_elevation_overlay.get_chunk_visual_count(),
			_entity_store.get_entity_count(),
			_living_state_store.get_living_count(),
		],
	)


func _process(delta: float) -> void:
	if _simulation_clock == null:
		return
	_simulation_clock.add_time(delta)
	var tick_advanced := false
	var frame_moved_entity_count := 0
	while _simulation_clock.consume_tick():
		tick_advanced = true
		_last_movement_tick = _simulation_clock.get_tick_index()
		_last_moved_entity_count = _entity_movement.step(
			_world_grid,
			_entity_store,
			_living_state_store,
			_last_movement_tick,
		)
		frame_moved_entity_count += _last_moved_entity_count
	if frame_moved_entity_count > 0:
		_debug_entity_renderer.refresh_from_store()
	if tick_advanced:
		_update_change_summary(_last_change_set)


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


func _populate_debug_entities() -> void:
	var world_size := _world_grid.get_world_size()
	var total_cell_count := world_size.x * world_size.y
	var start_index := DEBUG_WORLD_SEED % total_cell_count
	for visited_count in range(total_cell_count):
		if _entity_store.get_entity_count() >= DEBUG_ENTITY_COUNT:
			break
		var cell_index := (start_index + visited_count * DEBUG_ENTITY_PLACEMENT_STRIDE) % total_cell_count
		var cell_position := Vector2i(cell_index % world_size.x, floori(float(cell_index) / world_size.x))
		if _world_grid.get_terrain(cell_position) != TerrainTypes.Id.WATER:
			var entity_id := _entity_store.create_entity(cell_position)
			_living_state_store.add_living_state(entity_id, 0)


func _update_change_summary(change_set: WorldChangeSet) -> void:
	var overlay_state := "on" if _elevation_overlay.is_overlay_visible() else "off"
	_change_summary.text = (
		"SPACE: apply debug change batch\n"
		+ "E: elevation overlay (%s)\n" % overlay_state
		+ "seed: %d | generator: %d\n" % [DEBUG_WORLD_SEED, WorldGenerator.GENERATOR_VERSION]
		+ "world revision: %d | simulation tick: %d\n"
		% [_world_grid.get_revision(), _simulation_clock.get_tick_index()]
		+ "simulation: %.1f Hz | entities: %d | living: %d\n"
		% [
			_simulation_clock.get_tick_rate(),
			_entity_store.get_entity_count(),
			_living_state_store.get_living_count(),
		]
		+ "movement tick: %d | moved: %d\n"
		% [_last_movement_tick, _last_moved_entity_count]
		+ "last change-set revision: %d\n" % change_set.get_revision()
		+ "changed chunks: terrain %d | elevation %d"
		% [change_set.get_terrain_chunk_count(), change_set.get_elevation_chunk_count()]
	)
