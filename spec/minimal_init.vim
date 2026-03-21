" Minimal init for plenary tests
set noswapfile
set nobackup
set nowritebackup
set nocompatible
set hidden

" Add plugin to runtimepath
let g:termite_test_root = expand('<sfile>:p:h:h')
execute 'set rtp+=' . g:termite_test_root

" Initialize termite for testing
lua require('termite').setup({})
