# Raitsyn

A server-authoritative gods and titans tycoon in Luau. Random gods walk along a conveyor; buy them for your base, where each one earns cash every second, and steal gods from other players' bases.

The server owns every number and every roll. Clients only trigger prompts and ask to lock their base; the server decides what happens.

## Getting started

1. Install the toolchain with [Rokit](https://github.com/rojo-rbx/rokit): `rokit install`
2. Install packages: `wally install` (adds ProfileStore under `ServerPackages/`)
3. Serve into Studio: `rojo serve`, then connect from the Rojo plugin.
4. Press Play. In Studio, if the place has no `workspace.Plots` or `workspace.Lane`, placeholder ones are built for you.

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
| `src/shared` | `ReplicatedStorage.Shared` | Config (`Gods`, `Economy`), `Remotes`, `Validate`, `Rolls`, `Janitor` |
| `src/server` | `ServerScriptService.Server` | `Main`, `Gate`, `RateLimiter`, `Reach`, `DataSchema`, `GodFactory`, `DevScaffold`, `Services/*` |
| `src/client` | `StarterPlayerScripts.Client` | HUD: toasts, the lock button, and prompt filtering |
| `tests` | not synced | Lune unit tests |

## Building a real map

`workspace.Lane` holds two parts, `LaneStart` and `LaneEnd`. Gods walk in a straight line between them.

Each plot is a Model under `workspace.Plots` with `PrimaryPart` set to `Base` and these children:

| Child | Type | Purpose |
| --- | --- | --- |
| `Base` | BasePart | The plot's floor; a thief is home when standing over it |
| `Spawn` | BasePart | Where the owner's character is moved |
| `CollectPad` | BasePart | The owner steps on it to collect stored income |
| `Slots/Slot1`..`Slot8` | BasePart | Where bought gods stand, facing the part's front |

The server checks all of this at boot and errors with the missing name. God models are built in code by `GodFactory`; replace `GodFactory.Build` to use real models.

## Security model

- **Rolls** happen on the server with `Random.new()`, so no client can force a rare god.
- **Buying** goes through a server-side `ProximityPrompt`. The server checks the god is still on the lane, the buyer is in reach, has a free slot and can afford it. Price comes from server config.
- **Stealing** re-times the prompt hold on the server, checks reach and the target's lock, and cancels the steal if the thief gets home faster than `MaxCarrySpeed` allows. The god changes owner in saved data in one step, only when the thief reaches home, so leaving mid-steal cannot duplicate or lose it.
- **Income** is added on the server once a second from the saved slots; the god models are only pictures.
- **Remotes and prompts** are rate limited per player through `Gate`, which also checks remote argument types and count and kicks after 20 failures in 60 seconds. The only client-to-server remote is `RequestLock`.
- **Cleanup**: everything tied to a plot (prompts, connections, god models, the lock shield) is added to that plot's `Janitor` and torn down in one call when the player leaves.
- **Saving** uses ProfileStore session locks, so data cannot be duplicated across servers. Loaded data is sanitized: whole numbers in range, only known gods in valid slots.
