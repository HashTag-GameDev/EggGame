@tool
extends Area2D
class_name HitBox2D

const DAMAGE_SOURCE_PLAYER := 0b01
const DAMAGE_SOURCE_MOB := 0b10

@export var damage: float = 10.0
var damage_source := DAMAGE_SOURCE_MOB: set = set_damage_source
var detected_hurtboxes := DAMAGE_SOURCE_PLAYER: set = set_detected_hurtboxes

var linear_velocity: Vector2

signal hit_hurt_box(hurt_box: HurtBox2D)

func _init() -> void:
	monitoring = true
	monitorable = true
	area_entered.connect(func _on_area_entered(area: Area2D) -> void:
		if area is HurtBox2D:
			hit_hurt_box.emit(area)
	)

func _physics_process(delta: float) -> void:
	var parent: RigidBody2D = get_parent() as RigidBody2D
	if parent is RigidBody2D:
		linear_velocity = parent.linear_velocity

func as_player() -> void:
	set_damage_source(DAMAGE_SOURCE_PLAYER)
	set_detected_hurtboxes(DAMAGE_SOURCE_MOB)

func set_damage_source(new_value: int) -> void:
	damage_source = new_value
	collision_layer = damage_source

func set_detected_hurtboxes(new_value: int) -> void:
	detected_hurtboxes = new_value
	collision_mask = detected_hurtboxes
