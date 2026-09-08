# Valheim 1.0 release-day runbook

This runbook is for the private five-instance deployment on `alpha`. It assumes:

- `valheim2` / **Satropolis** is the shared hub and first canary;
- all five services begin stopped and disabled at boot;
- the old save trees are already preserved in verified, checksummed archives;
- the public IP is static, so dynamic DNS is not an open task;
- achievements and the 1.0 cheated-state markers are intentionally out of scope;
- no new production world has been generated before Valheim 1.0.

Do not update every instance at once. Prove the complete server/client stack on Satropolis first.

## Current instance map

| Instance | Server and world | Base port | UDP range |
| --- | --- | ---: | ---: |
| `valheim` | Kujamaton | 2456 | 2456-2457 |
| `valheim2` | Satropolis | 2459 | 2459-2460 |
| `valheim3` | Randleton | 2462 | 2462-2463 |
| `valheim4` | Lumiland | 2465 | 2465-2466 |
| `valheim5` | Everville | 2468 | 2468-2469 |

The public address and password remain private and are distributed separately.

## Phase 1: establish the release and compatibility gates

- [ ] Confirm Steam has delivered the final Valheim 1.0 build, not a preload or transitional depot.
- [ ] Read Iron Gate's release notes for dedicated-server flags, world generation, networking, and save changes.
- [ ] Confirm a BepInExPack release explicitly supports the installed 1.0 build.
- [ ] Confirm Cross Server Portals loads against that BepInEx/game combination.
- [ ] Record exact package versions and SHA-256 checksums in `templates/valheim-mods.lock`.
- [ ] Run `mise run check`, commit, and push the reviewed toolkit change.
- [ ] Pull the reviewed commit into `/home/jim/games/valheim-server-toolkit` on `alpha`.

If either mod has no verified 1.0 path, use the vanilla fallback below rather than experimenting on the new hub save.

## Phase 2A: modded Satropolis canary

Deploy the reviewed scripts and lockfile, then update the stopped instance:

```bash
cd /home/jim/games/valheim-server-toolkit
./scripts/install-instance.sh /home/jim/games/valheim2

cd /home/jim/games/valheim2
./valheim-maintain.sh update
./valheim-maintain.sh verify
sudo systemctl start valheim2.service
```

The first successful start creates the new `Satropolis` world. Check:

```bash
systemctl --no-pager --full status valheim2.service
journalctl -u valheim2.service -n 250 --no-pager
grep -E 'BepInEx|Chainloader|plugin|Error|Exception' \
  /home/jim/games/valheim2/BepInEx/LogOutput.log
```

Required server-side evidence:

- [ ] The expected 1.0 build is running.
- [ ] The world created as `Satropolis` under the configured save directory.
- [ ] BepInEx loaded without a fatal exception.
- [ ] Exactly the intended Cross Server Portals plugin loaded.
- [ ] Public PlayFab registration completed.
- [ ] The 2x `Resources=muchmore` modifier was accepted.
- [ ] No unexpected old plugin or configuration survived migration.

## Phase 2B: vanilla fallback

If the mod stack is not compatible, leave its files installed but disable loading:

```bash
sudo systemctl stop valheim2.service
$EDITOR /home/jim/games/valheim2/valheim.env
```

Set:

```bash
MODS_ENABLED="0"
```

Then update and start Satropolis:

```bash
cd /home/jim/games/valheim2
./valheim-maintain.sh update
./valheim-maintain.sh verify
sudo systemctl start valheim2.service
```

Players must launch unmodded Valheim while this fallback is active. Cross-server portals will not function. Do not publish a replacement r2modman code until a modded canary passes.

## Phase 3: administrator and client validation

On the first administrator join:

- [ ] Confirm the F2 panel or server log shows the same exact case-sensitive platform ID already present in `saves/adminlist.txt`.
- [ ] Confirm administrator-only portal renaming is recognized.
- [ ] Confirm normal inventory and character persistence.
- [ ] Disconnect, force a clean server save/restart, reconnect, and confirm persistence again.
- [ ] Test death and respawn.

For a modded canary, prepare the canonical r2modman profile:

- [ ] Use the exact BepInEx and Cross Server Portals versions pinned on the server.
- [ ] Test using **Start modded** on a clean client profile.
- [ ] Check client and server BepInEx logs for new errors.
- [ ] When a second server is available, test a cross-server portal in both directions and repeat after restarting both servers.
- [ ] Export the tested profile as a new r2modman code if any package or configuration changed.
- [ ] Replace the code in the README, retain a file export offline, commit, and push.
- [ ] Only then tell players to import the new code and start modded.

The existing profile code can remain only if its exact package versions and configuration pass 1.0 unchanged. Exporting again is the clearer default whenever the canonical profile changes.

## Phase 4: establish the new restore point

There is deliberately no `latest-working` pointer for the untested new world. Create it only after the full canary passes:

```bash
sudo systemctl stop valheim2.service
cd /home/jim/games/valheim2
./valheim-maintain.sh backup-working
sudo systemctl start valheim2.service
```

Then optionally enable only the permanent hub at boot:

```bash
sudo systemctl enable valheim2.service
```

Confirm the known-working pointer and service state:

```bash
./valheim-maintain.sh list-backups
systemctl is-active valheim2.service
systemctl is-enabled valheim2.service
```

## Phase 5: add personal worlds one at a time

Repeat the canary workflow separately for Kujamaton, Randleton, Lumiland, and Everville. For each instance:

1. deploy the reviewed toolkit and lockfile;
2. run `update` and `verify` while stopped;
3. start it to generate its correctly named world;
4. perform direct join, save/restart/rejoin, and log checks;
5. create and test both sides of its Satropolis portal;
6. stop it and create `backup-working`;
7. enable it at boot only if that owner needs continuous availability.

Never treat one server's successful startup as proof that every portal route and save is healthy.

## Rollback

After a new known-working snapshot exists:

```bash
sudo systemctl stop valheim2.service
cd /home/jim/games/valheim2
./valheim-maintain.sh restore latest
sudo systemctl start valheim2.service
```

Before that point, `latest-working` is intentionally absent. The pre-migration pointers for the former `valheim2` and `valheim3` deployments were retained as `latest-working.pre-migration`, and the separate legacy save archives remain available for deliberate recovery.

## Remaining operational decision

The maintenance commands are installed, but recurring backups and retention are not scheduled. After the 1.0 canary is stable, decide:

- backup frequency;
- how many daily and weekly archives to retain;
- whether stopped-server snapshots are acceptable or a save-aware online backup is required;
- whether update checks should notify only or be allowed to mutate a stopped server.

Prefer an automated backup timer plus **notification-only** update checks. Game and mod updates should continue to require a deliberate canary rollout.
