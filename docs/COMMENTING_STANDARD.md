# Commenting Standard

Use this standard for “explainability-first” code.

## Goals

- Make intent obvious without reverse-engineering math.
- Explain ownership boundaries between systems.
- Explain why a clamp/ramp/constant exists (not just what line does).

## Required Comment Types

1. **Function header intent**
   - One short block that states purpose and subsystem ownership.
2. **Force/math phases**
   - Label each phase (e.g., “position term,” “velocity term,” “final clamp”).
3. **Guardrails**
   - Comment why thresholds/clamps are present.
4. **Non-obvious state vars**
   - Comment persistent vars that encode behavior (blend, leash, smoothing vectors).

## Recommended Pattern

```gdscript
# 1) Build stable reference...
# 2) Compute error...
# 3) Apply term A...
# 4) Clamp...
```

Use numbered step comments for dense physics or rendering blocks.

## Keep Comments Accurate

- Update comments in the same change as code edits.
- If behavior changes, stale comments are bugs.
