# Alpha deployment record

Last verified: **2026-09-08**

This file records non-secret deployment state for the current `alpha` host. Passwords, join codes, public IP addresses, saves, BepInEx binaries, and backup archives are intentionally excluded from Git.

## Instances

| Instance | Display name | Base port | World | Service | Runtime state after setup |
| --- | --- | ---: | --- | --- | --- |
| `/home/jim/games/valheim` | Kujamaton | 2456 | Kujamaton | `valheim.service` | staged; inactive and disabled at boot |
| `/home/jim/games/valheim2` | Satropolis | 2459 | Satropolis | `valheim2.service` | hub; inactive and disabled at boot |
| `/home/jim/games/valheim3` | Randleton | 2462 | Randleton | `valheim3.service` | staged; inactive and disabled at boot |
| `/home/jim/games/valheim4` | Lumiland | 2465 | Lumiland | `valheim4.service` | staged; inactive and disabled at boot |
| `/home/jim/games/valheim5` | Everville | 2468 | Everville | `valheim5.service` | staged; inactive and disabled at boot |

All instances use:

- Valheim Dedicated Server build `21981590` (`l-0.221.12`, network version 36)
- BepInExPack Valheim `5.4.2333`
- Cross Server Portals `1.2.0`
- `SERVER_PUBLIC=1`
- `CROSSPLAY=1`
- `RESOURCE_PRESET=muchmore` (the broad built-in 2× resource modifier)
- `MODS_ENABLED=1` under normal operation; set to `0` for a clean-game fallback
- backups under `/home/jim/games/valheim-backups/<instance>/`

The deployed runtime scripts and mod lockfiles are SHA-256-compared to the host checkout during migration and verification.

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
