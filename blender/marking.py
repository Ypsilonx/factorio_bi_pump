"""Označení BUS trubek: „B“ nastříkané sprejem přes šablonu → průhledný sprite přes trubku.

Blender vyrenderuje siluetu písmene (s mezerou šablony). V numpy se z ní udělá nástřik: měkký okraj,
rozprašek kolem písmene a nerovnoměrná sytost. Pro plasticitu se písmeno ohne kolem válce trubky
(ke krajům se zužuje) a barva se nasvítí jako povrch válce včetně pololesklého odlesku. Svislá varianta
se otáčí před ohnutím a nasvícením, takže strana ke slunci (zleva shora) sedí i na svislé trubce.

Build modu: blender -b --factory-startup -P blender/marking.py -- fluid-bus/graphics/entity
Náhled jinou barvou: blender -b --factory-startup -P blender/marking.py -- <složka> r,g,b
Výstup: <složka>/b-horizontal.png, b-vertical.png a fluid-bus/prototypes/bus_marking_data.lua.
Parametry v blender/marking.toml.
"""
import sys
import tomllib
from pathlib import Path

import bpy
import numpy as np

HERE = Path(__file__).parent


def load_config():
    """Načte parametry označení z marking.toml."""
    with open(HERE / "marking.toml", "rb") as file:
        return tomllib.load(file)


def render_silhouette(cfg, pixels):
    """Bílé šablonové písmeno na černém pozadí (1 dlaždice); vrátí pole 0–1, řádek 0 dole."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "MATERIAL"
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("world")
    scene.world.color = (0, 0, 0)
    scene.render.resolution_x = pixels
    scene.render.resolution_y = pixels
    letter = cfg["letter"]
    curve = bpy.data.curves.new("letter", "FONT")
    curve.body = letter["text"]
    curve.size = letter["size"]
    curve.offset = letter["bold"]
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    white = bpy.data.materials.new("white")
    white.diffuse_color = (1, 1, 1, 1)
    curve.materials.append(white)
    text = bpy.data.objects.new("letter", curve)
    scene.collection.objects.link(text)
    bpy.context.view_layer.update()
    if letter["stencil_gap"] > 0:
        # Mezera šablony: černý svislý pásek přes písmeno mezi dříkem a bříšky.
        corners = [text.matrix_world @ __import__("mathutils").Vector(c) for c in text.bound_box]
        x_min, x_max = min(c.x for c in corners), max(c.x for c in corners)
        x = x_min + letter["stencil_at"] * (x_max - x_min)
        half = letter["stencil_gap"] / 2
        mesh = bpy.data.meshes.new("gap")
        mesh.from_pydata([(x - half, -1, 0.1), (x + half, -1, 0.1), (x + half, 1, 0.1), (x - half, 1, 0.1)],
                         [], [(0, 1, 2, 3)])
        black = bpy.data.materials.new("black")
        black.diffuse_color = (0, 0, 0, 1)
        gap = bpy.data.objects.new("gap", mesh)
        gap.data.materials.append(black)
        scene.collection.objects.link(gap)
    camera = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.0
    camera.location = (0, 0, 5)
    scene.collection.objects.link(camera)
    scene.camera = camera
    path = Path(bpy.app.tempdir) / "fb-silhouette.png"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    image = bpy.data.images.load(str(path))
    w, h = image.size
    rgba = np.array(image.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(image)
    path.unlink()
    return np.clip(rgba[:, :, :3].mean(axis=2), 0, 1)


def blur(values, radius):
    """Rozmazání opakovaným krabicovým filtrem (≈ Gauss) o poloměru v pixelech."""
    radius = int(round(radius))
    if radius < 1:
        return values
    out = values
    for _ in range(3):
        padded = np.pad(out, radius, mode="edge")
        cumulative = np.pad(np.cumsum(np.cumsum(padded, axis=0), axis=1), ((1, 0), (1, 0)))
        size = 2 * radius + 1
        out = (cumulative[size:, size:] - cumulative[:-size, size:] - cumulative[size:, :-size]
               + cumulative[:-size, :-size]) / size ** 2
    return out


def spray_alpha(silhouette, cfg, pixels):
    """Krytí nástřiku: měkký okraj, nerovnoměrná sytost a rozprašek kolem písmene."""
    paint = cfg["paint"]
    rng = np.random.default_rng(paint["seed"])
    body = blur(silhouette, paint["edge_soft"] * pixels)
    patches = blur(rng.random(silhouette.shape), pixels * 0.02)
    patches = (patches - patches.min()) / max(patches.max() - patches.min(), 1e-6)
    body *= 1 - paint["patchiness"] * patches
    mist = blur(silhouette, paint["overspray_reach"] * pixels) * (1 - body)
    speckles = (rng.random(silhouette.shape) < mist * paint["overspray"]) * rng.uniform(0.3, 0.8, silhouette.shape)
    return np.clip(np.maximum(body, speckles), 0, 1) * paint["opacity"]


def wrap_on_cylinder(field, vertical, cfg):
    """Ohne plochý obrázek kolem válce trubky (pohled shora): ke krajům válce se zužuje.

    Bod ve vzdálenosti a od osy na obrazovce leží na povrchu v oblouku s = R·asin(a/R);
    vzorkuje se tedy plochý obrázek v s. Mimo válec (|a| > R) nic není.
    """
    radius = cfg["shading"]["pipe_radius"]
    pixels = field.shape[0]
    coords = (np.arange(pixels) + 0.5) / pixels - 0.5
    inside = np.abs(coords) < radius
    arc = np.where(inside, radius * np.arcsin(np.clip(coords / radius, -1, 1)), 0)
    source = np.clip(np.round((arc + 0.5) * pixels - 0.5).astype(int), 0, pixels - 1)
    if vertical:
        return field[:, source] * inside[None, :]
    return field[source, :] * inside[:, None]


def cylinder_light(pixels, vertical, cfg):
    """Jas a odlesk povrchu válce napříč osou (osvětlení slunce ve hře, pohled shora).

    @return (diffuse, specular) – pole tvaru (pixels, pixels).
    """
    s = cfg["shading"]
    coords = (np.arange(pixels) + 0.5) / pixels - 0.5
    u = np.clip(coords / s["pipe_radius"], -1, 1)
    # Normála válce v rovině napříč osou: složka napříč (across) a nahoru ke kameře (up).
    across, up = u, np.sqrt(1 - u ** 2)
    light = np.array(s["light_from"], dtype=np.float64)
    light /= np.linalg.norm(light)
    # Vodorovná trubka: napříč = osa y (řádky, nahoru kladně); svislá: napříč = osa x.
    light_across = light[0] if vertical else light[1]
    diffuse = np.clip(across * light_across + up * light[2], 0, 1)
    half = np.array([light_across, light[2] + 1.0])
    half /= np.linalg.norm(half)
    specular = np.clip(across * half[0] + up * half[1], 0, 1) ** s["shininess"]
    if vertical:
        return np.tile(diffuse[None, :], (pixels, 1)), np.tile(specular[None, :], (pixels, 1))
    return np.tile(diffuse[:, None], (1, pixels)), np.tile(specular[:, None], (1, pixels))


def to_rgba(alpha, light, color, cfg, factor):
    """Barva nasvícená jako povrch válce + odlesk a krytí → RGBA v cílovém rozlišení."""
    s = cfg["shading"]
    diffuse, specular = light
    h, w = alpha.shape
    lit = np.array(color)[None, None, :] * (s["ambient"] + s["diffuse"] * diffuse)[:, :, None]
    lit += (s["specular"] * specular)[:, :, None]
    rgba = np.zeros((h, w, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(lit, 0, 1) * alpha[:, :, None]
    rgba[:, :, 3] = alpha
    small = rgba.reshape(h // factor, factor, w // factor, factor, 4).mean(axis=(1, 3))
    small[:, :, :3] /= np.maximum(small[:, :, 3:], 1e-6)
    return small


def save_rgba(rgba, path):
    """Uloží RGBA pole (řádek 0 dole) jako PNG."""
    h, w, _ = rgba.shape
    image = bpy.data.images.new("mask", w, h, alpha=True)
    image.pixels[:] = np.clip(rgba, 0, 1).ravel()
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()


def write_lua_placement(cfg, path):
    """Zapíše umístění z [placement] jako Lua tabulku pro mod (jediný zdroj pravdy je marking.toml)."""
    lines = ["-- Vygenerováno skriptem blender/marking.py z blender/marking.toml – neupravovat ručně.",
             "-- Kde na kusu trubky sedí nastříkané „B“: posun v dlaždicích (x doprava, y dolů) a orientace.",
             "return {"]
    for key in sorted(cfg["placement"]):
        place = cfg["placement"][key]
        x, y = place["shift"]
        lines.append(f'  {key} = {{ shift = {{ {x}, {y} }}, orientation = "{place["orientation"]}" }},')
    lines.append("}")
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8")


def build(out_dir, color=None):
    """Vyrobí b-horizontal.png a b-vertical.png do out_dir (barva z TOML, nebo zadaná)
    a Lua tabulku umístění do fluid-bus/prototypes/bus_marking_data.lua."""
    cfg = load_config()
    factor = cfg["mask"]["supersample"]
    pixels = cfg["mask"]["pixels"] * factor
    alpha = spray_alpha(render_silhouette(cfg, pixels), cfg, pixels)
    # Pole má řádek 0 dole (osa y nahoru), np.rot90 proto otáčí opačně – kladný úhel = proti směru hodin.
    turns = -round(cfg["orientation"]["vertical_rotation"] / 90)
    out_dir = Path(out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    color = color or cfg["paint"]["color"]
    for name, field, vertical in (("horizontal", alpha, False), ("vertical", np.rot90(alpha, turns), True)):
        wrapped = wrap_on_cylinder(np.ascontiguousarray(field), vertical, cfg)
        light = cylinder_light(pixels, vertical, cfg)
        save_rgba(to_rgba(wrapped, light, color, cfg, factor), out_dir / f"b-{name}.png")
    write_lua_placement(cfg, HERE.parent / "fluid-bus" / "prototypes" / "bus_marking_data.lua")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    build(args[0], [float(v) for v in args[1].split(",")] if len(args) > 1 else None)
