local cmp = require('cmp')

local function create_regex(patterns, head)
  local pattern = [[\%(]] .. table.concat(patterns, [[\|]]) .. [[\)]]
  if head then
    pattern = '^' .. pattern
  end
  return vim.regex(pattern)
end

local DEFAULT_OPTION = {
  ignore_cmds = { 'Man', '!' }
}

local MODIFIER_REGEX = create_regex({
  [=[\s*abo\%[veleft]\s*]=],
  [=[\s*bel\%[owright]\s*]=],
  [=[\s*bo\%[tright]\s*]=],
  [=[\s*bro\%[wse]\s*]=],
  [=[\s*conf\%[irm]\s*]=],
  [=[\s*hid\%[e]\s*]=],
  [=[\s*keepal\s*t]=],
  [=[\s*keeppa\%[tterns]\s*]=],
  [=[\s*lefta\%[bove]\s*]=],
  [=[\s*loc\%[kmarks]\s*]=],
  [=[\s*nos\%[wapfile]\s*]=],
  [=[\s*rightb\%[elow]\s*]=],
  [=[\s*sil\%[ent]\s*]=],
  [=[\s*tab\s*]=],
  [=[\s*to\%[pleft]\s*]=],
  [=[\s*verb\%[ose]\s*]=],
  [=[\s*vert\%[ical]\s*]=],
}, true)

local COUNT_RANGE_REGEX = create_regex({
  [=[\s*\%(\d\+\|\$\)\%[,\%(\d\+\|\$\)]\s*]=],
  [=[\s*'\%[<,'>]\s*]=],
  [=[\s*\%(\d\+\|\$\)\s*]=],
}, true)

local OPTION_NAME_COMPLETION_REGEX = create_regex({
  [=[se\%[tlocal]]=],
}, true)

local definitions = {
  {
    ctype = 'cmdline',
    regex = [=[[^[:blank:]]*$]=],
    kind = cmp.lsp.CompletionItemKind.Variable,
    isIncomplete = true,
    exec = function(option, arglead, cmdline, col, force)
      local _, parsed = pcall(function()
        local target = cmdline
        local s, e = COUNT_RANGE_REGEX:match_str(target)
        if s and e then
          target = target:sub(e + 1)
        end
        -- nvim_parse_cmd throw error when the cmdline contains range specifier.
        return vim.api.nvim_parse_cmd(target, {}) or {}
      end)
      parsed = parsed or {}

      -- Check ignore cmd.
      if vim.tbl_contains(option.ignore_cmds, parsed.cmd) then
        return {}
      end

      -- Cleanup modifiers.
      -- We can just remove modifiers because modifiers is always separated by space.
      if arglead ~= cmdline then
        while true do
          local s, e = MODIFIER_REGEX:match_str(cmdline)
          if s == nil then
            break
          end
          cmdline = string.sub(cmdline, e + 1)
        end
      end

      -- Support ":'<,'>del|".
      -- The `vim.fn.getcompletion` does not return `delete` command for this case.
      -- We should remove `'<,'>` for `vim.fn.getcompletion` and then after add the removed prefix for each completed items.
      if arglead == cmdline then
        while true do
          local s, e = COUNT_RANGE_REGEX:match_str(cmdline)
          if s == nil then
            break
          end
          cmdline = string.sub(cmdline, e + 1)
        end
      end

      -- Support `lua vim.treesitter._get|` or `'<,'>del|` completion.
      -- In this case, the `vim.fn.getcompletion` will return only `get_query` for `vim.treesitter.get_|`.
      -- We should detect `vim.treesitter.` and `get_query` separately.
      -- TODO: The `\h\w*` was choosed by huristic. We should consider more suitable detection.
      local fixed_input
      do
        local suffix_pos = vim.regex([[\h\w*$]]):match_str(arglead)
        fixed_input = string.sub(arglead, 1, suffix_pos or #arglead)
      end

      -- Ignore prefix only cmdline. (e.g.: 4, '<,'>)
      if not force and cmdline == '' then
        return {}
      end

      -- The `vim.fn.getcompletion` does not return `*no*cursorline` option.
      -- cmp-cmdline corrects `no` prefix for option name.
      local is_option_name_completion = OPTION_NAME_COMPLETION_REGEX:match_str(cmdline) ~= nil

      local items = {}
      local escaped = cmdline:gsub([[\\]], [[\\\\]]);
      for _, word_or_item in ipairs(vim.fn.getcompletion(escaped, 'cmdline')) do
        local word = type(word_or_item) == 'string' and word_or_item or word_or_item.word
        local item = { word = word }
        table.insert(items, item)
        if is_option_name_completion then
          table.insert(items, vim.tbl_deep_extend('force', {}, item, {
            word = 'no' .. item.word
          }))
        end
      end
      for _, item in ipairs(items) do
        if not string.find(item.word, fixed_input, 1, true) then
          item.word = fixed_input .. item.word
        end
      end
      return items
    end
  },
}

local source = {}

source.new = function()
  return setmetatable({
    before_line = '',
    offset = -1,
    ctype = '',
    items = {},
  }, { __index = source })
end

source.get_keyword_pattern = function()
  return [=[[^[:blank:]]*]=]
end

source.get_trigger_characters = function()
  return { ' ', '.', '#', '-' }
end

source.complete = function(self, params, callback)
  local offset = 0
  local ctype = ''
  local items = {}
  local kind = ''
  local isIncomplete = false
  for _, def in ipairs(definitions) do
    local s, e = vim.regex(def.regex):match_str(params.context.cursor_before_line)
    if s and e then
      offset = s
      ctype = def.type
      items = def.exec(
        vim.tbl_deep_extend('keep', params.option, DEFAULT_OPTION),
        string.sub(params.context.cursor_before_line, s + 1),
        params.context.cursor_before_line,
        params.context.cursor.col,
        params.context:get_reason() == cmp.ContextReason.Manual
      )
      kind = def.kind
      isIncomplete = def.isIncomplete
      if not (#items == 0 and def.fallback) then
        break
      end
    end
  end

  local labels = {}
  items = vim.tbl_map(function(item)
    if type(item) == 'string' then
      item = { label = item, kind = kind }
    else
      item = { label = item.word, kind = kind }
    end
    labels[item.label] = true
    return item
  end, items)

  -- `vim.fn.getcompletion` does not handle fuzzy matches. So, we must return all items, including items that were matched in the previous input.
  local should_merge_previous_items = false
  if #params.context.cursor_before_line > #self.before_line then
    should_merge_previous_items = string.find(params.context.cursor_before_line, self.before_line, 1, true) == 1
  elseif #params.context.cursor_before_line < #self.before_line then
    should_merge_previous_items = string.find(self.before_line, params.context.cursor_before_line, 1, true) == 1
  end

  if should_merge_previous_items and self.offset == offset and self.ctype == ctype then
    for _, item in ipairs(self.items) do
      if not labels[item.label] then
        table.insert(items, item)
      end
    end
  end
  self.before_line = params.context.cursor_before_line
  self.offset = offset
  self.ctype = ctype
  self.items = items

  callback({
    isIncomplete = isIncomplete,
    items = items,
  })
end

return source
