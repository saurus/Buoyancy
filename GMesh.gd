extends Resource
class_name GMesh

var verticesArray : PoolVector3Array
var triangles := []     # if int
var verticesTrx : PoolVector3Array # as verticesArray, but after applying tranformation

const EPSILON := 0.0001

func _init(mesh: Mesh = null, simplify: bool = true) -> void:
	if mesh:
		# simplify mesh, removing "duplicate" vertices: those are useful for
		# rendering, but wasteful for geometry calculations
		var aa := mesh.surface_get_arrays(0)
		if simplify:
			var idxmap := _add_vertices_uniq(aa[ArrayMesh.ARRAY_VERTEX])

			for idx in aa[ArrayMesh.ARRAY_INDEX]:
				triangles.append(idxmap[idx])
		else:
			verticesArray = aa[ArrayMesh.ARRAY_VERTEX]
			triangles = aa[ArrayMesh.ARRAY_INDEX]
		verticesTrx = verticesArray

#
# get mesh data in a format useful for building MeshInstances
#

func create_gl_array_solid() -> Array:
	var arrays := []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = verticesArray
	arrays[ArrayMesh.ARRAY_INDEX] = PoolIntArray(triangles)
	return arrays

#
# transformations
#

# apply a tranformation, returns transformed vertices
func apply_transformation(trx: Transform) -> void:
	verticesTrx = trx.xform(verticesArray)

func get_clipped_gmesh(plane: Plane) -> GMesh:
	var a := _clip_with_plane(plane)

	var newgmesh : GMesh = null
	if a and a[0] and a[1] and a[0].size() > 0 and a[1].size() > 0:
		newgmesh = get_script().new() # GMesh.new()
		newgmesh.verticesArray = PoolVector3Array(a[0])
		newgmesh.triangles = a[1]
		newgmesh.verticesTrx = newgmesh.verticesArray

	return newgmesh

#
# Populate object methods
#

func _add_vertices_uniq(vertices: PoolVector3Array) -> PoolIntArray:
	var xverticesArray := []
	var idxmap := PoolIntArray()
	idxmap.resize(vertices.size())
	for i in range(vertices.size()):
		idxmap[i] = _add_vertex(xverticesArray, vertices[i])

	verticesArray = PoolVector3Array(xverticesArray)
	return idxmap

func _add_vertex(vertices: Array, curVertex: Vector3) -> int:
	var size := vertices.size()
	for j in range(size):
		if (vertices[j] - curVertex).length_squared() < EPSILON:
			return j
	vertices.append(curVertex)
	return size

func _clip_with_plane(plane: Plane) -> Array:
	var newVertices := []
	var newTriangles := []
	var newFaceEdges := []
	var mapOldToNew := PoolIntArray()
	mapOldToNew.resize(verticesTrx.size())

	for i in range(verticesTrx.size()):
		if plane.is_point_over(verticesTrx[i]):
			# vertex is over the plane, don't add to new vertices
			# mark ad skipped
			mapOldToNew[i] = -1
		else:
			# vertex below plane
			mapOldToNew[i] = newVertices.size()
			newVertices.append(verticesTrx[i])

	# scan triangles
	for i in range(0, triangles.size(), 3):
		# for every triangular face, we have four possible situations:
		# 1. all vertices are above the plane: the face must be fully clipped
		# 2. all vertices are below the plane: the full face must be kept
		# 3. one vertex is below the plane, and two are above: a new, smaller
		#		triangle should be created
		# 4. two vertices are below the plane, and one is above: two new
		#		triangles should be created
		var c := 0
		var it0 : int = triangles[i]
		var it1 : int = triangles[i+1]
		var it2 : int = triangles[i+2]
		var i0 := mapOldToNew[it0]
		var i1 := mapOldToNew[it1]
		var i2 := mapOldToNew[it2]
		var v0 := plane.intersects_segment(verticesTrx[it0], verticesTrx[it1])
		var v1 := plane.intersects_segment(verticesTrx[it1], verticesTrx[it2])
		var v2 := plane.intersects_segment(verticesTrx[it2], verticesTrx[it0])
		var iv0 := _add_vertex(newVertices, v0) if v0 != null else -1
		var iv1 := _add_vertex(newVertices, v1) if v1 != null else -1
		var iv2 := _add_vertex(newVertices, v2) if v2 != null else -1
		if i0 >= 0: c += 100
		if i1 >= 0: c += 10
		if i2 >= 0: c += 1

		match c:
			000:  # all vertices above plane
				pass
			111: # all vertices below plane: this face is kept unchanged
				newTriangles.append(i0)
				newTriangles.append(i1)
				newTriangles.append(i2)
			001: # only last vertex below plane
				newTriangles.append(iv2)
				newTriangles.append(iv1)
				newTriangles.append(i2)
				_add_edge(newFaceEdges, iv1, iv2)
			010: # only second vertex below plane
				newTriangles.append(iv0)
				newTriangles.append(i1)
				newTriangles.append(iv1)
				_add_edge(newFaceEdges, iv0, iv1)
			100: # only first vertex below plane
				newTriangles.append(i0)
				newTriangles.append(iv0)
				newTriangles.append(iv2)
				_add_edge(newFaceEdges, iv2, iv0)
			011: # second and third vertices below plane
				newTriangles.append(iv0)
				newTriangles.append(i1)
				newTriangles.append(iv2)
				_add_edge(newFaceEdges, iv0, iv2)
				newTriangles.append(i1)
				newTriangles.append(i2)
				newTriangles.append(iv2)
			101: # first and third vertices below plane
				newTriangles.append(i0)
				newTriangles.append(iv0)
				newTriangles.append(i2)
				newTriangles.append(iv0)
				newTriangles.append(iv1)
				newTriangles.append(i2)
				_add_edge(newFaceEdges, iv1, iv0)
			110: # first and second vertices below plane
				newTriangles.append(i0)
				newTriangles.append(i1)
				newTriangles.append(iv1)
				newTriangles.append(iv1)
				newTriangles.append(iv2)
				newTriangles.append(i0)
				_add_edge(newFaceEdges, iv2, iv1)
	# calculate last face
	if newFaceEdges.size() > 0:
		var face = _make_new_face_edges(newFaceEdges)
		if face.size() > 0:
			var firstIndex = face[-2]
			var secondIndex = face[-1]

			for i in range(face.size()-2):
				newTriangles.append(firstIndex)
				newTriangles.append(secondIndex)
				secondIndex = face[i]
				newTriangles.append(secondIndex)

	return [ newVertices, newTriangles ]

func _sort_new_face_edges(newFaceEdges: Array) -> void:
	for i in range(0, newFaceEdges.size(), 2):
		for j in range(i+4, newFaceEdges.size(), 2):
			if newFaceEdges[i+1] == newFaceEdges[j] and newFaceEdges[j+1] != newFaceEdges[i]:
				var x : int = newFaceEdges[i+2]
				newFaceEdges[i+2] = newFaceEdges[j]
				newFaceEdges[j] = x
				x = newFaceEdges[i+3]
				newFaceEdges[i+3] = newFaceEdges[j+1]
				newFaceEdges[j+1] = x
				break

func _make_new_face_edges(newFaceEdges: Array) -> Array:
	var face := []
	# remove closed loops!
	for i in range(0, newFaceEdges.size(), 2):
		for j in range(i+2, newFaceEdges.size(), 2):
			if newFaceEdges[i] == newFaceEdges[j+1] and newFaceEdges[i+1] == newFaceEdges[j]:
				newFaceEdges[i] = -1
				newFaceEdges[i+1] = -1
				newFaceEdges[j] = -1
				newFaceEdges[j+1] = -1

	_sort_new_face_edges(newFaceEdges)
	for i in range(0, newFaceEdges.size(), 2):
		if newFaceEdges[i] == -1:
			continue
		face.append(newFaceEdges[i])

	return face

func _add_edge(newFaceEdges: Array, i1: int, i2: int) -> void:
	if i1 != i2:
		newFaceEdges.append(i1)
		newFaceEdges.append(i2)

func calculate_centroid() -> GCentroidVolume:
	var volume := 0.0
	var x := 0.0
	var y := 0.0
	var z := 0.0

	for i in range(triangles.size()/3):
		var idx = 3*i
		var a: Vector3 = verticesTrx[triangles[idx]]
		var b: Vector3 = verticesTrx[triangles[idx+1]]
		var c: Vector3 = verticesTrx[triangles[idx+2]]
		var n := (b-a).cross(c-a)
		var partial := a.dot(n)
		volume += partial

		var v : Vector3

		v = Vector3(1, 0, 0)
		var px := n.dot(v) * (pow((a + b).dot(v), 2) + pow((b + c).dot(v), 2) + pow((c + a).dot(v), 2))
		x += px
		v = Vector3(0, 1, 0)
		var py := n.dot(v) * (pow((a + b).dot(v), 2) + pow((b + c).dot(v), 2) + pow((c + a).dot(v), 2))
		y += py
		v = Vector3(0, 0, 1)
		var pz := n.dot(v) * (pow((a + b).dot(v), 2) + pow((b + c).dot(v), 2) + pow((c + a).dot(v), 2))
		z += pz

	volume /= -6

	if volume != 0:
		x /= -48*volume
		y /= -48*volume
		z /= -48*volume

	return GCentroidVolume.new(Vector3(x, y, z), volume)

class GCentroidVolume:
	var centroid : Vector3
	var volume : float

	func _init(centroid: Vector3, volume: float):
		._init()
		self.volume = volume
		self.centroid = centroid
