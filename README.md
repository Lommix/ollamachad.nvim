# Ollamachad v1.1.0

Chat with any Ollama model or use the prompts to generate/modify text.

[chat.webm](https://github.com/Lommix/ollamachad.nvim/assets/84206502/2fc0addd-c8aa-4e81-911b-66574eb8f2a4)

This plugin aims to provide a simple interface to chat with any Ollama model or use the prompts to generate/modify text, while being very minimalistic
and give the user full control over how to use it.

The Chat can be used with any model. There is a hotkey to switch between any available model found in your ollama instance.

# Installation & Configuration

```lua
-- lazy
return {
    "Lommix/ollamachad.nvim",
    dependencies = {
        "MunifTanjim/nui.nvim",
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
    },
    config = function()
        local Chat = require("ollamachad.chat")
        local gen = require("ollamachad.generate")
        local util = require("ollamachad.util")

        --- call setup if have a special address for your ollama server
        require("ollamachad").setup({
            api_url = "http://127.0.0.1:11434/api",
        })

        --- create a new chat, with optional configuration
        --- these are the defaults
        local chat = Chat:new({
            keymap = {
                clear = "<C-n>",
                send = "<CR>",
                quit = "<ESC>",
                select = "<C-k>",
            },
            cache_file = "~/.cache/nvim/ollamachad", -- persists selected model between sessions
            system_prompt = "", -- provide any context
        })

        --- bind a key to open
        vim.keymap.set("n", "<leader>t", function()
            chat:toggle()
        end, { silent = true })


        --- gen mode without a chat, just a single answer, create for creative text work
        --- create a quick visual select and rewrite generative request
        vim.keymap.set("v", "<leader>cr", function()
            local instruction =
            "Please rewrite the following text to improve clarity, coherence while keeping the vibe:",
            local request = {
                model = "mistral",
                prompt = instruction .. util.read_visiual_lines(),
            }
            gen.prompt(request)
        end, { silent = true })

    end,
}
```

[generate.webm](https://github.com/Lommix/ollamachad.nvim/assets/84206502/52f528ea-b880-4500-8afd-0c725b174189)
