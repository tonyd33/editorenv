# Server id -> default `command`, `filetypes` and `rootMarkers`, taken from
# nvim-lspconfig. Where it computes the root in Lua, `rootMarkers` approximates
# it with plain file names.
{
  ansiblels = {
    command = [
      "ansible-language-server"
      "--stdio"
    ];
    filetypes = [ "yaml.ansible" ];
    rootMarkers = [
      "ansible.cfg"
      ".ansible-lint"
    ];
  };
  basedpyright = {
    command = [
      "basedpyright-langserver"
      "--stdio"
    ];
    filetypes = [ "python" ];
    rootMarkers = [
      "pyrightconfig.json"
      "pyproject.toml"
      "setup.py"
      "setup.cfg"
      "requirements.txt"
      "Pipfile"
      ".git"
    ];
  };
  bashls = {
    command = [
      "bash-language-server"
      "start"
    ];
    filetypes = [
      "bash"
      "sh"
    ];
    rootMarkers = [ ".git" ];
  };
  buf_ls = {
    command = [
      "buf"
      "lsp"
      "serve"
      "--log-format=text"
    ];
    filetypes = [
      "proto"
      "buf-config"
    ];
    rootMarkers = [
      "buf.yaml"
      ".git"
    ];
  };
  ccls = {
    command = [ "ccls" ];
    filetypes = [
      "c"
      "cpp"
      "objc"
      "objcpp"
      "cuda"
    ];
    rootMarkers = [
      "compile_commands.json"
      ".ccls"
      ".git"
    ];
  };
  clangd = {
    command = [ "clangd" ];
    filetypes = [
      "c"
      "c.doxygen"
      "cpp"
      "cpp.doxygen"
      "objc"
      "objcpp"
      "cuda"
    ];
    rootMarkers = [
      ".clangd"
      ".clang-tidy"
      ".clang-format"
      "compile_commands.json"
      "compile_flags.txt"
      "configure.ac"
      ".git"
    ];
  };
  clojure_lsp = {
    command = [ "clojure-lsp" ];
    filetypes = [
      "clojure"
      "edn"
    ];
    rootMarkers = [
      "project.clj"
      "deps.edn"
      "build.boot"
      "shadow-cljs.edn"
      ".git"
      "bb.edn"
    ];
  };
  crystalline = {
    command = [ "crystalline" ];
    filetypes = [ "crystal" ];
    rootMarkers = [
      "shard.yml"
      ".git"
    ];
  };
  dagger = {
    command = [ "cuelsp" ];
    filetypes = [ "cue" ];
    rootMarkers = [
      "cue.mod"
      ".git"
    ];
  };
  elixirls = {
    command = [ "elixir-ls" ];
    filetypes = [
      "elixir"
      "eelixir"
      "heex"
      "surface"
    ];
    rootMarkers = [
      "mix.exs"
      ".git"
    ];
  };
  elmls = {
    command = [ "elm-language-server" ];
    filetypes = [ "elm" ];
    rootMarkers = [ "elm.json" ];
  };
  elp = {
    command = [
      "elp"
      "server"
    ];
    filetypes = [ "erlang" ];
    rootMarkers = [
      "rebar.config"
      "erlang.mk"
      ".git"
    ];
  };
  fortls = {
    command = [
      "fortls"
      "--notify_init"
      "--hover_signature"
      "--hover_language=fortran"
      "--use_signature_help"
    ];
    filetypes = [ "fortran" ];
    rootMarkers = [
      ".fortls"
      ".fortlsrc"
      ".fortls.json"
      ".git"
    ];
  };
  gopls = {
    command = [ "gopls" ];
    filetypes = [
      "go"
      "gomod"
      "gowork"
      "gotmpl"
    ];
    rootMarkers = [
      "go.work"
      "go.mod"
      ".git"
    ];
  };
  helm_ls = {
    command = [
      "helm_ls"
      "serve"
    ];
    filetypes = [
      "helm"
      "yaml.helm-values"
    ];
    rootMarkers = [ "Chart.yaml" ];
  };
  hls = {
    command = [
      "haskell-language-server-wrapper"
      "--lsp"
    ];
    filetypes = [
      "haskell"
      "lhaskell"
    ];
    rootMarkers = [
      "hie.yaml"
      "stack.yaml"
      "cabal.project"
      "package.yaml"
      ".git"
    ];
  };
  idris2_lsp = {
    command = [ "idris2-lsp" ];
    filetypes = [ "idris2" ];
    rootMarkers = [ ".git" ];
  };
  jsonnet_ls = {
    command = [ "jsonnet-language-server" ];
    filetypes = [
      "jsonnet"
      "libsonnet"
    ];
    rootMarkers = [
      "jsonnetfile.json"
      ".git"
    ];
  };
  kotlin_language_server = {
    command = [ "kotlin-language-server" ];
    filetypes = [ "kotlin" ];
    rootMarkers = [
      "settings.gradle"
      "settings.gradle.kts"
      "build.xml"
      "pom.xml"
      "build.gradle"
      "build.gradle.kts"
    ];
  };
  lua_ls = {
    command = [ "lua-language-server" ];
    filetypes = [ "lua" ];
    rootMarkers = [
      ".emmyrc.json"
      ".luarc.json"
      ".luarc.jsonc"
      ".luacheckrc"
      ".stylua.toml"
      "stylua.toml"
      "selene.toml"
      "selene.yml"
      ".git"
    ];
  };
  metals = {
    command = [ "metals" ];
    filetypes = [ "scala" ];
    rootMarkers = [
      "build.sbt"
      "build.sc"
      "build.gradle"
      "build.gradle.kts"
      "pom.xml"
    ];
  };
  # nvim-lspconfig says `millet`, but the binary is `millet-ls`.
  millet = {
    command = [ "millet-ls" ];
    filetypes = [ "sml" ];
    rootMarkers = [ "millet.toml" ];
  };
  nil_ls = {
    command = [ "nil" ];
    filetypes = [ "nix" ];
    rootMarkers = [
      "flake.nix"
      ".git"
    ];
  };
  nim_langserver = {
    command = [ "nimlangserver" ];
    filetypes = [ "nim" ];
    rootMarkers = [ ".git" ];
  };
  nixd = {
    command = [ "nixd" ];
    filetypes = [ "nix" ];
    rootMarkers = [
      "flake.nix"
      ".git"
    ];
  };
  ocamllsp = {
    command = [ "ocamllsp" ];
    filetypes = [
      "ocaml"
      "menhir"
      "ocamlinterface"
      "ocamllex"
      "reason"
      "dune"
    ];
    rootMarkers = [
      "dune-project"
      "dune-workspace"
      "opam"
      "esy.json"
      "package.json"
      ".git"
    ];
  };
  ols = {
    command = [ "ols" ];
    filetypes = [ "odin" ];
    rootMarkers = [
      "ols.json"
      ".git"
    ];
  };
  perlnavigator = {
    command = [ "perlnavigator" ];
    filetypes = [ "perl" ];
    rootMarkers = [ ".git" ];
  };
  phpactor = {
    command = [
      "phpactor"
      "language-server"
    ];
    filetypes = [ "php" ];
    rootMarkers = [
      ".git"
      "composer.json"
      ".phpactor.json"
      ".phpactor.yml"
    ];
  };
  pylsp = {
    command = [ "pylsp" ];
    filetypes = [ "python" ];
    rootMarkers = [
      "pyproject.toml"
      "setup.py"
      "setup.cfg"
      "requirements.txt"
      "Pipfile"
      ".git"
    ];
  };
  pyright = {
    command = [
      "pyright-langserver"
      "--stdio"
    ];
    filetypes = [ "python" ];
    rootMarkers = [
      "pyrightconfig.json"
      "pyproject.toml"
      "setup.py"
      "setup.cfg"
      "requirements.txt"
      "Pipfile"
      ".git"
    ];
  };
  # No command: the package is an R library, and `R` is not in its `bin/`.
  r_language_server = {
    filetypes = [
      "r"
      "rmd"
      "quarto"
    ];
    rootMarkers = [ ".git" ];
  };
  ruff = {
    command = [
      "ruff"
      "server"
    ];
    filetypes = [ "python" ];
    rootMarkers = [
      "pyproject.toml"
      "ruff.toml"
      ".ruff.toml"
      ".git"
    ];
  };
  rust_analyzer = {
    command = [ "rust-analyzer" ];
    filetypes = [ "rust" ];
    rootMarkers = [
      "Cargo.toml"
      "rust-project.json"
      ".git"
    ];
  };
  solargraph = {
    command = [
      "solargraph"
      "stdio"
    ];
    filetypes = [ "ruby" ];
    rootMarkers = [
      "Gemfile"
      ".git"
    ];
  };
  sourcekit = {
    command = [ "sourcekit-lsp" ];
    filetypes = [
      "swift"
      "objc"
      "objcpp"
      "c"
      "cpp"
    ];
    rootMarkers = [
      "buildServer.json"
      ".bsp"
      "compile_commands.json"
      "Package.swift"
      ".git"
    ];
  };
  terraformls = {
    command = [
      "terraform-ls"
      "serve"
    ];
    filetypes = [
      "terraform"
      "terraform-vars"
    ];
    rootMarkers = [
      ".terraform"
      ".git"
    ];
  };
  texlab = {
    command = [ "texlab" ];
    filetypes = [
      "tex"
      "plaintex"
      "bib"
    ];
    rootMarkers = [
      ".git"
      ".latexmkrc"
      "latexmkrc"
      ".texlabroot"
      "texlabroot"
      "Tectonic.toml"
    ];
  };
  tinymist = {
    command = [ "tinymist" ];
    filetypes = [ "typst" ];
    rootMarkers = [ ".git" ];
  };
  tofu_ls = {
    command = [
      "tofu-ls"
      "serve"
    ];
    filetypes = [
      "opentofu"
      "opentofu-vars"
      "terraform"
    ];
    rootMarkers = [
      ".terraform"
      ".git"
    ];
  };
  ts_ls = {
    command = [
      "typescript-language-server"
      "--stdio"
    ];
    filetypes = [
      "javascript"
      "javascriptreact"
      "typescript"
      "typescriptreact"
    ];
    rootMarkers = [
      "package-lock.json"
      "yarn.lock"
      "pnpm-lock.yaml"
      "bun.lockb"
      "bun.lock"
      ".git"
    ];
  };
  vala_ls = {
    command = [ "vala-language-server" ];
    filetypes = [
      "vala"
      "genie"
    ];
    rootMarkers = [
      "meson.build"
      ".git"
    ];
  };
  zls = {
    command = [ "zls" ];
    filetypes = [
      "zig"
      "zir"
    ];
    rootMarkers = [
      "zls.json"
      "build.zig"
      ".git"
    ];
  };
}
