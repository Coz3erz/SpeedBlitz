extends Node

# Flag to track if we've initialized settings
var settings_initialized = false

func _ready():
	# Wait longer for everything to initialize
	await get_tree().process_frame
	await get_tree().process_frame  # Extra wait for WebGL
	
	# Only apply settings if not already done by OptionsMenu
	if not settings_initialized:
		initialize_settings()

func initialize_settings():
	# Load saved settings
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		# Get saved fullscreen setting
		var is_fullscreen = config.get_value("graphics", "fullscreen", true)
		
		# Apply fullscreen setting
		var window = get_window()
		if is_fullscreen:
			window.mode = Window.MODE_FULLSCREEN
		else:
			window.mode = Window.MODE_WINDOWED
			# Set window to 75% of monitor size
			var monitor_size = DisplayServer.screen_get_size()
			var target_size = Vector2i(
				int(monitor_size.x * 0.75),
				int(monitor_size.y * 0.75)
			)
			window.size = target_size
			@warning_ignore("integer_division")
			window.position = (monitor_size - target_size) / 2
			@warning_ignore("integer_division")
		print("WindowHandler: Applied saved settings - Fullscreen:", is_fullscreen)
	else:
		print("WindowHandler: No saved settings, will be set by OptionsMenu")
	
	settings_initialized = true
