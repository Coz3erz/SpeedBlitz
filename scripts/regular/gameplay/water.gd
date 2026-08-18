@tool
extends Node2D
class_name Water

# --- Variables ---
@export_group("Dimensions")
@export var water_size: Vector2 = Vector2(100.0, 100.0)
@export var surface_pos_y: float = 0.5
@export_range(2, 512) var segment_count: int = 64

@export_group("Physics")
@export var player_splash_multiplier: float = 0.18
@export_range(0.0, 1000.0) var water_physics_speed: float = 90.0
@export var water_restoring_force: float = 0.025
@export var wave_energy_loss: float = 0.045
@export var wave_strength: float = 0.28
@export_range(1, 64) var wave_spread_updates: int = 8

@export_group("Visuals")
@export var surface_line_thickness: float = 10.0
@export var surface_color: Color = Color("3ce1da")
@export var water_fill_color: Color = Color("37b0c5b4")

@export_group("Audio")
@export var splash_velocity_threshold: float = 150.0
@export var soft_splash_paths: Array[String] = [
	"res://sounds/sound effects/map/splash1.sfxr"
]
@export var hard_splash_paths: Array[String] = [
	"res://sounds/sound effects/map/splash2.sfxr"
]
@export var min_volume_db: float = -8.0
@export var max_volume_db: float = 2.0
@export var max_distance: float = 2000.0
@export var debug_audio: bool = false

@export_group("Collision")
@export var collision_layer: int = 1
@export var collision_mask: int = 1

var segment_data: Array = []
var recently_splashed: bool = false
var surface_line: Line2D
var fill_polygon: Polygon2D
var audio_player: AudioStreamPlayer2D
var _cached_streams: Dictionary = {}

@export_tool_button("Update Water") var update_water_button: Callable = func():
	_ready()
	update_visuals()

# --- Core Logic ---

func _ready() -> void:
	for child in get_children():
		child.queue_free()
	initiate_water()

func initiate_water() -> void:
	segment_data.clear()
	for i in range(segment_count):
		segment_data.append({
			"height": surface_pos_y,
			"velocity": 0.0,
			"wave_to_left": 0.0,
			"wave_to_right": 0.0
		})

	surface_line = Line2D.new()
	surface_line.width = surface_line_thickness
	surface_line.default_color = surface_color
	add_child(surface_line)

	fill_polygon = Polygon2D.new()
	fill_polygon.color = water_fill_color
	fill_polygon.show_behind_parent = true
	surface_line.add_child(fill_polygon)

	var new_area: Area2D = Area2D.new()
	new_area.body_entered.connect(_on_body_entered)
	new_area.body_exited.connect(_on_body_exited)
	new_area.visible = false
	new_area.collision_layer = collision_layer
	new_area.collision_mask = collision_mask
	add_child(new_area)

	var new_shape: RectangleShape2D = RectangleShape2D.new()
	new_shape.size = water_size
	var new_collision: CollisionShape2D = CollisionShape2D.new()
	new_collision.shape = new_shape
	new_collision.position = water_size / 2.0 + Vector2(0, surface_pos_y / 2.0)
	new_area.add_child(new_collision)
	
	audio_player = AudioStreamPlayer2D.new()
	audio_player.max_distance = max_distance
	audio_player.bus = "SFX"
	add_child(audio_player)
	
	_preload_audio_streams()

func _preload_audio_streams() -> void:
	_cached_streams.clear()
	for path in soft_splash_paths + hard_splash_paths:
		if path.is_empty():
			continue
		if ResourceLoader.exists(path):
			_cached_streams[path] = load(path)
		else:
			push_warning("Water: Audio file not found: ", path)

func _process(delta: float) -> void:
	update_physics(delta)
	update_visuals()

func update_physics(delta: float) -> void:
	for i in range(segment_count):
		var displacement: float = segment_data[i]["height"] - surface_pos_y
		var acceleration: float = -water_restoring_force * displacement - segment_data[i]["velocity"] * wave_energy_loss
		segment_data[i]["velocity"] += acceleration * delta * water_physics_speed
		segment_data[i]["height"] += segment_data[i]["velocity"] * delta * water_physics_speed

	for _updates in range(wave_spread_updates):
		for i in range(segment_count):
			if i > 0:
				segment_data[i]["wave_to_left"] = (segment_data[i]["height"] - segment_data[i-1]["height"]) * wave_strength
				segment_data[i-1]["velocity"] += segment_data[i]["wave_to_left"] * delta * water_physics_speed
			if i < segment_count - 1:
				segment_data[i]["wave_to_right"] = (segment_data[i]["height"] - segment_data[i+1]["height"]) * wave_strength
				segment_data[i+1]["velocity"] += segment_data[i]["wave_to_right"] * delta * water_physics_speed

		for i in range(segment_count):
			if i > 0:
				segment_data[i-1]["height"] += segment_data[i]["wave_to_left"] * delta * water_physics_speed
			if i < segment_count - 1:
				segment_data[i+1]["height"] += segment_data[i]["wave_to_right"] * delta * water_physics_speed

	segment_data[0]["height"] = surface_pos_y
	segment_data[1]["height"] = surface_pos_y
	segment_data[segment_count - 1]["height"] = surface_pos_y
	segment_data[segment_count - 2]["height"] = surface_pos_y

	if not recently_splashed:
		var is_still: bool = true
		for i in segment_data:
			if abs(i["height"] - surface_pos_y) > 0.001:
				is_still = false
				break
		set_process(!is_still)
	else:
		recently_splashed = false

func update_visuals() -> void:
	var points: PackedVector2Array = []
	var segment_width: float = water_size.x / (segment_count - 1)
	for i in range(segment_count):
		points.append(Vector2(i * segment_width, segment_data[i]["height"]))

	var left_static_point: Vector2 = Vector2(points[0].x, surface_pos_y)
	var right_static_point: Vector2 = Vector2(points[points.size() - 1].x, surface_pos_y)

	var final_points: PackedVector2Array = PackedVector2Array([left_static_point])
	final_points.append_array(points)
	final_points.append(right_static_point)
	
	surface_line.points = final_points

	var bottom_y: float = surface_pos_y + water_size.y
	final_points.append(Vector2(water_size.x, bottom_y))
	final_points.append(Vector2(0, bottom_y))
	fill_polygon.polygon = final_points
# --- Interaction & Audio ---

func splash(splash_pos: Vector2, splash_velocity: float) -> void:
	var local_x_pos: float = to_local(splash_pos).x
	var segment_width: float = water_size.x / (segment_count - 1)
	var index: int = int(clamp(local_x_pos / segment_width, 0, segment_count - 1))
	segment_data[index]["velocity"] = splash_velocity
	recently_splashed = true
	set_process(true)

func play_splash_sound(velocity: float) -> void:
	if not audio_player:
		if debug_audio: print("Water: audio_player missing")
		return
	
	var abs_v: float = abs(velocity)
	var intensity: float = clamp(abs_v / 1200.0, 0.0, 1.0)
	audio_player.volume_db = lerp(min_volume_db, max_volume_db, intensity)
	audio_player.pitch_scale = randf_range(0.85, 1.15)
	
	var chosen_list: Array[String] = hard_splash_paths if abs_v > splash_velocity_threshold else soft_splash_paths
	
	if debug_audio:
		print("Water: v=%.2f, int=%.2f, vol=%.2f dB, list=%s" % [abs_v, intensity, audio_player.volume_db, "hard" if abs_v > splash_velocity_threshold else "soft"])
	
	if chosen_list.is_empty():
		if debug_audio: push_warning("Water: No sound paths assigned.")
		return
	
	var stream_path: String = chosen_list.pick_random()
	var stream: AudioStream = _cached_streams.get(stream_path)
	if not stream:
		if ResourceLoader.exists(stream_path):
			stream = load(stream_path)
			_cached_streams[stream_path] = stream
		else:
			push_error("Water: Audio file not found: ", stream_path)
			if debug_audio and not Engine.is_editor_hint():
				_generate_fallback_beep()
			return
	
	audio_player.stop()
	audio_player.stream = stream
	audio_player.play()
	
	if debug_audio: print("Water: Playing ", stream_path.get_file())

func _generate_fallback_beep() -> void:
	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = 0.1
	audio_player.stream = generator
	audio_player.play()
	
	var playback: AudioStreamGeneratorPlayback = audio_player.get_stream_playback()
	if playback:
		var frames: int = int(0.1 * 44100)
		for i in frames:
			var value: float = sin(i * 440.0 * TAU / 44100) * 0.3
			playback.push_frame(Vector2(value, value))

func _get_body_velocity_y(body: Node) -> float:
	if body is CharacterBody2D:
		return body.velocity.y
	elif body is RigidBody2D:
		return body.linear_velocity.y
	return 0.0

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("can_interact_with_water"):
		if debug_audio: print("Water: Body entered but not in group: ", body.name)
		return
	
	var vy: float = _get_body_velocity_y(body)
	splash(body.global_position, clamp(-vy * player_splash_multiplier,-900,900))
	play_splash_sound(vy)
	
	if body is CanvasItem:
		body.modulate = Color(0.6, 0.8, 1.0)
	if body is EntityBase and body.name == "blitz":
		body.velocity_multiplier = 0.5

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("can_interact_with_water"):
		return
	
	var vy: float = _get_body_velocity_y(body)
	splash(body.global_position, vy * player_splash_multiplier)
	play_splash_sound(vy)
	
	if body is CanvasItem:
		body.modulate = Color(1.0, 1.0, 1.0)
	if body is EntityBase and body.name == "blitz":
		body.velocity_multiplier = 1
