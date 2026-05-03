extends HSplitContainer

signal first_opened

var _first_open: bool = true
var _send_failed_mode: bool = false
var _options_permanently_hidden: bool = false
var _used_ending_options: Array = []

@onready var _messages: VBoxContainer = $MessagePanel/MessageScroll/MessageContainer
@onready var _scroll: ScrollContainer = $MessagePanel/MessageScroll
@onready var _response_options: VBoxContainer = $MessagePanel/ResponseOptions
@onready var _presence: ColorRect = $ContactsSidebar/VBoxContainer/ContactList/CipherContact/PresenceIndicator

func _ready() -> void:
	_presence.color = Color("#3a8a3a")
	ScriptManager.message_queued.connect(_on_message_received)
	
	# Check for any pending messages that arrived while CipherLink was closed
	var history: Array[Dictionary] = ScriptManager.get_message_history()
	for msg in history:
		_deliver_message(msg, true)
	
	if not GameState.brief_delivered:
		_on_first_open()

func _on_first_open() -> void:
	first_opened.emit()
	# Brief delivery and stage advance now handled by Desktop._begin_opening_sequence()

func _on_message_received(msg: Dictionary) -> void:
	AudioManager.play_message_receive()
	_deliver_message(msg)

func _deliver_message(msg: Dictionary, silent: bool = false) -> void:
	var container: VBoxContainer = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	
	# Header line: "cipher (23:08)" or "ghost (23:08)"
	var sender: String = msg.get("from", "cipher")
	var timestamp: String = msg.get("timestamp", _get_current_time())
	var header: Label = Label.new()
	header.text = sender + " (" + timestamp + ")"
	header.add_theme_font_size_override("font_size", 11)
	if sender == "ghost":
		header.add_theme_color_override("font_color", Color("#8a5a0a"))
	else:
		header.add_theme_color_override("font_color", Color("#4a4a4a"))
	
	# Message body
	var body: Label = Label.new()
	body.text = msg["body"]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 13)
	if sender == "ghost":
		body.add_theme_color_override("font_color", Color("#c8841a"))
	else:
		body.add_theme_color_override("font_color", Color("#d4d4d4"))
	
	# Spacer below message
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	
	container.add_child(header)
	container.add_child(body)
	container.add_child(spacer)
	_messages.add_child(container)
	
	if not silent:
		await get_tree().process_frame
		_scroll_to_bottom()
		GameState.record_activity()

func show_response_options(options: Array, ending_beat: bool = false) -> void:
	if _options_permanently_hidden or _send_failed_mode:
		return
		
	for child in _response_options.get_children():
		child.queue_free()
	
	# Add a subtle prompt indicator
	var prompt_label: Label = Label.new()
	prompt_label.text = ">"
	prompt_label.add_theme_color_override("font_color", Color("#4a4a4a"))
	prompt_label.add_theme_font_size_override("font_size", 13)
	_response_options.add_child(prompt_label)
	
	for option: String in options:
		var btn: Button = Button.new()
		btn.text = option
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.add_theme_color_override("font_color", Color("#8a8a8a"))
		btn.add_theme_color_override("font_color_hover", Color("#d4d4d4"))
		btn.add_theme_color_override("font_color_pressed", Color("#c8841a"))
		btn.add_theme_font_size_override("font_size", 13)
		btn.custom_minimum_size = Vector2(0, 24)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(
			_on_response_selected.bind(option, ending_beat)
		)
		_response_options.add_child(btn)
	
	_response_options.visible = true
	await get_tree().process_frame
	_scroll_to_bottom()

func _on_response_selected(text: String, ending_beat: bool = false) -> void:
	_send_ghost_message(text)
	_response_options.visible = false
	for child in _response_options.get_children():
		child.queue_free()
	
	if ending_beat:
		# Ending beat logic now handled by Desktop via ghost_sent_message events
		pass

func _send_ghost_message(text: String) -> void:
	_deliver_message({
		"from": "ghost",
		"body": text,
		"timestamp": _get_current_time()
	})
	ScriptManager.fire_event("ghost_sent_message:" + text)
	await get_tree().process_frame
	_scroll_to_bottom()

func hide_response_options_permanently() -> void:
	_response_options.visible = false
	for child in _response_options.get_children():
		child.queue_free()
	# Flag to prevent any future show_response_options calls
	_options_permanently_hidden = true

func activate_send_failed_mode() -> void:
	_send_failed_mode = true
	_presence.color = Color("#4a4a4a")
	# If response options are visible, hide them
	_response_options.visible = false

func _scroll_to_bottom() -> void:
	_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value

func _get_current_time() -> String:
	return Time.get_time_string_from_system().substr(0, 5)
