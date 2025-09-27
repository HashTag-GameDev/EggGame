extends CharacterBody2D

# Signals
signal slammed

# Exports (stats and tuning)
@export var health: float = 1000.0 ## Current health.
@export var max_health: float = 1000.0 ## Maximum health.
@export var detect_range: float = 360.0 ## Player detection range (px).
@export var jump_cooldown: float = 0.8 ## Cooldown after any attack (s).

# Exports (attack choreography)
@export var t_move: float = 0.30 ## Glide duration before slam (s).
@export var t_slam: float = 0.10 ## Slam duration (s).
@export var v_move: float = 260.0 ## Glide speed (px/s).
@export var v_slam: float = 520.0 ## Slam speed (px/s).

# Exports (accordion visuals)
@export var recoil_per_layer: float = 6.0 ## Accordion down offset per layer (px).
@export var overshoot_mult: float = 2.0 ## Accordion overshoot up multiplier.
@export var recoil_time: float = 0.07 ## Accordion down duration (s).
@export var spring_time: float = 0.12 ## Accordion up duration (s).
@export var settle_time: float = 0.10 ## Accordion settle duration (s).
@export var layer_stagger: float = 0.015 ## Stagger delay per layer (s).

# Exports (scene refs)
@export var hurt_box: HurtBox2D ## Enemy hurtbox; always active on layer 1.
@export var hit_box: HitBox2D ## Enemy hitbox; active only during slam, mask layer 2.
@export var pancake_nodes: Array[NodePath] = [] ## Pancake sprites bottom-to-top; index 0 is base.
@export var jump_sound: AudioStreamPlayer2D ## SFX for windup/jump.

# Exports (ranged volley)
@export var spawn_pos: Marker2D ## Projectile spawn marker (top pancake).
@export var syrup_scene: PackedScene ## Projectile scene to spawn.
@export var syrup_count: int = 3 ## Shots per volley.
@export var syrup_speed: float = 100.0 ## Initial projectile speed (px/s).
@export var ranged_attack_chance: float = 0.50 ## Chance to pick ranged over melee.
@export var aim_radius_px: float = 50.0 ## Aim jitter radius around player (px).

# Onready
@onready var health_bar: ProgressBar = $PlayerHealth

# State
enum State { IDLE, ATTACK, ATTACK2, COOLDOWN }
var state: State = State.IDLE
var _player: Node2D
var _dir_locked: Vector2 = Vector2.ZERO
var _cooldown_left: float = 0.0
var _attack_running: bool = false
var is_dying: bool = false

# Pancake visuals cache
var _pancakes: Array[Sprite2D] = []
var _orig_positions: Array[Vector2] = []

# RNG
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var is_ai_controlled: bool = true

func _ready() -> void:
	_rng.randomize()
	assert(is_instance_valid(hurt_box))
	hurt_box.took_hit.connect(took_damage)
	redraw_health_bar()

	_player = AI.Blackboard.player_actor

	# Cache pancake sprites and base positions
	for p: NodePath in pancake_nodes:
		var n: Node = get_node_or_null(p)
		if n is Sprite2D:
			_pancakes.append(n as Sprite2D)
		else:
			push_warning("%s is not a Sprite2D" % [str(p)])
	_orig_positions.resize(_pancakes.size())
	for idx: int in _pancakes.size():
		_orig_positions[idx] = _pancakes[idx].position

	if spawn_pos == null:
		push_warning("spawn_pos not assigned; ranged shots cannot spawn.")
	if syrup_scene == null:
		push_warning("syrup_scene not assigned; ranged shots will be skipped.")

	set_state(State.IDLE)

func set_state(new_state: State) -> void:
	"""Set FSM state and do entry actions."""
	state = new_state
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			_cooldown_left = 0.0
		State.ATTACK:
			if not _attack_running:
				_attack_sequence()
		State.ATTACK2:
			if not _attack_running:
				_attack2_sequence()
		State.COOLDOWN:
			velocity = Vector2.ZERO
			_cooldown_left = jump_cooldown

func _physics_process(delta: float) -> void:
	if _player == null:
		_player = AI.Blackboard.player_actor

	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			if _player and _is_player_in_range():
				if syrup_scene and _rng.randf() < ranged_attack_chance:
					set_state(State.ATTACK2)
				else:
					set_state(State.ATTACK)
		State.ATTACK, State.ATTACK2:
			pass # driven by async sequences
		State.COOLDOWN:
			velocity = Vector2.ZERO
			_cooldown_left -= delta
			if _cooldown_left <= 0.0:
				# Re-evaluate after cooldown
				if _player and _is_player_in_range():
					if syrup_scene and _rng.randf() < ranged_attack_chance:
						set_state(State.ATTACK2)
					else:
						set_state(State.ATTACK)
				else:
					set_state(State.IDLE)

	move_and_slide()

# Lifecycle helpers

func redraw_health_bar() -> void:
	"""Animate and recolor the health bar from current health values."""
	if not is_instance_valid(health_bar):
		return
	var t: Tween = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(health_bar, "value", health / max_health * 100.0, 0.3)
	var bg: StyleBoxFlat = health_bar.get_theme_stylebox(&"background", &"ProgressBar") as StyleBoxFlat
	var fill: StyleBoxFlat = health_bar.get_theme_stylebox(&"fill", &"ProgressBar") as StyleBoxFlat
	bg.bg_color.h = health_bar.value / 360.0
	fill.bg_color.h = health_bar.value / 360.0

func took_damage(colliding_hit_box: HitBox2D) -> void:
	"""Apply damage from a colliding hit box; triggers defeat at zero."""
	if is_dying:
		return
	health -= colliding_hit_box.damage
	redraw_health_bar()
	if health <= 0.0:
		game_over()

func game_over() -> void:
	"""Handle boss defeat."""
	SceneSwitcher.slide_to("uid://udfh2tbngavk")

# Attack sequences

func _attack_sequence() -> void:
	_attack_running = true
	_lock_dir_toward_player()

	# Windup
	velocity = Vector2.ZERO
	_run_accordion_stack()
	var gate: float = _recoil_gate_seconds()
	if is_instance_valid(jump_sound):
		jump_sound.play()
	await get_tree().create_timer(gate).timeout
	await get_tree().physics_frame

	# Glide
	velocity = _dir_locked * v_move
	await get_tree().create_timer(t_move).timeout

	# Slam window (enable hitbox only here)
	emit_signal(&"slammed")
	_enable_hitbox()
	velocity = _dir_locked * v_slam
	await get_tree().create_timer(t_slam).timeout
	_disable_hitbox()

	# Recover
	velocity = Vector2.ZERO
	set_state(State.COOLDOWN)
	_attack_running = false

func _attack2_sequence() -> void:
	_attack_running = true
	_lock_dir_toward_player()

	# Windup (no damage)
	velocity = Vector2.ZERO
	_run_accordion_stack()
	var gate: float = _recoil_gate_seconds()
	if is_instance_valid(jump_sound):
		jump_sound.play()
	await get_tree().create_timer(gate).timeout
	await get_tree().physics_frame

	# Fire aimed volley
	_spawn_syrup_volley()

	# Cooldown
	velocity = Vector2.ZERO
	set_state(State.COOLDOWN)
	_attack_running = false

# Ranged

func _spawn_syrup_volley() -> void:
	"""Spawn syrup_count projectiles aimed near the player with jitter."""
	if syrup_scene == null or spawn_pos == null:
		return

	var origin: Vector2 = spawn_pos.global_position
	var center: Vector2 = origin
	if _player:
		center = _player.hurt_box.global_position if ("hurt_box" in _player and is_instance_valid(_player.hurt_box)) else _player.global_position

	var count: int = max(syrup_count, 1)
	for shot_idx: int in count:
		var target: Vector2 = center + _random_point_in_circle(aim_radius_px)
		var dir: Vector2 = target - origin
		if dir.length() <= 0.001:
			continue
		dir = dir.normalized()

		var drop: Node = syrup_scene.instantiate()
		if drop.has_method(&"setup"):
			drop.call(&"setup", dir, syrup_speed) # syrup_projectile uses start_dir/speed in _ready()
		if drop is Node2D:
			var n2d: Node2D = drop as Node2D
			n2d.global_position = origin
			add_sibling(n2d)

# Internal helpers

func _lock_dir_toward_player() -> void:
	var v: Vector2 = Vector2.ZERO
	if _player:
		v = _player.global_position - global_position
	_dir_locked = v.normalized() if v.length() > 0.001 else Vector2.ZERO

func _is_player_in_range() -> bool:
	if not _player:
		return false
	return (_player.global_position - global_position).length() <= detect_range

func _recoil_gate_seconds() -> float:
	var n: int = max(_pancakes.size(), 1)
	return recoil_time + layer_stagger * float(n - 1)

func _run_accordion_stack() -> void:
	if _pancakes.size() <= 1:
		return
	var t: Tween = create_tween()
	t.set_parallel(true)
	var n: int = _pancakes.size()
	for idx: int in n:
		var spr: Sprite2D = _pancakes[idx]
		var base: Vector2 = _orig_positions[idx]
		if idx == 0:
			t.parallel().tween_property(spr, "position", base, settle_time)\
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
			continue
		var depth: float = float(idx)
		var down: Vector2 = Vector2(0.0, recoil_per_layer * depth)
		var up: Vector2 = Vector2(0.0, -recoil_per_layer * float(n - idx) * overshoot_mult)
		var delay: float = layer_stagger * depth
		t.parallel().tween_property(spr, "position", base + down, recoil_time)\
			.set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		t.parallel().tween_property(spr, "position", base + up, spring_time)\
			.set_delay(delay + recoil_time * 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.parallel().tween_property(spr, "position", base, settle_time)\
			.set_delay(delay + recoil_time + spring_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func _enable_hitbox() -> void:
	if not is_instance_valid(hit_box):
		return
	hit_box.set_deferred(&"monitoring", true)
	hit_box.set_deferred(&"monitorable", true)

func _disable_hitbox() -> void:
	if not is_instance_valid(hit_box):
		return
	hit_box.set_deferred(&"monitoring", false)
	hit_box.set_deferred(&"monitorable", false)

# Math

func _random_point_in_circle(radius: float) -> Vector2:
	var a: float = _rng.randf_range(0.0, TAU)
	var r: float = radius * sqrt(_rng.randf())
	return Vector2(cos(a), sin(a)) * r

# Explanation:
# The boss keeps its HurtBox2D always active on layer 1 and gates its HitBox2D so it only enables during the slam window.
# The hitbox gate disables monitoring, mask, and all CollisionShape2D children outside of slam, preventing passive contact damage.
# The ranged attack aims three shots at random points within a 50px circle around the player; syrup_projectile reads direction/speed in _ready().
