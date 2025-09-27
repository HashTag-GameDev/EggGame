extends RigidBody2D

@export var hit_box_2d: HitBox2D

var life_time: float = 5.0
var alive_for: float = 0.0
var is_ai_controlled: bool = true

func _init() -> void:
	set_physics_process(false)

func _ready() -> void:
	hit_box_2d.hit_hurt_box.connect(_on_hit_box_hit)

func _physics_process(delta: float) -> void:
	alive_for += delta
	if alive_for > life_time:
		die()

func get_ai_controlled() -> bool:
	return is_ai_controlled

func _on_hit_box_hit(_area: HurtBox2D) -> void:
	die()

func die() -> void:
	queue_free()
