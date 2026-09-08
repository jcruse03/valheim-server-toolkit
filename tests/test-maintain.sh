#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d -t valheim-toolkit-test.XXXXXXXX)"
INSTANCE_DIR="$TEST_ROOT/valheim-test"
BACKUP_ROOT="$TEST_ROOT/backups"

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$INSTANCE_DIR/saves" "$INSTANCE_DIR/BepInEx/core" \
  "$INSTANCE_DIR/BepInEx/plugins" "$INSTANCE_DIR/doorstop_libs"
install -m 0755 "$PROJECT_DIR/scripts/valheim-maintain.sh" "$INSTANCE_DIR/valheim-maintain.sh"
install -m 0755 "$PROJECT_DIR/scripts/valheim-serve.sh" "$INSTANCE_DIR/valheim-serve.sh"
install -m 0644 "$PROJECT_DIR/templates/valheim-mods.lock" "$INSTANCE_DIR/valheim-mods.lock"
install -m 0600 "$PROJECT_DIR/templates/valheim.env.example" "$INSTANCE_DIR/valheim.env"
touch "$INSTANCE_DIR/valheim_server.x86_64"
touch "$INSTANCE_DIR/BepInEx/core/BepInEx.Preloader.dll"
touch "$INSTANCE_DIR/BepInEx/plugins/ValheimCrossServerPortals.dll"
touch "$INSTANCE_DIR/doorstop_libs/libdoorstop_x64.so"
printf 'test-manifest\n' >"$INSTANCE_DIR/.valheim-mod-versions"
printf 'original-save\n' >"$INSTANCE_DIR/saves/world.db"

export VALHEIM_BACKUP_ROOT="$BACKUP_ROOT"
export VALHEIM_SERVICE_NAME="valheim-toolkit-test-does-not-exist.service"

"$INSTANCE_DIR/valheim-maintain.sh" verify >/dev/null
"$INSTANCE_DIR/valheim-maintain.sh" backup-working >/dev/null

pointer="$BACKUP_ROOT/valheim-test/latest-working"
[[ -s "$pointer" ]] || {
  printf 'latest-working pointer was not created\n' >&2
  exit 1
}

printf 'mutated-save\n' >"$INSTANCE_DIR/saves/world.db"
"$INSTANCE_DIR/valheim-maintain.sh" restore latest >/dev/null
grep -qx 'original-save' "$INSTANCE_DIR/saves/world.db"

specific="$(sed -n '1p' "$pointer")"
printf 'mutated-again\n' >"$INSTANCE_DIR/saves/world.db"
"$INSTANCE_DIR/valheim-maintain.sh" restore "$specific" >/dev/null
grep -qx 'original-save' "$INSTANCE_DIR/saves/world.db"

list_output="$("$INSTANCE_DIR/valheim-maintain.sh" list-backups)"
[[ "$list_output" == *"$specific"* ]]
printf 'All maintenance tests passed.\n'
