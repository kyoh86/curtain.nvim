" curtain.vim
" Resize windows easily like open and close a curtain.
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
endfunction

function! s:wincmd(winnr, cmd) abort
  " call wincmd on the target window (win-number)
  call s:call_on_winid(win_getid(a:winnr), { -> execute('wincmd ' . a:cmd) })
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

function! s:set_guide(buf) abort
  " set guide messages on the buffer
  let l:base_win = getwininfo(s:base_winid)[0]
  call nvim_win_set_height(s:float_winid, l:base_win.height)
  call nvim_win_set_width(s:float_winid, l:base_win.width)
  let l:winnrs = {}
  call s:call_on_winid(s:base_winid, { -> s:get_winnrs(l:winnrs) })

  " pad lines
  for l:row in range(l:base_win.height)
    call setbufline(a:buf, l:row, ' ')
  endfor

  if l:winnrs['above'] isnot l:winnrs['cur']
    call setbufline(a:buf, 1, s:get_centered_text(join(s:get_edge_guide_text('above'), '; '), l:base_win.width))
  endif

  if l:winnrs['left'] isnot l:winnrs['cur']
    let l:show_left = l:base_win.height >= len(s:behaviors) + 2
  else
    let l:show_left = v:false
  endif

  if l:winnrs['right'] isnot l:winnrs['cur']
    let l:show_right = l:base_win.height >= len(s:behaviors) + 2
  else
    let l:show_right = v:false
  endif

  if l:winnrs['below'] isnot l:winnrs['cur']
    call setbufline(a:buf, l:base_win.height, s:get_centered_text(join(s:get_edge_guide_text('below'), '; '), l:base_win.width))
  endif

  if l:show_left || l:show_right
    let l:side_msg_row = l:base_win.height/2-1
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
      let l:space = l:base_win.width - len(l:left_msgline) - len(l:right_msgline)
      if l:space < 1
        call setbufline(a:buf, l:side_msg_row + l:row, ' ')
      else
        call setbufline(a:buf, l:side_msg_row + l:row, l:left_msgline . repeat(' ', l:space) . l:right_msgline)
      endif
    endfor
  endif
endfunction

function! s:set_style() abort
  " set styles for float-window
  set winblend=10
  call nvim_win_set_option(s:float_winid, 'winhighlight', 'Normal:CurtainWindow,NormalNC:CurtainWindow')
endfunction

function! s:set_keymap(buf) abort
  " set keymaps on the buffer
  let l:base_win = getwininfo(s:base_winid)[0]
  let l:winnrs = {}
  call s:call_on_winid(s:base_winid, { -> s:get_winnrs(l:winnrs) })
  call nvim_buf_set_keymap(a:buf, 'n', '<enter>', '<cmd>call <SID>leave_float_win(' . a:buf . ', v:false)<cr>', {'noremap': v:true})
  call nvim_buf_set_keymap(a:buf, 'n', '<esc>', '<cmd>call <SID>leave_float_win(' . a:buf . ', v:false)<cr>', {'noremap': v:true})

  if l:winnrs['left'] isnot l:winnrs['cur']
    call nvim_buf_set_keymap(a:buf, 'n', s:keys['Focus left'], '<cmd>call <SID>focus(' . l:winnrs['left'] . ')<cr>', {'noremap': v:true})
    call nvim_buf_set_keymap(a:buf, 'n', s:keys['Increase left'], '<cmd>call <SID>wincmd(' . l:winnrs['left'] . ', "<")<cr><cmd>call <SID>set_guide(' . a:buf . ')<cr>', {'noremap': v:true})
    call nvim_buf_set_keymap(a:buf, 'n', s:keys['Decrease left'], '<cmd>call <SID>wincmd(' . l:winnrs['left'] . ', ">")<cr><cmd>call <SID>set_guide(' . a:buf . ')<cr>', {'noremap': v:true})
  endif

  if l:winnrs['above'] isnot l:winnrs['cur']
    call nvim_buf_set_keymap(a:buf, 'n', s:keys['Focus above'], '<cmd>call <SID>focus(' . l:winnrs['above'] . ')<cr>', {'noremap': v:true})
    call nvim_buf_set_keymap(a:buf, 'n', s:keys['Increase above'], '<cmd>call <SID>wincmd(' . l:winnrs['above'] . ', "-")<cr><cmd>call <SID>set_guide(' . a:buf . ')<cr>', {'noremap': v:true})
    call nvim_buf_set_keymap(a:buf, 'n', s:keys['Decrease above'], '<cmd>call <SID>wincmd(' . l:winnrs['above'] . ', "+")<cr><cmd>call <SID>set_guide(' . a:buf . ')<cr>', {'noremap': v:true})
  endif

  if l:winnrs['below'] isnot l:winnrs['cur']
    call nvim_buf_set_keymap(a:buf, 'n', s:keys['Focus below'], '<cmd>call <SID>focus(' . l:winnrs['below'] . ')<cr>', {'noremap': v:true})
    if l:winnrs['above'] is l:winnrs['cur']
      call nvim_buf_set_keymap(a:buf, 'n', s:keys['Increase below'], '<cmd>call <SID>wincmd(' . l:winnrs['cur'] . ', "+")<cr><cmd>call <SID>set_guide(' . a:buf . ')<cr>', {'noremap': v:true})
      call nvim_buf_set_keymap(a:buf, 'n', s:keys['Decrease below'], '<cmd>call <SID>wincmd(' . l:winnrs['cur'] . ', "-")<cr><cmd>call <SID>set_guide(' . a:buf . ')<cr>', {'noremap': v:true})
    else
      call nvim_buf_set_keymap(a:buf, 'n', s:keys['Increase below'], '<cmd>call <SID>wincmd(' . l:winnrs['below'] . ', "-")<cr><cmd>call <SID>set_guide(' . a:buf . ')<cr>', {'noremap': v:true})
      call nvim_buf_set_keymap(a:buf, 'n', s:keys['Decrease below'], '<cmd>call <SID>wincmd(' . l:winnrs['below'] . ', "+")<cr><cmd>call <SID>set_guide(' . a:buf . ')<cr>', {'noremap': v:true})
    endif
  endif

  if l:winnrs['right'] isnot l:winnrs['cur']
    call nvim_buf_set_keymap(a:buf, 'n', s:keys['Focus right'], '<cmd>call <SID>focus(' . l:winnrs['right'] . ')<cr>', {'noremap': v:true})
    if l:winnrs['left'] is l:winnrs['cur']
      " cur win on the left edge
      call nvim_buf_set_keymap(a:buf, 'n', s:keys['Increase right'], '<cmd>call <SID>wincmd(' . l:winnrs['cur'] . ', ">")<cr><cmd>call <SID>set_guide(' . a:buf . ')<cr>', {'noremap': v:true})
      call nvim_buf_set_keymap(a:buf, 'n', s:keys['Decrease right'], '<cmd>call <SID>wincmd(' . l:winnrs['cur'] . ', "<")<cr><cmd>call <SID>set_guide(' . a:buf . ')<cr>', {'noremap': v:true})
    else
      call nvim_buf_set_keymap(a:buf, 'n', s:keys['Increase right'], '<cmd>call <SID>wincmd(' . l:winnrs['right'] . ', "<")<cr><cmd>call <SID>set_guide(' . a:buf . ')<cr>', {'noremap': v:true})
      call nvim_buf_set_keymap(a:buf, 'n', s:keys['Decrease right'], '<cmd>call <SID>wincmd(' . l:winnrs['right'] . ', ">")<cr><cmd>call <SID>set_guide(' . a:buf . ')<cr>', {'noremap': v:true})
    endif
  endif
endfunction

function! s:leave_float_win(buf, autocmd)
  " on leaving from float window
  if a:autocmd && get(s:, 'curtain_moving', v:false)
    return
  endif
  execute 'bwipeout! ' . a:buf
  call s:close_float_win()
endfunction

function s:close_float_win()
  " close float window
  if s:float_winid isnot 0
    silent! call nvim_win_close(s:float_winid, v:true)
  endif
  let s:base_winnr = 0
  let s:base_winid = 0
  let s:float_winid = 0
endfunction

function! s:set_autocmd(buf)
  " set autocmds on the buffer
  augroup curtain.nvim
    autocmd!
    execute 'autocmd WinLeave <buffer=' . a:buf . '> call <SID>leave_float_win(' . a:buf . ', v:true)'
  augroup END
endfunction

function! s:set_option(buf) abort
  " set options on the buffer
  call nvim_buf_set_option(a:buf, 'filetype', 'curtain')
  call nvim_buf_set_option(a:buf, 'buftype', 'nofile')
endfunction

function! s:focus(winnr) abort
  " focus the window (as resizing window)
  if get(s:, 'float_winid', 0) isnot 0
    call s:close_float_win()
  endif
  let l:buf = nvim_create_buf(v:false, v:true)
  let s:base_winnr = a:winnr
  let s:base_winid = win_getid(s:base_winnr)
  let l:base_win = getwininfo(s:base_winid)[0]
  let s:float_winid = nvim_open_win(l:buf, v:true, {
        \ 'relative': 'win',
        \ 'win': s:base_winid,
        \ 'width': l:base_win.width,
        \ 'height': l:base_win.height,
        \ 'row': 0,
        \ 'col': 0,
        \ 'style': 'minimal',
        \ })
  call s:set_guide(l:buf)
  call s:set_style()
  call s:set_keymap(l:buf)
  call s:set_autocmd(l:buf)
  call s:set_option(l:buf)
endfunction

function! curtain#start()
  " start curtain mode (entrypoint)
  if winnr('$') == 1
    return
  endif

  call s:focus(winnr())
endfunction
