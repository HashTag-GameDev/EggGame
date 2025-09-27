extends CharacterBody2D
class_name Actor2D

@export var is_ai_controlled: bool = true
@export var sprite: AnimatedSprite2D = null
@export var camera: Camera2D = null

@export_category("Values")
@export var enemy_name: StringName
@export var movement_speed: float = 150.0
@export_enum("None", "Melee", "Ranged", "Both") var attack_type

@export_category("Detection")
@export var vision_range: float = 50.0
@export var attack_range: float = 50.0
@export var always_see_player: bool = false ## If true, AI treats player as always visible (set by arena when fight starts).

@export_category("Health")
@export var hurt_box: HurtBox2D = null
@export var health_bar: ProgressBar = null
@export var hit_particle: CPUParticles2D
@export var max_health: float = 100.0
@export var defense: float = 0.0

@export_category("Attacking")
@export var hit_box: HitBox2D = null

@export_category("SFX")
@export var audio_player: AudioStreamPlayer2D
@export var walking_audio: Array[AudioStream]
@export var walking_audio_cooldown: float = 0.25
@export var attack_audio_player_1: AudioStreamPlayer2D
@export var attack_audio_1: AudioStream
@export var attack_audio_player_2: AudioStreamPlayer2D
@export var attack_audio_2: AudioStream

@export_category("Drop_Soul")
@export var should_drop_soul: bool = false
@export var soul_scene: PackedScene
@export var dead_sprite: Texture2D

var _audio_cooling_down: bool = false
var _timer: Timer
var attacks: Array[Callable] = []
var idle_logic: Callable
var override_attack_anim: bool = false
var base_movement_speed: float
var health: float
var is_dying: bool = false

signal player_took_damage(damage: float)

func _ready() -> void:
	base_movement_speed = movement_speed
	hurt_box.took_hit.connect(took_damage)
	sprite.play(&"idle_front")
	setup()
	walking_timer_setup()
	
	if is_ai_controlled:
		health = max_health
		redraw_health()
		if !is_in_group("enemy"):
			add_to_group("enemy")
		if is_in_group("player"):
			remove_from_group("player")
		var state_machine := AI.StateMachine.new()
		add_child(state_machine)
		add_transitions(state_machine)
	else:
		if is_in_group("enemy"):
			remove_from_group("enemy")
		if !is_in_group("player"):
			add_to_group("player")
		if health_bar == null:
			return
		health_bar.hide()

func setup() -> void:
	pass

func walking_timer_setup() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(func() -> void: _audio_cooling_down = false)

func move_actor(v: Vector2) -> void:
	"""Move the actor and drive 4-dir walk/idle animations."""
	if is_dying:
		return

	# Movement
	v = v.normalized()
	velocity = v * movement_speed
	move_and_slide()

	# Animations (skip if an attack overrides them)
	if override_attack_anim:
		return

	if v.is_zero_approx():
		play_walking_audio(false)
		# Ensure any walking anim goes to its matching idle, including left/right
		match sprite.animation:
			"walking_front":
				sprite.animation = "idle_front"
			"walking_back":
				sprite.animation = "idle_back"
			"walking_right":
				sprite.animation = "idle_right"
			"walking_left":
				sprite.animation = "idle_left"
		return

	# Choose walking anim by dominant axis
	play_walking_audio(true)
	if absf(v.x) > absf(v.y):
		sprite.animation = "walking_right" if v.x > 0.0 else "walking_left"
	else:
		sprite.animation = "walking_front" if v.y > 0.0 else "walking_back"

func play_walking_audio(should_play: bool) -> void:
	if should_play and not _audio_cooling_down and walking_audio.size() > 0 and audio_player:
		audio_player.pitch_scale = randf_range(0.95, 1.05)
		audio_player.stream = walking_audio[randi() % walking_audio.size()]
		audio_player.play()
		_audio_cooling_down = true
		_timer.start(walking_audio_cooldown)

func play_attack_1() -> void:
	if attack_audio_player_1 and attack_audio_1:
		attack_audio_player_1.pitch_scale = randf_range(0.95, 1.05)
		attack_audio_player_1.stream = attack_audio_1
		attack_audio_player_1.play()

func play_attack_2() -> void:
	if attack_audio_player_2 and attack_audio_2:
		attack_audio_player_2.stream = attack_audio_2
		attack_audio_player_2.play()

func attack(id: int) -> float:
	if is_dying:
		return 0.0
	if id < attacks.size():
		var attack_function: Callable = attacks[id]
		var cooldown: float = await attack_function.call()
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
	var damage: float = colliding_hit_box.damage
	if !is_ai_controlled:
		player_took_damage.emit(damage)
		return
	
	health -= damage - defense
	redraw_health()
	if health <= 0.0:
		die()

func disable_hitbox(enable: bool = true) -> void:
	if (hit_box != null) and (hit_box.collider != null):
		hit_box.collider.disabled = enable

func redraw_health() -> void:
	if health_bar == null:
		push_warning("Health bar needs to be set.")
		return
	var health_percentage: float = health / max_health * 100.0
	health_bar.value = health_percentage

func hatch() -> void:
	queue_free()

func die() -> void:
	is_dying = true
	drop_soul()
	# TODO: sfx/vfx

func set_slow(is_slow: bool) -> void:
	movement_speed = movement_speed * 0.66 if is_slow else base_movement_speed

func get_ai_controlled() -> bool:
	return is_ai_controlled

func drop_soul() -> void:
	if should_drop_soul:
		var dead_body: Node2D = soul_scene.instantiate()
		dead_body.global_position = global_position
		dead_body.sprite = dead_sprite
		dead_body.sprite_2d.rotation = 90.0
		dead_body.speed = 50.0
		dead_body.enemy_name = enemy_name
		call_deferred("add_sibling", dead_body)
