#!/usr/bin/env bash
set -Eeuo pipefail

SERVER_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_FILE="$SERVER_DIR/valheim.env"

[[ -r "$CONFIG_FILE" ]] || {
  printf 'ERROR: Missing or unreadable configuration: %s\n' "$CONFIG_FILE" >&2
  exit 1
}

# This administrator-owned file contains the server password and launch settings.
# shellcheck disable=SC1090
source "$CONFIG_FILE"

: "${SERVER_NAME:?SERVER_NAME is required}"
: "${SERVER_PORT:?SERVER_PORT is required}"
: "${WORLD_NAME:?WORLD_NAME is required}"
: "${SERVER_PASSWORD:?SERVER_PASSWORD is required}"
: "${SAVE_DIR:?SAVE_DIR is required}"

[[ "$SERVER_PORT" =~ ^[0-9]+$ ]] || {
  printf 'ERROR: SERVER_PORT must be numeric.\n' >&2
  exit 1
}
(( SERVER_PORT >= 1024 && SERVER_PORT <= 65534 )) || {
  printf 'ERROR: SERVER_PORT must be between 1024 and 65534.\n' >&2
  exit 1
}
[[ ${#SERVER_PASSWORD} -ge 5 ]] || {
  printf 'ERROR: Valheim requires a password of at least five characters.\n' >&2
  exit 1
}
[[ "${SERVER_PUBLIC:-1}" =~ ^[01]$ ]] || {
  printf 'ERROR: SERVER_PUBLIC must be 0 or 1.\n' >&2
  exit 1
}
[[ "${CROSSPLAY:-1}" =~ ^[01]$ ]] || {
  printf 'ERROR: CROSSPLAY must be 0 or 1.\n' >&2
  exit 1
}

cd "$SERVER_DIR"
mkdir -p "$SAVE_DIR"

[[ -f "$SERVER_DIR/BepInEx/core/BepInEx.Preloader.dll" ]] || {
  printf 'ERROR: BepInEx is not installed. Run ./valheim-maintain.sh install first.\n' >&2
  exit 1
}

export DOORSTOP_ENABLED=1
export DOORSTOP_TARGET_ASSEMBLY="$SERVER_DIR/BepInEx/core/BepInEx.Preloader.dll"
export LD_LIBRARY_PATH="$SERVER_DIR/doorstop_libs:$SERVER_DIR/linux64:${LD_LIBRARY_PATH:-}"
export LD_PRELOAD="libdoorstop_x64.so${LD_PRELOAD:+:$LD_PRELOAD}"
export SteamAppId=892970
export SteamAppID=892970

args=(
  -nographics
  -batchmode
  -name "$SERVER_NAME"
  -port "$SERVER_PORT"
  -world "$WORLD_NAME"
  -password "$SERVER_PASSWORD"
  -savedir "$SAVE_DIR"
  -public "${SERVER_PUBLIC:-1}"
)

if [[ "${CROSSPLAY:-1}" == "1" ]]; then
  args+=(-crossplay)
fi

if [[ -n "${RESOURCE_PRESET:-}" ]]; then
  args+=(-modifier Resources "$RESOURCE_PRESET")
fi

printf 'Starting %s on port %s with world %s (crossplay: %s, public: %s, resources: %s)\n' \
  "$SERVER_NAME" "$SERVER_PORT" "$WORLD_NAME" "${CROSSPLAY:-1}" \
  "${SERVER_PUBLIC:-1}" "${RESOURCE_PRESET:-standard}"

exec "$SERVER_DIR/valheim_server.x86_64" "${args[@]}"
