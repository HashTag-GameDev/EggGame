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

# --- Runtime state ---
enum State { IDLE, ATTACK, COOLDOWN }
var state: State = State.IDLE

var _player: Node2D
var _dir_locked: Vector2 = Vector2.ZERO
var _cooldown_left: float = 0.0
var _attack_running: bool = false

var _pancakes: Array[Sprite2D] = []
var _orig_positions: Array[Vector2] = []

signal slammed

func _ready() -> void:
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
		State.COOLDOWN:
			velocity = Vector2.ZERO
			_cooldown_left = jump_cooldown

func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			if _player and _is_player_in_range():
				set_state(State.ATTACK)

		State.ATTACK:
			# movement handled inside the awaited sequence; we just slide
			pass

		State.COOLDOWN:
			velocity = Vector2.ZERO
			_cooldown_left -= delta
			if _cooldown_left <= 0.0:
				if _player and _is_player_in_range():
					set_state(State.ATTACK)
				else:
					set_state(State.IDLE)

	move_and_slide()

# --- Whole attack, serialized; NO MOVEMENT until recoil gate passes ---
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

	# compute exact time until the recoil (downward) finishes across all layers
	var recoil_gate := _recoil_gate_seconds()
	# wait that long so we cannot move during recoil
	await get_tree().create_timer(recoil_gate).timeout
	# also nudge one physics frame so movement never slips in the same tick
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

	# 4) LAND: hard stop → cooldown
	velocity = Vector2.ZERO
	set_state(State.COOLDOWN)

	_attack_running = false

# --- Helpers ---
func _is_player_in_range() -> bool:
	if not _player:
		return false
	return (_player.global_position - global_position).length() <= detect_range

# How long until the DOWNWARD recoil is complete across all staggered layers
func _recoil_gate_seconds() -> float:
	var n: int = max(_pancakes.size(), 1)
	# last layer to start = index n-1 → delay = layer_stagger*(n-1)
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
			# base fixed; optional micro settle
			tween.parallel()\
				.tween_property(spr, "position", base_pos, settle_time)\
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
			continue

		var depth := float(i)
		var down := Vector2(0, recoil_per_layer * depth)
		var up := Vector2(0, -recoil_per_layer * (float(n - i)) * overshoot_mult)
		var delay := layer_stagger * depth

		# Recoil DOWN
		tween.parallel()\
			.tween_property(spr, "position", base_pos + down, recoil_time)\
			.set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

		# Spring UP
		tween.parallel()\
			.tween_property(spr, "position", base_pos + up, spring_time)\
			.set_delay(delay + recoil_time * 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

		# Settle
		tween.parallel()\
			.tween_property(spr, "position", base_pos, settle_time)\
			.set_delay(delay + recoil_time + spring_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func reset_stack_positions() -> void:
	for i in _pancakes.size():
		_pancakes[i].position = _orig_positions[i]
