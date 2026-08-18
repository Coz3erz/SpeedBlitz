extends Node

@export var cursor_texture: Texture2D
@export var cursor_scale: float = 0.3
@export var stick_deadzone: float = 0.15
@export var cursor_speed: float = 12.0               # smooth, like the old script
@export var scroll_speed: float = 1.0

const BUTTON_CROSS = 0
const BUTTON_DPAD_UP = 11
const BUTTON_DPAD_DOWN = 12

var virtual_cursor: Sprite2D
var is_controller_connected: bool = false
var menu_states: Dictionary = {}
var _rebinding: bool = false

var mouse_mode_active: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

var prev_cross_pressed: bool = false
var click_pressed: bool = false

func _ready():
	process_mode = PROCESS_MODE_ALWAYS

	var canvas = CanvasLayer.new()
	canvas.layer = 128
	add_child(canvas)
	virtual_cursor = Sprite2D.new()
	if cursor_texture:
		virtual_cursor.texture = cursor_texture
	virtual_cursor.scale = Vector2(cursor_scale, cursor_scale)
	virtual_cursor.z_index = 128
	canvas.add_child(virtual_cursor)
	virtual_cursor.visible = false

	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _on_viewport_size_changed():
	if virtual_cursor and is_controller_connected:
		await get_tree().process_frame
		var vs = get_viewport().get_visible_rect().size
		virtual_cursor.position = vs / 2.0
		Input.warp_mouse(virtual_cursor.position)

func _input(event):
	# Switch to mouse mode when physical mouse is moved
	if event is InputEventMouseMotion and event.relative.length_squared() > 25.0:
		if not mouse_mode_active:
			mouse_mode_active = true
			_release_click()
			virtual_cursor.visible = false

	# Switch back to controller mode on any controller input
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var pressed = event.pressed if event is InputEventJoypadButton else true
		if pressed:
			if mouse_mode_active:
				mouse_mode_active = false
				last_mouse_pos = get_viewport().get_mouse_position()
				virtual_cursor.position = last_mouse_pos

func _process(delta):
	_check_controller_state()

	# ---- No controller: mouse is always visible, no virtual cursor ----
	if not is_controller_connected:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		virtual_cursor.visible = false
		_release_click()
		return

	# ---- Controller connected ----
	# If the user moved the physical mouse, let mouse mode take over
	if mouse_mode_active:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		virtual_cursor.visible = false
		_release_click()
		return

	# ---- Standard controller mode ----
	var player_exists = not get_tree().get_nodes_in_group("player").is_empty()
	var any_menu_open = false
	for state in menu_states.values():
		if state:
			any_menu_open = true
			break

	# Hide the real mouse ONLY during gameplay (player exists & not paused)
	var hide_mouse = (player_exists and not get_tree().paused)
	if hide_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Virtual cursor is used for menus or when the player is absent
	var use_virtual = get_tree().paused or not player_exists

	if use_virtual:
		_activate_controller_cursor(delta)
	else:
		virtual_cursor.visible = false
		_release_click()

	# Remember cross state for next frame
	prev_cross_pressed = Input.is_joy_button_pressed(0, BUTTON_CROSS)

func _check_controller_state():
	is_controller_connected = Input.get_connected_joypads().size() > 0

func _activate_controller_cursor(delta):
	virtual_cursor.visible = true

	# ---- Right stick movement (smooth) ----
	var rx = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if abs(rx) > stick_deadzone or abs(ry) > stick_deadzone:
		var vs = get_viewport().get_visible_rect().size
		virtual_cursor.position += Vector2(rx, ry) * cursor_speed * delta * 100.0
		virtual_cursor.position = virtual_cursor.position.clamp(Vector2.ZERO, vs)
		var screen_pos = virtual_cursor.position + get_viewport().get_visible_rect().position
		Input.warp_mouse(screen_pos)

	if _rebinding:
		return

	# ---- Left click (Cross button only) ----
	var cross_pressed = Input.is_joy_button_pressed(0, BUTTON_CROSS)
	if cross_pressed and not prev_cross_pressed:
		_simulate_mouse_button(true)
	elif not cross_pressed and click_pressed:
		_simulate_mouse_button(false)

	# ---- D‑pad / left stick scrolling ----
	var scroll_dir = 0.0
	if Input.is_joy_button_pressed(0, BUTTON_DPAD_UP):
		scroll_dir -= 1.0
	if Input.is_joy_button_pressed(0, BUTTON_DPAD_DOWN):
		scroll_dir += 1.0
	var ly = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if abs(ly) > stick_deadzone:
		scroll_dir += sign(ly)
	if scroll_dir != 0.0:
		_simulate_mouse_wheel(scroll_dir * scroll_speed * delta * 10.0)

func _simulate_mouse_button(pressed: bool):
	var ev = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = virtual_cursor.position
	Input.parse_input_event(ev)
	click_pressed = pressed

func _simulate_mouse_wheel(factor: float):
	var ev = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if factor > 0 else MOUSE_BUTTON_WHEEL_UP
	ev.factor = abs(factor)
	ev.pressed = true
	ev.position = virtual_cursor.position
	Input.parse_input_event(ev)

func _release_click():
	if click_pressed:
		_simulate_mouse_button(false)

func set_menu_open(menu_name: String, is_open: bool):
	menu_states[menu_name] = is_open

func set_rebinding(active: bool):
	_rebinding = active
