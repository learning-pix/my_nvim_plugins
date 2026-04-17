vim.g.vimtex_compiler_method = "latexmk"
vim.g.vimtex_view_method = "general"
local function is_executable(path)
  return path and path ~= "" and (vim.fn.filereadable(path) == 1 or vim.fn.executable(path) == 1)
end

local sumatra_from_env = vim.env.SUMATRAPDF
local edge_candidates = {
  vim.fn.expand("$ProgramFiles/Microsoft/Edge/Application/msedge.exe"),
  vim.fn.expand("$ProgramFiles(x86)/Microsoft/Edge/Application/msedge.exe"),
  vim.fn.expand("$LocalAppData/Microsoft/Edge/Application/msedge.exe"),
}

if is_executable(sumatra_from_env) then
  vim.g.vimtex_view_general_viewer = sumatra_from_env
  vim.g.vimtex_view_general_options = "-reuse-instance -forward-search @tex @line @pdf"
else
  local edge_path = nil
  for _, p in ipairs(edge_candidates) do
    if is_executable(p) then
      edge_path = p
      break
    end
  end

  if edge_path then
    vim.g.vimtex_view_general_viewer = edge_path
    vim.g.vimtex_view_general_options = "--new-window @pdf"
  else
    -- Final fallback: explorer.exe exists on Windows and opens with default PDF app.
    vim.g.vimtex_view_general_viewer = "explorer.exe"
    vim.g.vimtex_view_general_options = "@pdf"
  end
end
vim.g.vimtex_compiler_latexmk = {
  continuous = 1,
}

vim.api.nvim_create_autocmd("FileType", {
  pattern = "tex",
  callback = function(event)
    local options = { buffer = event.buf, silent = true, noremap = true }
    vim.keymap.set("n", "<leader>ll", ":VimtexCompile<CR>", options)
    vim.keymap.set("n", "<leader>lv", ":VimtexCompile<CR>:VimtexView<CR>", options)
  end,
})