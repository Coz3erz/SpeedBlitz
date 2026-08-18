extends Area2D

@export var sprite_texture : Texture # texture of object
@export var h_frames = 1 # h frames for anim
@export var v_frames = 1 # v frames for anim
@export var max_frames = 5 # max frames for anim
@export var object_tag = "base_object" # used to differentiate different objects from each other
@export var object_properties_array = [] # for properties of specific objects , for example index 0 for an object with the tag "MONEY" will always correspond to how much cash it gives , and you can encode it for any objects however you want.
@onready var sprite = $item_sprite # internal variable
var sine_wave_increment = 0 # internal variable
@export var float_speed = 5 #speed of floating with sine wave
@export var float_range = 5 # range of floating with sine wave
@export var frame_increment = 0.4 # increments frame by this variable until , if 0.4 , it will add 0.4 , 0.8 , 1.2 , since its now over 1 , then it adds 1 to frame.
@export var gravity_enabled = true
@export var fade_in_speed = 1
var can_be_picked_up = false
var pickup = false
var frame_increment_track = 0 # internal
func _ready():
	sprite.texture = sprite_texture
	sprite.hframes = h_frames
	sprite.vframes = v_frames
	sprite.frame = 0
	modulate.a = 0
	await get_tree().create_timer(0.7).timeout
	can_be_picked_up = true
func _process(delta):
	if pickup:
		position.y -= 200*delta
		$"../CollisionShape2D".disabled = true
		$"..".gravity_scale = 0
		modulate.a -= 1*delta
		if modulate.a <= 0:
			get_parent().queue_free()
	else: if !pickup and modulate.a != 1:
		modulate.a += fade_in_speed*delta
	sine_wave_increment += delta * float_speed
	position.y += sin(sine_wave_increment) * delta * float_range
	frame_increment_track += frame_increment * delta
	if frame_increment_track > 1:
			frame_increment_track = 0
			if sprite.frame == max_frames:
				sprite.frame = 0
			else:
				sprite.frame += 1

func _on_area_entered(area):
	if area.name=="entity_hitbox" and area.get_parent().name=="blitz" and pickup == false and can_be_picked_up:
		area.get_parent().item_pickup(self)
		pickup = true
