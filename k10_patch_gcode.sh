#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'EOF'
Usage:
  k10_patch_gcode.sh INPUT.gcode [OUTPUT.gcode] [options]

Options:
  --temp N                Set startup nozzle temp for first M104/M109 (default: 220)
  --z-offset N            Add effective first-layer lift after homing (default: 0.2)
  --first-layer-speed N   Insert M220 S<N> before ;LAYER:0 (default: 75)
  --normal-speed N        Insert M220 S<N> before ;LAYER:1 (default: 100)
  --force                 Overwrite output file if it already exists
  -h, --help              Show this help

Behavior:
  - Writes a patched copy. It does not modify the original input file.
  - Replaces only the first startup M104 and M109 commands.
  - Inserts:
      G92 Z-<offset> after the first G28 homing line
      M220 S<first-layer-speed> before ;LAYER_COUNT when present,
      otherwise before ;LAYER:0
      M220 S<normal-speed> before ;LAYER:1
  - Avoids adding duplicate K10 helper lines if they are already present.
EOF
}

if [[ $# -lt 1 ]]; then
  show_help
  exit 1
fi

INPUT=""
OUTPUT=""
TEMP=220
Z_OFFSET=0.2
FIRST_LAYER_SPEED=75
NORMAL_SPEED=100
FORCE=0

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --temp)
      TEMP="${2:?missing value for --temp}"
      shift 2
      ;;
    --z-offset)
      Z_OFFSET="${2:?missing value for --z-offset}"
      shift 2
      ;;
    --first-layer-speed)
      FIRST_LAYER_SPEED="${2:?missing value for --first-layer-speed}"
      shift 2
      ;;
    --normal-speed)
      NORMAL_SPEED="${2:?missing value for --normal-speed}"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    -*)
      printf 'Unknown option: %s\n' "$1" >&2
      exit 1
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [[ ${#POSITIONAL[@]} -lt 1 || ${#POSITIONAL[@]} -gt 2 ]]; then
  show_help
  exit 1
fi

INPUT="${POSITIONAL[0]}"
if [[ ! -f "$INPUT" ]]; then
  printf 'Input file not found: %s\n' "$INPUT" >&2
  exit 1
fi

if [[ ${#POSITIONAL[@]} -eq 2 ]]; then
  OUTPUT="${POSITIONAL[1]}"
else
  case "$INPUT" in
    *.gcode) OUTPUT="${INPUT%.gcode}_k10_adjusted.gcode" ;;
    *) OUTPUT="${INPUT}_k10_adjusted.gcode" ;;
  esac
fi

if [[ -e "$OUTPUT" && $FORCE -ne 1 ]]; then
  printf 'Output already exists: %s\nUse --force to overwrite it.\n' "$OUTPUT" >&2
  exit 1
fi

TMP_OUTPUT="$(mktemp)"
trap 'rm -f "$TMP_OUTPUT"' EXIT

awk \
  -v temp="$TEMP" \
  -v z_offset="$Z_OFFSET" \
  -v first_layer_speed="$FIRST_LAYER_SPEED" \
  -v normal_speed="$NORMAL_SPEED" \
'
  {
    lines[NR] = $0
  }
  END {
    saw_m104 = 0
    saw_m109 = 0
    inserted_z = 0
    inserted_l0 = 0
    inserted_l1 = 0

    z_line = "G92 Z-" z_offset " ; raise effective first layer by " z_offset "mm"
    l0_line = "M220 S" first_layer_speed " ; slow first layer for better adhesion on K10"
    l1_line = "M220 S" normal_speed " ; restore normal speed after first layer"

    for (i = 1; i <= NR; i++) {
      line = lines[i]
      next_line = (i < NR ? lines[i + 1] : "")
      prev_line = (i > 1 ? lines[i - 1] : "")

      if (!saw_m104 && line ~ /^M104[[:space:]]+S[0-9]+([.][0-9]+)?([[:space:]]*;.*)?$/) {
        print "M104 S" temp
        saw_m104 = 1
        continue
      }

      if (!saw_m109 && line ~ /^M109[[:space:]]+S[0-9]+([.][0-9]+)?([[:space:]]*;.*)?$/) {
        print "M109 S" temp
        saw_m109 = 1
        continue
      }

      if (!inserted_z && line ~ /^G28([[:space:]]*;.*)?$/) {
        print line
        if (next_line !~ /^G92[[:space:]]+Z-[0-9.]+[[:space:]]*;[[:space:]]*raise effective first layer by /) {
          print z_line
        }
        inserted_z = 1
        continue
      }

      if (!inserted_l0 && line ~ /^;LAYER_COUNT:/) {
        if (prev_line !~ /^M220[[:space:]]+S[0-9]+([[:space:]]*;[[:space:]]*slow first layer for better adhesion on K10)?$/) {
          print l0_line
        }
        print line
        inserted_l0 = 1
        continue
      }

      if (!inserted_l0 && line ~ /^;LAYER:0$/) {
        if (prev_line !~ /^M220[[:space:]]+S[0-9]+([[:space:]]*;[[:space:]]*slow first layer for better adhesion on K10)?$/) {
          print l0_line
        }
        print line
        inserted_l0 = 1
        continue
      }

      if (!inserted_l1 && line ~ /^;LAYER:1$/) {
        if (prev_line !~ /^M220[[:space:]]+S[0-9]+([[:space:]]*;[[:space:]]*restore normal speed after first layer)?$/) {
          print l1_line
        }
        print line
        inserted_l1 = 1
        continue
      }

      print line
    }
  }
' "$INPUT" > "$TMP_OUTPUT"

mv -f "$TMP_OUTPUT" "$OUTPUT"
trap - EXIT

printf 'Patched K10 G-code written to: %s\n' "$OUTPUT"
