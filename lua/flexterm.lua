-- lua/flexterm/init.lua
local M = {}
local terminals = {}  -- 存储所有终端实例

local config = {
  position = "bottom", -- "bottom" | "right" | "float"
  size = 15,
  shell = vim.o.shell,
  filetype = "flexterm",  -- 用于隐藏 bufferline
  start_insert = true,
  auto_close = true,
  hide_bufferline = true
}

---@class Terminal
---@field buf integer
---@field win integer
---@field job_id integer
---@field cmd string|string[]

local function generate_term_id(cmd, cwd)
  return table.concat({
    type(cmd) == "table" and table.concat(cmd, " ") or cmd,
    cwd or vim.loop.cwd()
  }, "|")
end

function M.toggle(cmd, opts)
  opts = opts or {}
  cmd = cmd or config.shell
  local term_id = generate_term_id(cmd, opts.cwd)

  -- 复用现有终端
  if terminals[term_id] and vim.api.nvim_win_is_valid(terminals[term_id].win) then
    local term = terminals[term_id]
    if vim.api.nvim_win_get_config(term.win).relative ~= "" then
      vim.api.nvim_win_hide(term.win)  -- 浮动窗口隐藏
    else
      vim.api.nvim_win_close(term.win, true)  -- 分屏窗口关闭
    end
    terminals[term_id] = nil
    return
  end

  -- 创建新终端
  local buf = vim.api.nvim_create_buf(false, true)
  local win_opts = {
    style = "minimal",
    relative = "editor",
    width = vim.o.columns,
    height = config.size,
    row = vim.o.lines - config.size - 1,
    col = 0
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)
  local job_id = vim.fn.termopen(cmd, {
    cwd = opts.cwd,
    env = opts.env,
    on_exit = function(_, code)
      if code ~= 0 and config.auto_close then
        M.toggle(cmd, opts)  -- 自动关闭异常终端
      end
    end
  })

  -- 配置终端特性
  vim.bo[buf].filetype = config.filetype
  if config.start_insert then
    vim.cmd.startinsert()
  end

  -- 记录终端实例
  terminals[term_id] = {
    buf = buf,
    win = win,
    job_id = job_id,
    cmd = cmd
  }

  -- 配置双 ESC 退出
  vim.keymap.set("t", "<Esc>", function()
    local timer = vim.loop.new_timer()
    timer:start(200, 0, function()
      timer:close()
      vim.schedule(function()
        vim.cmd.stopinsert()
      end)
    end)
    return "<Esc>"
  end, { buffer = buf, expr = true })

  -- 自动定位焦点
  vim.api.nvim_set_current_win(win)
end

function M.setup(user_config)
  config = vim.tbl_deep_extend("force", config, user_config or {})

  -- 隐藏 bufferline
  if config.hide_bufferline then
    vim.api.nvim_create_autocmd("FileType", {
      pattern = config.filetype,
      callback = function(args)
        vim.bo[args.buf].buflisted = false
      end
    })
  end
end

return M
