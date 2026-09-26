-- Runs after startup, i.e. after Neovim has loaded the project's .nvim.lua.
local failures = {}
local with_lspconfig = (os.getenv("LSPCONFIG") or "") ~= ""
local label = with_lspconfig and "with" or "without"
local function check(cond, what)
  if not cond then
    table.insert(failures, what)
  end
end
local function eq(a, b, what)
  check(vim.deep_equal(a, b), ("%s: expected %s, got %s"):format(what, vim.inspect(b), vim.inspect(a)))
end

local function run()
check(vim.g.editorenv_extra == true, "extraLua was not run (was .nvim.lua loaded?)")

-- The fully specified server.
local fake = vim.lsp.config.fake
check(fake ~= nil, "fake is not configured")
eq(fake.cmd, { "fake-ls" }, "fake.cmd")
eq(fake.filetypes, { "fakelang" }, "fake.filetypes")
eq(fake.root_markers, { ".git", "fake.toml" }, "fake.root_markers")
eq(fake.init_options, { mode = "test" }, "fake.init_options")
eq(fake.flags, { debounce_text_changes = 42 }, "fake.flags (editors.neovim.servers)")
check(vim.lsp.is_enabled("fake"), "fake is not enabled")

-- Servers that lean on nvim-lspconfig: project settings merge over its defaults.
eq(vim.lsp.config.zls.settings, { zls = { enable_build_on_save = true } }, "zls.settings")
eq(vim.lsp.config.rust_analyzer.settings["rust-analyzer"].cargo.features, "all", "rust_analyzer settings")
check(type(vim.lsp.config.rust_analyzer.on_attach) == "function", "rust_analyzer.on_attach is not a function")
if with_lspconfig then
  eq(vim.lsp.config.zls.cmd, { "zls" }, "zls.cmd from nvim-lspconfig")
end
check(vim.lsp.is_enabled("zls"), "zls is not enabled")

-- Disabled by the project although the user's config enabled it.
check(not vim.lsp.is_enabled("ts_ls"), "ts_ls is still enabled")

-- End to end: open a file, let fake-ls attach, and read what it received.
vim.cmd.edit(vim.fn.fnameescape(os.getenv("PROJECT") .. "/main.fake"))
local log = os.getenv("FAKE_LS_LOG")
local seen = {}
vim.wait(10000, function()
  seen = {}
  if vim.fn.filereadable(log) == 1 then
    for _, line in ipairs(vim.fn.readfile(log)) do
      local entry = vim.json.decode(line)
      seen[entry.kind] = entry.value
    end
  end
  return seen["workspace/configuration"] ~= nil and seen.didChangeConfiguration ~= nil
end, 50)

local clients = vim.lsp.get_clients({ name = "fake" })
check(#clients == 1, ("expected fake to attach once, got %d clients"):format(#clients))
if clients[1] then
  eq(clients[1].root_dir, vim.fn.resolve(os.getenv("PROJECT")), "fake root_dir")
end
eq(seen.initializationOptions, { mode = "test" }, "initializationOptions received by server")
eq(seen["workspace/configuration"], { { greeting = "hello", nested = { list = { 1, 2, 3 } } } }, "workspace/configuration answer")
eq(seen.didChangeConfiguration, { fake = { greeting = "hello", nested = { list = { 1, 2, 3 } } } }, "didChangeConfiguration settings")

end

local ok, err = pcall(run)
if not ok then
  table.insert(failures, "error: " .. tostring(err))
end
if #failures > 0 then
  io.stderr:write("FAIL (" .. label .. " nvim-lspconfig)\n  " .. table.concat(failures, "\n  ") .. "\n")
  vim.cmd("cquit 1")
else
  io.stdout:write("ok (" .. label .. " nvim-lspconfig)\n")
  vim.cmd("qall!")
end
