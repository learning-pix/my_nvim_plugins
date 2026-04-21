local ok, toggleterm = pcall(require, "toggleterm")
if not ok then
  return
end

toggleterm.setup({
  direction = "horizontal",
  close_on_exit = false,
  start_in_insert = true,
  persist_size = true,
  shade_terminals = true,
})

local Terminal = require("toggleterm.terminal").Terminal

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Code Runner" })
end

local function shell_quote(path)
  return string.format('"%s"', path)
end

local function powershell_quote(path)
  return string.format("'%s'", path:gsub("'", "''"))
end

local function is_windows()
  return vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
end

local function executable_extension()
  return is_windows() and ".exe" or ""
end

local function pick_compiler(filetype)
  local candidates = filetype == "c" and { "clang", "gcc" } or { "clang++", "g++" }

  for _, compiler in ipairs(candidates) do
    if vim.fn.executable(compiler) == 1 then
      return compiler
    end
  end

  return nil
end

local function run_in_terminal(command)
  local terminal = Terminal:new({
    cmd = command,
    hidden = true,
    direction = "horizontal",
    close_on_exit = false,
  })

  terminal:toggle()
end

local function run_python(source)
  local python_candidates = is_windows() and { "python", "py -3" } or { "python3", "python" }

  local python_command = nil
  for _, candidate in ipairs(python_candidates) do
    local executable_name = candidate:match("^(.-)%s") or candidate
    if vim.fn.executable(executable_name) == 1 then
      python_command = candidate
      break
    end
  end

  if not python_command then
    notify("未找到 Python，请安装 python3 或 python", vim.log.levels.ERROR)
    return
  end

  run_in_terminal(string.format("%s %s", python_command, shell_quote(source)))
end

local function run_executable_and_cleanup(executable)
  if is_windows() then
    local command = string.format(
      "powershell -NoProfile -ExecutionPolicy Bypass -Command \"& { & %s; Remove-Item -LiteralPath %s -Force -ErrorAction SilentlyContinue }\"",
      powershell_quote(executable),
      powershell_quote(executable)
    )
    run_in_terminal(command)
    return
  end

  local command = string.format("sh -lc %q", string.format("%s; rm -f %s", shell_quote(executable), shell_quote(executable)))
  run_in_terminal(command)
end

local function compile_c_like(source, filetype, run_after_compile)
  local compiler = pick_compiler(filetype)
  if not compiler then
    notify("未找到可用编译器，请安装 clang/clang++ 或 gcc/g++", vim.log.levels.ERROR)
    return
  end

  local standard = filetype == "c" and "-std=c11" or "-std=c++17"
  local output = vim.fn.fnamemodify(source, ":r") .. executable_extension()

  local extra_flags = {}
  if is_windows() then
    table.insert(extra_flags, "-mconsole")
  end

  local result
  if vim.system then
    local compile_args = {
      compiler,
      source,
      standard,
      "-O2",
      "-Wall",
      "-Wextra",
    }

    for _, flag in ipairs(extra_flags) do
      table.insert(compile_args, flag)
    end

    table.insert(compile_args, "-o")
    table.insert(compile_args, output)

    result = vim.system(compile_args, { text = true }):wait()
  else
    local compile_args = {
      compiler,
      source,
      standard,
      "-O2",
      "-Wall",
      "-Wextra",
    }

    for _, flag in ipairs(extra_flags) do
      table.insert(compile_args, flag)
    end

    table.insert(compile_args, "-o")
    table.insert(compile_args, output)

    local compile_output = vim.fn.system(compile_args)

    result = {
      code = vim.v.shell_error,
      stdout = compile_output,
      stderr = "",
    }
  end

  local output_text = vim.trim((result.stdout or "") .. "\n" .. (result.stderr or ""))
  if result.code ~= 0 then
    notify(output_text ~= "" and output_text or "编译失败", vim.log.levels.ERROR)
    return
  end

  notify("编译成功", vim.log.levels.INFO)

  if run_after_compile == "cleanup" then
    run_executable_and_cleanup(output)
  elseif run_after_compile == "run" then
    if is_windows() then
      run_in_terminal(shell_quote(output))
    else
      run_in_terminal("./" .. vim.fn.fnamemodify(output, ":t"))
    end
  end
end

local function build_or_run_current_buffer(mode)
  local source = vim.api.nvim_buf_get_name(0)
  if source == "" then
    notify("当前缓冲区没有文件", vim.log.levels.WARN)
    return
  end

  local filetype = vim.bo.filetype
  if filetype == "python" then
    if mode == "build" then
      notify("Python 不需要编译", vim.log.levels.INFO)
      return
    end

    run_python(source)
    return
  end

  if filetype ~= "c" and filetype ~= "cpp" then
    notify("仅支持 C / C++ / Python 文件", vim.log.levels.WARN)
    return
  end

  compile_c_like(source, filetype, mode)
end

vim.api.nvim_create_user_command("CodeRun", function()
  build_or_run_current_buffer("run")
end, {})

vim.api.nvim_create_user_command("CodeBuild", function()
  build_or_run_current_buffer("build")
end, {})

vim.api.nvim_create_user_command("CodeRunClean", function()
  build_or_run_current_buffer("cleanup")
end, {})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp", "python" },
  callback = function(event)
    local options = { buffer = event.buf, silent = true, noremap = true }

    vim.keymap.set("n", "<F5>", function()
      build_or_run_current_buffer("run")
    end, options)

    vim.keymap.set("n", "<leader>cr", function()
      build_or_run_current_buffer("run")
    end, options)

    vim.keymap.set("n", "<leader>cb", function()
      build_or_run_current_buffer("build")
    end, options)

    vim.keymap.set("n", "<leader>cx", function()
      build_or_run_current_buffer("cleanup")
    end, options)
  end,
})