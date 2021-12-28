local cmp = require('cmp')

local definitions = {
  {
    ctype = 'cmdline',
    regex = [=[[^[:blank:]]*$]=],
    kind = cmp.lsp.CompletionItemKind.Variable,
    isIncomplete = true,
    exec = function(arglead, cmdline, _)
      local s = vim.regex([[\k*$]]):match_str(arglead)
      local input = string.sub(arglead, 1, s or #arglead)

      local items = vim.fn.getcompletion(cmdline, 'cmdline')
      items = vim.tbl_map(function(item)
        return type(item) == 'string' and { word = item } or item
      end, items)

      local filtered = vim.tbl_filter(function(item)
        return string.find(item.word, input, 1, true) == 1
      end, items)

      if #filtered == 0 then
        filtered = vim.tbl_map(function(item)
          item.word = input .. item.word
          return item
        end, items)
      end

      return filtered
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
  return (vim.api.nvim_get_mode().mode == 'c'
    or vim.api.nvim_get_var('cmp_cmdline_cmdwin_active') == true)
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

  -- Check the previous completion can merge (support both backspace and new any char).
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

