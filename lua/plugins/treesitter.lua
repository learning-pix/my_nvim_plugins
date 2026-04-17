local ok, treesitter = pcall(require, "nvim-treesitter")
if not ok then
  return
end

treesitter.setup({})

-- 需要的语言解析器（若已安装则会跳过）
treesitter.install({
  "vim",
  "vimdoc",
  "bash",
  "c",
  "cpp",
  "javascript",
  "json",
  "lua",
  "python",
  "typescript",
  "tsx",
  "css",
  "rust",
  "latex",
  "markdown",
  "markdown_inline",
})

-- 新版中高亮由 Neovim 提供，这里在可用时自动启用
vim.api.nvim_create_autocmd("FileType", {
  callback = function(event)
    pcall(vim.treesitter.start, event.buf)
  end,
})
