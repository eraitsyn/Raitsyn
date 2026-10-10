# Egg RNG

A Roblox egg-rolling simulator in Luau. Roll random eggs, decide to buy or reroll, hatch them on a timer, collect pets, and use them to earn money and unlock new biomes.

Every player gets their own lane: a base at the front and their own eleven biomes behind it (Farm, Forest, Desert, Snow, Jungle, Ocean, Volcano, Prehistoric, Kingdom, Skylands, Cosmic). Nothing is shared and there is no stealing. Other players can only look at your base.

The server owns every number and every roll; the client only shows state and asks.

## How it plays

1. You spawn in your base. Walk out to your **Farm Egg Station**.
2. Standing on a station opens the roll panel: one egg offer with its rarity, price, hatch time and the pets it can hatch ("1 in N"). Press **BUY** if you can afford it, or **REROLL** for another offer.
3. Bought eggs go to your **egg inventory**. Open **Eggs** and press **Place** to put one in a free **hatch slot**. It counts down, also while you are offline.
4. When it is ready, go to the slot and **Open** it. The egg shakes, cracks and reveals the pet; rarer pets get bigger effects.
5. The pet goes to your **pet inventory** and is equipped on a free **platform**. Equipped pets earn money every second into your **Collector**; step on it to collect.
6. Spend money on better eggs, **upgrades** (Upgrade Station or the Upgrades button) and **unlocking the next biome** (walk up to its gate). The **Teleport** button jumps to any unlocked biome.

Each biome's station offers three eggs: Standard (often), Rare (sometimes, 5x price) and Royal (rarely, 25x price, can hatch the biome's best pet). Pets come in ten rarities: Common, Uncommon, Rare, Epic, Legendary, Mythic, Exotic, Divine, Secret, Cosmic. On top of rarity, each hatch can roll a Golden (x2), Diamond (x5) or Rainbow (x10) mutation.

## Getting started

1. Install the toolchain with [Rokit](https://github.com/rojo-rbx/rokit): `rokit install`
2. Install packages: `wally install` (adds ProfileStore under `ServerPackages/`)
3. Serve into Studio: `rojo serve`, then connect from the Rojo plugin.
4. Press Play. If the place has no `workspace.Lanes`, the whole map is built for you.

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
| `src/shared` | `ReplicatedStorage.Shared` | Config (`Pets`, `Economy`), `PetInfo`, `Rolls`, `Upgrades`, `Format`, `Remotes`, `Validate`, `Janitor` |
| `src/server` | `ServerScriptService.Server` | `Main`, `MapBuilder`, `Props`, `ModelFactory`, `Gate`, `RateLimiter`, `Reach`, `DataSchema`, `Services/*` |
| `src/client` | `StarterPlayerScripts.Client` | `Main`, `Hud`, `RollPanel`, `Panels`, `Hatch`, `World`, `Store`, `Ui` |
| `tests` | not synced | Lune unit tests |

All content lives in `src/shared/Config/Pets.luau`: biomes, rarities, pets, and the numbers that build every egg (prices, hatch times, odds). Upgrades, offline earnings and cooldowns live in `src/shared/Config/Economy.luau`.

## Building a real map

`MapBuilder` builds placeholder low-poly lanes from parts. To use your own build, make `workspace.Lanes` with one Model per lane (`PrimaryPart` = `Base`) containing:

| Child | Type | Purpose |
| --- | --- | --- |
| `Base`, `Spawn` | BasePart | The base floor, and where the owner appears |
| `Collector` | BasePart | Step on it to collect income |
| `UpgradeStation` | BasePart | Opens the Upgrades window |
| `Platforms/Platform1`..`Platform12` | BasePart | Where equipped pets stand |
| `HatchSlots/Slot1`..`Slot8` | BasePart | Where placed eggs sit while hatching |
| `Decor/<biome id>` | BasePart | Where the base decoration for each unlocked biome appears |
| `Biomes/<biome id>/Station` | BasePart | The roll station; standing near it opens the panel |
| `Biomes/<biome id>/Arrival` | BasePart | Where Teleport puts you |
| `Biomes/<biome id>/Gate` | BasePart | The unlock gate (every biome after Farm) |

The server checks all of this at boot and errors with the missing name. Pets and eggs are built in code by `ModelFactory`; replace `BuildPet` and `BuildEgg` to use real models.

## Security model

- **Rolls** (egg offers, pets and mutations) happen on the server with `Random.new()`. Luck comes from saved upgrades. The client's roll and hatch animations only show results the server already decided.
- **Buying** only works for the exact egg the server offered at that station, near the station, in a biome the player has unlocked, with a server roll cooldown. Prices come from server config.
- **Every remote** (`Roll`, `Buy`, `PlaceEgg`, `Equip`, `Unequip`, `EquipBest`, `Sell`, `Upgrade`, `Teleport`) goes through `Gate`: per-player rate limits, strict argument checks (known ids only), and a kick after 20 bad requests in 60 seconds. Every world action (open egg, unlock gate) is a server-side `ProximityPrompt` with owner and reach checks.
- **Gates** stay solid on the server; only the owner's client makes their unlocked gates passable, and stations refuse locked biomes anyway.
- **Hatch timers** and **offline earnings** use server unix time saved in the profile.
- **Cleanup**: everything tied to a lane is added to its `Janitor` and torn down in one call when the player leaves.
- **Saving** uses ProfileStore session locks, so data cannot be duplicated across servers. Loaded data is sanitized: whole numbers in range, only known pets, eggs, mutations and upgrades, capped inventories. Saves from earlier prototypes start over.
