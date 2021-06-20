extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var quadOffset = 0

export var distanceScale: Curve
export var cameraLerpFactorAngle: Curve
export var cameraLerpFactorDistance: Curve
export(float, 1, 1000, 0.1) var distanceFactorIn: float = 10
export(float, 1, 50, 0.1) var distanceFactorOut: float = 10


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func updateQuad():
	var quad = $Quad
	quad.translation.x = quad.mesh.size.x / 2 + quadOffset / scale.x
	quad.translation.y = -quad.mesh.size.y / 2


func update(text):
	var node = get_parent()
	scale = Vector3(1, 1, 1) * 5
	var mesh = node.get_node("MeshInstance")
	quadOffset = mesh.mesh.radius * mesh.scale.x + 0.02
	updateQuad()
	#quad.translation.x = quad.mesh.size.x / 2 + (mesh.mesh.radius * mesh.scale.x + 0.02) / scale.x
	$Viewport/Text.text = text
	$Viewport.render_target_update_mode = Viewport.UPDATE_ONCE

func lerpBasis(a, b, factor):
	return Basis(Quat(a.get_rotation_quat()).slerp(Quat(b.get_rotation_quat()), factor))

func projX(vec):
	return Vector3(vec.x, 0, vec.z)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var cameraPosition = get_viewport().get_camera().translation
	var cameraDirection = get_viewport().get_camera().transform.basis.z
	#var center = $Quad.mesh.size / 2
	#var oldPos = translation
	translation = Vector3(0, 0, 0)
	#translate_object_local(-Vector3(center.x, center.y, 0))
	look_at(cameraPosition, Vector3.UP)
	rotate_object_local(Vector3(0, 1, 0), PI)
	var distance = (to_global(Vector3(0, 0, 0)) - cameraPosition).length()
	var scaleFac = distanceScale.interpolate(distance / distanceFactorIn) * distanceFactorOut
	var dirFac = min(cameraLerpFactorDistance.interpolate(scaleFac / distance / 3), cameraLerpFactorAngle.interpolate(projX(transform.basis.z).angle_to(projX(cameraDirection)) / PI))
	#print(scaleFac / distance / 3, " ", cameraLerpFactorDistance.interpolate(scaleFac / distance / 3), " ", cameraLerpFactorAngle.interpolate(projX(transform.basis.z).angle_to(projX(cameraDirection)) / PI))
	#var dirFac = cameraLerpFactor.interpolate(projX(transform.basis.z).angle_to(projX(cameraDirection)) / PI)
	transform.basis = lerpBasis(transform.basis, get_viewport().get_camera().transform.basis, dirFac)
	scale = Vector3(1, 1, 1) * scaleFac
	#rotate_object_local(Vector3(0, 1, 0), transform.basis.z.angle_to(cameraDirection))
	#translation = oldPos
	#look_at_from_position($Quad.to_global(Vector3(center.x, center.y, 0)), cameraPosition, Vector3.UP)
	updateQuad()
