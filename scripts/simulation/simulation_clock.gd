class_name SimulationClock
extends RefCounted

const TICK_RATE_HZ: float = 10.0
const TICK_INTERVAL_SECONDS: float = 1.0 / TICK_RATE_HZ
const _TIME_EPSILON: float = 0.000000001

var _accumulated_seconds: float = 0.0
var _tick_index: int = 0


func add_time(delta_seconds: float) -> bool:
	if delta_seconds < 0.0:
		return false
	_accumulated_seconds += delta_seconds
	return true


func has_tick_due() -> bool:
	return _accumulated_seconds + _TIME_EPSILON >= TICK_INTERVAL_SECONDS


func consume_tick() -> bool:
	if not has_tick_due():
		return false
	_accumulated_seconds -= TICK_INTERVAL_SECONDS
	if absf(_accumulated_seconds) < _TIME_EPSILON:
		_accumulated_seconds = 0.0
	_tick_index += 1
	return true


func get_tick_index() -> int:
	return _tick_index


func get_tick_rate() -> float:
	return TICK_RATE_HZ


func get_accumulated_seconds() -> float:
	return _accumulated_seconds
