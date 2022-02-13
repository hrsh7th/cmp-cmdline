local cmp = require('cmp')

local MODIFIER_REGEX = {
  vim.regex([=[abo\%[veleft]]=]),
  vim.regex([=[bel\%[owright]]=]),
  vim.regex([=[bo\%[tright]]=]),
  vim.regex([=[bro\%[wse]]=]),
  vim.regex([=[conf\%[irm]]=]),
  vim.regex([=[hid\%[e]]=]),
  vim.regex([=[keepalt]=]),
  vim.regex([=[keeppa\%[tterns]]=]),
  vim.regex([=[lefta\%[bove]]=]),
  vim.regex([=[loc\%[kmarks]]=]),
  vim.regex([=[nos\%[wapfile]]=]),
  vim.regex([=[rightb\%[elow]]=]),
  vim.regex([=[sil\%[ent]]=]),
  vim.regex([=[tab]=]),
  vim.regex([=[to\%[pleft]]=]),
  vim.regex([=[verb\%[ose]]=]),
  vim.regex([=[vert\%[ical]]=]),
}
local COUNT_RANGE_REGEX = {
  vim.regex([=[\%(\d\+\|\$\),\%(\d\+\|\$\)]=]),
  vim.regex([=[\%(\d\+\|\$\)]=]),
}

local definitions = {
  {
    ctype = 'cmdline',
    regex = [=[[^[:blank:]]*$]=],
    kind = cmp.lsp.CompletionItemKind.Variable,
    isIncomplete = true,
    exec = function(arglead, cmdline, _)
      local suffix_pos = vim.regex([[\k*$]]):match_str(arglead)
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

      local items = {}
      for _, item in ipairs(vim.fn.getcompletion(cmdline, 'cmdline')) do
        item = type(item) == 'string' and { word = item } or item
        item.word = prefix .. item.word
        if not string.find(item.word, fixed_input, 1, true) then
          item.word = fixed_input .. item.word
        end
        table.insert(items, item)
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

source.is_available = function()
  return vim.api.nvim_get_mode().mode == 'c'
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
        params.context.cursor.col
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

