extends ProgressBar

@export var segments: int = 3
@export var corner_radius: float = 6.0
@export var segment_gap: float = 4.0
@export var colors: Array = [Color("5cf278"), Color("ffe15d"), Color("ff6464")]

# Outline properties
@export var outline_enabled: bool = true
@export var outline_color: Color = Color.BLACK
@export var outline_width: float = 2.0

# Flash effect
@export var flash_color: Color = Color.WHITE
@export var flash_duration: float = 0.25
var flash_timer: float = 0.0
var was_full: bool = false

func _process(delta: float) -> void:
	# Detect if bar just reached full
	if value >= max_value and not was_full:
		was_full = true
		flash_timer = flash_duration
	elif value < max_value:
		was_full = false
	
	# Count down flash timer
	if flash_timer > 0:
		flash_timer -= delta
		queue_redraw()

func _draw():
	var w = size.x
	var h = size.y
	var chunk_size = max_value / segments
	var chunk_width = (w - (segment_gap * (segments - 1))) / segments

	# Fade factor: 1.0 = full flash, 0.0 = normal colors
	var fade = clamp(flash_timer / flash_duration, 0.0, 1.0)

	for i in range(segments):
		var chunk_start_val = i * chunk_size
		var chunk_value = clamp(value - chunk_start_val, 0, chunk_size)
		@warning_ignore("shadowed_variable_base_class")
		var ratio = chunk_value / chunk_size

		var x = i * (chunk_width + segment_gap)
		var rect = Rect2(x, 0, chunk_width, h)

		# --- Background ---
		var bg = StyleBoxFlat.new()
		bg.bg_color = Color(0.15, 0.15, 0.15)
		bg.set_corner_radius_all(corner_radius)
		draw_style_box(bg, rect)

		# --- Fill ---
		if ratio > 0:
			var fill_rect = Rect2(x, 0, chunk_width * ratio, h)

			# Lerp between flash white → normal color
			var base_color = colors[i % colors.size()]
			var blended = flash_color.lerp(base_color, 1.0 - fade)

			var fill = StyleBoxFlat.new()
			fill.bg_color = blended
			fill.set_corner_radius_all(corner_radius)
			draw_style_box(fill, fill_rect)

		# --- Outline ---
		if outline_enabled and outline_width > 0:
			var outline = StyleBoxFlat.new()
			outline.bg_color = Color(0, 0, 0, 0)  # transparent fill
			outline.border_width_left   = outline_width
			outline.border_width_right  = outline_width
			outline.border_width_top    = outline_width
			outline.border_width_bottom = outline_width
			outline.border_color = outline_color
			outline.set_corner_radius_all(corner_radius)
			draw_style_box(outline, rect)
