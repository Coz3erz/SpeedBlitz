extends Node

var max_unlocked: int = 1
const SAVE_PATH = "user://level_data.cfg"

func _ready():
	load_save()

func load_save():
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		max_unlocked = config.get_value("progress", "max_unlocked", 1)
	else:
		max_unlocked = 1
		save_save()

func save_save():
	var config = ConfigFile.new()
	config.set_value("progress", "max_unlocked", max_unlocked)
	config.save(SAVE_PATH)

func unlock_level(level: int):
	if level > max_unlocked:
		max_unlocked = level
		save_save()

func unlock_next_level():
	unlock_level(max_unlocked + 1)

func is_level_unlocked(level: int) -> bool:
	return level <= max_unlocked

func get_current_max() -> int:
	return max_unlocked

func reset_save():
	max_unlocked = 1
	save_save()
