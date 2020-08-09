extends Spatial
class_name FloatingObject

func init(parent, ocean: Ocean, dbgLabel: Label, ref_plane_marker, buoyancy_point_marker) -> void:
	for n in get_children():
		if n is RigidBody and n.has_method("init"):
			n.init(parent, ocean, dbgLabel, ref_plane_marker, buoyancy_point_marker)

func set_debug(enabled_mesh: bool, enabled_draw: bool, dbgLabel) -> void:
	for n in get_children():
		if n is RigidBody and n.has_method("init"):
			n.set_debug(enabled_mesh, enabled_draw, dbgLabel)
