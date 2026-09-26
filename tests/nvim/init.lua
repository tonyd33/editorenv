-- Plays the user's own config: nvim-lspconfig on the runtimepath (when the
-- test provides it), a server enabled globally, and 'exrc' turned on.
local lspconfig = os.getenv("LSPCONFIG")
if lspconfig and lspconfig ~= "" then
  vim.opt.runtimepath:prepend(lspconfig)
end
vim.o.exrc = true
vim.lsp.enable("ts_ls")
vim.filetype.add({ extension = { fake = "fakelang" } })
