"""Render spojky busu (manometrová armatura) pro Factorio + náhled vedle vanilla trubek.

Spuštění: blender -b --factory-startup -P blender/coupler/build_coupler.py -- <složka modu> [náhled.png]
Výstupy (do složky modu):
    graphics/entity/fb-bus-coupler-{vertical,horizontal}.png         128×128 (2×2 dlaždice, ve hře scale 0.5)
    graphics/entity/fb-bus-coupler-{vertical,horizontal}-shadow.png  stín (draw_as_shadow)
    graphics/entity/fb-bus-coupler-{vertical,horizontal}-led.png     kontrolka (bílá, hra obarví podle stavu)
    graphics/icons/fb-bus-coupler.png                                ikona 64×64
Náhled (volitelný): spojka v řadě vanilla trubek vodorovně i svisle – k ladění rozměrů v coupler.toml.
Skript vždy začíná z prázdné scény (idempotentní). Moduly: model.py, fb_materials.py, fb_render.py.
"""
import math
import sys
import tomllib
from pathlib import Path

import bpy
import numpy as np

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
for _name in list(sys.modules):
    _file = getattr(sys.modules[_name], "__file__", None)
    if _file and Path(_file).parent == HERE:
        del sys.modules[_name]

import fb_render as R  # noqa: E402
import model  # noqa: E402

VANILLA = Path("C:/STEAM/steamapps/common/Factorio/data/base/graphics/entity/pipe")
#: Orientace spritu → natočení modelu (osa trubky X → svislá = otočení o 90°).
ORIENTATIONS = {"horizontal": 0.0, "vertical": 90.0}


def load_config():
    """Načte coupler.toml."""
    with open(HERE / "coupler.toml", "rb") as file:
        return tomllib.load(file)


def render_layer(scene, work, name, mode, parts, ground, px):
    """Vyrenderuje vrstvu do pracovní složky a vrátí ji zmenšenou na px."""
    path = str(work / f"{name}.png")
    R.render_pass(scene, path, mode, parts, ground)
    pixels = R.downsample(R.load_pixels(path))
    Path(path).unlink()
    return R.shadow_only(pixels) if mode == "shadow" else pixels


def render_led(scene, work, name, parts, led, ground):
    """Vrstva kontrolky: jen rozsvícená kontrolka (bílá – hra ji obarví podle stavu), ostatní díly ji zakrývají."""
    off = led.data.materials[0]
    led.data.materials[0] = bpy.data.materials["FB_LedOn"]
    for obj in parts:
        # Porovnání podle jména: Blender vrací pro stejný objekt různé pythonovské obaly (`is` nefunguje).
        obj.is_holdout = obj.name != led.name
        obj.visible_camera = True  # průchod stínu je mohl skrýt před kamerou
    ground.hide_render = True
    path = str(work / f"{name}.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    pixels = R.downsample(R.load_pixels(path))
    Path(path).unlink()
    for obj in parts:
        obj.is_holdout = False
    led.data.materials[0] = off
    return pixels


def colorize(layer, color):
    """Obarví vrstvu násobením barvou (jako apply_tint ve hře) – jen pro náhled."""
    out = layer.copy()
    out[..., :3] = out[..., :3] * np.array(color)
    return out


def place(canvas, sprite, tile_x, tile_y):
    """Složí sprite 128×128 (2×2 dlaždice) se středem na dlaždici (tile_x, tile_y) do plátna (64 px/dlaždice)."""
    # Plátno má okraj jedné dlaždice, aby se vešly i přečnívající sprity krajních buněk.
    x0, y0 = (tile_x + 1) * 64 + 32 - 64, (tile_y + 1) * 64 + 32 - 64
    h, w = sprite.shape[:2]
    region = canvas[y0:y0 + h, x0:x0 + w]
    canvas[y0:y0 + h, x0:x0 + w] = R.over(region, sprite)


def preview(frames, out_path):
    """Náhled: vodorovná řada a svislý sloupec vanilla trubek se spojkou uprostřed."""
    def vanilla(name):
        return R.load_pixels(str(VANILLA / f"pipe-{name}.png"))
    canvas = np.zeros((8 * 64, 10 * 64, 4), dtype=np.float32)
    canvas[..., :3] = (0.47, 0.44, 0.38)
    canvas[..., 3] = 1.0
    cells = [
        (6, 0, vanilla("ending-down")), (6, 1, vanilla("straight-vertical")),
        (6, 2, frames["vertical"]), (6, 3, vanilla("straight-vertical")), (6, 4, vanilla("ending-up")),
        (0, 2, vanilla("ending-right")), (1, 2, vanilla("straight-horizontal")), (2, 2, frames["horizontal"]),
        (3, 2, vanilla("straight-horizontal")), (4, 2, vanilla("ending-left")),
    ]
    for x, y, sprite in sorted(cells, key=lambda c: (c[1], c[0])):
        place(canvas, sprite, x, y)
    # Zvětšení 2× (nejbližší soused) – detail spojky je při 64 px/dlaždici malý.
    R.save_pixels(canvas.repeat(2, axis=0).repeat(2, axis=1), str(out_path))


def main():
    """Postaví scénu, vyrenderuje obě orientace, ikonu a případně náhled."""
    args = sys.argv[sys.argv.index("--") + 1:]
    mod = Path(args[0]).resolve()
    cfg = load_config()
    work = Path(bpy.app.tempdir)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    px = cfg["render"]["frame_px"]
    R.setup_render(scene, px)
    camera = R.setup_camera_and_lights(scene, ortho_scale=2.0)
    ground = R.add_ground(scene)
    root, parts, led = model.build(scene, cfg)

    frames = {}
    entity_dir = mod / "graphics" / "entity"
    entity_dir.mkdir(parents=True, exist_ok=True)
    for name, angle in ORIENTATIONS.items():
        root.rotation_euler = (0.0, 0.0, math.radians(angle))
        bpy.context.view_layer.update()
        base = render_layer(scene, work, f"{name}-base", "base", parts, ground, px)
        shadow = render_layer(scene, work, f"{name}-shadow", "shadow", parts, ground, px)
        R.save_pixels(base, str(entity_dir / f"fb-bus-coupler-{name}.png"))
        R.save_pixels(shadow, str(entity_dir / f"fb-bus-coupler-{name}-shadow.png"))
        light = render_led(scene, work, f"{name}-led", parts, led, ground)
        R.save_pixels(light, str(entity_dir / f"fb-bus-coupler-{name}-led.png"))
        # Náhled: kontrolka zeleně, jako by spojka měla proud.
        frames[name] = R.over(R.over(shadow, base), colorize(light, (0.2, 1.0, 0.3)))

    root.rotation_euler = (0.0, 0.0, 0.0)
    camera.data.ortho_scale = 1.2
    R.setup_render(scene, cfg["render"]["icon_px"])
    icon = render_layer(scene, work, "icon", "base", parts, ground, cfg["render"]["icon_px"])
    (mod / "graphics" / "icons").mkdir(parents=True, exist_ok=True)
    R.save_pixels(icon, str(mod / "graphics" / "icons" / "fb-bus-coupler.png"))

    if len(args) > 1:
        preview(frames, Path(args[1]).resolve())


main()
