# HUD + Map Notes

This document explains how map rendering is assembled and where warnings/fixes were applied.

## Files

- `master_hud.gd`
  - Primary map view and inventory UI logic.
- `minimap_hud.gd`
  - In-game minimap overlay.

## Map Proxy Geometry

Both HUD scripts construct simplified proxy meshes (roads, curbs, plinth) for map cameras.

Why proxy geometry exists:
- Improves readability of map render.
- Decouples map visuals from full world complexity.
- Allows map-specific material and color treatment.

## Godot 4 Material Compatibility

Removed deprecated properties from both files:
- `polygon_offset_factor`
- `polygon_offset_units`

These were old remapped properties that generated warnings in Godot 4.

## If z-fighting returns

Use Godot 4-compatible material/depth settings instead of legacy property names. Keep changes mirrored in both files to avoid map/minimap visual divergence.
