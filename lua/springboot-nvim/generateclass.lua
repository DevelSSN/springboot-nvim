-- lua/springboot-nvim/generateclass.lua

local api = vim.api
local utils = require("springboot-nvim.utils")

-- Java boilerplate templates
local templates = {
    class = "package %s;\n\npublic class %s {\n\n}",
    record = "package %s;\n\npublic record %s() {\n}",
    interface = "package %s;\n\npublic interface %s {\n\n}",
    enum = "package %s;\n\npublic enum %s {\n\n}"
}

local function generate_java_file(start_buf, type, package_buf, name_buf)
    local file_path = vim.fn.fnamemodify(start_buf, ':p')

    -- Get root path up to /java/
    local last_java_idx = nil
    local search_start = 1
    while true do
        local start_idx, end_idx = file_path:find("/java/", search_start)
        if not end_idx then break end
        last_java_idx = end_idx
        search_start = start_idx + 1
    end

    if not last_java_idx then
        print("Could not find /java/ folder in path")
        return
    end

    local root_path = file_path:sub(1, last_java_idx - 1)

    -- Get content from buffers
    local package_lines = api.nvim_buf_get_lines(package_buf, 0, -1, false)
    local class_lines = api.nvim_buf_get_lines(name_buf, 0, -1, false)
    local package_str = table.concat(package_lines):gsub("%s+", "")
    local class_str = table.concat(class_lines):gsub("%s+", "")

    if package_str == "" or class_str == "" then
        print("Package and class/interface/record/enum name cannot be empty")
        return
    end

    -- Convert package to file path
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
        print(type:sub(1,1):upper() .. type:sub(2) .. " already exists in package")
        existing_file:close()
        return
    end

    -- Remove trailing '.' from package if exists
    if package_str:sub(-1) == "." then
        package_str = package_str:sub(1, -2)
    end

    local template = templates[type]
    if not template then
        print("Unsupported type: " .. type)
        return
    end

    -- Write the new file
    local java_code = string.format(template, package_str, class_str)
    local file = io.open(full_file_path, "w")
    file:write(java_code)
    file:close()

    -- Open in current window
    vim.cmd("edit " .. vim.fn.fnameescape(full_file_path))
end

return {
    generate_java_file = generate_java_file
}
