extends Node
class_name PlayerController

# Exports
@export_category("Health")
@export var max_health: float = 100.0 ## Max player health.
@export var player_defense: float = 0.0 ## Flat damage reduction.

@export_category("Combat")
@export var attack_cooldown_sec: float = 0.25 ## Fixed attack interval; 0.0 uses actor's own cooldown.

@export_category("Spawn")
@export var initial_player_spawn: Marker2D ## Spawn marker for the first player actor.
@export var spawn_parent: Node2D ## Parent node to hold the player actor.

@export_category("UI")
@export var player_ui: PlayerUI ## Player HUD/UI controller.
@export var health_bar: ProgressBar ## Health bar UI.

# State
var current_actor: Actor2D
var player_health: float = 0.0
var _changing_actor: bool = false
var _attack_held: bool = false
var _cooling_down: bool = false

# Hatch UI state
var _hatch_open_actual: bool = false
var _hatch_tween: Tween
var _paused_by_hatch: bool = false

# Data
@onready var possible_actors: Array[Dictionary] = [
	{ &"name": &"Egg", &"unlocked": true, &"scene": preload("res://Scenes/Actors/egg_actor.tscn"), &"group": "egg" },
	{ &"name": &"Pea", &"unlocked": false, &"scene": preload("res://Scenes/Actors/pea_enemy.tscn"), &"group": "pea" },
	{ &"name": &"Muffin", &"unlocked": true, &"scene": preload("res://Scenes/Actors/muffin_enemy.tscn"), &"group": "muffin" },
]

# Lifecycle
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # read inputs during pause (UI only)

	assert(is_instance_valid(initial_player_spawn))
	assert(is_instance_valid(spawn_parent))
	assert(is_instance_valid(player_ui))
	assert(is_instance_valid(health_bar))
	assert(is_instance_valid(player_ui.hatch_ui))

	player_ui.hatch_ui.process_mode = Node.PROCESS_MODE_ALWAYS

	player_health = max_health
	health_bar.value = player_health
	_redraw_health_bar()

	_init_hatch_ui_hidden()

	if current_actor == null:
		_create_new_actor(0, initial_player_spawn.global_position)

	AI.Blackboard.player_controller = self

	# Optional: listen to UI hover to switch actor while menu is open
	if player_ui.has_signal("hatch_actor_hovered"):
		player_ui.hatch_actor_hovered.connect(_on_hatch_actor_hovered)

func _input(event: InputEvent) -> void:
	# Hatch menu open/close
	if event.is_action_pressed(&"hatch_menu"):
		_open_hatch_ui()
	elif event.is_action_released(&"hatch_menu"):
		_close_hatch_ui()

	# Attack press/release (track while paused too)
	if event.is_action_pressed(&"attack_1"):
		_attack_held = true
		_try_attack()
	elif event.is_action_released(&"attack_1"):
		_attack_held = false

func _physics_process(_delta: float) -> void:
	if get_tree().paused:
		return
	_resync_inputs_after_pause()
	_handle_movement()

func _resync_inputs_after_pause() -> void:
	_attack_held = Input.is_action_pressed(&"attack_1")

# Public API
func took_damage(damage: float) -> void:
	"""Apply damage to the player after defense, handle death."""
	var final_damage: float = maxf(0.0, damage - player_defense)
	player_health -= final_damage
	if player_health <= 0.0:
		_game_over()
	_redraw_health_bar()

func obtained_soul(enemy_name: StringName) -> void:
	"""Unlock an actor by soul name and play its unlock animation."""
	if _unlock_actor_by_name(enemy_name):
		_do_unlock_animation(enemy_name)
	else:
		push_warning("Unknown soul name: %s" % [str(enemy_name)])

func request_switch_actor_by_index(id: int) -> void:
	"""Request switching to an unlocked actor by index (no UI assumptions)."""
	if id < 0 or id >= possible_actors.size():
		return
	if !bool(possible_actors[id][&"unlocked"]):
		return
	var pos: Vector2 = current_actor.global_position if current_actor else initial_player_spawn.global_position
	_create_new_actor(id, pos)

# Internal — Hatch UI
func _init_hatch_ui_hidden() -> void:
	var ui: Control = player_ui.hatch_ui
	ui.modulate.a = player_ui.transparent
	ui.visible = false
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hatch_open_actual = false

func _kill_hatch_tween() -> void:
	if is_instance_valid(_hatch_tween):
		_hatch_tween.kill()
	_hatch_tween = null

func _open_hatch_ui() -> void:
	if _hatch_open_actual:
		return
	_kill_hatch_tween()
	var ui: Control = player_ui.hatch_ui

	if !get_tree().paused:
		get_tree().paused = true
		_paused_by_hatch = true

	ui.visible = true
	ui.mouse_filter = Control.MOUSE_FILTER_STOP
	_hatch_open_actual = true

	_hatch_tween = create_tween()
	_hatch_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_hatch_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hatch_tween.tween_property(ui, "modulate:a", player_ui.opaque, player_ui.fade_in_speed)
	await _hatch_tween.finished
	_hatch_tween = null

func _close_hatch_ui() -> void:
	if !_hatch_open_actual:
		return
	_kill_hatch_tween()
	var ui: Control = player_ui.hatch_ui

	_hatch_tween = create_tween()
	_hatch_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_hatch_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_hatch_tween.tween_property(ui, "modulate:a", player_ui.transparent, player_ui.fade_out_speed)
	await _hatch_tween.finished
	_hatch_tween = null

	ui.visible = false
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hatch_open_actual = false

	if _paused_by_hatch:
		get_tree().paused = false
		_paused_by_hatch = false
		_resync_inputs_after_pause()

# Internal — UI callbacks
func _on_hatch_actor_hovered(id: int) -> void:
	# Called by UI when hovering a panel; requires UI to be Control-based to work while paused.
	if !_hatch_open_actual:
		return
	if id < 0 or id >= possible_actors.size():
		return
	if !bool(possible_actors[id][&"unlocked"]):
		return
	var pos: Vector2 = current_actor.global_position if current_actor else initial_player_spawn.global_position
	_create_new_actor(id, pos)

# Internal — Spawn/Unlock
func _create_new_actor(id: int, spawn_pos: Vector2) -> void:
	if _changing_actor:
		return
	_changing_actor = true

	if id < possible_actors.size():
		if current_actor:
			_disconnect_signals()
			current_actor.hatch()
		var new_actor: Node = possible_actors[id][&"scene"].instantiate()
		if new_actor is Actor2D:
			current_actor = new_actor
			current_actor.is_ai_controlled = false
			current_actor.global_position = spawn_pos
			current_actor.activate_camera()
			spawn_parent.add_child(current_actor)
			_connect_signals()
			AI.Blackboard.player_actor = current_actor
			if current_actor.has_method(&"disable_hitbox"):
				current_actor.disable_hitbox(false)
	_changing_actor = false

func _do_unlock_animation(enemy_name: StringName) -> void:
	get_tree().paused = true
	player_ui.start_animation()
	player_ui.reset_panels_alpha()
	await player_ui.fade_in_window(player_ui.hatch_ui, 0.9)
	var panel_id: int = _find_actor_id_by_name(enemy_name)
	await player_ui.do_panel_animation(panel_id)
	await player_ui.fade_out_window(player_ui.hatch_ui)
	player_ui.finish_animation()
	get_tree().paused = false

func _find_actor_id_by_name(enemy_name: StringName) -> int:
	for i: int in possible_actors.size():
		var nm: String = str(possible_actors[i][&"name"])
		if nm == str(enemy_name):
			return i
	return -1

func _unlock_actor_by_name(enemy_name: StringName) -> bool:
	for i: int in possible_actors.size():
		var nm: String = str(possible_actors[i][&"name"])
		if nm == str(enemy_name):
			possible_actors[i][&"unlocked"] = true
			return true
	return false

# Internal — UI/Signals/Gameplay
func _redraw_health_bar() -> void:
	var t: Tween = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(health_bar, "value", player_health / max_health * 100.0, 0.3)
	var bg: StyleBoxFlat = health_bar.get_theme_stylebox(&"background", &"ProgressBar") as StyleBoxFlat
	var fill: StyleBoxFlat = health_bar.get_theme_stylebox(&"fill", &"ProgressBar") as StyleBoxFlat
	bg.bg_color.h = health_bar.value / 360.0
	fill.bg_color.h = health_bar.value / 360.0

func _connect_signals() -> void:
	current_actor.player_took_damage.connect(took_damage)
	if current_actor.has_signal("soul_obtained"):
		current_actor.soul_obtained.connect(obtained_soul)

func _disconnect_signals() -> void:
	if current_actor and current_actor.player_took_damage.is_connected(took_damage):
		current_actor.player_took_damage.disconnect(took_damage)
	if current_actor and current_actor.has_signal("soul_obtained") and current_actor.soul_obtained.is_connected(obtained_soul):
		current_actor.soul_obtained.disconnect(obtained_soul)

func _game_over() -> void:
	SceneSwitcher.slide_to("uid://udfh2tbngavk")

func _handle_movement() -> void:
	if current_actor == null:
		return
	var v: Vector2 = Vector2.ZERO
	v.x = Input.get_axis(&"move_left", &"move_right")
	v.y = Input.get_axis(&"move_up", &"move_down")
	current_actor.move_actor(v)

func _try_attack() -> void:
	if current_actor == null or !_attack_held or _cooling_down:
		return
	await _perform_attack()

func _perform_attack() -> void:
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
