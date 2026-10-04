"""Build the editable back-of-house route detail kit and Godot GLB.

Coordinates are authored in the Godot tavern's local metres, then converted to
Blender Z-up once. Geometry is decorative only; Godot keeps route collision and
interaction anchors in tavern_layout.gd.
Run with: blender --background --python build_routes.py
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DEST = ROOT / "Godot/three_d/assets/tavern-routes.glb"
DEST.parent.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.render.resolution_x = 1200
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
collection = bpy.data.collections.new("TavernRouteDetail")
scene.collection.children.link(collection)

def godot_to_blender(p):
    return (p[0], -p[2], p[1])

def material(name, color, metallic=0.0, roughness=.65):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return mat

mats = {
    "plaster": material("Route plaster · smoke stained", (.19, .145, .095), 0, .92),
    "brick": material("Kiln brick", (.24, .075, .035), 0, .88),
    "tile": material("Kitchen glazed tile", (.08, .15, .12), .05, .34),
    "walnut": material("Dark service oak", (.12, .047, .018), 0, .48),
    "wood": material("Quay weathered timber", (.22, .105, .045), 0, .76),
    "iron": material("Blackened iron", (.035, .042, .04), .78, .31),
    "brass": material("Aged brass", (.43, .27, .085), .82, .27),
    "enamel": material("Exit enamel", (.13, .26, .16), .46, .23),
    "ivory": material("Old ivory paint", (.65, .52, .31), .08, .58),
    "water": material("River water", (.018, .065, .082), .38, .24),
    "linen": material("Kitchen linen", (.39, .31, .2), 0, .95),
}
objects = []

def put(obj, name, mat):
    obj.name = name
    for users in list(obj.users_collection):
        users.objects.unlink(obj)
    collection.objects.link(obj)
    obj.data.materials.append(mats[mat])
    objects.append(obj)
    return obj

def box(name, pos, size, mat="walnut", bevel=.01):
    bpy.ops.mesh.primitive_cube_add(size=1, location=godot_to_blender(pos))
    obj = put(bpy.context.object, name, mat)
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Soft worn edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj

def rod(name, start, end, radius=.025, mat="iron", vertices=12):
    a, b = Vector(godot_to_blender(start)), Vector(godot_to_blender(end))
    axis = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=axis.length,
                                        location=(a + b) / 2)
    obj = put(bpy.context.object, name, mat)
    obj.rotation_euler = axis.to_track_quat("Z", "Y").to_euler()
    if vertices >= 24:
        for face in obj.data.polygons:
            face.use_smooth = True
    return obj

def lathe(name, pos, profile, mat, segments=24):
    verts, faces = [], []
    for y, radius in profile:
        for i in range(segments):
            angle = 2 * math.pi * i / segments
            verts.append((radius * math.cos(angle), radius * math.sin(angle), y))
    for row in range(len(profile) - 1):
        for i in range(segments):
            a = row * segments + i
            b = row * segments + (i + 1) % segments
            faces.append((a, b, b + segments, a + segments))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.location = godot_to_blender(pos)
    mesh.materials.append(mats[mat])
    objects.append(obj)
    for face in mesh.polygons:
        face.use_smooth = True
    return obj

# The corridor remains clear down its centre. These wall and floor accents sit
# inside the existing greybox shell and do not replace its collision surfaces.
for z in [-4.0, -5.1, -6.2, -7.0, -8.0, -9.0, -10.0, -11.0, -12.0]:
    box("Hall floor brass seam", (0, .012, z), (1.7, .018, .022), "brass", .004)
for x in [-.86, .86]:
    for z in [-4.1, -5.5, -6.8]:
        box("Hall wainscot panel", (x, .55, z), (.045, .92, .95), "walnut", .018)
        box("Wainscot brass bead", (x * 1.028, .99, z), (.025, .035, .97), "brass", .006)
for z in [-4.1, -5.7, -7.0]:
    box("Hall overhead beam", (0, 2.88, z), (1.95, .16, .11), "walnut", .018)

# Emergency hatch: a wheel, hinge straps and exposed latch make the route legible.
box("Hatch outer reveal", (-3.73, 1.15, -7), (.075, 1.92, 1.32), "iron", .018)
box("Hatch inset panel", (-3.68, 1.15, -7), (.055, 1.72, 1.12), "enamel", .025)
for z in [-7.42, -7.0, -6.58]:
    rod("Hatch hinge pin", (-3.62, 1.15, z), (-3.60, 1.15, z + .13), .034, "brass")
lathe("Hatch locking wheel", (-3.58, 1.22, -7), [(0, .16), (.025, .16), (.04, .125)], "brass", 32)
for angle in range(0, 360, 45):
    theta = math.radians(angle)
    rod("Wheel spoke", (-3.56, 1.22, -7),
        (-3.56, 1.22 + math.sin(theta) * .14, -7 + math.cos(theta) * .14), .012, "iron")

# Stair wing: brass nosings and iron rails track the existing twelve-step climb.
for i in range(12):
    y = (i + 1) * .1
    z = -9.125 - i * .25
    box("Stair brass nosing", (-2.75, y + .004, z - .11), (2.28, .022, .026), "brass", .004)
    for x in [-3.87, -1.63]:
        rod("Stair baluster", (x, y + .1, z), (x, y + .1, z - .25), .018, "iron")
for x in [-3.87, -1.63]:
    rod("Stair handrail", (x, .25, -9.0), (x, 1.55, -12.2), .045, "walnut", 24)
    for z in [-9.0, -12.2]:
        lathe("Rail brass newel cap", (x, 0, z), [(0, .075), (.08, .075), (.15, .035), (.17, 0)], "brass")
box("Kitchen tiled splashback", (-3.86, 1.1, -8.55), (.045, 1.35, 1.25), "tile", .01)
for y in [.55, .88, 1.21, 1.54]:
    box("Tile grout line", (-3.825, y, -8.55), (.012, .012, 1.2), "ivory", .002)
for z in [-9.1, -8.75, -8.4, -8.05]:
    box("Tile vertical grout", (-3.825, 1.08, z), (.012, 1.02, .012), "ivory", .002)
box("Kitchen wall shelf", (-3.45, 1.92, -8.55), (.62, .07, 1.3), "walnut", .015)
for z in [-9.0, -8.66, -8.32, -7.98]:
    lathe("Kitchen jar", (-3.46, 1.98, z), [(0, .07), (.02, .08), (.19, .08), (.22, .045), (.25, .045)], "ivory")
    box("Jar dark lid", (-3.46, 2.23, z), (.105, .035, .105), "iron", .012)
rod("Copper kitchen exhaust", (-3.6, 2.35, -8.15), (-3.6, 2.35, -9.05), .055, "brass", 24)
box("Linen on prep counter", (-3.65, .99, -8.55), (.36, .012, .28), "linen", .008)

# Loading lift wing: framing, cable drum, guide rails and a marked call plate.
for x in [.42, 1.82]:
    rod("Lift guide rail", (x, .08, -11.78), (x, 2.12, -11.78), .035, "iron")
for y in [.12, 2.08]:
    rod("Lift gate crossbar", (.42, y, -11.78), (1.82, y, -11.78), .032, "brass")
for x in [.58, .9, 1.22, 1.54, 1.74]:
    rod("Lift gate vertical bar", (x, .15, -11.78), (x, 2.03, -11.78), .018, "iron")
for x in [.35, 1.9]:
    box("Lift stone jamb", (x, 1.25, -11.91), (.18, 2.65, .24), "brick", .018)
lathe("Lift cable drum", (1.1, 2.52, -11.35), [(0, .18), (.04, .22), (.26, .22), (.3, .18)], "iron", 32)
rod("Lift cable", (1.1, 2.5, -11.35), (1.1, 1.95, -11.35), .012, "brass")
box("Lift call plate", (1.95, 1.35, -11.88), (.045, .42, .22), "iron", .018)
for y in [1.24, 1.43]:
    lathe("Lift call button", (1.92, y, -11.74), [(0, .035), (.025, .035), (.04, .02)], "enamel", 16)
for z in [-9.25, -10.0, -10.75]:
    box("Crate slat", (-.95, .45, z), (.78, .038, .83), "wood", .008)
    for x in [-1.22, -.68]:
        rod("Crate nail", (x, .48, z - .39), (x, .48, z - .36), .018, "iron", 10)

# Lower quay: anti-slip planks, bollards, rings, and mooring rope details.
for i in range(9):
    z = -12.35 - i * .145
    box("Quay anti-slip plank", (2.75, -1.185, z), (2.28, .028, .115), "wood", .009)
    for x in [1.72, 2.75, 3.78]:
        box("Plank brass nail", (x, -1.165, z), (.025, .012, .025), "brass", .004)
for z in [-12.4, -13.6]:
    for x in [1.6, 3.9]:
        lathe("Quay bollard", (x, -1.25, z), [(0, .09), (.07, .09), (.10, .14), (.15, .14), (.18, .08), (.28, .08)], "iron")
        rod("Mooring ring", (x, -1.12, z), (x, -.98, z), .018, "brass")
for z in [-12.4, -13.6]:
    rod("Quay edge timber", (1.55, -1.1, z), (3.95, -1.1, z), .08, "walnut", 20)
box("River reflective surface", (2.75, -1.48, -15.95), (4.6, .035, 3.5), "water", .02)
for z in [-15.2, -15.7, -16.2, -16.7]:
    rod("River ripple highlight", (1.0, -1.45, z), (1.7, -1.45, z), .009, "brass", 16)

# Export an editable source before optimizing a transient export selection.
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "tavern-routes.blend"))
import sys
sys.path.insert(0, str(HERE))
from export_routes import export_routes
export_routes()
