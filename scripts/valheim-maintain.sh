#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

SERVER_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
INSTANCE="$(basename -- "$SERVER_DIR")"
SERVICE_NAME="${VALHEIM_SERVICE_NAME:-${INSTANCE}.service}"
BACKUP_ROOT="${VALHEIM_BACKUP_ROOT:-/home/jim/games/valheim-backups}"
LOCK_FILE="$SERVER_DIR/.valheim-maintain.lock"
MOD_LOCK_FILE="$SERVER_DIR/valheim-mods.lock"

MANAGED_PATHS=(
  saves
  valheim-serve.sh
  valheim-maintain.sh
  valheim.env
  valheim-mods.lock
  BepInEx
  .valheim-mod-versions
  doorstop_config.ini
  doorstop_libs
  .doorstop_version
  start_game_bepinex.sh
  start_server_bepinex.sh
  winhttp.dll
  steam_appid.txt
)

log() {
  printf '[%s] %s\n' "$(date --iso-8601=seconds)" "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./valheim-maintain.sh COMMAND [ARGUMENT]

Commands:
  backup                  Create an integrity-checked application-state backup
  backup-working          Create a backup and mark it as the latest known-working backup
  list-backups            List backups and show the latest-working pointer
  install                 Back up, then install/update the pinned mod stack
  update                  Back up, update Valheim with SteamCMD, then install pinned mods
  verify                  Verify the expected server, framework, plugin, and config files
  restore latest          Restore the explicitly marked latest known-working backup
  restore FILE            Restore a specific backup basename or absolute archive path

The corresponding systemd service must be stopped for backup, install, update,
and restore. The script never starts or stops a service automatically.
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_stopped() {
  if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    die "$SERVICE_NAME is active. Stop it before running maintenance."
  fi
}

acquire_lock() {
  require_command flock
  exec 9>"$LOCK_FILE"
  flock -n 9 || die "Another maintenance process holds $LOCK_FILE"
}

load_mod_lock() {
  [[ -r "$MOD_LOCK_FILE" ]] || die "Missing mod lock file: $MOD_LOCK_FILE"
  # This file is supplied by this project and contains only pinned package data.
  # shellcheck disable=SC1090
  source "$MOD_LOCK_FILE"
  : "${BEPINEX_VERSION:?Missing BEPINEX_VERSION in $MOD_LOCK_FILE}"
  : "${BEPINEX_SHA256:?Missing BEPINEX_SHA256 in $MOD_LOCK_FILE}"
  : "${PORTAL_NAMESPACE:?Missing PORTAL_NAMESPACE in $MOD_LOCK_FILE}"
  : "${PORTAL_PACKAGE:?Missing PORTAL_PACKAGE in $MOD_LOCK_FILE}"
  : "${PORTAL_VERSION:?Missing PORTAL_VERSION in $MOD_LOCK_FILE}"
  : "${PORTAL_SHA256:?Missing PORTAL_SHA256 in $MOD_LOCK_FILE}"
}

download_and_verify() {
  local url="$1"
  local output="$2"
  local expected_sha="$3"
  local actual_sha

  curl --fail --location --retry 3 --retry-delay 2 --output "$output" "$url"
  actual_sha="$(sha256sum "$output" | awk '{print $1}')"
  [[ "$actual_sha" == "$expected_sha" ]] || die "Checksum mismatch for $output"
  unzip -tq "$output" >/dev/null || die "Invalid zip archive: $output"
}

write_archive_checksum() {
  local archive="$1"
  local archive_dir archive_name
  archive_dir="$(dirname -- "$archive")"
  archive_name="$(basename -- "$archive")"
  (
    cd "$archive_dir"
    sha256sum "$archive_name" >"$archive_name.sha256"
  )
  chmod 600 "$archive.sha256"
}

backup_server() {
  local label="${1:-manual}"
  local mark_working="${2:-0}"
  local destination_dir="$BACKUP_ROOT/$INSTANCE"
  local timestamp archive partial metadata
  local -a paths=()
  local path

  [[ "$label" =~ ^[a-z0-9-]+$ ]] || die "Invalid backup label: $label"
  timestamp="$(date '+%Y%m%d-%H%M%S')"
  archive="$destination_dir/${INSTANCE}-${timestamp}-${label}.tar.gz"
  partial="$archive.partial"
  metadata="$SERVER_DIR/.valheim-backup-metadata"
  mkdir -p "$destination_dir"

  {
    printf 'instance=%s\n' "$INSTANCE"
    printf 'hostname=%s\n' "$(hostname)"
    printf 'created=%s\n' "$(date --iso-8601=seconds)"
    printf 'label=%s\n' "$label"
    printf 'server_dir=%s\n' "$SERVER_DIR"
    printf 'service=%s\n' "$SERVICE_NAME"
    printf 'bepinex_version=%s\n' "$BEPINEX_VERSION"
    printf 'cross_server_portals_version=%s\n' "$PORTAL_VERSION"
    if [[ -f "$SERVER_DIR/steamapps/appmanifest_896660.acf" ]]; then
      printf '\n[steam-manifest]\n'
      sed -n '1,180p' "$SERVER_DIR/steamapps/appmanifest_896660.acf"
    fi
    if systemctl cat "$SERVICE_NAME" >/dev/null 2>&1; then
      printf '\n[systemd-unit]\n'
      systemctl cat "$SERVICE_NAME"
    fi
  } >"$metadata"

  trap 'rm -f -- "$metadata" "$partial"' EXIT
  paths+=(.valheim-backup-metadata)
  for path in "${MANAGED_PATHS[@]}"; do
    [[ -e "$SERVER_DIR/$path" || -L "$SERVER_DIR/$path" ]] && paths+=("$path")
  done

  log "Creating application-state backup $archive"
  tar --create --gzip --file "$partial" --directory "$SERVER_DIR" "${paths[@]}"
  tar --list --gzip --file "$partial" >/dev/null
  mv -- "$partial" "$archive"
  chmod 600 "$archive"
  write_archive_checksum "$archive"

  if [[ "$mark_working" == "1" ]]; then
    printf '%s\n' "$(basename -- "$archive")" >"$destination_dir/latest-working.tmp"
    mv -- "$destination_dir/latest-working.tmp" "$destination_dir/latest-working"
    chmod 600 "$destination_dir/latest-working"
    log "Marked as latest known-working backup"
  fi

  rm -f -- "$metadata"
  trap - EXIT
  log "Backup complete: $archive"
}

validate_archive_path() {
  local archive="$1"
  local archive_dir archive_name entry normalized top_level
  archive_dir="$(dirname -- "$archive")"
  archive_name="$(basename -- "$archive")"

  [[ -f "$archive" ]] || die "Backup not found: $archive"
  [[ -f "$archive.sha256" ]] || die "Backup checksum not found: $archive.sha256"
  (
    cd "$archive_dir"
    sha256sum --check --status "$archive_name.sha256"
  ) || die "Backup checksum failed: $archive"
  tar --list --gzip --file "$archive" >/dev/null || die "Unreadable backup archive: $archive"

  while IFS= read -r entry; do
    normalized="${entry#./}"
    [[ -n "$normalized" ]] || continue
    [[ "$normalized" != /* ]] || die "Unsafe absolute path in backup: $entry"
    [[ "$normalized" != '..' && "$normalized" != ../* && "$normalized" != */../* ]] || \
      die "Unsafe parent path in backup: $entry"
    top_level="${normalized%%/*}"
    case "$top_level" in
      saves|valheim-serve.sh|valheim-maintain.sh|valheim.env|valheim-mods.lock|BepInEx|\
      .valheim-mod-versions|doorstop_config.ini|doorstop_libs|.doorstop_version|\
      start_game_bepinex.sh|start_server_bepinex.sh|winhttp.dll|steam_appid.txt|\
      .valheim-backup-metadata)
        ;;
      *)
        die "Unexpected top-level path in backup: $top_level"
        ;;
    esac
  done < <(tar --list --gzip --file "$archive")
}

resolve_restore_archive() {
  local requested="$1"
  local destination_dir="$BACKUP_ROOT/$INSTANCE"
  local pointer archive

  if [[ "$requested" == "latest" ]]; then
    pointer="$destination_dir/latest-working"
    [[ -r "$pointer" ]] || die "No latest known-working backup is marked for $INSTANCE"
    requested="$(sed -n '1p' "$pointer")"
    [[ "$requested" == "$(basename -- "$requested")" ]] || die "Invalid latest-working pointer"
  fi

  if [[ "$requested" == */* ]]; then
    archive="$(realpath -e -- "$requested")"
  else
    archive="$(realpath -e -- "$destination_dir/$requested")"
  fi
  printf '%s\n' "$archive"
}

install_mod_stack() {
  local temp_dir bepinex_zip portal_zip bepinex_source
  local bepinex_url portal_url

  require_command curl
  require_command sha256sum
  require_command unzip

  bepinex_url="https://thunderstore.io/package/download/denikson/BepInExPack_Valheim/${BEPINEX_VERSION}/"
  portal_url="https://thunderstore.io/package/download/${PORTAL_NAMESPACE}/${PORTAL_PACKAGE}/${PORTAL_VERSION}/"
  temp_dir="$(mktemp -d -t "${INSTANCE}-mods.XXXXXXXX")"
  trap 'rm -rf -- "$temp_dir"' EXIT
  bepinex_zip="$temp_dir/BepInExPack_Valheim-${BEPINEX_VERSION}.zip"
  portal_zip="$temp_dir/${PORTAL_PACKAGE}-${PORTAL_VERSION}.zip"

  log "Downloading pinned BepInExPack $BEPINEX_VERSION"
  download_and_verify "$bepinex_url" "$bepinex_zip" "$BEPINEX_SHA256"
  unzip -q "$bepinex_zip" -d "$temp_dir/bepinex"
  bepinex_source="$temp_dir/bepinex/BepInExPack_Valheim"
  [[ -d "$bepinex_source/BepInEx/core" ]] || die "Unexpected BepInEx archive layout"

  log "Installing BepInExPack $BEPINEX_VERSION"
  cp -a "$bepinex_source/." "$SERVER_DIR/"
  chmod u+x "$SERVER_DIR/start_server_bepinex.sh" "$SERVER_DIR/start_game_bepinex.sh"

  log "Downloading pinned ${PORTAL_NAMESPACE}-${PORTAL_PACKAGE} $PORTAL_VERSION"
  download_and_verify "$portal_url" "$portal_zip" "$PORTAL_SHA256"
  unzip -q "$portal_zip" -d "$temp_dir/portal"
  [[ -f "$temp_dir/portal/ValheimCrossServerPortals.dll" ]] || die "Unexpected portal archive layout"

  mkdir -p "$SERVER_DIR/BepInEx/plugins"
  install -m 0644 "$temp_dir/portal/ValheimCrossServerPortals.dll" \
    "$SERVER_DIR/BepInEx/plugins/ValheimCrossServerPortals.dll"

  {
    printf 'BepInExPack_Valheim=%s\n' "$BEPINEX_VERSION"
    printf 'BepInExPack_Valheim_archive_sha256=%s\n' "$BEPINEX_SHA256"
    printf 'Cross_Server_Portals=%s\n' "$PORTAL_VERSION"
    printf 'Cross_Server_Portals_namespace=%s\n' "$PORTAL_NAMESPACE"
    printf 'Cross_Server_Portals_package=%s\n' "$PORTAL_PACKAGE"
    printf 'Cross_Server_Portals_archive_sha256=%s\n' "$PORTAL_SHA256"
    printf 'installed=%s\n' "$(date --iso-8601=seconds)"
  } >"$SERVER_DIR/.valheim-mod-versions.tmp"
  mv -- "$SERVER_DIR/.valheim-mod-versions.tmp" "$SERVER_DIR/.valheim-mod-versions"
  chmod 600 "$SERVER_DIR/.valheim-mod-versions"

  trap - EXIT
  rm -rf -- "$temp_dir"
  log "Pinned mod stack installed"
}

update_game() {
  require_command steamcmd
  log "Updating Valheim Dedicated Server with SteamCMD"
  steamcmd \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir "$SERVER_DIR" \
    +login anonymous \
    +app_update 896660 validate \
    +quit
}

verify_installation() {
  local failed=0
  local item
  local -a required=(
    "$SERVER_DIR/valheim_server.x86_64"
    "$SERVER_DIR/valheim-serve.sh"
    "$SERVER_DIR/valheim-maintain.sh"
    "$SERVER_DIR/valheim.env"
    "$SERVER_DIR/valheim-mods.lock"
    "$SERVER_DIR/BepInEx/core/BepInEx.Preloader.dll"
    "$SERVER_DIR/doorstop_libs/libdoorstop_x64.so"
    "$SERVER_DIR/BepInEx/plugins/ValheimCrossServerPortals.dll"
    "$SERVER_DIR/.valheim-mod-versions"
    "$SERVER_DIR/saves"
  )

  for item in "${required[@]}"; do
    if [[ ! -e "$item" ]]; then
      printf 'MISSING: %s\n' "$item" >&2
      failed=1
    fi
  done

  bash -n "$SERVER_DIR/valheim-serve.sh" || failed=1
  bash -n "$SERVER_DIR/valheim-maintain.sh" || failed=1
  if [[ -f "$SERVER_DIR/valheim.env" ]]; then
    [[ "$(stat -c '%a' "$SERVER_DIR/valheim.env")" == "600" ]] || {
      printf 'UNSAFE MODE: valheim.env must be 600\n' >&2
      failed=1
    }
  fi

  if [[ -f "$SERVER_DIR/.valheim-mod-versions" ]]; then
    printf '\nInstalled mod manifest:\n'
    sed -n '1,80p' "$SERVER_DIR/.valheim-mod-versions"
  fi

  (( failed == 0 )) || die "Verification failed"
  log "Verification passed"
}

list_backups() {
  local destination_dir="$BACKUP_ROOT/$INSTANCE"
  local pointer="(none)"
  [[ -d "$destination_dir" ]] || die "No backup directory exists for $INSTANCE"
  [[ -r "$destination_dir/latest-working" ]] && pointer="$(sed -n '1p' "$destination_dir/latest-working")"
  printf 'Latest known-working: %s\n\n' "$pointer"
  find "$destination_dir" -maxdepth 1 -type f -name '*.tar.gz' \
    -printf '%TY-%Tm-%Td %TH:%TM:%TS %f %s bytes\n' | sort
}

restore_backup() {
  local requested="$1"
  local archive stage rollback path link_target
  local restore_started=0
  local restore_committed=0

  archive="$(resolve_restore_archive "$requested")"
  validate_archive_path "$archive"
  log "Validated restore source: $archive"
  backup_server pre-restore 0

  stage="$(mktemp -d -t "${INSTANCE}-restore-stage.XXXXXXXX")"
  rollback="$(mktemp -d "$SERVER_DIR/.restore-rollback.XXXXXXXX")"

  cleanup_restore() {
    if [[ "$restore_started" == "1" && "$restore_committed" == "0" ]]; then
      log "Restore failed; rolling back the pre-restore state"
      for path in "${MANAGED_PATHS[@]}"; do
        rm -rf -- "${SERVER_DIR:?}/$path"
        if [[ -e "$rollback/$path" || -L "$rollback/$path" ]]; then
          mv -- "$rollback/$path" "$SERVER_DIR/$path"
        fi
      done
    fi
    rm -rf -- "$stage" "$rollback"
  }
  trap cleanup_restore EXIT

  tar --extract --gzip --file "$archive" --directory "$stage"
  while IFS= read -r -d '' path; do
    link_target="$(realpath -m -- "$path")"
    [[ "$link_target" == "$stage"/* ]] || die "Unsafe symlink in backup: $path"
  done < <(find "$stage" -type l -print0)

  restore_started=1
  for path in "${MANAGED_PATHS[@]}"; do
    if [[ -e "$SERVER_DIR/$path" || -L "$SERVER_DIR/$path" ]]; then
      mv -- "$SERVER_DIR/$path" "$rollback/$path"
    fi
  done
  for path in "${MANAGED_PATHS[@]}"; do
    if [[ -e "$stage/$path" || -L "$stage/$path" ]]; then
      mv -- "$stage/$path" "$SERVER_DIR/$path"
    fi
  done

  verify_installation
  restore_committed=1
  trap - EXIT
  rm -rf -- "$stage" "$rollback"
  log "Restore complete: $archive"
}

main() {
  local command_name="${1:-}"

  case "$command_name" in
    -h|--help|help|'')
      usage
      exit 0
      ;;
    backup|backup-working|install|update|verify|list-backups|restore)
      ;;
    *)
      usage >&2
      die "Unknown command: $command_name"
      ;;
  esac

  acquire_lock
  load_mod_lock

  case "$command_name" in
    backup|backup-working|install|update|restore)
      require_stopped
      ;;
  esac

  case "$command_name" in
    backup)
      backup_server manual 0
      ;;
    backup-working)
      verify_installation
      backup_server working 1
      ;;
    list-backups)
      list_backups
      ;;
    install)
      backup_server pre-install 0
      install_mod_stack
      verify_installation
      ;;
    update)
      backup_server pre-update 0
      update_game
      install_mod_stack
      verify_installation
      ;;
    verify)
      verify_installation
      ;;
    restore)
      [[ -n "${2:-}" ]] || die "restore requires 'latest' or a backup filename/path"
      [[ -z "${3:-}" ]] || die "restore accepts exactly one backup argument"
      restore_backup "$2"
      ;;
  esac
}

main "$@"
