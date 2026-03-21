" Minimal init for plenary tests
set noswapfile
set nobackup
set nowritebackup
set nocompatible
set hidden

" Add plugin to runtimepath
let g:termite_test_root = expand('<sfile>:p:h:h')
execute 'set rtp+=' . g:termite_test_root

" Add plenary.nvim to runtimepath (needed for CI)
let g:plenary_path = g:termite_test_root . '/vendor/plenary.nvim'
if isdirectory(g:plenary_path)
  execute 'set rtp+=' . g:plenary_path
endif

" Initialize termite for testing
lua require('termite').setup({})
