extends CharacterBody2D

@export var speed: float = 150.0

func _physics_process(_delta: float) -> void:
	handle_movement()

func handle_movement() -> void:
	var input_vector: Vector2 = Vector2.ZERO
	
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	
	input_vector = input_vector.normalized()
	
	velocity = input_vector * speed
	
	move_and_slide()
