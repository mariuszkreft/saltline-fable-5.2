# Saltline co-op multiplayer — the plan

Status: cut for the factory herd `herd-01` (see `.m2herd/herden/herd-01/`). Track: standard (G0
triaged, tier medium). This file is the human-readable plan; `specs/001-coop-multiplayer/` holds the
binding artifacts and `.m2herd/herden/herd-01/slices/` holds the worker tasks.

## 1. What we are building

Server-authoritative online co-op for **2–4 players** over the existing game: room codes, drop-in,
shared relay cutting at scaled difficulty, teammates visible on the HUD, downed/respawn, extraction
gated on the whole alive team.

**Not building:** PvP, matchmaking/accounts, persistence, host migration, voice, anti-cheat beyond
server authority.

**Hard constraint:** solo play must not regress. The shipped artifact stays one self-contained
`index.html`; `?solo=1` (and the bare URL) runs today's code path.

## 2. What the code gives us

`index.html` is 6,194 lines: CSS, then ~5.5k lines of bundled three.js, then ~270 minified lines of
game at 5928–6194. It is one IIFE, so scoping is shared and nothing has to be renamed to split it:
the split is **concatenation by slice boundary**, not an ESM rewrite.

The seam already exists:

| module | anchor | shape |
|---|---|---|
| `createInput` (`v_`) | 5928 | `{move, look, fire, ads, down(c), pressed(c)}` |
| `createPlayer` (`x_`) | 5928 | capsule sim, regen, death; **writes `i.camera`** |
| `createCombat` (`zv`) | 5928 | `playerShot`, `enemyShot`, `explode` |
| `createEnemies` (`Em`) | 6054 | 18 pooled agents, patrol/engage, tokens |
| `createWeapon` (`dm`) | 6054 | viewmodel + ammo, calls `combat.playerShot` |
| `createHud` (`hM`) | 6076 | DOM HUD, compass, markers |
| `mM` (flow) | 6189 | states, relay cut, waves, death/complete |
| boot + rAF loop | 6189 | per-module `update(dt)` |

`dr` (≈4180) is a stub table for `render/hud/audio/fx/weapon/enemies/mats` — the sim already runs
without presentation, which is what makes a headless server cheap.

Single-player hard-coding to remove: `i.player` (23 refs), the one `i.camera`, the one `i.input`, the
module-global `run` in `mM`, pointer-lock-loss ⇒ pause, one-player dead/complete flow.

## 3. Architecture

- One dedicated Node process owns the world at a fixed 60 Hz: real `physics`/`level`/`enemies`/
  `combat`/`flow`, stub `render/hud/audio/fx`.
- The player module becomes a factory instance per connection; the camera-follow part moves to
  `view/camera.js` so sim stops writing a camera.
- WebSocket for v1; inputs 30 Hz client→server, snapshots 20 Hz server→client, quantized and
  delta'd; discrete events multiplexed reliably and re-emitted into the client's `i.events` bus so
  `fx`/`audio`/`hud` need no changes.
- Client predicts its own movement with the real sim code and reconciles against server acks;
  remote players and enemies are interpolated 100 ms in the past; hit detection is server-side with
  ~120 ms enemy rewind.
- Enemies target the nearest visible alive player (re-evaluated ~0.4 s), never a global "the player".
- Relay progress is shared and additive (two cutters finish in ~1.2 s); waves scale with player count
  (`× (0.6 + 0.4·n)`), `maxAlive` and enemy tokens too.
- Death is per player: down → 6 s → respawn at the boat or last relay, 2 s invulnerable. Completion
  needs all relays cut plus every alive player inside the extraction radius.

## 4. Parallelisation

Phases are waves of at most four workers with **disjoint owned paths**. Wave 0 is a single gating
slice; no later slice starts before it is accepted.

| Wave | Slice | Owns |
|---|---|---|
| 0 | `p0-extract` | `src/**` skeleton, `tools/build.mjs`, `tools/parity.mjs`, seam stubs |
| 1 | `s1-proto` | `src/net/protocol.js`, `tools/proto-test.mjs` |
| 1 | `s3-sim-mp` | `src/sim/players.js`, `src/sim/targeting.js`, `src/sim/objectives.js` |
| 1 | `s5-view-camera` | `src/view/camera.js`, `src/view/remote-rig.js` |
| 1 | `s8-bots` | `tools/bot.js` |
| 2 | `s2-server` | `src/net/server.js`, `src/net/room.js`, `tools/serve.mjs` |
| 2 | `s4-client-net` | `src/net/client.js`, `src/net/interp.js` |
| 2 | `s6-hud-mp` | `src/view/hud-mp.js`, `src/ui/lobby.*` |
| 2 | `s7-evals` | `tools/evals/*`, `tools/soak.mjs` |
| 3 | `s9-lobby-flow` | `src/net/reconnect.js`, `src/ui/room-code.*` |
| 3 | `s10-budget` | `src/net/interest.js`, `tools/bandwidth.mjs` |
| 4 | `s11-docs` | `README.md`, `docs/multiplayer.md` |

Rules that make this safe: the build concatenates `src/` in filename order inside the original IIFE
wrapper, so no symbol is renamed and no slice may reorder files; shared files are named in exactly
one slice's task; everything talks through `contracts/protocol.md` and `contracts/sim-api.md`, which
are frozen after G1; solo parity is a frozen eval from wave 0 on, so any slice that breaks it goes
red immediately.

## 5. Gates

- G1 design review of `spec.md` + `plan.md` + `contracts/` — human approves.
- G2 cut check (`HERD-CUT.md`) — the cut above is what it reviews.
- G3 one frozen eval per acceptance criterion, drafted by a non-worker, red on the base sha.
- G4 per slice: evals green at the accepted sha **and** independent review clean.
- G5 merge on the human's go, wave by wave.

## 6. Budgets

Snapshot ≤ 2 KB with 4 players and 10 enemies; ≤ 40 KB/s per player down, ≤ 3 KB/s up; server tick
budget ≤ 6 ms p95 at 4 players; no regression of solo frame time beyond 3 %.