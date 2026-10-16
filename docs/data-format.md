# Data format

**Schema version: 1**

This document is the contract between tm_copiloto and any tool that reads its files.
Every statement below about units and value ranges was checked against recorded runs.

## Files

- One file per run, stored at
  `%USERPROFILE%\OpenplanetNext\PluginStorage\tm_copiloto\runs\<map_uid>\<YYYYMMDD-HHMMSS-mmm>.jsonl`
  (local time when the run started).
- [JSON Lines](https://jsonlines.org/): UTF-8, one JSON object per line. Key order inside an object is not guaranteed.
- A file stays open, and locked for reading, while its run is being recorded.
- A run starts at the end of the countdown (race time 0) and ends at the finish, a restart, leaving the race, or when recording is turned off.

## Line types

Every line has a `type` field.

| `type` | Count | Purpose |
|---|---|---|
| `header` | exactly 1, first line | Metadata about the run |
| `frame` | many | Car state sampled during the run |
| `checkpoint` | 0 or more | A waypoint was crossed (checkpoint, lap line or finish) |
| `respawn` | 0 or more | The car was respawned at its last checkpoint |
| `end` | 1, last line | Why and when the run ended. Missing if the game closed or crashed mid-run |

Lines are written as the plugin learns about them. Checkpoints and respawns are reported by the game a frame or
two after they happen, so a `checkpoint` line can follow a `frame` with a slightly later `race_time`.
Sort by `race_time` if you need strict chronological order.

### `header`

| Field | Type | Description |
|---|---|---|
| `schema_version` | int | Version of this format (currently `1`) |
| `plugin_version` | string | Version from the plugin's `info.toml` |
| `game_version` | string | Game build, e.g. `"2026-02-02_17_51"` |
| `recorded_at` | string | UTC timestamp of the run start, ISO 8601 (`2026-10-16T00:26:18Z`) |
| `editor` | bool | `true` when recorded in the map editor's test mode |
| `map.uid` | string | Map UID, or `"unknown-map"` if the game did not provide one |
| `map.name` | string | Map name without formatting codes |
| `map.author_login` | string | Author account login |
| `map.author_name` | string | Author display name without formatting codes |
| `vehicle` | string | Car at the start of the run: `CarSport`, `CarSnow`, `CarRally`, `CarDesert`, or `""` if unknown. Car changes during the run are not recorded |
| `sample_rate_hz` | int | Target sampling rate configured when the run was recorded |

### `frame`

| Field | Type | Unit / range | Description |
|---|---|---|---|
| `race_time` | int | ms | Time since the start of the run, on the same clock as the in-game chronometer and the `checkpoint` times |
| `pos` | [float, float, float] | m | World position `[x, y, z]`. **Y is up**; X and Z are horizontal |
| `vel` | [float, float, float] | m/s | World velocity `[x, y, z]` |
| `speed` | float | m/s | Forward speed, negative when reversing. Multiply by 3.6 for the km/h shown by the game |
| `gear` | int | 1–5 observed | Current gear |
| `rpm` | number | 0–11000 observed | Engine RPM, rounded to an integer. `0` if unavailable (see limitations) |
| `steer` | float | −1 to 1 | Steering input. **Negative is left** |
| `gas` | float | 0 to 1 | Throttle input. A keyboard only produces 0 or 1 |
| `brake` | float | 0 to 1 | Brake input |
| `ground` | bool | | The game's whole-car ground contact flag |
| `surface` | [string × 4] | | Material under each wheel, always in the order **front-left, front-right, rear-left, rear-right** |

Floats are written with 3 decimals.

**`surface` values** are the game's surface material names (`EPlugSurfaceMaterialId`), for example `Asphalt`,
`Concrete`, `Plastic`, `Sand`, `Grass`, `RoadIce`, `Metal`, `Rock`, `Rubber`. New names may appear; treat the
list as open. `XXX_Null` means the wheel is not touching anything.

**`ground` and `surface`:** when `ground` is `false`, all four wheels are `XXX_Null`. When `ground` is `true`, any
number of wheels can be `XXX_Null`, including all four (at spawn, on landing, or when only the body touches).
Use `surface` for per-wheel contact.

**What a frame measures:** the car's state as the game renders it, read once per rendered frame. It is not a
sample of every physics simulation step.

### Sampling

- Target interval: `1000 / sample_rate_hz` ms, using integer division (25 Hz → 40 ms).
- Samples are aligned to multiples of that interval. Each frame is taken on the first rendered frame at or after
  the target time, so real intervals vary with the frame rate (28–50 ms observed at 25 Hz). The rate cannot
  exceed the frame rate.
- Always use `race_time`, not the line position, as the time axis.
- No frames are written during the countdown (negative race time).

### `checkpoint`

| Field | Type | Description |
|---|---|---|
| `race_time` | int | Chronometer time at the waypoint, in ms. Exact: the same value the game shows as a split |
| `index` | int | 1-based waypoint number in this run. Checkpoints, lap lines and the finish all count |

### `respawn`

| Field | Type | Description |
|---|---|---|
| `race_time` | int | Moment of the respawn in ms, accurate to about one rendered frame. The run's race time keeps running |

### `end`

| Field | Type | Description |
|---|---|---|
| `reason` | string | `finish`, `restart`, `left` or `stopped` (see below) |
| `race_time` | int | For `finish`, the exact final time. Otherwise, the `race_time` of the last frame |
| `checkpoints` | [int] | All checkpoint times of the run, in order (the same values as the `checkpoint` lines) |

| `reason` | Meaning |
|---|---|
| `finish` | The finish line was crossed (on multilap maps, after the last lap) |
| `restart` | A new attempt started before finishing |
| `left` | The race left the screen without finishing: back to the menu, leaving editor test mode, end of an online round |
| `stopped` | Recording was turned off, or the plugin was disabled or reloaded |

## What is recorded

- Only the local player's own car, while it is on screen. Spectated players, replays and ghosts are not recorded.
- Solo, online and map editor test mode.
- Only runs whose countdown the plugin saw. A run already in progress when the plugin loads, or when recording is
  turned on, is skipped; the next one is recorded.

## Known limitations

- **Multilap maps in editor test mode:** the finish is not detected, so those runs end as `restart` or `left`.
- **Frames near the finish:** because the finish is reported a frame or two late, a run may contain a frame
  slightly after its final time.
- **RPM:** read through Openplanet's VehicleState plugin from a memory offset. After a game update it may read `0`
  until VehicleState is updated.

## Versioning

- `schema_version` increases on any breaking change: removing or renaming a field or line type, or changing a
  field's type, unit or meaning.
- Adding fields or line types is not a breaking change. Consumers must ignore fields and line types they do not
  know.

## Example

[`examples/sample-run.jsonl`](examples/sample-run.jsonl) is a real finished run on *Fall 2026 - 11* with one
respawn. To keep it small, frames are thinned to every 25th (about one per second); every other line is unchanged.
