extends Node

var default_duration: float = 1.0
var _layer: CanvasLayer
var _tex_rect: TextureRect
var _busy: bool = false

func _ready() -> void:
	# Overlay UI for transitions
	_layer = CanvasLayer.new()
	_layer.layer = 9999
	add_child(_layer)

	_tex_rect = TextureRect.new()
	_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	_tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tex_rect.visible = false
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_tex_rect)

func slide_to(scene_path: String, direction: String = "left", duration: float = -1.0, speed_pps: float = 1600.0) -> void:
	if _busy:
		return
	_busy = true

	var snap_sprite := _snapshot_sprite()
	_layer.add_child(snap_sprite)
	snap_sprite.position = Vector2.ZERO
	snap_sprite.modulate.a = 1.0

	await _change_scene(scene_path)
	await get_tree().process_frame

	var screen := get_viewport().get_visible_rect().size
	var to := Vector2.ZERO
	match direction:
		"right": to = Vector2(screen.x, 0)
		"up": to =Vector2(0, -screen.y)
		"down": to = Vector2(0, screen.y)
		_: to =Vector2(-screen.x, 0)

	# If duration not specified, derive from distance for consistent speed
	if duration <= 0.0:
		var dist: float = max(abs(to.x), abs(to.y))
		duration = dist / max(1.0, speed_pps)

	# Don’t let it be too fast
	duration = max(duration, 0.28)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	tween.tween_property(snap_sprite, "position", to, duration)
	tween.tween_property(snap_sprite, "modulate:a", 0.0, duration * 0.85)

	await tween.finished
	if is_instance_valid(snap_sprite):
		snap_sprite.queue_free()
	_busy = false

func _snapshot_sprite() -> Sprite2D:
	var vt: Texture2D = get_viewport().get_texture()
	var img := vt.get_image()
	var tex := ImageTexture.create_from_image(img)

	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	# Scale to match viewport size exactly (handles HiDPI)
	var vp_size := get_viewport().get_visible_rect().size
	var tex_size := tex.get_size()
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		spr.scale = vp_size / tex_size
	return spr

func _change_scene(scene_path: String) -> void:
	# Threaded/async load to keep animation smooth
	var rid := ResourceLoader.load_threaded_request(scene_path)
	if rid == OK:
		while true:
			var status := ResourceLoader.load_threaded_get_status(scene_path)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				break
			await get_tree().process_frame
		var packed := ResourceLoader.load_threaded_get(scene_path) as PackedScene
		if packed:
			get_tree().change_scene_to_packed(packed)
			return
	# Fallback (blocking) if threaded failed
	var packed_fallback := load(scene_path) as PackedScene
	if packed_fallback:
		get_tree().change_scene_to_packed(packed_fallback)
