extends Node2D

@export var offset_view_tiles = 2 # base tile viewing , if set to 2 , camera will be 2 tiles ahead always.
@onready var target_pos = $"..".global_position + Vector2(offset_view_tiles*160,0)
var current_pos
@export var speed = 1 # speed of camera
func _ready():
	current_pos = get_parent().global_position
func _process(delta):
	target_pos = $"..".global_position + Vector2(offset_view_tiles*160*$"..".facing_direction,0) 
	global_position += ((target_pos - global_position)/speed)*delta
	
