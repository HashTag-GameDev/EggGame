extends Node
class_name PlayerController

@onready var possible_actors := [
	{
		&"name": &"Egg",
		&"unlocked": true,
		&"scene": preload("res://Scenes/Actors/egg_actor.tscn")
	},
	{
		&"name": &"Pea",
		&"unlocked": false,
		&"scene": preload("res://Scenes/Actors/pea_enemy.tscn")
	},
]
@export_category("Health")
@export var max_health: float
@export var player_defense: float
@export_category("Spawn")
@export var initial_player_spawn: Marker2D
@export var spawn_parent: Node2D
@export_category("UI")
@export var player_ui: PlayerUI
@export var health_bar: ProgressBar

var current_actor: Actor2D
var changing_actor := false
var attack_cooldown := 0.0
var attack_counter := 0
var started_attacks := []

var player_health: float

func _ready():
	player_health = max_health
	health_bar.value = player_health
	redraw_health_bar()
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
			# TODO: Make hatch function and await
			disconnect_signals()
			current_actor.hatch()
		var new_actor = possible_actors[id]["scene"].instantiate()
		if new_actor is Actor2D:
			current_actor = new_actor
			current_actor.global_position = spawn_pos
			current_actor.activate_camera()
			connect_signals()
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
		if started_attacks.is_empty():
			var attack_id = attack_counter
			attack_counter += 1
			started_attacks.append(attack_id)
			var cooldown = await current_actor.attack(0)
			var idx = started_attacks.find(attack_id)
			if idx == -1:
				return
			attack_cooldown = cooldown / 2
			started_attacks.pop_at(idx)

func handle_movement() -> void:
	var input_vector: Vector2 = Vector2.ZERO
	
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	
	if !input_vector.is_zero_approx() and !started_attacks.is_empty():
		started_attacks.clear()
	
	current_actor.move_actor(input_vector)

func took_damage(damage: float) -> void:
	player_health -= damage - player_defense
	if player_health <= 0.0:
		# TODO: Make game_over() function
		pass
	redraw_health_bar()

func obtained_soul(enemy_name: StringName) -> void:
	var could_unlock = false
	for actor: Dictionary in possible_actors:
		if actor[&"name"] == enemy_name:
			actor[&"unlocked"] = true
			could_unlock = true
	if could_unlock:
		do_unlock_animation(enemy_name)

func do_unlock_animation(enemy_name: StringName) -> void:
	player_ui.start_animation()
	for actor: Dictionary in possible_actors:
		player_ui.
	await player_ui.fade_in_window(player_ui.hatch_ui, 0.9)
	
	player_ui.finish_animation()

func redraw_health_bar() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(health_bar, "value", player_health / max_health * 100.0, 0.3)
	var background_stylebox: StyleBoxFlat = health_bar.get_theme_stylebox(&"background", &"ProgressBar") as StyleBoxFlat
	var fill_stylebox: StyleBoxFlat = health_bar.get_theme_stylebox(&"fill", &"ProgressBar") as StyleBoxFlat
	
	background_stylebox.bg_color.h = health_bar.value / 360.0
	fill_stylebox.bg_color.h = health_bar.value / 360.0

func open_hatch_menu() -> void:
	player_ui.fade_in_window(player_ui.hatch_ui, 0.8)

func close_hatch_menu() -> void:
	player_ui.fade_out_window(player_ui.hatch_ui)
	var selected_panel: Panel = player_ui.selected_panel as Panel
	if !selected_panel:
		return
	var hatch_id = selected_panel.get_meta(&"id")
	if hatch_id == -1:
		return
	create_new_actor(hatch_id, current_actor.global_position)

func _on_detection_area_entered(area: Area2D) -> void:
	if area.is_in_group("spawn_area"):
		var hint_ui = player_ui.hint_ui
		player_ui.fade_in_window(hint_ui)

func _on_detection_area_exited(area: Area2D) -> void:
	if area.is_in_group("spawn_area"):
		var hint_ui = player_ui.hint_ui
		player_ui.fade_out_window(hint_ui)

func disconnect_signals() -> void:
	current_actor.player_took_damage.disconnect(took_damage)
	current_actor.soul_obtained.disconnect(obtained_soul)

func connect_signals() -> void:
	current_actor.player_took_damage.connect(took_damage)
	current_actor.soul_obtained.connect(obtained_soul)
