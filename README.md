# Valheim multi-server toolkit

Reproducible client and Linux dedicated-server setup for a small trusted group using:

- Valheim's built-in crossplay backend
- BepInExPack for Valheim **5.4.2333**
- Cross Server Portals **1.2.0**
- Valheim's built-in **2× resource** world modifier
- independent worlds, saves, ports, systemd services, and backups per server

> **Version boundary:** Valheim mods are binary plugins without official Iron Gate support. Do not update Valheim, BepInEx, or a plugin independently on production servers. Test the complete pinned set first and keep a known-working backup.

## Player quick start

Cross Server Portals must be installed on every PC client that needs to travel through a cross-server portal. Console players can join these crossplay-enabled servers but cannot install BepInEx plugins, so they must change servers manually.

### 1. Install Valheim and run it once

Install Valheim through Steam, launch the unmodded game once, and close it. This lets Steam and the mod manager discover the game correctly.

### 2. Install r2modman from an official source

Use only one of r2modman's two official distribution locations:

- [r2modman on Thunderstore](https://thunderstore.io/c/valheim/p/ebkr/r2modman/)
- [official r2modman GitHub releases](https://github.com/ebkr/r2modmanPlus/releases/latest)

The current release verified while writing this guide was **3.2.19**. A newer official release is fine; the *mod versions* below must remain pinned.

#### Windows

1. Open the official release or click **Manual Download** on Thunderstore.
2. If using the Thunderstore ZIP, extract it.
3. Run `r2modman Setup X.X.X.exe` and follow the installer.
4. Start r2modman, select **Valheim**, and choose **Steam** when asked for the platform.

The portable build also works, but the setup executable is the least confusing option for most players.

#### Linux desktop

Flatpak is the upstream-recommended path:

```bash
flatpak remote-add --user --if-not-exists r2builds \
  https://r2builds.ebkr.dev/flatpak/r2modman.flatpakrepo
flatpak install --user r2builds io.github.ebkr.r2modman
flatpak run io.github.ebkr.r2modman
```

Alternatively, download the AppImage, `.deb`, `.rpm`, pacman package, or `tar.gz` from the [official releases page](https://github.com/ebkr/r2modmanPlus/releases/latest). For an AppImage:

```bash
chmod +x r2modman-*.AppImage
./r2modman-*.AppImage
```

Do not run the Windows `.exe` through Wine. If r2modman cannot launch native Valheim and offers the documented Proton workaround, create an empty `.forceproton` file in the Valheim game directory.

#### Steam Deck

Switch to Desktop Mode, install the Flatpak using the Linux commands above, select Valheim, and use r2modman's Steam Deck/Game Mode integration if desired. Flatpak is the supported route for Game Mode.

#### macOS

r2modman's upstream installation documentation currently publishes Windows and Linux paths, not a supported macOS client. This repository therefore does not claim a working macOS modded-client procedure. A Mac player can use normal Valheim/crossplay if their game edition supports it, but Cross Server Portals should be treated as unavailable until a tested BepInEx/r2modman macOS path exists.

#### Xbox and other console clients

No client-side BepInEx installation is possible. Players can join through Valheim crossplay and use ordinary in-world portals, but a Cross Server Portal cannot transfer their client. They must disconnect and select the other server normally.

### 3. Create the group profile

1. In r2modman, select **Valheim**.
2. Create a new profile named something recognizable, such as `Jim's Valheim Group`.
3. Open **Online** and install these exact packages:
   - `denikson-BepInExPack_Valheim` version **5.4.2333**
   - `lunarbin-Cross_Server_Portals` version **1.2.0**
4. Do not click **Update all** unless the server lockfile has been intentionally updated and tested.
5. Click **Start modded**.

The first launch creates BepInEx configuration files. No client config changes are required for the initial test.

### 4. Connect and test

Use Valheim's server browser, join code, or public IP plus base port. These servers use the crossplay backend, so a local or loopback IP such as `127.0.0.1` is not valid for joining; use the public address/join flow.

Test in this order:

1. Join each server directly.
2. Confirm normal inventory and character persistence.
3. Create paired portals with the syntax below.
4. Traverse in each direction.
5. Restart both servers and repeat.

### 5. Export the tested profile for the group

After the profile works:

1. Open r2modman **Settings** for the profile.
2. Open the **Profile** section.
3. Choose **Export profile as code** (or export as a file for an offline copy).
4. Publish the code in the group's private channel and record it in a release note.

Other players select Valheim in r2modman, choose **Import/Update**, paste the code, and launch that imported profile with **Start modded**. An export includes the mod list and profile configuration; it does not include characters or world saves.

## Cross-server portals

Name a portal using one of the plugin's formats:

```text
SourceTag|ServerOrPublicIP:Port|TargetTag
SourceTag|ServerOrPublicIP:Port
```

Example for two servers exposed at `valheim.example.net`:

```text
# Portal on Origin, whose destination server uses base port 2462
resources|valheim.example.net:2462|origin-return

# Portal on the resource server, returning to Origin on base port 2459
origin-return|valheim.example.net:2459|resources
```

`TargetTag` is optional. When present, the destination server searches for a portal whose source tag or full tag matches it. Cross-server travel currently ignores normal item teleport restrictions.

The server-generated plugin config is `BepInEx/config/lunarbin.games.valheim.cfg`. `RequireAdminToRename` defaults to `true`; only an administrator can apply a tag containing `|` unless that setting is changed on the server.

Cross Server Portals predates Valheim 1.0 and has no official Iron Gate compatibility guarantee. Its current version was runtime-tested by this project against dedicated-server build `21981590`; repeat the smoke test after any game update.

---

## Server administrator guide

### Design

Each instance is independent:

```text
/home/jim/games/
├── valheim2/
│   ├── valheim.env                 # instance name/port/world/password
│   ├── valheim-mods.lock           # shared pinned package versions/checksums
│   ├── valheim-maintain.sh         # backup/update/install/restore
│   ├── valheim-serve.sh            # runtime only; no surprise updates
│   ├── BepInEx/
│   └── saves/
├── valheim3/
│   └── ...
└── valheim-backups/
    ├── valheim2/
    └── valheim3/
```

The instance directory name determines the default systemd unit name (`valheim3` → `valheim3.service`). Override it with `VALHEIM_SERVICE_NAME` only when necessary.

### Prerequisites

- 64-bit Linux
- SteamCMD available as `steamcmd`
- Bash, `curl`, `flock`, `find`, `realpath`, `sha256sum`, `tar`, and `unzip`
- a dedicated directory owned by the service user
- a unique base port for each instance; Valheim uses the base port and base port + 1

Crossplay uses PlayFab relay service and does not require router port forwarding for ordinary joins. The base port still distinguishes multiple servers on the same public IP. Cross Server Portals should use the public hostname/IP and each destination's base port.

### Add an instance

Create the directory, then from a checkout of this repository run:

```bash
mkdir -p /home/jim/games/valheim4
./scripts/install-instance.sh /home/jim/games/valheim4
```

Edit the generated private configuration:

```bash
chmod 600 /home/jim/games/valheim4/valheim.env
$EDITOR /home/jim/games/valheim4/valheim.env
```

Set a unique `SERVER_NAME`, `SERVER_PORT`, `WORLD_NAME`, `SERVER_PASSWORD`, and `SAVE_DIR`. Defaults enable crossplay, public discovery, and the broad 2× resource preset:

```bash
SERVER_PUBLIC="1"
CROSSPLAY="1"
RESOURCE_PRESET="muchmore"
```

`muchmore` is Valheim's built-in 2× **global resource-rate** modifier. It is intentionally simple but is not limited to lumber, stone, or construction materials. A later material-specific plugin can replace it after compatibility testing.

### Install/update the server and pinned mods

The service must be stopped:

```bash
sudo systemctl stop valheim4.service
cd /home/jim/games/valheim4
./valheim-maintain.sh update
```

`update` performs these steps in order:

1. creates an integrity-checked pre-update application-state backup;
2. updates/validates Steam app `896660` in the instance directory;
3. downloads BepInEx and Cross Server Portals from Thunderstore;
4. rejects either archive if its SHA-256 differs from `valheim-mods.lock`;
5. installs the pinned files and writes `.valheim-mod-versions`;
6. verifies scripts, framework, plugin, saves, manifest, and private config permissions.

Game binaries are deliberately not included in backups because SteamCMD can reproduce them. Saves, scripts, config, BepInEx, plugins, mod manifest, and Steam/systemd metadata are included.

### systemd

Existing per-instance units can keep using the instance's `valheim-serve.sh`. For a new unit, copy and edit `templates/valheim-instance.service`, or install it as an instantiated unit template:

```bash
sudo install -m 0644 templates/valheim-instance.service \
  /etc/systemd/system/valheim@.service
sudo systemctl daemon-reload
sudo systemctl enable --now valheim@valheim4.service
```

Operational commands:

```bash
sudo systemctl start valheim3.service
sudo systemctl stop valheim3.service
sudo systemctl restart valheim3.service
systemctl --no-pager --full status valheim3.service
journalctl -u valheim3.service -f
```

### Backups and known-working snapshots

```bash
cd /home/jim/games/valheim3

./valheim-maintain.sh backup
./valheim-maintain.sh verify
./valheim-maintain.sh backup-working
./valheim-maintain.sh list-backups
```

Use `backup-working` only after an actual server/client smoke test. It first runs static verification, creates the snapshot, and atomically updates:

```text
/home/jim/games/valheim-backups/valheim3/latest-working
```

That pointer is what makes unattended rollback deterministic. A merely recent pre-update archive is not silently assumed to be good.

Backups and checksum sidecars are mode `0600`. There is no automatic pruning; establish retention only after deciding how many daily/weekly generations to keep.

### Restore

Stop the service first. Restore the explicitly marked known-working snapshot:

```bash
sudo systemctl stop valheim3.service
cd /home/jim/games/valheim3
./valheim-maintain.sh restore latest
sudo systemctl start valheim3.service
```

Or select a specific archive by basename or absolute path:

```bash
./valheim-maintain.sh list-backups
./valheim-maintain.sh restore valheim3-20260908-140000-working.tar.gz
```

Restore safety behavior:

- refuses to run while the instance service is active;
- verifies the SHA-256 sidecar and tar readability;
- rejects absolute paths, parent traversal, unexpected top-level content, and escaping symlinks;
- takes a `pre-restore` safety backup before changing current state;
- stages extraction and rolls the original state back if verification fails;
- never starts the service automatically.

An automation wrapper may run `restore latest` followed by a service start, but only after it has independently decided a rollback is warranted. The maintenance script intentionally does not mistake one transient health-check failure for permission to replace a world.

### Maintenance command reference

```text
backup                  Snapshot current application state
backup-working          Verify, snapshot, and mark latest known-working
list-backups            List archives and the working pointer
install                 Backup and install only the pinned mod stack
update                  Backup, Steam update, mod install, verification
verify                  Static file/config verification
restore latest          Restore the marked known-working snapshot
restore FILE            Restore an explicitly selected snapshot
```

### Safe update procedure

1. Stop the server and confirm nobody is connected.
2. Run `backup-working` while the current version is still known good.
3. Run `update` on only one test instance.
4. Start it and inspect both `journalctl` and `BepInEx/LogOutput.log`.
5. Test direct joins, portal travel in both directions, death/respawn, save, restart, and reconnect.
6. Stop it and run `backup-working` only after the test passes.
7. Roll the same lockfile and process to the remaining instances.

After a Valheim update, assume all binary mods are incompatible until this procedure proves otherwise.

### Troubleshooting

#### BepInEx did not load

Check:

```bash
grep -E 'BepInEx|Chainloader|plugin|Error|Exception' BepInEx/LogOutput.log
```

The log should show BepInEx, one plugin to load, and `Valheim Cross Server Portals`.

#### SteamCMD reports state `0x6` and an old manifest is denied

Inspect `~/.steam/logs/content_log.txt`. A very old instance may reference a retired depot manifest. Preserve its `steamapps/appmanifest_896660.acf` in the instance backup, move the stale manifest aside, and rerun `update` so SteamCMD performs a clean in-place reconciliation. Do not delete saves or the entire instance.

#### Crossplay client cannot join by local IP

That is expected with Valheim's crossplay backend. Use public IP/hostname, join code, or server discovery. Loopback and LAN-only addresses are not accepted by the crossplay backend.

#### Cross-server portal does nothing for a console player

Expected: the feature requires the BepInEx plugin on the client. The player must manually join the destination server.

## Verified deployment

The initial live validation on `alpha` used:

- dedicated-server build `21981590`
- BepInExPack Valheim `5.4.2333`
- Cross Server Portals `1.2.0`
- Linux systemd services with separate directories and saves
- Valheim `Resources → muchmore` accepted at startup

Primary upstream references:

- [r2modman official repository](https://github.com/ebkr/r2modmanPlus)
- [r2modman on Thunderstore](https://thunderstore.io/c/valheim/p/ebkr/r2modman/)
- [BepInExPack Valheim](https://thunderstore.io/c/valheim/p/denikson/BepInExPack_Valheim/)
- [Cross Server Portals source](https://github.com/lunar91/CrossServerPortals)
- [Cross Server Portals on Thunderstore](https://thunderstore.io/c/valheim/p/lunarbin/Cross_Server_Portals/)

## License

MIT. The downloaded game, BepInEx, and plugin remain under their respective licenses; this repository contains only orchestration scripts, templates, and documentation.
