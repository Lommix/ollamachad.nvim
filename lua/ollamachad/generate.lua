local Job = require("plenary.job")
local Popup = require("nui.popup")
local ollamachad = require("ollamachad")
local M = {}

local generate_popup = Popup({
    size = {
        width = "80%",
        height = "80%",
    },
    position = "50%",
    enter = true,
    focusable = true,
    relative = "editor",
    border = {
        style = "rounded",
        text = {
            top = "Ollama response",
            top_align = "center",
        },
    },
    buf_options = {
        modifiable = true,
        readonly = false,
        swapfile = false,
    },
    win_options = {
        winblend = 10,
        winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    },
})

local popup_visibility = false

generate_popup:map("n", "<ESC>", function()
    generate_popup:hide()
    popup_visibility = false
end)

generate_popup:map("n", "<C-w>q", function()
    generate_popup:hide()
    popup_visibility = false
end)

M.toggle_popup = function()
    generate_popup:show()

    if popup_visibility then
        generate_popup:hide()
        popup_visibility = false
    else
        generate_popup:show()
        popup_visibility = true
    end
end

---@class GenerateRequest
---@field prompt string
---@field model string

---generate a prompt and stream to popup
---@param request GenerateRequest
---@return number - job id
M.prompt = function(request)
    vim.api.nvim_buf_set_lines(generate_popup.bufnr, 0, -1, false, {})

    generate_popup:show()
    generate_popup:update_layout()
    popup_visibility = true

    local max_width = generate_popup.win_config.width - 2
    local line = vim.api.nvim_buf_line_count(generate_popup.bufnr)
    local line_char_count = 0
    local words = {}

    local success, request_string = pcall(function()
        return vim.fn.json_encode(request)
    end)

    if not success then
        print("invalid request")
        return -1
    end

    local args = { "--silent", "--no-buffer", "-X", "POST", ollamachad.opts.generate_api_url, "-d", request_string }

    local job = Job:new({
        command = "curl",
        args = args,
        on_stdout = function(_, data)
            vim.schedule(function()
                local success, result = pcall(function()
                    return vim.fn.json_decode(data)
                end)

                if not success then
                    print("invalid response")
                    return
                end

                local token = result.response

                if (string.match(token, "^%s") and line_char_count > max_width) or string.match(token, "\n") then -- if returned data array has more than one element, a line break occured.
                    line = line + 1
                    words = {}
                    line_char_count = 0
                end

                line_char_count = line_char_count + #token
                local sanatised_token = token:gsub("\n", " ")
                if #sanatised_token > 0 then
                    table.insert(words, sanatised_token)
                    vim.api.nvim_buf_set_lines(generate_popup.bufnr, line, line + 1, false, { table.concat(words, "") })
                end
            end)
        end,
    })

    job:start()
    return job.pid
    -- P(ollamachad.opts.chat_api_url)
end

return M
