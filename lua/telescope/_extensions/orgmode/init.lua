local orgmode = require('orgmode.api')

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local entry_display = require("telescope.pickers.entry_display")
local conf = require("telescope.config").values

-- TODO: include headline.level and headline.is_archived() as part of the
-- public orgmode api
-- TODO: add highlight groups
-- TODO: add action to refile/capture

local function get_entries(opts)

    local file_results = vim.tbl_map(function(file)
        return { file = file, filename = file.filename }
    end, orgmode.load())

    if not opts.archived then
        file_results = vim.tbl_filter(function(entry)
            return not entry.file.is_archive_file
        end, file_results)
    end

    if opts.max_depth == 0 then
        return file_results
    end

    local results = {}
    for _, file_entry in ipairs(file_results) do
        local agenda_file = orgmode.load(file_entry.filename)
        for _, headline in ipairs(agenda_file.headlines) do

            local allowed_depth = opts.max_depth == nil or headline._section.level <= opts.max_depth
            local allowed_archive = opts.archived or not headline._section:is_archived()
            if allowed_depth and allowed_archive then
                local entry = {
                    file = file_entry.file,
                    filename = file_entry.filename,
                    headline = headline
                }
                table.insert(results, entry)
            end
        end
    end

    return results
end

local function search_headings(opts)
    opts = opts or {}

    local displayer = entry_display.create({
        separator = ' ',
        items = {
            { width = vim.F.if_nil(opts.location_width, 20) },
            { remaining = true }
        }
    })

    local function make_display(entry)
        return displayer({ entry.location, entry.line })
    end

    pickers.new(opts, {
        prompt_title = "Search Headings",
        finder = finders.new_table {
            results = get_entries(opts),
            entry_maker = opts.entry_maker or function(entry)

                local headline = entry.headline

                local lnum = nil
                local location = vim.fn.fnamemodify(entry.filename, ':t')
                local line = ""

                if headline then
                    lnum = headline.position.start_line
                    location = string.format('%s:%i', location, lnum)
                    line = string.format('%s %s', string.rep('*', headline._section.level), headline.title)
                end

                return {
                    value = entry,
                    ordinal = location .. ' ' .. line,
                    filename = entry.filename,
                    lnum = lnum,
                    display = make_display,
                    location = location,
                    line = line
                }
            end,
        },
        sorter = conf.generic_sorter(opts),
        previewer = conf.grep_previewer(opts),
    }):find()
end

return require("telescope").register_extension {
    exports = {
        search_headings = search_headings,
    },
}
