extends Node2D

# Exports
@export var enemy_name: StringName ## Name that must match PlayerController.possible_actors[].name.
@export var sprite: Texture2D ## Optional corpse sprite for visual flair.
@export var speed: float = 60.0 ## Homing speed toward the player's hurtbox.
@export var amplitude_y: float = 0.15
@export var speed_y: float = 1.5
@export var amplitude_s: float = 0.15
@export var speed_s: float = 1.5

# Onready
@onready var _soul: Sprite2D = $EnemySoul
@onready var _dead: Sprite2D = $"Dead Enemy"
@onready var _detect: Area2D = $EnemySoul/DetectArea
@onready var _touch: Area2D = $EnemySoul/TouchPlayer

# State
var _target_hurtbox: Area2D
var _t_y: float = 0.0
var _t_s: float = 0.0
var _base_y: float = 0.0
var _base_scale: float = 1.0
var _collected: bool = false

# Lifecycle
func _ready() -> void:
	# Be tolerant of missing visuals; do not hard-assert
	if is_instance_valid(_soul):
		_base_y = _soul.position.y
		_base_scale = _soul.scale.x
	if sprite and is_instance_valid(_dead):
		_dead.texture = sprite

	# Ensure trigger areas are active and connected
	if is_instance_valid(_detect) and not _detect.area_entered.is_connected(_on_detect_area_area_entered):
		_detect.monitoring = true
		_detect.monitorable = true
		_detect.area_entered.connect(_on_detect_area_area_entered)
	if is_instance_valid(_touch) and not _touch.area_entered.is_connected(_on_touch_player_area_entered):
		_touch.monitoring = true
		_touch.monitorable = true
		_touch.area_entered.connect(_on_touch_player_area_entered)

# Process
func _physics_process(delta: float) -> void:
	if _collected:
		return

	# Bob visuals if sprite exists
	if is_instance_valid(_soul):
		_t_y += delta * TAU * speed_y
		_t_s += delta * TAU * speed_s
		_soul.position.y = _base_y + amplitude_y * sin(_t_y)
		var s: float = _base_scale + amplitude_s * sin(_t_s)
		_soul.scale = Vector2(s, s)
		_soul.rotation += delta * 6.0

	# Home toward player
	if is_instance_valid(_target_hurtbox):
		var dir: Vector2 = global_position.direction_to(_target_hurtbox.global_position)
		global_position += dir * speed * delta

# Signals
func _on_detect_area_area_entered(_area: Area2D) -> void:
	"""Start homing when the player’s hurtbox is nearby."""
	var player: Actor2D = AI.Blackboard.player_actor
	if player and player.hurt_box:
		_target_hurtbox = player.hurt_box

func _on_touch_player_area_entered(_area: Area2D) -> void:
	"""Grant the soul to the player and free this node."""
	if _collected:
		return
	_collected = true

	# Unlock via the authoritative player actor
	var player: Node = AI.Blackboard.player_controller
	if player and player.has_method("obtained_soul"):
		print(player)
		if str(enemy_name).is_empty():
			push_warning("EnemySoul missing enemy_name; unlock will be skipped.")
		else:
			player.obtained_soul(enemy_name)

	# Fade and free
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	queue_free()
