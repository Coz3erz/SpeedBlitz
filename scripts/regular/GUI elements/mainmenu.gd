extends Node2D

@onready var main_gui = [$cam, $options, $play, $quit, $play_story]
@onready var extra_gui = [$extras/arcade, $extras/levels, $extras/credits, $extras/back]
@onready var options = $"../OptionsMenu"

# Dictionary to store running tweens per node (so we can stop them if a new fade starts)
var _node_tweens = {}

func set_logo_visible(_visible):
	# We'll handle fading separately, so this direct set is replaced by fade calls.
	# Keep this function for compatibility but internally use fade.
	fade_node($Logo, _visible)

func _ready():
	$Panel.connect("back_pressed",levels_back_pressed)
	# Fade in main GUI and logo on start
	fade_group(main_gui, true, 0.2)
	fade_node($Logo, true, 0.2)
	# Panel starts hidden (disappear already fades out)
	$Panel.disappear()
	options.options_closed.connect(__on_options_closed)
	if OS.get_name() == "Web":
		$quit.visible = false
		main_gui.erase($quit)

# ------------------------------------------------------------------
# Core fading functions
# ------------------------------------------------------------------
# Fade a single node (Control or Node2D) to target visibility.
func fade_node(node: Node, visible_target: bool, duration: float = 0.2):
	if not node:
		return
	
	# Stop any existing tween on this node
	if _node_tweens.has(node):
		_node_tweens[node].kill()
		_node_tweens.erase(node)
	
	# Determine start state
	var start_alpha = node.modulate.a
	var target_alpha = 1.0 if visible_target else 0.0
	
	# If we're already at target, just set visibility and return
	if (visible_target and node.visible and abs(start_alpha - target_alpha) < 0.01) or \
	   (not visible_target and not node.visible and abs(start_alpha - target_alpha) < 0.01):
		return
	
	# Prepare node for fading
	if visible_target and not node.visible:
		node.modulate.a = 0.0
		node.show()
	
	# Disable input during fade for Control nodes
	var was_input_enabled = true
	if node is Control:
		was_input_enabled = node.mouse_filter != Control.MOUSE_FILTER_IGNORE
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create tween
	var tween = create_tween()
	tween.set_parallel(false)
	_node_tweens[node] = tween
	
	# Animate alpha
	tween.tween_property(node, "modulate:a", target_alpha, duration)
	
	# On completion: re-enable input, hide if needed, and remove from tracking
	tween.tween_callback(func():
		if node is Control:
			node.mouse_filter = Control.MOUSE_FILTER_STOP if was_input_enabled else Control.MOUSE_FILTER_IGNORE
		if not visible_target:
			node.hide()
		_node_tweens.erase(node)
	)

# Fade a group of nodes (array) to the same target visibility.
func fade_group(group: Array, visible_target: bool, duration: float = 0.2):
	for node in group:
		fade_node(node, visible_target, duration)

# ------------------------------------------------------------------
# Legacy visibility functions replaced by fading
# ------------------------------------------------------------------
func _set_main_gui_visible(visible_: bool):
	fade_group(main_gui, visible_, 0.2)

func _set_extra_gui_visible(visible_: bool):
	fade_group(extra_gui, visible_, 0.2)

# ------------------------------------------------------------------
# Button handlers
# ------------------------------------------------------------------
func _on_play_pressed():
	fade_group(main_gui, false, 0.2)   # fade out main menu
	fade_node($Logo, true, 0.2)        # keep logo visible (or fade if you prefer)
	fade_group(extra_gui, true, 0.2)   # fade in extras

func _on_options_pressed():
	fade_group(main_gui, false, 0.2)
	fade_node($Logo, false, 0.2)
	options.appear()   # Options appears immediately (could also be faded if needed)

func __on_options_closed():
	fade_group(main_gui, true, 0.2)
	fade_node($Logo, true, 0.2)

func _on_quit_pressed():
	get_tree().quit()

func _on_play_story_pressed():
	SceneManager.change_scene(get_node("/root"),"res://scenes/levels/level" + str(LevelSave.get_current_max()) + ".tscn")

func _on_back_pressed():
	fade_group(extra_gui, false, 0.2)
	fade_group(main_gui, true, 0.2)
	fade_node($Logo, true, 0.2)

func _on_arcade_pressed():
	SceneManager.change_scene(get_node("/root"), "res://scenes/main scenes/industrial.tscn")

func _on_credits_pressed():
	SceneManager.change_scene(get_node("/root"), "res://scenes/main scenes/credits.tscn")

func _on_levels_pressed():
	fade_group(extra_gui, false, 0.2)
	fade_group(main_gui, false, 0.2)
	fade_node($Logo, false, 0.2)
	$Panel.appear()   # Panel has its own fade (0.5s by default – you can adjust inside Panel script)

# Called when back is pressed from the level panel
func appear():
	$Panel.disappear()               # Panel fades out
	fade_node($Logo, true, 0.2)      # logo fades in
	fade_group(extra_gui, true, 0.2) # extra GUI fades in

func levels_back_pressed():
	$Panel.disappear()
	fade_group(extra_gui, true, 0.2)
	fade_group(main_gui, false, 0.2)
	fade_node($Logo, true, 0.2)
