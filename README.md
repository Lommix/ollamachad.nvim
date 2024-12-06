# Ollamachad

A chat and generative prompt plugin for Neovim, powered by a local Ollama API.

-   Choose any installed model from the provided Ollama API (persisted cross session).
-   Mark any file as context. Context is added as system prompt automatically.
-   Provide your own system prompts to manipulate and shape behavior.

[ollamachad.webm](https://github.com/user-attachments/assets/f433d103-730a-4e4d-ac35-c8ae10a5e67f)

## Commands

-   `:OLLAMAMARK` to mark the current buffers file for context.
-   `:OLLAMACLEAR` clear marked files.

**The context is loaded into the cash when clearing the chat with default `<C-n>` inside the prompt buffer.**

## Installation & Configuration

Example for Lazy.

```lua
return {
	{
		"lommix/ollamachad.nvim",
		dir = "~/Projects/nvim_plugins/ollamachad.nvim",
		dependencies = {
			"MunifTanjim/nui.nvim",
			"nvim-lua/plenary.nvim",
		},
		config = function()
			require("ollamachad.init").setup({})

			local Chat = require("ollamachad.chat")
			local gen = require("ollamachad.generate")
			local util = require("ollamachad.util")

			-- toggle gen output
			vim.keymap.set("n", "<leader>co", function()
				gen.toggle_popup()
			end, { silent = true })

            -- using the gen module for fixed tasks
			vim.keymap.set("v", "<leader>cr", function()
				local instruction =
					"Please rewrite the following text to improve clarity, coherence while keeping the vibe:"
				local request = {
					model = "llama3.1:latest",
					prompt = instruction .. util.read_visiual_lines(),
				}
				gen.prompt(request)
			end, { silent = true })

			-- using the chat module
			local chat = Chat:new({
				show_keys = true,
                -- example system prompt
				system_prompt = [[
				You provide assistant to a developer. Follow the following rule set in order:
				1.) Conciseness: Provide short and concise answers.
				2.) Relevance: Only include relevant code snippets to the question. Use comments to replace boilerplate code.
				3.) Clarification: If additional information is needed to provide proper support, ask the user for it.
				4.) Transparency: If uncertain about a solution, inform the user that you cannot answer.
				]],
			})

            -- use this key in an open buffer to mark the file for context
			vim.keymap.set("n", "<leader>l", ":OLLAMAMARK<CR>", { silent = true })

            -- toggle the chat
			vim.keymap.set("n", "<leader>t", function()
				chat:toggle()
			end, { silent = true })
		end,
	},
}
```

## Configure

Provide a custom API-URL.

```lua
require("ollamachad.init").setup({
    api_url = "http://127.0.0.1:11434/api",
})
```

## Change Keys and Chat Settings

The default chat options

```lua
local default_chat_config = {
    keymap = {
        clear = "<C-n>",
        send = "<CR>",
        quit = "<ESC>",
        select = "<C-k>",
        context = "<C-c>",
        reload = "<C-l>",
        tab = "<TAB>",
    },
    cache_file =  vim.fn.expand("~") .. "/.cache/nvim/ollamachad",
    system_prompt = "",
    show_keys = true,
    model_options = {
        -- you can pass any model option
        -- specified by the Ollama-API documentation
        temperature = 0.7,
    },
}
local chat = Chat:new(default_chat_config)
```
