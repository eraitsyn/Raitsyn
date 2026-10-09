# Raitsyn

Server-authoritative Roblox tycoon systems in Luau: button purchases, droppers, upgraders and cash collection.

The server owns every number. Clients only ask for an action by id, and the server decides.

## Getting started

1. Install the toolchain with [Rokit](https://github.com/rojo-rbx/rokit): `rokit install`
2. Install packages: `wally install` (adds ProfileStore under `ServerPackages/`)
3. Serve into Studio: `rojo serve`, then connect from the Rojo plugin.
4. Press Play. In Studio, if the place has no `workspace.Plots` or `ServerStorage.Items`, placeholder ones are built for you.

Turn on **Game Settings > Security > Enable Studio Access to API Services** to save data in Studio. Without it, ProfileStore uses an in-memory mock.

## Checks

```sh
stylua --check src tests   # formatting
selene src                 # lint
lune run tests/run         # unit tests for the pure modules
```

## Layout

| Path | Lands in | What it holds |
| --- | --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` | Config, `Remotes`, `Validate`, `ButtonGraph`, `Janitor` |
| `src/server` | `ServerScriptService.Server` | `Main`, `Gate`, `RateLimiter`, `DataSchema`, `DevScaffold`, `Services/*` |
| `src/client` | `StarterPlayerScripts.Client` | HUD: toasts and the rebirth button |
| `tests` | not synced | Lune unit tests |

## Building real plots and items

Each plot is a Model under `workspace.Plots` with `PrimaryPart` set to `Base` and these children:

| Child | Type | Purpose |
| --- | --- | --- |
| `Base` | BasePart | The plot's origin; items are placed relative to it |
| `Spawn` | BasePart | Where the owner's character is moved |
| `Collector` | BasePart | Drops touching it are turned into stored cash |
| `CollectPad` | BasePart | The owner steps on it to move stored cash into cash |
| `Buttons/<buttonId>` | BasePart | One pad per id in `Config/Buttons` |
| `Items` | Folder | Purchased items are cloned here |

Each item is a Model in `ServerStorage.Items`, named as in `Config/Buttons`, built around the world origin as if the plot's `Base` were at `0, 0, 0`. Dropper items need a part named `DropOrigin`; upgrader items need a part named `UpgradeZone`.

The server checks all of this at boot and errors with the missing name.

## Security model

- **Purchases** go through server-side `ProximityPrompt`s, so the usual path has no remote at all. `RequestPurchase` exists for a GUI shop and carries only a button id.
- **Every purchase** checks, in order: known id, has a plot, not owned, prerequisites owned, within reach (prompt path), not mid-purchase, can afford. Price always comes from server config.
- **Drops** are server-owned parts (`SetNetworkOwner(nil)`). Their value lives only in a server table, never in an attribute, and each upgrader applies once per drop.
- **Remotes** are registered only through `Gate.Handle`, which rate limits per player per remote (token bucket), checks argument types and count, and kicks after 20 failures in 60 seconds.
- **Cleanup**: everything tied to a plot (prompts, connections, droppers, drops) is added to that plot's `Janitor` and torn down in one call on leave or rebirth.
- **Saving** uses ProfileStore session locks, so data cannot be duplicated across servers. Loaded data is sanitized: whole numbers in range, unknown button ids dropped.
