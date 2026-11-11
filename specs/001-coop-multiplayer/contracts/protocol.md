# Contract — wire protocol v1

Frozen after G1. `src/net/protocol.js` is the only writer/reader; every other slice imports it and
never re-implements a field. All numbers little-endian. Quantization bounds are the level bounds from
`src/sim/const.js` (`BOUNDS`), never magic literals.

## 1. Channels

One WebSocket per client (`ws://<host>:<port>/r/<CODE>`).

| Class | Messages | Delivery | Notes |
|---|---|---|---|
| control | `hello`, `welcome`, `reject`, `join`, `leave`, `ready` | ordered, reliable | JSON text frames are allowed here only |
| input | `input` | unordered, latest wins | client → server, 30 Hz |
| snapshot | `snapshot` | unordered, latest wins | server → client, 20 Hz |
| event | `ev` | ordered, reliable | server → client, batched per tick |

A stale or out-of-order input (`seq` ≤ last processed) is dropped. A snapshot with `tick` ≤ the last
applied tick is dropped.

## 2. Framing

Byte 0 is the message type; `0x01–0x0f` = client→server, `0x80–0x8f` = server→client.

```
0x01 input     u16 seq | u8 buttons | i16 moveX | i16 moveZ | u16 yaw | u16 pitch | u16 viewTick
0x81 welcome   u8 playerId | u8 maxPlayers | u32 token | u8 roomFlags | u16 tick
0x82 reject    u8 reason | u8 len | char[len]            reason: 1 unknown, 2 full, 3 in progress, 4 bad proto
0x83 snapshot  u16 tick | u16 ack | u8 playerCount | players… | u8 enemyCount | enemies… | world…
0x84 ev        u16 tick | u8 count | events…             each: u8 kind | u8 len | payload
```

`buttons` bitfield: 0 fire, 1 ads, 2 sprint, 3 crouch, 4 jump, 5 interact, 6 reload, 7 melee.
`moveX`/`moveZ` are Q15 of the input axis. `yaw`/`pitch` are Q16 of a full turn / half turn.

## 3. Entities

```
player  u8 id | u8 flags | u16 x | u16 y | u16 z | u16 yaw | u16 pitch | u8 health | u16 ammo
        flags: 1 alive, 2 downed, 4 crouch, 8 ads, 16 sprint, 32 invulnerable, 64 firing
enemy   u8 id | u8 type(1 gull,2 hound) | u16 x | u16 y | u16 z | u8 yawQ | u8 flags
        flags: 1 alive, 2 engage, 4 wreck
world   u8 cutMask | u8 cutterId | u8 cutProgress | u8 alivePlayers | u8 runState
```

Positions are Q16 over `BOUNDS` in three axes (0.02 m resolution at this level size, which is below
the capsule radius). If any coordinate falls outside `BOUNDS + 4 m`, the entity's block is prefixed
with a `0xFFFF` sentinel and sent as three f32.

## 4. Events

`1 impact, 2 hit, 3 killed, 4 weaponFire, 5 weaponDry, 6 reloadStart, 7 step, 8 land, 9 jump,
10 telegraph, 11 melee, 12 enemySpawn, 13 relayDone, 14 radio, 15 warn, 16 downed, 17 respawn,
18 extract, 19 teamState`.

Events carry only what the client needs to play the same `i.events` emission it plays today; payloads
are the ASCII of the emission, comma-separated (ids, quantized point, surface enum).

## 5. Budget

- A snapshot with 4 players and 10 enemies is ≤ 1 400 bytes; hard ceiling 2 048.
- Snapshots are delta'd per receiver against the last acked baseline (keyframe every 10 ticks or
  after 3 lost baselines).
- Interest radius 55 m around the receiver plus all alive players and all relays; enemies outside it
  are downsampled to 5 Hz and position-only.
- Downstream p95 ≤ 40 KB/s per player at 4 players.

## 6. Rules

- The server validates: payload length, enum ranges, `moveX/Z` saturation, yaw wrap.
- The client trusts only `welcome` for its id and `snapshot.ack` for reconciliation.
- Adding a message type or an event kind is a contract change: increment `PROTO_VERSION` and touch
  `tools/proto-test.mjs` fixtures in the same slice.