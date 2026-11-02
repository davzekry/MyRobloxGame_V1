# Crate Shop

A Roblox player data and shop system that you can try to break yourself.

- **Play:** https://www.roblox.com/games/95305691953806
- **60-second clip:** _link coming soon_

Open the **Stress Test** panel in-game and attack the shop. Every button sends the same requests a cheating client could send.

## The problem it solves

Lost progress, duplicated items, and exploited shops are the fastest ways to lose players. This system loads and saves player data safely, sells items without being tricked by the client, and shows its own defenses on screen.

## What was tested

All four Stress Tests passed in the published game on desktop and phone on 2026-11-02. See [docs/live-test-checklist.md](docs/live-test-checklist.md).

| Test | What you do | Result |
|---|---|---|
| Rejoin | Buy something, leave, and come back | Items and balance are still there |
| Cheat | Send fake requests: a price of 0, an unknown item, the wrong type, "give me 1,000,000 coins" | Each is rejected with a reason |
| Double-spend | Fire 50 buys at once | Coins spent always equal the price of what was bought, and the balance never goes negative |
| Duplicate session | Join on a second device while playing | The first session ends, and no data is lost or duplicated |

31 rule tests also run in Studio on every Play.

## Architecture

```
Client screens ──RemoteFunction──▶ RequestGate ──▶ Service ──▶ PlayerDataService ──▶ ProfileStore
   ▲                               rate limit       rules        cached profile        session lock,
   └────────── StateChanged ◀───── arg checks       no yields                          auto-save
                                    rejection log
```

| Part | Job |
|---|---|
| `PlayerDataService` | Loads, caches, and releases each player's profile with [ProfileStore](https://madstudioroblox.github.io/ProfileStore/) |
| `EconomyService` | The only code that changes coins, apart from the demo-only reset |
| `ShopService` | Validates and performs purchases |
| `InventoryService`, `CosmeticService` | Owned and equipped items, and putting them on the character |
| `PickupService` | Server-side coin pickups bound by a CollectionService tag |
| `RequestGate` | Rate limit, argument count, and rejection logging for every remote |
| `Rules/` | Pure functions with unit tests: purchase rules, request checks, starting data |

The client only displays state the server pushes. It never changes a balance itself.

## Security decisions

- **The server decides everything.** The client sends only an item id. Prices come from the server's catalog.
- **No yield between checking and changing data.** Luau runs one thread at a time and switches only at a yield, so a purchase can't be interrupted between "can afford" and "charge". This is what stops double-spending.
- **Every remote goes through one gate.** It rate limits each player (10 requests, refilling 5 per second), rejects wrong argument counts, including a trailing `nil`, and logs the rejection.
- **Coins and items save together** in one record, so a failure can roll a purchase back but never leave half of one.
- **Session locking.** A profile can only be open on one server at a time. If another server takes it over, the old server stops using it immediately. A player who rejoins the same server waits until their final save is written.
- **A failed load never starts a player with blank data.** They're asked to rejoin instead, so an outage can't overwrite real progress.

### Known limits

- A cheater can teleport to coins. Pickups check range on the server, so income is still capped at about 5 coins per second. A real game would also check movement speed.
- Auto-save runs every 5 minutes, so a server crash can lose up to that much progress. That a crash can't leave half a purchase follows from the design above. It wasn't tested by crashing a server.
- The double-spend receipt is calculated on the tester's own screen from the server's pushed state.

## Add it to your game

1. Copy `src/Server` into ServerScriptService and `src/Shared` into ReplicatedStorage.
2. Delete `src/Server/Services/DemoService.luau` and its line in `Bootstrap.server.luau`. It holds the demo-only decoy and reset. Also remove `AddCoins` and `ResetMyData` from `FUNCTIONS` in `src/Shared/Remotes.luau`.
3. Edit `src/Shared/Catalog.luau` for your items, and the builders in `CosmeticService.luau` for how they look.
4. Edit `src/Server/Rules/DataTemplate.luau` for your saved data. Bump `Version` when the shape changes.
5. Tag coin parts `CoinPickup` with a `Coins` attribute, or delete `PickupService` if you don't need it.
6. Turn on **Game Settings → Security → Enable Studio Access to API Services** to test saving in Studio. Studio uses a separate store, so tests can't touch live data.

The client screens in `src/Client` are optional. If you keep them, delete `StressPanel` and its line in `Main.client.luau`.

## Running it locally

The project syncs into Studio with [Argon](https://argon.wiki). Tests run automatically when you press Play in Studio. `tools/` has the room builder and the scripts used to keep Studio in sync with the files.

## Credits

[ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) by MAD STUDIO, under the Apache 2.0 license ([licenses/ProfileStore-LICENSE.txt](licenses/ProfileStore-LICENSE.txt)).
