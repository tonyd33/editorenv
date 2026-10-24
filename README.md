# editorenv

Declare a project's language servers in Nix, and get editor config for them
generated into the project. Your global editor config needs nothing beyond
Neovim's built-in [`exrc`](https://neovim.io/doc/user/options.html#'exrc').

```nix
editors.neovim.enable = true;
lsp.servers.zls = {
  package = pkgs.zls;                       # added to the project shell
  settings.zls.enable_build_on_save = true; # editor-agnostic, JSON-shaped
};
lsp.servers.ts_ls.enable = false;           # disabled even if enabled globally
```

produces `.nvim.lua` in the project root:

```lua
-- Generated from the project's Nix configuration (editors.neovim). Do not edit.
if vim.fn.has("nvim-0.11") == 0 then
  vim.notify(".nvim.lua" .. ": needs Neovim 0.11 or newer", vim.log.levels.WARN)
  return
end

vim.lsp.config("zls", {
  ["settings"] = {
    ["zls"] = {
      ["enable_build_on_save"] = true
    }
  }
})
vim.lsp.enable("zls")
vim.lsp.enable("ts_ls", false)
```

## Usage

### Plain flake

```nix
inputs.editorenv.url = "github:tonyd33/editorenv";
inputs.editorenv.inputs.nixpkgs.follows = "nixpkgs";
```

```nix
editor = editorenv.lib.mkProject {
  inherit pkgs;
  modules = [ ./editor.nix ];
};
devShells.default = pkgs.mkShell {
  inputsFrom = [ editor.shell.devShell ];
};
```

### [flake-parts](https://flake.parts)

Same input, then:

```nix
imports = [ editorenv.flakeModules.default ];
perSystem = { config, pkgs, ... }: {
  editorenv.settings = {
    editors.neovim.enable = true;
    lsp.servers.nixd.package = pkgs.nixd;
  };
  devShells.default = pkgs.mkShell {
    inputsFrom = [ config.editorenv.devShell ];
  };
};
```

### [devenv](https://devenv.sh)

```yaml
# devenv.yaml
inputs:
  editorenv:
    url: github:tonyd33/editorenv
imports:
  - editorenv/integrations/devenv
```

```nix
# devenv.nix
languages.go.enable = true;
editors.neovim.enable = true;
```

Servers enabled through devenv's `languages.<lang>.lsp` are added to
`lsp.servers` for you, so this is enough to get gopls configured. Set
`lsp.servers.gopls.settings` to configure it further, and declare servers devenv
has no language module for directly.

### Anything else

`imports = editorenv.modules;`, then consume `config.editors.files` and
`config.lsp.packages`.

Complete examples for the first three live in `examples/`.

## Neovim

Once, in your config:

```lua
vim.o.exrc = true  -- nixvim: opts.exrc = true;
```

Neovim 0.11+ is required. It reads `.nvim.lua` only from the directory it was
started in, so start it from the project root, inside the dev shell (the server
binaries are only on `PATH` there).

Neovim asks you to trust the file, and asks again whenever it changes. Trust is
keyed by the file's resolved path (the store path behind the symlink) plus its
hash, so `:trust` entries accumulate over time.

Servers that only set `settings` inherit their `cmd` and `filetypes` from
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig). Set `command` and
`filetypes` for servers it doesn't know, or if you don't use it.

## VS Code

```nix
editors.vscode.enable = true;
```

writes `.vscode/settings.json` and `.vscode/extensions.json`. VS Code has no
generic language server client, so each server maps onto its extension:

- `extensions.json` recommends the extension of every enabled server, and lists
  disabled servers' extensions under `unwantedRecommendations`.
- `settings` are flattened into dotted keys under their own section
  (`settings."rust-analyzer".cargo.features` becomes
  `"rust-analyzer.cargo.features"`). An object with dotted keys stays an
  object, as `gopls` expects.
- For servers editorenv knows (`rust_analyzer`, `gopls`, `clangd`, `lua_ls`,
  `nixd`, `nil_ls`, `hls`, `ruff`, `terraformls`, `tinymist`, `zls`), a set
  `package` pins the extension to that executable, so VS Code needn't be started
  from the dev shell.
- `command`, `filetypes`, `rootMarkers` and `initializationOptions` are not used.

For an extension that reads a different section than the server does, or a
server editorenv doesn't know, set `editors.vscode.servers.<id>`:

```nix
editors.vscode.servers.taplo.extension = "tamasfe.even-better-toml";
editors.vscode.servers.rust_analyzer.settings."rust-analyzer.check.command" = "clippy";
```

The generated `settings.json` is a read-only link into the Nix store, so
changing a workspace setting from VS Code's UI fails. Put workspace settings in
`editors.vscode.settings` instead.

## EditorConfig

```nix
editors.editorconfig = {
  enable = true;
  sections = {
    "*" = {
      end_of_line = "lf";
      insert_final_newline = true;
      indent_style = "space";
      indent_size = 2;
    };
    Makefile.indent_style = "tab";
  };
};
```

writes `.editorconfig` with `root = true`. Sections are written in name order,
and a later section overrides an earlier one where both match. Neovim reads
`.editorconfig` natively. With `editors.vscode` also enabled, `extensions.json`
recommends `editorconfig.editorconfig`.

## Formatters

```nix
format.formatters = {
  nixfmt.package = pkgs.nixfmt;             # added to the project shell
  ruff_fix = {
    package = pkgs.ruff;
    command = [ "ruff" "check" "--fix" "--stdin-filename" "$FILENAME" "-" ];
  };
  ruff_format = {
    package = pkgs.ruff;
    command = [ "ruff" "format" "--stdin-filename" "$FILENAME" "-" ];
  };
};
format.filetypes = {
  nix = [ "nixfmt" ];
  python = [ "ruff_fix" "ruff_format" ];    # run in order
  rust = [ { lsp = "rust_analyzer"; } ];    # formatted by the language server
};
format.onSave = true;
```

A formatter reads the file on stdin and writes the result to stdout.
`$FILENAME` in `command` is replaced by the file's path. `command` defaults to
the package's main program, and a bare executable name in it resolves to the
package's `bin/`, so neither editor needs starting from the dev shell.

`format.filetypes` uses Neovim's filetype names. Each step is a formatter id or
`{ lsp = <server id>; }`, and each step formats the previous step's output.
Disabled formatters are skipped. A step naming a missing formatter, or a server
that is missing or disabled, is an evaluation error.

In Neovim, `.nvim.lua` defines `:Format` and, with `onSave`, a `BufWritePre`
autocmd. It needs no plugin. It replaces only the lines that changed, so marks
and the cursor on other lines stay put. `lsp` steps go through
`vim.lsp.buf.format`. A step that fails shows its stderr and stops the chain,
and the output of the external steps since the last `lsp` step is discarded.

In VS Code, each filetype gets `editor.defaultFormatter` under its language
(`[nix]`, `[shellscript]`). VS Code runs one formatter per language, so a
filetype with more than one step is an evaluation error.

- Formatters editorenv knows (`nixfmt`, `alejandra`, `nixpkgs-fmt`, `prettier`,
  `ruff`, `black`) run through their own extension. A pinned executable is
  passed to it where the extension takes a path. `nix-ide` ignores
  `nix.formatterPath` while its language server is enabled.
- Any other formatter runs through `jkillian.custom-local-formatters`, which
  runs `command` from the workspace root.
- `lsp` steps use the server's extension.

Extensions are added to `extensions.json`. Set
`editors.vscode.formatters.<id>.extension` to use a different extension, and
`editors.vscode.languageIds.<filetype>` when a VS Code language id differs from
the Neovim filetype in a way editorenv doesn't know.

## How the file gets into the project

devenv writes the generated files through its own `files` option.

For plain flakes and flake-parts, the dev shell's hook symlinks each file into
the project on every shell entry:

- The target directory is `$EDITORENV_ROOT` if set, else the directory of the
  nearest `flake.nix` at or above the current directory (stopping at the
  repository root), else the current directory. `shell.root` pins it.
- Each link is registered as a GC root, so garbage collection can't leave it
  dangling. `shell.gcRoot = false` makes a plain symlink instead.
- A real (non-symlink) file at the target is left alone, with a warning. To
  keep a hand-written `.nvim.lua`, point `editors.neovim.path` elsewhere and
  `dofile()` the generated file from yours.
- Links are not removed when you turn an editor off. Delete them by hand.

The link points into the Nix store, so ignore it:

```gitignore
.nvim.lua
.vscode/settings.json
.vscode/extensions.json
.editorconfig
```

## Options

### `lsp.servers.<id>`

Ids follow [nvim-lspconfig's names](https://github.com/neovim/nvim-lspconfig/tree/master/lsp)
(`rust_analyzer`, `lua_ls`, `ts_ls`).

| Option | |
|---|---|
| `enable` | Default `true`. `false` actively disables the server in Neovim. |
| `package` | Added to the project shell. |
| `command` | Command and arguments. `null` uses the editor's default. |
| `filetypes`, `rootMarkers` | `null` uses the editor's default. |
| `settings` | Returned for `workspace/configuration` requests. JSON-shaped. |
| `initializationOptions` | Sent in the `initialize` request. |

### `format`

| Option | |
|---|---|
| `formatters.<id>.enable` | Default `true`. |
| `formatters.<id>.package` | Added to the project shell. Resolves a bare executable in `command`. |
| `formatters.<id>.command` | stdin to stdout. `$FILENAME` is the file's path. Defaults to the package's main program. |
| `filetypes.<filetype>` | Steps run in order: formatter ids, or `{ lsp = <server id>; }`. |
| `onSave` | Default `false`. |

### `editors.neovim`

| Option | |
|---|---|
| `enable` | Generate the config. |
| `path` | Default `.nvim.lua`. |
| `servers.<id>.config` | Neovim-only fields merged into `vim.lsp.config()`. Use `lib.generators.mkLuaInline` for Lua values such as `on_attach`. |
| `servers.<id>.name` | Neovim's name for the server, when it differs from the id. |
| `extraLua` | Appended to the generated file. |

### `editors.vscode`

| Option | |
|---|---|
| `enable` | Generate the config. |
| `path` | Default `.vscode/settings.json`. |
| `extensionsPath` | Default `.vscode/extensions.json`. `null` skips it. |
| `servers.<id>.extension` | Extension that runs the server, when editorenv doesn't know it. |
| `servers.<id>.settings` | VS Code settings merged over the derived ones. |
| `formatters.<id>.extension` | Extension that runs the formatter, instead of the known one or `custom-local-formatters`. |
| `formatters.<id>.settings` | VS Code settings for the formatter. |
| `languageIds.<filetype>` | VS Code language id of a Neovim filetype. |
| `settings` | Workspace settings merged over everything else. |

### `editors.editorconfig`

| Option | |
|---|---|
| `enable` | Generate the file. |
| `path` | Default `.editorconfig`. |
| `root` | Default `true`. Write `root = true`. |
| `sections.<glob>` | Properties for files matching `<glob>`. Booleans and integers are written as-is. |

## Adding an editor

Write `modules/editors/<editor>.nix`, have it read `config.lsp.servers`, and set
`editors.files.<path>.text`. Put editor-only options under `editors.<editor>`.
An editor that names servers differently maps ids in its own module.

## Credits

The shell hook's link handling (GC-rooted symlinks, refusing to replace a real
file) follows [git-hooks.nix](https://github.com/cachix/git-hooks.nix).
