"""Kamera, světla, render vrstev (base / shadow / full) a práce s pixely (skládání, převzorkování) – převzato ze Storage Optimizeru."""

import math

import bpy
import numpy as np

SAMPLES = 96
SUPERSAMPLE = 2  # render ve 2× rozlišení a zmenšení → ostřejší jemné detaily na 64 px/dlaždici


def setup_render(scene, px):
    """Cycles, průhledné pozadí, standardní převod barev; render v px × SUPERSAMPLE."""
    scene.render.engine = "CYCLES"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.resolution_x = px * SUPERSAMPLE
    scene.render.resolution_y = px * SUPERSAMPLE
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.get("FB_World") or bpy.data.worlds.new("FB_World")
    world.use_nodes = True
    nodes = world.node_tree.nodes
    # Blender 5 zakládá nový svět bez uzlů – pozadí a výstup případně doplníme.
    background = next((n for n in nodes if n.type == "BACKGROUND"), None) or nodes.new("ShaderNodeBackground")
    output = next((n for n in nodes if n.type == "OUTPUT_WORLD"), None) or nodes.new("ShaderNodeOutputWorld")
    if not output.inputs["Surface"].is_linked:
        world.node_tree.links.new(background.outputs["Background"], output.inputs["Surface"])
    background.inputs["Color"].default_value = (0.42, 0.42, 0.45, 1.0)
    background.inputs["Strength"].default_value = 0.4
    scene.world = world


def setup_camera_and_lights(scene, ortho_scale):
    """Ortografická kamera pod 45° (jako ve Factoriu), teplé slunce zleva shora (stín doprava) a chladné doplňkové."""
    cam_data = bpy.data.cameras.new("FB_Camera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho_scale
    camera = bpy.data.objects.new("FB_Camera", cam_data)
    camera.location = (0.0, -10.0, 10.0)
    camera.rotation_euler = (math.radians(45.0), 0.0, 0.0)
    scene.collection.objects.link(camera)
    scene.camera = camera

    sun_data = bpy.data.lights.new("FB_Sun", "SUN")
    sun_data.energy = 7.0
    sun_data.angle = math.radians(4.0)
    sun_data.color = (1.0, 0.95, 0.86)
    sun = bpy.data.objects.new("FB_Sun", sun_data)
    sun.rotation_euler = (math.radians(-12.0), math.radians(-48.0), 0.0)
    scene.collection.objects.link(sun)

    fill_data = bpy.data.lights.new("FB_Fill", "SUN")
    fill_data.energy = 0.8
    fill_data.color = (0.8, 0.88, 1.0)
    fill_data.use_shadow = False
    fill = bpy.data.objects.new("FB_Fill", fill_data)
    fill.rotation_euler = (math.radians(50.0), math.radians(30.0), 0.0)
    scene.collection.objects.link(fill)
    return camera


def add_ground(scene):
    """Podložka zachytávající stín (shadow catcher)."""
    bpy.ops.mesh.primitive_plane_add(size=6.0, location=(0, 0, 0))
    ground = bpy.context.active_object
    ground.name = "FB_Ground"
    ground.is_shadow_catcher = True
    return ground


def render_pass(scene, path, mode, parts, ground):
    """Vyrenderuje vrstvu: 'base' (model), 'shadow' (jen stín), 'full' (model se stínem)."""
    for obj in parts:
        obj.hide_render = False
        obj.visible_camera = mode != "shadow"
    ground.hide_render = mode not in ("shadow", "full")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def load_pixels(path):
    """Načte PNG jako numpy pole (výška, šířka, 4) s řádky shora dolů (hodnoty sRGB)."""
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    pixels = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
    bpy.data.images.remove(img)
    return pixels


def save_pixels(pixels, path):
    """Uloží numpy pole (výška, šířka, 4; řádky shora dolů; sRGB) jako PNG."""
    h, w = pixels.shape[:2]
    img = bpy.data.images.new("FB_tmp", width=w, height=h, alpha=True)
    img.pixels[:] = np.clip(pixels, 0.0, 1.0)[::-1].reshape(-1)
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def srgb_to_linear(c):
    """Převod sRGB (0–1) na lineární hodnoty."""
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    """Převod lineárních hodnot zpět na sRGB (0–1)."""
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def downsample(pixels, factor=SUPERSAMPLE):
    """Zmenší obraz průměrem bloků factor×factor v lineárním prostoru s premultiplikovanou alfou."""
    if factor == 1:
        return pixels
    h, w = pixels.shape[:2]
    alpha = pixels[..., 3:4]
    pre = np.concatenate([srgb_to_linear(pixels[..., :3]) * alpha, alpha], axis=-1)
    pre = pre.reshape(h // factor, factor, w // factor, factor, 4).mean(axis=(1, 3))
    a = pre[..., 3:4]
    rgb = np.where(a > 1e-6, pre[..., :3] / np.maximum(a, 1e-6), 0.0)
    return np.concatenate([linear_to_srgb(rgb), a], axis=-1)


def shadow_only(pixels):
    """Ze stínového renderu ponechá jen alfu (černý stín, jak ho Factorio kreslí přes draw_as_shadow)."""
    out = np.zeros_like(pixels)
    out[..., 3] = pixels[..., 3]
    return out


def over(dst, src):
    """Složí vrstvu src přes dst (sRGB, nepremultiplikovaná alfa)."""
    a = src[..., 3:4]
    out = dst.copy()
    out[..., :3] = src[..., :3] * a + dst[..., :3] * (1.0 - a)
    out[..., 3:4] = a + dst[..., 3:4] * (1.0 - a)
    return out

