extends Node

var music_bus: StringName = &"Music"
var mute_db: float = -60.0
var max_db: float = -15.0
var default_fade: float = 1.5

var tracks: Array[AudioStream] = [preload("uid://d1fsi3oylph5h"), preload("uid://cwe1y1mswr23j"), preload("uid://difsq3croeug2"), preload("uid://bl85xvsfdaa8s")]
var track_names: Array[StringName] = [&"Music_0", &"Music_1", &"Music_2", &"Music_3"]

var _players: Array[AudioStreamPlayer] = []
var _name_to_index: Dictionary = {}	# StringName -> int
var _current_index: int = -1
var _tween: Tween

func _ready() -> void:
	_build_players()
	prime_all()
	# Optionally start on the first track:
	# if _players.size() > 0: switch_to_index(0)

func _build_players() -> void:
	# Clear old (in case of hot-reload)
	for p in _players:
		if is_instance_valid(p):
			p.queue_free()
	_players.clear()
	_name_to_index.clear()

	var n := tracks.size()
	for i in n:
		var s := tracks[i].duplicate(true)
		s.set("loop", true)
		s.set("loop_offset", 0.05)
		var p := AudioStreamPlayer.new()
		p.bus = music_bus
		p.stream = s
		p.volume_db = mute_db
		p.autoplay = false
		add_child(p)
		_players.append(p)

		var nm: StringName
		if i < track_names.size() and track_names[i] != StringName():
			nm = track_names[i]
		else:
			nm = StringName("track_%d" % i)
		_name_to_index[nm] = _players.size() - 1

# Start all registered tracks playing silently (so crossfades are instant)
func prime_all() -> void:
	for p in _players:
		if not p.playing:
			p.play()
		p.volume_db = mute_db

# Crossfade by track_name (preferred if you set track_names)
func fade_to(track_name: StringName, duration: float = default_fade) -> void:
	if not _name_to_index.has(track_name):
		push_warning("fade_to: no track named %s" % [track_name])
		return
	fade_to_index(_name_to_index[track_name], duration)

# Crossfade by INDEX
func fade_to_index(index: int, duration: float = default_fade) -> void:
	if index < 0 or index >= _players.size():
		push_warning("fade_to_index: bad index %d" % index)
		return

	# Ensure all are playing
	for p in _players:
		if not p.playing:
			p.play()

	# Stop previous tween
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)

	# Target up
	var target := _players[index]
	_tween.tween_property(target, "volume_db", max_db, max(0.0, duration))

	# Others down
	for i in _players.size():
		if i == index:
			continue
		_tween.tween_property(_players[i], "volume_db", mute_db, max(0.0, duration))

	_current_index = index

# Instant switch (no fade)
func switch_to(track_name: StringName) -> void:
	if not _name_to_index.has(track_name):
		push_warning("switch_to: no track named %s" % [track_name])
		return
	switch_to_index(_name_to_index[track_name])

func switch_to_index(index: int) -> void:
	if index < 0 or index >= _players.size():
		push_warning("switch_to_index: bad index %d" % index)
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	for i in _players.size():
		var p := _players[i]
		p.volume_db = 0.0 if i == index else mute_db
		if not p.playing:
			p.play()
	_current_index = index

func current_index() -> int:
	return _current_index

func current_name() -> StringName:
	for nm in _name_to_index.keys():
		if _name_to_index[nm] == _current_index:
			return nm
	return StringName()

func stop_all() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	for p in _players:
		p.stop()
	_current_index = -1
