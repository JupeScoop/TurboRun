# sprite_2d.gd
# -----------------
# Controls the player's car sprite and translates keyboard input
# into steering values for the road renderer.  The sprite sheet
# contains multiple frames showing the car turning left and right.

extends Sprite2D

# --- Link to the RoadRenderer node ---------------------------------
@export var road_gen_path: NodePath = NodePath("../Node2D")
@onready var road_gen = get_node_or_null(road_gen_path) # resolved on scene load

# --- Frame indices for the sprite sheet -----------------------------
const FRAME_LEFT_HARD   = 0
const FRAME_LEFT_SOFT   = 1
const FRAME_CENTER      = 2
const FRAME_RIGHT_SOFT  = 3
const FRAME_RIGHT_HARD  = 4

# --- Sprite sheet setup --------------------------------------------
@export var frame_width: int      = 0    # width of a single frame
@export var turn_hold_time: float = 0.5  # time before a soft turn becomes hard

# --- Optional tilt tuning (disabled) -------------------------------
# Uncomment these exports if you want the car to visually tilt while
# steering.  They are left commented to keep the example simple.
#@export var max_tilt: float   = 20.0   # maximum rotation in degrees
#@export var tilt_speed: float = 7.0    # how quickly the car tilts

# --- Scaling & positioning -----------------------------------------
@export var scale_factor: Vector2 = Vector2(0.5, 0.5)  # final sprite scale
@export var bottom_margin: float = 50.0                # gap from bottom of screen

# --- Internal state ------------------------------------------------
var left_hold: float  = 0.0      # how long the left key has been held
var right_hold: float = 0.0      # how long the right key has been held

func _ready() -> void:
		# Enable regions so we can display one frame from the sprite sheet.
		region_enabled = true
		# Determine frame width from the texture if not supplied.
		if frame_width <= 0 and texture:
				frame_width = int(texture.get_width() / 5)
		_apply_frame(FRAME_CENTER)
		scale = scale_factor
		_update_position()

func _process(delta: float) -> void:
		# ------------------------------------------------------------
		# Read keyboard input and choose the appropriate sprite frame.
		# ------------------------------------------------------------
		var steer_left = Input.is_action_pressed("ui_left")
		var steer_right = Input.is_action_pressed("ui_right")
		if steer_left:
				left_hold += delta; right_hold = 0.0
		elif steer_right:
				right_hold += delta; left_hold = 0.0
		else:
				left_hold = 0.0; right_hold = 0.0

		# Decide which animation frame to show based on hold times.
		var sel_frame = FRAME_CENTER
		if left_hold > 0.0:
				sel_frame = FRAME_LEFT_HARD if left_hold >= turn_hold_time else FRAME_LEFT_SOFT
		elif right_hold > 0.0:
				sel_frame = FRAME_RIGHT_HARD if right_hold >= turn_hold_time else FRAME_RIGHT_SOFT
		_apply_frame(sel_frame)

		# Convert input into a steering value: -1 means right, +1 means left.
		var steer_val: float = -1.0 if steer_right else (1.0 if steer_left else 0.0)

		# Keep the car horizontally centred; the road scrolls underneath.
		position.x = get_viewport_rect().size.x * 0.5

		# Optional tilt effect for feedback (disabled above).
		# var target_rot = deg_to_rad(steer_val * max_tilt)
		# rotation = lerp_angle(rotation, target_rot, tilt_speed * delta)

		# Stick the sprite to the bottom of the viewport.
		_update_position()

		# Pass steering information to the road renderer so it can bend.
		if road_gen:
				road_gen.steering = steer_val
		else:
				push_warning("RoadRenderer not found: %s" % road_gen_path)

# ------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------

# Position the sprite vertically relative to the viewport size.
func _update_position() -> void:
		if not texture:
				return
		var vh = get_viewport_rect().size.y
		var sh = texture.get_height() * scale_factor.y
		position.y = vh - sh * 0.5 - bottom_margin

# Show only the requested frame of the sprite sheet.
func _apply_frame(frame_index: int) -> void:
		if texture and frame_width > 0:
				var h = texture.get_height()
				region_rect = Rect2(frame_index * frame_width, 0, frame_width, h)
