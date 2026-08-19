#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
deps="$root/.tests/site/pack/deps/start"
plenary_dir="$deps/plenary.nvim"

if [ ! -d "$plenary_dir" ]; then
  echo "Downloading plenary.nvim (test-only dependency)..."
  mkdir -p "$deps"
  git clone --depth 1 https://github.com/nvim-lua/plenary.nvim "$plenary_dir"
fi

nvim --headless --noplugin -u "$root/tests/minimal_init.lua" \
  -c "PlenaryBustedDirectory tests/procman { minimal_init = 'tests/minimal_init.lua' }"
