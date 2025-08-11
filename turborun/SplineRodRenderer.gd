extends Node2D

# ──────────────────────────────────────────────────────────────────────────────
# Inspector-tweakable parameters
# ──────────────────────────────────────────────────────────────────────────────
@export var path2d_node:       NodePath
@export var segment_count:     int    = 400
@export var segment_length:    float  = 80.0
@export var draw_distance:     int    = 200

@export var road_width:        float  = 2000.0
@export var camera_height:     float  = 1000.0
@export var camera_depth:      float  = 200.0
@export var horizon_pct:       float  = 0.5

@export var bake_interval:     float  = 1.0    # world-space sampling interval

@export var base_speed:        float  =   0.0  # cruise speed
@export var max_speed:         float  = 400.0  # throttle top speed
@export var accel_rate:        float  =   5.0  # accel smoothing
@export var decel_rate:        float  =   2.0  # decel smoothing

@export var steer_speed:       float  = 200.0  # how fast you pan when steering
@export var steer_smooth_rate: float  =   1.5  # smoothing raw steering input

# ──────────────────────────────────────────────────────────────────────────────
# Internal state
# ──────────────────────────────────────────────────────────────────────────────
var segments:       Array  = []      # each: { pos: Vector2, z: float, color: Color }
var player_z:       float  = 0.0
var current_speed:  float  = 0.0
var cam_x:          float  = 0.0
var smooth_steer:   float  = 0.0     # smoothed steering -1..1

func _ready() -> void:
    _build_track()
    set_process(true)
    queue_redraw()

func _process(delta: float) -> void:
    # — throttle/brake with smoothing —
    var throttle: bool       = Input.is_action_pressed("ui_select")
    var target_speed: float  = max_speed if throttle else base_speed
    var rate: float          = accel_rate if throttle else decel_rate
    current_speed = lerp(current_speed, target_speed, clamp(delta * rate, 0.0, 1.0))

    # — advance along track (with wrap) —
    player_z = fposmod(player_z + current_speed * delta,
                       float(segment_count) * segment_length)

    # — raw steering input (1=left, -1=right) —
    var raw_steer: float = 0.0
    if Input.is_action_pressed("ui_left"):
        raw_steer =  1.0
    elif Input.is_action_pressed("ui_right"):
        raw_steer = -1.0

    # — smooth steering —
    smooth_steer = lerp(smooth_steer, raw_steer, clamp(delta * steer_smooth_rate, 0.0, 1.0))
    var steer_offset: float = smooth_steer * steer_speed

    # — figure out which slice is under the camera —
    var base_i: int    = int(player_z / segment_length) % segment_count
    var center_x: float = segments[base_i].pos.x

    # — combine road-center lock + steering pan —
    cam_x = -center_x + steer_offset

    queue_redraw()

func _build_track() -> void:
    segments.clear()

    var path  = get_node(path2d_node) as Path2D
    var curve = path.curve
    curve.bake_interval = bake_interval
    var baked: PackedVector2Array = curve.get_baked_points()
    var max_idx: int = baked.size() - 1

    for i in range(segment_count):
        var dist: float   = float(i) * segment_length
        var raw_i: float  = dist / bake_interval
        var idx: int      = clamp(int(floor(raw_i)), 0, max_idx - 1)
        var frac: float   = raw_i - idx
        var p: Vector2    = baked[idx].lerp(baked[idx + 1], frac)
        var zpos: float   = float(i) * segment_length
        var col: Color    = Color8(105,105,105) if (i % 2 == 0) else Color8(115,115,115)

        segments.append({
            "pos":   p,
            "z":     zpos,
            "color": col
        })

func _draw() -> void:
    var vs: Vector2 = get_viewport_rect().size
    var cx: float  = vs.x * 0.5
    var hy: float  = vs.y * horizon_pct
    var base_i: int = int(player_z / segment_length) % segment_count

    for n in range(draw_distance, 0, -1):
        var seg      = segments[(base_i + n)     % segment_count]
        var next_seg = segments[(base_i + n + 1) % segment_count]

        var rz1: float = seg.z - player_z
        var rz2: float = next_seg.z - player_z
        if rz1 <= 0.0 or rz2 <= 0.0:
            continue

        var s1: float = camera_depth / rz1
        var s2: float = camera_depth / rz2

        var p1: Vector2 = seg.pos
        var p2: Vector2 = next_seg.pos

        # Flat-road projection: ignore spline Y
        var x1: float = cx + (p1.x + cam_x) * s1
        var x2: float = cx + (p2.x + cam_x) * s2
        var y1: float = hy + camera_height * s1
        var y2: float = hy + camera_height * s2

        var w1: float = road_width * s1 * 0.5
        var w2: float = road_width * s2 * 0.5

        var quad = PackedVector2Array([
            Vector2(x1 - w1, y1),
            Vector2(x1 + w1, y1),
            Vector2(x2 + w2, y2),
            Vector2(x2 - w2, y2),
        ])

        draw_polygon(quad, PackedColorArray([seg.color]))

        if n % 20 == 0:
            var m1: Vector2 = (quad[0] + quad[1]) * 0.5
            var m2: Vector2 = (quad[3] + quad[2]) * 0.5
            draw_line(m1, m2, Color(1,1,1), 2)
