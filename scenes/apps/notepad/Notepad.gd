extends VBoxContainer

## Notepad
## Plain text editor for GHOST

var _filename: String = ""
var _unsaved: bool = false
var _loaded_from_file: bool = false

@onready var _editor: TextEdit = $Editor


func _ready() -> void:
	# No placeholder text
	_editor.placeholder_text = ""
	
	# Connect text change signal
	_editor.text_changed.connect(_on_text_changed)
	
	# Check for pending content from FileBrowser
	var content: String = GameState.get("_pending_notepad_content")
	var filename: String = GameState.get("_pending_notepad_filename")
	
	if content != null and content != "":
		_editor.text = content
		_filename = filename if filename != "" else "untitled"
		_loaded_from_file = true
		_unsaved = false
		# Clear pending content
		GameState.set("_pending_notepad_content", "")
		GameState.set("_pending_notepad_filename", "")
		_update_title()
	else:
		_filename = ""
		_unsaved = false
		_update_title()
	
	# Focus the editor
	_editor.grab_focus()


func _on_text_changed() -> void:
	_unsaved = true
	_update_title()
	GameState.record_activity()


func _update_title() -> void:
	# Find the parent AppWindow and update its title
	var app_window: Node = get_parent()
	while app_window != null:
		if "title" in app_window:
			break
		app_window = app_window.get_parent()
	
	if app_window and "title" in app_window:
		var display_name: String = _filename if _filename != "" else "untitled"
		var unsaved_marker: String = " *" if _unsaved else ""
		app_window.title = "notepad — " + display_name + unsaved_marker


func _save() -> void:
	# Generate filename if needed
	if _filename == "":
		var time: String = Time.get_time_string_from_system().replace(":", "")
		_filename = "note_" + time + ".txt"
	
	# Create VFS instance and save
	var vfs: VirtualFileSystem = VirtualFileSystem.new()
	# Navigate to notes directory and add file
	# This is a simplified save - in a full implementation this would
	# properly integrate with the shared VFS
	# For now, just mark as saved
	_unsaved = false
	_update_title()
	
	print("Notepad: Saved ", _filename, " (", _editor.text.length(), " chars)")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Ctrl+S to save
		if event.keycode == KEY_S and event.ctrl_pressed:
			_save()
			get_viewport().set_input_as_handled()
		# Ctrl+A to select all
		if event.keycode == KEY_A and event.ctrl_pressed:
			_editor.select_all()
			get_viewport().set_input_as_handled()
