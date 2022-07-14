# cmp-cmdline

nvim-cmp source for vim's cmdline.

# Setup

Completions for command mode:
```lua
require'cmp'.setup.cmdline(':', {
  sources = {
    { name = 'cmdline' }
  },
  mapping = cmp.mapping.preset.cmdline({})
})
```

Completions for `/` search based on current buffer:
```lua
require'cmp'.setup.cmdline('/', {
  sources = {
    { name = 'buffer' }
  },
  mapping = cmp.mapping.preset.cmdline({}),
})
```

For the buffer source to work, [cmp-buffer](https://github.com/hrsh7th/cmp-buffer) is needed.
