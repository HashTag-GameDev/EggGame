extends Node
class_name PlayerController

# Exports
@export_category("Health")
@export var max_health: float = 100.0 ## Max player health.
@export var player_defense: float = 0.0 ## Flat damage reduction.

@export_category("Combat")
@export var attack_cooldown_sec: float = 0.25 ## Fixed attack interval; set 0.0 to use actor's own cooldown.

@export_category("Spawn")
@export var initial_player_spawn: Marker2D ## Required spawn marker.
@export var spawn_parent: Node2D ## Parent for the spawned actor.

@export_category("UI")
@export var player_ui: PlayerUI ## Player UI controller.
@export var health_bar: ProgressBar ## Health bar in HUD.

# Onready
@onready var possible_actors: Array[Dictionary] = [
	{
		&"name": &"Egg",
		&"unlocked": true,
		&"scene": preload("res://Scenes/Actors/egg_actor.tscn"),
		&"group": "egg"
	},
	{
		&"name": &"Pea",
		&"unlocked": false,
		&"scene": preload("res://Scenes/Actors/pea_enemy.tscn"),
		&"group": "pea"
	},
	{
		&"name": &"Muffin",
		&"unlocked": false,
		&"scene": preload("res://Scenes/Actors/muffin_enemy.tscn"),
		&"group": "muffin"
	},
]

# State
var current_actor: Actor2D
var player_health: float = 0.0
var _changing_actor: bool = false
var _attack_held: bool = false
var _cooling_down: bool = false

# Lifecycle
func _ready() -> void:
	assert(is_instance_valid(initial_player_spawn))
	assert(is_instance_valid(spawn_parent))
	assert(is_instance_valid(player_ui))
	assert(is_instance_valid(health_bar))

	player_health = max_health
	health_bar.value = player_health
	redraw_health_bar()

	if current_actor == null:
		create_new_actor(0, initial_player_spawn.global_position)

func _physics_process(_delta: float) -> void:
	# Poll input here so UI can't swallow events.
	if Input.is_action_just_pressed(&"attack_1"):
		_attack_held = true
		_try_attack()
	if Input.is_action_just_released(&"attack_1"):
		_attack_held = false

	_handle_movement()

func _input(event: InputEvent) -> void:
	# Use _input (not _unhandled_input) so menu toggles work even if UI consumes events.
	if event.is_action_pressed(&"hatch_menu"):
		open_hatch_menu()
	if event.is_action_released(&"hatch_menu"):
		close_hatch_menu()

# Public API
func create_new_actor(id: int, spawn_pos: Vector2) -> void:
	"""Spawn or switch to the actor at the given index."""
	if _changing_actor:
		return
	_changing_actor = true

	if id < possible_actors.size():
		if current_actor:
			disconnect_signals()
			current_actor.hatch()

		var new_actor: Node = possible_actors[id][&"scene"].instantiate()
		if new_actor is Actor2D:
			current_actor = new_actor
			current_actor.is_ai_controlled = false
			current_actor.global_position = spawn_pos
			current_actor.activate_camera()
			spawn_parent.add_child(current_actor)
			connect_signals()
			AI.Blackboard.player_actor = current_actor
			if current_actor.has_method(&"disable_hitbox"):
				current_actor.disable_hitbox(false) # Ensure combat is enabled.

	_changing_actor = false

func open_hatch_menu() -> void:
	"""Show the hatch selection UI."""
	player_ui.fade_in_window(player_ui.hatch_ui, 0.8)

func close_hatch_menu() -> void:
	"""Hide hatch UI and switch actor if a valid unlocked selection is made."""
	player_ui.fade_out_window(player_ui.hatch_ui)
	var selected_panel: Panel = player_ui.selected_panel as Panel
	if selected_panel == null:
		return
	var hatch_id: int = selected_panel.get_meta(&"id") as int
	if hatch_id == -1:
		return
	if hatch_id < possible_actors.size() and possible_actors[hatch_id][&"unlocked"]:
		if current_actor == null or !current_actor.is_in_group(possible_actors[hatch_id][&"group"]):
			var pos: Vector2 = current_actor.global_position if current_actor != null else initial_player_spawn.global_position
			create_new_actor(hatch_id, pos)

func took_damage(damage: float) -> void:
	"""Apply damage after defense, update health/UI, trigger game over if needed."""
	var final_damage: float = maxf(0.0, damage - player_defense)
	player_health -= final_damage
	if player_health <= 0.0:
		game_over()
	redraw_health_bar()

func obtained_soul(enemy_name: StringName) -> void:
	"""Unlock an actor when its soul is obtained and play the unlock animation."""
	var could_unlock: bool = false
	for actor: Dictionary in possible_actors:
		if actor[&"name"] == enemy_name:
			actor[&"unlocked"] = true
			could_unlock = true
	if could_unlock:
		do_unlock_animation(enemy_name)

func do_unlock_animation(enemy_name: StringName) -> void:
	"""Play the hatch UI animation for a newly unlocked actor."""
	get_tree().paused = true
	player_ui.start_animation()
	player_ui.reset_panels_alpha()
	await player_ui.fade_in_window(player_ui.hatch_ui, 0.9)
	var panel_id: int = find_actor_id_by_name(enemy_name)
	await player_ui.do_panel_animation(panel_id)
	await player_ui.fade_out_window(player_ui.hatch_ui)
	player_ui.finish_animation()
	get_tree().paused = false

func find_actor_id_by_name(enemy_name: StringName) -> int:
	"""Return the index of an actor by name, or -1 if not found."""
	var i: int = 0
	for actor: Dictionary in possible_actors:
		if actor[&"name"] == enemy_name:
			return i
		i += 1
	return -1

func redraw_health_bar() -> void:
	"""Tween the health bar value and hue based on current health."""
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(health_bar, "value", player_health / max_health * 100.0, 0.3)
	var bg: StyleBoxFlat = health_bar.get_theme_stylebox(&"background", &"ProgressBar") as StyleBoxFlat
	var fill: StyleBoxFlat = health_bar.get_theme_stylebox(&"fill", &"ProgressBar") as StyleBoxFlat
	bg.bg_color.h = health_bar.value / 360.0
	fill.bg_color.h = health_bar.value / 360.0

func disconnect_signals() -> void:
	"""Disconnect signals from the current actor."""
	if current_actor and current_actor.player_took_damage.is_connected(took_damage):
		current_actor.player_took_damage.disconnect(took_damage)
	if current_actor and current_actor.soul_obtained.is_connected(obtained_soul):
		current_actor.soul_obtained.disconnect(obtained_soul)

func connect_signals() -> void:
	"""Connect signals from the current actor."""
	current_actor.player_took_damage.connect(took_damage)

func game_over() -> void:
	"""Transition to the game over scene."""
	SceneSwitcher.slide_to("uid://udfh2tbngavk")

# Internal
func _handle_movement() -> void:
	if current_actor == null:
		return
	var input_vector: Vector2 = Vector2.ZERO
	input_vector.x = Input.get_axis(&"move_left", &"move_right")
	input_vector.y = Input.get_axis(&"move_up", &"move_down")
	current_actor.move_actor(input_vector)

func _try_attack() -> void:
	# Fire one attack if held and not cooling down; schedule next after cooldown.
	if current_actor == null:
		return
	if !_attack_held or _cooling_down:
		return
	await _perform_attack()

func _perform_attack() -> void:
	# Execute one attack, then enforce cooldown before chaining.
	if current_actor == null:
		return

	current_actor.override_attack_anim = true
	var idx: int = 0
	var actor_cd: float = await current_actor.attack(idx)
	if current_actor.has_method(&"disable_hitbox"):
		current_actor.disable_hitbox(false)

	var cd: float = attack_cooldown_sec if attack_cooldown_sec > 0.0 else actor_cd
	cd = maxf(0.0, cd)

	_cooling_down = true
	await get_tree().create_timer(cd).timeout
	_cooling_down = false

	if _attack_held:
		_try_attack()

# Note: If any fullscreen UI overlays exist, set their mouse_filter = Control.MOUSE_FILTER_IGNORE when hidden
# to avoid swallowing clicks, since this script now polls Input each physics frame for robustness.
