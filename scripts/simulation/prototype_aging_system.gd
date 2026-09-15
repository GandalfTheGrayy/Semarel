class_name PrototypeAgingSystem
extends RefCounted

const BASE_LIFESPAN_TICKS: int = 120
const LIFESPAN_VARIATION_TICKS: int = 81
const INVALID_LIFESPAN_TICKS: int = -1
const _HASH_MASK: int = 0x7fffffff


static func get_prototype_lifespan_ticks(entity_id: int) -> int:
	if entity_id <= EntityStore.INVALID_ENTITY_ID:
		return INVALID_LIFESPAN_TICKS
	var mixed := (entity_id * 73_856_093) & _HASH_MASK
	mixed = ((mixed ^ (mixed >> 13)) * 1_274_126_177) & _HASH_MASK
	mixed = (mixed ^ (mixed >> 16)) & _HASH_MASK
	return BASE_LIFESPAN_TICKS + mixed % LIFESPAN_VARIATION_TICKS


func step(
	current_tick: int,
	entity_store: EntityStore,
	living_state_store: LivingStateStore,
	remains_state_store: RemainsStateStore,
	lifecycle_transition: PrototypeLifecycleTransition,
) -> int:
	assert(current_tick >= 0, "Simulation tick index cannot be negative")
	assert(entity_store != null, "Prototype aging requires an EntityStore")
	assert(living_state_store != null, "Prototype aging requires a LivingStateStore")
	assert(remains_state_store != null, "Prototype aging requires a RemainsStateStore")
	assert(lifecycle_transition != null, "Prototype aging requires a lifecycle transition")
	assert(living_state_store.is_bound_to(entity_store), "Living state must belong to the aging EntityStore")
	assert(remains_state_store.is_bound_to(entity_store), "Remains state must belong to the aging EntityStore")

	var newly_dead_count := 0
	var dense_index := 0
	while dense_index < living_state_store.get_dense_count():
		var entity_id := living_state_store.get_entity_id_at_dense_index(dense_index)
		var age_ticks := living_state_store.get_age_ticks(entity_id, current_tick)
		var lifespan_ticks := get_prototype_lifespan_ticks(entity_id)
		if (
			age_ticks != LivingStateStore.INVALID_AGE_TICKS
			and lifespan_ticks != INVALID_LIFESPAN_TICKS
			and age_ticks >= lifespan_ticks
			and lifecycle_transition.transition_to_remains(
				entity_id,
				current_tick,
				entity_store,
				living_state_store,
				remains_state_store,
			)
		):
			newly_dead_count += 1
			# Swap-remove placed an unchecked living row at this same dense index.
			continue
		dense_index += 1
	return newly_dead_count
