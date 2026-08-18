extends Node

func _ready():
	if not OS.has_feature("web"):
		return
	
	# WebGL-specific initialization
	print("WebGL: Initializing for itch.io")
	
	# Wait for everything to load
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Set fullscreen after a delay
	await get_tree().create_timer(0.2).timeout
	
	# Check if settings exist, create if not
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") != OK:
		# Create default settings
		var default_config = ConfigFile.new()
		default_config.set_value("graphics", "fullscreen", true)
		default_config.save("user://settings.cfg")
		
		# Force fullscreen
		get_window().mode = Window.MODE_FULLSCREEN
	
	# Reload input map to ensure it's loaded
	await get_tree().create_timer(0.1).timeout
	InputMap.load_from_project_settings()
