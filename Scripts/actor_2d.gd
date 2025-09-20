extends CharacterBody2D
class_name Actor2D

@export var sprite: AnimatedSprite2D = null
#@export var hurt_box: HurtBox2D = null

@export_category("Detection")
@export var vision_range := 50.0
@export var attack_range := 50.0

var player: Player

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
