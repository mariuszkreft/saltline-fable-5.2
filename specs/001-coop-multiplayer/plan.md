# Plan — co-op multiplayer

Companion to `spec.md` and `contracts/`. Track standard. Everything here is what the herd builds;
the cut is in `tasks.md` and `.m2herd/herden/herd-01/`.

## 1. Split without a rewrite

`index.html` stays the source of truth for CSS (`src/ui/game.css` at wave 0) and the shipped page
shell. The minified game body is sliced at function boundaries into `src/` files and re-concatenated
by `tools/build.mjs` inside the original IIFE wrapper, in filename order, then inlined into a fresh
`index.html` together with `src/00-vendor.js` (the extracted three.js bundle).

Why concatenation: every symbol is a closure local of one IIFE today. Re-exporting them as ESM means
touching hundreds of minified names and a class of load-order bugs; concatenation keeps them all in
scope and lets parallel workers edit disjoint files with no import graph to resolve.

`tools/build.mjs`:

```
node tools/build.mjs           # → dist/index.html (single file, CSS + vendor + src, in order)
node tools/build.mjs --check   # fails when dist/ is stale against src/
```

`tools/parity.mjs` replays a recorded input tape against a headless sim and prints a trace hash
(player pos/health, relay timers, enemy ids). The hash is compared with the fixture from the pre-cut
commit; it is the solo regression gate and it runs on every slice.

## 2. Layout

```
src/00-vendor.js            three.js bundle, untouched
src/05-shared.js            helpers, rng, events bus, stub table `dr`
src/10-config.js            Pi/Mt/Yi/Ui tunables, settings
src/20-world/level.js       generation (deterministic, seeded — unchanged logic)
src/20-world/physics.js     capsules, raycasts, nav
src/30-sim/player.js        per-player factory (camera moved out)
src/30-sim/combat.js        per-player raycasts, rewind
src/30-sim/enemies.js       pooled agents, targeting hook
src/30-sim/objectives.js    relays, extraction
src/30-sim/weapon.js        ammo/reload/fire → combat
src/40-net/protocol.js      wire format
src/40-net/server.js        room loop, 60 Hz
src/40-net/client.js        prediction, reconcile
src/40-net/interp.js        remote entity buffers
src/40-net/interest.js      culling + downsampling
src/50-view/render.js       three.js renderer, post
src/50-view/camera.js       camera follow, shake, bob, fov
src/50-view/weapon-view.js  viewmodel
src/50-view/fx.js, audio.js, backdrop.js, ground.js, props.js
src/60-ui/hud.js, hud-mp.js, menus.js, lobby.js, room-code.js
src/90-flow.js              run state machine
src/99-boot.js              boot, rAF loop, route solo vs net
tools/…                     build, parity, bot, soak, bandwidth, proto-test
```

## 3. Server loop

Fixed 60 Hz `setInterval` on a monotonic clock; each tick: drain queued inputs into `i.inputs`, run
`objectives.cutTick`, `flow.update`, every `player.update(dt, input)`, `enemies.update(dt)`,
`combat` resolution, then one snapshot per client and a batch of `ev` frames. No accumulator drift:
late ticks are dropped, capped at 4 per wake-up. Room teardown after 90 s empty. Process handles
`SIGTERM` by broadcasting `ev:leave` and closing.

## 4. Client loop

Input sampled at 30 Hz into a ring buffer with `seq`. Local player predicted each frame from the
newest input (identical code as the server, `dt` from the render loop, clamped 50 ms). On snapshot:
apply remote entities to `interp`, take `ack`, drop acked inputs, replay the remainder over the
server pose, and correct: < 0.5 m blend, else snap. Enemies never predicted.

## 5. Determinism

Same `level` seed on both sides (`?seed=` is already supported by the game), same tunables, integer
tick. `i.rng` stays server-side; client FX use their own seeded rng so a client never consumes the
sim stream.

## 6. Protocol

Per `contracts/protocol.md`. `ws` is the only npm dependency (dev + runtime), declared in
`package.json`; nothing else is added and the shipped page keeps bundling three.js inline.

## 7. Modes

`?solo=1` or no `?net` → today's path. `?room=CODE` → net client. A build-time flag is avoided so one
artifact covers both.

## 8. Test & eval commands

```
node tools/build.mjs --check            # stale-artifact gate
node tools/parity.mjs --assert          # solo trace identical to the fixture
node tools/proto-test.mjs               # codec round-trip + fixture bytes + budget
node tools/serve.mjs --rooms 1 --port 8740 &
node tools/bot.mjs --room TEST --n 4 --duration 180 --complete
node tools/soak.mjs --minutes 10 --clients 4
node tools/bandwidth.mjs --clients 4 --enemies 10 --assert 40
```

Bots are headless: they use `src/net/client.js` with a scripted policy (walk to relay, hold interact,
shoot the nearest enemy) and never a DOM.

## 9. Risks

| Risk | Mitigation | Owner |
|---|---|---|
| Slice boundaries cut through one minified function | wave-0 slice sets boundaries; a boundary change is a contract change | `p0-extract` |
| Prediction feels wrong | reconcile budget + tune `accel`/error blend against a 120 ms/3 % loss fixture | `s4-client-net` |
| Two workers touch `flow.js` | one flow slice; a second file `objectives.js` holds relay logic | cut check |
| Bandwidth blows up with 10 enemies | `interest.js` from wave 3, budget eval red early | `s10-budget` |
| Solo regressions slip in | parity eval frozen from wave 0, red blocks G4 | `s7-evals` |
| Minified `index.html` merge conflicts | only `src/` is edited after wave 0; `index.html` is generated | build |

## 10. Order rationale

Wave 1 proves the three highest-uncertainty things at once and independently (codec, multi-player sim,
camera split) plus the bot that everything measures with. Wave 2 is the first end-to-end vertical
slice (server + client + HUD + evals). Waves 3–4 are hardening and polish. No wave starts before the
previous wave's evals are green.