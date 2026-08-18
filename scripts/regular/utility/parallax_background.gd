# UltimateParallaxBackground.gd
# Godot 4.4 - Complete Parallax Background System with Advanced Void
# Attach to ParallaxBackground node

extends ParallaxBackground

# --- Layer Configuration ---
@export_category("Layer Configuration")
@export var layer_textures: Array[Texture2D] = []
@export var motion_scales: Array[Vector2] = []
@export var vertical_layers: Array[bool] = []
@export var ground_layers: Array[bool] = []
@export var flip_h: Array[bool] = []
@export var flip_v: Array[bool] = []
@export var layer_offsets: Array[Vector2] = []  # Offset for each layer
@export var layer_scales: Array[Vector2] = []   # NEW: Scale for each layer
@export var auto_scroll_speed: float = 0.0

# --- Void Configuration ---
@export_category("Void Configuration")
@export var enable_void: bool = false
@export var void_texture: Texture2D = null
@export var void_color: Color = Color.BLACK
@export var void_height: float = 1000.0
@export var void_below_layer: int = -1
@export var void_motion_scale: Vector2 = Vector2(1.0, 1.0)
@export var void_flip_h: bool = false
@export var void_flip_v: bool = false
@export var void_vertical_mirror: bool = false
@export var void_render_below_layer: int = -1
@export var void_offset: Vector2 = Vector2.ZERO  # Offset for single void
@export var void_scale: Vector2 = Vector2.ONE   # NEW: Scale for single void

# --- Multiple Void Layers ---
@export_category("Multiple Void Layers")
@export var enable_multiple_voids: bool = false
@export var void_layer_textures: Array[Texture2D] = []
@export var void_layer_colors: Array[Color] = []
@export var void_layer_heights: Array[float] = []
@export var void_layer_below_layers: Array[int] = []
@export var void_layer_motion_scales: Array[Vector2] = []
@export var void_layer_flip_h: Array[bool] = []
@export var void_layer_flip_v: Array[bool] = []
@export var void_layer_vertical_mirror: Array[bool] = []
@export var void_layer_render_below_layers: Array[int] = []
@export var void_layer_offsets: Array[Vector2] = []  # Offsets for multiple voids
@export var void_layer_scales: Array[Vector2] = []   # NEW: Scales for multiple voids

# --- Internal Variables ---
var _camera: Camera2D = null
var _void_layers: Array[ParallaxLayer] = []

func _ready() -> void:
	_camera = get_viewport().get_camera_2d()
	_create_all_layers()
	_create_voids()

func _process(delta: float) -> void:
	_handle_auto_scroll(delta)

func _create_all_layers() -> void:
	for child in get_children():
		if not child in _void_layers:
			child.queue_free()
	
	var viewport_size := get_viewport().get_visible_rect().size
	var camera_zoom := _camera.zoom if _camera else Vector2.ONE
	var visible_world_size := Vector2(viewport_size.x / camera_zoom.x, viewport_size.y / camera_zoom.y)
	
	for i in range(layer_textures.size()):
		_create_single_layer(i, visible_world_size)

func _create_single_layer(layer_index: int, visible_world_size: Vector2) -> void:
	var texture = layer_textures[layer_index]
	if not texture: return
	
	@warning_ignore("shadowed_variable_base_class")
	var layer = ParallaxLayer.new()
	layer.name = "Layer%d" % layer_index
	
	var container = Node2D.new()
	container.name = "Container"
	
	# Apply layer offset if available
	if layer_index < layer_offsets.size():
		container.position = layer_offsets[layer_index]
	
	layer.add_child(container)
	add_child(layer)
	
	if layer_index < motion_scales.size():
		layer.motion_scale = motion_scales[layer_index]
	else:
		layer.motion_scale = Vector2(1.0, 1.0)
	
	var texture_size := Vector2(texture.get_width(), texture.get_height())
	var is_ground = layer_index < ground_layers.size() and ground_layers[layer_index]
	var is_vertical = layer_index < vertical_layers.size() and vertical_layers[layer_index]
	var flip_horizontal = layer_index < flip_h.size() and flip_h[layer_index]
	var flip_vertical = layer_index < flip_v.size() and flip_v[layer_index]
	
	# Get layer scale if available, otherwise use Vector2.ONE
	var layer_scale = Vector2.ONE
	if layer_index < layer_scales.size():
		layer_scale = layer_scales[layer_index]
	
	var scale_x = (visible_world_size.x / texture_size.x) * layer_scale.x
	var scale_y = (visible_world_size.y / texture_size.y) * layer_scale.y
	var scaled_texture_size := Vector2(texture_size.x * scale_x, texture_size.y * scale_y)
	
	_create_tiled_sprites(container, texture, is_vertical, is_ground, visible_world_size, scaled_texture_size, scale_x, scale_y, flip_horizontal, flip_vertical)
	
	if is_vertical:
		layer.motion_mirroring = scaled_texture_size
	else:
		layer.motion_mirroring = Vector2(scaled_texture_size.x, 0)

@warning_ignore("shadowed_variable")
func _create_tiled_sprites(container: Node2D, texture: Texture2D, is_vertical: bool, is_ground: bool, visible_world_size: Vector2, scaled_texture_size: Vector2, scale_x: float, scale_y: float, flip_h: bool, flip_v: bool) -> void:
	var copies_x = ceil(visible_world_size.x / scaled_texture_size.x) + 1
	var copies_y = 1
	if is_vertical: copies_y = ceil(visible_world_size.y / scaled_texture_size.y) + 1
	
	@warning_ignore("unused_variable")
	var start_x = 0
	var start_y = 0
	if is_ground: start_y = visible_world_size.y - scaled_texture_size.y
	
	for x in range(copies_x):
		for y in range(copies_y):
			var sprite = Sprite2D.new()
			sprite.texture = texture
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.flip_h = flip_h
			sprite.flip_v = flip_v
			
			if is_vertical: sprite.scale = Vector2(scale_x, scale_y)
			else: sprite.scale = Vector2(scale_x, scale_x)
			
			sprite.position = Vector2(x * scaled_texture_size.x, start_y + (y * scaled_texture_size.y))
			container.add_child(sprite)

func _create_voids() -> void:
	# Clear existing void layers
	for void_layer in _void_layers:
		if is_instance_valid(void_layer):
			void_layer.queue_free()
	_void_layers.clear()
	
	if enable_multiple_voids:
		# Create multiple void layers
		for i in range(void_layer_textures.size()):
			_create_single_void_layer(i)
	elif enable_void:
		# Create single void layer (backward compatibility)
		_create_single_void_layer(-1)

func _create_single_void_layer(void_index: int) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var camera_zoom := _camera.zoom if _camera else Vector2.ONE
	var visible_world_size := Vector2(viewport_size.x / camera_zoom.x, viewport_size.y / camera_zoom.y)
	
	var void_layer = ParallaxLayer.new()
	void_layer.name = "VoidLayer%d" % void_index if void_index >= 0 else "VoidLayer"
	
	# Use single void settings or multiple void settings based on index
	var use_multiple = enable_multiple_voids and void_index >= 0
	
	var current_texture = void_texture
	var current_color = void_color
	var current_height = void_height
	var current_below_layer = void_below_layer
	var current_motion_scale = void_motion_scale
	var current_flip_h = void_flip_h
	var current_flip_v = void_flip_v
	var current_vertical_mirror = void_vertical_mirror
	var current_render_below_layer = void_render_below_layer
	var current_offset = void_offset  # Default for single void
	var current_scale = void_scale    # Default for single void
	
	if use_multiple:
		if void_index < void_layer_textures.size(): current_texture = void_layer_textures[void_index]
		if void_index < void_layer_colors.size(): current_color = void_layer_colors[void_index]
		if void_index < void_layer_heights.size(): current_height = void_layer_heights[void_index]
		if void_index < void_layer_below_layers.size(): current_below_layer = void_layer_below_layers[void_index]
		if void_index < void_layer_motion_scales.size(): current_motion_scale = void_layer_motion_scales[void_index]
		if void_index < void_layer_flip_h.size(): current_flip_h = void_layer_flip_h[void_index]
		if void_index < void_layer_flip_v.size(): current_flip_v = void_layer_flip_v[void_index]
		if void_index < void_layer_vertical_mirror.size(): current_vertical_mirror = void_layer_vertical_mirror[void_index]
		if void_index < void_layer_render_below_layers.size(): current_render_below_layer = void_layer_render_below_layers[void_index]
		if void_index < void_layer_offsets.size(): current_offset = void_layer_offsets[void_index]
		if void_index < void_layer_scales.size(): current_scale = void_layer_scales[void_index]  # Get scale for multiple voids
	
	void_layer.motion_scale = current_motion_scale
	
	var void_container = Node2D.new()
	void_container.name = "VoidContainer"
	
	# Apply void offset
	void_container.position = current_offset
	
	void_layer.add_child(void_container)
	
	var void_start_y = _calculate_void_start_y(visible_world_size, current_below_layer)
	
	var void_tex = current_texture
	if not void_tex:
		var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(current_color)
		void_tex = ImageTexture.create_from_image(image)
	
	var tex_size = void_tex.get_size()
	
	# Apply void scale
	var scale_x = (visible_world_size.x / tex_size.x) * current_scale.x
	@warning_ignore("shadowed_variable_base_class")
	var scale = Vector2(scale_x, scale_x) * current_scale.y
	var scaled_tex_size = Vector2(tex_size.x * scale.x, tex_size.y * scale.y)
	
	var copies_x = ceil(visible_world_size.x / scaled_tex_size.x) + 2
	var copies_y = ceil(current_height / scaled_tex_size.y) + 2
	
	for x in range(copies_x):
		for y in range(copies_y):
			var sprite = Sprite2D.new()
			sprite.texture = void_tex
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.flip_h = current_flip_h
			sprite.flip_v = current_flip_v
			sprite.scale = scale
			sprite.position = Vector2(x * scaled_tex_size.x, void_start_y + (y * scaled_tex_size.y))
			void_container.add_child(sprite)
	
	if current_vertical_mirror:
		void_layer.motion_mirroring = scaled_tex_size
	else:
		void_layer.motion_mirroring = Vector2(scaled_tex_size.x, 0)
	
	add_child(void_layer)
	_void_layers.append(void_layer)
	
	# Set render order
	if current_render_below_layer == -1:
		move_child(void_layer, 0)
	else:
		move_child(void_layer, current_render_below_layer + 1)

@warning_ignore("unused_parameter")
func _calculate_void_start_y(visible_world_size: Vector2, below_layer: int) -> float:
	var void_start_y = 0
	
	if below_layer >= 0 and below_layer < get_parallax_layer_count():
		var target_layer = get_parallax_layer(below_layer)
		if target_layer and target_layer.get_child_count() > 0:
			var container = target_layer.get_child(0)
			if container and container.get_child_count() > 0:
				var sprite = container.get_child(0) as Sprite2D
				if sprite:
					var layer_bottom = sprite.position.y + (sprite.texture.get_height() * sprite.scale.y)
					void_start_y = layer_bottom
	else:
		var lowest_ground_bottom = 0
		for i in range(get_parallax_layer_count()):
			@warning_ignore("shadowed_variable_base_class")
			var layer = get_parallax_layer(i)
			if layer and layer.get_child_count() > 0:
				var container = layer.get_child(0)
				if container and container.get_child_count() > 0:
					var sprite = container.get_child(0) as Sprite2D
					if sprite:
						var is_ground = i < ground_layers.size() and ground_layers[i]
						if is_ground:
							var layer_bottom = sprite.position.y + (sprite.texture.get_height() * sprite.scale.y)
							lowest_ground_bottom = max(lowest_ground_bottom, layer_bottom)
		void_start_y = lowest_ground_bottom
	
	return void_start_y

func _handle_auto_scroll(delta: float) -> void:
	if auto_scroll_speed == 0.0: return
	@warning_ignore("shadowed_variable_base_class")
	for layer in get_children():
		if layer is ParallaxLayer: layer.motion_offset.x += auto_scroll_speed * delta

func refresh_layers() -> void:
	_create_all_layers()
	_create_voids()

func set_auto_scroll(speed: float) -> void:
	auto_scroll_speed = speed

func set_void_enabled(enabled: bool) -> void:
	enable_void = enabled
	_create_voids()

@warning_ignore("shadowed_variable") @warning_ignore("shadowed_variable_base_class") func add_void_layer(texture: Texture2D = null, color: Color = Color.BLACK, height: float = 1000.0, 
				   below_layer: int = -1, motion_scale: Vector2 = Vector2(1.0, 1.0), 
				   flip_h: bool = false, flip_v: bool = false, vertical_mirror: bool = false,

				   render_below_layer: int = -1, offset: Vector2 = Vector2.ZERO, 
				   scale: Vector2 = Vector2.ONE) -> void:  # NEW: Added scale parameter
	void_layer_textures.append(texture)
	void_layer_colors.append(color)
	void_layer_heights.append(height)
	void_layer_below_layers.append(below_layer)
	void_layer_motion_scales.append(motion_scale)
	void_layer_flip_h.append(flip_h)
	void_layer_flip_v.append(flip_v)
	void_layer_vertical_mirror.append(vertical_mirror)
	void_layer_render_below_layers.append(render_below_layer)
	void_layer_offsets.append(offset)
	void_layer_scales.append(scale)  # NEW: Store the scale
	enable_multiple_voids = true
	_create_voids()

func remove_void_layer(index: int) -> void:
	if index < void_layer_textures.size(): void_layer_textures.remove_at(index)
	if index < void_layer_colors.size(): void_layer_colors.remove_at(index)
	if index < void_layer_heights.size(): void_layer_heights.remove_at(index)
	if index < void_layer_below_layers.size(): void_layer_below_layers.remove_at(index)
	if index < void_layer_motion_scales.size(): void_layer_motion_scales.remove_at(index)
	if index < void_layer_flip_h.size(): void_layer_flip_h.remove_at(index)
	if index < void_layer_flip_v.size(): void_layer_flip_v.remove_at(index)
	if index < void_layer_vertical_mirror.size(): void_layer_vertical_mirror.remove_at(index)
	if index < void_layer_render_below_layers.size(): void_layer_render_below_layers.remove_at(index)
	if index < void_layer_offsets.size(): void_layer_offsets.remove_at(index)
	if index < void_layer_scales.size(): void_layer_scales.remove_at(index)  # NEW: Remove scale too
	_create_voids()

func get_parallax_layer_count() -> int:
	var count = 0
	for child in get_children():
		if child is ParallaxLayer and not child in _void_layers: count += 1
	return count

func get_parallax_layer(index: int) -> ParallaxLayer:
	var current_index = 0
	for child in get_children():
		if child is ParallaxLayer and not child in _void_layers:
			if current_index == index: return child
			current_index += 1
	return null

func get_parallax_layer_sprite(index: int) -> Sprite2D:
	@warning_ignore("shadowed_variable_base_class")
	var layer = get_parallax_layer(index)
	if layer and layer.get_child_count() > 0:
		var container = layer.get_child(0)
		if container and container.get_child_count() > 0: return container.get_child(0) as Sprite2D
	return null

func get_void_layer_count() -> int:
	return _void_layers.size()

func get_void_layer(index: int) -> ParallaxLayer:
	if index >= 0 and index < _void_layers.size(): return _void_layers[index]
	return null

# Function to set offset for a specific regular layer
@warning_ignore("shadowed_variable_base_class")
func set_layer_offset(layer_index: int, offset: Vector2) -> void:
	if layer_index < layer_offsets.size():
		layer_offsets[layer_index] = offset
	else:
		# If the array isn't big enough, resize it and set the offset
		layer_offsets.resize(layer_index + 1)
		layer_offsets[layer_index] = offset
	refresh_layers()

# NEW: Function to set scale for a specific regular layer
@warning_ignore("shadowed_variable_base_class")
func set_layer_scale(layer_index: int, scale: Vector2) -> void:
	if layer_index < layer_scales.size():
		layer_scales[layer_index] = scale
	else:
		# If the array isn't big enough, resize it and set the scale
		layer_scales.resize(layer_index + 1)
		layer_scales[layer_index] = scale
	refresh_layers()

# Function to set offset for a specific void layer
@warning_ignore("shadowed_variable_base_class")
func set_void_layer_offset(void_index: int, offset: Vector2) -> void:
	if enable_multiple_voids and void_index < void_layer_offsets.size():
		void_layer_offsets[void_index] = offset
		refresh_layers()
	elif not enable_multiple_voids and enable_void:
		void_offset = offset
		refresh_layers()

# NEW: Function to set scale for a specific void layer
@warning_ignore("shadowed_variable_base_class")
func set_void_layer_scale(void_index: int, scale: Vector2) -> void:
	if enable_multiple_voids and void_index < void_layer_scales.size():
		void_layer_scales[void_index] = scale
		refresh_layers()
	elif not enable_multiple_voids and enable_void:
		void_scale = scale
		refresh_layers()
