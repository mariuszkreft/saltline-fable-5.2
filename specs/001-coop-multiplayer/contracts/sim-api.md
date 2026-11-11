# Contract — sim API seams

Frozen after G1. These are the only cross-slice symbols. A slice may add to its own modules freely,
but changing a signature here is a contract change and needs the orchestrator.

Build order is filename order inside one IIFE: `src/00-vendor.js`, `src/05-shared.js`,
`src/10-config.js`, `src/20-world/*`, `src/30-sim/*`, `src/40-net/*`, `src/50-view/*`, `src/90-flow.js`,
`src/99-boot.js`. Lower numbers may be referenced by higher ones; never the reverse.

## Context object `i`

`i` is the single runtime bag, as today. Multiplayer adds:

```js
i.players      // Map<number, Player> — id → player, server and client
i.localId      // number|null — the local player's id (client only)
i.player       // getter → i.players.get(i.localId) — keeps today's call sites alive
i.net          // NetClient (client) | Room (server) | null (solo)
i.tick         // number — authoritative sim tick
i.isServer     // boolean
i.inputs       // Map<number, Input> — server: per-player input state
```

## `src/sim/player.js` — factory, no camera

```js
createPlayer(i, { id, spawn, yaw }) -> Player
Player.update(dt, input)        // pure sim: look already folded in, no i.camera writes
Player.reset(spawn)             // per-player spawn, not level.playerStart
Player.damage(amount, fromPos)
Player.down() / Player.respawn()
```

View-only state (`bob`, `shake` offsets, recoil apply, FOV) moves to `src/view/camera.js`, which reads
`Player` and writes `i.camera`. `Player.baseFov` stays in sim.

## `src/sim/targeting.js`

```js
pickTarget(i, enemy) -> Player|null     // nearest visible alive player, sticky ≤ 0.4 s
```

`enemies.think` calls it instead of `i.player`; `enemyShot` returns the hit `Player` (or null) so the
caller applies damage.

## `src/sim/objectives.js`

```js
cutTick(i, clamps)              // per-relay additive progress, decay, completion events
nearestRelayFor(i, player) -> Relay|null
extractionState(i) -> { ok, missing }
```

## `src/net/protocol.js`

`encode/decode` for every message in `contracts/protocol.md`, `PROTO_VERSION`, and `quant/dequant`.
No DOM, no three.js import order assumptions, usable from a headless test.

## `src/net/server.js`

```js
createRoom(i, code) -> Room
Room.add(client) -> Player|null
Room.remove(id)
Room.stepInput(id, decodedInput)     // buffers input for the next tick
Room.broadcastEvents(tickEvents)     // drains i.events into `ev` frames
Room.snapshotFor(id) -> ArrayBuffer
```

## `src/net/client.js`

```js
createNetClient(i, { url, token }) -> NetClient
NetClient.send(input)                // 30 Hz, drops when the socket is not open
NetClient.onSnapshot(fn) / onWelcome(fn) / onEvent(fn)
NetClient.reconcile(state)           // server pose + unacked input replay
NetClient.predict(dt)                // local player only
```

## `src/net/interp.js`

`push(entityId, tick, pose)`, `sample(entityId, renderTick) -> pose|null`, `snap(entityId)`.

## `src/view/camera.js`

`follow(i, player, dt)` — writes `i.camera` position/rotation/fov from the player's view state;
`snap()` after respawn.

## `src/view/hud-mp.js`

`showTeam(players)`, `setDowned(secs)`, `setRespawn(secs)`, `teammateMarker(player)` — all additive to
today's `hud` API, which keeps its signature.

## Rules

- Sim modules never touch the DOM; view modules never write sim state.
- Every module gets its stub in `src/05-shared.js` (`dr`) so the headless server boots without view.
- `?solo=1` must not install a `NetClient`.