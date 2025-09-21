extends RigidBody2D

@export var speed: float = 320.0
@export var travel_time: float = 0.9
@export var next_scene: PackedScene
@export var pass_velocity_forward: bool = true

@export var hit_box_2d: HitBox2D

# Direction picking — leave start_dir ZERO for random
@export var start_dir: Vector2 = Vector2.ZERO
@export var spread_deg: float = 360.0
@export var base_dir: Vector2 = Vector2.UP

# Visuals
@export var sprite_path: NodePath								# Sprite2D or AnimatedSprite2D
@export var flip_right_when_positive_x: bool = true				# flip X when moving right
@export var lock_body_rotation: bool = true						# keep physics body rotation fixed

# Sprite tilt based on vertical direction
@export var sprite_angle_up_deg: float = 0.0					# when moving up (y <= 0)
@export var sprite_angle_down_deg: float = 80.0					# when moving down (y > 0)
@export var sprite_angle_tween_time: float = 0.08				# 0 = snap, otherwise smooth tween

var _dir: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sprite: Node = null
var _timer_started: bool = false
var _angle_tween: Tween

func _ready() -> void:
	travel_time = randf_range(max(0.2, travel_time - 0.5), travel_time + 0.5)
	hit_box_2d.hit_hurt_box.connect(_on_hit_box_hit)
	_rng.randomize()
	if sprite_path != NodePath():
		_sprite = get_node_or_null(sprite_path)

	# 1) Pick direction
	if start_dir.length() > 0.001:
		_dir = start_dir.normalized()
	else:
		var spread : float = max(spread_deg, 0.0)
		if spread >= 359.9:
			var angle := _rng.randf_range(-PI, PI)
			_dir = Vector2.RIGHT.rotated(angle)
		else:
			var half := deg_to_rad(spread * 0.5)
			var ang := _rng.randf_range(-half, half)
			var b := Vector2.UP
			if base_dir.length() > 0.001:
				b = base_dir.normalized()
			_dir = b.rotated(ang)

	# 2) Set initial velocity
	linear_velocity = _dir * speed

	# 3) Set initial visuals
	_update_visual_flip()
	_update_sprite_angle(true)

	# 4) Lifetime → transform
	if not _timer_started:
		_timer_started = true
		var timer := get_tree().create_timer(travel_time)
		timer.timeout.connect(_transform_into_next)

func _physics_process(_dt: float) -> void:
	# keep body upright / not spinning
	if lock_body_rotation:
		rotation = 0.0
		angular_velocity = 0.0

	_update_visual_flip()
	_update_sprite_angle(false)

func _update_visual_flip() -> void:
	if _sprite == null:
		return
	var vx := linear_velocity.x
	if absf(vx) < 0.001:
		return

	var want_flip := (vx > 0.0)
	if not flip_right_when_positive_x:
		want_flip = not want_flip

	if _sprite is Sprite2D:
		(_sprite as Sprite2D).flip_h = want_flip
	elif _sprite is AnimatedSprite2D:
		(_sprite as AnimatedSprite2D).flip_h = want_flip

func _update_sprite_angle(force_snap: bool) -> void:
	if _sprite == null:
		return

	var vy := linear_velocity.y

	# choose up/down angle without ternary
	var target_deg := sprite_angle_up_deg
	if vy > 0.0:
		target_deg = sprite_angle_down_deg

	var target_rad := deg_to_rad(target_deg)

	# if visually mirrored (moving left), invert the tilt so it looks the same
	if _is_sprite_flipped():
		target_rad = -target_rad

	# apply to child sprite (not the body)
	if force_snap or sprite_angle_tween_time <= 0.0:
		if _sprite is Node2D:
			(_sprite as Node2D).rotation = target_rad
	else:
		if _angle_tween and _angle_tween.is_running():
			_angle_tween.kill()
		_angle_tween = create_tween()
		_angle_tween.tween_property(_sprite, "rotation", target_rad, sprite_angle_tween_time)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func _transform_into_next() -> void:
	sleeping = true
	if next_scene:
		var n := next_scene.instantiate()
		if n is Node2D:
			get_parent().add_child(n)
			n.global_position = global_position
			n.rotation = 0.0  # successor starts upright; tweak if desired

			if pass_velocity_forward:
				var v := linear_velocity
				if n.has_method("setup"):
					n.setup(v)
				elif n.has_method("set_velocity"):
					n.set_velocity(v)
				elif n is RigidBody2D:
					n.linear_velocity = v
				elif n is CharacterBody2D:
					n.velocity = v
	queue_free()

# Optional clean init from spawner
func setup(dir: Vector2, initial_speed: float = -1.0) -> void:
	if dir.length() > 0.001:
		start_dir = dir.normalized()
	if initial_speed > 0.0:
		speed = initial_speed

func _is_sprite_flipped() -> bool:
	if _sprite is Sprite2D:
		return (_sprite as Sprite2D).flip_h
	if _sprite is AnimatedSprite2D:
		return (_sprite as AnimatedSprite2D).flip_h
	return false

func _on_hit_box_hit(_area: HurtBox2D) -> void:
	
	queue_free()
