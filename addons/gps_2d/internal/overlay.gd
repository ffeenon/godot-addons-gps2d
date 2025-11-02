extends Node2D

@onready var _poly: Polygon2D = $Poly

var _mat: ShaderMaterial
var _ground: TileMapLayer

var _origin := Vector2.ZERO   # 网格(0,0)在 overlay 的局部坐标
var _px := Vector2.RIGHT      # 网格 +x 方向一个 cell 的屏幕向量（overlay坐标）
var _py := Vector2.DOWN       # 网格 +y 方向一个 cell 的屏幕向量（overlay坐标）

# =========== 对外 API ===========
func setup(ground: TileMapLayer, color_ok:Color, color_bad:Color) -> void:
	_ground = ground
	# 计算基向量（把 ground 的局部 -> 世界 -> overlay 局部）
	_origin = _grid_to_overlay(Vector2i(0,0))
	_px = _grid_to_overlay(Vector2i(1,0)) - _origin
	_py = _grid_to_overlay(Vector2i(0,1)) - _origin

	# Shader
	_mat = _poly.material as ShaderMaterial
	_poly.visible = false

	# 统一设置与调参
	_mat.set_shader_parameter("u_color_ok", color_ok)
	_mat.set_shader_parameter("u_color_bad", color_bad)

func update_highlighted_footprint(rect: Rect2i, ok: bool) -> void:
	if rect.size == Vector2i.ZERO or _ground == null:
		_poly.visible = false
		return

	# 四个角（网格到 overlay 局部）
	var tl := _origin + _px * rect.position.x + _py * rect.position.y
	var tr := _origin + _px * (rect.position.x + rect.size.x) + _py * rect.position.y
	var br := _origin + _px * (rect.position.x + rect.size.x) + _py * (rect.position.y + rect.size.y)
	var bl := _origin + _px * rect.position.x + _py * (rect.position.y + rect.size.y)

	_poly.polygon = PackedVector2Array([tl, tr, br, bl])
	_poly.visible = true

	# 更新 shader 参数
	_mat.set_shader_parameter("u_ok", ok)

# =========== 工具 ===========
func _grid_to_overlay(cell: Vector2i) -> Vector2:
	var p_local_on_ground := _ground.map_to_local(cell)
	var p_world := _ground.to_global(p_local_on_ground)
	return to_local(p_world)
