-- Vygenerováno skriptem blender/marking.py z blender/marking.toml – neupravovat ručně.
-- Kde na kusu trubky sedí nastříkané „B“: posun v dlaždicích (x doprava, y dolů) a orientace.
return {
  cross = { shift = { 0.0, -0.05 }, orientation = "horizontal" },
  east = { shift = { 0.1, 0.05 }, orientation = "horizontal" },
  north = { shift = { 0.0, -0.35 }, orientation = "vertical" },
  south = { shift = { 0.0, -0.02 }, orientation = "vertical" },
  straight_horizontal = { shift = { 0.0, -0.05 }, orientation = "horizontal" },
  straight_horizontal_window = { shift = { 0.0, -0.05 }, orientation = "horizontal" },
  straight_vertical = { shift = { 0.0, -0.1 }, orientation = "vertical" },
  straight_vertical_window = { shift = { 0.0, -0.1 }, orientation = "vertical" },
  t_down = { shift = { 0.0, -0.05 }, orientation = "horizontal" },
  t_left = { shift = { 0.0, -0.1 }, orientation = "vertical" },
  t_right = { shift = { 0.0, -0.1 }, orientation = "vertical" },
  t_up = { shift = { 0.0, -0.05 }, orientation = "horizontal" },
  west = { shift = { -0.1, 0.05 }, orientation = "horizontal" },
}
