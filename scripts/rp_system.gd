extends Node

# Single-player RP systems. Multiplayer currently mirrors only cosmetic state;
# rewards, arrests and combat stay local until the dedicated server is authoritative.

const BANK_ENTRANCE := Vector3(-63.0, 1.3, 54.2)
const POLICE_STATION := Vector3(109.0, 1.3, -74.5)
const HOSPITAL := Vector3(45.0, 1.3, -17.0)
const ESCAPE_POINT := Vector3(180.0, 0.0, -180.0)
const INTERIOR_ORIGIN := Vector3(0.0, 60.0, 0.0)
const VAULT_POSITION := Vector3(0.0, 61.3, -6.5)
const INTERIOR_EXIT := Vector3(0.0, 61.3, 8.0)
const VALID_ROLES := ["civilian", "police", "thief"]
const ROLE_NAMES := {"civilian":"FUQARO", "police":"POLITSIYA", "thief":"O‘G‘RI"}

var game
var entrances: Array[Dictionary] = []
var vehicles: Array[Dictionary] = []
var current_vehicle: Dictionary = {}
var inside_building := false
var current_entrance: Dictionary = {}
var interior_root: Node3D
var bank_props: Node3D
var police_props: Node3D
var interior_title: Label3D

var role_label: Label
var health_bar: ProgressBar
var prompt_label: Label
var alert_label: Label
var robbery_bar: ProgressBar
var toast_timer := 0.0
var ui_timer := 0.0

var robbery_state := "idle"
var robbery_timer := 0.0
var robbery_cooldown := 0.0
var carried_loot := 0
var compliance_active := false
var compliance_time := 5.0
var police_shot_timer := 0.0
var weapon_cooldown := 0.0
var current_suspect: Dictionary = {}

func _ready() -> void:
	game = get_parent()
	_make_landmarks()
	_collect_entrances()
	_make_interior()
	_register_existing_vehicle()
	_spawn_city_traffic()
	_make_rp_ui()
	select_role(game.player_role, false)

func _panel_style(alpha: float = 0.9, accent: Color = Color("48d9f2")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.082, alpha)
	style.border_color = Color(accent, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _make_landmarks() -> void:
	var glass: Material = game._mat(Color("28647d"), 0.12)
	var marble: Material = game._mat(Color("ddd8c9"), 0.36)
	var gold: Material = game._mat(Color("e1b657"), 0.24)
	var police_blue: Material = game._mat(Color("1e5a8c"), 0.3)
	# The existing block remains the shell; these details give it a clear identity.
	game._box(game, "Bank glass facade", Vector3(-63, 4.4, 56.9), Vector3(12.8, 6.6, .25), glass)
	game._box(game, "Bank columns", Vector3(-68.5, 3.2, 56.45), Vector3(.7, 6.4, .7), marble)
	game._box(game, "Bank columns", Vector3(-57.5, 3.2, 56.45), Vector3(.7, 6.4, .7), marble)
	game._box(game, "Bank crown", Vector3(-63, 8.1, 56.5), Vector3(14.5, 1.0, .8), gold)
	_add_world_label("MARKAZIY BANK", Vector3(-63, 7.9, 55.9), Color("ffe29a"))
	game._box(game, "Police facade", Vector3(109, 4.0, -72.0), Vector3(13.5, 6.2, .25), game._mat(Color("e7edf1")))
	game._box(game, "Police stripe", Vector3(109, 5.0, -71.8), Vector3(13.8, 1.1, .18), police_blue)
	_add_world_label("TOSHKENT SHAHAR POLITSIYASI", Vector3(109, 6.5, -71.5), Color("b9e7ff"))

func _add_world_label(text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.modulate = color
	label.font_size = 44
	label.pixel_size = 0.012
	label.outline_size = 8
	game.add_child(label)

func _collect_entrances() -> void:
	var number := 1
	for ix in range(-5, 6):
		for iz in range(-5, 6):
			var x := ix * 43.0 + 23.0
			var z := iz * 43.0 + 23.0
			if absf(x) < 18.0 or absf(z) < 18.0 or absf(absf(x)-180.0) < 21.0 or absf(absf(z)-180.0) < 21.0:
				continue
			if absf(x - 65.0) < 17.0 and absf(z - 65.0) < 17.0:
				continue
			if (ix + iz) % 4 == 0:
				continue
			var kind := "house"
			var title := "Turar joy %02d" % number
			if Vector2(x + 63.0, z - 66.0).length() < 4.0:
				kind = "bank"
				title = "Markaziy bank"
			elif Vector2(x - 109.0, z + 63.0).length() < 4.0:
				kind = "police"
				title = "Politsiya bo‘limi"
			entrances.append({"position":Vector3(x, 1.3, z-10.2), "outside":Vector3(x, 1.3, z-12.2), "kind":kind, "title":title})
			number += 1
	for shop_x in [-45.0, 45.0, 125.0]:
		entrances.append({"position":Vector3(shop_x, 1.3, -17.5), "outside":Vector3(shop_x, 1.3, -15.0), "kind":"shop", "title":"Shahar do‘koni"})
	entrances.append({"position":Vector3(65, 1.3, 54.5), "outside":Vector3(65, 1.3, 52.5), "kind":"shop", "title":"Chorsu savdo markazi"})

func _make_interior() -> void:
	interior_root = Node3D.new()
	interior_root.name = "ReusableInterior"
	interior_root.position = INTERIOR_ORIGIN
	game.add_child(interior_root)
	var floor_mat: Material = game._mat(Color("27343c"), .45)
	var wall_mat: Material = game._mat(Color("d8d5ca"), .72)
	var trim_mat: Material = game._mat(Color("35b8c8"), .28)
	var wood: Material = game._mat(Color("765238"), .65)
	game._box(interior_root, "Interior floor", Vector3(0,-.25,0), Vector3(18,.5,22), floor_mat, true)
	game._box(interior_root, "Interior ceiling", Vector3(0,4.7,0), Vector3(18,.35,22), wall_mat, true)
	game._box(interior_root, "Interior left wall", Vector3(-9,2.2,0), Vector3(.4,4.8,22), wall_mat, true)
	game._box(interior_root, "Interior right wall", Vector3(9,2.2,0), Vector3(.4,4.8,22), wall_mat, true)
	game._box(interior_root, "Interior back wall", Vector3(0,2.2,-11), Vector3(18,.4,4.8), wall_mat, true)
	game._box(interior_root, "Interior front L", Vector3(-5.5,2.2,11), Vector3(7,.4,4.8), wall_mat, true)
	game._box(interior_root, "Interior front R", Vector3(5.5,2.2,11), Vector3(7,.4,4.8), wall_mat, true)
	game._box(interior_root, "Exit glow", Vector3(0,1.9,10.75), Vector3(3.2,3.8,.16), trim_mat)
	game._box(interior_root, "Sofa", Vector3(-4.7,.65,-1.0), Vector3(3.8,1.3,1.4), wood)
	game._box(interior_root, "Table", Vector3(2.6,.65,1.0), Vector3(3.2,.3,2.2), wood)
	for x in [-1.0, 1.0]:
		game._box(interior_root, "Table leg", Vector3(2.6+x,.3,1.0), Vector3(.2,.6,1.4), wood)
	interior_title = Label3D.new()
	interior_title.position = Vector3(0,3.6,-10.7)
	interior_title.font_size = 52
	interior_title.pixel_size = .012
	interior_title.modulate = Color("dffbff")
	interior_root.add_child(interior_title)
	bank_props = Node3D.new()
	bank_props.name = "BankInterior"
	interior_root.add_child(bank_props)
	game._box(bank_props, "Vault", Vector3(0,1.8,-9.6), Vector3(6.2,3.6,.7), game._mat(Color("7e8d94"), .22))
	game._box(bank_props, "Vault wheel", Vector3(0,1.8,-9.15), Vector3(1.4,1.4,.25), game._mat(Color("d6b65d"), .18))
	game._box(bank_props, "Bank counter", Vector3(0,1.0,1.0), Vector3(7,2,1.0), game._mat(Color("234f63"), .25))
	police_props = Node3D.new()
	police_props.name = "PoliceInterior"
	interior_root.add_child(police_props)
	game._box(police_props, "Police desk", Vector3(0,1.0,-2.0), Vector3(7,2,1.2), game._mat(Color("285b80"), .28))
	game._box(police_props, "Holding cell", Vector3(0,2.0,-9.5), Vector3(7,.25,4.0), game._mat(Color("87949a"), .3))
	interior_root.visible = false

func _register_existing_vehicle() -> void:
	vehicles.append({"node":game.car, "model":"sedan", "traffic":false, "occupied":false, "player":false, "stolen":false, "fuel":game.fuel, "axis":"", "direction":0.0, "speed":0.0})

func _spawn_city_traffic() -> void:
	var colors := [Color("d64848"), Color("3479b8"), Color("f2f0e6"), Color("303a42"), Color("54a174"), Color("c08a38"), Color("8056a2")]
	var models := ["sedan", "compact", "suv", "taxi"]
	var roads := [-180.0, -90.0, 0.0, 90.0, 180.0]
	for i in range(12):
		var axis := "x" if i % 2 == 0 else "z"
		var direction := 1.0 if i % 4 < 2 else -1.0
		var road: float = roads[i % roads.size()]
		var lane := 4.8 * direction
		var position := Vector3(-210.0 + float((i*41)%400), .85, road+lane) if axis == "x" else Vector3(road+lane, .85, -210.0+float((i*47)%400))
		_spawn_vehicle(position, models[i % models.size()], colors[i % colors.size()], true, axis, direction, 7.0+float(i%4))
	# A parked police vehicle can be used by police or stolen by a criminal.
	var police_vehicle := _spawn_vehicle(POLICE_STATION+Vector3(6, -.45, 5), "police", Color.WHITE, false, "", 0.0, 0.0)
	police_vehicle["occupied"] = false

func _spawn_vehicle(position: Vector3, model: String, color: Color, traffic: bool, axis: String, direction: float, speed: float) -> Dictionary:
	var node := Node3D.new()
	node.name = "CityVehicle_%02d_%s" % [vehicles.size(), model]
	node.position = position
	game.add_child(node)
	game._build_sedan(node, model == "police", Color("f0c531") if model == "taxi" else color)
	if model == "compact":
		node.scale = Vector3(.86,.88,.9)
	elif model == "suv":
		node.scale = Vector3(1.08,1.16,1.06)
	if model == "taxi":
		game._box(node, "Taxi sign", Vector3(0,1.65,.1), Vector3(.9,.25,.35), game._mat(Color("fff0a1"), .2))
	var body := AnimatableBody3D.new()
	node.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4,1.6,4.8)
	collision.shape = shape
	collision.position.y = .3
	body.add_child(collision)
	node.rotation.y = (-PI/2.0 if direction > 0 else PI/2.0) if axis == "x" else (PI if direction > 0 else 0.0)
	var record := {"node":node, "model":model, "traffic":traffic, "occupied":traffic, "player":false, "stolen":false, "fuel":100.0, "axis":axis, "direction":direction, "speed":speed}
	vehicles.append(record)
	return record

func _make_rp_ui() -> void:
	var role_panel := PanelContainer.new()
	role_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	role_panel.position = Vector2(-190, 16)
	role_panel.add_theme_stylebox_override("panel", _panel_style())
	game.ui.add_child(role_panel)
	var roles := HBoxContainer.new()
	role_panel.add_child(roles)
	role_label = Label.new()
	role_label.custom_minimum_size.x = 105
	role_label.add_theme_font_size_override("font_size", 16)
	roles.add_child(role_label)
	for key in VALID_ROLES:
		var button := Button.new()
		button.text = ROLE_NAMES[key]
		button.pressed.connect(select_role.bind(key, true))
		roles.add_child(button)

	var status_panel := PanelContainer.new()
	status_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	status_panel.position = Vector2(-250, -128)
	status_panel.custom_minimum_size = Vector2(500, 0)
	status_panel.add_theme_stylebox_override("panel", _panel_style(.93, Color("f4c95d")))
	game.ui.add_child(status_panel)
	var status_stack := VBoxContainer.new()
	status_panel.add_child(status_stack)
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	status_stack.add_child(prompt_label)
	alert_label = Label.new()
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.modulate = Color("ffd37a")
	status_stack.add_child(alert_label)
	var bars := HBoxContainer.new()
	status_stack.add_child(bars)
	var health_text := Label.new()
	health_text.text = "SOG‘LIQ"
	bars.add_child(health_text)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(170, 18)
	health_bar.max_value = 100
	health_bar.show_percentage = true
	bars.add_child(health_bar)
	robbery_bar = ProgressBar.new()
	robbery_bar.custom_minimum_size = Vector2(180, 18)
	robbery_bar.max_value = 8.0
	robbery_bar.visible = false
	bars.add_child(robbery_bar)

	var action_row := HBoxContainer.new()
	action_row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_row.position = Vector2(-430, -65)
	game.ui.add_child(action_row)
	var order_button := Button.new()
	order_button.text = "Q  TASLIM / BUYRUQ"
	order_button.custom_minimum_size = Vector2(170, 52)
	order_button.pressed.connect(surrender_or_order)
	action_row.add_child(order_button)
	var weapon_button := Button.new()
	weapon_button.text = "G  QUROL"
	weapon_button.custom_minimum_size = Vector2(110, 52)
	weapon_button.pressed.connect(fire_weapon)
	action_row.add_child(weapon_button)

func select_role(role: String, announce: bool = true) -> void:
	if role not in VALID_ROLES:
		return
	if game.car_mode:
		_leave_vehicle()
	if robbery_state in ["looting", "escape"]:
		_cancel_robbery("Rol almashtirildi — bank o‘marishi bekor qilindi")
	game.player_role = role
	game.wanted_level = 0 if role == "police" else game.wanted_level
	compliance_active = false
	if role == "civilian":
		game.mission_target = game.DEPOT if game.job_pickup else game.JOB_STOPS[game.mission_stage % game.JOB_STOPS.size()]
	elif role == "thief":
		game.mission_target = BANK_ENTRANCE
	else:
		_assign_suspect()
	_update_marker()
	game._save_game()
	game._update_status()
	if announce:
		toast("Rol tanlandi: %s" % ROLE_NAMES[role])

func objective_text() -> String:
	if game.player_role == "thief":
		match robbery_state:
			"looting": return "BANK: seyf ochilmoqda — seyf yonida qoling"
			"escape": return "BANK: %d so‘mlik o‘ljani qutqarish nuqtasiga olib boring" % carried_loot
			"cooldown": return "BANK: xavfsizlik tiklanmoqda — %d soniya" % ceili(robbery_cooldown)
			_: return "O‘G‘RI: bankka kiring, seyf yonida R yoki E bosing"
	if game.player_role == "police":
		if current_suspect.is_empty():
			return "POLITSIYA: yangi chaqiruv kutilmoqda"
		if bool(current_suspect.get("fleeing", false)):
			return "POLITSIYA: gumondor qochmoqda — Q bilan hibs, G bilan zararsizlantirish"
		if bool(current_suspect.get("surrendered", false)):
			return "POLITSIYA: gumondor taslim bo‘ldi — yonida Q bosing"
		return "POLITSIYA: belgilangan gumondorga yaqinlashing va Q bosing"
	return "%s: %s | Mukofot: %d so‘m" % ["TAKSI" if game.job == "taxi" else "KURYER", "Markazdan yo‘lovchi oling (mashinada)" if game.job == "taxi" and game.job_pickup else ("Markazdan paket oling" if game.job_pickup else "Belgilangan manzilga yetkazing"), 400 if game.job == "taxi" else 250]

func interact() -> bool:
	if inside_building:
		if game.player.global_position.distance_to(INTERIOR_EXIT) < 4.0:
			exit_building()
		elif current_entrance.get("kind", "") == "bank" and game.player.global_position.distance_to(VAULT_POSITION) < 5.0:
			start_bank_robbery()
		else:
			toast("Chiqish eshigi yoki amal nuqtasiga yaqinlashing")
		return true
	if game.car_mode:
		_leave_vehicle()
		return true
	var entrance := _nearest_entrance()
	if not entrance.is_empty():
		enter_building(entrance)
		return true
	var vehicle := _nearest_vehicle()
	if not vehicle.is_empty():
		_enter_vehicle(vehicle)
		return true
	return false

func _nearest_entrance() -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 5.8
	for entrance in entrances:
		var distance: float = game.player.global_position.distance_to(entrance["position"])
		if distance < best_distance:
			best_distance = distance
			best = entrance
	return best

func enter_building(entrance: Dictionary) -> void:
	if game.car_mode:
		toast("Avval mashinadan tushing")
		return
	inside_building = true
	current_entrance = entrance
	interior_root.visible = true
	interior_title.text = str(entrance["title"]).to_upper()
	bank_props.visible = entrance["kind"] == "bank"
	police_props.visible = entrance["kind"] == "police"
	game.player.position = INTERIOR_ORIGIN + Vector3(0, 1.3, 7.0)
	game.player.velocity = Vector3.ZERO
	game.mission_marker.visible = false
	toast("%s ichiga kirdingiz" % entrance["title"])

func exit_building() -> void:
	if not inside_building:
		return
	var outside: Vector3 = current_entrance["outside"]
	inside_building = false
	interior_root.visible = false
	game.player.position = outside
	game.player.velocity = Vector3.ZERO
	game.mission_marker.visible = true
	toast("Ko‘chaga chiqdingiz")

func _nearest_vehicle() -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 8.0
	for vehicle in vehicles:
		var node: Node3D = vehicle["node"]
		var distance: float = game.player.global_position.distance_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = vehicle
	return best

func _enter_vehicle(vehicle: Dictionary) -> void:
	var theft: bool = bool(vehicle["occupied"]) or vehicle["model"] == "police"
	if theft:
		vehicle["stolen"] = true
		vehicle["occupied"] = false
		if game.player_role == "police":
			toast("Mashina xizmat vazifasi uchun olindi")
		else:
			game.wanted_level = maxi(game.wanted_level, 3 if vehicle["model"] == "police" else 1)
			game.wanted_timer = 90.0
			toast("Begona mashina olindi — politsiya qidirmoqda")
	current_vehicle = vehicle
	vehicle["traffic"] = false
	vehicle["player"] = true
	game.car = vehicle["node"]
	game.fuel = float(vehicle["fuel"])
	game.car_velocity = 0.0
	game.car_angle = game.car.rotation.y
	game._toggle_car()

func _leave_vehicle() -> void:
	if not game.car_mode:
		return
	if not current_vehicle.is_empty():
		current_vehicle["fuel"] = game.fuel
		current_vehicle["player"] = false
		current_vehicle["traffic"] = false
	game._toggle_car()

func vehicle_blocked(candidate: Vector3, current: Vector3, own: Node3D) -> bool:
	for vehicle in vehicles:
		var node: Node3D = vehicle["node"]
		if node == own:
			continue
		var future := candidate - node.position
		var now := current - node.position
		future.y = 0
		now.y = 0
		if future.length() < 5.0 and future.length() < now.length():
			return true
	return false

func _process(delta: float) -> void:
	_update_traffic(delta)
	if game.car_mode and not current_vehicle.is_empty():
		current_vehicle["fuel"] = game.fuel
	weapon_cooldown = maxf(0.0, weapon_cooldown-delta)
	robbery_cooldown = maxf(0.0, robbery_cooldown-delta)
	if robbery_state == "cooldown" and robbery_cooldown <= 0.0:
		robbery_state = "idle"
	_update_robbery(delta)
	_update_police_assignment()
	toast_timer = maxf(0.0, toast_timer-delta)
	ui_timer += delta
	if ui_timer >= .15:
		ui_timer = 0.0
		_refresh_ui()

func _update_traffic(delta: float) -> void:
	for vehicle in vehicles:
		if not bool(vehicle["traffic"]) or bool(vehicle["player"]):
			continue
		var node: Node3D = vehicle["node"]
		var direction: float = vehicle["direction"]
		var movement := direction * float(vehicle["speed"]) * delta
		if vehicle["axis"] == "x":
			node.position.x += movement
			if node.position.x > 225: node.position.x = -225
			if node.position.x < -225: node.position.x = 225
		else:
			node.position.z += movement
			if node.position.z > 225: node.position.z = -225
			if node.position.z < -225: node.position.z = 225
		var focus: Vector3 = game.car.global_position if game.car_mode else game.player.global_position
		node.visible = node.global_position.distance_squared_to(focus) < 48400.0

func start_bank_robbery() -> bool:
	if game.player_role != "thief":
		toast("Bank seyfini faqat O‘G‘RI roli ochishi mumkin")
		return false
	if not inside_building or current_entrance.get("kind", "") != "bank":
		toast("Avval Markaziy bank seyfiga kiring")
		return false
	if game.player.global_position.distance_to(VAULT_POSITION) > 5.0:
		toast("Seyfga yaqinlashing")
		return false
	if robbery_state != "idle":
		toast("Bank hozir tayyor emas")
		return false
	robbery_state = "looting"
	robbery_timer = 0.0
	toast("Signalizatsiya ishga tushdi — 8 soniya seyf yonida qoling")
	return true

func _update_robbery(delta: float) -> void:
	if robbery_state == "looting":
		if not inside_building or game.player.global_position.distance_to(VAULT_POSITION) > 5.5:
			_cancel_robbery("Seyfdan uzoqlashdingiz — o‘marish bekor qilindi")
			return
		robbery_timer += delta
		if robbery_timer >= 8.0:
			_finish_looting()
	elif robbery_state == "escape":
		var actor: Node3D = game.car if game.car_mode else game.player
		if not inside_building and actor.global_position.distance_to(BANK_ENTRANCE) > 110.0:
			_complete_robbery()

func _finish_looting() -> void:
	robbery_state = "escape"
	carried_loot = 3000
	game.wanted_level = 3
	game.wanted_timer = 150.0
	game.mission_target = ESCAPE_POINT
	_update_marker()
	toast("Seyf ochildi: 3000 so‘m o‘lja. Shahardan uzoqlashing!")

func _complete_robbery() -> void:
	game.cash += carried_loot
	carried_loot = 0
	robbery_state = "cooldown"
	robbery_cooldown = 60.0
	game.mission_target = BANK_ENTRANCE
	_update_marker()
	game._save_game()
	game._update_status()
	toast("Bank o‘marishi bajarildi — pul balansga tushdi")

func _cancel_robbery(message: String = "") -> void:
	robbery_state = "idle"
	robbery_timer = 0.0
	carried_loot = 0
	if not message.is_empty():
		toast(message)

func surrender_or_order() -> void:
	if game.player_role != "police" and game.wanted_level > 0:
		_arrest_player(false)
		return
	if game.player_role == "police":
		_order_suspect()
	else:
		toast("Hozir taslim bo‘lish talabi yo‘q")

func update_police_response(delta: float, nearest: float) -> void:
	if game.player_role == "police":
		game.wanted_level = 0
		compliance_active = false
		return
	if game.wanted_level <= 0:
		compliance_active = false
		compliance_time = 5.0
		return
	if nearest < 19.0:
		if not compliance_active:
			compliance_active = true
			compliance_time = 5.0
			toast("POLITSIYA: TO‘XTANG! Q bilan taslim bo‘ling")
		compliance_time -= delta
		if compliance_time <= 0.0 and nearest < 25.0:
			police_shot_timer -= delta
			if police_shot_timer <= 0.0:
				police_shot_timer = 1.15
				game.player_health = maxi(0, game.player_health-15)
				toast("Politsiya ogohlantiruvchi o‘t ochdi — sog‘liq %d" % game.player_health)
				if game.player_health <= 0:
					_arrest_player(true)

func _arrest_player(wounded: bool) -> void:
	if game.car_mode:
		_leave_vehicle()
	game.wanted_level = 0
	game.wanted_timer = 0.0
	game.player_health = 100
	game.cash = maxi(0, game.cash-(500 if wounded else 300))
	if inside_building:
		inside_building = false
		interior_root.visible = false
		current_entrance = {}
		game.mission_marker.visible = true
	game.player.position = HOSPITAL if wounded else POLICE_STATION
	game.player.velocity = Vector3.ZERO
	compliance_active = false
	compliance_time = 5.0
	_cancel_robbery()
	game._save_game()
	game._update_status()
	toast("%s: jarima yechildi va qidiruv bekor qilindi" % ("Shifoxona" if wounded else "Hibs"))

func _assign_suspect() -> void:
	current_suspect = {}
	for npc in game.pedestrians:
		if bool(npc.get("criminal", false)) and not bool(npc.get("surrendered", false)):
			current_suspect = npc
			break
	if current_suspect.is_empty():
		for npc in game.pedestrians:
			npc["surrendered"] = false
			npc["health"] = 100
			if bool(npc.get("criminal", false)):
				current_suspect = npc
				break

func _update_police_assignment() -> void:
	if game.player_role != "police" or current_suspect.is_empty():
		return
	var suspect: Node3D = current_suspect["node"]
	game.mission_target = suspect.global_position
	_update_marker()

func _order_suspect() -> void:
	if current_suspect.is_empty():
		_assign_suspect()
		return
	var suspect: Node3D = current_suspect["node"]
	var distance: float = game.player.global_position.distance_to(suspect.global_position)
	if distance > 18.0:
		toast("Gumondorga yaqinroq boring")
		return
	if bool(current_suspect.get("surrendered", false)):
		_arrest_suspect()
		return
	if bool(current_suspect.get("fleeing", false)):
		if distance < 5.0:
			current_suspect["surrendered"] = true
			current_suspect["fleeing"] = false
			_arrest_suspect()
		else:
			toast("Gumondor qochmoqda — ortidan boring")
		return
	if game.mission_stage % 2 == 0:
		current_suspect["surrendered"] = true
		toast("Gumondor buyruqqa bo‘ysundi — Q bilan hibsga oling")
	else:
		current_suspect["fleeing"] = true
		toast("Gumondor buyruqqa bo‘ysunmadi va qochdi")

func _arrest_suspect() -> void:
	game.cash += 500
	game.mission_stage += 1
	current_suspect["fleeing"] = false
	current_suspect["surrendered"] = true
	toast("Gumondor hibsga olindi: +500 so‘m")
	_assign_suspect()
	game._save_game()
	game._update_status()

func fire_weapon() -> bool:
	if weapon_cooldown > 0.0:
		return false
	if game.player_role not in ["police", "thief"]:
		toast("Qurol faqat politsiya yoki o‘g‘ri rolida mavjud")
		return false
	var target: Dictionary = {}
	if game.player_role == "police":
		if not current_suspect.is_empty() and bool(current_suspect.get("fleeing", false)):
			target = current_suspect
	else:
		var closest := 26.0
		for npc in game.pedestrians:
			var distance: float = game.player.global_position.distance_to((npc["node"] as Node3D).global_position)
			if distance < closest and not bool(npc.get("surrendered", false)):
				closest = distance
				target = npc
	if target.is_empty():
		toast("Nishon yo‘q")
		return false
	var target_node: Node3D = target["node"]
	if game.player.global_position.distance_to(target_node.global_position) > 30.0:
		toast("Nishon uzoqda")
		return false
	weapon_cooldown = .55
	target["health"] = maxi(0, int(target.get("health", 100))-50)
	target["knocked"] = 1.0
	if game.player_role == "thief":
		game.wanted_level = mini(3, game.wanted_level+1)
		game.wanted_timer = 120.0
	if int(target["health"]) <= 0:
		target["surrendered"] = true
		target["fleeing"] = false
		target["knocked"] = 15.0
		toast("Nishon zararsizlantirildi")
	else:
		toast("O‘q tegdi — nishon sog‘ligi %d" % target["health"])
	return true

func _refresh_ui() -> void:
	role_label.text = "%s  |  %d so‘m" % [ROLE_NAMES.get(game.player_role, "FUQARO"), game.cash]
	health_bar.value = game.player_health
	robbery_bar.visible = robbery_state == "looting"
	robbery_bar.value = robbery_timer
	if toast_timer <= 0.0:
		alert_label.text = ""
	if compliance_active:
		alert_label.text = "POLITSIYA BUYRUG‘I: Q BILAN TASLIM  |  %.1f s" % maxf(0.0, compliance_time)
	var prompt := _interaction_prompt()
	prompt_label.text = prompt
	game._update_status()
	if "CHIQISH" in prompt:
		game.action_button.text = "E  CHIQISH"
	elif "KIRISH" in prompt:
		game.action_button.text = "E  KIRISH"
	elif "TUSHISH" in prompt:
		game.action_button.text = "E  TUSHISH"
	elif "HAYDASH" in prompt:
		game.action_button.text = "E  HAYDASH"
	elif "SEYF" in prompt:
		game.action_button.text = "E  SEYF"
	else:
		game.action_button.text = "E  AMAL"

func _interaction_prompt() -> String:
	if inside_building:
		if game.player.global_position.distance_to(INTERIOR_EXIT) < 4.0:
			return "E  BINODAN CHIQISH"
		if current_entrance.get("kind", "") == "bank" and game.player.global_position.distance_to(VAULT_POSITION) < 5.0:
			return "R yoki E  BANK SEYFINI OCHISH"
		return "%s  |  chiqish eshigiga boring" % current_entrance.get("title", "Bino")
	if game.car_mode:
		return "E  MASHINADAN TUSHISH"
	var entrance := _nearest_entrance()
	if not entrance.is_empty():
		return "E  %s ICHIGA KIRISH" % str(entrance["title"]).to_upper()
	var vehicle := _nearest_vehicle()
	if not vehicle.is_empty():
		return "E  %s HAYDASH%s" % [str(vehicle["model"]).to_upper(), " (BEGONA)" if vehicle["occupied"] else ""]
	if game.player_role == "police":
		return "Q  GUMONDORGA BUYRUQ  |  G  QUROL"
	if game.wanted_level > 0:
		return "Q  TASLIM BO‘LISH"
	return "E  BINOGA KIRISH YOKI MASHINA HAYDASH"

func _update_marker() -> void:
	if game.mission_marker:
		game.mission_marker.position = game.mission_target + Vector3(0,4,0)

func toast(message: String) -> void:
	if alert_label:
		alert_label.text = message
	toast_timer = 3.5
