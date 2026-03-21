# CLAUDE.md — Blip Game Server

## What This Project Is

Blip is a Roblox-like voxel game platform. This repo contains the full stack:

- **C++ WebSocket game server** — runs Lua game worlds, handles player connections (port 80)
- **Go scheduler** — orchestrates game server Docker containers across regions (EU, US, SG)
- **Hub HTTP service** — player/game management API
- **Supporting services** — nginx proxy, ScyllaDB, Discord bot, WASM server, file server

The game server is the core component. It accepts WebSocket connections, executes Lua scripts in a sandboxed Luau VM, and manages multiplayer game state.

## Architecture

```
Client (WebSocket) → Game Server (C++ binary)
                         ↕
                    Hub API (Go/HTTP)
                         ↕
                    ScyllaDB / Mongo
```

### Game Server Binary

- **Language:** C++17 (compiled with gcc or clang)
- **Build system:** CMake + Ninja
- **Runtime:** Listens on port 80 via libwebsockets, 3 threads (game, network I/O, loading)
- **Scripting:** Luau (Lua VM by Roblox)
- **Binary:** `gameserver-build/gameserver`

### Key Directories

```
core/                    → C voxel engine (blocks, chunks, cameras, math)
common/VXGameServer/     → C++ game server entry point + WebSocket handling
common/VXFramework/      → Game framework (rendering, config, UI, animation)
common/VXLuaSandbox/     → Lua scripting sandbox (78 files)
common/VXNetworking/     → Network layer (Hub client, game messages, latency)
deps/                    → Prebuilt libraries and xptools
  xptools/               → Cross-platform utilities (WebSocket, HTTP, crypto, threading)
  libluau/_active_/      → Luau VM (prebuilt static library)
  libpng/_active_/       → PNG library (prebuilt static library)
  libssl/                → OpenSSL (prebuilt)
  libwebsockets/         → WebSocket protocol (prebuilt)
  libz/                  → Compression (prebuilt)
  bgfx/                  → Graphics library headers
servers/                 → Docker compose, scheduler, deployment configs
go/cu.bzh/scheduler/     → Go scheduler (manages Docker containers)
```

## How to Build the Game Server

### Prerequisites

- cmake 3.20+, ninja, gcc 11+ (or clang)
- git (to fetch Luau and libpng sources if prebuilts are missing)

### One-Command Build

```bash
./build-gameserver.sh
```

This script:
1. Checks prerequisites
2. Builds libluau from source if `deps/libluau/_active_/` is missing
3. Builds libpng from source if `deps/libpng/_active_/` is missing
4. Compiles the game server via cmake + ninja
5. Outputs binary to `gameserver-build/gameserver`

For a debug build: `./build-gameserver.sh --debug`

### Manual Build

```bash
export CUBZH_TARGETARCH=amd64
cmake -S common/VXGameServer -B gameserver-build -DCMAKE_BUILD_TYPE=Release -G Ninja
ninja -C gameserver-build -j$(nproc)
```

### Running the Server

```bash
HOSTNAME=$(hostname) ./gameserver-build/gameserver <mode> <worldID> <serverIDPrefix> <authToken> [maxPlayers]
```

Arguments:
- `mode`: `dev` (script editing) or `play` (read-only)
- `worldID`: UUID of the game world
- `serverIDPrefix`: region prefix like `eu-1-`, `us-1-`, `sg-1-`
- `authToken`: Hub API authentication token
- `maxPlayers`: optional, defaults to 8

Example:
```bash
HOSTNAME=$(hostname) ./gameserver-build/gameserver dev abc123-world-uuid eu-1- my-hub-token 8
```

The server connects to `api.cu.bzh:443` by default. Override via `config.json` in the working directory.

## Local Development Stack

### Quick Start — Prison Escape world

```bash
docker compose -f docker-compose.local.yml up
```

This starts two containers:
1. **fake-hub** (port 10083) — minimal Go HTTP server that acts as the Hub API
2. **gameserver** (port 8080→80) — C++ game server in `dev` mode, world `prison-escape-local`

The game server fetches `worlds/prison_escape/world.lua` from fake-hub at startup, builds the world,
and waits for WebSocket client connections on `ws://localhost:8080`.

### Smoke Test (no client needed)

```bash
docker build -t blip-prison-escape -f Dockerfile.gameserver .
docker run --rm -e HOSTNAME=docker-local blip-prison-escape
```

Runs `--local-script` mode: loads and executes the Lua world, prints output, then exits in ~3 seconds.
No WebSocket port is opened in this mode — use the docker-compose stack to connect a real client.

### Adding a New World

1. Drop a `world.lua` in `worlds/<name>/`
2. In `docker-compose.local.yml` update:
   - `WORLD_LUA_PATH`: `/worlds/<name>/world.lua`
   - `WORLD_ID`: `<name>-local`
   - `command:` worldID arg: `<name>-local`
3. `docker compose -f docker-compose.local.yml up --build`

---

## Fixes Applied (March 2025 – March 2026)

The original build was broken. Here's what was fixed:

### CMakeLists.txt (`common/VXGameServer/CMakeLists.txt`)
- **Compiler fallback:** Was hardcoded to `clang/clang++`. Now auto-detects and falls back to `gcc/g++`.
- **Out-of-source builds:** Changed `CMAKE_CURRENT_BINARY_DIR` to `CMAKE_CURRENT_SOURCE_DIR` for repo root path resolution.
- **Arch auto-detection:** `CUBZH_TARGETARCH` env var now auto-detects from `CMAKE_SYSTEM_PROCESSOR` instead of requiring Docker.

### xptools.cmake (`common/VXGameServer/xptools.cmake`)
- Bumped `cmake_minimum_required` from 3.4.1 to 3.10 (cmake 4.x compatibility).
- Same `BINARY_DIR` → `SOURCE_DIR` path fix.

### main.cpp (`common/VXGameServer/main.cpp`)
- **Null safety:** `std::getenv("HOSTNAME")` returns NULL when unset, which crashed `std::string()`. Now checks for null first.
- **API fix:** `Config::load()` was called with a file path argument, but the method takes no arguments (hardcodes `"config.json"`).

### VXCodeEditor.cpp (`common/VXFramework/VXCodeEditor.cpp`)
- **Luau API compatibility:** `Lexer::getOffset()` doesn't exist in current Luau. Replaced with `token.data` pointer arithmetic + `token.getLength()`.

### Missing Dependencies
- Built **libluau 0.661** from source (merged Ast, Compiler, VM, Analysis, CodeGen, EqSat, Config, CLI into single `.a`)
- Built **libpng 1.6.47** from source
- Created `deps/libluau/_active_/` and `deps/libpng/_active_/` directory structures

### main.cpp — additional fixes (March 2026)
- **`--local-script` mode added:** reads a Lua file from disk, creates a local `GameServer`, and runs it without a WebSocket port. Used for smoke testing.
- **Hub URL override:** `parseArgumentsAndLoadConfiguration` now reads `Config::apiHost()` (from `config.json`) instead of the hardcoded `HUB_API_URL` macro when constructing the `HubPrivateClient` address. This lets `local-config.json` redirect the game server to `fake-hub`.

### VXGameServer.cpp — threading fixes (March 2026)
- **Local mode:** `start()` now joins all three threads instead of returning immediately (was causing use-after-free / segfault when `main()` destroyed `gameServer` while threads were still running).
- **`stop()` guards:** Added `joinable()` checks before each `join()` to prevent double-join if `stop()` is called after `start()` already joined.
- **Fast shutdown:** Local mode constructor sets `_shutDownTimer(3000)` (3 s) instead of `SHUTDOWN_DELAY` (30 s) so smoke tests exit quickly.

### worlds/prison_escape/world.lua — API fixes (March 2026)
- Replaced `LocalEvent`-based init (`if is_server then LocalEvent:Listen(...)`) with server sandbox API: `Server.OnStart`, `Server.OnPlayerJoin`, `Server.DidReceiveEvent`, `Server.Tick`.
- Fixed all 10 `MutableShape:AddBlock` calls: argument order is `(color, x, y, z)`, not `(x, y, z, color)`.

## Common Tasks for Claude Code

### "Fix a compilation error"
1. Run `ninja -C gameserver-build -j1 2>&1 | grep "error:"` to get the exact error
2. The most common issues are Luau API mismatches (check `deps/libluau/_active_/prebuilt/linux/x86_64/include/Luau/`)
3. After fixing, `ninja -C gameserver-build` will rebuild only changed files

### "Add a new Lua API function"
- Lua bindings are in `common/VXLuaSandbox/` (one file per API module)
- Register in the appropriate `lua_*.cpp` file
- The sandbox restricts what Lua code can access

### "Modify network protocol"
- Message types: `common/VXNetworking/VXGameMessage.hpp`
- Client handler: `common/VXGameServer/VXConnectionHandlerJoin.cpp`
- Hub communication: `common/VXNetworking/VXHubPrivateClient.cpp`

### "Deploy to production"
- Production uses Docker Swarm (see `servers/docker-compose-prod.yml`)
- Three regions: EU (141.94.97.66), US (51.222.244.45), SG (15.235.181.168)
- Scheduler at `go/cu.bzh/scheduler/main.go` manages container lifecycle

### "Run with a local Hub (fake-hub)"
- Use `docker-compose.local.yml` — spins up `fake-hub` (Go) + `gameserver` (C++) together
- `fake-hub` listens on port 10083, serves the world script and ACKs heartbeats
- `gameserver` connects to `fake-hub`, loads the Lua world, and opens a WebSocket on port 8080

```bash
docker compose -f docker-compose.local.yml up      # start
docker compose -f docker-compose.local.yml down     # stop
docker compose -f docker-compose.local.yml build    # rebuild after code changes
```

Key files:
- `fake-hub/main.go` — minimal Go Hub stub
- `Dockerfile.fake-hub` — builds the fake-hub binary
- `local-config.json` — mounted at `/bundle/config.json` inside gameserver; sets `APIHost` to `http://fake-hub:10083`

Client connection info when the stack is running:
- Game server WebSocket: `ws://localhost:8080`
- Hub (for world lookup): `GET http://localhost:10083/worlds/prison-escape-local/server/any-tag`
  → returns `{"server":{"address":"localhost:8080","players":N,"maxPlayers":8}}`

To run a different world: change `WORLD_LUA_PATH` and `WORLD_ID` env vars in `docker-compose.local.yml`,
and update the `command:` worldID argument to match.

## Build Dependency Graph

```
gameserver (executable)
├── libz.a (compression)
├── libluau.a (Luau VM — Ast + Compiler + VM + Analysis + CodeGen + EqSat + Config + CLI)
├── libpng.a (PNG images)
├── libssl.a + libcrypto.a (TLS/crypto)
├── libwebsockets.a (WebSocket protocol)
├── pthread, dl, m (system)
└── Static libraries (compiled from source):
    ├── vx — VXFramework + VXNetworking + VXGameServer sources
    ├── sbs — VXLuaSandbox (Lua scripting environment)
    ├── cubzh_core — Core voxel engine (C)
    └── xptools — Cross-platform utilities (WebSocket server, HTTP, crypto, filesystem)
```

## Config Constants

- `SHUTDOWN_DELAY`: 30,000ms (time before server shuts down after last player leaves)
- `HUB_UPDATE_DELAY`: 20,000ms (heartbeat interval to Hub)
- `FRAME_DURATION_MS`: 50ms (20 FPS game tick)
- `LUA_DEFAULT_MEMORY_USAGE_LIMIT_FOR_GAMESERVER`: 100MB
- Default max players: 8
