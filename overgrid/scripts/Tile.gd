class_name Tile
extends Node2D

enum TileType { NORMAL, BOMB, COLOR_BOMB, MULTIPLIER }

const COLORS = [
	Color("#FF4455"),
	Color("#4488FF"),
	Color("#44FF88"),
	Color("#FFDD33"),
	Color("#BB44FF"),
]

const BOMB_BASE_COLOR = Color("#111122")
const BOMB_BORDER_COLOR = Color("#FF6600")
const CBOMB_BASE_COLOR = Color("#F0F0FF")
const CBOMB_BORDER_COLOR = Color("#FF44FF")

var color_id: int = 0
var grid_pos: Vector2i = Vector2i.ZERO
var tile_type: TileType = TileType.NORMAL

@onready var tile_body: Panel = $TileBody
@onready var selection_ring: Panel = $SelectionRing
@onready var bomb_icon: Label = $BombIcon

# ─── Setup ───────────────────────────────
func set_color(id: int) -> void:
	color_id = id
	tile_type = TileType.NORMAL
	bomb_icon.visible = false
	_apply_tile_style(COLORS[id])
	_apply_ring_style(Color(1, 1, 1, 0.35))

func set_as_bomb() -> void:
	tile_type = TileType.BOMB
	color_id = -1
	_apply_tile_style(BOMB_BASE_COLOR, BOMB_BORDER_COLOR, 5)
	_apply_ring_style(Color(1, 0.4, 0.0, 0.5))
	_show_icon("💣", 72)

func set_as_color_bomb() -> void:
	tile_type = TileType.COLOR_BOMB
	color_id = -1
	_apply_tile_style(CBOMB_BASE_COLOR, CBOMB_BORDER_COLOR, 5)
	_apply_ring_style(Color(1, 0.3, 1.0, 0.4))
	_show_icon("★", 80)

func set_as_multiplier(id: int) -> void:
	tile_type = TileType.MULTIPLIER
	color_id = id
	_apply_tile_style(COLORS[id], Color(1, 1, 1, 0.9), 4)
	_apply_ring_style(Color(1, 1, 1, 0.35))
	_show_icon("×2", 52)

# ─── Helpers ─────────────────────────────
func _apply_tile_style(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(20)
	if border_w > 0:
		style.border_color = border
		style.border_width_top = border_w
		style.border_width_bottom = border_w
		style.border_width_left = border_w
		style.border_width_right = border_w
	tile_body.add_theme_stylebox_override("panel", style)

func _apply_ring_style(color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(20)
	selection_ring.add_theme_stylebox_override("panel", style)
	selection_ring.visible = false

func _show_icon(text: String, size: int) -> void:
	bomb_icon.text = text
	bomb_icon.add_theme_font_size_override("font_size", size)
	bomb_icon.visible = true

# ─── State ───────────────────────────────
func is_bomb() -> bool:
	return tile_type == TileType.BOMB

func is_color_bomb() -> bool:
	return tile_type == TileType.COLOR_BOMB

func is_multiplier() -> bool:
	return tile_type == TileType.MULTIPLIER

func set_selected(selected: bool) -> void:
	selection_ring.visible = selected
	if selected:
		_pulse()

func _pulse() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.18, 1.18), 0.08) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12) \
		.set_ease(Tween.EASE_IN)
