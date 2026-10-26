# Slingshot an Egg!

A Roblox game: launch mystery eggs from a slingshot down a lane of 8 zones. The farther an egg lands, the rarer the pet that hatches. Pets live on your plot in the hub and earn coins, which buy a stronger slingshot.

The full game design is in the project's design doc.

## Setup (one time)

The code lives in this repo and is synced into Roblox Studio with [Rojo](https://rojo.space).

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder. That installs the Rojo version pinned in `rokit.toml`.
2. Install the Rojo plugin for Studio: run `rojo plugin install` (or get "Rojo" from the Creator Store).
3. Start the sync server: `rojo serve`
4. Open your place in Studio, open the **Rojo** plugin tab, and click **Connect**.

The scripts now appear in Studio and update every time a file changes. Press **Play** to test.

Set the place's **Max Players** to 4 (Game Settings, then Places), to match the 4 plots. Code can't change this setting.

## How the code is laid out

| Folder | Goes to | What's in it |
| --- | --- | --- |
| `src/shared` | ReplicatedStorage.Shared | `Config` (all tuning numbers), `Pets` (the 56 pets), `Economy` (prices), charge meter math, lane geometry, slingshot and pet models, network events |
| `src/server` | ServerScriptService.Server | Map builder, plots and pedestals, launching, hatching, coins and shops, saving |
| `src/client` | StarterPlayerScripts.Client | Launch button and meter, hatch reveal, coin counter and notices, Shop and Index menus, hint line |

To change zones, drop rates, pet earnings, prices, launch power, or the slingshot and egg tiers, edit `src/shared/Config.luau`.

## Using your own slingshot and egg models

Every slingshot and egg tier is drawn from parts by default. To swap in a real model, put it in Studio by hand (Rojo leaves these folders alone):

- **Slingshots:** make a Folder called `SlingshotModels` in ReplicatedStorage. Put a **Tool** in it named exactly like the tier in `Config.Slingshots` (for example `Iron Slingshot`), with a part called `Handle`. That model is then held in the hand and shown in the Shop.
- **Eggs:** make a Folder called `EggModels` in ReplicatedStorage. Put a **MeshPart** in it named exactly like the tier in `Config.Eggs` (for example `Golden Egg`), about 4 studs wide and 5 tall. That egg is then launched and shown in the Shop.

Tiers without a model keep the built-in look, so you can add them one at a time.

## Using your own slingshot animation

By default the arms are posed from code while charging and launching (`src/client/PoseController.client.luau`). To use your own instead, make them in Studio's Animation Editor, publish them from the account that owns the game, and put the ids in `Config.Slingshot`: `ChargeAnimationId` (set to Looping, plays while the button is held) and `LaunchAnimationId` (plays once on release).

## Saving in Studio

Progress is saved with DataStores. To test saving in Studio, turn on **Game Settings > Security > Enable Studio Access to API Services** (the place must be published). Without it the game still runs, it just starts fresh each time.

## Build progress

- [x] 1. Map built from code: studded hub with walls, 4 fenced plots, shop stands, walled 8-zone lane
- [x] 2. Slingshot item, charge meter with 6 stages, launch, landing zone
- [x] 3. Hatching with the drop rates and mutations, pets on pedestals, coins
- [x] 4. Saving player data, offline coins
- [x] 5. Shop menu (12 slingshots, 8 eggs, Luck, rebirth), pedestal buying
- [ ] 6. Animations, effects and real art (first pass done: slingshot pull and launch pose, hatch, beam, confetti, coin pops, pet bounce)
