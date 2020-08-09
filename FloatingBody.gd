extends RigidBody

var parent : Node
var ocean : Ocean
var dbg : Label
var ref_plane_marker
var buoyancy_point_marker
onready var buoyancy_mesh := $GMeshInstance
export(int, 1, 10000000) var buoyancy_factor := 50

const SEA_PLANE_EPSILON := 0.5
const DAMP_AIR := 0.7
const DAMP_WATER := 0.99
var full_volume := 0.0
var debug_mesh := false
var dd : DebugDraw3D

func _ready():
	self.set_linear_damp(0.7)
	self.set_angular_damp(0.7)

func init(parent: Node, ocean: Ocean, dbgLabel: Label, ref_plane_marker, buoyancy_point_marker) -> void:
	self.parent = parent
	self.ocean = ocean
	self.dbg = dbgLabel
	self.ref_plane_marker = ref_plane_marker
	self.buoyancy_point_marker = buoyancy_point_marker
	buoyancy_mesh.apply_transformation(Transform.IDENTITY)
	full_volume = buoyancy_mesh.calculate_centroid().volume * pow(buoyancy_mesh.EXPAND, 3)

func set_debug(enabled_mesh: bool, enabled_draw: bool, dbgLabel) -> void:
	debug_mesh = enabled_mesh
	if enabled_draw and not dd:
		dd = preload("res://externals/debug_draw_3d.gd").new(self)
	elif not enabled_draw and dd:
		dd.destroy()
		dd = null
	dbg = dbgLabel

func get_sea_level_at_point(point: Vector3) -> float:
	return ocean.get_displace(Vector2(point.x, point.z)).y

func get_sea_plane(point: Vector3) -> Plane:
	var point2d := Vector2(point.x, point.z)
	var tTL : Vector3 = ocean.get_displace(point2d + Vector2(-SEA_PLANE_EPSILON, -SEA_PLANE_EPSILON))
	var tTR : Vector3 = ocean.get_displace(point2d + Vector2(+SEA_PLANE_EPSILON, -SEA_PLANE_EPSILON))
	var tBL : Vector3 = ocean.get_displace(point2d + Vector2(-SEA_PLANE_EPSILON, +SEA_PLANE_EPSILON))
	var plane := Plane(tTL, tTR, tBL).normalized()
	return plane

func get_sea_transform_at_point(point: Vector3) -> Transform:
	var point2d := Vector2(point.x, point.z)
	var tTL : Vector3 = ocean.get_displace(point2d + Vector2(-1, -1))
	var tTR : Vector3 = ocean.get_displace(point2d + Vector2(+1, -1))
	var tBL : Vector3 = ocean.get_displace(point2d + Vector2(-1, +1))

	var ba := (tTR-tTL)
	var n := ba.cross(tBL-tTL)
	var w := n.normalized()
	var u := ba.normalized()
	var v := w.cross(u)
	var transform := Transform.IDENTITY
	transform.basis.x = u
	transform.basis.y = w
	transform.basis.z = v
	var tr := (tTR +  tBL) / 2
	transform.origin = tr
	return transform

func _integrate_forces(_state: PhysicsDirectBodyState) -> void:
	if not parent or not ocean:
		return

	if dbg: dbg_clear()
	var fu := 10.0
	if Input.is_action_pressed("ui_home"):
		add_force(Vector3(0,-fu,0), Vector3(-50,0,0))
	if Input.is_action_pressed("ui_end"):
		add_force(Vector3(0, fu,0), Vector3(-50,0,0))

	if dbg: d("rot %s", global_transform.basis.y)

	# buoyancy
	if dbg: d("point = %s", [pp(global_transform.origin)])
	var sea_plane : Plane = get_sea_plane(global_transform.origin)
	if ref_plane_marker:
		ref_plane_marker.global_transform = get_sea_transform_at_point(global_transform.origin)
		ref_plane_marker.global_transform.origin = sea_plane.center()
	var buoyancy_data := calculate_buoyancy(sea_plane)
	var damp := DAMP_AIR
	if buoyancy_data.volume > 0:
		damp += (DAMP_WATER - DAMP_AIR) * buoyancy_data.volume/full_volume
		if damp > DAMP_WATER:
			damp = DAMP_WATER # FIXME: sometimes calculated submerged volume is bigger than full volume!
	set_linear_damp(damp)
	set_angular_damp(damp)
	if dbg: d("damp: %s (vol %s, full %s)", [pf(damp), pf(buoyancy_data.volume), pf(full_volume)])
	if dbg: d("vol %s centroid %s", [ pf(buoyancy_data.volume), pv(buoyancy_data.centroid) ])
	if buoyancy_point_marker:
		buoyancy_point_marker.visible = (buoyancy_data.volume > 0.0)
		var delta := Vector3(global_transform.origin.x, -1, global_transform.origin.z)
		buoyancy_point_marker.global_transform.origin = buoyancy_data.centroid  +  delta # Vector3(0,-1,0)# transform.xform(point) +  Vector3(0,-1,0)
	apply_buoyancy(sea_plane.normal, buoyancy_data)
	if dd: dd.draw()

var mi
func calculate_buoyancy(plane: Plane) -> GMesh.GCentroidVolume:
	buoyancy_mesh.apply_transformation(self.global_transform)
	var newgmesh = buoyancy_mesh.get_clipped_gmesh(plane)
	if not newgmesh:
		return GMesh.GCentroidVolume.new(Vector3.ZERO, 0.0)

	var cv = newgmesh.calculate_centroid()
	# the centroid is in global coordinates. convert to offset relative to Body
	var o := self.global_transform.origin
	o.y = 0
	cv.centroid -= o

	if mi:
		mi.queue_free()
		mi = null

	if debug_mesh and newgmesh:
		var newgmeshinstance : GMeshInstance = GMeshInstance.new()
		newgmeshinstance.fill_new_gmeshinstance(newgmesh, self.global_transform.origin)
		newgmeshinstance.name = "submerged"
		parent.add_child(newgmeshinstance)
		mi = newgmeshinstance

	return cv

func apply_buoyancy(normal: Vector3, centroidVolume: GMesh.GCentroidVolume) -> void:
	var point := centroidVolume.centroid
	var buoyancy := 0.0
	if centroidVolume.volume > 0:
		buoyancy = buoyancy_factor * centroidVolume.volume
	if buoyancy > 1000:
		print("BIG BUOYANCY!!!! %s" % buoyancy)
#	var bforce := Vector3(0, buoyancy, 0)
	var scale := centroidVolume.volume/full_volume
	var v := normal.linear_interpolate(Vector3.UP, scale)
	var bforce := buoyancy * v
	add_force(bforce, point)
	if dbg: d("buoyancy: point %s, force %s", [ pp(point),pv(bforce) ])
	if dbg: d("buoyancy: scale %s", [ pf(scale) ])
	if dbg: d("    normal %s", [ pv(normal) ])
	if dbg: d("    vector %s", [ pv(v) ])
	if dd:
		var dscale := 2.0
		var p2 : Vector3 = global_transform.basis.xform_inv(dscale*v)
		dd.add_vector(Vector3.ZERO, p2, 0.1, Color.red, true)
		p2 = global_transform.basis.xform_inv(dscale*normal)
		dd.add_vector(Vector3.ZERO, p2, 0.1, Color.blue, true)
		p2 = global_transform.basis.xform_inv(dscale*Vector3.UP)
		dd.add_vector(Vector3.ZERO, p2, 0.05, Color(0,1,0,0.5), true)
		p2 = global_transform.basis.xform_inv(bforce)
		dd.add_vector(Vector3.ZERO, p2, 0.1, Color(1,1,1,0.7), true)
#	var pos := point + Vector3(global_transform.origin.x, 0, global_transform.origin.z)

func pf(f : float) -> String:
	return "%+2.3f" % f

func pv(v : Vector3) -> String:
	return "%+2.3f (%+2.3f,%+2.3f,%+2.3f)" % [ v.length(), v.x, v.y, v.z]

func pp(v : Vector3) -> String:
	return "(%+2.3f,%+2.3f,%+2.3f)" % [ v.x, v.y, v.z]

func d(fmt: String, params) -> void:
	if dbg:
		dbg.text += fmt % params
		dbg.text += "\n"

func dbg_clear() -> void:
	if dbg:
		dbg.text = ""
