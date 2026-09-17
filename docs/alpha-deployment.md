# Alpha deployment record

Last verified: **2026-09-17**

## September 17 Kujamaton-only update

The sections below this update record preserve the historical September 9 deployment;
their inactive/staged descriptions are not current live state.

- Updated **only Kujamaton** from Steam build `25253791` to `25364309`,
  Valheim `l-1.0.14` (network version `40`).
- Stopped `valheim.service` gracefully before maintenance. Created and verified
  `valheim-20260917-094907-pre-update.tar.gz` under the instance backup directory.
  This is an application-state backup, not a complete old game-binary image;
  it was **not** marked known-working.
- Reinstalled checksum-pinned BepInEx `5.4.2350` and Cross Server Portals `1.3.1`.
  Static installation verification passed. The service restarted at 09:50 EDT;
  the plugin chainloader completed, 19,625 world ZDOs loaded, and the game server
  connected and registered its session.
- Startup contains Unity resource-upload/video/shader errors. No plugin exception
  was observed in the inspected startup log; gameplay is not yet validated.
- Cross Server Portals and PortalPass built and packaged successfully against the
  updated dedicated-server managed assemblies: 16 and 14 unit tests passed.
  Toolkit syntax, maintenance tests, and ShellCheck also passed.
- The published Thunderstore Cross Server Portals `1.3.2` package contains the
  same DLL as deployed `1.3.1` (SHA-256
  `6db2033a07f860c3f116d5bc57b520a938e0776569a8880da47c7dcafb1886da`).
  PortalPass remains published at `0.1.2`. No code change or new mod package was
  warranted by these checks.
- Satropolis, Randleton, Lumiland, and Everville remained active with unchanged
  September 11 service start timestamps. No maintenance was performed on them.
- **Rollout gate:** Jim must confirm client login and gameplay on Kujamaton before
  any other server is updated. Cross-server travel to older servers may fail due
  to game/network version differences; do not update them to bypass this gate.
  Client-side PortalPass behavior and full portal traversal remain unverified.

## Historical September 9 record

This file records non-secret deployment state for the current `alpha` host. Passwords, join codes, public IP addresses, saves, BepInEx binaries, and backup archives are intentionally excluded from Git.

## Instances

| Instance | Display name | Base port | World | Service | Runtime state after setup |
| --- | --- | ---: | --- | --- | --- |
| `/home/jim/games/valheim` | Kujamaton | 2456 | Kujamaton | `valheim.service` | 1.0 mod canary failed; inactive and disabled at boot |
| `/home/jim/games/valheim2` | Satropolis | 2459 | Satropolis | `valheim2.service` | 1.0 vanilla hub; active and disabled at boot |
| `/home/jim/games/valheim3` | Randleton | 2462 | Randleton | `valheim3.service` | staged; inactive and disabled at boot |
| `/home/jim/games/valheim4` | Lumiland | 2465 | Lumiland | `valheim4.service` | staged; inactive and disabled at boot |
| `/home/jim/games/valheim5` | Everville | 2468 | Everville | `valheim5.service` | staged; inactive and disabled at boot |

The current Satropolis deployment uses:

- Valheim Dedicated Server build `25185644` (`l-1.0.7`, network version 39)
- `SERVER_PUBLIC=1`
- `CROSSPLAY=1`
- `RESOURCE_PRESET=more` (the broad built-in 1.5× resource modifier)
- `MODS_ENABLED=0`
- backups under `/home/jim/games/valheim-backups/<instance>/`

Kujamaton has build `25185644`, BepInExPack `5.4.2350`, Cross Server
Portals `1.2.0`, and `RESOURCE_PRESET=more`. The framework loads, but the
portal plugin fails against Valheim 1.0 with a missing
`ZDOMan.GetPortals()` method, so the service is stopped. Randleton, Lumiland,
and Everville remain staged on the pre-1.0 stack and stopped.

The deployed runtime scripts and mod lockfiles are SHA-256-compared to the host checkout during migration and verification.

## Valheim 1.0 canary

Satropolis passed direct join, logout, graceful save, restart, rejoin,
PlayFab registration, and persistence checks in vanilla mode. A checksummed
post-validation snapshot is marked as its current `latest-working` backup.

The separate Kujamaton mod canary confirmed that BepInExPack `5.4.2350`
starts on Unity `6000.0.75f1`, but Cross Server Portals `1.2.0` throws:

```text
MissingMethodException: Method not found:
System.Collections.Generic.List<ZDO> ZDOMan.GetPortals()
```

Kujamaton was stopped after capturing the failure. Do not update the client
profile or enable mods on Satropolis until a compatible portal release passes
the complete server/client canary.

## Validation performed

1. Preserved each original 2023 save, launch script, and Steam manifest before modification.
2. Reconciled each old Steam install against the current public depot. Steam denied the retired 2023 depot manifest, so its `.acf` was moved aside after backup and SteamCMD performed a clean in-place update.
3. Installed checksum-pinned BepInEx and Cross Server Portals packages.
4. Started both instances simultaneously.
5. Confirmed unique port use, BepInEx chainloader startup, plugin load, ServerSync RPC registration, 2× resource modifier acceptance, PlayFab login, public lobby creation, and active join codes.
6. Stopped both services and created per-instance `backup-working` snapshots.
7. Restarted both services for client testing while retaining their previous disabled-at-boot policy.

Known-working pointers created during deployment:

```text
/home/jim/games/valheim-backups/valheim2/latest-working
/home/jim/games/valheim-backups/valheim3/latest-working
```

## Host checkout

The repository is cloned at:

```text
/home/jim/games/valheim-server-toolkit
```

Use that checkout as the source for future instance deployments. Pull and test repository updates before copying scripts into a server directory.

## Five-instance staging migration

On 2026-09-08, before the planned Valheim 1.0 cutover:

1. Both active pilot services were stopped cleanly.
2. Each instance's complete `saves/` tree was archived under its own backup directory with a SHA-256 sidecar. Every checksum and tar stream was verified before cleanup.
3. The old live world copies and legacy BepInEx trees were removed. The save archives were retained.
4. All five instance configs and systemd units were standardized to the table above, including public crossplay, 2× resources, and the mod-disable fallback.
5. The current dedicated-server build and checksum-pinned mod stack were installed in all five directories.
6. Static verification passed for all five instances, including exact script/lockfile parity with the host checkout and the administrator entry in each private save directory.
7. No new world was generated. All five services remain stopped and disabled until the intended 1.0 rollout.

The previous `latest-working` pointers for `valheim2` and `valheim3` were retained as `latest-working.pre-migration`. Create a new `backup-working` snapshot only after the new 1.0 world, client join, save/restart, and portal tests pass.
