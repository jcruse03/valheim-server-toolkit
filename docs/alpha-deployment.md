# Alpha deployment record

Last verified: **2026-09-08**

This file records non-secret deployment state for the current `alpha` host. Passwords, join codes, public IP addresses, saves, BepInEx binaries, and backup archives are intentionally excluded from Git.

## Instances

| Instance | Display name | Base port | World | Service | Runtime state after setup |
| --- | --- | ---: | --- | --- | --- |
| `/home/jim/games/valheim2` | Origin | 2459 | Dedicated | `valheim2.service` | active; disabled at boot |
| `/home/jim/games/valheim3` | DanHammer | 2462 | Dedicated | `valheim3.service` | active; disabled at boot |

Both instances use:

- Valheim Dedicated Server build `21981590` (`l-0.221.12`, network version 36)
- BepInExPack Valheim `5.4.2333`
- Cross Server Portals `1.2.0`
- `SERVER_PUBLIC=1`
- `CROSSPLAY=1`
- `RESOURCE_PRESET=muchmore` (the broad built-in 2× resource modifier)
- backups under `/home/jim/games/valheim-backups/<instance>/`

The two deployed runtime scripts and mod lockfiles were SHA-256-compared to commit `de8cb3a4835003f0e08f926f009c869c7133c47f` before this record was written.

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
