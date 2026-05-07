# Cart Physics (Detailed)

This file explains the current cart model and why each force exists.

## Design Goals

1. Keep the cart stable when grabbed.
2. Prevent runaway launches on grab.
3. Keep turning responsive without camera-flick physics explosions.
4. Make tuning predictable with small parameter sets.

## Force Model Summary

### In `player.gd` (`_apply_cart_coupling`)

This is the planar “push linkage” between player and cart.

- Build a smoothed forward vector from player facing.
- Place an anchor point in front of player using leash distance.
- Compute horizontal position error from cart to anchor.
- Apply:
  - A clamped spring term (`cart_couple_stiffness`)
  - A velocity matching term (`cart_velocity_gain_*`)
- Blend in after grab (`cart_grab_blend_sec`) to avoid hard impulses.
- Clamp final horizontal force (`cart_max_planar_force`).
- Add a mild vertical bias mostly downward to avoid hovering.

### In `cart.gd` (`_integrate_forces`)

This is body stabilization and heading assist.

- Roll/pitch damping via angular velocity x/z.
- Yaw damping via angular velocity y.
- Yaw alignment torque toward camera heading (scaled down when idle).
- Grounding-only downward bias while grabbed and supported.

## Important Tunables

### Player coupling

- `cart_couple_stiffness`: stronger/slower leash position correction.
- `cart_velocity_gain_moving`: how strongly cart follows moving player velocity.
- `cart_velocity_gain_idle`: damping/follow behavior while standing.
- `cart_max_planar_force`: hard cap; protects against force spikes.
- `cart_grab_blend_sec`: attach smoothness.

### Cart body

- `yaw_align_strength`: heading correction strength.
- `yaw_max_torque`: upper bound for yaw torque.
- `yaw_angular_damping`: suppresses spin buildup.
- `roll_pitch_damping`: anti-wobble after bumps.
- `grabbed_downward_bias`: keeps cart planted while grabbed.

## Debug Symptoms -> Likely Knobs

- **Cart drifts when idle**
  - Lower `cart_velocity_gain_idle`.
  - Lower `yaw_align_idle_scale`.
- **Cart feels laggy to push**
  - Raise `cart_couple_stiffness` slightly.
  - Raise `cart_velocity_gain_moving`.
- **Cart jolts on attach**
  - Raise `cart_grab_blend_sec`.
  - Lower `cart_max_planar_force`.
- **Turning feels weak**
  - Raise `yaw_align_strength` or `yaw_max_torque`.
- **Too twitchy while looking around**
  - Lower `yaw_align_idle_scale`.

## Scope Guardrails

- Do not reintroduce multiple overlapping “helper” force stacks unless strictly needed.
- Keep one clear owner for each force category (player-coupling vs cart-stability).
