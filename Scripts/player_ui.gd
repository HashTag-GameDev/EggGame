extends CanvasLayer

@export var fade_in_speed: float = 0.1
@export var fade_out_speed: float = 0.1
@export var opaque: float = 0.75
@export var transparent: float = 0.1
@export var hint_ui: Control

func fade_in_window(window: Control) -> void:
	window.show()
	var tween = create_tween()
	tween.tween_property(window, "modulate:a", opaque, fade_in_speed)

func fade_out_window(window: Control) -> void:
	var tween = create_tween()
	tween.tween_property(window, "modulate:a", transparent, fade_out_speed)
	await tween.finished
	window.hide()
