extends Camera2D

# Camera effects
@export var max_lean_angle = 0.3
@export var lean_sensitivity = 0.002
@export var max_shake = 20.0
@export var shake_decay = 3.0
var trauma = 0.0
var base_rotation = 0.0

func _ready():
	base_rotation = rotation

func _process(delta):
	# Get parent (player) velocity for leaning
	var parent = get_parent()
	if parent and parent is CharacterBody2D:
		# Calculate target rotation based on velocity
		var target_rotation = base_rotation - parent.velocity.x * lean_sensitivity
		
		# Clamp the rotation
		target_rotation = clamp(target_rotation, -max_lean_angle, max_lean_angle)
		
		# Apply rotation with smoothing
		rotation = lerp(rotation, target_rotation, 10 * delta)
	
	# Apply camera shake
	if trauma > 0:
		trauma = max(trauma - shake_decay * delta, 0)
		shake()

func add_trauma(amount):
	if OptionsFetch.fetch_setting("gameplay","screen_shake",true):
		trauma = min(trauma + amount, 1.0)

func shake():
	var amount = trauma
	
	# Simple random shake
	var shake_offset = Vector2(
		randf_range(-max_shake, max_shake) * amount,
		randf_range(-max_shake, max_shake) * amount
	)
	
	offset = shake_offset
