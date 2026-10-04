"""Náhled označení „B“ na vanilla trubkách ve skutečném měřítku hry.

Spuštění: blender -b --factory-startup -P blender/preview_marking.py -- <složka masek> <výstupní PNG>
Parametry umístění a pozadí v blender/marking.toml. Slouží jen k ladění vzhledu – do modu nejde.
"""
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).parent))
import marking  # noqa: E402

GRAPHICS = Path("C:/STEAM/steamapps/common/Factorio/data/base/graphics/entity")
#: Sprite podzemní trubky podle strany napojení.
UNDERGROUND = {"north": "up", "south": "down", "east": "right", "west": "left"}
#: Ukázková síť: (sloupec, řádek, tvar). Řádek 0 nahoře.
LAYOUT = [
    (0, 0, "ending_right"), (1, 0, "straight_horizontal"), (2, 0, "straight_horizontal_window"),
    (3, 0, "t_down"), (4, 0, "straight_horizontal"), (5, 0, "corner_down_left"),
    (3, 1, "cross"), (2, 1, "ending_right"), (4, 1, "ending_left"), (5, 1, "straight_vertical"),
    (3, 2, "t_left"), (2, 2, "ending_right"), (5, 2, "straight_vertical_window"),
    (3, 3, "t_right"), (4, 3, "straight_horizontal"), (5, 3, "t_up"), (6, 3, "ending_left"),
    (3, 4, "ending_up"),
    (0, 6, "east"), (1, 6, "straight_horizontal"), (2, 6, "west"),
    (3, 5, "south"), (3, 6, "straight_vertical"), (3, 7, "north"),
]
COLUMNS, ROWS = 7, 8


def image_material(path):
    """Materiál, který zobrazí PNG s průhledností (emise = barvy beze změny osvětlením)."""
    mat = bpy.data.materials.new(path.stem)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(path))
    tex.interpolation = "Closest"
    emit = nodes.new("ShaderNodeEmission")
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(tex.outputs["Color"], emit.inputs["Color"])
    links.new(tex.outputs["Alpha"], mix.inputs["Fac"])
    links.new(transparent.outputs["BSDF"], mix.inputs[1])
    links.new(emit.outputs["Emission"], mix.inputs[2])
    links.new(mix.outputs["Shader"], out.inputs["Surface"])
    return mat


def plane(path, cx, cy, half, z, collection):
    """Čtverec se středem (cx, cy) a poloviční stranou half (v dlaždicích) s obrázkem."""
    mesh = bpy.data.meshes.new(path.stem)
    mesh.from_pydata([(cx - half, cy - half, z), (cx + half, cy - half, z), (cx + half, cy + half, z),
                      (cx - half, cy + half, z)], [], [(0, 1, 2, 3)])
    mesh.uv_layers.new().data.foreach_set("uv", [0, 0, 1, 0, 1, 1, 0, 1])
    obj = bpy.data.objects.new(path.stem, mesh)
    obj.data.materials.append(image_material(path))
    collection.objects.link(obj)


def main():
    """Složí vanilla sprity (2×2 dlaždice) a masku (1 dlaždice) a vyrenderuje PNG."""
    args = sys.argv[sys.argv.index("--") + 1:]
    masks, out = Path(args[0]).resolve(), Path(args[1]).resolve()
    cfg = marking.load_config()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.view_settings.view_transform = "Standard"
    coll = scene.collection
    bg = image_material.__globals__["bpy"].data.materials.new("bg")
    bg.use_nodes = True
    bg.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (*cfg["preview"]["background"], 1)
    bg.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 1.0
    bg.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0, 0, 0, 1)
    mesh = bpy.data.meshes.new("bg")
    mesh.from_pydata([(-1.5, -ROWS - 0.5, -1), (COLUMNS + 0.5, -ROWS - 0.5, -1), (COLUMNS + 0.5, 1.5, -1),
                      (-1.5, 1.5, -1)], [], [(0, 1, 2, 3)])
    background = bpy.data.objects.new("bg", mesh)
    background.data.materials.append(bg)
    coll.objects.link(background)
    for col, row, shape in LAYOUT:
        cx, cy = col, -row
        # Sprity 2×2 se překrývají – každý ve vlastní hloubce (níž položené řádky vpředu jako ve hře).
        if shape in UNDERGROUND:
            sprite = GRAPHICS / "pipe-to-ground" / ("pipe-to-ground-" + UNDERGROUND[shape] + ".png")
        else:
            sprite = GRAPHICS / "pipe" / ("pipe-" + shape.replace("_", "-") + ".png")
        plane(sprite, cx, cy, 1.0, 0.001 * (row * 10 + col), coll)
        place = cfg["placement"].get(shape)
        if place:
            sx, sy = place["shift"]
            mask = masks / ("b-" + place["orientation"] + ".png")
            plane(mask, cx + sx, cy - sy, 0.5, 0.5 + 0.001 * (row * 10 + col), coll)
    camera = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = COLUMNS + 2
    camera.location = ((COLUMNS - 1) / 2, -(ROWS - 1) / 2, 10)
    coll.objects.link(camera)
    scene.camera = camera
    ppt = cfg["preview"]["pixels_per_tile"]
    scene.render.resolution_x = (COLUMNS + 2) * ppt
    scene.render.resolution_y = (ROWS + 2) * ppt
    scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)


main()
