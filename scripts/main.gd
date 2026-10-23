extends Node3D

# ULTIMATE TASHKENT RP — minimal, self-contained Godot 4.x prototype.
# All geometry is procedural. No external assets, servers or plugins required.

const WALK_SPEED := 8.0
const DRIVE_SPEED := 23.0
const CITY_EXTENT := 235.0

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
# Static road markings, windows and vegetation use instanced meshes.
# This avoids hundreds of browser draw calls.
var static_batches: Dictionary = {}
var material_cache: Dictionary = {}
var batching_world := false
var hud_update_timer := 0.0
var fps_label: Label
var navigation_label: Label
var city_map: Control
var map_overlay: Control
var pedestrians: Array[Dictionary] = []
var player_parts: Dictionary = {}
var player_stride := 0.0
var car_obstacles: Array[Dictionary] = []
var police_cars: Array[Dictionary] = []
var wanted_level := 0
var wanted_timer := 0.0
var pursuit_time := 0.0
var player_health := 100
var shot_timer := 0.0
var wanted_label: Label

func _ready() -> void:
	_load_game()
	_make_world()
	_make_player()
	_make_car()
	_make_pedestrians()
	_make_police()
	_make_marker()
	_make_ui()
	_update_status()
	# Do not capture the mouse: it should be playable using a normal mouse and touchscreen.

func _mat(color: Color, rough: float = 0.82) -> StandardMaterial3D:
	var cache_key := color.to_html(true) + "_" + str(snappedf(rough, 0.01))
	if material_cache.has(cache_key):
		return material_cache[cache_key] as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	material_cache[cache_key] = m
	return m

func _add_static_instance(kind: String, material: Material, transform: Transform3D) -> void:
	var batch_id := kind + "_" + str(material.get_instance_id())
	if not static_batches.has(batch_id):
		static_batches[batch_id] = {"kind": kind, "material": material, "transforms": []}
	static_batches[batch_id]["transforms"].append(transform)

func _flush_static_batches() -> void:
	for batch_id in static_batches:
		var data: Dictionary = static_batches[batch_id]
		var transforms: Array = data["transforms"]
		if transforms.is_empty():
			continue
		var mesh: PrimitiveMesh
		if data["kind"] == "cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 1.0
			cylinder.bottom_radius = 1.0
			cylinder.height = 1.0
			cylinder.radial_segments = 8
			mesh = cylinder
		else:
			mesh = BoxMesh.new()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = transforms.size()
		for i in range(transforms.size()):
			multi.set_instance_transform(i, transforms[i])
		var node := MultiMeshInstance3D.new()
		node.name = "Batched_" + str(batch_id)
		node.multimesh = multi
		node.material_override = data["material"]
		add_child(node)
	static_batches.clear()

func _box(parent: Node3D, name: String, pos: Vector3, size: Vector3, material: Material, solid: bool = false) -> MeshInstance3D:
	if batching_world and parent == self and not solid:
		_add_static_instance("box", material, Transform3D(Basis.IDENTITY.scaled(size), pos))
		return null
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = pos
	mesh_node.material_override = material
	parent.add_child(mesh_node)
	if solid and parent == self and size.y > 1.7:
		car_obstacles.append({"x":pos.x,"z":pos.z,"hx":size.x/2.0,"hz":size.z/2.0})
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
	if batching_world and parent == self:
		_add_static_instance("cylinder", material, Transform3D(Basis.IDENTITY.scaled(Vector3(radius,height,radius)), pos))
		return null
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

func _sphere(parent: Node3D, name: String, pos: Vector3, size: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = name
	var mesh := SphereMesh.new()
	mesh.radius = .5
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 6
	part.mesh = mesh
	part.position = pos
	part.scale = size
	part.material_override = material
	parent.add_child(part)

func _make_world() -> void:
	batching_world = true
	var env := WorldEnvironment.new()
	var res := Environment.new()
	res.background_mode = Environment.BG_COLOR
	res.background_color = Color("a4cee3")
	res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	res.ambient_light_color = Color("d5e3e9")
	res.ambient_light_energy = 0.48
	res.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	res.fog_enabled = true
	res.fog_light_color = Color("b9d4dd")
	res.fog_density = 0.0018
	env.environment = res
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -34, 0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_blur = 1.4
	add_child(sun)
	var ground := _mat(Color("65866a"))
	var asphalt := _mat(Color("30373c"))
	var side := _mat(Color("b1b4ad"))
	var stripe := _mat(Color("f1da95"))
	var trunk := _mat(Color("684a36"))
	var leaf := _mat(Color("3c885d"))
	var leaf_light := _mat(Color("63a36c"))
	var leaf_dark := _mat(Color("286b4c"))
	var curb := _mat(Color("d5d5cb"))
	var glass := _mat(Color("397d9a"), 0.18)
	var concrete := _mat(Color("c4c0b4"))
	var red := _mat(Color("ba6c5c"))
	var blue := _mat(Color("658595"))
	var white := _mat(Color("9ca9ad"))
	var gold := _mat(Color("c5a45b"))
	_box(self, "Land", Vector3(0, -0.25, 0), Vector3(510,0.5,510), ground, true)
	# Broad north-south and east-west arterial roads, walkable pavements and lane marks.
	for pos in [-180.0,-90.0,0.0,90.0,180.0]:
		_box(self, "East-west road", Vector3(0,0.018,pos), Vector3(490,0.04,22), asphalt)
		_box(self, "North-south road", Vector3(pos,0.025,0), Vector3(22,0.04,490), asphalt)
		for i in range(-24,25):
			_box(self, "Lane", Vector3(i*10.0,0.055,pos), Vector3(4,0.015,0.23), stripe)
			_box(self, "Lane", Vector3(pos,0.06,i*10.0), Vector3(0.23,0.015,4), stripe)
		for margin in [-14.0,14.0]:
			_box(self, "Sidewalk", Vector3(0,0.1,pos+margin), Vector3(490,0.2,4), side)
			_box(self, "Sidewalk", Vector3(pos+margin,0.1,0), Vector3(4,0.2,490), side)
			_box(self, "Pavement curb", Vector3(0,0.16,pos+margin-2.05), Vector3(490,.26,.24), curb)
			_box(self, "Pavement curb", Vector3(pos+margin-2.05,0.16,0), Vector3(.24,.26,490), curb)
	# Low-poly Tashkent-inspired blocks, apartment towers, office glass and park trees.
	var facade := [concrete, red, blue, white, glass]
	for ix in range(-5,6):
		for iz in range(-5,6):
			var x := ix * 43.0 + 23.0
			var z := iz * 43.0 + 23.0
			if absf(x) < 18.0 or absf(z) < 18.0 or absf(absf(x)-180.0) < 21.0 or absf(absf(z)-180.0) < 21.0:
				continue
			if absf(x - 65.0) < 17.0 and absf(z - 65.0) < 17.0:
				continue
			if (ix + iz) % 4 == 0:
				for t in range(4):
					var ax := x + (t%2)*12.0 - 5.0
					var az := z + (t/2)*12.0 - 5.0
					_cylinder(self, "Tree trunk", Vector3(ax,1.6,az), 0.35,3.2,trunk)
					_cylinder(self, "Tree canopy", Vector3(ax,4.05,az), 2.5,2.1,leaf_dark)
					_cylinder(self, "Tree middle leaves", Vector3(ax,5.55,az), 2.1,1.5,leaf)
					_cylinder(self, "Tree crown", Vector3(ax,6.45,az), 1.55,1.1,leaf_light)
			else:
				var h := 11.0 + float(abs(ix*13+iz*7)%5)*6.0
				var m: Material = facade[absi(ix*3+iz*5)%facade.size()]
				var facade_dark := _mat(Color("304e5a"))
				var facade_trim := _mat(Color("d2d1c7"))
				_box(self, "Building", Vector3(x,h/2,z), Vector3(16,h,17),m,true)
				for floor_i in range(1, int(h/4.0)):
					var floor_y: float = float(floor_i)*4.0
					_box(self,"Floor trim",Vector3(x,floor_y-1.35,z-8.61),Vector3(16.2,.13,.22),facade_trim)
					for col_i in range(3):
						var wx: float = x-5.0+float(col_i)*5.0
						_box(self,"Window frame",Vector3(wx,floor_y,z-8.58),Vector3(3.15,2.42,.11),facade_dark)
						_box(self,"Window glass",Vector3(wx,floor_y,z-8.66),Vector3(2.75,2.06,.09),glass)
						_box(self,"Window center bar",Vector3(wx,floor_y,z-8.74),Vector3(.08,2.13,.09),facade_trim)
						_box(self,"Window sill",Vector3(wx,floor_y-1.17,z-8.74),Vector3(3.3,.15,.3),facade_trim)
						_box(self,"Side window left",Vector3(x-8.08,floor_y,z-4.3),Vector3(.08,1.8,2.0),glass)
						_box(self,"Side window right",Vector3(x+8.08,floor_y,z+4.3),Vector3(.08,1.8,2.0),glass)
				_box(self,"Roof rim",Vector3(x,h+0.25,z),Vector3(16.6,0.5,17.6),concrete)
				_box(self,"Entrance",Vector3(x,1.6,z-8.65),Vector3(2.5,3.1,0.12),_mat(Color("334b52")))
				_box(self,"Entrance canopy",Vector3(x,3.45,z-9.45),Vector3(4.4,.26,1.9),facade_trim)
				_box(self,"Entrance step",Vector3(x,.13,z-9.25),Vector3(3.4,.26,1.2),concrete)
				_box(self,"Facade pillar L",Vector3(x-7.8,h*.5,z-8.64),Vector3(.26,h,.26),facade_trim)
				_box(self,"Facade pillar R",Vector3(x+7.8,h*.5,z-8.64),Vector3(.26,h,.26),facade_trim)
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
	# V0.3: recognizable urban details with batched, low-cost geometry.
	var signal_dark := _mat(Color("26333a"))
	var signal_red := _mat(Color("c84842"))
	var signal_yellow := _mat(Color("c9a440"))
	var signal_green := _mat(Color("36986d"))
	var bus_blue := _mat(Color("326b96"))
	for junction in [-180.0,-90.0,0.0,90.0,180.0]:
		for lane in [-180.0,-90.0,0.0,90.0,180.0]:
			for corner in [-1.0, 1.0]:
				var sx: float = float(junction) + float(corner)*17.5
				var sz: float = float(lane) + 17.5
				_cylinder(self, "Traffic light pole", Vector3(sx,2.3,sz),0.12,4.6,signal_dark)
				_box(self,"Traffic signal case",Vector3(sx,4.75,sz),Vector3(.65,1.65,.42),signal_dark)
				_box(self,"Red signal",Vector3(sx,5.24,sz-.23),Vector3(.36,.31,.04),signal_red)
				_box(self,"Amber signal",Vector3(sx,4.76,sz-.23),Vector3(.36,.31,.04),signal_yellow)
				_box(self,"Green signal",Vector3(sx,4.28,sz-.23),Vector3(.36,.31,.04),signal_green)
	# Three bus stops with roof, seat and distinctive blue signs.
	for stop_x in [-65.0, 30.0, 115.0]:
		var stop_z := 17.5
		_box(self,"Bus shelter roof",Vector3(stop_x,3.15,stop_z),Vector3(5.5,.24,2.4),bus_blue)
		for dx in [-2.3,2.3]:
			_cylinder(self,"Bus shelter post",Vector3(stop_x+dx,1.6,stop_z),.11,3.1,signal_dark)
		_box(self,"Bus stop bench",Vector3(stop_x,0.8,stop_z+.4),Vector3(3.4,.22,.65),concrete)
		_box(self,"Bus stop sign",Vector3(stop_x+3.1,2.6,stop_z),Vector3(.9,.9,.12),bus_blue)
	# V0.4: urban RP points of interest, low-poly and batched for browser FPS.
	var shop_wall := _mat(Color("d5c6a5"))
	var shop_roof := _mat(Color("2c6c85"))
	var shop_door := _mat(Color("23414d"))
	var park_green := _mat(Color("437e56"))
	var kiosk_orange := _mat(Color("c98041"))
	for shop_x in [-45.0, 45.0, 125.0]:
		var shop_z: float = -21.0
		_box(self,"City shop",Vector3(shop_x,2.1,shop_z),Vector3(8.0,4.2,5.2),shop_wall,true)
		_box(self,"Shop awning",Vector3(shop_x,4.45,shop_z+1.3),Vector3(9.0,.35,3.0),shop_roof)
		_box(self,"Storefront signboard",Vector3(shop_x,3.78,shop_z+2.75),Vector3(6.6,.85,.16),_mat(Color("204c60")))
		_box(self,"Storefront sign trim",Vector3(shop_x,3.3,shop_z+2.85),Vector3(6.8,.08,.17),gold)
		_box(self,"Storefront step",Vector3(shop_x,.10,shop_z+3.1),Vector3(5.2,.2,1.15),concrete)
		_box(self,"Shop door",Vector3(shop_x,1.25,shop_z+2.68),Vector3(1.6,2.5,.10),shop_door)
		for pane in [-2.7,2.7]:
			_box(self,"Shop window",Vector3(shop_x+pane,2.0,shop_z+2.7),Vector3(1.65,1.65,.08),glass)
	for kiosk_x in [-115.0, -35.0, 115.0]:
		_box(self,"Street kiosk",Vector3(kiosk_x,1.45,35.0),Vector3(4.2,2.9,3.5),kiosk_orange,true)
		_box(self,"Kiosk canopy",Vector3(kiosk_x,3.05,35.0),Vector3(5.2,.3,4.1),shop_roof)
		_box(self,"Kiosk sign",Vector3(kiosk_x,2.68,33.18),Vector3(3.7,.43,.11),_mat(Color("e8d3a0")))
		_box(self,"Kiosk serving window",Vector3(kiosk_x,1.95,33.2),Vector3(2.8,1.25,.08),glass)
	# Park benches and planter beds near the fountain plaza.
	for bench_x in [26.0, 45.0, 64.0]:
		_box(self,"Park bench seat",Vector3(bench_x,.72,-66.0),Vector3(3.6,.22,.8),shop_wall)
		_box(self,"Park bench back",Vector3(bench_x,1.22,-66.35),Vector3(3.6,1.0,.18),shop_wall)
		for leg_x in [-1.3,1.3]:
			_box(self,"Park bench leg",Vector3(bench_x+leg_x,.37,-66.0),Vector3(.16,.7,.65),signal_dark)
		_box(self,"Park flower bed",Vector3(bench_x,.16,-72.0),Vector3(4.5,.28,2.0),park_green)
	# Crosswalks and roadside green strips.
	for junction in [-180.0,-90.0,0.0,90.0,180.0]:
		for lane in [-180.0,-90.0,0.0,90.0,180.0]:
			for bar in range(7):
				_box(self,"Crosswalk",Vector3(junction-7+bar*2.3,0.07,lane+10.0),Vector3(1.25,0.02,2.5),white)
	# Decorative shrubs near central square.
	for t in range(14):
		var ax := 45.0 + cos(float(t)*TAU/14.0)*24.0
		var az := -45.0 + sin(float(t)*TAU/14.0)*24.0
		_cylinder(self,"Shrub",Vector3(ax,0.75,az),0.95,1.5,leaf)
	_flush_static_batches()
	batching_world = false

func _make_human(root: Node3D, shade: Color, officer: bool = false) -> Dictionary:
	var jacket := _mat(shade)
	var skin := _mat(Color("c99470"))
	var jeans := _mat(Color("273340"))
	var sneaker := _mat(Color("e3e0d6"))
	var hair := _mat(Color("272629"))
	_sphere(root,"Shoulders",Vector3(0,.16,0),Vector3(.76,.47,.43),jacket)
	_sphere(root,"Torso",Vector3(0,-.18,0),Vector3(.62,.78,.42),jacket)
	_box(root,"Hips",Vector3(0,-.55,0),Vector3(.57,.19,.35),jeans)
	_box(root,"Neck",Vector3(0,.39,0),Vector3(.18,.17,.18),skin)
	_sphere(root,"Face",Vector3(0,.72,-.03),Vector3(.48,.55,.43),skin)
	_sphere(root,"Hair",Vector3(0,.99,.05),Vector3(.51,.20,.47),hair)
	for x in [-.12,.12]:
		_sphere(root,"Eye",Vector3(x,.77,-.252),Vector3(.06,.055,.045),hair)
	_box(root,"Nose",Vector3(0,.66,-.273),Vector3(.08,.12,.09),skin)
	_box(root,"Mouth",Vector3(0,.48,-.259),Vector3(.14,.025,.02),_mat(Color("875b50")))
	_box(root,"Jacket collar",Vector3(0,.34,-.225),Vector3(.34,.13,.05),_mat(Color("d5c7ae")))
	_box(root,"Jacket zipper",Vector3(0,-.12,-.206),Vector3(.026,.68,.03),_mat(Color("d2c7ae")))
	var left_arm := Node3D.new()
	left_arm.position = Vector3(-.43,.27,0)
	root.add_child(left_arm)
	_sphere(left_arm,"Sleeve",Vector3(0,-.31,0),Vector3(.28,.72,.30),jacket)
	_sphere(left_arm,"Hand",Vector3(0,-.69,0),Vector3(.19,.20,.19),skin)
	var right_arm := Node3D.new()
	right_arm.position = Vector3(.43,.27,0)
	root.add_child(right_arm)
	_sphere(right_arm,"Sleeve",Vector3(0,-.31,0),Vector3(.28,.72,.30),jacket)
	_sphere(right_arm,"Hand",Vector3(0,-.69,0),Vector3(.19,.20,.19),skin)
	var left_leg := Node3D.new()
	left_leg.position = Vector3(-.16,-.57,0)
	root.add_child(left_leg)
	_sphere(left_leg,"Trouser",Vector3(0,-.32,0),Vector3(.28,.76,.33),jeans)
	_box(left_leg,"Shoe",Vector3(0,-.70,-.07),Vector3(.31,.15,.46),sneaker)
	var right_leg := Node3D.new()
	right_leg.position = Vector3(.16,-.57,0)
	root.add_child(right_leg)
	_sphere(right_leg,"Trouser",Vector3(0,-.32,0),Vector3(.28,.76,.33),jeans)
	_box(right_leg,"Shoe",Vector3(0,-.70,-.07),Vector3(.31,.15,.46),sneaker)
	if officer:
		_box(root,"Police badge",Vector3(.18,.12,-.22),Vector3(.11,.13,.04),_mat(Color("c5ae57")))
		_box(root,"Cap",Vector3(0,1.09,-.09),Vector3(.54,.11,.40),hair)
	return {"left_arm":left_arm,"right_arm":right_arm,"left_leg":left_leg,"right_leg":right_leg}

func _animate_human(parts: Dictionary, phase: float) -> void:
	var swing: float = sin(phase)*.42
	(parts["left_leg"] as Node3D).rotation.x = swing
	(parts["right_leg"] as Node3D).rotation.x = -swing
	(parts["left_arm"] as Node3D).rotation.x = -swing*.75
	(parts["right_arm"] as Node3D).rotation.x = swing*.75

func _make_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0,1.3,25)
	add_child(player)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .42
	capsule.height = 2.45
	shape.shape = capsule
	player.add_child(shape)
	player_parts = _make_human(player,Color("2d608b"))
	camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.current = true
	camera.far = 225.0
	add_child(camera)

func _make_pedestrians() -> void:
	var outfits: Array[Color] = [Color("43649a"),Color("995546"),Color("3f8369"),Color("b28a40"),Color("73518b")]
	var lanes: Array[float] = [-194.5,-165.5,-104.5,-75.5,-14.5,14.5,75.5,104.5,165.5,194.5]
	for i in range(30):
		var npc := Node3D.new()
		npc.name = "Citizen_%02d" % i
		add_child(npc)
		npc.position = Vector3(lanes[i%lanes.size()],0,-192.0+float(i*37%38)*10.0)
		var skeleton := Node3D.new()
		skeleton.position.y = 1.30
		npc.add_child(skeleton)
		var parts := _make_human(skeleton,outfits[i%outfits.size()])
		parts["node"] = npc
		parts["direction"] = 1.0 if i%3 != 0 else -1.0
		parts["phase"] = float(i)*1.5
		parts["speed"] = 1.1+float(i%4)*.2
		parts["knocked"] = 0.0
		pedestrians.append(parts)

func _build_sedan(vehicle: Node3D, police: bool) -> void:
	var paint := _mat(Color("eeeeea") if police else Color("e4ac1e"),.28)
	var tire := _mat(Color("1a2429"))
	var window := _mat(Color("326276"),.15)
	var chrome := _mat(Color("b8bec3"),.34)
	var red := _mat(Color("c72d40"))
	_box(vehicle,"Chassis",Vector3(0,-.13,0),Vector3(2.38,.69,4.8),tire)
	_box(vehicle,"Body",Vector3(0,.20,0),Vector3(2.42,.84,4.75),paint)
	_box(vehicle,"Bonnet",Vector3(0,.66,-1.6),Vector3(2.25,.15,1.55),paint)
	_box(vehicle,"Trunk",Vector3(0,.67,1.76),Vector3(2.26,.15,1.13),paint)
	_box(vehicle,"Cabin",Vector3(0,1.02,.15),Vector3(2.00,.78,2.08),window)
	_box(vehicle,"Windshield upper edge",Vector3(0,1.38,-.91),Vector3(1.98,.08,.13),chrome)
	_box(vehicle,"Windshield lower edge",Vector3(0,.71,-.91),Vector3(2.05,.09,.13),chrome)
	_box(vehicle,"Rear glass trim",Vector3(0,1.10,1.22),Vector3(2.0,.08,.12),chrome)
	_box(vehicle,"Roof",Vector3(0,1.47,.16),Vector3(1.94,.15,1.92),paint)
	_box(vehicle,"Roof antenna",Vector3(0,1.61,1.04),Vector3(.07,.27,.07),tire)
	for sx in [-1.0,1.0]:
		for z in [-1.45,1.45]:
			var wheel := _cylinder(vehicle,"Wheel",Vector3(sx*1.25,-.33,z),.51,.31,tire)
			wheel.rotation_degrees.z = 90
			var rim := _cylinder(vehicle,"Rim",Vector3(sx*1.43,-.33,z),.29,.05,chrome)
			rim.rotation_degrees.z = 90
		_box(vehicle,"Side mirror",Vector3(sx*1.31,.83,-.85),Vector3(.33,.19,.28),tire)
		_box(vehicle,"Door handle",Vector3(sx*1.23,.50,-.27),Vector3(.055,.055,.22),chrome)
		_box(vehicle,"Rear handle",Vector3(sx*1.23,.50,.83),Vector3(.055,.055,.22),chrome)
		_box(vehicle,"Door separator",Vector3(sx*1.236,.37,.30),Vector3(.025,.66,.035),tire)
		_box(vehicle,"Side sill",Vector3(sx*1.22,-.19,0),Vector3(.10,.11,2.6),chrome)
		_box(vehicle,"Wheel arch trim front",Vector3(sx*1.21,.05,-1.45),Vector3(.08,.12,1.18),tire)
		_box(vehicle,"Wheel arch trim rear",Vector3(sx*1.21,.05,1.45),Vector3(.08,.12,1.18),tire)
		_box(vehicle,"Front light",Vector3(sx*.83,.36,-2.41),Vector3(.48,.22,.07),_mat(Color("f7eed4")))
		_box(vehicle,"Rear light",Vector3(sx*.83,.36,2.42),Vector3(.46,.22,.07),red)
	_box(vehicle,"Front grille",Vector3(0,.23,-2.45),Vector3(1.04,.26,.09),tire)
	_box(vehicle,"Front number plate",Vector3(0,-.08,-2.54),Vector3(.84,.18,.04),chrome)
	_box(vehicle,"Rear number plate",Vector3(0,-.07,2.52),Vector3(.84,.18,.04),chrome)
	_box(vehicle,"Hood detail",Vector3(0,.755,-1.35),Vector3(1.45,.025,.65),paint)
	_box(vehicle,"Front bumper",Vector3(0,-.22,-2.46),Vector3(2.35,.17,.11),chrome)
	_box(vehicle,"Rear bumper",Vector3(0,-.22,2.46),Vector3(2.35,.17,.11),chrome)
	if police:
		var blue := _mat(Color("2151a0"))
		_box(vehicle,"Police stripe",Vector3(0,.25,2.44),Vector3(1.07,.28,.05),blue)
		_box(vehicle,"Lightbar",Vector3(0,1.63,.15),Vector3(1.3,.12,.42),tire)
		_box(vehicle,"Blue siren",Vector3(-.36,1.74,.15),Vector3(.55,.16,.32),blue)
		_box(vehicle,"Red siren",Vector3(.36,1.74,.15),Vector3(.55,.16,.32),red)

func _make_car() -> void:
	car = Node3D.new()
	car.name = "DriveableCar"
	car.position = Vector3(8,.85,25)
	add_child(car)
	_build_sedan(car,false)
	var parked_body := StaticBody3D.new()
	car.add_child(parked_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.3,1.5,4.6)
	shape.shape = box
	shape.position.y = .3
	parked_body.add_child(shape)

func _make_police() -> void:
	for i in range(2):
		var patrol := Node3D.new()
		patrol.name = "PolicePatrol_%d" % i
		patrol.position = Vector3(7.0 if i == 0 else -97.0,.85,-116.0 if i == 0 else 110.0)
		add_child(patrol)
		_build_sedan(patrol,true)
		police_cars.append({"node":patrol,"heading":0.0 if i==0 else PI,"base_z":patrol.position.z,"idle_dir":1.0 if i == 0 else -1.0})
		var officer := Node3D.new()
		officer.name = "Officer_%d" % i
		officer.position = patrol.position+Vector3(3, -.85,0)
		add_child(officer)
		var body := Node3D.new()
		body.position.y = 1.30
		officer.add_child(body)
		_make_human(body,Color("244778"),true)

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
	top.custom_minimum_size = Vector2(415,0)
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
	title.text = "ULTIMATE TASHKENT RP  |  V1.0 VISUAL CITY"
	title.add_theme_font_size_override("font_size",20)
	labels.add_child(title)
	coins_label = Label.new()
	labels.add_child(coins_label)
	speed_label = Label.new()
	labels.add_child(speed_label)
	fps_label = Label.new()
	labels.add_child(fps_label)
	navigation_label = Label.new()
	labels.add_child(navigation_label)
	wanted_label = Label.new()
	labels.add_child(wanted_label)
	save_label = Label.new()
	save_label.text = "Progress avtomatik saqlanadi"
	labels.add_child(save_label)
	mission_label = Label.new()
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.custom_minimum_size = Vector2(365, 0)
	labels.add_child(mission_label)
	information = Label.new()
	information.text = "WASD - harakat  |  E - mashina  |  SHIFT - yugurish"
	information.add_theme_font_size_override("font_size",14)
	labels.add_child(information)
	# Persistent top-right radar with a full-screen map on M.
	var map_script: Script = load("res://scripts/city_map.gd")
	city_map = Control.new()
	city_map.set_script(map_script)
	city_map.position = Vector2(0,0)
	city_map.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	city_map.position = Vector2(-205,18)
	city_map.custom_minimum_size = Vector2(188,188)
	city_map.size = Vector2(188,188)
	root.add_child(city_map)
	map_overlay = Control.new()
	map_overlay.set_script(map_script)
	map_overlay.set_anchors_preset(Control.PRESET_CENTER)
	map_overlay.position = Vector2(-300,-240)
	map_overlay.size = Vector2(600,480)
	map_overlay.visible = false
	map_overlay.set("expanded",true)
	root.add_child(map_overlay)
	var map_button := Button.new()
	map_button.text = "XARITA (M)"
	map_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	map_button.position = Vector2(-205,209)
	map_button.custom_minimum_size = Vector2(188,42)
	root.add_child(map_button)
	map_button.pressed.connect(_toggle_map)
	# Right-side Android camera touch zone intentionally does not cover HUD buttons.
	touch_pad = Control.new()
	touch_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_pad)
	var left_base := Control.new()
	left_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left_base.position = Vector2(18,-210)
	root.add_child(left_base)
	_touch_button(left_base,"W",Vector2(68,0),"forward")
	_touch_button(left_base,"A",Vector2(0,68),"left")
	_touch_button(left_base,"S",Vector2(68,68),"back")
	_touch_button(left_base,"D",Vector2(136,68),"right")
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
	note.text = "Android: chap tugmalar - harakat, ong ekran - kamera"
	note.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	note.position = Vector2(20,-24)
	root.add_child(note)

func _toggle_map() -> void:
	map_overlay.visible = not map_overlay.visible
	city_map.visible = not map_overlay.visible

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
		if event.keycode == KEY_M:
			_toggle_map()
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

func _process(delta: float) -> void:
	# NPCs walk along sidewalks, reverse at district boundaries.
	for npc in pedestrians:
		var citizen: Node3D = npc["node"]
		var heading: float = npc["direction"]
		if float(npc["knocked"]) > 0.0:
			npc["knocked"] = maxf(0.0,float(npc["knocked"])-delta)
			citizen.rotation.z = lerpf(citizen.rotation.z,1.1,minf(delta*5.0,1.0))
			continue
		citizen.rotation.z = lerpf(citizen.rotation.z,0.0,minf(delta*5.0,1.0))
		citizen.position.z += heading * float(npc["speed"]) * delta
		if citizen.position.z > 137.0 or citizen.position.z < -137.0:
			npc["direction"] = -heading
			citizen.position.z = clampf(citizen.position.z,-137.0,137.0)
		citizen.rotation.y = 0.0 if float(npc["direction"]) < 0.0 else PI
		npc["phase"] = float(npc["phase"]) + delta*7.0
		var swing: float = sin(float(npc["phase"]))*0.42
		(npc["left_leg"] as Node3D).rotation.x = swing
		(npc["right_leg"] as Node3D).rotation.x = -swing
		(npc["left_arm"] as Node3D).rotation.x = -swing*.75
		(npc["right_arm"] as Node3D).rotation.x = swing*.75
	_update_patrols(delta)
	hud_update_timer += delta
	if hud_update_timer >= 0.3:
		hud_update_timer = 0.0
		var current_pos: Vector3 = car.global_position if car_mode else player.global_position
		city_map.call("update_navigation",current_pos,mission_target,car_angle if car_mode else player.rotation.y)
		map_overlay.call("update_navigation",current_pos,mission_target,car_angle if car_mode else player.rotation.y)
		if wanted_label:
			wanted_label.text = "QIDIRUV: %d/3  |  POLITSIYA" % wanted_level if wanted_level > 0 else "POLITSIYA: TINCH"
		if speed_label:
			speed_label.text = "TEZLIK  %03d km/soat" % int(absf(car_velocity)*5.0) if car_mode else "PIYODA  •  WASD"
		if fps_label:
			fps_label.text = "FPS: %d | Visual City" % Engine.get_frames_per_second()
		if navigation_label:
			var focus_position: Vector3 = car.global_position if car_mode else player.global_position
			var meters := int(focus_position.distance_to(mission_target))
			navigation_label.text = "MANZIL: %d m  |  X:%d  Z:%d" % [meters, int(focus_position.x), int(focus_position.z)]

func _blocked_by_patrol(candidate: Vector3, current: Vector3) -> bool:
	# Allow a player to drive OUT of an existing overlap, but not deeper into one.
	for patrol in police_cars:
		var unit: Node3D = patrol["node"]
		var future_diff: Vector3 = candidate - unit.position
		var current_diff: Vector3 = current - unit.position
		future_diff.y = 0.0
		current_diff.y = 0.0
		if future_diff.length() < 5.6 and future_diff.length() < current_diff.length():
			return true
	return false

func _blocked_for_vehicle(candidate: Vector3) -> bool:
	for obstacle in car_obstacles:
		if absf(candidate.x - float(obstacle["x"])) < float(obstacle["hx"]) + 1.4 and absf(candidate.z - float(obstacle["z"])) < float(obstacle["hz"]) + 2.2:
			return true
	return false

func _clear_patrol_destination(candidate: Vector3, own_car: Node3D) -> bool:
	# Do not place patrols inside the player car or other police vehicles.
	var player_delta: Vector3 = candidate - car.position
	player_delta.y = 0.0
	if player_delta.length() < 6.8:
		return false
	for patrol in police_cars:
		var other: Node3D = patrol["node"]
		if other == own_car:
			continue
		var diff: Vector3 = candidate - other.position
		diff.y = 0.0
		if diff.length() < 6.2:
			return false
	return not _blocked_for_vehicle(candidate)

func _update_patrols(delta: float) -> void:
	if wanted_level == 0:
		# Calm patrols drive short routes without pushing through parked vehicles.
		for patrol in police_cars:
			var unit: Node3D = patrol["node"]
			var direction_z: float = float(patrol["idle_dir"])
			var base_z: float = float(patrol["base_z"])
			var next_z: float = unit.position.z + direction_z * 3.5 * delta
			if absf(next_z - base_z) > 26.0:
				direction_z = -direction_z
				patrol["idle_dir"] = direction_z
				next_z = unit.position.z + direction_z * 3.5 * delta
			var desired := Vector3(unit.position.x,unit.position.y,next_z)
			if _clear_patrol_destination(desired,unit):
				unit.position = desired
			unit.rotation.y = 0.0 if direction_z < 0.0 else PI
		pursuit_time = 0.0
		return
	wanted_timer -= delta
	var target: Vector3 = car.global_position if car_mode else player.global_position
	var nearest: float = 10000.0
	for patrol in police_cars:
		var unit: Node3D = patrol["node"]
		var to_target: Vector3 = target - unit.global_position
		to_target.y = 0.0
		var distance: float = to_target.length()
		nearest = minf(nearest,distance)
		var stop_distance: float = 7.2 if car_mode else 4.2
		if distance > stop_distance:
			var speed: float = 10.0 + float(wanted_level)*2.5
			var step: float = minf(delta*speed,distance-stop_distance)
			var destination: Vector3 = unit.position + to_target.normalized()*step
			if _clear_patrol_destination(destination,unit):
				unit.position = destination
			unit.rotation.y = atan2(-to_target.x,-to_target.z)
	if nearest < (8.5 if car_mode else 4.9):
		pursuit_time += delta
		if pursuit_time > 2.5:
			wanted_level = 0
			wanted_timer = 0.0
			pursuit_time = 0.0
			car_velocity = 0.0
			cash = maxi(0,cash-150)
			_save_game()
			_update_status()
	else:
		pursuit_time = 0.0
	if wanted_timer <= 0.0:
		wanted_level = 0

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
		# Sweep the travelled distance to avoid jumping through thin obstacles on slow frames.
		var from_position: Vector3 = car.position
		var blocked := false
		var segment_count: int = maxi(1,ceili(travel.length() / 0.8))
		for segment_i in range(1,segment_count+1):
			var candidate: Vector3 = from_position + travel * (float(segment_i)/float(segment_count))
			if _blocked_for_vehicle(candidate) or _blocked_by_patrol(candidate,from_position):
				blocked = true
				break
		if blocked:
			car_velocity = 0.0
		else:
			car.position = from_position + travel
		car.position.x = clampf(car.position.x,-CITY_EXTENT,CITY_EXTENT)
		car.position.z = clampf(car.position.z,-CITY_EXTENT,CITY_EXTENT)
		if absf(car_velocity) > 4.0:
			for npc in pedestrians:
				var citizen: Node3D = npc["node"]
				if float(npc["knocked"]) <= 0.0 and citizen.global_position.distance_to(car.global_position) < 2.3:
					npc["knocked"] = 7.0
					wanted_level = mini(3,wanted_level+1)
					wanted_timer = 35.0
					break
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
		coins_label.text = "Balans: %s som  |  %s" % [str(cash), "MASHINADA" if car_mode else "PIYODA"]
	if mission_label:
		mission_label.text = "Topshiriq #%d: yashil belgilangan manzilga boring — mukofot 250 so‘m" % (mission_stage+1)
	if action_button:
		action_button.text = "E  TUSHISH" if car_mode else "E  MASHINA"
