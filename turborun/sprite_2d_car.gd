extends Sprite2D

# ── Frame indices in your 5-frame strip ──
const FRAME_LEFT_HARD   := 0
const FRAME_LEFT_SOFT   := 1
const FRAME_CENTER      := 2
const FRAME_RIGHT_SOFT  := 3
const FRAME_RIGHT_HARD  := 4

# ── Sprite strip setup ──
@export var frame_width:  int   = 1039  # width of one frame in the strip
@export var turn_hold_time: float = 0.2 # seconds until hard-turn frame

# ── Drift & tilt tuning ──
@export var max_drift:  float = 300.0  # horizontal drift in pixels
@export var drift_speed: float = 5.0   # lerp speed for horizontal movement
@export var max_tilt:   float = 15.0   # tilt angle in degrees
@export var tilt_speed: float = 5.0    # lerp speed for rotation

# ── Internal hold timers ──
var left_hold:  float = 0.0
var right_hold: float = 0.0

func _ready() -> void:
	region_enabled = true

func _process(delta: float) -> void:
	# 1) Read steering input
	var steer_left  = Input.is_action_pressed("ui_left")
	var steer_right = Input.is_action_pressed("ui_right")

	# 2) Update hold timers
	if steer_left:
		left_hold  += delta
		right_hold = 0.0
	elif steer_right:
		right_hold += delta
		left_hold  = 0.0
	else:
		left_hold  = 0.0
		right_hold = 0.0

	# 3) Select frame
	var sel_frame = FRAME_CENTER
	if left_hold > 0.0:
		if left_hold >= turn_hold_time:
			sel_frame = FRAME_LEFT_HARD
		else:
			sel_frame = FRAME_LEFT_SOFT
	elif right_hold > 0.0:
		if right_hold >= turn_hold_time:
			sel_frame = FRAME_RIGHT_HARD
		else:
			sel_frame = FRAME_RIGHT_SOFT

	# 4) Apply region
	if texture and frame_width > 0:
		var h = texture.get_height()
		region_rect = Rect2(sel_frame * frame_width, 0, frame_width, h)

	# 5) Compute steering value
	var steer_val: float = 0.0
	if steer_right:
		steer_val = 1.0
	elif steer_left:
		steer_val = -1.0

	# 6) Send to the road generator
	var road = get_parent().get_node("Road Generator")
	if road:
		road.steering = steer_val

	# 7) Drift car horizontally
	var center_x = get_viewport_rect().size.x * 0.5
	var target_x = center_x + steer_val * max_drift
	position.x = lerp(position.x, target_x, drift_speed * delta)

	# 8) Tilt car into the turn
	var target_r = deg_to_rad(steer_val * max_tilt)
	rotation = lerp_angle(rotation, target_r, tilt_speed * delta)

# Resets the car to the horizontal centre of the screen and clears any steering.
func reset_to_center() -> void:
	var center_x = get_viewport_rect().size.x * 0.5
	position.x = center_x
	rotation = 0.0
	left_hold = 0.0
	right_hold = 0.0
	var road = get_parent().get_node("Road Generator")
	if road:
		road.steering = 0.0
