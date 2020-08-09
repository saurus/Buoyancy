# Buoyancy
Calculate Buoyancy in Godot/GDScript

Starting from the ocean demo https://github.com/saurus/Godot-Ocean-Demo (remember, based on https://github.com/SIsilicon/Godot-Ocean-Demo), I'm slowly adding features.

This repository contains code to calculate buoyancy of an object, using the Godot's RigidBodies and physics engine to handle gravity.

## Buoyancy algorithm

_"Any object, totally or partially immersed in a fluid or liquid, is buoyed up by a force equal to the weight of the fluid displaced by the object"_ 
 (Archimedes' principle, from https://en.wikipedia.org/wiki/Archimedes%27_principle).

Starting from notorius Archimedes' principle, it's easy to see that if we can calculate the volume of the solid under the water (let's call it <img src="https://render.githubusercontent.com/render/math?math=V"> in <img src="https://render.githubusercontent.com/render/math?math=m^3">), and given the water's density of circa <img src="https://render.githubusercontent.com/render/math?math=1.000 \frac{kg}{m^3}">, the displaced mass is:

<img src="https://render.githubusercontent.com/render/math?math=1.000 \frac{kg}{m^3} \cdot V m^3 = 1.000 \cdot V kg">

Using the (also famous) Newton's second law of motion, <img src="https://render.githubusercontent.com/render/math?math=F = m \cdot a">, and the gravity acceleration:

<img src="https://render.githubusercontent.com/render/math?math=F =  1.000 \cdot V kg \cdot 9,8 \frac{m}{s^2} = 9.800 \cdot V N">

Easy, right? But how to calculate the volume? here comes the tricky part. Let's divide the problem in two: first, we need to identify the part of the object immersed, when we have this new object (a polyhedron), we need to calculate the volume and the buoyancy center. 

### Calculating the immersed part of a polyhedron

So, let's start assuming the water's surface is a perfect plane. While not exaclty true (considering a wavy sea), It's a good approximation.

I searched a lot around for a ready made algoritm, and most useful documents are:

https://fabiensanglard.net/polygon_codec/clippingdocument/Clipping.pdf: this is a very mathematical explanation.

https://www.geometrictools.com/Documentation/ClipMesh.pdf: a computer graphics oriented document, with in-depth explanations and pseudo-code.

In the end, I settled with a very simple (and not so efficient) implementation, the important part is in [GMesh.gd](./GMesh.gd), function _clip_with_plane.

First, all the vertices from the original polyhedron lying below the plane are vertices of the clipped polyhedron, so they are added to an Array, and a mapping between old and new vertex indexes is made.

Then, for every (triangular) face, we have four possible configurations. Two are easy: all the vertices are below the plane, so this original face is still present in the clipped polyhedron, or the face is fully above the plane, and this face is not present in the target polyhedron.

The other two configurations are one point above and two below the plane, and the other way around.

```
       o-----------o                         o
        \         /                         / \
         \       /                         /   \
    ------x-----x-------------------------x-----x------
           \   /                         /       \
            \ /                         /         \
             o                         o-----------o
```

in both cases, two new vertices are needed (marked with a `x` in the drawing above). But in the first, the new vertices define a new triangle, in the second, two triangles are needed.

Futhermore, we need to decide which vertices to keep, and the correct order when defining the triangles. The easier way is to split every configuration in three:

```
       2-----------3          1-----------2          3-----------1   
        \         /            \         /            \         /    
         \       /              \       /              \       /     
    ------x-----x------    ------x-----x------    ------x-----x------
           \   /                  \   /                  \   /       
            \ /                    \ /                    \ /        
             1                      3                      2         
```

and likewise for the other configuration.

All in all, we settled with eight configurations, each handled separately for simplicity.

The variables have names a bit "concise", there is an explanation of meanings:
- `it0, it1, it2`: indexes of vertices in original triangle. Used to calculate intersections between edges and plane
- `v0, v1, v2`: intersection between edges and plane. `v0` is the intersection between the first (index zero) and the second vertices, and so on)
- `i0, i1, i2`: indexes for vertices on new polyhedron, for vertices in original polyhedron. 
- `iv0, iv1, iv2`: indexes for new vertices created.

We are almost there, but not yet. We need to create a new face to close the polyhedron, with all the new vertices. We have two problem to tackle: we need to find the correct vertices' order, and ne need to divide the resulting shape in triangles. 

We carefully saved the new edges in the array `newFaceEdges`, reversing the new edges laying on the plane, so they are already in the correct direction. in the `_make_new_face_edges` those edges are ordered, matching every egde ending on a vertex with the edge starting with the same vertex. as vertices are checked for equality with an error margin, some triangles can become lines, so here those edge cases (pun intended...) are handled. All this makes this step a bit complicated, and certainly not fast...

In the end, the function returns the vertices and the indexes making the faces.


### Calculating the volume of a Polyhedron

Again, internet is our friend! Finding an algorithm to calculate the volume of a generic polyhedron is not easy, most search results are for 2D or for simple shapes.

The resource used for this step is http://wwwf.imperial.ac.uk/~rn/centroid.pdf

The implementation is in the function `calculate_centroid`: Here the code is an almost direct translation of the formulas the the paper linked above.

Both volume and centroid are calculated together, as the formulas have a lot in common.

### About centroid...

Another small thing needed is the point to apply the buoyancy force. Assuming an homogeneous object, this is the geometric center.

As stated in the Archimedes' principle above, the force is applied upward. but this assumes a static liquid, where the surface is flat and horizontal. 
When the object is on a wave, the local surface is not horizontal (while we keep assuming is flat), so the side near to the crest of the wave is 
"pushed up" more then the other side. The object is not only tilted, but is also pushed a bit away from the wave. All this can be obtained simply 
using the normal to the plane when applying the buoyancy force, but not always. When the object is totally covered by water, the orientation of the water
plane doesn't matter: the force goes always up. So in the end the force is applied using a vector interpolated between the plane normal and the up vector,
based on the fraction of the object below the water. All this is calculated in [FloatingBody.gd](./FloatingBody.gd), fucntion `apply_buoyancy`.

## The application

To show all this in action, the application allows to switch between different shapes. All the parameters defining the wave are customizable (as in the original ocean wave demo), and you can look around moving the mouse while pressing the middle button, and pan round pressing right button (just like in the Godot editor, or in Blender).

A few debugging features are present: a green plane showing the local water surface and a yellow triangle (well, a narrow prism) pointing to the calculated centroid.

Rendering the shape below the water can be activated: this is implemented in the file [GMeshInstance.gd](./GMeshInstance.gd). The water wave can alse be hidden, to allow a better view of the reference plane
and the buoyancy mesh. 

Using the nice DebugDraw https://github.com/RBerezkin/Test_DebugDraw/, there's an option to enable viewing some vectors (plane normal, up vector, interpolated normal, buoyancy force).


