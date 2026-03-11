"==============================================================================
"    Copyright: Copyright (C) 2012 Stanislas Polu an other Contributors
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               dwm.vim is provided *as is* and comes with no warranty of
"               any kind, either expressed or implied. In no event will the
"               copyright holder be liable for any damages resulting from
"               the use of this software.
" Name Of File: dwm.vim
"  Description: Dynamic Window Manager behaviour for Vim
"   Maintainer: Stanislas Polu (polu.stanislas at gmail dot com)
" Last Changed: Tuesday, 23 August 2012
"      Version: See g:dwm_version for version number.
"        Usage: This file should reside in the plugin directory and be
"               automatically sourced.
"
"               For more help see supplied documentation.
"      History: See supplied documentation.
"==============================================================================

"==============================================================================
"   Contributor: Pablo Gimenez (pablogipi at gmail dot com)
"  Last Changed: Monday, 09 March 2026
"       Version: See g:dwm_version for version number.
"       Changes: Added support to keep layout with plugins
"                like NERD Tree, Vista Scratch and with Quickfix
"                windows
"==============================================================================


" Exit quickly if already running
if exists("g:dwm_version") || &diff || &cp
  finish
endif

let g:dwm_version = "0.1.3"

" Check for Vim version 700 or greater {{{1
if v:version < 700
  echo "Sorry, dwm.vim ".g:dwm_version."\nONLY runs with Vim 7.0 and greater."
  finish
endif

" All layout transformations assume the layout contains one master pane on the
" left and an arbitrary number of stacked panes on the right
" +--------+--------+
" |        |   S1   |
" |        +--------+
" |   M    |   S3   |
" |        +--------+
" |        |   S3   |
" +--------+--------+

" Move the current master pane to the stack
function! DWM_Stack(clockwise)
  1wincmd w
  if a:clockwise
    " Move to the top of the stack
    wincmd K
  else
    " Move to the bottom of the stack
    wincmd J
  endif
  " At this point, the layout *should* be the following with the previous master
  " at the top.
  " +-----------------+
  " |        M        |
  " +-----------------+
  " |        S1       |
  " +-----------------+
  " |        S2       |
  " +-----------------+
  " |        S3       |
  " +-----------------+
endfunction

" Pre layout windows. This allows to do some operations before any DWM layoput
" command is run:
" - Take care of NERDTree windws to keep layout with NERDTree at the left
function! DWM_PreLayout()


endfunction


" Add a new buffer
function! DWM_New()
    " Check if the  current window is part of the 'layout'
    if !DWM_CanChangeLayout()
        return
    endif
    call DWM_PreLayoutChange()

    " Move current master pane to the stack
    call DWM_Stack(1)
    " Create a vertical split
    vert topleft split
    call DWM_ResizeMasterPaneWidth()

    call DWM_PostLayoutChange()
endfunction

" Move the current window to the master pane (the previous master window is
" added to the top of the stack). If current window is master already - switch
" to stack top
function! DWM_Focus()
    " Check if the  current window is part of the 'layout'
    if !DWM_CanChangeLayout()
        return
    endif
    call DWM_PreLayoutChange()

    if winnr('$') == 1
        return
    endif

    if winnr() == 1
        wincmd w
    endif

    let l:curwin = winnr()
    call DWM_Stack(1)
    exec l:curwin . "wincmd w"
    wincmd H
    call DWM_ResizeMasterPaneWidth()

    call DWM_PostLayoutChange()
endfunction

" Handler for BufWinEnter autocommand
" Recreate layout broken by new window
function! DWM_AutoEnter()
  if winnr('$') == 1
    return
  endif

  " Skip buffers without filetype
  if !len(&l:filetype)
    return
  endif

  " Skip quickfix buffers
  if &l:buftype == 'quickfix'
    return
  endif
  " Skip nerdtree buffers
  if &l:buftype == 'nerdtree'
    return
  endif
  " Skip nerdtree buffers
  if &l:filetype == 'vista'
    return
  endif
  " Skip Scratch buffers
  if &l:filetype == 'scratch'
    return
  endif
  " Skip terminal buffers
  if &l:buftype == 'terminal'
    return
  endif

  " Move new window to stack top
  wincmd K

  " Focus new window (twice :)
  call DWM_Focus()
  call DWM_Focus()
endfunction

" Close the current window
function! DWM_Close()
    " Check if the  current window is part of the 'layout'
    if !DWM_CanChangeLayout()
        return
    endif

    if winnr() == 1
        " Close master panel.
        return 'close | wincmd H | call DWM_ResizeMasterPaneWidth()'
    else
        return 'close'
    end

    call DWM_PreLayoutChange()

    call DWM_PostLayoutChange()
endfunction

function! DWM_ResizeMasterPaneWidth()
  " Make all windows equally high and wide
  wincmd =

  " resize the master pane if user defined it
  if exists('g:dwm_master_pane_width')
    if type(g:dwm_master_pane_width) == type("")
      exec 'vertical resize ' . ((str2nr(g:dwm_master_pane_width)*&columns)/100)
    else
      exec 'vertical resize ' . g:dwm_master_pane_width
    endif
  endif
endfunction

function! DWM_GrowMaster()
  if winnr() == 1
    exec "vertical resize +1"
  else
    exec "vertical resize -1"
  endif
  if exists("g:dwm_master_pane_width") && g:dwm_master_pane_width
    let g:dwm_master_pane_width += 1
  else
    let g:dwm_master_pane_width = ((&columns)/2)+1
  endif
endfunction

function! DWM_ShrinkMaster()
  if winnr() == 1
    exec "vertical resize -1"
  else
    exec "vertical resize +1"
  endif
  if exists("g:dwm_master_pane_width") && g:dwm_master_pane_width
    let g:dwm_master_pane_width -= 1
  else
    let g:dwm_master_pane_width = ((&columns)/2)-1
  endif
endfunction

" Function to do all required operations before layoput changes
" - Find all well know buffer types (NerdTree, Vista, Qyuckfix, etc ....
" - Register found windows in global vars
" - For every known window Close it
function! DWM_PreLayoutChange()
    " Find well known windows
    let g:dwm_has_nerdtree = TDVimFindWindowByType ( "nerdtree" )
    let g:dwm_has_vista    = TDVimFindWindowByType ( "vista" )
    let g:dwm_has_quickfix = TDVimFindWindowByType ( "quickfix" )
    let g:dwm_has_scratch  = TDVimFindWindowByType ( "scratch" )
    let g:dwm_has_terminal  = TDVimFindWindowByType ( "terminal" )

    " close well known windows
    if g:dwm_has_nerdtree > 0
        echomsg "Close NERDTree: " . g:dwm_has_nerdtree
        NERDTreeToggleVCS
    endif
    if g:dwm_has_vista > 0
        echomsg "Close Vista: " . g:dwm_has_vista
        silent! Vista!
    endif
    if g:dwm_has_quickfix > 0
        echomsg "Close Quickfix: " . g:dwm_has_quickfix
        cclose
    endif
    if g:dwm_has_scratch > 0
        echomsg "Close Scratch: " . g:dwm_has_scratch
        exe g:dwm_has_scratch . "wincmd c"
    endif
    if g:dwm_has_terminal > 0
        echomsg "Hide Terminal: " . g:dwm_has_terminal
        exe g:dwm_has_terminal . "hide"
    endif

endfunction

" Function to do all required operations after layoput changes
" - Find registered well known windows. Basically envars
" - For registered windows restore them
" - Reset every positive envar related to well known windows
function! DWM_PostLayoutChange()
    " Save current buffer focus
    let nbuf     = winbufnr(winnr())
    let buftype  = getbufvar(nbuf, '&buftype')
    let bufname  = bufname(nbuf)
    let filetype = getbufvar(nbuf, '&filetype')
    let restore_focus = v:false
    " Find well known windows that needs to be restored
    echo "Need to restore NERDTree: " . g:dwm_has_nerdtree
    if g:dwm_has_nerdtree > 0
        NERDTreeToggleVCS
        echomsg "NERDTRee restored"
        let g:dwm_has_nerdtree = -1
        let restore_focus = v:true
    endif
    echo "Need to restore Vista: " . g:dwm_has_vista
    if g:dwm_has_vista > 0
        silent! Vista!!
        echomsg "Vista restored"
        let g:dwm_has_vista = -1
        let restore_focus = v:true
    endif
    echo "Need to restore Quickfix: " . g:dwm_has_quickfix
    if g:dwm_has_quickfix > 0
        copen
        echomsg "Quickfix restored"
        let g:dwm_has_quickfix = -1
        let restore_focus = v:true
    endif
    echo "Need to restore Scratch: " . g:dwm_has_scratch
    if g:dwm_has_scratch > 0
        Scratch
        echomsg "Scratch restored"
        let g:dwm_has_quickfix = -1
        let restore_focus = v:true
    endif
    echo "Need to restore Terminal: " . g:dwm_has_terminal
    if g:dwm_has_terminal > 0
        " Thanks Deepseek
        execute "botright sb" filter(range(1, bufnr('$')), 'getbufvar(v:val, "&buftype") == "terminal"')[0]
        echomsg "Tewrminal restored"
        let g:dwm_has_terminal = -1
        let restore_focus = v:true
    endif
    " Restore focus to our window
    if restore_focus
        echomsg "Looking for buffer: " . bufname
        let win_nr = bufwinnr(bufname)
        echomsg  "Found at: " . win_nr
        if win_nr != -1
            exe win_nr . "wincmd w"
        endif
    endif

endfunction

" Check if the  current window is part of the 'layout'
" For instance if our focus is in a NERDTree window thne don't modify the
" layout
function! DWM_CanChangeLayout()
    let nbuf = winbufnr(winnr())
    let buftype = getbufvar(nbuf, '&buftype')
    let filetype = getbufvar(nbuf, '&filetype')

    if buftype  ==# "nofile" || filetype ==# 'nerdtree'
        return v:false
    endif

    return v:true
endfunction



" Rotate windows, clockwise or anti clockwise. Main window move to first
" position in stack and last window in stack becomes main window (clockwise)
function! DWM_Rotate(clockwise)

    " Check if the  current window is part of the 'layout'
    if !DWM_CanChangeLayout()
        return
    endif
    call DWM_PreLayoutChange()

    call DWM_Stack(a:clockwise)
    if a:clockwise
        wincmd W
    else
        wincmd w
    endif
    wincmd H
    call DWM_ResizeMasterPaneWidth()

    call DWM_PostLayoutChange()
endfunction

nnoremap <silent> <Plug>DWMRotateCounterclockwise :call DWM_Rotate(0)<CR>
nnoremap <silent> <Plug>DWMRotateClockwise        :call DWM_Rotate(1)<CR>

nnoremap <silent> <Plug>DWMNew   :call DWM_New()<CR>
nnoremap <silent> <Plug>DWMClose :exec DWM_Close()<CR>
nnoremap <silent> <Plug>DWMFocus :call DWM_Focus()<CR>

nnoremap <silent> <Plug>DWMGrowMaster   :call DWM_GrowMaster()<CR>
nnoremap <silent> <Plug>DWMShrinkMaster :call DWM_ShrinkMaster()<CR>

if !exists('g:dwm_map_keys')
  let g:dwm_map_keys = 1
endif

if g:dwm_map_keys
  nnoremap <C-J> <C-W>w
  nnoremap <C-K> <C-W>W

  if !hasmapto('<Plug>DWMRotateCounterclockwise')
      "nmap <C-,> <Plug>DWMRotateCounterclockwise
      nmap <C-,>    :call DWM_Rotate(0)<CR>
  endif
  if !hasmapto('<Plug>DWMRotateClockwise')
      "nmap <C-.> <Plug>DWMRotateClockwise
      nmap <C-.>    :call DWM_Rotate(1)<CR>
  endif

  if !hasmapto('<Plug>DWMNew')
      nmap <C-N> <Plug>DWMNew
  endif
  if !hasmapto('<Plug>DWMClose')
      nmap <C-C> <Plug>DWMClose
  endif
  if !hasmapto('<Plug>DWMFocus')
      nmap <C-@> <Plug>DWMFocus
      nmap <C-Space> <Plug>DWMFocus
  endif

  if !hasmapto('<Plug>DWMGrowMaster')
      nmap <C-L> <Plug>DWMGrowMaster
  endif
  if !hasmapto('<Plug>DWMShrinkMaster')
      nmap <C-H> <Plug>DWMShrinkMaster
  endif
endif

if has('autocmd')
  augroup dwm
    au!
    au BufWinEnter * if &l:buflisted || &l:filetype == 'help' | call DWM_AutoEnter() | endif
  augroup end
endif
