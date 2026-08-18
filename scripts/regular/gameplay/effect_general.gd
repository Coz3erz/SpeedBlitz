extends Node2D

# Effect Components
@onready var sprite = $effect_sprite
@onready var particles = $CPUParticles2D

# Activation Controls
@export var particle_active: bool = false
@export var sprite_active: bool = false

# Deletion Controls
@export var delete_on_sprite_animation_end: bool = false
@export var delete_on_particle_end: bool = false
@export var delete_after_duration: bool = false
@export var effect_duration: float = 0.0

# Sprite Animation Properties
@export var h_frames: int = 1
@export var v_frames: int = 1
@export var speed_scale: float = 1.0
@export var max_frames: int = 5
@export var sprite_loop: bool = false
@export var start_frame: int = 0

# Particle Properties
@export var particle_emitting: bool = false
@export var particle_one_shot: bool = true
@export var particle_explosiveness: float = 1.0
@export var particle_lifetime: float = 1.0
@export var particle_amount: int = 1

# Flip Controls
@export var sprite_flip_h: bool = false:
	set(value):
		sprite_flip_h = value
		if sprite:
			sprite.flip_h = value

@export var sprite_flip_v: bool = false:
	set(value):
		sprite_flip_v = value
		if sprite:
			sprite.flip_v = value

@export var particle_flip_h: bool = false:
	set(value):
		particle_flip_h = value
		if particles:
			particles.scale.x = -1.0 if value else 1.0

@export var particle_flip_v: bool = bool():
	set(value):
		particle_flip_v = value
		if particles:
			particles.scale.y = -1.0 if value else 1.0

# Dynamic Property Modifiers
@export var additive_quantities: PackedStringArray = []
@export var subtractive_quantities: PackedStringArray = []
@export var multiplicative_quantities: PackedStringArray = []
@export var property_modifiers: Dictionary = {}

# Scale controls for modification intensity
@export var additive_scale: float = 1.0
@export var subtractive_scale: float = 1.0
@export var multiplicative_scale: float = 1.0

# Timing and Sequencing
@export var start_delay: float = 0.0
@export var stagger_components: bool = false
@export var sprite_start_delay: float = 0.0
@export var particle_start_delay: float = 0.0

# Transform Animation
@export var rotate_speed: float = 0.0
@export var scale_over_time: Vector2 = Vector2.ONE
@export var scale_speed: float = 1.0
@export var move_direction: Vector2 = Vector2.ZERO
@export var move_speed: float = 0.0

# Color and Modulation
@export var modulate_over_time: Color = Color.WHITE
@export var modulate_speed: float = 1.0
@export var start_modulate: Color = Color.WHITE

# Internal tracking variables
var _current_frame: int = 0
var _frame_timer: float = 0.0
var _frame_duration: float = 0.1
var _effect_timer: float = 0.0
var _start_delay_timer: float = 0.0
var _sprite_delay_timer: float = 0.0
var _particle_delay_timer: float = 0.0
var _effect_started: bool = false
var _original_scale: Vector2
var _original_modulate: Color
var _frame_width: float = 0.0
var _frame_height: float = 0.0
var _total_frames: int = 0

# Signal for external control
signal effect_finished
signal sprite_animation_finished
signal particle_effect_finished

func _ready():
	if !OptionsFetch.fetch_setting("gameplay","particles_enabled",true):
		queue_free()
	# Make effect independent of parent modulation
	top_level = true
	self_modulate = Color.WHITE
	
	_initialize_effect()
	
	if start_delay > 0:
		_start_delay_timer = start_delay
	else:
		_start_effect_components()

func _initialize_effect():
	_original_scale = scale
	_original_modulate = modulate
	
	# Initialize sprite
	if sprite and sprite_active:
		_setup_sprite_animation()
		sprite.flip_h = sprite_flip_h
		sprite.flip_v = sprite_flip_v
	
	# Initialize particles
	if particles:
		particles.emitting = false
		# Apply particle flip using scale
		particles.scale.x = -1.0 if particle_flip_h else 1.0
		particles.scale.y = -1.0 if particle_flip_v else 1.0
		if particle_active and not stagger_components and start_delay <= 0:
			particles.emitting = true
	
	modulate = start_modulate

func _setup_sprite_animation():
	if not sprite or not sprite.texture:
		return
		
	# Fix: Ensure h_frames and v_frames are at least 1 to avoid division by zero
	h_frames = max(1, h_frames)
	v_frames = max(1, v_frames)
		
	_total_frames = h_frames * v_frames
	_frame_width = sprite.texture.get_width() / h_frames
	_frame_height = sprite.texture.get_height() / v_frames
	
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, _frame_width, _frame_height)
	
	# Fix: Ensure start_frame is within valid range
	_current_frame = clamp(start_frame, 0, _total_frames - 1)
	_update_sprite_frame()

func _update_sprite_frame():
	if not sprite or not sprite.texture:
		return
		
	var frame_x = (_current_frame % h_frames) * _frame_width
	@warning_ignore("integer_division")
	var frame_y = (_current_frame / h_frames) * _frame_height
	
	sprite.region_rect = Rect2(frame_x, frame_y, _frame_width, _frame_height)

func _start_effect_components():
	_effect_started = true
	
	# Start sprite with delay if staggered
	if sprite and sprite_active:
		if sprite_start_delay > 0:
			_sprite_delay_timer = sprite_start_delay
		else:
			_current_frame = start_frame
			_update_sprite_frame()
	
	# Start particles with delay if staggered
	if particles and particle_active:
		if particle_start_delay > 0:
			_particle_delay_timer = particle_start_delay
		else:
			particles.emitting = true

func _process(delta):
	# Handle start delay
	if _start_delay_timer > 0:
		_start_delay_timer -= delta
		if _start_delay_timer <= 0:
			_start_effect_components()
		return

	if not _effect_started:
		return
	
	# Update effect timer for duration-based deletion
	if delete_after_duration and effect_duration > 0:
		_effect_timer += delta
		if _effect_timer >= effect_duration:
			_finish_effect()
			return
	
	# Handle component delays
	_handle_component_delays(delta)
	
	# Update sprite animation
	if sprite and sprite_active and _sprite_delay_timer <= 0:
		_update_sprite_animation(delta)
	
	# Check for particle completion
	if particles and particle_active and _particle_delay_timer <= 0:
		_check_particle_completion()
	
	# Apply dynamic property modifications
	_apply_property_modifications(delta)
	
	# Apply transform animations
	_apply_transform_animations(delta)
	
	# Fix: Check for effect completion after all updates
	_check_effect_completion()

func _handle_component_delays(delta):
	# Handle sprite start delay
	if _sprite_delay_timer > 0:
		_sprite_delay_timer -= delta
		if _sprite_delay_timer <= 0 and sprite and sprite_active:
			_current_frame = start_frame
			_update_sprite_frame()
	
	# Handle particle start delay
	if _particle_delay_timer > 0:
		_particle_delay_timer -= delta
		if _particle_delay_timer <= 0 and particles and particle_active:
			particles.emitting = true

func _update_sprite_animation(delta):
	_frame_timer += delta * speed_scale
	
	var actual_frame_duration = _frame_duration / speed_scale if speed_scale > 0 else _frame_duration
	
	if _frame_timer >= actual_frame_duration:
		_frame_timer = 0
		_current_frame += 1
		
		# Handle animation completion
		if _current_frame >= min(max_frames, _total_frames):
			if sprite_loop:
				_current_frame = start_frame
			else:
				_current_frame = min(max_frames, _total_frames) - 1
				if delete_on_sprite_animation_end:
					sprite_active = false
				emit_signal("sprite_animation_finished")
		
		_update_sprite_frame()

func _check_particle_completion():
	if particles and particle_active and particle_one_shot and not particles.emitting:
		if delete_on_particle_end:
			particle_active = false
		emit_signal("particle_effect_finished")

func _apply_property_modifications(delta):
	# Apply additive quantities using set()
	for property in additive_quantities:
		_modify_property(property, delta, "add", additive_scale)
	
	# Apply subtractive quantities using set()
	for property in subtractive_quantities:
		_modify_property(property, delta, "subtract", subtractive_scale)
	
	# Apply multiplicative quantities using set()
	for property in multiplicative_quantities:
		_modify_property(property, delta, "multiply", multiplicative_scale)
	
	# Apply custom property modifiers
	for property in property_modifiers:
		_modify_property_custom(property, property_modifiers[property], delta)

func _modify_property(property: String, delta: float, operation: String, scale_value: float):
	# Fix: Use a safer approach to check if property exists
	if not property in self:
		return
		
	var current_value = get(property)
	
	if current_value != null:
		var new_value = current_value
		var scaled_delta = delta * scale_value
		
		match operation:
			"add":
				if current_value is float or current_value is int:
					new_value = current_value + scaled_delta
				elif current_value is Vector2:
					new_value = current_value + Vector2(scaled_delta, scaled_delta)
				elif current_value is Vector3:
					new_value = current_value + Vector3(scaled_delta, scaled_delta, scaled_delta)
				elif current_value is Color:
					new_value = Color(
						clamp(current_value.r + scaled_delta, 0.0, 1.0),
						clamp(current_value.g + scaled_delta, 0.0, 1.0),
						clamp(current_value.b + scaled_delta, 0.0, 1.0),
						clamp(current_value.a + scaled_delta, 0.0, 1.0)
					)
			"subtract":
				if current_value is float or current_value is int:
					new_value = current_value - scaled_delta
				elif current_value is Vector2:
					new_value = current_value - Vector2(scaled_delta, scaled_delta)
				elif current_value is Vector3:
					new_value = current_value - Vector3(scaled_delta, scaled_delta, scaled_delta)
				elif current_value is Color:
					new_value = Color(
						clamp(current_value.r - scaled_delta, 0.0, 1.0),
						clamp(current_value.g - scaled_delta, 0.0, 1.0),
						clamp(current_value.b - scaled_delta, 0.0, 1.0),
						clamp(current_value.a - scaled_delta, 0.0, 1.0)
					)
			"multiply":
				if current_value is float or current_value is int:
					new_value = current_value * (1.0 + scaled_delta)
				elif current_value is Vector2:
					new_value = current_value * (1.0 + scaled_delta)
				elif current_value is Vector3:
					new_value = current_value * (1.0 + scaled_delta)
				elif current_value is Color:
					new_value = Color(
						clamp(current_value.r * (1.0 + scaled_delta), 0.0, 1.0),
						clamp(current_value.g * (1.0 + scaled_delta), 0.0, 1.0),
						clamp(current_value.b * (1.0 + scaled_delta), 0.0, 1.0),
						clamp(current_value.a * (1.0 + scaled_delta), 0.0, 1.0)
					)
		
		set(property, new_value)

func _modify_property_custom(property: String, value: float, delta: float):
	# Fix: Use a safer approach to check if property exists
	if not property in self:
		return
		
	var current_value = get(property)
	
	if current_value != null:
		var new_value = current_value
		
		if current_value is float or current_value is int:
			new_value = current_value + value * delta
		elif current_value is Vector2:
			new_value = current_value + Vector2(value, value) * delta
		elif current_value is Vector3:
			new_value = current_value + Vector3(value, value, value) * delta
		elif current_value is Color:
			new_value = Color(
				clamp(current_value.r + value * delta, 0.0, 1.0),
				clamp(current_value.g + value * delta, 0.0, 1.0),
				clamp(current_value.b + value * delta, 0.0, 1.0),
				clamp(current_value.a + value * delta, 0.0, 1.0)
			)
		
		set(property, new_value)

func _apply_transform_animations(delta):
	# Rotation
	if rotate_speed != 0:
		rotation_degrees += rotate_speed * delta
	
	# Scale interpolation
	if scale_over_time != Vector2.ONE:
		scale = scale.lerp(scale_over_time, scale_speed * delta)
	
	# Movement
	if move_direction != Vector2.ZERO and move_speed > 0:
		position += move_direction.normalized() * move_speed * delta
	
	# Color modulation interpolation
	if modulate_over_time != Color.WHITE:
		modulate = modulate.lerp(modulate_over_time, modulate_speed * delta)

func _check_effect_completion():
	var sprite_finished = not sprite_active or (sprite and delete_on_sprite_animation_end and _current_frame >= min(max_frames, _total_frames) - 1 and not sprite_loop)
	var particle_finished = not particle_active or (particles and delete_on_particle_end and particle_one_shot and not particles.emitting)
	
	if (sprite_finished and particle_finished) or (delete_after_duration and effect_duration > 0 and _effect_timer >= effect_duration):
		_finish_effect()

func _finish_effect():
	emit_signal("effect_finished")
	queue_free()

# Public API methods for external control
func restart_effect():
	_effect_timer = 0.0
	_current_frame = start_frame
	_frame_timer = 0.0
	if sprite:
		_update_sprite_frame()
	if particles:
		particles.emitting = true
		particles.restart()

func stop_effect():
	sprite_active = false
	particle_active = false
	if particles:
		particles.emitting = false

func set_sprite_frame(frame: int):
	_current_frame = clamp(frame, 0, min(max_frames, _total_frames) - 1)
	_update_sprite_frame()

func set_particle_emitting(emitting: bool):
	particle_active = emitting
	if particles:
		particles.emitting = emitting

# Flip control methods
func set_sprite_flip(horizontal: bool, vertical: bool):
	sprite_flip_h = horizontal
	sprite_flip_v = vertical

func set_particle_flip(horizontal: bool, vertical: bool):
	particle_flip_h = horizontal
	particle_flip_v = vertical

func set_both_flip(horizontal: bool, vertical: bool):
	sprite_flip_h = horizontal
	sprite_flip_v = vertical
	particle_flip_h = horizontal
	particle_flip_v = vertical

# Configuration method for runtime setup
func configure_effect(sprite_texture: Texture2D = null, particle_texture: Texture2D = null, new_properties: Dictionary = {}):
	if sprite_texture and sprite:
		sprite.texture = sprite_texture
		_setup_sprite_animation()
	
	if particle_texture and particles:
		particles.texture = particle_texture
	
	for property in new_properties:
		# Fix: Safer property checking
		if property in self:
			set(property, new_properties[property])
