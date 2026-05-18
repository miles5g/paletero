# El Paletero

A gritty first-person urban vending prototype in **Godot 4** — push a physics-driven paleta cart through a low-poly city block, serve NPC customers, and manage inventory under PS2-era presentation.

## Key concepts (portfolio)

- **Physics cart as core verb** — The cart is a `RigidBody3D` (Jolt). While grabbed, the player applies planar leash forces and velocity blending; the cart handles yaw alignment, stability damping, and grounded jump checks. Player and cart must both be grounded to hop together.
- **Procedural city block** — Streets, curbs, sidewalks, and parcel pads are built in code (`world.gd`) with a shared layer profile (road grade, curb crown, walk surface, lot line) so art and collision stay aligned.
- **NPC sales loop** — Clients approach the cart; dialogue and a terminal-style transaction UI handle quotes, inventory, and payouts without breaking first-person control flow.
- **Terminal HUD** — Manifest, stats, minimap, and map views share proxy geometry that mirrors the procedural layout.

## Tech stack

- Godot 4.x (Forward+), **Jolt Physics**
- GDScript
- Procedural meshes + CSG (world floor), hand-painted-style floor materials (chunky UVs / triplanar walks)
- Optional deeper notes: [`docs/CODEBASE_MAP.md`](docs/CODEBASE_MAP.md), [`docs/CART_PHYSICS_DETAILED.md`](docs/CART_PHYSICS_DETAILED.md)

## Current features

| Area | What's in the build |
|------|---------------------|
| **Movement** | WASD, sprint, crouch, jump (coyote time when not pushing) |
| **Cart** | Grab/release, push coupling, camera-steered heading, jump sync, impact feedback |
| **World** | Cross-shaped streets, curbs, concrete sidewalks, parcel pads, mock L-shaped buildings |
| **Time** | `CelestialCycle` day/night lighting |
| **Economy** | Cart + player inventory, item pickups, NPC transactions |
| **UI** | Master HUD (Tab manifest, M map), minimap, NPC dialogue + sell terminal |
| **Look** | Low-poly / chunky textures, fog and grade tuned for a PS2-adjacent read |

## Run

1. Open the project in **Godot 4.x** (project uses Jolt — enable or use a build that includes it).
2. Open `world.tscn`.
3. **Play Scene** (F6).

## Controls

| Input | Action |
|-------|--------|
| `WASD` | Move |
| `Mouse` | Look |
| `E` | Grab / release cart · interact |
| `Space` | Jump |
| `Shift` | Sprint |
| `Ctrl` | Crouch |
| `Tab` | Toggle inventory (manifest) |
| `M` | Map view |
| `T` | Toggle celestial wait / time pause |
| `Esc` | Close menus / back out of NPC UI |

## Project layout (quick)

- `world.gd` — Procedural block, spawns player/cart/NPCs, street layout
- `player.gd` — Movement, cart coupling, inventory, NPC UI hooks
- `cart.gd` — Rigid-body helpers, jump gating, interaction zones
- `master_hud.gd` / `minimap_hud.gd` — HUD and map proxies
- `client_npc.gd`, `npc_transaction_ui.gd`, `npc_dialogue_ui.gd` — Customer flow

## Status

Active prototype — mechanics and blockout over content breadth. Good fit for demonstrating **physics feel**, **procedural level assembly**, and **gameplay UI integration** in a small scoped slice.
