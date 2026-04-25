# k10-3dprinter-gcode-fix

A small EasyThreed K10 G-code fixer that patches Cura-generated files with startup temperature, effective Z-offset, and first-layer speed adjustments while preserving the original file.

## What It Does

This tool takes an existing `.gcode` file and writes out a separate adjusted copy for the EasyThreed K10.

The current patch flow can:

- raise the first startup nozzle temperature
- add a small effective Z lift after homing
- slow the first layer for better adhesion
- restore normal speed after the first layer

The original slicer export is not modified.

## Why This Exists

The EasyThreed K10 can be awkward with stock Cura-style output. This script exists to apply a small, repeatable set of edits that improved real prints without manually opening each G-code file and editing lines by hand every time.

This project is aimed at practical K10 use, not at replacing proper slicer setup. If a print needs support changes, brim changes, rotation, scale changes, or bed-bound corrections, it should be re-sliced instead of force-patched.

## Files

- `k10_patch_gcode.sh`
  The main patch script.
- `K10_GCODE_EDIT_NOTES.md`
  Notes explaining the practical edits and when to re-slice instead.

## Current Patch Rules

By default the script:

1. changes the first startup `M104` to `S220`
2. changes the first startup `M109` to `S220`
3. inserts:
   `G92 Z-0.2 ; raise effective first layer by 0.2mm`
   after the first `G28`
4. inserts:
   `M220 S75 ; slow first layer for better adhesion on K10`
   before `;LAYER_COUNT` when that marker exists, otherwise before `;LAYER:0`
5. inserts:
   `M220 S100 ; restore normal speed after first layer`
   before `;LAYER:1`

## Usage

Basic usage:

```bash
./k10_patch_gcode.sh input.gcode
```

This writes:

```text
input_k10_adjusted.gcode
```

Explicit output file:

```bash
./k10_patch_gcode.sh input.gcode output.gcode
```

With manual tuning:

```bash
./k10_patch_gcode.sh input.gcode output.gcode \
  --temp 220 \
  --z-offset 0.2 \
  --first-layer-speed 75 \
  --normal-speed 100
```

Overwrite an existing output:

```bash
./k10_patch_gcode.sh input.gcode output.gcode --force
```

## Command Options

- `--temp N`
  Set startup nozzle temperature.
- `--z-offset N`
  Set the effective first-layer Z lift.
- `--first-layer-speed N`
  Set the inserted `M220` value before the first layer.
- `--normal-speed N`
  Set the inserted `M220` value used to restore normal speed.
- `--force`
  Overwrite the output file if it already exists.

## Example

If the input begins like this:

```gcode
M104 S200
M109 S200
G28 ;Home
G1 Z15.0 F6000 ;Move the platform down 15mm
...
;LAYER_COUNT:297
;LAYER:0
```

The patched output becomes:

```gcode
M104 S220
M109 S220
G28 ;Home
G92 Z-0.2 ; raise effective first layer by 0.2mm
G1 Z15.0 F6000 ;Move the platform down 15mm
...
M220 S75 ; slow first layer for better adhesion on K10
;LAYER_COUNT:297
;LAYER:0
```

And before `;LAYER:1`:

```gcode
M220 S100 ; restore normal speed after first layer
;LAYER:1
```

## Limits

This script is intentionally narrow. It does not try to:

- re-slice models
- generate supports
- fix bad bed placement
- change model scale or orientation
- rewrite full feed-rate strategy across the file

It is meant for a small, repeatable patch set only.

## Commercial Use

This repository is licensed under the BSD 3-Clause License.

That means you can use, modify, redistribute, and sell software that includes this code, provided the BSD license terms are kept with the distribution.

## Notes

This project is based on practical K10 edits that worked on real Cura-generated files. It should still be tested on your own printer, filament, and model setup before trusting it on important prints.
