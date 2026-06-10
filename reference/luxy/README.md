# Luxy reference scripts

Read-only reference material used while porting game logic into Alleral.

| File | Description |
|------|-------------|
| `script.obfuscated.lua` | Original obfuscated Luxy Hub script |
| `script.deobfuscated.lua` | Strings decrypted + formatted for reading |
| `kick_a_lucky_blox.obfuscated.lua` | [Luxy-Scripts Kick A Lucky Blox.lua](https://github.com/Omnie7/Luxy-Scripts/blob/main/Games/Kick%20A%20Lucky%20Blox.lua) |
| `kick_a_lucky_blox.deobfuscated.lua` | XOR string decode of the Kick script above |
| `analytics.obfuscated.lua` | Obfuscated Luxy analytics module (LuaObfuscator VM) |
| `analytics.deobfuscated.lua` | Reconstructed Tracker API reference |

These are **not** loaded by the loader. Do not execute them in-game.

Upstream Luxy repos by [Omnie7](https://github.com/Omnie7):

- [Luxy-Core](https://github.com/Omnie7/Luxy-Core) — `Data/KickBlox.luau`, analytics module
- [Luxy-Hub](https://github.com/Omnie7/Luxy-Hub) — UI library and place-id router
- [Luxy-Scripts](https://github.com/Omnie7/Luxy-Scripts) — per-game script payloads

Alleral uses Starlight (not LuxyHub UI) but follows the same `game:HttpGet` + `?nocache=` fetch pattern and vendors KickBlox data from Luxy-Core.

Kick-specific notes from Omnie7's obfuscated script:

- Game modules load via `pcall(require, ...)` — no separate `LuckyBlocksData`; pools live on `EntitiesData.LuckyBlocks`
- Remotes under `Shared.Packages.Network` with `ref_*` / `rev_*` fallbacks at `ReplicatedStorage` root
- `WeightsData` is found with `ReplicatedStorage:FindFirstChild("WeightsData", true)`
- KickBlox dropdown data from `Luxy-Core/Data/KickBlox.luau`
