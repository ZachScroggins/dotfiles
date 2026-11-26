-- Organize TS/JS imports on save via vtsls "source.organizeImports":
-- sorts, merges duplicates, and deletes unused imports.
-- Registered as a LazyVim formatter with a higher priority than ESLint (200) and conform (100),
-- so the order on save is: organize imports -> ESLint --fix -> Prettier. <leader>uf toggles all of it.

---@param buf integer
local function organize_imports(buf)
  local client = vim.lsp.get_clients({ bufnr = buf, name = "vtsls" })[1]
  if not client then
    return
  end
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(buf) },
    range = {
      start = { line = 0, character = 0 },
      ["end"] = { line = vim.api.nvim_buf_line_count(buf), character = 0 },
    },
    context = { only = { "source.organizeImports" }, diagnostics = {} },
  }
  local res = client:request_sync("textDocument/codeAction", params, 3000, buf)
  for _, action in ipairs(res and res.result or {}) do
    if not action.edit and client:supports_method("codeAction/resolve") then
      local resolved = client:request_sync("codeAction/resolve", action, 3000, buf)
      action = resolved and resolved.result or action
    end
    if action.edit then
      vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
    end
  end
end

return {
  {
    "neovim/nvim-lspconfig",
    init = function()
      LazyVim.format.register({
        name = "vtsls: organize imports",
        primary = false,
        priority = 300,
        format = organize_imports,
        sources = function(buf)
          return #vim.lsp.get_clients({ bufnr = buf, name = "vtsls" }) > 0 and { "vtsls" } or {}
        end,
      })
    end,
  },
}
