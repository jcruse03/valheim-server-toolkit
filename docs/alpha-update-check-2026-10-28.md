# Alpha Valheim update check — 2026-10-28 (corrected)

The previous report's no-update conclusion was incorrect. It confused the
installed build with the current public Steam build, and looked for instance
locks in the wrong location. Its recommendation is superseded by the authorized
Kujamaton-first server-health-gated rollout in
[alpha-rollout-2026-10-28.md](alpha-rollout-2026-10-28.md).

## Fresh evidence

- Directly executed on alpha:
  `ssh alpha steamcmd +login anonymous +app_info_update 1 +app_info_print 896660 +quit`
  returned public build **26266951**, previous stable **25909431**.
- All five initial installed manifests were **25909431**: an update was needed.
- Actual locks `/home/jim/games/{valheim,valheim2,valheim3,valheim4,valheim5}/valheim-mods.lock`
  all existed and pinned BepInEx **5.4.2350**, own Continued fork **1.3.1**.
- Fresh Thunderstore metadata confirms BepInEx **5.4.2351**, Continued **1.3.2**,
  optional client-only PortalPass **0.1.2**.
- Freshly downloaded Continued 1.3.2 DLL SHA256
  `6db2033a07f860c3f116d5bc57b520a938e0776569a8880da47c7dcafb1886da`
  matches all five original live DLLs. Runtime plugin still reports 1.3.1.
- Framework compatibility investigation found logging changes and Linux Doorstop
  4.5.0 (glibc >=2.7; alpha has 2.44). Toolkit config-preservation regression test,
  syntax and shellcheck all pass. Pins and fix pushed as `7e744e2` before game updates.
- Kujamaton canary updated successfully to build **26266951**, game **l-1.0.21 /
  network 41**, BepInEx pack **5.4.2351**. One Continued plugin loaded, zero failed;
  existing world loaded and PlayFab session became active. Existing BepInEx.cfg
  preserved byte-for-byte. Remaining serial rollout/results are recorded in the
  linked artifact.

Headless graphics/audio warnings are not a clean error-free log; no fatal or
plugin-loading failure was observed in the canary. Client join, gameplay,
PortalPass handshake and portal traversal have not been performed. Players need
the matching updated game; Continued 1.3.2 is the same plugin binary, and
PortalPass 0.1.2 remains client-only. Server success does not prove client travel.
