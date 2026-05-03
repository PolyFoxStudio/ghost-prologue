extends PanelContainer

@onready var _master_slider: HSlider = %MasterSlider
@onready var _notifications_toggle: CheckButton = %NotificationsToggle
@onready var _ambient_toggle: CheckButton = %AmbientToggle

func _ready() -> void:
    _master_slider.value_changed.connect(_on_master_volume_changed)
    _notifications_toggle.toggled.connect(_on_notifications_toggled)
    _ambient_toggle.toggled.connect(_on_ambient_toggled)
    %CloseButton.pressed.connect(queue_free)
    _load_settings()

func _on_master_volume_changed(value: float) -> void:
    AudioServer.set_bus_volume_db(0, value)
    _save_settings()

func _on_notifications_toggled(enabled: bool) -> void:
    GameState.notifications_enabled = enabled
    _save_settings()

func _on_ambient_toggled(enabled: bool) -> void:
    if enabled:
        AudioServer.set_bus_volume_db(
            AudioServer.get_bus_index("Ambient"), -20.0
        )
    else:
        AudioServer.set_bus_volume_db(
            AudioServer.get_bus_index("Ambient"), -80.0
        )
    _save_settings()

func _save_settings() -> void:
    var config = ConfigFile.new()
    config.set_value("audio", "master_volume", _master_slider.value)
    config.set_value("audio", "notifications_enabled", 
                     _notifications_toggle.button_pressed)
    config.set_value("audio", "ambient_enabled", 
                     _ambient_toggle.button_pressed)
    config.save("user://settings.cfg")

func _load_settings() -> void:
    var config = ConfigFile.new()
    if config.load("user://settings.cfg") != OK:
        return
    _master_slider.value = config.get_value("audio", "master_volume", 0.0)
    _notifications_toggle.button_pressed = config.get_value(
        "audio", "notifications_enabled", true
    )
    _ambient_toggle.button_pressed = config.get_value(
        "audio", "ambient_enabled", true
    )
    _on_master_volume_changed(_master_slider.value)
