#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
INSTANCE_DIR="${1:-}"

if [[ -z "$INSTANCE_DIR" || "$INSTANCE_DIR" == "-h" || "$INSTANCE_DIR" == "--help" ]]; then
  printf 'Usage: ./scripts/install-instance.sh /absolute/path/to/valheim-instance\n' >&2
  exit 2
fi

[[ "$INSTANCE_DIR" == /* ]] || {
  printf 'ERROR: instance path must be absolute: %s\n' "$INSTANCE_DIR" >&2
  exit 1
}
[[ -d "$INSTANCE_DIR" ]] || {
  printf 'ERROR: instance directory does not exist: %s\n' "$INSTANCE_DIR" >&2
  exit 1
}

install -m 0755 "$PROJECT_DIR/scripts/valheim-maintain.sh" "$INSTANCE_DIR/valheim-maintain.sh"
install -m 0755 "$PROJECT_DIR/scripts/valheim-serve.sh" "$INSTANCE_DIR/valheim-serve.sh"
install -m 0644 "$PROJECT_DIR/templates/valheim-mods.lock" "$INSTANCE_DIR/valheim-mods.lock"

if [[ ! -e "$INSTANCE_DIR/valheim.env" ]]; then
  install -m 0600 "$PROJECT_DIR/templates/valheim.env.example" "$INSTANCE_DIR/valheim.env"
  sed -i "s|/home/jim/games/valheim-example/saves|$INSTANCE_DIR/saves|" "$INSTANCE_DIR/valheim.env"
  printf 'Created %s/valheim.env; edit its name, port, world, and password before use.\n' "$INSTANCE_DIR"
else
  chmod 0600 "$INSTANCE_DIR/valheim.env"
  printf 'Preserved existing %s/valheim.env.\n' "$INSTANCE_DIR"
fi

printf 'Installed toolkit files into %s.\n' "$INSTANCE_DIR"
