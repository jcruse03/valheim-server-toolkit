# Alpha rollout — 2026-10-28

## Brief and authorized plan

Goal: update five alpha servers, mods first, Kujamaton canary then serial
Satropolis, Randleton, Lumiland, Everville. Preserve worlds, configs, secrets,
and the Continued fork. Gate on service/process stability, current public build,
framework/plugin loading, world load and online PlayFab registration; no client
play or portal traversal is claimed.

1. Query Steam live and inspect actual instance locks and packages.
2. Review/test minimal config-preserving maintenance change and new package pins;
   push before any production game update.
3. Stop only canary, create and independently verify working backup, sync reviewed
   script/lock, update through maintenance script, start and verify health.
4. Only after canary success repeat serially for other four.
5. Record evidence and correct inaccurate prior report.

Rollback: stop failed canary, restore verified application-state backup using
maintenance script. Backups do not contain game binaries; Steam currently exposes
old build 25909431 on default_old if game rollback is necessary. Do not touch
remaining services on canary failure. No vanilla fallback.

## Verified research

- Live `ssh alpha steamcmd +login anonymous +app_info_update 1 +app_info_print 896660 +quit`
  completed successfully: public **26266951**, previous stable/default_old
  **25909431**. SteamCMD self-updated during this query (client version 1792617903).
- All five installed app manifests are **25909431**. All services active/running,
  NRestarts=0 before maintenance.
- Correct locks are `/home/jim/games/<instance>/valheim-mods.lock`; all five pin
  BepInEx 5.4.2350 and jcruse03/Cross_Server_Portals_Continued 1.3.1.
- Candidate BepInEx 5.4.2351 archive SHA256:
  `bce631497976a93977ceb08e166712e6c31d15244956f89f17df092a9b62e29f`.
- Candidate Continued 1.3.2 archive SHA256:
  `a9f14f6a76ee6ebd2ba75a764b1af7af5ce6e1d24cde40703b9b381d20d13e91`.
  Extracted DLL SHA256 `6db2033a07f860c3f116d5bc57b520a938e0776569a8880da47c7dcafb1886da`
  matches all five live DLLs exactly. This is a packaging update, not new plugin code.
- BepInEx changelog: improved plugin/chainloader logging and stock UnityDoorstop
  4.5.0 Linux library (glibc >=2.7). Alpha glibc is 2.44. Continued declares
  BepInEx >=5.4.2350, Valheim 1.0/network39 compatibility. Runtime canary still required.
- Existing installer overlays packaged BepInEx.cfg, whose hash differs from live
  configuration. Must preserve existing config before using installer.

Sources retrieved directly:
- https://thunderstore.io/c/valheim/p/denikson/BepInExPack_Valheim/changelog/
- https://thunderstore.io/package/download/denikson/BepInExPack_Valheim/5.4.2351/
- https://thunderstore.io/c/valheim/p/jcruse03/Cross_Server_Portals_Continued/
- https://thunderstore.io/package/download/jcruse03/Cross_Server_Portals_Continued/1.3.2/
- https://thunderstore.io/c/valheim/p/jcruse03/PortalPass/ (client-only; no server install)

## Execution status — complete

All five updates completed in the authorized serial order, all services
active/running with NRestarts=0 and the PIDs below. All five manifests verified
at build 26266951, all five locks match canonical SHA256
`09e802b0da8508d5d1825996b7e22a86d5760959fdc402815a6948e575cc2293`.
Final scan found no Exception/Fatal entries; all five actual runtime logs confirm
one plugin loaded and active PlayFab sessions. No command denied or failed in
this execution; all operations targeted alpha explicitly. SteamCMD self-update,
remote toolkit pull, per-instance script/lock/game/mod updates and ordinary
server-generated saves/logs are the remote mutations. No systemd configuration
or credentials were edited.

Toolkit fix and pins committed/pushed as `7e744e2` before any game updates.
`mise run check` passed syntax, backup/restore + config-preservation tests and
shellcheck; `git diff --check` passed. Remote clean toolkit fast-forwarded.
Installer now preserves administrator BepInEx configuration when overlaying
package defaults. Canary BepInEx.cfg SHA256 remained
`e05e67031fb33decebdd9f560e1ce011582ef1bbc9a67c503a105561e4e6a376`.

Server-side canary passed before Satropolis was stopped. All observed logs have
headless graphics/video/intro warnings/errors (AsyncResourceUpload, shaders,
intro cinematic), not fatal failures. No plugin exceptions observed. Canary
remained same PID with zero restarts through the serial rollout and emitted
its 10-minute connection heartbeat. New runtime reports **l-1.0.21/network 41**,
not the network39 named in older Continued documentation. This is server-side
compatibility evidence only, not a client gameplay certification.

### Per-server evidence (alpha local EDT timestamps)

All start from build **25909431**, BepInEx pack **5.4.2350**, Continued package
**1.3.1**. Target is **26266951**, **5.4.2351**, **1.3.2** respectively. Plugin
DLL is unchanged and reports **1.3.1**. Each has one loaded, zero skipped/failed
plugins and loads the named existing world.

| Service / world | World load complete | PlayFab session active | PID |
| --- | --- | --- | --- |
| valheim / Kujamaton | 10:31:37 | 10:31:46 | 3576670 |
| valheim2 / Satropolis | 10:35:35 | 10:35:44 | 3583501 |
| valheim3 / Randleton | 10:39:48 | 10:39:56 | 3590707 |
| valheim4 / Lumiland | 10:43:57 | 10:44:06 | 3597964 |
| valheim5 / Everville | 10:48:01 | 10:48:11 | 3604948 |

### Backups

Archives live under `/home/jim/games/valheim-backups/<instance>/`. Each stopped
server first ran `backup-working`; its SHA256 sidecar was independently checked
before changing its lock/script or running update. Automatic pre-update backups
also created and independently checked. All archive creation includes `tar --list`
validation. Working archives retain the original lock/script/mod stack;
pre-update archives contain new pins/script but old installed game/mod state.
The game binaries themselves are not in these application-state backups.

| Instance | Verified original-state working backup | Automatic pre-update backup |
| --- | --- | --- |
| valheim | valheim-20261028-102948-working.tar.gz | valheim-20261028-103102-pre-update.tar.gz |
| valheim2 | valheim2-20261028-103349-working.tar.gz | valheim2-20261028-103434-pre-update.tar.gz |
| valheim3 | valheim3-20261028-103656-working.tar.gz | valheim3-20261028-103806-pre-update.tar.gz |
| valheim4 | valheim4-20261028-104117-working.tar.gz | valheim4-20261028-104250-pre-update.tar.gz |
| valheim5 | valheim5-20261028-104514-working.tar.gz | valheim5-20261028-104646-pre-update.tar.gz |

### Client implications and limitations

Update client Valheim to match l-1.0.21/network41. Current server stack uses
BepInEx 5.4.2351 and Continued package 1.3.2; Continued's DLL is unchanged.
PortalPass remains 0.1.2 and client-only, verified from
https://thunderstore.io/api/experimental/package/jcruse03/PortalPass/ .
Latest framework and Continued versions confirmed from the corresponding
`/api/experimental/package/denikson/BepInExPack_Valheim/` and
`/api/experimental/package/jcruse03/Cross_Server_Portals_Continued/` endpoints.
No new mod release or client profile was published; no client direct join,
PortalPass handshake, or portal traversal was performed. No restore was needed.
No credentials, worlds, backups, or binaries were committed.
