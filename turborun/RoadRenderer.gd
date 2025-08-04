extends Node2D

# Configurable parameters
@export var segment_count: int     = 2000
@export var segment_length: float  = 80.0
@export var road_width: float      = 3000.0
@export var camera_height: float   = 1000.0
@export var camera_depth: float    = 200.0
@export var draw_distance: int     = 200
@export var speed: float           = 200.0
@export var horizon_pct: float     = 0.4
@export var curve_scale: float     = 300.0    # increased for more visible bend
@export var steer_influence: float = 0.00018  # positive influence: right turns bend right, left bends left    # stronger steering effect

# Runtime state
var player_z: float             = 0.0
var current_curve: float        = 0.0
var steering: float             = 0.0
var segments: Array[Dictionary] = []

func _ready() -> void:
	_build_track()

func _process(delta: float) -> void:
	# Advance along track
	var total_length = segment_count * segment_length
	player_z = fposmod(player_z + delta * speed, total_length)

	# Blend natural curve + steering
	var base_curve = sin(player_z * 0.0015) * 0.00015
	current_curve = lerp(current_curve, base_curve + steering * steer_influence, 0.2)  # steering + for right, - for left
	# ensure left turns curve left: steering is -1 for left  # quicker response

	queue_redraw()

func _draw() -> void:
	var vs = get_viewport_rect().size
	var cx = vs.x * 0.5
	var horizon_y = vs.y * horizon_pct

	var x_off = 0.0
	var dx = 0.0
	var base_i = int(player_z / segment_length) % segment_count

	for n in range(draw_distance - 1, -1, -1):
		var seg = segments[(base_i + n) % segment_count]
		var next_seg = segments[(base_i + n + 1) % segment_count]

		var rel_z1 = seg.z - player_z
		var rel_z2 = next_seg.z - player_z
		if rel_z1 <= 0 or rel_z2 <= 0:
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

		dx -= current_curve * curve_scale  # invert sign so left steering moves road left, right steering moves road right
		x_off -= dx

func _build_track() -> void:
	segments.clear()
	var z_pos = 0.0
	for i in range(segment_count):
		var seg_color = Color8(105,105,105) if i % 2 == 0 else Color8(115,115,115)
		segments.append({"z": z_pos, "color": seg_color})
		z_pos += segment_length
