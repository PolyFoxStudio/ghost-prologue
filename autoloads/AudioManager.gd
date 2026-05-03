extends Node

@onready var _sfx_ui: AudioStreamPlayer = $SFX_UI
@onready var _sfx_terminal: AudioStreamPlayer = $SFX_Terminal
@onready var _ambient: AudioStreamPlayer = $Ambient

func _ready() -> void:
	# Load streams directly in code — no Inspector assignment needed
	var msg_stream = load("res://resources/audio/message_receive.wav")
	if msg_stream:
		_sfx_ui.stream = msg_stream
		print("AUDIO: message_receive.wav loaded successfully")
	else:
		print("AUDIO ERROR: message_receive.wav not found at res://resources/audio/")
	
	var transfer_stream = load("res://resources/audio/transfer_complete.wav")
	if transfer_stream:
		_sfx_terminal.stream = transfer_stream
		print("AUDIO: transfer_complete.wav loaded successfully")
	else:
		print("AUDIO ERROR: transfer_complete.wav not found at res://resources/audio/")

	
	# Confirm bus assignments
	_sfx_ui.bus = "UI"
	_sfx_terminal.bus = "Terminal"
	_ambient.bus = "Ambient"

func play_message_receive() -> void:
	if _sfx_ui.stream:
		_sfx_ui.play()
	else:
		print("AUDIO ERROR: message_receive stream not loaded")

func play_transfer_complete() -> void:
	if _sfx_terminal.stream:
		_sfx_terminal.play()
	else:
		print("AUDIO ERROR: transfer_complete stream not loaded")

func play_notification() -> void:
	# Same sound as message receive but slightly quieter
	# Used for toast notifications when CipherLink is closed
	if _sfx_ui.stream:
		_sfx_ui.volume_db = -6.0
		_sfx_ui.play()
		_sfx_ui.volume_db = 0.0

func fade_in_ambient(duration: float) -> void:
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
