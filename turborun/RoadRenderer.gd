# RoadRenderer.gd (OutRun-style with customizable curves)
extends Node2D
signal track_completed
# Configurable parameters
@export var segment_count: int       = 2000
@export var segment_length: float    = 80.0
@export var road_width: float        = 3500.0
@export var camera_height: float     = 1000.0
@export var camera_depth: float      = 200.0
@export var draw_distance: int       = 250
@export var base_speed: float        = 0.0
@export var max_speed: float         = 700.0
@export var horizon_pct: float       = 0.35
@export var curve_scale: float       = 300.0
@export var steer_influence: float   = 0.0004
@export var steer_smooth_rate: float = 1.0
@export var accel_rate: float        = 0.75
@export var decel_rate: float        = 0.75

# ── Tree parameters ────────────────────────────────────────────────
@export var tree_spacing: int        = 40     # segments between trees
@export var tree_offset: float       = 400.0  # distance from road edge (world units)
@export var tree_size: float         = 600.0  # base size of tree (world units)
@export var tree_color: Color        = Color8(0,200,0)
@export var tree_texture: Texture2D

# ── NEW! Define your bends here ─────────────────────────────────
# Each entry: start Z, length of segment, curvature strength
# e.g. {"start": 1000.0, "length": 2000.0, "curve": 0.0006}
@export var curve_defs: Array[Dictionary] = [
	{ "start":  1000.0, "length": 8000.0, "curve":  0.0002 },
	{ "start":  9000.0, "length": 1000.0, "curve": -0.0002 },
	{ "start":  10000.0, "length": 1000.0, "curve":  0.00008 },
	{ "start":  11000.0, "length": 10000.0, "curve":  0 }
]

# ── NEW exports/vars Finish Line ────────────────────────────────────────────
@export var finish_scene_path: String = ""  # leave blank to quit(), or set to your end‐scene
var finish_z: float = 0.0
var race_finished: bool = false

# Runtime state
var player_z: float               = 0.0
var current_curve: float          = 0.0
var steering: float               = 0.0
var smooth_steering: float        = 0.0
var current_speed: float          = base_speed
var segments: Array[Dictionary]   = []

func _ready() -> void:
	_build_track()

	# ── compute finish line Z ───────────────────────────────────
	finish_z = 0.0
	for def in curve_defs:
		finish_z = max(finish_z, def.start + def.length)

func _process(delta: float) -> void:
	# ── speed & movement ───────────────────────────────────────
	var throttle = Input.is_action_pressed("ui_select")
	var target_speed = max_speed if throttle else base_speed
	var speed_rate = accel_rate if throttle else decel_rate
	current_speed = lerp(current_speed, target_speed, clamp(delta * speed_rate, 0.0, 0.9))
	player_z = fposmod(player_z + delta * current_speed, segment_count * segment_length)

	# ── end‐of‐track check ───────────────────────────────────────
	if not race_finished and player_z >= finish_z:
		race_finished = true
		emit_signal("track_completed")
		if finish_scene_path != "":
			get_tree().change_scene(finish_scene_path)
		else:
			get_tree().quit()
		return

	# ── steering smoothing ───────────────────────────────────────
	smooth_steering = lerp(smooth_steering, steering, clamp(delta * steer_smooth_rate, 0.0, 1.5))
	var speed_factor = clamp(current_speed / max_speed, 0.0, 1.0)

	# ── Continuous track curve (Option 1) ───────────────────────
	var curve_val: float = 0.0
	for def in curve_defs:
		if player_z >= def.start and player_z < def.start + def.length:
			var t: float = (player_z - def.start) / def.length
			curve_val = def.curve * sin(t * PI)
			break

	# ── Blend toward curve + steering ───────────────────────────
	if current_speed > 10.0:
		current_curve = lerp(
			current_curve,
			curve_val + smooth_steering * steer_influence * speed_factor,
			0.2
		)
	else:
		current_curve = lerp(current_curve, curve_val, 0.2)

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

		# Draw a tree if this segment has one
		if seg.get("tree", 0) != 0:
			var tree_x = x1 + seg.tree * (w1 + tree_offset * scale1)
			var tree_y = y1
			var tree_h = tree_size * scale1
			if tree_texture:
				var rect = Rect2(tree_x - tree_h * 0.5, tree_y - tree_h, tree_h, tree_h)
				draw_texture_rect(tree_texture, rect, false)
			else:
				var tw = tree_h * 0.5
				var tri = PackedVector2Array([
					Vector2(tree_x, tree_y - tree_h),
					Vector2(tree_x - tw, tree_y),
					Vector2(tree_x + tw, tree_y)
				])
				draw_polygon(tri, PackedColorArray([tree_color]))

		# Apply the current curve to shift road
		dx -= current_curve * curve_scale
		x_off -= dx

# make sure PI is available (Godot has it built-in)
func _build_track() -> void:
        segments.clear()
        var z_pos := 0.0
        var side := 1
        for i in range(segment_count):
                var seg_color = Color8(105,105,105) if i % 2 == 0 else Color8(115,115,115)
                var seg := {
                        "z": z_pos,
                        "color": seg_color,
                        "tree": 0
                }
                if tree_spacing > 0 and i % tree_spacing == 0:
                        seg.tree = side
                        side = -side
                segments.append(seg)
                z_pos += segment_length
