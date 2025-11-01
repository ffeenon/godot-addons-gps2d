extends Node
class_name Gps2d

# ---------------- external exports/configs ----------------
@export var _ground:TileMapLayer

# ---------------- exposed signals ----------------

# ---------------- preload module internal class ----------------
const _Occupancy := preload("res://addons/gps_2d/internal/occupancy.gd")
const _Overlay := preload("res://addons/gps_2d/internal/overlay.gd")

# ---------------- const ----------------
const _ZERO_RECT := Rect2i(0,0,0,0)
const _INVALID_CELL := Vector2i(-(1 << 63), -(1 << 63)) # max int
const _TAP_THRESHOLD_MS := 300   # 毫秒
const _INVALID_TOUCH_ID := -1

# ---------------- init ----------------
@onready var _occupancy :_Occupancy = _Occupancy.new()
@onready var _overlay: _Overlay = $Overlay

# ---------------- states ----------------
var _last_drag_cell: Vector2i = _INVALID_CELL
var _drag_start_cell: Vector2i = _INVALID_CELL
var _drag_start_footprint: Rect2i = _ZERO_RECT
var _last_press_cell :Vector2i = _INVALID_CELL
var _last_press_time_ms := 0.0
var _drag_id := _INVALID_TOUCH_ID
var _occupant:_Occupancy.Occupant:
	set(value):
		if _occupant == value: return
		if _occupant != null:
			var is_rect_valid = !_occupancy.any_occupied(_occupant.rect)
			if is_rect_valid:
				_occupancy.attach(_occupant)
				_footprint = _occupant.rect # 更新instance位置
			else:
				_occupant.instance.queue_free()
			_occupant = null
			_footprint = _ZERO_RECT
		if value != null:
			_occupant = value
			if _occupancy.has_occupant(_occupant): _occupancy.detach(_occupant)
			_footprint = _occupant.rect

		

var _footprint:Rect2i = _ZERO_RECT: # instance 位置依赖_footprint 更新
	set(value):
		if _footprint != value:
			_footprint = value

			var ok := !_occupancy.any_occupied(value)
			_overlay.update_highlighted_footprint(value, ok)
			if _footprint != _ZERO_RECT:
				_occupant.instance.global_position = _squre_world_center(_footprint)

			
# ---------------- exposed funcs ----------------
func add(data: Gps2dPlaceableData, find_free_area := true):
	_occupant = null
	
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
	var occupant = _Occupancy.Occupant.new(instance, rect)
	get_tree().root.add_child.call_deferred(instance)
	await instance.ready
	_occupant = occupant


# ---------------- lifecycle funcs ----------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		var world_pos := _get_world_pos_in_touch_pos(event.position)
		var ground_local_pos = _ground.to_local(world_pos)
		var ground_cell := _ground.local_to_map(ground_local_pos)
		var pressed_occupant = _get_pressed_occupant(ground_cell)
		
		
		if event is InputEventScreenTouch:
			if event.pressed:
				_last_press_cell = ground_cell
				_last_press_time_ms = Time.get_ticks_msec()
				
				if pressed_occupant != null and pressed_occupant == _occupant:
					# start dragging
					_drag_id = event.index
					_drag_start_cell = ground_cell
					_last_drag_cell = ground_cell
					_drag_start_footprint = _footprint
			else:
				var is_press_same_cell = _last_press_cell == ground_cell
				var short_enough = Time.get_ticks_msec() - _last_press_time_ms < _TAP_THRESHOLD_MS
				var is_tap := is_press_same_cell and short_enough
				
				
				if event.index == _drag_id:
					# stop dragging
					_drag_id = _INVALID_TOUCH_ID
					_drag_start_cell = _INVALID_CELL
					_last_drag_cell = _INVALID_CELL
					_try_update_rect()

				if is_tap:
					if _occupant != null and _occupancy.any_occupied(_footprint): # 限制更换目标
						return
					_occupant = pressed_occupant

		elif event is InputEventScreenDrag:
			if event.index != _drag_id: return
			
			# dragging
			if ground_cell == _last_drag_cell: return
			_last_drag_cell = ground_cell
			var rect:=_footprint
			rect.position = _drag_start_footprint.position + ground_cell - _drag_start_cell
			_footprint = rect

# ---------------- helper funcs ----------------
#func _set_occupant(occupant: _Occupancy.Occupant):
	#if _occupant == occupant: return
	#_occupant = occupant
	#if _occupancy.has_occupant(_occupant): _occupancy.detach(occupant)
	#_footprint = occupant.rect
#
#func _clear_occupant(has_valid_area = true):
	#var is_rect_valid = !_occupancy.any_occupied(_occupant.rect)
	#
	#if is_rect_valid:
		#_occupancy.attach(_occupant)
	#else:
		#_occupant.instance.queue_free()
	#_occupant = null
	#_footprint = _ZERO_RECT

func _try_update_rect():
	if not _occupancy.any_occupied(_footprint):
		_occupant.rect = _footprint

func _get_pressed_occupant(cell:Vector2i) -> _Occupancy.Occupant:
	if _occupant != null and _cell_in_rect(cell, _footprint): return _occupant

	return _occupancy.get_occupant(cell)

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
		var occupant := _occupancy.get_occupant(cell)
		if occupant != null:
			occupants.append(occupant)
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

func _cell_in_rect(cell:Vector2i, rect: Rect2i):
	return cell.x >= rect.position.x and cell.x <= rect.position.x + rect.size.x - 1 and cell.y >= rect.position.y and cell.y <= rect.position.y + rect.size.y - 1
