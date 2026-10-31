# Shoot an Egg!

(Formerly "Slingshot an Egg!"; the code still uses "Slingshot" in internal names such as `SlingshotLevel`, so saves keep working.)

A Roblox game: shoot mystery eggs from a bow down a lane of 8 zones. The farther an egg lands, the rarer the pet that hatches. Pets live on your plot in the hub and earn coins, which buy a stronger bow.

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
| `src/shared` | ReplicatedStorage.Shared | `Config` (all tuning numbers), `Pets` (the 56 pets), `Economy` (prices), charge meter math, lane geometry, bow and pet models, network events |
| `src/server` | ServerScriptService.Server | Map builder, plots and pedestals, launching, hatching, coins and shops, saving |
| `src/client` | StarterPlayerScripts.Client | Launch button and meter, hatch reveal, coin counter and notices, Shop and Index menus, hint line |

To change zones, drop rates, pet earnings, prices, launch power, or the bow and egg tiers, edit `src/shared/Config.luau`.

## Using your own models

Everything is drawn from simple parts by default. To swap in a real model, put it in a folder in ReplicatedStorage in Studio (Rojo leaves these folders alone). Names must match (spaces, underscores and capitals don't matter, so `Golden_Egg` counts as `Golden Egg`). Scripts inside a model are removed when it's used, so free models can't run code. Anything without a model keeps the built-in look, so you can add them one at a time.

| Folder in ReplicatedStorage | Put in it | Named like | Notes |
| --- | --- | --- | --- |
| `BowModels` | a **mesh** (MeshPart, or the Model the 3D Importer makes) or a **Tool** with a part called `Handle` | the tier in `Config.Slingshots`, e.g. `Iron Bow` | a mesh replaces only the bow, and the game adds the drawing string and nock; a Tool replaces everything (name its nock `Pouch`) |
| `EggModels` | a **mesh** (MeshPart, or the importer's Model) | the tier in `Config.Eggs`, e.g. `Golden Egg` | sized to about 4 studs wide and 5 tall |
| `PetModels` | a **Model** | the pet in `src/shared/Pets.luau`, e.g. `Puddle Frog` | front facing -Z (Studio's front); any size, it's scaled to pet height |
| `StandModels` | a **Model** or a mesh | the shop title in `src/shared/Shops.luau`: `Bow Shop`, `Egg Shop`, `Rebirth` | front facing -Z; it's stood on the floor by its lowest point |

Textures: the built-in stands use the Wood and Fabric materials, so a custom material set as an override in the Material Manager (Wood, Fabric, Grass, ...) restyles them everywhere at once.

## Models made in Blender

`models/` has ready-made models for all 12 bows, all 8 eggs and the 3 shop stands, each an `.fbx` with its texture inside (the texture is also next to it as a `.png`). See `models/*/previews.png` for what they look like.

> The 12 bows and the Bow Shop stand are designed in `blender/bows.py` and `blender/stands.py` but not built yet, so `models/bows` doesn't exist yet. To build them, run `python blender/build.py bows` and then `python blender/build.py stands` (needs `pip install bpy`). Until then the game uses its built-in bow.

To use them:

1. In Studio, make three folders in **ReplicatedStorage**: `BowModels`, `EggModels` and `StandModels`.
2. Click **Import 3D** (Home tab, or File > Import 3D) and pick the `.fbx` files from `models/bows`. Leave the import settings as they are and click **Import**. The models appear in the Workspace, named after their files.
3. Drag them into `BowModels`.
4. Do the same for `models/eggs` into `EggModels` and `models/stands` into `StandModels`.
5. Press **Play**.

You don't need to resize or move anything: the game sizes and places each one from `src/shared/MeshSizes.luau`. If a model shows up white, its texture didn't come in: upload its `.png` (Asset Manager, Bulk Import) and paste the image id into the MeshPart's **TextureID**. If a stand faces the wall, move it to the Workspace, turn it around (rotate 180 degrees), and drag it back into `StandModels`.

The models are made by Python scripts in `blender/`, so they can be changed and rebuilt: edit a design in `blender/bows.py`, `blender/eggs.py` or `blender/stands.py`, then run `blender --background --python blender/build.py` (made with Blender 5.2). That rebuilds the files in `models/` and `src/shared/MeshSizes.luau`; import the changed ones again.

## Using your own bow animation

By default the arms are posed from code while charging and launching (`src/client/PoseController.client.luau`). To use your own instead, make them in Studio's Animation Editor, publish them from the account that owns the game, and put the ids in `Config.Slingshot`: `ChargeAnimationId` (set to Looping, plays while the button is held) and `LaunchAnimationId` (plays once on release).

## Robux shop

The Shop button opens the Robux shop, set up in `Config.RobuxShop`. To make an item buyable, create it on the [Creator Dashboard](https://create.roblox.com/dashboard/creations) (your experience, then Monetization, then Passes or Developer Products), and paste its id into `Id`. Items with `Id = 0` show "Coming soon". Working now: 2x Luck and VIP (passes) and the two coin packs (products). Auto-Launch and Extra Pedestals are listed but not built yet.

## Saving in Studio

Progress is saved with DataStores. To test saving in Studio, turn on **Game Settings > Security > Enable Studio Access to API Services** (the place must be published). Without it the game still runs, it just starts fresh each time.

## Build progress

- [x] 1. Map built from code: studded hub with walls, 4 fenced plots, shop stands, walled 8-zone lane
- [x] 2. Slingshot item, charge meter with 6 stages, launch, landing zone
- [x] 3. Hatching with the drop rates and mutations, pets on pedestals, coins
- [x] 4. Saving player data, offline coins
- [x] 5. Shops in the hub (stand in a shop's circle to open it): 12 bows, 8 eggs with Luck up to 1000x, rebirth; pedestal buying; Robux shop
- [ ] 6. Animations, effects and real art (first pass done: bow draw and launch pose, hatch, beam, confetti, coin pops, pet bounce)
