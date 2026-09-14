class_name PrototypeLifecycleTransition
extends RefCounted


func transition_to_remains(
	entity_id: int,
	death_tick: int,
	entity_store: EntityStore,
	living_state_store: LivingStateStore,
	remains_state_store: RemainsStateStore,
) -> bool:
	if entity_store == null or living_state_store == null or remains_state_store == null:
		return false
	if not living_state_store.is_bound_to(entity_store):
		return false
	if not remains_state_store.is_bound_to(entity_store):
		return false
	if death_tick < 0 or not entity_store.has_entity(entity_id):
		return false
	if not living_state_store.has_living_state(entity_id):
		return false
	if remains_state_store.has_remains_state(entity_id):
		return false

	if not remains_state_store.add_remains_state(entity_id, death_tick):
		return false
	if living_state_store.remove_living_state(entity_id):
		return true

	# Keep the two stores unchanged if an unexpected removal failure occurs.
	remains_state_store.remove_remains_state(entity_id)
	return false
