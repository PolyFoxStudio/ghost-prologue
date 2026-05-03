extends HSplitContainer

var _vfs: VirtualFileSystem
var _current_path: String = "/home/ghost"
var _selected_entry: String = ""

@onready var _tree_container: VBoxContainer = %TreeContainer
@onready var _content_container: VBoxContainer = %ContentContainer
@onready var _path_label: Label = %PathLabel


func _ready() -> void:
	# Create new VirtualFileSystem instance
	_vfs = VirtualFileSystem.new()
	
	# Set up VFS state based on game flags
	if GameState.brief_delivered:
		_vfs.deliver_brief_archive()
	if GameState.transfer_complete == false and GameState.brief_delivered:
		_vfs.populate_brief()
	
	# Connect to world events
	ScriptManager.world_event_fired.connect(_on_world_event)
	
	# Build UI
	_build_tree()
	_show_directory(_current_path)


func _on_world_event(event_name: String) -> void:
	match event_name:
		"brief_delivered":
			_vfs.deliver_brief_archive()
			_refresh()
		"wipe_complete":
			_vfs.wipe_archive()
			_refresh()


func _build_tree() -> void:
	# Clear existing tree entries
	for child in _tree_container.get_children():
		child.queue_free()
	
	# Add root entry for home directory
	_add_tree_entry("~ (home)", "/home/ghost", 0)
	
	# Add common subdirectories
	_add_tree_entry("downloads", "/home/ghost/downloads", 1)
	_add_tree_entry("notes", "/home/ghost/notes", 1)
	_add_tree_entry(".config", "/home/ghost/.config", 1)


func _add_tree_entry(label: String, path: String, indent: int) -> void:
	var container: HBoxContainer = HBoxContainer.new()
	
	# Indentation with arrow indicator
	var indent_label: Label = Label.new()
	indent_label.text = "  ".repeat(indent) + "▶ "
	indent_label.add_theme_color_override("font_color", Color("#4a4a4a"))
	container.add_child(indent_label)
	
	# Directory button
	var btn: Button = Button.new()
	btn.text = label
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true
	btn.add_theme_color_override("font_color", Color("#8a8a8a"))
	btn.add_theme_color_override("font_hover_color", Color("#d4d4d4"))
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(_show_directory.bind(path))
	container.add_child(btn)
	
	_tree_container.add_child(container)


func _show_directory(path: String) -> void:
	_current_path = path
	_path_label.text = path.replace("/home/ghost", "~")
	
	# Clear existing content
	for child in _content_container.get_children():
		child.queue_free()
	
	# List directory contents
	var result = _vfs.list(path)
	
	if result == null or not (result is Array):
		_add_content_row("(empty)", "", "")
		return
	
	if result.is_empty():
		_add_content_row("(empty)", "", "")
		return
	
	for entry in result:
		var is_dir: bool = entry.ends_with("/")
		var entry_name: String = entry
		var entry_size: String = "" if is_dir else "—"
		var entry_modif: String = "—"
		_add_content_row(entry_name, entry_size, entry_modif)


func _add_content_row(entry_name: String, entry_size: String, entry_modif: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ContentRow"
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Name column
	var name_label: Label = Label.new()
	name_label.text = entry_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color("#d4d4d4"))
	name_label.add_theme_font_size_override("font_size", 12)
	row.add_child(name_label)
	
	# Size column
	var size_label: Label = Label.new()
	size_label.text = entry_size
	size_label.custom_minimum_size.x = 80
	size_label.add_theme_color_override("font_color", Color("#8a8a8a"))
	size_label.add_theme_font_size_override("font_size", 12)
	size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(size_label)
	
	# Modified column
	var modif_label: Label = Label.new()
	modif_label.text = entry_modif
	modif_label.custom_minimum_size.x = 80
	modif_label.add_theme_color_override("font_color", Color("#8a8a8a"))
	modif_label.add_theme_font_size_override("font_size", 12)
	modif_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(modif_label)
	
	# Connect input handling
	row.gui_input.connect(_on_entry_input.bind(entry_name))
	
	_content_container.add_child(row)


func _on_entry_input(event: InputEvent, entry_name: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				var full_path: String = _current_path + "/" + entry_name.trim_suffix("/")
				if entry_name.ends_with("/"):
					_show_directory(full_path)
					_vfs.on_directory_entered(full_path)
				else:
					_open_in_notepad(full_path)
		GameState.record_activity()


func _open_in_notepad(path: String) -> void:
	var content = _vfs.read_file(path)
	
	if content == null or not content is String:
		return
	if content == "PERMISSION_DENIED":
		return
	
	# Store content for Notepad to retrieve
	GameState.set("_pending_notepad_content", content)
	GameState.set("_pending_notepad_filename", path.get_file())
	
	# Fire event to open notepad
	ScriptManager.fire_event("open_notepad:" + path)


func _refresh() -> void:
	_build_tree()
	_show_directory(_current_path)
