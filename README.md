# Båtspillet 🚤

A gentle, exploration-focused 2D boat game for young children, built with
[LÖVE](https://love2d.org) (Love2D) 11.x. Sail between friendly ports, carry
cargo, earn gold, and discover islands. No combat, no failure, no rush.

Note - for those viewing this, this is a Norwegian language game!
---

## How to run

You already have LÖVE installed at `/Applications/love.app`. From the project
folder (`fespill/`, the one containing `main.lua`):

```bash
/Applications/love.app/Contents/MacOS/love .
```

Tip — make it short:

```bash
alias love='/Applications/love.app/Contents/MacOS/love'
love .            # run the game from the project folder
```

It starts in a resizable **window** for development. To launch in **fullscreen**
(what your child plays), open `src/config.lua` and set:

```lua
config.START_FULLSCREEN = true
```

You can always toggle fullscreen at runtime with **F11**.

---

## Controls

| Input                     | Action                                        |
|---------------------------|-----------------------------------------------|
| **Arrow keys / WASD**     | Steer the boat (gentle accel, slow turning)   |
| **Left click on water**   | Sail to that spot (auto-steer)                |
| **Right click + drag**    | Look around the map                           |
| **Mouse wheel**           | Zoom in / out                                 |
| **C**                     | Re-center the camera on the boat              |
| **SPACE (MELLOMROM)**     | Load / deliver cargo at a port                |
| **ESC**                   | Back to menu (saves first) / quit from menu   |

### Developer hotkeys

| Key   | Action                                              |
|-------|-----------------------------------------------------|
| **F5**  | Reload the current scene (quick restart)          |
| **F6**  | Reload data files (`boats.lua`, `ports.lua`)      |
| **F11** | Toggle fullscreen                                 |
| **M**   | Mute / unmute audio                               |

---

## How to play

1. From the menu, press **Enter** or click **"Seil ut!"**.
2. Sail to a port (steer with keys, or click where you want to go).
3. When close, the HUD says *"Trykk MELLOMROM"* — press **Space** to load cargo.
4. The cargo shows its destination port. Sail there and press **Space** to
   deliver it for **gold**.
5. Sail near the green islands to **discover** them.

Everything is forgiving: the boat never sinks, bounces softly off land, and
there's no timer or losing.

---

## Project layout

```
main.lua            love callbacks -> Game
conf.lua            window / module config (runs before the game)
src/
  game.lua          scene manager + state + save/load + dev hotkeys
  config.lua        ALL tuning numbers and colors (edit gameplay feel here)
  assets.lua        image loader (with code placeholders) + sound synthesis
  json.lua          tiny dependency-free JSON for the save file
  scenes/
    menu.lua        title screen
    world.lua       the playable scene (ties everything together)
  entities/
    boat.lua        player boat (movement, collision, draw)
    port.lua        a port (range check, placeholder art)
    island.lua      scenery + soft obstacle + discoverable landmark
  systems/
    iso.lua         2:1 isometric projection math + multi-tile footprints
    terrain.lua     procedural heightmap world (elevation, slopes, coasts)
    objects.lua     sprite-object layer: place art on single OR multiple tiles
    camera.lua      iso follow / drag / zoom camera, screen<->world
    cargo.lua       the pickup/deliver economy
  ui/
    hud.lua         coins, cargo, port prompts, toasts (screen space)
  data/
    boats.lua       boat definitions (add boats here, no code changes)
    ports.lua       port definitions (add ports here, no code changes)
assets/             drop in PNGs to replace placeholders (see assets/README.md)
save/savegame.json  illustrative default save (see note below)
```

## Where saves actually live

LÖVE sandboxes file writes. The real save is written to LÖVE's save directory,
**not** the `save/` folder in this repo:

```
~/Library/Application Support/LOVE/batspillet/savegame.json
```

The `save/savegame.json` checked into the repo is just an illustrative default.

---

## Extending the game

- **New boat or port?** Edit `src/data/boats.lua` / `src/data/ports.lua`, then
  press **F6** in-game to hot-reload. No code changes needed. Ports auto-snap to
  the nearest coastline and flatten the ground under themselves.
- **Reshape the world?** Edit `config.ISLANDS` (island domes), `config.WORLD_SEED`,
  `HILL_AMP`, `HILL_SCALE`, `COAST`, `MAX_LEVEL` in `src/config.lua`. F6 regenerates.
- **Change the feel** (speed, zoom, colors, pickup range)? Edit `src/config.lua`.
- **Add real art?** Drop PNGs into `assets/` — see `assets/README.md` for names
  (ground tiles, single-tile props, and multi-tile harbor sprites).

---

## Technical notes

- Targets LÖVE **11.x** (tested on 11.3)
- No external dependencies; physics, JSON, and audio are all hand-rolled and
  simple. `joystick` and `box2d physics` modules are disabled in `conf.lua`.
- Sound effects (coin, horn, delivery, bump), ocean ambience, and a looping
  90s-style chiptune are **synthesized at load** — there are no audio files.
