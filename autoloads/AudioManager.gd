extends Node

@export var message_receive: AudioStream
@export var transfer_complete: AudioStream

@onready var _sfx_ui: AudioStreamPlayer = $SFX_UI
@onready var _sfx_terminal: AudioStreamPlayer = $SFX_Terminal
@onready var _ambient: AudioStreamPlayer = $Ambient

func _ready() -> void:
	# Assign streams if exported vars are set
	if message_receive:
		_sfx_ui.stream = message_receive
	if transfer_complete:
		_sfx_terminal.stream = transfer_complete

func play_message_receive() -> void:
	if _sfx_ui.stream:
		_sfx_ui.play()

func play_transfer_complete() -> void:
	if _sfx_terminal.stream:
		_sfx_terminal.play()

func fade_in_ambient(duration: float) -> void:
	# Fade Ambient bus from -80dB to -20dB over duration seconds
	var tween = create_tween()
	tween.tween_method(
		func(vol: float): 
			AudioServer.set_bus_volume_db(
				AudioServer.get_bus_index("Ambient"), vol
			),
		-80.0, -20.0, duration
	)

func set_ambient_stream(stream: AudioStream) -> void:
	_ambient.stream = stream
	_ambient.play()

func stop_ambient() -> void:
	var tween = create_tween()
	tween.tween_method(
		func(vol: float):
			AudioServer.set_bus_volume_db(
				AudioServer.get_bus_index("Ambient"), vol
			),
		AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index("Ambient")
		),
		-80.0, 2.0
	)
	await tween.finished
	_ambient.stop()
