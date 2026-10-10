# Raitsyn

A server-authoritative Egg RNG tycoon in Luau. Every player gets their own base with an egg shop, four incubators, eight pet pedestals and a luck board. Buy an egg, wait for it to hatch, and the pet it rolls goes onto a pedestal where it earns cash every second. Step on a pedestal's green button to collect.

The server owns every number and every roll. Clients only trigger prompts; the server decides what happens.

## How it plays

1. **Buy an egg** at one of the three shop stands in your base (Basic, Golden, Cosmic). The sign above each stand lists every pet it can hatch as "1 in N", already adjusted for your luck.
2. **Incubate.** The egg goes into a free incubator and counts down. The timer keeps running while you are offline.
3. **Hatch** it when the timer hits zero. The server rolls the pet and places it on a free pedestal. Mythical and Secret hatches are announced to the whole server.
4. **Collect.** Each pet adds its income to its pedestal once a second. Step on the pedestal's green button to collect it.
5. **Upgrade luck** at the luck board (x1.25, x1.5, ...). Luck shifts the odds toward Rare and better pets.
6. **Sell** a pet by holding its prompt, for 10 times its income plus any cash left on its pedestal.

## Getting started

1. Install the toolchain with [Rokit](https://github.com/rojo-rbx/rokit): `rokit install`
2. Install packages: `wally install` (adds ProfileStore under `ServerPackages/`)
3. Serve into Studio: `rojo serve`, then connect from the Rojo plugin.
4. Press Play. In Studio, if the place has no `workspace.Plots`, four placeholder bases are built for you.

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
| `src/shared` | `ReplicatedStorage.Shared` | Config (`Pets`, `Economy`), `Remotes`, `Validate`, `Rolls`, `Luck`, `Janitor` |
| `src/server` | `ServerScriptService.Server` | `Main`, `Gate`, `RateLimiter`, `Reach`, `DataSchema`, `ModelFactory`, `DevScaffold`, `Services/*` |
| `src/client` | `StarterPlayerScripts.Client` | HUD: toasts, rare-hatch reveal, luck label, egg countdowns, prompt filtering |
| `tests` | not synced | Lune unit tests |

Eggs, pets, prices, hatch times and odds live in `src/shared/Config/Pets.luau`. Money, luck and slot counts live in `src/shared/Config/Economy.luau`.

## Building a real map

Each plot is a Model under `workspace.Plots` with `PrimaryPart` set to `Base` and these children:

| Child | Type | Purpose |
| --- | --- | --- |
| `Base` | BasePart | The plot's floor |
| `Spawn` | BasePart | Where the owner's character is moved |
| `LuckBoard` | BasePart | Holds the Upgrade Luck prompt and the luck sign |
| `Shop/Basic`, `Shop/Golden`, `Shop/Cosmic` | BasePart | One stand per egg; holds the Buy prompt and the odds sign |
| `Incubators/Incubator1`..`Incubator4` | BasePart | Where bought eggs sit while they count down |
| `Pedestals/Pedestal1`..`Pedestal8` | BasePart | Where hatched pets stand |
| `Buttons/Button1`..`Button8` | BasePart | The green collect button for the pedestal with the same number |

The server checks all of this at boot and errors with the missing name. Pet and egg models are built in code by `ModelFactory`; replace `ModelFactory.BuildPet` and `ModelFactory.BuildEgg` to use real models.

## Security model

- **Rolls** happen on the server with `Random.new()` when an egg hatches, so no client can force a rare pet. Luck comes from saved data, not the client.
- **Every action is a server-side `ProximityPrompt`** (buy, hatch, sell, upgrade luck). Each handler checks the prompt rate limit, that the player owns the base, and that they are within reach. Prices come from server config.
- **Hatch timers** are stored as server unix time. The client only draws the countdown; hatching early is refused.
- **Income** is added on the server once a second from saved pedestals; collecting needs the owner's own character to touch that pedestal's button.
- **Remotes and prompts** are rate limited per player through `Gate`, which also checks remote argument types and count and kicks after 20 failures in 60 seconds. There is no client-to-server remote; the only remote is the server's `Notify`.
- **Cleanup**: everything tied to a plot (prompts, connections, models, signs) is added to that plot's `Janitor` and torn down in one call when the player leaves.
- **Saving** uses ProfileStore session locks, so data cannot be duplicated across servers. Loaded data is sanitized: whole numbers in range, only known pets and eggs in valid slots.
