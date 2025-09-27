extends CharacterBody2D
class_name Actor2D

# Exports
@export var is_ai_controlled: bool = true
@export var sprite: AnimatedSprite2D
@export var camera: Camera2D

@export_category("Values") 
@export var movement_speed: float = 150.0
@export_enum("None", "Melee", "Ranged", "Both") var attack_type

@export_category("Detection") 
@export var vision_range: float = 50.0
@export var attack_range: float = 50.0
@export var always_see_player: bool = false ## Set true by arenas so AI always sees the player.

@export_category("Health")
@export var hurt_box: HurtBox2D
@export var health_bar: ProgressBar
@export var hit_particle: CPUParticles2D
@export var max_health: float = 100.0
@export var defense: float = 0.0

@export_category("Attacking")
@export var hit_box: HitBox2D

@export_category("SFX") 
@export var audio_player: AudioStreamPlayer2D
@export var walking_audio: Array[AudioStream] = []
@export var walking_audio_cooldown: float = 0.25
@export var attack_audio_player_1: AudioStreamPlayer2D
@export var attack_audio_1: AudioStream

@export_category("Unlock/Soul")
@export var should_drop_soul: bool = false ## If true, spawn a soul once on death to unlock this enemy type.
@export var soul_scene: PackedScene ## Optional override for the soul scene.
@export var soul_sprite: Texture2D ## Optional corpse sprite shown with the soul.
@export var soul_speed: float = 60.0 ## Homing speed for the soul pickup.
@export var unlock_name: StringName ## Name that must match PlayerController.possible_actors[].name.

# Signals
signal player_took_damage(damage: float)

# Internals
var _audio_cooling_down: bool = false
var _timer: Timer
var attacks: Array[Callable] = []
var idle_logic: Callable
var override_attack_anim: bool = false
var base_movement_speed: float
var health: float
var is_dying: bool = false

# Lifecycle
func _ready() -> void:
	base_movement_speed = movement_speed
	assert(is_instance_valid(sprite))
	assert(is_instance_valid(hurt_box))
	hurt_box.took_hit.connect(took_damage)
	sprite.play(&"idle_front")
	setup()
	_walking_timer_setup()
	if is_ai_controlled:
		health = max_health
		redraw_health()
		if !is_in_group("enemy"):
			add_to_group("enemy")
		if is_in_group("player"):
			remove_from_group("player")
		var sm := AI.StateMachine.new()
		add_child(sm)
		add_transitions(sm)
	else:
		if is_in_group("enemy"):
			remove_from_group("enemy")
		if !is_in_group("player"):
			add_to_group("player")
		if health_bar:
			health_bar.hide()

# Public API
func setup() -> void:
	"""Child classes register attacks and set metadata here."""
	pass

func move_actor(v: Vector2) -> void:
	"""Move and drive 4-dir walk/idle animations unless an attack overrides them."""
	if is_dying:
		return
	v = v.normalized()
	velocity = v * movement_speed
	move_and_slide()
	if override_attack_anim:
		return
	if v.is_zero_approx():
		_play_walking_audio(false)
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
	_play_walking_audio(true)
	if absf(v.x) > absf(v.y):
		sprite.animation = "walking_right" if v.x > 0.0 else "walking_left"
	else:
		sprite.animation = "walking_front" if v.y > 0.0 else "walking_back"

func attack(id: int) -> float:
	"""Run a registered attack by id and return its cooldown."""
	if is_dying:
		return 0.0
	if id >= 0 and id < attacks.size():
		var fn: Callable = attacks[id]
		var cd: float = await fn.call()
		return cd
	return 0.0

func activate_camera() -> void:
	camera.enabled = true

func add_transitions(_state_machine: AI.StateMachine) -> void:
	"""Child classes declare AI transitions here."""
	pass

func took_damage(colliding_hit_box: HitBox2D) -> void:
	if is_dying:
		return
	if hit_particle:
		hit_particle.direction = colliding_hit_box.linear_velocity
		hit_particle.emitting = true
	var dmg: float = colliding_hit_box.damage
	if !is_ai_controlled:
		player_took_damage.emit(dmg)
		return
	health -= maxf(0.0, dmg - defense)
	redraw_health()
	if health <= 0.0:
		die()

func disable_hitbox(enable: bool = true) -> void:
	if hit_box and hit_box.collider:
		hit_box.collider.disabled = enable

func redraw_health() -> void:
	if not health_bar:
		return
	var pct: float = health / max_health * 100.0
	health_bar.value = pct

func hatch() -> void:
	queue_free()

func die() -> void:
	"""Spawn soul if needed, then free this enemy."""
	is_dying = true
	drop_soul()
	queue_free()

func drop_soul() -> void:
	"""Spawn a homing soul to unlock this enemy type via the player controller."""
	if !should_drop_soul:
		return
	should_drop_soul = false

	var scene: PackedScene = soul_scene if soul_scene else preload("uid://cm17q46b7lpcc")
	if scene == null:
		push_warning("No soul scene assigned; cannot drop soul.")
		return

	var soul := scene.instantiate() as Node2D
	if soul == null:
		push_warning("Soul scene did not instantiate to Node2D.")
		return

	# Determine unlock name: prefer export, fallback to meta("name")
	var name_to_unlock: String = str(unlock_name)
	if name_to_unlock.is_empty() and has_meta(&"name"):
		name_to_unlock = str(get_meta(&"name"))

	if name_to_unlock.is_empty():
		push_warning("unlock_name not set on %s; soul will not unlock anything." % [get_class()])
	else:
		if soul.has_method("set"):
			soul.set("enemy_name", StringName(name_to_unlock))
			if soul_sprite:
				soul.set("sprite", soul_sprite)
			soul.set("speed", soul_speed)

	soul.global_position = global_position
	call_deferred("add_sibling", soul)

# Internal
func _walking_timer_setup() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(func() -> void: _audio_cooling_down = false)

func _play_walking_audio(should_play: bool) -> void:
	if should_play and not _audio_cooling_down and walking_audio.size() > 0 and audio_player:
		audio_player.pitch_scale = randf_range(0.95, 1.05)
		audio_player.stream = walking_audio[randi() % walking_audio.size()]
		audio_player.play()
		_audio_cooling_down = true
		_timer.start(walking_audio_cooldown)

func play_attack_1() -> void:
	"""Play primary attack SFX with slight random pitch."""
	if not attack_audio_player_1 or not attack_audio_1:
		return
	attack_audio_player_1.pitch_scale = randf_range(0.95, 1.05)
	attack_audio_player_1.stream = attack_audio_1
	attack_audio_player_1.play()
