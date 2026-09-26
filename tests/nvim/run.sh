#!/usr/bin/env bash
# Loads a generated .nvim.lua through Neovim's real 'exrc' path and checks it.
#
#   run.sh GENERATED_LUA
#
# Environment: NVIM (default: nvim), LSPCONFIG (nvim-lspconfig checkout;
# empty to test without it), PYTHON (default: python3).
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
generated=$(readlink -f "$1")
nvim=${NVIM:-nvim}
python=${PYTHON:-python3}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# A project, with the generated file linked in the way the integrations do it.
export PROJECT=$tmp/project
mkdir -p "$PROJECT/.git"
echo "content" > "$PROJECT/main.fake"
ln -s "$generated" "$PROJECT/.nvim.lua"

# The fake server, on PATH as `fake-ls` like a real server package would be.
mkdir -p "$tmp/bin"
printf '#!/bin/sh\nexec %s %s "$@"\n' "$python" "$here/fake_ls.py" > "$tmp/bin/fake-ls"
chmod +x "$tmp/bin/fake-ls"
export PATH=$tmp/bin:$PATH
export FAKE_LS_LOG=$tmp/fake-ls.log

# Isolated Neovim state. The user config goes in the standard location: `-u`
# skips 'exrc'. Pre-trust the file as `:trust` records it, by its hash and
# resolved path (the store path behind the symlink).
export XDG_CONFIG_HOME=$tmp/config XDG_DATA_HOME=$tmp/data XDG_STATE_HOME=$tmp/state XDG_CACHE_HOME=$tmp/cache
mkdir -p "$XDG_CONFIG_HOME/nvim" "$XDG_STATE_HOME/nvim"
cp "$here/init.lua" "$XDG_CONFIG_HOME/nvim/init.lua"
hash=$(sha256sum "$generated" | cut -d' ' -f1)
printf '%s %s\n' "$hash" "$generated" > "$XDG_STATE_HOME/nvim/trust"

cd "$PROJECT"
timeout 60 "$nvim" --headless -c "luafile $here/check.lua" </dev/null
