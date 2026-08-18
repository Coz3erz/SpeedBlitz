extends Node

@export var anim_playing = false
@export var sprite_txt : Texture2D
@export var offset_ = Vector2.ZERO
@export var fliph_ = false
@export var flipv_ = false
@export var vframes_ = 1
@export var hframes = 1
@export var frame_ = 1 
@export var current_anim : StringName = "placeholder"
@export var speed_scale = 1
@export var anim_unit : AnimationMixer
@export var sprite_unit : Sprite2D
func ready():
	change_sprite(sprite_txt,offset_,fliph_,flipv_,hframes,vframes_,frame_)
	set_anim_pauseplay(anim_playing)
	play_animation(current_anim,speed_scale)
	
func play_animation(animation,speed):
	anim_unit.play(animation)
	anim_unit.speed_scale = speed

@warning_ignore("shadowed_variable")
func change_sprite(sprite,offset,fliph,flipv,hframes,vframes,frame):
	sprite_unit.texture = load(sprite)
	sprite_unit.offset = offset
	sprite_unit.flip_h = fliph
	sprite_unit.flip_v = flipv
	sprite_unit.hframes = hframes
	sprite_unit.vframes = vframes
	sprite_unit.frame = frame

func set_anim_pauseplay(val):
	anim_playing = val
	if anim_playing:
		anim_unit.play()
	else:
		anim_unit.pause()
func set_properties():
	change_sprite(sprite_txt,offset_,fliph_,flipv_,hframes,vframes_,frame_)
	set_anim_pauseplay(anim_playing)
	play_animation(current_anim,speed_scale)
	
