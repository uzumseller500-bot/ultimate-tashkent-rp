extends Node3D

# ULTIMATE TASHKENT RP — minimal, self-contained Godot 4.x prototype.
# All geometry is procedural. No external assets, servers or plugins required.

const WALK_SPEED := 8.0
const DRIVE_SPEED := 23.0
const CITY_EXTENT := 155.0

var player: CharacterBody3D
var car: Node3D
var camera: Camera3D
var ui: CanvasLayer
var information: Label
var mission_label: Label
var coins_label: Label
var action_button: Button
var touch_pad: Control
var car_mode := false
var cash := 500
const SAVE_PATH := "user://tashkent_rp_save.json"
var speed_label: Label
var save_label: Label
var car_velocity := 0.0
var engine_time := 0.0
var mission_stage := 0
var mission_target := Vector3(65, 0, 65)
var view_yaw := 0.0
var view_pitch := -0.30
var car_angle := 0.0
var controls := {"forward":false,"back":false,"left":false,"right":false,"run":false}
var look_pointer := -1
var last_look := Vector2.ZERO
var mouse_look := false
var mission_marker: MeshInstance3D
var city_materials: Array[Material] = []

func _ready() -> void:
	_load_game()
	_make_world()
	_make_player()
	_make_car()
	_make_marker()
	_make_ui()
	_update_status()
	# Do not capture the mouse: it should be playable using a normal mouse and touchscreen.

func _mat(color: Color, rough: float = 0.82) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _box(parent: Node3D, name: String, pos: Vector3, size: Vector3, material: Material, solid: bool = false) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = pos
	mesh_node.material_override = material
	parent.add_child(mesh_node)
	if solid:
		var collider := StaticBody3D.new()
		mesh_node.add_child(collider)
		var shape := CollisionShape3D.new()
		var shape_box := BoxShape3D.new()
		shape_box.size = size
		shape.shape = shape_box
		collider.add_child(shape)
	return mesh_node

func _cylinder(parent: Node3D, name: String, pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node

func _make_world() -> void:
	var env := WorldEnvironment.new()
	var res := Environment.new()
	res.background_mode = Environment.BG_COLOR
	res.background_color = Color("8bbdd5")
	res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	res.ambient_light_color = Color("d5e3e9")
	res.ambient_light_energy = 0.52
	res.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = res
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -34, 0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	add_child(sun)
	var ground := _mat(Color("65866a"))
	var asphalt := _mat(Color("303840"))
	var side := _mat(Color("b2b5ac"))
	var stripe := _mat(Color("f1da95"))
	var trunk := _mat(Color("684a36"))
	var leaf := _mat(Color("317e59"))
	var glass := _mat(Color("60a6b6"), 0.26)
	var concrete := _mat(Color("d9cfba"))
	var red := _mat(Color("ba6c5c"))
	var blue := _mat(Color("83a7b8"))
	var white := _mat(Color("cbd2d0"))
	var gold := _mat(Color("c5a45b"))
	_box(self, "Land", Vector3(0, -0.25, 0), Vector3(360,0.5,360), ground, true)
	# Broad north-south and east-west arterial roads, walkable pavements and lane marks.
	for pos in [-90.0, 0.0, 90.0]:
		_box(self, "East-west road", Vector3(0,0.018,pos), Vector3(330,0.04,22), asphalt)
		_box(self, "North-south road", Vector3(pos,0.025,0), Vector3(22,0.04,330), asphalt)
		for i in range(-15,16):
			_box(self, "Lane", Vector3(i*10.0,0.055,pos), Vector3(4,0.015,0.23), stripe)
			_box(self, "Lane", Vector3(pos,0.06,i*10.0), Vector3(0.23,0.015,4), stripe)
		for margin in [-14.0,14.0]:
			_box(self, "Sidewalk", Vector3(0,0.1,pos+margin), Vector3(330,0.2,4), side)
			_box(self, "Sidewalk", Vector3(pos+margin,0.1,0), Vector3(4,0.2,330), side)
	# Low-poly Tashkent-inspired blocks, apartment towers, office glass and park trees.
	var facade := [concrete, red, blue, white, glass]
	for ix in range(-3,4):
		for iz in range(-3,4):
			var x := ix * 43.0 + 23.0
			var z := iz * 43.0 + 23.0
			if absf(x) < 18.0 or absf(z) < 18.0:
				continue
			if absf(x - 65.0) < 17.0 and absf(z - 65.0) < 17.0:
				continue
			if (ix + iz) % 4 == 0:
				for t in range(4):
					var ax := x + (t%2)*12.0 - 5.0
					var az := z + (t/2)*12.0 - 5.0
					_cylinder(self, "Tree trunk", Vector3(ax,1.6,az), 0.35,3.2,trunk)
					_cylinder(self, "Tree canopy", Vector3(ax,4.4,az), 2.4,3.4,leaf)
			else:
				var h := 11.0 + float(abs(ix*13+iz*7)%5)*6.0
				var m: Material = facade[absi(ix*3+iz*5)%facade.size()]
				_box(self, "Building", Vector3(x,h/2,z), Vector3(16,h,17),m,true)
				for floor_i in range(1, int(h/4.0)):
					for col_i in range(3):
						_box(self,"Window",Vector3(x-5+col_i*5, floor_i*4.0,z-8.55),Vector3(2.7,2,0.07),glass)
				_box(self,"Roof rim",Vector3(x,h+0.25,z),Vector3(16.6,0.5,17.6),concrete)
				_box(self,"Entrance",Vector3(x,1.6,z-8.65),Vector3(2.5,3.1,0.12),_mat(Color("334b52")))
				_box(self,"Base trim",Vector3(x,0.45,z-8.7),Vector3(16.1,0.65,0.15),side)
	# A monumental central plaza, fountain and bazaar-style landmark.
	_box(self,"Central square",Vector3(45,0.08,-45),Vector3(40,0.15,40),concrete)
	_cylinder(self,"Fountain pool",Vector3(45,0.3,-45),8.0,0.55,blue)
	_cylinder(self,"Fountain core",Vector3(45,2,-45),1.4,4,gold)
	_box(self,"Market building",Vector3(65,5.5,65),Vector3(17,11,18),red,true)
	_box(self,"Market roof",Vector3(65,11.4,65),Vector3(21,1.7,22),gold)
	for a in range(6):
		_box(self,"Market door",Vector3(57+a*3.0,2.7,55.9),Vector3(2,4.5,0.08),glass)
	# Road lamps make the map legible at distance.
	for i in range(-2,3):
		for sign_i in [-1,1]:
			_cylinder(self,"Street light pole",Vector3(i*48,3.7,sign_i*16),0.14,7.4,side)
			_box(self,"Lamp head",Vector3(i*48,7.35,sign_i*16),Vector3(1.5,.4,.8),white)
	# Crosswalks and roadside green strips.
	for junction in [-90.0,0.0,90.0]:
		for lane in [-90.0,0.0,90.0]:
			for bar in range(7):
				_box(self,"Crosswalk",Vector3(junction-7+bar*2.3,0.07,lane+10.0),Vector3(1.25,0.02,2.5),white)
	# Decorative shrubs near central square.
	for t in range(14):
		var ax := 45.0 + cos(float(t)*TAU/14.0)*24.0
		var az := -45.0 + sin(float(t)*TAU/14.0)*24.0
		_cylinder(self,"Shrub",Vector3(ax,0.75,az),0.95,1.5,leaf)

func _make_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0,1.2,25)
	add_child(player)
	var collision := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.55
	cap.height = 2.2
	collision.shape = cap
	player.add_child(collision)
	var body := _cylinder(player,"Character coat",Vector3(0,-0.05,0),0.51,1.35,_mat(Color("263b65")))
	var head := _cylinder(player,"Character head",Vector3(0,0.92,0),0.33,0.52,_mat(Color("d1a585")))
	_box(player,"Front marker",Vector3(0,0.2,-0.46),Vector3(.2,.25,.12),_mat(Color("e3d865")))
	camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.current = true
	add_child(camera)

func _make_car() -> void:
	car = Node3D.new()
	car.name = "DriveableCar"
	car.position = Vector3(8,0.85,25)
	add_child(car)
	var paint := _mat(Color("d8a323"), 0.28)
	var black := _mat(Color("18252c"), 0.6)
	var glass := _mat(Color("2b5368"), 0.12)
	var metal := _mat(Color("a9b0b3"), 0.38)
	var red_light := _mat(Color("a82d30"), 0.32)
	var lamp := _mat(Color("fff0c5"), 0.18)
	_box(car,"Car lower chassis",Vector3(0,-0.10,0),Vector3(2.5,0.7,4.9),black)
	_box(car,"Body panels",Vector3(0,0.18,0),Vector3(2.5,0.82,4.9),paint)
	_box(car,"Bonnet",Vector3(0,0.53,-1.65),Vector3(2.35,0.12,1.55),paint)
	_box(car,"Roof",Vector3(0,1.27,0.10),Vector3(2.1,0.16,2.15),paint)
	_box(car,"Front windscreen",Vector3(0,0.97,-1.04),Vector3(2.05,0.69,0.11),glass)
	_box(car,"Rear windscreen",Vector3(0,0.97,1.15),Vector3(2.05,0.67,0.11),glass)
	for side_x in [-1.0,1.0]:
		for z in [-1.54,1.54]:
			var wheel := _cylinder(car,"Tyre",Vector3(side_x*1.27,-0.34,z),0.52,0.29,black)
			wheel.rotation_degrees.z = 90
			var hub := _cylinder(car,"Wheel alloy",Vector3(side_x*1.43,-0.34,z),0.26,0.04,metal)
			hub.rotation_degrees.z = 90
		_box(car,"Side window",Vector3(side_x*1.10,0.99,0.08),Vector3(0.06,0.55,1.88),glass)
		_box(car,"Mirror",Vector3(side_x*1.37,0.79,-0.88),Vector3(.34,.19,.36),black)
		_box(car,"Headlamp",Vector3(side_x*.85,.27,-2.49),Vector3(.52,.22,.07),lamp)
		_box(car,"Rear light",Vector3(side_x*.87,.27,2.49),Vector3(.52,.22,.07),red_light)
	_box(car,"Front grille",Vector3(0,.12,-2.51),Vector3(1.08,.20,.05),black)
	_box(car,"Front bumper",Vector3(0,-.22,-2.49),Vector3(2.35,.18,.12),metal)
	_box(car,"Rear bumper",Vector3(0,-.22,2.49),Vector3(2.35,.18,.12),metal)

func _make_marker() -> void:
	mission_marker = _cylinder(self,"Mission waypoint",mission_target + Vector3(0,4,0),2.4,8,_mat(Color(0.12,0.9,0.83,0.55)))
	var material := mission_marker.material_override as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _make_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var top := PanelContainer.new()
	top.position = Vector2(18,16)
	top.custom_minimum_size = Vector2(390,0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045,0.09,0.13,0.86)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 14
	panel_style.content_margin_top = 12
	panel_style.content_margin_right = 14
	panel_style.content_margin_bottom = 12
	top.add_theme_stylebox_override("panel",panel_style)
	root.add_child(top)
	var labels := VBoxContainer.new()
	top.add_child(labels)
	var title := Label.new()
	title.text = "ULTIMATE TASHKENT RP  |  V0.2"
	title.add_theme_font_size_override("font_size",20)
	labels.add_child(title)
	coins_label = Label.new()
	labels.add_child(coins_label)
	speed_label = Label.new()
	labels.add_child(speed_label)
	save_label = Label.new()
	save_label.text = "● Progress avtomatik saqlanadi"
	labels.add_child(save_label)
	mission_label = Label.new()
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(mission_label)
	information = Label.new()
	information.text = "WASD — yurish/haydash • E — mashina • SHIFT — yugurish\nSichqoncha o‘ng tugmasi + surish — kamerani burish"
	information.add_theme_font_size_override("font_size",14)
	labels.add_child(information)
	var instructions := Label.new()
	instructions.text = "● Baland yashil belgi tomon boring: birinchi topshiriq"
	instructions.position = Vector2(20,189)
	root.add_child(instructions)
	# Right-side Android camera touch zone intentionally does not cover HUD buttons.
	touch_pad = Control.new()
	touch_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_pad)
	var left_base := Control.new()
	left_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left_base.position = Vector2(18,-210)
	root.add_child(left_base)
	_touch_button(left_base,"▲",Vector2(68,0),"forward")
	_touch_button(left_base,"◀",Vector2(0,68),"left")
	_touch_button(left_base,"▼",Vector2(68,68),"back")
	_touch_button(left_base,"▶",Vector2(136,68),"right")
	var right_base := Control.new()
	right_base.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right_base.position = Vector2(-220,-200)
	root.add_child(right_base)
	_touch_button(right_base,"RUN",Vector2(0,40),"run")
	action_button = Button.new()
	action_button.text = "E  MASHINA"
	action_button.position = Vector2(92,30)
	action_button.custom_minimum_size = Vector2(128,65)
	right_base.add_child(action_button)
	action_button.pressed.connect(_toggle_car)
	var note := Label.new()
	note.text = "Android: chap tugmalar — yurish, o‘ng ekran — kamerani burish"
	note.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	note.position = Vector2(20,-24)
	root.add_child(note)

func _touch_button(parent: Control, label: String, pos: Vector2, key: String) -> void:
	var btn := Button.new()
	btn.text = label
	btn.position = pos
	btn.custom_minimum_size = Vector2(64,64)
	btn.add_theme_font_size_override("font_size",22)
	parent.add_child(btn)
	btn.button_down.connect(func(): controls[key] = true)
	btn.button_up.connect(func(): controls[key] = false)

func _toggle_car() -> void:
	if car_mode:
		car_mode = false
		car_velocity = 0.0
		player.position = car.position + Vector3(3,0.45,0)
		player.visible = true
	elif player.global_position.distance_to(car.global_position) < 8.5:
		car_mode = true
		player.visible = false
		car_angle = car.rotation.y
	_update_status()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_toggle_car()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		mouse_look = event.pressed
	if event is InputEventMouseMotion and mouse_look:
		view_yaw -= event.relative.x * 0.005
		view_pitch = clampf(view_pitch - event.relative.y * 0.003,-0.75,0.12)
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x*0.52 and look_pointer < 0:
			look_pointer = event.index
			last_look = event.position
		elif not event.pressed and event.index == look_pointer:
			look_pointer = -1
	if event is InputEventScreenDrag and event.index == look_pointer:
		view_yaw -= (event.position.x-last_look.x)*0.007
		view_pitch = clampf(view_pitch-(event.position.y-last_look.y)*0.004,-0.75,0.12)
		last_look = event.position

func _physics_process(delta: float) -> void:
	var forward := float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or controls["forward"])
	forward -= float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or controls["back"])
	var side := float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or controls["right"])
	side -= float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or controls["left"])
	var movement := Vector2(side,forward).normalized()
	if car_mode:
		# Arcade driving: W/S to accelerate or reverse, A/D to steer.
		var target_speed := forward*DRIVE_SPEED
		car_velocity = move_toward(car_velocity,target_speed,delta*(12.0 if absf(forward)>0.01 else 19.0))
		car_angle += side*delta*1.15*clampf(absf(car_velocity)/DRIVE_SPEED,0.15,1.0)*(1.0 if car_velocity>=0 else -1.0)
		car.rotation.y = car_angle
		var travel := Vector3(-sin(car_angle),0,-cos(car_angle))*car_velocity*delta
		car.position += travel
		car.position.x = clampf(car.position.x,-CITY_EXTENT,CITY_EXTENT)
		car.position.z = clampf(car.position.z,-CITY_EXTENT,CITY_EXTENT)
		player.position = car.position + Vector3(0,0.4,0)
		view_yaw = lerp_angle(view_yaw,car_angle, minf(delta*3.0,1.0))
	else:
		var forward_dir := Vector3(-sin(view_yaw),0,-cos(view_yaw))
		var right_dir := Vector3(cos(view_yaw),0,-sin(view_yaw))
		var direction := (right_dir*movement.x + forward_dir*movement.y).normalized()
		var sprint: bool = Input.is_key_pressed(KEY_SHIFT) or bool(controls["run"])
		player.velocity.x = direction.x*WALK_SPEED*(1.65 if sprint else 1.0)
		player.velocity.z = direction.z*WALK_SPEED*(1.65 if sprint else 1.0)
		if not player.is_on_floor():
			player.velocity.y -= 18.0*delta
		else:
			player.velocity.y = -0.2
		player.move_and_slide()
		player.position.x = clampf(player.position.x,-CITY_EXTENT,CITY_EXTENT)
		player.position.z = clampf(player.position.z,-CITY_EXTENT,CITY_EXTENT)
		if direction.length_squared() > 0.1:
			player.rotation.y = atan2(-direction.x,-direction.z)
	var focus := car.global_position if car_mode else player.global_position
	var offset := Vector3(sin(view_yaw)*13.0,7.0+(-view_pitch*9.0),cos(view_yaw)*13.0)
	var goal := focus + offset
	camera.global_position = camera.global_position.lerp(goal,minf(delta*7.5,1.0))
	camera.look_at(focus+Vector3(0,1.1,0),Vector3.UP)
	if focus.distance_to(mission_target) < 9.0:
		mission_stage += 1
		cash += 250
		match mission_stage%3:
			0: mission_target = Vector3(65,0,65)
			1: mission_target = Vector3(-85,0,-65)
			2: mission_target = Vector3(45,0,-45)
		mission_marker.position = mission_target + Vector3(0,4,0)
		_save_game()
		_update_status()
	if speed_label:
		speed_label.text = "TEZLIK  %03d km/soat" % int(absf(car_velocity)*5.0) if car_mode else "PIYODA  •  WASD"

func _save_game() -> void:
	var data := {"cash":cash,"mission_stage":mission_stage,"mission_target":[mission_target.x,mission_target.y,mission_target.z]}
	var f := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH,FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	cash = maxi(0,int(parsed.get("cash",500)))
	mission_stage = maxi(0,int(parsed.get("mission_stage",0)))
	var target = parsed.get("mission_target",[])
	if typeof(target) == TYPE_ARRAY and target.size()==3:
		mission_target = Vector3(float(target[0]),float(target[1]),float(target[2]))

func _update_status() -> void:
	if coins_label:
		coins_label.text = "💰 Balans: %s so‘m   |   %s" % [str(cash), "🚘 MASHINADA" if car_mode else "🚶 PIYODA"]
	if mission_label:
		mission_label.text = "Topshiriq #%d: yashil belgilangan manzilga boring — mukofot 250 so‘m" % (mission_stage+1)
	if action_button:
		action_button.text = "E  TUSHISH" if car_mode else "E  MASHINA"
