@tool
@icon("res://addons/virtual_joystick/icon.svg")
class_name MobileButtons
extends Node2D

#region Private Properties ======================================
var _ground_slam_button: TouchScreenButton
var _dash_button: TouchScreenButton
var _jump_button: TouchScreenButton

var _warnings: PackedStringArray = []
var _initialized: bool = false
#endregion Private Properties ====================================

#region Exports ===================================================
@export_category("Mobile Buttons")
@export var active: bool = true:
	set(value):
		active = value
		if not active and not Engine.is_editor_hint():
			_release_all_actions()
		_update_visibility()

@export_range(0.1, 2.0, 0.001, "suffix:x", "or_greater") var scale_factor: float = 1.0:
	set(value):
		scale_factor = value
		if _initialized:
			_apply_scale_to_buttons()
			_update_positions()

## Set to true to only show when touchscreen is detected
@export var only_touchscreen: bool = true:
	set(value):
		only_touchscreen = value
		_update_visibility()

@export_category("Button Textures")
@export var ground_slam_texture: Texture2D:
	set(value):
		ground_slam_texture = value
		if _initialized and _ground_slam_button:
			_ground_slam_button.texture_normal = value
			_update_button_visibility()
@export var ground_slam_pressed_texture: Texture2D:
	set(value):
		ground_slam_pressed_texture = value
		if _initialized and _ground_slam_button:
			_ground_slam_button.texture_pressed = value
@export var dash_texture: Texture2D:
	set(value):
		dash_texture = value
		if _initialized and _dash_button:
			_dash_button.texture_normal = value
			_update_button_visibility()
@export var dash_pressed_texture: Texture2D:
	set(value):
		dash_pressed_texture = value
		if _initialized and _dash_button:
			_dash_button.texture_pressed = value
@export var jump_texture: Texture2D:
	set(value):
		jump_texture = value
		if _initialized and _jump_button:
			_jump_button.texture_normal = value
			_update_button_visibility()
@export var jump_pressed_texture: Texture2D:
	set(value):
		jump_pressed_texture = value
		if _initialized and _jump_button:
			_jump_button.texture_pressed = value

@export_category("Button Actions")
@export var ground_slam_action: String = "ground_slam"
@export var dash_action: String = "dash"
@export var jump_action: String = "jump"

@export_category("Positioning")
## Center point for the triangle arrangement
@export var triangle_center: Vector2 = Vector2(300, 500):
	set(value):
		triangle_center = value
		if _initialized:
			_update_positions()
## Spacing between buttons in the triangle
@export var button_spacing: float = 80.0:
	set(value):
		button_spacing = value
		if _initialized:
			_update_positions()
## Button size (width and height)
@export var button_size: Vector2 = Vector2(100, 100):
	set(value):
		button_size = value
		if _initialized:
			_update_positions()
#endregion Exports =================================================

#region Engine Methods =============================================
func _init() -> void:
	_ground_slam_button = TouchScreenButton.new()
	_dash_button = TouchScreenButton.new()
	_jump_button = TouchScreenButton.new()

func _ready() -> void:
	add_child(_ground_slam_button)
	add_child(_dash_button)
	add_child(_jump_button)
	
	_configure_buttons()
	_initialized = true
	
	_update_positions()
	_update_visibility()
	
	if not Engine.is_editor_hint() and is_inside_tree() and get_tree():
		get_viewport().size_changed.connect(_on_viewport_resized)
	
	if not Engine.is_editor_hint():
		_connect_button_signals()

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	if not active or Engine.is_editor_hint():
		return

func _get_configuration_warnings() -> PackedStringArray:
	_warnings = []
	
	if not ground_slam_texture:
		_warnings.append("Ground slam button texture is not set.")
	if not dash_texture:
		_warnings.append("Dash button texture is not set.")
	if not jump_texture:
		_warnings.append("Jump button texture is not set.")
	
	if ground_slam_action == "":
		_warnings.append("Ground slam action is empty.")
	if dash_action == "":
		_warnings.append("Dash action is empty.")
	if jump_action == "":
		_warnings.append("Jump action is empty.")
	
	return _warnings
#endregion Engine Methods =============================================

#region Simple Mobile Detection ======================================
func _update_visibility() -> void:
	if Engine.is_editor_hint():
		return
	
	if not only_touchscreen:
		visible = true
		_update_button_visibility()
		return
	
	# SIMPLE: Check if touchscreen is available
	var has_touchscreen = DisplayServer.is_touchscreen_available()
	visible = has_touchscreen
	_update_button_visibility()
	
	if not has_touchscreen and not Engine.is_editor_hint():
		_release_all_actions()

func _update_button_visibility() -> void:
	if not _initialized:
		return
	
	var should_show = visible and (ground_slam_texture != null or dash_texture != null or jump_texture != null)
	_ground_slam_button.visible = ground_slam_texture != null and should_show
	_dash_button.visible = dash_texture != null and should_show
	_jump_button.visible = jump_texture != null and should_show
#endregion Simple Mobile Detection ====================================

#region Private Methods ============================================
func _configure_buttons() -> void:
	if ground_slam_texture:
		_ground_slam_button.texture_normal = ground_slam_texture
	if ground_slam_pressed_texture:
		_ground_slam_button.texture_pressed = ground_slam_pressed_texture
	_ground_slam_button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	_ground_slam_button.name = "GroundSlamButton"
	
	if dash_texture:
		_dash_button.texture_normal = dash_texture
	if dash_pressed_texture:
		_dash_button.texture_pressed = dash_pressed_texture
	_dash_button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	_dash_button.name = "DashButton"
	
	if jump_texture:
		_jump_button.texture_normal = jump_texture
	if jump_pressed_texture:
		_jump_button.texture_pressed = jump_pressed_texture
	_jump_button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	_jump_button.name = "JumpButton"
	
	_apply_scale_to_buttons()

func _update_positions() -> void:
	if not _initialized or Engine.is_editor_hint():
		return
	
	# Triangle arrangement around triangle_center:
	# Dash: Top right of center
	# Jump: Bottom right of center
	# Ground Slam: Left of center, vertically centered between dash and jump
	
	var dash_pos = triangle_center + Vector2(button_spacing, -button_spacing)
	var jump_pos = triangle_center + Vector2(button_spacing, button_spacing)
	var ground_slam_pos = triangle_center + Vector2(-button_spacing, 0)
	
	_dash_button.position = dash_pos
	_jump_button.position = jump_pos
	_ground_slam_button.position = ground_slam_pos

func _apply_scale_to_buttons() -> void:
	if not _initialized:
		return
	
	_ground_slam_button.scale = Vector2(scale_factor, scale_factor)
	_dash_button.scale = Vector2(scale_factor, scale_factor)
	_jump_button.scale = Vector2(scale_factor, scale_factor)
	
	if not Engine.is_editor_hint():
		_update_positions()

func _connect_button_signals() -> void:
	if Engine.is_editor_hint():
		return
	
	_ground_slam_button.pressed.connect(_on_ground_slam_pressed)
	_dash_button.pressed.connect(_on_dash_pressed)
	_jump_button.pressed.connect(_on_jump_pressed)
	
	_ground_slam_button.released.connect(_on_ground_slam_released)
	_dash_button.released.connect(_on_dash_released)
	_jump_button.released.connect(_on_jump_released)

func _on_ground_slam_pressed() -> void:
	if Engine.is_editor_hint():
		return
	
	if active and ground_slam_action and InputMap.has_action(ground_slam_action):
		Input.action_press(ground_slam_action)

func _on_ground_slam_released() -> void:
	if Engine.is_editor_hint():
		return
	
	if ground_slam_action and InputMap.has_action(ground_slam_action):
		Input.action_release(ground_slam_action)

func _on_dash_pressed() -> void:
	if Engine.is_editor_hint():
		return
	
	if active and dash_action and InputMap.has_action(dash_action):
		Input.action_press(dash_action)

func _on_dash_released() -> void:
	if Engine.is_editor_hint():
		return
	
	if dash_action and InputMap.has_action(dash_action):
		Input.action_release(dash_action)

func _on_jump_pressed() -> void:
	if Engine.is_editor_hint():
		return
	
	if active and jump_action and InputMap.has_action(jump_action):
		Input.action_press(jump_action)

func _on_jump_released() -> void:
	if Engine.is_editor_hint():
		return
	
	if jump_action and InputMap.has_action(jump_action):
		Input.action_release(jump_action)

func _release_all_actions() -> void:
	if Engine.is_editor_hint():
		return
	
	if ground_slam_action and InputMap.has_action(ground_slam_action):
		Input.action_release(ground_slam_action)
	if dash_action and InputMap.has_action(dash_action):
		Input.action_release(dash_action)
	if jump_action and InputMap.has_action(jump_action):
		Input.action_release(jump_action)

func _on_viewport_resized() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	
	call_deferred("_update_positions")
#endregion Private Methods ===========================================

#region Public Methods =============================================
func get_ground_slam_button() -> TouchScreenButton:
	return _ground_slam_button

func get_dash_button() -> TouchScreenButton:
	return _dash_button

func get_jump_button() -> TouchScreenButton:
	return _jump_button

func enable_buttons() -> void:
	active = true

func disable_buttons() -> void:
	active = false

func update_button_positions() -> void:
	_update_positions()

func set_custom_positions(ground_slam_pos: Vector2, dash_pos: Vector2, jump_pos: Vector2) -> void:
	_ground_slam_button.position = ground_slam_pos
	_dash_button.position = dash_pos
	_jump_button.position = jump_pos

func get_button_positions() -> Array[Vector2]:
	return [_ground_slam_button.position, _dash_button.position, _jump_button.position]

func get_triangle_layout() -> Array[Vector2]:
	return [_ground_slam_button.position, _dash_button.position, _jump_button.position]
#endregion Public Methods ============================================
