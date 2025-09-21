extends CanvasLayer

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

func _ready() -> void:
	hatch_enemy_1.mouse_entered.connect(hovered_panel.bind(hatch_enemy_1))
	hatch_enemy_2.mouse_entered.connect(hovered_panel.bind(hatch_enemy_2))
	hatch_enemy_3.mouse_entered.connect(hovered_panel.bind(hatch_enemy_3))
	hatch_enemy_4.mouse_entered.connect(hovered_panel.bind(hatch_enemy_4))
	hatch_cancel.mouse_entered.connect(hovered_panel.bind(hatch_cancel))
	
	hatch_enemy_1.set_meta(&"id", 1)
	hatch_enemy_2.set_meta(&"id", 2)
	hatch_enemy_3.set_meta(&"id", 3)
	hatch_enemy_4.set_meta(&"id", 4)
	hatch_cancel.set_meta(&"id", -1)

func _physics_process(_delta: float) -> void:
	if line:
		var mouse_pos := get_window().get_mouse_position()
		line.set_point_position(1, mouse_pos)

func fade_in_window(window: Control, fade_in_amount: float = 0.0) -> void:
	window.show()
	var tween = create_tween()
	tween.tween_property(window, "modulate:a", opaque if fade_in_amount == 0.0 else fade_in_amount, fade_in_speed)

func fade_out_window(window: Control) -> void:
	var tween = create_tween()
	tween.tween_property(window, "modulate:a", transparent, fade_out_speed)
	await tween.finished
	window.hide()

func draw_line_from_center() -> void:
	var mouse_pos := get_window().get_mouse_position()
	var screen_center := hatch_ui.size / 2
	
	line = Line2D.new()
	line.add_point(screen_center)
	line.add_point(mouse_pos)
	line.width = 3
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.default_color = Color(0.364, 0.553, 0.735, 0.553)
	add_child(line)

func stop_drawing_line() -> void:
	line.queue_free()

func hovered_panel(panel: Panel) -> void:
	if selected_panel != null:
		selected_panel.modulate.a = 0.5
	panel.modulate.a = 0.9
	selected_panel = panel
