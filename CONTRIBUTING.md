# Contributing

Thanks for helping. A few rules keep the plugin small and its data trustworthy.

## Ground rules

- **English everywhere**: code, comments, docs, commit messages, pull requests and UI text.
- **The plugin only records.** No overlays, hints or anything that helps during a race, no network access, and
  never change game state.
- **The data format is a public contract.** Any change to what is written updates
  [docs/data-format.md](docs/data-format.md) (and the example when relevant). A breaking change, as defined there,
  also increments `SCHEMA_VERSION` in `src/Recorder.as`.

## Development setup

1. Follow the installation steps in the [README](README.md) to link your clone into the Openplanet plugins folder
   and switch to Developer signature mode.
2. After editing a `.as` file, use **Developer → Reload plugin → tm_copiloto** in the game.
3. Check `%USERPROFILE%\OpenplanetNext\Openplanet.log` for compile errors. A failed compilation is still followed
   by a "Loaded plugin" line, so look for `ERR` lines.

Before relying on a game API, check its definition in `%USERPROFILE%\OpenplanetNext\Openplanet.h` (written by
Openplanet for your game version) or in the [Openplanet docs](https://openplanet.dev/docs).

## Testing a change

Record a few runs that exercise the change (finish, restart, respawn, editor test mode) and inspect the resulting
`.jsonl` files. Describe in your pull request what you drove and what you checked in the files.

## Commits and pull requests

Keep commits small, with a clear message explaining what changed and why.
