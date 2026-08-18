extends Node2D
class_name LevelGenerator

# -----------------------
# CONFIG
# -----------------------
@export var chunk_scenes: Array[PackedScene] = []
@export var wall_scene: PackedScene = null
@export var offscreen_multiplier = 1.5
@export var chunks_ahead: int = 3
@export var player_path: NodePath = NodePath("")
@export var camera_path: NodePath = NodePath("")
@export var chunks_parent_name: String = "Chunks"

# Chunk metadata arrays - must match chunk_scenes indices
@export var chunk_entrance_counts: Array[int] = []
@export var chunk_exit_counts: Array[int] = []
@export var chunk_heights: Array[int] = []

# Height limits
@export var max_height: int = 8
@export var min_height: int = -8
@export var tile_x = 160
@export var tile_y = 160

# -----------------------
# STATE
# -----------------------
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var playable_chunks: Array = []
var wall_node: Node2D = null
var player: Node2D = null
var camera: Camera2D = null
var chunks_parent: Node2D = null
var last_chunk_scene: PackedScene = null  # Track last chunk to avoid duplicates
var current_height: int = 0  # Track current height level
var current_exit_count: int = 1  # Track exit count of last placed chunk

# -----------------------
# READY
# -----------------------
func _ready() -> void:
	global_position = get_node(player_path).global_position
	rng.randomize()
	_resolve_nodes()
	_setup_chunks_parent()

	# Spawn starting wall if available
	var anchor_for_first: Variant = global_position
	if wall_scene != null:
		anchor_for_first = _spawn_starting_wall(anchor_for_first)

	# Always spawn first chunk (index 0)
	var first_chunk_index = 0
	if chunk_scenes.size() > first_chunk_index and chunk_scenes[first_chunk_index] != null:
		var first_chunk = _instantiate_scene_safe(chunk_scenes[first_chunk_index])
		if first_chunk != null:
			chunks_parent.add_child(first_chunk)
			
			# Position first chunk at starting position
			var ent := first_chunk.get_node_or_null("Entrance") as Node2D
			if ent != null:
				first_chunk.global_position += anchor_for_first - ent.global_position
			else:
				first_chunk.global_position = anchor_for_first
			
			playable_chunks.append(first_chunk)
			last_chunk_scene = chunk_scenes[first_chunk_index]
			
			# Update current height and exit count from first chunk
			if chunk_heights.size() > first_chunk_index:
				current_height = chunk_heights[first_chunk_index]
			if chunk_exit_counts.size() > first_chunk_index:
				current_exit_count = chunk_exit_counts[first_chunk_index]
			
			print("LevelGen: Spawned first chunk '%s' at %s, height: %d, exits: %d" % 
				  [first_chunk.name, str(first_chunk.global_position), current_height, current_exit_count])
	
	# Spawn remaining initial chunks with filtering
	var cur_anchor = _get_last_exit()
	for i in range(chunks_ahead - 1):  # -1 because we already placed the first chunk
		var exit_node = _spawn_chunk(cur_anchor)
		if exit_node == null:
			break
		cur_anchor = exit_node

	_debug_state("After _ready()")

# -----------------------
# PROCESS
# -----------------------
func _process(_delta: float) -> void:
	# try to keep camera available
	if camera == null:
		_resolve_camera()
		if camera == null:
			return

	var cam_left = camera.global_position.x - get_camera_visible_width()
	@warning_ignore("unused_variable")
	var spawn_right = camera.global_position.x + get_camera_visible_width()

	# Check for deletion (chunks too far left)
	if playable_chunks.size() > 0:
		var oldest = playable_chunks[0]
		if is_instance_valid(oldest):
			var exit_node = oldest.get_node_or_null("Exit") as Node2D
			if exit_node != null:
				if exit_node.global_position.x < cam_left:
					_cycle_delete_oldest()

	# Ensure chunks ahead (check if we need to spawn more to the right)
	_ensure_chunks_ahead()

# -----------------------
# CYCLE DELETE (final behavior)
# -----------------------
func _cycle_delete_oldest() -> void:
	if playable_chunks.size() == 0:
		return

	var removed_chunk: Node2D = playable_chunks[0]
	if not is_instance_valid(removed_chunk):
		# remove invalid entry and bail
		playable_chunks.remove_at(0)
		return

	# --- 1) Cache the deleted chunk's Exit global position (authoritative)
	var deleted_exit_pos: Vector2 = removed_chunk.global_position
	var deleted_exit_node := removed_chunk.get_node_or_null("Exit") as Node2D
	if deleted_exit_node != null:
		deleted_exit_pos = deleted_exit_node.global_position

	# --- 2) Remove previous wall (only one allowed)
	if wall_node != null and is_instance_valid(wall_node):
		wall_node.queue_free()
		wall_node = null
		print("LevelGen: Removed previous wall")

	# --- 3) Spawn a replacement wall positioned at the deleted chunk's Exit
	if wall_scene != null:
		var new_wall := _instantiate_scene_safe(wall_scene)
		if new_wall != null:
			# add before removing chunk so player can't fall through a gap
			chunks_parent.add_child(new_wall)

			# Align wall.Entrance -> deleted_chunk.Exit (preferred)
			var w_ent := new_wall.get_node_or_null("Entrance") as Node2D
			var w_ex  := new_wall.get_node_or_null("Exit") as Node2D

			var placed := false
			if w_ent != null:
				# place so Entrance aligns to deleted_exit_pos
				new_wall.global_position += (deleted_exit_pos - w_ent.global_position)

				placed = true
			elif w_ex != null:
				# fallback: align wall.Exit to deleted_exit_pos but then shift by negative of exit offset
				new_wall.global_position += deleted_exit_pos - w_ex.global_position

				placed = true

			if placed == false:
				# ultimate fallback: set origin to deleted_exit_pos
				new_wall.global_position = deleted_exit_pos


			# Force visibility and collisions in front
			_force_wall_front(new_wall)

			# commit wall_node reference
			wall_node = new_wall
			print("LevelGen: Placed wall at", wall_node.global_position)
	else:
		print("LevelGen: No wall scene set; deleted chunk will be freed and may show void.")

	# --- 4) Spawn a new chunk at the far end to maintain flow
	var last_exit := _get_last_exit()
	var spawn_anchor: Variant = global_position
	if last_exit != null:
		spawn_anchor = last_exit
	_spawn_chunk(spawn_anchor)

	# --- 5) Now safely remove the deleted chunk from list and tree
	if playable_chunks.size() > 0 and playable_chunks[0] == removed_chunk:
		playable_chunks.remove_at(0)
	else:
		var idx := playable_chunks.find(removed_chunk)
		if idx != -1:
			playable_chunks.remove_at(idx)

	if removed_chunk.is_inside_tree():
		removed_chunk.queue_free()
	print("LevelGen: Deleted chunk:", removed_chunk.name)

	_debug_state("After _cycle_delete()")

# -----------------------
# WALL VISIBILITY HELPER
# -----------------------
func _force_wall_front(wall: Node2D) -> void:
	if wall == null:
		return

	# Use a safe z_index value (max is 4096 in Godot 4)
	wall.z_as_relative = false
	wall.z_index = 100  # High but safe value

	# apply to all child CanvasItems
	for child in wall.get_children():
		if child is CanvasItem:
			var c := child as CanvasItem
			c.z_as_relative = false
			c.z_index = 100

# -----------------------
# SPAWNING HELPERS
# -----------------------
func _spawn_starting_wall(anchor: Variant) -> Variant:
	var start_wall := _instantiate_scene_safe(wall_scene)
	if start_wall != null:
		chunks_parent.add_child(start_wall)

		var ent := start_wall.get_node_or_null("Entrance") as Node2D
		if ent != null:
			start_wall.global_position += global_position - ent.global_position
		else:
			start_wall.global_position = global_position

		wall_node = start_wall
		_force_wall_front(wall_node)

		var wex := start_wall.get_node_or_null("Exit") as Node2D
		if wex != null:
			return wex.global_position
		return start_wall.global_position
	return anchor

func _spawn_chunk(spawn_anchor: Variant) -> Node2D:
	if chunk_scenes.is_empty():
		push_error("LevelGen: chunk_scenes empty; cannot spawn.")
		return null

	# Filter scenes based on our criteria
	var valid_indices: Array[int] = []
	for i in range(chunk_scenes.size()):
		var scene = chunk_scenes[i]
		if scene and scene != last_chunk_scene:
			# Check if this chunk meets our requirements
			if _is_chunk_valid(i):
				valid_indices.append(i)
	
	# If no valid scenes (all were filtered out), allow any scene as fallback
	if valid_indices.is_empty():
		for i in range(chunk_scenes.size()):
			if chunk_scenes[i]:
				valid_indices.append(i)
	
	if valid_indices.is_empty():
		return null

	var idx := rng.randi_range(0, valid_indices.size() - 1)
	var scene_index = valid_indices[idx]
	var packed := chunk_scenes[scene_index]
	if packed == null:
		return null

	var chunk := _instantiate_scene_safe(packed)
	if chunk == null:
		return null

	chunks_parent.add_child(chunk)

	var anchor_pos: Vector2
	if spawn_anchor is Node:
		anchor_pos = (spawn_anchor as Node).global_position
	elif spawn_anchor is Vector2:
		anchor_pos = spawn_anchor
	else:
		anchor_pos = global_position

	var ent := chunk.get_node_or_null("Entrance") as Node2D
	if ent != null:
		chunk.global_position += anchor_pos - ent.global_position
	else:
		chunk.global_position = anchor_pos

	playable_chunks.append(chunk)
	last_chunk_scene = packed  # Update last chunk
	
	# Update current height and exit count from the chunk
	if chunk_heights.size() > scene_index:
		current_height += chunk_heights[scene_index]
	if chunk_exit_counts.size() > scene_index:
		current_exit_count = chunk_exit_counts[scene_index]
	
	print("LevelGen: Spawned chunk '%s' (idx %d) at %s, height: %d, exits: %d" % 
		  [chunk.name, scene_index, str(chunk.global_position), current_height, current_exit_count])
	
	var exit := chunk.get_node_or_null("Exit") as Node2D
	return exit

# Check if a chunk meets our filtering criteria
func _is_chunk_valid(chunk_index: int) -> bool:
	# Check if we have metadata for this chunk
	if chunk_entrance_counts.size() <= chunk_index:
		return true  # No metadata, allow it
	
	# Check if entrance count matches current exit count
	if chunk_entrance_counts[chunk_index] != current_exit_count:
		return false
	
	# Check height limits
	if chunk_heights.size() > chunk_index:
		var new_height = current_height + chunk_heights[chunk_index]
		if new_height < min_height or new_height > max_height:
			return false
	
	return true

func _get_last_exit() -> Node2D:
	# last playable chunk's Exit if available
	if playable_chunks.size() > 0:
		var last = playable_chunks[playable_chunks.size() - 1]
		if is_instance_valid(last):
			var ex := last.get_node_or_null("Exit") as Node2D
			if ex != null:
				return ex

	# fallback to wall Exit (useful at start)
	if wall_node != null and is_instance_valid(wall_node):
		var wex := wall_node.get_node_or_null("Exit") as Node2D
		if wex != null:
			return wex

	return null

func _ensure_chunks_ahead() -> void:
	_prune_null_playables()
	
	# Get the rightmost point we should generate up to
	var generation_threshold = camera.global_position.x + get_camera_visible_width()
	
	# Check if we need to generate more chunks
	var needs_more_chunks = false
	if playable_chunks.size() == 0:
		needs_more_chunks = true
	else:
		var last_chunk = playable_chunks[playable_chunks.size() - 1]
		if is_instance_valid(last_chunk):
			var last_exit = last_chunk.get_node_or_null("Exit") as Node2D
			if last_exit != null:
				needs_more_chunks = last_exit.global_position.x < generation_threshold
			else:
				needs_more_chunks = last_chunk.global_position.x < generation_threshold
		else:
			needs_more_chunks = true
	
	# Generate chunks until we reach the threshold
	while needs_more_chunks and playable_chunks.size() < chunks_ahead + 1:  # +1 for safety
		var last_exit := _get_last_exit()
		var anchor: Variant = global_position
		if last_exit != null:
			anchor = last_exit
		var new_chunk_exit = _spawn_chunk(anchor)
		
		# Check if we still need more chunks
		if new_chunk_exit != null:
			needs_more_chunks = new_chunk_exit.global_position.x < generation_threshold
		else:
			needs_more_chunks = false

func _instantiate_scene_safe(packed: PackedScene) -> Node2D:
	if packed == null:
		return null
	var inst := packed.instantiate()
	if inst is Node2D:
		return inst as Node2D
	# If root isn't Node2D, error (we rely on Entrance/Exit markers)
	push_error("LevelGen: Scene root is not Node2D; got %s" % [typeof(inst)])
	return null

# -----------------------
# UTIL / DEBUG
# -----------------------
func _resolve_nodes() -> void:
	if str(player_path) != "":
		player = get_node_or_null(player_path) as Node2D
	if player == null:
		var root := get_tree().get_current_scene()
		if root:
			player = root.find_node("Player", true, false) as Node2D

	if str(camera_path) != "":
		camera = get_node_or_null(camera_path) as Camera2D
	if camera == null:
		camera = get_viewport().get_camera_2d()
	if camera == null:
		var root2 := get_tree().get_current_scene()
		if root2:
			camera = root2.find_node("Camera2D", true, false) as Camera2D

func _setup_chunks_parent() -> void:
	chunks_parent = get_node_or_null(chunks_parent_name) as Node2D
	if chunks_parent == null:
		chunks_parent = Node2D.new()
		chunks_parent.name = chunks_parent_name
		add_child(chunks_parent)

func _prune_null_playables() -> void:
	var cleaned: Array = []
	for n in playable_chunks:
		if is_instance_valid(n):
			cleaned.append(n)
	playable_chunks = cleaned

func _debug_state(context: String = "") -> void:
	var names: Array = []
	for n in playable_chunks:
		if is_instance_valid(n):
			names.append(n.name)
		else:
			names.append("null")
	var wallname := "none"
	if wall_node != null and is_instance_valid(wall_node):
		wallname = wall_node.name
	print("LevelGen:", context, "playable=%d, wall=%s, height=%d, exits=%d -> %s" % 
		  [playable_chunks.size(), wallname, current_height, current_exit_count, ", ".join(names)])

func _resolve_camera() -> void:
	if str(camera_path) != "":
		camera = get_node_or_null(camera_path) as Camera2D
	if camera == null:
		camera = get_viewport().get_camera_2d()
	if camera == null:
		var root2 := get_tree().get_current_scene()
		if root2:
			camera = root2.find_node("Camera2D", true, false) as Camera2D

func get_camera_visible_width() -> float:
	var viewport_width_pixels = get_viewport().get_visible_rect().size.x
	var camera_zoom_x = get_node(camera_path).zoom.x
	return (viewport_width_pixels * offscreen_multiplier) / camera_zoom_x
