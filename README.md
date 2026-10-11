# Raitsyn

Server-authoritative Roblox tycoon systems in Luau.

## Roll RNG (pet farm simulator)

Roll for eggs of seven rarities, hatch pets, place them on your own plot to earn coins every second, and grow a
43-tile hexagonal upgrade tree. Design and architecture plan:
[Roll RNG: Game Design & Architecture Plan](https://claude.ai/code/artifact/186f292d-42ac-4095-9bc4-a0bd6e77c51d).

### Getting started

```sh
rokit install          # installs the pinned rojo, lune, stylua, selene
rojo serve             # then connect from the Rojo plugin in Studio
lune run tests/run     # unit tests (no Studio needed)
lune run tools/sim/economy   # economy simulation report
```

### Layout

| Path | What lives there |
| --- | --- |
| `src/shared/Config` | Every tunable number: rarities and odds, pets, roll tiers, hex tree, economy, daily rewards |
| `src/shared/Logic` | Pure game rules shared by server and client: odds, stats, income, costs, hex graph, formatting, validation |
| `src/server/Data` | Saved profile schema, migrations and repair |
| `tests` | Lune unit tests; `tests/lib/Loader.luau` lets the real ModuleScripts run outside Roblox |
| `tools/sim` | Economy simulator that plays the game with the real config |

Rules of the codebase:

- The server decides every result. Clients send ids, never amounts or outcomes.
- Numbers live in `Config`, never inline in game code.
- `shared/Logic` has no Roblox service calls, so it is unit tested and used identically on both sides.
