extends CharacterBody2D

# Player states
enum State { NORMAL, CARRIED, THROWING, BOUNCING, DEAD }
var has_throwed = false

@export var player_id: int = 1
@export var speed: int = 300
@export var jump_speed: int = 500
@export var throw_strength: float = 500.0
@export var bounce_speed: float = 600.0
@export var other_player: Node2D


@onready var bounce_speed_var: float = bounce_speed
@onready var collider : CollisionShape2D = $CollisionShape2D

@onready var carry_position = $CarryPosition
@onready var carry_position2 = $CarriPosition2
@onready var carry_position3 = $CarriPosition3
@onready var pickup_area = $PickupArea
@onready var sprite = $Sprite2D

var current_state: State = State.NORMAL
var carried_player: Node2D = null
var carrier_player: Node2D = null
var can_pickup: bool = false
var nearby_players: Array[Node2D] = []

var respawn_point: Vector2 = Vector2(20, 20)

# Throw variables
var throw_velocity: Vector2 = Vector2.ZERO
var bounce_direction: Vector2 = Vector2.RIGHT
@export var throw_mode: int = 0  # 0 = Parabolic, 1 = Bouncing

# Input action names
var move_left: String
var move_right: String
var move_up: String
var move_down: String
var interact: String

# Input tracking
var down_pressed: bool = false
var interact_pressed: bool = false

var last_dir : Vector2 = Vector2(1,0)

#Character Animations
@onready var body_sprite : AnimatedSprite2D = $BodyAnimations
@onready var legs_sprite : AnimatedSprite2D = $LegsAnimations
const  red_body_sprites : String = "res://Assets/Sprites_GameJamPlus2025/Personaje1_SpriteSheet/RedAnimations_body.tres"
const red_legs_sprites : String = "res://Assets/Sprites_GameJamPlus2025/Personaje1_SpriteSheet/RedAnimations_legs.tres"
const yellow_body_sprites : String = "res://Assets/Sprites_GameJamPlus2025/Personaje2_SpriteSheet/YellowAnimations_body.tres"
const yellow_legs_sprites : String = "res://Assets/Sprites_GameJamPlus2025/Personaje2_SpriteSheet/YellowAnimations_legs.tres"

func set_respawn(position: Vector2) -> void:
	if respawn_point == position:
		return
	respawn_point = position
	other_player.set_respawn(position)

#LoadSprites according to player id
func load_sprites() -> void:
	var body_sprite_frames : SpriteFrames = SpriteFrames.new()
	var leg_sprite_frames : SpriteFrames = SpriteFrames.new()
	if player_id == 2:
		body_sprite_frames = load(red_body_sprites)
		leg_sprite_frames = load(red_legs_sprites)
		pass
	else:
		body_sprite_frames = load(yellow_body_sprites)
		leg_sprite_frames = load(yellow_legs_sprites)
		pass
	legs_sprite.sprite_frames = leg_sprite_frames
	body_sprite.sprite_frames = body_sprite_frames
	
	pass

func set_collision_shape():
	var	shape : CapsuleShape2D = collider.shape.duplicate()
	if player_id == 1:
		shape.radius = 21.65
		shape.height = 96.65
		collider.position.x = 0.105
		jump_speed = 500 * 1.25
		pass
	elif player_id == 2:
		shape.radius = 21.65
		shape.height = 63
	collider.shape = shape


func _ready():
	# Set up input actions based on player_id
	move_left = "p%d_move_left" % player_id
	move_right = "p%d_move_right" % player_id
	move_up = "p%d_move_up" % player_id
	move_down = "p%d_move_down" % player_id
	interact = "p%d_interact" % player_id
	load_sprites()
	body_sprite.play("idle")
	legs_sprite.play("idle")
	set_collision_shape()
	# Connect pickup area signals
	pickup_area.body_entered.connect(_on_pickup_area_body_entered)
	pickup_area.body_exited.connect(_on_pickup_area_body_exited)

func _physics_process(delta):
	check_thrwing_is_playing()
	if player_id == 1:
		if carried_player != null:
			jump_speed = 500
		else:
			jump_speed = 500 * 1.25
	match current_state:
		State.NORMAL:
			handle_normal_movement(delta)
		State.CARRIED:
			handle_carried_state()
		State.THROWING:
			handle_throwing_state(delta)
		State.BOUNCING:
			handle_bouncing_state(delta)
	update_input_tracking()

func check_thrwing_is_playing():
	if !body_sprite.is_playing() and body_sprite.animation == "throw" and has_throwed:
		has_throwed = false
		body_sprite.play("idle")

func play_throwing_animation():
	body_sprite.play("throw")
	
func play_ball_animation() -> void:
	if body_sprite.animation != "throw" and !has_throwed:
		body_sprite.play("ball")
	pass


func play_falling_animation() -> void:
	if carried_player == null:
		if body_sprite.animation != "throw" and !has_throwed:
			body_sprite.play("falling")
	else:
		if body_sprite.animation != "throw" and !has_throwed:
			body_sprite.play("walking_grab")
	legs_sprite.play("falling")

func play_normal_animation_movement(dir : Vector2) -> void:
	if dir.x > 0:
		body_sprite.flip_h = false
		legs_sprite.flip_h = false
		last_dir = dir
	elif dir.x < 0:
		body_sprite.flip_h = true
		legs_sprite.flip_h = true
		last_dir = dir
	
	if dir.x != 0:
		if body_sprite.animation != "throw" and !has_throwed:
			body_sprite.play("walking")
		legs_sprite.play("walking")
	else:
		if body_sprite.animation != "throw" and !has_throwed:
			body_sprite.play("idle")
		legs_sprite.play("idle")

func play_normal_grabbing_animation_movement(dir : Vector2) -> void:
	if dir.x > 0:
		body_sprite.flip_h = false
		legs_sprite.flip_h = false
		last_dir = dir
	elif dir.x < 0:
		body_sprite.flip_h = true
		legs_sprite.flip_h = true
		last_dir = dir
	
	if dir.x != 0:
		if body_sprite.animation != "throw" and !has_throwed:
			body_sprite.play("walking_grab")
		legs_sprite.play("walking")
	else:
		if body_sprite.animation != "throw" and !has_throwed:
			body_sprite.play("idle_grab")
		legs_sprite.play("idle")

func handle_normal_movement(delta):
	legs_sprite.visible = true
	# Only process movement if not being carried
	if carrier_player != null:
		return
	var direction = Vector2.ZERO
	direction.x = Input.get_axis(move_left, move_right)
	if carried_player == null:
		play_normal_animation_movement(direction)
	else:
		play_normal_grabbing_animation_movement(direction)
	# Only use vertical input for movement if not trying to drop
	if not (carried_player and Input.is_action_pressed(interact) and not down_pressed):
		if is_on_floor() and Input.is_action_pressed(move_up):
			# print("ON FLOOR: ", self.name, "\tVelocity Y", velocity.y)
			velocity.y -= jump_speed
	velocity.x = direction.x * speed
	
	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
		velocity.y = min(velocity.y, 600.0)
		play_falling_animation()
	elif velocity.y > 0:
		velocity.y = 0
		
	move_and_slide()

func handle_carried_state():
	if carrier_player != null:
		if carrier_player.last_dir.x > 0:
			body_sprite.flip_h = false
			legs_sprite.flip_h = false
		elif carrier_player.last_dir.x < 0:
			body_sprite.flip_h = true
			legs_sprite.flip_h = true
		pass
	# When carried, we don't control our own movement
	legs_sprite.visible = false
	if body_sprite.animation != "throw" and !has_throwed:
		body_sprite.play("ball")
	# Our position is set by the carrier in their physics process
	velocity = Vector2.ZERO

func handle_throwing_state(delta):
	# Apply gravity and movement for parabolic throw
	velocity.y += get_gravity().y * delta
	var collision = move_and_collide(velocity * delta)
	
	if collision:
		# Landed on ground or hit something
		current_state = State.NORMAL
		velocity = Vector2.ZERO
		modulate = Color(1, 1, 1)  # Reset color
	pass

func handle_bouncing_state(delta):
	# Bounce around like a beam of light
	var collision = move_and_collide(bounce_direction * bounce_speed_var * delta)
	
	if collision:
		# Bounce off surfaces
		bounce_direction = bounce_direction.bounce(collision.get_normal())
		
		# Optional: Add some energy loss
		bounce_speed_var *= 0.95
		
		if bounce_speed_var < 200.0:  # Stop when speed gets too low
			current_state = State.NORMAL
			legs_sprite.visible = true #Show legs
			bounce_speed_var = bounce_speed  # Reset for next time
			modulate = Color(1, 1, 1)  # Reset color

func _input(event):
	# Handle input for carried player (struggle to break free)
	if current_state == State.CARRIED:
		if event.is_action_pressed(interact) and randf() < 0.3:  # 30% chance to break free
			carrier_player.drop_player()
		return
	# Handle input for normal state
	if current_state == State.NORMAL:
		# Pick up nearby player
		if event.is_action_pressed(interact) and not carried_player and can_pickup and nearby_players.size() > 0:
			var target_player = get_best_pickup_target()
			if target_player:
				pickup_player(target_player)
				interact_pressed = true
				
		if event.is_action_released(interact):
			interact_pressed = false
		if interact_pressed:
			return
		# Cycle throw mode with interact + up
		#if event.is_action_pressed(interact) and Input.is_action_pressed(move_up) and not carried_player:
		#	cycle_throw_mode()
		# Handle throw/drop when carrying someone
		if carried_player and event.is_action_pressed(interact):
			# Check if down is also pressed for drop
			if down_pressed:
				drop_player()
			else:
				throw_player()
				
	if current_state == State.BOUNCING and event.is_action_pressed(move_down):
		current_state = State.NORMAL

func update_input_tracking():
	down_pressed = Input.is_action_pressed(move_down)
	# interact_pressed = Input.is_action_just_pressed(interact)

func get_best_pickup_target():
	for player in nearby_players:
		if player.current_state != State.CARRIED and player.current_state != State.DEAD and player != self:
			return player
	return null

func pickup_player(target: Node2D):
	carried_player = target
	target.get_picked_up(self)
	
	# Visual feedback
	modulate = Color(0.8, 1.0, 0.8)  # Light green for carrier
	target.modulate = Color(1.0, 0.8, 0.8)  # Light red for carried
	
	can_pickup = false
	nearby_players.erase(target)
	
	# Show throw mode indicator
	show_throw_indicator()

func get_picked_up(by: Node2D):
	carrier_player = by
	current_state = State.CARRIED
	bounce_speed_var = bounce_speed
	$CollisionShape2D.disabled = true
	velocity = Vector2.ZERO	
	# Important: Set our position to the carrier's carry position immediately
	global_position = carrier_player.carry_position.global_position

func drop_player():
	if not carried_player:
		return
	
	# Reset visual feedback
	modulate = Color(1, 1, 1)
	carried_player.modulate = Color(1, 1, 1)
	
	carried_player.get_dropped()
	carried_player = null

func get_dropped():
	carrier_player = null
	current_state = State.NORMAL
	set_collision.call_deferred(false)
	
func set_collision(value: bool):
	$CollisionShape2D.disabled = value

func throw_player():
	if not carried_player:
		return
	var throw_direction = Vector2.ZERO
	
	# Determine throw direction based on last movement or facing
	if velocity.length() > 0:
		throw_direction = velocity.normalized()
		throw_direction.x = last_dir.x
	else:
		# Default to right if no movement
		throw_direction = Vector2(1, -1)  # Slightly upward
		throw_direction.x = last_dir.x
	
	if throw_mode == 0:  # Parabolic throw
		parabolic_throw(carried_player, throw_direction)
	else:  # Bouncing throw
		bouncing_throw(carried_player, throw_direction)
	# Reset visual feedback for thrower
	modulate = Color(1, 1, 1)
	carried_player = null
	has_throwed = true
	play_throwing_animation()

func parabolic_throw(target: Node2D, direction: Vector2):
	target.get_thrown_parabolic(direction * throw_strength)
	
	# Optional: Add slight recoil to the thrower
	velocity = -direction * throw_strength * 0.1

func bouncing_throw(target: Node2D, direction: Vector2):
	target.get_thrown_bouncing(direction)

func get_thrown_parabolic(initial_velocity: Vector2):
	carrier_player = null
	current_state = State.THROWING
	$CollisionShape2D.disabled = false
	velocity = initial_velocity
	legs_sprite.visible = false #hide legs while being thrown
	# Visual effect
	modulate = Color(1.0, 0.7, 0.3)  # Orange tint while flying

func get_thrown_bouncing(direction: Vector2):
	carrier_player = null
	current_state = State.BOUNCING
	$CollisionShape2D.disabled = false
	bounce_direction = direction.normalized()
	velocity = Vector2.ZERO  # We use bounce_direction for movement
	legs_sprite.visible = false #hide legs while being thrown
	# Visual effect
	modulate = Color(0.3, 0.7, 1.0)  # Blue tint while bouncing

func _on_pickup_area_body_entered(body):
	if body is CharacterBody2D and body.has_method("get_picked_up") and body != self:
		if not body in nearby_players:
			nearby_players.append(body)
			can_pickup = true
			
			# Visual feedback - highlight when pickup is available
			if current_state == State.NORMAL and carried_player == null:
				modulate = Color(0.9, 0.9, 1.2)  # Slight blue tint

func _on_pickup_area_body_exited(body):
	if body in nearby_players:
		nearby_players.erase(body)
		if nearby_players.size() == 0:
			can_pickup = false
		# Reset visual feedback
		if current_state == State.NORMAL and carried_player == null:
			modulate = Color(1, 1, 1)

# Visual indicator for current throw mode
func show_throw_indicator():
	if throw_mode == 0:
		# Show parabolic indicator
		print("Parabolic throw mode - Press INTERACT to throw, INTERACT+DOWN to drop")
	else:
		# Show bouncing indicator
		print("Bouncing throw mode - Press INTERACT to throw, INTERACT+DOWN to drop")

# Function to cycle throw modes (call this from somewhere, like a separate button)
func cycle_throw_mode():
	throw_mode = (throw_mode + 1) % 2
	show_throw_indicator()
	
func die() -> void:
	if carrier_player != null:
		carrier_player.drop_player()
	else:
		drop_player()
	
	set_collision_layer_value(1, false)
	current_state = State.DEAD
	
	for i in 8:
		self.modulate.a = 0.5 if Engine.get_frames_drawn() % 2 == 0 else 1.0
	
	respawn.call_deferred()

func respawn() -> void:
	legs_sprite.visible = true #Show legs
	position = respawn_point
	set_collision_layer_value(1, true)
	current_state = State.NORMAL

# Add this function to update carried player position
func _process(delta):
	# If we're carrying someone, update their position
	if carried_player:
		#sprint("player_id that is being carried: " + str(player_id))
		if player_id == 2:
			carried_player.global_position = carry_position.global_position
		else:
			if last_dir.x > 0:
				carried_player.global_position = carry_position2.global_position
			elif last_dir.x < 0:
				carried_player.global_position = carry_position3.global_position
