extends CanvasLayer
class_name PlayerUI

signal hatch_actor_hovered(id: int) ## Emitted when any hatch panel is hovered; id is set via panel metadata.

@export var fade_in_speed: float = 0.5 ## Seconds to fade in windows.
@export var fade_out_speed: float = 0.5 ## Seconds to fade out windows.
@export var opaque: float = 0.75 ## Target alpha when shown.
@export var transparent: float = 0.0 ## Target alpha when hidden.
@export var hint_ui: Control ## Reference to hint UI root.
@export var hatch_ui: Control ## Reference to hatch menu root.
@export var hatch_enemy_1: Panel ## Panel for actor slot 0.
@export var hatch_enemy_2: Panel ## Panel for actor slot 1.
@export var hatch_enemy_3: Panel ## Panel for actor slot 2.
@export var hatch_enemy_4: Panel ## Panel for actor slot 3.
@export var hatch_cancel: Panel ## Panel for cancel (-1).
@export var panel_base_alpha: float = 0.5 ## Default alpha for inactive panels.

var selected_panel: Panel
var doing_animation: bool = false
var hatch_panels: Array[Panel] = []

func _ready() -> void:
	# Ensure UI keeps receiving input and tweens during pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hatch_ui.process_mode = Node.PROCESS_MODE_ALWAYS

	show()
	hatch_ui.modulate.a = 0.0

	# Set panel IDs once.
	hatch_enemy_1.set_meta(&"id", 0)
	hatch_enemy_2.set_meta(&"id", 1)
	hatch_enemy_3.set_meta(&"id", 2)
	hatch_enemy_4.set_meta(&"id", 3)
	hatch_cancel.set_meta(&"id", -1)

	# Collect panels for utility.
	hatch_panels = [hatch_enemy_1, hatch_enemy_2, hatch_enemy_3, hatch_enemy_4, hatch_cancel]

	# Hover signals -> update selection visuals and emit id outward.
	for panel: Panel in hatch_panels:
		panel.mouse_entered.connect(_on_panel_hovered.bind(panel))

func fade_in_window(window: Control, fade_in_amount: float = 0.0) -> void:
	"""Fade a window to visible; safe during pause."""
	window.show()
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var target: float = opaque if fade_in_amount == 0.0 else fade_in_amount
	tween.tween_property(window, "modulate:a", target, fade_in_speed)
	await tween.finished

func fade_out_window(window: Control) -> void:
	"""Fade a window to hidden; safe during pause."""
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(window, "modulate:a", transparent, fade_out_speed)
	await tween.finished
	window.hide()

func start_animation() -> void:
	"""Mark UI as doing an animation (optional external check)."""
	doing_animation = true

func finish_animation() -> void:
	"""Clear animation flag."""
	doing_animation = false

func do_panel_animation(id: int) -> void:
	"""Play a brief highlight animation on the panel with id."""
	var panel: Panel = get_panel_by_id(id)
	var panel_sprite: AnimatedSprite2D = panel.get_node_or_null("Enemy Sprite") as AnimatedSprite2D

	await get_tree().create_timer(0.5).timeout

	var original_alpha: float = panel.modulate.a
	var tween_panel: Tween = create_tween()
	tween_panel.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_panel.tween_property(panel, "modulate:a", 0.9, 0.5)
	await tween_panel.finished
	await get_tree().create_timer(0.25).timeout
	var tween_sprite: Tween = create_tween()
	tween_sprite.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_sprite.tween_property(panel_sprite, "modulate:v", 1.0, 0.5)
	await tween_sprite.finished
	await get_tree().create_timer(0.25).timeout
	var tween_back: Tween = create_tween()
	tween_back.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_back.tween_property(panel, "modulate:a", original_alpha, 0.5)
	await tween_back.finished

func reset_panels_alpha() -> void:
	"""Reset all hatch panels to base alpha."""
	for panel: Panel in hatch_panels:
		panel.modulate.a = panel_base_alpha

func get_panel_by_id(id: int) -> Panel:
	"""Return the hatch panel by id (0..3); defaults to first slot."""
	match id:
		0:
			return hatch_enemy_1
		1:
			return hatch_enemy_2
		2:
			return hatch_enemy_3
		3:
			return hatch_enemy_4
	return hatch_enemy_1

func get_panel_id_at_mouse() -> int:
	"""Return the hatch panel id under the mouse, or -1 if none/cancel."""
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	for panel: Panel in hatch_panels:
		if !panel.visible:
			continue
		var id: int = int(panel.get_meta(&"id")) if panel.has_meta(&"id") else -1
		if id == -1:
			continue
		if panel.get_global_rect().has_point(mouse_pos):
			return id
	return -1

func _on_panel_hovered(panel: Panel) -> void:
	# Update visual selection.
	if selected_panel != null:
		selected_panel.modulate.a = panel_base_alpha
	panel.modulate.a = 0.9
	selected_panel = panel

	# Emit id outward for controller to react (controller ignores hover for switching).
	var id: int = int(panel.get_meta(&"id")) if panel.has_meta(&"id") else -1
	hatch_actor_hovered.emit(id)
