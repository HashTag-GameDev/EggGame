extends Area2D

@export var is_boss_battle: bool = false

var enemies_remaining: Array = []
var area_complete: bool = false

func _on_player_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		#start battle / Raise Walls
		if is_boss_battle:
			MusicManager.fade_to(&"Music_3", 0.25)
		else:
			MusicManager.fade_to(&"Music_2", 0.5)

func _on_body_entered(body: Node2D) -> void:
	if !body.is_in_group("player") and body.is_in_group("enemy"):
		enemies_remaining.append(body)

func _on_body_exited(body: Node2D) -> void:
	if !body.is_in_group("player") and body.is_in_group("enemy"):
		enemies_remaining.erase(body)
		if check_enemies_remaining() <= 0:
			# remove walls
			area_complete = true
			pass

func check_enemies_remaining() -> int:
	return enemies_remaining.size()

func _on_player_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		MusicManager.fade_to(&"Music_1", 0.25)
