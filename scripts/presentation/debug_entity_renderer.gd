class_name DebugEntityRenderer
extends Node2D

const MARKER_COLOR: Color = Color8(255, 224, 92)
const MARKER_SIZE: Vector2 = Vector2(3.0, 3.0)

var _entity_store: EntityStore
var _marker_positions: Array[Vector2i] = []
var _refresh_count: int = 0


func _init() -> void:
	z_index = 2


func set_entity_store(entity_store: EntityStore) -> void:
	_entity_store = entity_store


func refresh_from_store() -> void:
	_marker_positions = [] if _entity_store == null else _entity_store.get_cell_positions_copy()
	_refresh_count += 1
	queue_redraw()


func get_marker_count() -> int:
	return _marker_positions.size()


func get_refresh_count() -> int:
	return _refresh_count


func get_marker_positions_copy() -> Array[Vector2i]:
	return _marker_positions.duplicate()


func _draw() -> void:
	for cell_position: Vector2i in _marker_positions:
		var display_position := Vector2(cell_position) * WorldPresentationConfig.CELL_DISPLAY_SCALE
		draw_rect(Rect2(display_position - Vector2.ONE, MARKER_SIZE), MARKER_COLOR)
