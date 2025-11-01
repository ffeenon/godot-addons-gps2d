extends TileMapLayer

var _src_id: int = 0
var _atlas_ok: Vector2i = Vector2i(0,0)
var _atlas_bad: Vector2i = Vector2i(0,1)

func update_highlighted_footprint(rect: Rect2i, ok: bool):
	clear()
	if rect.size == Vector2i.ZERO: return
	
	var atlas = _atlas_ok if ok else _atlas_bad
	var p:=rect.position
	var s:=rect.size
	for y in s.y:
		var gy : = p.y + y
		for x in s.x:
			var gx = p.x + x
			set_cell(Vector2i(gx, gy), _src_id, atlas)
