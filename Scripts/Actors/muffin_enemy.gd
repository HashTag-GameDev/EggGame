extends Actor2D
class_name MuffinEnemy

const DEAD_BODY = preload("uid://cm17q46b7lpcc")
const MUFFIN_DEAD = preload("uid://ccngw8y7btw4s")

@export_category("Rush Cycle")
@export var long_idle_cooldown: float = 2.5
@export var windup_time: float = 0.3
@export var dash_speed: float = 360.0
@export var dash_duration: float = 0.70
@export var attack_cooldown: float = 3.0
@export var recover_time: float = 0.45

@export_category("Patrol (circle when no player in vision)")
@export var patrol_radius: float = 40.0
@export var patrol_clockwise: bool = false
@export var patrol_center_offset: Vector2 = Vector2.ZERO
@export var should_drop_soul = false

var _patrol_center: Vector2
var _patrol_angle: float = 0.0

func setup() -> void:
	if !is_ai_controlled and hit_box:
		hit_box.as_player()
	attacks.append(muffin_attack)
	idle_logic = _patrol_circle
	_patrol_center = global_position + patrol_center_offset
	_patrol_angle = 0.0
	enable_hitbox(false)

func _patrol_circle() -> void:
	# Vector from center to our current position
	var r := global_position - _patrol_center
	if r.length_squared() < 1e-6:
		# If we ever spawn exactly on the center, nudge to the rim
		r = Vector2.RIGHT * max(1.0, patrol_radius)

	var radial := r.normalized()

	# Tangent direction (clockwise vs counter-clockwise)
	var tangent := Vector2(-radial.y, radial.x)
	if patrol_clockwise:
		tangent = -tangent

	# Constant-speed tangent motion
	var v := tangent * movement_speed

	# Gentle radial correction so we stick to the requested radius
	var radius_error := patrol_radius - r.length()
	# 4.0 is a light spring gain; adjust if you want tighter/looser circle
	v += radial * (radius_error * 4.0)

	move_actor(v)

# --- Attack (rush/tackle) registered as index 0 ---
func muffin_attack() -> float:
	# Windupdd
	await get_tree().create_timer(windup_time).timeout
	enable_hitbox()
	play_attack_1()
	# Lock dash direction at start
	var dir: Vector2
	if is_ai_controlled:
		dir = AI.Blackboard.player_actor.hurt_box.global_position
	else:
		dir = get_global_mouse_position()
	
	var dash_dir := (dir - global_position).normalized()

	# Dash for a fixed number of physics frames
	var frames := int(ceil(dash_duration * Engine.get_physics_ticks_per_second()))
	for _i in range(frames):
		velocity = dash_dir * dash_speed
		move_and_slide()
		await get_tree().physics_frame

	# Stop and recover
	velocity = Vector2.ZERO
	enable_hitbox(false)
	await get_tree().create_timer(recover_time).timeout

	override_attack_anim = false
	
	return attack_cooldown

func add_transitions(state_machine: AI.StateMachine) -> void:
	var idle := AI.StateIdle.new(self)
	var attack_player := AI.StateAttackPlayer.new(self, 0) # calls muffin_attack()
	var cooldown := AI.StateCooldown.new(self, long_idle_cooldown)

	state_machine.transitions = {
		idle: {
			AI.Event.PLAYER_ENTERED_VISION_RANGE: attack_player,
		},
		attack_player: {
			AI.Event.FINISHED: cooldown,
		},
		cooldown: {
			AI.Event.PLAYER_ENTERED_ATTACK_RANGE: attack_player,
			AI.Event.PLAYER_EXITED_VISION_RANGE: idle
		}
	}
	
	state_machine.activate(idle)

func drop_soul() -> void:
	if should_drop_soul:
		var dead_body = DEAD_BODY.instantiate()
		dead_body.global_position = global_position
		dead_body.sprite = MUFFIN_DEAD
		dead_body.sprite_transform.rotated(0.25)
		dead_body.speed = 50.0
		dead_body.enemy_name = &"Muffin"
		add_sibling(dead_body)
