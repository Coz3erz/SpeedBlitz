extends CanvasLayer

signal resume_pressed

var transition = false
@export var background_style: StyleBoxFlat
@export var button_style: StyleBoxFlat
@export var button_hover_style: StyleBoxFlat
@export var button_pressed_style: StyleBoxFlat
@export var font: Font
@export var font_size: int = 32
@export var scale_multiplier: float = 2.5

var pause_menu: Control
var is_paused: bool = false
var options_menu: CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	create_pause_menu()
	options_menu = get_tree().root.find_child("OptionsMenu", true, false)
	if options_menu:
		if options_menu.has_signal("options_closed"):
			options_menu.options_closed.connect(_on_options_closed)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		# Don't toggle pause if options menu is open; instead, close options
		if options_menu and options_menu.visible:
			# Optionally, you can call apply_pending_changes before hiding
			if options_menu.has_method("apply_pending_changes"):
				options_menu.apply_pending_changes()
			options_menu.visible = false
			return
		toggle_pause()

func create_pause_menu():
	pause_menu = Control.new()
	pause_menu.name = "PauseMenu"
	pause_menu.visible = false
	pause_menu.anchor_right = 1.0
	pause_menu.anchor_bottom = 1.0
	pause_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pause_menu)

	var background = ColorRect.new()
	background.name = "Background"
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.color = Color(0, 0, 0, 0.7)
	if background_style:
		background.set("custom_styles/panel", background_style)
	pause_menu.add_child(background)

	var center_container = CenterContainer.new()
	center_container.name = "CenterContainer"
	center_container.anchor_right = 1.0
	center_container.anchor_bottom = 1.0
	center_container.offset_left = 0
	center_container.offset_top = 0
	center_container.offset_right = 0
	center_container.offset_bottom = 0
	pause_menu.add_child(center_container)

	var button_container = VBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.custom_minimum_size = Vector2(200, 150)
	center_container.add_child(button_container)

	var resume_button = create_button("Resume")
	var restart_button = create_button("Restart Level")
	var options_button = create_button("Options") 
	var quit_button = create_button("Quit To Menu")

	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	button_container.add_child(resume_button)
	button_container.add_child(restart_button)
	button_container.add_child(options_button)
	button_container.add_child(quit_button)

	button_container.add_theme_constant_override("separation", 20)

func create_button(text: String) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200, 50)

	if button_style:
		button.add_theme_stylebox_override("normal", button_style)
	if button_hover_style:
		button.add_theme_stylebox_override("hover", button_hover_style)
	if button_pressed_style:
		button.add_theme_stylebox_override("pressed", button_pressed_style)

	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.focus_mode = Control.FOCUS_NONE

	if font:
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", font_size)

	return button

func toggle_pause():
	if SceneManager.transition:
		return
	is_paused = !is_paused
	pause_menu.visible = is_paused
	get_tree().paused = is_paused

	# Notify the controller manager about menu state
	# When paused (menu open), we want mouse visible and controller virtual cursor.
	# When unpaused (menu closed), we want mouse hidden if controller is connected.
	ControllerMouse.set_menu_open("pause",is_paused)

func _on_resume_pressed():
	if is_paused:
		# Apply any pending options changes if options menu was open
		if options_menu and options_menu.visible:
			if options_menu.has_method("apply_pending_changes"):
				options_menu.apply_pending_changes()
			options_menu.visible = false
		emit_signal("resume_pressed")
		toggle_pause()

func _on_options_pressed():
	if options_menu and options_menu.has_method("show_options") and !Input.is_action_pressed("ui_cancel"):
		options_menu.set_meta("calling_pause_menu", self)
		options_menu.is_main_menu_mode = false
		pause_menu.visible = false
		options_menu.options_show()

func _on_quit_pressed():
	if options_menu and options_menu.visible:
		if options_menu.has_method("apply_pending_changes"):
			options_menu.apply_pending_changes()
		options_menu.visible = false
	SceneManager.change_scene(get_node("/root"), "res://scenes/main scenes/main_menu.tscn")

func _on_options_closed():
	# Options menu closed, show pause menu again
	pause_menu.visible = true
	# Since pause menu is still open (game is paused), notify controller
	ControllerMouse.set_menu_open("pause",true)

func on_options_closed():
	# This function might be called externally, but we'll use the signal connection above
	if is_paused:
		pause_menu.visible = true
		ControllerMouse.set_menu_open("pause",true)

func _on_restart_pressed():
	if options_menu and options_menu.visible:
		if options_menu.has_method("apply_pending_changes"):
			options_menu.apply_pending_changes()
		options_menu.visible = false
	SceneManager.restart_level()
	ControllerMouse.set_menu_open("pause",false)
