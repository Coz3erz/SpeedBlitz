extends Sprite2D

@export var direction_flip = true # if true , it will turn player upside down upon touching. 
@export var exit_when_jump = false # if true , player will exit upside down upon jumping
@export var tile_combination_size = Vector2(5,5)  # sets the static bodys collision shape , which is vector2 * tile_size
@export var launch_size = Vector2(5,0.5) # size of launch area collision , same logic as static body
@export var launch_mult_tile_pos_change = Vector2(0,-1.5)  # much more complicated , look at code
@export var color : Color = Color.WHITE # color
@export var collision_disabled = false # boolean
var blitz # internal variable
func _ready():
	modulate = color
	$StaticBody2D/CollisionShape2D.scale = Vector2(16,16)*tile_combination_size
	$jumppad_stick/CollisionShape2D.scale = Vector2(8,8)*launch_size
	$jumppad_stick/CollisionShape2D.position = Vector2(160,160) * launch_mult_tile_pos_change
	$StaticBody2D/CollisionShape2D.disabled = collision_disabled
	if collision_disabled:
		modulate.a /= 2

func _on_area_2d_area_entered(area):
	if area.name != "jumppad_stick":
		if area.name == "entity_hitbox" and area.get_parent().name == "blitz":
			blitz = area.get_parent()
			area.get_parent().is_wall_sliding = false
			if area.get_parent().current_state == "GROUND_SLAMMING":
				area.get_parent().stop_ground_slam()
			if direction_flip:
				blitz.enter_upside_down(exit_when_jump)
			if !direction_flip:
				blitz.exit_upside_down()
