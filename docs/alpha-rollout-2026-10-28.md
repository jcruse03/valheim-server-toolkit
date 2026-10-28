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

## Execution status

Research completed; implementation and rollout pending.
