--- @class OllamaOptions
--- @field chat_api_url string
--- @field generate_api_url string
local defaults = {
    generate_api_url = "http://127.0.0.1:11434/api/generate",
    chat_api_url = "http://127.0.0.1:11434/api/chat",
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
