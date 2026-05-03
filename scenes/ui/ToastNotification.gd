extends PanelContainer

class_name ToastNotification


func _ready() -> void:
	# Add visible background
	var stylebox: StyleBoxFlat = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	stylebox.border_width_top = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.2, 0.8, 1, 0.8)
	stylebox.corner_radius_top_left = 4
	stylebox.corner_radius_top_right = 4
	stylebox.corner_radius_bottom_left = 4
	stylebox.corner_radius_bottom_right = 4
	stylebox.content_margin_left = 12
	stylebox.content_margin_right = 12
	stylebox.content_margin_top = 8
	stylebox.content_margin_bottom = 8
	add_theme_stylebox_override("panel", stylebox)
	
	# Position in bottom-right corner above taskbar
	var screen: Vector2 = get_viewport_rect().size
	position = Vector2(screen.x - 320, screen.y - 90)
	modulate.a = 0.0
	_animate_in()


func _animate_in() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	await tween.finished
	await get_tree().create_timer(3.0).timeout
	_animate_out()


func _animate_out() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()
