---@class OllamaOptions
---@field api_url string
local defaults = {
    api_url = "http://127.0.0.1:11434/api",
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

return M
