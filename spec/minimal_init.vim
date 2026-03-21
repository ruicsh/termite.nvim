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

" Mock jobstart to prevent spawning real shell processes during tests
" This avoids "too many open files" errors when running the full test suite
lua << EOF
local orig_jobstart = vim.fn.jobstart
vim.fn.jobstart = function(cmd, opts)
  -- Return a fake job ID without actually starting a process
  local job_id = math.random(1000, 9999)
  -- Schedule the on_exit callback if provided to simulate process exit
  if opts and opts.on_exit then
    vim.schedule(function()
      opts.on_exit(job_id, 0, "exit")
    end)
  end
  return job_id
end
EOF
