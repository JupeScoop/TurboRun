extends Control

@export var road_renderer_path: NodePath = NodePath("../Node2D")
@onready var road_renderer = get_node_or_null(road_renderer_path)

@export var radius: float = 40.0
@export var thickness: float = 8.0
@export var background_color: Color = Color(0.1, 0.1, 0.1, 0.6)
@export var fill_color: Color = Color(0.2, 1.0, 0.2, 0.9)

var speed_ratio: float = 0.0

func _ready() -> void:
	# run + draw at least once
	set_process(true)
	queue_redraw()

	# fixed size for the circle we draw
	var s := Vector2((radius + thickness) * 2.0, (radius + thickness) * 2.0)
	custom_minimum_size = s
	size = s

	# stick to bottom-left of the viewport (16 px padding)
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	position = Vector2(75, 525)   # x: from left, y: from bottom (negative goes up)


func _process(delta: float) -> void:
	if road_renderer:
		speed_ratio = clamp(road_renderer.current_speed / max(road_renderer.max_speed, 0.0001), 0.0, 1.0)
	else:
		speed_ratio = 0.0
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5

	# Background ring (full circle)
	draw_arc(center, radius, 0.0, TAU, 64, background_color, thickness, true)

	# Filled arc (speed)
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * speed_ratio, 64, fill_color, thickness, true)

	# Optional text
	if road_renderer:
		var font := get_theme_default_font()
		var fsize := get_theme_default_font_size()
		var speed_text := str(int(road_renderer.current_speed))
		# Correct Godot 4 signature: (text, alignment, width, font_size)
		var text_size := font.get_string_size(speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize)
		draw_string(font, center - text_size * 0.5, speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize)
