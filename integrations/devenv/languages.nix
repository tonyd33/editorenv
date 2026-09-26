# Adds the servers enabled through `languages.<lang>.lsp` to `lsp.servers`.
{ lib, config, ... }:
let
  # Package name (`lib.getName`) -> server id (nvim-lspconfig naming). Covers
  # the defaults of devenv's language modules plus common alternatives.
  serverIds = {
    ansible-language-server = "ansiblels";
    basedpyright = "basedpyright";
    bash-language-server = "bashls";
    ccls = "ccls";
    clangd = "clangd";
    clang-tools = "clangd";
    clojure-lsp = "clojure_lsp";
    crystalline = "crystalline";
    cuelsp = "dagger";
    elixir-ls = "elixirls";
    elm-language-server = "elmls";
    erlang-language-platform = "elp";
    fortls = "fortls";
    gopls = "gopls";
    haskell-language-server = "hls";
    helm-ls = "helm_ls";
    idris2-lsp = "idris2_lsp";
    jsonnet-language-server = "jsonnet_ls";
    kotlin-language-server = "kotlin_language_server";
    languageserver = "r_language_server";
    lua-language-server = "lua_ls";
    metals = "metals";
    millet = "millet";
    nil = "nil_ls";
    nimlangserver = "nim_langserver";
    nixd = "nixd";
    ocaml-lsp-server = "ocamllsp";
    ols = "ols";
    perlnavigator = "perlnavigator";
    phpactor = "phpactor";
    pkl-lsp = "pkl";
    pyright = "pyright";
    python-lsp-server = "pylsp";
    ruff = "ruff";
    rust-analyzer = "rust_analyzer";
    solargraph = "solargraph";
    sourcekit-lsp = "sourcekit";
    terraform-ls = "terraformls";
    texlab = "texlab";
    tinymist = "tinymist";
    tofu-ls = "tofu_ls";
    typescript-language-server = "ts_ls";
    vala-language-server = "vala_ls";
    zls = "zls";
  };

  languages = config.languages or { };

  enabledServers = lib.filterAttrs (_: pkg: pkg != null) (
    lib.mapAttrs (
      _: lang:
      if (lang.enable or false) && (lang ? lsp) && (lang.lsp.enable or false) then
        lang.lsp.package or null
      else
        null
    ) languages
  );

  resolved = lib.mapAttrs (_: pkg: serverIds.${lib.getName pkg} or null) enabledServers;
  known = lib.filterAttrs (_: id: id != null) resolved;
  unknown = lib.attrNames (lib.filterAttrs (_: id: id == null) resolved);
in
{
  options.lsp.fromLanguages = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether to add the language servers enabled through devenv's
      `languages.<lang>.lsp` options to `lsp.servers`.
    '';
  };

  config = lib.mkIf config.lsp.fromLanguages {
    lsp.servers = lib.mapAttrs' (_: id: lib.nameValuePair id { }) known;

    warnings = map (
      lang:
      "editorenv: no server id known for languages.${lang}.lsp.package "
      + "(${lib.getName enabledServers.${lang}}); declare it in lsp.servers.<id> to configure it."
    ) unknown;
  };
}
