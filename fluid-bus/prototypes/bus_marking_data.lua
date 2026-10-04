-- Vygenerováno skriptem blender/marking.py z blender/marking.toml – neupravovat ručně.
-- Kde na kusu trubky sedí nastříkané „B“: posun v dlaždicích (x doprava, y dolů) a orientace.
return {
  east = { shift = { 0.1, 0.05 }, orientation = "horizontal" },
  north = { shift = { 0.0, -0.35 }, orientation = "vertical" },
  south = { shift = { 0.0, -0.02 }, orientation = "vertical" },
  straight_horizontal = { shift = { 0.0, -0.05 }, orientation = "horizontal" },
  straight_vertical = { shift = { 0.0, -0.1 }, orientation = "vertical" },
  west = { shift = { -0.1, 0.05 }, orientation = "horizontal" },
}
