extends Node
class_name Gps2d

# ---------------- external exports/configs ----------------
@export var _ground:TileMapLayer

# ---------------- exposed signals ----------------

# ---------------- preload module internal class ----------------
const _Occupancy := preload("res://addons/gps_2d/internal/occupancy.gd")
const _OverlayTml := preload("res://addons/gps_2d/internal/overlay_tml.gd")

# ---------------- const ----------------
const _INVALID_CELL := Vector2i(-(1 << 63), -(1 << 63)) # max int
const _TAP_THRESHOLD_MS := 300   # 毫秒
const _INVALID_TOUCH_ID := -1
const _ZERO_RECT := Rect2i(0,0,0,0)

# ---------------- init ----------------
@onready var _occupancy :_Occupancy = _Occupancy.new()
@onready var _tml: _OverlayTml = $TML

# ---------------- states ----------------
var _last_press_cell :Vector2i = _INVALID_CELL
var _last_press_time_ms := 0.0
var _last_cell: Vector2i = _INVALID_CELL
var _drag_id := _INVALID_TOUCH_ID
var _press_occupant: _Occupancy.Occupant = null

var _occupant:_Occupancy.Occupant

var _footprint:Rect2i = _ZERO_RECT:
	set(value):
		if _footprint == value: return
		_footprint = value
		var ok := !_occupancy.any_occupied(value)
		_tml.update_highlighted_footprint(value, ok)

# ---------------- exposed funcs ----------------
func add(data: Gps2dPlaceableData, find_free_area := true):
	var size := data.size
	var size_v := Vector2i(size,size)
	
	var center_cell := _screen_center_cell()
	
	var anchor: Vector2i = (
		_find_nearest_free_anchor(center_cell, size)
		if find_free_area
		else _anchor_from_center_cell(center_cell, size)
	)
	
	var rect = Rect2i(anchor, size_v)
	var instance:= data.scene.instantiate()
	instance.global_position = _squre_world_center(rect)
	var occupant = _occupancy.add(instance, rect)
	get_tree().root.add_child.call_deferred(instance)
	await instance.ready
	_occupant = occupant

# ---------------- lifecycle funcs ----------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		var world_pos := _get_world_pos_in_touch_pos(event.position)
		var ground_local_pos = _ground.to_local(world_pos)
		var ground_cell := _ground.local_to_map(ground_local_pos)
		var occupant = _get_occupant_around_cell(ground_cell)
		
		if event is InputEventScreenTouch:
			if event.pressed:
				_last_press_cell = ground_cell
				_last_press_time_ms = Time.get_ticks_msec()
				_last_cell = _INVALID_CELL 
				_press_occupant = occupant
				
				if occupant != null and occupant == _occupant:
					# start dragging
					_drag_id = event.index
					if _footprint == _ZERO_RECT:
						_occupancy.detach_by_id(occupant.id)
						_footprint = occupant.rect
			else:
				var is_same_cell = _last_press_cell == ground_cell
				var short_enough = Time.get_ticks_msec() - _last_press_time_ms < _TAP_THRESHOLD_MS
				var is_tap := is_same_cell and short_enough
				if event.index == _drag_id:
					# stop dragging
					_drag_id = _INVALID_TOUCH_ID
					if not _occupancy.any_occupied(_footprint):
						_occupancy.attach(_occupant.id, _footprint)
						_footprint = _ZERO_RECT
				elif is_tap:
					# set occupant
					_occupant = _press_occupant
				_press_occupant = null
		elif event is InputEventScreenDrag:
			if event.index != _drag_id:
				
				return
			# dragging
			if ground_cell == _last_cell: 
				return
			_last_cell = ground_cell
			var rect:=_occupant.rect
			rect.position += ground_cell - _last_press_cell
			if _footprint != rect:
				_footprint = rect
				_occupant.instance.global_position = _squre_world_center(rect)
				#todo 更新四角箭头

# ---------------- helper funcs ----------------
func _get_occupant_around_cell(cell:Vector2i) -> _Occupancy.Occupant:
	var adjacent_cells := _get_adjacent_cells(cell)
	var cells:Array[Vector2i] = [cell]
	cells.append_array(adjacent_cells)
	
	var occupants := _get_occupants_from_cells(cells)

	if occupants.size() == 0:
		return null
	else:
		if _occupant in occupants:
			return _occupant
		else : return occupants[0]

func _squre_world_center(square: Rect2i) -> Vector2:
	#return _ground.to_global(_ground.map_to_local(square.get_center()))
	var tl := _ground.map_to_local(square.position)
	var br := _ground.map_to_local(square.position + square.size - Vector2i.ONE)
	return _ground.to_global((tl + br) * 0.5)

func _get_world_pos_in_touch_pos(touch_pos:Vector2) -> Vector2:
	return get_viewport().canvas_transform.affine_inverse() * touch_pos

func _get_adjacent_cells(cell: Vector2i) -> Array[Vector2i]:
	var r:Array[Vector2i] = []
	r.append(Vector2i(cell.x + 1, cell.y))
	r.append(Vector2i(cell.x, cell.y + 1))
	r.append(Vector2i(cell.x - 1, cell.y))
	r.append(Vector2i(cell.x, cell.y - 1))
	return r

func _get_occupants_from_cells(cells: Array[Vector2i]) -> Array[_Occupancy.Occupant]:
	var occupants:Array[_Occupancy.Occupant] = []
	for cell in cells:
		var id := _occupancy.get_id_at(cell)
		var o := _occupancy.get_occupant(id)
		if o != null:
			occupants.append(o)
	return occupants

func _screen_center_cell() -> Vector2i:
	var vp := get_viewport()
	var screen_center := vp.get_visible_rect().size * 0.5
	var world_center := _get_world_pos_in_touch_pos(screen_center)
	return _ground.local_to_map(_ground.to_local(world_center))

# 给定“中心格 + 边长s”，求 footprint 的左上锚点
# 说明：s 为偶数时，几何中心会落在四格交点，无法精确对齐到单一 cell 中心，这是等轴/网格的客观限制。
func _anchor_from_center_cell(c: Vector2i, s: int) -> Vector2i:
	return c - Vector2i((s - 1) >> 1, (s - 1) >> 1)

# 以屏幕中心为起点做曼哈顿“环形”搜索最近可用锚点
func _find_nearest_free_anchor(center_cell: Vector2i, s: int, max_r: int = 64) -> Vector2i:
	var size_v := Vector2i(s, s)

	# r = 0（中心）
	var a0 := _anchor_from_center_cell(center_cell, s)
	if not _occupancy.any_occupied(Rect2i(a0, size_v)):
		return a0

	# r >= 1 的环：|dx| + |dy| = r
	for r in range(1, max_r + 1):
		for dx in range(-r, r + 1):
			var dy : int = r - abs(dx)
			# 上/下两个点；dy==0 时避免重复检查
			var c1 := center_cell + Vector2i(dx,  dy)
			var a1 := _anchor_from_center_cell(c1, s)
			if not _occupancy.any_occupied(Rect2i(a1, size_v)):
				return a1
			if dy != 0:
				var c2 := center_cell + Vector2i(dx, -dy)
				var a2 := _anchor_from_center_cell(c2, s)
				if not _occupancy.any_occupied(Rect2i(a2, size_v)):
					return a2

	# 找不到就回退中心
	return a0
