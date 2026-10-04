"""Geometrie spojky busu – manometrová armatura (1 jednotka = 1 dlaždice, střed na počátku, osa trubky = X).

Díly: průchozí trubka s přírubami a šrouby (napojení na sousední BUS trubky), natřené válcové těleso s lemy,
manometr s ručičkou nakloněný ke kameře a elektrická skříňka s kabelem a kontrolkou.
Parametry v coupler.toml.
"""

import math

import bpy

import fb_materials as fm


def _finish(obj, name, mat, parent):
    """Pojmenuje objekt, přiřadí materiál a rodiče."""
    obj.name = name
    obj.data.materials.append(mat)
    obj.parent = parent
    return obj


def cylinder(name, radius, depth, location, mat, parent, rotation=(0.0, 0.0, 0.0), vertices=32, bevel=0.0):
    """Válec; rotation ve stupních, bevel = zaoblení hran."""
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, vertices=vertices, location=location,
                                        rotation=tuple(math.radians(a) for a in rotation))
    obj = bpy.context.active_object
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    bpy.ops.object.shade_smooth()
    return _finish(obj, name, mat, parent)


def box(name, size, location, mat, parent, bevel=0.01, rotation=(0.0, 0.0, 0.0)):
    """Kvádr (x, y, z) se zkosenými hranami; rotation ve stupních."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.scale = size
    obj.rotation_euler = tuple(math.radians(a) for a in rotation)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    return _finish(obj, name, mat, parent)


def materials(cfg):
    """Materiály spojky podle barev z konfigurace."""
    return {
        "pipe": fm.weathered_metal("FB_Pipe", tuple(cfg["pipe"]["color"]), rust=0.75, wear=0.45),
        "housing": fm.chipped_paint("FB_Housing", tuple(cfg["housing"]["color"]), chipping=0.66),
        "bolt": fm.weathered_metal("FB_Bolt", (0.2, 0.19, 0.17), rust=0.6, wear=0.8),
        "box": fm.chipped_paint("FB_Box", tuple(cfg["power"]["color"]), chipping=0.6),
        "bezel": fm.weathered_metal("FB_Bezel", tuple(cfg["gauge"]["bezel"]), rust=0.2, wear=0.9, metallic=0.9,
                                    roughness=0.35),
        "face": _plain("FB_Face", tuple(cfg["gauge"]["face"]), roughness=0.4),
        "needle": fm.chipped_paint("FB_Needle", tuple(cfg["gauge"]["needle"]), rusty=False, chipping=0.95),
        "cable": fm.rubber("FB_Cable"),
        "marking": fm.chipped_paint("FB_Marking", tuple(cfg["marking"]["color"]), rusty=False, chipping=0.9),
        # Kontrolka: v základním spritu zhasnutá; svítící bílou vrstvu obarví hra podle stavu (apply_tint).
        "led_off": fm.chipped_paint("FB_LedOff", (0.03, 0.03, 0.03), rusty=False, chipping=0.99),
        "led_on": _emission("FB_LedOn", (1.0, 1.0, 1.0)),
    }


def _plain(name, color, roughness=0.6):
    """Čistá matná barva bez patiny (ciferník – zrnitá patina by na 64 px vypadala jako šum)."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def _emission(name, color):
    """Svítící materiál (kontrolka)."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (*color, 1.0)
    emit.inputs["Strength"].default_value = 3.0
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return mat


def build(scene, cfg):
    """Postaví model; vrátí (root, díly, kontrolka). Root je pod pomocným objektem s protažením Y o √2
    (projekce hry). Kontrolka je v dílech také (zhasnutá); pro vrstvu světla se jí vymění materiál."""
    m = materials(cfg)
    stretch = bpy.data.objects.new("FB_Stretch", None)
    # Kamera pod 45° zkracuje hloubku o cos 45°; roztažení Y o √2 vrátí dlaždicím čtvercový tvar jako ve hře.
    stretch.scale = (1.0, math.sqrt(2.0), 1.0)
    # Vanilla trubky jsou kreslené na střed dlaždice; zvednutou osu kamera posune nahoru – vrátit posunem ke kameře.
    stretch.location = (0.0, cfg["pipe"]["screen_offset"], 0.0)
    scene.collection.objects.link(stretch)
    root = bpy.data.objects.new("FB_Root", None)
    root.parent = stretch
    scene.collection.objects.link(root)

    p, h, g, pw, mk = cfg["pipe"], cfg["housing"], cfg["gauge"], cfg["power"], cfg["marking"]
    z = p["height"]
    parts = [cylinder("FB_Pipe", p["radius"], 1.0, (0, 0, z), m["pipe"], root, rotation=(0, 90, 0))]
    for side in (-1, 1):
        x = side * p["flange_x"]
        parts.append(cylinder(f"FB_Flange_{side}", p["flange_radius"], p["flange_thickness"], (x, 0, z), m["pipe"],
                              root, rotation=(0, 90, 0), bevel=0.008))
        bolt_x = x - side * p["flange_thickness"] * 0.6
        for i in range(p["bolts"]):
            a = 2 * math.pi * (i + 0.5) / p["bolts"]
            r = (p["flange_radius"] + p["radius"]) / 2
            parts.append(cylinder(f"FB_Bolt_{side}_{i}", 0.018, 0.03, (bolt_x, r * math.cos(a), z + r * math.sin(a)),
                                  m["bolt"], root, rotation=(0, 90, 0), vertices=6))

    parts.append(cylinder("FB_Housing", h["radius"], h["length"], (0, 0, z), m["housing"], root,
                          rotation=(0, 90, 0), bevel=0.02))
    for side in (-1, 1):
        parts.append(cylinder(f"FB_Ring_{side}", h["radius"] + 0.012, h["ring"],
                              (side * (h["length"] / 2 - h["ring"] / 2), 0, z), m["bolt"], root,
                              rotation=(0, 90, 0), bevel=0.006))

    # Manometr: krček z vrcholu tělesa, ciferník nakloněný ke kameře (kamera se dívá od -Y).
    top = z + h["radius"]
    parts.append(cylinder("FB_GaugeNeck", 0.035, g["neck"], (0, 0, top + g["neck"] / 2), m["bolt"], root,
                          vertices=16))
    center = (0, -0.02, top + g["neck"] + g["radius"] * 0.75)
    tilt = (90 - g["tilt"], 0, 0)
    parts.append(cylinder("FB_GaugeBody", g["radius"], g["thickness"], center, m["bezel"], root, rotation=tilt,
                          bevel=0.01))
    normal = (0, -math.cos(math.radians(g["tilt"])), math.sin(math.radians(g["tilt"])))
    face_at = tuple(c + n * (g["thickness"] / 2 + 0.002) for c, n in zip(center, normal))
    parts.append(cylinder("FB_GaugeFace", g["radius"] * 0.8, 0.004, face_at, m["face"], root, rotation=tilt))
    needle_at = tuple(c + n * 0.006 for c, n in zip(face_at, normal))
    parts.append(box("FB_GaugeNeedle", (0.012, 0.004, g["radius"] * 0.7), needle_at, m["needle"], root, bevel=0,
                     rotation=(90 - g["tilt"] - 90, 35, 0)))

    # Černé „B“ nastříkané na čele tělesa: tenký text tečně k povrchu, natočený ke kameře.
    angle = math.radians(mk["angle"])
    curve = bpy.data.curves.new("FB_MarkingText", "FONT")
    curve.body = mk["text"]
    curve.size = mk["size"]
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.extrude = 0.002
    text = bpy.data.objects.new("FB_Marking", curve)
    scene.collection.objects.link(text)
    surface = h["radius"] + 0.004
    text.location = (mk["x"], -surface * math.sin(angle), z + surface * math.cos(angle))
    text.rotation_euler = (angle, 0.0, 0.0)
    curve.materials.append(m["marking"])
    text.parent = root
    parts.append(text)

    # Elektrická skříňka s kontrolkou (vpředu, ať je vidět) a kabelem k zemi.
    bx, by = pw["offset"]
    size = pw["box"]
    box_center = (bx, by, top - 0.02 + size[2] / 2)
    parts.append(box("FB_PowerBox", tuple(size), box_center, m["box"], root, bevel=0.012))
    led = cylinder("FB_Led", pw["led_radius"], 0.012, (bx, by - size[1] / 2 - 0.005, box_center[2] + 0.015), m["led_off"], root,
                   rotation=(90, 0, 0), vertices=16)
    parts.append(led)
    parts.append(cylinder("FB_Cable", 0.022, z + 0.05, (bx + size[0] * 0.3, by + size[1] / 2 + 0.03, (z + 0.05) / 2),
                          m["cable"], root, vertices=12))
    return root, parts, led
