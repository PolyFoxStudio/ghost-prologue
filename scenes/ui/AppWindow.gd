extends PanelContainer

## AppWindow
## Reusable window chrome for all application windows in GHOST

# Signals
signal closed
signal focused
signal minimized

# Icon preloads
const ICON_MAXIMIZE: Texture2D = preload("res://assets/generated/icon_window_maximize_frame_0.png")
const ICON_RESTORE: Texture2D = preload("res://assets/generated/icon_window_restore_frame_0.png")

# Exported properties
@export var title: String = "app":
	set(value):
		title = value
		if is_inside_tree():
			_update_title()

@export var min_size: Vector2 = Vector2(320, 240)

# Internal state
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _resizing: bool = false
var _resize_start_pos: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
var _maximised: bool = false
var _pre_maximise_position: Vector2 = Vector2.ZERO
var _pre_maximise_size: Vector2 = Vector2.ZERO

# Node references
@onready var _title_label: Label = %TitleLabel
@onready var _title_bar: HBoxContainer = %TitleBar
@onready var _close_button: Button = %CloseButton
@onready var _minimise_button: Button = %MinimiseButton
@onready var _maximise_button: Button = %MaximiseButton
@onready var _resize_handle: Control = %ResizeHandle


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	
	if _close_button:
		_close_button.pressed.connect(_on_close)
		_close_button.mouse_entered.connect(_on_close_hover)
		_close_button.mouse_exited.connect(_on_close_unhover)
		
	if _minimise_button:
		_minimise_button.pressed.connect(_on_minimise)
		_minimise_button.mouse_entered.connect(_on_minimise_hover)
		_minimise_button.mouse_exited.connect(_on_minimise_unhover)
		
	if _maximise_button:
		_maximise_button.pressed.connect(_on_maximise)
		_maximise_button.mouse_entered.connect(_on_maximise_hover)
		_maximise_button.mouse_exited.connect(_on_maximise_unhover)
		
	if _title_bar:
		_title_bar.gui_input.connect(_on_titlebar_input)
		
	if _resize_handle:
		_resize_handle.gui_input.connect(_on_resize_input)
	
	focus_entered.connect(_on_focus_entered)
	
	_update_title()

func _on_focus_entered() -> void:
	_focus_app_content()

func _focus_app_content() -> void:
	var app_container: MarginContainer = get_node_or_null("VBoxContainer/AppContainer")
	if app_container and app_container.get_child_count() > 0:
		var content: Node = app_container.get_child(0)
		if content is Control:
			# Look for specific nodes that need focus like LineEdit in CipherLink
			var input_field: Control = content.find_child("InputField", true, false)
			if input_field:
				input_field.call_deferred("grab_focus")
			else:
				content.call_deferred("grab_focus")



func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_focus_app_content()

func _update_title() -> void:
	if _title_label:
		_title_label.text = title


func _on_close() -> void:
	closed.emit()
	queue_free()


func _on_minimise() -> void:
	minimize()


func minimize() -> void:
	visible = false
	minimized.emit()


func restore() -> void:
	visible = true
	_bring_to_front()
	_focus_app_content()


func _on_maximise() -> void:
	if _maximised:
		# Restore to previous size and position
		position = _pre_maximise_position
		size = _pre_maximise_size
		_maximised = false
		# Button text will be set by hover handlers
		_resize_handle.visible = true
	else:
		# Save current state and maximize
		_pre_maximise_position = position
		_pre_maximise_size = size
		var viewport_size: Vector2 = get_viewport_rect().size
		# Account for taskbar at top (32px height)
		position = Vector2(0, 32)
		size = Vector2(viewport_size.x, viewport_size.y - 32)
		_maximised = true
		# Button text will be set by hover handlers
		_resize_handle.visible = false


func _on_titlebar_input(event: InputEvent) -> void:
	if _maximised:
		# Double-click on title bar when maximized restores the window
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			_on_maximise()
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			# Double-click title bar to maximize
			_on_maximise()
			return
		
		_dragging = event.pressed
		if _dragging:
			_drag_offset = get_global_mouse_position() - global_position
			focused.emit()
			_bring_to_front()
			_focus_app_content()
	
	if event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset
		_clamp_to_screen()


func _on_resize_input(event: InputEvent) -> void:
	if _maximised:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_resizing = event.pressed
		if _resizing:
			_resize_start_pos = get_global_mouse_position()
			_resize_start_size = size
	
	if event is InputEventMouseMotion and _resizing:
		var new_size: Vector2 = _resize_start_size + (get_global_mouse_position() - _resize_start_pos)
		size = new_size.clamp(min_size, Vector2(9999, 9999))


func _bring_to_front() -> void:
	var parent: Node = get_parent()
	if parent:
		parent.move_child(self, parent.get_child_count() - 1)


func _clamp_to_screen() -> void:
	var screen: Vector2 = get_viewport_rect().size
	global_position.x = clampf(global_position.x, 0.0, screen.x - size.x)
	global_position.y = clampf(global_position.y, 0.0, screen.y - size.y)


# Hover effects for window control buttons
func _on_minimise_hover() -> void:
	_minimise_button.text = "−"

func _on_minimise_unhover() -> void:
	_minimise_button.text = "•"

func _on_maximise_hover() -> void:
	_maximise_button.text = "□"

func _on_maximise_unhover() -> void:
	_maximise_button.text = "•"

func _on_close_hover() -> void:
	_close_button.text = "×"

func _on_close_unhover() -> void:
	_close_button.text = "•"
