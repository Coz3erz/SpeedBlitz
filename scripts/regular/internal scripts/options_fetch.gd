extends Node

@onready var options = preload("res://scripts/regular/GUI elements/options.gd")

func fetch_setting(section,setting,fallback):
	return options.get_setting_global(section, setting, fallback)
