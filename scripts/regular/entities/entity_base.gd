extends CharacterBody2D
class_name EntityBase

# Health system
@export var max_health: float = 100.0
@export var health: float = max_health
@export var is_dead: bool = false

# Attack system
@export var base_damage: float = 10.0
@export var attack_cooldown: float = 0.5
var attack_cooldown_timer: float = 0.0
var can_attack: bool = true

# Knockback system
@export var knockback_resistance: float = 1.0  # Higher = less knockback
@export var stun_duration: float = 0.1
var stun_timer: float = 0.0
var is_stunned: bool = false

# Death system
var explosion_spritesheet= "res://sprites/effect sprites/explosion_death.png"  # Set path to spritesheet
var explosion_hframes: int = 4
var explosion_vframes: int = 2
@export var explosion_fps: float = 10.0
@export var explosion_duration: float = 0.5
@export var explosion_scale: Vector2 = Vector2(5, 5)

# Multiplayer ready
@export var is_network_synced: bool = false
var network_id: int = 0

# Signals for battle system
signal entity_damaged(damage: float, attacker: Node, knockback_direction: Vector2, knockback_force: float)
signal entity_died(killer: Node)
signal entity_healed(amount: float)
signal entity_respawned()

# Groups for collision
@export var damageable_group: String = "damageable"
@export var attacker_group: String = "attacker"

func _ready():
	add_to_group(damageable_group)
	health = max_health
	_setup_animation_player()

func _physics_process(delta):
	if is_dead:
		return
	
	# Handle stun
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0:
			is_stunned = false
			_on_stun_end()
	
	# Handle attack cooldown
	if not can_attack:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0:
			can_attack = true

func _setup_animation_player():
	# Check if animation player exists, create if not
	if not has_node("AnimationPlayer"):
		var anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		add_child(anim_player)

# Damage handling
func take_damage(damage: float, attacker: Node = null, knockback_direction: Vector2 = Vector2.ZERO, knockback_force: float = 500.0) -> void:
	if is_dead or is_stunned:
		return
	
	health -= damage
	
	# Apply knockback
	if knockback_force > 0:
		apply_knockback(knockback_direction, knockback_force / knockback_resistance)
	
	emit_signal("entity_damaged", damage, attacker, knockback_direction, knockback_force)
	
	# Flash red effect
	flash_damage_effect()
	
	# Spawn damage number
	spawn_damage_number(damage)
	
	# Check death
	if health <= 0:
		die(attacker)
	else:
		# Brief stun
		is_stunned = true
		stun_timer = stun_duration

# Apply knockback
func apply_knockback(direction: Vector2, force: float) -> void:
	if direction != Vector2.ZERO:
		velocity = direction.normalized() * force
		move_and_slide()

# Death function
func die(killer: Node = null) -> void:
	if is_dead:
		return
	
	is_dead = true
	emit_signal("entity_died", killer)
	
	# Create death explosion
	create_explosion()
	
	# Disable collisions
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	# Hide sprite
	if has_node("sprite"):
		$sprite.visible = false
	
	# Queue free after delay
	await get_tree().create_timer(explosion_duration).timeout
	call_deferred("queue_free")
# Create explosion effect
func create_explosion() -> void:
	if explosion_spritesheet == "":
		# Create a simple flash effect if no spritesheet provided
		var flash = ColorRect.new()
		flash.color = Color(1, 0.5, 0, 0.8)
		flash.size = Vector2(64, 64)
		flash.position = -flash.size / 2
		flash.global_position = global_position
		get_parent().add_child(flash)
		
		var tween = create_tween()
		tween.tween_property(flash, "color:a", 0.0, explosion_duration)
		tween.tween_callback(flash.queue_free)
		return
	
	# Create sprite with spritesheet animation
	var explosion_sprite = Sprite2D.new()
	var texture = load(explosion_spritesheet)
	if texture:
		explosion_sprite.texture = texture
		explosion_sprite.hframes = explosion_hframes
		explosion_sprite.vframes = explosion_vframes
		explosion_sprite.scale = explosion_scale
		explosion_sprite.global_position = global_position
		explosion_sprite.z_index = 10
		
		get_parent().add_child(explosion_sprite)
		
		# Animate the sprite
		var frame_count = explosion_hframes * explosion_vframes
		var frame_time = 1.0 / explosion_fps
		
		var tween = create_tween()
		for i in range(frame_count):
			tween.tween_callback(explosion_sprite.set_frame.bind(i))
			tween.tween_interval(frame_time)
		tween.tween_callback(explosion_sprite.queue_free)
		explosion_sprite.queue_free()

# Flash damage effect
func flash_damage_effect() -> void:
	if has_node("sprite"):
		var sprite = $sprite
		var original_modulate = sprite.modulate
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite):
			sprite.modulate = original_modulate

# Spawn damage number
func spawn_damage_number(damage: float) -> void:
	var label = Label.new()
	label.text = str(round(damage))
	label.global_position = global_position + Vector2(randf_range(-20, 20), -50)
	label.add_theme_color_override("font_color", Color.RED)
	label.add_theme_font_size_override("font_size", 20)
	label.z_index = 100
	
	get_parent().add_child(label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 30, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

# Healing
func heal(amount: float) -> void:
	if is_dead:
		return
	
	health = min(health + amount, max_health)
	emit_signal("entity_healed", amount)

# Respawn function
func respawn(spawn_position: Vector2 = Vector2.ZERO) -> void:
	is_dead = false
	health = max_health
	velocity = Vector2.ZERO
	global_position = spawn_position
	
	# Re-enable collisions
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	
	# Show sprite
	if has_node("sprite"):
		$sprite.visible = true
	
	emit_signal("entity_respawned")

# Attacking function (override in child classes)
func perform_attack(attack_direction: Vector2, attack_force: float = 300.0, attack_damage: float = 0.0) -> void:
	if not can_attack or is_dead or is_stunned:
		return
	
	var damage = attack_damage if attack_damage > 0 else base_damage
	
	# Launch attack hitbox or damage area
	var attack_area = create_attack_area(damage, knockback_resistance, attack_direction)
	if attack_area:
		# Position it in attack direction
		attack_area.global_position = global_position + attack_direction.normalized() * 30
		
		# Add to attacker group for multiplayer identification
		attack_area.add_to_group(attacker_group)
		
		# Auto-cleanup
		get_tree().create_timer(0.1).timeout.connect(attack_area.queue_free)
	
	# Start cooldown
	can_attack = false
	attack_cooldown_timer = attack_cooldown

# Create attack area (override for custom behavior)
func create_attack_area(damage: float, knockback: float, direction: Vector2) -> Area2D:
	var area = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 30.0
	collision.shape = shape
	area.add_child(collision)
	
	# Store attack data
	area.set_meta("damage", damage)
	area.set_meta("knockback_force", knockback * 500)
	area.set_meta("attacker", self)
	area.set_meta("attack_direction", direction)
	
	get_parent().add_child(area)
	
	# Connect hit detection
	area.body_entered.connect(_on_attack_hit.bind(area))
	
	return area

# Handle attack hits
func _on_attack_hit(body: Node, attack_area: Area2D) -> void:
	if body == self or not body.is_in_group(damageable_group) or not body.has_method("take_damage"):
		return
	
	var damage = attack_area.get_meta("damage")
	var knockback_force = attack_area.get_meta("knockback_force")
	var attack_direction = attack_area.get_meta("attack_direction")
	
	body.take_damage(damage, self, attack_direction, knockback_force)

# Called when stun ends (override for custom behavior)
func _on_stun_end() -> void:
	pass

# Network helper functions
func set_network_owner(id: int) -> void:
	network_id = id
	if is_network_synced:
		set_multiplayer_authority(id)

# Helper to get all damageable entities in scene
func get_all_damageable() -> Array:
	return get_tree().get_nodes_in_group("damageable")
