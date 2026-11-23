#!/usr/bin/env bash
# Screenshots of a level in the real renderer (task Д0). Runs tools/shots.gd on
# a virtual screen, then glues the frames into one contact sheet that a session
# can look at in one read, and optionally a video.
#
#   tools/shots.sh level_01 [shots.gd arguments ...]
#   tools/shots.sh level_01 --every 30 --scale 0.5
#   tools/shots.sh level_02 --every 2 --from 600 --to 900 --video
#   tools/shots.sh --level level_01 --ticks 240 --hold rewind
#   tools/shots.sh --scene mech_test --plan '150:;120:rewind' --every 30
#
# Output: build/shots/NAME/ — frames t00120_fwd.png / t00120_rev.png,
# sheet.png (labelled tick and direction), and with --video also video.mp4.
# Needs xvfb-run, ImageMagick (montage) and ffmpeg for --video; all three are in
# the cloud container. build/ is ignored by git.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

video=0
args=()
name=""
if [[ $# -gt 0 && "$1" != --* ]]; then
	name="$1"
	args+=(--solution "$1")
	shift
fi
while [[ $# -gt 0 ]]; do
	case "$1" in
		--video) video=1; shift ;;
		--level|--scene) name="${name:-$2}"; args+=("$1" "$2"); shift 2 ;;
		--out) out="$2"; args+=("$1" "$2"); shift 2 ;;
		*) args+=("$1"); shift ;;
	esac
done
if [[ -z "$name" ]]; then
	echo "usage: tools/shots.sh SOLUTION_NAME [--every N] [--from T] [--to T] [--scale F] [--video]" >&2
	exit 1
fi
out="${out:-$root/build/shots/$name}"
mkdir -p "$out"
rm -f "$out/sheet.png" "$out/video.mp4"

# --fixed-fps 60: one rendered frame per physics tick, so frame N is tick N.
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path "$root/game" --rendering-driver opengl3 \
	--fixed-fps 60 --script "$root/tools/shots.gd" -- "${args[@]}" --out "$out" 2>&1 \
	| grep -E '^SHOTS|^shots:|SCRIPT ERROR' || true

shopt -s nullglob
frames=("$out"/t*.png)
if [[ ${#frames[@]} -eq 0 ]]; then
	echo "no frames saved" >&2
	exit 1
fi
if [[ $video -eq 1 ]]; then
	ffmpeg -loglevel error -y -framerate 30 -pattern_type glob -i "$out/t*.png" \
		-vf "scale=960:-2" -pix_fmt yuv420p "$out/video.mp4"
	echo "video: $out/video.mp4"
fi
# A sheet of at most 24 frames, evenly picked, 4 per row, 480 px wide each.
step=$(( (${#frames[@]} + 23) / 24 ))
picked=()
for (( i = 0; i < ${#frames[@]}; i += step )); do
	picked+=("${frames[$i]}")
done
montage -label '%t' "${picked[@]}" -geometry 480x270+4+4 -tile 4x \
	-pointsize 18 -background '#202020' -fill white "$out/sheet.png"
echo "sheet: $out/sheet.png (${#picked[@]} of ${#frames[@]} frames)"
