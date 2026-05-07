# Paletero Codebase Map

This document is a high-level map of the gameplay code so new contributors (and LLMs) can quickly find where behavior lives.

## Core Runtime Flow

- `world.gd`
  - Procedurally builds the play space.
  - Spawns and configures the `Cart` rigid body.
  - Spawns the `Player`.
  - Connects world UI/HUD interactions.
- `player.gd`
  - First-person movement and input.
  - Cart grab/release state.
  - Applies cart coupling forces while pushing.
  - Handles held items and inventory interactions.
- `cart.gd`
  - Cart rigid-body physics helpers (yaw alignment, stability damping, grounding while grabbed).
  - Cart interaction trigger areas.
  - Cart inventory storage API.

## UI / HUD Systems

- `master_hud.gd`
  - Main HUD pages.
  - Inventory menu and transfer logic.
  - Map view and proxy geometry for map rendering.
- `minimap_hud.gd`
  - Real-time minimap viewport and markers.
  - Lightweight proxy world geometry used by minimap camera.

## Data and Item Systems

- `item_resource.gd`
  - Data shape for inventory entries.
- `physical_item.gd`
  - World pickup object behavior and physical representation.

## Time / Lighting Systems

- `celestial_cycle.gd`
  - Day/night progression and environmental lighting sync.

## Cart Physics Ownership Rules

To avoid “dueling forces,” cart responsibilities are intentionally split:

- `player.gd` owns **cart planar coupling** (XZ pull/velocity blending while grabbed).
- `cart.gd` owns **body-level stabilization** and **yaw alignment**.

This split should remain stable unless a refactor intentionally changes ownership.
