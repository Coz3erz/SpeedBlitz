extends Node2D

@export var object_powerup_tag = "base_object"
@export var object_instantiate = preload("res://scenes/collectibles/collectible_object_general.tscn")
@export var max_frames = 3 # max frames for anim
@onready var sprite = $object_sprite # internal variable
@export var frame_increment = 0.4 # increments frame by this variable until , if 0.4 , it will add 0.4 , 0.8 , 1.2 , since its now over 1 , then it adds 1 to frame.
var frame_increment_track = 0
var item_given = false
func _ready():
	sprite.frame = 0

func _process(delta):
	frame_increment_track += frame_increment * delta
	if frame_increment_track > 1:
			frame_increment_track = 0
			if sprite.frame == max_frames:
				sprite.frame = 0
			else:
				sprite.frame += 1
func _on_object_hitbox_area_entered(area):
	if area.name == "entity_hitbox" and area.get_parent().name == "blitz" and item_given == false:
		instantiate_scene(object_instantiate,Vector2.ZERO).linear_velocity = Vector2(200*1 if randi() % 2 == 0 else -1,-500)
		item_given = true
func instantiate_scene(scene: PackedScene , _position: Vector2 = Vector2.ZERO) -> Node:
	if not scene:
		push_warning("No scene provided to instantiate")
		return null
	
	var instance = scene.instantiate()
	
	# Use deferred for adding and setting position
	instance.position = _position
	call_deferred("add_child", instance)
	return instance
