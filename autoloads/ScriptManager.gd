extends Node

## ScriptManager
## Message queue and event system for GHOST narrative

# Signals
signal message_queued(message: Dictionary)
signal world_event_fired(event_name: String)
signal notification_needed

# History of all messages for CipherLink
var _message_history: Array[Dictionary] = []

# Sequence gating for CipherLink
var _pending_sequences: Dictionary = {}
var _cipherlink_open: bool = false


func queue_message(msg: Dictionary) -> void:
	if msg.has("delay") and msg["delay"] > 0.0:
		var timer: SceneTreeTimer = get_tree().create_timer(msg["delay"])
		timer.timeout.connect(_send_message.bind(msg))
	else:
		_send_message(msg)


func _send_message(msg: Dictionary) -> void:
	# Check trigger condition if present
	if msg.has("trigger"):
		if _evaluate_trigger(msg["trigger"]):
			return
	
	# Set any flags specified in the message
	if msg.has("flags_set"):
		for flag_name: String in msg["flags_set"]:
			var flag_value: bool = msg["flags_set"][flag_name]
			GameState.set_flag(flag_name, flag_value)
	
	# Ensure timestamp is set (defaults to current time if not provided)
	if not msg.has("timestamp"):
		msg["timestamp"] = Time.get_time_string_from_system().substr(0, 5)
	
	# Store message in history if it's for CipherLink
	if msg.get("from", "") in ["cipher", "ghost", "system"]:
		_message_history.append(msg)
	
	# Emit the message (for if CipherLink is already open)
	message_queued.emit(msg)


func set_cipherlink_open(is_open: bool) -> void:
	_cipherlink_open = is_open
	if is_open and not _pending_sequences.is_empty():
		_flush_pending_sequences()


func queue_sequence(messages: Array) -> void:
	# First message always delivers immediately
	if messages.is_empty():
		return
	_send_message(messages[0])
	
	if messages.size() == 1:
		return
	
	var remaining: Array = messages.slice(1)
	
	if _cipherlink_open:
		# CipherLink is open — deliver with normal delays
		var base_delay: float = 2.0
		for msg: Dictionary in remaining:
			var adjusted: Dictionary = msg.duplicate()
			adjusted["delay"] = base_delay
			base_delay += randf_range(2.0, 4.0)
			queue_message(adjusted)
	else:
		# CipherLink is closed — hold remaining messages
		# Emit notification signal
		notification_needed.emit()
		_pending_sequences["cipherlink"] = remaining


func _flush_pending_sequences() -> void:
	if not _pending_sequences.has("cipherlink"):
		return
	var messages: Array = _pending_sequences["cipherlink"].duplicate()
	_pending_sequences.erase("cipherlink")
	
	var base_delay: float = 2.0
	for msg: Dictionary in messages:
		var adjusted: Dictionary = msg.duplicate()
		adjusted["delay"] = base_delay
		base_delay += randf_range(2.0, 4.0)
		queue_message(adjusted)


func fire_event(event_name: String) -> void:
	world_event_fired.emit(event_name)


func _evaluate_trigger(condition: String) -> bool:
	return GameState.get(condition) == true


func get_message_history() -> Array[Dictionary]:
	return _message_history.duplicate()
