extends Actor2D
class_name EggActor

@export_category("Attack Parms")
@export var attack_cooldown: float = 1.0

@onready var hit_box_2d: HitBox2D = $HitBox2D

func setup() -> void:
	attacks.append(kick_attack)
	set_meta(&"name", &"Egg")

func kick_attack() -> float:
	disable_hitbox(false)
	play_attack_1()
	sprite.play("attack_one")
	await sprite.animation_finished
	override_attack_anim = false
	disable_hitbox()
	return attack_cooldown
