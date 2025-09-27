extends Control

@export var speed: float = 0.5

@onready var title_bg_2: Sprite2D = $TitleBG2
@onready var sub_title_2: Sprite2D = $SubTitle2
@onready var title_bg_1: Sprite2D = $TitleBG1
@onready var sub_title_1: Sprite2D = $SubTitle1
@onready var title_1: Sprite2D = $Title1

var _t := 0.0
var base_scale: float = 1.0 
var amplitude: float = 0.15

func _ready() -> void:
	if randi() % 2 == 0:
		show_title_one()
	else:
		show_title_two()

func _process(delta: float) -> void:
	_t += delta * TAU * speed           # TAU = 2π (full cycle)
	var s := base_scale + amplitude * sin(_t)
	title_1.scale = Vector2(s, s)
	sub_title_1.scale = Vector2(s, s)
	sub_title_2.scale = Vector2(s, s)

func show_title_one() -> void:
	base_scale = 1.2
	amplitude = 0.15
	title_1.visible = true
	title_bg_1.visible = true
	sub_title_1.visible = true
	title_bg_2.visible = false
	sub_title_2.visible = false

func show_title_two() -> void:
	base_scale = 0.3
	amplitude = 0.09
	title_1.visible = false
	title_bg_1.visible = false
	sub_title_1.visible = false
	title_bg_2.visible = true
	sub_title_2.visible = true
