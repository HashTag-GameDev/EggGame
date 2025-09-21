extends StaticBody2D

@export var collider: CollisionShape2D
@export var sprite: AnimatedSprite2D

func _ready() -> void:
	sprite.play(&"default")
	collider.disabled = true

func raise() -> void:
	collider.set_deferred(&"disabled", false)
	sprite.play(&"raise")

func lower() -> void:
	sprite.play(&"lower")
	await sprite.animation_finished
	collider.set_deferred(&"disabled", false)
