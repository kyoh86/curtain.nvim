" curtain.vim
" Resize windows easily like a curtain.
"
" AUTHOR: kyoh86 <me@kyoh86.dev>
" LICENSE: MIT

"TODO: support changing keys
let s:keys = {
      \ 'Focus left':  '<left>',
      \ 'Focus below': '<down>',
      \ 'Focus above': '<up>',
      \ 'Focus right': '<right>',
      \
      \ 'Increase left':  'h',
      \ 'Increase below': 'j',
      \ 'Increase above': 'k',
      \ 'Increase right': 'l',
      \
      \ 'Decrease left':  'H',
      \ 'Decrease below': 'J',
      \ 'Decrease above': 'K',
      \ 'Decrease right': 'L',
      \ }

let s:behaviors = ['Focus', 'Increase', 'Decrease']

function! s:call_on_winid(t_winid, callback) " never abort
  " call a function on the target window (window-ID)
  let l:c_winid = win_getid(winnr())
  if l:c_winid isnot a:t_winid
    let s:curtain_moving = v:true
    call win_gotoid(a:t_winid)
  endif
  call a:callback()
  if l:c_winid isnot a:t_winid
    call win_gotoid(l:c_winid)
    let s:curtain_moving = v:false
  endif
  stopinsert
endfunction

function! s:wincmd(winnr, cmd) abort
  " call wincmd on the target window (win-number)
  call s:call_on_winid(win_getid(a:winnr), { -> execute('wincmd ' . a:cmd) })
endfunction

function! s:fix_width(exceptions) abort
  let l:winnr = 1
  let l:wincnt = winnr('$')
  let g:curtain#__undo = {}
  while l:winnr <= l:wincnt
    let g:curtain#__undo[l:winnr] = getwinvar(l:winnr, '&winfixwidth')
    call setwinvar(l:winnr, '&winfixwidth', get(a:exceptions, l:winnr, 1))
    let l:winnr = l:winnr + 1
  endwhile
endfunction

function! s:release_width() abort
  for l:winnr in keys(g:curtain#__undo)
    call setwinvar(l:winnr, '&winfixwidth', g:curtain#__undo[l:winnr])
  endfor
endfunction

function! s:fix_height(exceptions) abort
  let l:winnr = 1
  let l:wincnt = winnr('$')
  let g:curtain#__undo = {}
  while l:winnr <= l:wincnt
    let g:curtain#__undo[l:winnr] = getwinvar(l:winnr, '&winfixheight')
    call setwinvar(l:winnr, '&winfixheight', get(a:exceptions, l:winnr, 1))
    let l:winnr = l:winnr + 1
  endwhile
endfunction

function! s:release_height() abort
  for l:winnr in keys(g:curtain#__undo)
    call setwinvar(l:winnr, '&winfixheight', g:curtain#__undo[l:winnr])
  endfor
endfunction

function! s:get_key_guide_text(key) abort
  return a:key . ': ' . s:keys[a:key]
endfunction

function! s:get_edge_guide_text(edge) abort
  return map(copy(s:behaviors), {_, v -> s:get_key_guide_text(v . ' ' . a:edge)})
endfunction

function! s:get_centered_text(text, width) abort
  " pad left to center the text
  let l:padding = a:width - len(a:text)
  if l:padding > 0
    return repeat(' ', l:padding/2) . a:text
  endif
  return a:text
endfunction

function! s:get_winnrs(dict) abort
  let a:dict['left'] = winnr('h')
  let a:dict['below'] = winnr('j')
  let a:dict['above'] = winnr('k')
  let a:dict['right'] = winnr('l')
  let a:dict['cur'] = winnr()
endfunction

function! s:set_guide(under_winid, float_winid, float_bufnr) abort
  " set guide messages on the buffer
  let l:under_win = getwininfo(a:under_winid)[0]
  call nvim_win_set_height(a:float_winid, l:under_win.height)
  call nvim_win_set_width(a:float_winid, l:under_win.width)
  let l:winnrs = {}
  call s:call_on_winid(a:under_winid, { -> s:get_winnrs(l:winnrs) })

  " pad lines
  silent! call deletebufline(a:float_bufnr, 1,  '$')
  for l:row in range(l:under_win.height)
    call setbufline(a:float_bufnr, l:row, ' ')
  endfor

  if l:winnrs['above'] isnot l:winnrs['cur']
    call setbufline(a:float_bufnr, 1, s:get_centered_text(join(s:get_edge_guide_text('above'), '; '), l:under_win.width))
  endif

  if l:winnrs['left'] isnot l:winnrs['cur']
    let l:show_left = l:under_win.height >= len(s:behaviors) + 2
  else
    let l:show_left = v:false
  endif

  if l:winnrs['right'] isnot l:winnrs['cur']
    let l:show_right = l:under_win.height >= len(s:behaviors) + 2
  else
    let l:show_right = v:false
  endif

  if l:winnrs['below'] isnot l:winnrs['cur']
    call setbufline(a:float_bufnr, l:under_win.height, s:get_centered_text(join(s:get_edge_guide_text('below'), '; '), l:under_win.width))
  endif

  if l:show_left || l:show_right
    let l:side_msg_row = l:under_win.height/2-1
    let l:left_msg = s:get_edge_guide_text('left')
    let l:right_msg = s:get_edge_guide_text('right')
    for l:row in range(len(s:behaviors))
      if l:show_left
        let l:left_msgline = l:left_msg[l:row]
      else
        let l:left_msgline = ''
      endif
      if l:show_right
        let l:right_msgline = l:right_msg[l:row]
      else
        let l:right_msgline = ''
      endif
      let l:space = l:under_win.width - len(l:left_msgline) - len(l:right_msgline)
      if l:space < 1
        call setbufline(a:float_bufnr, l:side_msg_row + l:row, ' ')
      else
        call setbufline(a:float_bufnr, l:side_msg_row + l:row, l:left_msgline . repeat(' ', l:space) . l:right_msgline)
      endif
    endfor
  endif
endfunction

function! s:set_style(float_winid) abort
  " set styles for float-window
  " set winblend=10
  call nvim_win_set_option(a:float_winid, 'winhighlight', 'Normal:CurtainWindow,NormalNC:CurtainWindow')
  call nvim_win_set_option(a:float_winid, 'winblend', 10)
endfunction

function! s:set_keymap(under_winid, float_winid, float_bufnr) abort
  " set keymaps on the buffer
  let l:opt = {'noremap': v:true, 'silent': v:true, 'nowait': v:true}
  let l:under_win = getwininfo(a:under_winid)[0]
  let l:winnrs = {}
  call s:call_on_winid(a:under_winid, { -> s:get_winnrs(l:winnrs) })
  call nvim_buf_set_keymap(a:float_bufnr, 'n', '<enter>', '<cmd>call <sid>leave_float_win(' . a:float_bufnr . ', v:false)<cr>', l:opt)
  call nvim_buf_set_keymap(a:float_bufnr, 'n', '<esc>', '<cmd>call <sid>leave_float_win(' . a:float_bufnr . ', v:false)<cr>', l:opt)
  call nvim_buf_set_keymap(a:float_bufnr, 'n', '<C-w>', '<nop>', l:opt)

  if l:winnrs['left'] isnot l:winnrs['cur']
    call nvim_buf_set_keymap(a:float_bufnr, 'n', s:keys['Focus left'], '<cmd>call <sid>leave_float_win(' . a:float_bufnr . ', v:false)<cr><cmd>call <sid>focus(' . l:winnrs['left'] . ')<cr>', l:opt)
    call nvim_buf_set_keymap(a:float_bufnr, 'n', s:keys['Increase left'], '<cmd>call <sid>fix_width({'.l:winnrs['cur'].':0,'.l:winnrs['left'].':0})<cr><cmd>call <sid>wincmd(' . l:winnrs['left'] . ', "<")<cr><cmd>call <sid>set_guide(' . a:under_winid . ', ' . a:float_winid . ', ' . a:float_bufnr . ')<cr><cmd>call <sid>release_width()<cr>', l:opt)
    call nvim_buf_set_keymap(a:float_bufnr, 'n', s:keys['Decrease left'], '<cmd>call <sid>fix_width({'.l:winnrs['cur'].':0,'.l:winnrs['left'].':0})<cr><cmd>call <sid>wincmd(' . l:winnrs['left'] . ', ">")<cr><cmd>call <sid>set_guide(' . a:under_winid . ', ' . a:float_winid . ', ' . a:float_bufnr . ')<cr><cmd>call <sid>release_width()<cr>', l:opt)
  endif

  if l:winnrs['above'] isnot l:winnrs['cur']
    call nvim_buf_set_keymap(a:float_bufnr, 'n', s:keys['Focus above'], '<cmd>call <sid>leave_float_win(' . a:float_bufnr . ', v:false)<cr><cmd>call <sid>focus(' . l:winnrs['above'] . ')<cr>', l:opt)
    call nvim_buf_set_keymap(a:float_bufnr, 'n', s:keys['Increase above'], '<cmd>call <sid>fix_height({'.l:winnrs['cur'].':0,'.l:winnrs['above'].':0})<cr><cmd>call <sid>wincmd(' . l:winnrs['above'] . ', "-")<cr><cmd>call <sid>set_guide(' . a:under_winid . ', ' . a:float_winid . ', ' . a:float_bufnr . ')<cr><cmd>call <sid>release_height()<cr>', l:opt)
    call nvim_buf_set_keymap(a:float_bufnr, 'n', s:keys['Decrease above'], '<cmd>call <sid>fix_height({'.l:winnrs['cur'].':0,'.l:winnrs['above'].':0})<cr><cmd>call <sid>wincmd(' . l:winnrs['above'] . ', "+")<cr><cmd>call <sid>set_guide(' . a:under_winid . ', ' . a:float_winid . ', ' . a:float_bufnr . ')<cr><cmd>call <sid>release_height()<cr>', l:opt)
  endif

  if l:winnrs['below'] isnot l:winnrs['cur']
    call nvim_buf_set_keymap(a:float_bufnr, 'n', s:keys['Focus below'], '<cmd>call <sid>leave_float_win(' . a:float_bufnr . ', v:false)<cr><cmd>call <sid>focus(' . l:winnrs['below'] . ')<cr>', l:opt)
    if l:winnrs['above'] is l:winnrs['cur']
      call nvim_buf_set_keymap(a:float_bufnr, 'n', s:keys['Increase below'], '<cmd>call <sid>fix_height({'.l:winnrs['cur'].':0,'.l:winnrs['below'].':0})<cr><cmd>call <sid>wincmd(' . l:winnrs['cur'] . ', "+")<cr><cmd>call <sid>set_guide(' . a:under_winid . ', ' . a:float_winid . ', ' . a:float_bufnr . ')<cr><cmd>call <sid>release_height()<cr>', l:opt)
      call nvim_buf_set_keymap(a:float_bufnr, 'n', s:keys['Decrease below'], '<cmd>call <sid>fix_height({'.l:winnrs['cur'].':0,'.l:winnrs['below'].':0})<cr><cmd>call <sid>wincmd(' . l:winnrs['cur'] . ', "-")<cr><cmd>call <sid>set_guide(' . a:under_winid . ', ' . a:float_winid . ', ' . a:float_bufnr . ')<cr><cmd>call <sid>release_height()<cr>', l:opt)
    else
      call nvim_buf_set_keymap(a:float_bufnr, 'n', s:keys['Increase below'], '<cmd>call <sid>fix_height({'.l:winnrs['cur'].':0,'.l:winnrs['below'].':0})<cr><cmd>call <sid>wincmd(' . l:winnrs['below'] . ', "-")<cr><cmd>call <sid>set_guide(' . a:under_winid . ', ' . a:float_winid . ', ' . a:float_bufnr . ')<cr><cmd>call <sid>release_height()<cr>', l:opt)
      call nvim_buf_set_keymap(a:float_bufnr, 'n', s:keys['Decrease below'], '<cmd>call <sid>fix_height({'.l:winnrs['cur'].':0,'.l:winnrs['below'].':0})<cr><cmd>call <sid>wincmd(' . l:winnrs['below'] . ', "+")<cr><cmd>call <sid>set_guide(' . a:under_winid . ', ' . a:float_winid . ', ' . a:float_bufnr . ')<cr><cmd>call <sid>release_height()<cr>', l:opt)
    endif
  endif

  if l:winnrs['right'] isnot l:winnrs['cur']
    call nvim_buf_set_keymap(a:float_bufnr, 'n', s:keys['Focus right'], '<cmd>call <sid>leave_float_win(' . a:float_bufnr . ', v:false)<cr><cmd>call <sid>focus(' . l:winnrs['right'] . ')<cr>', l:opt)
    if l:winnrs['left'] is l:winnrs['cur']
      " cur win on the left edge
      call nvim_buf_set_keymap(a:float_bufnr, 'n', s:keys['Increase right'], '<cmd>call <sid>fix_width({'.l:winnrs['cur'].':0,'.l:winnrs['right'].':0})<cr><cmd>call <sid>wincmd(' . l:winnrs['cur'] . ', ">")<cr><cmd>call <sid>set_guide(' . a:under_winid . ', ' . a:float_winid . ', ' . a:float_bufnr . ')<cr><cmd>call <sid>release_width()<cr>', l:opt)
      call nvim_buf_set_keymap(a:float_bufnr, 'n', s:keys['Decrease right'], '<cmd>call <sid>fix_width({'.l:winnrs['cur'].':0,'.l:winnrs['right'].':0})<cr><cmd>call <sid>wincmd(' . l:winnrs['cur'] . ', "<")<cr><cmd>call <sid>set_guide(' . a:under_winid . ', ' . a:float_winid . ', ' . a:float_bufnr . ')<cr><cmd>call <sid>release_width()<cr>', l:opt)
    else
      call nvim_buf_set_keymap(a:float_bufnr, 'n', s:keys['Increase right'], '<cmd>call <sid>fix_width({'.l:winnrs['cur'].':0,'.l:winnrs['right'].':0})<cr><cmd>call <sid>wincmd(' . l:winnrs['right'] . ', "<")<cr><cmd>call <sid>set_guide(' . a:under_winid . ', ' . a:float_winid . ', ' . a:float_bufnr . ')<cr><cmd>call <sid>release_width()<cr>', l:opt)
      call nvim_buf_set_keymap(a:float_bufnr, 'n', s:keys['Decrease right'], '<cmd>call <sid>fix_width({'.l:winnrs['cur'].':0,'.l:winnrs['right'].':0})<cr><cmd>call <sid>wincmd(' . l:winnrs['right'] . ', ">")<cr><cmd>call <sid>set_guide(' . a:under_winid . ', ' . a:float_winid . ', ' . a:float_bufnr . ')<cr><cmd>call <sid>release_width()<cr>', l:opt)
    endif
  endif
endfunction

function! s:leave_float_win(float_bufnr, autocmd)
  " on leaving from float window
  if a:autocmd && get(s:, 'curtain_moving', v:false)
    return
  endif
  execute 'silent! bwipeout! ' . a:float_bufnr
endfunction

function! s:set_autocmd(float_bufnr)
  " set autocmds on the buffer
  augroup curtain.nvim
    autocmd!
    execute 'autocmd WinLeave call <sid>leave_float_win(' . a:float_bufnr . ', v:true)'
  augroup END
endfunction

function! s:set_option(float_winid, float_bufnr) abort
  " set options on the buffer
  call nvim_buf_set_option(a:float_bufnr, 'filetype', 'curtain')
  call nvim_buf_set_option(a:float_bufnr, 'buftype', 'nofile')
  call nvim_win_set_option(a:float_winid, 'cursorline', v:false)
  call nvim_win_set_option(a:float_winid, 'cursorcolumn', v:false)
  call nvim_win_set_option(a:float_winid, 'scrolloff', 0)
  call nvim_win_set_option(a:float_winid, 'sidescrolloff', 0)
endfunction

function! s:focus(under_winnr) abort
  " focus the window (as resizing window)
  let l:float_bufnr = nvim_create_buf(v:false, v:true)
  let l:under_winid = win_getid(a:under_winnr)
  let l:under_win = getwininfo(l:under_winid)[0]
  let l:float_winid = nvim_open_win(l:float_bufnr, v:true, {
        \ 'relative': 'win',
        \ 'win': l:under_winid,
        \ 'width': l:under_win.width,
        \ 'height': l:under_win.height,
        \ 'row': 0,
        \ 'col': 0,
        \ 'style': 'minimal',
        \ })
  call s:set_guide(l:under_winid, l:float_winid, l:float_bufnr)
  call s:set_style(l:float_winid)
  call s:set_keymap(l:under_winid, l:float_winid, l:float_bufnr)
  call s:set_option(l:float_winid, l:float_bufnr)
  call s:set_autocmd(l:float_bufnr)
  " call win_gotoid(l:float_winid)
endfunction

function! curtain#start()
  " start curtain mode (entrypoint)
  let l:winnum = 0
  for l:winnr in range(1, winnr('$'))
    let l:type = win_gettype(l:winnr)
    if l:type ==# "autocmd" || l:type ==# "quickfix" || l:type ==# "preview" || l:type ==# "command" || l:type ==# ""
      let l:winnum = l:winnum + 1
    endif
  endfor
  if l:winnum <= 1
    return
  endif

  call s:focus(winnr())
endfunction
