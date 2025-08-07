# RoadRenderer.gd (OutRun-style with customizable curves)
extends Node2D

# Configurable parameters
@export var segment_count: int       = 2000
@export var segment_length: float    = 80.0
@export var road_width: float        = 3500.0
@export var camera_height: float     = 1000.0
@export var camera_depth: float      = 200.0
@export var draw_distance: int       = 250
@export var base_speed: float        = 0.0
@export var max_speed: float         = 500.0
@export var horizon_pct: float       = 0.35
@export var curve_scale: float       = 300.0
@export var steer_influence: float   = 0.0004
@export var steer_smooth_rate: float = 1.0
@export var accel_rate: float        = 5.0
@export var decel_rate: float        = 0.50

# ── NEW! Define your bends here ─────────────────────────────────
# Each entry: start Z, length of segment, curvature strength
# e.g. {"start": 1000.0, "length": 2000.0, "curve": 0.0006}
@export var curve_defs: Array[Dictionary] = [
	{ "start":  1000.0, "length": 2000.0, "curve":  0.00008 },
	{ "start":  4000.0, "length": 1500.0, "curve": -0.00008 },
	{ "start":  6000.0, "length": 1000.0, "curve":  0.00008 },
]

# Runtime state
var player_z: float               = 0.0
var current_curve: float          = 0.0
var steering: float               = 0.0
var smooth_steering: float        = 0.0
var current_speed: float          = base_speed
var segments: Array[Dictionary]   = []

func _ready() -> void:
	_build_track()

func _process(delta: float) -> void:
	# — speed & movement (unchanged) —
	var throttle = Input.is_action_pressed("ui_select")
	var target_speed = max_speed if throttle else base_speed
	var speed_rate = accel_rate if throttle else decel_rate
	current_speed = lerp(current_speed, target_speed, clamp(delta * speed_rate, 0.0, 0.9))
	player_z = fposmod(player_z + delta * current_speed, segment_count * segment_length)

	# — steering smoothing (unchanged) —
	smooth_steering = lerp(smooth_steering, steering, clamp(delta * steer_smooth_rate, 0.0, 1.5))
	var speed_factor = clamp(current_speed / max_speed, 0.0, 1.0)

	# ── NEW! Grab the track curve at our current position ───────────
	var seg_index = int(player_z / segment_length) % segment_count
	var track_curve = segments[seg_index].curve

	# Blend toward the track curve + any steering
	if current_speed > 10.0:
		current_curve = lerp(
			current_curve,
			track_curve + smooth_steering * steer_influence * speed_factor,
			0.2
		)
	else:
		current_curve = lerp(current_curve, track_curve, 0.2)

	queue_redraw()

func _draw() -> void:
	var vs = get_viewport_rect().size
	var cx = vs.x * 0.5
	var horizon_y = vs.y * horizon_pct

	var x_off = 0.0
	var dx    = 0.0
	var base_i = int(player_z / segment_length) % segment_count

	for n in range(draw_distance - 1, -1, -1):
		var seg = segments[(base_i + n) % segment_count]
		var next_seg = segments[(base_i + n + 1) % segment_count]

		var rel_z1 = seg.z - player_z
		var rel_z2 = next_seg.z - player_z
		if rel_z1 <= 0.0 or rel_z2 <= 0.0:
			continue

		var scale1 = camera_depth / rel_z1
		var scale2 = camera_depth / rel_z2
		var w1 = road_width * scale1
		var w2 = road_width * scale2
		var y1 = horizon_y + camera_height * scale1
		var y2 = horizon_y + camera_height * scale2
		var x1 = cx + x_off
		var x2 = cx + x_off + dx

		var quad = PackedVector2Array([
			Vector2(x1 - w1, y1),
			Vector2(x1 + w1, y1),
			Vector2(x2 + w2, y2),
			Vector2(x2 - w2, y2)
		])
		draw_polygon(quad, PackedColorArray([seg.color]))

		# Apply the current curve to shift road
		dx -= current_curve * curve_scale
		x_off -= dx

# make sure PI is available (Godot has it built-in)
# make sure PI is available (Godot has it built-in)
func _build_track() -> void:
	segments.clear()
	var z_pos := 0.0
	for i in range(segment_count):
		var seg_color = Color8(105,105,105) if i % 2 == 0 else Color8(115,115,115)

		# ── EASY IN/OUT via sine ramp ──────────────────────────────────
		var curve_val := 0.0
		for def in curve_defs:
			var t : float = (z_pos - def.start) / def.length
			if t >= 0.0 and t <= 1.0:
				# sin(0)=0 at start, sin(pi/2)=1 at mid, sin(pi)=0 at end
				curve_val = def.curve * sin(t * PI)
				break

		segments.append({
			"z":     z_pos,
			"color": seg_color,
			"curve": curve_val
		})
		z_pos += segment_length
