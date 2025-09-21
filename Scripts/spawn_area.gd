extends Area2D

@export var player_controller: Node

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		var player_ui = player_controller.get_node("UILayer")
		player_ui.fade_in_window(player_ui.hint_ui, 60.0)

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("player"):
		var player_ui = player_controller.get_node("UILayer")
		player_ui.fade_out_window(player_ui.hint_ui)
