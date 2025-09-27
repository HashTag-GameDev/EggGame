@tool
extends Area2D
class_name HitBox2D

@export var damage: float = 10.0
@export var collider: Node2D

var linear_velocity: Vector2

signal hit_hurt_box(hurt_box: HurtBox2D)

func _init() -> void:
	area_entered.connect(func _on_area_entered(area: Area2D) -> void:
		if area is HurtBox2D:
			hit_hurt_box.emit(area)
	)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	if get_parent().has_method("get_ai_controlled"):
		if get_parent().is_ai_controlled:
			set_collision_layer_value(1, true)
			set_collision_mask_value(2, true)
		else:
			set_collision_layer_value(2, true)
			set_collision_mask_value(1, true)
	else:
		set_collision_layer_value(1, true)
		set_collision_mask_value(1, true)

func _physics_process(delta: float) -> void:
	var parent: RigidBody2D = get_parent() as RigidBody2D
	if parent is RigidBody2D:
		linear_velocity = parent.linear_velocity
