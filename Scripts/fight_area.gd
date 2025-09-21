extends Node2D
class_name FightArea

@export var is_boss_battle: bool = false
@export var enemy_detector: Area2D
@export var player_detector: Area2D
@export var barriers: Array[StaticBody2D]

var enemies_remaining: Array = []
var area_complete: bool = false
var player_entered: bool = false

func _ready() -> void:
	player_detector.body_entered.connect(_on_player_detector_body_entered)
	player_detector.body_exited.connect(_on_player_detector_body_exited)
	enemy_detector.body_entered.connect(_on_body_entered)
	enemy_detector.body_exited.connect(_on_body_exited)

func _on_player_detector_body_entered(body: Node2D) -> void:
	if !player_entered:
		if body.is_in_group("player"):
			player_entered = true
			raise_barriers()
			if is_boss_battle:
				MusicManager.fade_to(&"Music_3", 0.25)
			else:
				print("transition")
				MusicManager.fade_to(&"Music_2", 0.5)

func _on_body_entered(body: Node2D) -> void:
	if !body.is_in_group("player") and body.is_in_group("enemy"):
		enemies_remaining.append(body)

func _on_body_exited(body: Node2D) -> void:
	if !body.is_in_group("player") and body.is_in_group("enemy"):
		enemies_remaining.erase(body)
		if check_enemies_remaining() <= 0:
			lower_barriers()
			area_complete = true
			pass

func check_enemies_remaining() -> int:
	return enemies_remaining.size()

func _on_player_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		MusicManager.fade_to(&"Music_1", 0.25)

func raise_barriers() -> void:
	for barrier in barriers:
		barrier.raise()

func lower_barriers() -> void:
	for barrier in barriers:
		barrier.lower()
