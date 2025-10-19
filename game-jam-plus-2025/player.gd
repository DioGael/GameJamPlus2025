extends CharacterBody2D

# Player states
enum State { NORMAL, CARRIED, THROWING, BOUNCING }
@export var player_id: int = 1
@export var speed: int = 300
@export var jump_speed: int = 500
@export var throw_strength: float = 500.0
@export var bounce_speed: float = 400.0

@onready var carry_position = $CarryPosition
@onready var pickup_area = $PickupArea
@onready var sprite = $Sprite2D

var current_state: State = State.NORMAL
var carried_player: Node2D = null
var carrier_player: Node2D = null
var can_pickup: bool = false
var nearby_players: Array[Node2D] = []

# Throw variables
var throw_velocity: Vector2 = Vector2.ZERO
var bounce_direction: Vector2 = Vector2.RIGHT
var throw_mode: int = 0  # 0 = Parabolic, 1 = Bouncing

# Input action names
var move_left: String
var move_right: String
var move_up: String
var move_down: String
var interact: String

# Input tracking
var down_pressed: bool = false
var interact_pressed: bool = false

func _ready():
	# Set up input actions based on player_id
	move_left = "p%d_move_left" % player_id
	move_right = "p%d_move_right" % player_id
	move_up = "p%d_move_up" % player_id
	move_down = "p%d_move_down" % player_id
	interact = "p%d_interact" % player_id
	
	# Connect pickup area signals
	pickup_area.body_entered.connect(_on_pickup_area_body_entered)
	pickup_area.body_exited.connect(_on_pickup_area_body_exited)

func _physics_process(delta):
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

func handle_normal_movement(delta):
	# Only process movement if not being carried
	if carrier_player != null:
		return
		
	var direction = Vector2.ZERO
	direction.x = Input.get_axis(move_left, move_right)
	
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
	elif velocity.y > 0:
		velocity.y = 0
		
	move_and_slide()

func handle_carried_state():
	# When carried, we don't control our own movement
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
	var collision = move_and_collide(bounce_direction * bounce_speed * delta)
	
	if collision:
		# Bounce off surfaces
		bounce_direction = bounce_direction.bounce(collision.get_normal())
		
		# Optional: Add some energy loss
		bounce_speed *= 0.95
		
		if bounce_speed < 50:  # Stop when speed gets too low
			current_state = State.NORMAL
			bounce_speed = 400.0  # Reset for next time
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
		if event.is_action_pressed(interact) and Input.is_action_pressed(move_up) and not carried_player:
			cycle_throw_mode()
		# Handle throw/drop when carrying someone
		if carried_player and event.is_action_pressed(interact):
			# Check if down is also pressed for drop
			if down_pressed:
				drop_player()
			else:
				throw_player()

func update_input_tracking():
	down_pressed = Input.is_action_pressed(move_down)
	# interact_pressed = Input.is_action_just_pressed(interact)

func get_best_pickup_target():
	for player in nearby_players:
		if player.current_state != State.CARRIED and player != self:
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
	$CollisionShape2D.disabled = false

func throw_player():
	if not carried_player:
		return
	
	var throw_direction = Vector2.ZERO
	
	# Determine throw direction based on last movement or facing
	if velocity.length() > 0:
		throw_direction = velocity.normalized()
	else:
		# Default to right if no movement
		throw_direction = Vector2(1, -0.3)  # Slightly upward
		
	
	if throw_mode == 0:  # Parabolic throw
		parabolic_throw(carried_player, throw_direction)
	else:  # Bouncing throw
		bouncing_throw(carried_player, throw_direction)
	
	# Reset visual feedback for thrower
	modulate = Color(1, 1, 1)
	
	carried_player = null

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
	
	# Visual effect
	modulate = Color(1.0, 0.7, 0.3)  # Orange tint while flying

func get_thrown_bouncing(direction: Vector2):
	carrier_player = null
	current_state = State.BOUNCING
	$CollisionShape2D.disabled = false
	bounce_direction = direction.normalized()
	velocity = Vector2.ZERO  # We use bounce_direction for movement
	
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
	
# Add this function to update carried player position



func _process(delta):
	# If we're carrying someone, update their position
	if carried_player:
		carried_player.global_position = carry_position.global_position
