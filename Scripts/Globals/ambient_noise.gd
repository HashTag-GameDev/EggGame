extends Node

@export var player_group: StringName = &"ambient_player"
@export var min_delay_sec: float = 6.0
@export var max_delay_sec: float = 14.0
@export var max_simultaneous: int = 2
@export var random_pitch_min: float = 0.96
@export var random_pitch_max: float = 1.04
@export var autostart: bool = true
@export var retry_when_busy_sec: float = 1.5

# ---- preload your sounds here ----
var sounds: Array[AudioStream] = [
	preload("uid://bnv22xqhdl5kb"),
	preload("uid://dydc1xv2u0d8u"),
	preload("uid://c4tmp6k0xwqfy"),
	preload("uid://cxgdv2f0su767"),
]

# ---- internals ----
var _rng := RandomNumberGenerator.new()
var _timer: Timer
var _players: Array[AudioStreamPlayer2D] = []

func _ready() -> void:
	_rng.randomize()
	_refresh_players()

	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timeout)

	if autostart:
		start()

func start() -> void:
	_schedule_next()

func stop() -> void:
	_timer.stop()

func _refresh_players() -> void:
	_players.clear()
	for n in get_tree().get_nodes_in_group(player_group):
		if n is AudioStreamPlayer2D:
			var p: AudioStreamPlayer2D = n
			# make sure we can track when it frees up
			if not p.finished.is_connected(_on_player_finished):
				p.finished.connect(_on_player_finished)
			_players.append(p)

func _on_player_finished() -> void:
	# nothing to do; we just let the scheduler handle timing
	pass

func _on_timeout() -> void:
	_refresh_players()

	if _players.is_empty() or sounds.is_empty():
		_timer.start(retry_when_busy_sec)
		return

	# respect max simultaneous by counting players currently playing
	var playing_count := 0
	for p in _players:
		if p.playing:
			playing_count += 1

	if playing_count >= max_simultaneous:
		_timer.start(retry_when_busy_sec)
		return

	# pick a free player at random
	var free_players: Array[AudioStreamPlayer2D] = []
	for p in _players:
		if not p.playing:
			free_players.append(p)

	if free_players.is_empty():
		_timer.start(retry_when_busy_sec)
		return

	var player := free_players[_rng.randi_range(0, free_players.size() - 1)]
	var stream := sounds[_rng.randi_range(0, sounds.size() - 1)]

	player.pitch_scale = _rng.randf_range(random_pitch_min, random_pitch_max)

	player.stream = stream
	player.play()
	_schedule_next()

func _schedule_next() -> void:
	var lo : float = max(0.0, min_delay_sec)
	var hi : float = max(lo, max_delay_sec)
	var delay := _rng.randf_range(lo, hi)
	_timer.start(delay)
