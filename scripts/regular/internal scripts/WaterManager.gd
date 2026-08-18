extends Node

@export var update_interval: float = 0.2

const MAX_LEVEL := 8
const SPREAD_LOSS := 1

var water_levels := {}
var water_sources := {}
var time := 0.0

var visual_node: Node2D
var ground_layer: TileMapLayer
var update_timer: Timer

func _ready():
	call_deferred("_setup")

func _setup():
	var root = get_tree().current_scene
	if not root:
		print("No current scene")
		return

	visual_node = Node2D.new()
	visual_node.name = "WaterVisuals"
	root.add_child(visual_node)
	visual_node.draw.connect(_draw_water)
	print("Visual node added")

	# Find ground layer
	for child in root.get_children():
		if child is TileMapLayer:
			print("Found layer: ", child.name)
			if "tile" in child.name.to_lower():
				ground_layer = child
				print("Ground layer set to: ", child.name)

	if not ground_layer:
		print("Ground layer not found (no TileMapLayer with 'tile' in name)")

	# Find water source layers
	var water_layers = []
	for child in root.get_children():
		if child is TileMapLayer and "water" in child.name.to_lower():
			water_layers.append(child)
			print("Water source layer: ", child.name)

	if water_layers.is_empty():
		print("No water source layers found")

	for layer in water_layers:
		var cells = layer.get_used_cells()
		print("Layer ", layer.name, " has ", cells.size(), " tiles")
		for cell in cells:
			water_sources[cell] = true
			water_levels[cell] = MAX_LEVEL
			print("Water source at ", cell)

	# Start flow timer
	update_timer = Timer.new()
	update_timer.wait_time = update_interval
	update_timer.timeout.connect(_flow_step)
	add_child(update_timer)
	update_timer.start()

	set_process(true)
	print("WaterManager ready")

func _process(delta):
	time += delta
	if visual_node:
		visual_node.queue_redraw()

func _draw_water():
	# DEBUG: draw a fixed red rectangle to confirm drawing works
	visual_node.draw_rect(Rect2(100, 100, 50, 50), Color.RED, true)

	if not ground_layer:
		print("No ground_layer in _draw_water")
		return

	var cell_size = ground_layer.tile_set.tile_size.x
	print("Ground layer cell size: ", cell_size)
	print("Water levels count: ", water_levels.size())

	for cell in water_levels:
		var level = water_levels[cell]
		if level <= 0:
			continue

		var world_pos = ground_layer.map_to_local(cell)
		var rect = Rect2(
			world_pos - Vector2(cell_size/2, cell_size/2),
			Vector2(cell_size, cell_size)
		)

		var alpha = 0.3 + 0.5 * (level / float(MAX_LEVEL))
		var base_color = Color(0.2, 0.6, 1.0, alpha)
		visual_node.draw_rect(rect, base_color, true)

		var line_count = 3
		var line_speed = 2.0
		for i in line_count:
			var y_offset = sin(time * line_speed + i * 2.0) * 2
			var line_y = rect.position.y + (i + 1) * rect.size.y / (line_count + 1) + y_offset
			visual_node.draw_line(
				Vector2(rect.position.x, line_y),
				Vector2(rect.position.x + rect.size.x, line_y),
				Color(1, 1, 1, 0.6),
				1.0
			)

func _flow_step():
	if not ground_layer:
		return

	var cells = water_levels.keys()
	for cell in cells:
		_flow_from_cell(cell)

func _flow_from_cell(cell: Vector2i):
	if water_sources.has(cell):
		return

	var level = water_levels.get(cell, 0)
	if level <= 0:
		return

	var below = cell + Vector2i.DOWN
	if not _is_solid(below) and water_levels.get(below, 0) < MAX_LEVEL:
		var transfer = min(level, MAX_LEVEL - water_levels.get(below, 0))
		if transfer > 0:
			_set_water(below, water_levels.get(below, 0) + transfer)
			_set_water(cell, level - transfer)
			return

	var left = cell + Vector2i.LEFT
	var right = cell + Vector2i.RIGHT
	var targets = []

	for dir in [left, right]:
		if not _is_solid(dir) and water_levels.get(dir, 0) < level - SPREAD_LOSS:
			targets.append(dir)

	if targets.is_empty():
		return

	var total_loss = 0
	for target in targets:
		var target_level = water_levels.get(target, 0)
		var flow = min(level - total_loss - SPREAD_LOSS, MAX_LEVEL - target_level)
		if flow > 0:
			_set_water(target, target_level + flow)
			total_loss += flow
	_set_water(cell, level - total_loss)

func _set_water(cell: Vector2i, new_level: int):
	if new_level <= 0:
		water_levels.erase(cell)
	else:
		water_levels[cell] = new_level

func _is_solid(cell: Vector2i) -> bool:
	if not ground_layer:
		return false
	var tile_data = ground_layer.get_cell_tile_data(cell)
	return tile_data != null and tile_data.get_collision_polygons_count(1) > 0

func add_source(cell: Vector2i):
	water_sources[cell] = true
	_set_water(cell, MAX_LEVEL)

func remove_source(cell: Vector2i):
	water_sources.erase(cell)
