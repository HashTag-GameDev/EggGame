extends Actor2D

@onready var spear_scene: PackedScene = preload("res://Scenes/Projectiles/spear_projectile.tscn")
@export var spear_cooldown: float = 3.0
@export var spear_speed: float = 150.0

func setup() -> void:
	attacks.append(spear_attack)

func spear_attack():
	print("Spear thrown")
	sprite.play(&"throw_spear")
	await sprite.animation_finished
	print("Throwing spear animation finished")
	var spear_direction: Vector2
	if is_ai_controlled:
		spear_direction = (AI.Blackboard.player_actor.hurt_box.global_position) - global_position
	else:
		spear_direction = get_global_mouse_position() - AI.Blackboard.player_actor.global_position
	var spear_instance := spear_scene.instantiate() as RigidBody2D
	spear_instance.global_position = global_position
	spear_instance.linear_velocity = spear_direction.normalized() * spear_speed
	spear_instance.rotate(spear_direction.angle() + PI * 0.5)
	add_sibling(spear_instance)
	sprite.play(&"throw_spear_cooldown")
	return true

func add_transitions(state_machine: AI.StateMachine) -> void:
	var idle := AI.StateIdle.new(self)
	var move_to_player := AI.StateMoveToPlayer.new(self)
	var attack_player := AI.StateAttackPlayer.new(self, 0)
	var cooldown := AI.StateCooldown.new(self, 3.0)
	
	state_machine.transitions = {
		idle: {
			AI.Event.PLAYER_ENTERED_VISION_RANGE: move_to_player,
		},
		move_to_player: {
			AI.Event.PLAYER_EXITED_VISION_RANGE: idle,
			AI.Event.PLAYER_ENTERED_ATTACK_RANGE: attack_player,
		},
		attack_player: {
			AI.Event.FINISHED: cooldown,
		},
		cooldown: {
			AI.Event.PLAYER_ENTERED_ATTACK_RANGE: attack_player,
			AI.Event.PLAYER_EXITED_ATTACK_RANGE: move_to_player,
			AI.Event.PLAYER_EXITED_VISION_RANGE: idle
		}
	}
	
	state_machine.activate(idle)
