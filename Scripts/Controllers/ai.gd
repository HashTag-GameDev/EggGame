extends RefCounted
class_name AI

class Blackboard extends RefCounted:
	static var player_actor: Actor2D = null
	static var player_controller: Node = null

enum Event {
	NONE,
	FINISHED,
	PLAYER_ENTERED_VISION_RANGE,
	PLAYER_EXITED_VISION_RANGE,
	PLAYER_ENTERED_ATTACK_RANGE,
	PLAYER_EXITED_ATTACK_RANGE
}

class StateMachine extends Node:
	var transitions: Dictionary = {}: set = set_transitions
	var current_state: State

	func set_transitions(new_transitions: Dictionary) -> void:
		"""Assign the state transition table and validate entries in debug builds."""
		transitions = new_transitions
		if OS.is_debug_build():
			for state: State in transitions:
				assert(state is State, "Invalid state in transitions.")
				for event: Event in transitions[state]:
					assert(event is Event, "Invalid event in transitions.")
					assert(transitions[state][event] is State, "Invalid transition target.")

	func _ready() -> void:
		set_physics_process(false)

	func activate(initial_state: State = null) -> void:
		"""Start the state machine at initial_state."""
		if initial_state != null:
			current_state = initial_state
		assert(current_state != null, "State machine needs an initial state.")
		current_state.finished.connect(_on_state_finished.bind(current_state))
		current_state.enter()
		set_physics_process(true)

	func _physics_process(delta: float) -> void:
		var event: Event = current_state.update(delta)
		if event == Event.NONE:
			return
		trigger_event(event)

	func trigger_event(event: Event) -> void:
		"""Trigger a transition based on the given event, if defined."""
		if not current_state in transitions:
			return
		if not transitions[current_state].has(event):
			# Use Node.name for readable debug
			print_debug("Missing transition for event %s from %s" % [Event.keys()[event], current_state.name])
			return
		var next_state: State = transitions[current_state][event]
		current_state.exit()
		current_state.finished.disconnect(_on_state_finished.bind(current_state))
		current_state = next_state
		current_state.finished.connect(_on_state_finished.bind(current_state))
		current_state.enter()

	func _on_state_finished(_state: State) -> void:
		trigger_event(Event.FINISHED)

class State extends Node:
	"""Base AI state with helpers for common player checks."""
	signal finished

	var state_name: String
	var actor: Actor2D

	func _init(init_name: String, init_actor: Actor2D) -> void:
		state_name = init_name
		actor = init_actor
		name = init_name # set Node.name for nicer debug output

	func is_player_in_vision_range() -> bool:
		if AI.Blackboard.player_actor == null:
			return false
		# Always-visible toggle (set by arena)
		if "always_see_player" in actor and actor.always_see_player:
			return true
		var player_distance: float = actor.global_position.distance_to(AI.Blackboard.player_actor.global_position)
		return player_distance < actor.vision_range

	func is_player_in_attack_range() -> bool:
		if AI.Blackboard.player_actor == null:
			return false
		var player_distance: float = actor.global_position.distance_to(AI.Blackboard.player_actor.global_position)
		return player_distance < actor.attack_range

	func update(_delta: float) -> Event:
		return Event.NONE

	func enter() -> void:
		pass

	func exit() -> void:
		pass

class StateIdle extends State:
	func _init(init_actor: Actor2D) -> void:
		super("Idle", init_actor)

	func enter() -> void:
		actor.sprite.play(&"idle_front")

	func update(_delta: float) -> Event:
		if actor.idle_logic.is_valid():
			actor.idle_logic.call()
		if is_player_in_vision_range():
			return Event.PLAYER_ENTERED_VISION_RANGE
		return Event.NONE

class StateMoveToPlayer extends State:
	var duration: float = 3.0
	var _time: float = 0.0

	func _init(init_actor: Actor2D) -> void:
		super("Move To Player", init_actor)

	func enter() -> void:
		_time = 0.0

	func update(_delta: float) -> Event:
		var player := AI.Blackboard.player_actor
		if player:
			var direction: Vector2 = player.global_position - actor.global_position
			actor.move_actor(direction)
		if !is_player_in_vision_range():
			return Event.PLAYER_EXITED_VISION_RANGE
		if is_player_in_attack_range():
			return Event.PLAYER_ENTERED_ATTACK_RANGE
		return Event.NONE

class StateCirclePlayer extends State:
	func _init(init_actor: Actor2D) -> void:
		super("Circle Player", init_actor)

class StateAttackPlayer extends State:
	var attack_id: int

	func _init(init_actor: Actor2D, init_attack_id: int) -> void:
		super("Attack Player", init_actor)
		attack_id = init_attack_id

	func enter() -> void:
		_do_attack()

	func update(_delta: float) -> Event:
		return Event.NONE

	func _do_attack() -> void:
		await actor.attack(attack_id)
		finished.emit()

class StateCooldown extends State:
	"""Cooldown state with small per-entry random jitter to desync groups."""
	var cooldown: float
	var _time: float = 0.0
	var _target_cooldown: float = 0.0

	func _init(init_actor: Actor2D, init_cooldown: float) -> void:
		super("Cooldown", init_actor)
		cooldown = init_cooldown

	func enter() -> void:
		_time = 0.0
		# Read per-enemy jitter if present; else use a sensible default (20%)
		var j: float = 0.20
		if "attack_jitter_pct" in actor:
			j = clampf(actor.attack_jitter_pct, 0.0, 0.95)
		# Sample a multiplier in [1-j, 1+j]
		var mult: float = 1.0 + randf_range(-j, j)
		_target_cooldown = maxf(0.0, cooldown * mult)

	func update(delta: float) -> Event:
		_time += delta
		if _time >= _target_cooldown:
			if is_player_in_vision_range():
				if is_player_in_attack_range():
					return Event.PLAYER_ENTERED_ATTACK_RANGE
				return Event.PLAYER_EXITED_ATTACK_RANGE
			return Event.PLAYER_EXITED_VISION_RANGE
		return Event.NONE
