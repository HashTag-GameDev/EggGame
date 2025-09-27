@tool
extends Area2D
class_name HurtBox2D

signal took_hit(hit_box: HitBox2D)

func _init() -> void:
	area_entered.connect(func _on_area_entered(area: Area2D) -> void:
		if area is HitBox2D:
			took_hit.emit(area)
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
