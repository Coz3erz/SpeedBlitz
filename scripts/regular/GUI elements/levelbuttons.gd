extends Panel
@warning_ignore("unused_signal")
signal level_selected(level_number)
signal back_pressed

# ---------- Core Configuration ----------
@export var total_levels: int = 35
@export var columns: int = 10
@export var rows_per_page: int = 3
@export var button_min_size: Vector2 = Vector2(100, 100)

# ---------- Level Button Styling ----------
@export var level_button_stylebox: StyleBox
@export var level_button_font: Font
@export var level_button_font_size: int = 16
@export var level_outline_color: Color = Color.WHITE
@export var level_outline_width: int = 0

# ---------- Locked Button Appearance ----------
@export var lock_icon: Texture2D
@export var lock_icon_size: Vector2 = Vector2(32, 32)  # hint for icon scaling

# ---------- Navigation Button Styling ----------
@export var nav_button_stylebox: StyleBox
@export var nav_button_font: Font
@export var nav_button_font_size: int = 20
@export var nav_button_min_size: Vector2 = Vector2(120, 50)
@export var nav_outline_color: Color = Color.WHITE
@export var nav_outline_width: int = 0

# Navigation layout
@export var nav_separation: int = 20                # space between prev, label, next
@export var nav_offset: Vector2 = Vector2.ZERO     # move the whole navigation group by (x, y)

# ---------- Button Sounds ----------
@export var back_button_sound: AudioStream
@export var nav_button_sound: AudioStream
@export var level_button_sound: AudioStream

@export var back_button_text: String = "Back"

# ---------- Internal ----------
var pages: Array[GridContainer] = []
var current_page: int = 0
var sound_player: AudioStreamPlayer

var main_vbox: VBoxContainer
var top_bar: HBoxContainer
var back_btn: Button
var page_nav: HBoxContainer
var prev_btn: Button
var next_btn: Button
var page_label: Label
var pages_vbox: VBoxContainer

var level_save: LevelSave   # reference to autoload

# ------------------------------------------------------------------
func _ready():
	level_save = LevelSave
	generate_ui()

func generate_ui():
	for child in get_children():
		child.queue_free()
	pages.clear()

	sound_player = AudioStreamPlayer.new()
	sound_player.name = "SoundPlayer"
	add_child(sound_player)

	main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.anchors_preset = Control.PRESET_FULL_RECT
	add_child(main_vbox)

	# --- Top bar ---
	top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	main_vbox.add_child(top_bar)

	# Back button (left)
	back_btn = Button.new()
	back_btn.text = back_button_text
	back_btn.custom_minimum_size = nav_button_min_size
	back_btn.connect("pressed", Callable(self, "_on_back_pressed"))
	_apply_nav_button_style(back_btn)
	top_bar.add_child(back_btn)

	# Expander to push navigation to center
	var left_expander = Control.new()
	left_expander.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(left_expander)

	# Navigation group container (allows offset)
	var nav_container = Control.new()
	nav_container.name = "NavContainer"
	nav_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_container.mouse_filter = Control.MOUSE_FILTER_PASS
	top_bar.add_child(nav_container)

	# Navigation HBox (centered inside nav_container)
	page_nav = HBoxContainer.new()
	page_nav.name = "PageNav"
	page_nav.anchors_preset = Control.PRESET_CENTER
	page_nav.add_theme_constant_override("separation", nav_separation)
	nav_container.add_child(page_nav)

	prev_btn = Button.new()
	prev_btn.text = "Previous"
	prev_btn.custom_minimum_size = nav_button_min_size
	prev_btn.connect("pressed", Callable(self, "_on_prev_pressed"))
	_apply_nav_button_style(prev_btn)
	page_nav.add_child(prev_btn)

	page_label = Label.new()
	page_label.name = "PageLabel"
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	page_label.custom_minimum_size = Vector2(100, nav_button_min_size.y)
	if nav_button_font:
		page_label.add_theme_font_override("font", nav_button_font)
	if nav_button_font_size > 0:
		page_label.add_theme_font_size_override("font_size", nav_button_font_size)
	page_nav.add_child(page_label)

	next_btn = Button.new()
	next_btn.text = "Next"
	next_btn.custom_minimum_size = nav_button_min_size
	next_btn.connect("pressed", Callable(self, "_on_next_pressed"))
	_apply_nav_button_style(next_btn)
	page_nav.add_child(next_btn)

	# Apply offset to the navigation group (relative to its centered position)
	page_nav.offset_left = nav_offset.x
	page_nav.offset_top = nav_offset.y
	page_nav.offset_right = nav_offset.x
	page_nav.offset_bottom = nav_offset.y

	# Right expander (keeps centering balanced)
	var right_expander = Control.new()
	right_expander.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(right_expander)

	# --- Pages container ---
	pages_vbox = VBoxContainer.new()
	pages_vbox.name = "PagesVBox"
	pages_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(pages_vbox)

	# Create pages
	var buttons_per_page = columns * rows_per_page
	var num_pages = ceil(total_levels / float(buttons_per_page))

	for page_idx in range(num_pages):
		var grid = GridContainer.new()
		grid.name = "GridPage%d" % page_idx
		grid.columns = columns
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		pages_vbox.add_child(grid)
		pages.append(grid)

		var start = page_idx * buttons_per_page
		var end = min(start + buttons_per_page, total_levels)
		for i in range(start, end):
			var level_num = i + 1
			var btn = Button.new()
			_configure_level_button(btn, level_num)
			grid.add_child(btn)

	show_page(0)

func _configure_level_button(btn: Button, level_num: int):
	btn.set_meta("level_number", level_num)
	var unlocked = level_save.is_level_unlocked(level_num)

	var final_style = _apply_outline(level_button_stylebox, level_outline_color, level_outline_width)
	btn.add_theme_stylebox_override("normal", final_style)
	btn.add_theme_stylebox_override("hover", final_style)
	btn.add_theme_stylebox_override("pressed", final_style)
	btn.add_theme_stylebox_override("disabled", final_style)

	if level_button_font:
		btn.add_theme_font_override("font", level_button_font)
	if level_button_font_size > 0:
		btn.add_theme_font_size_override("font_size", level_button_font_size)

	if button_min_size != Vector2.ZERO:
		btn.custom_minimum_size = button_min_size

	if unlocked:
		btn.text = str(level_num)
		btn.icon = null
		btn.disabled = false
	else:
		btn.text = ""
		if lock_icon:
			btn.icon = lock_icon
			btn.expand_icon = true
		btn.disabled = true

	btn.connect("pressed", Callable(self, "_on_level_button_pressed").bind(level_num))

func _apply_outline(stylebox: StyleBox, outline_color: Color, outline_width: int) -> StyleBox:
	if outline_width <= 0:
		return stylebox
	if stylebox is StyleBoxFlat:
		var flat = stylebox.duplicate() as StyleBoxFlat
		flat.border_width_left = outline_width
		flat.border_width_top = outline_width
		flat.border_width_right = outline_width
		flat.border_width_bottom = outline_width
		flat.border_color = outline_color
		return flat
	return stylebox

func _apply_nav_button_style(btn: Button):
	var final_style = _apply_outline(nav_button_stylebox, nav_outline_color, nav_outline_width)
	btn.add_theme_stylebox_override("normal", final_style)
	btn.add_theme_stylebox_override("hover", final_style)
	btn.add_theme_stylebox_override("pressed", final_style)
	btn.add_theme_stylebox_override("disabled", final_style)

	if nav_button_font:
		btn.add_theme_font_override("font", nav_button_font)
	if nav_button_font_size > 0:
		btn.add_theme_font_size_override("font_size", nav_button_font_size)

# ------------------------------------------------------------------
func show_page(page_index: int):
	if page_index < 0 or page_index >= pages.size():
		return
	current_page = page_index
	for i in range(pages.size()):
		pages[i].visible = (i == page_index)

	page_label.text = "Page %d/%d" % [current_page+1, pages.size()]
	prev_btn.disabled = (current_page == 0)
	next_btn.disabled = (current_page == pages.size() - 1)

func _on_prev_pressed():
	_play_sound(nav_button_sound)
	show_page(current_page - 1)

func _on_next_pressed():
	_play_sound(nav_button_sound)
	show_page(current_page + 1)

func _on_back_pressed():
	_play_sound(back_button_sound)
	emit_signal("back_pressed")

func _on_level_button_pressed(level_num: int):
	if LevelSave.is_level_unlocked(level_num):
		_play_sound(level_button_sound)
		SceneManager.change_scene(get_node("/root"),"res://scenes/levels/level" + str(level_num) + ".tscn")
func _play_sound(stream: AudioStream):
	if stream and sound_player:
		sound_player.stream = stream
		sound_player.play()

# Refresh all buttons after unlocking new levels (call this if the selector is still visible)
func refresh_lock_states():
	for grid in pages:
		for child in grid.get_children():
			if child is Button:
				var level_num = child.get_meta("level_number", 0)
				if level_num > 0:
					var unlocked = level_save.is_level_unlocked(level_num)
					if unlocked:
						child.text = str(level_num)
						child.icon = null
						child.disabled = false
					else:
						child.text = ""
						if lock_icon:
							child.icon = lock_icon
							child.expand_icon = true
						child.disabled = true

# ------------------------------------------------------------------
# Fading with input disabled
# ------------------------------------------------------------------
func appear(duration: float = 0.2):
	# Store original input settings
	var original_mouse_filter = mouse_filter
	var original_focus_mode = focus_mode
	
	# Block input during fade
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE
	get_viewport().gui_release_focus()
	
	show()
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1,1,1,1), duration).from(Color(1,1,1,0))
	await tween.finished
	
	# Restore input settings
	mouse_filter = original_mouse_filter
	focus_mode = original_focus_mode

func disappear(duration: float = 0.2):
	# Store original input settings
	var original_mouse_filter = mouse_filter
	var original_focus_mode = focus_mode
	
	# Block input during fade
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE
	get_viewport().gui_release_focus()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1,1,1,0), duration)
	await tween.finished
	hide()
	
	# Restore input settings
	mouse_filter = original_mouse_filter
	focus_mode = original_focus_mode
