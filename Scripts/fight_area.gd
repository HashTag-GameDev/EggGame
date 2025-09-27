extends Node2D
class_name FightArea

@export var is_boss_battle: bool = false ## Use boss music when arena starts.
@export var enemy_detector: Area2D ## Area2D that bounds enemies of this arena.
@export var player_detector: Area2D ## Trigger the player enters to start the arena.
@export var barriers: Array[StaticBody2D] ## Barriers raised on start and lowered on clear.

@export_category("Arena Logic")
@export var gate_damage_until_start: bool = true ## Disable enemy hurtboxes before start.
@export var force_vision_on_start: bool = true ## Mark enemies to always see the player once started.
@export var forced_detect_range: float = 1.0e9 ## For bosses that use detect_range (e.g., Pancake).

var enemies_remaining: Array[Node2D] = []
var area_complete: bool = false
var player_entered: bool = false

func _ready() -> void:
	assert(is_instance_valid(player_detector))
	assert(is_instance_valid(enemy_detector))
	player_detector.body_entered.connect(_on_player_detector_body_entered)
	enemy_detector.body_entered.connect(_on_enemy_area_body_entered)
	enemy_detector.body_exited.connect(_on_enemy_area_body_exited)
	
	# Initialize any enemies already overlapping at scene start
	if enemy_detector.monitoring:
		for b in enemy_detector.get_overlapping_bodies():
			var body := b as Node2D
			if body and _is_enemy(body):
				_register_enemy(body)
				if player_entered:
					_arm_enemy(body)
				else:
					_gate_enemy(body)

func _on_player_detector_body_entered(body: Node2D) -> void:
	"""Start the arena when the player enters."""
	if player_entered or not body.is_in_group("player"):
		return
	player_entered = true
	_raise_barriers()
	if is_boss_battle:
		MusicManager.fade_to(&"Music_3", 0.25)
	else:
		MusicManager.fade_to(&"Music_2", 0.5)
	for e in enemies_remaining:
		_arm_enemy(e)

func _on_enemy_area_body_entered(body: Node2D) -> void:
	if not _is_enemy(body):
		return
	_register_enemy(body)
	if player_entered:
		_arm_enemy(body)
	else:
		_gate_enemy(body)

func _on_enemy_area_body_exited(body: Node2D) -> void:
	if not _is_enemy(body):
		return
	enemies_remaining.erase(body)
	if _count_enemies_remaining() <= 0 and not area_complete:
		MusicManager.fade_to(&"Music_1", 0.25)
		_lower_barriers()
		area_complete = true

func _register_enemy(e: Node2D) -> void:
	if enemies_remaining.has(e):
		return
	enemies_remaining.append(e)

func _is_enemy(n: Node2D) -> bool:
	return n.is_in_group("enemy") and not n.is_in_group("player")

func _count_enemies_remaining() -> int:
	return enemies_remaining.size()

func _raise_barriers() -> void:
	for b in barriers:
		b.raise()

func _lower_barriers() -> void:
	for b in barriers:
		b.lower()

func _gate_enemy(e: Node2D) -> void:
	# Prevent taking damage before start.
	if not gate_damage_until_start:
		return
	var hb := _get_hurtbox(e)
	if hb:
		hb.set_deferred("monitoring", false)
		hb.set_deferred("monitorable", false)

func _arm_enemy(e: Node2D) -> void:
	# Re-enable damage and force omniscient vision.
	var hb := _get_hurtbox(e)
	if hb:
		hb.set_deferred("monitoring", true)
		hb.set_deferred("monitorable", true)
	if force_vision_on_start:
		if "always_see_player" in e:
			e.always_see_player = true
		# For custom bosses that don't use our AI state helpers.
		if "detect_range" in e:
			e.detect_range = forced_detect_range

func _get_hurtbox(e: Node) -> Area2D:
	# Prefer exported property, fallback to a child named "HurtBox2D".
	if "hurt_box" in e:
		return e.hurt_box as Area2D
	return e.get_node_or_null("HurtBox2D") as Area2D
