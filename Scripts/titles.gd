extends Control

@export var base_scale: float = 1.0     
@export var amplitude: float = 0.15 
@export var speed: float = 1.5 

@onready var title: Sprite2D = $Title
@onready var sub_title: Sprite2D = $SubTitle

var _t := 0.0

func _ready() -> void:
	title.scale = Vector2.ONE * base_scale

func _process(delta: float) -> void:
	_t += delta * TAU * speed           # TAU = 2π (full cycle)
	var s := base_scale + amplitude * sin(_t)
	title.scale = Vector2(s, s)
	sub_title.scale = Vector2(s, s)
