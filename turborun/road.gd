extends Node2D

const SEGMENT_COUNT: int = 200
const ROAD_WIDTH: float = 2000.0
const CAMERA_DEPTH: float = 1.0
const CAMERA_HEIGHT: float = 1000.0
const DRAW_DISTANCE: float = 1000.0
const ROAD_LENGTH: float = 10000.0

var player_pos_z: float = 0.0
var current_curve: float = 0.0
var steering_input: float = 0.0
const STRIPE_LENGTH: float = 80.0

func _process(delta: float) -> void:
    # Match the camera's position
    position = get_viewport().get_camera_2d().global_position

    player_pos_z += delta * 200.0
    if player_pos_z > ROAD_LENGTH:
        player_pos_z = 0.0

    var base_curve = sin(player_pos_z * 0.0025) * 0.0006  # Dynamic track curve
    var steer_curve = steering_input * 0.0004          # Player influence
    current_curve = lerp(current_curve, base_curve + steer_curve, 0.1)

    # ✅ This triggers _draw(), valid in Node2D / CanvasItem
    queue_redraw()

func set_steering(dir: int) -> void:
    steering_input = clamp(dir, -1, 1)

func _draw() -> void:
    var viewport_size := get_viewport_rect().size
    var screen_center_x = viewport_size.x / 2
    var screen_center_y = viewport_size.y / 2

    var x_offset: float = 0.0
    var dx: float = 0.0
    var y_offset = viewport_size.y * 0.6

    const stripe_spacing: float = 60.0

    for i in range(SEGMENT_COUNT):
        var z1: float = (i / SEGMENT_COUNT) * DRAW_DISTANCE + 1.0
        var z2: float = ((i + 1) / SEGMENT_COUNT) * DRAW_DISTANCE + 1.0

        var elevation1 = sin((player_pos_z + z1) * 0.001) * 150
        var elevation2 = sin((player_pos_z + z2) * 0.001) * 150

        var scale1: float = CAMERA_DEPTH / z1
        var scale2: float = CAMERA_DEPTH / z2

        var road_w1: float = ROAD_WIDTH * scale1
        var road_w2: float = ROAD_WIDTH * scale2

        var y1: float = -y_offset + CAMERA_HEIGHT * scale1 - elevation1
        var y2: float = -y_offset + CAMERA_HEIGHT * scale2 - elevation2

        var x1: float = screen_center_x + x_offset
        var x2: float = screen_center_x + x_offset + dx

        # === Alternating stripe color based on world Z position ===
        var stripe_index = int((player_pos_z + i * stripe_spacing) / stripe_spacing)
        var color: Color
        if stripe_index % 2 == 0:
            color = Color("gray")
        else:
            color = Color("lightgray")

        # === Draw road polygon ===
        var road_points := PackedVector2Array([
            Vector2(x1 - road_w1, y1),
            Vector2(x1 + road_w1, y1),
            Vector2(x2 + road_w2, y2),
            Vector2(x2 - road_w2, y2)
        ])
        draw_polygon(road_points, PackedColorArray([color]))

        
        # Update curvature
        dx += current_curve * 200.0
        x_offset -= dx
