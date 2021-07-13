extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var time = 0

const radius = 4
const minRepulse = 0
const maxRepulse = 10

const springLength = 2
const springFactor = 50
const springMax = 1000
const springFactorIncoming = 1
const springFactorOutgoing = 2

const originFactor = 1

const convergenceRate = 0.005

var velocityFactor = 1

var NodeClass = preload("res://CallGraph/GraphNode.tscn")
var EdgeClass = preload("res://CallGraph/Edge.tscn")

var nodesByName = {}
var nodeVel = {}
var nodeEdgeCount = {}
var nodeList = []
var edges = []
var bidiEdges = []
var nodeDistances = {}
var forwardEdges = {}
var backwardEdges = {}
var nodeDetailTexts = {}
var nodeDetailObjects = {}

var focusDistanceForward = {}
var focusDistanceBackward = {}

var focusNode = null
var hoverNodes = {}

var cameraPosition = Vector3(0, 0, 0)

var outColor = Color8(80, 220, 255)
var inColor = Color8(240, 120, 80)
var unrelatedColor = Color8(128, 128, 128)

var DetailsPanel = preload("res://CallGraph/DetailsPanel.tscn")

var NodeMaterial = preload("res://CallGraph/NodeMaterial.tres")
var NodeMaterialFocused = preload("res://CallGraph/FocusNodeMaterial.tres")
var NodeMaterialOut = preload("res://CallGraph/NodeMaterialOut.tres")
var NodeMaterialIn = preload("res://CallGraph/NodeMaterialIn.tres")
var NodeMaterialUnrelated = preload("res://CallGraph/NodeMaterialUnrelated.tres")

var EdgeConeMaterial = preload("res://CallGraph/EdgeCone.tres")
var EdgeConeMaterialOut = EdgeConeMaterial.duplicate()
var EdgeConeMaterialIn = EdgeConeMaterial.duplicate()
var EdgeConeMaterialUnrelated = EdgeConeMaterial.duplicate()

var EdgeParticles = preload("res://CallGraph/EdgeParticles.tres")
var EdgeParticlesOut = EdgeParticles.duplicate()
var EdgeParticlesIn = EdgeParticles.duplicate()
var EdgeParticlesUnrelated = EdgeParticles.duplicate()

var fadedMaterials = {}

func connectNodes(node1, node2, edge):
	edge.look_at_from_position(node1.translation, node2.translation, node1.translation - cameraPosition)
	edge.translation = node1.translation
	edge.scale.z = (node1.translation.distance_to(node2.translation) / 8)


func reset():
	loadJSON("user://callgraph.json")

func setAlpha(color, a):
	return Color(color.r, color.g, color.b, a)

func fadeAlpha(color, fade):
	return Color(color.r, color.g, color.b, color.a * fade)

func recolorGradient(gradTex, color, fade):
	gradTex = gradTex.duplicate()
	var grad = gradTex.gradient.duplicate()
	gradTex.gradient = grad
	for i in range(grad.get_point_count()):
		var col = grad.get_color(i)
		if color != null:
			col.r = color.r
			col.g = color.g
			col.b = color.b
		col.a = col.a * fade
		grad.set_color(i, col)
	return gradTex

func recolorParticles(particles, color = null, fade = 1):
	if particles:
		particles.trail_color_modifier = recolorGradient(particles.trail_color_modifier, color, fade)
		particles.color_ramp = recolorGradient(particles.color_ramp, color, fade)

func getFadedMaterial(mat):
	if not mat in fadedMaterials:
		var faded = mat.duplicate()
		if faded is ParticlesMaterial:
			recolorParticles(faded, null, 0.4)
		if faded is SpatialMaterial:
			faded.albedo_color = fadeAlpha(faded.albedo_color, 0.4)
		fadedMaterials[mat] = faded
	return fadedMaterials[mat]

# Called when the node enters the scene tree for the first time.
func _ready():
	EdgeConeMaterialIn.albedo_color = setAlpha(inColor, EdgeConeMaterialIn.albedo_color.a)
	EdgeConeMaterialOut.albedo_color = setAlpha(outColor, EdgeConeMaterialOut.albedo_color.a)
	EdgeConeMaterialUnrelated.albedo_color = setAlpha(unrelatedColor, EdgeConeMaterialUnrelated.albedo_color.a)
	recolorParticles(EdgeParticlesOut, outColor)
	recolorParticles(EdgeParticlesIn, inColor)
	recolorParticles(EdgeParticlesUnrelated, unrelatedColor)
	reset()


func _input(event):
	if event is InputEventKey and event.pressed:
		if event.scancode == KEY_R:
			reset()


func initVelocities():
	nodeVel = {}
	for node in nodeList:
		nodeVel[node] = Vector3(0, 0, 0)


func processOverlap(delta):
	for node1 in nodeList:
		for node2 in node1.get_overlapping_areas():
			# Skip nodes with edges
			if not node2 in nodeDistances[node1]:
				var force = (node1.translation - node2.translation)
				var factor = clamp(force.length() / radius, 0, 1)
				force = force.normalized() * ((1 - factor) * maxRepulse + factor * minRepulse) * delta
				nodeVel[node1] += force
				nodeVel[node2] -= force

func processEdgeConstraints(delta):
	for edge in bidiEdges:
		var node1 = edge[0]
		var node2 = edge[1]
		var force = (node2.translation - node1.translation)
		var effectiveSpringLength = springLength
		if node1 == focusNode || node2 == focusNode:
			effectiveSpringLength *= 0.5
		var forceLength = clamp((force.length() - effectiveSpringLength) * springFactor, -springMax, springMax) * edge[2]
		force = force.normalized() * forceLength * delta
		nodeVel[node1] += force / (nodeEdgeCount[node1] + 2) * springFactorOutgoing
		nodeVel[node2] -= force / (nodeEdgeCount[node2] + 2) * springFactorIncoming

func applyVelocity(delta):
	var meanSquareError = 0
	for node in nodeList:
		meanSquareError += nodeVel[node].length_squared()

	velocityFactor = velocityFactor * clamp(meanSquareError / nodeList.size() * convergenceRate + (1 - convergenceRate), 0, 1)

	var effectiveVelocityFactor = velocityFactor

	var origin = Vector3(0, 0, 0)
	if focusNode != null:
		effectiveVelocityFactor *= 0.2
		origin = focusNode.translation

	for node in nodeList:
		node.translation += (nodeVel[node] + (origin - node.translation) * delta * originFactor) * effectiveVelocityFactor

	if focusNode != null:
		focusNode.translation = origin

func connectAllNodes():
	for edge in edges:
		connectNodes(edge[1], edge[2], edge[0])


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	cameraPosition = get_viewport().get_camera().translation
	# Force fixed framerate
	delta = 1 / 60.0
	if velocityFactor > 0.0001:
		initVelocities()
		processOverlap(delta)
		processEdgeConstraints(delta)
		applyVelocity(delta)
	connectAllNodes()
	#rotateDetailsToCamera()


func buildDistanceMap(start, edgeMap):
	var distanceMap = {}
	var pending = {}
	pending[start] = 0
	while true:
		# Find closest pending node
		var current
		for node in pending:
			if current == null or pending[node] < pending[current]:
				current = node

		# No more pending nodes: we are done
		if current == null:
			return distanceMap

		# Loop over edges
		var dist = pending[current] + 1
		for node in edgeMap[current]:
			if node in pending:
				pending[node] = min(pending[node], dist)
			elif !(node in distanceMap):
				pending[node] = dist
		distanceMap[current] = pending[current]
		pending.erase(current)


func updateEdgeColors():
	for edge in edges:
		var particles = edge[0].get_node("Particles")
		var barrel = edge[0].get_node("Barrel")

		if not (edge[1] in focusDistanceForward or edge[2] in focusDistanceBackward):
			particles.process_material = getFadedMaterial(EdgeParticlesUnrelated)
			barrel.material = getFadedMaterial(EdgeConeMaterialUnrelated)
			continue

		var distF = focusDistanceForward.get(edge[1], 10000)
		var distB = focusDistanceBackward.get(edge[2], 10000)

		var distDiff = distF - distB
		if distDiff > 0:
			particles.process_material = EdgeParticlesIn
			barrel.material = EdgeConeMaterialIn
		elif distDiff < 0:
			particles.process_material = EdgeParticlesOut
			barrel.material = EdgeConeMaterialOut
		else:
			particles.process_material = EdgeParticles
			barrel.material = EdgeConeMaterial

		if min(distF, distB) > 0:
			particles.process_material = getFadedMaterial(particles.process_material)
			barrel.material = getFadedMaterial(barrel.material)

	# Update edge force multipliers
	for edge in bidiEdges:
		if edge[0] in focusDistanceForward or edge[1] in focusDistanceBackward:
			edge[2] = 2
		else:
			edge[2] = 0.5

	# Update node colors
	for node in nodeList:
		var mat = NodeMaterial
		var sca = 1

		if not (node in focusDistanceForward or node in focusDistanceBackward):
			mat = getFadedMaterial(NodeMaterialUnrelated)
			sca = 0.5
		else:
			var distF = focusDistanceForward.get(node, 10000)
			var distB = focusDistanceBackward.get(node, 10000)
			var distDiff = distF - distB
			sca = (1 / (min(distF, distB) + 1)) * 0.25 + 0.75
			if distDiff > 0:
				mat = NodeMaterialIn
			elif distDiff < 0:
				mat = NodeMaterialOut
			if min(distF, distB) > 1:
				mat = getFadedMaterial(mat)
		var mesh = node.get_node("MeshInstance")
		mesh.set_surface_material(0, mat)
		mesh.scale = Vector3(1, 1, 1) * sca

	if focusNode:
		focusNode.find_node("MeshInstance").set_surface_material(0, NodeMaterialFocused)
		focusNode.find_node("MeshInstance").scale = Vector3(1, 1, 1) * 1.25


func getDetails(node):
	if node == null:
		return null
	else:
		return nodeDetailObjects.get(node)


func updateDetails(node, details):
	details.update(nodeDetailTexts.get(node, "(Unknown)"))


func updateDetailPriority(node):
	var maxDetail = null
	for detail in nodeDetailObjects.values():
		if detail.get_parent() == node:
			if maxDetail == null || detail.scale.x > maxDetail.scale.x:
				maxDetail = detail
			detail.visible = false
	if maxDetail != null:
		maxDetail.visible = true


func setDetails(id, node, sca = 1):
	var details = nodeDetailObjects.get(id)
	if details == null:
		details = DetailsPanel.instance()
		details.scaleFactor = sca
		nodeDetailObjects[id] = details

	var parent = details.get_parent()

	if parent == node:
		return

	if parent != null:
		parent.remove_child(details)
		updateDetailPriority(parent)

	if node != null:
		node.add_child(details)
		updateDetails(node, details)
		updateDetailPriority(node)


func setFocusNode(node):
	if node == focusNode || (node != null && node.get_parent() != $Nodes):
		return

	focusNode = node

	if focusNode:
		focusDistanceForward = buildDistanceMap(focusNode, forwardEdges)
		focusDistanceBackward = buildDistanceMap(focusNode, backwardEdges)
	else:
		focusDistanceForward = {}
		focusDistanceBackward = {}

	updateEdgeColors()

	setDetails("focus", focusNode)

	velocityFactor = 1


func loadJSON(filename):
	var file = File.new()
	file.open(filename, File.READ)
	var json = JSON.parse(file.get_as_text()).result

	setFocusNode(null)

	for n in $Nodes.get_children():
		$Nodes.remove_child(n)
		n.queue_free()

	for e in $Edges.get_children():
		$Edges.remove_child(e)
		e.queue_free()

	nodesByName = {}
	nodeEdgeCount = {}
	nodeList = []
	edges = []
	bidiEdges = []
	nodeDistances = {}
	nodeDetailTexts = {}
	nodeDetailObjects = {}

	forwardEdges = {}
	backwardEdges = {}

	velocityFactor = 1

	# Trim orphans
	var orphans = {}
	for node in json.nodes:
		if node.edges.empty():
			if not node.name in orphans:
				orphans[node.name] = true
		else:
			for edge in node.edges:
				orphans[edge] = false

	for node in json.nodes:
		if orphans.get(node.name, false):
			continue
		# TODO Skip "null function" node, because it doesn't actually call these functions
		var nodeObject = NodeClass.instance()
		nodeObject.translation = Vector3(rand_range(-5, 5), rand_range(-5, 5), rand_range(-5, 5))
		$Nodes.add_child(nodeObject)
		nodesByName[node.name] = nodeObject
		nodeList.append(nodeObject)
		nodeEdgeCount[nodeObject] = 0
		nodeDistances[nodeObject] = {}
		forwardEdges[nodeObject] = []
		backwardEdges[nodeObject] = []
		nodeDetailTexts[nodeObject] = node.simpleName

	for node in json.nodes:
		if orphans.get(node.name, false):
			continue
		for edge in node.edges:
			if edge != node.name and node.name in nodesByName and edge in nodesByName:
				var node1 = nodesByName[node.name]
				var node2 = nodesByName[edge]
				# Deduplicate (TODO: store as edge weight instead?)
				if node2 in nodeDistances[node1] and nodeDistances[node1][node2] > 0:
					continue

				var edgeObject = EdgeClass.instance()
				$Edges.add_child(edgeObject)
				edges.append([edgeObject, node1, node2])
				if node.name < edge:
					bidiEdges.append([node1, node2, 1])
				else:
					bidiEdges.append([node2, node1, 1])
				nodeEdgeCount[node1] += 1
				nodeEdgeCount[node2] += 1
				# TODO remove duplicate edges
				nodeDistances[node1][node2] = 1
				nodeDistances[node2][node1] = -1
				# Add to forward/backward edge list
				forwardEdges[node1].append(node2)
				backwardEdges[node2].append(node1)

	for node in nodeDetailTexts:
		nodeDetailTexts[node] += "\n[i][color=#ff8080]In: %s[/color] [color=#80ffff]Out: %s[/color][/i]" % [backwardEdges[node].size(), forwardEdges[node].size()]

	if "main" in nodesByName:
		var mainNode = nodesByName["main"]
		mainNode.translation /= 1000
		setFocusNode(mainNode)
