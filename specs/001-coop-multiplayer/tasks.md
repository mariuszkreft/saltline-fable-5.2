# Tasks — co-op multiplayer

`[P]` = own slice, parallel within its wave. Unmarked = gates the wave, becomes `stacked_on` for the
slices below it. One task = one worker session. Source of requirements: `spec.md` FR ids in brackets.

## Wave 0 — gating

- [ ] T000 Extract `index.html` into `src/` by function boundary; write `tools/build.mjs` (concat +
  inline, `--check`), `tools/parity.mjs`, `src/ui/game.css`, and the frozen stub seams for
  `player/combat/enemies/objectives/protocol/server/client/interp/camera/hud-mp` [FR-020, FR-021]
  → slice `p0-extract`

## Wave 1

- [P] T001 Codec + quantization + fixtures + `tools/proto-test.mjs` for every message in
  `contracts/protocol.md` §2–5 [FR-018] → slice `s1-proto`
- [P] T002 Per-player factory: `players` map, `localId`, `player` getter compatibility, per-player
  spawn, down/respawn [FR-003, FR-015, FR-017] → slice `s3-sim-mp`
- [P] T003 Enemy targeting hook `pickTarget`, sticky re-evaluation, `enemyShot` returns the hit player
  [FR-011] → slice `s3-sim-mp`
- [P] T004 Camera out of sim into `src/view/camera.js`; remote player rig [FR-007, FR-008]
  → slice `s5-view-camera`
- [P] T005 Bot client `tools/bot.mjs` with the scripted policy, driven over the real net client
  [SC-001] → slice `s8-bots`

## Wave 2

- [ ] T006 Room + lobby handshake on the server: create, join by code, reject reasons, 4 cap, 60 Hz
  tick [FR-001, FR-002, FR-017] → slice `s2-server`
- [ ] T007 Relay progress additive + decay, extraction gating, wave scaling by player count
  [FR-012, FR-013, FR-014] → slice `s3-sim-mp`
- [P] T008 Client net layer: 30 Hz input, snapshot apply, prediction + reconcile, snap on respawn
  [FR-006, FR-008, FR-009] → slice `s4-client-net`
- [P] T009 Interpolation buffers for remote players and enemies [FR-007] → slice `s4-client-net`
- [P] T010 Squad HUD: health strip, teammate compass markers, downed/respawn timers [FR-016]
  → slice `s6-hud-mp`
- [P] T011 Lobby screen + room code entry + `?room=` route [FR-001, FR-002] → slice `s6-hud-mp`
- [P] T012 Frozen evals per AC (parity, prediction, relay, spawn, budget), test-writer drafted
  [SC-002, SC-003] → slice `s7-evals`
- [P] T013 Soak harness [SC-001] → slice `s7-evals`

## Wave 3

- [P] T014 Drop-in mid-run + reconnect token + 60 s slot hold [FR-003, FR-004] → slice `s9-lobby-flow`
- [P] T015 Interest management, delta baselines, 5 Hz far-enemy downsampling, bandwidth assert
  [FR-018, SC-003] → slice `s10-budget`

## Wave 4

- [P] T016 README + `docs/multiplayer.md` (hosting, ports, limits) [FR-020] → slice `s11-docs`

## Cut notes

- `s3-sim-mp` carries T002/T003 in wave 1 and T007 in wave 2 because they share `src/sim/`; the same
  worker resumes it, so it is one slice with two start points (second start `stacked_on s2-server`).
- `s4-client-net` and `s6-hud-mp` are separate files but both wave 2: no shared file, so they are
  parallel, not stacked.
- Nothing in wave 2 starts before every wave-1 eval is green.