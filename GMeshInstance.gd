extends MeshInstance
class_name GMeshInstance

var gmesh: GMesh
const EXPAND := 1.01

func view_toggler_activated():
	self.visible = !self.visible

func _ready():
	gmesh = GMesh.new(mesh)

#
# transformations
#

#func apply_self_transformation() -> void:
#	# ???
#	var neworigin := Vector3(0,self.global_transform.origin.y,0)
#	var trx := Transform(self.global_transform.basis, neworigin)
#	trx = self.global_transform
#	apply_transformation(trx)

# apply a tranformation, returns transformed vertices
func apply_transformation(trx: Transform) -> void:
	gmesh.apply_transformation(trx)

func get_clipped_gmesh(plane: Plane) -> GMesh:
	return gmesh.get_clipped_gmesh(plane)

func get_clipped_gmeshinstance(plane: Plane) -> GMeshInstance:
	var newgmesh = gmesh.get_clipped_gmesh(plane)
	var newgmeshinstance : GMeshInstance = null
	if newgmesh:
		newgmeshinstance = get_script().new()
		newgmeshinstance.gmesh = newgmesh
		return newgmeshinstance.fill_new_gmeshinstance(newgmesh, self.global_transform.origin)
	else:
		return null

func fill_new_gmeshinstance(newgmesh: GMesh, origin: Vector3) -> void:
	self.gmesh = newgmesh
	var x = newgmesh.verticesTrx
	for i in range(x.size()):
		x[i] = EXPAND * (x[i] - origin) + origin

	newgmesh.verticesArray = x
	self.mesh = ArrayMesh.new()
	var aa = newgmesh.create_gl_array_solid()
	if aa[ArrayMesh.ARRAY_VERTEX].size() > 0:
		self.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, aa)
		var sm = SpatialMaterial.new()
		sm.albedo_color = Color( 0, 1, 1, 0.7 )
		sm.flags_transparent = true
		self.set_surface_material(0, sm)

	self.apply_transformation(Transform.IDENTITY)

#
# Populate object methods
#

func calculate_centroid() -> GMesh.GCentroidVolume:
	return gmesh.calculate_centroid()
