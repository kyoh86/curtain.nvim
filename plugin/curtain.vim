" curtain.vim
" Resize windows easily like open and close a curtain.
"
" AUTHOR: kyoh86 <me@kyoh86.dev>
" LICENSE: MIT

if exists("g:loaded_curtain")
  finish
endif
let g:loaded_curtain = 1

highlight default link CurtainWindow NONE

command! Curtain call curtain#start()
nnoremap <plug>(curtain-start) <cmd>call curtain#start()<cr>
