# Crate Shop: Design Spec

Date: 2026-11-01. Approved section by section in the Phase 0 design review. This spec replaces Sections 3 to 6 of `portfolio-roadmap.md` wherever the two differ.

## 1. Goal

Show Roblox game owners a reliable player data and shop system they can try to break themselves.

**Success means:**
- An owner can try the attacks and see the results in under a minute.
- The user can explain and defend every line in a client interview.
- The public repo claims only what was tested.

**Constraints:** under 5 hours a week, about 25 hours in total, and a room built from basic shapes. The demo has to prove the system, not be fun to play.

**Left out on purpose:** trading, Robux purchases, pets, leaderboards, and custom art.

## 2. What owners see

### Demo

One room with coin pickups, a shop with three cosmetics, an inventory with equipping, and data that saves between sessions. The shop, inventory, and Stress Test panel are on-screen panels opened from buttons on the HUD, which also suits phones.

| Item id | Name | Slot | Price |
|---|---|---|---|
| `crate_hat` | Crate Hat | `Hat` | 100 |
| `spark_trail` | Spark Trail | `Trail` | 150 |
| `gold_color` | Gold Color | `Color` | 200 |

New players start with 250 coins so owners can test straight away. The items cost 450 in total, so a new player can't afford all three.

### Stress Test panel

| Test | What the owner does | What they see |
|---|---|---|
| Rejoin | Buys, leaves, comes back | Item and balance are still there |
| Cheat | Presses an attack button | The request is rejected and the reason is shown |
| Double-spend | Presses a button that fires 50 buys at once across all items | A receipt: balance before and after, items bought, and rejections by code |
| Duplicate session | Joins on a second device | Roblox drops the first session, and no data is lost or duplicated |

The Duplicate session test is run by hand and filmed. It is the first thing to cut if the project runs over budget.

**Cheat buttons:**

| Button | Request | Result |
|---|---|---|
| Buy for 0 coins | `BuyItem("crate_hat", 0)` | `InvalidRequest` |
| Unknown item | `BuyItem("free_robux")` | `UnknownItem` |
| Wrong type | `BuyItem(12345)` | `InvalidRequest` |
| Give me 1,000,000 coins | `AddCoins(1000000)` | `Forbidden` |

`AddCoins` is a decoy that never grants coins. It shares the rate limit, so spamming it can't flood the log. The panel says it exists only for the demo.

**Receipt rule:** coins spent always equal the total price of the items bought, and the balance never goes below zero.

**Reset my data:** returns the player to 250 coins, no items, and nothing equipped, so the tests can be repeated. It gives no advantage, because the player loses every item to get the coins back.

## 3. Architecture

### Folders

```
src/
  Server/
    Bootstrap.server.luau        starts the services in order
    Packages/ProfileStore.luau   copied in; keep its license notice
    Rules/
      DataTemplate.luau          pure starting data; a new table on every call
      PurchaseRules.luau         pure buy rules
      RequestRules.luau          pure argument checks
    RateLimiter.luau             per-player token bucket
    RejectionLog.luau            recent rejections per player
    RequestGate.luau             shared rate limit, argument count, and logging
    Services/
      PlayerDataService.luau     loads, caches, and releases profiles
      EconomyService.luau        the only code that changes coins
      ShopService.luau           handles BuyItem
      InventoryService.luau      owned and equipped items; handles SetEquipped
      CosmeticService.luau       puts equipped items on the character
      PickupService.luau         server-side coin pickups
      DemoService.luau           AddCoins decoy and ResetMyData
    Tests/
      Runner.server.luau         Studio-only test runner
      *.spec.luau                test modules
  Shared/
    Catalog.luau                 item ids, names, slots, prices
    Types.luau                   shared types
    ResultCodes.luau             every result code
    Remotes.luau                 creates and finds all remotes
  Client/
    Main.client.luau
    UI/                          HUD, shop, inventory, Stress Test panel
tools/
  build_room.luau                rebuilds the room in Studio
```

`Shared` is sent to every client, so server-only code stays in `Server`. To add this system to another game, an owner deletes `DemoService.luau` and the Stress Test panel. Nothing else depends on them.

### Module interfaces

| Module | Interface |
|---|---|
| `PlayerDataService` | `GetData(player): PlayerData?` returns nil unless the session is active. `PushState(player)` sends `StateChanged`. |
| `EconomyService` | `Award(player, amount)` and `Spend(player, amount)`. Neither yields. |
| `InventoryService` | `Grant(player, itemId)` does not yield. Handles `SetEquipped`. |
| `PurchaseRules` | `check(data, item): ResultCode` is a pure function. |
| `RequestRules` | Pure checks that take raw client values and return whether they are valid. |
| `RateLimiter` | `new(capacity, refillPerSecond)`, then `allow(key, now): boolean`. The time is passed in so tests can control it. |
| `RejectionLog` | `add(player, entry)` stores the entry and sends `RejectionLogged`. |

`Bootstrap` starts these in order: `Remotes`, `PlayerDataService`, `EconomyService`, `InventoryService`, `CosmeticService`, `ShopService`, `PickupService`, `DemoService`.

### Remotes

| Remote | Type | Arguments | Returns |
|---|---|---|---|
| `BuyItem` | RemoteFunction | `itemId: string` | `ResultCode` |
| `SetEquipped` | RemoteFunction | `itemId: string, equipped: boolean` | `ResultCode` |
| `ResetMyData` | RemoteFunction | None | `ResultCode` |
| `AddCoins` | RemoteFunction | Anything | `Forbidden`, or `RateLimited` over the limit. Never grants coins |
| `StateChanged` | RemoteEvent, server to client | `Coins, OwnedItems, EquippedItems, SavingEnabled` | None |
| `RejectionLogged` | RemoteEvent, server to client | `Code, Remote, ItemId?` | None |

All four RemoteFunctions are called by the client and answered by the server. The server never invokes a client. `SavingEnabled` is true when `ProfileStore.DataStoreState` is `"Access"`.

### Saved data

```lua
type PlayerData = {
	Version: number,
	Coins: number,
	OwnedItems: { [string]: boolean },
	EquippedItems: { [string]: string },
}
```

- The template is `Version = 1`, `Coins = 250`, and empty tables.
- `EquippedItems` maps a slot to an item id, so each slot holds one item.
- Coins and items are one record, so a crash can roll back a purchase but cannot leave half of one.
- Call `Profile:Reconcile()` after load so new template fields reach old saves, and `Profile:AddUserId()` so data can be erased on request.
- Studio uses the store name `PlayerData_Studio` and the live game uses `PlayerData_v1`. Studio shares data stores with the live game, so the names must differ. `ProfileStore.Mock` is not used, because it forgets data at shutdown and the rejoin check needs real saves.

### Purchase flow

1. The client calls `BuyItem(itemId)`.
2. The server checks, in order: rate limit, exact arguments, profile loaded, item exists, not owned, enough coins.
3. The server calls `Spend` and `Grant` with **no yield between the checks and the change**.
4. The server calls `PushState` and returns `Ok`.
5. A failed check returns its code. Every rejection except `RateLimited` goes to `RejectionLog`.

Prices always come from the server's copy of `Catalog`. The client sends only an item id.

Luau runs one thread at a time and only switches at a yield. With no yield in step 2 or 3, no other request can run between the check and the change.

### Equip flow

`SetEquipped` checks the rate limit, exact arguments, profile loaded, item exists, and owned. Equipping replaces the item in that slot. Unequipping clears the slot if that item is in it, and otherwise does nothing and returns `Ok`.

### Reset flow

`ResetMyData` checks the rate limit, exact arguments, and profile loaded. It then restores the template values, removes cosmetics from the character, and calls `PushState`.

### Rate limit and rejection log

- One token bucket per player, shared across the four RemoteFunctions: capacity 10, refilling 5 tokens a second.
- In the 50-buy burst, about 10 requests are processed and the rest return `RateLimited`. The receipt counts return values, so it doesn't need the log.
- `RateLimited` responses aren't logged, so spamming can't flood the log.
- The log keeps the last 50 rejections per player and is cleared when the player leaves. Item ids are cut to 40 characters.

### Coin pickups

- Parts are tagged `CoinPickup` and carry a `Coins` attribute of 10. The room has 8.
- The server listens to `Touched`, finds the player, and checks that the pickup is active, the profile is loaded, and the player is within 12 studs of it. Exploiters can fake touches, so the distance check is required.
- On success the pickup is hidden for everyone for 15 seconds and `Award` adds the coins.
- The amount is read on the server. The client never reports it.

### Cosmetics

`CosmeticService` builds each item in code from basic shapes and applies equipped items on `CharacterAdded`:

| Slot | How it appears |
|---|---|
| `Hat` | A part welded to the head |
| `Trail` | A `Trail` between two attachments on the root part |
| `Color` | A `BodyColors` change |

### The room

`tools/build_room.luau` creates `Workspace.Room`, replacing any earlier copy, inside a ChangeHistoryService recording. It is run with `tools/argon_exec.py`, so the room can be rebuilt from the public repo even though the place file isn't in git.

## 4. Error handling

### Player data

| Situation | Behavior |
|---|---|
| Load takes longer than 30 seconds or fails | Kick with "please rejoin". Never start with blank data |
| `StartSessionAsync` returns nil | Same kick |
| Player leaves during loading | `Cancel` stops the load |
| Request before the profile loads | Return `NotReady` |
| Another server takes the session (`OnSessionEnd`) | Remove the profile from the cache immediately, then kick with "please rejoin" |
| Player leaves normally | Call `EndSession()` |
| Server shuts down | ProfileStore finishes saving |
| Saving unavailable | Panel shows "Saving is off", and a warning goes to Output |

`Cancel` returns true when the player has left **or** 30 seconds have passed. Setting `Cancel` turns off ProfileStore's default timeout, so the deadline has to be ours.

The cache removal matters because changes to `Profile.Data` stop being saved once a session ends. `GetData` returning nil turns that gap into `NotReady`.

### Result codes

| Code | Meaning | Logged |
|---|---|---|
| `Ok` | Success | No |
| `NotReady` | Profile isn't loaded or the session has ended | Yes |
| `RateLimited` | Too many requests | No |
| `InvalidRequest` | Wrong type, missing, extra, or empty arguments | Yes |
| `UnknownItem` | Item isn't in the catalog | Yes |
| `AlreadyOwned` | Buying an item the player owns | Yes |
| `NotEnoughCoins` | Balance is below the price | Yes |
| `NotOwned` | Equipping an item the player doesn't own | Yes |
| `Forbidden` | Called the `AddCoins` decoy | Yes |

### Client and character

| Situation | Behavior |
|---|---|
| A remote call fails | Button shows "Try again" and the display doesn't change |
| Button pressed during a request | Button is disabled until the response arrives |
| Item equipped while respawning | Data saves now and the item appears on the next spawn |

Balance and inventory screens update only from `StateChanged`, never from a button press.

## 5. Testing

| Layer | Covers | Runs |
|---|---|---|
| Unit tests | Pure rules | Automatically on Play in Studio |
| Studio checks | Each phase's "Done when" line | By hand, end of each phase |
| Live checks | All four Stress Tests | By hand in the published game, desktop and phone, in Phase 6 |
| Tool tests | `python tools/test_snapshot_place.py` and `python tools/test_argon_exec.py` | When the tools change |

**Runner:** about 30 lines of our own in `src/Server/Tests/`. It prints one summary line such as `Tests: 24 passed, 0 failed`, plus any failures, and runs only when `RunService:IsStudio()` is true. The user pastes the results into the session, because Claude can't read Studio's Output window.

**Unit test cases:**

| Module | Cases |
|---|---|
| `PurchaseRules` | Enough coins, exact coins, one coin short, already owned, unknown item, owned wins over short of coins |
| `RequestRules` | Wrong type, missing, extra, empty string |
| `RateLimiter` | First 10 pass, 11th refused, tokens refill, players don't share buckets |
| `Catalog` | Unique ids, positive prices, valid slots |

**Not proven by unit tests:**
- The no-yield guarantee and the receipt rule are checked by the Double-spend receipt, in Studio and live.
- Saving, rejoining, and session handoff need the published game. A private place works, because the user can join on two devices with one account.
- A real crash during a purchase can't be triggered reliably. The README describes that as design reasoning, not a tested result.

**Phase 6 gate:** the game goes public only after all four Stress Tests pass live on desktop and phone. If the Duplicate session test is cut, the README doesn't list it as tested.

## 6. Changes to the roadmap

| Roadmap says | Use instead |
|---|---|
| `BuyItem` is fired | It is a RemoteFunction that returns a result code |
| `Packages/` under `Shared` | `Server/Packages/` |
| `argon exec` | `python tools/argon_exec.py <port> <file.luau>` |
| `place.rbxlx` | `Crate Shop.rbxlx` |
| About 23 hours | About 25 hours, for `CosmeticService`, `DemoService`, `RequestRules`, the runner, and `build_room.luau` |
| Temporary command in Phase 1 | Studio-only behind `RunService:IsStudio()`, and removed in Phase 2 once pickups can change coins |
