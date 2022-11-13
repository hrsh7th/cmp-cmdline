local cmp = require('cmp')

local MODIFIER_REGEX = {
  vim.regex([=[abo\%[veleft]\s*]=]),
  vim.regex([=[bel\%[owright]\s*]=]),
  vim.regex([=[bo\%[tright]\s*]=]),
  vim.regex([=[bro\%[wse]\s*]=]),
  vim.regex([=[conf\%[irm]\s*]=]),
  vim.regex([=[hid\%[e]\s*]=]),
  vim.regex([=[keepal\s*t]=]),
  vim.regex([=[keeppa\%[tterns]\s*]=]),
  vim.regex([=[lefta\%[bove]\s*]=]),
  vim.regex([=[loc\%[kmarks]\s*]=]),
  vim.regex([=[nos\%[wapfile]\s*]=]),
  vim.regex([=[rightb\%[elow]\s*]=]),
  vim.regex([=[sil\%[ent]\s*]=]),
  vim.regex([=[tab\s*]=]),
  vim.regex([=[to\%[pleft]\s*]=]),
  vim.regex([=[verb\%[ose]\s*]=]),
  vim.regex([=[vert\%[ical]\s*]=]),
}
local COUNT_RANGE_REGEX = {
  vim.regex([=[\%(\d\+\|\$\),\%(\d\+\|\$\)\s*]=]),
  vim.regex([=['<,'>\s*]=]),
  vim.regex([=[\%(\d\+\|\$\)\s*]=]),
}

local OPTION_NAME_COMPLETION_REGEX = {
  vim.regex([=[se\%[tlocal]]=]),
}

local definitions = {
  {
    ctype = 'cmdline',
    regex = [=[[^[:blank:]]*$]=],
    kind = cmp.lsp.CompletionItemKind.Variable,
    isIncomplete = true,
    exec = function(arglead, cmdline, col, force)
      local suffix_pos = vim.regex([[\k*$]]):match_str(arglead)

      -- Support `lua vim.treesitter._get|` completion.
      -- In this case, the `vim.fn.getcompletion` will return only `get_query` for `vim.treesitter.get_|`.
      -- We should detect `vim.treesitter.` and `get_query` separately.
      local fixed_input = string.sub(arglead, 1, suffix_pos or #arglead)

      -- Cleanup modifiers.
      if arglead ~= cmdline then
        for _, re in ipairs(MODIFIER_REGEX) do
          local s, e = re:match_str(cmdline)
          if s and e then
            cmdline = string.sub(cmdline, e + 1)
            break
          end
        end
      end

      -- Cleanup range or count.
      local prefix = ''
      for _, re in ipairs(COUNT_RANGE_REGEX) do
        local s, e = re:match_str(cmdline)
        if s and e then
          if arglead == cmdline then
            prefix = string.sub(cmdline, 1, e)
          end
          cmdline = string.sub(cmdline, e + 1)
          break
        end
      end

      -- Ignore prefix only cmdline. (e.g.: 4, '<,'>)
      if not force and cmdline == '' then
        return {}
      end

      -- The `vim.fn.getcompletion` does not return `*no*cursorline` option.
      -- cmp-cmdline corrects `no` prefix for option name.
      local is_option_name_completion --[[@as string]]
      for _, re in ipairs(OPTION_NAME_COMPLETION_REGEX) do
        if re:match_str(cmdline) then
          is_option_name_completion = true
          break
        end
      end

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
        item.word = prefix .. item.word
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
