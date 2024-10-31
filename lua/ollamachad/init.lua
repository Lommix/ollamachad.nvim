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

vim.g.ollamachad_marked_files = {}

vim.api.nvim_create_user_command("OLLAMAMARK", function()
    local current_file = vim.fn.expand("%")
    if not vim.tbl_contains(vim.g.ollamachad_marked_files, current_file) then
        local m = vim.g.ollamachad_marked_files
        table.insert(m, current_file)
        vim.g.ollamachad_marked_files = m
        print("Marked context file!")
    else
        print("File already marked")
    end
end, {})

vim.api.nvim_create_user_command("OLLAMACLEAR", function()
    vim.g.ollamachad_marked_files = {}
end, {})

--- @param opts ?OllamaOptions
M.setup = function(opts)
    M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
end

return M
