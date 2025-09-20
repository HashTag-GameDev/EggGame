extends StaticBody2D

@export var one_way: bool = false

var player: CharacterBody2D

func _ready() -> void:
	$CollisionPolygon2D3.disabled = !one_way

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player.z_index = 1

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player.z_index = 0
