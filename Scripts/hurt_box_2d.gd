@tool
extends Area2D
class_name HurtBox2D

const DAMAGE_SOURCE_PLAYER := 0b01
const DAMAGE_SOURCE_MOB := 0b10

var damage_source := DAMAGE_SOURCE_PLAYER: set = set_damage_source
var hurtbox_type := DAMAGE_SOURCE_MOB: set = set_hurtbox_type

signal took_hit(hit_box: HitBox2D)

func _init() -> void:
	monitoring = true
	monitorable = true
	area_entered.connect(func _on_area_entered(area: Area2D) -> void:
		if area is HitBox2D:
			took_hit.emit(area)
	)

func as_player_hurtbox() -> void:
	set_damage_source(DAMAGE_SOURCE_MOB)
	set_hurtbox_type(DAMAGE_SOURCE_PLAYER)

func set_damage_source(new_value: int) -> void:
	damage_source = new_value
	collision_mask = damage_source

func set_hurtbox_type(new_value: int) -> void:
	hurtbox_type = new_value
	collision_layer = hurtbox_type
