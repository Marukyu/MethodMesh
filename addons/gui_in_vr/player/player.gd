extends ARVROrigin

# Future proofing.
const XRServer = ARVRServer

var _ws := 1.0
var enableVR := true

var holdLT = false
var holdRT = false

var holdMenu = false

var gui2D
var guiPanel : Spatial

onready var _camera = $XRCamera
onready var _camera_near_scale = _camera.near
onready var _camera_far_scale = _camera.far

var GUIType = preload("res://addons/gui_in_vr/gui.tscn")
export(NodePath) var callGraphPath

func initVR():
	var vr = XRServer.find_interface("OpenVR")
	if vr and vr.initialize():
		var viewport = get_viewport()
		viewport.arvr = true
		#viewport.hdr = false
		OS.set_window_maximized(true)
		OS.vsync_enabled = false
		Engine.target_fps = 180
		guiPanel = get_parent().find_node("GUIPanel3D")
		gui2D = guiPanel.find_node("Viewport").find_node("GUI")
		gui2D.callgraph = get_node(callGraphPath).get_path()
		gui2D.connect("datasetLoaded", get_node(callGraphPath), "loadJSON")
	else:
		printerr("Can't initialize OpenVR, exiting.")
		get_tree().quit()


func _ready():
	if enableVR:
		initVR()
	else:
		get_parent().find_node("GUIPanel3D").queue_free()
		get_parent().find_node("Crosshair").show()
		gui2D = GUIType.instance()
		get_parent().call_deferred("add_child", gui2D)
		gui2D.connect("datasetLoaded", get_node(callGraphPath), "loadJSON")
		gui2D.visible = false
		gui2D.callgraph = get_node(callGraphPath).get_path()
		Engine.target_fps = 60
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func checkNodeCollision(raycast, press):
	var collider = raycast.get_collider()
	if collider && collider.is_in_group("nodeHitbox"):
		setHoverNode(raycast, collider.get_parent())
		if press:
			setFocusNode(collider.get_parent())


func doControllerMovement(con, delta):
	var movement = Vector3(con.get_joystick_axis(JOY_ANALOG_LX), 0, -con.get_joystick_axis(JOY_ANALOG_LY))
	if movement.length() > 0.025:
		movement = movement.normalized() * movement.length_squared() * delta * 3
		movement = con.transform.basis.xform(movement)
		translate(movement)
		$LeftController.translate(movement)
		$RightController.translate(movement)


func _physics_process(delta):
	if enableVR:
		doControllerMovement($LeftController, delta)
		doControllerMovement($RightController, delta)


func checkShowGuiPanel(con : ARVRController):
	if con.is_button_pressed(JOY_BUTTON_1):
		guiPanel.visible = !guiPanel.visible
		#guiPanel.global_transform.origin = con.global_transform.origin
		guiPanel.transform = _camera.global_transform
		guiPanel.translate_object_local(Vector3.FORWARD * 1.75)
		guiPanel.scale = Vector3(1, 1, 1) * 5

func processVR(delta):
	var new_ws = XRServer.world_scale
	if _ws != new_ws:
		_ws = new_ws
		_camera.near = _ws * _camera_near_scale
		_camera.far = _ws * _camera_far_scale
		var child_count = get_child_count()
		for i in range(3, child_count):
			get_child(i).scale = Vector3.ONE * _ws

	var pressLT = ($LeftController.get_joystick_axis(JOY_VR_ANALOG_TRIGGER) > 0.6)
	var pressRT = ($RightController.get_joystick_axis(JOY_VR_ANALOG_TRIGGER) > 0.6)

	checkNodeCollision($LeftController/ControllerRayCast, pressLT && !holdLT)
	checkNodeCollision($RightController/ControllerRayCast, pressRT && !holdRT)

	holdLT = pressLT
	holdRT = pressRT

	var pressMenu = $LeftController.is_button_pressed(JOY_BUTTON_1) || $RightController.is_button_pressed(JOY_BUTTON_1)
	if pressMenu && !holdMenu:
		checkShowGuiPanel($LeftController)
		checkShowGuiPanel($RightController)
	holdMenu = pressMenu


func _input(event):
	if !enableVR:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED && !gui2D.visible && event is InputEventMouseButton:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE && event is InputEventMouseMotion:
			_camera.rotation_degrees.y -= (event.relative.x * 0.15)
			_camera.rotation_degrees.x = clamp(_camera.rotation_degrees.x - event.relative.y * 0.2, -90, 90)


func _notification(event):
	if !enableVR:
		if event == MainLoop.NOTIFICATION_WM_FOCUS_OUT:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func setFocusNode(node):
	get_parent().find_node("CallGraph").setFocusNode(node)

func setHoverNode(id, node):
	get_parent().find_node("CallGraph").setDetails(id, node, 0.7)

func processNonVR(delta):
	get_parent().find_node("Crosshair").position = get_viewport().size / 2
	var speed = delta * 2
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= 3
	if Input.is_action_pressed("move_right"):
		_camera.translate_object_local(Vector3(speed, 0, 0))
	if Input.is_action_pressed("move_left"):
		_camera.translate_object_local(Vector3(-speed, 0, 0))
	if Input.is_action_pressed("move_forward"):
		_camera.translate_object_local(Vector3(0, 0, -speed))
	if Input.is_action_pressed("move_backward"):
		_camera.translate_object_local(Vector3(0, 0, speed))
	if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		checkNodeCollision($XRCamera/RayCast, Input.is_action_just_pressed("select_focus_node"))
	if Input.is_action_just_pressed("toggle_menu"):
		gui2D.visible = !gui2D.visible
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if gui2D.visible else Input.MOUSE_MODE_CAPTURED)


func _process(delta):
	if enableVR:
		processVR(delta)
	else:
		processNonVR(delta)
