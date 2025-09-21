extends CharacterBody2D
class_name Actor2D

@export var is_ai_controlled: bool = false
@export var sprite: AnimatedSprite2D = null
@export var camera: Camera2D = null

@export_category("Values")
@export var movement_speed: float = 150.0
@export_enum("None", "Melee", "Ranged", "Both") var attack_type

@export_category("Detection")
@export var vision_range := 50.0
@export var attack_range := 50.0

@export_category("Health")
@export var hurt_box: HurtBox2D = null
@export var health_bar: ProgressBar = null
@export var hit_particle: CPUParticles2D
@export var max_health: float = 100.0
@export var defense: float = 0.0

@export_category("Attacking")
@export var hit_box: HitBox2D = null

var health: float
var is_dying := false

var attacks: Array[Callable] = []

var idle_logic: Callable
var override_attack_anim = false

signal player_took_damage(damage: float)
signal soul_obtained(enemy_name: StringName)

func _ready() -> void:
	hurt_box.took_hit.connect(took_damage)
	sprite.play(&"idle_front")
	setup()
	
	if is_ai_controlled:
		health = max_health
		redraw_health()
		if !is_in_group("enemy"):
			add_to_group("enemy")
		if is_in_group("player"):
			remove_from_group("player")
		print("Is AI controlled: ", is_ai_controlled)
		var state_machine = AI.StateMachine.new()
		add_child(state_machine)
		add_transitions(state_machine)
	else:
		if is_in_group("enemy"):
			remove_from_group("enemy")
		if !is_in_group("player"):
			add_to_group("player")
		hurt_box.as_player_hurtbox()
		if health_bar == null:
			return
		health_bar.hide()

func setup() -> void:
	pass

func move_actor(v: Vector2) -> void:
	if is_dying:
		return
	v = v.normalized()
	velocity = v * movement_speed
	move_and_slide()
	
	if !override_attack_anim:
		if v.is_zero_approx():
			match sprite.animation:
				"walking_front":
					sprite.animation = "idle_front"
				"walking_back":
					sprite.animation = "idle_back"
				"walking_left":
					sprite.animation = "idle_left"
				"walking_right":
					sprite.animation = "idle_right"
		elif v.y > 0:
			sprite.play("walking_front")
		elif v.y < 0:
			sprite.play("walking_back")
		elif v.x > 0:
			sprite.play("walking_right")
			sprite.flip_h = false
		elif v.x < 0:
			sprite.play("walking_left")
			sprite.flip_h = true

func attack(id: int) -> float:
	if is_dying:
		return 0.0
	if id < attacks.size():
		var attack_function: Callable = attacks[id] as Callable
		var cooldown = await attack_function.call()
		return cooldown
	return 0.0

func activate_camera() -> void:
	camera.enabled = true

func add_transitions(_state_machine: AI.StateMachine) -> void:
	pass

func took_damage(colliding_hit_box: HitBox2D) -> void:
	if is_dying:
		return
	if hit_particle != null:
		hit_particle.direction = colliding_hit_box.linear_velocity
		hit_particle.emitting = true
	var damage := colliding_hit_box.damage
	if !is_ai_controlled:
		player_took_damage.emit(damage)
		return
	
	health -= damage - defense
	redraw_health()
	if health <= 0.0:
		# TODO: Make die method and animation.
		die()

func enable_hitbox(enable: bool = true) -> void:
	if hit_box != null:
		hit_box.monitorable = enable
		hit_box.monitoring = enable

func redraw_health() -> void:
	if health_bar == null:
		print("Health bar needs to be set.")
		return
	var health_percentage = health / max_health * 100.0
	health_bar.value = health_percentage

func hatch() -> void:
	queue_free()

func die() -> void:
	is_dying = true
	# TODO: Make better dying logic and play animation.
	if hit_particle != null:
		if hit_particle.emitting:
			await hit_particle.finished
	queue_free()

func obtain_soul(enemy_name: StringName) -> void:
	if is_ai_controlled:
		return
	soul_obtained.emit(enemy_name)
