#!/bin/bash
# Start of a Claude Code session in Shift Time.
# 1) Prints the «Сейчас» section of docs/progress.md: the session starts with the
#    project state in its context and needs no step to read it.
# 2) In a cloud session, puts the pinned Godot on PATH if it is missing and imports
#    the project once, so the test commands from CLAUDE.md work at once.
#    The version and the SHA-512 come from the CI action, one place for both.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

awk '/^## Сейчас/{f=1; next} /^## /{if (f) exit} f' docs/progress.md
echo "Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

action=.github/actions/install-godot/action.yml
version=$(sed -n 's/^ *GODOT_VERSION: *//p' "$action")
sum=$(sed -n 's/^ *GODOT_SHA512: *//p' "$action")
if ! godot --version 2>/dev/null | grep -q "^${version%-stable}\.stable"; then
  name="Godot_v${version}_linux.x86_64"
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/${version}/${name}.zip"
  echo "${sum}  $tmp/godot.zip" | sha512sum -c - >/dev/null
  mkdir -p /opt/godot
  unzip -o -q "$tmp/godot.zip" -d /opt/godot
  chmod +x "/opt/godot/${name}"
  ln -sf "/opt/godot/${name}" /usr/local/bin/godot
  rm -rf "$tmp"
  echo "Godot ${version} installed."
fi

if [ ! -d game/.godot ]; then
  godot --headless --path game --import >/dev/null 2>&1
  echo "Godot project imported."
fi
