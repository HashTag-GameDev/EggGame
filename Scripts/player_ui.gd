extends CanvasLayer
class_name PlayerUI

@export var fade_in_speed: float = 0.1
@export var fade_out_speed: float = 0.1
@export var opaque: float = 0.75
@export var transparent: float = 0.0
@export var hint_ui: Control
@export var hatch_ui: Control
@export var hatch_enemy_1: Panel
@export var hatch_enemy_2: Panel
@export var hatch_enemy_3: Panel
@export var hatch_enemy_4: Panel
@export var hatch_cancel: Panel

var line: Line2D
var selected_panel: Panel
var doing_animation := false

func _ready() -> void:
	hatch_ui.modulate.a = 0.0
	hatch_enemy_1.mouse_entered.connect(hovered_panel.bind(hatch_enemy_1))
	hatch_enemy_2.mouse_entered.connect(hovered_panel.bind(hatch_enemy_2))
	hatch_enemy_3.mouse_entered.connect(hovered_panel.bind(hatch_enemy_3))
	hatch_enemy_4.mouse_entered.connect(hovered_panel.bind(hatch_enemy_4))
	hatch_cancel.mouse_entered.connect(hovered_panel.bind(hatch_cancel))
	
	hatch_enemy_1.set_meta(&"id", 0)
	hatch_enemy_2.set_meta(&"id", 1)
	hatch_enemy_3.set_meta(&"id", 2)
	hatch_enemy_4.set_meta(&"id", 3)
	hatch_cancel.set_meta(&"id", -1)

func fade_in_window(window: Control, fade_in_amount: float = 0.0) -> void:
	window.show()
	var tween = create_tween()
	tween.tween_property(window, "modulate:a", opaque if fade_in_amount == 0.0 else fade_in_amount, fade_in_speed)
	await tween.finished

func fade_out_window(window: Control) -> void:
	var tween = create_tween()
	tween.tween_property(window, "modulate:a", transparent, fade_out_speed)
	await tween.finished
	window.hide()

func hovered_panel(panel: Panel) -> void:
	if selected_panel != null:
		selected_panel.modulate.a = 0.5
	panel.modulate.a = 0.9
	selected_panel = panel

func start_animation() -> void:
	doing_animation = true

func finish_animation() -> void:
	doing_animation = false

func do_panel_animation(id: int) -> void:
	var panel: Panel = null
	panel = get_panel_by_id(id)
	
	var original_alpha := panel.modulate.a

func set_panel_alpha(id: int, alpha: float) -> void:
	var panel := get_panel_by_id(id)
	panel.modulate.a = alpha

func get_panel_by_id(id: int) -> Panel:
	match id:
		0:
			return hatch_enemy_1
		1:
			return hatch_enemy_2
		2:
			return hatch_enemy_3
		3:
			return hatch_enemy_4
	return null
