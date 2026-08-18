extends Camera2D

const scroll_speed = 300
var transition = false
func _ready():
	position.y = -1500
	
func _process(_delta):
	if transition:
		return
	AudioServer.playback_speed_scale = 1
	$particles.speed_scale = 0.37
	var scr = scroll_speed
	if Input.is_action_pressed("shift"):
		scr *= 8
		AudioServer.playback_speed_scale = 1.8
		$particles.speed_scale = 0.67
	position.y += scr*_delta

func _on_visible_on_screen_notifier_2d_screen_exited():
	if !transition:
		transition = true
		AudioServer.playback_speed_scale = 1
		SceneManager.change_scene(get_node("/root"),"res://scenes/main scenes/main_menu.tscn")
		AudioServer.playback_speed_scale = 1
