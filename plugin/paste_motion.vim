" paste_motion.vim: Paste from register over the motion.
"
" DEPENDENCIES:
"   - Requires Vim 7.0 or higher.
"

" Make sure the code loads at most once.
if exists('g:loaded_paste_motion') || (v:version < 700)
    finish
endif
let g:loaded_paste_motion = 1

" Save the original value of cpo, to restore it after the script finished
" running.
let s:original_cpo = &cpo
set cpo&vim

" TODO: Understand better what the mapping does.
" Create a map to the expression of calling the plugin to call the wanted
" function.
nnoremap <expr> <Plug>paste_motion_operator paste_motion#paste_motion_operator()

" TODO: Add support for repeat and repeat.vim.
" TODO: Add support for line pasting
" TODO: Add support for visual pasting
" TODO: Change the command that paste to be configurable

if ! hasmapto('<Plug>paste_motion_operator', 'n')
    nmap gp <Plug>paste_motion_operator
endif

" Restore the value of the original cpo.
let &cpo = s:original_cpo
unlet s:original_cpo
