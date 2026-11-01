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

To use them:

1. In Studio, make three folders in **ReplicatedStorage**: `BowModels`, `EggModels` and `StandModels`.
2. Click **Import 3D** (Home tab, or File > Import 3D) and pick the `.fbx` files from `models/bows`. Leave the import settings as they are and click **Import**. The models appear in the Workspace, named after their files.
3. Drag them into `BowModels`.
4. Do the same for `models/eggs` into `EggModels` and `models/stands` into `StandModels`.
5. Press **Play**.

You don't need to resize or move anything: the game sizes and places each one from `src/shared/MeshSizes.luau`. If a model shows up white, its texture didn't come in: upload its `.png` (Asset Manager, Bulk Import) and paste the image id into the MeshPart's **TextureID**. If a stand faces the wall, move it to the Workspace, turn it around (rotate 180 degrees), and drag it back into `StandModels`.

The models are made by Python scripts in `blender/`, so they can be changed and rebuilt: edit a design in `blender/bows.py`, `blender/eggs.py` or `blender/stands.py`, then run `blender --background --python blender/build.py` (made with Blender 5.2). That rebuilds the files in `models/` and `src/shared/MeshSizes.luau`; import the changed ones again.

## Bow animations

Shooting is a character animation that plays after you tap (`animations/BowShot1.rbxmx` and `animations/BowShot2.rbxmx`, made by `blender/bow_animation.py`). Rojo puts them in **ReplicatedStorage > BowAnimations**.

- While the meter bounces you just stand holding the bow. When you tap, the camera swings round to your side and one shot plays:
  - **BowShot1** (70%, 3 s): lift the bow, a slow smooth draw, a held breath, release, follow-through.
  - **BowShot2** (30%, 3.6 s): a low power stance, a heavy draw with a deep lean back, a big kick on the release and a full spin.
- The egg leaves at the animation's `Release` frame (`ReleaseAt` in `src/shared/ShotAnimations.luau`, which the script writes along with the chances). On a **Perfect** it freezes on its `Impact` frame for `Config.Charge.PerfectFreeze` seconds while the impact frames flash, and fades back to normal at `Done`.

In Studio they play without uploading (only for you, only in Studio). For the real game, upload them once:

1. In Studio, with Rojo connected, open **ReplicatedStorage > BowAnimations** in the Explorer.
2. Right-click **BowShot1** and choose **Save to Roblox**. Give it a name, pick the owner of the game (you, or the group), and click Save/Submit. Copy the number it shows (the asset id).
3. Do the same for **BowShot2**.
4. In `src/shared/Config.luau`, under `ShotAnimationIds`, set `BowShot1 = "rbxassetid://<id>"` and `BowShot2 = "rbxassetid://<id>"`.

If **Save to Roblox** isn't in the menu: **Avatar tab > Rig Builder > Block Rig** (R15), copy **BowShot1** into the new dummy, open **Avatar tab > Animation Editor**, click the dummy, then **... > Load** and pick it, then **... > Publish to Roblox**. Here you can also tweak the poses by hand before publishing. If you make your own shot in Blender or the Animation Editor instead, keep the same name (or add it to `blender/bow_animation.py`) and keep a `Release` marker where the string lets go, then set its `ReleaseAt`.

To change the shots in code, edit `blender/bow_animation.py` and run `python3 blender/bow_animation.py`, then upload again.

Without animations (a live game with no ids set), the arms are posed from code instead (`src/client/PoseController.client.luau`).

## Robux shop

The Shop button opens the Robux shop, set up in `Config.RobuxShop`. To make an item buyable, create it on the [Creator Dashboard](https://create.roblox.com/dashboard/creations) (your experience, then Monetization, then Passes or Developer Products), and paste its id into `Id`. Items with `Id = 0` show "Coming soon". Working now: 2x Luck and VIP (passes) and the two coin packs (products). Auto-Launch and Extra Pedestals are listed but not built yet.

The Shop shows a **Featured** section (big cards for items with `Featured = true`; the 2x Luck card has tiles showing how much more likely each rarity gets), then **Passes** and **Coins**. Coin packs have **Buy 1** and **Buy 3** buttons: for Buy 3, make a second developer product that gives three packs and paste its id into `Id3` (and its price into `Price3`). `Tag = "BEST VALUE"` (or any short text) puts a ribbon on a card's corner.

## Saving in Studio

Progress is saved with DataStores. To test saving in Studio, turn on **Game Settings > Security > Enable Studio Access to API Services** (the place must be published). Without it the game still runs, it just starts fresh each time.

## Build progress

- [x] 1. Map built from code: studded hub with walls, 4 fenced plots, shop stands, walled 8-zone lane
- [x] 2. Slingshot item, charge meter with 6 stages, launch, landing zone
- [x] 3. Hatching with the drop rates and mutations, pets on pedestals, coins
- [x] 4. Saving player data, offline coins
- [x] 5. Shops in the hub (stand in a shop's circle to open it): 12 bows, 8 eggs with Luck up to 1000x, rebirth; pedestal buying; Robux shop
- [ ] 6. Animations, effects and real art (done so far: bow draw and release animations with the shot camera and Perfect impact frames, hatch, beam, confetti, coin pops, pet bounce)
