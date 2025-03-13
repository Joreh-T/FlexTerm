-- lua/flexterm/init.lua（修改后）
local M = {}
local config = {}
local terminals = {}

local default_config = {
  split_mode = "vsplit", -- 支持 "vsplit"（垂直）或 "hsplit"（水平）
  split_ratio = 0.5,     -- 分割比例
  dynamic_layout = true  -- 自动根据侧边栏调整
}

local function get_main_area()
  local has_sidebar = false
  local sidebar_width = 0
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "neo-tree" then
      has_sidebar = true
      sidebar_width = vim.api.nvim_win_get_width(win)
    end
  end

  return {
    has_sidebar = has_sidebar,
    sidebar_width = sidebar_width,
    main_width = vim.o.columns - sidebar_width,
    main_height = vim.o.lines - 2 -- 减去状态栏和命令行高度
  }
end

function M.create_terminal()
  local area = get_main_area()
  
  -- Step 1: 创建右侧主窗口（如果不存在）
  if not terminals.main_win then
    vim.cmd("wincmd l") -- 移动到右侧
    terminals.main_win = vim.api.nvim_get_current_win()
  end

  -- Step 2: 在右侧主窗口内水平分割
  vim.api.nvim_set_current_win(terminals.main_win)
  vim.cmd("split term://"..config.shell)
  
  -- Step 3: 调整分割比例
  local term_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(term_win, math.floor(area.main_height * (1 - config.split_ratio)))
  
  -- Step 4: 返回上层窗口（文本编辑区）
  vim.cmd("wincmd k")
  terminals.text_win = vim.api.nvim_get_current_win()

  return term_win
end

function M.toggle()
  if terminals.term_win and vim.api.nvim_win_is_valid(terminals.term_win) then
    vim.api.nvim_win_close(terminals.term_win, true)
    terminals.term_win = nil
  else
    terminals.term_win = M.create_terminal()
  end
end

function M.setup(user_config)
  config = vim.tbl_deep_extend("force", default_config, user_config or {})

  -- 自动布局调整
  if config.dynamic_layout then
    vim.api.nvim_create_autocmd({"WinResized", "BufEnter"}, {
      callback = function()
        if terminals.term_win and vim.api.nvim_win_is_valid(terminals.term_win) then
          local area = get_main_area()
          vim.api.nvim_win_set_width(terminals.main_win, area.main_width)
          vim.api.nvim_win_set_height(terminals.term_win, 
            math.floor(area.main_height * (1 - config.split_ratio)))
        end
      end
    })
  end
end

return M