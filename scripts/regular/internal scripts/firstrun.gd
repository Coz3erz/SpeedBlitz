# Create a new script called FirstRunHandler.gd as an autoload
extends Node

var first_run_complete = false

func _ready():
	# Check if this is first run
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err != OK:
		# First run - create default settings
		create_default_settings()
		await get_tree().create_timer(0.5).timeout  # Wait for settings to save
		force_window_redraw()

func create_default_settings():
	var config = ConfigFile.new()
	
	# Set default values
	config.set_value("gameplay", "screen_shake", true)
	config.set_value("gameplay", "particles_enabled", true)
	config.set_value("graphics", "quality", 2)  # Medium
	config.set_value("graphics", "fullscreen", true)
	config.set_value("graphics", "vsync", true)
	config.set_value("graphics", "msaa", 0)
	config.set_value("graphics", "fps_limit", 2)
	config.set_value("audio", "master_volume", 100)
	config.set_value("audio", "music_volume", 100)
	config.set_value("audio", "sfx_volume", 100)
	
	config.save("user://settings.cfg")
	print("FirstRunHandler: Created default settings")

func force_window_redraw():
	# Force a window mode change to apply settings
	var window = get_window()
	window.mode = Window.MODE_WINDOWED
	await get_tree().process_frame
	window.mode = Window.MODE_FULLSCREEN
	
	# Add a small delay and refresh input map
	await get_tree().create_timer(0.1).timeout
	InputMap.load_from_project_settings()
