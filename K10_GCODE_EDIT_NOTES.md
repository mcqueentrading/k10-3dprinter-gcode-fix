# K10 G-code Edit Notes

These are the usual edits that have helped Cura-generated G-code print better on the EasyThreed K10.

## Baseline Checks

- Keep the model inside the K10 build volume: about `100 x 100 x 100 mm`.
- Avoid placing the model or skirt/brim at `X0` or `Y0`; leave a few millimeters of bed margin when possible.
- Prefer simple filenames for the TF card: letters and numbers only.
- If Cura says `SKIRT`, that is not a brim. A real brim should show `;TYPE:BRIM` in the G-code.

## Typical Manual Patch

Use these changes on a copied file, not the original slicer export.

1. Raise PLA nozzle startup temperature from `200C` to `220C`:

```gcode
M104 S220
M109 S220
```

2. If the first layer prints too low but the cat test prints fine, add a small effective Z lift right after homing:

```gcode
G28 ;Home
G92 Z-0.2 ; raise effective first layer by 0.2mm
```

Do not use `1` or `2` mm for normal first-layer correction. Start with `0.2 mm`; try `0.3 mm` only if it still scrapes.

3. Slow the first layer:

```gcode
M220 S75 ; slow first layer for better adhesion on K10
```

Place it before `;LAYER:0`.

4. Restore normal speed at layer 1:

```gcode
M220 S100 ; restore normal speed after first layer
;LAYER:1
```

## When To Re-slice Instead

- Re-slice in Cura if the model needs a real brim, support changes, rotation, scale changes, or if the G-code bounds touch the bed edge.
- Use `Draft 0.2 mm` as a reliable starting layer height.
- Use `Brim` for bed adhesion when a model may get knocked loose.
- Use supports for floating parts; use `Everywhere` only when `Touching Buildplate` misses necessary support.

## TODO: Calibration

- Run a calibration print later to compare the current K10 settings against a slower `13 mm/s` print speed.
- In G-code terms, `13 mm/s` is `F780`, but prefer changing print speed in Cura and re-slicing instead of bulk-editing feed rates.
