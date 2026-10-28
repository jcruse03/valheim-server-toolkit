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
# Exercise the real installer with deterministic local archives and mocked curl.
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/package/BepInExPack_Valheim/BepInEx/config" \
  "$TEST_ROOT/package/BepInExPack_Valheim/BepInEx/core" "$TEST_ROOT/portal"
printf 'package-default\n' >"$TEST_ROOT/package/BepInExPack_Valheim/BepInEx/config/BepInEx.cfg"
printf 'new-default\n' >"$TEST_ROOT/package/BepInExPack_Valheim/BepInEx/config/new.cfg"
touch "$TEST_ROOT/package/BepInExPack_Valheim/start_server_bepinex.sh" \
  "$TEST_ROOT/package/BepInExPack_Valheim/start_game_bepinex.sh"
touch "$TEST_ROOT/portal/ValheimCrossServerPortals.dll"
(cd "$TEST_ROOT/package" && zip -qr "$TEST_ROOT/framework.zip" .)
(cd "$TEST_ROOT/portal" && zip -qr "$TEST_ROOT/portal.zip" .)
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -eu
while [[ "$1" != '--output' ]]; do shift; done
output="$2"
url="$3"
case "$url" in
  *BepInExPack*) cp "$TEST_FRAMEWORK_ZIP" "$output" ;;
  *) cp "$TEST_PORTAL_ZIP" "$output" ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/curl"
export TEST_FRAMEWORK_ZIP="$TEST_ROOT/framework.zip" TEST_PORTAL_ZIP="$TEST_ROOT/portal.zip"
export PATH="$TEST_ROOT/bin:$PATH"
{
  printf 'BEPINEX_SHA256=%s\n' "$(sha256sum "$TEST_FRAMEWORK_ZIP" | cut -d ' ' -f1)"
  printf 'PORTAL_SHA256=%s\n' "$(sha256sum "$TEST_PORTAL_ZIP" | cut -d ' ' -f1)"
} >>"$INSTANCE_DIR/valheim-mods.lock"
mkdir -p "$INSTANCE_DIR/BepInEx/config"
printf 'administrator-setting\n' >"$INSTANCE_DIR/BepInEx/config/BepInEx.cfg"
printf 'portal-setting\n' >"$INSTANCE_DIR/BepInEx/config/portal.cfg"
"$INSTANCE_DIR/valheim-maintain.sh" install >/dev/null
grep -qx 'administrator-setting' "$INSTANCE_DIR/BepInEx/config/BepInEx.cfg"
grep -qx 'portal-setting' "$INSTANCE_DIR/BepInEx/config/portal.cfg"
grep -qx 'new-default' "$INSTANCE_DIR/BepInEx/config/new.cfg"
printf 'All maintenance tests passed.\n'
