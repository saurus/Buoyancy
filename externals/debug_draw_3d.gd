class_name DebugDraw3D


var parent: Spatial

var mat: SpatialMaterial
var ig: ImmediateGeometry

var items_to_draw: Array = []
enum Primitive {RAY, VECTOR, CUBE, SPHERE, CONE, CYLINDER}


func _init(_parent: Spatial) -> void:
	parent = _parent

	mat = SpatialMaterial.new()
	mat.flags_unshaded = true
	mat.vertex_color_use_as_albedo = true

	ig = ImmediateGeometry.new()
	ig.material_override = mat

	parent.call_deferred("add_child", ig)

func destroy():
	ig.call_deferred("queue_free")

# MESH PRIMITIVES ==============================================================
# ==============================================================================
func _make_line(p1: Vector3, p2: Vector3) -> void:
	ig.add_vertex(p1)
	ig.add_vertex(p2)


func _make_triangle(p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	ig.add_vertex(p1)
	ig.add_vertex(p2)
	ig.add_vertex(p3)
# ==============================================================================


# CUBE =========================================================================
# ==============================================================================
func _make_cube(p: Vector3, extents: Vector3, fill: bool) -> void:
	var x: = extents.x
	var y: = extents.y
	var z: = extents.z

	var points: = PoolVector3Array()
	points.push_back(Vector3(-x, -y, -z) + p)
	points.push_back(Vector3(-x, -y, z) + p)
	points.push_back(Vector3(-x, y, -z) + p)
	points.push_back(Vector3(-x, y, z) + p)
	points.push_back(Vector3(x, -y, -z) + p)
	points.push_back(Vector3(x, -y, z) + p)
	points.push_back(Vector3(x, y, -z) + p)
	points.push_back(Vector3(x, y, z) + p)

	if fill:
		_make_triangle(points[0], points[2], points[3])
		_make_triangle(points[3], points[1], points[0])
		_make_triangle(points[4], points[5], points[7])
		_make_triangle(points[7], points[6], points[4])
		_make_triangle(points[0], points[1], points[5])
		_make_triangle(points[5], points[4], points[0])
		_make_triangle(points[3], points[2], points[7])
		_make_triangle(points[7], points[2], points[6])
		_make_triangle(points[0], points[4], points[2])
		_make_triangle(points[2], points[4], points[6])
		_make_triangle(points[1], points[3], points[7])
		_make_triangle(points[7], points[5], points[1])
	else:
		_make_line(points[0], points[1])
		_make_line(points[1], points[3])
		_make_line(points[3], points[2])
		_make_line(points[2], points[0])
		_make_line(points[4], points[5])
		_make_line(points[5], points[7])
		_make_line(points[7], points[6])
		_make_line(points[6], points[4])
		_make_line(points[0], points[4])
		_make_line(points[1], points[5])
		_make_line(points[3], points[7])
		_make_line(points[2], points[6])


func add_cube(p: Vector3, extents: Vector3, color: = Color.white, fill: bool = false) -> void:
	items_to_draw.push_back([
		[Primitive.CUBE, color, fill],
		[p, extents]
	])
# ==============================================================================


# CONE =========================================================================
# ==============================================================================
func _make_cone(p1: Vector3, p2: Vector3, r1: float, r2: float, lon: int, caps: bool, fill: bool) -> void:
	var v: = p2 - p1
	var l: = v.length()

	for i in range(1, lon + 1):
		var lon0: = 2.0 * PI * ((i - 1) as float / lon)
		var x0: = cos(lon0)
		var z0: = sin(lon0)

		var lon1: = 2.0 * PI * (i as float / lon)
		var x1: = cos(lon1)
		var z1: = sin(lon1)

		var points: = PoolVector3Array()
		points.push_back(Vector3(x0 * r1, 0, z0 * r1))
		points.push_back(Vector3(x0 * r2, l, z0 * r2))
		points.push_back(Vector3(x1 * r1, 0, z1 * r1))
		points.push_back(Vector3(x1 * r2, l, z1 * r2))
		points.push_back(Vector3(0.0, 0, 0.0))
		points.push_back(Vector3(0.0, l, 0.0))

		var dir: = v.normalized()
		var rot: = Vector3.RIGHT
		var ang: = 0.0

		if dir == Vector3.DOWN:
			ang = PI
		elif dir != Vector3.UP and dir != Vector3.ZERO:
			rot = Vector3.UP.cross(dir).normalized()
			ang = Vector3.UP.angle_to(dir)

		for j in points.size():
			points[j] = points[j].rotated(rot, ang) + p1

		if fill:
			_make_triangle(points[0], points[2], points[1])
			_make_triangle(points[1], points[2], points[3])

			if caps:
				_make_triangle(points[0], points[4], points[2])
				_make_triangle(points[1], points[3], points[5])
		else:
			_make_line(points[0], points[1])
			_make_line(points[1], points[3])
			_make_line(points[2], points[0])

			if caps:
				_make_line(points[0], points[4])
				_make_line(points[1], points[5])


func add_cone(p1: Vector3, p2: Vector3, r1: float, r2: float, lon: int = 8, caps: bool = true, color: = Color.white, fill: bool = false) -> void:
	items_to_draw.push_back([
		[Primitive.CONE, color, fill],
		[p1, p2, r1, r2, lon, caps]
	])
# ==============================================================================


# SPHERE =======================================================================
# ==============================================================================
func _make_sphere(p: Vector3, r: float, lon: int, lat: int, fill: bool) -> void:
	for i in range(1, lat + 1):
		var lat0: = PI * (-0.5 + (i - 1) as float / lat)
		var y0: = sin(lat0)
		var r0: = cos(lat0)

		var lat1: = PI * (-0.5 + i as float / lat)
		var y1: = sin(lat1)
		var r1: = cos(lat1)

		for j in range(1, lon + 1):
			var lon0: = 2 * PI * ((j - 1) as float / lon)
			var x0: = cos(lon0)
			var z0: = sin(lon0)

			var lon1: = 2 * PI * (j as float / lon)
			var x1: = cos(lon1)
			var z1: = sin(lon1)

			var points: = PoolVector3Array()
			points.push_back(r * Vector3(x1 * r0, y0, z1 * r0) + p)
			points.push_back(r * Vector3(x1 * r1, y1, z1 * r1) + p)
			points.push_back(r * Vector3(x0 * r1, y1, z0 * r1) + p)
			points.push_back(r * Vector3(x0 * r0, y0, z0 * r0) + p)

			if fill:
				_make_triangle(points[0], points[1], points[2])
				_make_triangle(points[2], points[3], points[0])
			else:
				_make_line(points[0], points[1])
				_make_line(points[1], points[2])


func add_sphere(p: Vector3, r: float, lon: int = 16, lat: int = 8, color: = Color.white, fill: bool = false) -> void:
	items_to_draw.push_back([
		[Primitive.SPHERE, color, fill],
		[p, r, lon, lat]
	])
# ==============================================================================


# CYLINDER =====================================================================
# ==============================================================================
func _make_cylinder(p1: Vector3, p2: Vector3, r: float, lon: int, fill: bool) -> void:
	_make_cone(p1, p2, r, r, lon, true, fill)

func add_cylinder(p1: Vector3, p2: Vector3, r: float, lon: int = 8, color: = Color.white, fill: bool = false) -> void:
	items_to_draw.push_back([
		[Primitive.CYLINDER, color, fill],
		[p1, p2, r, lon]
	])
# ==============================================================================


# RAY ==========================================================================
# ==============================================================================
func _make_ray(p1: Vector3, p2: Vector3, thickness: float, fill: bool) -> void:
	if thickness <= 0.0:
		_make_line(p1, p2)
	else:
		_make_cylinder(p1, p2, thickness / 2, 8, fill)


func add_ray(p1: Vector3, p2: Vector3, thickness: float = 0.0, color: = Color.white, fill: bool = false) -> void:
	items_to_draw.push_back([
		[Primitive.RAY, color, fill],
		[p1, p2, thickness]
	])
# ==============================================================================


# VECTOR =======================================================================
# ==============================================================================
func _make_vector(p1: Vector3, p2: Vector3, thickness: float, fill: bool) -> void:
	var n: = (p2 - p1).normalized()
	var p3: = p2 - n * 0.1

	if thickness <= 0.0:
		_make_ray(p1, p2, 0.0, fill)
		_make_cone(p3, p2, 0.05, 0, 4, false, fill)
	else:
		_make_ray(p1, p3, thickness, fill)
		_make_cone(p3, p2, thickness, 0, 8, true, fill)


func add_vector(p1: Vector3, p2: Vector3, thickness: float = 0.0, color: = Color.white, fill: bool = false) -> void:
	items_to_draw.push_back([
		[Primitive.VECTOR, color, fill],
		[p1, p2, thickness]
	])
# ==============================================================================


func draw() -> void:
	ig.clear()

	for item in items_to_draw:
		var item_type: = item[0][0] as int
		var color: = item[0][1] as Color

		var draw_mode: int = Mesh.PRIMITIVE_TRIANGLES if item[0][2] else Mesh.PRIMITIVE_LINES

		ig.begin(draw_mode)
		ig.set_color(color)

		match item_type:
			Primitive.CUBE:
				_make_cube(item[1][0], item[1][1], item[0][2])
			Primitive.CONE:
				_make_cone(item[1][0], item[1][1], item[1][2], item[1][3], item[1][4], item[1][5], item[0][2])
			Primitive.CYLINDER:
				_make_cylinder(item[1][0], item[1][1], item[1][2], item[1][3], item[0][2])
			Primitive.SPHERE:
				_make_sphere(item[1][0], item[1][1], item[1][2], item[1][3], item[0][2])
			Primitive.RAY:
				_make_ray(item[1][0], item[1][1], item[1][2], item[0][2])
			Primitive.VECTOR:
				_make_vector(item[1][0], item[1][1], item[1][2], item[0][2])

		ig.end()

	items_to_draw.clear()
