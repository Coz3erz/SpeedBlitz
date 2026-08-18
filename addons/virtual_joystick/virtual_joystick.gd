@tool
extends Control
class_name VirtualJoystick

# Signals
signal joystick_moved(direction: Vector2)
signal joystick_released

# Settings
@export var dynamic_mode: bool = true
@export var deadzone: float = 0.1
@export var joystick_size: float = 120.0
@export var stick_size: float = 50.0
@export var max_distance: float = 70.0
@export var auto_hide: bool = true
@export var fade_speed: float = 5.0

# Screen confinement
@export var confine_initial_tap_to_left: bool = true
@export var screen_margin: float = 50.0

# Colors
@export var outer_color: Color = Color(1, 1, 1, 0.3)
@export var inner_color: Color = Color(1, 1, 1, 0.7)

# State
var is_active: bool = false
var touch_index: int = -1
var joystick_position: Vector2
var stick_position: Vector2
var current_direction: Vector2 = Vector2.ZERO
var opacity: float = 0.0
var screen_size: Vector2 = Vector2.ZERO
var screen_center_x: float = 0.0
var left_half_boundary: float = 0.0

func _ready():
	if !DisplayServer.is_touchscreen_available():
		return
	
	# Get screen size
	screen_size = get_viewport_rect().size
	screen_center_x = screen_size.x / 2.0
	left_half_boundary = screen_center_x
	
	# Cover entire screen for touch input
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Make this control transparent to mouse but receive all input
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Start hidden if in dynamic mode
	if dynamic_mode and auto_hide:
		opacity = 0.0
		modulate.a = opacity
		visible = false
	else:
		opacity = 1.0
		modulate.a = opacity
		visible = true
	
	# Set initial positions
	joystick_position = Vector2(joystick_size + screen_margin, screen_size.y - joystick_size - screen_margin)
	stick_position = joystick_position
	
	# Draw on top of everything
	z_index = 999
	
	# Connect to viewport resize
	if not Engine.is_editor_hint():
		get_viewport().size_changed.connect(_on_viewport_resized)
	
	# DEBUG: Print to confirm setup
	print("VirtualJoystick Ready - Screen size: ", screen_size)

func _process(delta):
	if !DisplayServer.is_touchscreen_available():
		return
	
	# Fade in/out
	if dynamic_mode and auto_hide:
		if is_active and opacity < 1.0:
			opacity = min(opacity + fade_speed * delta, 1.0)
			modulate.a = opacity
		elif not is_active and opacity > 0.0:
			opacity = max(opacity - fade_speed * delta, 0.0)
			modulate.a = opacity
			
			# Hide completely when invisible
			if opacity <= 0.0:
				visible = false
				# Reset position when hidden
				stick_position = joystick_position
				current_direction = Vector2.ZERO
	
	queue_redraw()

func _draw():
	if !DisplayServer.is_touchscreen_available():
		return
	
	if not visible and not Engine.is_editor_hint():
		return
	
	# Only draw in editor or when visible
	if Engine.is_editor_hint() or opacity > 0.0:
		# Draw outer circle (joystick base)
		draw_circle(joystick_position, joystick_size, outer_color * Color(1, 1, 1, opacity))
		
		# Draw inner circle (stick)
		draw_circle(stick_position, stick_size, inner_color * Color(1, 1, 1, opacity))
		
		# Draw left half boundary line (for debugging)
		if Engine.is_editor_hint() and confine_initial_tap_to_left:
			draw_line(Vector2(left_half_boundary, 0), Vector2(left_half_boundary, screen_size.y), Color.RED, 2.0)

# USE _unhandled_input INSTEAD OF _gui_input - This gets called BEFORE other UI elements
func _unhandled_input(event):
	if Engine.is_editor_hint():
		return
	
	if !DisplayServer.is_touchscreen_available():
		return
	
	# Handle touch events
	if event is InputEventScreenTouch:
		_handle_touch_event(event)
	
	elif event is InputEventScreenDrag:
		_handle_drag_event(event)

func _handle_touch_event(event: InputEventScreenTouch):
	if event.pressed:
		# Check if this is a new touch on the left side
		if confine_initial_tap_to_left and event.position.x > left_half_boundary:
			return  # Ignore right side touches
		
		# Only start if we're not already active
		if not is_active and touch_index == -1:
			touch_index = event.index
			
			# Position joystick at touch location
			if dynamic_mode:
				# Clamp position to keep joystick fully on screen
				var clamped_x = clamp(event.position.x, joystick_size + screen_margin, screen_size.x - joystick_size - screen_margin)
				var clamped_y = clamp(event.position.y, joystick_size + screen_margin, screen_size.y - joystick_size - screen_margin)
				
				joystick_position = Vector2(clamped_x, clamped_y)
				stick_position = joystick_position
				visible = true
				is_active = true
				opacity = 0.3
				modulate.a = opacity
				
				print("Joystick STARTED with touch index: ", touch_index, " at position: ", joystick_position)
			
			# Process initial position
			_update_stick_position(event.position)
			
			# Mark event as handled to prevent other controls from using it
			get_tree().get_root().set_input_as_handled()
	
	elif not event.pressed:
		# Only release if this is OUR touch
		if event.index == touch_index:
			print("Joystick RELEASED - touch index: ", touch_index)
			_release_joystick()
			get_tree().get_root().set_input_as_handled()

func _handle_drag_event(event: InputEventScreenDrag):
	# Only process drag if it's OUR touch
	if is_active and event.index == touch_index:
		# Allow drag anywhere on screen
		_update_stick_position(event.position)
		get_tree().get_root().set_input_as_handled()

func _update_stick_position(touch_pos: Vector2):
	if not is_active:
		return
	
	# Calculate direction from joystick center
	var direction = touch_pos - joystick_position
	var distance = direction.length()
	
	# Limit stick movement
	if distance > max_distance:
		direction = direction.normalized() * max_distance
		distance = max_distance
	
	# Update stick position
	stick_position = joystick_position + direction
	
	# Calculate normalized direction (0 to 1)
	if distance > 0:
		current_direction = direction.normalized() * (distance / max_distance)
		
		# Apply deadzone
		if current_direction.length() < deadzone:
			current_direction = Vector2.ZERO
	else:
		current_direction = Vector2.ZERO
	
	# Emit signal
	joystick_moved.emit(current_direction)
	
	# Update input actions
	_update_input_actions()
	
	# Update visuals
	queue_redraw()

func _update_input_actions():
	# Clear all movement actions first
	_clear_movement_actions()
	
	# Only set actions if we're outside deadzone
	if current_direction.length() > deadzone:
		# Horizontal movement
		if current_direction.x > 0.1:  # Right
			_create_and_parse_action("move_right", current_direction.x)
		elif current_direction.x < -0.1:  # Left
			_create_and_parse_action("move_left", abs(current_direction.x))
		
		# Vertical movement
		if current_direction.y > 0.1:  # Down
			_create_and_parse_action("move_down", current_direction.y)
		elif current_direction.y < -0.1:  # Up
			_create_and_parse_action("move_up", abs(current_direction.y))

func _create_and_parse_action(action_name: String, strength: float):
	var event = InputEventAction.new()
	event.action = action_name
	event.pressed = true
	event.strength = clamp(strength, 0.0, 1.0)
	Input.parse_input_event(event)

func _clear_movement_actions():
	# Release all movement actions
	var actions = ["move_left", "move_right", "move_up", "move_down"]
	
	for action in actions:
		if InputMap.has_action(action):
			var event = InputEventAction.new()
			event.action = action
			event.pressed = false
			event.strength = 0.0
			Input.parse_input_event(event)

func _release_joystick():
	touch_index = -1
	is_active = false
	
	# Reset stick
	stick_position = joystick_position
	current_direction = Vector2.ZERO
	
	# Clear all input actions
	_clear_movement_actions()
	
	# Emit signal
	joystick_released.emit()
	
	print("Joystick released, current state: is_active=", is_active, " touch_index=", touch_index)

# Mouse handling for editor testing (commented out by default)
func _input(event):
	if Engine.is_editor_hint():
		return
	
	# UNCOMMENT FOR DESKTOP TESTING
	# if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
	#     var touch_event = InputEventScreenTouch.new()
	#     touch_event.index = 999
	#     touch_event.position = event.position
	#     touch_event.pressed = event.pressed
	#     _handle_touch_event(touch_event)
	# 
	# elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
	#     var drag_event = InputEventScreenDrag.new()
	#     drag_event.index = 999
	#     drag_event.position = event.position
	#     _handle_drag_event(drag_event)

func _on_viewport_resized():
	if !DisplayServer.is_touchscreen_available():
		return
	
	# Update screen size
	screen_size = get_viewport_rect().size
	screen_center_x = screen_size.x / 2.0
	left_half_boundary = screen_center_x
	
	# Update joystick position for static mode
	if not dynamic_mode:
		joystick_position = Vector2(joystick_size + screen_margin, screen_size.y - joystick_size - screen_margin)
		stick_position = joystick_position
	
	queue_redraw()

func _on_mouse_entered():
	pass

func _on_mouse_exited():
	pass

# Public API
func get_direction() -> Vector2:
	return current_direction

func get_raw_direction() -> Vector2:
	return current_direction

func is_pressed() -> bool:
	return is_active

func set_joystick_size(size: float):
	joystick_size = size
	queue_redraw()

func set_stick_size(size: float):
	stick_size = size
	queue_redraw()

func set_static_position(pos: Vector2):
	if not dynamic_mode:
		joystick_position = pos
		stick_position = pos
		queue_redraw()

func set_left_half_boundary(boundary_x: float):
	left_half_boundary = boundary_x
	queue_redraw()
