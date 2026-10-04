"""Vyrenderuje ikonu „B“ do menu stavby (bílé písmo s tmavým obrysem).

Spuštění: blender -b --factory-startup -P blender/build_overlay.py -- <složka modu>
Výstup: graphics/icons/b.png (64×64). Označení na trubkách ve světě dělá blender/marking.py.
Skript vždy začíná z prázdné scény, takže je idempotentní.
"""
import sys
from pathlib import Path

import bpy

# Laditelné hodnoty: velikost písma ikony (v jednotkách kamery, 1 = šířka ikony) a tloušťka obrysu.
TEXT_SIZE = 0.67
OUTLINE = 0.025
FILL = (1.0, 1.0, 1.0, 1.0)
EDGE = (0.05, 0.05, 0.05, 1.0)


def reset_scene():
    """Prázdná scéna, Workbench s plochým světlem a průhledným pozadím."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    camera = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.0
    camera.location = (0, 0, 10)
    scene.collection.objects.link(camera)
    scene.camera = camera
    return scene


def material(name, color):
    """Materiál s barvou pro Workbench."""
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    return mat


def text(body, size, rotation, offset, color, z):
    """Vystředěný text; offset rozšíří obrys písmen (pro tmavý lem)."""
    curve = bpy.data.curves.new(f"text-{z}", "FONT")
    curve.body = body
    curve.size = size
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.offset = offset
    obj = bpy.data.objects.new(f"text-{z}", curve)
    obj.location = (0, 0, z)
    obj.rotation_euler = (0, 0, rotation)
    obj.data.materials.append(material(f"m-{z}", color))
    bpy.context.scene.collection.objects.link(obj)


def render(body, size, rotation, pixels, path):
    """Vyrenderuje jeden overlay do PNG."""
    scene = reset_scene()
    scene.render.resolution_x = pixels
    scene.render.resolution_y = pixels
    text(body, size, rotation, OUTLINE, EDGE, 0.0)
    text(body, size, rotation, 0.0, FILL, 0.01)
    path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    """Vstupní bod: cesta ke složce modu za oddělovačem --."""
    root = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
    render("B", TEXT_SIZE, 0.0, 64, root / "graphics/icons/b.png")


main()
