class_name DebugEntityRenderer
extends Node2D

const LIVING_MARKER_COLOR: Color = Color8(255, 224, 92)
const REMAINS_MARKER_COLOR: Color = Color8(142, 91, 74)
const GENERIC_MARKER_COLOR: Color = Color8(190, 190, 190)
const MARKER_SIZE: Vector2 = Vector2(3.0, 3.0)
const _GENERIC_MARKER: int = 0
const _LIVING_MARKER: int = 1
const _REMAINS_MARKER: int = 2

var _entity_store: EntityStore
var _living_state_store: LivingStateStore
var _remains_state_store: RemainsStateStore
var _marker_positions: Array[Vector2i] = []
var _marker_kinds: PackedByteArray = PackedByteArray()
var _living_marker_count: int = 0
var _remains_marker_count: int = 0
var _refresh_count: int = 0


func _init() -> void:
	z_index = 2


func set_entity_store(entity_store: EntityStore) -> void:
	_entity_store = entity_store


func set_state_stores(
	living_state_store: LivingStateStore,
	remains_state_store: RemainsStateStore,
) -> void:
	if living_state_store != null:
		assert(_entity_store != null and living_state_store.is_bound_to(_entity_store))
	if remains_state_store != null:
		assert(_entity_store != null and remains_state_store.is_bound_to(_entity_store))
	_living_state_store = living_state_store
	_remains_state_store = remains_state_store


func refresh_from_store() -> void:
	_marker_positions = [] if _entity_store == null else _entity_store.get_cell_positions_copy()
	_marker_kinds.resize(_marker_positions.size())
	_living_marker_count = 0
	_remains_marker_count = 0
	for dense_index in range(_marker_positions.size()):
		var entity_id := _entity_store.get_entity_id_at_dense_index(dense_index)
		if _living_state_store != null and _living_state_store.has_living_state(entity_id):
			_marker_kinds[dense_index] = _LIVING_MARKER
			_living_marker_count += 1
		elif _remains_state_store != null and _remains_state_store.has_remains_state(entity_id):
			_marker_kinds[dense_index] = _REMAINS_MARKER
			_remains_marker_count += 1
		else:
			_marker_kinds[dense_index] = _GENERIC_MARKER
	_refresh_count += 1
	queue_redraw()


func get_marker_count() -> int:
	return _marker_positions.size()


func get_refresh_count() -> int:
	return _refresh_count


func get_living_marker_count() -> int:
	return _living_marker_count


func get_remains_marker_count() -> int:
	return _remains_marker_count


func get_marker_positions_copy() -> Array[Vector2i]:
	return _marker_positions.duplicate()


func _draw() -> void:
	for dense_index in range(_marker_positions.size()):
		var cell_position := _marker_positions[dense_index]
		var display_position := Vector2(cell_position) * WorldPresentationConfig.CELL_DISPLAY_SCALE
		match _marker_kinds[dense_index]:
			_LIVING_MARKER:
				draw_rect(Rect2(display_position - Vector2.ONE, MARKER_SIZE), LIVING_MARKER_COLOR)
			_REMAINS_MARKER:
				draw_line(
					display_position - Vector2.ONE,
					display_position + Vector2.ONE,
					REMAINS_MARKER_COLOR,
					1.0,
				)
				draw_line(
					display_position + Vector2(-1.0, 1.0),
					display_position + Vector2(1.0, -1.0),
					REMAINS_MARKER_COLOR,
					1.0,
				)
			_:
				draw_rect(Rect2(display_position - Vector2.ONE, MARKER_SIZE), GENERIC_MARKER_COLOR)
