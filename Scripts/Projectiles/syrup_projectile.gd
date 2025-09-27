extends RigidBody2D

# Exports
@export var speed: float = 320.0 ## Initial speed in pixels/sec.
@export var travel_time: float = 0.9 ## Lifetime before transforming (seconds).
@export var next_scene: PackedScene ## Optional scene to spawn on expiration.
@export var pass_velocity_forward: bool = true ## Pass current velocity to the next scene.

@export var hit_box_2d: HitBox2D ## Hit box used to damage the player.

# Direction picking — leave start_dir ZERO for random
@export var start_dir: Vector2 = Vector2.ZERO ## If non-zero, used as initial direction.
@export var spread_deg: float = 360.0 ## Random spread (deg) around base_dir when start_dir is zero.
@export var base_dir: Vector2 = Vector2.UP ## Base direction for spread mode.

# Visuals
@export var sprite_path: NodePath ## Child Sprite2D/AnimatedSprite2D for flip/tilt visuals.
@export var flip_right_when_positive_x: bool = true ## Flip sprite when moving right.
@export var lock_body_rotation: bool = true ## Keep physics body upright (no spin).

# Sprite tilt based on vertical direction
@export var sprite_angle_up_deg: float = 0.0 ## Tilt when moving up (degrees).
@export var sprite_angle_down_deg: float = 80.0 ## Tilt when moving down (degrees).
@export var sprite_angle_tween_time: float = 0.08 ## Tween time for tilt (0 = snap).

# Internals
var _dir: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sprite: Node = null
var _timer_started: bool = false
var _angle_tween: Tween

func _ready() -> void:
	assert(is_instance_valid(hit_box_2d))
	_rng.randomize()
	travel_time = randf_range(max(0.2, travel_time - 0.5), travel_time + 0.5)
	hit_box_2d.hit_hurt_box.connect(_on_hit_box_hit)
	if sprite_path != NodePath():
		_sprite = get_node_or_null(sprite_path)

	_set_enemy_hitbox_masks() # enemy hitboxes should mask 2 (player hurtboxes)

	# 1) Direction (prefer start_dir)
	if start_dir.length() > 0.001:
		_dir = start_dir.normalized()
	else:
		var spread: float = max(spread_deg, 0.0)
		if spread >= 359.9:
			var angle: float = _rng.randf_range(-PI, PI)
			_dir = Vector2.RIGHT.rotated(angle)
		else:
			var half: float = deg_to_rad(spread * 0.5)
			var ang: float = _rng.randf_range(-half, half)
			var b: Vector2 = base_dir.normalized() if base_dir.length() > 0.001 else Vector2.UP
			_dir = b.rotated(ang)

	# 2) Velocity
	linear_velocity = _dir * speed

	# 3) Visuals
	_update_visual_flip()
	_update_sprite_angle(true)

	# 4) Lifetime
	if not _timer_started:
		_timer_started = true
		var timer: SceneTreeTimer = get_tree().create_timer(travel_time)
		timer.timeout.connect(_transform_into_next)

func _physics_process(_dt: float) -> void:
	if lock_body_rotation:
		rotation = 0.0
		angular_velocity = 0.0
	_update_visual_flip()
	_update_sprite_angle(false)

func _set_enemy_hitbox_masks() -> void:
	# Clear all mask bits, then enable only layer 2 (player hurtboxes).
	for i: int in range(1, 33):
		hit_box_2d.set_collision_mask_value(i, false)
	hit_box_2d.set_collision_mask_value(2, true)

func _update_visual_flip() -> void:
	if _sprite == null:
		return
	var vx: float = linear_velocity.x
	if absf(vx) < 0.001:
		return
	var want_flip: bool = vx > 0.0
	if not flip_right_when_positive_x:
		want_flip = not want_flip
	if _sprite is Sprite2D:
		(_sprite as Sprite2D).flip_h = want_flip
	elif _sprite is AnimatedSprite2D:
		(_sprite as AnimatedSprite2D).flip_h = want_flip

func _update_sprite_angle(force_snap: bool) -> void:
	if _sprite == null:
		return
	var vy: float = linear_velocity.y
	var target_deg: float = sprite_angle_up_deg
	if vy > 0.0:
		target_deg = sprite_angle_down_deg
	var target_rad: float = deg_to_rad(target_deg)
	if _is_sprite_flipped():
		target_rad = -target_rad
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
		var n: Node = next_scene.instantiate()
		if n is Node2D:
			get_parent().add_child(n)
			(n as Node2D).global_position = global_position
			(n as Node2D).rotation = 0.0
			if pass_velocity_forward:
				var v: Vector2 = linear_velocity
				if n.has_method("setup"):
					n.call("setup", v)
				elif n.has_method("set_velocity"):
					n.call("set_velocity", v)
				elif n is RigidBody2D:
					(n as RigidBody2D).linear_velocity = v
				elif n is CharacterBody2D:
					(n as CharacterBody2D).velocity = v
	queue_free()

# Public API

func setup(dir: Vector2, initial_speed: float = -1.0) -> void:
	"""Set direction and optional speed before entering the tree."""
	if dir.length() > 0.001:
		start_dir = dir.normalized()
	if initial_speed > 0.0:
		speed = initial_speed

func set_velocity(vel: Vector2) -> void:
	"""Alternative setup: pass a velocity vector directly."""
	var s: float = vel.length()
	if s > 0.001:
		start_dir = vel / s
		speed = s

# Internal

func _is_sprite_flipped() -> bool:
	if _sprite is Sprite2D:
		return (_sprite as Sprite2D).flip_h
	if _sprite is AnimatedSprite2D:
		return (_sprite as AnimatedSprite2D).flip_h
	return false

func _on_hit_box_hit(_area: HurtBox2D) -> void:
	queue_free()

# Explanation: This sets the projectile hitbox mask to only collide with layer 2 (player hurtboxes), then applies velocity from start_dir.
# Visuals update each frame, and after travel_time it can spawn next_scene and free itself.
