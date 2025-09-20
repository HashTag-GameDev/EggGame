@tool
extends Area2D
class_name HitBox2D

const DAMAGE_SOURCE_PLAYER := 0b01
const DAMAGE_SOURCE_MOB := 0b10

var damage: float = 10.0
var damage_source := DAMAGE_SOURCE_MOB: set = set_damage_source
var detected_hurtboxes := DAMAGE_SOURCE_PLAYER: set = set_detected_hurtboxes

signal hit_hurt_box(hurt_box: HurtBox2D)

func _init(as_player: bool = false) -> void:
	monitoring = true
	monitorable = true
	area_entered.connect(func _on_area_entered(area: Area2D) -> void:
		if area is HurtBox2D:
			hit_hurt_box.emit(area)
	)
	if as_player:
		set_damage_source(DAMAGE_SOURCE_PLAYER)
		set_detected_hurtboxes(DAMAGE_SOURCE_MOB)

func set_damage_source(new_value: int) -> void:
	damage_source = new_value
	collision_layer = damage_source

func set_detected_hurtboxes(new_value: int) -> void:
	detected_hurtboxes = new_value
	collision_mask = detected_hurtboxes
