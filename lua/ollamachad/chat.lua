local Job = require("plenary.job")
local Popup = require("nui.popup")
local Layout = require("nui.layout")
local Text = require("nui.text")
local ollamachad = require("ollamachad")

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

---@class Keymap
---@field clear string
---@field send string
---@field quit string
---@field select string
---@field tab string
---@field context string
---@field reload string

---@class ModelOptions
---@description checkout all options @https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values
---@field temperature ?float
---@field num_predict ?integer
---@field num_ctx ?integer

---@class ChatConfig
---@field keymap ?Keymap
---@field cache_file ?string
---@field system_prompt ?string
---@field show_keys ?boolean
---@field model_options ?ModelOptions
---@type ChatConfig
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
        temperature = 0.7,
    },
}

---@class Message
---@field role string
---@field content string

---@class CurrentChat
---@field model string
---@field messages Message[]
---@field options ModelOptions

---@class Chat
---@field opts ChatConfig
---@field layout NuiLayout
---@field chat_float NuiPopup
---@field prompt_float NuiPopup
---@field available_models string[]
---@field model string
---@field toggle function
---@field context string
---@field prompt_bufnr number
---@field chat_bufnr number
---@field private visible boolean
---@field private running boolean
---@field private current_chat CurrentChat
local Chat = {}

--- create a new chat instance
--- @param opts ChatConfig
function Chat:new(opts)
    opts = vim.tbl_deep_extend("force", default_chat_config, opts or {})

    local chat = {
        opts = vim.tbl_deep_extend("force", default_chat_config, opts or {}),
        model = "",
        chat_bufnr = vim.api.nvim_create_buf(false, true),
        prompt_bufnr = vim.api.nvim_create_buf(false, true),
        visible = false,
        context = "",
    }

    setmetatable(chat, self)
    self.__index = self

    chat:clear_chat()
    chat:load_available_models()
    chat:load_model()

    return chat
end

function Chat:create_modal()
    local chat_float = Popup({
        bufnr = self.chat_bufnr,
        focusable = true,
        border = {
            highlight = "FloatBorder",
            style = "rounded",
            text = {
                top = "[ no model selected ]",
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
        bufnr = self.prompt_bufnr,
        focusable = true,
        enter = true,
        border = {
            highlight = "FloatBorder",
            style = "rounded",
            text = {
                top = "[ Prompt ]",
                bottom = (function()
                    if self.opts.show_keys == true then
                        return "[ "
                            .. self.opts.keymap.reload
                            .. ": load ctx    "
                            .. self.opts.keymap.clear
                            .. ": clear    "
                            .. self.opts.keymap.select
                            .. ": select ]"
                    else
                        return ""
                    end
                end)(),
            },
        },
    })

    local layout = Layout(
        {
            position = 0.5,
            size = {
                width = "80%",
                height = "80%",
            },
        },
        Layout.Box({
            Layout.Box(chat_float, { size = 0.85 }),
            Layout.Box(prompt_float, { size = 0.15 }),
        }, { dir = "col" })
    )

    prompt_float:map("n", self.opts.keymap.send, function()
        self:send()
    end)

    chat_float:map("n", self.opts.keymap.quit, function()
        self:toggle()
    end)

    prompt_float:map("n", self.opts.keymap.quit, function()
        self:toggle()
    end)

    prompt_float:map("n", self.opts.keymap.clear, function()
        self:clear_chat()
    end)

    prompt_float:map("n", self.opts.keymap.reload, function()
        self:load_context_files()
        self:draw_header()
    end)

    prompt_float:map("n", self.opts.keymap.context, function()
        vim.g.ollamachad_marked_files = {}
        self.context = ""
        self:draw_header()
    end)

    prompt_float:map("n", self.opts.keymap.select, function()
        pickers
            .new({}, {
                prompt_title = "pick a model",
                finder = finders.new_table({
                    results = self.available_models,
                }),
                layout_config = {
                    vertical = {
                        width = 0.3,
                        height = 0.3,
                    },
                    horizontal = {
                        width = 0.3,
                        height = 0.3,
                    },
                },
                sorter = conf.generic_sorter(self.opts),
                attach_mappings = function(prompt_bufnr, map)
                    actions.select_default:replace(function()
                        actions.close(prompt_bufnr)
                        local selection = action_state.get_selected_entry()
                        if #selection[1] > 0 then
                            local model = selection[1]
                            self:set_model(model)
                            self:save_model()
                        end
                    end)
                    return true
                end,
            })
            :find()
    end)
    chat_float:map("n", self.opts.keymap.tab, "<C-w>W", { silent = true })
    prompt_float:map("n", self.opts.keymap.tab, "<C-w>w", { silent = true })

    self.chat_float = chat_float
    self.prompt_float = prompt_float
    self.layout = layout
    self:draw_header()
end


--- set model
function Chat:set_model(model)
    self.model = model
    self.current_chat.model = model
end

function Chat:draw_header()
    local header = "model: " .. self.model

    header = header
        .. "    context size: "
        .. #self.context
        .. "    marked files: "
        .. #vim.g.ollamachad_marked_files
        .. "    temp: "
        .. self.opts.model_options.temperature
    self.chat_float.border:set_text("top", header, "center")
end

--- save model to cache file
function Chat:save_model()
    local f, err = io.open(self.opts.cache_file, "w+")

    if err ~= nil then
        print(err)
        return
    end

    if f == nil then
        print("file handle went missing")
        return
    end

    f:write(self.model)
    f:close()
end

--- load model from cache file
function Chat:load_model()
    local f, err = io.open(self.opts.cache_file, "r")
    if err ~= nil then
        print(err)
        return
    end

    if f == nil then
        print("file handle went missing")
        return
    end

    local model = f:read("*a")
    f:close()

    if model ~= nil then
        self:set_model(model)
    elseif #self.available_models > 0 then
        self:set_model(self.available_models[1])
    end
end

--- clearing the chat buffer
function Chat:clear_chat()
    vim.api.nvim_buf_set_lines(self.chat_bufnr, 0, -1, false, {})
    self:load_context_files()
    self.current_chat = {
        model = self.model,
        options = self.opts.model_options,
        messages = {
            {
                role = "system",
                content = self.opts.system_prompt,
            },
            {
                role = "system",
                content = "<context>" .. self.context .. "</context>",
            },
        },
    }

end

--- load context from files
function Chat:load_context_files()
    local files_content = {}

    for _, file_path in ipairs(vim.g.ollamachad_marked_files) do
        local handle = io.open(file_path, "r") -- Open the file in read-only mode

        if not handle then
            print("Could not open file: " .. file_path)
            goto continue
        end

        local buffer_content = handle:read("*a") -- Read the entire content of the file as a string
        handle:close()
        table.insert(files_content, "<file name=" .. file_path .. ">\n" .. buffer_content .. "\n</file>")
        ::continue::
    end
    self.context = table.concat(files_content)

    ::continue::
end

--- send and recieve the current prompt
function Chat:send()
    if self.running then
        print("Already running or stuck. Try restart")
        return
    end

    local prompt_buffer = vim.api.nvim_buf_get_lines(self.prompt_float.bufnr, 0, -1, false)
    local prompt_string = table.concat(prompt_buffer, " ")

    -- remove line
    vim.api.nvim_buf_set_lines(self.prompt_bufnr, 0, -1, false, {})

    for i, line in ipairs(prompt_buffer) do
        prompt_buffer[i] = "# " .. line
    end
    prompt_buffer[#prompt_buffer + 1] = ""

    -- insert into chat
    vim.api.nvim_buf_set_lines(self.chat_bufnr, -1, -1, false, prompt_buffer)

    self.current_chat.messages[#self.current_chat.messages + 2] = {
        role = "user",
        content = prompt_string,
    }

    self:prompt()
end

--- toggles chat window
function Chat:toggle()
    if self.visible then
        self.layout:unmount()
        self.visible = false
    else
        self:create_modal()
        self.layout:show()
        self.layout:update()
        self.visible = true
        self:draw_header()
    end
end

--- load available models from api
function Chat:load_available_models()
    local url = ollamachad.opts.api_url .. "/tags"
    local args = { "-s", "--no-buffer", "-X", "GET", url }

    self.available_models = {}
    Job:new({
        command = "curl",
        args = args,
        on_exit = function(j, _)
            vim.schedule(function()
                local success, result = pcall(function()
                    local res = j:result()
                    return vim.fn.json_decode(res[1])
                end)

                for i, v in ipairs(result.models) do
                    table.insert(self.available_models, v.model)
                end
            end)
        end,
    }):start()
end

--- prompt the current chat.
--- @return string|integer|function - error | pid
function Chat:prompt()
    local line = vim.api.nvim_buf_line_count(self.chat_float.bufnr)
    local line_char_count = 0
    local words = {}

    local success, request_string = pcall(function()
        return vim.fn.json_encode(self.current_chat)
    end)

    if not success then
        return "failed to parse json"
    end

    local url = ollamachad.opts.api_url .. "/chat"
    local args = { "--silent", "--no-buffer", "-X", "POST", url, "-d", request_string }

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

                if result and not result.done then
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
                        self.chat_bufnr,
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
