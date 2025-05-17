# cmp-cmdline

nvim-cmp source for vim's cmdline.

# Setup

Completions for `/` search based on current buffer:
```lua
    -- `/` cmdline setup.
    cmp.setup.cmdline('/', {
      mapping = cmp.mapping.preset.cmdline(),
      sources = {
        { name = 'buffer' }
      }
    })
```

Completions for command mode:
```lua
    -- `:` cmdline setup.
    cmp.setup.cmdline(':', {
      mapping = cmp.mapping.preset.cmdline(),
      sources = cmp.config.sources({
        { name = 'path' }
      }, {
        {
          name = 'cmdline',
          option = {
            ignore_cmds = { 'Man', '!' }
          }
        }
      })
    })
```

For the buffer source to work, [cmp-buffer](https://github.com/hrsh7th/cmp-buffer) is needed.


# Option

### ignore_cmds: string[]
Default: `{ "Man", "!" }`

You can specify ignore command name.

### treat_trailing_slash: boolean
Default: `true`

`vim.fn.getcompletion` can return path items.
unfortunately, that items has trailing slash so we don't narrowing with next directory with pressing `/`.

if you turned on this option, `cmp-cmdline` removes trailing slash automatically.
