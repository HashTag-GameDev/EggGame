extends RigidBody2D

@export var hit_box_2d: HitBox2D

var life_time: float = 5.0
var alive_for: float = 0.0

func _init() -> void:
	set_physics_process(false)

func _ready() -> void:
	hit_box_2d.hit_hurt_box.connect(_on_hit_box_hit)

func _physics_process(delta: float) -> void:
	alive_for += delta
	if alive_for > life_time:
		die()

func _on_hit_box_hit(_area: HurtBox2D) -> void:
	die()

func as_player() -> void:
	hit_box_2d.as_player()

func die() -> void:
	queue_free()
