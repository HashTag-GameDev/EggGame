@tool
extends HitBox2D

var life_time: float = 10.0
var alive_for: float = 0.0

func _init() -> void:
	set_physics_process(false)

func _ready() -> void:
	$AudioStreamPlayer2D.pitch_scale = randf_range(0.95, 1.05)
	$AudioStreamPlayer2D.play()
	hit_hurt_box.connect(_on_hit_box_hit)

func _physics_process(delta: float) -> void:
	alive_for += delta
	if alive_for > life_time:
		die()

func _on_hit_box_hit(_area: HurtBox2D) -> void:
	die()

func die() -> void:
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.took_damage(self)
		body.set_slow(true)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.set_slow(false)
