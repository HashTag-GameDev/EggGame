extends Node
class_name PlayerController

@onready var possible_actors = [
	{
		"name": "Egg",
		"hatchable": false,
		"unlocked": true,
		"scene": preload("res://Scenes/Actors/egg_actor.tscn")
	},
	{
		"name": "Pea",
		"hatchable": true,
		"unlocked": true,
		"scene": preload("res://Scenes/Actors/pea_enemy.tscn")
	},
]

@export var player_ui: CanvasLayer
@export var initial_player_spawn: Marker2D
@export var spawn_parent: Node2D

var current_actor: Actor2D
var changing_actor := false
var attack_cooldown := 0.0

func _ready():
	if current_actor == null:
		create_new_actor(0, initial_player_spawn.global_position)

func _physics_process(delta: float) -> void:
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
		attack_cooldown = clampf(attack_cooldown, 0.0, 99.0)
		return
	handle_movement()

func create_new_actor(id: int, spawn_pos: Vector2) -> void:
	if changing_actor:
		return
	changing_actor = true
	if id < possible_actors.size():
		if current_actor:
			#await current_actor.despawn_self()
			pass
		var new_actor = possible_actors[id]["scene"].instantiate()
		if new_actor is Actor2D:
			current_actor = new_actor
			current_actor.global_position = spawn_pos
			current_actor.activate_camera()
			spawn_parent.add_child(current_actor)
			AI.Blackboard.player_actor = current_actor
	changing_actor = false

func _unhandled_input(event: InputEvent) -> void:
	if attack_cooldown != 0.0:
		return
	if event.is_action_pressed(&"hatch_menu"):
		open_hatch_menu()
	if event.is_action_released(&"hatch_menu"):
		close_hatch_menu()
	if Input.is_action_just_pressed(&"attack_1"):
		attack_cooldown = 1.5
		current_actor.attack(0)

func handle_movement() -> void:
	var input_vector: Vector2 = Vector2.ZERO
	
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	
	current_actor.move_actor(input_vector)

func open_hatch_menu() -> void:
	player_ui.fade_in_window(player_ui.hatch_ui, 0.8)
	#player_ui.draw_line_from_center()

func close_hatch_menu() -> void:
	player_ui.fade_out_window(player_ui.hatch_ui)
	var selected_panel: Panel = player_ui.selected_panel as Panel
	var hatch_id = selected_panel.get_meta(&"id")
	if hatch_id == -1:
		return
	create_new_actor(hatch_id, current_actor.global_position)
	#player_ui.stop_drawing_line()

func _on_detection_area_entered(area: Area2D) -> void:
	if area.is_in_group("spawn_area"):
		var hint_ui = player_ui.hint_ui
		player_ui.fade_in_window(hint_ui)

func _on_detection_area_exited(area: Area2D) -> void:
	if area.is_in_group("spawn_area"):
		var hint_ui = player_ui.hint_ui
		player_ui.fade_out_window(hint_ui)
