Create a complete Love2D project for a children's 2D boat game.  
Name of game: "Båtspillet" (my boy is Norwegian)

Target audience:
- 5 year old child, understands Norwegian
- Relaxed gameplay.
- Exploration and discovery focused.
- Very little punishment or failure.
- Simple controls.

Technical constraints:
- Must run on Love2D 11.x.
- Must be compatible with older Macs running macOS High Sierra.
- Performance should be excellent on older hardware.
- No external dependencies unless absolutely necessary.
- Code should be simple and maintainable.

Project goals:
- Fullscreen mode.
- Quick restart during development.
- Data-driven architecture.
- Easy for an AI coding assistant to extend.
- Easy for a non-game developer to understand.

Game concept:
The player controls a small boat sailing between ports and islands.

Core gameplay loop:
1. Sail between ports.
2. Pick up cargo or passengers.
3. Deliver them elsewhere.
4. Earn GOLD coins
5. Unlock bigger boats.
6. Discover new islands, maybe with procedurally generated maps. Maps can be isometric and in retro style like Civ 2 or Settlers or Sim City 2000

The world should feel friendly and colorful.

No combat for the initial version.

Avoid:
- Complex physics.
- Realistic simulation.
- Large frameworks.
- ECS architectures.
- Premature optimization.

Use a simple scene/state system.

Required project structure:

main.lua

src/
    game.lua
    config.lua

    scenes/
        menu.lua
        world.lua

    entities/
        boat.lua
        port.lua
        island.lua

    systems/
        camera.lua
        cargo.lua

    ui/
        hud.lua

    data/
        boats.lua
        ports.lua

assets/
    boats/
    ports/
    islands/
    ui/

save/
    savegame.json

Architecture requirements:

1. Scene management

Use a simple scene manager.

Scenes:
- Menu
- World

Each scene must expose:
- load()
- update(dt)
- draw()
- keypressed(key)

2. Data driven content

Boats must be defined in:

src/data/boats.lua

Ports must be defined in:

src/data/ports.lua

Game designers should be able to add content by editing data files without touching game logic.

Example boat data:

{
    id = "starter_boat",
    name = "Little Tug",
    speed = 120,
    capacity = 5,
    sprite = "boat1.png"
}

3. Entity pattern

Use simple Lua tables with methods.

Example:

Boat:new(...)
Boat:update(dt)
Boat:draw()

Avoid inheritance hierarchies.

4. Asset management

Create a central asset loader.

Assets should only be loaded once.

Example:

Assets.images.boat1
Assets.images.port1

Sounds as well and maybe some simple polyphonic music that would resemble something like from the 1990s, with boat horns generated, wave sounds, and so on

5. Save game support

Create a simple save system.

Store:
- coins
- unlocked boats
- discovered islands

Use JSON.

6. Development features

F5:
Reload current scene.

F6:
Reload game data files.

F11:
Toggle fullscreen.

ESC:
Return to menu.

7. Fullscreen startup

When played game should launch in fullscreen, but as I develop I'd probbaly want to run it in smaller window.

For fullscreen, determine resolution dynamically.

Use scaling so that artwork remains usable across resolutions.

8. Camera

Simple camera or isometric, using the mouse to drag up and down on the map, and maybe click to have the boat go to places.

No external libraries.

9. Placeholder art

Generate primitive placeholder graphics in code when image files are missing. Should look like sim City 2000 style.

The game must still run without assets and just placeholders so we know what sprites need
to be populated by pngs or whatever.

10. Child-friendly design

Movement should feel forgiving.

Boat should:
- Accelerate gently.
- Turn slowly.
- Never sink.
- Bounce lightly from obstacles.

Initial playable milestone:

Menu screen:
- Start Game

World:
- Ocean background
- One controllable boat
- Three ports
- Camera follow
- Simple cargo pickup and delivery
- Coin counter
- Fullscreen support

After generating the project structure, implement the complete initial playable milestone and explain how to run it on Love2D.

