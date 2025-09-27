extends Area2D

# Exports
@export var lifetime: float = 4.0 ## Seconds this AOE exists before freeing.
@export var hit_box: HitBox2D ## Child HitBox2D that deals damage (mask set to 2).
@export var sfx_on_spawn: bool = true ## Play SFX when spawned (disabled in editor).
@export var stop_sfx_on_free: bool = true ## Stop SFX when freeing.

var is_ai_controlled: bool = true

# Onready
@onready var sfx: AudioStreamPlayer2D = %Sfx # Optional child; ensure Autoplay is OFF in the editor.

# Lifecycle
func _ready() -> void:
	_validate_nodes()
	_configure_hitbox()
	_play_spawn_sfx()
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _exit_tree() -> void:
	if stop_sfx_on_free and is_instance_valid(sfx):
		sfx.stop()

# Internal
func _validate_nodes() -> void:
	assert(is_instance_valid(hit_box), "syrup_aoe.gd: hit_box must be assigned (HitBox2D).")
	# sfx is optional; if present, ensure Autoplay is off in the editor scene to avoid editor playback.

func _configure_hitbox() -> void:
	# Enemy hitboxes should only mask player hurtboxes on layer 2.
	for i: int in range(1, 33):
		hit_box.set_collision_mask_value(i, false)
		hit_box.set_collision_layer_value(i, false)
	hit_box.set_collision_mask_value(2, true)
	hit_box.monitoring = true
	hit_box.monitorable = true

func _play_spawn_sfx() -> void:
	# Prevent editor playback; only play during game runtime.
	if not sfx_on_spawn:
		return
	if not is_instance_valid(sfx):
		return
	if Engine.is_editor_hint():
		return
	sfx.play()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		body.set_slow(true)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		body.set_slow(false)
