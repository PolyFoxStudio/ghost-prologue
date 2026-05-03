extends Control

## Desktop
## Main scene of GHOST — manages desktop background, app icons, windows, and UI

# Preload app scenes
const TERMINAL_SCENE: PackedScene = preload("res://scenes/apps/terminal/Terminal.tscn")
const CIPHERLINK_SCENE: PackedScene = preload("res://scenes/apps/cipherlink/CipherLink.tscn")
# const FILES_SCENE = preload("res://scenes/apps/files/FileBrowser.tscn")
# const NOTEPAD_SCENE = preload("res://scenes/apps/notepad/Notepad.tscn")

const APP_WINDOW_SCENE: PackedScene = preload("res://scenes/ui/AppWindow.tscn")

# Node references
@onready var _window_layer: Control = $WindowLayer
@onready var _right_click_menu: PopupMenu = $RightClickMenu
@onready var _objectives_board: PanelContainer = $ObjectivesBoard
@onready var _nudge_system: Node = $NudgeSystem
@onready var _taskbar_buttons: HBoxContainer = %TaskbarButtons
@onready var _clock_label: Label = %Clock

# Open window tracking
var _open_windows: Dictionary = {}
var _taskbar_button_map: Dictionary = {}  # Maps app_name to taskbar button

# Notification tracking
var _notifications: Dictionary = {}

# Double-click detection
const DOUBLE_CLICK_TIME: float = 0.4  # 400ms for double-click
var _last_click_time: Dictionary = {}  # Track last click time per icon
var _last_click_pos: Dictionary = {}   # Track last click position per icon


func _ready() -> void:
	# Connect global signals
	GameState.stage_advanced.connect(_on_stage_advanced)
	ScriptManager.world_event_fired.connect(_on_world_event)
	
	# Connect desktop icon inputs
	$DesktopIcons/TerminalIcon.gui_input.connect(_on_icon_input.bind("terminal"))
	$DesktopIcons/CipherLinkIcon.gui_input.connect(_on_icon_input.bind("cipherlink"))
	$DesktopIcons/FilesIcon.gui_input.connect(_on_icon_input.bind("files"))
	$DesktopIcons/NotepadIcon.gui_input.connect(_on_icon_input.bind("notepad"))
	
	# Start clock update
	_update_clock()
	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_clock)
	add_child(timer)
	timer.start()
	
	# CipherLink notification will be handled when app opens


func _update_clock() -> void:
	var time: Dictionary = Time.get_time_dict_from_system()
	var hour: int = time.hour
	var minute: int = time.minute
	_clock_label.text = "%02d:%02d" % [hour, minute]


func open_app(app_name: String) -> void:
	# If window already open, bring to front
	if app_name in _open_windows:
		var window: Control = _open_windows[app_name]
		var parent: Node = window.get_parent()
		if parent:
			parent.move_child(window, parent.get_child_count() - 1)
		return
	
	# Instantiate the appropriate app scene
	var app_content: Control = null
	var window_title: String = ""
	
	match app_name:
		"terminal":
			if TERMINAL_SCENE:
				app_content = TERMINAL_SCENE.instantiate()
				window_title = "Terminal"
		"cipherlink":
			if CIPHERLINK_SCENE:
				app_content = CIPHERLINK_SCENE.instantiate()
				window_title = "CipherLink"
		"files":
			print("open_app: files — not yet implemented")
			return
		"notepad":
			print("open_app: notepad — not yet implemented")
			return
	
	if not app_content:
		return
	
	# Create window chrome
	var window: PanelContainer = APP_WINDOW_SCENE.instantiate()
	window.title = window_title
	window.size = Vector2(800, 600)
	
	# Add app content to window's AppContainer
	var app_container: MarginContainer = window.get_node("VBoxContainer/AppContainer")
	app_container.add_child(app_content)
	
	# Add window to layer
	_window_layer.add_child(window)
	
	# Position and track
	_position_new_window(window)
	_open_windows[app_name] = window
	
	# Connect closed signal
	window.closed.connect(_on_window_closed.bind(app_name))
	
	# Connect minimized signal to update taskbar
	window.minimized.connect(_on_window_minimized.bind(app_name))
	
	# Create taskbar button
	_create_taskbar_button(app_name, window_title, window)
	
	# Ensure the window can receive input by calling grab_focus on it
	window.call_deferred("grab_focus")


func _on_window_closed(app_name: String) -> void:
	_open_windows.erase(app_name)
	_remove_taskbar_button(app_name)


func _on_window_minimized(app_name: String) -> void:
	# Update taskbar button to show window is minimized
	if app_name in _taskbar_button_map:
		var button: Button = _taskbar_button_map[app_name]
		# Add visual indicator that window is minimized (could use modulate or text prefix)
		button.modulate = Color(0.7, 0.7, 0.7, 1.0)


func _create_taskbar_button(app_name: String, title: String, window: Control) -> void:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(28, 28)
	button.size_flags_horizontal = 0  # Don't expand
	button.expand_icon = true
	button.flat = true
	button.tooltip_text = title
	
	# Set icon based on app name
	var icon_path: String = ""
	match app_name:
		"terminal":
			icon_path = "res://assets/generated/icon_terminal_frame_0.png"
		"cipherlink":
			icon_path = "res://assets/generated/icon_cipherlink_frame_0.png"
		"files":
			icon_path = "res://assets/generated/icon_files_frame_0.png"
		"notepad":
			icon_path = "res://assets/generated/icon_notepad_frame_0.png"
	
	if icon_path and ResourceLoader.exists(icon_path):
		var texture: Texture2D = load(icon_path)
		button.icon = texture
	
	# Connect button press to restore/focus window
	button.pressed.connect(_on_taskbar_button_pressed.bind(app_name, window))
	
	# Add to taskbar
	_taskbar_buttons.add_child(button)
	_taskbar_button_map[app_name] = button


func _remove_taskbar_button(app_name: String) -> void:
	if app_name in _taskbar_button_map:
		var button: Button = _taskbar_button_map[app_name]
		button.queue_free()
		_taskbar_button_map.erase(app_name)


func _on_taskbar_button_pressed(app_name: String, window: Control) -> void:
	if not window:
		return
	
	# If window is minimized, restore it
	if not window.visible:
		window.restore()
		# Update button appearance
		if app_name in _taskbar_button_map:
			var button: Button = _taskbar_button_map[app_name]
			button.modulate = Color.WHITE
	else:
		# If window is visible, bring it to front (or minimize if already focused)
		var parent: Node = window.get_parent()
		if parent:
			# Check if window is already on top
			var is_on_top: bool = parent.get_child(parent.get_child_count() - 1) == window
			
			if is_on_top:
				# If already on top, minimize it
				window.minimize()
			else:
				# Otherwise, bring to front
				parent.move_child(window, parent.get_child_count() - 1)
				window.grab_focus()


func _position_new_window(window: Control) -> void:
	window.z_index = 10
	var offset: Vector2 = Vector2(24, 24) * _open_windows.size()
	window.position = Vector2(100, 80) + offset


func _on_stage_advanced(new_stage: int) -> void:
	_objectives_board.refresh()


func _get_app_content(app_name: String) -> Node:
	var window: Node = _open_windows.get(app_name, null)
	if window == null:
		return null
	var app_container: Node = window.get_node_or_null("VBoxContainer/AppContainer")
	if app_container == null:
		return null
	if app_container.get_child_count() == 0:
		return null
	return app_container.get_child(0)


func _get_cipherlink() -> Node:
	return _get_app_content("cipherlink")


func _on_brief_delivered() -> void:
	GameState.brief_delivered = true


func _on_world_event(event_name: String) -> void:
	match event_name:
		"brief_delivered":
			_on_brief_delivered()
		
		"vpn_established":
			# Terminal handles this internally
			GameState.record_activity()
		
		"calloway_aware":
			ScriptManager.queue_message({
				"from": "cipher",
				"body": "ghost. calloway's machine just woke up.\nthey're in the archive.\n\nthey know someone's there.",
				"delay": 5.0
			})
			GameState.calloway_aware = true
		
		"archive_found":
			ScriptManager.queue_message({
				"from": "cipher",
				"body": "you found it. they're moving data out in real time.\n\nstart the extraction. we need everything.",
				"delay": 1.5
			})
		
		"wipe_in_progress":
			# Calloway's mid-wipe message arrives on the terminal
			var terminal: Node = _get_app_content("terminal")
			if terminal and terminal.has_method("receive_calloway_broadcast"):
				terminal.receive_calloway_broadcast()
			GameState.wipe_complete = false
		
		"alarm_fired":
			GameState.alarm_fired = true
			ScriptManager.queue_message({
				"from": "cipher",
				"body": "ghost.\n\nphysical security at calloway's building just got\nan alert. I'm watching their external dispatch system.\n\nthat's faster than it should be. I ran the timing\nagainst their security contract. the response team\nshouldn't have been notified for another six minutes\nminimum.\n\nI don't know what this is.\nthis wasn't in the brief.",
				"delay": 1.0
			})
			ScriptManager.queue_message({
				"from": "cipher",
				"body": "teams are moving. calloway's floor.\n\nghost — what do you want to do?",
				"delay": 5.0
			})
			# Show response options after 6 seconds
			await get_tree().create_timer(6.0).timeout
			var cl: Node = _get_cipherlink()
			if cl:
				cl.show_response_options([
					"can you warn them?",
					"not our job.",
				])
		
		"calloway_dead":
			ScriptManager.queue_message({
				"from": "cipher",
				"body": "ghost.\n\ncalloway is dead.\n\nthe report's being filed as accidental.\nthey're calling it a fall.\n\nI've seen these reports before.\nthis one is not that.\n\nthis is not what we were hired to do.",
				"delay": 1.0
			})
			ScriptManager.queue_message({
				"from": "cipher",
				"body": "talk to me.\n\nI need to know what you're thinking.",
				"delay": 180.0
			})
			_begin_ending_beat()
		
		"epilogue_begin":
			var cl: Node = _get_cipherlink()
			if cl:
				cl.activate_send_failed_mode()
			
			# Start epilogue message sequence
			_run_epilogue()
		
		"ending_beat_complete":
			_trigger_epilogue()
		
		_:
			# Check for ghost_sent_message events in ending beat
			if event_name.begins_with("ghost_sent_message:"):
				var message: String = event_name.substr("ghost_sent_message:".length())
				_handle_ghost_ending_response(message)
			else:
				print("World event: " + event_name)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_show_desktop_right_click(event.global_position)
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_objectives_board.toggle()
		get_viewport().set_input_as_handled()
	
	# DEBUG ONLY — remove before release
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			_debug_skip_to_ending_beat()


func _show_desktop_right_click(pos: Vector2) -> void:
	_right_click_menu.clear()
	_right_click_menu.add_item("Properties", 0)
	
	if not _right_click_menu.id_pressed.is_connected(_on_right_click_item):
		_right_click_menu.id_pressed.connect(_on_right_click_item)
	
	_right_click_menu.position = pos
	_right_click_menu.popup()


func _on_right_click_item(id: int) -> void:
	if id == 0:
		print("Properties clicked — wallpaper panel not yet implemented")


func _on_icon_input(event: InputEvent, app_name: String) -> void:
	if not event is InputEventMouseButton:
		return
	
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	# Check for double-click
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var last_time: float = _last_click_time.get(app_name, 0.0)
	var time_diff: float = current_time - last_time
	
	if time_diff < DOUBLE_CLICK_TIME:
		# Double-click detected!
		open_app(app_name)
		GameState.record_activity()
		_last_click_time[app_name] = 0.0  # Reset to prevent triple-click
	else:
		# First click - just record the time
		_last_click_time[app_name] = current_time


func set_notification(app_name: String, active: bool) -> void:
	_notifications[app_name] = active
	# Visual notification on icons will be added in the styling pass


func _begin_ending_beat() -> void:
	await get_tree().create_timer(182.0).timeout
	var cl: Node = _get_cipherlink()
	if cl and cl.has_method("show_ending_beat_options"):
		cl.show_ending_beat_options()


func _handle_ghost_ending_response(message: String) -> void:
	match message:
		"we didn't know.":
			ScriptManager.queue_message({
				"from": "cipher",
				"body": "yeah.\n\nwe didn't.\n\nI'm going to need to sit with that for a while.",
				"delay": 4.0
			})
			GameState.set_flag("ghost_rationalized", true)
		
		"we were used.":
			ScriptManager.queue_message({
				"from": "cipher",
				"body": "yes. we were.\n\nI checked that routing twice.\nit came back cold both times.\n\nwhoever built this operation knew we'd check it.\ndesigned it to come back clean.\n\nwe were supposed to be standing\nexactly where we stood.",
				"delay": 4.0
			})
			GameState.set_flag("ghost_named_it", true)
		
		"I read the archive.":
			ScriptManager.queue_message({
				"from": "cipher",
				"body": "...\n\nwhat was in it?",
				"delay": 4.0
			})
			GameState.set_flag("cipher_knows_truth", true)
		
		"the response time was wrong.":
			ScriptManager.queue_message({
				"from": "cipher",
				"body": "I know.\n\nI've been trying to figure out how they got\nthere that fast. the math doesn't work for\na standard response contract.\n\npre-staged. had to be.\n\nwhich means someone wanted them dead.\nnot just the files gone.",
				"delay": 4.0
			})
			GameState.set_flag("ghost_flagged_timing", true)
		
		"I need to find out who the client is.":
			ScriptManager.queue_message({
				"from": "cipher",
				"body": "yeah.\n\nyeah, I think so too.",
				"delay": 4.0
			})
			GameState.set_flag("client_investigation_flagged", true)


func _trigger_epilogue() -> void:
	ScriptManager.queue_message({
		"from": "cipher",
		"body": "get some rest.\n\nwe'll figure out what we do with this\nin the morning.",
		"delay": 3.0
	})
	await get_tree().create_timer(10.0).timeout
	ScriptManager.fire_event("epilogue_begin")


func _run_epilogue() -> void:
	# Epilogue messages from Cipher over time
	# Days pass, messages go unanswered
	var epilogue_messages: Array = [
		{"body": "checking in.", "delay": 5.0},
		{"body": "found something in the client routing.\nnot sure what it means yet.\nwant to look at it together?", "delay": 12.0},
		{"body": "I hope you're alright.", "delay": 22.0},
		{"body": "still here.", "delay": 35.0},
	]
	
	for msg: Dictionary in epilogue_messages:
		await get_tree().create_timer(msg["delay"]).timeout
		ScriptManager.queue_message({
			"from": "cipher",
			"body": msg["body"],
			"delay": 0.0
		})
	
	# Final message
	await get_tree().create_timer(50.0).timeout
	ScriptManager.queue_message({
		"from": "cipher",
		"body": "wherever you went, I hope it's somewhere quiet.\ntake care of yourself.\n— c",
		"delay": 0.0
	})
	
	# After final message, wait then show title card
	await get_tree().create_timer(15.0).timeout
	_show_title_card()


func _show_title_card() -> void:
	# Fade to black then show "Two years later."
	# For now just print to confirm it fires
	print("TITLE CARD: Two years later.")


func _debug_skip_to_ending_beat() -> void:
	# Set all state flags as if the full sequence completed
	GameState.vpn_established = true
	GameState.archive_located = true
	GameState.transfer_complete = true
	GameState.wipe_complete = true
	GameState.logs_cleared = true
	GameState.calloway_aware = true
	GameState.alarm_fired = true
	GameState.objective_stage = 6
	GameState.brief_delivered = true
	
	# Set some story flags for variety
	GameState.ghost_read_readme = true
	GameState.ghost_knows_mayas_name = true
	
	# Advance objectives board to complete
	_objectives_board.refresh()
	
	# Open CipherLink if not already open
	if "cipherlink" not in _open_windows:
		open_app("cipherlink")
	
	# Wait a frame for CipherLink to initialise
	await get_tree().process_frame
	
	# Queue Calloway's death message then trigger ending beat
	ScriptManager.queue_message({
		"from": "cipher",
		"body": "ghost.\n\ncalloway is dead.\n\nthe report's being filed as accidental.\nthey're calling it a fall.\n\nI've seen these reports before.\nthis one is not that.\n\nthis is not what we were hired to do.",
		"delay": 1.0
	})
	
	await get_tree().create_timer(3.0).timeout
	_begin_ending_beat()
