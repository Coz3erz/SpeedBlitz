extends Sprite2D

var tile_size = 160
@export var direction_launch = Vector2(0,-1) # direction of launch
@export var launch_power = 9000 # launch power
@export var tile_combination_size = Vector2(5,5) # sets the static bodys collision shape , which is vector2 * tile_size
@export var launch_size = Vector2(5,0.5) # size of launch area collision , same logic as static body
@export var launch_mult_tile_pos_change = Vector2(0,-1.5) # much more complicated , look at code
@export var color : Color = Color.WHITE # color
@export var collision_disabled = false # boolean
@export var keep_y_at_zero = false # boolean
var blitz
func _ready():
	modulate = color
	$StaticBody2D/CollisionShape2D.scale = Vector2(16,16)*tile_combination_size
	$jumppad/CollisionShape2D.scale = Vector2(8,8)*launch_size
	$jumppad/CollisionShape2D.position = Vector2(tile_size,tile_size) * launch_mult_tile_pos_change
	$StaticBody2D/CollisionShape2D.disabled = collision_disabled
	if collision_disabled:
		modulate.a /= 2
	
func _on_area_2d_area_entered(area):
	if area.name != "jumppad":
		if area.name == "entity_hitbox" and area.get_parent().name == "blitz":
			var apply_speed_x = true
			var apply_speed_y = true
			blitz = area.get_parent()
			blitz.has_double_jump = true
			blitz.is_wall_sliding = false
			if collision_disabled:
				if sign(direction_launch.x) == 1 and blitz.velocity.x > direction_launch.x * launch_power:
					apply_speed_x = false
				if sign(direction_launch.x) == -1 and blitz.velocity.x < direction_launch.x * launch_power:
					apply_speed_x = false
				if sign(direction_launch.y) == 1 and blitz.velocity.y > direction_launch.y * launch_power:
					apply_speed_y = false
				if sign(direction_launch.y) == -1 and blitz.velocity.y < direction_launch.y * launch_power:
					apply_speed_y = false
			if blitz.current_state == "GROUND_SLAMMING" and apply_speed_y:
				blitz.stop_ground_slam()
			if direction_launch.x != 0 and apply_speed_x:
				blitz.velocity.x = direction_launch.x * launch_power
			if direction_launch.y != 0 and apply_speed_y:
				blitz.velocity.y = direction_launch.y * launch_power
			if keep_y_at_zero and apply_speed_x:
				blitz.keep_y_at_zero(0.15)
				if blitz.current_state == "GROUND_SLAMMING":
					blitz.stop_ground_slam()
			if !keep_y_at_zero and blitz.keep_y_at_zero_:
				blitz.keep_y_at_zero_ = false
		elif area.name == "entity_hitbox":
			if direction_launch.x != 0:
				area.get_parent().velocity.x = direction_launch.x * launch_power
			if direction_launch.y != 0:
				area.get_parent().velocity.y = direction_launch.y * launch_power
			if keep_y_at_zero:
				area.get_parent().keep_y_at_zero(0.3)
			if !keep_y_at_zero and area.get_parent().keep_y_at_zero_:
				area.get_parent().keep_y_at_zero_ = false
