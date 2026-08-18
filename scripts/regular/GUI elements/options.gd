extends CanvasLayer

signal options_closed

@export var is_main_menu_mode: bool = false
@export var fade_duration: float = 0.2

enum Section { GAMEPLAY, GRAPHICS, AUDIO, INPUT }
var current_section: Section = Section.GAMEPLAY

var settings_changed: bool = false
var original_settings = {}

var rebinding_action: String = ""
var rebinding_button: Button = null
var new_event: InputEvent = null
var is_rebinding: bool = false

var confirm_dialog: AcceptDialog

var quality_presets = [
	{"name": "Very Low", "scale": 0.5},
	{"name": "Low", "scale": 0.75},
	{"name": "Medium", "scale": 1.0},
	{"name": "High", "scale": 1.25},
	{"name": "Ultra", "scale": 1.5},
	{"name": "Native", "scale": 2.0}
]

var section_buttons = {}
var content_containers = {}

@export var background_style: StyleBoxFlat
@export var button_style: StyleBoxFlat
@export var button_hover_style: StyleBoxFlat
@export var button_pressed_style: StyleBoxFlat
@export var label_font: Font
@export var button_font: Font
@export var font_size: int = 24
@export var title_font_size: int = 36
@export var dialog_font_size: int = 28
@export var checkbox_scale: float = 1.5
@export var checkbox_texture_checked: Texture2D
@export var checkbox_texture_unchecked: Texture2D

@export var content_width: int = 800
@export var input_button_width: int = 250
@export var rebind_cancel_key: Key = KEY_ESCAPE

var input_actions: Array[String] = [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "dash", "ground_slam", "attack", "shoot"
]

var has_graphics_changes: bool = false
var is_web_or_mobile: bool = false
var _is_fading: bool = false

var default_input_snapshot: Dictionary = {}

# ------------------------------------------------------------------
# Ready & Initial Setup
# ------------------------------------------------------------------
func _ready():
	if OS.has_feature("mobile") or OS.has_feature("web"):
		if DisplayServer.is_touchscreen_available():
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
		is_web_or_mobile = true

	process_mode = Node.PROCESS_MODE_ALWAYS

	ensure_all_actions_exist()
	_snapshot_default_input_map()
	ensure_audio_buses()
	load_input_map()
	create_options_menu()
	await get_tree().process_frame
	load_settings()
	update_section_visibility()
	self.visible = false

	if is_web_or_mobile:
		force_fullscreen_web_mobile()

func _snapshot_default_input_map():
	default_input_snapshot.clear()
	for action in input_actions:
		if InputMap.has_action(action):
			var events = InputMap.action_get_events(action)
			var event_list = []
			for ev in events:
				event_list.append(_serialize_input_event_for_saving(ev))
			default_input_snapshot[action] = event_list
		else:
			default_input_snapshot[action] = []

func restore_default_input_map():
	for action in input_actions:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			if default_input_snapshot.has(action):
				for ev_dict in default_input_snapshot[action]:
					var ev = _deserialize_input_event_for_loading(ev_dict)
					if ev:
						InputMap.action_add_event(action, ev)
		else:
			InputMap.add_action(action)
			if default_input_snapshot.has(action):
				for ev_dict in default_input_snapshot[action]:
					var ev = _deserialize_input_event_for_loading(ev_dict)
					if ev:
						InputMap.action_add_event(action, ev)
	save_input_map()

func ensure_all_actions_exist():
	var fallback = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE],
		"dash": [KEY_SHIFT],
		"ground_slam": [KEY_S],
		"attack": [MOUSE_BUTTON_LEFT],
		"shoot": [KEY_F],
	}
	for action in input_actions:
		if not InputMap.has_action(action):
			print("WARNING: '", action, "' action not found! Creating it now...")
			InputMap.add_action(action)
			var bindings = fallback.get(action, [])
			for binding in bindings:
				if binding is int and binding < 1000:
					var key_event = InputEventKey.new()
					key_event.keycode = binding
					InputMap.action_add_event(action, key_event)
				elif binding == MOUSE_BUTTON_LEFT:
					var mouse_event = InputEventMouseButton.new()
					mouse_event.button_index = MOUSE_BUTTON_LEFT
					InputMap.action_add_event(action, mouse_event)
		else:
			var events = InputMap.action_get_events(action)
			if events.size() == 0:
				print("WARNING: '", action, "' action exists but has NO bindings! Adding defaults...")
				var bindings = fallback.get(action, [])
				for binding in bindings:
					if binding is int and binding < 1000:
						var key_event = InputEventKey.new()
						key_event.keycode = binding
						InputMap.action_add_event(action, key_event)
					elif binding == MOUSE_BUTTON_LEFT:
						var mouse_event = InputEventMouseButton.new()
						mouse_event.button_index = MOUSE_BUTTON_LEFT
						InputMap.action_add_event(action, mouse_event)
			else:
				print("'", action, "' action exists with ", events.size(), " binding(s)")

func ensure_audio_buses():
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		var new_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(new_bus_idx, "Music")
		AudioServer.set_bus_send(new_bus_idx, "Master")

	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if sfx_bus_idx == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		var new_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(new_bus_idx, "SFX")
		AudioServer.set_bus_send(new_bus_idx, "Master")

func force_fullscreen_web_mobile():
	var window = get_window()
	window.mode = Window.MODE_FULLSCREEN
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	set_setting("graphics", "fullscreen", true)

func load_input_map():
	var config = ConfigFile.new()
	if config.load("user://user_input_map.cfg") == OK:
		print("Loading user input map from file")
		for action in input_actions:
			if config.has_section_key("user_input", action):
				var event_data = config.get_value("user_input", action, [])
				InputMap.action_erase_events(action)
				for event_dict in event_data:
					var event = _deserialize_input_event_for_loading(event_dict)
					if event:
						InputMap.action_add_event(action, event)
	else:
		ensure_all_actions_exist()

func save_input_map():
	var config = ConfigFile.new()
	for action in input_actions:
		var events = InputMap.action_get_events(action)
		var event_data = []
		for event in events:
			var event_dict = _serialize_input_event_for_saving(event)
			if not event_dict.is_empty():
				event_data.append(event_dict)
		config.set_value("user_input", action, event_data)
	config.save("user://user_input_map.cfg")

func _input(event):
	if _is_fading:
		return
	if event.is_action_pressed("ui_cancel"):
		if is_rebinding:
			_cancel_rebinding()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("fullscreen") and not is_web_or_mobile:
		var current_fullscreen = get_setting("graphics", "fullscreen", false)
		_on_fullscreen_toggled(!current_fullscreen)
		get_viewport().set_input_as_handled()
	if is_rebinding and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return

# ------------------------------------------------------------------
# Show / Hide
# ------------------------------------------------------------------
func options_show():
	_is_fading = false
	var mc = find_child("MainContainer", true, false)
	var bg = find_child("Background", true, false)
	if mc:
		mc.mouse_filter = Control.MOUSE_FILTER_STOP
		mc.focus_mode = Control.FOCUS_ALL
		mc.modulate.a = 1.0
	if bg and bg is ColorRect: bg.color.a = 0.9
	self.visible = true
	ControllerMouse.set_menu_open("options",true)

func options_hide():
	_is_fading = false
	self.visible = false
	emit_signal("options_closed")
	ControllerMouse.set_menu_open("options",false)

func appear():
	if _is_fading: return
	_is_fading = true
	var bg = find_child("Background", true, false)
	var mc = find_child("MainContainer", true, false)
	if mc: mc.mouse_filter = Control.MOUSE_FILTER_IGNORE; mc.focus_mode = Control.FOCUS_NONE
	self.visible = true
	ControllerMouse.set_menu_open("options",true)
	if bg is ColorRect: bg.color.a = 0.0
	if mc: mc.modulate.a = 0.0
	var dur = max(fade_duration, 0.01)
	var tw = create_tween().set_parallel(true)
	if bg is ColorRect: tw.tween_property(bg, "color:a", 0.9, dur)
	if mc: tw.tween_property(mc, "modulate:a", 1.0, dur)
	tw.tween_callback(func(): if mc: mc.mouse_filter = Control.MOUSE_FILTER_STOP; mc.focus_mode = Control.FOCUS_ALL; _is_fading = false)

func disappear():
	get_viewport().gui_disable_input = true
	if _is_fading: return
	_is_fading = true
	emit_signal("options_closed")
	ControllerMouse.set_menu_open("options",false)
	var bg = find_child("Background", true, false)
	var mc = find_child("MainContainer", true, false)
	if mc: mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dur = max(fade_duration, 0.2)
	var elapsed = 0.0
	while elapsed < dur:
		elapsed += get_process_delta_time()
		var t = min(elapsed / dur, 1.0)
		var a = lerp(0.9, 0.0, t)
		if bg: bg.color.a = a
		if mc: mc.modulate.a = a
		await get_tree().process_frame
	if bg: bg.color.a = 0.0
	if mc: mc.modulate.a = 0.0
	self.visible = false
	if mc: mc.mouse_filter = Control.MOUSE_FILTER_STOP; get_viewport().gui_disable_input = false
	_is_fading = false

# ------------------------------------------------------------------
# UI Creation (Gameplay, Graphics, Audio, Input)
# ------------------------------------------------------------------
# ... (all the create_*_section functions remain identical to the last full version you had) ...

# ------------------------------------------------------------------
# Event Display – FIXED MATCH SYNTAX
# ------------------------------------------------------------------
func get_event_display_text(event: InputEvent) -> String:
	if event == null: return "Click to bind"
	if event is InputEventKey: return event.as_text()
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT: return "Left Mouse"
			MOUSE_BUTTON_RIGHT: return "Right Mouse"
			MOUSE_BUTTON_MIDDLE: return "Middle Mouse"
			MOUSE_BUTTON_WHEEL_UP: return "Mouse Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Mouse Wheel Down"
			MOUSE_BUTTON_XBUTTON1: return "Mouse X Button 1"
			MOUSE_BUTTON_XBUTTON2: return "Mouse X Button 2"
			_: return "Mouse Button %d" % event.button_index
	if event is InputEventJoypadButton: return "Joypad Button %d" % event.button_index
	if event is InputEventJoypadMotion:
		var axis_name = "Left" if event.axis < 2 else "Right"
		var direction = "X" if event.axis % 2 == 0 else "Y"
		return "Joypad %s %s" % [axis_name, direction]
	return "Unknown"

# ------------------------------------------------------------------
# Menu creation (complete)
# ------------------------------------------------------------------
func create_options_menu():
	# Background
	var background = ColorRect.new()
	background.name = "Background"
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.color = Color(0, 0, 0, 0.9)
	if background_style:
		background.set("custom_styles/panel", background_style)
	add_child(background)

	# Main container
	var main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.anchor_right = 1.0
	main_container.anchor_bottom = 1.0
	main_container.offset_left = 50
	main_container.offset_right = -50
	main_container.offset_top = 50
	main_container.offset_bottom = -50
	main_container.add_theme_constant_override("separation", 20)
	add_child(main_container)

	# Title
	var title = Label.new()
	title.name = "Title"
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if label_font:
		title.add_theme_font_override("font", label_font)
	title.add_theme_font_size_override("font_size", title_font_size)
	main_container.add_child(title)

	# Section buttons
	var section_buttons_container = HBoxContainer.new()
	section_buttons_container.name = "SectionButtons"
	section_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	section_buttons_container.add_theme_constant_override("separation", 10)
	main_container.add_child(section_buttons_container)

	# Create section buttons
	section_buttons["gameplay"] = create_section_button("Gameplay")
	section_buttons["gameplay"].pressed.connect(_on_gameplay_pressed)
	section_buttons_container.add_child(section_buttons["gameplay"])

	section_buttons["graphics"] = create_section_button("Graphics")
	section_buttons["graphics"].pressed.connect(_on_graphics_pressed)
	section_buttons_container.add_child(section_buttons["graphics"])

	section_buttons["audio"] = create_section_button("Audio")
	section_buttons["audio"].pressed.connect(_on_audio_pressed)
	section_buttons_container.add_child(section_buttons["audio"])

	section_buttons["input"] = create_section_button("Input")
	section_buttons["input"].pressed.connect(_on_input_pressed)
	section_buttons_container.add_child(section_buttons["input"])

	# Content area with scroll
	var content_scroll = ScrollContainer.new()
	content_scroll.name = "ContentScroll"
	content_scroll.custom_minimum_size = Vector2(content_width, 400)
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(content_scroll)

	var content_container = VBoxContainer.new()
	content_container.name = "ContentContainer"
	content_container.add_theme_constant_override("separation", 15)
	content_scroll.add_child(content_container)

	# Create all section contents
	create_gameplay_section(content_container)
	create_graphics_section(content_container)
	create_audio_section(content_container)
	create_input_section(content_container)

	# Bottom buttons
	var bottom_buttons = HBoxContainer.new()
	bottom_buttons.name = "BottomButtons"
	bottom_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_buttons.add_theme_constant_override("separation", 20)
	main_container.add_child(bottom_buttons)

	var back_btn = create_action_button("Back")
	back_btn.pressed.connect(_on_back_pressed)
	bottom_buttons.add_child(back_btn)

	var apply_btn = create_action_button("Apply")
	apply_btn.pressed.connect(_on_apply_pressed)
	bottom_buttons.add_child(apply_btn)

	var reset_btn = create_action_button("Reset Quality")
	reset_btn.pressed.connect(_on_reset_quality_pressed)
	bottom_buttons.add_child(reset_btn)

	var reset_defaults_btn = create_action_button("Reset to Defaults")
	reset_defaults_btn.pressed.connect(_on_reset_defaults_pressed)
	bottom_buttons.add_child(reset_defaults_btn)

	# Create confirmation dialog
	create_confirm_dialog()

	# Force update the UI
	call_deferred("update_ui_visibility")

func update_ui_visibility():
	for container in content_containers.values():
		container.visible = false

	match current_section:
		Section.GAMEPLAY: content_containers["gameplay"].visible = true
		Section.GRAPHICS: content_containers["graphics"].visible = true
		Section.AUDIO:   content_containers["audio"].visible   = true
		Section.INPUT:    content_containers["input"].visible    = true

func create_section_button(text: String) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 40)

	if button_style:
		button.add_theme_stylebox_override("normal", button_style)
	if button_hover_style:
		button.add_theme_stylebox_override("hover", button_hover_style)
	if button_pressed_style:
		button.add_theme_stylebox_override("pressed", button_pressed_style)

	if button_font:
		button.add_theme_font_override("font", button_font)
		button.add_theme_font_size_override("font_size", font_size)

	button.focus_mode = Control.FOCUS_NONE
	var style_empty = StyleBoxEmpty.new()
	button.add_theme_stylebox_override("focus", style_empty)

	return button

func create_action_button(text: String) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 40)

	if button_style:
		button.add_theme_stylebox_override("normal", button_style)
	if button_hover_style:
		button.add_theme_stylebox_override("hover", button_hover_style)
	if button_pressed_style:
		button.add_theme_stylebox_override("pressed", button_pressed_style)

	if button_font:
		button.add_theme_font_override("font", button_font)
		button.add_theme_font_size_override("font_size", font_size)

	button.focus_mode = Control.FOCUS_NONE
	var style_empty = StyleBoxEmpty.new()
	button.add_theme_stylebox_override("focus", style_empty)

	return button

# ------------------------------------------------------------------
# Section contents
# ------------------------------------------------------------------
func create_gameplay_section(parent: VBoxContainer):
	var container = VBoxContainer.new()
	container.name = "GameplayContent"
	content_containers["gameplay"] = container
	parent.add_child(container)

	# Screen Shake
	var shake_container = HBoxContainer.new()
	shake_container.add_theme_constant_override("separation", 20)
	container.add_child(shake_container)

	var shake_label = Label.new()
	shake_label.text = "Screen Shake:"
	shake_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	shake_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if label_font:
		shake_label.add_theme_font_override("font", label_font)
		shake_label.add_theme_font_size_override("font_size", font_size)
	shake_container.add_child(shake_label)

	var shake_toggle = CheckBox.new()
	shake_toggle.name = "ShakeToggle"
	shake_toggle.toggled.connect(_on_shake_toggled)
	shake_toggle.focus_mode = Control.FOCUS_NONE
	shake_toggle.scale = Vector2(checkbox_scale, checkbox_scale)

	if checkbox_texture_checked and checkbox_texture_unchecked:
		shake_toggle.add_theme_icon_override("checked", checkbox_texture_checked)
		shake_toggle.add_theme_icon_override("unchecked", checkbox_texture_unchecked)

	shake_container.add_child(shake_toggle)

	# Particles
	var particle_container = HBoxContainer.new()
	particle_container.add_theme_constant_override("separation", 20)
	container.add_child(particle_container)

	var particle_label = Label.new()
	particle_label.text = "Particles Enabled:"
	particle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	particle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if label_font:
		particle_label.add_theme_font_override("font", label_font)
		particle_label.add_theme_font_size_override("font_size", font_size)
	particle_container.add_child(particle_label)

	var particle_toggle = CheckBox.new()
	particle_toggle.name = "ParticleToggle"
	particle_toggle.toggled.connect(_on_particle_toggled)
	particle_toggle.focus_mode = Control.FOCUS_NONE
	particle_toggle.scale = Vector2(checkbox_scale, checkbox_scale)

	if checkbox_texture_checked and checkbox_texture_unchecked:
		particle_toggle.add_theme_icon_override("checked", checkbox_texture_checked)
		particle_toggle.add_theme_icon_override("unchecked", checkbox_texture_unchecked)

	particle_container.add_child(particle_toggle)

	# Use left joystick for aiming
	var aim_container = HBoxContainer.new()
	aim_container.add_theme_constant_override("separation", 20)
	container.add_child(aim_container)

	var aim_label = Label.new()
	aim_label.text = "Use left joystick for aiming:"
	aim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	aim_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if label_font:
		aim_label.add_theme_font_override("font", label_font)
		aim_label.add_theme_font_size_override("font_size", font_size)
	aim_container.add_child(aim_label)

	var aim_toggle = CheckBox.new()
	aim_toggle.name = "AimStickToggle"
	aim_toggle.toggled.connect(_on_aim_stick_toggled)
	aim_toggle.focus_mode = Control.FOCUS_NONE
	aim_toggle.scale = Vector2(checkbox_scale, checkbox_scale)

	if checkbox_texture_checked and checkbox_texture_unchecked:
		aim_toggle.add_theme_icon_override("checked", checkbox_texture_checked)
		aim_toggle.add_theme_icon_override("unchecked", checkbox_texture_unchecked)

	aim_container.add_child(aim_toggle)

func create_graphics_section(parent: VBoxContainer):
	var container = VBoxContainer.new()
	container.name = "GraphicsContent"
	content_containers["graphics"] = container
	parent.add_child(container)

	# QUALITY SLIDER (Render Scale)
	var quality_container = HBoxContainer.new()
	quality_container.add_theme_constant_override("separation", 20)
	container.add_child(quality_container)

	var quality_label = Label.new()
	quality_label.text = "Render Quality:"
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	quality_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if label_font:
		quality_label.add_theme_font_override("font", label_font)
		quality_label.add_theme_font_size_override("font_size", font_size)
	quality_container.add_child(quality_label)

	# Quality slider container
	var quality_slider_container = VBoxContainer.new()
	quality_slider_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quality_container.add_child(quality_slider_container)

	var quality_slider = HSlider.new()
	quality_slider.name = "QualitySlider"
	quality_slider.min_value = 0
	quality_slider.max_value = quality_presets.size() - 1
	quality_slider.step = 1
	quality_slider.value = 2  # Default to Medium (index 2)
	quality_slider.value_changed.connect(_on_quality_slider_changed)
	quality_slider.focus_mode = Control.FOCUS_NONE
	quality_slider_container.add_child(quality_slider)

	# Fullscreen - ONLY SHOW ON DESKTOP (not web or mobile)
	if not is_web_or_mobile:
		var fullscreen_container = HBoxContainer.new()
		fullscreen_container.add_theme_constant_override("separation", 20)
		container.add_child(fullscreen_container)

		var fullscreen_label = Label.new()
		fullscreen_label.text = "Fullscreen:"
		fullscreen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		fullscreen_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if label_font:
			fullscreen_label.add_theme_font_override("font", label_font)
			fullscreen_label.add_theme_font_size_override("font_size", font_size)
		fullscreen_container.add_child(fullscreen_label)

		var fullscreen_toggle = CheckBox.new()
		fullscreen_toggle.name = "FullscreenToggle"
		fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
		fullscreen_toggle.focus_mode = Control.FOCUS_NONE
		fullscreen_toggle.scale = Vector2(checkbox_scale, checkbox_scale)

		if checkbox_texture_checked and checkbox_texture_unchecked:
			fullscreen_toggle.add_theme_icon_override("checked", checkbox_texture_checked)
			fullscreen_toggle.add_theme_icon_override("unchecked", checkbox_texture_unchecked)

		fullscreen_container.add_child(fullscreen_toggle)

	# VSync
	var vsync_container = HBoxContainer.new()
	vsync_container.add_theme_constant_override("separation", 20)
	container.add_child(vsync_container)

	var vsync_label = Label.new()
	vsync_label.text = "VSync:"
	vsync_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vsync_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if label_font:
		vsync_label.add_theme_font_override("font", label_font)
		vsync_label.add_theme_font_size_override("font_size", font_size)
	vsync_container.add_child(vsync_label)

	var vsync_toggle = CheckBox.new()
	vsync_toggle.name = "VSyncToggle"
	vsync_toggle.toggled.connect(_on_vsync_toggled)
	vsync_toggle.focus_mode = Control.FOCUS_NONE
	vsync_toggle.scale = Vector2(checkbox_scale, checkbox_scale)

	if checkbox_texture_checked and checkbox_texture_unchecked:
		vsync_toggle.add_theme_icon_override("checked", checkbox_texture_checked)
		vsync_toggle.add_theme_icon_override("unchecked", checkbox_texture_unchecked)

	vsync_container.add_child(vsync_toggle)

	# MSAA
	var msaa_container = HBoxContainer.new()
	msaa_container.add_theme_constant_override("separation", 20)
	container.add_child(msaa_container)

	var msaa_label = Label.new()
	msaa_label.text = "Anti-Aliasing:"
	msaa_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	msaa_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if label_font:
		msaa_label.add_theme_font_override("font", label_font)
		msaa_label.add_theme_font_size_override("font_size", font_size)
	msaa_container.add_child(msaa_label)

	var msaa_option = OptionButton.new()
	msaa_option.name = "MSAAOption"
	msaa_option.add_item("Disabled", 0)
	msaa_option.add_item("2x", 1)
	msaa_option.add_item("4x", 2)
	msaa_option.add_item("8x", 3)
	msaa_option.item_selected.connect(_on_msaa_selected)
	msaa_option.focus_mode = Control.FOCUS_NONE
	if button_font:
		msaa_option.add_theme_font_override("font", button_font)
		msaa_option.add_theme_font_size_override("font_size", font_size)
	msaa_container.add_child(msaa_option)

	# FPS Limit
	var fps_container = HBoxContainer.new()
	fps_container.add_theme_constant_override("separation", 20)
	container.add_child(fps_container)

	var fps_label = Label.new()
	fps_label.text = "FPS Limit:"
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	fps_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if label_font:
		fps_label.add_theme_font_override("font", label_font)
		fps_label.add_theme_font_size_override("font_size", font_size)
	fps_container.add_child(fps_label)

	var fps_option = OptionButton.new()
	fps_option.name = "FPSOption"
	fps_option.add_item("Unlimited", 0)
	fps_option.add_item("30", 1)
	fps_option.add_item("60", 2)
	fps_option.add_item("120", 3)
	fps_option.add_item("144", 4)
	fps_option.add_item("240", 5)
	fps_option.item_selected.connect(_on_fps_limit_selected)
	fps_option.focus_mode = Control.FOCUS_NONE
	if button_font:
		fps_option.add_theme_font_override("font", button_font)
		fps_option.add_theme_font_size_override("font_size", font_size)
	fps_container.add_child(fps_option)

func create_audio_section(parent: VBoxContainer):
	var container = VBoxContainer.new()
	container.name = "AudioContent"
	content_containers["audio"] = container
	parent.add_child(container)

	# Master Volume
	var master_container = VBoxContainer.new()
	container.add_child(master_container)

	var master_label = Label.new()
	master_label.text = "Master Volume"
	master_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if label_font:
		master_label.add_theme_font_override("font", label_font)
		master_label.add_theme_font_size_override("font_size", font_size)
	master_container.add_child(master_label)

	var master_slider = HSlider.new()
	master_slider.name = "MasterSlider"
	master_slider.min_value = 0
	master_slider.max_value = 100
	master_slider.value = 100
	master_slider.value_changed.connect(_on_master_volume_changed)
	master_slider.focus_mode = Control.FOCUS_NONE
	master_container.add_child(master_slider)

	# Music Volume
	var music_container = VBoxContainer.new()
	container.add_child(music_container)

	var music_label = Label.new()
	music_label.text = "Music Volume"
	music_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if label_font:
		music_label.add_theme_font_override("font", label_font)
		music_label.add_theme_font_size_override("font_size", font_size)
	music_container.add_child(music_label)

	var music_slider = HSlider.new()
	music_slider.name = "MusicSlider"
	music_slider.min_value = 0
	music_slider.max_value = 100
	music_slider.value = 100
	music_slider.value_changed.connect(_on_music_volume_changed)
	music_slider.focus_mode = Control.FOCUS_NONE
	music_container.add_child(music_slider)

	# SFX Volume
	var sfx_container = VBoxContainer.new()
	container.add_child(sfx_container)

	var sfx_label = Label.new()
	sfx_label.text = "SFX Volume"
	sfx_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if label_font:
		sfx_label.add_theme_font_override("font", label_font)
		sfx_label.add_theme_font_size_override("font_size", font_size)
	sfx_container.add_child(sfx_label)

	var sfx_slider = HSlider.new()
	sfx_slider.name = "SFXSlider"
	sfx_slider.min_value = 0
	sfx_slider.max_value = 100
	sfx_slider.value = 100
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	sfx_slider.focus_mode = Control.FOCUS_NONE
	sfx_container.add_child(sfx_slider)

func create_input_section(parent: VBoxContainer):
	var container = VBoxContainer.new()
	container.name = "InputContent"
	content_containers["input"] = container
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(container)

	var input_label = Label.new()
	input_label.text = "INPUT BINDINGS"
	input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if label_font:
		input_label.add_theme_font_override("font", label_font)
		input_label.add_theme_font_size_override("font_size", title_font_size)
	container.add_child(input_label)

	var input_scroll = ScrollContainer.new()
	input_scroll.custom_minimum_size = Vector2(content_width, 350)
	input_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	input_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(input_scroll)

	var input_container = VBoxContainer.new()
	input_container.add_theme_constant_override("separation", 10)
	input_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_scroll.add_child(input_container)

	print("Creating input section with actions: ", input_actions)

	for action in input_actions:
		create_input_action_row(action, input_container)

	# Add Reset Keybinds button at the bottom
	var reset_keybinds_btn = create_action_button("Reset Keybinds")
	reset_keybinds_btn.pressed.connect(_on_reset_keybinds_pressed)
	reset_keybinds_btn.custom_minimum_size = Vector2(200, 40)
	input_container.add_child(reset_keybinds_btn)

	# Add a spacer to push content up
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	input_container.add_child(spacer)

func create_input_action_row(action: String, parent: VBoxContainer):
	var action_container = HBoxContainer.new()
	action_container.custom_minimum_size = Vector2(0, 50)
	action_container.add_theme_constant_override("separation", 20)
	action_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(action_container)

	# Action label
	var action_label = Label.new()
	action_label.text = action.capitalize().replace("_", " ") + ":"
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if label_font:
		action_label.add_theme_font_override("font", label_font)
		action_label.add_theme_font_size_override("font_size", font_size)
	action_container.add_child(action_label)

	# Get all events for this action
	var events = InputMap.action_get_events(action)
	print("Action '", action, "' has ", events.size(), " events")

	# Create button for each event
	for event in events:
		var key_button = Button.new()
		key_button.custom_minimum_size = Vector2(input_button_width, 40)
		key_button.text = get_event_display_text(event)
		key_button.pressed.connect(_on_input_button_pressed.bind(action, event, key_button))
		key_button.focus_mode = Control.FOCUS_NONE

		# Apply styles
		if button_style:
			key_button.add_theme_stylebox_override("normal", button_style)
		if button_hover_style:
			key_button.add_theme_stylebox_override("hover", button_hover_style)
		if button_pressed_style:
			key_button.add_theme_stylebox_override("pressed", button_pressed_style)

		# Apply font
		if button_font:
			key_button.add_theme_font_override("font", button_font)
			key_button.add_theme_font_size_override("font_size", font_size)

		# Remove focus style
		var style_empty = StyleBoxEmpty.new()
		key_button.add_theme_stylebox_override("focus", style_empty)

		action_container.add_child(key_button)

	# If no events found, add a placeholder button
	if events.size() == 0:
		var key_button = Button.new()
		key_button.custom_minimum_size = Vector2(input_button_width, 40)
		key_button.text = "Click to bind"
		key_button.pressed.connect(_on_input_button_pressed.bind(action, null, key_button))
		key_button.focus_mode = Control.FOCUS_NONE

		# Apply styles
		if button_style:
			key_button.add_theme_stylebox_override("normal", button_style)
		if button_hover_style:
			key_button.add_theme_stylebox_override("hover", button_hover_style)
		if button_pressed_style:
			key_button.add_theme_stylebox_override("pressed", button_pressed_style)

		# Apply font
		if button_font:
			key_button.add_theme_font_override("font", button_font)
			key_button.add_theme_font_size_override("font_size", font_size)

		# Remove focus style
		var style_empty = StyleBoxEmpty.new()
		key_button.add_theme_stylebox_override("focus", style_empty)

		action_container.add_child(key_button)

func create_confirm_dialog():
	confirm_dialog = AcceptDialog.new()
	confirm_dialog.name = "ConfirmDialog"
	confirm_dialog.title = "Unsaved Changes"
	confirm_dialog.dialog_text = "You have unsaved changes. What would you like to do?"

	# In Godot 4, we need to use different methods to hide default buttons
	var ok_button = confirm_dialog.get_ok_button()
	ok_button.visible = false

	# Add custom buttons in the order: Apply, Discard, Cancel
	confirm_dialog.add_button("Apply", false, "apply")
	confirm_dialog.add_button("Discard", false, "discard")
	confirm_dialog.add_button("Cancel", true, "cancel")

	confirm_dialog.connect("custom_action", _on_confirm_dialog_custom_action)
	add_child(confirm_dialog)

func _on_confirm_dialog_custom_action(action: String):
	match action:
		"apply":
			apply_settings()
			hide_options()
		"discard":
			revert_to_original_settings()
			hide_options()
		"cancel":
			pass
	# Always hide the dialog after making a choice
	confirm_dialog.hide()

func revert_to_original_settings():
	# Revert all settings to their original values (from when menu was opened)

	# Gameplay
	var shake_toggle = find_child("ShakeToggle", true, false)
	if shake_toggle:
		shake_toggle.button_pressed = original_settings.get("screen_shake", true)

	# Add particle toggle revert
	var particle_toggle = find_child("ParticleToggle", true, false)
	if particle_toggle:
		particle_toggle.button_pressed = original_settings.get("particles_enabled", true)

	# Aim stick toggle
	var aim_toggle = find_child("AimStickToggle", true, false)
	if aim_toggle:
		aim_toggle.button_pressed = original_settings.get("use_left_joystick_aim", false)

	# Graphics - QUALITY
	var quality_slider = find_child("QualitySlider", true, false)
	if quality_slider:
		quality_slider.value = original_settings.get("quality", 2)

	# Fullscreen - only revert on desktop
	if not is_web_or_mobile:
		var fullscreen_toggle = find_child("FullscreenToggle", true, false)
		if fullscreen_toggle:
			var original_fullscreen = original_settings.get("fullscreen", false)
			fullscreen_toggle.button_pressed = original_fullscreen
			# APPLY IMMEDIATELY
			apply_fullscreen_now(original_fullscreen)

	var vsync_toggle = find_child("VSyncToggle", true, false)
	if vsync_toggle:
		vsync_toggle.button_pressed = original_settings.get("vsync", true)

	var msaa_option = find_child("MSAAOption", true, false)
	if msaa_option:
		msaa_option.select(original_settings.get("msaa", 0))

	var fps_option = find_child("FPSOption", true, false)
	if fps_option:
		fps_option.select(original_settings.get("fps_limit", 2))

	# Audio
	var master_slider = find_child("MasterSlider", true, false)
	if master_slider:
		master_slider.value = original_settings.get("master_volume", 100)

	var music_slider = find_child("MusicSlider", true, false)
	if music_slider:
		music_slider.value = original_settings.get("music_volume", 100)

	var sfx_slider = find_child("SFXSlider", true, false)
	if sfx_slider:
		sfx_slider.value = original_settings.get("sfx_volume", 100)

	# Apply reverted settings to the game
	apply_non_graphics_settings()

	# After reverting UI elements, revert the actual engine settings and config
	set_setting("gameplay", "screen_shake", original_settings.get("screen_shake", true))
	set_setting("gameplay", "particles_enabled", original_settings.get("particles_enabled", true))
	set_setting("gameplay", "use_left_joystick_aim", original_settings.get("use_left_joystick_aim", false))
	set_setting("graphics", "quality", original_settings.get("quality", 2))
	set_setting("graphics", "fullscreen", original_settings.get("fullscreen", false))
	set_setting("graphics", "vsync", original_settings.get("vsync", true))
	set_setting("graphics", "msaa", original_settings.get("msaa", 0))
	set_setting("graphics", "fps_limit", original_settings.get("fps_limit", 2))
	set_setting("audio", "master_volume", original_settings.get("master_volume", 100))
	set_setting("audio", "music_volume", original_settings.get("music_volume", 100))
	set_setting("audio", "sfx_volume", original_settings.get("sfx_volume", 100))

	settings_changed = false
	print("Reverted all settings to original")

@warning_ignore("unused_parameter")
func _on_input_button_pressed(action: String, event: InputEvent, button: Button):
	# If we're already rebinding, ignore new presses
	if is_rebinding:
		return

	# Start a new rebind
	rebinding_action = action
	rebinding_button = button
	new_event = null
	is_rebinding = true  # Set rebinding flag

	# Notify ControllerMouse autoload that we are rebinding (stop simulating clicks)
	ControllerMouse.set_rebinding(true)

	# Store the original button text in case we need to revert
	if not button.has_meta("original_text"):
		button.set_meta("original_text", button.text)

	# Change button text to indicate we're waiting for input
	rebinding_button.text = "Press any key..."

	# Start listening for input
	set_process_unhandled_input(true)

func _unhandled_input(event):
	if not is_rebinding:
		return

	# Don't allow the configured cancel key for rebinding
	if event is InputEventKey and event.keycode == rebind_cancel_key:
		_cancel_rebinding()
		get_viewport().set_input_as_handled()
		return

	# Allow Enter key to confirm (KEY_ENTER or KEY_KP_ENTER)
	if event is InputEventKey and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) and event.pressed and not event.is_echo():
		if new_event != null:
			_finalize_rebind()
		else:
			_cancel_rebinding()
		get_viewport().set_input_as_handled()
		return

	# --- FIXED: Validate event without accessing .pressed on JoypadMotion ---
	var valid_event = false
	if event is InputEventJoypadMotion:
		# Axis events (triggers/sticks) are always valid for rebinding
		valid_event = true
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.pressed and not (event is InputEventKey and event.is_echo()):
			valid_event = true

	if valid_event:
		# Special handling for mouse clicks on the rebinding button itself
		if event is InputEventMouseButton:
			var mouse_pos = get_viewport().get_mouse_position()
			var button_rect = rebinding_button.get_global_rect()
			if button_rect.has_point(mouse_pos):
				get_viewport().set_input_as_handled()
				return

		_handle_rebind_input(event)
		get_viewport().set_input_as_handled()

func _handle_rebind_input(event):
	var conflicting_action = find_conflicting_action(event, rebinding_action)
	if conflicting_action != "":
		rebinding_button.text = "Already bound to " + conflicting_action.capitalize().replace("_", " ")
		await get_tree().create_timer(1.5).timeout
		_cancel_rebinding()
		return

	new_event = event
	_finalize_rebind()

func _finalize_rebind():
	if new_event != null and rebinding_action != "" and rebinding_button != null:
		InputMap.action_erase_events(rebinding_action)
		InputMap.action_add_event(rebinding_action, new_event)

		rebinding_button.text = get_event_display_text(new_event)
		rebinding_button.set_meta("original_text", rebinding_button.text)

		save_input_map()
		print("Rebound ", rebinding_action, " to ", get_event_display_text(new_event))

	# Reset rebinding state
	rebinding_action = ""
	rebinding_button = null
	new_event = null
	is_rebinding = false
	ControllerMouse.set_rebinding(false)
	set_process_unhandled_input(false)

func _cancel_rebinding():
	if rebinding_button != null:
		if rebinding_button.has_meta("original_text"):
			rebinding_button.text = rebinding_button.get_meta("original_text")
		else:
			var events = InputMap.action_get_events(rebinding_action)
			if events.size() > 0:
				rebinding_button.text = get_event_display_text(events[0])
			else:
				rebinding_button.text = "Click to bind"

	rebinding_action = ""
	rebinding_button = null
	new_event = null
	is_rebinding = false
	ControllerMouse.set_rebinding(false)
	set_process_unhandled_input(false)

func find_conflicting_action(event: InputEvent, exclude_action: String) -> String:
	var actions = InputMap.get_actions()
	for action in actions:
		if action == exclude_action or action.begins_with("ui_"):
			continue
		var events = InputMap.action_get_events(action)
		for e in events:
			if _events_physically_match(e, event):
				return action
	return ""

func _events_physically_match(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.keycode == b.keycode
	elif a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	elif a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	elif a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and sign(a.axis_value) == sign(b.axis_value)
	return false

# Section switching
func _on_gameplay_pressed(): current_section = Section.GAMEPLAY; update_section_visibility()
func _on_graphics_pressed(): current_section = Section.GRAPHICS; update_section_visibility()
func _on_audio_pressed(): current_section = Section.AUDIO; update_section_visibility()
func _on_input_pressed(): current_section = Section.INPUT; update_section_visibility()

func update_section_visibility():
	for container in content_containers.values():
		container.visible = false
	match current_section:
		Section.GAMEPLAY: content_containers["gameplay"].visible = true
		Section.GRAPHICS: content_containers["graphics"].visible = true
		Section.AUDIO:   content_containers["audio"].visible   = true
		Section.INPUT:    content_containers["input"].visible    = true

# Gameplay options
func _on_shake_toggled(toggled: bool): set_setting("gameplay", "screen_shake", toggled); check_settings_changed()
func _on_particle_toggled(toggled: bool): set_setting("gameplay", "particles_enabled", toggled); check_settings_changed()
func _on_aim_stick_toggled(toggled: bool): set_setting("gameplay", "use_left_joystick_aim", toggled); check_settings_changed()

# Graphics options
func _on_quality_slider_changed(value: float):
	var index = int(value)
	if index >= 0 and index < quality_presets.size():
		set_setting("graphics", "quality", index); has_graphics_changes = true; check_settings_changed()

func _on_fullscreen_toggled(toggled: bool):
	if not is_web_or_mobile:
		apply_fullscreen_now(toggled); set_setting("graphics", "fullscreen", toggled); check_settings_changed()
	else: print("Fullscreen cannot be changed on web/mobile")

func apply_fullscreen_now(is_fullscreen: bool):
	var window = get_window()
	if is_fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		var monitor_size = DisplayServer.screen_get_size()
		var target_size = Vector2i(int(monitor_size.x * 0.75), int(monitor_size.y * 0.75))
		window.size = target_size
		@warning_ignore("integer_division")
		window.position = (monitor_size - target_size) / 2

func _on_vsync_toggled(toggled: bool):
	if toggled: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	set_setting("graphics", "vsync", toggled); check_settings_changed()

func _on_msaa_selected(index: int):
	var msaa_value = 0
	msaa_value = index
	@warning_ignore("int_as_enum_without_cast")
	get_viewport().msaa_3d = msaa_value
	set_setting("graphics", "msaa", index); check_settings_changed()

func _on_fps_limit_selected(index: int):
	var fps_limits = [0, 30, 60, 120, 144, 240]
	if index < fps_limits.size(): Engine.max_fps = fps_limits[index]
	set_setting("graphics", "fps_limit", index); check_settings_changed()

# Audio options
func _on_master_volume_changed(value: float): _set_bus_volume("Master", value)
func _on_music_volume_changed(value: float): _set_bus_volume("Music", value)
func _on_sfx_volume_changed(value: float): _set_bus_volume("SFX", value)

func _set_bus_volume(bus: String, value: float):
	var bus_idx = AudioServer.get_bus_index(bus)
	if bus_idx != -1: AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100))
	set_setting("audio", bus.to_lower() + "_volume", value); check_settings_changed()

func check_settings_changed():
	var current_settings = get_current_settings()
	settings_changed = false
	for key in original_settings:
		if current_settings.get(key) != original_settings.get(key):
			settings_changed = true; break

func get_current_settings() -> Dictionary:
	return {
		"screen_shake": get_setting("gameplay", "screen_shake", true),
		"particles_enabled": get_setting("gameplay", "particles_enabled", true),
		"use_left_joystick_aim": get_setting("gameplay", "use_left_joystick_aim", false),
		"quality": get_setting("graphics", "quality", 2),
		"fullscreen": get_setting("graphics", "fullscreen", false),
		"vsync": get_setting("graphics", "vsync", true),
		"msaa": get_setting("graphics", "msaa", 0),
		"fps_limit": get_setting("graphics", "fps_limit", 2),
		"master_volume": get_setting("audio", "master_volume", 100),
		"music_volume": get_setting("audio", "music_volume", 100),
		"sfx_volume": get_setting("audio", "sfx_volume", 100)
	}

# Bottom buttons
func _on_back_pressed():
	if settings_changed: show_confirm_dialog()
	else:
		if get_parent().name == "pause": options_hide()
		else: hide_options()

func _on_apply_pressed(): save_all_settings(); save_original_settings(); settings_changed = false

func _on_reset_quality_pressed():
	var quality_slider = find_child("QualitySlider", true, false)
	if quality_slider: quality_slider.value = 2
	set_setting("graphics", "quality", 2); has_graphics_changes = true; check_settings_changed()

func _on_reset_defaults_pressed():
	reset_settings_to_defaults()
	reset_input_bindings()
	if not is_web_or_mobile:
		var fullscreen_toggle = find_child("FullscreenToggle", true, false)
		if fullscreen_toggle:
			var should_be_fullscreen = get_setting("graphics", "fullscreen", false)
			fullscreen_toggle.button_pressed = should_be_fullscreen; apply_fullscreen_now(should_be_fullscreen)
	load_settings(); apply_non_graphics_settings(); save_all_settings(); save_original_settings()
	settings_changed = false; has_graphics_changes = true

func reset_settings_to_defaults():
	var default_settings = {
		"gameplay": {"screen_shake": true, "particles_enabled": true, "use_left_joystick_aim": false},
		"graphics": {"quality": 1, "fullscreen": true, "vsync": true, "msaa": 0, "fps_limit": 2},
		"audio": {"master_volume": 100, "music_volume": 50, "sfx_volume": 50}
	}
	for category in default_settings:
		for key in default_settings[category]:
			set_setting(category, key, default_settings[category][key])

func apply_non_graphics_settings():
	var vsync_enabled = get_setting("graphics", "vsync", true)
	if vsync_enabled: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if OS.get_name() != "Web":
		var msaa_index = get_setting("graphics", "msaa", 0)
		var msaa_vals = [0,1,2,3]
		@warning_ignore("int_as_enum_without_cast")
		get_viewport().msaa_3d = msaa_vals[msaa_index] if msaa_index < msaa_vals.size() else 0
	var fps_index = get_setting("graphics", "fps_limit", 2)
	var fps_limits = [0, 30, 60, 120, 144, 240]
	if fps_index < fps_limits.size(): Engine.max_fps = fps_limits[fps_index]
	for bus in ["Master","Music","SFX"]:
		var vol = get_setting("audio", bus.to_lower()+"_volume", 100)
		var bus_idx = AudioServer.get_bus_index(bus)
		if bus_idx != -1: AudioServer.set_bus_volume_db(bus_idx, linear_to_db(vol / 100))

func show_confirm_dialog(): confirm_dialog.popup_centered(Vector2i(500, 200))

func apply_settings(): save_all_settings(); save_original_settings(); settings_changed = false

func apply_pending_changes():
	if has_graphics_changes: apply_graphics_changes_now(); has_graphics_changes = false
	save_all_settings(); save_original_settings(); settings_changed = false

func apply_graphics_changes_now():
	var quality_slider = find_child("QualitySlider", true, false)
	
	if quality_slider:
		var quality_index = int(quality_slider.value)
		
		if quality_index >= 0 and quality_index < quality_presets.size():
			var preset = quality_presets[quality_index]
			var render_scale = preset["scale"]
			
			print("Applying quality: ", preset["name"], " (", render_scale, "x)")
			
			# FIXED: Use content_scale_factor on the root Window
			(get_tree().root as Window).content_scale_factor = render_scale
		
		set_setting("graphics", "quality", quality_index)
func hide_options(): disappear()
func show_options():
	appear()
	save_original_settings()
	settings_changed = false; has_graphics_changes = false

func save_original_settings(): original_settings = get_current_settings()

func load_settings():
	if OS.has_feature("web"): await get_tree().process_frame
	var shake_toggle = find_child("ShakeToggle", true, false)
	if shake_toggle: shake_toggle.button_pressed = get_setting("gameplay", "screen_shake", true)
	var particle_toggle = find_child("ParticleToggle", true, false)
	if particle_toggle: particle_toggle.button_pressed = get_setting("gameplay", "particles_enabled", true)
	var aim_toggle = find_child("AimStickToggle", true, false)
	if aim_toggle: aim_toggle.button_pressed = get_setting("gameplay", "use_left_joystick_aim", false)
	var quality_slider = find_child("QualitySlider", true, false)
	if quality_slider: quality_slider.value = get_setting("graphics", "quality", 2)
	if not is_web_or_mobile:
		var fullscreen_toggle = find_child("FullscreenToggle", true, false)
		if fullscreen_toggle:
			var saved_fullscreen = get_setting("graphics", "fullscreen", false)
			fullscreen_toggle.button_pressed = saved_fullscreen; apply_fullscreen_now(saved_fullscreen)
	else: force_fullscreen_web_mobile()
	var vsync_toggle = find_child("VSyncToggle", true, false)
	if vsync_toggle: vsync_toggle.button_pressed = get_setting("graphics", "vsync", true)
	var msaa_option = find_child("MSAAOption", true, false)
	if msaa_option: msaa_option.select(get_setting("graphics", "msaa", 0))
	var fps_option = find_child("FPSOption", true, false)
	if fps_option: fps_option.select(get_setting("graphics", "fps_limit", 2))
	for bus in ["Master","Music","SFX"]:
		var slider = find_child(bus+"Slider", true, false)
		if slider: slider.value = get_setting("audio", bus.to_lower()+"_volume", 100)
	apply_non_graphics_settings()
	load_input_map()

func set_setting(category: String, key: String, value):
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") != OK: print("Creating new settings file")
	config.set_value(category, key, value)
	config.save("user://settings.cfg")

func get_setting(category: String, key: String, default):
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") != OK: return default
	return config.get_value(category, key, default)

static func get_setting_global(category: String, key: String, default):
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") != OK: return default
	return config.get_value(category, key, default)

func save_all_settings():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK: config.save("user://settings.cfg")
	save_input_map()

func reset_input_bindings(): restore_default_input_map(); reload_input_section()

func reload_input_section():
	var input_container = content_containers.get("input")
	if input_container:
		var parent = input_container.get_parent(); parent.remove_child(input_container); input_container.queue_free()
	var content_container = find_child("ContentContainer", true, false)
	if content_container: create_input_section(content_container); update_section_visibility()

func _on_reset_keybinds_pressed(): reset_input_bindings()

func _serialize_input_event_for_saving(event: InputEvent) -> Dictionary:
	var event_dict = {}
	if event is InputEventKey:
		event_dict = {"type": "key", "keycode": event.keycode, "physical_keycode": event.physical_keycode, "shift_pressed": event.shift_pressed, "ctrl_pressed": event.ctrl_pressed, "alt_pressed": event.alt_pressed, "meta_pressed": event.meta_pressed}
	elif event is InputEventMouseButton:
		event_dict = {"type": "mouse", "button_index": event.button_index, "double_click": event.double_click, "factor": event.factor}
	elif event is InputEventJoypadButton:
		event_dict = {"type": "joypad_button", "button_index": event.button_index, "pressure": event.pressure}
	elif event is InputEventJoypadMotion:
		event_dict = {"type": "joypad_motion", "axis": event.axis, "axis_value": event.axis_value}
	return event_dict

func _deserialize_input_event_for_loading(event_dict: Dictionary) -> InputEvent:
	var event
	match event_dict.get("type"):
		"key":
			event = InputEventKey.new()
			event.keycode = event_dict.get("keycode", 0); event.physical_keycode = event_dict.get("physical_keycode", 0)
			event.shift_pressed = event_dict.get("shift_pressed", false); event.ctrl_pressed = event_dict.get("ctrl_pressed", false)
			event.alt_pressed = event_dict.get("alt_pressed", false); event.meta_pressed = event_dict.get("meta_pressed", false)
		"mouse":
			event = InputEventMouseButton.new()
			event.button_index = event_dict.get("button_index", 0); event.double_click = event_dict.get("double_click", false); event.factor = event_dict.get("factor", 1.0)
		"joypad_button":
			event = InputEventJoypadButton.new()
			event.button_index = event_dict.get("button_index", 0); event.pressure = event_dict.get("pressure", 1.0)
		"joypad_motion":
			event = InputEventJoypadMotion.new()
			event.axis = event_dict.get("axis", 0); event.axis_value = event_dict.get("axis_value", 0.0)
		_: return null
	return event
