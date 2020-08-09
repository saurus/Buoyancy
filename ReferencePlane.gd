extends MeshInstance

func _ready():
	var va := PoolVector3Array()

	var va2 := PoolVector3Array()
	va2.push_back(Vector3(0, 0,  10))
	va2.push_back(Vector3(0, 0, -10))
	var va3 := PoolVector3Array()
	va3.push_back(Vector3(-10, 0, 0))
	va3.push_back(Vector3( 10, 0, 0))
	for i in range(-10, 11):
		if i != 0:
			va.push_back(Vector3(i, 0,  10))
			va.push_back(Vector3(i, 0, -10))

	for i in range(-10, 11):
		if i != 0:
			va.push_back(Vector3(-10, 0,  i))
			va.push_back(Vector3(10, 0, i))

	var arrays := []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = va
	self.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	arrays[ArrayMesh.ARRAY_VERTEX] = va2
	self.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var sm = SpatialMaterial.new()
	sm.albedo_color = Color.red
	self.set_surface_material(1, sm)

	arrays[ArrayMesh.ARRAY_VERTEX] = va3
	self.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	sm = SpatialMaterial.new()
	sm.albedo_color = Color.blue
	self.set_surface_material(2, sm)
