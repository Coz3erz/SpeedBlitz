class_name scene_manager extends CanvasLayer

var transition = false
@onready var animation : AnimationPlayer = $AnimationPlayer
var last_scene_name : String

func _ready():
	visible = false
	set_process_priority(100)
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	set_process_input(true)
	layer = 1000
	visible = true
	animation.play("fade_out")
	await animation.animation_finished
	
	# Keep input disabled a bit longer
	await get_tree().create_timer(0.05).timeout
	get_viewport().gui_disable_input = false
	
	layer = -3
	visible = false
	transition = false
@warning_ignore("unused_parameter")
func _input(event):
	# Block all input during transition
	if transition:
		get_viewport().set_input_as_handled()

func change_scene(from, to_scene_name: String) -> void:
	# Set transition true FIRST
	transition = true
	
	# Immediately disable all input on viewport
	get_viewport().gui_disable_input = true
	
	# Clear any buffered ESC key presses
	Input.flush_buffered_events()
	
	# Now show and animate
	visible = true
	last_scene_name = from.name
	layer = 100
	
	animation.play("fade_in")
	await animation.animation_finished
	
	from.get_tree().call_deferred("change_scene_to_file", to_scene_name)
	get_tree().paused = false
	
	animation.play("fade_out")
	await animation.animation_finished
	
	# Keep input disabled a bit longer
	await get_tree().create_timer(0.05).timeout
	get_viewport().gui_disable_input = false
	
	layer = -3
	visible = false
	transition = false
func restart_level() -> void:
	# Set transition true FIRST
	transition = true
	
	# Immediately disable all input on viewport
	get_viewport().gui_disable_input = true
	
	# Clear any buffered ESC key presses
	Input.flush_buffered_events()
	
	# Get current scene from scene manager's tree
	var current_scene = get_tree().current_scene
	last_scene_name = current_scene.name
	
	# Now show and animate
	visible = true
	layer = 100
	
	# Fade in (to black)
	animation.play("fade_in")
	await animation.animation_finished
	
	# Reload the current scene using the scene manager's tree
	get_tree().call_deferred("reload_current_scene")
	get_tree().paused = false
	
	# Fade out (from black to new scene)
	animation.play("fade_out")
	await animation.animation_finished
	
	# Keep input disabled a bit longer
	await get_tree().create_timer(0.05).timeout
	get_viewport().gui_disable_input = false
	
	layer = -3
	visible = false
	transition = false
