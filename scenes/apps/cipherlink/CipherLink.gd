extends HSplitContainer

signal first_opened

var _first_open: bool = true
var _send_failed_mode: bool = false
var _used_ending_options: Array = []

@onready var _messages: VBoxContainer = $MessagePanel/MessageScroll/MessageContainer
@onready var _scroll: ScrollContainer = $MessagePanel/MessageScroll
@onready var _input: LineEdit = $MessagePanel/InputRow/InputField
@onready var _response_options: HBoxContainer = $MessagePanel/ResponseOptions
@onready var _presence: ColorRect = $ContactsSidebar/VBoxContainer/ContactList/CipherContact/PresenceIndicator

func _ready() -> void:
	_presence.color = Color("#3a8a3a")
	_input.text_submitted.connect(_on_input_submitted)
	ScriptManager.message_queued.connect(_on_message_received)
	_input.focus_mode = Control.FOCUS_CLICK
	
	# Check for any pending messages that arrived while CipherLink was closed
	var history: Array[Dictionary] = ScriptManager.get_message_history()
	for msg in history:
		_deliver_message(msg, true)
	
	if not GameState.brief_delivered:
		_on_first_open()
	
	# Grab focus on the input field after everything is set up
	_input.call_deferred("grab_focus")

func _on_first_open() -> void:
	first_opened.emit()
	ScriptManager.queue_message({
		"from": "cipher",
		"body": "alright. job's live. routing's clean — I checked it\ntwice, came back cold both times.\n\ntarget is jordan calloway. corporate analyst,\nvantage dynamics. mid-level. access to the internal\ndocument archive. they've been doing something with\nit — moving files around, compressing batches, the\npattern looks like staged extraction.\n\nclient thinks calloway is building a package for\na competitor.\n\nyour job: get in ahead of them. pull whatever\nthey've staged, wipe the trail. standard IP\nprotection work.\n\nI've got calloway's home network mapped.\nbrief's in your downloads.",
		"timestamp": _get_current_time()
	})
	GameState.advance_stage(1)
	ScriptManager.fire_event("brief_delivered")

func _on_message_received(msg: Dictionary) -> void:
	_deliver_message(msg)
	AudioManager.play_message_receive()

func _deliver_message(msg: Dictionary, silent: bool = false) -> void:
	var container: VBoxContainer = VBoxContainer.new()
	
	# Timestamp
	var timestamp_label: Label = Label.new()
	timestamp_label.text = msg.get("timestamp", _get_current_time())
	timestamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timestamp_label.add_theme_color_override("font_color", Color("#4a4a4a"))
	timestamp_label.add_theme_font_size_override("font_size", 10)
	
	# Message body
	var body_label: Label = Label.new()
	body_label.text = msg["body"]
	body_label.add_theme_color_override("font_color", Color("#d4d4d4"))
	body_label.add_theme_font_size_override("font_size", 13)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	container.add_child(timestamp_label)
	container.add_child(body_label)
	_messages.add_child(container)
	
	# Read receipt
	var receipt_label: Label = Label.new()
	receipt_label.text = "[READ]"
	receipt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	receipt_label.add_theme_color_override("font_color", Color("#4a4a4a"))
	receipt_label.add_theme_font_size_override("font_size", 10)
	container.add_child(receipt_label)
	
	if not silent:
		await get_tree().process_frame
		_scroll_to_bottom()
		GameState.record_activity()

func show_response_options(options: Array, ending_beat: bool = false) -> void:
	for child in _response_options.get_children():
		child.queue_free()
	
	for option: String in options:
		var button: Button = Button.new()
		button.text = option
		button.pressed.connect(_on_response_selected.bind(option, ending_beat))
		_response_options.add_child(button)
	
	_response_options.visible = true

func _on_response_selected(text: String, ending_beat: bool = false) -> void:
	_send_ghost_message(text)
	_response_options.visible = false
	for child in _response_options.get_children():
		child.queue_free()
	
	if ending_beat:
		_used_ending_options.append(text)
		# Queue remaining options after delay
		await get_tree().create_timer(3.0).timeout
		var remaining: Array = []
		var all_options: Array = [
			"we didn't know.",
			"we were used.",
			"I read the archive.",
			"the response time was wrong.",
			"I need to find out who the client is.",
		]
		for opt: String in all_options:
			if opt not in _used_ending_options:
				remaining.append(opt)
		if remaining.size() > 0:
			show_response_options(remaining, true)
		else:
			# All options used — trigger ending beat complete
			ScriptManager.fire_event("ending_beat_complete")

func _on_input_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	
	if _send_failed_mode:
		_handle_send_failed()
		_input.clear()
		return
	
	_send_ghost_message(text)
	_input.clear()
	GameState.record_activity()

func _send_ghost_message(text: String) -> void:
	ScriptManager.queue_message({
		"from": "ghost",
		"body": text,
		"timestamp": _get_current_time()
	})
	
	ScriptManager.fire_event("ghost_sent_message:" + text)
	
	await get_tree().process_frame
	_scroll_to_bottom()

func show_ending_beat_options() -> void:
	# These are Ghost's available responses in the ending beat
	# Player can select any, and can engage multiple times
	# Options disappear after selection but can reappear
	show_response_options([
		"we didn't know.",
		"we were used.",
		"I read the archive.",
		"the response time was wrong.",
		"I need to find out who the client is.",
	], true)

func activate_send_failed_mode() -> void:
	_send_failed_mode = true
	_presence.color = Color("#4a4a4a")

func _handle_send_failed() -> void:
	await get_tree().create_timer(0.3).timeout
	
	var label: Label = Label.new()
	label.text = "no active route"
	label.add_theme_color_override("font_color", Color("#4a4a4a"))
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_messages.add_child(label)
	_scroll_to_bottom()
	
	await get_tree().create_timer(2.0).timeout
	label.queue_free()

func _scroll_to_bottom() -> void:
	_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value

func _get_current_time() -> String:
	return Time.get_time_string_from_system().substr(0, 5)
