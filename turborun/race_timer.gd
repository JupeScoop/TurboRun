extends Label

@export var road_renderer_path: NodePath = NodePath("../Node2D")
@onready var road_renderer = get_node_or_null(road_renderer_path)

var elapsed: float = 0.0
var running: bool = false

func _process(delta: float) -> void:
        if road_renderer:
                if not running and road_renderer.current_speed > 0.1:
                        running = true
                if running:
                        elapsed += delta
        var minutes = int(elapsed) / 60
        var seconds = int(elapsed) % 60
        text = "%02d:%02d" % [minutes, seconds]
