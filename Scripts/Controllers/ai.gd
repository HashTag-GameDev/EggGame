extends RefCounted
class_name AI

class Blackboard extends RefCounted:
	static var player_actor: Actor2D = null

enum Event {
	NONE,
	FINISHED,
	PLAYER_ENTERED_VISION_RANGE,
	PLAYER_EXITED_VISION_RANGE,
	PLAYER_ENTERED_ATTACK_RANGE,
	PLAYER_EXITED_ATTACK_RANGE
}

class StateMachine extends Node:
	var transitions := {}: set = set_transitions
	var current_state: State
	
	func set_transitions(new_transitions: Dictionary) -> void:
		transitions = new_transitions
		if OS.is_debug_build():
			for state: State in transitions:
				assert(
					state is State,
					"Invalid state in the transitions dictionary. " +
					"Expected a State object, but got " + str(state)
				)
				for event: Event in transitions[state]:
					assert(
						event is Event,
						"Invalid event in the transitions dictionary. " +
						"Expected an Event object, but got " + str(event)
					)
					assert(
						transitions[state][event] is State,
						"Invalid state in the transitions dictionary. " +
						"Expected a State object, but got " +
						str(transitions[state][event])
					)
	
	func _ready() -> void:
		set_physics_process(false)
	
	func activate(initial_state: State = null) -> void:
		if initial_state != null:
			current_state = initial_state
		assert(
			current_state != null,
			"Activated the state machine but the state variable is null. " +
			"Please assign a starting state to the state machine."
		)
		current_state.finished.connect(_on_state_finished.bind(current_state))
		current_state.enter()
		set_physics_process(true)
	
	func _physics_process(delta: float) -> void:
		var event := current_state.update(delta)
		if event == Event.NONE:
			return
		trigger_event(event)
	
	func trigger_event(event: Event) -> void:
		if not current_state in transitions:
			return
		if not transitions[current_state].has(event):
			print_debug(
				"Trying to trigger event " + Event.keys()[event] +
				" from state " + current_state.name +
				" but the transition does not exist."
			)
			return
		var next_state = transitions[current_state][event]
		_transition(next_state)
	
	func _transition(new_state: State) -> void:
		current_state.exit()
		current_state.finished.disconnect(_on_state_finished)
		current_state = new_state
		current_state.finished.connect(_on_state_finished.bind(current_state))
		current_state.enter()
	
	func _on_state_finished(finished_state: State) -> void:
		assert(
			Event.FINISHED in transitions[finished_state],
			"Received a state that does not have a transition for the FINISHED event, " + current_state.name + ". " +
			"Add a transition for this event in the transitions dictionary."
		)
		_transition(transitions[finished_state][Event.FINISHED])

class State extends RefCounted:
	
	signal finished
	
	var name := "State"
	var actor: Actor2D = null
	
	func _init(init_name: String, init_actor: Actor2D) -> void:
		name = init_name
		actor = init_actor
	
	func is_player_in_vision_range() -> bool:
		if AI.Blackboard.player_actor != null:
			var player_distance := actor.global_position.distance_to(AI.Blackboard.player_actor.global_position)
			return player_distance < actor.vision_range
		else:
			return false
	
	func is_player_in_attack_range() -> bool:
		if AI.Blackboard.player_actor != null:
			var player_distance := actor.global_position.distance_to(AI.Blackboard.player_actor.global_position)
			return player_distance < actor.attack_range
		else:
			return false
	
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
	var duration := 3.0
	var _time := 0.0
	
	func _init(init_actor: Actor2D) -> void:
		super("Move To Player", init_actor)
	
	func enter() -> void:
		_time = 0.0
	
	func update(_delta: float) -> Event:
		var direction := AI.Blackboard.player_actor.global_position - actor.global_position
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
	
	func update(_delta: float) -> Event:
		actor.attack(attack_id)
		return Event.FINISHED

class StateCooldown extends State:
	var cooldown: float
	var _time := 0.0
	
	func _init(init_actor: Actor2D, init_cooldown: float) -> void:
		super("Cooldown", init_actor)
		cooldown = init_cooldown
	
	func enter() -> void:
		_time = 0.0
	
	func update(delta: float) -> Event:
		_time += delta
		if _time >= cooldown:
			if is_player_in_vision_range():
				if is_player_in_attack_range():
					return Event.PLAYER_ENTERED_ATTACK_RANGE
				else:
					return Event.PLAYER_EXITED_ATTACK_RANGE
			return Event.PLAYER_EXITED_VISION_RANGE
		return Event.NONE
