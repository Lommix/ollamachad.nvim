local Job = require("plenary.job")
local Popup = require("nui.popup")
local Layout = require("nui.layout")
local ollamachad = require("ollamachad")

---@class ChatConfig
---@field keymap table<string, string>
---@field system_prompt string
---@type ChatConfig
local defaults = {
    keymap = {
        clear = "<C-n>",
        send = "<CR>",
        quit = "<ESC>",
    },
    system_prompt = "",
}

---@class Message
---@field role string
---@field content string

---@class CurrentChat
---@field model string
---@field messages Message[]

---@class Chat
---@field opts table
---@field layout NuiLayout
---@field chat_float NuiPopup
---@field prompt_float NuiPopup
---@field model string
---@field toggle function
---@field private visible boolean
---@field private running boolean
---@field private current_chat CurrentChat
local Chat = {}

function Chat:new(model, opts)
    local chat_float = Popup({
        focusable = true,
        border = {
            highlight = "FloatBorder",
            style = "rounded",
            text = {
                top = " Chat ",
            },
        },
        win_options = {
            wrap = true,
            linebreak = true,
            foldcolumn = "1",
            winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
        },
        buf_options = {
            filetype = "markdown",
        },
    })

    local prompt_float = Popup({
        focusable = true,
        enter = true,
        border = {
            highlight = "FloatBorder",
            style = "rounded",
            text = {
                top = " Prompt ",
            },
        },
    })

    local layout = Layout(
        {
            position = "50%",
            size = {
                width = "80%",
                height = "80%",
            },
        },
        Layout.Box({
            Layout.Box(chat_float, { size = "85%" }),
            Layout.Box(prompt_float, { size = "15%" }),
        }, { dir = "col" })
    )

    local chat = {
        opts = vim.tbl_deep_extend("force", defaults, opts or {}),
        model = model,
        chat_float = chat_float,
        prompt_float = prompt_float,
        layout = layout,
        visible = false,
    }

    prompt_float:map("n", ollamachad.opts.keymap.prompt, function()
        chat:send()
    end)

    prompt_float:map("n", ollamachad.opts.keymap.close, function()
        chat:toggle()
    end)

    prompt_float:map("n", ollamachad.opts.keymap.clear, function()
        chat:clear_chat()
    end)

    chat_float:map("n", ollamachad.opts.keymap.tab, "<C-w>W", { silent = true })
    prompt_float:map("n", ollamachad.opts.keymap.tab, "<C-w>w", { silent = true })

    setmetatable(chat, self)
    self.__index = self

    chat:clear_chat()
    return chat
end

function Chat:set_model(model)
    self.model = model
    self.current_chat.model = model
end

function Chat:clear_chat()
    vim.api.nvim_buf_set_lines(self.chat_float.bufnr, 0, -1, false, {})

    self.current_chat = {
        model = self.model,
        messages = {},
    }

    if self.opts.system_prompt ~= "" then
        self.current_chat.messages[1] = {
            role = "system",
            content = self.opts.system_prompt,
        }
    end
end

function Chat:send()
    if self.running then
        print("Already running")
        return
    end

    local prompt_buffer = vim.api.nvim_buf_get_lines(self.prompt_float.bufnr, 0, -1, false)
    local prompt_string = table.concat(prompt_buffer, " ")

    -- remove line
    vim.api.nvim_buf_set_lines(self.prompt_float.bufnr, 0, -1, false, {})

    for i, line in ipairs(prompt_buffer) do
        prompt_buffer[i] = "# " .. line
    end
    prompt_buffer[#prompt_buffer + 1] = ""

    -- insert into chat
    vim.api.nvim_buf_set_lines(self.chat_float.bufnr, -1, -1, false, prompt_buffer)

    self.current_chat.messages[#self.current_chat.messages + 1] = {
        role = "user",
        content = prompt_string,
    }

    self:prompt()
end

--.toggles chat window
function Chat:toggle()
    if self.visible then
        self.layout:hide()
        self.visible = false
    else
        self.layout:show()
        self.layout:update()
        self.visible = true
    end
end

--- prompt the current chat.
--- @return number - pid of the curl process
function Chat:prompt()
    local line = vim.api.nvim_buf_line_count(self.chat_float.bufnr)
    local line_char_count = 0
    local words = {}

    local success, request_string = pcall(function()
        return vim.fn.json_encode(self.current_chat)
    end)

    if not success then
        print("Error: " .. json)
        return -1
    end

    local args = { "--silent", "--no-buffer", "-X", "POST", ollamachad.opts.chat_api_url, "-d", request_string }

    local response = {
        role = "assistant",
        content = "",
    }

    self.current_chat.messages[#self.current_chat.messages + 1] = response
    self.running = true

    local job = Job:new({
        command = "curl",
        args = args,
        on_stdout = function(_, data)
            vim.schedule(function()
                local success, result = pcall(function()
                    return vim.fn.json_decode(data)
                end)

                if not success then
                    print("Error: " .. result)
                    return
                end

                if not result.done then
                    local token = result.message.content

                    if string.match(token, "\n") then
                        line = line + 1
                        words = {}
                        line_char_count = 0
                        token = token:gsub("\n", "")
                    end

                    -- trim leading whitespace on new lines
                    if line_char_count == 0 then
                        token = token:gsub("^%s+", "")
                    end

                    line_char_count = line_char_count + #token

                    table.insert(words, token)

                    vim.api.nvim_buf_set_lines(
                        self.chat_float.bufnr,
                        line,
                        line + 1,
                        false,
                        { table.concat(words, "") }
                    )

                    -- scroll to bottom
                    vim.api.nvim_win_set_cursor(self.chat_float.winid, { line + 1, 0 })

                    -- save response
                    response.content = response.content .. result.message.content
                else
                    self.running = false
                end
            end)
        end,
        on_stderr = function(_, data)
            print("Error: " .. data)
        end,
    })

    job:start()
    return job.pid
end

return Chat
