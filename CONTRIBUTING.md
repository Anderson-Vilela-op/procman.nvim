# Contributing to procman.nvim

Bug reports, feature requests, and PRs are all welcome.

## Running tests

```sh
bash scripts/test.sh
```

This downloads plenary.nvim (test-only dependency) into `.tests/` on the
first run and executes the suite headlessly. No plugin manager or personal
Neovim config is needed.

## Adding a provider

If you want to add support for another language/tool (e.g. a new
ecosystem's marker file), see the "Adding a provider" section in the
[README](README.md#adding-a-provider) -- a provider is a small module with
just a `detect` and a `discover` function. `lua/procman/providers/dotnet.lua`
is a good reference for a more complete one; `rust.lua`/`go.lua` are good
references for a minimal one.

## Before opening a PR

- Run `bash scripts/test.sh` and make sure it passes.
- Add/update tests for the change (see `tests/procman/` for examples).
- Update the README if the change affects config, commands, or keymaps.
- Keep PRs focused -- one change per PR is easier to review than several
  bundled together.

## Reporting bugs

Please include your Neovim version, OS, plugin manager, and (if possible) a
minimal `.procman.lua` or `setup()` snippet that reproduces the issue. The
bug report issue template will prompt for this.
