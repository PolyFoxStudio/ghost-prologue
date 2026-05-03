class_name Notepad
extends VBoxContainer

var _tabs: Array = []
var _active_tab: int = -1

@onready var _editor: TextEdit = $Editor
@onready var _tab_list: HBoxContainer = $TabBar/TabBarInner/TabList
@onready var _add_btn: Button = $TabBar/TabBarInner/AddTabButton
@onready var _rename_btn: Button = $TabBar/TabBarInner/RenameButton
@onready var _delete_btn: Button = $TabBar/TabBarInner/DeleteButton

func _ready() -> void:
	# Apply theme overrides to TextEdit
	_editor.add_theme_color_override("background_color", Color("#0d0d0d"))
	_editor.add_theme_color_override("font_color", Color("#d4d4d4"))
	_editor.add_theme_font_size_override("font_size", 13)
	_editor.add_theme_color_override("caret_color", Color("#d4d4d4"))
	_editor.add_theme_color_override("selection_color", Color("#2a2a2a"))
	
	# Apply theme to buttons
	_add_btn.add_theme_color_override("font_color", Color("#4a4a4a"))
	_add_btn.add_theme_color_override("font_color_hover", Color("#d4d4d4"))
	_add_btn.add_theme_font_size_override("font_size", 14)
	
	_rename_btn.add_theme_color_override("font_color", Color("#8a8a8a"))
	_rename_btn.add_theme_color_override("font_color_hover", Color("#d4d4d4"))
	_rename_btn.add_theme_font_size_override("font_size", 11)
	_delete_btn.add_theme_color_override("font_color", Color("#8a8a8a"))
	_delete_btn.add_theme_color_override("font_color_hover", Color("#d4d4d4"))
	_delete_btn.add_theme_font_size_override("font_size", 11)
	
	# Style the TabBar background
	var tab_bar: PanelContainer = $TabBar
	var tab_bar_style: StyleBoxFlat = StyleBoxFlat.new()
	tab_bar_style.bg_color = Color("#0d0d0d")
	tab_bar_style.set_border_width(SIDE_BOTTOM, 1)
	tab_bar_style.border_color = Color("#3a3a3a")
	tab_bar_style.content_margin_left = 4
	tab_bar_style.content_margin_right = 4
	tab_bar_style.content_margin_top = 4
	tab_bar_style.content_margin_bottom = 4
	tab_bar.add_theme_stylebox_override("panel", tab_bar_style)
	
	# Connect signals
	_add_btn.pressed.connect(_add_blank_tab)
	_rename_btn.pressed.connect(_rename_active_tab)
	_delete_btn.pressed.connect(_delete_active_tab)
	_editor.text_changed.connect(_on_text_changed)
	
	# Load state from GameState
	if GameState.notepad_tabs.is_empty():
		_tabs = []
		_add_blank_tab()
	else:
		_tabs = GameState.notepad_tabs.duplicate(true)
		_switch_to_tab(GameState.notepad_active_tab)
	
	load_pending_content()
	_editor.grab_focus()

func load_pending_content() -> void:
	var content: String = GameState.get("_pending_notepad_content")
	var filename: String = GameState.get("_pending_notepad_filename")
	if content != null and content != "":
		_add_tab(filename if filename != "" else "untitled", content)
		GameState.set("_pending_notepad_content", "")
		GameState.set("_pending_notepad_filename", "")

func _sync_state() -> void:
	GameState.notepad_tabs = _tabs.duplicate(true)
	GameState.notepad_active_tab = _active_tab

func _add_blank_tab() -> void:
	_add_tab("untitled", "")

func _add_tab(name: String, content: String) -> void:
	if _active_tab >= 0 and _active_tab < _tabs.size():
		_tabs[_active_tab]["content"] = _editor.text
		_tabs[_active_tab]["scroll_pos"] = _editor.scroll_vertical
	
	var tab: Dictionary = {
		"name": name,
		"content": content,
		"scroll_pos": 0
	}
	_tabs.append(tab)
	
	_rebuild_tab_bar()
	_switch_to_tab(_tabs.size() - 1)

func _switch_to_tab(index: int) -> void:
	if _active_tab >= 0 and _active_tab < _tabs.size():
		_tabs[_active_tab]["content"] = _editor.text
		_tabs[_active_tab]["scroll_pos"] = _editor.scroll_vertical
	
	_active_tab = clamp(index, 0, _tabs.size() - 1)
	
	if _active_tab >= 0 and _active_tab < _tabs.size():
		_editor.text = _tabs[_active_tab]["content"]
		_editor.scroll_vertical = _tabs[_active_tab]["scroll_pos"]
	
	_rebuild_tab_bar()
	_update_window_title()
	_sync_state()
	_editor.grab_focus()

func _rebuild_tab_bar() -> void:
	for child in _tab_list.get_children():
		_tab_list.remove_child(child)
		child.queue_free()
	
	for i in range(_tabs.size()):
		var tab: Dictionary = _tabs[i]
		var tab_container: PanelContainer = PanelContainer.new()
		
		var style_box: StyleBoxFlat = StyleBoxFlat.new()
		if i == _active_tab:
			style_box.bg_color = Color("#2a2a2a")
		else:
			style_box.bg_color = Color("#1a1a1a")
		
		style_box.set_border_width_all(1)
		style_box.border_color = Color("#3a3a3a")
		style_box.set_corner_radius_all(4)
		style_box.content_margin_left = 8
		style_box.content_margin_right = 8
		style_box.content_margin_top = 4
		style_box.content_margin_bottom = 4
		
		tab_container.add_theme_stylebox_override("panel", style_box)
		
		var inner_hbox: HBoxContainer = HBoxContainer.new()
		inner_hbox.add_theme_constant_override("separation", 4)
		
		var tab_button: Button = Button.new()
		tab_button.text = tab["name"]
		tab_button.flat = true
		tab_button.focus_mode = Control.FOCUS_NONE
		tab_button.add_theme_font_size_override("font_size", 11)
		
		if i == _active_tab:
			tab_button.add_theme_color_override("font_color", Color("#e8e8e8"))
		else:
			tab_button.add_theme_color_override("font_color", Color("#8a8a8a"))
		
		tab_button.pressed.connect(_switch_to_tab.bind(i))
		
		inner_hbox.add_child(tab_button)
		
		if _tabs.size() > 1:
			var close_btn: Button = Button.new()
			close_btn.text = "×"
			close_btn.flat = true
			close_btn.focus_mode = Control.FOCUS_NONE
			close_btn.add_theme_color_override("font_color", Color("#4a4a4a"))
			close_btn.add_theme_color_override("font_color_hover", Color("#cc3333"))
			close_btn.custom_minimum_size = Vector2(16, 16)
			close_btn.pressed.connect(_close_tab.bind(i))
			
			inner_hbox.add_child(close_btn)
		
		tab_container.add_child(inner_hbox)
		_tab_list.add_child(tab_container)

func _rename_active_tab() -> void:
	if _active_tab < 0:
		return
	var current_name: String = _tabs[_active_tab]["name"]
	var new_name: String = await _show_rename_dialog(current_name)
	if new_name != "" and new_name != current_name:
		_tabs[_active_tab]["name"] = new_name
		_rebuild_tab_bar()
		_update_window_title()
		_sync_state()

func _show_rename_dialog(current_name: String) -> String:
	var new_name: String = ""
	var dialog = AcceptDialog.new()
	dialog.title = "Rename Tab"
	
	var line_edit = LineEdit.new()
	line_edit.text = current_name
	line_edit.select_all()
	dialog.add_child(line_edit)
	
	get_tree().root.add_child(dialog)
	dialog.popup_centered(Vector2(300, 100))
	
	await dialog.confirmed
	new_name = line_edit.text.strip_edges()
	dialog.queue_free()
	
	return new_name if new_name != "" else current_name

func _delete_active_tab() -> void:
	if _tabs.size() <= 1:
		return
	_close_tab(_active_tab)

func _close_tab(index: int) -> void:
	if _tabs.size() <= 1:
		return
	
	# If we are closing the active tab, don't let _switch_to_tab save the current text 
	# over the next tab's data.
	if index == _active_tab:
		_active_tab = -1
	elif index < _active_tab:
		_active_tab -= 1
	
	_tabs.remove_at(index)
	
	var next_tab = clamp(_active_tab, 0, _tabs.size() - 1)
	if _active_tab == -1: # We closed the active one
		next_tab = clamp(index, 0, _tabs.size() - 1)
	
	_switch_to_tab(next_tab)

func _on_text_changed() -> void:
	if _active_tab < 0:
		return
	
	_tabs[_active_tab]["content"] = _editor.text
	_sync_state()
	GameState.record_activity()

func _update_window_title() -> void:
	var app_window: Node = get_parent()
	while app_window != null:
		if "title" in app_window:
			break
		app_window = app_window.get_parent()
	
	if app_window and "title" in app_window:
		var name: String = _tabs[_active_tab]["name"] if _active_tab >= 0 else "untitled"
		app_window.title = "notepad — " + name

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_A and event.ctrl_pressed:
			_editor.select_all()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_W and event.ctrl_pressed:
			_close_tab(_active_tab)
			get_viewport().set_input_as_handled()
