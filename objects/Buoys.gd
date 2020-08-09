extends FloatingObject

const NUM := 2
const SPACE := 5.0
var buoyi = preload("res://objects/Buoy.tscn")

func init(parent, ocean: Ocean, dbgLabel: Label, ref_plane_marker, buoyancy_point_marker) -> void:
	for x in range(-NUM, NUM + 1):
		for z in range(-NUM, NUM + 1):
			var buoy = buoyi.instance()
			buoy.transform.origin.x = SPACE*x
			buoy.transform.origin.z = SPACE*z
			add_child(buoy)
			buoy.init(parent, ocean, dbgLabel, ref_plane_marker, buoyancy_point_marker)
