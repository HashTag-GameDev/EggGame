extends Node
class_name PlayerController

@onready var unlocked_actors = [
	{
		"name": "Egg",
		"hatchable": false,
		"scene": preload("res://Scenes/Characters/egg_actor.tscn")
	}
]

@export var player_ui: CanvasLayer
@export var initial_player_spawn: Marker2D
@export var spawn_parent: Node2D

var current_actor: Actor2D

func _ready():
	if current_actor == null:
		create_new_actor(0, initial_player_spawn.global_position)

func _physics_process(_delta: float) -> void:
	handle_movement()

func create_new_actor(id: int, spawn_pos: Vector2) -> void:
	if id < unlocked_actors.size():
		var new_actor = unlocked_actors[id]["scene"].instantiate()
		if new_actor is Actor2D:
			current_actor = new_actor
			current_actor.global_position = spawn_pos
			current_actor.activate_camera()
			spawn_parent.add_child(current_actor)
			AI.Blackboard.player_actor = current_actor

func handle_movement() -> void:
	var input_vector: Vector2 = Vector2.ZERO
	
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	
	current_actor.move_actor(input_vector)

func _on_detection_area_entered(area: Area2D) -> void:
	if area.is_in_group("spawn_area"):
		var hint_ui = player_ui.hint_ui
		player_ui.fade_in_window(hint_ui)

func _on_detection_area_exited(area: Area2D) -> void:
	if area.is_in_group("spawn_area"):
		var hint_ui = player_ui.hint_ui
		player_ui.fade_out_window(hint_ui)
