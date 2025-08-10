extends Control

@export var road_renderer_path: NodePath = NodePath("../../Node2D")
@onready var road_renderer = get_node_or_null(road_renderer_path)

@export var radius: float = 40.0
@export var thickness: float = 8.0
@export var background_color: Color = Color(0.1, 0.1, 0.1, 0.6)
@export var fill_color: Color = Color(0.2, 1.0, 0.2, 0.9)

var speed_ratio: float = 0.0

func _process(delta: float) -> void:
        if road_renderer:
                speed_ratio = clamp(road_renderer.current_speed / road_renderer.max_speed, 0.0, 1.0)
                queue_redraw()

func _draw() -> void:
        var center = size / 2
        draw_arc(center, radius, 0.0, TAU, 64, background_color, thickness, true)
        draw_arc(center, radius, -PI / 2, -PI / 2 + TAU * speed_ratio, 64, fill_color, thickness, true)
        if road_renderer:
                var font = get_theme_default_font()
                var fsize = get_theme_default_font_size()
                var speed_text = str(int(road_renderer.current_speed))
                var text_size = font.get_string_size(speed_text, fsize)
                draw_string(font, center - text_size / 2, speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE)
