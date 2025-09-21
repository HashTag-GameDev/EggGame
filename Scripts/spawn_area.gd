extends Area2D

@export var player_controller: Node

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var player_ui = player_controller.get_node("UILayer")
		player_ui.fade_in_window(player_ui.hint_ui, 0.9)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		var player_ui = player_controller.get_node("UILayer")
		player_ui.fade_out_window(player_ui.hint_ui)
