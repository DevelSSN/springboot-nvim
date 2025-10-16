-- lua/springboot-nvim/generateclass.lua

local api = vim.api
local utils = require("springboot-nvim.utils")
local ui_utils = require("springboot-nvim.ui.ui_utils")

local buf, win, start_buf
local windows, bufs

-- Java boilerplate templates
local templates = {
    class = "package %s;\n\npublic class %s {\n\n}",
    record = "package %s;\n\npublic record %s() {\n}",
    interface = "package %s;\n\npublic interface %s {\n\n}",
    enum = "package %s;\n\npublic enum %s {\n\n}"
}

local function generate_java_file(start_buf, type, package_buf, name_buf)
    local file_path = vim.fn.fnamemodify(start_buf, ':p')
    local last_java_idx = nil
    local search_start = 1

    while true do
        local start_idx = string.find(file_path, "/java/", search_start)
        if not start_idx then break end
        last_java_idx = start_idx + 5
        search_start = start_idx + 1
    end

    if not last_java_idx then
        print("Could not find /java/ folder in path")
        return
    end

    local root_path = file_path:sub(1, last_java_idx - 1)

    -- Get buffer contents
    local package_lines = api.nvim_buf_get_lines(package_buf, 0, -1, false)
    local class_lines = api.nvim_buf_get_lines(name_buf, 0, -1, false)
    local package_str = table.concat(package_lines):gsub("%s+", "")
    local class_str = table.concat(class_lines):gsub("%s+", "")

    if package_str == "" or class_str == "" then
        print("Package and class/interface/record/enum name cannot be empty")
        return
    end

    -- Clean up package string
    if package_str:sub(-1) == "." then
        package_str = package_str:sub(1, -2)
    end

    local package_path = package_str:gsub("%.", "/")
    if package_path:sub(-1) ~= "/" then
        package_path = package_path .. "/"
    end

    local full_dir = root_path .. "/" .. package_path
    local full_file_path = full_dir .. class_str .. ".java"

    -- Ensure directory exists
    if vim.fn.isdirectory(full_dir) ~= 1 then
        os.execute("mkdir -p " .. full_dir)
    end

    -- Prevent overwriting
    local existing_file = io.open(full_file_path, "r")
    if existing_file then
        print(type:sub(1, 1):upper() .. type:sub(2) .. " already exists in package")
        existing_file:close()
        return
    end

    local template = templates[type]
    if not template then
        print("Unsupported type: " .. type)
        return
    end

    -- Write Java boilerplate
    local java_code = string.format(template, package_str, class_str)
    local file = io.open(full_file_path, "w")
    file:write(java_code)
    file:close()

    require("springboot-nvim.generateclass").close_generate_class()

    -- Open the new file
    vim.cmd("edit " .. vim.fn.fnameescape(full_file_path))
end

local function close_generate_class()
    for _, w in ipairs(windows or {}) do
        if vim.api.nvim_win_is_valid(w) then
            vim.api.nvim_win_close(w, true)
        end
    end
    for _, b in ipairs(bufs or {}) do
        if vim.api.nvim_buf_is_valid(b) then
            vim.api.nvim_buf_delete(b, { force = true })
        end
    end
end

local function create_package_ui(row, col, width, height, file_path)
    local package_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(package_buf, 'filetype', 'springbootnvim')

    local opts = {
        style = 'minimal',
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        zindex = 102
    }

    local package = ui_utils.package_text(file_path)
    api.nvim_buf_set_lines(package_buf, 0, -1, false, { package })

    local package_win = api.nvim_open_win(package_buf, true, opts)

    table.insert(windows, package_win)
    table.insert(bufs, package_buf)

    return {
        buf = package_buf,
        win = package_win
    }
end

local function create_class_ui(row, col, width, height)
    local class_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(class_buf, 'filetype', 'springbootnvim')

    local opts = {
        style = 'minimal',
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        zindex = 102
    }

    api.nvim_buf_set_lines(class_buf, 0, -1, false, { "" })

    local class_win = api.nvim_open_win(class_buf, true, opts)

    table.insert(windows, class_win)
    table.insert(bufs, class_buf)

    return {
        buf = class_buf,
        win = class_win
    }
end

local function set_mappings()
    vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', [[<Cmd>lua require("springboot-nvim.generateclass").generate_class()<CR>]], { noremap = true, silent = true })
end

local function draw_package_section()
    return {
        ui_utils.center_text("Enter package path:"),
        ""
    }
end

local function draw_class_section()
    return {
        ui_utils.center_text("Enter class/interface/record/enum name:"),
        ""
    }
end

local function create_ui(bufnr)
    start_buf = vim.fn.bufname(bufnr)
    local file_path = vim.fn.fnamemodify(start_buf, ':p')
    local project_root = utils.get_spring_boot_project_root(file_path)
    local main_class_dir = utils.find_main_application_class_directory(project_root)

    windows = {}
    bufs = {}

    buf = api.nvim_create_buf(false, true)
    table.insert(bufs, buf)
    api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

    local border_buf = api.nvim_create_buf(false, true)
    table.insert(bufs, border_buf)

    local width = 60
    local height = 8
    local row = math.floor((vim.fn.winheight(0) - height) / 2)
    local col = math.floor((vim.fn.winwidth(0) - width) / 2)

    local border_opts = {
        style = 'minimal',
        relative = 'editor',
        width = width + 2,
        height = height + 2,
        row = row - 1,
        col = col - 1,
        zindex = 99
    }

    local opts = {
        style = 'minimal',
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        zindex = 100
    }

    local outline = ui_utils.draw_border(width, height)
    api.nvim_buf_set_lines(border_buf, 0, -1, false, outline)

    local border_win = api.nvim_open_win(border_buf, true, border_opts)
    table.insert(windows, border_win)

    win = api.nvim_open_win(buf, true, opts)
    table.insert(windows, win)

    api.nvim_buf_set_lines(buf, 0, -1, false, { ui_utils.center_text("Generate Class") })
    api.nvim_buf_set_lines(buf, 1, -1, false, draw_package_section())
    api.nvim_buf_set_lines(buf, 5, -1, false, draw_class_section())
    api.nvim_buf_set_lines(buf, 8, -1, false, { ui_utils.center_text("Confirm selections with <Enter>") })

    local package_area = create_package_ui(row + 2, col + 10, 48, 1, main_class_dir)
    local class_area = create_class_ui(row + 5, col + 10, 25, 1)

    api.nvim_set_current_win(package_area.win)
    local first_line = vim.fn.getline(1)
    api.nvim_win_set_cursor(package_area.win, { 1, #first_line[1] })

    set_mappings()

    -- Save buffers for later access
    bufs.package = package_area.buf
    bufs.class = class_area.buf
end

local function generate_class()
    generate_java_file(start_buf, "class", bufs.package, bufs.class)
end

return {
    create_ui = create_ui,
    generate_class = generate_class,
    generate_java_file = generate_java_file,
    close_generate_class = close_generate_class,
}
