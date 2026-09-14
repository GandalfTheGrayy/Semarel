extends MainLoop

var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	_test_initial_zero_and_negative_time()
	_test_fixed_step_accumulation()
	_test_large_delta_catchup()
	_test_render_schedule_independence()
	_test_world_revision_independence_and_data_boundary()
	if _failures == 0:
		print("SIMULATION_CLOCK_TESTS_PASSED assertions=%d" % _assertions)
	else:
		printerr("SIMULATION_CLOCK_TESTS_FAILED failures=%d assertions=%d" % [_failures, _assertions])
		assert(false, "Simulation clock test suite failed")


func _process(_delta: float) -> bool:
	return true


func _test_initial_zero_and_negative_time() -> void:
	var clock := SimulationClock.new()
	_expect_equal(clock.get_tick_index(), 0, "initial tick index")
	_expect_true(is_equal_approx(clock.get_tick_rate(), 10.0), "prototype tick rate is centralized at ten hertz")
	_expect_false(clock.has_tick_due(), "initial clock has no due tick")
	_expect_false(clock.consume_tick(), "cannot consume an unavailable tick")
	_expect_true(clock.add_time(0.0), "zero delta is accepted")
	_expect_false(clock.has_tick_due(), "zero delta creates no tick")
	_expect_false(clock.add_time(-0.01), "negative delta is safely rejected")
	_expect_equal(clock.get_tick_index(), 0, "negative delta cannot advance time")
	_expect_true(is_zero_approx(clock.get_accumulated_seconds()), "negative delta leaves accumulator unchanged")


func _test_fixed_step_accumulation() -> void:
	var clock := SimulationClock.new()
	_expect_true(clock.add_time(0.04), "first small delta accepted")
	_expect_false(clock.has_tick_due(), "first small delta stays below interval")
	_expect_true(clock.add_time(0.06), "second small delta accepted")
	_expect_true(clock.has_tick_due(), "small deltas accumulate to one tick")
	_expect_true(clock.consume_tick(), "accumulated tick consumed")
	_expect_equal(clock.get_tick_index(), 1, "one fixed tick advances index once")
	_expect_false(clock.has_tick_due(), "exact interval leaves no due tick")
	_expect_true(is_zero_approx(clock.get_accumulated_seconds()), "exact interval leaves no remainder")


func _test_large_delta_catchup() -> void:
	var clock := SimulationClock.new()
	clock.add_time(0.55)
	var consumed := _consume_all(clock)
	_expect_equal(consumed, 5, "large delta exposes every due fixed tick")
	_expect_equal(clock.get_tick_index(), 5, "catchup advances one index per consumed tick")
	_expect_true(is_equal_approx(clock.get_accumulated_seconds(), 0.05), "catchup preserves sub-tick remainder")
	_expect_false(clock.consume_tick(), "remainder cannot produce an extra tick")


func _test_render_schedule_independence() -> void:
	_expect_equal(_run_schedule(60, 1.0 / 60.0), 10, "sixty render frames produce ten simulation ticks")
	_expect_equal(_run_schedule(30, 1.0 / 30.0), 10, "thirty render frames produce ten simulation ticks")
	_expect_equal(_run_schedule(10, 0.1), 10, "ten coarse frames produce ten simulation ticks")


func _test_world_revision_independence_and_data_boundary() -> void:
	var clock := SimulationClock.new()
	var world := WorldGrid.new(Vector2i(2, 2), 2, TerrainTypes.Id.WATER)
	world.set_terrain(Vector2i.ZERO, TerrainTypes.Id.LAND)
	world.commit_changes()
	_expect_equal(world.get_revision(), 1, "world revision advances independently")
	_expect_equal(clock.get_tick_index(), 0, "world commit does not advance simulation tick")
	clock.add_time(0.2)
	_consume_all(clock)
	_expect_equal(clock.get_tick_index(), 2, "simulation clock advances independently")
	_expect_equal(world.get_revision(), 1, "simulation time does not change world revision")
	_expect_true(clock is RefCounted, "clock is data-only RefCounted")
	_expect_false(clock.has_method("get_tree"), "clock has no scene-tree API")
	var source := FileAccess.get_file_as_string("res://scripts/simulation/simulation_clock.gd")
	_expect_false(source.contains("extends Node"), "clock source has no Node dependency")


func _run_schedule(frame_count: int, frame_delta: float) -> int:
	var clock := SimulationClock.new()
	for frame_index in range(frame_count):
		clock.add_time(frame_delta)
		_consume_all(clock)
	return clock.get_tick_index()


func _consume_all(clock: SimulationClock) -> int:
	var consumed := 0
	while clock.consume_tick():
		consumed += 1
	return consumed


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
