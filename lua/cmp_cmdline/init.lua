local cmp = require('cmp')

local definitions = {
  {
    type = 'option',
    regex = [=[&[^[:blank:]]*$]=],
    kind = cmp.lsp.CompletionItemKind.Variable,
    isIncomplete = false,
    exec = function(_, _, _)
      return vim.fn.getcompletion('', 'option')
    end
  },
  {
    type = 'environment',
    regex = [=[\$[^[:blank:]]*$]=],
    kind = cmp.lsp.CompletionItemKind.Variable,
    isIncomplete = false,
    exec = function(_, _, _)
      return vim.fn.getcompletion('', 'environment')
    end
  },
  {
    type = 'customlist',
    regex = [=[\%(\k\)*$]=],
    kind = cmp.lsp.CompletionItemKind.Variable,
    fallback = true,
    isIncomplete = false,
    exec = function(arglead, cmdline, curpos)
      local name = cmdline:match([=[^[ <'>]*(%a*)]=])
      if not name then
        return {}
      end
      for name_, option in pairs(vim.api.nvim_get_commands({ builtin = false })) do
        if name_ == name then
          if vim.tbl_contains({ 'customlist', 'custom' }, option.complete) then
            local ok, items = pcall(function()
              local func = string.gsub(option.complete_arg, 's:', ('<SNR>%d_'):format(option.script_id))
              return vim.api.nvim_call_function(func, { arglead, cmdline, curpos })
            end)
            if not ok then
              return {}
            end
            if type(items) == 'string' then
              return vim.split(items, '\n')
            elseif type(items) == 'table' then
              return items
            end
            return {}
          end
        end
      end
      return {}
    end
  },
  {
    type = 'cmdline',
    regex = [=[.*]=],
    kind = cmp.lsp.CompletionItemKind.Variable,
    isIncomplete = true,
    exec = function(arglead, _, _)
      return vim.fn.getcompletion(arglead, 'cmdline')
    end
  },
}

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.get_keyword_pattern = function()
  return [=[\h\%(\w\|-\|\/\|#\|:\|\.\)*]=]
end

source.get_trigger_characters = function()
  return { '$', ':', '!', '&', ' ' }
end

source.is_available = function()
  return vim.api.nvim_get_mode().mode == 'c'
end

source.complete = function(_, params, callback)
  local items, kind, isIncomplete = {}, cmp.lsp.CompletionItemKind.Text, false
  for _, type in ipairs(definitions) do
    local s, e = vim.regex(type.regex):match_str(params.context.cursor_before_line)
    if s and e then
      items = type.exec(
        string.sub(params.context.cursor_before_line, s + 1, e + 1),
        params.context.cursor_before_line,
        params.context.cursor.col
      )
      kind = type.kind
      isIncomplete = type.isIncomplete
      if not (#items == 0 and type.fallback) then
        break
      end
    end
  end

  callback({
    isIncomplete = isIncomplete,
    items = vim.tbl_map(function(item)
      if type(item) == 'string' then
        return {
          label = item,
          kind = kind,
        }
      end
      return {
        label = item.word,
        kind = kind,
      }
    end, items)
  })
end

return source

