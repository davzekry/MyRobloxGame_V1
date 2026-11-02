# Live Test Checklist

Run this in the published game, still private, before making it public. Studio can't prove live saving or session handoff, so these results are what the README is allowed to claim.

## Before you start

- [x] Publish the latest build from Studio: **File → Publish to Roblox**. Keep the experience **private**.
- [ ] In **Game Settings → Basic Info** (or **Places**), confirm **Computer** and **Phone** are allowed devices.
- [x] Join from the Roblox app or website, not from Studio.

The live game uses its own data store (`PlayerData_v1`), so your first join starts at 250 coins with no items.

## Desktop

| # | Test | Steps | Pass when | Result |
|---|---|---|---|---|
| 1 | Loads | Join the game | Balance shows 250 coins, and the Stress Test panel shows no "Saving is off" banner | Pass |
| 2 | Pickups | Collect two coins, wait 15 seconds near one | Balance rises by 10 each time, and the coin comes back | Pass |
| 3 | Rejoin | Buy the Crate Hat and equip it, leave the game, wait 30 seconds, and join again | The hat is on your character, the Shop says Owned, and the balance is the same as when you left | Pass |
| 4 | Cheat | Press Run on all four cheat tests | Invalid request, Unknown item, Invalid request, Refused, and all four appear under Rejected requests | Pass |
| 5 | Double-spend | Reset my data, then Run the 50-buy test | Receipt says PASS: 250 to 0, Crate Hat and Spark Trail bought, Gold Color refused | Pass |

## Phone

| # | Test | Steps | Pass when | Result |
|---|---|---|---|---|
| 6 | Layout | Join on a phone, held upright, then sideways | All four top buttons fit, and every panel opens, scrolls, and closes | Pass |
| 7 | Buy and equip | Reset my data, collect coins if needed, buy and equip an item with the screens only | It works without help, and the item appears | Pass |
| 8 | Cheat and receipt | Repeat tests 4 and 5 | Same results as on desktop | Pass |

## Duplicate session (film this)

| # | Test | Steps | Pass when | Result |
|---|---|---|---|---|
| 9 | Second device | Join on desktop and note your balance and items. Then join the same game on your phone with the same account | Desktop is disconnected, and the phone shows the same balance and items | Pass |
| 10 | Changes follow you | On the phone, buy or equip something, then leave. Join again on desktop | Desktop shows the phone's change | Pass |

If test 9 or 10 runs over budget, cut it, record that here, and don't claim it in the README.

## Results

- Date tested: 2026-11-02, all 10 tests reported passing by the tester
- Build published at:
- Anything that failed, and what was fixed: nothing failed

Only make the game public after every test you're keeping passes on desktop and phone.
