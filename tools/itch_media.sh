#!/usr/bin/env bash
# Pictures for the itch.io page (task И1, 27.11.2026), remade in one line from
# the levels as they are now: a GIF of level 01 «the world goes back, she goes
# forward» and one 1920x1080 screenshot per level, each taken while the level's
# solution plays (tests/solutions/level_NN.json) at the tick given below.
#
#   tools/itch_media.sh            # GIF and every screenshot
#   tools/itch_media.sh shots      # only the screenshots
#   tools/itch_media.sh gif        # only the GIF
#   tools/itch_media.sh cover      # only the 630x500 cover (tools/itch_cover.py)
#   tools/itch_media.sh shots level_03:760   # one level at another tick
#
# Output: docs/itch/gif/level_01_rewind.gif (under 3 MB, the itch cap for a
# page image, D204) and
# docs/itch/shots/level_NN.jpg. Uses tools/shots.sh (xvfb, ImageMagick, ffmpeg).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$root/build/itch"
what="${1:-all}"
shift || true

# level:tick — a moment of the solution under Shift, after the opening overview.
SHOTS=(level_01:900 level_02:600 level_03:760 level_04:740 level_05:1110)
if [[ $# -gt 0 ]]; then
	SHOTS=("$@")
fi
# The GIF: ticks of the level 01 solution where the platform plays back up and
# carries her to the exit; 15 frames a second, 560 px wide.
GIF_FROM=660
GIF_TO=1060
GIF_WIDTH=560
GIF_COLORS=96
GIF_LIMIT_MB=3

mkdir -p "$root/docs/itch/gif" "$root/docs/itch/shots"

if [[ "$what" == all || "$what" == shots ]]; then
	for item in "${SHOTS[@]}"; do
		level="${item%%:*}"
		tick="${item##*:}"
		out="$work/$level"
		rm -rf "$out"
		"$root/tools/shots.sh" "$level" --from "$tick" --to "$tick" --every 1 --out "$out" >/dev/null
		frame=$(ls "$out"/t*.png | head -1)
		convert "$frame" -quality 90 "$root/docs/itch/shots/$level.jpg"
		echo "shot: docs/itch/shots/$level.jpg (tick $tick, $(identify -format '%wx%h' "$frame"))"
	done
fi

if [[ "$what" == all || "$what" == gif ]]; then
	out="$work/gif"
	rm -rf "$out"
	"$root/tools/shots.sh" level_01 --every 4 --from "$GIF_FROM" --to "$GIF_TO" --scale 0.5 --out "$out" >/dev/null
	gif="$root/docs/itch/gif/level_01_rewind.gif"
	ffmpeg -loglevel error -y -framerate 15 -pattern_type glob -i "$out/t*.png" \
		-vf "scale=$GIF_WIDTH:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=$GIF_COLORS:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
		-loop 0 "$gif"
	size=$(stat -c %s "$gif")
	echo "gif: docs/itch/gif/level_01_rewind.gif ($((size / 1024)) KB)"
	if (( size > GIF_LIMIT_MB * 1024 * 1024 )); then
		echo "the GIF is over $GIF_LIMIT_MB MB: narrow GIF_FROM..GIF_TO or GIF_WIDTH" >&2
		exit 1
	fi
fi

if [[ "$what" == all || "$what" == cover ]]; then
	python3 "$root/tools/itch_cover.py"
fi
