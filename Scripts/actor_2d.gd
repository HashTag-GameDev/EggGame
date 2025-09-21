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

var attacks: Array[Callable] = []

var idle_logic: Callable
var override_attack_anim = false

func _ready() -> void:
	sprite.play(&"idle_front")
	setup()
	
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

func move_actor(v: Vector2) -> void:
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
					sprite.animation = "idle_left"
		elif v.y > 0:
			sprite.play("walking_front")
		elif v.y < 0:
			sprite.play("walking_back")
		elif v.x > 0:
			sprite.play("walking_left")
			sprite.flip_h = true
		elif v.x < 0:
			sprite.play("walking_left")
			sprite.flip_h = false

func attack(id: int) -> void:
	if id < attacks.size():
		var attack_function: Callable = attacks[id] as Callable
		attack_function.call()

func activate_camera() -> void:
	camera.enabled = true

func add_transitions(_state_machine: AI.StateMachine) -> void:
	pass
