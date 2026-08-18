# InputSnapshot.gd - Autoload to capture default input map
extends Node

var default_input_map: Dictionary = {}

func _ready():
	# Capture default input map IMMEDIATELY when game starts
	capture_default_input_map()
	print("InputSnapshot: Captured default input map")

func capture_default_input_map():
	# Store ALL actions from InputMap at game start
	var all_actions = InputMap.get_actions()
	
	for action in all_actions:
		# Get all events for this action
		var events = InputMap.action_get_events(action)
		var event_data = []
		
		for event in events:
			var event_dict = _serialize_input_event(event)
			if not event_dict.is_empty():
				event_data.append(event_dict)
		
		default_input_map[action] = event_data
		print("Captured default for action: ", action, " with ", event_data.size(), " events")

func _serialize_input_event(event: InputEvent) -> Dictionary:
	var event_dict = {}
	
	if event is InputEventKey:
		event_dict = {
			"type": "key",
			"keycode": event.keycode,
			"physical_keycode": event.physical_keycode,
			"shift_pressed": event.shift_pressed,
			"ctrl_pressed": event.ctrl_pressed,
			"alt_pressed": event.alt_pressed,
			"meta_pressed": event.meta_pressed
		}
	elif event is InputEventMouseButton:
		event_dict = {
			"type": "mouse",
			"button_index": event.button_index,
			"double_click": event.double_click,
			"factor": event.factor
		}
	elif event is InputEventJoypadButton:
		event_dict = {
			"type": "joypad_button",
			"button_index": event.button_index,
			"pressure": event.pressure
		}
	elif event is InputEventJoypadMotion:
		event_dict = {
			"type": "joypad_motion",
			"axis": event.axis,
			"axis_value": event.axis_value
		}
	
	return event_dict

func _deserialize_input_event(event_dict: Dictionary) -> InputEvent:
	var event
	
	match event_dict.get("type"):
		"key":
			event = InputEventKey.new()
			event.keycode = event_dict.get("keycode", 0)
			event.physical_keycode = event_dict.get("physical_keycode", 0)
			event.shift_pressed = event_dict.get("shift_pressed", false)
			event.ctrl_pressed = event_dict.get("ctrl_pressed", false)
			event.alt_pressed = event_dict.get("alt_pressed", false)
			event.meta_pressed = event_dict.get("meta_pressed", false)
		"mouse":
			event = InputEventMouseButton.new()
			event.button_index = event_dict.get("button_index", 0)
			event.double_click = event_dict.get("double_click", false)
			event.factor = event_dict.get("factor", 1.0)
		"joypad_button":
			event = InputEventJoypadButton.new()
			event.button_index = event_dict.get("button_index", 0)
			event.pressure = event_dict.get("pressure", 1.0)
		"joypad_motion":
			event = InputEventJoypadMotion.new()
			event.axis = event_dict.get("axis", 0)
			event.axis_value = event_dict.get("axis_value", 0.0)
		_:
			return null
	
	return event

func get_default_events_for_action(action: String) -> Array:
	# Returns the default events for a specific action
	return default_input_map.get(action, [])

func reset_action_to_default(action: String):
	# Reset a single action to its default state
	if default_input_map.has(action):
		InputMap.action_erase_events(action)
		var default_events = default_input_map[action]
		
		for event_dict in default_events:
			var event = _deserialize_input_event(event_dict)
			if event:
				InputMap.action_add_event(action, event)
		
		print("Reset action '", action, "' to default")

func reset_all_to_default():
	# Reset ALL actions to their default state
	for action in default_input_map.keys():
		reset_action_to_default(action)
	print("Reset ALL input bindings to defaults")

func save_default_map_to_file():
	# Save the default map for future reference
	var config = ConfigFile.new()
	
	for action in default_input_map.keys():
		config.set_value("default_input", action, default_input_map[action])
	
	config.save("user://default_input_map.cfg")
	print("Saved default input map to file")
