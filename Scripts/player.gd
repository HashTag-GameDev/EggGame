extends CharacterBody2D
class_name Player

@export var speed: float = 150.0
@export var animated_sprite: AnimatedSprite2D
@export var player_ui: CanvasLayer

func _ready():
	AI.Blackboard.player = self

func _physics_process(_delta: float) -> void:
	handle_movement()
	handle_animation()

func handle_movement() -> void:
	var input_vector: Vector2 = Vector2.ZERO
	
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	
	input_vector = input_vector.normalized()
	
	velocity = input_vector * speed
	
	move_and_slide()

func handle_animation() -> void:
	var input_vector: Vector2 = Vector2.ZERO
	
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	
	input_vector = input_vector.normalized()
	
	if input_vector.is_zero_approx():
		match animated_sprite.animation:
			"walking_front":
				animated_sprite.animation = "idle_front"
			"walking_back":
				animated_sprite.animation = "idle_back"
			"walking_side":
				animated_sprite.animation = "idle_side"
	elif input_vector.y > 0:
		animated_sprite.play("walking_front")
	elif input_vector.y < 0:
		animated_sprite.play("walking_back")
	elif input_vector.x > 0:
		animated_sprite.play("walking_side")
		animated_sprite.flip_h = false
	elif input_vector.x < 0:
		animated_sprite.play("walking_side")
		animated_sprite.flip_h = true

func _on_detection_area_entered(area: Area2D) -> void:
	if area.is_in_group("spawn_area"):
		var hint_ui = player_ui.hint_ui
		player_ui.fade_in_window(hint_ui)

func _on_detection_area_exited(area: Area2D) -> void:
	if area.is_in_group("spawn_area"):
		var hint_ui = player_ui.hint_ui
		player_ui.fade_out_window(hint_ui)
