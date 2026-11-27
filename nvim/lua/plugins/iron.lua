-- iron.nvim: IPython in a split on the right, send code from Python files.
-- Keys (Python buffers only, localleader = ","):
--   ,rs open/show REPL   ,rf %run whole file   ,sl send line   ,ss send selection (visual)
--   ,sc send # %% cell   ,sn send cell + next  ,rr restart     ,ri interrupt   ,rh hide
--   ,rp (any buffer) fuzzy-pick a .py file and %run it   ,rv (any buffer) variables (%whos)
--   ,rf / ,rp / ,rv move the cursor into the REPL (leave: Ctrl-\ Ctrl-N, then Ctrl-w h)
-- REPL command: vim.g.iron_python_cmd if a project sets it (e.g. in .nvim.lua),
-- otherwise `uv run ipython --no-autoindent`.
-- ,rp (any buffer): fuzzy-pick a .py file of the project and %run it, without opening it.

-- Move the cursor into the Python REPL window, in terminal mode, so its output follows live
-- and you can type straight away. Leave it with Ctrl-\ Ctrl-N (normal mode) then Ctrl-w h.
local function focus_repl()
  vim.schedule(function()
    require("iron.core").focus_on("python")
    vim.cmd("startinsert")
  end)
end

-- %run a file in the Python REPL (iron starts the REPL if it is not running yet), then focus it.
local function run_file(path)
  require("iron.core").send("python", { "%run " .. vim.fn.fnameescape(path) })
  focus_repl()
end

-- Variable explorer: IPython's %whos (name, type, and shape/dtype for arrays).
local function show_variables()
  require("iron.core").send("python", { "%whos" })
  focus_repl()
end

local function pick_and_run()
  Snacks.picker.files({
    title = "%run",
    ft = "py",
    confirm = function(picker, item)
      picker:close()
      if item then
        vim.schedule(function() run_file(Snacks.picker.util.path(item)) end)
      end
    end,
  })
end

return {
  "Vigemus/iron.nvim",
  ft = "python",
  keys = {
    { "<localleader>rp", pick_and_run, desc = "IPython: pick a file and %run it" },
    { "<localleader>rv", show_variables, desc = "IPython: variables (%whos)" },
  },
  config = function()
    local iron = require("iron.core")
    local view = require("iron.view")
    local common = require("iron.fts.common")

    iron.setup({
      config = {
        scratch_repl = true,
        repl_definition = {
          python = {
            command = function()
              return vim.g.iron_python_cmd or { "uv", "run", "ipython", "--no-autoindent" }
            end,
            format = common.bracketed_paste_python,
            block_dividers = { "# %%", "#%%" },
          },
        },
        repl_open_cmd = view.split.vertical.botright("40%"),
        -- Show the REPL in the bufferline tabs, with a short name instead of term://…
        buflisted = true,
        repl_filetype = function(bufnr, ft)
          local name = ft == "python" and "IPython" or ("REPL " .. ft)
          if not pcall(vim.api.nvim_buf_set_name, bufnr, name) then
            pcall(vim.api.nvim_buf_set_name, bufnr, name .. " " .. bufnr) -- name taken (e.g. after restart)
          end
          return "iron"
        end,
      },
      keymaps = {}, -- set below, for Python buffers only
      highlight = { italic = true },
      ignore_blank_lines = true,
    })

    local function map(bufnr, mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = "IPython: " .. desc })
    end

    local function set_keys(bufnr)
      map(bufnr, "n", "<localleader>rs", "<cmd>IronRepl<cr>", "open / show")
      map(bufnr, "n", "<localleader>rf", function()
        vim.cmd("silent! write")
        run_file(vim.fn.expand("%:p"))
      end, "run file (%run)")
      map(bufnr, "n", "<localleader>sl", iron.send_line, "send line")
      map(bufnr, "v", "<localleader>ss", iron.visual_send, "send selection")
      map(bufnr, "n", "<localleader>sc", function() iron.send_code_block(false) end, "send cell")
      map(bufnr, "n", "<localleader>sn", function() iron.send_code_block(true) end, "send cell + next")
      map(bufnr, "n", "<localleader>rr", "<cmd>IronRestart<cr>", "restart")
      map(bufnr, "n", "<localleader>ri", function() iron.send(nil, string.char(3)) end, "interrupt")
      map(bufnr, "n", "<localleader>rh", "<cmd>IronHide<cr>", "hide")
    end

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "python",
      callback = function(ev) set_keys(ev.buf) end,
    })
    -- The buffer that triggered loading (ft = "python") already had its FileType event.
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].filetype == "python" then set_keys(buf) end
    end
  end,
}
