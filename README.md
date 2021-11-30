# cmp-cmdline

nvim-cmp source for vim's cmdline.

# Setup

Completions for command mode:
```lua
require'cmp'.setup.cmdline(':', {
  sources = {
    { name = 'cmdline' }
  }
})
```

Completions for `/` search based on current buffer:
```lua
require'cmp'.setup.cmdline('/', {
  sources = {
    { name = 'buffer' }
  }
})
```

For the buffer source to work, [cmp-buffer](https://github.com/hrsh7th/cmp-buffer) is needed.
