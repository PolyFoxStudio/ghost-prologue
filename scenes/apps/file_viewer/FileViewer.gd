extends VBoxContainer

@onready var _editor: TextEdit = $Editor

func _ready() -> void:
	# Styling
	_editor.add_theme_color_override("background_color", Color("#0d0d0d"))
	_editor.add_theme_color_override("font_color", Color("#d4d4d4"))
	_editor.add_theme_font_size_override("font_size", 13)
	_editor.add_theme_color_override("caret_color", Color("#d4d4d4"))
	_editor.add_theme_color_override("selection_color", Color("#2a2a2a"))
	
	var content: String = GameState.get("_pending_viewer_content")
	var filename: String = GameState.get("_pending_viewer_filename")
	
	if content != null:
		_editor.text = content
	
	_update_title(filename if filename != "" else "viewer")
	
	# Clear pending state
	GameState.set("_pending_viewer_content", "")
	GameState.set("_pending_viewer_filename", "")

func _update_title(display_name: String) -> void:
	var app_window: Node = get_parent()
	while app_window != null:
		if "title" in app_window:
			break
		app_window = app_window.get_parent()
	
	if app_window and "title" in app_window:
		app_window.title = "viewer — " + display_name
