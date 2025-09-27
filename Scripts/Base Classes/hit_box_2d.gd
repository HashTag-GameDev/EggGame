@tool
extends Area2D
class_name HitBox2D

signal hit_hurt_box(hurt_box: HurtBox2D)

@export var damage: float = 10.0 ## Damage applied when hitting a HurtBox2D.
@export var collider: Node2D ## Optional CollisionShape2D parent to toggle.
@export_enum("Auto", "Enemy", "Player") var owner_type: int = 0 ## Auto = infer from parent/groups.

const LAYER_ENEMY: int = 1
const LAYER_PLAYER: int = 2

var linear_velocity: Vector2

func _ready() -> void:
	# Clear first, then set desired bits.
	collision_layer = 0
	collision_mask = 0
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	_apply_layers()

func refresh_collision() -> void:
	"""Re-apply layers/masks when the parent allegiance changes at runtime."""
	collision_layer = 0
	collision_mask = 0
	_apply_layers()

func _on_area_entered(area: Area2D) -> void:
	if area is HurtBox2D:
		hit_hurt_box.emit(area)

func _apply_layers() -> void:
	var is_enemy: bool = _is_enemy_owner()
	# HitBox sits on its side's layer, and collides with the opposite side's hurtboxes.
	if is_enemy:
		set_collision_layer_value(LAYER_ENEMY, true)
		set_collision_mask_value(LAYER_PLAYER, true)
	else:
		set_collision_layer_value(LAYER_PLAYER, true)
		set_collision_mask_value(LAYER_ENEMY, true)

func _is_enemy_owner() -> bool:
	# Explicit override via export wins.
	match owner_type:
		1: return true
		2: return false
		_: pass
	# Infer from parent type/props/groups.
	var p: Node = get_parent()
	if p is Actor2D:
		return (p as Actor2D).is_ai_controlled
	if "is_ai_controlled" in p:
		return bool(p.is_ai_controlled)
	if p.is_in_group("enemy"):
		
		return true
	if p.is_in_group("player"):
		return false
	# Default to player if unknown.
	return false
