extends CharacterBody2D

# --- Scene refs ---
@export var pancake_nodes: Array[NodePath] = []	# index 0 = base/bottom sprite

# --- Targeting / loop control ---
@export var detect_range: float = 360.0
@export var jump_cooldown: float = 0.8

# --- Attack sequencing (seconds) ---
@export var t_move: float = 0.30	# glide window (starts AFTER recoil fully completes)
@export var t_slam: float = 0.10	# fast burst, then stop

# --- Speeds (pixels/sec) ---
@export var v_move: float = 260.0
@export var v_slam: float = 520.0

# --- Accordion tuning ---
@export var recoil_per_layer: float = 6.0
@export var overshoot_mult: float = 2.0
@export var recoil_time: float = 0.07
@export var spring_time: float = 0.12
@export var settle_time: float = 0.10
@export var layer_stagger: float = 0.015

# --- Ranged (Attack 2) exports ---
@export var spawn_pos: Marker2D
@export var syrup_scene: PackedScene                    # <-- assign your syrup drop scene here
@export var syrup_count: int = 5                        # how many drops per volley
@export var syrup_spread_deg: float = 35.0              # total fan spread (centered on straight up)
@export var syrup_speed: float = 320.0                  # initial speed of each drop
@export var syrup_spawn_offset: Vector2 = Vector2(0, -8)# small offset from top sprite
@export var ranged_attack_chance: float = 0.45          # chance to pick ranged over melee when in range

# --- Runtime state ---
enum State { IDLE, ATTACK, ATTACK2, COOLDOWN }
var state: State = State.IDLE

var _player: Node2D
var _dir_locked: Vector2 = Vector2.ZERO
var _cooldown_left: float = 0.0
var _attack_running: bool = false

var _pancakes: Array[Sprite2D] = []
var _orig_positions: Array[Vector2] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

signal slammed

func _ready() -> void:
	_rng.randomize()

	_player = AI.Blackboard.player_actor
	if _player == null:
		push_warning("Player path not set.")

	for p in pancake_nodes:
		var s := get_node_or_null(p)
		if s is Sprite2D:
			_pancakes.append(s)
		else:
			push_warning("NodePath %s is not a Sprite2D" % [str(p)])

	_orig_positions.resize(_pancakes.size())
	for i in _pancakes.size():
		_orig_positions[i] = _pancakes[i].position

	set_state(State.IDLE)

func set_state(new_state: State) -> void:
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
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			if _player and _is_player_in_range():
				# pick melee vs ranged
				if syrup_scene and _rng.randf() < ranged_attack_chance:
					set_state(State.ATTACK2)
				else:
					set_state(State.ATTACK)

		State.ATTACK:
			# handled inside awaited sequence
			pass

		State.ATTACK2:
			# handled inside awaited sequence
			pass

		State.COOLDOWN:
			velocity = Vector2.ZERO
			_cooldown_left -= delta
			if _cooldown_left <= 0.0:
				if _player and _is_player_in_range():
					if syrup_scene and _rng.randf() < ranged_attack_chance:
						set_state(State.ATTACK2)
					else:
						set_state(State.ATTACK)
				else:
					set_state(State.IDLE)

	move_and_slide()

# --- Whole melee attack (unchanged) ---
func _attack_sequence() -> void:
	_attack_running = true

	# lock direction now
	if _player:
		var v := (_player.global_position - global_position)
		_dir_locked = v.normalized() if v.length() > 0.001 else Vector2.ZERO
	else:
		_dir_locked = Vector2.ZERO

	# 1) JUMP (windup): start accordion immediately; keep velocity ZERO
	velocity = Vector2.ZERO
	_run_accordion_stack()

	var recoil_gate := _recoil_gate_seconds()
	await get_tree().create_timer(recoil_gate).timeout
	await get_tree().physics_frame

	# 2) MOVE: glide
	var timer_move := get_tree().create_timer(t_move)
	while timer_move.time_left > 0.0:
		velocity = _dir_locked * v_move
		await get_tree().physics_frame

	# 3) SLAM: burst
	emit_signal("slammed")
	var timer_slam := get_tree().create_timer(t_slam)
	while timer_slam.time_left > 0.0:
		velocity = _dir_locked * v_slam
		await get_tree().physics_frame

	# 4) LAND → cooldown
	velocity = Vector2.ZERO
	set_state(State.COOLDOWN)

	_attack_running = false

# --- New: Ranged attack that reuses the same accordion windup ---
func _attack2_sequence() -> void:
	_attack_running = true

	# keep a lock, mainly for facing logic if you add it later
	if _player:
		var v := (_player.global_position - global_position)
		_dir_locked = v.normalized() if v.length() > 0.001 else Vector2.ZERO
	else:
		_dir_locked = Vector2.ZERO

	# 1) JUMP (windup): same accordion, no movement
	velocity = Vector2.ZERO
	_run_accordion_stack()

	# Wait until recoil completes across all layers so it syncs with the peak "pop"
	var recoil_gate := _recoil_gate_seconds()
	await get_tree().create_timer(recoil_gate).timeout
	await get_tree().physics_frame

	# 2) FIRE SYRUP: spawn from the TOP pancake sprite, fanning upward
	_spawn_syrup_volley()

	# 3) Stop and go to cooldown
	velocity = Vector2.ZERO
	set_state(State.COOLDOWN)

	_attack_running = false

func _spawn_syrup_volley() -> void:
	if syrup_scene == null:
		return

	# Upward base direction (Godot y-down, so up = Vector2(0, -1))
	var base_dir := Vector2(0, -1)

	# Create evenly-spaced directions across the spread
	var count : int = max(syrup_count, 1)
	var spread_rad := deg_to_rad(max(syrup_spread_deg, 0.0))

	var step := 0.0
	if count > 1:
		step = spread_rad / float(count - 1)

	var start_angle := -spread_rad * 0.5

	for i in count:
		var angle := start_angle + step * float(i)
		var dir := base_dir.rotated(angle).normalized()

		var drop := syrup_scene.instantiate()
		if drop is Node2D:
			drop.global_position = spawn_pos.global_position
			add_sibling(drop)

			var v := dir * syrup_speed

			# Preferred hooks your projectile can implement:
			if drop.has_method("setup"):
				# e.g. func setup(velocity: Vector2) -> void
				drop.setup(v)
			elif drop.has_method("set_velocity"):
				drop.set_velocity(v)
			elif drop is RigidBody2D:
				drop.linear_velocity = v
			elif drop is CharacterBody2D:
				drop.velocity = v
			# else: let the projectile move itself in _physics_process

# --- Helpers ---
func _is_player_in_range() -> bool:
	if not _player:
		return false
	return (_player.global_position - global_position).length() <= detect_range

# How long until the DOWNWARD recoil is complete across all staggered layers
func _recoil_gate_seconds() -> float:
	var n: int = max(_pancakes.size(), 1)
	return recoil_time + layer_stagger * float(n - 1)

# Start the accordion (we don't await the whole tween on purpose)
func _run_accordion_stack() -> void:
	if _pancakes.size() <= 1:
		return

	var tween := create_tween()
	tween.set_parallel(true)

	var n := _pancakes.size()
	for i in n:
		var spr := _pancakes[i]
		var base_pos := _orig_positions[i]

		if i == 0:
			tween.parallel()\
				.tween_property(spr, "position", base_pos, settle_time)\
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
			continue

		var depth := float(i)
		var down := Vector2(0, recoil_per_layer * depth)
		var up := Vector2(0, -recoil_per_layer * (float(n - i)) * overshoot_mult)
		var delay := layer_stagger * depth

		tween.parallel()\
			.tween_property(spr, "position", base_pos + down, recoil_time)\
			.set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

		tween.parallel()\
			.tween_property(spr, "position", base_pos + up, spring_time)\
			.set_delay(delay + recoil_time * 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

		tween.parallel()\
			.tween_property(spr, "position", base_pos, settle_time)\
			.set_delay(delay + recoil_time + spring_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func reset_stack_positions() -> void:
	for i in _pancakes.size():
		_pancakes[i].position = _orig_positions[i]
