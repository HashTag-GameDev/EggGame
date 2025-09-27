extends Actor2D
class_name MuffinEnemy

@export_category("Rush Cycle")
@export var long_idle_cooldown: float = 2.5
@export var windup_time: float = 0.3
@export var dash_speed: float = 360.0
@export var dash_duration: float = 0.70
@export var attack_cooldown: float = 3.0
@export var recover_time: float = 0.45

func setup() -> void:
	"""Register attack and set a simple idle (no patrol)."""
	unlock_name = &"Muffin" # must match PlayerController.possible_actors[].name
	attacks.append(muffin_attack)
	idle_logic = _idle_stand
	disable_hitbox()

func _idle_stand() -> void:
	"""Stand still and ensure idle animation."""
	move_actor(Vector2.ZERO) # snaps any walking_* to idle_*

func muffin_attack() -> float:
	"""Dash attack that uses walking anims at 10x speed instead of a bespoke attack anim."""
	await get_tree().create_timer(windup_time).timeout
	disable_hitbox(false)
	play_attack_1()

	# Lock dash direction at start
	var target_pos: Vector2 = AI.Blackboard.player_actor.hurt_box.global_position if is_ai_controlled else get_global_mouse_position()
	var dash_dir: Vector2 = (target_pos - global_position).normalized()

	# Drive fast walking animation during dash
	override_attack_anim = true
	var prev_speed: float = sprite.speed_scale
	sprite.speed_scale = 10.0
	_play_walk_anim_for_dir(dash_dir)

	# Dash for fixed frames
	var frames: int = int(ceil(dash_duration * Engine.get_physics_ticks_per_second()))
	for _i: int in range(frames):
		velocity = dash_dir * dash_speed
		move_and_slide()
		await get_tree().physics_frame

	# Stop and reset visuals
	velocity = Vector2.ZERO
	disable_hitbox()
	override_attack_anim = false
	sprite.speed_scale = prev_speed
	move_actor(Vector2.ZERO) # return to idle

	await get_tree().create_timer(recover_time).timeout
	return attack_cooldown

func _play_walk_anim_for_dir(dir: Vector2) -> void:
	"""Pick a walking_* anim based on direction."""
	if dir.is_zero_approx():
		sprite.play(&"idle_front")
		return
	if absf(dir.x) > absf(dir.y):
		if dir.x > 0.0:
			sprite.play(&"walking_right")
		else:
			sprite.play(&"walking_left")
	else:
		if dir.y > 0.0:
			sprite.play(&"walking_front")
		else:
			sprite.play(&"walking_back")

func add_transitions(state_machine: AI.StateMachine) -> void:
	"""FSM: Idle -> Attack -> Cooldown -> Attack (keeps cycling)."""
	var idle: AI.StateIdle = AI.StateIdle.new(self)
	var attack_player: AI.StateAttackPlayer = AI.StateAttackPlayer.new(self, 0)
	var cooldown: AI.StateCooldown = AI.StateCooldown.new(self, long_idle_cooldown)

	state_machine.transitions = {
		idle: {
			AI.Event.PLAYER_ENTERED_VISION_RANGE: attack_player,
		},
		attack_player: {
			AI.Event.FINISHED: cooldown,
		},
		cooldown: {
			AI.Event.PLAYER_ENTERED_ATTACK_RANGE: attack_player,
			AI.Event.PLAYER_EXITED_ATTACK_RANGE: attack_player,
			AI.Event.PLAYER_EXITED_VISION_RANGE: idle,
		},
	}
	state_machine.activate(idle)
