extends Node2D

# Exports
@export var enemy_name: StringName ## Name that must match PlayerController.possible_actors[].name.
@export var dead_sprite: Texture2D ## Optional corpse sprite for visual flair.
@export var speed: float = 60.0 ## Homing speed toward the player's hurtbox.
@export var amplitude_y: float = 0.15
@export var speed_y: float = 1.5
@export var amplitude_s: float = 0.15
@export var speed_s: float = 1.5

@onready var _soul: Sprite2D = $MoveNode/EnemySoul
@onready var move_node: Node2D = $MoveNode


var _t_y: float = 0.0
var _t_s: float = 0.0
var _base_y: float = 0.0
var _base_scale: float = 1.0
var _collected: bool = false
var player_detected: bool = false

func _ready() -> void:
	$"Dead Enemy".texture = dead_sprite

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
	if player_detected:
		var player: Actor2D = AI.Blackboard.player_actor
		var _target = player.detection_area.global_position
		var dir: Vector2 = move_node.global_position.direction_to(_target)
		move_node.global_position += dir * speed * delta
		print(_target)

# Signals
func _on_detect_area_area_entered(_area: Area2D) -> void:
	"""Start homing when the player’s hurtbox is nearby."""
	if _area.get_parent() == _soul:
		return
	player_detected = true

func _on_touch_player_area_entered(_area: Area2D) -> void:
	"""Grant the soul to the player and free this node."""
	if _area.get_parent() == _soul:
		return
	if _collected:
		return
	_collected = true
	print(_area)

	# Unlock via the authoritative player actor
	var player: Node = AI.Blackboard.player_controller
	if player and player.has_method("obtained_soul"):
		if str(enemy_name).is_empty():
			push_warning("EnemySoul missing enemy_name; unlock will be skipped.")
		else:
			player.obtained_soul(enemy_name)

	# Fade and free
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	queue_free()
