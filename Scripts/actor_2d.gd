extends CharacterBody2D
class_name Actor2D

@export var is_ai_controlled: bool = false
@export var sprite: AnimatedSprite2D = null
@export var hurt_box: HurtBox2D = null
@export var camera: Camera2D = null

@export_category("Values")
@export var movement_speed: float = 150.0
@export_enum("None", "Melee", "Ranged", "Both") var attack_type

@export_category("Detection")
@export var vision_range := 50.0
@export var attack_range := 50.0

@export_category("SFX")
@export var audio_player: AudioStreamPlayer2D
@export var walking_audio: Array[AudioStream]
@export var walking_audio_cooldown: float = 0.25
@export var attack_audio_player_1: AudioStreamPlayer2D
@export var attack_audio_1: AudioStream
@export var attack_audio_player_2: AudioStreamPlayer2D
@export var attack_audio_2: AudioStream

var _audio_cooling_down: bool = false
var _timer: Timer

var attacks: Array[Callable] = []

var idle_logic: Callable
var override_attack_anim = false

func _ready() -> void:
	setup()
	walking_timer_setup()
	
	if is_ai_controlled:
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

func setup() -> void:
	pass

func walking_timer_setup() -> void:
	_timer = Timer.new()
	print(_timer)
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(func(): _audio_cooling_down = false)

func move_actor(v: Vector2) -> void:
	v = v.normalized()
	velocity = v * movement_speed
	move_and_slide()
	
	if !override_attack_anim:
		if v.is_zero_approx():
			play_walking_audio(false)
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
			play_walking_audio(true)
		elif v.y < 0:
			sprite.play("walking_back")
			play_walking_audio(true)
		elif v.x > 0:
			sprite.play("walking_right")
			play_walking_audio(true)
			sprite.flip_h = false
		elif v.x < 0:
			sprite.play("walking_left")
			play_walking_audio(true)
			sprite.flip_h = true

func play_walking_audio(is_walking: bool) -> void:
	if not _timer:
		return
	if not is_walking:
		return
	if _audio_cooling_down:
		return
	if walking_audio.is_empty():
		return
	
	
	audio_player.stream = walking_audio[min(0, randi_range(0, (walking_audio.size() - 1)))]
	audio_player.pitch_scale = randf_range(0.95, 1.05)
	audio_player.play(0.0)
	_audio_cooling_down = true
	_timer.start(walking_audio_cooldown)

func play_attack_1() -> void:
	if attack_audio_player_1 and attack_audio_1:
		attack_audio_player_1.stream = attack_audio_1
		attack_audio_player_1.play()

func play_attack_2() -> void:
	if attack_audio_player_2 and attack_audio_2:
		attack_audio_player_2.stream = attack_audio_2
		attack_audio_player_2.play()

func attack(id: int) -> void:
	if id < attacks.size():
		var attack_function: Callable = attacks[id] as Callable
		attack_function.call()

func activate_camera() -> void:
	camera.enabled = true

func add_transitions(state_machine: AI.StateMachine) -> void:
	pass
