# tm_copiloto

An [Openplanet](https://openplanet.dev/) plugin for Trackmania (2020) that records telemetry of your runs to local
files.

It only records. There is no analysis, no overlay or in-race hint, and no network access: everything stays on your
disk, in a documented format meant to be read by other tools.

## What it records

For every run of your own car, in solo, online or map editor test mode:

- map, car, game and plugin metadata;
- the car's state, sampled 25 times per second by default: position, velocity, speed, gear, RPM, steering,
  throttle, brake, ground contact and the surface under each wheel;
- checkpoint times, respawns and the final time.

The file format is described in [docs/data-format.md](docs/data-format.md), with a sample in
[docs/examples/](docs/examples/).

## Requirements

- Trackmania (2020) with Openplanet.
- **MLFeed: Race Data**, installed from Openplanet's Plugin Manager. It brings its own dependency, MLHook.
- VehicleState, which ships with Openplanet.

## Installation

The plugin is not published on openplanet.dev yet, so it only loads in Openplanet's **Developer** signature mode.
Developer mode turns on School Mode, which blocks online play and leaderboard records on most maps.

1. Install **MLFeed: Race Data** from the Plugin Manager.
2. Clone this repository and link it into the plugins folder (a directory junction needs no admin rights):

   ```powershell
   git clone https://github.com/baphomello/tm_copiloto.git
   New-Item -ItemType Junction -Path "$env:USERPROFILE\OpenplanetNext\Plugins\tm_copiloto" -Target "<path to your clone>"
   ```

3. In the game, open the overlay (F3), choose **Openplanet → Signature Mode → Developer**, then load
   `tm_copiloto` from the **Developer** menu.

## Usage

- **Plugins → tm_copiloto** turns recording and the status window on or off.
- The **status window** shows whether recording is on, the frame count of the current run and the last saved file.
  Its **Live values** section shows every recorded field as it is read, to check the data.
- **Openplanet → Settings → tm_copiloto** has the same toggles plus **Sample rate (Hz)** (1–100, default 25).

## Where the files are

```
%USERPROFILE%\OpenplanetNext\PluginStorage\tm_copiloto\runs\<map_uid>\<YYYYMMDD-HHMMSS-mmm>.jsonl
```

One file per run, about 0.4 MB per minute of driving at 25 Hz. Nothing is deleted automatically.

## Out of scope

Run analysis, charts, AI, reading replays, ghosts or map files, and map editing tools belong to separate projects
that consume these files.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Copyright (C) 2026 Baphomello. Licensed under the [GNU Affero General Public License v3.0](LICENSE).
