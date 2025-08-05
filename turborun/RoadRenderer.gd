# RoadRenderer.gd (OutRun-style with Throttle & Smooth Deceleration)
extends Node2D

@export var segment_count: int    = 2000
@export var segment_length: float = 80.0
@export var road_width: float     = 3000.0
@export var camera_height: float  = 1000.0
@export var camera_depth: float   = 200.0
@export var draw_distance: int    = 250
@export var base_speed: float     = 0.0    # cruise speed
@export var max_speed: float      = 800.0    # top speed when fully throttled
@export var horizon_pct: float    = 0.4
@export var curve_scale: float    = 300.0    # bend visibility
@export var steer_influence: float= 0.00006    # steering effect
@export var accel_rate: float     = 5.0      # how quickly speed adjusts
@export var decel_rate: float     = 2.0      # deceleration strength when no throttle

var player_z: float              = 0.0
var current_curve: float         = 0.0
var steering: float              = 0.0
var current_speed: float         = base_speed
var segments: Array[Dictionary]  = []

func _ready() -> void:
	_build_track()

func _process(delta: float) -> void:
	# Determine desired speed
	var throttle = Input.is_action_pressed("ui_select")
	var target_speed: float = max_speed if throttle else base_speed

	# Smoothly move current_speed toward target_speed
	var rate: float = accel_rate if throttle else decel_rate
	current_speed = lerp(current_speed, target_speed, clamp(delta * rate, 0.0, 1.0))

	# Advance along track
	var total_length = segment_count * segment_length
	player_z = fposmod(player_z + delta * current_speed, total_length)

	# Blend natural curve + steering
	var base_curve = sin(player_z * 0.0015) * 0.00015
	current_curve = lerp(current_curve, base_curve + steering * steer_influence, 0.2)

	queue_redraw()

func _draw() -> void:
	var vs = get_viewport_rect().size
	var cx = vs.x * 0.5
	var hy = vs.y * horizon_pct

	var x_off = 0.0
	var dx = 0.0
	var base_i = int(player_z / segment_length) % segment_count

	for n in range(draw_distance - 1, -1, -1):
		var seg = segments[(base_i + n) % segment_count]
		var next_seg = segments[(base_i + n + 1) % segment_count]
		var rz1 = seg.z - player_z
		var rz2 = next_seg.z - player_z
		if rz1 <= 0 or rz2 <= 0:
			continue
		var s1 = camera_depth / rz1
		var s2 = camera_depth / rz2
		var w1 = road_width * s1
		var w2 = road_width * s2
		var y1 = hy + camera_height * s1
		var y2 = hy + camera_height * s2
		var x1 = cx + x_off
		var x2 = cx + x_off + dx
		var quad = PackedVector2Array([
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
	var z = 0.0
	for i in range(segment_count):
		var c = Color8(105,105,105) if i % 2 == 0 else Color8(115,115,115)
		segments.append({"z":z, "color":c})
		z += segment_length
