# RoadRenderer.gd (OutRun-style with Throttle, Smooth Decel & Speed-scaled Steering)
extends Node2D

# Configurable parameters
@export var segment_count: int       = 2000
@export var segment_length: float    = 80.0
@export var road_width: float        = 3000.0
@export var camera_height: float     = 1000.0
@export var camera_depth: float      = 200.0
@export var draw_distance: int       = 250
@export var base_speed: float        = 0.0     # cruise speed
@export var max_speed: float         = 800.0   # top speed when fully throttled
@export var horizon_pct: float       = 0.3
@export var curve_scale: float       = 300.0   # bend visibility
@export var steer_influence: float   = 0.00007 # steering effect magnitude
@export var steer_smooth_rate: float = 3.0     # how quickly steering influence smooths
@export var accel_rate: float        = 5.0     # acceleration smoothing rate
@export var decel_rate: float        = 2.0     # deceleration smoothing rate

# Runtime state
var player_z: float               = 0.0
var current_curve: float          = 0.0
var steering: float               = 0.0   # raw input from Car.gd
var smooth_steering: float        = 0.0   # smoothed steering value
var current_speed: float          = base_speed
var segments: Array[Dictionary]   = []

func _ready() -> void:
	_build_track()

func _process(delta: float) -> void:
	# Determine target speed
	var throttle = Input.is_action_pressed("ui_select")
	var target_speed: float = max_speed if throttle else base_speed

	# Smooth speed change
	var speed_rate: float = accel_rate if throttle else decel_rate
	current_speed = lerp(current_speed, target_speed, clamp(delta * speed_rate, 0.0, 1.0))

	# Advance along track
	var total_length: float = segment_count * segment_length
	player_z = fposmod(player_z + delta * current_speed, total_length)

	# Smooth steering input
	smooth_steering = lerp(smooth_steering, steering, clamp(delta * steer_smooth_rate, 0.0, 1.0))

	# Compute speed factor (0–1)
	var speed_factor: float = clamp(current_speed / max_speed, 0.0, 1.0)

	# Blend natural curve + steering scaled by speed
	var base_curve: float = sin(player_z * 0.0017) * 0.00017
	if current_speed > 10.0:
		current_curve = lerp(current_curve, base_curve + smooth_steering * steer_influence * speed_factor, 0.2)
	else:
		current_curve = lerp(current_curve, base_curve, 0.2)

	queue_redraw()

func _draw() -> void:
	var vs: Vector2 = get_viewport_rect().size
	var cx: float = vs.x * 0.5
	var horizon_y: float = vs.y * horizon_pct

	var x_off: float = 0.0
	var dx: float    = 0.0
	var base_i: int  = int(player_z / segment_length) % segment_count

	for n in range(draw_distance - 1, -1, -1):
		var seg = segments[(base_i + n) % segment_count]
		var next_seg = segments[(base_i + n + 1) % segment_count]

		var rel_z1: float = seg.z - player_z
		var rel_z2: float = next_seg.z - player_z
		if rel_z1 <= 0.0 or rel_z2 <= 0.0:
			continue

		var scale1: float = camera_depth / rel_z1
		var scale2: float = camera_depth / rel_z2

		var w1: float = road_width * scale1
		var w2: float = road_width * scale2
		var y1: float = horizon_y + camera_height * scale1
		var y2: float = horizon_y + camera_height * scale2

		var x1: float = cx + x_off
		var x2: float = cx + x_off + dx

		var quad: PackedVector2Array = PackedVector2Array([
			Vector2(x1 - w1, y1),
			Vector2(x1 + w1, y1),
			Vector2(x2 + w2, y2),
			Vector2(x2 - w2, y2)
		])
		draw_polygon(quad, PackedColorArray([seg.color]))

		dx -= current_curve * curve_scale
		x_off -= dx

func _build_track() -> void:
	segments.clear()
	var z_pos: float = 0.0
	for i in range(segment_count):
		var seg_color: Color = Color8(105,105,105) if i % 2 == 0 else Color8(115,115,115)
		segments.append({"z": z_pos, "color": seg_color})
		z_pos += segment_length
