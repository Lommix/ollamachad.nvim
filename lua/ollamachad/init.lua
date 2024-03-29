---@class Keymap
---@field prompt string
---@field close string
---@field clear string

---@class OllamaOptions
---@field chat_api_url string
---@field generate_api_url string
---@field keymap Keymap
local defaults = {
    generate_api_url = "http://127.0.0.1:11434/api/generate",
    chat_api_url = "http://127.0.0.1:11434/api/chat",
    keymap = {
        -- send prompt
        prompt = "<CR>",
        -- close chat
        close = "<Esc>",
        -- clear chat
        clear = "<C-n>",
        -- tab between prompt and chat
        tab = "<Tab>",
    },
}

--- @class Ollamachad
--- @field opts OllamaOptions
local M = {
    opts = vim.deepcopy(defaults),
}

--- @param opts OllamaOptions
M.setup = function(opts)
    M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
end

M.prompt = function()
    local string = require("ollamachad.util").read_visiual_lines()
    P(string)
end

return M
