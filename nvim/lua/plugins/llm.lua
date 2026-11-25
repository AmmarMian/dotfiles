-- ~/.config/nvim/lua/plugins/gp.lua
return {
  "robitx/gp.nvim",
  -- needs the `llm` CLI for the API key; skipped on machines without it
  cond = vim.fn.executable("llm") == 1,
  config = function()
    local gp = require("gp")

    gp.setup({
      providers = {
        albert = {
          disable = false,
          endpoint = "https://albert.api.etalab.gouv.fr/v1/chat/completions",
          secret = { "llm", "keys", "get", "albert" },
        },
      },

      agents = {
        { name = "ChatGPT4o", disable = true },
        { name = "ChatGPT4o-mini", disable = true },
        { name = "CodeGPT4o", disable = true },
        { name = "CodeGPT4o-mini", disable = true },

        {
          name = "AlbertMistralSmall",
          provider = "albert",
          chat = true,
          command = true,
          model = { model = "mistralai/Mistral-Small-3.2-24B-Instruct-2506" },
          system_prompt = "You are a concise assistant. Explain and answer questions about the "
            .. "provided code or text. Do not rewrite, generate, or complete code unless "
            .. "explicitly asked to.",
        },
        {
          name = "AlbertMinistral",
          provider = "albert",
          chat = true,
          command = true,
          model = { model = "mistralai/Ministral-3-8B-Instruct-2512" },
          system_prompt = "You are a concise assistant. Explain and answer questions about the "
            .. "provided code or text. Do not rewrite, generate, or complete code unless "
            .. "explicitly asked to.",
        },
        {
          name = "AlbertQwenCoder",
          provider = "albert",
          chat = true,
          command = true,
          model = { model = "Qwen/Qwen3-Coder-30B-A3B-Instruct" },
          system_prompt = "You are a concise assistant. Explain and answer questions about the "
            .. "provided code or text. Do not rewrite, generate, or complete code unless "
            .. "explicitly asked to.",
        },
        {
          name = "AlbertGptOss",
          provider = "albert",
          chat = true,
          command = true,
          model = { model = "openai/gpt-oss-120b" },
          system_prompt = "You are a concise assistant. Explain and answer questions about the "
            .. "provided code or text. Do not rewrite, generate, or complete code unless "
            .. "explicitly asked to.",
        },
      },

      chat_user_prefix = "Ammar:",
      default_chat_agent = "AlbertMistralSmall",
      default_command_agent = "AlbertMistralSmall",

      -- hooks are auto-registered as :Gp<HookName> commands
      hooks = {
        Explain = function(gp_, params)
          local template = "I have the following code from {{filename}}:\n\n"
            .. "```{{filetype}}\n{{selection}}\n```\n\n"
            .. "Please respond by explaining the code above."
          local agent = gp_.get_chat_agent()
          gp_.Prompt(params, gp_.Target.popup, agent, template)
        end,

        Ask = function(gp_, params)
          local template = "I have the following code from {{filename}}:\n\n"
            .. "```{{filetype}}\n{{selection}}\n```\n\n"
            .. "{{command}}"
          local agent = gp_.get_chat_agent()
          gp_.Prompt(params, gp_.Target.popup, agent, template)
        end,
      },
    })

    vim.keymap.set("v", "<leader>ae", ":<C-u>'<,'>GpExplain<CR>", { desc = "Gp: explain selection" })
    vim.keymap.set("v", "<leader>aa", ":<C-u>'<,'>GpAsk<CR>", { desc = "Gp: ask about selection" })
    vim.keymap.set("v", "<leader>ac", ":<C-u>'<,'>GpChatNew<CR>", { desc = "Gp: chat about selection" })
    vim.keymap.set("n", "<leader>at", "<cmd>GpChatToggle<CR>", { desc = "Gp: toggle chat" })
    vim.keymap.set({ "n", "v" }, "<leader>am", "<cmd>GpAgent<CR>", { desc = "Gp: switch agent" })
  end,
}
