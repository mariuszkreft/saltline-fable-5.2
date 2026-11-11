# Feature 001 — Saltline co-op multiplayer

Feature: `001-coop-multiplayer`
Track: standard (G0 `multiplayer-co-op-for-saltline-extract-t-502570`)
Sources: `PLAN-MULTIPLAYER.md`, `specs/001-coop-multiplayer/contracts/`

## Why

Saltline is a one-player browser FPS in a single 1.4 MB `index.html`: cut three uplink relays in a
rainy container port while drones and robot dogs hunt you, then reach the boat. The objective chain
and the wave pacing are built for a squad, but only one person can play. Co-op is the cheapest real
multiplayer: same world, same goals, more hands.

## What a user can do afterwards

Two to four people open the same URL, one types a room code, the others fold in, and they cut the
relays together against a scaled-up enemy budget and leave on the boat as a team — from separate
machines, over the internet, without a game server per player. One person alone still gets exactly
today's game.

## Actors & surfaces

- **Player** — a browser tab, mouse/keyboard, touch or gamepad.
- **Room** — 2–4 players, 4-character code, drop-in allowed, no accounts.
- **Server** — one Node process per room-set, authoritative, headless.
- Surfaces: the title/lobby screen, the in-game HUD (squad readout, teammate markers), the death and
  extraction screens.

## Requirements

### Session

- **FR-001** A player creates a room and is shown a 4-character code (unambiguous alphabet: no
  `O/0`, `I/1`, lowercase folded).
- **FR-002** A player joins by typing the code, or by opening `?room=<CODE>`; an unknown or full room
  answers with a stated reason and stays on the lobby.
- **FR-003** A player may drop in at any time while the run is `playing`; they spawn at the current
  team point with 2 s invulnerability.
- **FR-004** A dropped socket keeps the player's slot for 60 s; rejoining with the same token resumes
  the same player (position, health, ammo). After 60 s the slot is free.
- **FR-005** Leaving never ends the run for the others; the run ends only on team extraction.

### Movement and view

- **FR-006** The local player's own movement is predicted and feels identical to solo at 0 ms, and
  converges on the server position within 250 ms after a 120 ms artificial delay plus 3 % loss.
- **FR-007** Remote players render interpolated ~100 ms in the past, with a rig that shows stance
  (stand/crouch/ADS), yaw and a muzzle flash.
- **FR-008** A reconnect or a teleport (respawn) snaps without interpolation, never sliding through
  walls.

### Combat

- **FR-009** Shots are resolved on the server against enemy capsules rewound by the sender's
  measured latency (clamped 0–200 ms).
- **FR-010** Damage, kills, ammo and reloads are server state; a client never decides a hit.
- **FR-011** Enemies pick the nearest visible alive player as their target and re-evaluate about every
  0.4 s; a target that dies or breaks line of sight drops to `search`.

### Objective

- **FR-012** Relay cut progress is shared per relay and additive: every player holding interact
  contributes `dt/cutSeconds`, so two cutters take about half the time; progress decays when nobody
  holds.
- **FR-013** Wave composition scales with the player count at spawn time (`× (0.6 + 0.4·n)` on gull
  and hound counts, `maxAlive` and enemy tokens), and the pursuit phase scales the same way.
- **FR-014** Extraction requires all relays cut **and** every alive player inside the boat radius;
  otherwise the boat hint names what is missing.

### Death

- **FR-015** A player at 0 health goes down for 6 s, then respawns at the boat or the last relay,
  whichever is nearer, with 2 s invulnerability and full health.
- **FR-016** The squad HUD shows each teammate's health, and a downed teammate appears as a marker on
  the compass.

### Authority and data

- **FR-017** The server owns health, ammo, relay progress, waves, enemy state and the run state
  machine; the client's role is input and presentation.
- **FR-018** Snapshots stay within the byte budget in `contracts/protocol.md` §5 and are
  interest-limited around each receiver.
- **FR-019** Radio lines, warnings and the objective text arrive as events; unchanged call sites in
  `fx`, `audio` and `hud` consume them.

### Compatibility

- **FR-020** `?solo=1` and the bare URL run today's single-player path with no server; the build
  output stays one self-contained `index.html`.
- **FR-021** Solo simulation is trace-identical to the pre-change build for a recorded input tape
  (positions, health, relay timers within 1e-6).

## Non-goals

PvP, matchmaking, accounts, persistence, host migration, voice, anti-cheat beyond server authority,
more than one level.

## Success criteria

- **SC-001** Four bot clients complete a full run (3 relays, extraction) on the dev server without a
  desync or a snapshot over budget.
- **SC-002** Solo parity eval green after every slice.
- **SC-003** Per-player downstream p95 ≤ 40 KB/s with four players and ten live enemies.

## Open questions

See `.m2herd/overview.json` `open_questions` — the ones that change a slice are mirrored in its
task's *Notes*.