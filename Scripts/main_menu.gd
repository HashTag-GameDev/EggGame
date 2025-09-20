extends Control

@export var main_game: String = "res://Scenes/main_game.tscn"

# --- Bus names ---
const BUS_MASTER : StringName = &"Master"
const BUS_MUSIC : StringName = &"Music"
const BUS_SFX : StringName = &"SFX"
const BUS_AMBI : StringName = &"Ambi"

# --- Slider mapping: ---
const DB_MIN: float = -30.0
const DB_MAX: float = 0.0

# --- Save file ---
const CFG_PATH := "user://settings.cfg"
const CFG_SECTION := "audio"

@onready var master_slider: HSlider = $SettingsMenu/MasterSlider
@onready var music_slider: HSlider = $SettingsMenu/MusicSlider
@onready var sfx_slider: HSlider = $SettingsMenu/SFXSlider
@onready var ambiance_slider: HSlider = $SettingsMenu/AmbianceSlider
@onready var check_mute: CheckBox = $SettingsMenu/HBoxContainer/CheckMute

@onready var pressed_play_bg: TileMapLayer = $ButtonContainer/PressedPlayBG
@onready var pressed_settings_bg: TileMapLayer = $ButtonContainer/PressedSettingsBG
@onready var settings_menu: VBoxContainer = $SettingsMenu
@onready var button_container: VBoxContainer = $ButtonContainer

var _idx_master: int
var _idx_music: int
var _idx_sfx: int
var _idx_ambi: int
var _loading: bool = false

func _ready() -> void:
	_idx_master = AudioServer.get_bus_index("Master")
	_idx_music = AudioServer.get_bus_index("Music")
	_idx_sfx = AudioServer.get_bus_index("SFX")
	_idx_ambi = AudioServer.get_bus_index("Ambi")
	
	_loading = true
	_load_settings()
	_loading = false
	
	MusicManager.fade_to("Music_0", 2.5)

func _on_play_button_pressed() -> void:
	SceneSwitcher.slide_to(main_game)

func _on_settings_button_pressed() -> void:
	settings_menu.visible = true
	button_container.visible = false

func _on_play_button_button_down() -> void:
	pressed_play_bg.visible = true

func _on_play_button_button_up() -> void:
	pressed_play_bg.visible = false

func _on_settings_button_button_down() -> void:
	pressed_settings_bg.visible = true

func _on_settings_button_button_up() -> void:
	pressed_settings_bg.visible = false

func _on_back_button_pressed() -> void:
	settings_menu.visible = false
	button_container.visible = true

func _on_master_slider_value_changed(value: float) -> void:
	_set_bus_db(_idx_master, _db_from_slider(value))
	_save_settings()

func _on_music_slider_value_changed(value: float) -> void:
	_set_bus_db(_idx_music, _db_from_slider(value))
	_save_settings()

func _on_sfx_slider_value_changed(value: float) -> void:
	_set_bus_db(_idx_sfx, _db_from_slider(value))
	_save_settings()

func _on_ambiance_slider_value_changed(value: float) -> void:
	_set_bus_db(_idx_ambi, _db_from_slider(value))
	_save_settings()

func _on_check_box_toggled(toggled_on: bool) -> void:
	if _idx_master != -1:
		AudioServer.set_bus_mute(_idx_master, toggled_on)
	_save_settings()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var ok := cfg.load(CFG_PATH)
	if ok == OK:
		var master_v := float(cfg.get_value(CFG_SECTION, "master_db", _get_bus_db_safe(_idx_master)))
		var music_v  := float(cfg.get_value(CFG_SECTION, "music_db",  _get_bus_db_safe(_idx_music)))
		var sfx_v    := float(cfg.get_value(CFG_SECTION,  "sfx_db",   _get_bus_db_safe(_idx_sfx)))
		var ambi_v    := float(cfg.get_value(CFG_SECTION,  "ambi_db",   _get_bus_db_safe(_idx_ambi)))
		var mute     := bool(cfg.get_value(CFG_SECTION, "master_mute", _get_bus_mute_safe(_idx_master)))

		# Apply to buses
		_set_bus_db(_idx_master, master_v)
		_set_bus_db(_idx_music,  music_v)
		_set_bus_db(_idx_sfx,    sfx_v)
		if _idx_master != -1:
			AudioServer.set_bus_mute(_idx_master, mute)

		master_slider.value = _slider_from_db(master_v)
		music_slider.value  = _slider_from_db(music_v)
		sfx_slider.value    = _slider_from_db(sfx_v)
		ambiance_slider.value    = _slider_from_db(ambi_v)
		check_mute.button_pressed = mute
	else:
		# First run: initialize UI from current bus states
		var md := _get_bus_db_safe(_idx_master)
		var mu := _get_bus_db_safe(_idx_music)
		var sx := _get_bus_db_safe(_idx_sfx)
		var am := _get_bus_db_safe(_idx_ambi)
		master_slider.value = _slider_from_db(md)
		music_slider.value  = _slider_from_db(mu)
		sfx_slider.value    = _slider_from_db(sx)
		ambiance_slider.value    = _slider_from_db(am)
		check_mute.button_pressed = _get_bus_mute_safe(_idx_master)
		_save_settings() # write defaults

func _save_settings() -> void:
	if _loading: return
	var cfg := ConfigFile.new()
	cfg.set_value(CFG_SECTION, "master_db", _db_from_slider(master_slider.value))
	cfg.set_value(CFG_SECTION, "music_db",  _db_from_slider(music_slider.value))
	cfg.set_value(CFG_SECTION, "sfx_db",    _db_from_slider(sfx_slider.value))
	cfg.set_value(CFG_SECTION, "ambi_db",    _db_from_slider(ambiance_slider.value))
	cfg.set_value(CFG_SECTION, "master_mute", check_mute.button_pressed)
	cfg.save(CFG_PATH)
	
func _get_bus_db_safe(idx: int) -> float:
	return AudioServer.get_bus_volume_db(idx) if idx != -1 else 0.0

func _get_bus_mute_safe(idx: int) -> bool:
	return AudioServer.is_bus_mute(idx) if idx != -1 else false

func _db_from_slider(v: float) -> float:
	v = clamp(v, 0.0, 1.0)
	return lerp(DB_MIN, DB_MAX, v)

func _slider_from_db(db: float) -> float:
	db = clamp(db, DB_MIN, DB_MAX)
	return (db - DB_MIN) / (DB_MAX - DB_MIN)

func _set_bus_db(idx: int, db: float) -> void:
	if idx == -1: return
	AudioServer.set_bus_volume_db(idx, db)
