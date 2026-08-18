extends Sprite2D

var time = 0.0
var scale_duration = 2
var min_scale = 0.6
var max_scale = 0.7
var rotation_speed = 1.1
var rotation_amplitude = 0.1
var target_scale
var side_scroll_speed = 200
func _ready():
	await get_tree().create_timer(0.5).timeout
	$"../../main_menu_sound".play()
func _process(delta):
	time += delta
	$"..".position += Vector2(side_scroll_speed,0) * delta
	# Handle scale (independent of sine)
	var scale_progress = fmod(time, scale_duration) / scale_duration
	var current_scale = max_scale - (scale_progress * (max_scale - min_scale))
	target_scale = Vector2(current_scale, current_scale)
	scale += (target_scale - scale)/1.8
	# Handle rotation (with sine wave)
	rotation = (sin(time * rotation_speed) * rotation_amplitude)+0.05
