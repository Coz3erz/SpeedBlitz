extends Node2D

@export var background_music_stream_player : AudioStreamPlayer
func _ready():
	if background_music_stream_player:
		background_music_stream_player.play()
