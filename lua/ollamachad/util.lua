local M = {}

--- @return string
M.read_visiual_lines = function()
    vim.api.nvim_feedkeys("gv", "x", false)

    local start_row, start_col = unpack(vim.api.nvim_buf_get_mark(0, "<"))
    local end_row, end_col = unpack(vim.api.nvim_buf_get_mark(0, ">"))
    local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)

    if start_row == 0 then
        lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        start_row = 1
        start_col = 0
        end_row = #lines
        end_col = #lines[#lines]
    end

    start_col = start_col + 1
    end_col = math.min(end_col, #lines[#lines] - 1) + 1

    lines[#lines] = lines[#lines]:sub(1, end_col)
    lines[1] = lines[1]:sub(start_col)

    return table.concat(lines, "\n")
end

return M
