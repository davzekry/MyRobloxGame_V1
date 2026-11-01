# Crate Shop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Crate Shop demo: a player data and shop system that game owners can try to break, ready for a public portfolio.

**Architecture:** Server-authoritative Luau services over ProfileStore. Pure rule modules hold the logic that unit tests cover. A thin request gate gives every client-called remote the same rate limit, argument check, and rejection logging.

**Tech Stack:** Luau (`--!strict`), Roblox Studio, Argon 2.0.29, ProfileStore, Python 3.12 for tools.

**Spec:** `docs/specs/crate-shop-design.md`

## Global Constraints

- Follow `CLAUDE.md`: `--!strict`, `game:GetService(...)`, `task.wait/spawn/delay`, and no admin backdoors.
- No yield between checking a balance and changing it.
- Starting balance 250. Rate limit capacity 10, refill 5 per second, one bucket per player. Rejection log keeps 50 per player, with item ids cut to 40 characters.
- Pickups: tag `CoinPickup`, attribute `Coins` = 10, 8 in the room, 12-stud range, 15-second respawn.
- Load deadline 30 seconds. Store names `PlayerData_Studio` and `PlayerData_v1`.
- Claude can't read Studio's Output window. Every "Play in Studio" step is run by the user, who pastes back the result.
- Change the world with `python tools/argon_exec.py <port> <file.luau>` and confirm in Studio or with a fresh snapshot. A success reply proves nothing.
- Each task ends with an explanation of its key decisions, using web development comparisons.
- Commit only at the end of a phase, after the user says to.
- The project must remain private until the user changes that setting in Phase 6.

## Review Focus

1. A player who leaves and rejoins within seconds should load after the old session saves, not be kicked or get blank data. Checked in Task 4.
2. `BuyItem("crate_hat", nil)` has two arguments even though the second is nil, and should return `InvalidRequest`. Tested in Task 7.
3. Players already in the server when services start, common in Studio, should still load. Checked in Task 2.
4. Equipped items should appear on the first spawn after joining, even if the character loads before the profile. Checked in Task 10.
5. `ResetMyData` must never share template tables between players, or one player's purchase would appear on another. Tested in Task 1.

---

## Phase 0: Finish

### Task 0: First commit

- [ ] **Step 1:** Confirm `git status` shows no `.rbxlx` file, `snapshot/`, or `sourcemap.json`.
- [ ] **Step 2:** With the user's OK, commit everything as `chore: set up project, tools, spec, and plan`.

---

## Phase 1: Player data

**Done when:** a value survives leaving and rejoining in Studio with API access on.

### Task 1: Test runner and shared types

**Files:**
- Delete: `src/Server/Main.server.luau`, `src/Shared/Hello.luau`
- Create: `src/Server/Tests/Runner.server.luau`, `src/Server/Tests/DataTemplate.spec.luau`, `src/Server/Rules/DataTemplate.luau`, `src/Shared/Types.luau`, `src/Shared/ResultCodes.luau`
- Modify: `src/Client/Main.client.luau` (empty placeholder until Task 11)

**Interfaces:**
- Produces: a spec module returns `{ [testName: string]: () -> () }` and fails by erroring.
- Produces: `Types.PlayerData`, `Types.CatalogItem = { Id, Name, Slot, Price }`, `Types.PlayerState = { Coins, OwnedItems, EquippedItems, SavingEnabled }`, `Types.RejectionEntry = { Code, Remote, ItemId: string? }`.
- Produces: `ResultCodes.Ok` and the eight other codes from spec Section 4, as a frozen table of strings, plus `export type ResultCode`.
- Produces: `DataTemplate.new(): PlayerData`, a new table on every call.

- [ ] **Step 1:** Create `Runner.server.luau`, about 30 lines. It returns at once unless `RunService:IsStudio()`, requires every ModuleScript in `script.Parent` whose name ends in `.spec`, runs each test in `pcall`, warns each failure, and prints `Tests: N passed, M failed`. Check the snapshot to confirm Argon names the instance `X.spec`.
- [ ] **Step 2:** Write `DataTemplate.spec.luau` with `new returns starting values` (`Version` 1, `Coins` 250, empty tables) and `new never shares tables` (changing one result's `OwnedItems` doesn't affect a second result).
- [ ] **Step 3:** Play in Studio. Expected: 2 failures, because `DataTemplate` doesn't exist.
- [ ] **Step 4:** Implement `DataTemplate.new`, `Types`, and `ResultCodes`.
- [ ] **Step 5:** Play in Studio. Expected: `Tests: 2 passed, 0 failed`.

### Task 2: Load and release profiles

Before writing code, explain session locking with a web development comparison.

**Files:**
- Create: `src/Server/Packages/ProfileStore.luau`, `src/Server/Services/PlayerDataService.luau`, `src/Server/Bootstrap.server.luau`

**Interfaces:**
- Consumes: `DataTemplate.new()`
- Produces: `PlayerDataService.Init()`, `GetData(player): PlayerData?`, `OnProfileLoaded(callback: (Player) -> ())`. Every service `Init` must not yield.

- [ ] **Step 1:** Copy ProfileStore from its official source, keep its license notice, and check the current API against its docs.
- [ ] **Step 2:** Implement `Init`: create the store with the Studio or live name, connect `PlayerAdded` and `PlayerRemoving`, and also load every player in `Players:GetPlayers()`.
- [ ] **Step 3:** On load, call `StartSessionAsync` with a `Cancel` that returns true when the player has left or 30 seconds have passed. Then call `AddUserId` and `Reconcile`, and cache the profile. On leaving, call `EndSession` and remove it from the cache.
- [ ] **Step 4:** Add `Bootstrap.server.luau`, which calls `PlayerDataService.Init()`.
- [ ] **Step 5:** Play in Studio with a temporary print of the loaded data. Expected: 250 coins on first join, no errors, and the print removed afterward.

### Task 3: Failure paths

**Files:**
- Modify: `src/Server/Services/PlayerDataService.luau`

- [ ] **Step 1:** Kick with a "please rejoin" message when load returns nil or the deadline passes, unless the player has already left. Never cache blank data.
- [ ] **Step 2:** Connect `OnSessionEnd`: remove the profile from the cache first, then kick with "please rejoin".
- [ ] **Step 3:** Temporarily make `Cancel` return true at once, Play in Studio, then restore it. Expected: the kick message appears and no profile is cached.

### Task 4: Push state and prove saving

**Files:**
- Create: `src/Shared/Remotes.luau`, `src/Server/DevCoins.luau`
- Modify: `src/Server/Services/PlayerDataService.luau`, `src/Server/Bootstrap.server.luau`

**Interfaces:**
- Produces: `Remotes.init()` (server only) creates a `Remotes` folder in ReplicatedStorage. `Remotes.func(name): RemoteFunction` and `Remotes.event(name): RemoteEvent` work on both sides.
- Produces: `PlayerDataService.PushState(player)` fires `StateChanged` with a `PlayerState`. `SavingEnabled` is `ProfileStore.DataStoreState == "Access"`.

- [ ] **Step 1:** Implement `Remotes` and `PushState`, and call `PushState` after load.
- [ ] **Step 2:** Add `DevCoins.luau`, a temporary chat command behind `RunService:IsStudio()` that sets the player's coins.
- [ ] **Step 3:** Tell the user the exact Studio test: set coins, stop, Play again. Expected: the value survives.
- [ ] **Step 4:** Stop and immediately Play again. Expected: the data loads with no kick.
- [ ] **Step 5:** With the user's OK, commit as `feat: load, save, and release player data`.

---

## Phase 2: Coins and pickups

**Done when:** pickups award coins, respawn after a cooldown, and an exploiter can't set the amount.

### Task 5: Economy and pickups

**Files:**
- Create: `src/Server/Services/EconomyService.luau`, `src/Server/Services/PickupService.luau`
- Delete: `src/Server/DevCoins.luau`
- Modify: `src/Server/Bootstrap.server.luau`

**Interfaces:**
- Consumes: `PlayerDataService.GetData`, `PushState`
- Produces: `EconomyService.Award(player, amount: number): boolean` and `Spend(player, amount: number): boolean`. Neither yields. Each returns false if the profile is missing, and `Spend` also returns false if the balance is too low. Both require a positive integer.
- Produces: `PickupService.Init()`

- [ ] **Step 1:** Implement `EconomyService`. It does not call `PushState`; callers do, so a purchase pushes once.
- [ ] **Step 2:** Implement `PickupService`: bind tagged parts, including ones added later. On `Touched`, find the player and check the pickup is active, the profile is loaded, and the root part is within 12 studs. The pickup becomes inactive before coins are awarded, so two touches can't both count. Respawn with `task.delay(15, ...)`.
- [ ] **Step 3:** Add `PickupService.Init()` to `Bootstrap`, and delete `DevCoins`.

### Task 6: Test room

Read a fresh snapshot first.

**Files:**
- Create: `tools/build_room.luau`

- [ ] **Step 1:** Write `build_room.luau`: inside a ChangeHistoryService recording, replace `Workspace.Room` with a floor, walls, and 8 tagged pickups with `Coins` = 10.
- [ ] **Step 2:** Run it with `tools/argon_exec.py`. The user confirms the room in Studio, and Ctrl+Z removes it in one step. Run it again to keep the room.
- [ ] **Step 3:** The user re-saves the place. Run the snapshot and confirm `tags=CoinPickup` on all 8. This is the first real proof of the tag fix.
- [ ] **Step 4:** Play in Studio. Expected: a pickup adds 10 coins, vanishes, and returns after 15 seconds.
- [ ] **Step 5:** Explain how a cheating client might attack this and how the code stops each attack.
- [ ] **Step 6:** With the user's OK, commit as `feat: add coins, pickups, and test room`.

---

## Phase 3: Shop and inventory

**Done when:** all purchase tests pass and every rejection returns a clear code.

### Task 7: Catalog and request rules

**Files:**
- Create: `src/Shared/Catalog.luau`, `src/Server/Rules/RequestRules.luau`
- Test: `src/Server/Tests/Catalog.spec.luau`, `src/Server/Tests/RequestRules.spec.luau`

**Interfaces:**
- Produces: `Catalog.Items: { CatalogItem }` and `Catalog.get(id: unknown): CatalogItem?`
- Produces: `RequestRules.hasExactArgs(count: number, expected: number): boolean`, `isItemId(value: unknown): boolean`, `logSafeItemId(value: unknown): string?`

- [ ] **Step 1:** Write `Catalog.spec.luau`: `ids are unique`, `prices are positive`, `slots are valid` (`Hat`, `Trail`, `Color`), `get returns nil for a non-string`.
- [ ] **Step 2:** Write `RequestRules.spec.luau`: `extra argument fails`, `missing argument fails`, `explicit nil counts as an extra argument` (`select("#", "crate_hat", nil)` is 2), `number is not an item id`, `empty string is not an item id`, `string over 64 characters is not an item id`, `valid id passes`, `log id is cut to 40 characters`, `log id is nil for a non-string`.
- [ ] **Step 3:** Play in Studio. Expected: all new tests fail.
- [ ] **Step 4:** Implement both modules, with the items and prices from spec Section 2.
- [ ] **Step 5:** Play in Studio. Expected: 0 failed.

### Task 8: Purchase rules and rate limiter

Before writing `PurchaseRules`, ask the user to write the validation steps in their own words, then review them.

**Files:**
- Create: `src/Server/Rules/PurchaseRules.luau`, `src/Server/RateLimiter.luau`
- Test: `src/Server/Tests/PurchaseRules.spec.luau`, `src/Server/Tests/RateLimiter.spec.luau`

**Interfaces:**
- Produces: `PurchaseRules.check(data: PlayerData, item: CatalogItem?): ResultCode`
- Produces: `RateLimiter.new(capacity: number, refillPerSecond: number)`, with methods `allow(key: any, now: number): boolean` and `forget(key: any)`

- [ ] **Step 1:** Write `PurchaseRules.spec.luau`: `enough coins is Ok`, `exact coins is Ok`, `one coin short is NotEnoughCoins`, `already owned is AlreadyOwned`, `nil item is UnknownItem`, `owned wins over short of coins`.
- [ ] **Step 2:** Write `RateLimiter.spec.luau`, passing explicit times: `first 10 pass`, `11th is refused`, `tokens refill over time` (one token back after 0.2 seconds), `tokens never exceed capacity`, `players don't share buckets`, `forget resets a key`.
- [ ] **Step 3:** Play in Studio. Expected: all new tests fail.
- [ ] **Step 4:** Implement both modules.
- [ ] **Step 5:** Play in Studio. Expected: 0 failed.

### Task 9: Buying

Point out exactly where a yield would create a double-spend bug.

**Files:**
- Create: `src/Server/RejectionLog.luau`, `src/Server/RequestGate.luau`, `src/Server/Services/ShopService.luau`, `src/Server/Services/InventoryService.luau`
- Modify: `src/Server/Bootstrap.server.luau`

**Interfaces:**
- Consumes: `RateLimiter`, `RequestRules`, `Catalog`, `PurchaseRules`, `EconomyService.Spend`, `PlayerDataService`
- Produces: `RejectionLog.add(player, entry: RejectionEntry)` stores up to 50 entries, fires `RejectionLogged`, and clears on leave.
- Produces: `RequestGate.bind(name: string, expectedArgs: number?, handler: (Player, ...any) -> (ResultCode, any?))` sets `OnServerInvoke`. It owns the shared limiter and runs the rate limit first, then the argument count from `select("#", ...)` when `expectedArgs` isn't nil. It logs every non-`Ok` result except `RateLimited`, and calls `forget` on leave. The optional second handler value is the raw item id for the log.
- Produces: `InventoryService.Grant(player, itemId): boolean`, which does not yield.

- [ ] **Step 1:** Implement `RejectionLog`, using `logSafeItemId` for the item id.
- [ ] **Step 2:** Implement `RequestGate`.
- [ ] **Step 3:** Implement `ShopService`'s `BuyItem` handler in the order of spec Section 3, with no yield from the first check to the end of `Grant`, then call `PushState`.
- [ ] **Step 4:** Add `ShopService.Init()` to `Bootstrap`.
- [ ] **Step 5:** In a Studio Play test, invoke `BuyItem` from a temporary client script with each Cheat request, then remove the script. Expected: the result codes from spec Section 2, and a real buy returns `Ok` and charges the catalog price.

### Task 10: Equipping and cosmetics

**Files:**
- Create: `src/Server/Services/CosmeticService.luau`
- Modify: `src/Server/Services/InventoryService.luau`, `src/Server/Bootstrap.server.luau`

**Interfaces:**
- Consumes: `RequestGate.bind`, `PlayerDataService.OnProfileLoaded`
- Produces: `CosmeticService.Init()` and `Apply(player)`, which clears and rebuilds everything on the current character and does nothing if there is no character.

- [ ] **Step 1:** Implement the `SetEquipped` handler as in spec Section 3, with a boolean check on `equipped`.
- [ ] **Step 2:** Implement `CosmeticService`. Call `Apply` on `CharacterAppearanceLoaded`, on `OnProfileLoaded`, and after `SetEquipped`. Keep the character's original `BodyColors` so unequipping restores them.
- [ ] **Step 3:** Play in Studio. Expected: each slot equips and unequips, items return after a respawn, and items appear on first spawn after rejoining.
- [ ] **Step 4:** Equip a second `Hat`-slot item through a temporary catalog entry, then remove it. Expected: it replaces the first.
- [ ] **Step 5:** With the user's OK, commit as `feat: add shop, inventory, and cosmetics`.

---

## Phase 4: Player UI

**Done when:** a new player can earn, buy, and equip without help, on desktop and in the phone emulator.

Keep the look simple and clean. Build UI in code with scale-based sizes, in a `ScreenGui` with `ResetOnSpawn = false`.

### Task 11: Client foundation and HUD

**Files:**
- Create: `src/Client/UI/Api.luau`, `src/Client/UI/Hud.luau`
- Modify: `src/Client/Main.client.luau`

**Interfaces:**
- Produces: `Api.call(name: string, ...any): string` wraps `InvokeServer` in `pcall` and returns a result code, or `"CallFailed"` on error.
- Produces: `Api.state(): PlayerState?` and `Api.onState(callback)`. Screens update only from here.
- Produces: `Api.bindButton(button, label: string, action: () -> string)` disables the button during the request, shows the result, and shows "Try again" on `"CallFailed"`.

- [ ] **Step 1:** Implement `Api` and connect `StateChanged`.
- [ ] **Step 2:** Implement `Hud`: the balance, plus buttons that open the Shop, Inventory, and Stress Test panels.
- [ ] **Step 3:** Play in Studio. Expected: the balance updates on pickup with no client-side arithmetic.

### Task 12: Shop screen

**Files:**
- Create: `src/Client/UI/ShopPanel.luau`

- [ ] **Step 1:** Implement the panel from `Catalog.Items`: name, price, and a buy button using `Api.bindButton`. Owned items show "Owned" from state.
- [ ] **Step 2:** Play in Studio. Expected: buying shows the server's result, and the balance changes only after `StateChanged`.

### Task 13: Inventory screen and phone pass

**Files:**
- Create: `src/Client/UI/InventoryPanel.luau`

- [ ] **Step 1:** Implement owned items with equip and unequip buttons.
- [ ] **Step 2:** In Studio's device emulator, use a phone at both orientations. Fix anything off-screen or too small to tap.
- [ ] **Step 3:** Have someone who hasn't seen the game earn, buy, and equip, or walk through it as a new player.
- [ ] **Step 4:** With the user's OK, commit as `feat: add player UI`.

---

## Phase 5: Stress Test panel

**Done when:** every panel test works, and the panel can't give anyone an advantage.

### Task 14: Demo service

**Files:**
- Create: `src/Server/Services/DemoService.luau`
- Modify: `src/Server/Bootstrap.server.luau`

**Interfaces:**
- Consumes: `RequestGate.bind`, `DataTemplate.new`, `CosmeticService.Apply`, `PushState`

- [ ] **Step 1:** Bind `AddCoins` with `expectedArgs = nil` and a handler that only returns `Forbidden`.
- [ ] **Step 2:** Bind `ResetMyData` with `expectedArgs = 0`. It copies each `DataTemplate.new()` field into the profile's data, then calls `Apply` and `PushState`.
- [ ] **Step 3:** Confirm by reading the code that nothing else depends on `DemoService`, so an owner can delete it.

### Task 15: Cheat buttons and rejection feed

**Files:**
- Create: `src/Client/UI/StressPanel.luau`

- [ ] **Step 1:** Add the four Cheat buttons from spec Section 2, firing the real remotes through `Api.call`.
- [ ] **Step 2:** Add the rejection feed from `RejectionLogged`, the "exists only for the demo" note on `AddCoins`, the Reset button, the "Saving is off" banner when `SavingEnabled` is false, and short instructions for the Rejoin and Duplicate session tests.
- [ ] **Step 3:** Play in Studio. Expected: each button shows the spec's code. Turning off API access shows the banner.

### Task 16: Double-spend receipt

**Files:**
- Modify: `src/Client/UI/StressPanel.luau`

- [ ] **Step 1:** Add the burst: record the state, then `task.spawn` 50 `Api.call("BuyItem", id)` calls cycling through `Catalog.Items`, counting each returned code.
- [ ] **Step 2:** When all 50 return, wait 0.5 seconds and read the latest state. Show balance before and after, items bought, and counts by code.
- [ ] **Step 3:** Show PASS when coins spent equal the total price of newly owned items and the balance is at least 0. Otherwise show FAIL.
- [ ] **Step 4:** Play in Studio from a fresh reset. Expected: Crate Hat and Spark Trail bought, balance 0, `NotEnoughCoins` for Gold Color, most requests `RateLimited`, and PASS.

### Task 17: Security review

- [ ] **Step 1:** Review every remote and all server code for holes, and list anything that could embarrass the user in front of a client.
- [ ] **Step 2:** Confirm no yield exists in any path that checks then changes coins, including every function called along the way.
- [ ] **Step 3:** Fix what's found, with a test wherever a rule module changes.
- [ ] **Step 4:** With the user's OK, commit as `feat: add Stress Test panel`.

---

## Phase 6: Publish

**Done when:** the four tests pass in the live game, on desktop and on a phone.

### Task 18: Release prep

**Files:**
- Create: `docs/live-test-checklist.md`

- [ ] **Step 1:** Remove debug prints and temporary code. Confirm `DevCoins` is gone and search for leftover `print`.
- [ ] **Step 2:** Check place settings and write the checklist for all four Stress Tests on desktop and phone.
- [ ] **Step 3:** The user publishes the latest build, still private. **Stop before any step that changes public settings.**

### Task 19: Live test

- [ ] **Step 1:** The user runs the checklist in the private live game and reports each result.
- [ ] **Step 2:** Fix any live-only issues.
- [ ] **Step 3:** Run the Duplicate session test on two devices and film it. If it runs over budget, cut it and record that.
- [ ] **Step 4:** After every kept test passes, the user changes the experience to public themselves.
- [ ] **Step 5:** With the user's OK, commit as `chore: prepare live release`.

---

## Phase 7: Package the portfolio

**Done when:** a stranger can understand what you built within a minute.

### Task 20: README and integration guide

**Files:**
- Create: `README.md`

- [ ] **Step 1:** Write the README: demo link and clip first, then the problem it solves, architecture, security decisions, and how to add it to an existing game by deleting `DemoService.luau` and the Stress Test panel.
- [ ] **Step 2:** Check each claim against test results. Describe the crash case as design reasoning, and omit the Duplicate session test if it was cut.

### Task 21: Clip and public repo

- [ ] **Step 1:** Write a shot list for a clip of 60 seconds or less that shows results in the first 10 seconds. The user records it.
- [ ] **Step 2:** Add the clip link to the README.
- [ ] **Step 3:** Before the repo goes public, confirm no private files or personal data are in it or its history, and that ProfileStore's license is respected.
- [ ] **Step 4:** With the user's OK, commit as `docs: add README and portfolio details`. The user makes the repo public.
