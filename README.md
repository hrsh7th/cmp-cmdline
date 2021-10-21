# cmp-cmdline

nvim-cmp source for vim's cmdline.

# Setup

```lua
require'cmp'.setup.cmdline(':', {
  sources = {
    { name = 'cmdline' }
  }
})
```

# Warning

This source will work after merged https://github.com/hrsh7th/nvim-cmp/pull/362

