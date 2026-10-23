extends Control

# Stylized in-game district overview. Not a real-world street map.
var expanded := false
var player_position := Vector3.ZERO
var target_position := Vector3(65,0,65)
var heading := 0.0
const MAP_EXTENT := 155.0
const DISTRICTS := [
	"Bektemir","Chilonzor","Yashnobod","Yakkasaroy",
	"Mirzo Ulugbek","Mirobod","Olmazor","Sergeli",
	"Shayxontohur","Uchtepa","Yunusobod","Yangihayot"
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func update_navigation(world_pos: Vector3, destination: Vector3, facing: float) -> void:
	player_position = world_pos
	target_position = destination
	heading = facing
	queue_redraw()

func set_expanded(value: bool) -> void:
	expanded = value
	queue_redraw()

func _draw() -> void:
	var size := get_size()
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.035,0.085,0.12,0.91),true)
	draw_rect(Rect2(Vector2.ZERO,size),Color("59d3db"),false,2.0)
	var pad := 12.0 if not expanded else 24.0
	var area := Rect2(Vector2(pad,pad),size-Vector2(pad*2,pad*2))
	draw_rect(area,Color("243f3a"),true)
	var origin := area.position
	var dimensions := area.size
	# Stylized district sectors; geographic accuracy is not claimed.
	for i in range(1,4):
		var x: float = origin.x+dimensions.x*float(i)/4.0
		var y: float = origin.y+dimensions.y*float(i)/3.0
		draw_line(Vector2(x,origin.y),Vector2(x,origin.y+dimensions.y),Color("52676c"),1.0)
		if i < 3:
			draw_line(Vector2(origin.x,y),Vector2(origin.x+dimensions.x,y),Color("52676c"),1.0)
	for road in [-90.0,0.0,90.0]:
		var x: float = origin.x+(road+MAP_EXTENT)/(MAP_EXTENT*2.0)*dimensions.x
		var y: float = origin.y+(road+MAP_EXTENT)/(MAP_EXTENT*2.0)*dimensions.y
		draw_line(Vector2(x,origin.y),Vector2(x,origin.y+dimensions.y),Color("87999d"),3.0)
		draw_line(Vector2(origin.x,y),Vector2(origin.x+dimensions.x,y),Color("87999d"),3.0)
	if expanded:
		var font := ThemeDB.fallback_font
		for i in range(DISTRICTS.size()):
			var col := i%4
			var line := i/4
			var center := Vector2(origin.x+(float(col)+.5)*dimensions.x/4.0,origin.y+(float(line)+.5)*dimensions.y/3.0)
			draw_string(font,center-Vector2(36,-4),DISTRICTS[i],HORIZONTAL_ALIGNMENT_LEFT,dimensions.x/4.0-6,12,Color("e5f4f0"))
	var p := _project(player_position,area)
	var t := _project(target_position,area)
	draw_line(p,t,Color("f5d16d"),2.5,true)
	draw_circle(t,7.0,Color("f9c34a"))
	draw_arc(t,10.0,0.0,TAU,24,Color.WHITE,2.0)
	draw_circle(p,6.0,Color("48d9f2"))
	var nose := p+Vector2(-sin(heading),-cos(heading))*12.0
	draw_line(p,nose,Color.WHITE,3.0,true)
	if expanded:
		draw_string(ThemeDB.fallback_font,Vector2(24,20),"TOSHKENT RP | 12 TUMAN | GPS",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(24,size.y-7),"Sariq: manzil   Ko'k: siz   M: yopish",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)

func _project(world: Vector3,area: Rect2) -> Vector2:
	return Vector2(area.position.x+clampf((world.x+MAP_EXTENT)/(2.0*MAP_EXTENT),0,1)*area.size.x,area.position.y+clampf((world.z+MAP_EXTENT)/(2.0*MAP_EXTENT),0,1)*area.size.y)
