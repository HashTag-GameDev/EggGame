extends Node2D

@export var enemy_name: StringName
@export var sprite: Texture2D
@export var sprite_2d: Sprite2D
@export var base_y: float = 1.0
@export var base_scale: float = 1.0
@export var amplitude_y: float = 0.15
@export var speed_y: float = 1.5
@export var amplitude_s: float = 0.15
@export var speed_s: float = 1.5
@export var speed := 10.0

var soul: Sprite2D
var target_area: Area2D

var t_y := 0.0
var t_s := 0.0

func _ready() -> void:
	soul = $"EnemySoul"
	base_y = soul.position.y
	base_scale = soul.scale.x
	var dead_enemy: Sprite2D = $"Dead Enemy"
	if sprite != null:
		dead_enemy.texture = sprite

func _physics_process(delta: float) -> void:
	if !target_area:
		t_y += delta * TAU * speed_y
		var y := base_y + amplitude_y * sin(t_y)
		soul.position.y = y
	else:
		soul.global_position += soul.global_position.direction_to(target_area.global_position).normalized() * speed * delta
	t_s += delta * TAU * speed_s
	var s := base_scale + amplitude_s * sin(t_s)
	soul.scale = Vector2(s, s)
	soul.rotation += delta * 6

func _on_detect_area_area_entered(area: Area2D) -> void:
	if area.get_parent().is_in_group("player"):
		target_area = area.get_parent().get_node_or_null("HurtBox2D")

func _on_touch_player_area_entered(area: Area2D) -> void:
	if area.get_parent().is_in_group("player"):
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		await tween.finished
		if area.get_parent().has_method("obtain_soul"):
			area.get_parent().obtain_soul(enemy_name)
		queue_free()
