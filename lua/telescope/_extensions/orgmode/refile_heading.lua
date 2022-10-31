local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local action_set = require("telescope.actions.set")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local utils = require('orgmode-telescope.utils')

local Files = require('orgmode.parser.files')
local Capture = require('orgmode.capture')

return function(opts)
  opts = opts or {}

  -- TODO: this should be included in return from Files.get_current_file
  local has_capture, is_capture = pcall(vim.api.nvim_buf_get_var, 0, 'org_capture')

  local src_file = Files.get_current_file()
  local src_item = src_file:get_closest_headline()
  local src_lines = src_file:get_headline_lines(src_item)

  local function refile(prompt_bufnr)
    local entry = action_state.get_selected_entry()
    actions.close(prompt_bufnr)

    local dst_file = entry.value.file
    local dst_headline = entry.value.headline
    if dst_headline then
      -- NOTE: adapted from Capture:refile_to_headline
      if src_item and src_item.level <= dst_headline._section.level then
        -- Refiling in same file just moves the lines from one position
        -- to another,so we need to apply demote instantly
        local is_same_file = dst_file.filename == src_item.root.filename
        src_lines = src_item:demote(dst_headline._section.level - src_item.level + 1, true, not is_same_file)
      end
      local refiled = Capture:_refile_to(dst_file.filename, src_lines, src_item, dst_headline.position.end_line)
      if not refiled then
        return false
      end
      --utils.echo_info(string.format('Wrote %s', dst_file.filename))
      --return true
    else
      --return Capture:_refile_to_end(dst_file.filename, src_lines, src_item)
      Capture:_refile_to_end(dst_file.filename, src_lines, src_item)
    end

    if has_capture and is_capture then
      Capture:kill()
    end
  end

  local current_depth = opts.max_depth
  local next_depth = nil
  if current_depth ~= 0 then
    next_depth = 0
  end

  local function depth_toggle(prompt_bufnr)
    local current_picker = action_state.get_current_picker(prompt_bufnr)

    -- TODO: use action_state to store these to allow easy rebinding by users
    local aux = current_depth
    current_depth = next_depth
    next_depth = aux

    opts.max_depth = current_depth
    local new_finder = finders.new_table {
      results = utils.get_entries(opts),
      entry_maker = opts.entry_maker or utils.make_entry(opts),
    }

    current_picker:refresh(new_finder, opts)
  end

  pickers.new(opts, {
     -- TODO: alter prompt title when depth is 0: Refile under file, Refile
     -- under Headline
    prompt_title = "Refile Destination",
    finder = finders.new_table {
      results = utils.get_entries(opts),
      entry_maker = opts.entry_maker or utils.make_entry(opts),
    },
    sorter = conf.generic_sorter(opts),
    previewer = conf.grep_previewer(opts),
    attach_mappings = function(_, map)
      action_set.select:replace(refile)
      map("i", "<c-space>", depth_toggle)
      return true
    end,
  }):find()
end
