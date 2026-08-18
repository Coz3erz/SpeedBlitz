extends EntityBase  # Changed from CharacterBody2D

# Movement constants
@export var accel = 2800.0 # acceleration 
@export var air_accel = 2800.0 # air acceleration 
@export var jump_velocity = -2800.0 # jump velocity
@export var double_jump_velocity = -2800.0 # double jump veloity
@export var dash_last_time = 0.16 # how long dash lasts for
@export var dash_cooldown_time = 0.25 # dash cooldown
@export var dash_speed_multiplier = 1.2 # dash_length = max(velocity.x * dash_speed_multiplier ,min dash)
@export var min_dash_speed = 2500.0 # minimum value for dash
@export var dash_jump_mult = 1.2 # when performing jump + dash at the same time , velocity.x will be multiplied by this
@export var dash_jump_y_mult = 0.9 # same as above but for velocity.y
@export var dash_jump_buffer_time = 0.1 # after dash finishes , this is the buffer time to register jump input to perform dash + jump tech
@export var wall_jump_horizontal = 2400.0 # wall jump horizontal power
@export var wall_jump_vertical = -2600.0 # wall jump vertical power
@export var wall_jump_cooldown = 0.05 # cooldown time for wall jumping
@export var gravity = 8000.0 # gravity to apply
@export var ground_slam_force = 5000.0 # speed of descent for ground slam
@export var ground_slam_bounce = 0.0 # bounce for ground slam
@export var ground_slam_jump_timer_ = 0.07 # the time after landing from a ground slam where if jump is registered , ground slam rejump activates.
@export var ground_slam_rejump_power_base = 2 # base rejump power
@export var ground_slam_rejump_growth_while_falling = 2 #shows how fast ground slam rejump power grows while falling down 
@export var wall_slide_speed = 500.0 # wall sliding speed
@export var player_collision : CollisionShape2D # collision for world

# Stamina system
@export var max_stamina = 300.0 # max stamina
@export var stamina_regen_base = 60.0 # base stamina regen regardless of speed
@export var stamina_regen_speed_multiplier = 0.1 # same logic with dash , max(regen_mult*velocity.x,regen_base)
@export var dash_cost = 100.0 # dash cost
@export var double_jump_cost = 0.0 # double jump cost
@export var ground_slam_cost = 100.0 # ground slam cost
@export var stamina_bar: ProgressBar # stamina bar node
@export var velocity_multiplier : float = 1.0   # Global speed scale for jumps, dashes, etc.
# Wall detection
@export var wall_detector_offset = 10.0 # offsets for wall detectors for wall sliding
@export var wall_collision_layer = 1 # collision layer for wall sliding detectors
@export var auto_wall_slide_time = 1 # auto wall slide time right after leaving a wall
@export var offset_div = 5000 # line right after move and slide , basically max(velocity.x/5000,base_tile_offset) , this allows for camera to expand as you speed up

# ============================================
# BATTLE SYSTEM VARIABLES (SIMPLIFIED)
# ============================================
@export var attack_speed: float = 5000.0  # Constant attack dash speed
@export var attack_range: float = 2500.0  # Maximum attack distance
@export var attack_cooldown_time: float = 0.3  # Time between attacks
@export var attack_damage_multiplier: float = 1.0  # Damage multiplier
@export var attack_effect_scene: PackedScene  # Optional particle effect
@export var health_bar: ProgressBar  # Health bar reference
@export var respawn_delay: float = 1.5  # Delay before respawn
@export var respawn_position: Vector2 = Vector2.ZERO  # Respawn point

# Attack state
var is_attacking: bool = false
var attack_direction: Vector2 = Vector2.ZERO
var attack_distance_remaining: float = 0.0  # How far left to travel
var attack_hitbox: Area2D
var has_hit_during_attack: bool = false

# ============================================
# BULLET / SHOOTING VARIABLES
# ============================================
@export var bullet_texture: Texture2D                     # Texture for the bullet sprite
@export var bullet_hframes: int = 1                       # Horizontal frames in texture
@export var bullet_vframes: int = 1                       # Vertical frames in texture
@export var bullet_speed: float = 1200.0                  # Speed of the bullet
@export var bullet_damage: float = 25.0                   # Damage per bullet
@export var bullet_knockback: float = 400.0               # Knockback force
@export var bullet_size: Vector2 = Vector2(20, 10)        # Size of the bullet collision rectangle
@export var bullet_lifetime: float = 1.5                  # Time before bullet auto-deletes
@export var bullet_cooldown: float = 0.2                  # Minimum time between bullets
var bullets: Array = []                                   # Active bullets
var bullet_timer: float = 0.0                             # Internal timer
var prev_bullet_timer: float = 0.0                        # Used to detect cooldown completion for flash

# ============================================
# GROUND SLAM DAMAGE EXPORTS
# ============================================
@export var groundslam_damage: float = 50.0               # Damage dealt by ground slam impact
@export var groundslam_knockback: float = 1000.0          # Knockback force of ground slam

# ============================================
# AIM INDICATOR SYSTEM
# ============================================
@export var aim_dot_texture: Texture2D                    # The texture for the aim dot (a small circle)
@export var aim_indicator_distance: float = 100.0         # Distance from player centre
var aim_direction: Vector2 = Vector2.RIGHT                # Current RAW aim direction (normalised)
var is_using_gamepad_aim: bool = false                    # True when right stick is active
var aim_indicator: Sprite2D                               # The visual dot node

# ============================================
# AFTERIMAGE OPTION
# ============================================
@export var create_afterimages: bool = false              # If true, afterimages while moving
var flash_tween: Tween = null
var flash_overlay: Sprite2D = null
var flash_overlay_active: bool = false

# ============================================
# DASH COOLDOWN CLOCK SYSTEM
# ============================================
@export var dash_cooldown_clock_texture: Texture2D        # Clock spritesheet (16 frames horizontally)
@export var dash_cooldown_clock_hframes: int = 16         # Horizontal frames
@export var dash_cooldown_clock_vframes: int = 1          # Vertical frames
@export var dash_clock_position: Vector2 = Vector2(960, 50)  # Top‑right position (adjust for your viewport)
@export var dash_clock_scale: Vector2 = Vector2(1, 1)     # Scale of the clock sprite
@export var dash_clock_appear_start: int = 1              # First appear frame (1‑based)
@export var dash_clock_appear_end: int = 4                # Last appear frame
@export var dash_clock_cooldown_start: int = 5            # First cooldown frame
@export var dash_clock_cooldown_end: int = 13             # Last cooldown frame
@export var dash_clock_disappear_start: int = 14          # First disappear frame
@export var dash_clock_disappear_end: int = 16            # Last disappear frame
@export var dash_clock_appear_speed: float = 0.05         # Seconds per frame for appear/disappear

var clock_sprite: Sprite2D = null
var clock_timer: float = 0.0
var clock_state: int = 0   # 0 = idle, 1 = appear, 2 = cooldown, 3 = disappear
var clock_frame: int = 0

var stamina = 300.0 # stamina internal variable
@onready var cam_const = $cam.offset_view_tiles # cam constant from cam node
@onready var sfx_player = $sound_effects
var sound_streams = {}
var playback: AudioStreamPlaybackPolyphonic

# Movement state
var is_on_slope = false # boolean 
var jump_mult = 1 # jump multiplier applied everytime you jump
var current_state = "IDLE" # current player state
var facing_direction = 1 # facing direction of player
var can_dash = true # can dash boolean
var has_double_jump = true # allows double jump
var is_wall_sliding = false # boolean
var wall_side = 0 # shows which side the wall is on
var coyote_time = 0.0 # coyote time internal
var jump_buffer_time = 0.0 # jump buffer time internal
var last_wall_jump_time = 0.0 # internal
var is_ground_slamming = false # is ground slamming boolean
var auto_wall_slide_timer = 0.0 # internal
var is_dashing = false # is dashing boolean
var dash_jump_applicable = false # allows if dash + jump is applicable in scenarios
var override_slope_rotation = false # allows to override slopes rotation
var node_array = [] # node array which stores all current nodes created by the player (cycled through to delete null nodes)
var ground_slam_effect_temp # variable to store the ground slam effect temporarily 
var ground_slam_rejump_internal = ground_slam_rejump_power_base # it grows in magnitude as you fall , so if you fall from great heights and perform ground slam rejump , you get greater power.

# Slope handling - ADDED BUFFER
var slope_timer = 0.0 # slope timer
var slope_debounce = 0.1 # debounce
var slope_buffer_timer = 0.0  # NEW: Buffer to keep slope state true for a few frames

# ROBUST FLOOR DETECTION
var ground_ray: RayCast2D # ground ray for raycasting
var was_on_floor = false # boolean
var floor_collision_override = false # floor collision override boolean
var is_upside_down = false # Is upside down boolean , shows if gravity is flipped.
var upside_down_mult = 1 # multiplier for gravity , jump , ground slam etc when upside down
var exit_when_jump = false # boolean while upside down , if true , exit upside down immediately upon jump
var should_snap = true # should snap to floors via raycast boolean
var keep_y_at_zero_ = false # if active , velocity.y = 0 constant , can be activated via keep_y_at_zero(time) function

# Timers
var coyote_timer: Timer # timer internal variable
var jump_buffer_timer: Timer # timer internal variable
var dash_timer: Timer # timer internal variable
var dash_cooldown_timer: Timer # timer internal variable
var ground_slam_jump_timer : Timer # timer internal variable
var dash_jump_speed_timer : Timer # timer internal variable

# Camera reference
@export var camera_node: NodePath # camera node internal
@onready var sprite_node = $sprite # optimized sprite node call
@onready var effect_spawn = $effect_spawn_location # optimized effect spawn call
@onready var animation_player = $sprite/animation # AnimationPlayer instead of entity_sprite_handler
@export var slope_threshold = 5 # some slope threshold , keep it at 5 I suppose.
@export var walk_threshold = 100.0 # threshold for walk/run animation

var camera
# preloaded scenes
var dash_effect_scene = preload("res://scenes/effects/dash_effect_r.tscn")
var ground_slam_fall_effect = preload("res://scenes/effects/ground_slam_effect_r.tscn")
var ground_slam_check_fall_effect = "ground_slam_effect_r"
var ground_slam_cloud_effect = preload("res://scenes/effects/ground_slam_cloud_effect_r.tscn")

#sound effects
var groundslam_sfx = "res://sounds/sound effects/player/groundslam.sfxr"
var dash_sfx = "res://sounds/sound effects/player/dash.sfxr"
var jump_sfx = "res://sounds/sound effects/player/jump.sfxr"

# Wall detection
var left_detector: Area2D # internal
var right_detector: Area2D # internal

var nodes_to_add_position_of_player = [] # if any node is inside this array , their position will snap to exactly the players position.
var current_areas_inside = [] # shows which area2ds are within our area2d
var current_areas_inside_names = [] # shows which area2ds are within with their names

# Animation tracking
var current_animation = ""
var jump_start_played = false

# Afterimage effect
var afterimage_enabled = true
var afterimage_timer = 0.0
var afterimage_interval = 0.1
var afterimage_timer_2 = 0.0   # Timer for create_afterimages toggle

func _ready():
	# Ensure attack action exists (shoot is manual)
	_ensure_attack_action_exists()
	
	add_to_group("can_interact_with_water")
	add_to_group("player")  # Add player to player group for battle system
	add_to_group("attacker")  # Add to attacker group
	
	sfx_player.stream = AudioStreamPolyphonic.new()
	sfx_player.play()  # Required to initialize playback
	playback = sfx_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	sfx_player.bus = "SFX"
	safe_margin = 0.12
	stamina = max_stamina
	
	# Create timers
	coyote_timer = Timer.new()
	coyote_timer.one_shot = true 
	add_child(coyote_timer)
	
	jump_buffer_timer = Timer.new()
	jump_buffer_timer.one_shot = true
	add_child(jump_buffer_timer)
	
	dash_timer = Timer.new()
	dash_timer.one_shot = true
	add_child(dash_timer)

	dash_cooldown_timer = Timer.new()
	dash_cooldown_timer.one_shot = true
	add_child(dash_cooldown_timer)
	
	ground_slam_jump_timer = Timer.new()
	ground_slam_jump_timer.one_shot = true
	add_child(ground_slam_jump_timer)
	
	dash_jump_speed_timer = Timer.new()
	dash_jump_speed_timer.one_shot = true
	add_child(dash_jump_speed_timer)
	
	dash_timer.timeout.connect(_on_dash_timer_timeout)
	
	ground_slam_jump_timer.timeout.connect(groundslam_timer_func)
	
	dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timer_timeout)
	
	dash_jump_speed_timer.timeout.connect(dash_jump_timer_func)
	
	# ROBUST: Create ground detection raycast
	create_ground_detection()
	
	# Get camera reference
	if camera_node:
		camera = get_node(camera_node)
	else:
		camera = $Camera2D
	
	# Create wall detection areas
	create_wall_detectors()
	
	# ============================================
	# BATTLE SYSTEM SETUP
	# ============================================
	_setup_battle_system()
	
	# ============================================
	# AIM INDICATOR SETUP
	# ============================================
	aim_indicator = Sprite2D.new()
	aim_indicator.name = "AimIndicator"
	if aim_dot_texture:
		aim_indicator.texture = aim_dot_texture
	aim_indicator.z_index = 10  # Render above most things
	add_child(aim_indicator)

func _ensure_attack_action_exists():
	"""Ensure the attack action exists in the Input Map (shoot is NOT created here)"""
	if not InputMap.has_action("attack"):
		print("WARNING: 'attack' action not found! Creating it...")
		InputMap.add_action("attack")
		var mouse_event = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", mouse_event)
		print("Created 'attack' action with Left Mouse Button")
	else:
		var events = InputMap.action_get_events("attack")
		if events.size() == 0:
			print("WARNING: 'attack' action has no bindings! Adding Left Mouse Button...")
			var mouse_event = InputEventMouseButton.new()
			mouse_event.button_index = MOUSE_BUTTON_LEFT
			InputMap.action_add_event("attack", mouse_event)
		else:
			print("'attack' action ready with ", events.size(), " binding(s)")

# ROBUST: Create ground detection system
func create_ground_detection():
	ground_ray = RayCast2D.new()
	ground_ray.name = "GroundRay"
	ground_ray.enabled = true
	ground_ray.collision_mask = collision_mask
	ground_ray.target_position = Vector2(0, 1000)  # Very long ray
	ground_ray.collide_with_areas = false
	ground_ray.collide_with_bodies = true
	ground_ray.enabled = false
	add_child(ground_ray)

func create_wall_detectors():
	# Remove any existing detectors
	for child in get_children():
		if child.name.begins_with("WallDetector"):
			child.queue_free()
	
	# Get player collision shape to match size
	
	if not player_collision:
		push_error("Player has no CollisionShape2D for wall detection!")
		return
	
	var player_shape = player_collision.shape
	var shape_size = Vector2(10, 10)  # Default size
	
	# Try to get the actual size from common shape types
	if player_shape is RectangleShape2D:
		shape_size = Vector2(player_shape.size.x,(player_shape.size.y-1)/2.3)
	elif player_shape is CapsuleShape2D:
		shape_size = Vector2(player_shape.radius * 2, (player_shape.height-1)/2.3)
	elif player_shape is CircleShape2D:
		shape_size = Vector2(player_shape.radius * 2, ((player_shape.radius * 2)-1)/2.3)
	
	# Left wall detector
	left_detector = Area2D.new()
	left_detector.name = "WallDetectorLeft"
	var left_collision = CollisionShape2D.new()
	var left_shape = RectangleShape2D.new()
	left_shape.size = shape_size
	left_collision.shape = left_shape
	left_collision.position = Vector2(-wall_detector_offset, 0)
	left_detector.add_child(left_collision)
	
	# Set collision mask to only detect walls (not the player)
	left_detector.collision_mask = wall_collision_layer
	left_detector.collision_layer = 0
	
	add_child(left_detector)
	
	# Right wall detector
	right_detector = Area2D.new()
	right_detector.name = "WallDetectorRight"
	var right_collision = CollisionShape2D.new()
	var right_shape = RectangleShape2D.new()
	right_shape.size = shape_size
	right_collision.shape = right_shape
	right_collision.position = Vector2(wall_detector_offset, 0)
	right_detector.add_child(right_collision)
	
	# Set collision mask to only detect walls (not the player)
	right_detector.collision_mask = wall_collision_layer
	right_detector.collision_layer = 0
	
	add_child(right_detector)

# ============================================
# BATTLE SYSTEM INITIALIZATION
# ============================================
func _setup_battle_system():
	# Initialize health from entity base
	health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	
	# Connect death and damage signals from entity base
	entity_died.connect(_on_player_died)
	entity_damaged.connect(_on_player_damaged)
	
	# Setup explosion values for death (customize these paths)
	explosion_spritesheet = "res://sprites/explosion.png"  # SET YOUR EXPLOSION SPRITESHEET PATH HERE
	explosion_hframes = 8  # Number of columns in spritesheet
	explosion_vframes = 1  # Number of rows in spritesheet
	explosion_fps = 12.0
	explosion_duration = 0.8
	explosion_scale = Vector2(3, 3)

func _physics_process(delta):
	facing_direction = sign(facing_direction)
	# Afterimage timer (original: dash & ground slam, now also attack)
	afterimage_timer += delta
	if afterimage_enabled and (current_state == "DASHING" or current_state == "GROUND_SLAMMING" or current_state == "ATTACKING"):
		if afterimage_timer >= afterimage_interval:
			create_afterimage()
			afterimage_timer = 0.0
	
	# Afterimages if create_afterimages toggle is on and moving
	if create_afterimages and velocity.length() > 10.0:
		afterimage_timer_2 += delta
		if afterimage_timer_2 >= 0.2:
			create_afterimage()
			afterimage_timer_2 = 0.0
	else:
		afterimage_timer_2 = 0.0
	
	# Sprite flipping - FIXED for upside down
	if is_upside_down:
		sprite_node.flip_h = (facing_direction == 1)  # Inverted when upside down
	else:
		sprite_node.flip_h = (facing_direction == -1)
	
	# Update slope timers
	slope_timer += delta
	slope_buffer_timer = max(0.0, slope_buffer_timer - delta)  # NEW: Update buffer timer
	
	# ROBUST: Store previous floor state
	was_on_floor = is_on_floor()
	
	# ROBUST: Update ground detection BEFORE any movement
	update_ground_detection()
	
	# ============================================
	# UPDATE AIM DIRECTION (RAW, NO FLOOR CORRECTION)
	# ============================================
	update_aim_direction()
	update_aim_indicator()
	
	# ============================================
	# BATTLE SYSTEM PROCESSING
	# ============================================
	_process_battle(delta)
	
	# ============================================
	# SHOOTING SYSTEM
	# ============================================
	handle_shooting(delta)
	
	# ============================================
	# UPDATE DASH COOLDOWN CLOCK
	# ============================================
	_update_cooldown_clock(delta)
	
	# Skip movement processing if dead
	if is_dead:
		return
	
	handle_stamina(delta)
	handle_input()
	apply_gravity(delta)
	handle_movement(delta)
	handle_dash()
	handle_ground_slam()
	
	# Double jump check - only if not wall sliding and not already used
	if (not is_on_floor() and 
		has_double_jump and 
		Input.is_action_just_pressed("jump") and 
		stamina >= double_jump_cost and 
		not is_wall_sliding and
		current_state != "WALL_SLIDING" and current_state != "GROUND_SLAMMING" and
		current_state != "ATTACKING") and !is_upside_down:
		play_sfx(jump_sfx)
		velocity.y = double_jump_velocity*jump_mult*upside_down_mult
		if jump_mult>1:
			velocity.x *= jump_mult/(jump_mult-0.3)
		has_double_jump = false
		stamina -= double_jump_cost
		current_state = "JUMPING"
		jump_start_played = false  # Reset for jump animation
	
	# Regular jump handling (coyote time and jump buffer)
	handle_jump()
	
	# NEW APPROACH: Simple slope handling
	handle_slopes()
	
	# Handle wall slide
	handle_wall_slide()
	
	update_state()
	
	last_wall_jump_time += delta
	
	# Update auto wall slide timer
	if auto_wall_slide_timer > 0:
		auto_wall_slide_timer -= delta

	# ROBUST: Apply movement with aggressive snap
	apply_movement_with_guaranteed_snap(delta)
	$cam.offset_view_tiles = clamp(max((velocity.x/offset_div),cam_const),cam_const,7)
	update_visuals()
	if keep_y_at_zero_:
		velocity.y = 0
	velocity *= velocity_multiplier
	move_and_slide()
	# Restore original velocity after move_and_slide
	velocity /= velocity_multiplier
	# Reset jump animation when landing
	if is_on_floor() and (current_state == "IDLE" or current_state == "WALKING"):
		jump_start_played = false
	
	for y in range(node_array.size() - 1, -1, -1):
		if node_array[y] == null:
			node_array.remove_at(y)
		else:
			if ground_slam_check_fall_effect in node_array[y].name and current_state != "GROUND_SLAMMING":
				node_array.remove_at(y)
	
	# FIXED: Safe array cleanup for nodes_to_add_position_of_player
	for i in range(nodes_to_add_position_of_player.size() - 1, -1, -1):
		var node = nodes_to_add_position_of_player[i]
		if node != null and is_instance_valid(node):
			node.global_position = global_position
		else:
			nodes_to_add_position_of_player.remove_at(i)
	if current_state == "GROUND_SLAMMING":
		ground_slam_rejump_internal += 1 * delta
	#effect_r means to rotate along with the sprite
	if sprite_node.rotation != 0:
		for i in range(len(node_array)):
			if node_array[i] != null:
				if "effect_r" in node_array[i].name:
					node_array[i].rotation = sprite_node.rotation
		# Keep the flash overlay synced to the player’s current frame/animation
	if flash_overlay_active and flash_overlay and is_instance_valid(flash_overlay):
		flash_overlay.texture = sprite_node.texture
		flash_overlay.frame = sprite_node.frame
		flash_overlay.flip_h = sprite_node.flip_h
		flash_overlay.flip_v = sprite_node.flip_v
		flash_overlay.rotation = sprite_node.rotation
		# scale stays Vector2.ONE (parent already provides scaling)
		flash_overlay.region_rect = sprite_node.region_rect
		flash_overlay.region_enabled = sprite_node.region_enabled
# ============================================
# AIM DIRECTION COMPUTATION (RAW – NO FLOOR CORRECTION)
# ============================================
func update_aim_direction():
	var joypads = Input.get_connected_joypads()
	if joypads.size() > 0:
		# Controller stick (right stick, or left if option is set)
		var use_left = OptionsFetch.fetch_setting("gameplay", "use_left_joystick_aim", false)
		var axis_x = JOY_AXIS_LEFT_X if use_left else JOY_AXIS_RIGHT_X
		var axis_y = JOY_AXIS_LEFT_Y if use_left else JOY_AXIS_RIGHT_Y

		var stick_x = Input.get_joy_axis(0, axis_x)
		var stick_y = Input.get_joy_axis(0, axis_y)

		if abs(stick_x) > 0.15 or abs(stick_y) > 0.15:
			# Stick is being used – aim exactly where you push
			aim_direction = Vector2(stick_x, stick_y).normalized()
			is_using_gamepad_aim = true
			return
		else:
			aim_direction = Vector2.RIGHT*facing_direction
			return
	else:
		# Stick idle – fall through to mouse/touch
		is_using_gamepad_aim = false
		var mouse_pos = get_global_mouse_position()
		var dir = (mouse_pos - global_position).normalized()
		aim_direction = dir
func update_aim_indicator():
	if not aim_indicator:
		return
	aim_indicator.position = aim_direction * aim_indicator_distance
	aim_indicator.rotation = aim_direction.angle()
# ============================================
# BATTLE SYSTEM PROCESSING
# ============================================
func _process_battle(delta):
	if is_dead:
		return
	
	# Handle attack input (left mouse button)
	if Input.is_action_just_pressed("attack") and can_attack and not is_stunned:
		if current_state != "GROUND_SLAMMING" and current_state != "DASHING":
			start_attack()
	
	# Update attack state
	if is_attacking:
		# Move at constant speed
		velocity = attack_direction * attack_speed
		# Decrease remaining distance
		attack_distance_remaining -= attack_speed * delta
		
		# Check for wall/ground/ceiling collision
		if is_on_wall() or is_on_floor() or is_on_ceiling():
			end_attack()
			return
		
		# End attack when distance traveled
		if attack_distance_remaining <= 0:
			end_attack()

func start_attack():
	if is_attacking or not can_attack or is_dead:
		return
	
	# Use raw aim direction, but correct for floor if needed
	var attack_dir = aim_direction
	
	# If on ground and aiming downward, force the attack horizontal (Y = 0)
	if is_on_floor() and attack_dir.y > 0:
		attack_dir.y = 0
		attack_dir = attack_dir.normalized()
	
	attack_direction = attack_dir
	attack_distance_remaining = attack_range
	
	# Update facing direction based on horizontal component
	if abs(attack_direction.x) > 0.1:
		facing_direction = sign(attack_direction.x)
	
	# Stop wall sliding immediately
	is_wall_sliding = false
	
	# Start attack
	is_attacking = true
	can_attack = false
	has_hit_during_attack = false
	current_state = "ATTACKING"
	
	# Apply initial velocity
	velocity = attack_direction * attack_speed
	
	# Create attack hitbox
	create_player_attack_hitbox()
	
	# ALWAYS play roll animation during attack
	if animation_player and animation_player.has_animation("roll"):
		animation_player.play("roll")
		current_animation = "roll"
	
	# Spawn attack effect if available
	if attack_effect_scene:
		var effect = instantiate_scene(attack_effect_scene, get_parent(), global_position)
		if effect:
			effect.rotation = attack_direction.angle()
			node_array.append(effect)

func end_attack():
	if not is_attacking:
		return
	
	is_attacking = false
	
	# Keep a small remnant of momentum, then let gravity take over
	velocity = attack_direction * (attack_speed * 0.1)
	
	# Reset state
	if current_state == "ATTACKING":
		if is_on_floor():
			current_state = "IDLE"
		elif is_on_wall():
			# If we ended on a wall, go to wall sliding
			current_state = "WALL_SLIDING"
		else:
			current_state = "FALLING"
	
	# Remove attack hitbox
	if attack_hitbox and is_instance_valid(attack_hitbox):
		attack_hitbox.queue_free()
		attack_hitbox = null
	
	# Start cooldown clock animation
	_start_cooldown_clock()
	
	# Start cooldown
	await get_tree().create_timer(attack_cooldown_time).timeout
	can_attack = true

func create_player_attack_hitbox():
	# Remove old hitbox if exists
	if attack_hitbox and is_instance_valid(attack_hitbox):
		attack_hitbox.queue_free()
	
	attack_hitbox = Area2D.new()
	attack_hitbox.name = "AttackHitbox"
	attack_hitbox.collision_layer = 0  # Don't collide with world
	attack_hitbox.collision_mask = 0  # We'll detect manually
	
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(80, 100)  # Fixed size hitbox
	collision_shape.shape = shape
	collision_shape.rotation = attack_direction.angle()
	
	attack_hitbox.add_child(collision_shape)
	attack_hitbox.global_position = global_position + attack_direction * 50  # Offset in front
	
	# Set attack metadata for damage calculation
	attack_hitbox.set_meta("damage", base_damage * attack_damage_multiplier)
	attack_hitbox.set_meta("knockback_force", 800.0)
	attack_hitbox.set_meta("attacker", self)
	attack_hitbox.set_meta("attack_direction", attack_direction)
	
	# Connect signals for hit detection
	attack_hitbox.body_entered.connect(_on_attack_hitbox_entered)
	attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)
	
	get_parent().add_child(attack_hitbox)
	
	# Auto-remove hitbox after a reasonable time
	get_tree().create_timer(1.0).timeout.connect(func():
		if attack_hitbox and is_instance_valid(attack_hitbox):
			attack_hitbox.queue_free()
	)

func _on_attack_hitbox_entered(body):
	# Don't hit ourselves
	if body == self:
		return
	
	# Prevent multiple hits from same attack
	if has_hit_during_attack:
		return
	
	# Check if body can take damage
	if body.has_method("take_damage") and body.is_in_group("damageable"):
		_apply_attack_damage(body)
		return
	
	# Check if the body has an entity_hitbox child
	if body.has_node("entity_hitbox") or body.has_node("EntityHitbox"):
		_apply_attack_damage(body)
		return

func _on_attack_hitbox_area_entered(area):
	# Check if area is an entity_hitbox
	if "entity_hitbox" in area.name.to_lower() or "hitbox" in area.name.to_lower():
		var parent = area.get_parent()
		if parent and parent != self and parent.has_method("take_damage"):
			if not has_hit_during_attack:
				_apply_attack_damage(parent)
				return

func _apply_attack_damage(target):
	if has_hit_during_attack:
		return
	
	var damage = attack_hitbox.get_meta("damage")
	var knockback_force = attack_hitbox.get_meta("knockback_force")
	var attack_dir = attack_hitbox.get_meta("attack_direction")
	
	target.take_damage(damage, self, attack_dir, knockback_force)
	
	has_hit_during_attack = true
	
	# Add camera shake on successful hit
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.4)
	
	# Hit stop effect for game feel
	hit_stop_effect()

# ============================================
# BULLET SYSTEM (with cooldown & hold-to-shoot)
# ============================================
func handle_shooting(delta):
	if is_dead:
		return
	
	# Store previous bullet timer for flash detection
	prev_bullet_timer = bullet_timer
	
	# Bullet cooldown timer
	if bullet_timer > 0:
		bullet_timer -= delta
	
	# Fire when action held and cooldown ready
	if Input.is_action_pressed("shoot") and bullet_timer <= 0:
		spawn_bullet()
		bullet_timer = bullet_cooldown
	
	# Flash white when bullet cooldown just finished
	if prev_bullet_timer > 0 and bullet_timer <= 0:
		flash_white()
	
	# Update existing bullets
	for i in range(bullets.size() - 1, -1, -1):
		var bullet = bullets[i]
		if not is_instance_valid(bullet):
			bullets.remove_at(i)
			continue
		
		# Move bullet
		var direction = bullet.get_meta("direction")
		bullet.global_position += direction * bullet_speed * delta
		
		# Animate bullet if spritesheet used
		if bullet_hframes > 1 or bullet_vframes > 1:
			var sprite = bullet.get_node_or_null("Sprite")
			if sprite:
				var elapsed = Time.get_ticks_msec() / 1000.0 - bullet.get_meta("birth_time")
				var total_frames = bullet_hframes * bullet_vframes
				var frame = int(elapsed * 10.0) % total_frames
				sprite.frame = frame
		
		# Lifetime
		if Time.get_ticks_msec() / 1000.0 - bullet.get_meta("birth_time") > bullet_lifetime:
			bullet.queue_free()
			bullets.remove_at(i)

func spawn_bullet():
	var dir = aim_direction   # Shoot uses the RAW aim direction
	
	# Create bullet Area2D
	var bullet = Area2D.new()
	bullet.name = "Bullet"
	bullet.collision_layer = 0
	bullet.collision_mask = 1
	
	var col_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = bullet_size
	col_shape.shape = rect
	bullet.add_child(col_shape)
	
	# Sprite
	var sprite = Sprite2D.new()
	sprite.texture = bullet_texture
	sprite.hframes = bullet_hframes
	sprite.vframes = bullet_vframes
	sprite.frame = 0
	if bullet_hframes > 1 or bullet_vframes > 1:
		sprite.region_enabled = true
	
	# --- Scale sprite to match bullet_size ---
	if bullet_texture:
		var tex_size = bullet_texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			sprite.scale = Vector2(bullet_size.x / tex_size.x, bullet_size.y / tex_size.y)
	
	# --- Rotate sprite to face flight direction ---
	sprite.rotation = dir.angle()
	
	bullet.add_child(sprite)
	
	bullet.global_position = global_position
	bullet.set_meta("direction", dir)
	bullet.set_meta("birth_time", Time.get_ticks_msec() / 1000.0)
	bullet.set_meta("damage", bullet_damage)
	bullet.set_meta("knockback", bullet_knockback)
	bullet.set_meta("attacker", self)
	
	bullet.body_entered.connect(_on_bullet_body_entered.bind(bullet))
	bullet.area_entered.connect(_on_bullet_area_entered.bind(bullet))
	
	get_parent().add_child(bullet)
	bullets.append(bullet)


func flash_white():
	if not sprite_node or not is_instance_valid(sprite_node):
		return

	# Reuse an existing overlay if it's still alive
	if flash_overlay and is_instance_valid(flash_overlay):
		var old_tween = flash_overlay.get_meta("tween", null)
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	else:
		flash_overlay = Sprite2D.new()
		flash_overlay.z_index = sprite_node.z_index + 1
		sprite_node.add_child(flash_overlay)

	# Copy the current player appearance (scale = 1,1 because parent already scales)
	flash_overlay.texture = sprite_node.texture
	flash_overlay.hframes = sprite_node.hframes
	flash_overlay.vframes = sprite_node.vframes
	flash_overlay.frame = sprite_node.frame
	flash_overlay.flip_h = sprite_node.flip_h
	flash_overlay.flip_v = sprite_node.flip_v
	flash_overlay.rotation = sprite_node.rotation
	flash_overlay.scale = Vector2.ONE                       # CORRECT: no double scaling
	flash_overlay.region_rect = sprite_node.region_rect
	flash_overlay.region_enabled = sprite_node.region_enabled
	flash_overlay.position = Vector2.ZERO
	flash_overlay.offset = sprite_node.offset

	# Set bright white
	flash_overlay.modulate = Color(256,256,256,1)
	flash_overlay.self_modulate = Color(256,256,256,1)

	# Mark overlay as active – it will be synced every frame
	flash_overlay_active = true

	# Fade out and clean up
	var tween = create_tween()
	flash_overlay.set_meta("tween", tween)
	tween.tween_property(flash_overlay, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		if flash_overlay and is_instance_valid(flash_overlay):
			flash_overlay.queue_free()
			flash_overlay = null
		flash_overlay_active = false
	)
func _on_bullet_body_entered(body, bullet):
	if body == self:
		return
	_bullet_hit(bullet, body)

func _on_bullet_area_entered(area, bullet):
	var parent = area.get_parent()
	if parent == self:
		return
	_bullet_hit(bullet, parent if parent else area)

func _bullet_hit(bullet, target):
	if not is_instance_valid(bullet):
		return
	if target.has_method("take_damage") and target.is_in_group("damageable"):
		var dmg = bullet.get_meta("damage")
		var kb = bullet.get_meta("knockback")
		var dir = bullet.get_meta("direction")
		target.take_damage(dmg, self, dir, kb)
	
	bullets.erase(bullet)
	bullet.queue_free()

# ============================================
# GROUND SLAM DAMAGE
# ============================================
func spawn_groundslam_damage_hitbox():
	# Get player collision dimensions
	var player_width = 20.0
	var player_height = 40.0
	if player_collision and player_collision.shape:
		var shape = player_collision.shape
		if shape is RectangleShape2D:
			player_width = shape.size.x
			player_height = shape.size.y
		elif shape is CapsuleShape2D:
			player_width = shape.radius * 2
			player_height = shape.height
		elif shape is CircleShape2D:
			player_width = shape.radius * 2
			player_height = shape.radius * 2
	
	var hitbox_width = player_width * 3
	var hitbox_height = player_height / 2
	
	var damage_area = Area2D.new()
	damage_area.name = "GroundSlamDamage"
	damage_area.collision_layer = 0
	damage_area.collision_mask = 1
	
	var col_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(hitbox_width, hitbox_height)
	col_shape.shape = rect
	# Position at feet: offset downward by half player height
	col_shape.position = Vector2(0, player_height / 2)
	damage_area.add_child(col_shape)
	
	damage_area.global_position = global_position
	
	damage_area.set_meta("damage", groundslam_damage)
	damage_area.set_meta("knockback", groundslam_knockback)
	damage_area.set_meta("attacker", self)
	
	damage_area.body_entered.connect(_on_groundslam_damage_body_entered.bind(damage_area))
	damage_area.area_entered.connect(_on_groundslam_damage_area_entered.bind(damage_area))
	
	get_parent().add_child(damage_area)
	
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_instance_valid(damage_area):
			damage_area.queue_free()
	)

func _on_groundslam_damage_body_entered(body, damage_area):
	if body == self:
		return
	if body.has_method("take_damage") and body.is_in_group("damageable"):
		var dmg = damage_area.get_meta("damage")
		var kb = damage_area.get_meta("knockback")
		var dir = Vector2.UP  # knock up
		body.take_damage(dmg, self, dir, kb)

func _on_groundslam_damage_area_entered(area, damage_area):
	var parent = area.get_parent()
	if parent == self:
		return
	if parent and parent.has_method("take_damage") and parent.is_in_group("damageable"):
		var dmg = damage_area.get_meta("damage")
		var kb = damage_area.get_meta("knockback")
		var dir = Vector2.UP
		parent.take_damage(dmg, self, dir, kb)

# Modify stop_ground_slam to spawn damage hitbox
func stop_ground_slam():
	if is_upside_down:
		var eff = instantiate_scene(ground_slam_cloud_effect,self,global_position)
		eff.set_particle_flip(false,true)
	else:
		instantiate_scene(ground_slam_cloud_effect,self,global_position)
	if ground_slam_effect_temp != null:
		ground_slam_effect_temp.set_particle_emitting(false)
	
	# Spawn ground slam damage
	spawn_groundslam_damage_hitbox()
	
	# If we hit a slope, adjust bounce direction
	should_snap = true
	var floor_angle = rad_to_deg(get_floor_angle())
	if abs(floor_angle) > slope_threshold and abs(floor_angle) != 90.0:
		# We hit a slope - bounce in a more controlled way
		velocity.y = -ground_slam_bounce * 0.7  # Reduced bounce on slopes
		var slope_direction = sign(get_floor_normal().x)
		velocity.x += slope_direction * ground_slam_bounce * 0.5
	else:
		# Regular flat ground bounce
		velocity.y = -ground_slam_bounce * upside_down_mult
	
	current_state = "JUMPING"
	is_ground_slamming = false
	jump_mult = ground_slam_rejump_internal
	ground_slam_rejump_internal = ground_slam_rejump_power_base
	ground_slam_jump_timer.start(ground_slam_jump_timer_)

func hit_stop_effect():
	var original_scale = Engine.time_scale
	Engine.time_scale = 0.2
	await get_tree().create_timer(0.04).timeout
	Engine.time_scale = original_scale

# Override take_damage from EntityBase
func take_damage(damage: float, attacker: Node = null, knockback_direction: Vector2 = Vector2.ZERO, knockback_force: float = 500.0) -> void:
	super.take_damage(damage, attacker, knockback_direction, knockback_force)
	
	# Update health bar UI
	if health_bar:
		health_bar.value = health
	
	# Add camera shake on damage taken
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.5)
	
	# Interrupt current actions
	if is_ground_slamming:
		stop_ground_slam()
	if is_attacking:
		end_attack()

# Override heal from EntityBase
func heal(amount: float) -> void:
	super.heal(amount)
	if health_bar:
		health_bar.value = health

# Player death handler
func _on_player_died(killer: Node):
	print("Player died! Killer: ", killer.name if killer else "Unknown")
	
	# Stop all actions
	is_attacking = false
	is_dashing = false
	is_ground_slamming = false
	is_wall_sliding = false
	
	# Disable collisions temporarily
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	# Respawn after delay
	await get_tree().create_timer(respawn_delay).timeout
	respawn_player()

# Player respawn function
func respawn_player():
	# Use entity base respawn
	respawn(respawn_position)
	
	# Reset all abilities
	stamina = max_stamina
	can_dash = true
	has_double_jump = true
	is_wall_sliding = false
	is_ground_slamming = false
	is_attacking = false
	current_state = "IDLE"
	
	# Reset velocity
	velocity = Vector2.ZERO
	
	# Re-enable collisions
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	
	# Update UI
	if health_bar:
		health_bar.value = health
	if stamina_bar:
		stamina_bar.value = stamina
	
	# Show sprite
	if sprite_node:
		sprite_node.visible = true

# Player damage visual feedback
func _on_player_damaged(damage: float, attacker: Node, knockback_direction: Vector2, knockback_force: float):
	# Flash player sprite red
	if sprite_node:
		var tween = create_tween()
		tween.tween_property(sprite_node, "modulate", Color.RED, 0.05)
		tween.tween_property(sprite_node, "modulate", Color.WHITE, 0.15)

# ============================================
# REST OF MOVEMENT / PHYSICS (UNCHANGED)
# ============================================

# ROBUST: Multi-layered ground detection
func update_ground_detection():
	if is_upside_down:
		return
	# Update raycast position and check
	ground_ray.force_raycast_update()
	
	# If ray detects ground and we're falling, force floor state
	if ground_ray.is_colliding() and velocity.y > 0:
		var collision_point = ground_ray.get_collision_point()
		var distance_to_floor = collision_point.y - global_position.y
		
		# If we're very close to ground, prepare to snap
		if distance_to_floor <= 150:  # Increased detection range
			floor_collision_override = true
		else:
			floor_collision_override = false
	else:
		floor_collision_override = false

# ROBUST: Guaranteed floor snapping
func apply_movement_with_guaranteed_snap(delta):
	# FIXED: More reasonable snap lengths
	if not is_on_slope and not is_on_floor():
		# Small snap when in air
		floor_snap_length = 64
	elif not is_on_slope:
		# Normal ground snap
		floor_snap_length = 128
	else:
		# Moderate slope snap (reduced from 2500)
		var required_snap = abs(velocity.y) * delta * 1.5 + 100
		floor_snap_length = min(required_snap, 800)  # Reduced max from 2500 to 800
	
	# FIXED: Better safety net that doesn't interfere with normal movement
	ground_ray.force_raycast_update()
	
	# Only use safety net as last resort
	if not is_on_floor() and ground_ray.is_colliding() and velocity.y > 0 and !is_upside_down:
		var collision_point = ground_ray.get_collision_point()
		var distance_to_floor = collision_point.y - global_position.y
		
		# Only snap if very close and moving downward significantly
		if distance_to_floor <= 8 and velocity.y > 100 and should_snap:
			global_position.y = collision_point.y - 2
			velocity.y = 0
	if stamina_bar:
		stamina_bar.value = stamina
		stamina_bar.max_value = max_stamina

func update_visuals():
	# ANIMATION SYSTEM - Using AnimationPlayer
	match current_state:
		"IDLE":
			if is_on_floor() and abs(velocity.x) < walk_threshold:
				if current_animation != "idle":
					animation_player.play("idle")
					current_animation = "idle"
		
		"WALKING":
			if is_on_floor() and abs(velocity.x) >= walk_threshold:
				if current_animation != "run":
					animation_player.play("run")
					current_animation = "run"
		
		"JUMPING":
			if not jump_start_played:
				animation_player.play("jump start")
				current_animation = "jump start"
				jump_start_played = true
			elif not animation_player.is_playing() or animation_player.current_animation != "jump start":
				if current_animation != "roll":
					animation_player.play("roll")
					current_animation = "roll"
		
		"FALLING":
			if current_animation != "roll":
				animation_player.play("roll")
				current_animation = "roll"
		
		"WALL_SLIDING":
			if current_animation != "wall slide":
				animation_player.play("wall slide")
				current_animation = "wall slide"
		
		"DASHING":
			if current_animation != "dash":
				animation_player.play("dash")
				current_animation = "dash"
		
		"GROUND_SLAMMING":
			if current_animation != "roll":
				animation_player.play("roll")
				current_animation = "roll"
		
		"ATTACKING":
			# Always use roll animation during attack
			if animation_player.has_animation("roll"):
				if current_animation != "roll":
					animation_player.play("roll")
					current_animation = "roll"

# FIXED: Proper slope detection and sprite rotation WITH BUFFER
func handle_slopes():
	# Only check for slope state changes after debounce time
	if slope_timer < slope_debounce:
		return
	
	# Reset timer
	slope_timer = 0.0
	
	# Reset rotation first
	if !override_slope_rotation:
		sprite_node.rotation_degrees = 0
	
	# Simple slope detection - only check floor angle
	if is_on_floor():
		var floor_normal = get_floor_normal()
		var _floor_angle = rad_to_deg(floor_normal.angle())
		
		# Fix the angle calculation - convert to proper slope angle
		var slope_angle = 0.0
		if abs(floor_normal.x) > 0.001:  # Avoid division by zero
			slope_angle = rad_to_deg(atan2(abs(floor_normal.y), abs(floor_normal.x)))
		
		var new_slope_state = abs(slope_angle) > slope_threshold and abs(slope_angle) < 85.0
		
		# NEW: SLOPE BUFFER - Keep slope state true for 0.2 seconds even after leaving slope
		if new_slope_state:
			is_on_slope = true
			slope_buffer_timer = 0.2  # Reset buffer timer when on slope
		elif slope_buffer_timer <= 0:
			is_on_slope = false
		
		# Update rotation if on slope - use floor normal angle but adjust for visual
		if new_slope_state:
			# Calculate the visual rotation based on floor normal
			var visual_rotation = 0.0
			if floor_normal.x > 0:  # Slope facing right
				visual_rotation = -slope_angle
			else:  # Slope facing left  
				visual_rotation = slope_angle
			if !override_slope_rotation:
				sprite_node.rotation_degrees = -snapped(visual_rotation, 22.5)
		else:
			# Not on slope, ensure rotation is 0
			if !override_slope_rotation:
				sprite_node.rotation_degrees = 0
	else:
		# Not on floor, not on slope (but use buffer)
		if slope_buffer_timer <= 0:
			is_on_slope = false
		if !override_slope_rotation:
			sprite_node.rotation_degrees = 0
	
func handle_stamina(delta):
	# Only regenerate stamina if not dashing or attacking
	if current_state != "DASHING" and current_state != "ATTACKING":
		# Stamina regenerates faster when moving faster
		var speed_bonus = abs(velocity.x) * stamina_regen_speed_multiplier
		var total_regen = stamina_regen_base + speed_bonus
		
		stamina = min(stamina + total_regen * delta, max_stamina)

func handle_input():
	var input_dir = Input.get_axis("move_left", "move_right")
	if input_dir != 0:
		facing_direction = input_dir
	
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer.start(0.1)

func apply_gravity(delta):
	if not is_on_floor() and current_state != "DASHING" and current_state != "GROUND_SLAMMING" and current_state != "ATTACKING":
		velocity.y += gravity * delta * upside_down_mult

func handle_movement(delta):
	# Don't process movement during attack
	if current_state == "ATTACKING":
		return
		
	var input_dir = Input.get_axis("move_left", "move_right")
	
	var current_accel = accel if is_on_floor() or (is_on_ceiling_only() and is_upside_down) else air_accel
	
	if current_state != "DASHING" and current_state != "GROUND_SLAMMING":
		if input_dir != 0:
			# On slopes, adjust acceleration to prevent speed fluctuations
			var effective_accel = current_accel
			if is_on_slope:
				# Reduce acceleration slightly on slopes for more consistent speed
				effective_accel = current_accel * 0.9
				
			velocity.x += input_dir * effective_accel * delta
			if sign(input_dir) != sign(velocity.x):
				if "jumppad" in current_areas_inside_names:
					velocity.x += input_dir * effective_accel * delta * 2.0
				else:
					velocity.x = input_dir * effective_accel * delta * 2.0
		elif is_on_floor() or (is_on_ceiling_only() and is_upside_down):
			velocity.x = lerp(velocity.x, 0.0, 0.1)

func handle_jump():
	if current_state == "GROUND_SLAMMING" or current_state == "ATTACKING":
		return
	# NEW: PREVENT JUMPING ON SLOPES AND CLEAR JUMP BUFFER
	if is_on_slope:
		jump_buffer_time = 0  # Clear any buffered jumps
		return
	
	if current_state == "DASHING":
		dash_jump_applicable = true
	if dash_jump_speed_timer.time_left > 0:
		dash_jump_applicable = true
	if is_on_floor() or (is_on_ceiling_only() and is_upside_down):
		coyote_time = 0.1
		has_double_jump = true
	elif coyote_time > 0:
		coyote_time -= get_physics_process_delta_time()
	
	if (is_on_floor() or coyote_time > 0 or (is_on_ceiling_only() and is_upside_down)) and jump_buffer_time > 0:
		velocity.y = jump_velocity*jump_mult*upside_down_mult
		play_sfx(jump_sfx)
		if exit_when_jump:
			exit_upside_down()
		if dash_jump_applicable:
			velocity.x *= dash_jump_mult
			velocity.y *= dash_jump_y_mult
		if jump_mult>1:
			velocity.x *= jump_mult/(jump_mult-0.3)
		coyote_time = 0
		jump_buffer_time = 0
		current_state = "JUMPING"
		jump_start_played = false  # Reset for jump animation
	
	if Input.is_action_just_released("jump") and velocity.y < jump_velocity * 0.5 and !current_state == "GROUND_SLAMMING":
		velocity.y = jump_velocity * 0.5
	
	if jump_buffer_timer.time_left > 0:
		jump_buffer_time = jump_buffer_timer.time_left
	else:
		jump_buffer_time = 0

func handle_dash():
	if current_state == "ATTACKING":
		return
		
	if Input.is_action_just_pressed("dash") and can_dash and stamina >= dash_cost:
		# Determine dash direction
		var dash_direction = facing_direction
		# If wall sliding, dash in opposite direction (away from wall)
		if is_wall_sliding:
			dash_direction = wall_side
			# Also update facing direction to match dash direction
			facing_direction = dash_direction
		if current_state == "GROUND_SLAMMING" and ground_slam_effect_temp != null:
			ground_slam_effect_temp.set_particle_emitting(false)
		# Calculate dash speed relative to current speed with minimum
		var current_speed = abs(velocity.x)
		var dash_speed = max(current_speed * dash_speed_multiplier, min_dash_speed)
		is_dashing = true
		play_sfx(dash_sfx)
		velocity.x = dash_direction * dash_speed# Dash horizontal speed

		velocity.y = 0  # Keep vertical velocity at 0 during dash
		can_dash = false
		stamina -= dash_cost
		current_state = "DASHING"
		dash_timer.start(dash_last_time)
		dash_cooldown_timer.start(dash_cooldown_time)
		node_array.append(instantiate_scene(dash_effect_scene,get_parent(),global_position))
		nodes_to_add_position_of_player.append(node_array[len(node_array)-1])
		if dash_direction == 1:
			node_array[len(node_array)-1].set_particle_flip(true,false)

func handle_wall_slide():
	# Prevent wall slide during certain states
	if current_state == "GROUND_SLAMMING" or current_state == "DASHING" or current_state == "ATTACKING" or (is_on_slope) or ("jumppad" in current_areas_inside_names) or is_upside_down:
		is_wall_sliding = false
		return
		
	@warning_ignore("unused_variable")
	var input_dir = Input.get_axis("move_left", "move_right")  # Fixed variable name
	
	# Only check for wall sliding if in air
	if not is_on_floor():
		# Check left wall - only count if there are overlapping bodies that aren't the player
		var left_wall_detected = false
		var left_valid_wall = true
		for body in left_detector.get_overlapping_areas():
			if "NO_WALLSLIDE" in body.name:
				left_valid_wall = false
		for body in left_detector.get_overlapping_bodies():
			if body != self and not body.is_in_group("player") and (body != CharacterBody2D and body != RigidBody2D) and left_valid_wall:
				left_wall_detected = true
				break
		
		# Check right wall - only count if there are overlapping bodies that aren't the player
		var right_wall_detected = false
		var right_valid_wall = true
		for body in right_detector.get_overlapping_areas():
			if "NO_WALLSLIDE" in body.name:
				right_valid_wall = false
		for body in right_detector.get_overlapping_bodies():
			if body != self and not body.is_in_group("player") and (body != CharacterBody2D and body != RigidBody2D) and right_valid_wall:
				right_wall_detected = true
				break
		
		# Check if we should start wall sliding
		var should_wall_slide = false
		
		# Manual wall slide (pressing toward wall)
		if left_wall_detected:
			should_wall_slide = true
			wall_side = 1

		if right_wall_detected:
			should_wall_slide = true
			wall_side = -1
		
		# Auto wall slide after wall jump (any wall)
		if auto_wall_slide_timer > 0 and not should_wall_slide:
			if left_wall_detected:
				should_wall_slide = true
				wall_side = 1
			elif right_wall_detected:
				should_wall_slide = true
				wall_side = -1
		
		# If we're already wall sliding, maintain it even if we release the key
		elif is_wall_sliding and not should_wall_slide:
			if (wall_side == 1 and left_wall_detected) or (wall_side == -1 and right_wall_detected):
				should_wall_slide = true
		
		# Update wall sliding state
		is_wall_sliding = should_wall_slide
		
		# If we're wall sliding, apply slide physics
		if is_wall_sliding and !current_state == "GROUND_SLAMMING":
			velocity.y = min(velocity.y*upside_down_mult, wall_slide_speed*upside_down_mult)
			has_double_jump = true
			current_state = "WALL_SLIDING"
			facing_direction = -wall_side
			# Wall jump - jump AWAY from wall
			if Input.is_action_just_pressed("jump") and last_wall_jump_time > wall_jump_cooldown:
				if wall_side == 1:
					velocity.x = wall_jump_horizontal  # Jump to the right
				else:
					velocity.x = -wall_jump_horizontal  # Jump to the left
				
				velocity.y = wall_jump_vertical*upside_down_mult
				has_double_jump = true
				current_state = "JUMPING"
				last_wall_jump_time = 0.0
				is_wall_sliding = false
				facing_direction = wall_side  # Face away from wall
				# Start auto wall slide timer
				auto_wall_slide_timer = auto_wall_slide_time
				
				# Reset jump animation for wall jump
				jump_start_played = false
	else:
		# On floor, stop wall sliding
		is_wall_sliding = false

func handle_ground_slam():
	if current_state == "ATTACKING":
		return
		
	# Start ground slam
	if Input.is_action_just_pressed("ground_slam") and not is_on_floor() and current_state != "DASHING" and stamina >= ground_slam_cost and current_state != "GROUND_SLAMMING" and !keep_y_at_zero_:
		is_wall_sliding = false
		velocity.y = ground_slam_force*upside_down_mult
		ground_slam_effect_temp = instantiate_scene(ground_slam_fall_effect,self,global_position)
		nodes_to_add_position_of_player.append(ground_slam_effect_temp)
		if is_upside_down:
			ground_slam_effect_temp.set_particle_flip(false,true)
		should_snap = false
		stamina -= ground_slam_cost
		current_state = "GROUND_SLAMMING"
		is_ground_slamming = true
	
	# Bounce when hitting ground
	if current_state == "GROUND_SLAMMING" and (is_on_floor() or (is_on_ceiling() and is_upside_down)):
		stop_ground_slam()
		if camera and camera.has_method("add_trauma"):
			camera.add_trauma(0.8)
			play_sfx(groundslam_sfx)

func update_state():
	# Don't change state during attack, dash, or ground slam
	if current_state == "DASHING" or (current_state == "GROUND_SLAMMING" and is_ground_slamming) or current_state == "ATTACKING":
		return
	
	if is_on_floor() or (is_on_ceiling() and is_upside_down):
		if abs(velocity.x) > walk_threshold:  # Using walk_threshold
			current_state = "WALKING"
		else:
			current_state = "IDLE"
	else:
		if is_wall_sliding:
			current_state = "WALL_SLIDING"
		elif velocity.y * upside_down_mult < 0:
			current_state = "JUMPING"
		else:
			current_state = "FALLING"

func _on_dash_timer_timeout():
	if current_state == "DASHING":
		velocity.y = 0
		current_state = "FALLING"
		velocity.x *= 0.9
		is_dashing = false
		dash_jump_speed_timer.start(dash_jump_buffer_time)
		
func _on_dash_cooldown_timer_timeout():
	can_dash = true

func groundslam_timer_func():
	jump_mult = 1

func dash_jump_timer_func():
	dash_jump_applicable = false

# AFTERIMAGE FUNCTION
func create_afterimage():
	if not afterimage_enabled:
		return
	
	var afterimage = Sprite2D.new()
	
	# Copy sprite properties
	afterimage.texture = sprite_node.texture
	afterimage.global_position = sprite_node.global_position
	afterimage.scale = sprite_node.global_scale  # Fixed: Use global_scale for proper scaling
	afterimage.rotation = sprite_node.rotation
	afterimage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Handle flip for upside down
	if is_upside_down:
		afterimage.flip_h = sprite_node.flip_h
		afterimage.flip_v = true  # Flip vertically when upside down
	else:
		afterimage.flip_h = sprite_node.flip_h
		afterimage.flip_v = false
	
	# Copy spritesheet properties
	afterimage.hframes = sprite_node.hframes
	afterimage.vframes = sprite_node.vframes
	afterimage.frame = sprite_node.frame
	afterimage.frame_coords = sprite_node.frame_coords
	
	# Copy region properties if using AtlasTexture
	afterimage.region_rect = sprite_node.region_rect
	afterimage.region_enabled = sprite_node.region_enabled
	
	# Set semi-transparent
	afterimage.modulate = Color(1, 1, 1, 0.5)
	
	# Add to scene
	get_parent().add_child(afterimage)
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(afterimage, "modulate", Color(1, 1, 1, 0), 0.6)
	tween.tween_callback(afterimage.queue_free)

func _on_entity_hitbox_area_entered(area):
	current_areas_inside.append(area)
	current_areas_inside_names.append(area.name)

func _on_entity_hitbox_area_exited(area):
	current_areas_inside.erase(area)
	current_areas_inside_names.erase(area.name)

func enter_upside_down(exit_when_jump_):
	if is_upside_down:
		return
	velocity.y = 0
	is_upside_down = true
	upside_down_mult = -1
	up_direction = Vector2.DOWN
	exit_when_jump = exit_when_jump_
	override_slope_rotation = true
	$sprite.rotation_degrees = 180
	$sprite.offset.y = -1.35
	has_double_jump = false

func exit_upside_down():
	if !is_upside_down:
		return
	is_upside_down = false
	upside_down_mult = 1
	up_direction = Vector2.UP
	exit_when_jump = false
	velocity.y = 0
	override_slope_rotation = false
	$sprite.rotation_degrees = 0
	$sprite.offset.y = -4.7

func keep_y_at_zero(time):
	keep_y_at_zero_ = true
	if current_state == "GROUND_SLAMMING":
		stop_ground_slam()
	await get_tree().create_timer(time).timeout
	keep_y_at_zero_ = false

func instantiate_scene(scene: PackedScene, parent , _position: Vector2 = Vector2.ZERO, properties: Array = [], values: Array = []) -> Node:
	if not scene:
		push_warning("No scene provided to instantiate")
		return null
	
	var instance = scene.instantiate()
	
	# Use deferred for adding and setting position
	instance.global_position = _position
	parent.call_deferred("add_child", instance)
	node_array.append(instance)
	# Apply properties
	for i in range(properties.size()):
		if i < values.size():
			instance.set(properties[i], values[i])
		else:
			push_warning("No value provided for property: " + str(properties[i]))
	
	return instance

func _on_pause_pressed():
	if get_tree().root.find_child("pause", true, false):
		var cancel_event = InputEventAction.new()
		cancel_event.action = "ui_cancel"
		cancel_event.pressed = true
		Input.parse_input_event(cancel_event)
		$CanvasLayer/Control/pause_.visible = false
		Input.action_release("ui_cancel")
		await get_tree().root.find_child("pause", true, false).resume_pressed
		$CanvasLayer/Control/pause_.visible = true

func play_sfx(song_path):
	var stream = load(song_path)
	playback.play_stream(stream)

func item_pickup(item):
	var objtag = item.object_tag
	if objtag == "base_object":
		Screen.print("$100")

# ============================================
# DASH COOLDOWN CLOCK FUNCTIONS (UPDATED)
# ============================================
func _start_cooldown_clock():
	if dash_cooldown_clock_texture == null:
		return
	# Use the CanvasLayer that is a direct child of the player
	var canvas = $CanvasLayer
	if not canvas:
		push_error("CanvasLayer node not found as child of blitz")
		return

	# Remove any existing clock sprite (just in case)
	if clock_sprite and is_instance_valid(clock_sprite):
		clock_sprite.queue_free()

	clock_sprite = Sprite2D.new()
	clock_sprite.texture = dash_cooldown_clock_texture
	clock_sprite.hframes = dash_cooldown_clock_hframes
	clock_sprite.vframes = dash_cooldown_clock_vframes
	clock_sprite.frame = 0
	clock_sprite.z_index = 20
	clock_sprite.position = dash_clock_position
	clock_sprite.scale = dash_clock_scale   # Apply the exported scale
	canvas.add_child(clock_sprite)

	clock_frame = dash_clock_appear_start
	clock_state = 1
	clock_timer = dash_clock_appear_speed   # time for first appear frame
	clock_sprite.frame = clock_frame - 1

func _update_cooldown_clock(delta):
	if clock_sprite == null or not is_instance_valid(clock_sprite):
		return

	clock_timer -= delta
	if clock_timer > 0:
		return

	match clock_state:
		1: # appear
			clock_frame += 1
			if clock_frame > dash_clock_appear_end:
				clock_frame = dash_clock_cooldown_start
				clock_state = 2
				var cooldown_frames = dash_clock_cooldown_end - dash_clock_cooldown_start + 1
				clock_timer = attack_cooldown_time / cooldown_frames
			else:
				clock_timer = dash_clock_appear_speed
			clock_sprite.frame = clock_frame - 1   # 0‑based
		2: # cooldown
			clock_frame += 1
			if clock_frame > dash_clock_cooldown_end:
				clock_frame = dash_clock_disappear_start
				clock_state = 3
				clock_timer = dash_clock_appear_speed
			else:
				var cooldown_frames = dash_clock_cooldown_end - dash_clock_cooldown_start + 1
				clock_timer = attack_cooldown_time / cooldown_frames
			clock_sprite.frame = clock_frame - 1
		3: # disappear
			clock_frame += 1
			if clock_frame > dash_clock_disappear_end:
				clock_sprite.queue_free()
				clock_sprite = null
				clock_state = 0
				return
			clock_timer = dash_clock_appear_speed
			clock_sprite.frame = clock_frame - 1
