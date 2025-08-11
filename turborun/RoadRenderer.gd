# RoadRenderer.gd
# -----------------
# This script renders an "OutRun" style pseudo-3D road using simple
# 2D drawing commands.  The road is made up of lots of flat segments
# that are scaled and shifted each frame to give the illusion of
# perspective.  Plenty of inline comments are provided so that new
# Godot users can understand and adapt the code for their own projects.

extends Node2D

# Emitted when the player reaches the end of the track.  External
# nodes can connect to this to change scenes or show a score screen.
signal track_completed

# ------------------------------------------------------------------
#                      Basic road configuration
# ------------------------------------------------------------------
# Each export variable can be tweaked in the editor to change how the
# road behaves.  Values are expressed in "world" units; nothing here
# deals with pixels directly.

@export var segment_count: int       = 2000   # total number of segments in the looping track
@export var segment_length: float    = 80.0   # length of an individual segment
@export var road_width: float        = 3500.0 # width of the road surface
@export var camera_height: float     = 1000.0 # height of the virtual camera above the road
@export var camera_depth: float      = 200.0  # how far into the distance we project points
@export var draw_distance: int       = 250    # how many segments are drawn each frame
@export var base_speed: float        = 0.0    # speed when the player is not accelerating
@export var max_speed: float         = 2500.0 # maximum speed of the player
@export var horizon_pct: float       = 0.45   # horizon line position relative to screen height
@export var curve_scale: float       = 300.0  # scales how strongly curves bend the road
@export var steer_influence: float   = 0.0003 # strength of player steering on road curvature
@export var steer_smooth_rate: float = 0.8    # smoothing factor for steering input
@export var accel_rate: float        = 0.75   # acceleration lerp rate
@export var decel_rate: float        = 1.0    # deceleration lerp rate

# ------------------------------------------------------------------
#                           Sky parameters
# ------------------------------------------------------------------
# A simple animated sky is drawn above the horizon.  The texture is a
# sprite sheet containing multiple frames.

@export var sky_texture: Texture2D = preload("res://Assets/Scenery/Jupiter.png")
@export var sky_frame_count: int = 8      # number of frames in the sprite sheet
@export var sky_anim_speed: float = 8.0   # animation speed in frames per second

# ------------------------------------------------------------------
#                         Tree decoration
# ------------------------------------------------------------------
# Trees are purely decorative but give the scene depth.  They are
# randomly assigned to segments when the track is built.

@export var tree_spacing: int        = 4     # place a tree every N segments
@export var tree_offset: float       = 400.0 # distance from road edge to tree base
@export var tree_size: float         = 1800.0 # base height of the tree sprite
@export var tree_color: Color        = Color8(0,200,0) # fallback color if texture missing
@export var tree_texture: Texture2D = preload("res://Assets/Scenery/trees.png")
@export var tree_frame_count: int   = 7     # frames in the tree sprite sheet

# ------------------------------------------------------------------
#                      Track curvature definitions
# ------------------------------------------------------------------
# Each dictionary describes a bend in the road:
#   * "start"  – Z position where the curve begins
#   * "length" – how long the curve lasts
#   * "curve"  – strength and direction of the bend
# The sin() function is used later to ease into and out of the bend.

@export var curve_defs: Array[Dictionary] = [
		{ "start":  1000.0, "length":  8000.0, "curve":  0.0002 },
		{ "start":  9000.0, "length": 10000.0, "curve": -0.0003 },
		{ "start": 19000.0, "length": 10000.0, "curve":  0.0003 },
		{ "start": 31000.0, "length":10000.0, "curve":  0.0001 },
		{ "start": 41000.0, "length":100000.0, "curve":  -0.0004 },
		{ "start": 151000.0, "length":10000.0, "curve":  0 } 
]

# ------------------------------------------------------------------
#                           Finish line
# ------------------------------------------------------------------
# When the player's position (player_z) surpasses finish_z the track is
# considered complete.  If a scene path is provided the game will load
# that scene; otherwise the project simply exits.

@export var finish_scene_path: String = ""
var finish_z: float = 0.0        # absolute Z position of the finish line
var race_finished: bool = false  # set true once the finish line is crossed

# ------------------------------------------------------------------
#                         Runtime state
# ------------------------------------------------------------------
# These variables continually change while the game is running.

var player_z: float               = 0.0      # player's Z position along the track
var current_curve: float          = 0.0      # current curve applied to the road
var steering: float               = 0.0      # latest steering input from the car
var smooth_steering: float        = 0.0      # smoothed steering for nicer motion
var current_speed: float          = base_speed
var segments: Array[Dictionary]   = []       # pre-generated road segments
var sky_frame: int                = 0        # which frame of the sky to draw
var sky_frame_time: float         = 0.0      # accumulates time for sky animation

# ------------------------------------------------------------------
#                              Setup
# ------------------------------------------------------------------
func _ready() -> void:
		randomize()           # ensure different random trees each run
		_build_track()        # pre-generate the array of road segments

		# Determine where the finish line is by looking at the furthest
		# end point from our curve definitions.
	# 1) finish at the end of the last curve
		finish_z = 0.0
		for def in curve_defs:
			finish_z = max(finish_z, float(def.start) + float(def.length))

		# 2) ensure we have enough segments to cover finish_z
		var track_len := float(segment_count) * segment_length
		if track_len < finish_z:
			segment_count = int(ceil(finish_z / segment_length)) + 1
			_build_track()  # rebuild with the larger count

# ------------------------------------------------------------------
						 #                       Per-frame update
# ------------------------------------------------------------------
func _process(delta: float) -> void:
		# -- Speed and forward movement --
		# Holding "ui_select" acts as the accelerator.
		var throttle = Input.is_action_pressed("ui_select")
		var target_speed = max_speed if throttle else base_speed
		var speed_rate = accel_rate if throttle else decel_rate
		current_speed = lerp(current_speed, target_speed, clamp(delta * speed_rate, 0.0, 0.9))

		# Advance the player along the track.  fposmod keeps the value
		# within the total length so the road loops forever.
		#player_z = fposmod(player_z + delta * current_speed, segment_count * segment_length)
		# 3) advance with NO wrap
		player_z += current_speed * delta

		# optional: slow down near finish
		if finish_z - player_z < 2000.0: current_speed = min(current_speed, 600.0)
		# -- Finish line check --
		if not race_finished and player_z >= finish_z:
				race_finished = true
				emit_signal("track_completed")
				if finish_scene_path != "":
						get_tree().change_scene(finish_scene_path)
				else:
						get_tree().quit()
				return

		# -- Steering smoothing --
		smooth_steering = lerp(smooth_steering, steering, clamp(delta * steer_smooth_rate, 0.0, 1.5))
		var speed_factor = clamp(current_speed / max_speed, 0.0, 1.0)

		# -- Determine road curvature based on player position --
		var curve_val: float = 0.0
		for def in curve_defs:
				if player_z >= def.start and player_z < def.start + def.length:
						var t: float = (player_z - def.start) / def.length
						# Smoothly ease into and out of the curve
						curve_val = def.curve * sin(t * PI)
						break

		# -- Blend the current curve with steering influence --
		if current_speed > 10.0:
				current_curve = lerp(
						current_curve,
						curve_val + smooth_steering * steer_influence * speed_factor,
						0.2
				)
		else:
				current_curve = lerp(current_curve, curve_val, 0.2)

		# Update the sky animation frame
		if sky_anim_speed > 0:
				sky_frame_time += delta
				if sky_frame_time >= 1.0 / sky_anim_speed:
						sky_frame_time = 0.0
						sky_frame = (sky_frame + 1) % sky_frame_count

		queue_redraw()  # request a call to _draw() next frame

# ------------------------------------------------------------------
#                          Drawing routine
# ------------------------------------------------------------------
func _draw() -> void:
	var vs: Vector2 = get_viewport_rect().size
	var cx: float = vs.x * 0.5                 # screen centre X
	var horizon_y: float = vs.y * horizon_pct  # horizon line Y

	# ----- draw the animated sky -----
	if sky_texture:
		var sky_f_w: float = sky_texture.get_width() / float(sky_frame_count)
		var sky_f_h: float = sky_texture.get_height()
		var scale: float = horizon_y / sky_f_h
		var sky_w: float = sky_f_w * scale
		var x: float = 0.0
		while x < vs.x:
			var src := Rect2(sky_f_w * sky_frame, 0, sky_f_w, sky_f_h)
			var dest := Rect2(x, 0, sky_w, horizon_y)
			draw_texture_rect_region(sky_texture, dest, src)
			x += sky_w

	# Pre-calc tree frame size for later use
	var frame_w: float = 0.0
	var frame_h: float = 0.0
	if tree_texture:
		frame_w = tree_texture.get_width() / float(tree_frame_count)
		frame_h = tree_texture.get_height()

	var x_off: float = 0.0     # horizontal offset from curves
	var dx: float = 0.0        # incremental change in offset
	var base_i: int = int(player_z / segment_length)

	# --- NEW: limit draw distance to finish line ---
	var remaining: float = max(finish_z - player_z, 0.0)
	var max_slices: int = min(draw_distance, int(ceil(remaining / segment_length)))
	var last_i: int = min(base_i + max_slices, segment_count - 1)

	# Render from farthest to nearest so nearer ones draw over
	for i in range(last_i - 1, base_i - 1, -1):
		var seg: Dictionary = segments[i]
		var next_seg: Dictionary = segments[i + 1]

		var rel_z1: float = seg.z - player_z
		var rel_z2: float = next_seg.z - player_z
		if rel_z1 <= 0.0 or rel_z2 <= 0.0:
			continue  # behind the player

		# Convert 3D segment endpoints to 2D screen values
		var scale1: float = camera_depth / rel_z1
		var scale2: float = camera_depth / rel_z2
		var w1: float = road_width * scale1
		var w2: float = road_width * scale2
		var y1: float = horizon_y + camera_height * scale1
		var y2: float = horizon_y + camera_height * scale2
		var x1: float = cx + x_off
		var x2: float = cx + x_off + dx

		# Draw the road quad for this segment
		var quad := PackedVector2Array([
			Vector2(x1 - w1, y1),
			Vector2(x1 + w1, y1),
			Vector2(x2 + w2, y2),
			Vector2(x2 - w2, y2)
		])
		draw_polygon(quad, PackedColorArray([seg.color]))

		# ---- optional tree drawing ----
		if seg.get("tree", 0) != 0:
			var tree_x: float = x1 + seg.tree * (w1 + tree_offset * scale1)
			var tree_y: float = y1
			var tree_h: float = tree_size * scale1
			if tree_texture:
				var frame_idx: int = seg.get("tree_frame", 0)
				var src_tree := Rect2(frame_w * frame_idx, 0, frame_w, frame_h)
				var dest_w: float = tree_h * (frame_w / frame_h)
				var rect := Rect2(tree_x - dest_w * 0.5, tree_y - tree_h, dest_w, tree_h)
				draw_texture_rect_region(tree_texture, rect, src_tree)
			else:
				var tw: float = tree_h * 0.5
				var tri := PackedVector2Array([
					Vector2(tree_x, tree_y - tree_h),
					Vector2(tree_x - tw, tree_y),
					Vector2(tree_x + tw, tree_y)
				])
				draw_polygon(tri, PackedColorArray([tree_color]))

		# Apply the current curve to shift the road sideways
		dx -= current_curve * curve_scale
		x_off -= dx                          

# ------------------------------------------------------------------
#                     Segment data generation
# ------------------------------------------------------------------
func _build_track() -> void:
		segments.clear()
		var z_pos := 0.0
		var side := 1  # used to alternate tree placement left/right
		for i in range(segment_count):
				var seg_color = Color8(105,105,105) if i % 2 == 0 else Color8(115,115,115)
				var seg := {
						"z": z_pos,        # world Z position of this segment
						"color": seg_color,
						"tree": 0          # 0 means no tree on this segment
				}
				if tree_spacing > 0 and i % tree_spacing == 0:
						seg.tree = side
						seg.tree_frame = randi() % tree_frame_count
						side = -side       # next tree goes on the other side
				segments.append(seg)
				z_pos += segment_length
