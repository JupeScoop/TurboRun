extends Sprite2D

# ── Bind to Road Generator ──
@export var road_gen_path: NodePath = NodePath("../Node2D")
@onready var road_gen = get_node_or_null(road_gen_path)

# ── Frame indices ──
const FRAME_LEFT_HARD   = 0
const FRAME_LEFT_SOFT   = 1
const FRAME_CENTER      = 2
const FRAME_RIGHT_SOFT  = 3
const FRAME_RIGHT_HARD  = 4

# ── Sprite sheet setup ──
@export var frame_width: int      = 0
@export var turn_hold_time: float = 0.2

# ── Tilt tuning ──
#@export var max_tilt: float   = 20.0   # increased tilt for clearer feedback
#@export var tilt_speed: float = 7.0    # bit snappier tilt response

# ── Scaling & positioning ──
@export var scale_factor: Vector2 = Vector2(0.5, 0.5)
@export var bottom_margin: float = 50.0

# ── Internal state ──
var left_hold: float  = 0.0
var right_hold: float = 0.0

func _ready() -> void:
	region_enabled = true
	if frame_width <= 0 and texture:
		frame_width = int(texture.get_width() / 5)
	_apply_frame(FRAME_CENTER)
	scale = scale_factor
	_update_position()

func _process(delta: float) -> void:
	# Steering input & hold timers
	var steer_left = Input.is_action_pressed("ui_left")
	var steer_right = Input.is_action_pressed("ui_right")
	if steer_left:
		left_hold += delta; right_hold = 0.0
	elif steer_right:
		right_hold += delta; left_hold = 0.0
	else:
		left_hold = 0.0; right_hold = 0.0

	# Frame selection
	var sel_frame = FRAME_CENTER
	if left_hold > 0.0:
		sel_frame = FRAME_LEFT_HARD if left_hold >= turn_hold_time else FRAME_LEFT_SOFT
	elif right_hold > 0.0:
		sel_frame = FRAME_RIGHT_HARD if right_hold >= turn_hold_time else FRAME_RIGHT_SOFT
	_apply_frame(sel_frame)

	# Compute steering value
	var steer_val: float = -1.0 if steer_right else (1.0 if steer_left else 0.0)

	# Center car X; road moves under
	position.x = get_viewport_rect().size.x * 0.5

	# Tilt for feedback
#	var target_rot = deg_to_rad(steer_val * max_tilt)
#	rotation = lerp_angle(rotation, target_rot, tilt_speed * delta)

	# Vertical positioning
	_update_position()

	# Pass steering to road
	if road_gen:
		road_gen.steering = steer_val
	else:
		push_warning("RoadGenerator not found: %s" % road_gen_path)

func _update_position() -> void:
	if not texture: return
	var vh = get_viewport_rect().size.y
	var sh = texture.get_height() * scale_factor.y
	position.y = vh - sh * 0.5 - bottom_margin

func _apply_frame(frame_index: int) -> void:
	if texture and frame_width > 0:
		var h = texture.get_height()
		region_rect = Rect2(frame_index * frame_width, 0, frame_width, h)
