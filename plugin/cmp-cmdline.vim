let g:cmp_cmdline_cmdwin_active = v:false
augroup cmp_cmdline
	autocmd!
	autocmd CmdWinEnter * let g:cmp_cmdline_cmdwin_active = v:true
	autocmd CmdWinLeave * let g:cmp_cmdline_cmdwin_active = v:false
augroup END
